--!nocheck
-- UIKit: the shared UI components (Oct 2026 restyle: dark glass, white outlined text, accent
-- underlines, a subtle stud texture). Used by the edit-time UIBuilder (which bakes the screens into
-- StarterGui) and by client code for runtime pieces (toasts, feed lines, cards).
-- One component per element type; only the colour ramp varies (LESSONS 3: consistency).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("UI"):WaitForChild("Theme"))
local TierConfig = require(ReplicatedStorage.EOS.Shared.TierConfig)

local UIKit = {}

local function new(class: string, props: { [string]: any }?, parent: Instance?): any
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
UIKit.new = new

function UIKit.corner(parent: Instance, radius: number | UDim)
	return new("UICorner", { CornerRadius = if typeof(radius) == "UDim" then radius else UDim.new(0, radius) }, parent)
end

function UIKit.stroke(parent: Instance, color: Color3, thickness: number, mode: Enum.ApplyStrokeMode?)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

function UIKit.vgrad(parent: Instance, top: Color3, mid: Color3?, bot: Color3)
	local seq
	if mid then
		seq = ColorSequence.new({ ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(0.48, mid), ColorSequenceKeypoint.new(1, bot) })
	else
		seq = ColorSequence.new(top, bot)
	end
	return new("UIGradient", { Color = seq, Rotation = 90 }, parent)
end

-- Outlined display text. o: Name, Text, TextSize, Color, Size, Position, AnchorPoint, Align,
-- YAlign, Scaled (TextScaled with a max), Stroke (thickness), Wrapped, ZIndex, LayoutOrder, Font
function UIKit.text(parent: Instance, o: { [string]: any }): TextLabel
	local size = o.TextSize or 32
	local t = new("TextLabel", {
		Name = o.Name or "Text",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.new(1, 0, 0, size * 1.25),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.new(),
		FontFace = o.Font or Theme.font,
		Text = o.Text or "",
		TextSize = size,
		TextColor3 = o.Color or Theme.white,
		TextXAlignment = o.Align or Enum.TextXAlignment.Center,
		TextYAlignment = o.YAlign or Enum.TextYAlignment.Center,
		TextWrapped = o.Wrapped or false,
		TextScaled = o.Scaled or false,
		RichText = o.RichText or false,
		ZIndex = o.ZIndex or 1,
		LayoutOrder = o.LayoutOrder or 0,
		Visible = if o.Visible == nil then true else o.Visible,
	}, parent)
	if o.Scaled then
		-- MinTextSize is in rendered px (after the Fit UIScale): keep it low or small phones truncate
		new("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = o.MinTextSize or 7 }, t)
	end
	local st = o.Stroke
	if st == nil then
		st = math.max(1.5, math.floor(size / 13 * 2) / 2) -- the reference's thinner, crisp outline
	end
	if st > 0 then
		UIKit.stroke(t, Theme.textOutline, st, Enum.ApplyStrokeMode.Contextual)
	end
	return t
end

-- faint stud texture over a surface (the "subtle stud element")
function UIKit.studs(parent: GuiObject, transparency: number?, tile: number?, radius: number?): ImageLabel
	local img = new("ImageLabel", {
		Name = "Studs",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = Theme.img.stud,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(tile or 56, tile or 56),
		ImageTransparency = transparency or Theme.studT,
		ZIndex = parent.ZIndex,
	}, parent)
	if radius then
		UIKit.corner(img, radius)
	end
	return img
end

local function solidGrad(ramp: any): ColorSequence
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, ramp.top), ColorSequenceKeypoint.new(0.5, ramp.mid), ColorSequenceKeypoint.new(1, ramp.lip) })
end

