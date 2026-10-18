-- HOS-LOBBY-002: pro altar in the middle of the Halloween lobby plaza, with a summoning circle
-- in the middle where players stand to enter (SummonZone marks the volume for gameplay code).
-- HOS-LOBBY-003: ProGate = a tall fading beam wall round it and a PRO LOBBY / LOCKED sign over each
-- entrance; the client controller ProximityFade fades it in near the altar and out away from it.
-- Lobby style: Plastic + Studs surfaces, the kit's stone purples, Neon only for glow accents.
local CHS = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local kit = game:GetService("ServerStorage"):WaitForChild("HalloweenLobbyKit")

local CENTRE_XZ = Vector3.new(0, 0, 1500)
local groundOnly = RaycastParams.new()
groundOnly.FilterType = Enum.RaycastFilterType.Include
groundOnly.FilterDescendantsInstances = { workspace.Ground }
local hit = workspace:Raycast(CENTRE_XZ + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), groundOnly)
assert(hit and hit.Instance:IsDescendantOf(workspace.Ground), "centre ground not found")
local G = hit.Position.Y -- plaza top
local O = CFrame.new(CENTRE_XZ.X, G, CENTRE_XZ.Z)

-- palette (read from the lobby's kit and old central shrine)
local C = {
	stoneLight = Color3.fromRGB(93, 83, 121),
	stone = Color3.fromRGB(84, 72, 110),
	stoneDark = Color3.fromRGB(74, 63, 99),
	deep = Color3.fromRGB(47, 41, 68),
	crack = Color3.fromRGB(44, 36, 58),
	black = Color3.fromRGB(34, 28, 44),
	metal = Color3.fromRGB(58, 48, 54),
	wood = Color3.fromRGB(62, 46, 44),
	woodLight = Color3.fromRGB(77, 56, 51),
	glowOrange = Color3.fromRGB(255, 122, 26),
	glowPurple = Color3.fromRGB(180, 92, 255),
	banner = Color3.fromRGB(88, 40, 138),
	bannerDark = Color3.fromRGB(64, 28, 104),
	gold = Color3.fromRGB(255, 194, 58),
	goldDark = Color3.fromRGB(196, 140, 40),
	goldInner = Color3.fromRGB(120, 78, 22),
}

-- dimensions
local HALF = 11 -- dais half-width (corner blocks' outer faces)
local CORE = 10.95 -- core slab half-width (corner blocks sit 0.05 proud)
local ARM = 5.5 -- half-width of the cross walkway / stair flights (and of the open centre)
local RISE = 0.5
local D = 3 * RISE -- dais top above the plaza
local TREAD = 0.9
local CB_TOP = D + 0.6 -- corner block top (low plinths for the lamps and obelisks)
local CAP_T = 0.4
local CIRCLE = 1.2 -- summoning circle scale (1 = radius 3.2)

local root = Instance.new("Model")
root.Name = "ProAltar"

local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local STUDS, SMOOTH, INLET = Enum.SurfaceType.Studs, Enum.SurfaceType.Smooth, Enum.SurfaceType.Inlet
local function brick(parent, name, size, cf, color, opt)
	opt = opt or {}
	local p = Instance.new(opt.class or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.CastShadow = opt.shadow ~= false
	local style = opt.style or "studs"
	if style == "neon" then
		p.Material = Enum.Material.Neon
		p.CastShadow = false
	else
		p.Material = Enum.Material.Plastic
	end
	if style == "studs" then
		p.TopSurface, p.FrontSurface, p.BackSurface, p.LeftSurface, p.RightSurface = STUDS, STUDS, STUDS, STUDS, STUDS
		p.BottomSurface = INLET
	elseif style == "weld" then
		local W = Enum.SurfaceType.Weld
		p.TopSurface, p.FrontSurface, p.BackSurface, p.LeftSurface, p.RightSurface, p.BottomSurface = W, W, W, W, W, W
	else
		p.TopSurface, p.BottomSurface = SMOOTH, SMOOTH
	end
	if opt.collide == false then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	p.Parent = parent
	return p
end

-- box from min/max corners in a frame (keeps the maths readable)
local function box(parent, name, frame, x0, y0, z0, x1, y1, z1, color, opt)
	local size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	local mid = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	return brick(parent, name, size, frame * CFrame.new(mid), color, opt)
end

local function kitClone(name, parent, scale)
	local m = kit:FindFirstChild(name):Clone()
	if scale then
		m:ScaleTo(scale)
	end
	m.Parent = parent
	return m
end

-- crown emblem on a face: frame's -Z is the face normal, z0/z1 the plate depth range (z0 = outermost)
local function crown(parent, frame, cx, cy, z0, z1, s, color, opt, jewel)
	local function plate(name, x0, y0, x1, y1, dz)
		box(parent, name, frame, cx + x0 * s, cy + y0 * s, z0 - dz, cx + x1 * s, cy + y1 * s, z1 - dz, color, opt)
	end
	plate("CrownBand", -0.7, 0, 0.7, 0.3, 0)
	plate("CrownRim", -0.78, -0.1, 0.78, 0.02, -0.006)
	for i, x in { -0.52, 0, 0.52 } do
		local tall = i == 2 and 0.14 or 0
		plate("CrownPoint", x - 0.19, 0.3, x + 0.19, 0.6 + tall, 0.003)
		plate("CrownPoint", x - 0.11, 0.6 + tall, x + 0.11, 0.86 + tall, 0.006)
		plate("CrownTip", x - 0.08, 0.86 + tall, x + 0.08, 1.02 + tall, 0.009)
	end
	if jewel then
		for _, x in { -0.4, 0, 0.4 } do
			box(parent, "CrownJewel", frame, cx + (x - 0.07) * s, cy + 0.08 * s, z0 - 0.02, cx + (x + 0.07) * s, cy + 0.22 * s, z0 + 0.01, jewel, { style = "smooth", collide = false })
		end
	end
end

-- ===== dais core =====
local dais = model("Dais", root)
box(dais, "Core", O, -CORE, 0, -CORE, CORE, D, CORE, C.stoneLight)

-- ===== per side: stairs, cheeks, corner block (rotated four times) =====
for k = 0, 3 do
	local Q = O * CFrame.Angles(0, k * math.pi / 2, 0) -- local +Z = this side's outward direction
	local side = model(("Side_%d"):format(k + 1), root)

	-- stair flight (two steps below the dais top), embedded 0.05 into the core and the cheeks
	local stairs = model("Stairs", side)
	local z0 = CORE - 0.05
	box(stairs, "Step_Upper", Q, -ARM - 0.05, 0, z0 + 0.004, ARM + 0.05, 2 * RISE, CORE + TREAD, C.stone)
	box(stairs, "Step_Lower", Q, -ARM - 0.053, 0, z0 + 0.008, ARM + 0.053, RISE, CORE + 2 * TREAD, C.stone)
	-- glowing step noses (top step = the dais edge)
	for i, nose in { { D, CORE }, { 2 * RISE, CORE + TREAD }, { RISE, CORE + 2 * TREAD } } do
		local y, z = nose[1], nose[2]
		box(stairs, "GlowEdge_" .. i, Q, -ARM + 0.06, y - 0.1, z - 0.1, ARM - 0.06, y + 0.02, z + 0.02, C.glowOrange, { style = "neon", collide = false })
	end

	-- stair cheeks: a low outer tier and a taller inner tier, each capped
	for _, sx in { -1, 1 } do
		local cheek = model(sx < 0 and "Cheek_L" or "Cheek_R", stairs)
		local a, b = sx * (ARM - 0.05), sx * (ARM + 0.6)
		local xa, xb = math.min(a, b), math.max(a, b)
		box(cheek, "Low", Q, xa - 0.006, 0, z0 - 0.003, xb + 0.006, 1.75 * RISE, CORE + 2 * TREAD + 0.35, C.stoneDark)
		box(cheek, "LowCap", Q, xa - 0.08, 1.75 * RISE, z0 + 0.012, xb + 0.08, 1.75 * RISE + 0.25, CORE + 2 * TREAD + 0.45, C.stoneLight)
		box(cheek, "High", Q, xa, 0, z0 + 0.016, xb, D + 0.2, CORE + TREAD + 0.25, C.stoneDark)
		box(cheek, "HighCap", Q, xa - 0.085, D + 0.2, z0 + 0.02, xb + 0.085, D + 0.45, CORE + TREAD + 0.35, C.stoneLight)
	end

	-- corner block in this side's (+X, +Z) corner
	local corner = model("Corner", side)
	local cb = model("Block", corner)
	box(cb, "Body", Q, ARM, 0, ARM, HALF, CB_TOP, HALF, C.stone)
	box(cb, "BaseCourse", Q, ARM - 0.15, 0, ARM - 0.15, HALF + 0.15, 0.42, HALF + 0.15, C.stoneDark) -- stays below the bottom step's top
	box(cb, "Cap", Q, ARM - 0.25, CB_TOP, ARM - 0.25, HALF + 0.25, CB_TOP + CAP_T, HALF + 0.25, C.stoneLight)
	box(cb, "CapLip", Q, ARM - 0.12, CB_TOP - 0.2, ARM - 0.12, HALF + 0.12, CB_TOP + 0.05, HALF + 0.12, C.deep)
	-- cracks on the two outer faces (relief, like the kit's stone blocks)
	local cracks = {
		{ 0.7, 1.43, 0.5, 0.12 }, { 1.1, 1.28, 0.12, 0.4 }, { 3.2, 2.13, 0.4, 0.1 }, { 3.35, 1.88, 0.1, 0.37 }, { 2.1, 0.98, 0.3, 0.1 },
	}
	local yScale, uScale = (CB_TOP - 0.3) / 3.6, (HALF - ARM) / 4
	for i, c in cracks do
		local u, y, w, h = c[1] * uScale, c[2] * yScale, c[3], c[4]
		local proud = 0.05 + i * 0.008 -- every crack at its own depth
		box(cb, "Crack", Q, ARM + u, y, HALF - 0.02, ARM + u + w, y + h, HALF + proud, C.crack, { style = "smooth" })
		box(cb, "Crack", Q, HALF - 0.02, y + 0.15, HALF - u - w, HALF + proud, y + 0.15 + h, HALF - u, C.crack, { style = "smooth" })
	end

	local capTop = CB_TOP + CAP_T
	local capC = Q * CFrame.new((ARM + HALF) / 2, capTop, (ARM + HALF) / 2) -- centre of the cap's top face
	local outward = (Q * CFrame.new(1, 0, 1)).Position - Q.Position
	local F = CFrame.lookAt(capC.Position, capC.Position + outward.Unit) -- -Z faces out of the corner

	-- candles on three cap corners (the inner one stays clear)
	local candles = model("Candles", corner)
	for _, c in { { "A05_Candle_Large", 1, 1 }, { "A05_Candle_Medium", 1, -1 }, { "A05_Candle_Small", -1, 1 } } do
		local m = kitClone(c[1], candles)
		local _, size = m:GetBoundingBox()
		local off = (HALF - ARM) / 2 - 0.6
		m:PivotTo((Q * CFrame.new((ARM + HALF) / 2 + c[2] * off, capTop + size.Y / 2 + 0.002, (ARM + HALF) / 2 + c[3] * off)) * CFrame.Angles(0, math.rad(15 * (k + 1)), 0))
	end

	-- low spiked fence hugging the block's two outer faces
	local fence = model("SpikeFence", corner)
	local FL = HALF + 0.9 -- fence line
	local runs = {
		{ Vector3.new(ARM + 0.75, 0, FL), Vector3.new(FL, 0, FL) },
		{ Vector3.new(FL, 0, FL), Vector3.new(FL, 0, ARM - 0.3) },
	}
	for r, run in runs do
		local a, b = run[1], run[2]
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local n = math.max(2, math.floor(len / 1.1 + 0.5))
		local railCF = Q * CFrame.lookAt(a + (b - a) / 2, b) -- -Z along the run
		for _, ry in { 0.45 + r * 0.004, 1.15 + r * 0.004 } do
			brick(fence, "Rail", Vector3.new(0.14, 0.18, len + 0.1), railCF * CFrame.new(0, ry, 0), C.woodLight, { style = "weld" })
		end
		for i = (r == 1 and 0 or 1), n do
			local p = a + dir * (len * i / n)
			local h = 1.55 + ((i + r) % 2) * 0.15
			brick(fence, "Post", Vector3.new(0.26, h, 0.26), Q * CFrame.new(p + Vector3.new(0, h / 2, 0)), C.wood, { style = "weld" })
			brick(fence, "Spike", Vector3.new(0.22, 0.22, 0.22), Q * CFrame.new(p + Vector3.new(0, h + 0.06, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), C.wood, { style = "smooth" })
		end
	end

	-- jack-o'-lantern on the ground outside the corner, facing out
	local pumpkin = kitClone("A04_JackOLantern", corner, 0.85)
	pumpkin.Name = "JackOLantern"
	do
		local piv = pumpkin:GetPivot()
		local sum, n = Vector3.zero, 0
		for _, p in pumpkin:GetDescendants() do
			if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
				sum += p.Position
				n += 1
			end
		end
		local f = piv:VectorToObjectSpace(sum / n - piv.Position) * Vector3.new(1, 0, 1)
		local _, size = pumpkin:GetBoundingBox()
		local pos = (Q * CFrame.new(HALF + 3.0, size.Y / 2 + 0.002, HALF + 3.0)).Position
		local turn = CFrame.lookAt(Vector3.zero, outward.Unit) * CFrame.lookAt(Vector3.zero, f.Unit):Inverse()
		pumpkin:PivotTo(CFrame.new(pos) * turn.Rotation * CFrame.Angles(0, math.rad(k % 2 == 0 and 15 or -15), 0))
	end

	if k % 2 == 0 then
		-- ===== lamp post with two lanterns and a crown banner =====
		local lamp = model("LampPost", corner)
		box(lamp, "Plinth", F, -0.75, 0, -0.75, 0.75, 0.5, 0.75, C.stoneDark)
		box(lamp, "Plinth2", F, -0.6, 0.5, -0.6, 0.6, 0.8, 0.6, C.deep)
		box(lamp, "Shaft", F, -0.3, 0.8, -0.3, 0.3, 7.8, 0.3, C.metal, { style = "weld" })
		box(lamp, "Collar", F, -0.4, 1.1, -0.4, 0.4, 1.35, 0.4, C.deep, { style = "weld" })
		box(lamp, "Collar", F, -0.4, 6.9, -0.4, 0.4, 7.15, 0.4, C.deep, { style = "weld" })
		box(lamp, "CrossBar", F, -2.3, 7.25, -0.175, 2.3, 7.6, 0.175, C.metal, { style = "weld" })
		for _, sx in { -1, 1 } do
			box(lamp, "BarEnd", F, sx * 2.3 - 0.25, 7.175, -0.25, sx * 2.3 + 0.25, 7.675, 0.25, C.deep, { style = "weld" })
			box(lamp, "Brace", F, sx * 0.3 - (sx < 0 and 0.45 or 0), 6.75, -0.15, sx * 0.3 + (sx > 0 and 0.45 or 0), 7.26, 0.15, C.metal, { style = "weld" })
			local lan = kitClone("A03_HangingLantern", lamp)
			lan:PivotTo(F * CFrame.new(sx * 1.85, 7.25 + 0.1 - 2.015, 0) * CFrame.Angles(0, 0, math.pi / 2))
		end
		box(lamp, "Finial", F, -0.4, 7.8, -0.4, 0.4, 8.1, 0.4, C.deep, { style = "weld" })
		box(lamp, "Finial", F, -0.25, 8.1, -0.25, 0.25, 8.6, 0.25, C.metal, { style = "smooth" })
		box(lamp, "Finial", F, -0.15, 8.6, -0.15, 0.15, 8.95, 0.15, C.metal, { style = "smooth" })
		box(lamp, "Finial", F, -0.07, 8.95, -0.07, 0.07, 9.2, 0.07, C.gold, { style = "smooth" })

		-- banner hangs in front of the shaft on a short arm and rod
		local banner = model("Banner", lamp)
		box(banner, "Arm", F, -0.08, 6.95, -0.62, 0.08, 7.11, -0.28, C.metal, { style = "smooth" })
		box(banner, "Rod", F, -0.95, 6.9, -0.7, 0.95, 7.06, -0.54, C.metal, { style = "smooth" })
		box(banner, "Cloth", F, -0.75, 4.0, -0.68, 0.75, 6.92, -0.56, C.banner, { collide = false })
		for _, sx in { -1, 1 } do
			box(banner, "Tail", F, sx > 0 and 0.2 or -0.75, 3.45, -0.676, sx > 0 and 0.75 or -0.2, 4.01, -0.564, C.banner, { collide = false })
			box(banner, "TailTip", F, sx > 0 and 0.62 or -0.75, 3.3, -0.69, sx > 0 and 0.75 or -0.62, 3.46, -0.55, C.gold, { style = "smooth", collide = false })
			box(banner, "Trim", F, sx * 0.75 - 0.06, 4.0, -0.7, sx * 0.75 + 0.06, 6.92, -0.54, C.gold, { style = "smooth", collide = false })
		end
		box(banner, "Trim", F, -0.81, 6.72, -0.704, 0.81, 6.84, -0.536, C.gold, { style = "smooth", collide = false })
		box(banner, "Band", F, -0.69, 4.25, -0.684, 0.69, 4.45, -0.556, C.bannerDark, { style = "smooth", collide = false })
		-- gold crown on both faces of the cloth
		crown(banner, F, 0, 5.05, -0.72, -0.66, 0.62, C.gold, { style = "smooth", collide = false }, C.bannerDark)
		crown(banner, F * CFrame.Angles(0, math.pi, 0), 0, 5.05, 0.52, 0.58, 0.62, C.gold, { style = "smooth", collide = false }, C.bannerDark)
	else
		-- ===== purple-glow obelisk =====
		local ob = model("Obelisk", corner)
		box(ob, "Base", F, -0.85, 0, -0.85, 0.85, 0.5, 0.85, C.stoneDark)
		box(ob, "Base2", F, -0.7, 0.5, -0.7, 0.7, 0.8, 0.7, C.deep)
		box(ob, "Shaft", F, -0.55, 0.8, -0.55, 0.55, 4.0, 0.55, C.stone)
		for r = 0, 3 do
			local R = F * CFrame.Angles(0, r * math.pi / 2, 0)
			box(ob, "GlowPanel", R, -0.22, 1.3, -0.58, 0.22, 3.5, -0.53, C.glowPurple, { style = "neon", collide = false })
			box(ob, "Gem", R, -0.15, 4.55, -0.43, 0.15, 4.85, -0.38, C.gold, { style = "smooth" })
		end
		box(ob, "Band", F, -0.65, 4.0, -0.65, 0.65, 4.25, 0.65, C.deep)
		box(ob, "Upper", F, -0.4, 4.25, -0.4, 0.4, 5.25, 0.4, C.stone)
		box(ob, "Tip", F, -0.28, 5.25, -0.28, 0.28, 5.65, 0.28, C.stoneDark, { style = "smooth" })
		box(ob, "Tip", F, -0.16, 5.65, -0.16, 0.16, 6.0, 0.16, C.deep, { style = "smooth" })
		box(ob, "TipGlow", F, -0.08, 6.0, -0.08, 0.08, 6.3, 0.08, C.glowPurple, { style = "neon", collide = false })
		local light = Instance.new("PointLight")
		light.Color = C.glowPurple
		light.Brightness = 0.6
		light.Range = 9
		light.Parent = ob:FindFirstChild("Shaft")
	end
end

-- ===== centre: summoning circle (players stand here to enter) =====
local summon = model("SummoningCircle", root)
local F0 = D -- dais floor
-- stepped round floor disc (four overlapping slabs, each a hair taller so no tops are coplanar)
for i, r in { { 3.2, 1.2 }, { 2.95, 2.15 }, { 2.15, 2.95 }, { 1.2, 3.2 } } do
	box(summon, "Disc", O, -r[1] * CIRCLE, F0, -r[2] * CIRCLE, r[1] * CIRCLE, F0 + 0.12 + i * 0.004, r[2] * CIRCLE, C.deep)
end
local discTop = F0 + 0.12 + 4 * 0.004
-- glowing rings: 24 segments at 15-degree steps, alternate segments a hair taller
local function ring(name, radius, width, color)
	local len = 2 * radius * math.tan(math.rad(7.5)) + 0.04
	for i = 0, 23 do
		local a = math.rad(i * 15)
		local h = 0.06 + (i % 2) * 0.006
		local cf = O * CFrame.Angles(0, a, 0) * CFrame.new(0, discTop - 0.02 + h / 2, -radius)
		brick(summon, name, Vector3.new(len, h, width), cf, color, { style = "neon", collide = false })
	end
end
ring("OuterRing", 2.85 * CIRCLE, 0.22 * CIRCLE, C.glowPurple)
ring("InnerRing", 1.7 * CIRCLE, 0.16 * CIRCLE, C.glowOrange)
-- eight runes between the rings, two alternating shapes, each turned to face the centre
for i = 0, 7 do
	local R = O * CFrame.Angles(0, math.rad(i * 45), 0) * CFrame.new(0, discTop, -2.27 * CIRCLE)
	local function rune(x0, z0, x1, z1, t)
		box(summon, "Rune", R, x0, -0.02, z0, x1, 0.035 + t, z1, C.glowPurple, { style = "neon", collide = false })
	end
	rune(-0.05, -0.24, 0.05, 0.24, 0)
	if i % 2 == 0 then
		rune(-0.2, -0.05, 0.2, 0.05, 0.004)
	else
		rune(-0.18, -0.24, -0.08, -0.04, 0.004)
		rune(0.08, 0.04, 0.18, 0.24, 0.004)
	end
end
-- centre sigil: a glowing diamond with a dark heart
local D45 = O * CFrame.Angles(0, math.rad(45), 0)
box(summon, "Sigil", D45, -0.5, discTop - 0.02, -0.5, 0.5, discTop + 0.05, 0.5, C.glowPurple, { style = "neon", collide = false })
box(summon, "SigilHeart", D45, -0.25, discTop - 0.02, -0.25, 0.25, discTop + 0.058, 0.25, C.deep, { style = "smooth", collide = false })

-- rising motes and a purple glow over the circle
local fx = box(summon, "SummonFX", O, -2.4 * CIRCLE, discTop + 0.05, -2.4 * CIRCLE, 2.4 * CIRCLE, discTop + 0.15, 2.4 * CIRCLE, C.glowPurple, { style = "smooth", collide = false })
fx.Transparency = 1
local glow = Instance.new("PointLight")
glow.Color = C.glowPurple
glow.Brightness = 1
glow.Range = 12
glow.Parent = fx
local motes = Instance.new("ParticleEmitter")
motes.Name = "Motes"
motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
motes.Color = ColorSequence.new(C.glowPurple, Color3.fromRGB(255, 160, 90))
motes.LightEmission = 1
motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
motes.Lifetime = NumberRange.new(1.8, 2.8)
motes.Rate = 6
motes.Speed = NumberRange.new(0.8, 1.6)
motes.SpreadAngle = Vector2.new(10, 10)
motes.EmissionDirection = Enum.NormalId.Top
motes.Parent = fx

-- the volume players stand in to enter (no collision; for gameplay code to read)
local zone = box(summon, "SummonZone", O, -3.1 * CIRCLE, discTop, -3.1 * CIRCLE, 3.1 * CIRCLE, discTop + 7, 3.1 * CIRCLE, C.glowPurple, { style = "smooth" })
zone.Transparency = 1
zone.CanCollide = false
zone.CastShadow = false
zone:SetAttribute("Purpose", "Players standing in this volume are entering (summoning circle). Not wired to any code yet.")

-- ===== pro gate: tall beam wall + PRO LOBBY / LOCKED signs (HOS-LOBBY-003) =====
local GATE = HALF + 5 -- wall half-width: clear of the stairs and the jack-o'-lanterns
local BEAM_H = 70
local gate = model("ProGate", root)
gate:SetAttribute("FadeNear", GATE + 8) -- fully shown within this many studs of the centre
gate:SetAttribute("FadeFar", GATE + 20) -- fully hidden beyond this
CollectionService:AddTag(gate, "EOS_ProximityFade")

local WALL_T = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.08, 0.72),
	NumberSequenceKeypoint.new(0.4, 0.92), NumberSequenceKeypoint.new(1, 1),
})
local GLOW_T = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1),
})
-- one flat (not camera-facing) beam spanning a whole side, from the ground line straight up.
-- Attachment axes: X = up (the beam's run), Y = outward (the beam's face), Z = along the side (its width).
local function wallBeam(line: BasePart, Q: CFrame, name: string, height: number, width: number, transparency: NumberSequence, c0: Color3, c1: Color3)
	local base = (Q * CFrame.new(0, 0.03, GATE)).Position
	local up, out = Vector3.yAxis, Q.LookVector * -1 -- Q's -LookVector is its +Z, i.e. outward
	local function att(n: string, pos: Vector3)
		local a = Instance.new("Attachment")
		a.Name = n
		a.CFrame = line.CFrame:ToObjectSpace(CFrame.fromMatrix(pos, up, out))
		a.Parent = line
		return a
	end
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0 = att(name .. "Base", base)
	b.Attachment1 = att(name .. "Top", base + Vector3.new(0, height, 0))
	b.FaceCamera = false
	b.Width0, b.Width1 = width, width
	b.Segments = 16
	b.Color = ColorSequence.new(c0, c1)
	b.Transparency = transparency
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Brightness = 1
	b.Parent = line
	return b
