--!strict
-- ProfileLogic: pure transforms over the persisted ProfileV2 (GDD 9). Every function returns a
-- result instead of yielding, so DataService can run them inside DataStore:UpdateAsync and the
-- same code runs against the mock store in tests.
--
-- Exact-once rule: a settlement carries a `key` (matchId, or matchId..":partial"). Applying a
-- key already in awardedMatchIds changes nothing (B02, B07).
--
-- V3 (GDD v0.4): Gold (earn-only) replaces Shells, Gems (earned now, purchasable later), egg PIECES
-- (common / rare / epic) replace egg tokens, pets crafted from pieces, cosmetics bought with Gold/Gems.
-- Economy numbers come in through `econ` (Shared/EconomyConfig) so tests and server share them.

local ProfileLogic = {}

ProfileLogic.SCHEMA_VERSION = 3

local TIER_KEYS = { "1", "2", "3", "4" } -- string keys: DataStore JSON keeps them stable
local MATERIAL_KEYS = { "common", "rare", "epic", "crowned" } -- crowned: reserved (deferred tier)
local LEGACY_TIER_TO_MATERIAL = { ["1"] = "common", ["2"] = "rare", ["3"] = "epic", ["4"] = "epic" }
local IncubatorLogic = require(script.Parent:WaitForChild("IncubatorLogic")) -- HOS-EGG-002: the incubator egg (shards, hatch, focus)

local function num(v: any, default: number): number
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return default
	end
	return v
end

function ProfileLogic.default(): any
	local eggs = {}
	for _, k in ipairs(TIER_KEYS) do
		eggs[k] = 0
	end
	local materials = {}
	for _, k in ipairs(MATERIAL_KEYS) do
		materials[k] = 0
	end
	return {
		schemaVersion = ProfileLogic.SCHEMA_VERSION,
		gold = 0,
		xp = 0, -- account XP (EconomyConfig.levelFor -> the nameplate level)
		gems = 0, -- spendable (earned + purchased); purchases are also tallied in stats + receipts
		materials = materials,
		pets = {}, -- { id, family, rarity, species, n } (n = hatch number, for ordering)
		nextPetId = 1,
		equippedPet = "", -- pet id, "" = none (no starter pet)
		firstCommonFree = true, -- the first Common hatch includes a free family choice
		cosmetics = { owned = {}, consumables = {}, case = "", trailNext = "" },
		emotes = {}, -- [emoteId] = true (won from the Emote Crate; see Shared/EmoteConfig)
		emoteWheel = {}, -- up to 6 owned emote ids on the G wheel ("" = empty slot)
		receipts = {}, -- bounded exact-once ledger for Robux purchases (newest last)
		shells = 0, -- V2 currency, moved into gold by migrate (kept for old saves)
		unhatchedEggsByTier = eggs, -- V2 egg tokens, moved into materials by migrate
		stats = {
			wins = 0,
			matchesCompleted = 0,
			captures = 0,
			successfulCrossings = 0,
			lifetimeBestTier = 1,
			lifetimeShellsEarned = 0,
			timesFirstHunter = 0,
			goldEarned = 0,
			gemsEarned = 0,
			gemsPurchased = 0,
			petsHatched = 0,
		},
		dailyQuests = { utcDate = "", active = {}, progress = {}, claimed = {} },
		afkPreference = false,
		volunteerPreference = false,
		settings = { sfx = true, reduceEffects = false, showHints = true },
		hunterHistory = { recentMatchIds = {}, lastHunterAt = 0 },
		cosmeticInventory = {}, -- RESERVED, DO NOT POPULATE
		petInventory = {}, -- RESERVED, DO NOT POPULATE
		awardedMatchIds = {}, -- bounded exact-once ledger (newest last)
	}
end

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = deepCopy(v)
	end
	return c
end
ProfileLogic.deepCopy = deepCopy