-- Button / tag plate. Returns root, face, label.
--  * default: dark glass pill with a thin light edge and a coloured accent underline (nav buttons,
--    tags, toggles); the ramp only colours the accent
--  * Solid = true: filled with the ramp colour (actions: claim, buy, hatch, continue, tag, dash)
-- o: Name, Size, Position, AnchorPoint, Ramp, Text, TextSize, Radius, Button, Solid, Accent (false = no
--    underline), Studs (false = none), LayoutOrder, ZIndex, Visible, Align
function UIKit.plate(parent: Instance, o: { [string]: any }): (GuiObject, Frame, TextLabel)
	local rampName = o.Ramp or "blue"
	local ramp = Theme.ramps[rampName]
	local radius = o.Radius or 14
	local solid = o.Solid == true
	local root = new(if o.Button then "TextButton" else "Frame", {
		Name = o.Name or "Plate",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromOffset(240, 84),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.new(),
		LayoutOrder = o.LayoutOrder or 0,
		ZIndex = o.ZIndex or 1,
		Visible = if o.Visible == nil then true else o.Visible,
	}, parent)
	if o.Button then
		root.Text = ""
		root.AutoButtonColor = false
		root.Selectable = true
		root:SetAttribute("Button", true)
	end
	root:SetAttribute("Ramp", rampName)
	root:SetAttribute("Solid", solid)
	local face = new("Frame", {
		Name = "Face",
		BackgroundColor3 = if solid then Color3.new(1, 1, 1) else Theme.panel,
		BackgroundTransparency = if solid then 0 else (o.Transparency or Theme.panelT),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = root.ZIndex,
	}, root)
	UIKit.corner(face, radius)
	local edge = UIKit.stroke(face, if solid then Theme.ink else Theme.edge, if solid then 3 else 2)
	edge.Name = "Edge"
	edge.Transparency = if solid then 0 else Theme.edgeT
	if solid then
		new("UIGradient", { Name = "Fill", Color = solidGrad(ramp), Rotation = 90 }, face)
	end
	if o.Studs ~= false then
		UIKit.studs(face, if solid then Theme.studSolidT else Theme.studT, o.TileSize, radius)
	end
	if not solid and o.Accent ~= false then
		local bar = new("Frame", {
			Name = "Accent",
			BackgroundColor3 = ramp.mid,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -math.max(16, radius), 0, o.AccentHeight or 4),
			ZIndex = root.ZIndex + 1,
		}, face)
		UIKit.corner(bar, 2)
	end
	local label = UIKit.text(face, {
		Name = "Label",
		Text = o.Text or "",
		TextSize = o.TextSize or 34,
		Size = UDim2.new(1, -20, 1, -6),
		Position = UDim2.fromOffset(10, 0),
		Scaled = true,
		Align = o.Align,
		ZIndex = root.ZIndex + 2,
	})
	return root, face, label
end

-- recolour an existing plate to another ramp (toggles, states)
function UIKit.setRamp(root: Instance, rampName: string)
	local ramp = Theme.ramps[rampName]
	if not ramp or root:GetAttribute("Ramp") == rampName then
		return
	end
	root:SetAttribute("Ramp", rampName)
	local face = root:FindFirstChild("Face")
	if not face then
		return
	end
	local fill = face:FindFirstChild("Fill")
	if fill and fill:IsA("UIGradient") then
		fill.Color = solidGrad(ramp)
	end
	local accent = face:FindFirstChild("Accent")
	if accent and accent:IsA("Frame") then
		accent.BackgroundColor3 = ramp.mid
	end
end

-- Window panel: dark glass, header text with an accent underline (top left), red X close.
-- Returns root, body, close (nil when NoClose).
-- o: Name, Size, Position, AnchorPoint, Title, Ramp (accent), NoClose, Visible
function UIKit.panel(parent: Instance, o: { [string]: any }): (Frame, Frame, GuiObject?)
	local ramp = Theme.ramps[o.Ramp or "blue"]
	local root = new("Frame", {
		Name = o.Name or "Panel",
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = o.Transparency or Theme.windowT,
		BorderSizePixel = 0,
		Size = o.Size or UDim2.fromOffset(1100, 720),
		Position = o.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
		Visible = if o.Visible == nil then true else o.Visible,
		Active = true,
	}, parent)
	UIKit.corner(root, 24)
	local edge = UIKit.stroke(root, Theme.edge, 2)
	edge.Transparency = 0.8
	UIKit.studs(root, 0.94, 64, 24)
	if o.Title then
		local header = new("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, -150, 0, 92), Position = UDim2.fromOffset(40, 18), ZIndex = 5 }, root)
		UIKit.text(header, { Name = "Title", Text = o.Title, TextSize = 54, Size = UDim2.new(1, 0, 0, 66), Align = Enum.TextXAlignment.Left, Scaled = true, ZIndex = 5 })
		local bar = new("Frame", { Name = "Accent", BackgroundColor3 = ramp.mid, BorderSizePixel = 0, Size = UDim2.fromOffset(140, 6), Position = UDim2.fromOffset(2, 74), ZIndex = 5 }, header)
		UIKit.corner(bar, 3)
	end
	local close = nil
	if not o.NoClose then
		close = UIKit.plate(root, {
			Name = "Close",
			Ramp = "red",
			Solid = true,
			Text = "X",
			TextSize = 44,
			Size = UDim2.fromOffset(76, 76),
			Position = UDim2.new(1, -22, 0, 22),
			AnchorPoint = Vector2.new(1, 0),
			Radius = 18,
			Button = true,
			ZIndex = 6,
		})
	end
	local body = new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(40, if o.Title then 120 else 30),
		Size = UDim2.new(1, -80, 1, if o.Title then -150 else -60),
	}, root)
	return root, body, close