end

-- sign style copied from the incubator sign (Workspace.Incubator A09_Sign*): stone plaque, navy inset panel,
-- lavender GothamSSm Heavy text with a purple outline, purple neon star diamonds, SurfaceGui brightness 2
local signFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local INC_PANEL = Color3.fromRGB(17, 18, 38)
local INC_TEXT = Color3.fromRGB(230, 200, 255)
local INC_STROKE = Color3.fromRGB(166, 64, 255)
for k = 0, 3 do
	local Q = O * CFrame.Angles(0, k * math.pi / 2, 0) -- local +Z = outward
	local side = model(("Side_%d"):format(k + 1), gate)
	-- glowing ground line along this side (alternate sides a hair taller so the corners don't flicker)
	local line = box(side, "GroundLine", Q, -GATE - 0.15, 0, GATE - 0.15, GATE + 0.15, 0.06 + (k % 2) * 0.006, GATE + 0.15, C.glowPurple, { style = "neon", collide = false })
	-- one full-length wall beam per side, plus a shorter brighter glow band at its foot
	wallBeam(line, Q, "Wall", BEAM_H, 2 * GATE + 0.3, WALL_T, C.glowPurple, INC_STROKE)
	wallBeam(line, Q, "WallGlow", 9, 2 * GATE + 0.3, GLOW_T, INC_TEXT, C.glowPurple)

	-- sign over the entrance, facing out, in front of the wall (the incubator sign's construction)
	local S = Q * CFrame.new(0, 7.7, GATE + 0.6) * CFrame.Angles(0, math.pi, 0) -- -Z faces out
	local signM = model("Sign", side)
	box(signM, "Plaque", S, -4.9, -2.05, -0.25, 4.9, 2.05, 0.25, C.deep, { collide = false })
	box(signM, "PlaqueCap", S, -5.05, 2.05, -0.3, 5.05, 2.4, 0.3, C.stoneDark, { collide = false })
	local panel = box(signM, "Panel", S, -4.5, -1.7, -0.3, 4.5, 1.7, -0.22, INC_PANEL, { collide = false })
	-- purple neon four-point stars either side of the title (like the incubator sign's)
	for _, sx in { -1, 1 } do
		local at = S * CFrame.new(sx * 3.95, 0.65, -0.33)
		brick(signM, "StarGlow", Vector3.new(0.3, 0.3, 0.06), at * CFrame.Angles(0, 0, math.rad(45)), C.glowPurple, { style = "neon", collide = false })
		brick(signM, "StarGlow", Vector3.new(0.08, 0.9, 0.064), at, C.glowPurple, { style = "neon", collide = false })
		brick(signM, "StarGlow", Vector3.new(0.7, 0.08, 0.068), at, C.glowPurple, { style = "neon", collide = false })
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = panel
	local fade = Instance.new("CanvasGroup") -- ProximityFade fades the text through this
	fade.Name = "Fade"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundTransparency = 1
	fade.Parent = gui
	local function label(name: string, text: string, y: number, h: number, w: number)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.AnchorPoint = Vector2.new(0.5, 0)
		t.Position = UDim2.fromScale(0.5, y)
		t.Size = UDim2.fromScale(w, h)
		t.BackgroundTransparency = 1
		t.FontFace = signFont
		t.Text = text
		t.TextScaled = true
		t.TextColor3 = INC_TEXT
		t.Parent = fade
		local st = Instance.new("UIStroke")
		st.Color = INC_STROKE
		st.Thickness = 3
		st.Parent = t
	end
	label("Title", "PRO LOBBY", 0.1, 0.46, 0.72)
	label("Status", "LOCKED", 0.6, 0.28, 0.5)
end
gate.WorldPivot = O

-- ===== place it =====
local rec = CHS:TryBeginRecording("HOS-LOBBY-002 pro altar")
local folder = workspace:FindFirstChild("CentralAltar")
local old = folder and folder:FindFirstChild("ProAltar")
if old then
	old:Destroy()
end
root.Parent = folder or workspace
root.WorldPivot = O
if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
local cf, size = root:GetBoundingBox()
local n = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("ProAltar built: %d parts, ground y %.2f, bbox %.1f x %.1f x %.1f"):format(n, G, size.X, size.Y, size.Z)