-- Load-time migration. Accepts nil (new player), V1-ish shapes, or V2. Never wipes positive
-- balances, keeps unknown fields (future versions), sanitises NaN/inf. Returns (profile, changed).
function ProfileLogic.migrate(raw: any): (any, boolean)
	if type(raw) ~= "table" then
		return ProfileLogic.default(), true
	end
	local p = deepCopy(raw)
	local d = ProfileLogic.default()
	local changed = false
	local version = num(p.schemaVersion, 1)

	-- V1 field names seen in the v0.1 design: coins, eggs = { basic=, uncommon=, ... }
	if version < 2 then
		if p.shells == nil and type(p.coins) == "number" then
			p.shells = p.coins
		end
		if type(p.eggs) == "table" and type(p.unhatchedEggsByTier) ~= "table" then
			local map = { basic = "1", uncommon = "2", rare = "3", epic = "4" }
			local eggs = {}
			for name, count in pairs(p.eggs) do
				local k = map[string.lower(tostring(name))] or (if tonumber(name) then tostring(tonumber(name)) else nil)
				if k then
					eggs[k] = (eggs[k] or 0) + num(count, 0)
				end
			end
			p.unhatchedEggsByTier = eggs
		end
		p.schemaVersion = ProfileLogic.SCHEMA_VERSION
		changed = true
	end

	-- fill missing fields from defaults (shallow for scalars, one level for tables)
	for k, v in pairs(d) do
		if p[k] == nil then
			p[k] = deepCopy(v)
			changed = true
		elseif type(v) == "table" and type(p[k]) == "table" then
			for k2, v2 in pairs(v) do
				if p[k][k2] == nil and k ~= "awardedMatchIds" and k ~= "cosmeticInventory" and k ~= "petInventory" and k ~= "pets" and k ~= "receipts" then
					p[k][k2] = deepCopy(v2)
					changed = true
				end
			end
		elseif type(v) ~= type(p[k]) then
			p[k] = deepCopy(v)
			changed = true
		end
	end

	-- egg counts: numeric keys -> string keys, sanitise
	local eggs = {}
	for k, v in pairs(p.unhatchedEggsByTier) do
		local key = tostring(tonumber(k) or k)
		eggs[key] = math.max(0, math.floor(num(v, 0))) + (eggs[key] or 0)
	end
	for _, k in ipairs(TIER_KEYS) do
		eggs[k] = eggs[k] or 0
	end
	p.unhatchedEggsByTier = eggs

	p.shells = math.max(0, math.floor(num(p.shells, 0)))
	p.gold = math.max(0, math.floor(num(p.gold, 0)))
	p.gems = math.max(0, math.floor(num(p.gems, 0)))
	for _, k in ipairs(MATERIAL_KEYS) do
		p.materials[k] = math.max(0, math.floor(num(p.materials[k], 0)))
	end
	-- V2 -> V3: Shells become Gold and egg tokens become pieces of the matching tier (Tier 4 = Epic).
	-- Balances move, they are never wiped; the old fields are zeroed so this runs once.
	if version < 3 then
		p.gold += p.shells
		p.shells = 0
		for k, n in pairs(p.unhatchedEggsByTier) do
			local m = LEGACY_TIER_TO_MATERIAL[k]
			if m and n > 0 then
				p.materials[m] += n
				p.unhatchedEggsByTier[k] = 0
			end
		end
		p.schemaVersion = ProfileLogic.SCHEMA_VERSION
		changed = true
	end
	if type(p.equippedPet) ~= "string" then
		p.equippedPet = ""
	end
	local petIds = {}
	local cleanPets = {}
	for _, pet in ipairs(p.pets) do
		if type(pet) == "table" and type(pet.id) == "string" and type(pet.family) == "string" and type(pet.rarity) == "string" and not petIds[pet.id] then
			petIds[pet.id] = true
			table.insert(cleanPets, pet)
		end
	end
	p.pets = cleanPets
	if p.equippedPet ~= "" and not petIds[p.equippedPet] then
		p.equippedPet = ""
	end
	for _, k in ipairs({ "owned", "consumables" }) do
		if type(p.cosmetics[k]) ~= "table" then
			p.cosmetics[k] = {}
		end
	end
	for _, k in ipairs({ "case", "trailNext" }) do
		if type(p.cosmetics[k]) ~= "string" then
			p.cosmetics[k] = ""
		end
	end
	for k, v in pairs(p.stats) do
		p.stats[k] = num(v, 0)
	end
	if p.stats.lifetimeBestTier < 1 then
		p.stats.lifetimeBestTier = 1
	end
	if type(p.dailyQuests.active) ~= "table" then
		p.dailyQuests.active = {}
	end
	changed = IncubatorLogic.migrate(p) or changed -- HOS-EGG-002: the incubator egg; old pieces -> fill once (incubatorV1)
	return p, changed
end

