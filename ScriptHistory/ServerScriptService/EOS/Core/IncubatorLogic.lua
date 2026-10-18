--!strict
-- IncubatorLogic (HOS-EGG-002, 17 Oct 2026): the profile side of the egg plan, pure (no services, no yields; every
-- random draw is passed in so DataService can replay a change and get the same result). ProfileLogic hooks it in
-- one line each (migrate, applySettlement, clientView); EggService calls hatch / setFocus / claimFirstPet.
--   p.incubator = { fill, shards = { common, rare, epic, legendary }, focus = "Any" | family, hatched, firstWon,
--                   unseen = { rarity, ... } (HOS-INC-001: shards not yet watched flying into the lobby incubator) }
--   p.incubatorV1 = true once the old pieces were converted (they stay in p.materials, zeroed, for one release)
--   p.stats.secondsPlayed = match time from settlements (new players fill the meter faster: first EggConfig.CHARGE.NEWBIE_HOURS)
-- Families and species come from EconomyConfig (`econ`): a family can hatch a rarity when it is a launch family
-- with a species of that rarity. Legendary odds fold into Epic until such a species exists (Q1, 17 Oct).

local IncubatorLogic = {}

local EggLogic: any = nil
if script ~= nil then
	EggLogic = require(game:GetService("ReplicatedStorage"):WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("EggLogic"))
end

function IncubatorLogic.setEggLogic(m: any)
	EggLogic = m
end

-- the pet data the client view reads (EconomyConfig); tests inject a stub
local Econ: any = nil
if script ~= nil then
	Econ = require(game:GetService("ReplicatedStorage"):WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("EconomyConfig"))
end

function IncubatorLogic.setEcon(e: any)
	Econ = e
end

local function num(v: any): number
	return if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then v else 0
end

-- shards not yet seen at the lobby incubator (HOS-INC-001, 17 Oct, Matthew): each settled shard is also remembered in
-- p.incubator.unseen (rarity names, oldest first, at most UNSEEN_MAX) until the player walks up to the incubator and
-- watches it fly into the egg (EggService SeenShards -> markSeen). A hatch starts a new egg, so it forgets them.
-- Presentation only: fill, odds and hatches never read it.
local UNSEEN_MAX = 12

local function cleanUnseen(list: any): { string }
	local out = {}
	if type(list) == "table" then
		for _, r in ipairs(list) do
			if EggLogic.isRarity(r) then
				table.insert(out, r)
			end
		end
	end
	while #out > UNSEEN_MAX do
		table.remove(out, 1)
	end
	return out
end

-- creates / repairs p.incubator and p.stats.secondsPlayed. Returns true when it changed something.
function IncubatorLogic.ensure(p: any): boolean
	local changed = false
	if type(p.incubator) ~= "table" then
		p.incubator = EggLogic.newIncubator()
		changed = true
	end
	EggLogic.sanitize(p.incubator)
	if type(p.stats) == "table" and type(p.stats.secondsPlayed) ~= "number" then
		p.stats.secondsPlayed = 0
		changed = true
	end
	return changed
end

-- ProfileLogic.migrate's hook, only while the egg plan is on (EggConfig.ENABLED false = old pieces untouched):
-- the incubator field, and the old pieces -> fill once (incubatorV1)
function IncubatorLogic.migrate(p: any): boolean
	if not EggLogic.config().ENABLED then
		return false
	end
	local changed = IncubatorLogic.ensure(p)
	if p.incubatorV1 ~= true then
		if type(p.materials) == "table" then
			EggLogic.migratePieces(p.incubator, p.materials)
			for k in pairs(p.materials) do
				p.materials[k] = 0
			end
		end
		p.incubatorV1 = true
		changed = true
	end
	return changed
end

-- ===== which families can hatch what (from the pet data) =====

