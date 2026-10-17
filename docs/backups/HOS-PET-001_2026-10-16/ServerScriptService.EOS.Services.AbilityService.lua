--!strict
-- AbilityService: the equipped pet's ability in a match (GDD v0.4 section 13). One pet = one ability.
-- The server owns cooldowns and effects; the family is fixed for the whole match (no mid-match swaps),
-- and the cooldown carries over when a Runner becomes a Catcher.
--  * DECOY: a copy of you (same look, egg and knife) runs ahead for a few seconds, then poofs.
--           It can't tag or be tagged; Catchers who swing at it see "DECOY!".
--  * SCOUT: the 3 nearest opponents are pinged through walls for you (ScoutPing).
--  * BRAKE: your client kills its momentum and cuts at full speed (Movement.brake); the server keeps
--           the cooldown and tells everyone.
-- Everyone sees a short pet summon + ring when an ability fires (AbilityFx); followers stay private.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local AnimConfig = require(Shared:WaitForChild("AnimConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Layout = require(Shared:WaitForChild("Layout"))
local Net = require(Shared:WaitForChild("Net"))
local ProfileLogic = require(ServerScriptService.EOS.Core.ProfileLogic)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)

local AbilityService = {}

type Loadout = { family: string, species: string, rarity: string, gold: boolean, readyAt: number, level: number }
local loadouts: { [Player]: Loadout } = {}

-- Pets that fly in before their ability lands: the copy appears this many seconds after the
-- request, on the flash (client CrowPet.INTRO must match). Looks only; the mechanics are shared.
local INTRO: { [string]: number } = { Crow = 0.5, Kitsune = 1.25, ["Prism Chameleon"] = 0.7, ["Grim Ghost"] = 0.55 }

-- invisibility state (defined in the INVISIBILITY section below; declared here for onMatchEnd)
local invisToken: { [Player]: any } = {}
local endInvisible: (plr: Player, species: string?, level: number?, token: any?) -> ()

-- every Decoy copy runs off at a random angle inside this cone (degrees) around your heading
local DECOY_SPREAD = 145
local decoyRng = Random.new()

-- a pet's mutation level (1..3); pets have no level field yet, so 1 until they do
local function petLevel(pet: any): number
	local lv = tonumber(pet and (pet.level or pet.mutation)) or 1
	return math.clamp(math.floor(lv), 1, 3)
end

-- Studio pet test, set on Workspace (live servers ignore it): EOS_TestPet = species ("Crow"),
-- EOS_TestPetLevel = 1..3 (or 0 = cycle 1 > 2 > 3, one level per use), EOS_TestCooldown = seconds.
-- Copied onto each player as they join (EOS_TestPet / EOS_TestPetLevel player attributes).
local function studioTest(): (string?, number, number?)
	if not RunService:IsStudio() then
		return nil, 1, nil
	end
	local sp = workspace:GetAttribute("EOS_TestPet")
	local lv = workspace:GetAttribute("EOS_TestPetLevel")
	local cd = workspace:GetAttribute("EOS_TestCooldown")
	return (if type(sp) == "string" and sp ~= "" then sp else nil),
		(if type(lv) == "number" then math.clamp(math.floor(lv), 0, 3) else 1),
		(if type(cd) == "number" and cd > 0 then cd else nil)
end

local function runtimeFolder(name: string): Folder
	local rt = workspace:FindFirstChild("EOS_Runtime")
	if not rt then
		rt = Instance.new("Folder")
		rt.Name = "EOS_Runtime"
		rt.Parent = workspace
	end
	local f = rt:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = rt
	end
	return f :: Folder
end

local function inZone(pos: Vector3): boolean
	return Layout.inBox(pos, Layout.Zones.A) or Layout.inBox(pos, Layout.Zones.B)
end

-- snapshot the equipped pet as the match starts
local function onMatchStart(plr: Player)
	loadouts[plr] = nil
	-- Studio pet test (EOS_PetLab): player attributes EOS_TestPet = species, EOS_TestPetLevel = 1..3
	local test = if RunService:IsStudio() then plr:GetAttribute("EOS_TestPet") else nil
	if type(test) == "string" and test ~= "" then
		local fam = plr:GetAttribute("EOS_TestPetFamily")
		local family = if type(fam) == "string" and EconomyConfig.FAMILIES[fam]
			then fam
			else (EconomyConfig.familyOfSpecies(test) or "Decoy")
		loadouts[plr] = {
			family = family,
			species = test,
			rarity = "common",
			gold = false,
			readyAt = 0,
			level = petLevel({ level = plr:GetAttribute("EOS_TestPetLevel") }),
		}
		return
	end
	local p = DataService.get(plr)
	if not p or p.equippedPet == "" then
		return
	end
	local pet = ProfileLogic.petById(p, p.equippedPet)
	if not pet or not EconomyConfig.FAMILIES[pet.family] then
		return
	end
	loadouts[plr] = {
		family = pet.family,
		species = pet.species,
		rarity = pet.rarity,
		gold = p.cosmetics.owned.fx_gold == true,
		readyAt = 0,
		level = petLevel(pet),
	}
end

local function onMatchEnd(plr: Player)
	loadouts[plr] = nil
	if invisToken[plr] then
		local char = plr.Character
		endInvisible(plr, char and char:GetAttribute("EOS_InvisibleSpecies"), char and char:GetAttribute("EOS_InvisibleLevel"))
	end
	local f = workspace:FindFirstChild("EOS_Runtime")
	local decoys = f and f:FindFirstChild("Decoys")
	if decoys then
		for _, d in ipairs(decoys:GetChildren()) do
			if d:GetAttribute("EOS_Decoy") == plr.UserId then
				d:Destroy()
			end
		end
	end
end

-- ===== DECOY =====

local function decoy(plr: Player, dir: Vector3, duration: number, species: string?, level: number?)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local human = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hrp or not human then
		return
	end
	local was = char.Archivable
	char.Archivable = true
	local clone = char:Clone()
	char.Archivable = was
	if not clone then
		return
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("ForceField") or d:IsA("LinearVelocity") or d:IsA("AlignOrientation") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	clone.Name = plr.Name
	clone:SetAttribute("EOS_Decoy", plr.UserId)
	local h = clone:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = clone:FindFirstChild("HumanoidRootPart") :: BasePart
	if not h or not root then
		clone:Destroy()
		return
	end
	local speed = human:GetAttribute("EOS_MaxSpeed")
	h.WalkSpeed = if type(speed) == "number" then speed else GameConfig.Movement.RUNNER_SPEED
	h.AutoRotate = true
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	h:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local moving = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
	if flat.Magnitude < 0.1 and moving.Magnitude > 4 then
		flat = moving -- no stick input but still carrying speed (a slide, a lunge): go the way you're moving
	elseif flat.Magnitude < 0.1 then
		flat = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	end
	flat = flat.Unit
	-- the copy picks its own heading inside a cone around yours, so Catchers can't call which way it goes
	local half = math.rad(DECOY_SPREAD / 2)
	flat = (CFrame.Angles(0, decoyRng:NextNumber(-half, half), 0) * flat).Unit
	-- The server sees a running player a moment in the past, and the copy reaches their screen later
	-- still: start it where they'll be by then (ping + interpolation), already at full speed, so it
	-- doesn't appear behind them. A wall in the way stops the lead short of it.
	local vel = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
	-- measured in Studio: a new copy shows up on the owner's screen about 0.3 s behind the server
	local lead = vel * math.clamp(plr:GetNetworkPing() + 0.3, 0.25, 0.6)
	local start = hrp.Position
	if lead.Magnitude > 0.05 then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char, runtimeFolder("Decoys") }
		local hit = workspace:Raycast(hrp.Position, lead, params)
		start = if hit
			then hrp.Position + lead.Unit * math.max(0, (hit.Position - hrp.Position).Magnitude - 1.5)
			else hrp.Position + lead
	end
	clone:PivotTo(CFrame.lookAt(start, start + flat))
	clone.Parent = runtimeFolder("Decoys")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	root.AssemblyLinearVelocity = flat * h.WalkSpeed -- already running when it appears
	-- the same run clip the owner shows (published id; Studio-only clips can't play on the server)
	local animator = h:FindFirstChildOfClass("Animator") or Instance.new("Animator", h)
	local runId = AnimConfig.ids.Run
	if runId and runId ~= "" then
		local a = Instance.new("Animation")
		a.AnimationId = runId
		local ok, track = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok and track then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Movement
			track:Play(0.1, 1, h.WalkSpeed / (AnimConfig.naturalSpeed.Run or 21.5))
		end
	end
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not clone.Parent or os.clock() - t0 > duration then
			conn:Disconnect()
			if clone.Parent then
				Net.event("AbilityFx"):FireAllClients({
					userId = plr.UserId,
					family = "Decoy",
					kind = "poof",
					pos = root.Position,
					species = species,
					level = level,
				})
				clone:Destroy()
			end
			return
		end
		h:Move(flat, false)
	end)
