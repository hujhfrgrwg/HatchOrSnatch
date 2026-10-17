-- RealPlayerPool (HOS-BOT-001): believable NPCs, the same for everyone in the server.
-- STATS ONLY come from real players: everyone who leaves is recorded ({ lv = level, pf/ps/pr/pl =
-- equipped pet family/species/rarity/level, w = wins, t = time; u = UserId, kept only to dedupe and
-- never handed out }) in DataStore "HOS_PlayerPool", key "recent_v1": newest first, one entry per
-- player, at most Npc.POOL_CAP. Writes are batched: at most one UpdateAsync per
-- Npc.POOL_WRITE_INTERVAL seconds per server (plus one on shutdown).
-- Names and looks are made up: a generated Roblox-style username (from generic word lists, never
-- from a real name) and an outfit of free Roblox-made catalog items (hair, maybe a hat, shirt,
-- pants, skin tone; CURATED below + shirts/pants from a catalog search). No NPC carries a real player's name, UserId or avatar.
-- NPC slot n gets one identity and keeps it for the server's life, so the lobby NPC and the match
-- NPC in that slot are the same "person" on the overhead tag, the feeds and the boards.
-- Studio with the memory-only DataService: Npc.POOL_STUDIO_SEED makes up a few stat records so
-- previews work. Nothing is written from Studio.