-- ===== daily quests =====

function ProfileLogic.utcDate(epochSeconds: number): string
	-- Roblox's os.date only supports "*t" / "!*t", so format by hand
	local t = os.date("!*t", math.floor(epochSeconds)) :: any
	return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

-- Seconds until the next 00:00 UTC (quest reset timer)
function ProfileLogic.secondsToUtcMidnight(epochSeconds: number): number
	return 86400 - (math.floor(epochSeconds) % 86400)
end

-- Reset quests when the server UTC day differs from the stored one (B12).
function ProfileLogic.ensureDaily(p: any, utcDate: string, questConfig: any): boolean
	local dq = p.dailyQuests
	if dq.utcDate == utcDate and #dq.active > 0 then
		return false
	end
	local active = questConfig.forDate(utcDate)
	local progress, claimed = {}, {}
	for _, id in ipairs(active) do
		progress[id] = 0
		claimed[id] = false
	end
	p.dailyQuests = { utcDate = utcDate, active = active, progress = progress, claimed = claimed }
	return true
end

local function questDelta(q: any, s: any): number
	local qs = s.quest or {}
	if q.metric == "crossings" then
		return num(qs.crossings, 0)
	elseif q.metric == "captures" then
		return num(qs.captures, 0)
	elseif q.metric == "matches" then
		return num(qs.matches, 0)
	elseif q.metric == "secureTier" then
		return if num(qs.securedTier, 0) >= (q.minTier or 1) then 1 else 0
	end
	return 0
end

-- ===== settlement =====

local function ledgerHas(p: any, key: string): boolean
	for _, k in ipairs(p.awardedMatchIds) do
		if k == key then
			return true
		end
	end
	return false
end

