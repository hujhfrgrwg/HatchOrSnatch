--!strict
-- CharacterService: everything the server does to a character for its role.
--  * collision groups (players never collide with each other; Catchers can't enter safe zones)
--  * walk speed per role (+ EOS_MaxSpeed attribute the client movement ramp reads)
--  * the physical match egg (voxel egg on the Runner's back; massless, no collision/query/touch)
--  * the overhead tag (name + role/tier line); outlines are drawn per viewer on the client
--    (Controllers/Outlines: Catchers and downed players red, Runner teammates blue)
--  * the Catcher's knife (ServerStorage.EOS_Assets["Minute Dagger"], from the dagger moveset rig),
--    held in the right hand on the joint the hit clips pose ("Minute Sword" -> "Minute Dagger")
--  * safe teleports
--  * the caught Runner's ragdoll (joints swap to ball sockets for a few seconds; see Shared/Ragdoll)

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TierConfig = require(Shared:WaitForChild("TierConfig"))
local EggModel = require(Shared:WaitForChild("EggModel"))
local Ragdoll = require(Shared:WaitForChild("Ragdoll"))

local CharacterService = {}

CharacterService.GROUPS = {
	LOBBY = "EOS_Lobby",
	RUNNER = "EOS_Runners",
	CATCHER = "EOS_Catchers",
	CATCHER_WALL = "EOS_CatcherWall",
	GATE = "EOS_Gate",
	BOT = "EOS_Bot",
	SAFE = "EOS_SafeRunners", -- Runners who made it across this crossing: the zone wall holds them in
	SKIN = "EOS_Skin", -- the NPC looks each client dresses its NPC bodies in: never collide with anything
}
local G = CharacterService.GROUPS

local RED = Color3.fromRGB(255, 72, 72)
local GREY = Color3.fromRGB(170, 175, 185)
local INK = Color3.fromRGB(7, 10, 14)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)

function CharacterService.setupCollisionGroups()
	for _, name in pairs(G) do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	-- characters (players and NPCs, any role) never collide with each other
	local chars = { G.LOBBY, G.RUNNER, G.CATCHER, G.SAFE }
	for _, a in ipairs(chars) do
		for _, b in ipairs(chars) do
			PhysicsService:CollisionGroupSetCollidable(a, b, false)
		end
		PhysicsService:CollisionGroupSetCollidable(a, G.BOT, false)
	end
	-- the zone wall (the "CatcherWall" parts, invisible, on each safe zone's edge) stops Catchers always,
	-- and Runners who already made it across (so they can't go back into the field this crossing)
	PhysicsService:CollisionGroupSetCollidable(G.CATCHER_WALL, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(G.CATCHER_WALL, G.LOBBY, false)
	PhysicsService:CollisionGroupSetCollidable(G.CATCHER_WALL, G.RUNNER, false)
	PhysicsService:CollisionGroupSetCollidable(G.CATCHER_WALL, G.BOT, false)
	PhysicsService:CollisionGroupSetCollidable(G.CATCHER_WALL, G.CATCHER, true)
	PhysicsService:CollisionGroupSetCollidable(G.CATCHER_WALL, G.SAFE, true)
	PhysicsService:CollisionGroupSetCollidable(G.CATCHER_WALL, G.GATE, false)
	PhysicsService:CollisionGroupSetCollidable(G.GATE, "Default", false)
	-- NPC looks: pure decoration (their Humanoid keeps switching the Torso's CanCollide back on)
	for _, name in pairs(G) do
		PhysicsService:CollisionGroupSetCollidable(G.SKIN, name, false)
	end
	PhysicsService:CollisionGroupSetCollidable(G.SKIN, "Default", false)
end

-- the group a body's parts belong in for its role (a Runner held in the zone after crossing: SAFE)
local function roleGroup(char: Model?, role: string): string
	if role == "RUNNER" then
		return if char and char:GetAttribute("EOS_ZoneLocked") == true then G.SAFE else G.RUNNER
	end
	return if role == "CATCHER" then G.CATCHER else G.LOBBY
end

local function setGroup(char: Model, group: string)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and not d:GetAttribute("EOS_Egg") then
			d.CollisionGroup = group
		end
	end
end

-- ===== the physical egg (built by Shared/EggModel) =====

-- cosmetics (egg case, trail) dress every carried egg as it's built (EconomyService)
local eggHooks: { (any, Model) -> () } = {}
function CharacterService.onEggBuilt(fn: (any, Model) -> ())
	table.insert(eggHooks, fn)
end

function CharacterService.setEgg(plr: Player, tier: number?)
	local char = plr.Character
	if not char then
		return
	end
	local old = char:FindFirstChild("EOS_Egg")
	if old then
		old:Destroy()
	end
	if not tier then
		return
	end
	local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return
	end
	local egg = EggModel.build(tier, true)
	local base = egg.PrimaryPart :: BasePart
	-- on the back: +Z is behind the torso; bottom of the egg near the waist
	egg:PivotTo(torso.CFrame * CFrame.new(0, -0.55, torso.Size.Z / 2 + 0.7 * TierConfig.get(tier).scale)) -- egg half-depth ~0.66 x scale: snug on the back
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = base
	weld.Parent = base
	egg.Parent = char
	for _, fn in ipairs(eggHooks) do
		local ok, err = pcall(fn, plr, egg)
		if not ok then
			warn("[EOS] egg cosmetic failed: " .. tostring(err))
		end
	end
end

-- ===== overhead tag =====

local function ensureTag(char: Model): BillboardGui?
	local head = char:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local tag = head:FindFirstChild("EOS_Tag") :: BillboardGui?
	if tag then
		return tag
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "EOS_Tag"
	bb.Size = UDim2.new(7, 0, 1.9, 0)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.7, 0)
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	local name = Instance.new("TextLabel")
	name.Name = "NameLabel"
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.5)
	name.FontFace = FONT
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	local s1 = Instance.new("UIStroke")
	s1.Color = INK
	s1.Thickness = 2
	s1.Parent = name
	name.Parent = bb
	local status = Instance.new("TextLabel")
	status.Name = "StatusLabel"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0, 0.5)
	status.Size = UDim2.fromScale(1, 0.42)
	status.FontFace = FONT
	status.TextScaled = true
	status.TextColor3 = Color3.new(1, 1, 1)
	local s2 = Instance.new("UIStroke")
	s2.Color = INK
	s2.Thickness = 2
	s2.Parent = status
	status.Parent = bb
	bb.Adornee = head
	bb.Parent = head
	return bb
end

function CharacterService.refreshTag(plr: Player)
	local char = plr.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local tag = ensureTag(char)
	if not tag then
		return
	end
	local nameLabel = tag:FindFirstChild("NameLabel") :: TextLabel
	local status = tag:FindFirstChild("StatusLabel") :: TextLabel
	-- VIP pass (PassService): a gold VIP ahead of the name, in the lobby and in matches
	if plr:GetAttribute("EOS_VIP") == true then
		nameLabel.RichText = true
		nameLabel.Text = '<font color="#FFD23A">VIP</font>  ' .. plr.DisplayName
	else
		nameLabel.RichText = false
		nameLabel.Text = plr.DisplayName
	end
	local role = plr:GetAttribute("EOS_Role") or "LOBBY"
	-- minimal HUD: in a match the tag is the name only (catchers already glow red, eggs show their level)
	status.Visible = role ~= "RUNNER" and role ~= "CATCHER" and role ~= "CAUGHT"
	if role == "RUNNER" then
		local t = plr:GetAttribute("EOS_Tier") or 1
		local def = TierConfig.get(t)
		status.Text = "RUNNER  ·  LEVEL " .. t .. " EGG"
		status.TextColor3 = def.text
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
	elseif role == "CATCHER" then
		status.Text = "CATCHER"
		status.TextColor3 = RED
		nameLabel.TextColor3 = Color3.fromRGB(255, 190, 190)
	elseif role == "CAUGHT" then
		status.Text = "CAUGHT  ·  CATCHER NEXT ROUND"
		status.TextColor3 = GREY
		nameLabel.TextColor3 = GREY
	else
		local level = plr:GetAttribute("EOS_Level") or 1
		local wins = plr:GetAttribute("EOS_Wins") or 0
		local afk = plr:GetAttribute("EOS_AFK") == true
		-- reference style: "Lv. 12  ·  4 wins  ·  AFK" (Lv = account level from match XP, 16 Oct; was the best egg level)
		status.Text = ("Lv. %d  ·  %d %s%s"):format(level, wins, if wins == 1 then "win" else "wins", if afk then "  ·  AFK" else "")
		status.TextColor3 = if afk then Color3.fromRGB(190, 190, 200) else Color3.fromRGB(255, 226, 120)
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
	end
end

-- kind: "CATCHER" (red) | "CAUGHT" (grey: out until the next crossing) | nil (none)
local function setHighlight(char: Model, kind: string?)
	local h = char:FindFirstChild("EOS_CatcherHighlight") :: Highlight?
	if kind and not h then
		local nh = Instance.new("Highlight")
		nh.Name = "EOS_CatcherHighlight"
		nh.OutlineTransparency = 0.1
		nh.DepthMode = Enum.HighlightDepthMode.Occluded -- no wallhacks: line-of-sight mind games matter
		nh.Parent = char
		h = nh
	elseif not kind and h then
		h:Destroy()
		return
	end
	if h and kind then
		local color = if kind == "CAUGHT" then GREY else RED
		h.FillColor = color
		h.OutlineColor = color
		h.FillTransparency = if kind == "CAUGHT" then 0.55 else 0.78
	end
end

local function setKnife(char: Model, on: boolean)
	for _, c in ipairs(char:GetChildren()) do
		if c:GetAttribute("EOS_Knife") then
			c:Destroy()
		end
	end
	local arm = char:FindFirstChild("Right Arm") :: BasePart?
	if arm then
		local oldMotor = arm:FindFirstChild("Minute Sword")
		if oldMotor then
			oldMotor:Destroy()
		end
	end
	if not on or not arm then
		return
	end
	local assets = game:GetService("ServerStorage"):FindFirstChild("EOS_Assets")
	local template = assets and assets:FindFirstChild("Minute Dagger")
	if not template or not template:IsA("BasePart") then
		return
	end
	local knife = template:Clone()
	knife:SetAttribute("EOS_Knife", true)
	knife:SetAttribute("EOS_Egg", true) -- keeps setGroup from touching it (it never collides anyway)
	local motor = knife:FindFirstChild("Minute Sword") :: Motor6D
	motor.Part0 = arm
	motor.Part1 = knife
	knife.CFrame = arm.CFrame * motor.C0 * motor.C1:Inverse()
	motor.Parent = arm
	knife.Parent = char
end

-- ===== ragdoll =====

local function isPlayer(actor: any): boolean
	return typeof(actor) == "Instance" and actor:IsA("Player")
end

-- Caught = a real ragdoll fall, then frozen (developer, Oct 16: "too laggy", but they must still
-- fall). The joints swap for ball sockets and the body falls the way it was hit; after
-- Capture.RAGDOLL_SETTLE seconds it is locked in the pose it landed in: every limb welded where it lies
-- and the body anchored. A body lying down for the rest of the crossing then costs nothing (before, every
-- downed body kept simulating and streaming physics until the crossing ended).

-- ball sockets + limb colliders, built once per body and left disabled until a fall
local function ragdollRig(char: Model): Folder?
	local torso = char:FindFirstChild("Torso") :: BasePart?
	if not torso then
		return nil
	end
	local existing = char:FindFirstChild("EOS_Ragdoll")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = "EOS_Ragdoll"
	for name, j in pairs(Ragdoll.JOINTS) do
		local motor = torso:FindFirstChild(name)
		local limb = if motor and motor:IsA("Motor6D") then motor.Part1 else nil
		if limb then
			local a0 = Instance.new("Attachment")
			a0.Name = "EOS_RD0_" .. name
			a0.CFrame = j.c0
			a0.Parent = torso
			local a1 = Instance.new("Attachment")
			a1.Name = "EOS_RD1_" .. name
			a1.CFrame = j.c1
			a1.Parent = limb
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = name
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.UpperAngle = j.cone
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -j.twist
			socket.TwistUpperAngle = j.twist
			socket.MaxFrictionTorque = 4 -- limbs settle instead of flapping
			socket.Enabled = false
			socket.Parent = f
			if limb.Name ~= "Head" then
				-- R6 arms and legs never collide: an invisible box keeps them out of the floor while down
				local box = Instance.new("Part")
				box.Name = "EOS_RDCollider"
				box.Size = limb.Size * 0.9
				box.CFrame = limb.CFrame
				box.Transparency = 1
				box.Massless = true
				box.CanCollide = false
				box.CanQuery = false
				box.CanTouch = false
				box.CollisionGroup = torso.CollisionGroup
				box:SetAttribute("EOS_RagdollPart", true)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = limb
				weld.Part1 = box
				weld.Parent = box
				box.Parent = f
			end
		end
	end
	f.Parent = char
	return f
end

-- lock a fallen body in the pose it landed in: limbs welded where they lie, body anchored
local function freezeFall(char: Model)
	local torso = char:FindFirstChild("Torso") :: BasePart?
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local f = char:FindFirstChild("EOS_Ragdoll")
	if not torso or not root or not f then
		return
	end
	local pose = char:FindFirstChild("EOS_Pose")
	if pose then
		pose:Destroy()
	end
	pose = Instance.new("Folder")
	pose.Name = "EOS_Pose"
	for _, socket in ipairs(f:GetChildren()) do
		if socket:IsA("BallSocketConstraint") and socket.Enabled then
			local limb = socket.Attachment1 and socket.Attachment1.Parent
			if limb and limb:IsA("BasePart") then
				local w = Instance.new("Weld")
				w.Name = socket.Name
				w.Part0 = torso
				w.Part1 = limb
				w.C0 = torso.CFrame:ToObjectSpace(limb.CFrame)
				w.Parent = pose
			end
			socket.Enabled = false
		elseif socket:IsA("BasePart") then
			socket.CanCollide = false
		end
	end
	pose.Parent = char
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then
			p.AssemblyLinearVelocity = Vector3.zero
			p.AssemblyAngularVelocity = Vector3.zero
		end
	end
	root.Anchored = true
	char:SetAttribute("EOS_RagdollFrozen", true)
end

-- knock a body over: `push` is the hit (world velocity, studs/s). It stays down until unragdoll
-- (a new role or a teleport: the end of the crossing) unless `seconds` (or RAGDOLL_STAY_DOWN = false)
-- gives it a time to get back up.
function CharacterService.ragdoll(actor: any, push: Vector3?, seconds: number?)
	local char = actor.Character :: Model?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local torso = char and char:FindFirstChild("Torso") :: BasePart?
	if not char or not hum or not torso or hum.Health <= 0 then
		return
	end
	local f = ragdollRig(char)
	if not f then
		return
	end
	for _, socket in ipairs(f:GetChildren()) do
		if socket:IsA("BallSocketConstraint") then
			local motor = torso:FindFirstChild(socket.Name)
			if motor and motor:IsA("Motor6D") then
				motor.Enabled = false
			end
			socket.Enabled = true
		elseif socket:IsA("BasePart") then
			socket.CollisionGroup = torso.CollisionGroup
			socket.CanCollide = true
		end
	end
	-- the loose limbs are assemblies of their own now: keep them with whoever simulates the body
	local owner = if isPlayer(actor) then actor else nil
	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("BasePart") then
			pcall(function()
				part:SetNetworkOwner(owner)
			end)
		end
	end
	local token = (char:GetAttribute("EOS_RagdollToken") or 0) + 1
	char:SetAttribute("EOS_RagdollToken", token)
	char:SetAttribute("EOS_RagdollPush", push or Vector3.zero)
	char:SetAttribute("EOS_RagdollFrozen", nil)
	char:SetAttribute("EOS_Ragdoll", true) -- the owner's client goes into Physics on this (Shared/Ragdoll)
	if not owner then
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		Ragdoll.fling(char, push or Vector3.zero)
	end
	local C = GameConfig.Capture
	-- the fall plays out, then the body is locked where it landed
	task.delay(C.RAGDOLL_SETTLE or 1.2, function()
		if char.Parent and char:GetAttribute("EOS_RagdollToken") == token and char:GetAttribute("EOS_Ragdoll") == true then
			freezeFall(char)
		end
	end)
	local hold = seconds or (if C.RAGDOLL_STAY_DOWN then nil else C.RAGDOLL_SECONDS)
	if hold then
		task.delay(hold, function()
			if char.Parent and char:GetAttribute("EOS_RagdollToken") == token then
				CharacterService.unragdoll(actor)
			end
		end)
	end
end

-- joints back, on your feet (also called early by a teleport or a new role)
function CharacterService.unragdoll(actor: any)
	local char = actor.Character :: Model?
	if not char or char:GetAttribute("EOS_Ragdoll") ~= true then
		return
	end
	local torso = char:FindFirstChild("Torso")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local pose = char:FindFirstChild("EOS_Pose")
	if pose then
		pose:Destroy()
	end
	local f = char:FindFirstChild("EOS_Ragdoll")
	if f and torso then
		for _, socket in ipairs(f:GetChildren()) do
			if socket:IsA("BallSocketConstraint") then
				socket.Enabled = false
				local motor = torso:FindFirstChild(socket.Name)
				if motor and motor:IsA("Motor6D") then
					motor.Enabled = true
				end
			elseif socket:IsA("BasePart") then
				socket.CanCollide = false
			end
		end
	end
	if root and root.Anchored then
		Ragdoll.standUp(char) -- upright where they lay, before the body is let go
		root.Anchored = false
	end
	char:SetAttribute("EOS_RagdollFrozen", nil)
	char:SetAttribute("EOS_RagdollToken", (char:GetAttribute("EOS_RagdollToken") or 0) + 1) -- cancels the timers
	char:SetAttribute("EOS_Ragdoll", nil) -- the owner's client stands up on this
	if not isPlayer(actor) then
		local hum = char:FindFirstChildOfClass("Humanoid")
		Ragdoll.standUp(char)
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end

-- Apply everything for a role. role: "LOBBY" | "RUNNER" | "CATCHER" | "CAUGHT" | "PRACTICE"
-- CAUGHT = tagged this crossing: out (can't tag or be tagged, walks through everyone) until the next one
function CharacterService.applyRole(plr: Player, role: string, tier: number?)
	if role ~= "CAUGHT" then
		CharacterService.unragdoll(plr) -- a new role (next crossing, back to the lobby) means back up
	end
	plr:SetAttribute("EOS_Role", role)
	plr:SetAttribute("EOS_Tier", if role == "RUNNER" then (tier or 1) else nil)
	local char = plr.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local M = GameConfig.Movement
	local speed = if role == "RUNNER" then M.RUNNER_SPEED elseif role == "CATCHER" then M.CATCHER_SPEED else M.LOBBY_SPEED
	if role ~= "CATCHER" then
		char:SetAttribute("EOS_Held", nil) -- only Catchers are ever held
	end
	char:SetAttribute("EOS_RoleSpeed", speed)
	if char:GetAttribute("EOS_Held") == true then
		speed = 0
	end
	if hum then
		hum.WalkSpeed = speed
		hum.UseJumpPower = false
		hum.JumpHeight = M.JUMP_HEIGHT
		hum:SetAttribute("EOS_MaxSpeed", speed)
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false -- the ragdoll switches the Neck motor off; that must not kill anyone
	end
	char:SetAttribute("EOS_ZoneLocked", nil) -- a new role (or tier) starts unlocked; MatchService re-locks
	setGroup(char, roleGroup(char, role))
	CharacterService.setEgg(plr, if role == "RUNNER" then (tier or 1) else nil)
	setHighlight(char, nil) -- (clears the old server-side highlight) outlines are per viewer now: Controllers/Outlines
	setKnife(char, role == "CATCHER")
	CharacterService.refreshTag(plr)
end

-- the top speed this character should have right now (role speed, 0 while held, reduced while slowed)
local function liveSpeed(char: Model): number
	if char:GetAttribute("EOS_Held") == true then
		return 0
	end
	local base = char:GetAttribute("EOS_RoleSpeed")
	base = if type(base) == "number" then base else GameConfig.Movement.LOBBY_SPEED
	local slowUntil = char:GetAttribute("EOS_SlowUntil")
	local factor = char:GetAttribute("EOS_SlowFactor")
	if type(slowUntil) == "number" and type(factor) == "number" and workspace:GetServerTimeNow() < slowUntil then
		base *= factor
	end
	return base
end

local function pushSpeed(actor: any)
	local char = actor.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local s = liveSpeed(char)
	hum:SetAttribute("EOS_MaxSpeed", s) -- players' clients drive from this
	if not isPlayer(actor) then
		hum.WalkSpeed = s -- NPCs (their brain also reads EOS_Held / EOS_SlowUntil)
	end
end

-- Catchers held in place (role reveal, side flip, the first moment of a crossing): they can't move
-- before the Runners. Works for players (EOS_MaxSpeed 0 stops the client drive) and NPCs.
function CharacterService.setHold(actor: any, on: boolean)
	local char = actor.Character
	if not char then
		return
	end
	char:SetAttribute("EOS_Held", if on then true else nil)
	pushSpeed(actor)
end

-- slowed to `factor` of top speed for `seconds` (the lunge's price, GameConfig.Lunge.SLOW_*). Players'
-- clients drive from EOS_MaxSpeed; NPC brains read EOS_SlowUntil / EOS_SlowFactor.
function CharacterService.slowFor(actor: any, factor: number, seconds: number)
	local char = actor.Character
	if not char then
		return
	end
	local untilT = workspace:GetServerTimeNow() + seconds
	char:SetAttribute("EOS_SlowFactor", factor)
	char:SetAttribute("EOS_SlowUntil", untilT)
	pushSpeed(actor)
	task.delay(seconds + 0.02, function()
		if char.Parent and char:GetAttribute("EOS_SlowUntil") == untilT then
			char:SetAttribute("EOS_SlowUntil", nil)
			char:SetAttribute("EOS_SlowFactor", nil)
			pushSpeed(actor)
		end
	end)
end

-- A Runner who made it across: the zone wall now stops them too, so they can't walk back into the
-- field this crossing (MatchService turns it on once they're clear of the wall, off at the next crossing).
function CharacterService.setZoneLock(plr: any, on: boolean)
	local char = plr.Character
	if not char or (char:GetAttribute("EOS_ZoneLocked") == true) == on then
		return
	end
	char:SetAttribute("EOS_ZoneLocked", if on then true else nil)
	setGroup(char, roleGroup(char, plr:GetAttribute("EOS_Role") or "LOBBY"))
end

function CharacterService.teleport(plr: Player, pos: Vector3, lookAt: Vector3?)
	local char = plr.Character
	if not char or not char.PrimaryPart then
		return
	end
	CharacterService.unragdoll(plr)
	local target = pos + Vector3.new(0, 2.5, 0)
	local cf = if lookAt then CFrame.lookAt(target, Vector3.new(lookAt.X, target.Y, lookAt.Z)) else CFrame.new(target)
	char:PivotTo(cf)
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
	plr:SetAttribute("EOS_TeleportedAt", os.clock())
end

-- a Catcher's hit, for everyone's screens: when it started and which way it went (world direction).
-- Clients turn that character's arm and knife toward it while the hit plays (CharacterAnim).
-- `who` is a Player or an NPC (anything with a .Character). `age`: how long ago the hit started, if it
-- reaches the server late (0 by default: swings are sent on the click).
function CharacterService.markSwing(who: any, aim: Vector3, age: number?)
	local char = who.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or aim.Magnitude < 1e-3 then
		return
	end
	local dir = aim.Unit
	hum:SetAttribute("EOS_SwingAim", Vector3.new(math.floor(dir.X * 100 + 0.5) / 100, math.floor(dir.Y * 100 + 0.5) / 100, math.floor(dir.Z * 100 + 0.5) / 100))
	hum:SetAttribute("EOS_SwingAt", workspace:GetServerTimeNow() - (age or 0))
end

function CharacterService.rootPosition(plr: Player): Vector3?
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then
		return hrp.Position
	end
	return nil
end

function CharacterService.init()
	CharacterService.setupCollisionGroups()
	local function onChar(plr: Player, char: Model)
		local rootPart = char:WaitForChild("HumanoidRootPart", 10)
		char:WaitForChild("Head", 10)
		-- fell into the void: the body is destroyed but the Humanoid never dies (RequiresNeck = false), so
		-- Roblox never respawns it and the player is stuck. Give them a fresh character instead.
		if rootPart then
			rootPart.AncestryChanged:Connect(function(_, parent)
				if parent == nil and plr.Parent and plr.Character == char then
					task.delay(1, function()
						if plr.Parent and plr.Character == char and not char:FindFirstChild("HumanoidRootPart") then
							plr:LoadCharacter()
						end
					end)
				end
			end)
		end
		-- new parts (accessories loading late) join the right group
		char.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") and not d:GetAttribute("EOS_Egg") then
				d.CollisionGroup = roleGroup(char, plr:GetAttribute("EOS_Role") or "LOBBY")
			end
		end)
		local role = plr:GetAttribute("EOS_Role") or "LOBBY"
		CharacterService.applyRole(plr, role, plr:GetAttribute("EOS_Tier"))
		-- The R6 StarterCharacter keeps every rig R6 (the movement clips are R6), but on its own it
		-- spawns everyone as the same default body: put the player's own avatar on it.
		if plr.UserId > 0 then
			task.spawn(function()
				local ok, desc = pcall(function()
					return Players:GetHumanoidDescriptionFromUserId(plr.UserId)
				end)
				local hum = char:FindFirstChildOfClass("Humanoid")
				if ok and desc and hum and char.Parent then
					local applied, err = pcall(function()
						hum:ApplyDescription(desc)
					end)
					if not applied then
						warn("[EOS] avatar for " .. plr.Name .. " not applied: " .. tostring(err))
					end
				end
			end)
		end
	end
	local function onPlayer(plr: Player)
		if not plr:GetAttribute("EOS_Role") then
			plr:SetAttribute("EOS_Role", "LOBBY")
		end
		plr.CharacterAdded:Connect(function(c)
			onChar(plr, c)
		end)
		if plr.Character then
			task.spawn(onChar, plr, plr.Character)
		end
		for _, attr in ipairs({ "EOS_AFK", "EOS_Wins", "EOS_BestTier", "EOS_Level", "EOS_VIP" }) do
			plr:GetAttributeChangedSignal(attr):Connect(function()
				CharacterService.refreshTag(plr)
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, plr in ipairs(Players:GetPlayers()) do
		onPlayer(plr)
	end
end

return CharacterService
