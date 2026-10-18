-- HOS-ICON-001 round 6: the Emote Crate card's buttons get faces built from frames, not stretched raster art.
-- The exported button arts (340x88 / 290x66 at 2x) carry a dotted fade on their right side, so slicing them to the
-- card's bigger sizes showed that fade as a strip on the right edge and cut the bottom rows off. Each button's Art
-- becomes a Frame (CrateExtras' sliceArt only touches ImageLabels named Art, and its resize() still sizes this one):
--   Edge  dark outline + bottom shadow, full size
--   Lip   the darker 3D bottom, inset 3
--   Face  the colour, inset 3, 6 px short of the lip; a soft top-to-bottom gradient
--   Studs the place's stud tile (as on the quests pill), fading in toward the right like the other buttons' dots
-- Run in edit mode (execute_luau) with the card path below; `face(button, palette)` is also what the preview used.
local STUDS = "rbxassetid://75407673232479"

local PALETTE = {
	gems = { top = Color3.fromRGB(122, 206, 92), face = Color3.fromRGB(86, 176, 66), lip = Color3.fromRGB(46, 112, 44) },
	robux = { top = Color3.fromRGB(170, 112, 214), face = Color3.fromRGB(132, 78, 184), lip = Color3.fromRGB(82, 44, 124) },
	see = { top = Color3.fromRGB(246, 182, 84), face = Color3.fromRGB(222, 140, 48), lip = Color3.fromRGB(150, 84, 28) },
}
local EDGE = Color3.fromRGB(20, 14, 26)

local function frame(name, parent, z, color, pos, size, radius)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Position = pos
	f.Size = size
	f.ZIndex = z
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = f
	f.Parent = parent
	return f
end

local function face(b, pal)
	local old = b:FindFirstChild("Art")
	local keepImage = old and old:IsA("ImageLabel") and old.Image or old and old:GetAttribute("HOS_WasImage")
	if old then
		old:Destroy()
	end
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromOffset(b.Size.X.Offset, b.Size.Y.Offset) -- offsets: CrateExtras resize() adds to them
	art.ZIndex = 1
	art:SetAttribute("HOS_WasImage", keepImage)
	art.Parent = b
	frame("Edge", art, 1, EDGE, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 1, 0), 14)
	frame("Lip", art, 1, pal.lip, UDim2.fromOffset(3, 3), UDim2.new(1, -6, 1, -6), 11)
	local f = frame("Face", art, 1, Color3.new(1, 1, 1), UDim2.fromOffset(3, 3), UDim2.new(1, -6, 1, -12), 11) -- white: the gradient multiplies it
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(pal.top, pal.face)
	g.Parent = f
	local s = Instance.new("ImageLabel")
	s.Name = "Studs"
	s.BackgroundTransparency = 1
	s.Image = STUDS
	s.ScaleType = Enum.ScaleType.Tile
	s.TileSize = UDim2.fromOffset(40, 40)
	s.ImageColor3 = Color3.new(1, 1, 1)
	s.ImageTransparency = 0.55
	s.Size = UDim2.fromScale(1, 1)
	s.ZIndex = 1
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 11)
	sc.Parent = s
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.45, 0.85),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	sg.Parent = s
	s.Parent = f
	return art
end

return { face = face, PALETTE = PALETTE }