end

-- ===== INVISIBILITY =====
-- Shared by every invisibility pet: the pet's summon is only a look. For `duration` seconds the body
-- carries EOS_Invisible; each client draws it (Controllers.Invisibility: ghosted for you, a faint
-- shimmer for everyone else, no tag/outline/egg sparkle) and NPC Catchers stop targeting it
-- (NpcService). Tags and collisions are unchanged: an opponent who finds you can still catch you.

function endInvisible(plr: Player, species: string?, level: number?, token: any?)
	if token ~= nil and invisToken[plr] ~= token then
		return
	end
	invisToken[plr] = nil
	local char = plr.Character
	if char and char:GetAttribute("EOS_Invisible") then
		char:SetAttribute("EOS_Invisible", nil)
		char:SetAttribute("EOS_InvisibleSpecies", nil)
		char:SetAttribute("EOS_InvisibleLevel", nil)
		local r = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		Net.event("AbilityFx"):FireAllClients({
			userId = plr.UserId,
			family = "Invisibility",
			kind = "reveal",
			pos = r and r.Position or nil,
			species = species,
			level = level,
		})
	end
end

local function invisible(plr: Player, duration: number, species: string?, level: number?)
	local char = plr.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return
	end
	local token = {}
	invisToken[plr] = token
	char:SetAttribute("EOS_InvisibleSpecies", species)
	char:SetAttribute("EOS_InvisibleLevel", level or 1)
	char:SetAttribute("EOS_Invisible", true)
	-- caught / role change / new body: it ends at once
	local conns: { RBXScriptConnection } = {}
	local function finish()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		endInvisible(plr, species, level, token)
	end
	table.insert(conns, plr:GetAttributeChangedSignal("EOS_Role"):Connect(finish))
	table.insert(conns, plr.CharacterRemoving:Connect(finish))
	task.delay(duration, finish)
