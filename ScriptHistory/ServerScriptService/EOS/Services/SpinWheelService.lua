--!strict
-- SpinWheelService (HOS-SPIN-001, 18 Oct 2026, Matthew): the lobby spin wheel (Workspace.SpinWheel). The server owns
-- the spins and rolls every result; the client (SpinWheelController) only shows them.
--  * one free spin, then another SpinWheelConfig.FREE_SECONDS after it is used
--  * spins bought with Robux (SpinWheelConfig.PACKS) are kept in the profile until used
--  * a spin of 1, 5 or 10 uses the free spin first, then bought spins; every result is paid in one save, which is
--    ledger-guarded by a spin id so a retried save never pays twice
--  * everyone in the lobby sees the big wheel turn to the result (Spun)
--
-- profile.spinWheel = { spins = n, freeAt = unix (0 = ready), total = n, done = { spinId } (last 20),
--                       receipts = { purchaseId } (last 50) }
-- Remotes: ReplicatedStorage.EOS_SpinWheel { State (server -> client), Ask (client -> server), Spin (RemoteFunction),
--          Spun (server -> all clients: userId, slot) }

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local C = require(Shared:WaitForChild("SpinWheelConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local EggLogic = require(Shared:WaitForChild("EggLogic"))
local IncubatorLogic = require(ServerScriptService.EOS.Core.IncubatorLogic)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

local SpinWheelService = {}

local DONE_MAX, RECEIPTS_MAX, UNSEEN_MAX = 20, 50, 12

local remotes: Folder
local stateEvent: RemoteEvent
local spunEvent: RemoteEvent
local busyUntil: { [Player]: number } = {}
local lastSent: { [Player]: string } = {}
local rng = Random.new()

local function num(v: any): number
	return if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then v else 0
end

local function rec(p: any): any
	local s = p.spinWheel
	if type(s) ~= "table" then
		s = {}
		p.spinWheel = s
	end
	s.spins = math.max(0, math.floor(num(s.spins)))
	s.freeAt = num(s.freeAt)
	if type(s.done) ~= "table" then s.done = {} end
	if type(s.receipts) ~= "table" then s.receipts = {} end
	return s
end

local function remember(list: { string }, id: string, max: number)
	table.insert(list, id)
	while #list > max do table.remove(list, 1) end
end

local function view(p: any): any
	local s = p.spinWheel or {}
	local now = os.time()
	return {
		spins = math.max(0, math.floor(num(s.spins))),
		freeAt = num(s.freeAt),
		freeReady = num(s.freeAt) <= now,
		serverNow = now,
	}
end

local function send(plr: Player, force: boolean?)
	local p = DataService.get(plr)
	if not p then return end
	local v = view(p)
	local key = v.spins .. "|" .. v.freeAt .. "|" .. tostring(v.freeReady)
	if not force and lastSent[plr] == key then return end
	lastSent[plr] = key
	stateEvent:FireClient(plr, v)
end

-- one slot's reward into a profile (runs inside the guarded transform). Returns what was given, for the client.
local function grant(p: any, i: number): any
	local s = C.SLOTS[i]
	local kind, amount = s.kind, num(s.amount)
	if kind == "weapon" then
		local item = s.weaponId and EconomyConfig.item(s.weaponId)
		if item and item.kind == "knifeSkin" then
			if p.cosmetics.owned[s.weaponId] then -- a duplicate: Weapon Shards, like a crate
				local shards = (EconomyConfig.KNIFE_CRATE.shards or {})[item.rarity] or 0
				p.weaponShards = num(p.weaponShards) + shards
				return { kind = "weapon", itemId = s.weaponId, dupe = true, shards = shards }
			end
			p.cosmetics.owned[s.weaponId] = true
			p.cosmetics.knifeSkin = s.weaponId
			return { kind = "weapon", itemId = s.weaponId }
		end
		kind, amount = "gold", num(s.fallbackGold) -- placeholder weapon: Gold until it is picked
	end
	p.stats = p.stats or {}
	if kind == "gold" then
		p.gold = num(p.gold) + amount
		p.stats.goldEarned = num(p.stats.goldEarned) + amount
	elseif kind == "gems" then
		p.gems = num(p.gems) + amount
		p.stats.gemsEarned = num(p.stats.gemsEarned) + amount
	elseif kind == "shard" and EggLogic.isRarity(s.rarity) then
		IncubatorLogic.ensure(p)
		EggLogic.addShard(p.incubator, s.rarity)
		-- it flies into the lobby incubator's egg next time they walk up, like a match shard (HOS-INC-001)
		local unseen = if type(p.incubator.unseen) == "table" then p.incubator.unseen else {}
		table.insert(unseen, s.rarity)
		while #unseen > UNSEEN_MAX do table.remove(unseen, 1) end
		p.incubator.unseen = unseen
		return { kind = "shard", rarity = s.rarity }
	end
	return { kind = kind, amount = amount }
end

local function spin(plr: Player, count: any): any
	count = tonumber(count)
	if not count or not table.find(C.MULTI, count) then return { ok = false, reason = "bad" } end
	local now = os.clock()
	if busyUntil[plr] and now < busyUntil[plr] then return { ok = false, reason = "busy" } end
	if plr:GetAttribute("EOS_InMatch") == true then return { ok = false, reason = "match" } end
	local live = DataService.get(plr)
	if not live then return { ok = false, reason = "loading" } end
	local sw = rec(live)
	local t = os.time()
	local useFree = sw.freeAt <= t
	local paid = count - (if useFree then 1 else 0)
	if sw.spins < paid then
		send(plr, true)
		return { ok = false, reason = "no_spins", state = view(live) }
	end
	busyUntil[plr] = now + C.SPIN_TIME
	-- rolled before the transform: a retried save re-runs it, so it must not roll again
	local slots = {}
	for _ = 1, count do table.insert(slots, C.roll(rng:NextNumber())) end
	local id = HttpService:GenerateGUID(false)
	local gave = {}
	local weapon = false
	DataService.update(plr, "spin_wheel", function(p)
		local s = rec(p)
		if table.find(s.done, id) then return end
		remember(s.done, id, DONE_MAX)
		if useFree then s.freeAt = t + C.FREE_SECONDS end
		s.spins = math.max(0, s.spins - paid)
		s.total = num(s.total) + count
		local out = {}
		for _, i in slots do
			local g = grant(p, i)
			if g.kind == "weapon" then weapon = true end
			table.insert(out, g)
		end
		gave = out
	end)
	if weapon then
		local CharacterService = require(script.Parent.CharacterService) :: any
		CharacterService.refreshKnife(plr)
		task.defer(require(script.Parent.WeaponExtras).checkSets, plr)
	end
	local best = C.best(slots)
	spunEvent:FireAllClients(plr.UserId, best)
	Analytics.log("SpinWheel", { userId = plr.UserId, count = count, free = useFree, slots = table.concat(slots, ","), best = best })
	send(plr, true)
	return { ok = true, slots = slots, best = best, gave = gave, state = view(DataService.get(plr) or live) }
end

-- Robux spin packs: granted only after the save, exact-once by the pack's own receipt ledger. nil = not ours.
function SpinWheelService.processReceipt(info: any, plr: Player): Enum.ProductPurchaseDecision?
	local pack = nil
	for _, k in C.PACKS do
		if k.productId and k.productId == info.ProductId then pack = k end
	end
	if not pack then return nil end
	local receipt = tostring(info.PurchaseId)
	local granted = false
	if not DataService.commit(plr, "receipt:" .. receipt, function(p)
		local s = rec(p)
		if table.find(s.receipts, receipt) then return end
		remember(s.receipts, receipt, RECEIPTS_MAX)
		s.spins += pack.spins
		granted = true
	end) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if granted then
		Analytics.log("SpinWheelPack", { userId = plr.UserId, spins = pack.spins, robux = info.CurrencySpent, purchaseId = receipt })
	end
	send(plr, true)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function SpinWheelService.init()
	local old = ReplicatedStorage:FindFirstChild("EOS_SpinWheel")
	if old then old:Destroy() end
	remotes = Instance.new("Folder")
	remotes.Name = "EOS_SpinWheel"
	stateEvent = Instance.new("RemoteEvent")
	stateEvent.Name = "State"
	stateEvent.Parent = remotes
	local ask = Instance.new("RemoteEvent")
	ask.Name = "Ask"
	ask.Parent = remotes
	local spinFn = Instance.new("RemoteFunction")
	spinFn.Name = "Spin"
	spinFn.Parent = remotes
	spunEvent = Instance.new("RemoteEvent")
	spunEvent.Name = "Spun"
	spunEvent.Parent = remotes
	remotes.Parent = ReplicatedStorage

	spinFn.OnServerInvoke = spin
	ask.OnServerEvent:Connect(function(plr) send(plr, true) end)
	stateEvent.OnServerEvent:Connect(function() end)
	spunEvent.OnServerEvent:Connect(function() end)

	DataService.Loaded:Connect(function(plr) send(plr, true) end)
	DataService.Changed:Connect(function(plr) send(plr) end)
	Players.PlayerRemoving:Connect(function(plr)
		busyUntil[plr] = nil
		lastSent[plr] = nil
	end)
	-- the free spin turns ready while they're on
	task.spawn(function()
		while true do
			task.wait(5)
			for _, plr in Players:GetPlayers() do send(plr) end
		end
	end)
end

return SpinWheelService
