--!strict
-- FieldGems (HOS-GEMS-002, 17 Oct): the look of the Gems lying on the field (FieldGemService places them).
--  * each Gem spins and bobs above the turf with a lean sparkle around it (Rate x Lifetime ~3)
--  * a pickup: ring + rays + glitter burst where it was, a 3D chime for everyone; for the collector a
--    2D chime rising in pitch with each Gem this match and a green "+1" that floats up
--  * at the per-match cap: "MAX" over the Gem instead (the match HUD hides ordinary toasts)
-- Textures are from the AllVFX pack (already uploaded for the ability effects: vfx/abilities/image_ids.json),
-- greyscale and tinted here. Gameplay never waits on any of this.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("Net"))
local Theme = require(ReplicatedStorage.EOS:WaitForChild("UI"):WaitForChild("Theme"))
local Sound = require(script.Parent.Sound)
local WorldFX = require(script.Parent.WorldFX)

local FieldGems = {}

local TAG = "EOS_FieldGem"
local TEX = {
	glitter = "rbxassetid://117932483145389", -- av_glitter
	ring = "rbxassetid://87500185897341", -- av_ring_glow
	rays = "rbxassetid://107516728001898", -- av_burst_rays
}
local GREEN = Color3.fromRGB(70, 240, 130)
local PALE = Color3.fromRGB(200, 255, 215)
local SPIN = 1.6 -- radians a second
local BOB = 0.35 -- studs
local BOB_SPEED = 2.4

local player = Players.LocalPlayer
local gems: { [BasePart]: { base: CFrame, phase: number } } = {}

local function seq(a: number, b: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

local function addIdle(part: BasePart)
	if WorldFX.reduceEffects then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "GemFX"
	att.Parent = part
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX.glitter
	e.Color = ColorSequence.new(PALE, GREEN)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = seq(0.1, 1)
	e.Lifetime = NumberRange.new(0.6, 0.9)
	e.Rate = 4
	e.Speed = NumberRange.new(0.6, 1.4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.LockedToPart = false
	e.Parent = att
	-- a soft green light so the Gem reads on the turf from across the field (no Neon fake glow)
	local light = Instance.new("PointLight")
	light.Color = GREEN
	light.Brightness = 1.2
	light.Range = 7
	light.Shadows = false
	light.Parent = part
end

local function track(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	gems[inst] = { base = inst.CFrame, phase = math.random() * math.pi * 2 }
	addIdle(inst)
end

local function burst(pos: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(pos)
	local att = Instance.new("Attachment")
	att.Parent = p
	local function emitter(tex: string, props: { [string]: any }): ParticleEmitter
		local e = Instance.new("ParticleEmitter")
		e.Texture = tex
		e.LightEmission = 1
		e.Enabled = false
		for k, v in pairs(props) do
			(e :: any)[k] = v
		end
		e.Parent = att
		return e
	end
	local ring = emitter(TEX.ring, {
		Color = ColorSequence.new(GREEN),
		Size = seq(0.6, 7),
		Transparency = seq(0.05, 1),
		Lifetime = NumberRange.new(0.4),
		Speed = NumberRange.new(0),
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
	})
	local rays = emitter(TEX.rays, {
		Color = ColorSequence.new(PALE, GREEN),
		Size = seq(1.5, 4.5),
		Transparency = seq(0.2, 1),
		Lifetime = NumberRange.new(0.25),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
	})
	local glitter = emitter(TEX.glitter, {
		Color = ColorSequence.new(PALE, GREEN),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = seq(0, 1),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -18, 0),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
	})
	p.Parent = workspace
	ring:Emit(1)
	rays:Emit(1)
	glitter:Emit(if WorldFX.reduceEffects then 6 else 14)
	task.delay(1.2, function()
		p:Destroy()
	end)
end

-- "+1" (or "MAX") that floats up from where the Gem was, for the collector only
local function floatText(pos: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0))
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 50)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.font
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Theme.textOutline
	label.TextStrokeTransparency = 0
	label.Parent = bb
	anchor.Parent = workspace
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { CFrame = anchor.CFrame + Vector3.new(0, 3.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.1, function()
		anchor:Destroy()
	end)
end

local function onPicked(t: any)
	if type(t) ~= "table" or typeof(t.position) ~= "Vector3" then
		return
	end
	if t.full then
		if t.userId == player.UserId then
			floatText(t.position, "MAX", Theme.mutedText)
		end
		return
	end
	burst(t.position)
	if t.userId == player.UserId then
		local n = if type(t.total) == "number" then t.total else 1
		Sound.play("gem", 1 + 0.08 * math.max(0, n - 1)) -- a run of Gems rises in pitch
		floatText(t.position, "+1", Theme.gemText)
	else
		Sound.playAt("gem", t.position, 0.6)
	end
end

function FieldGems.init()
	for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
		track(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
		gems[inst :: BasePart] = nil
	end)
	Net.event("FieldGemPicked").OnClientEvent:Connect(onPicked)
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for part, g in pairs(gems) do
			if part.Parent then
				local y = math.sin(now * BOB_SPEED + g.phase) * BOB
				part.CFrame = CFrame.new(g.base.Position + Vector3.new(0, y, 0)) * CFrame.Angles(0, now * SPIN + g.phase, 0) * g.base.Rotation
			else
				gems[part] = nil
			end
		end
	end)
end

return FieldGems
