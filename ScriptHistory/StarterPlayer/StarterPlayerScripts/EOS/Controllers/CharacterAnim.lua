-- CharacterAnim: plays the developer's picked clips on the local character, and turns every
-- player's head toward where that player's camera looks.
--  * locomotion by speed: WalkSlow (#2) -> WalkFast (#1) -> Run (#8), playback rate matched to
--    the real ground speed; Roblox's R6 idle when standing, its fall clip when airborne
--  * Catchers (camera-facing): sideways movement plays StrafeLeft/Right (#4/#5). Runners face their
--    movement, so they never strafe. Walking backwards in a match (anyone, S) plays WalkFast in reverse;
--    back-left / back-right (S+A, S+D) play the side walks #4 / #5.
--  * dash: DashBack / DashLeft / DashRight on Movement's dash event (no forward dash)
--  * the Catcher's hit (Tag swing): a full-body lunge stab, SwingJab (the developer's "knife attack"
--    clip: torso, legs, head, both arms and the knife), played over everything. Moving, the run takes
--    the legs back right after the thrust (GameConfig.Stab.MOVING_FADE_AT) so the lunge stance doesn't
--    slide along; standing still it plays out and fades by Stab.END_FADE_AT. Looks only: the hit itself
--    is decided on the click (Tag), from the body's centre. The arm is turned about the
--    shoulder so the strike goes where the camera aims (up, down, left, right; clamped), for every
--    Catcher on every screen, NPCs included. (SwingSlash, the old arms-only backhand, is no longer used.)
--  * head look (in a match only): the body keeps its facing while the head turns toward the camera,
--    side to side and up and down (clamped). The angles go to the server a few times a second and
--    come back as character attributes, so other players see it too. Purely cosmetic.
-- Clip ids: Shared/AnimConfig (published ids); Studio playtests fall back to temporary ids
-- registered from ReplicatedStorage.EOS_Animations.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local AnimConfig = require(Shared:WaitForChild("AnimConfig"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Movement = require(script.Parent.Movement)
local Tag = require(script.Parent.Tag)

local H = GameConfig.HeadLook
local CharacterAnim = {}

local player = Players.LocalPlayer
local idCache: { [string]: string } = {}
local warned: { [string]: boolean } = {}

-- published id, else (Studio only) a temporary id for the KeyframeSequence
local function resolve(slot: string): string?
	local published = AnimConfig.ids[slot]
	if published and published ~= "" then
		return published
	end
	if idCache[slot] then
		return idCache[slot]
	end
	if not RunService:IsStudio() then
		if not warned[slot] then
			warned[slot] = true
			warn("[EOS] animation '" .. slot .. "' has no published id yet (Shared/AnimConfig)")
		end
		return nil
	end
	local lib = ReplicatedStorage:WaitForChild(AnimConfig.LIBRARY, 10)
	local seq = lib and lib:FindFirstChild(slot)
	if not seq then
		return nil
	end
	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(seq)
	end)
	if ok and id then
		idCache[slot] = id
		return id
	end
	warn("[EOS] could not register clip " .. slot .. ": " .. tostring(id))
	return nil
end

local LOOPS = { "Idle", "Fall", "WalkSlow", "WalkFast", "Run", "StrafeLeft", "StrafeRight" }
local DASHES = { Back = "DashBack", Left = "DashLeft", Right = "DashRight" }
-- the Catcher's hit: the full-body lunge stab (more slots here would take turns)
local SWINGS = { "SwingJab" }
local nextSwing = 1
local ST = GameConfig.Stab

type Rig = {
	character: Model,
	human: Humanoid,
	root: BasePart,
	tracks: { [string]: AnimationTrack },
	weights: { [string]: number },
	airTime: number,
}
local rig: Rig? = nil

local function load(animator: Animator, slot: string, id: string?): AnimationTrack?
	if not id then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.Name = "EOS_" .. slot
	anim.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	return if ok then track else nil
end

local function bindLocal(character: Model)
	rig = nil
	local human = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not human or not root or player.Character ~= character then
		return
	end
	-- our controller replaces Roblox's default Animate script
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		animate.Enabled = false
	end
	local animator = human:FindFirstChildOfClass("Animator") or Instance.new("Animator", human)
	for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
		t:Stop(0)
	end
	local tracks = {}
	for _, slot in ipairs(LOOPS) do
		local id = if slot == "Idle" or slot == "Fall" then AnimConfig.builtin[slot] else resolve(slot)
		local t = load(animator, slot, id)
		if t then
			t.Looped = true
			t.Priority = if slot == "Idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Movement
			t:Play(0, 0.0001, 1)
			tracks[slot] = t
		end
	end
	for _, slot in pairs(DASHES) do
		local t = load(animator, slot, resolve(slot))
		if t then
			t.Looped = false
			t.Priority = Enum.AnimationPriority.Action
			tracks[slot] = t
		end
	end
	for _, slot in ipairs(SWINGS) do
		local t = load(animator, slot, resolve(slot))
		if t then
			t.Looped = false
			t.Priority = Enum.AnimationPriority.Action2 -- above the dash clips
			tracks[slot] = t
		end
	end
	-- the Catcher's lunge (Space): the two-handed overhead stab, over everything
	local lt = load(animator, "LungeStab", resolve("LungeStab"))
	if lt then
		lt.Looped = false
		lt.Priority = Enum.AnimationPriority.Action2
		tracks.LungeStab = lt
	end
	rig = { character = character, human = human, root = root, tracks = tracks, weights = {}, airTime = 0 }
end

local function setWeight(r: Rig, slot: string, w: number)
	local t = r.tracks[slot]
	if not t then
		return
	end
	if math.abs((r.weights[slot] or -1) - w) > 0.001 then
		r.weights[slot] = w
		t:AdjustWeight(math.max(w, 0.0001), AnimConfig.FADE)
	end
end

local function setRate(r: Rig, slot: string, rate: number)
	local t = r.tracks[slot]
	if t and math.abs(t.Speed - rate) > 0.03 then
		t:AdjustSpeed(rate)
	end
end

local function rateFor(slot: string, speed: number): number
	local natural = AnimConfig.naturalSpeed[slot] or 10
	local rate = speed / natural
	if slot == "Run" then
		-- live tuning knob (ReplicatedStorage.EOS_Tuning.RunAnimRate) on top of speed matching
		local tuning = ReplicatedStorage:FindFirstChild("EOS_Tuning")
		local k = tuning and tuning:GetAttribute("RunAnimRate")
		rate *= if type(k) == "number" then k else 1
	end
	return math.clamp(rate, AnimConfig.RATE_MIN, AnimConfig.RATE_MAX)
end

-- the stab playing now (to fade its recovery out) and when it started
local stabTrack: AnimationTrack? = nil
local stabAt = -math.huge

local function endStab(fade: number)
	local t = stabTrack
	stabTrack = nil
	if t and t.IsPlaying then
		t:Stop(fade)
	end
end

local function updateLocal(dt: number)
	local r = rig
	if not r or not r.character:IsDescendantOf(workspace) or r.human.Health <= 0 then
		return
	end
	local v = r.root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = flat.Magnitude
	-- moving: the thrust is done, the run takes the legs back (the Catcher never slows for the stab)
	if stabTrack and os.clock() - stabAt >= ST.MOVING_FADE_AT and (speed > AnimConfig.IDLE_BELOW or Movement.wishDir().Magnitude > 0.1) then
		endStab(ST.MOVING_FADE)
	end
	local airborne = r.human.FloorMaterial == Enum.Material.Air
	r.airTime = if airborne then r.airTime + dt else 0
	local want: { [string]: number } = {}
	if r.airTime > 0.25 then
		want.Fall = 1
	elseif speed < AnimConfig.IDLE_BELOW then
		want.Idle = 1
	else
		local slot = if speed >= AnimConfig.RUN_FROM then "Run" elseif speed >= AnimConfig.WALK_FAST_FROM then "WalkFast" else "WalkSlow"
		local rate = rateFor(slot, speed)
		if Movement.backpedaling and flat:Dot(r.root.CFrame.LookVector) < 0 then
			-- walking backwards (facing the camera): straight back = the walk clip in reverse; back-left /
			-- back-right (S+A, S+D) = the side walks #4 / #5 (the pack has no back-diagonal walk)
			local rel = r.root.CFrame:VectorToObjectSpace(flat)
			if math.abs(math.atan2(rel.X, -rel.Z)) >= AnimConfig.BACK_STRAIGHT_FROM then
				slot, rate = "WalkFast", -rateFor("WalkFast", speed)
			else
				slot = if rel.X > 0 then "StrafeRight" else "StrafeLeft"
				rate = rateFor(slot, speed)
			end
		elseif Movement.facingMode == "CAMERA" then
			-- Catchers face the camera: pick by the angle between movement and facing
			local rel = r.root.CFrame:VectorToObjectSpace(flat)
			local angle = math.abs(math.atan2(rel.X, -rel.Z))
			if angle >= AnimConfig.BACKPEDAL_FROM then
				slot, rate = "WalkFast", -rateFor("WalkFast", speed)
			elseif angle >= AnimConfig.STRAFE_FROM then
				slot = if rel.X > 0 then "StrafeRight" else "StrafeLeft"
				rate = rateFor(slot, speed)
			end
		end
		want[slot] = 1
		setRate(r, slot, rate)
	end
	for _, slot in ipairs(LOOPS) do
		setWeight(r, slot, want[slot] or 0)
	end
end

local function playDash(side: string)
	local r = rig
	local slot = DASHES[side]
	local t = r and slot and r.tracks[slot]
	if t then
		endStab(0.08) -- (Catchers can't dash; a Runner never has a stab playing)
		t:Play(0.05, 1, GameConfig.Dash.ANIM_SPEED)
	end
end

local localSwingAt = -math.huge

-- the lunge: plays through the strike and the hold; moving after that, the run takes the legs back
local LUNGE_HOLD_UNTIL = 0.42 -- seconds into the clip (after the impact hold)
local lungeTrack: AnimationTrack? = nil
local lungeAt = -math.huge
local function playLunge()
	local r = rig
	local t = r and r.tracks.LungeStab
	if not t then
		return
	end
	endStab(0.05)
	t:Play(0.05, 1, GameConfig.Lunge.ANIM_SPEED)
	lungeTrack, lungeAt = t, os.clock()
end
local function updateLunge()
	local t = lungeTrack
	if not t or not rig then
		return
	end
	if not t.IsPlaying then
		lungeTrack = nil
		return
	end
	local v = rig.root.AssemblyLinearVelocity
	local moving = Vector3.new(v.X, 0, v.Z).Magnitude > AnimConfig.IDLE_BELOW or Movement.wishDir().Magnitude > 0.1
	if moving and os.clock() - lungeAt >= LUNGE_HOLD_UNTIL then
		t:Stop(0.18)
		lungeTrack = nil
	end
end

local function playSwing()
	local r = rig
	if not r then
		return
	end
	local now = os.clock()
	localSwingAt = now
	local slot = SWINGS[nextSwing]
	nextSwing = nextSwing % #SWINGS + 1
	local t = r.tracks[slot]
	if t then
		for _, other in ipairs(SWINGS) do
			local o = r.tracks[other]
			if o and o ~= t and o.IsPlaying then
				o:Stop(0.05)
			end
		end
		t:Play(0.04, 1, 1)
		stabTrack, stabAt = t, now
		-- standing still it plays out: fade it once it has settled rather than snap at its last frame
		task.delay(ST.END_FADE_AT, function()
			if stabTrack == t and stabAt == now then
				endStab(0.2)
			end
		end)
	end
end

-- ===== head look =====

local baseNeck: { [Motor6D]: CFrame } = {}
local shownLook: { [Model]: Vector2 } = {} -- X = yaw, Y = pitch (radians, eased)
local lastSent, lastSentAt = Vector2.zero, 0
local SETTLE_TIME = 0.5 -- a small leftover change is still sent once the head has held still this long

local function neckOf(character: Model): Motor6D?
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	local head = character:FindFirstChild("Head")
	local neck = (torso and torso:FindFirstChild("Neck")) or (head and head:FindFirstChild("Neck"))
	return if neck and neck:IsA("Motor6D") then neck else nil
end

-- the head is held on the camera's direction in the world, so the run clip's lean and bob don't
-- drag it off; when the body tilts a lot (the forward dive) the head goes along with the body instead
local HOLD_FULL_UNTIL = math.rad(25) -- body tilt (from upright) with the head fully held
local HOLD_NONE_FROM = math.rad(45) -- body tilt where the head simply follows the body

local function applyHead(character: Model, look: Vector2, dt: number)
	local neck = neckOf(character)
	local torso = neck and neck.Part0
	local root = character:FindFirstChild("HumanoidRootPart")
	if not neck or not torso or not root or not root:IsA("BasePart") then
		return
	end
	local base = baseNeck[neck]
	if not base then
		base = neck.C0
		baseNeck[neck] = base
	end
	local shown = shownLook[character] or Vector2.zero
	shown += (look - shown) * (1 - math.exp(-dt * 12))
	shownLook[character] = shown
	-- turn about the body's up axis, then tilt about the head's own side axis
	local turn = CFrame.fromEulerAnglesYXZ(shown.Y, shown.X, 0)
	local followBody = turn * base.Rotation
	local tilt = math.acos(math.clamp(torso.CFrame.UpVector:Dot(root.CFrame.UpVector), -1, 1))
	local hold = math.clamp((HOLD_NONE_FROM - tilt) / (HOLD_NONE_FROM - HOLD_FULL_UNTIL), 0, 1)
	local rotation = followBody
	if hold > 0 then
		-- head rotation = root rotation * turn: undo the torso's animated rotation and the clip's own neck motion
		local held = torso.CFrame.Rotation:Inverse() * root.CFrame.Rotation * turn * neck.C1.Rotation * neck.Transform.Rotation:Inverse()
		rotation = if hold >= 1 then held else followBody:Lerp(held, hold)
	end
	neck.C0 = CFrame.new(base.Position) * rotation
end

-- where this player's camera looks, relative to their body (the upright root): (yaw, pitch), clamped
local function localLook(character: Model): Vector2?
	local root = character:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not root or not cam or not root:IsA("BasePart") then
		return nil
	end
	local look = root.CFrame:VectorToObjectSpace(cam.CFrame.LookVector)
	local flat = Vector3.new(look.X, 0, look.Z)
	local yaw = if flat.Magnitude < 0.05 then 0 else math.atan2(-flat.X, -flat.Z)
	-- looking far behind: face forward again instead of an owl twist
	if math.abs(yaw) > math.rad(150) then
		return Vector2.zero
	end
	local pitch = math.asin(math.clamp(look.Y, -1, 1))
	return Vector2.new(math.clamp(yaw, -H.MAX_YAW, H.MAX_YAW), math.clamp(pitch, -H.MAX_PITCH_DOWN, H.MAX_PITCH_UP))
end

-- ===== hit aim: the swing goes where the Catcher's camera points =====
-- While a hit plays, the whole right arm (and the knife with it) is turned about the shoulder so the
-- clip's forward strike points at the aim: your own crosshair live, or for everyone else the direction
-- the server got with their swing (humanoid attributes EOS_SwingAt + EOS_SwingAim; NPC Catchers aim at
-- the Runner they swing at). Fades in during the wind-up, holds through the thrust (the knife at full
-- reach at GameConfig.Stab.STRIKE_TIME), out as the knife is pulled back (or the run takes over).
-- The lunge twists and leans the whole torso, so the turn is worked out against the BODY (the upright
-- root, which the clip strikes straight ahead of), then applied about the shoulder in the chest's frame.
local CAP = GameConfig.Capture
local AIM_IN, AIM_HOLD, AIM_OUT = 0.1, 0.22, 0.35 -- seconds into the hit
local baseShoulder: { [Motor6D]: CFrame } = {}

local function aimWeight(age: number): number
	if age < 0 or age >= AIM_OUT then
		return 0
	elseif age < AIM_IN then
		return age / AIM_IN
	elseif age <= AIM_HOLD then
		return 1
	end
	local t = (age - AIM_HOLD) / (AIM_OUT - AIM_HOLD)
	return 1 - t * t * (3 - 2 * t)
end

local function shoulderOf(character: Model): Motor6D?
	local torso = character:FindFirstChild("Torso")
	local m = torso and torso:FindFirstChild("Right Shoulder")
	return if m and m:IsA("Motor6D") then m else nil
end

-- aim: world direction (from the shoulder) or nil; w: 0..1
local function applyArm(character: Model, aim: Vector3?, w: number)
	local m = shoulderOf(character)
	local torso = m and m.Part0
	if not m or not torso then
		return
	end
	local base = baseShoulder[m]
	if not base then
		base = m.C0
		baseShoulder[m] = base
	end
	if w <= 0.001 or not aim then
		if m.C0 ~= base then
			m.C0 = base
		end
		return
	end
	-- the aim against the body (the clip strikes straight ahead of the root, whatever the torso does)
	local root = character:FindFirstChild("HumanoidRootPart")
	local frame = if root and root:IsA("BasePart") then root.CFrame.Rotation else torso.CFrame.Rotation
	local d = frame:VectorToObjectSpace(aim)
	local flat = Vector3.new(d.X, 0, d.Z)
	local yaw = if flat.Magnitude < 0.05 then 0 else math.atan2(-flat.X, -flat.Z)
	local pitch = math.asin(math.clamp(d.Y / math.max(d.Magnitude, 1e-3), -1, 1))
	yaw = math.clamp(yaw, -CAP.ARM_MAX_YAW, CAP.ARM_MAX_YAW) * w
	pitch = math.clamp(pitch, -CAP.ARM_MAX_DOWN, CAP.ARM_MAX_UP) * w
	-- that turn is about the body's axes; carry it into the chest's frame and turn the arm about the
	-- shoulder with it: the clip's straight-ahead strike now points along the aim
	local turnWorld = frame * CFrame.fromEulerAnglesYXZ(pitch, yaw, 0) * frame:Inverse()
	local turnChest = torso.CFrame.Rotation:Inverse() * turnWorld * torso.CFrame.Rotation
	m.C0 = CFrame.new(base.Position) * turnChest * base.Rotation
end

local function shoulderWorld(character: Model): Vector3?
	local m = shoulderOf(character)
	local torso = m and m.Part0
	if not m or not torso then
		return nil
	end
	local base = baseShoulder[m] or m.C0
	return (torso.CFrame * base).Position
end

-- someone else's (or an NPC's) hit, from the attributes the server set
local function remoteAim(character: Model): (Vector3?, number)
	local human = character:FindFirstChildOfClass("Humanoid")
	local at = human and human:GetAttribute("EOS_SwingAt")
	local dir = human and human:GetAttribute("EOS_SwingAim")
	if type(at) ~= "number" or typeof(dir) ~= "Vector3" then
		return nil, 0
	end
	return dir, aimWeight(workspace:GetServerTimeNow() - at)
end

local function updateArms()
	for _, plr in ipairs(Players:GetPlayers()) do
		local character = plr.Character
		if character then
			if plr == player then
				local w = aimWeight(os.clock() - localSwingAt)
				local from = if w > 0 then shoulderWorld(character) else nil
				applyArm(character, if from then Tag.aimFrom(from) else nil, w)
			else
				applyArm(character, remoteAim(character))
			end
		end
	end
	local runtime = workspace:FindFirstChild("EOS_Runtime")
	local npcs = runtime and runtime:FindFirstChild("Npcs")
	if npcs then
		for _, m in ipairs(npcs:GetChildren()) do
			if m:IsA("Model") then
				applyArm(m, remoteAim(m))
			end
		end
	end
	for m in pairs(baseShoulder) do
		if not m.Parent then
			baseShoulder[m] = nil
		end
	end
end

local function updateHeads(dt: number)
	local now = os.clock()
	updateArms()
	for _, plr in ipairs(Players:GetPlayers()) do
		local character = plr.Character
		local human = character and character:FindFirstChildOfClass("Humanoid")
		if character and human and human.Health > 0 then
			local look: Vector2
			-- heads only follow the camera during a match (the lobby looks where you walk)
			local inMatch = plr:GetAttribute("EOS_InMatch") == true
			if plr == player then
				look = if inMatch then (localLook(character) or Vector2.zero) else Vector2.zero
				local diff = look - lastSent
				local change = math.max(math.abs(diff.X), math.abs(diff.Y))
				local due = now - lastSentAt >= 1 / H.SEND_RATE
				if due and (change >= H.MIN_CHANGE or (change > math.rad(0.5) and now - lastSentAt >= SETTLE_TIME)) then
					lastSent, lastSentAt = look, now
					Net.event("RequestLook"):FireServer(math.floor(look.X * 50 + 0.5) / 50, math.floor(look.Y * 50 + 0.5) / 50)
				end
			else
				local yaw = human:GetAttribute("EOS_HeadYaw")
				local pitch = human:GetAttribute("EOS_HeadPitch")
				look = if inMatch
					then Vector2.new(if type(yaw) == "number" then yaw else 0, if type(pitch) == "number" then pitch else 0)
					else Vector2.zero
			end
			applyHead(character, look, dt)
		end
	end
	for character in pairs(shownLook) do
		if not character.Parent then
			shownLook[character] = nil
		end
	end
	for neck in pairs(baseNeck) do
		if not neck.Parent then
			baseNeck[neck] = nil
		end
	end
end

function CharacterAnim.init()
	player.CharacterAdded:Connect(function(c)
		task.spawn(bindLocal, c)
	end)
	if player.Character then
		task.spawn(bindLocal, player.Character)
	end
	Movement.onDash(playDash)
	Tag.addSwingListener(playSwing)
	Tag.addLungeListener(playLunge)
	RunService.Heartbeat:Connect(function(dt)
		updateLocal(dt)
		updateLunge()
	end)
	RunService:BindToRenderStep("EOS_HeadLook", Enum.RenderPriority.Character.Value + 1, updateHeads)
end

return CharacterAnim
