--!nocheck
-- WorldKit: stud-style building helpers (studify doctrine, SurfaceType fallback because this place
-- has no stud MaterialVariants). Plastic everywhere, pattern by ROLE:
--   Universal = big fills / ground / panels, Weld = structure (posts, rails, frames, crates),
--   Studs = walls / roofs / accents, Inlet = rock tops, Smooth = tiny parts and Neon accents.
-- Every part is anchored and lives under a named Model hierarchy.

local CollectionService = game:GetService("CollectionService")

local Kit = {}

Kit.PAL = {
	grass = Color3.fromRGB(113, 200, 64),
	grassDark = Color3.fromRGB(88, 178, 56),
	grassCap = Color3.fromRGB(126, 214, 72),
	leaf = Color3.fromRGB(104, 196, 62),
	leaf2 = Color3.fromRGB(84, 175, 59),
	leaf3 = Color3.fromRGB(132, 214, 70),
	dirt = Color3.fromRGB(236, 142, 112),
	dirt2 = Color3.fromRGB(218, 112, 100),
	dirt3 = Color3.fromRGB(192, 94, 88),
	sand = Color3.fromRGB(242, 216, 160),
	stone = Color3.fromRGB(156, 166, 226),
	stone2 = Color3.fromRGB(132, 142, 210),
	stoneDark = Color3.fromRGB(108, 116, 186),
	water = Color3.fromRGB(70, 204, 242),
	wood = Color3.fromRGB(176, 112, 66),
	wood2 = Color3.fromRGB(146, 90, 56),
	trunk = Color3.fromRGB(232, 126, 120),
	trunk2 = Color3.fromRGB(218, 110, 108),
	white = Color3.fromRGB(246, 246, 240),
	cream = Color3.fromRGB(250, 238, 206),
	red = Color3.fromRGB(232, 74, 74),
	redDark = Color3.fromRGB(184, 52, 58),
	gold = Color3.fromRGB(255, 206, 64),
	blue = Color3.fromRGB(70, 150, 255),
	blueDark = Color3.fromRGB(40, 104, 214),
	pink = Color3.fromRGB(255, 132, 178),
	hay = Color3.fromRGB(242, 208, 104),
	hay2 = Color3.fromRGB(222, 182, 84),
	ink = Color3.fromRGB(7, 10, 14),
	roofTeal = Color3.fromRGB(84, 196, 186),
	zoneA = Color3.fromRGB(84, 168, 255),
	zoneB = Color3.fromRGB(255, 176, 56),
}
local PAL = Kit.PAL

Kit.CHECKER = "rbxassetid://111949839624798" -- uploaded EOS_Checker (2x2 checker)
Kit.FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)

local function applyPattern(p: BasePart, pattern: string)
	local surf
	if pattern == "Weld" then
		surf = Enum.SurfaceType.Weld
	elseif pattern == "Studs" then
		surf = Enum.SurfaceType.Studs
	elseif pattern == "Inlet" then
		surf = Enum.SurfaceType.Inlet
	elseif pattern == "Smooth" then
		surf = Enum.SurfaceType.Smooth
	else
		surf = Enum.SurfaceType.Universal
	end
	p.TopSurface = surf
	p.FrontSurface = surf
	p.BackSurface = surf
	p.LeftSurface = surf
	p.RightSurface = surf
	p.BottomSurface = if pattern == "Smooth" then Enum.SurfaceType.Smooth else Enum.SurfaceType.Inlet
end

