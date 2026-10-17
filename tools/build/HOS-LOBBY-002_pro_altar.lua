-- HOS-LOBBY-002: pro altar in the middle of the Halloween lobby plaza.
-- Lobby style: Plastic + Studs surfaces, the kit's stone purples, Neon only for glow accents.
local CHS = game:GetService("ChangeHistoryService")
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
local HALF = 7 -- dais half-width (corner blocks' outer faces)
local CORE = 6.95 -- core slab half-width (corner blocks sit 0.05 proud)
local ARM = 3 -- half-width of the cross walkway / stair flights
local RISE = 0.8
local D = 3 * RISE -- dais top above the plaza
local TREAD = 0.9
local CB_TOP = D + 1.8 -- corner block top
local CAP_T = 0.4

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
		box(cheek, "Low", Q, xa - 0.006, 0, z0 - 0.003, xb + 0.006, 1.4, CORE + 2 * TREAD + 0.35, C.stoneDark)
		box(cheek, "LowCap", Q, xa - 0.08, 1.4, z0 + 0.012, xb + 0.08, 1.65, CORE + 2 * TREAD + 0.45, C.stoneLight)
		box(cheek, "High", Q, xa, 0, z0 + 0.016, xb, 2.6, CORE + TREAD + 0.25, C.stoneDark)
		box(cheek, "HighCap", Q, xa - 0.085, 2.6, z0 + 0.02, xb + 0.085, 2.85, CORE + TREAD + 0.35, C.stoneLight)
	end

	-- corner block in this side's (+X, +Z) corner
	local corner = model("Corner", side)
	local cb = model("Block", corner)
	box(cb, "Body", Q, ARM, 0, ARM, HALF, CB_TOP, HALF, C.stone)
	box(cb, "BaseCourse", Q, ARM - 0.15, 0, ARM - 0.15, HALF + 0.15, 0.5, HALF + 0.15, C.stoneDark)
	box(cb, "FloorBand", Q, ARM - 0.1, D, ARM - 0.1, HALF + 0.1, D + 0.3, HALF + 0.1, C.stoneDark)
	box(cb, "Cap", Q, ARM - 0.25, CB_TOP, ARM - 0.25, HALF + 0.25, CB_TOP + CAP_T, HALF + 0.25, C.stoneLight)
	box(cb, "CapLip", Q, ARM - 0.12, CB_TOP - 0.2, ARM - 0.12, HALF + 0.12, CB_TOP + 0.05, HALF + 0.12, C.deep)
	-- cracks on the two outer faces (relief, like the kit's stone blocks)
	local cracks = {
		{ 0.6, 1.43, 0.5, 0.12 }, { 1.0, 1.28, 0.12, 0.4 }, { 2.6, 3.23, 0.4, 0.1 }, { 2.75, 2.98, 0.1, 0.37 }, { 1.8, 0.98, 0.3, 0.1 },
	}
	for i, c in cracks do
		local u, y, w, h = c[1], c[2], c[3], c[4]
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
	for _, c in { { "A05_Candle_Large", 1.45, 1.45 }, { "A05_Candle_Medium", 1.45, -1.45 }, { "A05_Candle_Small", -1.45, 1.45 } } do
		local m = kitClone(c[1], candles)
		local _, size = m:GetBoundingBox()
		m:PivotTo((Q * CFrame.new((ARM + HALF) / 2 + c[2], capTop + size.Y / 2 + 0.002, (ARM + HALF) / 2 + c[3])) * CFrame.Angles(0, math.rad(15 * (k + 1)), 0))
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

-- ===== centre: pedestal and trophy =====
local ped = model("Pedestal", root)
box(ped, "Medallion", O, -2.6, D, -2.6, 2.6, D + 0.12, 2.6, C.deep)
for _, s in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
	box(ped, "MedallionGem", O, s[1] * 2.25 - 0.18, D + 0.12, s[2] * 2.25 - 0.18, s[1] * 2.25 + 0.18, D + 0.17, s[2] * 2.25 + 0.18, C.glowPurple, { style = "neon", collide = false })
end
box(ped, "Plinth", O, -1.8, D + 0.12, -1.8, 1.8, D + 0.52, 1.8, C.stoneDark)
box(ped, "Body", O, -1.4, D + 0.52, -1.4, 1.4, D + 2.92, 1.4, C.black)
for _, s in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
	box(ped, "GoldEdge", O, s[1] * 1.4 - 0.1, D + 0.525, s[2] * 1.4 - 0.1, s[1] * 1.4 + 0.1, D + 2.86, s[2] * 1.4 + 0.1, C.gold, { style = "smooth" })
end
box(ped, "GoldLip", O, -1.53, D + 2.8, -1.53, 1.53, D + 2.9, 1.53, C.gold, { style = "smooth" })
box(ped, "Cap", O, -1.65, D + 2.92, -1.65, 1.65, D + 3.27, 1.65, C.deep)
-- glowing gold crown on every face of the body
for r = 0, 3 do
	local R = O * CFrame.Angles(0, r * math.pi / 2, 0)
	crown(ped, R, 0, D + 1.15, -1.47, -1.39, 1.15, C.gold, { style = "neon", collide = false }, C.black)
end

local trophy = model("Trophy", ped)
local T0 = D + 3.27
local pad = box(trophy, "GlowPad", O, -0.85, T0, -0.85, 0.85, T0 + 0.1, 0.85, C.gold, { style = "neon", collide = false })
T0 += 0.1
local tiers = {
	{ "Base", 1.3, 0, 0.3, C.goldDark }, { "Base2", 1.0, 0.3, 0.55, C.gold }, { "Stem", 0.35, 0.55, 1.25, C.gold },
	{ "Knot", 0.65, 0.85, 1.05, C.goldDark }, { "Cup1", 0.7, 1.25, 1.5, C.gold }, { "Cup2", 1.1, 1.5, 1.8, C.gold },
	{ "Cup3", 1.45, 1.8, 2.5, C.gold }, { "Rim", 1.65, 2.5, 2.7, C.goldDark },
}
for _, t in tiers do
	local h = t[2] / 2
	box(trophy, t[1], O, -h, T0 + t[3], -h, h, T0 + t[4], h, t[5], { style = t[2] >= 1 and "studs" or "smooth" })
end
box(trophy, "Inside", O, -0.62, T0 + 2.65, -0.62, 0.62, T0 + 2.71, 0.62, C.goldInner, { style = "smooth" })
for _, sx in { -1, 1 } do
	local a, b = sx * 0.7, sx * 1.15
	box(trophy, "Handle", O, math.min(a, b), T0 + 2.2, -0.12, math.max(a, b), T0 + 2.38, 0.12, C.gold, { style = "smooth" })
	box(trophy, "Handle", O, sx * 1.15 - 0.09, T0 + 1.597, -0.13, sx * 1.15 + 0.09, T0 + 2.383, 0.13, C.gold, { style = "smooth" })
	box(trophy, "Handle", O, math.min(sx * 0.62, sx * 1.15), T0 + 1.6, -0.124, math.max(sx * 0.62, sx * 1.15), T0 + 1.78, 0.124, C.gold, { style = "smooth" })
end
local glow = Instance.new("PointLight")
glow.Color = C.gold
glow.Brightness = 1.2
glow.Range = 14
glow.Parent = pad
local sparkle = Instance.new("ParticleEmitter")
sparkle.Name = "Sparkles"
sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparkle.Color = ColorSequence.new(C.gold)
sparkle.LightEmission = 1
sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
sparkle.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
sparkle.Lifetime = NumberRange.new(1.2, 2)
sparkle.Rate = 4
sparkle.Speed = NumberRange.new(0.6, 1.2)
sparkle.SpreadAngle = Vector2.new(25, 25)
sparkle.EmissionDirection = Enum.NormalId.Top
sparkle.Parent = pad

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