local AvatarEditorService = game:GetService("AvatarEditorService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local N = GameConfig.Npc
local STORE_NAME = "HOS_PlayerPool"
local KEY = "recent_v1"

local RealPlayerPool = {}

export type Look = { skin: Color3, shirt: number?, pants: number?, hair: number?, hat: number? }
export type Identity = {
	key: number, -- opaque, unique per identity (client skins compare it)
	name: string,
	level: number,
	petFamily: string,
	petSpecies: string,
	petRarity: string,
	petLevel: number,
	wins: number,
	look: Look,
}

local rng = Random.new()
local stats: { any } = {} -- recorded stat lines not yet given to a slot (shuffled)
local bySlot: { [number]: Identity } = {}
local usedNames: { [string]: boolean } = {}
local pending: { [number]: any } = {} -- UserId -> record waiting for the next write
local catalog: { [string]: { number } } = { hair = {}, hat = {}, shirt = {}, pants = {} }
local serial = 0
local started = false
local ready = false
local store: DataStore? = nil

-- ===== made-up names =====

local ADJ = {
	"Sneaky", "Fuzzy", "Lazy", "Crispy", "Silent", "Turbo", "Happy", "Sleepy", "Spicy", "Frosty",
	"Wobbly", "Cosmic", "Tiny", "Mega", "Shadow", "Golden", "Lucky", "Rapid", "Fluffy", "Salty",
	"Bouncy", "Electric", "Crazy", "Chill", "Super", "Pixel", "Sunny", "Stormy", "Neon", "Cheesy",
}
local NOUN = {
	"Panda", "Taco", "Noodle", "Fox", "Bagel", "Llama", "Otter", "Ninja", "Pickle", "Waffle",
	"Gecko", "Raccoon", "Muffin", "Shark", "Penguin", "Nugget", "Dragon", "Bean", "Kiwi", "Cookie",
	"Moose", "Toast", "Hamster", "Comet", "Pancake", "Frog", "Tiger", "Potato", "Wizard", "Duck",
}
local TAIL = { "_YT", "TV", "_x", "Gamer", "Pro", "_RBLX", "Plays", "" }

local function pick(t: { any }): any
	return t[rng:NextInteger(1, #t)]
end

local function digits(): string
	local r = rng:NextInteger(1, 4)
	return if r == 1 then tostring(rng:NextInteger(1, 99)) elseif r == 2 then tostring(rng:NextInteger(100, 9999)) elseif r == 3 then tostring(rng:NextInteger(2008, 2016)) else ""
end

local function makeName(): string
	local a, n = pick(ADJ), pick(NOUN)
	local s = rng:NextInteger(1, 7)
	if s == 1 then
		return a .. n .. digits()
	elseif s == 2 then
		return string.lower(a) .. "_" .. string.lower(n) .. digits()
	elseif s == 3 then
		return "xX" .. a .. n .. "Xx"
	elseif s == 4 then
		return n .. pick(NOUN) .. rng:NextInteger(1, 999)
	elseif s == 5 then
		return string.lower(n) .. pick(TAIL) .. digits()
	elseif s == 6 then
		return a .. "_" .. n .. pick(TAIL)
	end
	return "the" .. n .. a .. rng:NextInteger(1, 99)
end

-- a fresh name: not used by another NPC here and not anyone's name in this server
local function freshName(): string
	for _ = 1, 50 do
		local name = makeName()
		local low = string.lower(name)
		local clash = usedNames[low] or #name > 20
		for _, p in ipairs(Players:GetPlayers()) do
			if string.lower(p.Name) == low or string.lower(p.DisplayName) == low then
				clash = true
			end
		end
		if not clash then
			usedNames[low] = true
			return name
		end
	end
	return "Player" .. rng:NextInteger(10000, 99999)
end

-- ===== made-up looks (free Roblox-made catalog items) =====

local SKINS = {
	Color3.fromRGB(255, 205, 160), Color3.fromRGB(234, 184, 146), Color3.fromRGB(204, 142, 105),
	Color3.fromRGB(160, 110, 80), Color3.fromRGB(124, 92, 70), Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(90, 66, 52), Color3.fromRGB(245, 200, 170),
}

-- free Roblox-made items checked to load onto the R6 body (17 Oct). The catalog search's hair and
-- hats are mostly newer layered/mesh items that come back EMPTY on R6, so those two use only this list;
-- shirts and pants (classic clothing, always fine) start from it and add whatever the search finds.
local CURATED = {
	hair = { 1103003368, 451221329, 2956239660, 63690008, 451220849, 3814474927, 376524487, 376526888, 3814476174, 1772336109 },
	hat = { 417457461, 607702162, 2646473721, 607700713, 617605556, 48474313, 3403874988, 4047554959, 4324158403, 4489239608 },
	shirt = { 607785314, 3670737444, 398633584, 144076358, 382538059 },
	pants = { 398633812, 398635338, 398634487, 144076760, 382538503 },
}

local function loadCatalog()
	for kind, ids in pairs(CURATED) do
		catalog[kind] = table.clone(ids)
	end
	local kinds = {
		shirt = Enum.AvatarAssetType.Shirt,
		pants = Enum.AvatarAssetType.Pants,
	}
	for kind, assetType in pairs(kinds) do
		local ok, pages = pcall(function()
			local p = CatalogSearchParams.new()
			p.AssetTypes = { assetType }
			p.MinPrice, p.MaxPrice = 0, 0
			p.CreatorName = "Roblox"
			return AvatarEditorService:SearchCatalog(p)
		end)
		if ok and pages then
			for _, item in ipairs(pages:GetCurrentPage()) do
				if type(item.Id) == "number" and not table.find(catalog[kind], item.Id) then
					table.insert(catalog[kind], item.Id)
				end
			end
		else
			warn("[EOS] RealPlayerPool: catalog search failed (" .. kind .. "): " .. tostring(pages))
		end
	end
end

local function makeLook(): Look
	local function maybe(kind: string, chance: number): number?
		local list = catalog[kind]
		return if #list > 0 and rng:NextNumber() < chance then pick(list) else nil
	end
	return {
		skin = pick(SKINS),
		shirt = maybe("shirt", 1),
		pants = maybe("pants", 1),
		hair = maybe("hair", 0.85),
		hat = maybe("hat", 0.3),
	}
end

-- the outfit as a HumanoidDescription (NpcSkinService builds the R6 model from it)
function RealPlayerPool.description(id: Identity): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local L = id.look
	d.HeadColor, d.TorsoColor, d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor = L.skin, L.skin, L.skin, L.skin, L.skin, L.skin
	d.Shirt = L.shirt or 0
	d.Pants = L.pants or 0
	d.HairAccessory = if L.hair then tostring(L.hair) else ""
	d.HatAccessory = if L.hat then tostring(L.hat) else ""
	return d
end

-- ===== stats =====

local function randomStats(): any
	local sp = pick({ "", "", "Crow", "Kitsune", "Hare", "Toad" })
	return { lv = rng:NextInteger(1, 18), pf = "", ps = sp, pr = if sp == "" then "" else "Common", pl = if sp == "" then 1 else rng:NextInteger(1, 2), w = rng:NextInteger(0, 12) }
end

local function makeIdentity(): Identity
	local r = if #stats > 0 then table.remove(stats, 1) else randomStats()
	serial += 1
	return {
		key = -serial, -- opaque; never a real UserId (negative)
		name = freshName(),
		level = math.max(1, math.floor(tonumber(r.lv) or 1)),
		petFamily = tostring(r.pf or ""),
		petSpecies = tostring(r.ps or ""),
		petRarity = tostring(r.pr or ""),
		petLevel = math.clamp(math.floor(tonumber(r.pl) or 1), 1, 3),
		wins = math.max(0, math.floor(tonumber(r.w) or 0)),
		look = makeLook(),
	}
end

local function useStore(): boolean
	if not RunService:IsStudio() then
		return true
	end
	-- Studio: only when DataService is on the Studio test store too (workspace UseDataStore = true)
	local ok, DataService = pcall(require, script.Parent.DataService)
	return ok and DataService.mode == "datastore"
end

local function load()
	loadCatalog()
	if useStore() then
		local ok, ds = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			store = ds
			local got, data = pcall(function()
				return ds:GetAsync(KEY)
			end)
			if got and type(data) == "table" then
				for _, r in ipairs(data) do
					if type(r) == "table" then
						table.insert(stats, { lv = r.lv, pf = r.pf, ps = r.ps, pr = r.pr, pl = r.pl, w = r.w }) -- no UserId past here
					end
				end
			elseif not got then
				warn("[EOS] RealPlayerPool: read failed: " .. tostring(data))
			end
		end
	elseif N.POOL_STUDIO_SEED then
		for _ = 1, 12 do
			table.insert(stats, randomStats())
		end
	end
	for i = #stats, 2, -1 do
		local j = rng:NextInteger(1, i)
		stats[i], stats[j] = stats[j], stats[i]
	end
	ready = true
	local looks = #catalog.shirt + #catalog.pants + #catalog.hair + #catalog.hat
	print(("[EOS] RealPlayerPool: %d stat lines (%s), %d catalog items"):format(#stats, if store then "DataStore" else "Studio seed", looks))
end

-- ===== recording =====

local function record(plr: Player)
	if plr.UserId <= 0 then
		return
	end
	pending[plr.UserId] = {
		u = plr.UserId,
		lv = tonumber(plr:GetAttribute("EOS_Level")) or 1,
		pf = plr:GetAttribute("EOS_PetFamily") or "",
		ps = plr:GetAttribute("EOS_PetSpecies") or "",
		pr = plr:GetAttribute("EOS_PetRarity") or "",
		pl = tonumber(plr:GetAttribute("EOS_PetLevel")) or 1,
		w = tonumber(plr:GetAttribute("EOS_Wins")) or 0,
		t = os.time(),
	}
end

local function flush()
	if not store or next(pending) == nil then
		return
	end
	local batch = pending
	pending = {}
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(KEY, function(old)
			local merged, seen, fresh = {}, {}, {}
			for _, r in pairs(batch) do
				table.insert(fresh, r)
			end
			table.sort(fresh, function(a, b)
				return a.t > b.t
			end)
			for _, r in ipairs(fresh) do
				seen[r.u] = true
				table.insert(merged, r)
			end
			if type(old) == "table" then
				for _, r in ipairs(old) do
					if #merged >= N.POOL_CAP then
						break
					end
					if type(r) == "table" and type(r.u) == "number" and not seen[r.u] then
						seen[r.u] = true
						table.insert(merged, r)
					end
				end
			end
			while #merged > N.POOL_CAP do
				table.remove(merged)
			end
			return merged
		end)
	end)
	if not ok then
		warn("[EOS] RealPlayerPool: write failed, retrying next round: " .. tostring(err))
		for uid, r in pairs(batch) do
			if not pending[uid] then
				pending[uid] = r
			end
		end
	end
end

-- ===== API =====

-- the identity slot `slot` shows (made the first time it's asked for; kept for the server's life)
function RealPlayerPool.forSlot(slot: number): Identity
	if started and not ready then
		-- server just started: give the stats and catalog a moment to load
		local deadline = os.clock() + 10
		while not ready and os.clock() < deadline do
			task.wait(0.2)
		end
	end
	local id = bySlot[slot]
	if not id then
		id = makeIdentity()
		bySlot[slot] = id
	end
	return id
end

-- a bot takes slot `slot`: its identity
function RealPlayerPool.take(slot: number): Identity
	return RealPlayerPool.forSlot(slot)
end

-- the bot in this slot is gone (the identity stays with the slot for the next bot there)
function RealPlayerPool.release(_slot: number) end

-- identities for slots 1..n
function RealPlayerPool.list(n: number): { Identity }
	local out = {}
	for i = 1, n do
		out[i] = RealPlayerPool.forSlot(i)
	end
	return out
end

function RealPlayerPool.isReady(): boolean
	return ready
end

function RealPlayerPool.init()
	if started or not N.REAL_POOL then
		return
	end
	started = true
	task.spawn(load)
	local ok, DataService = pcall(require, script.Parent.DataService)
	if ok and DataService.onLeaving then
		DataService.onLeaving(record)
	else
		Players.PlayerRemoving:Connect(record)
	end
	task.spawn(function()
		while true do
			task.wait(N.POOL_WRITE_INTERVAL)
			flush()
		end
	end)
	game:BindToClose(function()
		task.wait(1) -- let DataService's leave hooks run first
		flush()
	end)
end

return RealPlayerPool