-- brick(parent, name, size, cframe, color, opts) -> Part
-- opts: Pattern, Class, Material, Transparency, CanCollide, CastShadow, Tags {..}, Attrs {..}, Shape
function Kit.brick(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, opts: any?): BasePart
	opts = opts or {}
	local p = Instance.new(opts.Class or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = opts.Material or Enum.Material.Plastic
	if opts.Shape then
		p.Shape = opts.Shape
	end
	local tiny = size.X < 0.5 and size.Y < 0.5 and size.Z < 0.5
	if p.Material == Enum.Material.Neon or tiny then
		applyPattern(p, "Smooth")
	else
		applyPattern(p, opts.Pattern or "Universal")
	end
	if opts.Transparency then
		p.Transparency = opts.Transparency
	end
	if opts.CanCollide ~= nil then
		p.CanCollide = opts.CanCollide
	end
	if opts.CanQuery ~= nil then
		p.CanQuery = opts.CanQuery
	end
	if opts.CanTouch ~= nil then
		p.CanTouch = opts.CanTouch
	end
	if opts.CastShadow ~= nil then
		p.CastShadow = opts.CastShadow
	end
	if opts.CollisionGroup then
		p.CollisionGroup = opts.CollisionGroup
	end
	for _, t in ipairs(opts.Tags or {}) do
		CollectionService:AddTag(p, t)
	end
	for k, v in pairs(opts.Attrs or {}) do
		p:SetAttribute(k, v)
	end
	p.Parent = parent
	return p
end

-- axis-aligned box by world extents (x0..x1, y0..y1, z0..z1)
function Kit.box(parent, name, x0, x1, y0, y1, z0, z1, color, opts)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local c = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	return Kit.brick(parent, name, size, CFrame.new(c), color, opts)
end

function Kit.model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Kit.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- checker tint overlay on a big top face (production-baseplate recipe)
function Kit.checker(part: BasePart, studsPerTile: number?, transparency: number?)
	local t = Instance.new("Texture")
	t.Name = "Checker"
	t.Texture = Kit.CHECKER
	t.Face = Enum.NormalId.Top
	t.StudsPerTileU = studsPerTile or 8
	t.StudsPerTileV = studsPerTile or 8
	t.Transparency = transparency or 0.88
	t.Parent = part
	return t
end

-- ===== text =====

-- SurfaceGui with stacked lines: lines = { {text=, size=0..1 height fraction, color=} }
function Kit.surfaceText(part: BasePart, face: Enum.NormalId, lines: { any }, opts: any?): SurfaceGui
	opts = opts or {}
	local sg = Instance.new("SurfaceGui")
	sg.Name = opts.Name or "Text"
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = opts.PixelsPerStud or 40
	sg.LightInfluence = 0
	sg.MaxDistance = opts.MaxDistance or 260
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.Parent = holder
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = opts.VAlign or Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder
	for i, l in ipairs(lines) do
		local t = Instance.new("TextLabel")
		t.Name = l.name or ("Line" .. i)
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, l.size or 0.4)
		t.FontFace = Kit.FONT
		t.Text = l.text or ""
		t.TextScaled = true
		t.TextColor3 = l.color or Color3.new(1, 1, 1)
		t.TextXAlignment = l.align or Enum.TextXAlignment.Center
		local st = Instance.new("UIStroke")
		st.Color = PAL.ink
		st.Thickness = l.stroke or 4
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = t
		t.Parent = holder
	end
	sg.Parent = part
	return sg
end

-- floating bold sign text over a shop (style vocabulary)
function Kit.floatingText(parent: BasePart, text: string, color: Color3, studsWide: number, offsetY: number): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "FloatingSign"
	bb.Size = UDim2.new(studsWide, 0, studsWide * 0.22, 0)
	bb.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	bb.MaxDistance = 300
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Kit.FONT
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = color
	local st = Instance.new("UIStroke")
	st.Color = PAL.ink
	st.Thickness = 3
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.Parent = t
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.51, Color3.fromRGB(230, 230, 230)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
	})
	g.Rotation = 90
	g.Parent = t
	t.Parent = bb
	bb.Adornee = parent
	bb.Parent = parent
	return bb
end

-- ===== props =====