end

-- ===== SCOUT =====

local function opponents(plr: Player, role: string): { { uid: number, pos: Vector3 } }
	local want = if role == "RUNNER" then "CATCHER" else "RUNNER"
	local out = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= plr and other:GetAttribute("EOS_InMatch") and other:GetAttribute("EOS_Role") == want and not other:GetAttribute("EOS_Safe") then
			local c = other.Character
			local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				table.insert(out, { uid = other.UserId, pos = r.Position })
			end
		end
	end
	local rt = workspace:FindFirstChild("EOS_Runtime")
	local npcs = rt and rt:FindFirstChild("Npcs")
	if npcs then
		for _, m in ipairs(npcs:GetChildren()) do
			local uid = m:GetAttribute("EOS_UserId")
			local r = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and type(uid) == "number" and m:GetAttribute("EOS_InMatch") and m:GetAttribute("EOS_Role") == want and not m:GetAttribute("EOS_Safe") then
				if want ~= "RUNNER" or not inZone(r.Position) then
					table.insert(out, { uid = uid, pos = r.Position })
				end
			end
		end
	end
	return out
end

local function scout(plr: Player, role: string, duration: number)
	local c = plr.Character
	local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not r then
		return
	end
	local list = opponents(plr, role)
	table.sort(list, function(a, b)
		return (a.pos - r.Position).Magnitude < (b.pos - r.Position).Magnitude
	end)
	local targets = {}
	for i = 1, math.min(3, #list) do
		table.insert(targets, list[i].uid)
	end
	Net.event("ScoutPing"):FireClient(plr, { targets = targets, duration = duration })
end

-- ===== the request =====

local WORDS = {
	NO_PET = "No pet equipped: hatch one at the incubator",
	COOLDOWN = nil, -- the card shows the timer
	WAIT = "Wait for the crossing to start",
	OUT = "You're out this crossing",
	LOBBY = "Abilities work in matches",
}

local function onRequest(plr: Player, moveDir: any)
	if not MatchService.limiter:allow(plr.UserId, "RequestAbility", os.clock()) then
		return
	end
	if moveDir ~= nil and (typeof(moveDir) ~= "Vector3" or moveDir ~= moveDir or moveDir.Magnitude > 2) then
		return
	end
	local function refuse(reason: string, readyIn: number?)
		Net.event("AbilityState"):FireClient(plr, { ok = false, reason = reason, readyIn = readyIn })
		local w = WORDS[reason]
		if w then
			Net.event("Toast"):FireClient(plr, { text = w, kind = "info" })
		end
	end
	if plr:GetAttribute("EOS_InMatch") ~= true then
		return refuse("LOBBY")
	end
	local role = plr:GetAttribute("EOS_Role")
	if role ~= "RUNNER" and role ~= "CATCHER" then
		return refuse("OUT")
	end
	local sandbox = plr:GetAttribute("EOS_Sandbox") == true -- Studio knife-test baseplate
	if Net.state():GetAttribute("Phase") ~= "CROSSING" and not sandbox then
		return refuse("WAIT")
	end
	if sandbox and not loadouts[plr] then
		onMatchStart(plr)
	end
	local lo = loadouts[plr]
	if not lo then
		return refuse("NO_PET")
	end
	local now = os.clock()
	if now < lo.readyAt then
		return refuse("COOLDOWN", lo.readyAt - now)
	end
	local def = EconomyConfig.FAMILIES[lo.family]
	local testPet, testLevel, testCooldown = studioTest()
	local cooldown = testCooldown or def.cooldown
	lo.readyAt = now + cooldown
	if testPet and plr:GetAttribute("EOS_TestPet") == lo.species then
		-- Studio pet test: this use plays the level the player's crow shows; cycle mode moves it on
		lo.level = petLevel({ level = plr:GetAttribute("EOS_TestPetLevel") })
		if testLevel == 0 then
			local nextLevel = lo.level % 3 + 1
			task.delay((INTRO[lo.species] or 0) + def.duration + 0.2, function()
				if plr.Parent then
					plr:SetAttribute("EOS_TestPetLevel", nextLevel)
				end
			end)
		end
	end
	local c = plr.Character
	local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if lo.family == "Decoy" then
		local dir = if typeof(moveDir) == "Vector3" then moveDir else Vector3.zero
		local intro = INTRO[lo.species]
		if intro then
			-- the pet flies in first; the copy appears on its flash (same copy, same rules)
			task.delay(intro, function()
				if loadouts[plr] == lo and plr.Parent then
					decoy(plr, dir, def.duration, lo.species, lo.level)
				end
			end)
		else
			decoy(plr, dir, def.duration, lo.species, lo.level)
		end
	elseif lo.family == "Invisibility" then
		-- the pet merges into you first; you fade on its flash
		local intro = INTRO[lo.species] or 0
		task.delay(intro, function()
			if loadouts[plr] == lo and plr.Parent then
				invisible(plr, def.duration, lo.species, lo.level)
			end
		end)
	elseif lo.family == "Scout" then
		scout(plr, role, def.duration)
	end
	Net.event("AbilityState"):FireClient(plr, { ok = true, family = lo.family, readyIn = cooldown })
	Net.event("AbilityFx"):FireAllClients({
		userId = plr.UserId,
		family = lo.family,
		species = lo.species,
		kind = "summon",
		pos = r and r.Position or nil,
		gold = lo.gold,
		level = lo.level,
	})
	Analytics.log("AbilityUsed", { userId = plr.UserId, family = lo.family, role = role })
end

function AbilityService.init()
	Net.event("RequestAbility").OnServerEvent:Connect(onRequest)
	MatchService.onPlayerMatchStart(onMatchStart)
	MatchService.onPlayerMatchEnd(onMatchEnd)
	Players.PlayerRemoving:Connect(function(plr)
		onMatchEnd(plr)
	end)
	if RunService:IsStudio() then
		local function tag(plr: Player)
			local sp, lv = studioTest()
			if sp then
				plr:SetAttribute("EOS_TestPet", sp)
				plr:SetAttribute("EOS_TestPetLevel", math.max(lv, 1))
			end
		end
		Players.PlayerAdded:Connect(tag)
		for _, plr in ipairs(Players:GetPlayers()) do
			tag(plr)
		end
	end
end

return AbilityService
