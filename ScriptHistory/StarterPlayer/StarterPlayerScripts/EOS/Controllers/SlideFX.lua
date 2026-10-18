--!strict
-- SlideFX: speed streaks for every side slide and back dash (and NPC dives), on everyone's screen.
--  * on the floor: a dark scuff the width of the body, a bright core band down its middle and two
--    bright edge lines, lying flat along the ground where the body slid
--  * in the air: two speed lines off the torso (shoulder height and hip height), facing the camera
--  * a small dust kick as the slide starts (Roblox's built-in smoke texture)
--  * HOS-TRAIL-002 (Matthew 18 Oct: "Can you have the dash beams be the trail beams as well?"): a player wearing an egg
--    trail (Player attribute EOS_Trail, set by EconomyService) slides in that trail's look: the core band, edge lines
--    and speed lines take its colours (the rainbow runs along them) and the core band its first layer's texture
--    (Shared.TrailLook). No trail (and NPCs): the usual white-blue streaks. The dark scuff stays as it is.
-- Triggered by the dash clips themselves (Animator.AnimationPlayed), so it covers your own slides,
-- other players' and NPCs' with no extra network traffic. Built locally per body on its first slide;
-- nothing here replicates. Reduce Effects keeps only the floor lines.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local AnimConfig = require(Shared:WaitForChild("AnimConfig"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local TrailLook = require(Shared:WaitForChild("TrailLook"))
local WorldFX = require(script.Parent.WorldFX)

local SlideFX = {}

local D = GameConfig.Dash
local ON_TIME = D.BURST_TIME + D.RECOVER_TIME - 0.04 -- the streaks draw while the body is sliding
local FLOOR_Y = -2.92 -- R6: the floor is 3 studs under the root; a hair above it so it never flickers
local DUST = "rbxasset://textures/particles/smoke_main.dds"

-- which clip is which slide: by published id and by the Animation's name (Studio clips)
local SIDES: { [string]: string } = {}
local function addClip(id: string?, side: string)
	local n = id and string.match(id, "%d+")
	if n then
		SIDES[n] = side
	end
end
addClip(AnimConfig.ids.DashLeft, "Left")
addClip(AnimConfig.ids.DashRight, "Right")
addClip(AnimConfig.ids.DashBack, "Back")
addClip(AnimConfig.npcIds.DiveForward, "Forward")
local NAMES = { EOS_DashLeft = "Left", EOS_DashRight = "Right", EOS_DashBack = "Back", EOS_DiveForward = "Forward" }

local function sideOf(track: AnimationTrack): string?
	local anim = track.Animation
	if not anim then
		return nil
	end
	local byName = NAMES[anim.Name]
	if byName then
		return byName
	end
	local n = string.match(anim.AnimationId, "%d+")
	return if n then SIDES[n] else nil
end

local function seq(points: { { number } }): NumberSequence
	local kp = {}
	for _, p in ipairs(points) do
		table.insert(kp, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(kp)
end

type Rig = {
	floor: { { a0: Attachment, a1: Attachment, from: number, to: number } }, -- across-the-path spans
	trails: { Trail },
	air: { Trail },
	bright: { { t: Trail, color: ColorSequence, brightness: number, textured: boolean } }, -- the streaks a worn trail restyles
	dust: ParticleEmitter,
	token: number,
}
local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any

local function trail(name: string, a0: Attachment, a1: Attachment, props: { [string]: any }): Trail
	local t = Instance.new("Trail")
	t.Name = name
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Enabled = false
	t.MinLength = 0.05
	for k, v in pairs(props) do
		(t :: any)[k] = v
	end
	t.Parent = a0.Parent
	return t
end

local function attach(part: BasePart, name: string, pos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	a.Parent = part
	return a
end

local function build(char: Model): Rig?
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = char:FindFirstChild("Torso") :: BasePart?
	if not root or not torso then
		return nil
	end
	local rig: Rig = { floor = {}, trails = {}, air = {}, bright = {}, dust = nil :: any, token = 0 }
	local function span(name: string, from: number, to: number, props: { [string]: any })
		local a0 = attach(root, "EOS_Slide_" .. name .. "0", Vector3.zero)
		local a1 = attach(root, "EOS_Slide_" .. name .. "1", Vector3.zero)
		table.insert(rig.floor, { a0 = a0, a1 = a1, from = from, to = to })
		table.insert(rig.trails, trail("EOS_Slide_" .. name, a0, a1, props))
	end
	-- the scuff: dark, soft, as wide as the body (value against the bright floor)
	span("Scuff", -1.25, 1.25, {
		FaceCamera = false,
		Lifetime = 0.55,
		Color = ColorSequence.new(Color3.fromRGB(25, 40, 30)),
		Transparency = seq({ { 0, 0.4 }, { 0.5, 0.7 }, { 1, 1 } }),
		WidthScale = seq({ { 0, 1 }, { 1, 0.5 } }),
		LightEmission = 0,
		LightInfluence = 1,
	})
	-- a bright core band down the middle of the scuff
	span("Core", -0.5, 0.5, {
		FaceCamera = false,
		Lifetime = 0.35,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(160, 220, 255)),
		Transparency = seq({ { 0, 0.25 }, { 1, 1 } }),
		WidthScale = seq({ { 0, 1 }, { 1, 0.2 } }),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
	})
	-- two bright edge lines either side of it
	local edge = {
		FaceCamera = false,
		Lifetime = 0.3,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 225, 255)),
		Transparency = seq({ { 0, 0 }, { 1, 1 } }),
		WidthScale = seq({ { 0, 1 }, { 1, 0.25 } }),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
	}
	span("EdgeA", -1.3, -0.95, edge)
	span("EdgeB", 0.95, 1.3, edge)
	-- speed lines in the air: shoulder height and hip height, always facing the camera
	local air = {
		FaceCamera = true,
		Lifetime = 0.28,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 235, 255)),
		Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
		WidthScale = seq({ { 0, 1 }, { 1, 0 } }),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
	}
	local s0, s1 = attach(torso, "EOS_SlideAir1_0", Vector3.new(0, 0.55, 0)), attach(torso, "EOS_SlideAir1_1", Vector3.new(0, 0.95, 0))
	local h0, h1 = attach(torso, "EOS_SlideAir2_0", Vector3.new(0, -0.5, 0)), attach(torso, "EOS_SlideAir2_1", Vector3.new(0, -0.82, 0))
	table.insert(rig.air, trail("EOS_SlideAir1", s0, s1, air))
	table.insert(rig.air, trail("EOS_SlideAir2", h0, h1, air))
	-- dust kick at the feet
	local feet = attach(root, "EOS_SlideDust", Vector3.new(0, FLOOR_Y + 0.15, 0))
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "EOS_SlideDust"
	dust.Texture = DUST
	dust.Enabled = false
	dust.Rate = 0
	dust.EmissionDirection = Enum.NormalId.Top
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.Speed = NumberRange.new(3, 7)
	dust.Drag = 4
	dust.Acceleration = Vector3.new(0, 1.5, 0)
	dust.Lifetime = NumberRange.new(0.35, 0.6)
	dust.Size = seq({ { 0, 0.8 }, { 1, 2.8 } })
	dust.Transparency = seq({ { 0, 0.3 }, { 1, 1 } })
	dust.Color = ColorSequence.new(Color3.fromRGB(236, 238, 228))
	dust.LightEmission = 0
	dust.LightInfluence = 1
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-40, 40)
	dust.Parent = feet
	rig.dust = dust
	for _, t in ipairs(rig.trails) do
		if t.Name ~= "EOS_Slide_Scuff" then
			table.insert(rig.bright, { t = t, color = t.Color, brightness = t.Brightness, textured = t.Name == "EOS_Slide_Core" })
		end
	end
	for _, t in ipairs(rig.air) do
		table.insert(rig.bright, { t = t, color = t.Color, brightness = t.Brightness, textured = false })
	end
	rigs[char] = rig
	return rig