-- Voxel-blob tree (verified recipe from the style notes, scaled): coral trunk column with
-- roots growing out of the trunk, stepped round canopy with proud bump blocks.
function Kit.tree(parent: Instance, base: Vector3, height: number, rng: Random, leafColor: Color3?): Model
	local m = Kit.model(parent, "Tree")
	local leaf = leafColor or PAL.leaf
	local trunkH = height * 0.42
	local tw = math.max(1.6, height * 0.12)
	local segs = 4
	local y = base.Y
	for i = 1, segs do
		local h = trunkH / segs
		local off = Vector3.new(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
		Kit.brick(m, "Trunk" .. i, Vector3.new(tw - (i - 1) * 0.12, h + 0.2, tw - (i - 1) * 0.12), CFrame.new(base.X + off.X, y + h / 2, base.Z + off.Z), if i % 2 == 0 then PAL.trunk2 else PAL.trunk, { Pattern = "Weld" })
		y += h
	end
	-- roots: start on the trunk side ~1.5 up, angle down into the ground
	for k = 0, 3 do
		local ang = math.rad(k * 90 + rng:NextInteger(-1, 1) * 15)
		local dir = Vector3.new(math.sin(ang), 0, math.cos(ang))
		local start = base + dir * (tw / 2) + Vector3.new(0, 1.4, 0)
		local finish = base + dir * (tw / 2 + 1.6) + Vector3.new(0, 0.3, 0)
		local len = (finish - start).Magnitude + 0.4
		Kit.brick(m, "Root" .. k, Vector3.new(0.8, 0.8, len), CFrame.lookAt((start + finish) / 2, finish), PAL.trunk2, { Pattern = "Weld" })
		Kit.brick(m, "RootToe" .. k, Vector3.new(1.1, 0.5, 1.1), CFrame.new(finish.X, base.Y + 0.25, finish.Z), PAL.trunk2, { Pattern = "Weld" })
	end
	-- canopy
	local canopyH = height - trunkH
	local maxW = height * 0.55
	local profile = { 0.55, 0.82, 0.98, 1.0, 0.92, 0.74, 0.5 }
	local ch = canopyH / #profile
	local cy = y - ch * 0.6
	for i, f in ipairs(profile) do
		local w = maxW * f + rng:NextNumber(-0.8, 0.8)
		local d = maxW * f + rng:NextNumber(-0.8, 0.8)
		local jitter = Vector3.new(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6))
		local col = if rng:NextNumber() < 0.25 then leaf:Lerp(PAL.leaf3, 0.35) else leaf
		Kit.brick(m, "Canopy" .. i, Vector3.new(w, ch + 0.01 * i, d), CFrame.new(base.X + jitter.X, cy + ch / 2, base.Z + jitter.Z), col, { Pattern = "Studs" })
		-- proud bump blocks
		for b = 1, (if i >= 2 and i <= 5 then 2 else 0) do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = (math.max(w, d) / 2) * 0.9
			local bs = rng:NextNumber(1.6, 2.6)
			Kit.brick(m, "Bump", Vector3.new(bs, bs * 0.8, bs), CFrame.new(base.X + jitter.X + math.cos(a) * r, cy + ch / 2, base.Z + jitter.Z + math.sin(a) * r), if rng:NextNumber() < 0.4 then PAL.leaf2 else col, { Pattern = "Studs" })
		end
		cy += ch
	end
	return m
end

-- ranch fence: square posts every ~6 studs, two rails, Weld pattern, small imperfections
function Kit.fence(parent: Instance, a: Vector3, b: Vector3, rng: Random, opts: any?): Model
	opts = opts or {}
	local m = Kit.model(parent, opts.Name or "Fence")
	local dir = (b - a)
	local len = dir.Magnitude
	local n = math.max(1, math.floor(len / (opts.spacing or 6)))
	local postH = opts.height or 3.6
	local postColor = opts.postColor or PAL.wood
	local railColor = opts.railColor or PAL.wood2
	local look = CFrame.lookAt(a, b)
	for i = 0, n do
		local p = a + dir * (i / n)
		local h = postH + rng:NextNumber(-0.15, 0.15)
		Kit.brick(m, "Post", Vector3.new(1, h, 1), CFrame.new(p.X, p.Y + h / 2, p.Z) * look.Rotation, postColor, { Pattern = "Weld" })
	end
	local mid = (a + b) / 2
	for k, yy in ipairs({ postH * 0.72, postH * 0.36 }) do
		Kit.brick(m, "Rail" .. k, Vector3.new(0.6, 0.6, len + 0.4), CFrame.new(mid.X, mid.Y + yy, mid.Z) * look.Rotation * CFrame.new(rng:NextNumber(-0.05, 0.05), 0, 0), railColor, { Pattern = "Weld" })
	end
	return m
end

