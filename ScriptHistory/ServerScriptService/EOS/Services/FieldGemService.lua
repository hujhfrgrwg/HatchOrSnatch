--!strict
-- FieldGemService (HOS-GEMS-002, 17 Oct): Gems lying on the field during crossings, after the reference
-- game Hunter showed ("spawns gems on the map, more as it gets into the later rounds but a modest amount").
--  * Each crossing drops a few Gems on open field away from the safe zones and the Catcher line, a few
--    more each crossing (GameConfig.FieldGems.PER_CROSSING); scaled down for matches with few real players
--  * A Runner who isn't safe yet picks one up by walking into it (server distance check, 10 Hz)
--  * Picked-up Gems are banked in the match (MatchLogic:addFieldGem) and paid with the match's other
--    Gems at settlement, inside EconomyConfig.GEMS.CAP. Practice matches never save, same as any reward.
--  * Gems left on the field vanish when the crossing ends
-- The look (spin, sparkle, pickup burst, sound, "+1") is client-side: Controllers/FieldGems.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Layout = require(Shared:WaitForChild("Layout"))
local Net = require(Shared:WaitForChild("Net"))
local Analytics = require(script.Parent.Analytics)
local CharacterService = require(script.Parent.CharacterService)
local MatchService = require(script.Parent.MatchService)
local NpcService = require(script.Parent.NpcService)

local FG = GameConfig.FieldGems
local TAG = "EOS_FieldGem"

local FieldGemService = {}

type Gem = { id: string, part: BasePart, pos: Vector3 }
local live: { Gem } = {}
local rng = Random.new()
local loopToken = 0

local function folder(): Folder
	local f = workspace:FindFirstChild("EOS_FieldGems")
	if not f then
		f = Instance.new("Folder")
		f.Name = "EOS_FieldGems"
		f.Parent = workspace
	end
	return f :: Folder
end

local function clearAll()
	loopToken += 1
	for _, g in ipairs(live) do
		g.part:Destroy()
	end
	table.clear(live)
end

-- how many Gems this crossing: the per-crossing table (last entry repeats), scaled by real players
local function countFor(c: any, wave: number): number
	local list = FG.PER_CROSSING
	local base = list[math.clamp(wave, 1, #list)]
	local real = 0
	for _, plr in pairs(c.roster) do
		if not NpcService.isBot(plr) then
			real += 1
		end
	end
	local share = math.min(1, real / FG.FULL_AT_PLAYERS)
	return math.clamp(math.floor(base * share + 0.5), 1, base)
end

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.RespectCanCollide = true
local down = RaycastParams.new()
down.FilterType = Enum.RaycastFilterType.Exclude

local function excludes(): { Instance }
	local out: { Instance } = { folder() }
	local runtime = workspace:FindFirstChild("EOS_Runtime")
	if runtime then
		table.insert(out, runtime)
	end
	for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
		if plr.Character then
			table.insert(out, plr.Character)
		end
	end
	for _, g in ipairs(CollectionService:GetTagged("EOS_Gate")) do
		table.insert(out, g)
	end
	return out
end

-- a random open spot on the field: off the safe zones, off the Catcher line, clear of walls and other Gems
local function pickSpot(taken: { Vector3 }): Vector3?
	local A = Layout.Arena
	local c = A.CENTER
	local maxX = A.FIELD_HALF_X - FG.ZONE_INSET
	local maxZ = A.HALF_Z - FG.EDGE_INSET
	if maxX <= FG.CENTER_GAP then
		return nil
	end
	local ex = excludes()
	for _ = 1, 40 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x = c.X + side * rng:NextNumber(FG.CENTER_GAP, maxX)
		local z = c.Z + rng:NextNumber(-maxZ, maxZ)
		local probe = Vector3.new(x, Layout.GROUND_Y + 3, z)
		local ok = true
		for _, p in ipairs(taken) do
			if (Vector3.new(p.X, 0, p.Z) - Vector3.new(x, 0, z)).Magnitude < FG.MIN_SPACING then
				ok = false
				break
			end
		end
		if ok then
			overlap.FilterDescendantsInstances = ex
			for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(probe + Vector3.new(0, 1, 0)), Vector3.new(4, 5, 4), overlap)) do
				if part.CanCollide and part.CollisionGroup ~= CharacterService.GROUPS.CATCHER_WALL then
					ok = false
					break
				end
			end
		end
		if ok then
			down.FilterDescendantsInstances = ex
			local hit = workspace:Raycast(probe + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), down)
			if hit then
				return hit.Position + Vector3.new(0, FG.HOVER, 0)
			end
		end
	end
	return nil
end