end

-- the worn trail's look on the bright streaks, or their own white-blue. A worn trail draws at TRAIL_BRIGHTNESS: at the
-- streaks' own 3 its colours wash out to white
local TRAIL_BRIGHTNESS = 1
local function dress(rig: Rig, char: Model)
	local plr = Players:GetPlayerFromCharacter(char)
	local id = plr and plr:GetAttribute("EOS_Trail")
	local item = if type(id) == "string" then EconomyConfig.item(id) else nil
	local layers = item and TrailLook.LAYERS[item.id]
	local color = if item then TrailLook.color(item) else nil
	local tex = if layers then layers[1].tex else ""
	for _, b in ipairs(rig.bright) do
		b.t.Color = color or b.color
		b.t.Brightness = if color then TRAIL_BRIGHTNESS else b.brightness
		b.t.Texture = if color and b.textured then tex else ""
		b.t.TextureMode = Enum.TextureMode.Stretch
	end
end

-- one slide on `char`: side = "Left" | "Right" | "Back" | "Forward" (relative to the body, which holds
-- still for the slide)
function SlideFX.play(char: Model, side: string)
	local rig = rigs[char] or build(char)
	if not rig then
		return
	end
	-- the floor spans lie across the path: front-to-back for a side slide, side-to-side for back/forward
	-- to start with, then square to the body's actual motion while it slides (diagonal slides, dives)
	local function lay(across: Vector3)
		for _, s in ipairs(rig.floor) do
			s.a0.Position = Vector3.new(0, FLOOR_Y, 0) + across * s.from
			s.a1.Position = Vector3.new(0, FLOOR_Y, 0) + across * s.to
		end
	end
	lay(if side == "Left" or side == "Right" then Vector3.zAxis else Vector3.xAxis)
	dress(rig, char)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local reduce = WorldFX.reduceEffects
	for _, t in ipairs(rig.trails) do
		t:Clear() -- no streak joining the last slide to this one
		t.Enabled = true
	end
	for _, t in ipairs(rig.air) do
		t:Clear()
		t.Enabled = not reduce
	end
	if not reduce then
		rig.dust:Emit(9)
		task.delay(0.12, function()
			if rig.dust.Parent then
				rig.dust:Emit(5)
			end
		end)
	end
	rig.token += 1
	local token = rig.token
	local follow = RunService.Heartbeat:Connect(function()
		if rig.token ~= token or not root then
			return
		end
		local v = root.AssemblyLinearVelocity
		local flat = Vector3.new(v.X, 0, v.Z)
		if flat.Magnitude > 6 then
			lay(root.CFrame:VectorToObjectSpace(Vector3.yAxis:Cross(flat.Unit)))
		end
	end)
	task.delay(ON_TIME, function()
		follow:Disconnect()
		if rig.token ~= token then
			return -- a newer slide owns the streaks
		end
		for _, t in ipairs(rig.trails) do
			t.Enabled = false
		end
		for _, t in ipairs(rig.air) do
			t.Enabled = false
		end
	end)
end

local hooked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function watch(char: Model)
	if hooked[char] then
		return
	end
	hooked[char] = true
	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 10)
		local animator = hum and hum:WaitForChild("Animator", 10)
		if not animator or not animator:IsA("Animator") then
			return
		end
		animator.AnimationPlayed:Connect(function(track)
			local side = sideOf(track)
			if side and char.Parent then
				SlideFX.play(char, side)
			end
		end)
	end)
end

function SlideFX.init()
	local function onPlayer(plr: Player)
		plr.CharacterAdded:Connect(watch)
		if plr.Character then
			watch(plr.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, plr in ipairs(Players:GetPlayers()) do
		onPlayer(plr)
	end
	-- NPC bodies live in workspace.EOS_Runtime.Npcs
	task.spawn(function()
		local runtime = workspace:WaitForChild("EOS_Runtime", 60)
		local npcs = runtime and runtime:WaitForChild("Npcs", 60)
		if not npcs then
			return
		end
		npcs.ChildAdded:Connect(function(m)
			if m:IsA("Model") then
				watch(m)
			end
		end)
		for _, m in ipairs(npcs:GetChildren()) do
			if m:IsA("Model") then
				watch(m)
			end
		end
	end)
end

return SlideFX