function Kit.rock(parent: Instance, base: Vector3, size: number, rng: Random): Model
	local m = Kit.model(parent, "Rock")
	local tones = { PAL.stone2, PAL.stone, PAL.stoneDark }
	local y = base.Y
	for i = 1, rng:NextInteger(2, 3) do
		local s = size * (1 - (i - 1) * 0.28)
		local h = s * 0.45
		local p = Kit.brick(m, "Slab" .. i, Vector3.new(s, h, s * rng:NextNumber(0.8, 1.1)), CFrame.new(base.X + rng:NextNumber(-0.3, 0.3) * size * 0.3, y + h / 2, base.Z + rng:NextNumber(-0.3, 0.3) * size * 0.3) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 5) * 15), 0), tones[rng:NextInteger(1, #tones)], { Pattern = "Smooth" })
		p.TopSurface = Enum.SurfaceType.Inlet
		y += h * 0.85
	end
	return m
end

function Kit.flower(parent: Instance, base: Vector3, color: Color3): Model
	local m = Kit.model(parent, "Flower")
	local y = base.Y + 0.2
	Kit.brick(m, "Center", Vector3.new(0.6, 0.4, 0.6), CFrame.new(base.X, y, base.Z), PAL.gold, { Pattern = "Smooth" })
	for k, off in ipairs({ Vector3.new(0.6, 0, 0), Vector3.new(-0.6, 0, 0), Vector3.new(0, 0, 0.6), Vector3.new(0, 0, -0.6) }) do
		Kit.brick(m, "Petal" .. k, Vector3.new(0.6, 0.39, 0.6), CFrame.new(base + off + Vector3.new(0, 0.2, 0)), color, { Pattern = "Smooth" })
	end
	return m
end

function Kit.tuft(parent: Instance, base: Vector3, rng: Random): Model
	local m = Kit.model(parent, "GrassTuft")
	for k = 1, rng:NextInteger(3, 4) do
		local h = rng:NextNumber(0.8, 1.5)
		local lean = math.rad((k - 2) * 15)
		Kit.brick(m, "Blade", Vector3.new(0.3, h, 0.3), CFrame.new(base + Vector3.new((k - 2) * 0.25, h / 2, rng:NextNumber(-0.2, 0.2))) * CFrame.Angles(0, 0, lean), PAL.leaf2, { Pattern = "Smooth" })
	end
	return m
end

-- hay bale: block with two darker twine bands (Weld pattern, it's a crate-like prop)
function Kit.hayBale(parent: Instance, cf: CFrame, size: Vector3): Model
	local m = Kit.model(parent, "HayBale")
	Kit.brick(m, "Bale", size, cf, PAL.hay, { Pattern = "Weld" })
	for k, f in ipairs({ -0.28, 0.28 }) do
		Kit.brick(m, "Twine" .. k, Vector3.new(size.X + 0.12, size.Y + 0.12, 0.35), cf * CFrame.new(0, 0, size.Z * f), PAL.hay2, { Pattern = "Smooth" })
	end
	return m
end

-- lamp post with a small plastic lamp (max 1-2 lamps per prop: no "AI glow")
function Kit.lamp(parent: Instance, base: Vector3): Model
	local m = Kit.model(parent, "Lamp")
	Kit.brick(m, "Foot", Vector3.new(1.6, 0.6, 1.6), CFrame.new(base + Vector3.new(0, 0.3, 0)), PAL.stoneDark, { Pattern = "Weld" })
	Kit.brick(m, "Pole", Vector3.new(0.6, 8, 0.6), CFrame.new(base + Vector3.new(0, 4.6, 0)), PAL.ink:Lerp(PAL.stoneDark, 0.6), { Pattern = "Weld" })
	Kit.brick(m, "Cap", Vector3.new(1.6, 0.4, 1.6), CFrame.new(base + Vector3.new(0, 9.9, 0)), PAL.ink:Lerp(PAL.stoneDark, 0.6), { Pattern = "Weld" })
	local bulb = Kit.brick(m, "Bulb", Vector3.new(1.1, 1.1, 1.1), CFrame.new(base + Vector3.new(0, 9.15, 0)), Color3.fromRGB(255, 236, 170), { Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 0.8
	light.Color = Color3.fromRGB(255, 226, 160)
	light.Parent = bulb
	return m
end

-- plateau mass (barrier/decor): stacked shrinking tiers, dirt sides, overhanging grass caps
function Kit.plateau(parent: Instance, center: Vector3, size: Vector3, tiers: number, rng: Random, yaw: number?): Model
	local m = Kit.model(parent, "Plateau")
	local rot = CFrame.Angles(0, math.rad(yaw or 0), 0)
	local y = center.Y
	local w, d = size.X, size.Z
	local tierH = size.Y / tiers
	for i = 1, tiers do
		local off = Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
		local dirtCol = if i == 1 then PAL.dirt3 elseif i == 2 then PAL.dirt2 else PAL.dirt
		local body = CFrame.new(center.X, y + tierH / 2, center.Z) * rot * CFrame.new(off)
		Kit.brick(m, "Tier" .. i, Vector3.new(w, tierH, d), body, dirtCol, { Pattern = "Studs" })
		local cap = Kit.brick(m, "Cap" .. i, Vector3.new(w + 1.6, 1.4, d + 1.6), CFrame.new(center.X, y + tierH + 0.7, center.Z) * rot * CFrame.new(off), PAL.grassCap, { Pattern = "Universal" })
		Kit.checker(cap, 8, 0.9)
		-- a nib per tier so the outline isn't one rectangle
		Kit.brick(m, "Nib" .. i, Vector3.new(4, tierH * 0.7, 3), body * CFrame.new(w / 2 - 1, -tierH * 0.15, d / 4), dirtCol, { Pattern = "Studs" })
		y += tierH
		w *= rng:NextNumber(0.62, 0.78)
		d *= rng:NextNumber(0.62, 0.78)
	end
	m:SetAttribute("TopY", y + 1.4)
	return m
end

-- Floating-island ground: grass cap (top at y=0) over salmon dirt strata that step inward,
-- with stepped edge nibs so the outline is never one rectangle. Returns the top slab.
function Kit.island(parent: Instance, x0: number, x1: number, z0: number, z1: number, rng: Random): BasePart
	local m = Kit.model(parent, "Island")
	local top = Kit.box(m, "GrassTop", x0, x1, -2, 0, z0, z1, PAL.grass, { Pattern = "Universal" })
	Kit.checker(top, 8, 0.88)
	Kit.box(m, "Strata1", x0 + 0.6, x1 - 0.6, -6, -2.0001, z0 + 0.6, z1 - 0.6, PAL.dirt, { Pattern = "Studs" })
	Kit.box(m, "Strata2", x0 + 3, x1 - 3, -11, -6.0001, z0 + 3, z1 - 3, PAL.dirt2, { Pattern = "Studs" })
	Kit.box(m, "Strata3", x0 + 7, x1 - 7, -16, -11.0001, z0 + 7, z1 - 7, PAL.dirt3, { Pattern = "Studs" })
	-- edge nibs on all four sides
	local function nibs(ax: string, fixed: number, from: number, to: number, outward: number)
		local pos = from + rng:NextNumber(2, 8)
		while pos < to - 6 do
			local len = rng:NextNumber(6, 16)
			local out = rng:NextNumber(2, 5)
			local depthBelow = rng:NextNumber(4, 9)
			local a, b = pos, math.min(pos + len, to - 2)
			local o0, o1 = fixed - (if outward > 0 then 0.5 else -0.5), fixed + outward * out
			local lo, hi = math.min(o0, o1), math.max(o0, o1)
			if ax == "x" then -- runs along X at constant Z
				Kit.box(m, "NibTop", a, b, -2 + 0.0003, -0.0003 - (if rng:NextNumber() < 0.3 then 0.4 else 0), lo, hi, PAL.grassCap, { Pattern = "Universal" })
				Kit.box(m, "NibDirt", a + 0.5, b - 0.5, -2 - depthBelow, -2, lo + (if outward > 0 then 0 else 0.6), hi - (if outward > 0 then 0.6 else 0), PAL.dirt, { Pattern = "Studs" })
			else
				Kit.box(m, "NibTop", lo, hi, -2 + 0.0003, -0.0003 - (if rng:NextNumber() < 0.3 then 0.4 else 0), a, b, PAL.grassCap, { Pattern = "Universal" })
				Kit.box(m, "NibDirt", lo + (if outward > 0 then 0 else 0.6), hi - (if outward > 0 then 0.6 else 0), -2 - depthBelow, -2, a + 0.5, b - 0.5, PAL.dirt, { Pattern = "Studs" })
			end
			pos = b + rng:NextNumber(3, 10)
		end
	end
	nibs("x", z0, x0, x1, -1)
	nibs("x", z1, x0, x1, 1)
	nibs("z", x0, z0, z1, -1)
	nibs("z", x1, z0, z1, 1)
	return top
end

-- invisible boundary wall around a rectangle (keeps players on the island)
function Kit.boundary(parent: Instance, x0: number, x1: number, z0: number, z1: number, height: number, opts: any?)
	local m = Kit.model(parent, (opts and opts.Name) or "Boundary")
	local t = 2
	local o = { Transparency = 1, CanQuery = false, CastShadow = false, Pattern = "Smooth" }
	if opts and opts.CollisionGroup then
		o.CollisionGroup = opts.CollisionGroup
	end
	Kit.box(m, "N", x0 - t, x1 + t, 0, height, z0 - t, z0, PAL.white, o)
	Kit.box(m, "S", x0 - t, x1 + t, 0, height, z1, z1 + t, PAL.white, o)
	Kit.box(m, "W", x0 - t, x0, 0, height, z0, z1, PAL.white, o)
	Kit.box(m, "E", x1, x1 + t, 0, height, z0, z1, PAL.white, o)
	return m
end

return Kit