function IncubatorLogic.familyHas(econ: any, family: string, rarity: string): boolean
	if not table.find(econ.LAUNCH_FAMILIES, family) then
		return false
	end
	local f = econ.FAMILIES[family]
	local sp = f ~= nil and type(f.species) == "table" and f.species[rarity] -- a species, or a list of them (HOS-PET-REDO)
	return type(sp) == "string" or (type(sp) == "table" and #sp > 0)
end

-- families (EggConfig order) that have a pet of this rarity
function IncubatorLogic.openFamilies(econ: any, rarity: string): { string }
	local out = {}
	for _, fam in ipairs(EggLogic.config().FAMILIES) do
		if IncubatorLogic.familyHas(econ, fam, rarity) then
			table.insert(out, fam)
		end
	end
	return out
end

-- a family is pickable as a focus only when it has a pet at every rarity a hatch can roll without folding: Rare and
-- Epic (Legendary folds into Epic for a family without one). Otherwise its chip shows locked, "coming soon".
-- Read from the live pet data (17 Oct, focus rules 1-3).
function IncubatorLogic.focusOpen(econ: any, family: string): boolean
	if family == EggLogic.config().ANY then
		return true
	end
	return IncubatorLogic.familyHas(econ, family, "rare") and IncubatorLogic.familyHas(econ, family, "epic")
end

-- the rarity a hatch lands on in `family`: the rolled one, else the nearest one below that the family has (nil = none)
function IncubatorLogic.nearestDown(econ: any, family: string, rarity: string): string?
	for i = EggLogic.rarityIndex(rarity), 1, -1 do
		local r = EggLogic.rarityAt(i)
		if IncubatorLogic.familyHas(econ, family, r) then
			return r
		end
	end
	return nil
end

-- what a hatch gives for a rolled rarity, never failing while any family has a pet (focus rules 2 and 3):
-- focused: the focus family at the rolled rarity or the nearest below; a family with nothing falls back to Any and
-- the focus is refunded. Any: a family that has the rolled rarity, else the nearest rarity down that some family has.
-- Returns (family, rarity, refunded) or nil.
function IncubatorLogic.resolve(econ: any, focus: string, rarity: string, rFamily: number): (string?, string?, boolean)
	local C = EggLogic.config()
	if focus ~= C.ANY then
		local r = IncubatorLogic.nearestDown(econ, focus, rarity)
		if r then
			return focus, r, false
		end
	end
	for i = EggLogic.rarityIndex(rarity), 1, -1 do
		local r = EggLogic.rarityAt(i)
		local fam = EggLogic.pickFamily(C.ANY, IncubatorLogic.openFamilies(econ, r), rFamily)
		if fam then
			return fam, r, focus ~= C.ANY
		end
	end
	return nil, nil, false
end

-- Legendary is on the table for this focus (Any: any family has a Legendary pet)
function IncubatorLogic.legendaryOpen(econ: any, focus: string): boolean
	if focus == EggLogic.config().ANY then
		return #IncubatorLogic.openFamilies(econ, "legendary") > 0
	end
	return IncubatorLogic.familyHas(econ, focus, "legendary")
end

-- the odds the egg shows (and the hatch rolls)
function IncubatorLogic.odds(p: any, econ: any): any
	IncubatorLogic.ensure(p)
	return EggLogic.incubatorOdds(p.incubator, IncubatorLogic.legendaryOpen(econ, p.incubator.focus))
end

-- ===== settlement =====
-- s.shard = rarity or nil, s.seconds = match length. Runs inside applySettlement after its exact-once check.
-- Returns the shard actually added (nil = none).
function IncubatorLogic.applySettlement(p: any, s: any): string?
	IncubatorLogic.ensure(p)
	local secs = math.clamp(num(s.seconds), 0, 3600)
	p.stats.secondsPlayed = num(p.stats.secondsPlayed) + secs
	local shard = s.shard
	if not EggLogic.isRarity(shard) then
		return nil
	end
	EggLogic.addShard(p.incubator, shard)
	local unseen = cleanUnseen(p.incubator.unseen)
	table.insert(unseen, shard)
	p.incubator.unseen = cleanUnseen(unseen)
	p.incubator.firstWon = true
	return shard
end

-- the player watched their unseen shards fly into the egg (EggService SeenShards). (false, "NONE") = nothing to clear.
function IncubatorLogic.markSeen(p: any): (boolean, string?)
	IncubatorLogic.ensure(p)
	if #cleanUnseen(p.incubator.unseen) == 0 then
		return false, "NONE"
	end
	p.incubator.unseen = {}
	return true, nil
end

-- ===== focus =====
function IncubatorLogic.setFocus(p: any, focus: any, econ: any): (boolean, string?)
	IncubatorLogic.ensure(p)
	local C = EggLogic.config()
	if type(focus) ~= "string" or not (focus == C.ANY or table.find(C.FAMILIES, focus)) then
		return false, "BAD_FAMILY"
	end
	if not IncubatorLogic.focusOpen(econ, focus) then
		return false, "LOCKED"
	end
	if p.incubator.focus == focus then
		return false, "SAME"
	end
	p.incubator.focus = focus
	return true, nil
end

-- ===== pets =====
local function addPet(p: any, family: string, rarity: string, species: string): (any, boolean)
	local dup = false
	for _, q in ipairs(p.pets) do
		if q.species == species and q.rarity == rarity then
			dup = true
		end
	end
	local pet = { id = "p" .. tostring(p.nextPetId), family = family, rarity = rarity, species = species, n = p.nextPetId }
	p.nextPetId += 1
	table.insert(p.pets, pet)
	-- copies of the same species level the pet up (1..3, the mastery stars; Economy Decisions #19)
	local copies = {}
	for _, q in ipairs(p.pets) do
		if q.species == species and q.rarity == rarity then
			table.insert(copies, q)
		end
	end
	for _, q in ipairs(copies) do
		q.level = math.min(#copies, 3)
	end
	if p.equippedPet == "" then
		p.equippedPet = pet.id
	end
	p.stats.petsHatched = num(p.stats.petsHatched) + 1
	return pet, dup
end

-- Hatch the full egg. rolls = { rarity, family, species } each in [0, 1), lucky = owns the Lucky Egg pass (EggService's
-- cached check). Atomic: nothing changes on failure.
-- Returns (ok, reason, pet, info) with info = { rarity, family, focused, fillUsed, duplicate, odds }.
function IncubatorLogic.hatch(p: any, econ: any, rolls: any): (boolean, string?, any?, any?)
	IncubatorLogic.ensure(p)
	local inc = p.incubator
	if not EggLogic.isReady(inc) then
		return false, "NOT_READY", nil, nil
	end
	local odds = EggLogic.hatchOdds(inc, IncubatorLogic.legendaryOpen(econ, inc.focus), rolls.lucky == true) -- + the pass, boost, cap
	local rolled = EggLogic.hatchRoll(odds, num(rolls.rarity))
	local family, rarity, refunded = IncubatorLogic.resolve(econ, inc.focus, rolled, num(rolls.family))
	if not family or not rarity then
		return false, "NO_PET", nil, nil -- no family has any pet at all (never in a live game)
	end
	local owned = {}
	for _, q in ipairs(p.pets) do
		owned[q.species] = true
	end
	local list = econ.FAMILIES[family].species[rarity] -- several pets at one rarity: an even pick, unowned first
	local species = EggLogic.pickSpecies(if type(list) == "table" then list else { list }, owned, num(rolls.species))
	if not species then
		return false, "NO_PET", nil, nil
	end
	local focused = EggLogic.isFocused(inc)
	local fillAtHatch, boostTier = inc.fill, inc.boost -- overfill: the odds came from this (minus the focus cost); the hatch spends it all
	local cost = EggLogic.focusCost(inc)
	EggLogic.consumeHatch(inc)
	inc.unseen = {} -- a new egg: the old egg's unseen shards went into this pet (HOS-INC-001)
	local refund = 0
	if refunded then
		-- "Focus refunded": what the focus cost is credited to the next egg; the focus goes back to Any
		refund = cost
		EggLogic.addFill(inc, refund)
		inc.focus = EggLogic.config().ANY
	end
	local pet, dup = addPet(p, family, rarity, species)
	return true, nil, pet, { rarity = rarity, rolled = rolled, family = family, focused = focused, fillUsed = fillAtHatch - refund, fillAtHatch = fillAtHatch, duplicate = dup, odds = odds, lucky = rolls.lucky == true, boostTier = boostTier, focusRefunded = refunded, refund = refund }
end

-- a bought hatch boost tier (EggService's receipt handler, inside DataService.commit): idempotent by purchase id
function IncubatorLogic.grantBoost(p: any, tier: number, receipt: string): boolean
	IncubatorLogic.ensure(p)
	return EggLogic.grantBoost(p.incubator, tier, receipt, 50)
end

-- the first pet (Economy Decisions #15): once the player has won their first egg, a free Common of a family they
-- choose, outside the incubator
function IncubatorLogic.canClaimFirstPet(p: any): boolean
	IncubatorLogic.ensure(p)
	return p.firstCommonFree == true and p.incubator.firstWon == true
end

function IncubatorLogic.claimFirstPet(p: any, family: any, econ: any): (boolean, string?, any?)
	if not IncubatorLogic.canClaimFirstPet(p) then
		return false, if p.firstCommonFree == true then "NOT_YET" else "CLAIMED", nil
	end
	if type(family) ~= "string" or not IncubatorLogic.familyHas(econ, family, "common") then
		return false, "BAD_FAMILY", nil
	end
	p.firstCommonFree = false
	local common = econ.FAMILIES[family].species.common
	local pet = addPet(p, family, "common", if type(common) == "table" then common[1] else common)
	return true, nil, pet
end

-- ===== client view (read-only: never changes the profile) =====
function IncubatorLogic.view(p: any): any
	local copy: any = nil
	if type(p.incubator) == "table" then
		copy = table.clone(p.incubator)
		copy.shards = if type(copy.shards) == "table" then table.clone(copy.shards) else nil
	end
	local inc = EggLogic.sanitize(copy)
	local out: any = {
		fill = inc.fill,
		shards = table.clone(inc.shards),
		focus = inc.focus,
		hatched = inc.hatched,
		firstWon = inc.firstWon == true,
		secondsPlayed = num(type(p.stats) == "table" and p.stats.secondsPlayed),
		unseen = cleanUnseen(inc.unseen), -- HOS-INC-001: shards to fly into the lobby incubator's egg
	}
	if Econ then -- what the screen shows, computed here so it is exactly what the server rolls
		local C = EggLogic.config()
		out.need = EggLogic.fillNeeded(inc)
		out.ready = EggLogic.isReady(inc)
		out.full = C.INCUBATOR.FILL -- 100% (the ring's marks: 100 / 150 / 200%)
		out.cap = EggLogic.fillCap()
		out.focusCost = EggLogic.focusCost(inc)
		out.oddsLevel = EggLogic.oddsLevel(inc) -- the share of FILL the odds read from (1 = 100%)
		out.carry = inc.carry
		out.legendaryOpen = IncubatorLogic.legendaryOpen(Econ, inc.focus)
		out.odds = EggLogic.hatchOdds(inc, out.legendaryOpen, false) -- the screen adds the Lucky Egg pass (EOS_LuckyEgg)
		out.boost = inc.boost -- the hatch boost tier bought for this egg
		out.focusOpen = {}
		for _, fam in ipairs(C.FAMILIES) do
			out.focusOpen[fam] = IncubatorLogic.focusOpen(Econ, fam)
		end
		out.firstPetFamilies = IncubatorLogic.openFamilies(Econ, "common")
		out.firstPetClaimable = p.firstCommonFree == true and inc.firstWon == true
	end
	return out
end

return IncubatorLogic
