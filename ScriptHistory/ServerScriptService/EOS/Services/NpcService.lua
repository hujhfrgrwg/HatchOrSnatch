-- NpcService: NPC bodies and brains (server). Everyone sees the same NPC moving the same way; each
-- player's own client dresses the bodies as that player's friends (NpcSkinService + client NpcSkins).
--  * a bot is a plain R6 body (a clone of StarterPlayer.StarterCharacter) plus a small table that
--    answers like a Player (UserId, DisplayName, Character, Get/SetAttribute), so the match code
--    and CharacterService treat bots and players the same way
--  * lobby: when the server has fewer than Npc.LOBBY_TARGET people, NPCs walk around the lobby
--    (walking only: no running or slides there)
--  * matches: MatchService creates the bots it needs (NPC Runners top the match up to
--    Npc.RUNNER_TARGET Runners) and hands this service the running match; bots follow every rule
--    a player does (caught or timed out = Catcher)
--  * brains run Npc.THINK_RATE times a second; NPC Runners' dashes use the players' burst numbers,
--    clips and rules (no forward dashes or dives since Oct 15); NPC Catchers don't dash
-- Attributes on each bot's model (replicated): EOS_IsNpc, EOS_NpcSlot (which friend look),
-- EOS_UserId, plus the usual EOS_Role / EOS_Tier / EOS_Safe / EOS_InMatch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local AnimConfig = require(Shared:WaitForChild("AnimConfig"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Layout = require(Shared:WaitForChild("Layout"))
local Net = require(Shared:WaitForChild("Net"))
local CharacterService = require(script.Parent.CharacterService)

local N = GameConfig.Npc
local D = GameConfig.Dash
local ST = GameConfig.Stab
local NpcService = {}

local state = Net.state()
local rng = Random.new()
local serial = 0
local bots: { any } = {}
local slots: { [number]: any } = {}
local matchRef: any = nil -- the running match (MatchService's `current`), set while one runs
local slotListeners: { () -> () } = {}

-- ===== a bot answers like a Player =====

local BotMeta = {}
BotMeta.__index = BotMeta
function BotMeta:GetAttribute(name: string): any
	local m = self.Character
	return if m then m:GetAttribute(name) else nil
end
function BotMeta:SetAttribute(name: string, value: any)
	local m = self.Character
	if m then
		m:SetAttribute(name, value)
	end
end

function NpcService.isBot(actor: any): boolean
	return type(actor) == "table" and actor.IsBot == true
end

local function folder(): Folder
	local runtime = workspace:FindFirstChild("EOS_Runtime")
	if not runtime then
		runtime = Instance.new("Folder")
		runtime.Name = "EOS_Runtime"
		runtime.Parent = workspace
	end
	local f = runtime:FindFirstChild("Npcs")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Npcs"
		f.Parent = runtime
	end
	return f :: Folder
end

local function freeSlot(): number?
	for i = 1, N.MAX_SLOTS do
		if not slots[i] then
			return i
		end
	end
	return nil
end

-- highest friend look in use (NpcSkinService builds looks up to this)
function NpcService.highestSlot(): number
	local hi = 0
	for i in pairs(slots) do
		hi = math.max(hi, i)
	end
	return hi
end

function NpcService.onSlotsChanged(fn: () -> ())
	table.insert(slotListeners, fn)
end

local function slotsChanged()
	for _, fn in ipairs(slotListeners) do
		task.spawn(fn)
	end
end

local PALETTE = {
	Color3.fromRGB(255, 205, 160), Color3.fromRGB(234, 184, 146), Color3.fromRGB(204, 142, 105),
	Color3.fromRGB(124, 92, 70), Color3.fromRGB(255, 220, 190),
}
local CLOTHES = {
	Color3.fromRGB(52, 142, 64), Color3.fromRGB(13, 105, 172), Color3.fromRGB(196, 40, 28),
	Color3.fromRGB(245, 205, 48), Color3.fromRGB(107, 50, 124), Color3.fromRGB(39, 70, 45),
	Color3.fromRGB(27, 42, 53), Color3.fromRGB(218, 133, 65),
}

local function newBody(slot: number, uid: number): Model?
	local template = StarterPlayer:FindFirstChild("StarterCharacter")
	if not template then
		warn("[EOS] NPCs need StarterPlayer.StarterCharacter (the R6 body)")
		return nil
	end
	local model = template:Clone() :: Model
	model.Name = "EOS_NPC_" .. slot
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	-- a plain fallback look (each player normally sees a friend's avatar instead)
	local skin = PALETTE[rng:NextInteger(1, #PALETTE)]
	local shirt = CLOTHES[rng:NextInteger(1, #CLOTHES)]
	local pants = CLOTHES[rng:NextInteger(1, #CLOTHES)]
	local bc = model:FindFirstChildOfClass("BodyColors")
	if bc then
		bc.HeadColor3, bc.LeftArmColor3, bc.RightArmColor3 = skin, skin, skin
		bc.TorsoColor3, bc.LeftLegColor3, bc.RightLegColor3 = shirt, pants, pants
	end
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.UseJumpPower = false
	hum.JumpHeight = 0
	for _, st in ipairs({ Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Seated }) do
		hum:SetStateEnabled(st, false)
	end
	if not hum:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = hum
	end
	-- never streamed out (or half streamed: a body missing limbs looks like an NPC vanished)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	model:SetAttribute("EOS_IsNpc", true)
	model:SetAttribute("EOS_NpcSlot", slot)
	model:SetAttribute("EOS_UserId", uid)
	return model
end

-- ===== animation (server-played, replicates to everyone) =====

local LOCO = { "Idle", "WalkSlow", "WalkFast", "Run" }
local ONE_SHOTS = { "DashLeft", "DashRight", "DashBack" }

local function loadTracks(bot: any)
	local animator = bot.human:FindFirstChildOfClass("Animator") :: Animator
	local function load(name: string, id: string?, looped: boolean, priority: Enum.AnimationPriority)
		if not id or id == "" then
			return
		end
		local a = Instance.new("Animation")
		a.Name = "EOS_" .. name
		a.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok and track then
			track.Looped = looped
			track.Priority = priority
			bot.tracks[name] = track
		end
	end
	load("Idle", AnimConfig.builtin.Idle, true, Enum.AnimationPriority.Idle)
	for _, n in ipairs({ "WalkSlow", "WalkFast", "Run", "StrafeLeft", "StrafeRight" }) do
		load(n, AnimConfig.ids[n], true, Enum.AnimationPriority.Movement)
	end
	for _, n in ipairs({ "DashLeft", "DashRight", "DashBack" }) do
		load(n, AnimConfig.ids[n], false, Enum.AnimationPriority.Action)
	end
	-- the Catcher's jab and lunge (Studio: an unpublished clip plays from its local KeyframeSequence)
	load("SwingJab", AnimConfig.ids.SwingJab, false, Enum.AnimationPriority.Action2)
	local lungeId = AnimConfig.ids.LungeStab
	if (not lungeId or lungeId == "") and RunService:IsStudio() then
		local lib = ReplicatedStorage:FindFirstChild(AnimConfig.LIBRARY)
		local seq = lib and lib:FindFirstChild("LungeStab")
		if seq then
			local ok, id = pcall(function()
				return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(seq)
			end)
			lungeId = if ok then id else nil
		end
	end
	load("LungeStab", lungeId, false, Enum.AnimationPriority.Action2)
end

-- an NPC Catcher's knife hit: the full-body lunge stab, aimed at the Runner it swings at. Like a
-- player's, it never slows the body: moving, the run takes the legs back right after the thrust.
-- Cosmetic: NPC Catchers tag by contact.
local function swing(bot: any, at: Vector3?)
	local now = os.clock()
	if now < (bot.swingReadyAt or 0) or now < bot.dashUntil then
		return
	end
	bot.swingReadyAt = now + GameConfig.Capture.TAG_COOLDOWN
	require(script.Parent.PointsService).catcherAttacked(bot, "swing") -- HOS-PTS-001: a miss near a Runner is a juke
	local t = bot.tracks.SwingJab
	if t then
		t:Play(0.04, 1, 1)
		bot.stabAt = now
		task.delay(ST.MOVING_FADE_AT, function()
			local v = bot.root.AssemblyLinearVelocity
			if bot.stabAt == now and t.IsPlaying and Vector3.new(v.X, 0, v.Z).Magnitude > AnimConfig.IDLE_BELOW then
				t:Stop(ST.MOVING_FADE)
			end
		end)
		task.delay(ST.END_FADE_AT, function()
			if bot.stabAt == now and t.IsPlaying then
				t:Stop(0.2)
			end
		end)
	end
	if at then
		-- from about the right shoulder to the Runner's chest
		local from = (bot.root.CFrame * CFrame.new(1, 1, 0)).Position
		CharacterService.markSwing(bot, at + Vector3.new(0, 0.5, 0) - from)
	end
end

local STRAFE_RATE_MAX = 3.6 -- side-walk clips are slow walks: let them play faster at running pace

local function animate(bot: any)
	local v = bot.root.AssemblyLinearVelocity
	local flatV = Vector3.new(v.X, 0, v.Z)
	local speed = flatV.Magnitude
	local slot = if speed < AnimConfig.IDLE_BELOW then "Idle" elseif speed < AnimConfig.WALK_FAST_FROM then "WalkSlow" elseif speed < AnimConfig.RUN_FROM then "WalkFast" else "Run"
	local rate = 1
	local trackName = slot
	if slot ~= "Idle" then
		rate = math.clamp(speed / (AnimConfig.naturalSpeed[slot] or 10), AnimConfig.RATE_MIN, AnimConfig.RATE_MAX)
		-- squared up to a Runner (facing them, not the way it moves): side walk or walk backwards, like a
		-- player Catcher facing the camera
		local look = Vector3.new(bot.root.CFrame.LookVector.X, 0, bot.root.CFrame.LookVector.Z)
		if look.Magnitude > 0.01 and speed > 2 then
			local angle = math.acos(math.clamp(look.Unit:Dot(flatV.Unit), -1, 1))
			if angle >= AnimConfig.BACKPEDAL_FROM then
				slot, trackName = "Back", "WalkFast"
				rate = -math.clamp(speed / AnimConfig.naturalSpeed.WalkFast, AnimConfig.RATE_MIN, STRAFE_RATE_MAX)
			elseif angle >= AnimConfig.STRAFE_FROM then
				local rel = CFrame.lookAt(Vector3.zero, look):VectorToObjectSpace(flatV)
				slot = if rel.X > 0 then "StrafeRight" else "StrafeLeft"
				trackName = slot
				rate = math.clamp(speed / (AnimConfig.naturalSpeed[slot] or 6), AnimConfig.RATE_MIN, STRAFE_RATE_MAX)
			end
			if not bot.tracks[trackName] then
				trackName = if speed >= AnimConfig.RUN_FROM then "Run" else "WalkFast"
			end
		end
	end
	local t = bot.tracks[trackName]
	if bot.loco ~= slot then
		local old = bot.locoTrack
		if old and old ~= t then
			old:Stop(AnimConfig.FADE)
		end
		if t then
			t:Play(AnimConfig.FADE, 1, rate)
		end
		bot.loco = slot
		bot.locoTrack = t
	elseif t and math.abs(t.Speed - rate) > 0.08 then
		t:AdjustSpeed(rate)
	end
end

-- ===== spawn / despawn =====

-- kind: "LOBBY" | "MATCH"
function NpcService.spawn(kind: string, at: Vector3?, lookAt: Vector3?): any?
	local slot = freeSlot()
	if not slot then
		return nil
	end
	serial += 1
	local uid = -(1000000 + serial)
	local model = newBody(slot, uid)
	if not model then
		return nil
	end
	local bot = setmetatable({
		IsBot = true,
		UserId = uid,
		Name = "NPC" .. slot,
		DisplayName = "Runner " .. slot, -- shared fallback; each client shows its own friend's name
		Character = model,
		Parent = nil :: Instance?,
		slot = slot,
		kind = kind,
		human = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		root = model:FindFirstChild("HumanoidRootPart") :: BasePart,
		tracks = {},
		loco = nil :: string?,
		dashReadyAt = 0,
		burstUntil = 0,
		dashUntil = 0,
		dashDir = Vector3.zero,
		brain = {},
	}, BotMeta)
	slots[slot] = bot
	-- HOS-BOT-001: this slot's made-up identity (name, outfit; stats from real players), the same for everyone
	bot.identity = if N.REAL_POOL then require(script.Parent.RealPlayerPool).take(slot) else nil
	if bot.identity then
		bot.Name, bot.DisplayName = bot.identity.name, bot.identity.name
	end
	local spot = at or Layout.Lobby.SPAWN
	local target = spot + Vector3.new(0, 3, 0)
	model:PivotTo(if lookAt then CFrame.lookAt(target, Vector3.new(lookAt.X, target.Y, lookAt.Z)) else CFrame.new(target))
	model.Parent = folder()
	bot.Parent = model.Parent
	pcall(function()
		bot.root:SetNetworkOwner(nil) -- the server drives NPCs; no client may own them
	end)
	-- lobby flavour for the overhead tag (best tier / wins line)
	bot:SetAttribute("EOS_BestTier", rng:NextInteger(1, 3))
	local id = bot.identity
	bot:SetAttribute("EOS_Wins", if id then id.wins else rng:NextInteger(0, 12))
	if id then
		bot:SetAttribute("EOS_Level", id.level)
		bot:SetAttribute("EOS_PetFamily", id.petFamily)
		bot:SetAttribute("EOS_PetSpecies", id.petSpecies)
		bot:SetAttribute("EOS_PetRarity", id.petRarity)
		bot:SetAttribute("EOS_PetLevel", id.petLevel)
	end
	CharacterService.applyRole(bot, "LOBBY")
	loadTracks(bot)
	table.insert(bots, bot)
	slotsChanged()
	return bot
end

function NpcService.despawn(bot: any)
	local i = table.find(bots, bot)
	if i then
		table.remove(bots, i)
	end
	if slots[bot.slot] == bot then
		slots[bot.slot] = nil
		if bot.identity then
			require(script.Parent.RealPlayerPool).release(bot.slot)
		end
	end
	bot.Parent = nil
	if bot.Character then
		bot.Character:Destroy()
	end
	slotsChanged()
end

function NpcService.all(): { any }
	return bots
end

-- the match NPCs act in (nil = no match); MatchService sets it at the start and clears it at the end
function NpcService.setMatch(m: any)
	matchRef = m
	for _, bot in ipairs(bots) do
		bot.brain = {}
	end
end

-- ===== movement helpers =====

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function unit(v: Vector3, fallback: Vector3): Vector3
	return if v.Magnitude > 1e-3 then v.Unit else fallback
end

local function rotate(v: Vector3, deg: number): Vector3
	return CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(v)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function groupFor(bot: any): string
	if bot.root then
		return bot.root.CollisionGroup -- whatever the body is in right now (a safe Runner: held in the zone)
	end
	local role = bot:GetAttribute("EOS_Role")
	local G = CharacterService.GROUPS
	return if role == "RUNNER" then G.RUNNER elseif role == "CATCHER" then G.CATCHER else G.LOBBY
end

-- steer round whatever blocks this bot (respects its collision group: Catchers and safe Runners see
-- the zone walls)
local function avoid(bot: any, pos: Vector3, dir: Vector3): Vector3
	rayParams.CollisionGroup = groupFor(bot)
	local origin = pos - Vector3.new(0, 1.8, 0) -- knee height (low planters and bales count)
	local function clear(d: Vector3): boolean
		return workspace:Raycast(origin, d * 7, rayParams) == nil
	end
	if clear(dir) then
		return dir
	end
	for _, a in ipairs({ 35, -35, 70, -70, 110, -110 }) do
		local d = rotate(dir, if bot.brain.turnBias == -1 then -a else a)
		if clear(d) then
			return d
		end
	end
	return dir
end

local function setSpeed(bot: any, speed: number)
	local char = bot.Character
	if char then
		if char:GetAttribute("EOS_Held") == true then
			speed = 0 -- a held Catcher (CharacterService.setHold)
		else
			local slowUntil = char:GetAttribute("EOS_SlowUntil")
			local factor = char:GetAttribute("EOS_SlowFactor")
			if type(slowUntil) == "number" and type(factor) == "number" and workspace:GetServerTimeNow() < slowUntil then
				speed *= factor -- just lunged
			end
		end
	end
	if os.clock() >= bot.dashUntil and math.abs(bot.human.WalkSpeed - speed) > 0.05 then
		bot.human.WalkSpeed = speed
	end
end

local function move(bot: any, dir: Vector3?)
	if os.clock() < bot.burstUntil then
		return -- the dash owns the body
	end
	bot.human:Move(dir or Vector3.zero, false)
end

-- a dash like a player's: burst, then ease back; the clip is picked against the facing. Same rules as
-- players: never as a Catcher in a match, never the way the body faces (no forward dashes or dives)
local function dash(bot: any, dir: Vector3)
	local now = os.clock()
	if now < bot.dashReadyAt or bot.human.FloorMaterial == Enum.Material.Air then
		return
	end
	if not D.CATCHER_DASH and bot:GetAttribute("EOS_InMatch") and bot:GetAttribute("EOS_Role") == "CATCHER" then
		return
	end
	local look = unit(flat(bot.root.CFrame.LookVector), Vector3.new(0, 0, -1))
	if dir:Dot(look) >= math.cos(D.BODY_FORWARD_MAX_ANGLE) then
		return
	end
	bot.dashReadyAt = now + N.DASH_COOLDOWN
	bot.burstSpeed, bot.recoverTime = nil, nil
	local rel = CFrame.lookAt(Vector3.zero, look):VectorToObjectSpace(dir)
	local angle = math.atan2(rel.X, -rel.Z)
	local clip = if math.abs(angle) >= D.BACK_MIN_ANGLE then "DashBack" elseif angle > 0 then "DashRight" else "DashLeft"
	bot.dashDir = dir
	bot.burstUntil = now + D.BURST_TIME
	bot.dashUntil = now + D.BURST_TIME + D.RECOVER_TIME
	bot.human.AutoRotate = false -- slides keep the body's facing so the clip reads
	bot.human.WalkSpeed = D.SPEED
	bot.human:Move(dir, false)
	local t = bot.tracks[clip]
	if t then
		t:Play(0.05, 1, D.ANIM_SPEED)
	end
end

-- Turning an NPC by writing root.CFrame snaps it on every client (the write resets the client's
-- smoothing: measured 5-7.5 stud jumps per lunge). Facing goes through a physics AlignOrientation
-- instead, which replicates smoothly. look = nil releases the body back to AutoRotate.
local function faceToward(bot: any, look: Vector3?, responsiveness: number?)
	local root = bot.root
	if not root or not root.Parent then
		return
	end
	local ao = root:FindFirstChild("EOS_Face") :: AlignOrientation?
	if not ao then
		local att = Instance.new("Attachment")
		att.Name = "EOS_FaceAtt"
		att.Parent = root
		local a = Instance.new("AlignOrientation")
		a.Name = "EOS_Face"
		a.Mode = Enum.OrientationAlignmentMode.OneAttachment
		a.Attachment0 = att
		a.MaxTorque = math.huge
		a.MaxAngularVelocity = math.huge
		a.RigidityEnabled = false
		a.Enabled = false
		a.Parent = root
		ao = a
	end
	local align = ao :: AlignOrientation
	if look and Vector3.new(look.X, 0, look.Z).Magnitude > 0.01 then
		bot.human.AutoRotate = false
		align.Responsiveness = responsiveness or 40
		align.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(look.X, 0, look.Z))
		align.Enabled = true
	else
		align.Enabled = false
	end
end

-- an NPC Catcher's lunge (GameConfig.Lunge): the overhead stab clip, a burst toward the Runner, then
-- slowed like a player. The hit itself is the server's contact scan (the burst carries the body in).
local LG = GameConfig.Lunge
local function lunge(bot: any, dir: Vector3): boolean
	local now = os.clock()
	if not LG.ENABLED or now < (bot.lungeReadyAt or 0) or now < bot.dashUntil or bot.human.FloorMaterial == Enum.Material.Air then
		return false
	end
	bot.lungeReadyAt = now + LG.COOLDOWN
	require(script.Parent.PointsService).catcherAttacked(bot, "lunge") -- HOS-PTS-001: a miss near a Runner is a juke
	bot.dashDir = dir
	bot.burstSpeed = LG.SPEED
	bot.recoverTime = LG.RECOVER_TIME
	bot.burstUntil = now + LG.BURST_TIME
	bot.dashUntil = now + LG.BURST_TIME + LG.RECOVER_TIME
	bot.faceAt = nil
	bot.human.AutoRotate = false
	faceToward(bot, dir, 120) -- swing round fast, through physics (no root.CFrame snap)
	bot.human.WalkSpeed = LG.SPEED
	bot.human:Move(dir, false)
	local t = bot.tracks.LungeStab
	if t then
		t:Play(0.05, 1, LG.ANIM_SPEED)
	end
	task.delay(LG.BURST_TIME, function()
		if bot.Character and bot:GetAttribute("EOS_Role") == "CATCHER" then
			CharacterService.slowFor(bot, LG.SLOW_FACTOR, LG.SLOW_TIME)
		end
	end)
	return true
end

local function randomDashes(bot: any, dir: Vector3, dt: number)
	if rng:NextNumber() < N.RANDOM_DASH_PER_SEC * dt then
		dash(bot, rotate(dir, if rng:NextNumber() < 0.5 then 70 else -70))
	end
end

-- stuck against something: sidestep for a moment
local function unstick(bot: any, b: any, dir: Vector3, now: number): Vector3
	local v = bot.root.AssemblyLinearVelocity
	if flat(v).Magnitude < 2 and now >= bot.dashUntil then
		b.stuckFor = (b.stuckFor or 0) + 1 / N.THINK_RATE
	else
		b.stuckFor = 0
	end
	if (b.stuckFor or 0) > 0.8 then
		b.stuckFor = 0
		b.unstickUntil = now + 0.7
		b.turnBias = if rng:NextNumber() < 0.5 then 1 else -1
		b.unstickDir = rotate(dir, 100 * b.turnBias)
	end
	if b.unstickUntil and now < b.unstickUntil then
		return b.unstickDir
	end
	return dir
end

-- ===== brains =====

local A = Layout.Arena

local function inZone(pos: Vector3): boolean
	return Layout.inBox(pos, Layout.Zones.A) or Layout.inBox(pos, Layout.Zones.B)
end

local function lobbyThink(bot: any, b: any, now: number, dt: number)
	setSpeed(bot, b.speed or N.LOBBY_WALK_SPEED)
	if b.pauseUntil == nil then
		-- just arrived in the lobby: most start out standing around
		b.pauseUntil = now + rng:NextNumber(0, N.LOBBY_STAND_MAX)
	end
	if now < b.pauseUntil then
		move(bot, nil)
		return
	end
	local pos = bot.root.Position
	if not b.goal or now > b.goalUntil or flat(b.goal - pos).Magnitude < 4 then
		if b.goal then
			-- got there (or gave up): mostly hang out a while before the next short stroll
			b.goal = nil
			if rng:NextNumber() < N.LOBBY_STAND_CHANCE then
				b.pauseUntil = now + rng:NextNumber(N.LOBBY_STAND_MIN, N.LOBBY_STAND_MAX)
				move(bot, nil)
				return
			end
		end
		-- a short stroll somewhere nearby (not across the whole lobby), inside the wander area
		local lo, hi = Layout.Lobby.WANDER_MIN, Layout.Lobby.WANDER_MAX
		local angle = rng:NextNumber(0, 2 * math.pi)
		local dist = rng:NextNumber(N.LOBBY_STROLL_MIN, N.LOBBY_STROLL_MAX)
		local g = pos + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		b.goal = Vector3.new(math.clamp(g.X, lo.X, hi.X), 0, math.clamp(g.Z, lo.Z, hi.Z))
		b.goalUntil = now + 12
		b.speed = N.LOBBY_WALK_SPEED * rng:NextNumber(0.85, 1.15) -- everyone walks, at their own pace
	end
	local dir = unit(flat(b.goal - pos), Vector3.new(0, 0, -1))
	dir = avoid(bot, pos, unstick(bot, b, dir, now))
	move(bot, dir)
end

type Ctx = {
	phase: string,
	wave: number,
	finishSide: string,
	timeLeft: number,
	runners: { any },
	catchers: { any },
	claims: { [number]: number }, -- Runner uid -> NPC Catchers going after them
}

-- HOS-PET-006: an invisible Catcher is only noticed inside its reveal radius (none = never)
local function unseen(c: any, d: number): boolean
	return c.hidden and (type(c.reveal) ~= "number" or d > c.reveal)
end

local function nearestCatcher(ctx: Ctx, pos: Vector3): (any?, number)
	local best, bestD = nil, math.huge
	for _, c in ipairs(ctx.catchers) do
		local d = flat(c.pos - pos).Magnitude
		if d < bestD and not unseen(c, d) then
			best, bestD = c, d
		end
	end
	return best, bestD
end

-- push away from same-role neighbours (bodies don't collide, so without this they stack into one)
local function separation(bot: any, pos: Vector3, list: { any }): Vector3
	local push = Vector3.zero
	for _, o in ipairs(list) do
		if o.uid ~= bot.UserId and not o.safe then
			local off = flat(pos - o.pos)
			local d = off.Magnitude
			if d < N.SEPARATION_RADIUS then
				if d < 0.05 then
					off = rotate(Vector3.xAxis, (bot.slot * 137) % 360) -- exactly on top: split a fixed way
					d = 0.05
				end
				push += off.Unit * (1 - d / N.SEPARATION_RADIUS)
			end
		end
	end
	return push
end

-- "<wave><side>" -> safe Runners already standing in that crossing's row
local safeSlots: { [string]: number } = {}
local lastWaveSeen = 0
-- Runner uid -> the last lunge a Catcher threw at them ({ at = os.clock(), dir = Vector3 })
local lungeThreat: { [any]: { at: number, dir: Vector3 } } = {}

local function runnerThink(bot: any, b: any, ctx: Ctx, now: number, dt: number)
	local pos = bot.root.Position
	local zone = Layout.Zones[ctx.finishSide]
	if bot:GetAttribute("EOS_Safe") == true then
		-- made it: take the next spot in the row on the line (filling out from the middle), then stand
		-- there facing back over the field, like the reference
		if b.safeWave ~= ctx.wave then
			b.safeWave = ctx.wave
			local key = tostring(ctx.wave) .. ctx.finishSide
			safeSlots[key] = (safeSlots[key] or 0) + 1
			b.safeSlot = safeSlots[key]
		end
		local k = b.safeSlot - 1
		local off = if k % 2 == 0 then k / 2 else -(k + 1) / 2 -- 0, -1, 1, -2, 2, ...
		local towardField = if zone.center.X < A.CENTER.X then 1 else -1
		local spot = Vector3.new(zone.center.X + towardField * (zone.size.X / 2 - N.SAFE_ROW_INSET), pos.Y, math.clamp(A.CENTER.Z + off * N.SAFE_ROW_SPACING, A.CENTER.Z - (A.HALF_Z - 4), A.CENTER.Z + (A.HALF_Z - 4)))
		local to = flat(spot - pos)
		if to.Magnitude > 1.2 then
			setSpeed(bot, N.LOBBY_WALK_SPEED * 1.6)
			bot.faceAt = nil
			move(bot, avoid(bot, pos, to.Unit))
		else
			setSpeed(bot, N.LOBBY_WALK_SPEED)
			move(bot, nil)
			bot.faceAt = Vector3.new(A.CENTER.X, pos.Y, spot.Z) -- look back over the field
		end
		return
	end
	bot.faceAt = nil
	setSpeed(bot, N.RUNNER_SPEED)
	if b.wave ~= ctx.wave then
		-- a new crossing: when to go, which lane, how much to weave
		b.wave = ctx.wave
		b.startAt = now + rng:NextNumber(0, N.START_DELAY_MAX)
		b.cautious = rng:NextNumber() < N.CAUTIOUS_SHARE
		-- keep roughly the lane it lined up in (everyone side by side, not one shared path)
		local here = pos.Z - A.CENTER.Z
		b.laneZ = math.clamp(here + rng:NextNumber(-N.LANE_JITTER, N.LANE_JITTER), -(A.HALF_Z - 10), A.HALF_Z - 10)
		b.weavePhase = rng:NextNumber(0, math.pi * 2)
		b.weaveAmp = rng:NextNumber(N.WEAVE_MIN, N.WEAVE_MAX)
	end
	local catcher, catcherD = nearestCatcher(ctx, pos)
	if now < b.startAt or (b.cautious and ctx.timeLeft > 12 and catcherD < 26 and inZone(pos)) then
		move(bot, nil)
		return
	end
	local goal = Vector3.new(zone.center.X, pos.Y, A.CENTER.Z + b.laneZ)
	local goalDir = unit(flat(goal - pos), Vector3.new(1, 0, 0))
	local side = Vector3.new(-goalDir.Z, 0, goalDir.X)
	local dir = goalDir + side * math.sin(now * 1.4 + b.weavePhase) * b.weaveAmp
	-- steer away from Catchers (stronger the closer they are)
	for _, c in ipairs(ctx.catchers) do
		local off = flat(pos - c.pos)
		local d = off.Magnitude
		if d > 0.01 and d < N.EVADE_RADIUS and not unseen(c, d) then
			dir += off.Unit * ((1 - d / N.EVADE_RADIUS) ^ 2) * N.EVADE_WEIGHT
		end
	end
	dir += separation(bot, pos, ctx.runners) * N.SEPARATION_WEIGHT
	dir = unit(dir, side)
	if dir:Dot(goalDir) < -0.2 and ctx.timeLeft < 10 then
		dir = unit(dir + goalDir * 1.6, goalDir) -- running out of time: commit
	end
	dir = avoid(bot, pos, unstick(bot, b, dir, now))
	-- a Catcher just lunged at me: most of the time, side-slide out of the way (like players juke dives)
	local threat = lungeThreat[bot.UserId]
	if threat and now - threat.at < 0.25 and b.dodgedAt ~= threat.at then
		b.dodgedAt = threat.at
		if rng:NextNumber() < N.LUNGE_DODGE_CHANCE then
			local perp = Vector3.new(-threat.dir.Z, 0, threat.dir.X)
			if perp:Dot(goalDir) < 0 then
				perp = -perp -- slide toward the finish side of the lunge
			end
			dash(bot, unit(perp + goalDir * 0.25, perp))
		end
	end
	-- juke a Catcher that's closing in: slide off to the side away from it
	if catcher and catcherD < N.JUKE_RADIUS then
		local closing = catcher.vel:Dot(unit(flat(pos - catcher.pos), Vector3.zero)) > 4
		if closing and rng:NextNumber() < N.JUKE_CHANCE * 0.35 then
			local away = flat(pos - catcher.pos)
			local perp = Vector3.new(-away.Z, 0, away.X)
			if perp:Dot(goalDir) < 0 then
				perp = -perp
			end
			dash(bot, unit(perp + goalDir * 0.3, goalDir))
		end
	end
	randomDashes(bot, dir, dt)
	move(bot, dir)
end

-- NPC Catchers (developer, Oct 15):
--  * no mobbing: at most N.MAX_PER_TARGET go after one Runner while others are free, and the ones
--    sharing a Runner come at them from different sides (flanks), never down the same path
--  * squared up: facing the Runner, they shuffle sideways (and walk back) to stay between the Runner and
--    the finish, like a defender. They only turn and run straight at a Runner who got past them.
--  * same-role separation keeps every Catcher its own body
local FLANKS = { 0, -1, 1, -2, 2 }

local function validTarget(r: any): boolean
	-- an invisible Runner (Invisibility pets) drops off the NPC Catchers' radar until it shows again
	return r ~= nil and not r.safe and not r.hidden and not inZone(r.pos)
end

-- uid -> os.clock() a Runner was last seen mid-dash (Npc.DASH_FAKE_TIME)
local dashSeenAt: { [any]: number } = {}

local function catcherThink(bot: any, b: any, ctx: Ctx, now: number, dt: number)
	local pos = bot.root.Position
	if bot:GetAttribute("EOS_Held") == true then
		-- held on the line until just after the Runners go: stand, facing them
		bot.faceAt = nil
		setSpeed(bot, 0)
		move(bot, nil)
		return
	end
	local fwd = if Layout.Zones[ctx.finishSide].center.X > A.CENTER.X then 1 else -1 -- the way Runners go
	local target = nil
	for _, r in ipairs(ctx.runners) do
		if r.uid == b.target then
			target = r
		end
	end
	if not validTarget(target) or not b.retargetAt or now >= b.retargetAt then
		b.retargetAt = now + rng:NextNumber(0.7, 1.1)
		local mine = if validTarget(target) then b.target else nil
		local best, bestScore, bestClaims = nil, math.huge, 0
		for _, r in ipairs(ctx.runners) do
			if validTarget(r) then
				local claims = (ctx.claims[r.uid] or 0) - (if r.uid == b.target then 1 else 0)
				local score = flat(r.pos - pos).Magnitude * (if r.human then N.HUMAN_PREFERENCE else 1) + claims * N.CLAIM_PENALTY
				if claims >= N.MAX_PER_TARGET then
					score += 1000 -- full: only if nobody else is left to chase
				end
				if r.uid == mine then
					score -= 6 -- a little stickiness: no flip-flopping between two Runners
				end
				if score < bestScore then
					best, bestScore, bestClaims = r, score, claims
				end
			end
		end
		local newId = if best then best.uid else nil
		if newId ~= b.target then
			if b.target and ctx.claims[b.target] then
				ctx.claims[b.target] = math.max(0, ctx.claims[b.target] - 1)
			end
			if newId then
				ctx.claims[newId] = (ctx.claims[newId] or 0) + 1
			end
			-- first one on a Runner comes straight; the next ones take a side each
			local f = FLANKS[(bestClaims % #FLANKS) + 1]
			b.flank = if bot.slot % 2 == 1 then -f else f
		end
		b.target = newId
		target = best
	end

	local dir: Vector3? = nil
	local face: Vector3? = nil
	local faked = target ~= nil and now < (target.fakedUntil or 0)
	if target and not faked then
		b.lastSeen = target.pos
	end
	if target and faked and b.lastSeen then
		-- faked out by a dash: keep going for where they were; no lunge, no stab until it wears off
		local off = flat(b.lastSeen - pos)
		if off.Magnitude > 1.5 then
			dir = off.Unit
		end
		face = b.lastSeen
	elseif target then
		local toT = flat(target.pos - pos)
		local d = toT.Magnitude
		local past = (target.pos.X - pos.X) * fwd > N.PAST_MARGIN
		if past then
			-- got past me: turn and run them down (this is the only straight-line chase)
			local lead = target.vel * (N.CHASE_PREDICT + math.min(d / 60, 0.5))
			local aim = target.pos + lead + Vector3.new(0, 0, (b.flank or 0) * 3)
			dir = unit(flat(aim - pos), unit(toT, Vector3.xAxis))
		elseif d < N.CLOSE_IN_RADIUS then
			-- close: step in for the stab, still facing them
			dir = unit(toT + target.vel * 0.15, Vector3.xAxis)
			face = target.pos
		else
			-- squared up: hold a spot between them and the finish, on my flank, mirroring their sidesteps
			local ahead = math.clamp(d * 0.5, N.GUARD_AHEAD_MIN, N.GUARD_AHEAD_MAX)
			local guard = target.pos + Vector3.new(fwd * ahead, 0, (b.flank or 0) * N.FLANK_SPACING + target.vel.Z * 0.4)
			local off = flat(guard - pos)
			if off.Magnitude > 1.5 then
				dir = off.Unit
			end
			face = target.pos
		end
		if d < 5 then
			swing(bot, target.pos) -- close: the jab (no cost)
		elseif d >= LG.NPC_MIN_RANGE and d <= LG.NPC_MAX_RANGE and math.abs(target.pos.Y - pos.Y) < 4 then
			-- in lunge range: lunge at where they're going
			local ldir = unit(flat(target.pos + target.vel * 0.2 - pos), unit(toT, Vector3.xAxis))
			if lunge(bot, ldir) then
				lungeThreat[target.uid] = { at = now, dir = ldir } -- an NPC Runner may side-slide out of it
				move(bot, nil) -- (the burst drives the body; stepDashes)
				return
			end
		end
	else
		-- nobody to chase: spread out across the middle of the field, watching the Runners
		if not b.patrol or now > b.patrolUntil or flat(b.patrol - pos).Magnitude < 4 then
			local lane = ((bot.slot % 7) - 3) * 16
			b.patrol = A.CENTER + Vector3.new(rng:NextNumber(-12, 12), 0, math.clamp(lane + rng:NextNumber(-5, 5), -(A.HALF_Z - 8), A.HALF_Z - 8))
			b.patrolUntil = now + rng:NextNumber(4, 7)
		end
		local off = flat(b.patrol - pos)
		if off.Magnitude > 2 then
			dir = off.Unit
		end
		local near = nil
		local nearD = math.huge
		for _, r in ipairs(ctx.runners) do
			local dd = flat(r.pos - pos).Magnitude
			if dd < nearD then
				near, nearD = r, dd
			end
		end
		face = if near and nearD < 60 then near.pos else nil
	end

	-- keep my own space (no stacking into one body)
	local sep = separation(bot, pos, ctx.catchers)
	if sep.Magnitude > 0.05 then
		dir = unit((dir or Vector3.zero) + sep * N.SEPARATION_WEIGHT, sep.Unit)
	end
	local speedMul = 1
	if dir then
		dir = avoid(bot, pos, unstick(bot, b, dir, now))
		if face then
			local look = flat(face - pos)
			if look.Magnitude > 0.5 and dir:Dot(look.Unit) < -0.35 then
				speedMul = N.BACKPEDAL_FRACTION -- walking backwards is slower, as for players
			end
		end
	end
	bot.faceAt = face
	setSpeed(bot, N.CATCHER_SPEED * speedMul)
	move(bot, dir)
end

-- caught this crossing: walk off to the nearest sideline and watch until the next one
local function caughtThink(bot: any, b: any)
	setSpeed(bot, N.LOBBY_WALK_SPEED)
	local pos = bot.root.Position
	if not b.sideline then
		local side = if pos.Z >= A.CENTER.Z then 1 else -1
		b.sideline = Vector3.new(pos.X, pos.Y, A.CENTER.Z + side * (A.HALF_Z - 5))
	end
	local off = flat(b.sideline - pos)
	if off.Magnitude < 3 then
		move(bot, nil)
	else
		move(bot, avoid(bot, pos, off.Unit))
	end
end

local function matchContext(m: any): Ctx?
	if not m or not m.roster or not m.logic then
		return nil
	end
	local ends = state:GetAttribute("PhaseEndsAt") or 0
	local ctx: Ctx = {
		phase = state:GetAttribute("Phase") or "",
		wave = state:GetAttribute("Wave") or 0,
		finishSide = state:GetAttribute("FinishSide") or "B",
		timeLeft = ends - workspace:GetServerTimeNow(),
		runners = {},
		catchers = {},
		claims = {},
	}
	-- a new match restarts the crossing count: start the safe rows over
	if ctx.wave < lastWaveSeen then
		table.clear(safeSlots)
	end
	lastWaveSeen = ctx.wave
	for _, bot in ipairs(bots) do
		local t = bot.brain and bot.brain.target
		if t and bot:GetAttribute("EOS_Role") == "CATCHER" then
			ctx.claims[t] = (ctx.claims[t] or 0) + 1
		end
	end
	for uid, actor in pairs(m.roster) do
		local p = m.logic:get(uid)
		local char = actor.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if p and not p.disconnected and hrp then
			local entry = { uid = uid, pos = hrp.Position, vel = flat(hrp.AssemblyLinearVelocity), human = not NpcService.isBot(actor), safe = p.isSafeThisWave, fakedUntil = 0, hidden = char:GetAttribute("EOS_Invisible") == true, reveal = char:GetAttribute("EOS_InvisibleReveal") }
			if p.role == "RUNNER" then
				-- mid-dash (much faster than a run): Catchers on this Runner get faked out for a moment
				local now = os.clock()
				if entry.vel.Magnitude > N.RUNNER_SPEED * N.DASH_SEEN_SPEED then
					dashSeenAt[uid] = now
				end
				local seen = dashSeenAt[uid]
				if seen and now - seen < N.DASH_FAKE_TIME then
					entry.fakedUntil = seen + N.DASH_FAKE_TIME
					entry.vel = Vector3.zero -- no lead read off the dash
				end
				table.insert(ctx.runners, entry)
			elseif p.role == "CATCHER" then
				table.insert(ctx.catchers, entry)
			end
		end
	end
	return ctx
end

local function think(dt: number)
	local now = os.clock()
	local ctx = if matchRef then matchContext(matchRef) else nil
	-- raycasts ignore every character
	local ignore: { Instance } = { folder() }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
	for _, bot in ipairs(bots) do
		if bot.Character and bot.Character.Parent and bot.human.Health > 0 then
			local b = bot.brain
			bot.faceAt = nil -- only a Catcher's brain squares the body up to someone; it sets this again
			if bot:GetAttribute("EOS_Role") ~= "CATCHER" then
				b.target = nil
			end
			if bot.kind == "LOBBY" then
				lobbyThink(bot, b, now, dt)
			elseif ctx and ctx.phase == "CROSSING" and bot:GetAttribute("EOS_InMatch") == true then
				local role = bot:GetAttribute("EOS_Role")
				if role == "RUNNER" then
					runnerThink(bot, b, ctx, now, dt)
				elseif role == "CATCHER" then
					b.sideline = nil
					catcherThink(bot, b, ctx, now, dt)
				elseif role == "CAUGHT" then
					caughtThink(bot, b)
				else
					move(bot, nil)
				end
			else
				-- role reveal, between crossings, results: stand still
				move(bot, nil)
			end
			animate(bot)
		end
	end
end

-- per frame: dash bursts and the ease back down
local function stepDashes()
	local now = os.clock()
	for _, bot in ipairs(bots) do
		if bot.dashUntil > 0 then
			local burst = bot.burstSpeed or D.SPEED -- (a Catcher's lunge sets its own)
			if now < bot.burstUntil then
				bot.human.WalkSpeed = burst
				bot.human:Move(bot.dashDir, false)
			elseif now < bot.dashUntil then
				local t = (now - bot.burstUntil) / math.max(bot.recoverTime or D.RECOVER_TIME, 0.01)
				local base = if bot.kind == "LOBBY" then (bot.brain.speed or N.LOBBY_WALK_SPEED) elseif bot:GetAttribute("EOS_Role") == "CATCHER" then N.CATCHER_SPEED * LG.SLOW_FACTOR else N.RUNNER_SPEED
				bot.human.WalkSpeed = burst + (base - burst) * t
			else
				bot.dashUntil = 0
				bot.burstSpeed, bot.recoverTime = nil, nil
				faceToward(bot, nil)
				bot.human.AutoRotate = true
			end
		end
	end
end

-- per frame: a Catcher squared up to a Runner turns to face them (it moves sideways / backwards
-- underneath); everyone else faces the way they move (AutoRotate)
local function stepFacing(dt: number)
	local now = os.clock()
	for _, bot in ipairs(bots) do
		local root, hum = bot.root, bot.human
		if root and root.Parent and hum and now >= bot.dashUntil and bot.dashUntil == 0 then
			local at = bot.faceAt
			local st = hum:GetState()
			if at and st ~= Enum.HumanoidStateType.Physics and st ~= Enum.HumanoidStateType.Dead then
				if hum.AutoRotate then
					hum.AutoRotate = false
				end
				local p = root.Position
				local look = Vector3.new(at.X - p.X, 0, at.Z - p.Z)
				if look.Magnitude > 0.5 then
					faceToward(bot, look, N.FACE_RATE * 2) -- physics turn (no per-frame root.CFrame writes)
				end
			elseif not at then
				faceToward(bot, nil)
				if not hum.AutoRotate then
					hum.AutoRotate = true
				end
			end
		end
	end
end

-- ===== lobby head-count =====

local function lobbyCount(): number
	local n = 0
	for _, bot in ipairs(bots) do
		if bot.kind == "LOBBY" then
			n += 1
		end
	end
	return n
end

local function balanceLobby()
	local want = if N.ENABLED then math.max(0, N.LOBBY_TARGET - #Players:GetPlayers()) else 0
	while lobbyCount() < want do
		local spot = Layout.Lobby.SPAWN + Vector3.new(rng:NextNumber(-20, 20), 0, rng:NextNumber(-24, 4))
		if not NpcService.spawn("LOBBY", spot, Layout.Lobby.CENTERPIECE) then
			break
		end
	end
	while lobbyCount() > want do
		for i = #bots, 1, -1 do
			if bots[i].kind == "LOBBY" then
				NpcService.despawn(bots[i])
				break
			end
		end
	end
end

function NpcService.init()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		stepDashes()
		stepFacing(dt)
		acc += dt
		local step = 1 / N.THINK_RATE
		if acc >= step then
			local elapsed = acc
			acc = 0
			think(elapsed)
		end
	end)
	require(script.Parent.NpcEmotes).init(NpcService) -- HOS-BOT-002 lobby NPC emotes (Npc.LOBBY_EMOTES)
	Players.PlayerAdded:Connect(balanceLobby)
	Players.PlayerRemoving:Connect(function()
		task.defer(balanceLobby)
	end)
	task.spawn(function()
		while true do
			balanceLobby()
			task.wait(2)
		end
	end)
end

return NpcService