-- the gem's body: the uploaded mesh (ReplicatedStorage.EOS_FieldGemTemplate) when the place has it,
-- else a stand-in (a glass cube on its point) so the prototype runs without it
local function makeGemPart(pos: Vector3): BasePart
	local template = ReplicatedStorage:FindFirstChild("EOS_FieldGemTemplate")
	local part: BasePart
	if template and template:IsA("BasePart") then
		part = template:Clone()
	else
		local p = Instance.new("Part")
		p.Size = Vector3.new(1.6, 1.6, 1.6)
		p.Material = Enum.Material.Glass
		p.Color = Color3.fromRGB(60, 220, 110)
		p.Reflectance = 0.25
		part = p
	end
	part.Name = "FieldGem"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(45), 0, math.rad(35))
	return part
end

local function spawnFor(c: any, wave: number)
	clearAll()
	if not FG.ENABLED then
		return
	end
	local taken = {}
	for _ = 1, countFor(c, wave) do
		local pos = pickSpot(taken)
		if pos then
			table.insert(taken, pos)
			local id = HttpService:GenerateGUID(false)
			local part = makeGemPart(pos)
			part:SetAttribute("GemId", id)
			part:SetAttribute("Wave", wave)
			CollectionService:AddTag(part, TAG)
			part.Parent = folder()
			table.insert(live, { id = id, part = part, pos = pos })
		end
	end
end

-- can this match participant take a Gem right now?
local function canPick(c: any, uid: number): boolean
	local p = c.logic:get(uid)
	if not p or p.disconnected then
		return false
	end
	if p.role == "RUNNER" then
		return not p.isSafeThisWave
	end
	return p.role == "CATCHER" and not FG.RUNNERS_ONLY
end

local capWarned: { [number]: boolean } = {}

local function pickupLoop(c: any)
	loopToken += 1
	local token = loopToken
	task.spawn(function()
		while token == loopToken and MatchService.current() == c and c.logic.phase == "ACTIVE" do
			if #live > 0 then
				for uid, plr in pairs(c.roster) do
					if not NpcService.isBot(plr) and plr.Parent and canPick(c, uid) then
						local pos = CharacterService.rootPosition(plr)
						if pos then
							for i = #live, 1, -1 do
								local g = live[i]
								local d = Vector3.new(pos.X - g.pos.X, 0, pos.Z - g.pos.Z).Magnitude
								if d <= FG.PICKUP_RADIUS and math.abs(pos.Y - g.pos.Y) <= 6 then
									local ok, total = c.logic:addFieldGem(uid, EconomyConfig.GEMS.FIELD_CAP)
									if ok then
										table.remove(live, i)
										g.part:Destroy()
										Net.event("FieldGemPicked"):FireAllClients({
											id = g.id,
											position = g.pos,
											userId = uid,
											total = total,
											cap = EconomyConfig.GEMS.FIELD_CAP,
										})
										Analytics.log("FieldGemPicked", { userId = uid, matchId = c.matchId, wave = c.logic.wave, total = total })
									elseif not capWarned[uid] then
										capWarned[uid] = true
										-- (the match HUD hides ordinary toasts: the Gem controller says it over the Gem)
										Net.event("FieldGemPicked"):FireClient(plr, { id = g.id, position = g.pos, userId = uid, full = true, cap = EconomyConfig.GEMS.FIELD_CAP })
									end
									break
								end
							end
						end
					end
				end
			end
			task.wait(FG.TICK)
		end
	end)
end

-- a Hero run (HOS-HOC-001) holds the crossing's Gems until the group is released: HeroChickenService
-- sets EOS_State.HeroRunActive before the "start" event and clears it on release / crossing end.
-- The spawn is deferred and token-checked: crossingEnded clears the flag just before "end" fires, and
-- that "end" must win.
local heroWait: RBXScriptConnection? = nil
local heroToken = 0

local function stopHeroWait()
	heroToken += 1
	if heroWait then
		heroWait:Disconnect()
		heroWait = nil
	end
end

function FieldGemService.init()
	MatchService.onCrossing(function(c: any, event: string, wave: number)
		stopHeroWait()
		if event == "start" then
			if wave == 1 then
				table.clear(capWarned)
			end
			local state = Net.state()
			if state:GetAttribute("HeroRunActive") == true then
				local token = heroToken
				heroWait = state:GetAttributeChangedSignal("HeroRunActive"):Connect(function()
					if state:GetAttribute("HeroRunActive") == true or token ~= heroToken then
						return
					end
					if heroWait then
						heroWait:Disconnect()
						heroWait = nil
					end
					task.defer(function()
						if token == heroToken and c.logic.wave == wave and MatchService.current() == c and c.logic.phase == "ACTIVE" then
							spawnFor(c, wave)
							pickupLoop(c)
						end
					end)
				end)
				return
			end
			spawnFor(c, wave)
			pickupLoop(c)
		else -- "end" (crossing over) or "match" (match over)
			clearAll()
		end
	end)
end

return FieldGemService