-- Apply one match settlement exactly once. Returns (applied, summary).
-- summary lists quest progress changes so the caller can log QuestProgressed.
function ProfileLogic.applySettlement(p: any, s: any, ctx: { utcDate: string, questConfig: any, ledgerSize: number, economy: any? }): (boolean, any)
	if type(s) ~= "table" or type(s.key) ~= "string" then
		return false, { reason = "BAD_SETTLEMENT" }
	end
	if ledgerHas(p, s.key) then
		return false, { reason = "DUPLICATE" }
	end
	ProfileLogic.ensureDaily(p, ctx.utcDate, ctx.questConfig)

	-- Gold (s.shells is the pre-V3 name for the same thing)
	local gold = math.max(0, math.floor(num(if s.gold ~= nil then s.gold else s.shells, 0)))
	p.gold += gold
	p.stats.goldEarned += gold
	local gems = math.max(0, math.floor(num(s.gems, 0)))
	p.gems += gems
	p.stats.gemsEarned += gems

	-- account XP; each level-up pays EconomyConfig.LEVEL_REWARD (ctx.economy), in this same exact-once settlement
	local xp = math.max(0, math.floor(num(s.xp, 0)))
	local levelUps = {}
	if xp > 0 then
		local econ = ctx.economy
		local before = if econ then (econ.levelFor(num(p.xp, 0))) else 0
		p.xp = num(p.xp, 0) + xp
		if econ then
			local after = (econ.levelFor(p.xp))
			local R = econ.LEVEL_REWARD
			for L = before + 1, after do
				local g = R.gold
				local gm = if L % R.gemsEvery == 0 then R.gems else 0
				p.gold += g
				p.stats.goldEarned += g
				p.gems += gm
				p.stats.gemsEarned += gm
				table.insert(levelUps, { level = L, gold = g, gems = gm })
			end
		end
	end

	-- the match's one egg piece (at most one primary piece per match)
	local material = s.material
	if type(material) == "string" and p.materials[material] ~= nil and material ~= "crowned" then
		p.materials[material] += 1
	else
		material = nil
	end
	-- HOS-HOC-001: bonus egg pieces (a Hero who got across alone rolls one per Hero run), at most 5
	local bonusMaterials = {}
	if type(s.bonusMaterials) == "table" then
		for i, m in ipairs(s.bonusMaterials) do
			if i <= 5 and type(m) == "string" and p.materials[m] ~= nil and m ~= "crowned" then
				p.materials[m] += 1
				table.insert(bonusMaterials, m)
			end
		end
	end
	local shard = IncubatorLogic.applySettlement(p, s) -- HOS-EGG-002: the match's shard (s.shard) + match time (s.seconds)
	local egg = s.eggTier
	if not (type(egg) == "number" and egg >= 1 and egg <= #TIER_KEYS and egg == math.floor(egg)) then
		egg = nil
	end

	local st = s.stats or {}
	p.stats.wins += num(st.wins, 0)
	p.stats.matchesCompleted += num(st.matchesCompleted, 0)
	p.stats.captures += num(st.captures, 0)
	p.stats.successfulCrossings += num(st.successfulCrossings, 0)
	if type(s.bestTier) == "number" then
		p.stats.lifetimeBestTier = math.max(p.stats.lifetimeBestTier, s.bestTier)
	end
	if s.initialHunter then
		p.stats.timesFirstHunter += 1
		table.insert(p.hunterHistory.recentMatchIds, s.matchId)
		while #p.hunterHistory.recentMatchIds > 10 do
			table.remove(p.hunterHistory.recentMatchIds, 1)
		end
	end

	-- quest progress (only for today's active quests, capped at target)
	local questChanges = {}
	local dq = p.dailyQuests
	for _, id in ipairs(dq.active) do
		local q = ctx.questConfig.get(id)
		if q and not dq.claimed[id] then
			local before = num(dq.progress[id], 0)
			local after = math.min(q.target, before + questDelta(q, s))
			if after ~= before then
				dq.progress[id] = after
				table.insert(questChanges, { id = id, from = before, to = after, target = q.target })
			end
		end
	end

	table.insert(p.awardedMatchIds, s.key)
	while #p.awardedMatchIds > ctx.ledgerSize do
		table.remove(p.awardedMatchIds, 1)
	end
	return true, { gold = gold, gems = gems, xp = xp, levelUps = levelUps, material = material, bonusMaterials = bonusMaterials, eggTier = egg, quests = questChanges, shard = shard }
end

-- Claim a completed daily quest once (B11). Returns (ok, reason, reward).
function ProfileLogic.claimQuest(p: any, questId: string, ctx: { utcDate: string, questConfig: any }): (boolean, string?, number?)
	ProfileLogic.ensureDaily(p, ctx.utcDate, ctx.questConfig)
	local dq = p.dailyQuests
	local active = false
	for _, id in ipairs(dq.active) do
		if id == questId then
			active = true
		end
	end
	if not active then
		return false, "NOT_ACTIVE", nil
	end
	if dq.claimed[questId] then
		return false, "ALREADY_CLAIMED", nil
	end
	local q = ctx.questConfig.get(questId)
	if not q then
		return false, "UNKNOWN", nil
	end
	if num(dq.progress[questId], 0) < q.target then
		return false, "NOT_COMPLETE", nil
	end
	dq.claimed[questId] = true
	p.gold += q.reward
	p.stats.goldEarned += q.reward
	return true, nil, q.reward
end

-- ===== incubator: pieces -> pets (GDD 03, 09) =====

-- What a hatch would use. focused = the player picks the family (one extra piece), except the first
-- Common hatch, which includes a free pick. Missing pieces of the recipe tier can be filled 1:1 from
-- HIGHER tiers (never lower). Returns (plan, reason).
function ProfileLogic.hatchPlan(p: any, rarity: string, focused: boolean, econ: any): (any?, string?)
	local recipe = econ.RECIPES[rarity]
	local idx = econ.materialIndex(rarity)
	if not recipe or not idx then
		return nil, "BAD_RARITY"
	end
	local free = rarity == "common" and p.firstCommonFree == true
	local cost = if focused and not free then recipe.focus else recipe.base
	local take: { [string]: number } = {}
	local need = cost
	local usesHigher = false
	for i = idx, #econ.MATERIALS do
		local m = econ.MATERIALS[i]
		local n = math.min(p.materials[m] or 0, need)
		if n > 0 then
			take[m] = n
			need -= n
			if i > idx then
				usesHigher = true
			end
		end
		if need == 0 then
			break
		end
	end
	local plan = { rarity = rarity, cost = cost, take = take, free = free, focused = focused or free, usesHigher = usesHigher, missing = need }
	if need > 0 then
		return plan, "NOT_ENOUGH"
	end
	return plan, nil
end

-- Hatch a pet. ctx: { econ, pickFamily: () -> string, allowHigher: boolean? }
-- family = nil for a random family. Returns (ok, reason, pet, plan). Atomic: nothing changes on failure.
function ProfileLogic.hatch(p: any, rarity: string, family: string?, ctx: any): (boolean, string?, any?, any?)
	local econ = ctx.econ
	if family ~= nil and not table.find(econ.LAUNCH_FAMILIES, family) then
		return false, "BAD_FAMILY", nil, nil
	end
	local plan, reason = ProfileLogic.hatchPlan(p, rarity, family ~= nil, econ)
	if not plan or reason then
		return false, reason, nil, plan
	end
	if plan.free and family == nil then
		return false, "CHOOSE_FAMILY", nil, plan -- the first Common pet is always a chosen family
	end
	if plan.usesHigher and not ctx.allowHigher then
		return false, "NEEDS_HIGHER", nil, plan -- the UI asks before spending higher pieces
	end
	local fam = family or ctx.pickFamily()
	if not econ.FAMILIES[fam] then
		return false, "BAD_FAMILY", nil, plan
	end
	for m, n in pairs(plan.take) do
		p.materials[m] -= n
	end
	local pet = {
		id = "p" .. p.nextPetId,
		family = fam,
		rarity = rarity,
		species = econ.speciesFor(fam, rarity),
		n = p.nextPetId,
	}
	p.nextPetId += 1
	table.insert(p.pets, pet)
	-- copies of the same family + rarity level the pet up (1..3 = the menu's mastery stars): its
	-- level look (extra parts, colours, bigger ability effects) follows on every copy
	local copies = {}
	for _, q in ipairs(p.pets) do
		if q.family == fam and q.rarity == rarity then
			table.insert(copies, q)
		end
	end
	for _, q in ipairs(copies) do
		q.level = math.min(#copies, 3)
	end
	if rarity == "common" then
		p.firstCommonFree = false
	end
	if p.equippedPet == "" then
		p.equippedPet = pet.id
	end
	p.stats.petsHatched += 1
	return true, nil, pet, plan
end

function ProfileLogic.petById(p: any, id: string): any?
	for _, pet in ipairs(p.pets) do
		if pet.id == id then
			return pet
		end
	end
	return nil
end

function ProfileLogic.equipPet(p: any, id: string): (boolean, string?)
	if id == "" then
		p.equippedPet = ""
		return true, nil
	end
	if not ProfileLogic.petById(p, id) then
		return false, "NO_PET"
	end
	p.equippedPet = id
	return true, nil
end

-- the equipped pet's ability family, or nil (no pet = baseline movement and dodge only)
function ProfileLogic.equippedFamily(p: any): string?
	local pet = if p.equippedPet ~= "" then ProfileLogic.petById(p, p.equippedPet) else nil
	return pet and pet.family or nil
end

-- ===== shops (GDD 04, 05, appendix C) =====

-- Buy one shop item. Returns (ok, reason, item).
function ProfileLogic.buy(p: any, itemId: string, econ: any): (boolean, string?, any?)
	local item = econ.item(itemId)
	if not item then
		return false, "UNKNOWN", nil
	end
	if item.kind == "pet" and econ.buyPet then return econ.buyPet(p, item) end -- HOS-HWN-001 Halloween pets (HalloweenShop)
	local consumable = econ.isConsumable(item)
	if not consumable and p.cosmetics.owned[itemId] then
		return false, "OWNED", item
	end
	local wallet = item.wallet
	if wallet ~= "gold" and wallet ~= "gems" then
		return false, "BAD_WALLET", item
	end
	if (p[wallet] or 0) < item.price then
		return false, "NOT_ENOUGH", item
	end
	p[wallet] -= item.price
	if consumable then
		p.cosmetics.consumables[itemId] = (p.cosmetics.consumables[itemId] or 0) + 1
		if item.kind == "trail" then
			p.cosmetics.trailNext = itemId -- worn in your next match
		end
	else
		p.cosmetics.owned[itemId] = true
		if item.kind == "case" then
			p.cosmetics.case = itemId
		elseif item.kind == "abilitySkin" and type(item.slot) == "string" then
			p.cosmetics[item.slot] = itemId -- HOS-VFX-RES-001: a new skin is worn straight away
		end
	end
	return true, nil, item
end

-- Use one consumable now (a lobby burst) or at match start (a trail). Returns ok.
function ProfileLogic.consume(p: any, itemId: string): boolean
	local n = p.cosmetics.consumables[itemId] or 0
	if n <= 0 then
		return false
	end
	n -= 1
	p.cosmetics.consumables[itemId] = if n > 0 then n else nil
	if n <= 0 and p.cosmetics.trailNext == itemId then
		p.cosmetics.trailNext = ""
	end
	return true
end

-- Pick the egg case to show ("" = none) or the trail for the next match ("" = none).
function ProfileLogic.setCosmetic(p: any, slot: string, itemId: string, econ: any): (boolean, string?)
	if slot ~= "case" and slot ~= "trailNext" and slot ~= "riftSkin" then
		return false, "BAD_SLOT"
	end
	if itemId == "" then
		p.cosmetics[slot] = ""
		return true, nil
	end
	local item = econ.item(itemId)
	if not item then
		return false, "UNKNOWN"
	end
	if slot == "case" and (item.kind ~= "case" or not p.cosmetics.owned[itemId]) then
		return false, "NOT_OWNED"
	end
	if slot == "trailNext" and (item.kind ~= "trail" or (p.cosmetics.consumables[itemId] or 0) <= 0) then
		return false, "NOT_OWNED"
	end
	if slot == "riftSkin" and (item.slot ~= "riftSkin" or not p.cosmetics.owned[itemId]) then
		return false, "NOT_OWNED"
	end
	p.cosmetics[slot] = itemId
	return true, nil
end

-- Emote Crate, paid with Gems: the emote is rolled by the caller BEFORE this runs (so every replay
-- of the change gives the same emote). A duplicate refunds its rarity's gems. Returns
-- (ok, reasonOrResult). result = { emote = id, dupe = bool, refund = n }
function ProfileLogic.openEmoteCrate(p: any, emoteId: string, emoteConfig: any): (boolean, any)
	local e = emoteConfig.get(emoteId)
	if not e then
		return false, "UNKNOWN"
	end
	local price = emoteConfig.CRATE_GEMS
	if p.gems < price then
		return false, "NOT_ENOUGH"
	end
	p.gems -= price
	if type(p.emotes) ~= "table" then
		p.emotes = {}
	end
	local dupe = p.emotes[emoteId] == true
	local refund = 0
	if dupe then
		refund = emoteConfig.DUPE_REFUND[e.rarity] or 0
		p.gems += refund
	else
		p.emotes[emoteId] = true
	end
	return true, { emote = emoteId, dupe = dupe, refund = refund }
end

-- Robux receipts share one bounded exact-once ledger (Gem packs, items, crates). true = new receipt (now recorded).
local function takeReceipt(p: any, receiptId: string, ledgerSize: number): boolean
	if type(p.receipts) ~= "table" then
		p.receipts = {}
	end
	for _, r in ipairs(p.receipts) do
		if r == receiptId then
			return false
		end
	end
	table.insert(p.receipts, receiptId)
	while #p.receipts > ledgerSize do
		table.remove(p.receipts, 1)
	end
	return true
end

-- A shop item bought outright with Robux (its own developer product, HOS-GEMS-001). Already owned (a keep-forever
-- item bought twice) = its Gem price is credited instead, so the Robux is never wasted. Returns (granted, reason).
function ProfileLogic.grantItemPurchase(p: any, receiptId: string, itemId: string, econ: any, ledgerSize: number): (boolean, string?)
	local item = econ.item(itemId)
	if type(receiptId) ~= "string" or receiptId == "" or not item then
		return false, "BAD_RECEIPT"
	end
	if not takeReceipt(p, receiptId, ledgerSize) then
		return false, "DUPLICATE"
	end
	if item.kind == "pet" and econ.grantPetPurchase then return econ.grantPetPurchase(p, item) end -- HOS-HWN-001 Halloween pets (HalloweenShop)
	if econ.isConsumable(item) then
		p.cosmetics.consumables[itemId] = (p.cosmetics.consumables[itemId] or 0) + 1
		if item.kind == "trail" then
			p.cosmetics.trailNext = itemId
		end
	elseif p.cosmetics.owned[itemId] then
		p.gems += if item.wallet == "gems" then item.price else 0
		return true, "OWNED_REFUNDED"
	else
		p.cosmetics.owned[itemId] = true
		if item.kind == "case" then
			p.cosmetics.case = itemId
		end
	end
	return true, nil
end

-- An Emote Crate opened with Robux: the emote is rolled by the caller (like openEmoteCrate, minus the Gems).
-- Returns (granted, resultOrReason); result = { emote, dupe, refund }.
function ProfileLogic.grantCratePurchase(p: any, receiptId: string, emoteId: string, emoteConfig: any, ledgerSize: number): (boolean, any)
	local e = emoteConfig.get(emoteId)
	if type(receiptId) ~= "string" or receiptId == "" or not e then
		return false, "BAD_RECEIPT"
	end
	if not takeReceipt(p, receiptId, ledgerSize) then
		return false, "DUPLICATE"
	end
	if type(p.emotes) ~= "table" then
		p.emotes = {}
	end
	local dupe = p.emotes[emoteId] == true
	local refund = 0
	if dupe then
		refund = emoteConfig.DUPE_REFUND[e.rarity] or 0
		p.gems += refund
	else
		p.emotes[emoteId] = true
	end
	return true, { emote = emoteId, dupe = dupe, refund = refund }
end

-- The G wheel: slots cleaned by EmoteConfig.cleanWheel (owned, no duplicates, 6 entries)
function ProfileLogic.setEmoteWheel(p: any, slots: any, emoteConfig: any): boolean
	p.emoteWheel = emoteConfig.cleanWheel(slots, p.emotes)
	return true
end

-- a newly won emote goes into the first empty wheel slot (if there is one)
function ProfileLogic.wheelAdd(p: any, emoteId: string, emoteConfig: any)
	local w = emoteConfig.cleanWheel(p.emoteWheel, p.emotes)
	for i = 1, #w do
		if w[i] == emoteId then
			p.emoteWheel = w
			return
		end
	end
	for i = 1, #w do
		if w[i] == "" then
			w[i] = emoteId
			break
		end
	end
	p.emoteWheel = w
end

-- Robux Gem packs: grant exactly once per receipt id (ProcessReceipt). Returns (granted, reason).
function ProfileLogic.grantPurchasedGems(p: any, receiptId: string, gems: number, ledgerSize: number): (boolean, string?)
	if type(receiptId) ~= "string" or receiptId == "" or type(gems) ~= "number" or gems <= 0 then
		return false, "BAD_RECEIPT"
	end
	for _, r in ipairs(p.receipts) do
		if r == receiptId then
			return false, "DUPLICATE"
		end
	end
	p.gems += math.floor(gems)
	p.stats.gemsPurchased += math.floor(gems)
	table.insert(p.receipts, receiptId)
	while #p.receipts > ledgerSize do
		table.remove(p.receipts, 1)
	end
	return true, nil
end

function ProfileLogic.setFlag(p: any, field: string, value: boolean): boolean
	if field ~= "afkPreference" and field ~= "volunteerPreference" then
		return false
	end
	p[field] = value == true
	return true
end

function ProfileLogic.setSettings(p: any, settings: any): boolean
	if type(settings) ~= "table" then
		return false
	end
	local s = p.settings
	for _, k in ipairs({ "sfx", "music", "reduceEffects", "showHints" }) do
		if type(settings[k]) == "boolean" then
			s[k] = settings[k]
		end
	end
	return true
end

-- The read-only view sent to the owning client.
function ProfileLogic.clientView(p: any, questConfig: any): any
	local quests = {}
	for _, id in ipairs(p.dailyQuests.active) do
		local q = questConfig.get(id)
		if q then
			table.insert(quests, {
				id = id,
				title = q.title,
				target = q.target,
				progress = num(p.dailyQuests.progress[id], 0),
				claimed = p.dailyQuests.claimed[id] == true,
				reward = q.reward,
			})
		end
	end
	return {
		gold = p.gold,
		gems = p.gems,
		xp = num(p.xp, 0),
		materials = deepCopy(p.materials),
		incubator = IncubatorLogic.view(p), -- HOS-EGG-002
		pets = deepCopy(p.pets),
		equippedPet = p.equippedPet,
		firstCommonFree = p.firstCommonFree,
		cosmetics = deepCopy(p.cosmetics),
		emotes = deepCopy(p.emotes),
		emoteWheel = deepCopy(p.emoteWheel),
		stats = deepCopy(p.stats),
		quests = quests,
		questDate = p.dailyQuests.utcDate,
		afk = p.afkPreference,
		volunteer = p.volunteerPreference,
		settings = deepCopy(p.settings),
	}
end

return ProfileLogic
