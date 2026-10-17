--!strict
-- CatcherGesture (HOS-HOC-001, 17 Oct, Hunter: "the lead catcher should probably do an animation of some sort
-- as well when he's picking"). Server-side, so every screen sees it (players' and NPCs' bodies alike):
--   consider(actor)          while the Catcher chooses: a looping "considering" pose (hand up at the chin,
--                            head slowly scanning the Runner line)
--   point(actor, targetPos)  on the pick: the Catcher turns smoothly to face the picked Runner and holds a point
--   stop(actor)              back to normal (crossing start, timeout, leave, death)
-- Clips are R6 KeyframeSequences authored here (the game has no point / think emote). A published id in
-- HeroChickenConfig.Gesture (CONSIDER_ID / POINT_ID) always wins. Without one:
--   point     procedural, on every server: the root turns to the Runner and the right shoulder Motor6D's C0
--             is tweened so the arm aims straight at their HumanoidRootPart. C0 set on the server replicates
--             to every client (17 Oct: Hunter wasn't seeing the point, because unpublished clips only play in Studio).
--   consider  Studio only: the sequence is registered locally (KeyframeSequenceProvider); live servers skip it.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local HC = require(Shared:WaitForChild("HeroChickenConfig"))

local CatcherGesture = {}

local G = HC.Gesture
local rad = math.rad

-- R6 joint transforms (Motor6D space: shoulders / neck rotate about their Z axis)
local function pose(parent: Instance, name: string, cf: CFrame?, children: { Instance }?): Pose
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf or CFrame.new()
	p.Weight = if cf then 1 else 0
	p.EasingStyle = Enum.PoseEasingStyle.Cubic
	p.EasingDirection = Enum.PoseEasingDirection.InOut
	for _, c in ipairs(children or {}) do
		c.Parent = p
	end
	p.Parent = parent
	return p
end

local function keyframe(seq: KeyframeSequence, t: number, joints: { [string]: CFrame })
	local kf = Instance.new("Keyframe")
	kf.Time = t
	local root = Instance.new("Pose")
	root.Name = "HumanoidRootPart"
	root.Weight = 0
	local torso = pose(root, "Torso", joints.Torso)
	for _, part in ipairs({ "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }) do
		if joints[part] then
			pose(torso, part, joints[part])
		end
	end
	root.Parent = kf
	kf.Parent = seq
end

-- "considering": right hand up toward the chin, left hand at the side, head scanning slowly
local function buildConsider(): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "HC_CatcherConsider"
	seq.Loop = true
	seq.Priority = Enum.AnimationPriority.Action
	local hand = CFrame.Angles(rad(-35), rad(-20), rad(G.CHIN_RAISE))
	local left = CFrame.Angles(0, 0, rad(-12))
	keyframe(seq, 0, { ["Right Arm"] = hand, ["Left Arm"] = left, Head = CFrame.Angles(0, 0, rad(-G.HEAD_SCAN)) })
	keyframe(seq, G.SCAN_SECONDS / 2, { ["Right Arm"] = hand * CFrame.Angles(0, 0, rad(4)), ["Left Arm"] = left, Head = CFrame.Angles(0, 0, rad(G.HEAD_SCAN)) })
	keyframe(seq, G.SCAN_SECONDS, { ["Right Arm"] = hand, ["Left Arm"] = left, Head = CFrame.Angles(0, 0, rad(-G.HEAD_SCAN)) })
	return seq
end

-- the point: right arm straight out at the picked Runner, head along it, a small lean in
local function buildPoint(): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "HC_CatcherPoint"
	seq.Loop = true -- every keyframe is the pose: the play fade raises the arm, then it holds
	seq.Priority = Enum.AnimationPriority.Action2
	local arm = CFrame.Angles(0, 0, rad(90))
	keyframe(seq, 0, { ["Right Arm"] = arm, ["Left Arm"] = CFrame.Angles(0, 0, rad(-8)), Torso = CFrame.Angles(rad(-6), 0, 0) })
	keyframe(seq, 1, { ["Right Arm"] = arm, ["Left Arm"] = CFrame.Angles(0, 0, rad(-8)), Torso = CFrame.Angles(rad(-6), 0, 0) })
	return seq
end

local animIds: { consider: string?, point: string? } = {}
type Entry = { tracks: { AnimationTrack }, conns: { RBXScriptConnection }, arms: { [Motor6D]: CFrame } }
local playing: { [any]: Entry } = {}

local function idFor(kind: string, build: () -> KeyframeSequence): string?
	local published = if kind == "consider" then G.CONSIDER_ID else G.POINT_ID
	if type(published) == "number" and published > 0 then
		return "rbxassetid://" .. published
	end
	if RunService:IsStudio() then
		local ok, id = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(build())
		end)
		if ok then
			return id
		end
	end
	return nil -- live without a published id: no gesture (the cut-scene still plays)
end

local function animatorOf(actor: any): Animator?
	local char = actor.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local a = hum:FindFirstChildOfClass("Animator")
	if not a then
		a = Instance.new("Animator")
		a.Parent = hum
	end
	return a
end

local function restoreArms(p: Entry, char: Model?)
	for m, c0 in pairs(p.arms) do
		if m.Parent then
			TweenService:Create(m, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { C0 = c0 }):Play()
		end
	end
	p.arms = {}
	-- clients leave the shoulder to the server while EOS_ArmHeld is set (CharacterAnim); let go once the arm is down
	local held = char and char:GetAttribute("EOS_ArmHeld")
	if char and held then
		task.delay(0.3, function()
			if char:GetAttribute("EOS_ArmHeld") == held then
				char:SetAttribute("EOS_ArmHeld", nil)
			end
		end)
	end
end

function CatcherGesture.stop(actor: any)
	local p = playing[actor]
	if not p then
		return
	end
	playing[actor] = nil
	for _, t in ipairs(p.tracks) do
		pcall(function()
			t:Stop(0.25)
		end)
	end
	restoreArms(p, actor.Character)
	for _, c in ipairs(p.conns) do
		c:Disconnect()
	end
end

local function entry(actor: any): Entry
	local p = playing[actor]
	if not p then
		p = { tracks = {}, conns = {}, arms = {} }
		playing[actor] = p
		local char = actor.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			table.insert(p.conns, hum.Died:Connect(function()
				CatcherGesture.stop(actor)
			end))
		end
		if char then
			table.insert(p.conns, char.AncestryChanged:Connect(function(_, parent)
				if not parent then
					CatcherGesture.stop(actor)
				end
			end))
		end
	end
	return p
end

local function play(actor: any, id: string?, fade: number): boolean
	if not id then
		return false
	end
	local animator = animatorOf(actor)
	if not animator then
		return false
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok or not track then
		return false
	end
	local p = entry(actor)
	track:Play(fade)
	table.insert(p.tracks, track)
	return true
end

-- the right shoulder joint and the arm part below it (R6 or R15)
local function shoulderOf(char: Model): Motor6D?
	local torso = char:FindFirstChild("Torso")
	local m = torso and torso:FindFirstChild("Right Shoulder")
	if m and m:IsA("Motor6D") then
		return m
	end
	local ua = char:FindFirstChild("RightUpperArm")
	m = ua and ua:FindFirstChild("RightShoulder")
	if m and m:IsA("Motor6D") then
		return m
	end
	return nil
end

-- procedural point: C0 rotated so the arm's length (its -Y) runs from the shoulder to the target.
-- part0Goal is where the torso will be once the turn ends, so the turn and the raise tween together.
local function aimArm(actor: any, p: Entry, targetPos: Vector3, part0Goal: CFrame?)
	local char = actor.Character
	local m = char and shoulderOf(char)
	if not m or not m.Part0 or not m.Part1 then
		return
	end
	local c0 = p.arms[m] or m.C0
	p.arms[m] = c0
	local p0 = part0Goal or m.Part0.CFrame
	local joint = p0 * c0
	local down = -(joint * m.C1:Inverse()).UpVector
	local dir = targetPos - joint.Position
	if dir.Magnitude < 0.5 then
		return
	end
	dir = dir.Unit
	local axis = down:Cross(dir)
	local turn = if axis.Magnitude > 1e-4
		then CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(down:Dot(dir), -1, 1)))
		else CFrame.identity
	local goal = p0:ToObjectSpace(CFrame.new(joint.Position) * turn * joint.Rotation)
	char:SetAttribute("EOS_ArmHeld", os.clock()) -- every client's CharacterAnim leaves this shoulder to the server
	TweenService:Create(m, TweenInfo.new(G.ARM_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { C0 = goal }):Play()
end

function CatcherGesture.consider(actor: any)
	CatcherGesture.stop(actor)
	animIds.consider = animIds.consider or idFor("consider", buildConsider)
	play(actor, animIds.consider, 0.4)
end

function CatcherGesture.point(actor: any, targetPos: Vector3?)
	local p = playing[actor]
	if p then
		for _, t in ipairs(p.tracks) do
			pcall(function()
				t:Stop(0.3)
			end)
		end
		p.tracks = {}
	end
	-- a published point clip wins; otherwise the procedural arm (every server, no upload needed)
	local published = type(G.POINT_ID) == "number" and G.POINT_ID > 0
	local animated = published and play(actor, "rbxassetid://" .. G.POINT_ID, 0.3)
	-- turn smoothly to face the picked Runner (the lineup holds the Catcher anchored: tween the root)
	local root = actor.Character and actor.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rootGoal: CFrame? = nil
	if root and targetPos then
		local flat = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
		if (flat - root.Position).Magnitude > 0.5 then
			rootGoal = CFrame.lookAt(root.Position, flat)
			if root.Anchored then
				TweenService:Create(root, TweenInfo.new(G.TURN_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = rootGoal }):Play()
			else
				root.CFrame = rootGoal :: CFrame
			end
		end
	end
	if not animated and root and targetPos then
		local char = actor.Character
		local m = char and shoulderOf(char)
		local p0Goal = if m and m.Part0 and rootGoal then (rootGoal :: CFrame) * root.CFrame:ToObjectSpace(m.Part0.CFrame) else nil
		aimArm(actor, entry(actor), targetPos, p0Goal)
	end
end

-- the two clips as KeyframeSequences (for publishing them: export, upload as Animation, ids into config)
function CatcherGesture.buildSequences(): { KeyframeSequence }
	return { buildConsider(), buildPoint() }
end

function CatcherGesture.stopAll()
	for actor in pairs(playing) do
		CatcherGesture.stop(actor)
	end
end

return CatcherGesture
