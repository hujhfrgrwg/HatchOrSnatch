-- WorldFX: small, readable world feedback (no complex VFX in this pass, per the GDD).
--  * Runners: the CURRENT finish zone glows (client-side Highlight) so the direction is obvious
--  * capture: a ring + sparkle burst where it happened
--  * evolve: a short twinkle burst on the Runner
-- Particles use textures uploaded from the toolkit's vfx-kit / ui-kit (owned by the developer).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("UI"):WaitForChild("Theme"))
local Net = require(ReplicatedStorage.EOS.Shared.Net)

local WorldFX = {}
WorldFX.reduceEffects = false

local player = Players.LocalPlayer
local state = Net.state()
local zoneHighlight: Highlight? = nil

local function zoneModel(side: string): Instance?
	local world = workspace:FindFirstChild("EOS_World")
	local arena = world and world:FindFirstChild("Arena")
	local zones = arena and arena:FindFirstChild("SafeZones")
	return zones and zones:FindFirstChild("Zone" .. side)
end

local function updateZoneHighlight()
	local phase = state:GetAttribute("Phase")
	local runner = player:GetAttribute("EOS_InMatch") and player:GetAttribute("EOS_Role") == "RUNNER"
	local show = runner and (phase == "CROSSING" or phase == "ROLE_REVEAL" or phase == "WAVE_END") and not player:GetAttribute("EOS_Safe")
	local side = state:GetAttribute("FinishSide")
	if phase == "WAVE_END" then
		-- next wave runs the other way
		side = if side == "A" then "B" else "A"
	end
	local zm = if show and side then zoneModel(side) else nil
	local target = zm and zm:FindFirstChild("Pad") -- only the floor pad (never the invisible walls)
	if target then
		if not zoneHighlight then
			local h = Instance.new("Highlight")
			h.Name = "EOS_FinishGlow"
			h.FillColor = Color3.fromRGB(110, 255, 120)
			h.OutlineColor = Color3.fromRGB(200, 255, 200)
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = workspace
			zoneHighlight = h
		end
		zoneHighlight.Adornee = target
		zoneHighlight.Enabled = true
	elseif zoneHighlight then
		zoneHighlight.Enabled = false
	end
end

local function burstAt(pos: Vector3, color: Color3, big: boolean)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos)
	local att = Instance.new("Attachment")
	att.Parent = p
	local ring = Instance.new("ParticleEmitter")
	ring.Texture = Theme.img.ring
	ring.Color = ColorSequence.new(color)
	ring.LightEmission = 1
	ring.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, if big then 14 else 9) })
	ring.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	ring.Lifetime = NumberRange.new(0.45)
	ring.Speed = NumberRange.new(0)
	ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ring.EmissionDirection = Enum.NormalId.Top
	ring.Enabled = false
	ring.Parent = att
	local spark = Instance.new("ParticleEmitter")
	spark.Texture = Theme.img.twinkleFlip
	spark.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	spark.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	spark.Color = ColorSequence.new(color)
	spark.LightEmission = 1
	spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.6) })
	spark.Lifetime = NumberRange.new(0.6, 0.8)
	spark.Speed = NumberRange.new(8, 16)
	spark.SpreadAngle = Vector2.new(180, 180)
	spark.Drag = 4
	spark.Enabled = false
	spark.Parent = att
	p.Parent = workspace
	ring:Emit(1)
	spark:Emit(if WorldFX.reduceEffects then 4 else (if big then 16 else 10))
	task.delay(1.5, function()
		p:Destroy()
	end)
end

function WorldFX.capture(pos: Vector3)
	burstAt(pos, Color3.fromRGB(255, 90, 90), true)
end

-- who: a Player or a character Model (NPCs)
function WorldFX.evolve(who: any, tierColor: Color3)
	local c = if typeof(who) == "Instance" and who:IsA("Model") then who else who.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		burstAt(hrp.Position, tierColor, false)
	end
end

function WorldFX.init()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		updateZoneHighlight()
		if zoneHighlight and zoneHighlight.Enabled then
			local t = os.clock()
			zoneHighlight.FillTransparency = 0.62 + 0.18 * math.sin(t * 4)
			zoneHighlight.OutlineTransparency = 0.2
		end
	end)
end

return WorldFX