end

-- Dark glass card (HUD chrome, list rows). o.Tint = ramp name: a faint coloured wash (ability cards).
function UIKit.card(parent: Instance, o: { [string]: any }): Frame
	local f = new("Frame", {
		Name = o.Name or "Card",
		BackgroundColor3 = o.Color or Theme.panel,
		BackgroundTransparency = o.Transparency or Theme.panelT,
		BorderSizePixel = 0,
		Size = o.Size or UDim2.fromOffset(300, 80),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.new(),
		LayoutOrder = o.LayoutOrder or 0,
		Visible = if o.Visible == nil then true else o.Visible,
		ZIndex = o.ZIndex or 1,
	}, parent)
	local radius = o.Radius or 14
	UIKit.corner(f, radius)
	local edge = UIKit.stroke(f, Theme.edge, o.Outline or 2)
	edge.Name = "Edge"
	edge.Transparency = Theme.edgeT
	if o.Tint then
		local ramp = Theme.ramps[o.Tint]
		new("UIGradient", {
			Name = "Tint",
			Color = ColorSequence.new(Theme.panel:Lerp(ramp.lip, 0.35), Theme.panel:Lerp(ramp.lip, 0.12)),
			Rotation = 90,
		}, f)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
	end
	if o.Studs then
		UIKit.studs(f, Theme.studT, o.TileSize or 48, radius)
	end
	return f
end

