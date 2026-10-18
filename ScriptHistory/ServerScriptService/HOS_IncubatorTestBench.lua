--!nocheck
-- HOS_IncubatorTestBench (HOS-INC-001, 17 Oct 2026, Matthew): a quick Studio test of the lobby incubator. Does nothing
-- outside Studio (and Studio profiles live in their own datastore, so nothing here touches real players).
-- When you press Play: your egg is emptied, the shards in the Shards attribute are given to you as unseen fragments,
-- and you're put 17 studs in front of the incubator, facing it. Walk up: the fragments fly in and snap into the egg,
-- and the incubator screen opens.
-- Chat commands (Studio only):
--   !shards                give the Shards attribute's list again
--   !shards epic legendary give those rarities (common, rare, epic, legendary)
--   !shards 5              give 5 random fragments
--   !full                  give fragments until the egg is ready to hatch
--   !reset                 empty the egg
--   !tp                    back in front of the incubator
-- Attributes on this script: Enabled (turn the whole bench off), Shards (comma list for Play and !shards),
-- ResetOnPlay (empty the egg when you join).
-- Fragments fly in when you walk up to the incubator, or straight away if you are already standing at it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

if not RunService:IsStudio() then return end
if script:GetAttribute("Enabled") == nil then script:SetAttribute("Enabled", true) end
if script:GetAttribute("Shards") == nil then script:SetAttribute("Shards", "common,rare,rare,epic,legendary") end
if script:GetAttribute("ResetOnPlay") == nil then script:SetAttribute("ResetOnPlay", true) end
if not script:GetAttribute("Enabled") then return end

local DataService = require(ServerScriptService.EOS.Services.DataService)
local IncubatorLogic = require(ServerScriptService.EOS.Core.IncubatorLogic)
local EggConfig = require(game:GetService("ReplicatedStorage").EOS.Shared.EggConfig)

local RARITIES = { "common", "rare", "epic", "legendary" }
local FRONT = 17 -- studs in front of the egg (outside the walk-up radius, so walking in plays the fly-in)

local function loaded(plr: Player): boolean
	for _ = 1, 60 do
		if not plr.Parent then return false end
		if DataService.get(plr) then return true end
		task.wait(0.25)
	end
	return false
end

-- the spot in front of the incubator (on the side its sign faces), on the ground, looking at the egg
local function frontOf(): CFrame?
	local inc = workspace:FindFirstChild("Incubator")
	local m = inc and inc:FindFirstChild("Incubator")
	local centre = m and m:FindFirstChild("A09_EggCentre")
	if not centre then return nil end
	local E = centre.Position
	local sign = m:FindFirstChild("A09_Sign")
	local dir = Vector3.xAxis
	if sign then
		local d = sign:GetPivot().Position - E
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude > 0.1 then dir = d.Unit end
	end
	local spot = E + dir * FRONT
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local chars = {}
	for _, p in Players:GetPlayers() do
		if p.Character then table.insert(chars, p.Character) end
	end
	params.FilterDescendantsInstances = chars
	local hit = workspace:Raycast(spot + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), params)
	local y = if hit then hit.Position.Y + 3 else E.Y
	local at = Vector3.new(spot.X, y, spot.Z)
	return CFrame.lookAt(at, Vector3.new(E.X, y, E.Z))
end

local function teleport(plr: Player)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cf = frontOf()
	if hrp and cf then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = cf
		plr:SetAttribute("HOS_TestBenchAt", os.clock()) -- HOS_IncubatorTestBenchCamera turns the camera to the egg
	end
end

local function reset(plr: Player)
	DataService.update(plr, "hosIncTestReset", function(p)
		IncubatorLogic.ensure(p)
		local inc = p.incubator
		inc.fill = 0
		if type(inc.shards) == "table" then
			for r in inc.shards do inc.shards[r] = 0 end
		end
		inc.unseen = {}
		inc.focus = "Any"
		p.firstCommonFree = false -- the normal incubator screen, not the first free pet
	end)
end

local function give(plr: Player, list: { string })
	DataService.update(plr, "hosIncTestShards", function(p)
		IncubatorLogic.ensure(p)
		for _, r in list do
			IncubatorLogic.applySettlement(p, { shard = r, seconds = 60 })
		end
	end)
end

local function parse(words: { string }): { string }
	local out = {}
	local n = tonumber(words[1])
	if n then
		for _ = 1, math.clamp(math.floor(n), 1, 30) do
			table.insert(out, RARITIES[math.random(1, #RARITIES)])
		end
		return out
	end
	for _, w in words do
		w = string.lower(w)
		if table.find(RARITIES, w) then table.insert(out, w) end
	end
	return out
end

local function defaultList(): { string }
	return parse(string.split(string.gsub(tostring(script:GetAttribute("Shards") or ""), "%s", ""), ","))
end

local function fill(plr: Player)
	local list = {}
	DataService.update(plr, "hosIncTestFull", function(p)
		table.clear(list) -- update can run this more than once
		IncubatorLogic.ensure(p)
		local v = IncubatorLogic.view(p)
		local missing = (v.need or 18) - (v.fill or 0)
		for _, r in { "legendary", "epic", "rare", "common" } do -- biggest first, then top up
			local w = EggConfig.SHARD_WEIGHT[r] or 1
			local cap = if r == "legendary" then 1 elseif r == "epic" then 3 else 40 -- a mix for the fly-in
			local n = 0
			while missing >= w - 1e-9 and n < cap and #list < 40 do
				table.insert(list, r)
				missing -= w
				n += 1
			end
		end
		while missing > 1e-9 and #list < 40 do -- a last half-fill
			table.insert(list, "common")
			missing -= EggConfig.SHARD_WEIGHT.common or 0.5
		end
		for _, r in list do
			IncubatorLogic.applySettlement(p, { shard = r, seconds = 60 })
		end
	end)
	return list
end

local function onChat(plr: Player, msg: string)
	local words = string.split(msg, " ")
	local cmd = string.lower(table.remove(words, 1) or "")
	if cmd == "!shards" then
		local list = if #words > 0 then parse(words) else defaultList()
		give(plr, list)
		print(("[IncubatorTestBench] gave %s: %s (they fly in at the incubator)"):format(plr.Name, table.concat(list, ", ")))
	elseif cmd == "!full" then
		local list = fill(plr)
		print(("[IncubatorTestBench] %s's egg filled with %s"):format(plr.Name, table.concat(list, ", ")))
	elseif cmd == "!reset" then
		reset(plr)
		print("[IncubatorTestBench] egg emptied for " .. plr.Name)
	elseif cmd == "!tp" then
		teleport(plr)
	end
end

local function setup(plr: Player)
	plr.Chatted:Connect(function(msg) onChat(plr, msg) end)
	if not loaded(plr) then return end
	if script:GetAttribute("ResetOnPlay") then reset(plr) end
	local list = defaultList()
	give(plr, list)
	local char = plr.Character or plr.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart", 10)
	task.wait(1) -- after the lobby has placed the character
	teleport(plr)
	print(("[IncubatorTestBench] %s is in front of the incubator with %s to fly in. Chat: !shards, !shards 5, !full, !reset, !tp"):format(plr.Name, table.concat(list, ", ")))
end

Players.PlayerAdded:Connect(function(plr) task.spawn(setup, plr) end)
for _, plr in Players:GetPlayers() do task.spawn(setup, plr) end
