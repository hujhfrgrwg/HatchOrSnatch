-- HOS-SPIN-001 (18 Oct 2026, Matthew): puts the rewards on the lobby spin wheel (Workspace.SpinWheel).
--  * recolours the 8 sectors from SpinWheelConfig (only the weapon slot, Sector_1 at the top, is orange)
--  * Wheel.Labels: an invisible plate just in front of the sectors with one SurfaceGui (icon + amount per slot); it is
--    part of the Wheel model, so it turns with it
--  * SpinSign: a camera-facing sign over the crystal ("SPIN THE WHEEL", the free spin timer), filled in per player
--    by the client (SpinWheelController)
--  * the model streams in whole (ModelStreamingMode Atomic) so the client can always turn the entire wheel
-- Everything is relative to the model's pivot (front = the pivot's +Z), so it works wherever the wheel stands.
-- Re-runnable: it replaces what it made before.
local C = require(game.ReplicatedStorage.EOS.Shared.SpinWheelConfig)
local sw = workspace.SpinWheel
local wheel = sw.Wheel
local pivot = sw:GetPivot()
local front = pivot.ZVector
local centre = pivot:PointToWorldSpace(Vector3.new(0, 10.72, 0))
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local INK = Color3.fromRGB(5, 5, 6)

sw.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

for i, s in C.SLOTS do
	local sector = wheel.Sectors:FindFirstChild("Sector_" .. i)
	if sector then
		sector.Color = s.color
		sector:SetAttribute("Reward", C.name(s))
	end
end

local old = wheel:FindFirstChild("Labels")
if old then old:Destroy() end
local PPS, SIZE = 100, 12
local plate = Instance.new("Part")
plate.Name = "Labels"
plate.Size = Vector3.new(SIZE, SIZE, 0.05)
plate.Transparency = 1
plate.Anchored = true
plate.CanCollide = false
plate.CanQuery = false
plate.CanTouch = false
plate.CastShadow = false
-- the sectors' front is at local z -0.02 and the dividers stand out to +0.05: the plate's front face sits between
local at = centre + front * 0.035
plate.CFrame = CFrame.lookAt(at, at + front) -- its Front face looks out of the wheel
local gui = Instance.new("SurfaceGui")
gui.Name = "Rewards"
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = PPS
gui.LightInfluence = 0.35
gui.Brightness = 1.4
gui.MaxDistance = 220
gui.Parent = plate

local function label(parent: Instance, name: string, text: string, pos: UDim2, size: UDim2, ts: number, stroke: number)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = pos
	t.Size = size
	t.FontFace = FONT
	t.Text = text
	t.TextSize = ts
	t.TextColor3 = Color3.new(1, 1, 1)
	t.ZIndex = 3
	local st = Instance.new("UIStroke")
	st.Thickness = stroke
	st.Color = INK
	st.Parent = t
	t.Parent = parent
	return t
end

local R = 4.05 * PPS -- slot centre, studs from the hub (sectors run 1.8 to 5.98)
for i, s in C.SLOTS do
	local a = math.rad((i - 1) * 45)
	local f = Instance.new("Frame")
	f.Name = "Slot" .. i
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(260, 300)
	f.Position = UDim2.fromOffset(SIZE * PPS / 2 + R * math.sin(a), SIZE * PPS / 2 - R * math.cos(a))
	f.Rotation = (i - 1) * 45
	f.Parent = gui
	local big = s.kind == "weapon"
	local isz = if big then 200 else 165
	local sh = Instance.new("ImageLabel")
	sh.Name = "IconShadow"
	sh.BackgroundTransparency = 1
	sh.AnchorPoint = Vector2.new(0.5, 0.5)
	sh.Position = UDim2.new(0.5, 0, 0.5, -36 + 8)
	sh.Size = UDim2.fromOffset(isz, isz)
	sh.Image = C.icon(s)
	sh.ImageColor3 = Color3.new(0, 0, 0)
	sh.ImageTransparency = 0.35
	sh.ZIndex = 1
	sh.Parent = f
	local ic = sh:Clone()
	ic.Name = "Icon"
	ic.Position = UDim2.new(0.5, 0, 0.5, -36)
	ic.ImageColor3 = Color3.new(1, 1, 1)
	ic.ImageTransparency = 0
	ic.ZIndex = 2
	ic.Parent = f
	if big and not s.weaponId then
		ic.ImageColor3 = Color3.fromRGB(40, 22, 8) -- the placeholder weapon is a dark silhouette with a "?"
		label(f, "Mystery", "?", UDim2.new(0.5, 0, 0.5, -40), UDim2.fromOffset(200, 150), 130, 9)
	end
	label(f, "Amount", C.short(s), UDim2.new(0.5, 0, 0.5, 92), UDim2.fromOffset(260, 80), if s.kind == "shard" then 56 elseif big then 50 else 70, 7)
end
plate.Parent = wheel

-- the sign over the crystal
local oldSign = sw:FindFirstChild("SpinSign")
if oldSign then oldSign:Destroy() end
local anchor = Instance.new("Part")
anchor.Name = "SpinSign"
anchor.Size = Vector3.new(0.2, 0.2, 0.2)
anchor.Transparency = 1
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.CFrame = CFrame.new(pivot:PointToWorldSpace(Vector3.new(0, 23.3, 0.6)))
local bb = Instance.new("BillboardGui")
bb.Name = "Sign"
bb.Size = UDim2.fromScale(9, 2.6)
bb.LightInfluence = 0
bb.MaxDistance = 140
bb.Parent = anchor
local title = label(bb, "Title", "SPIN THE WHEEL", UDim2.fromScale(0.5, 0.3), UDim2.fromScale(1, 0.56), 0, 3)
title.TextScaled = true
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(255, 226, 120), Color3.fromRGB(255, 150, 30))
grad.Rotation = 90
grad.Parent = title
local sub = label(bb, "Sub", "", UDim2.fromScale(0.5, 0.78), UDim2.fromScale(1, 0.38), 0, 2.5)
sub.TextScaled = true
anchor.Parent = sw

return "labels + sign done"