-- Progress bar: track + gradient fill + centred label. Returns root, fill, label.
function UIKit.bar(parent: Instance, o: { [string]: any }): (Frame, Frame, TextLabel)
	local ramp = Theme.ramps[o.Ramp or "green"]
	local track = new("Frame", {
		Name = o.Name or "Bar",
		BackgroundColor3 = Color3.fromRGB(8, 10, 14),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = o.Size or UDim2.fromOffset(400, 40),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.new(),
		LayoutOrder = o.LayoutOrder or 0,
	}, parent)
	UIKit.corner(track, UDim.new(0.5, 0))
	local edge = UIKit.stroke(track, Theme.edge, 2)
	edge.Transparency = 0.8
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(o.Value or 0, 1) }, track)
	UIKit.corner(fill, UDim.new(0.5, 0))
	UIKit.vgrad(fill, ramp.top, ramp.mid, ramp.lip)
	local label = UIKit.text(track, { Name = "Label", Text = o.Text or "", TextSize = o.TextSize or 26, Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	return track, fill, label
end

-- Simple shape glyphs (the project has no licensed icon pack: no emojis, no generated icons).
-- kind: "coin" | "gem" | "bag" | "bars" | "paw" | "list" | "zz" | "target" | "gear" | "egg"
function UIKit.glyph(parent: Instance, kind: string, o: { [string]: any }): Frame
	local size = o.Size or 48
	local root = new("Frame", {
		Name = o.Name or "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.new(),
		ZIndex = o.ZIndex or 2,
		LayoutOrder = o.LayoutOrder or 0,
	}, parent)
	local z = root.ZIndex
	local col = o.Color or Theme.white
	local function box(name: string, x: number, y: number, w: number, h: number, c: Color3, r: number?, rot: number?, zz: number?)
		local f = new("Frame", {
			Name = name,
			BackgroundColor3 = c,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			Rotation = rot or 0,
			ZIndex = zz or z,
		}, root)
		if r then
			UIKit.corner(f, UDim.new(r, 0))
		end
		return f
	end
	local function ink(f: Frame, t: number?)
		UIKit.stroke(f, Theme.ink, t or math.max(2, size / 18))
	end
	if kind == "coin" then
		local c = box("Disc", 0.5, 0.5, 0.9, 0.9, Color3.fromRGB(255, 196, 40), 0.5)
		ink(c)
		UIKit.vgrad(c, Color3.fromRGB(255, 232, 120), Color3.fromRGB(255, 200, 48), Color3.fromRGB(226, 140, 16))
		local ring = box("Ring", 0.5, 0.5, 0.56, 0.56, Color3.fromRGB(255, 214, 72), 0.5, nil, z + 1)
		ring.BackgroundTransparency = 1
		UIKit.stroke(ring, Color3.fromRGB(196, 120, 10), math.max(2, size / 16))
	elseif kind == "gem" then
		local g = box("Gem", 0.5, 0.5, 0.64, 0.64, Color3.fromRGB(70, 220, 130), 0.12, 45)
		ink(g)
		UIKit.vgrad(g, Color3.fromRGB(160, 255, 190), Color3.fromRGB(60, 220, 120), Color3.fromRGB(20, 150, 80))
		box("Shine", 0.4, 0.38, 0.14, 0.14, Color3.fromRGB(235, 255, 240), 0.5, 45, z + 1)
	elseif kind == "bag" then
		local b = box("Body", 0.5, 0.6, 0.78, 0.6, col, 0.18)
		ink(b)
		local h = box("Handle", 0.5, 0.26, 0.42, 0.34, col, 0.5)
		h.BackgroundTransparency = 1
		UIKit.stroke(h, col, math.max(3, size / 11))
	elseif kind == "bars" then
		for i, hgt in ipairs({ 0.45, 0.7, 0.95 }) do
			local b = box("Bar" .. i, 0.2 + (i - 1) * 0.3, 0.98 - hgt / 2, 0.22, hgt, col, 0.25)
			ink(b, 2)
		end
	elseif kind == "paw" then
		ink(box("Pad", 0.5, 0.66, 0.56, 0.46, col, 0.5))
		for i, pos in ipairs({ Vector2.new(0.2, 0.36), Vector2.new(0.4, 0.18), Vector2.new(0.6, 0.18), Vector2.new(0.8, 0.36) }) do
			ink(box("Toe" .. i, pos.X, pos.Y, 0.2, 0.24, col, 0.5), 2)
		end
	elseif kind == "list" then
		for i = 1, 3 do
			local y = 0.2 + (i - 1) * 0.3
			ink(box("Dot" .. i, 0.12, y, 0.16, 0.16, col, 0.5), 2)
			ink(box("Line" .. i, 0.6, y, 0.66, 0.14, col, 0.5), 2)
		end
	elseif kind == "zz" then
		UIKit.text(root, { Name = "Z", Text = "Zz", TextSize = size * 0.8, Size = UDim2.fromScale(1, 1), Color = col, ZIndex = z })
	elseif kind == "target" then
		local r = box("Ring", 0.5, 0.5, 0.78, 0.78, col, 0.5)
		r.BackgroundTransparency = 1
		UIKit.stroke(r, col, math.max(3, size / 10))
		ink(box("Dot", 0.5, 0.5, 0.2, 0.2, col, 0.5), 2)
		box("H", 0.5, 0.5, 1, 0.08, col)
		box("V", 0.5, 0.5, 0.08, 1, col)
	elseif kind == "gear" then
		for i = 0, 3 do
			box("Tooth" .. i, 0.5, 0.5, 0.94, 0.2, col, 0.2, i * 45)
		end
		local hub = box("Hub", 0.5, 0.5, 0.66, 0.66, col, 0.5, nil, z + 1)
		ink(hub, 2)
		box("Hole", 0.5, 0.5, 0.26, 0.26, Theme.panel, 0.5, nil, z + 2)
	elseif kind == "note" then
		-- two beamed eighth notes
		ink(box("HeadL", 0.27, 0.78, 0.3, 0.22, col, 0.5, -20), 2)
		ink(box("HeadR", 0.73, 0.68, 0.3, 0.22, col, 0.5, -20), 2)
		box("StemL", 0.38, 0.47, 0.09, 0.6, col)
		box("StemR", 0.84, 0.37, 0.09, 0.6, col)
		local beam = box("Beam", 0.61, 0.16, 0.56, 0.14, col, nil, -12)
		ink(beam, 2)
	elseif kind == "speaker" then
		ink(box("Box", 0.22, 0.5, 0.26, 0.36, col, 0.15), 2)
		ink(box("Cone", 0.42, 0.5, 0.3, 0.3, col, 0.1, 45), 2)
		box("ConeFill", 0.3, 0.5, 0.14, 0.36, col, nil, nil, z + 1)
		ink(box("Wave1", 0.7, 0.5, 0.1, 0.36, col, 0.5), 1.5)
		ink(box("Wave2", 0.88, 0.5, 0.1, 0.62, col, 0.5), 1.5)
	elseif kind == "egg" then
		UIKit.eggIcon(root, { Name = "Egg", Width = size * 0.72, Height = size * 0.9, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Tier = o.Tier or 1, ZIndex = z })
	end
	return root
end

-- Stud-style egg icon (stacked frames following the egg profile) for a tier.
local PROFILE = { 0.62, 0.9, 1.0, 0.98, 0.86, 0.66, 0.4 }
function UIKit.eggIcon(parent: Instance, o: { [string]: any }): Frame
	local w, h = o.Width or 64, o.Height or 80
	local root = new("Frame", {
		Name = o.Name or "EggIcon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(w, h),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.new(),
		LayoutOrder = o.LayoutOrder or 0,
		ZIndex = o.ZIndex or 1,
	}, parent)
	local ch = h / #PROFILE
	for i, f in ipairs(PROFILE) do
		local course = new("Frame", {
			Name = "Course" .. i,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -(i - 1) * ch),
			Size = UDim2.new(f, 0, 0, ch + 1),
			ZIndex = root.ZIndex,
		}, root)
		UIKit.corner(course, math.floor(ch * 0.35))
		course:SetAttribute("Course", i)
	end
	local band = new("Frame", { Name = "Band", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -2.5 * ch), Size = UDim2.new(1.02, 0, 0, ch * 0.55), ZIndex = root.ZIndex + 1 }, root)
	UIKit.corner(band, 3)
	local spots = new("Frame", { Name = "Spots", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = root.ZIndex + 1 }, root)
	for k, pos in ipairs({ Vector2.new(0.32, 0.36), Vector2.new(0.66, 0.3), Vector2.new(0.5, 0.18) }) do
		local s = new("Frame", { Name = "Spot" .. k, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(pos.X, pos.Y), Size = UDim2.fromOffset(w * 0.16, w * 0.16), ZIndex = root.ZIndex + 1 }, spots)
		UIKit.corner(s, UDim.new(0.3, 0))
	end
	UIKit.setEggIcon(root, o.Tier or 1)
	return root
end

function UIKit.setEggIcon(icon: Instance, tier: number)
	local def = TierConfig.get(tier)
	for _, c in ipairs(icon:GetChildren()) do
		if c:GetAttribute("Course") then
			c.BackgroundColor3 = def.shell
		end
	end
	local band = icon:FindFirstChild("Band")
	if band then
		band.Visible = tier >= 2
		band.BackgroundColor3 = def.spot
	end
	local spots = icon:FindFirstChild("Spots")
	if spots then
		spots.Visible = tier >= 3
		for _, s in ipairs(spots:GetChildren()) do
			s.BackgroundColor3 = def.spot
		end
	end
	icon:SetAttribute("Tier", tier)
end

-- Direction arrow built from frames (no icon pack in this project). Rotate the root.
-- Shaft + two chevron wings meeting at the apex; ink copies drawn behind give one clean outline.
function UIKit.arrow(parent: Instance, o: { [string]: any }): Frame
	local size = o.Size or 120
	local root = new("Frame", {
		Name = o.Name or "Arrow",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5),
	}, parent)
	local col = o.Color or Theme.ramps.green.mid
	local t, L = 0.22, 0.56
	local d = (L / 2) * math.sin(math.rad(45))
	local pieces = {
		{ "Shaft", 0.5, 0.56, t, 0.78, 0 },
		{ "WingL", 0.5 - d + 0.02, 0.1 + d, t, L, 45 },
		{ "WingR", 0.5 + d - 0.02, 0.1 + d, t, L, -45 },
	}
	for pass = 1, 2 do
		for _, pc in ipairs(pieces) do
			local grow = if pass == 1 then 10 else 0
			local f = new("Frame", {
				Name = pc[1] .. (if pass == 1 then "Ink" else ""),
				BackgroundColor3 = if pass == 1 then Theme.ink else col,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(pc[2], pc[3]),
				Size = UDim2.new(pc[4], grow, pc[5], grow),
				Rotation = pc[6],
				ZIndex = pass,
			}, root)
			UIKit.corner(f, 6)
		end
	end
	return root
end

-- Fit scale group: tagged so the client Fit module rescales it with the screen.
function UIKit.fit(group: GuiObject, base: number?): UIScale
	local s = group:FindFirstChild("Fit") or new("UIScale", { Name = "Fit" }, group)
	s.Scale = base or 1
	CollectionService:AddTag(group, "EOS_Fit")
	return s
end

return UIKit
