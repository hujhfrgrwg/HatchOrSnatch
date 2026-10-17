--!nocheck
-- Haunted Graveyard (HOS-MAP-001, 17 Oct 2026, from Matthew's approved concept
-- docs/concepts/HOS-MAP-001_halloween_arena_concept.webp): night-time halloween arena, field 192 long
-- (Stadium size). NO cover: an empty dark-purple field with small coloured tile patches. The safe
-- zones are the glowing lanes past the field (purple A, orange B); past them is out-of-bounds paving.
-- No chalk lines, flags or tall back walls: the zone edge is where the field block ends.
-- Scenery only outside the fence: candle pillars in the fence, hanging-lantern posts, gravestones,
-- wooden crosses, jack-o'-lanterns, candle clusters, a glowing purple pool (lobby side), a red-roofed
-- shrine (back-left), a bubbling cauldron (east) and loose fence pieces to move around.
-- Trees, sky and anything off the island are placed by hand (Matthew).
local Kit = require(script.Parent.Parent.WorldKit)
local Frame = require(script.Parent.ArenaFrame)
local PAL = Kit.PAL

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local G = {
	field = rgb(88, 62, 128),
	pave = rgb(128, 106, 136), pave2 = rgb(112, 92, 124),
	stone = rgb(108, 98, 142), stone2 = rgb(92, 82, 124), stoneDark = rgb(74, 64, 104),
	cliff1 = rgb(92, 72, 128), cliff2 = rgb(74, 56, 110), cliff3 = rgb(58, 44, 92),
	laneA = rgb(132, 72, 214), laneB = rgb(232, 124, 52),
	glowA = rgb(186, 110, 255), glowB = rgb(255, 160, 70),
	wood = rgb(104, 64, 48), wood2 = rgb(128, 80, 56), woodDark = rgb(78, 50, 42),
	iron = rgb(52, 44, 62),
	grave = rgb(132, 128, 160), grave2 = rgb(112, 108, 140), graveLight = rgb(156, 152, 182),
	mound = rgb(98, 72, 84),
	pumpkin = rgb(236, 122, 40), pumpkin2 = rgb(214, 100, 34), stem = rgb(86, 110, 52),
	candle = rgb(246, 236, 206), flame = rgb(255, 190, 90),
	lantern = rgb(255, 156, 60), crystal = rgb(196, 120, 255),
	shrineRed = rgb(184, 52, 52), shrineRed2 = rgb(150, 40, 46), shrineWall = rgb(96, 58, 54),
	brew = rgb(176, 84, 255), pot = rgb(48, 42, 60),
}
-- field patches: mostly orange, some purple, a few dull green (as in the concept)
local PATCH = {
	rgb(196, 108, 64), rgb(196, 108, 64), rgb(214, 128, 70), rgb(214, 128, 70),
	rgb(122, 78, 176), rgb(104, 60, 120), rgb(72, 100, 84),
}

local THEME = {
	ground = G.pave, groundEdge = G.pave2,
	strata = { G.cliff1, G.cliff2, G.cliff3 },
	field = G.field, apron = G.stone, line = PAL.white,
	flagPost = G.iron, fencePost = G.wood, fenceRail = G.wood2,
	backWall = G.stone, backWallCap = G.stoneDark,
}

-- ===== small props (each its own Model; face = local -Z, pointed with CFrame.lookAt) =====
local function facing(base: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(base, base + Vector3.new(dir.X, 0, dir.Z))
end

local function candles(parent, base: Vector3, n: number, rng, spread: number?)
	local m = Kit.model(parent, "Candles")
	local sp = spread or 0.9
	for k = 1, n do
		local a = (k / n) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local r = if k == 1 then 0 else rng:NextNumber(sp * 0.55, sp)
		local w = rng:NextNumber(0.4, 0.55) + 0.0001 * k
		local h = rng:NextNumber(0.5, 1.4) + 0.0001 * k
		local p = base + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		Kit.brick(m, "Candle", Vector3.new(w, h, w), CFrame.new(p.X, p.Y + h / 2, p.Z), G.candle, { Pattern = "Smooth" })
		Kit.brick(m, "Flame", Vector3.new(0.22, 0.35, 0.22), CFrame.new(p.X, p.Y + h + 0.15, p.Z), G.flame, { Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	end
	return m
end

local function gravestone(parent, base: Vector3, dir: Vector3, s: number, rng)
	local m = Kit.model(parent, "Gravestone")
	local cf = facing(base, dir)
	local col = if rng:NextNumber() < 0.5 then G.grave else G.grave2
	Kit.brick(m, "Base", Vector3.new(3 * s, 0.5, 1.6 * s), cf * CFrame.new(0, 0.25, 0), G.stoneDark, { Pattern = "Weld" })
	local h = 2.6 * s
	Kit.brick(m, "Stone", Vector3.new(2.2 * s, h, 0.7 * s), cf * CFrame.new(0, 0.5 + h / 2, 0), col, { Pattern = "Studs" })
	-- stepped round top
	Kit.brick(m, "Top1", Vector3.new(1.6 * s, 0.4 * s, 0.7 * s), cf * CFrame.new(0, 0.5 + h + 0.2 * s, 0), col, { Pattern = "Studs" })
	Kit.brick(m, "Top2", Vector3.new(0.9 * s, 0.3 * s, 0.7 * s), cf * CFrame.new(0, 0.5 + h + 0.55 * s, 0), col, { Pattern = "Studs" })
	-- carved cross relief, proud of the face
	local fz = -0.35 * s - 0.05
	Kit.brick(m, "ReliefV", Vector3.new(0.3, 1.2 * s, 0.14), cf * CFrame.new(0, 0.5 + h * 0.62, fz), G.graveLight, { Pattern = "Smooth" })
	Kit.brick(m, "ReliefH", Vector3.new(0.9 * s, 0.3, 0.14), cf * CFrame.new(0, 0.5 + h * 0.72, fz - 0.0001), G.graveLight, { Pattern = "Smooth" })
	return m
end

local function crossGrave(parent, base: Vector3, dir: Vector3, rng)
	local m = Kit.model(parent, "CrossGrave")
	local cf = facing(base, dir)
	Kit.brick(m, "Mound", Vector3.new(2.2, 0.5, 3.4), cf * CFrame.new(0, 0.25, -1.6), G.mound, { Pattern = "Universal" })
	local lean = CFrame.Angles(0, 0, math.rad(if rng:NextNumber() < 0.4 then (if rng:NextNumber() < 0.5 then 15 else -15) else 0))
	local h = rng:NextNumber(4.4, 5.6)
	local pc = cf * lean
	local col = if rng:NextNumber() < 0.5 then G.wood else G.woodDark
	Kit.brick(m, "Post", Vector3.new(0.6, h, 0.6), pc * CFrame.new(0, h / 2, 0), col, { Pattern = "Weld" })
	Kit.brick(m, "Bar", Vector3.new(2.8, 0.6, 0.6001), pc * CFrame.new(0, h * 0.72, 0), col, { Pattern = "Weld" })
	return m
end

local function pumpkin(parent, base: Vector3, dir: Vector3, s: number)
	local m = Kit.model(parent, "Pumpkin")
	local cf = facing(base, dir)
	Kit.brick(m, "Body", Vector3.new(2.4 * s, 1.8 * s, 2.4 * s), cf * CFrame.new(0, 0.9 * s, 0), G.pumpkin, { Pattern = "Studs" })
	Kit.brick(m, "LobeX", Vector3.new(2.8 * s, 1.4 * s, 1.8 * s), cf * CFrame.new(0, 0.9 * s, 0), G.pumpkin2, { Pattern = "Studs" })
	Kit.brick(m, "LobeZ", Vector3.new(1.8 * s, 1.4 * s + 0.0002, 2.8 * s), cf * CFrame.new(0, 0.9 * s, 0), G.pumpkin2, { Pattern = "Studs" })
	Kit.brick(m, "Cap", Vector3.new(1.4 * s, 0.25 * s, 1.4 * s), cf * CFrame.new(0, 1.8 * s + 0.12 * s, 0), G.pumpkin2, { Pattern = "Studs" })
	Kit.brick(m, "Stem", Vector3.new(0.4 * s, 0.7 * s, 0.4 * s), cf * CFrame.new(0.1 * s, 2.05 * s + 0.3 * s, 0) * CFrame.Angles(0, 0, math.rad(15)), G.stem, { Pattern = "Smooth" })
	-- carved face on the -Z lobe (proud by 0.04, embedded 0.06)
	local fz = -1.4 * s - 0.04
	local glow = { Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }
	for _, ex in { -0.5, 0.5 } do
		Kit.brick(m, "Eye", Vector3.new(0.5 * s, 0.25 * s, 0.1), cf * CFrame.new(ex * s, 1.15 * s, fz), G.lantern, glow)
		Kit.brick(m, "EyeTip", Vector3.new(0.22 * s, 0.2 * s, 0.1), cf * CFrame.new(ex * s, 1.35 * s, fz + 0.0001), G.lantern, glow)
	end
	Kit.brick(m, "Mouth", Vector3.new(1.3 * s, 0.25 * s, 0.1), cf * CFrame.new(0, 0.6 * s, fz), G.lantern, glow)
	for _, tx in { -0.4, 0, 0.4 } do
		Kit.brick(m, "Tooth", Vector3.new(0.2 * s, 0.15 * s, 0.1), cf * CFrame.new(tx * s, 0.8 * s, fz + 0.0002), G.lantern, glow)
	end
	return m
end

local function ruin(parent, base: Vector3, dir: Vector3, rng)
	local m = Kit.model(parent, "StoneRuin")
	local cf = facing(base, dir)
	local cols = { G.stone, G.stone2, G.stoneDark }
	local y = 0
	local w, d = rng:NextNumber(3, 4.4), rng:NextNumber(2.2, 3)
	for k = 1, rng:NextInteger(2, 3) do
		local h = rng:NextNumber(1.2, 1.8)
		local off = CFrame.new(rng:NextNumber(-0.5, 0.5), y + h / 2, rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, math.rad(if k == 1 then 0 else rng:NextInteger(-1, 1) * 15), 0)
		Kit.brick(m, "Block" .. k, Vector3.new(w, h + 0.0001 * k, d), cf * off, cols[rng:NextInteger(1, #cols)], { Pattern = "Universal" })
		y += h
		w, d = w * rng:NextNumber(0.6, 0.8), d * rng:NextNumber(0.7, 0.9)
	end
	-- a fallen block beside the pile
	Kit.brick(m, "Fallen", Vector3.new(1.6, 1, 1.4), cf * CFrame.new(2.6, 0.5, 0.6) * CFrame.Angles(0, math.rad(30), 0), G.stone2, { Pattern = "Universal" })
	return m
end

-- concept lamp post: stone foot, dark post, purple crystal finial, arm with a hanging orange lantern
local function lanternPost(parent, base: Vector3, armDir: Vector3)
	local m = Kit.model(parent, "LanternPost")
	local cf = CFrame.lookAt(base, base + Vector3.new(armDir.X, 0, armDir.Z)) * CFrame.Angles(0, math.rad(90), 0) -- local +X = arm
	Kit.brick(m, "Foot", Vector3.new(1.8, 0.8, 1.8), cf * CFrame.new(0, 0.4, 0), G.stoneDark, { Pattern = "Weld" })
	Kit.brick(m, "Plinth", Vector3.new(1.3, 0.6, 1.3), cf * CFrame.new(0, 1.1, 0), G.stone2, { Pattern = "Weld" })
	Kit.brick(m, "Post", Vector3.new(0.9, 8.5, 0.9), cf * CFrame.new(0, 1.3 + 4.25, 0), G.iron, { Pattern = "Weld" })
	Kit.brick(m, "PostCap", Vector3.new(1.1, 0.3, 1.1), cf * CFrame.new(0, 9.95, 0), G.iron, { Pattern = "Weld" })
	Kit.brick(m, "Crystal", Vector3.new(0.6, 0.7, 0.6), cf * CFrame.new(0, 10.4, 0) * CFrame.Angles(0, math.rad(45), 0), G.crystal, { Material = Enum.Material.Neon, CastShadow = false })
	Kit.brick(m, "Arm", Vector3.new(2.8, 0.5, 0.5), cf * CFrame.new(1.4, 9.25, 0), G.iron, { Pattern = "Weld" })
	Kit.brick(m, "ArmTip", Vector3.new(0.7, 0.7, 0.7), cf * CFrame.new(2.8, 9.25, 0), G.iron, { Pattern = "Weld" })
	local lx = 2.4
	Kit.brick(m, "Chain", Vector3.new(0.15, 0.7, 0.15), cf * CFrame.new(lx, 8.68, 0), G.iron, { Pattern = "Smooth" })
	Kit.brick(m, "LanternCap", Vector3.new(1.2, 0.3, 1.2), cf * CFrame.new(lx, 8.25, 0), G.iron, { Pattern = "Weld" })
	local glow = Kit.brick(m, "LanternGlow", Vector3.new(0.8, 1.4, 0.8), cf * CFrame.new(lx, 7.42, 0), G.lantern, { Material = Enum.Material.Neon, CastShadow = false })
	Kit.brick(m, "LanternBase", Vector3.new(1.0, 0.25, 1.0), cf * CFrame.new(lx, 6.62, 0), G.iron, { Pattern = "Weld" })
	for _, c in { { -0.45, -0.45 }, { 0.45, -0.45 }, { -0.45, 0.45 }, { 0.45, 0.45 } } do
		Kit.brick(m, "LanternBar", Vector3.new(0.15, 1.45, 0.15), cf * CFrame.new(lx + c[1], 7.42, c[2]), G.iron, { Pattern = "Smooth" })
	end
	local light = Instance.new("PointLight")
	light.Range = 12
	light.Brightness = 0.9
	light.Color = G.lantern
	light.Parent = glow
	return m
end

-- a loose wooden fence piece (posts + two rails); broken ones lose a rail end and lean a post
local function looseFence(parent, a: Vector3, b: Vector3, rng, broken: boolean)
	local m = Kit.fence(parent, a, b, rng, { Name = "LooseFence", spacing = 3.5, postColor = G.wood, railColor = G.wood2 })
	if broken then
		local rail = m:FindFirstChild("Rail2")
		if rail then
			rail.Size = Vector3.new(rail.Size.X, rail.Size.Y, rail.Size.Z * 0.6)
			rail.CFrame = rail.CFrame * CFrame.new(0, 0, -rail.Size.Z * 0.33) * CFrame.Angles(math.rad(15), 0, 0)
		end
		for _, p in m:GetChildren() do
			if p.Name == "Post" then
				p.CFrame = p.CFrame * CFrame.new(0, -p.Size.Y / 2, 0) * CFrame.Angles(math.rad(15), 0, 0) * CFrame.new(0, p.Size.Y / 2, 0)
				break
			end
		end
	end
	return m
end

local function shrine(parent, cx: number, cz: number, rng)
	local m = Kit.model(parent, "Shrine")
	local hw, hd = 7, 6 -- wall half sizes (door faces +Z)
	local y0 = 1.2
	Kit.box(m, "Plinth", cx - hw - 1.5, cx + hw + 1.5, 0, y0, cz - hd - 1.5, cz + hd + 1.5, G.stoneDark, { Pattern = "Weld" })
	for i = 1, 2 do
		local d = cz + hd + 1.5 + (2 - i) * 1.2
		Kit.box(m, "Step" .. i, cx - 3.5, cx + 3.5, 0, i * 0.6 - 0.0001 * i, d - 0.0001, d + 1.2, G.stone2, { Pattern = "Weld" })
	end
	local wallTop = y0 + 7
	-- walls in strips around the door and windows (front), solid sides/back with a window each side
	local W = Kit.model(m, "Walls")
	local function wall(nm, x0, x1, ya, yb, z0, z1)
		Kit.box(W, nm, x0, x1, ya, yb, z0, z1, G.shrineWall, { Pattern = "Studs" })
	end
	local fz0, fz1 = cz + hd - 0.6, cz + hd
	-- front: door 3 wide x 5 tall at centre, windows 2.4 x 2.4 at x = +-4, sill 2.2 up
	wall("FrontL", cx - hw, cx - 5.2, y0, wallTop, fz0, fz1)
	wall("FrontR", cx + 5.2, cx + hw, y0, wallTop, fz0, fz1)
	for _, sx in { -1, 1 } do
		local a, b = cx + sx * 2.8, cx + sx * 1.5
		wall("FrontMid", math.min(a, b), math.max(a, b), y0, wallTop, fz0, fz1)
		local wa, wb = cx + sx * 5.2, cx + sx * 2.8
		wall("UnderWin", math.min(wa, wb), math.max(wa, wb), y0, y0 + 2.2, fz0, fz1)
		wall("OverWin", math.min(wa, wb), math.max(wa, wb), y0 + 4.6, wallTop, fz0, fz1)
	end
	wall("OverDoor", cx - 1.5, cx + 1.5, y0 + 5, wallTop, fz0, fz1)
	wall("Back", cx - hw, cx + hw, y0, wallTop, cz - hd, cz - hd + 0.6)
	for _, sx in { -1, 1 } do
		local x0, x1 = if sx < 0 then cx - hw else cx + hw - 0.6, if sx < 0 then cx - hw + 0.6 else cx + hw
		wall("SideBack", x0, x1, y0, wallTop, cz - hd + 0.6, cz - 1.2)
		wall("SideFront", x0, x1, y0, wallTop, cz + 1.2, fz0)
		wall("SideUnder", x0, x1, y0, y0 + 2.2, cz - 1.2, cz + 1.2)
		wall("SideOver", x0, x1, y0 + 4.6, wallTop, cz - 1.2, cz + 1.2)
	end
	-- warm glow filling the inside so every opening reads lit (embedded into the wall strips)
	Kit.box(m, "InteriorGlow", cx - hw + 0.5, cx + hw - 0.5, y0, wallTop - 0.2, cz - hd + 0.5, fz0 + 0.1, G.lantern, { Material = Enum.Material.Neon, CastShadow = false })
	-- frames: door, two front windows, one window each side (purple glow on the east side)
	local function frameZ(nm, x0, x1, ya, yb)
		Kit.box(m, nm .. "Head", x0 - 0.3, x1 + 0.3, yb, yb + 0.4, fz1 - 0.1, fz1 + 0.3, G.shrineRed, { Pattern = "Weld" })
		Kit.box(m, nm .. "JambL", x0 - 0.3, x0 + 0.1, ya, yb + 0.0001, fz1 - 0.1, fz1 + 0.3, G.shrineRed, { Pattern = "Weld" })
		Kit.box(m, nm .. "JambR", x1 - 0.1, x1 + 0.3, ya, yb + 0.0001, fz1 - 0.1, fz1 + 0.3, G.shrineRed, { Pattern = "Weld" })
	end
	frameZ("Door", cx - 1.5, cx + 1.5, y0, y0 + 5)
	Kit.box(m, "DoorMullion", cx - 0.1, cx + 0.1, y0, y0 + 5, fz0 + 0.1, fz1, G.shrineRed2, { Pattern = "Smooth" })
	for _, sx in { -1, 1 } do
		local a, b = cx + sx * 5.2, cx + sx * 2.8
		frameZ("Win", math.min(a, b), math.max(a, b), y0 + 2.2, y0 + 4.6)
		Kit.box(m, "WinSill", math.min(a, b) - 0.4, math.max(a, b) + 0.4, y0 + 1.9, y0 + 2.2001, fz1 - 0.1, fz1 + 0.6, G.shrineRed2, { Pattern = "Weld" })
		Kit.box(m, "WinMullion", (a + b) / 2 - 0.1, (a + b) / 2 + 0.1, y0 + 2.2, y0 + 4.6, fz0 + 0.1, fz1, G.shrineRed2, { Pattern = "Smooth" })
		-- side window glow pane (purple on the east, orange on the west) proud of the interior glow
		local fa, fb = cx + sx * (hw - 0.1), cx + sx * (hw + 0.3)
		local x0, x1 = math.min(fa, fb), math.max(fa, fb)
		Kit.box(m, "SideWinHead", x0, x1, y0 + 4.6, y0 + 5.0, cz - 1.5, cz + 1.5, G.shrineRed, { Pattern = "Weld" })
		Kit.box(m, "SideWinSill", x0, x1 + sx * 0.0001, y0 + 1.8, y0 + 2.2001, cz - 1.7, cz + 1.7, G.shrineRed2, { Pattern = "Weld" })
		Kit.box(m, "SideWinJambL", x0, x1, y0 + 2.2, y0 + 4.6001, cz - 1.5, cz - 1.1, G.shrineRed, { Pattern = "Weld" })
		Kit.box(m, "SideWinJambR", x0, x1, y0 + 2.2, y0 + 4.6001, cz + 1.1, cz + 1.5, G.shrineRed, { Pattern = "Weld" })
		Kit.box(m, "SideWinGlow", math.min(cx + sx * (hw - 0.6), cx + sx * (hw + 0.1)), math.max(cx + sx * (hw - 0.6), cx + sx * (hw + 0.1)), y0 + 2.2, y0 + 4.6, cz - 1.2, cz + 1.2, if sx > 0 then G.crystal else G.lantern, { Material = Enum.Material.Neon, CastShadow = false })
	end
	-- red corner posts + mid posts, proud of the walls
	for _, px in { -hw, hw } do
		for _, pz in { -hd, hd } do
			Kit.box(m, "CornerPost", cx + px - 0.6, cx + px + 0.6, y0, wallTop + 0.5, cz + pz - 0.6001, cz + pz + 0.6001, G.shrineRed, { Pattern = "Weld" })
		end
	end
	Kit.box(m, "Beam", cx - hw - 0.5, cx + hw + 0.5, wallTop, wallTop + 0.6, cz - hd - 0.5, cz + hd + 0.5, G.shrineRed2, { Pattern = "Weld" })
	-- stepped pagoda roof: wide eave, shrinking rows, upturned corner tips, ridge + purple crystal
	local roof = Kit.model(m, "Roof")
	local ry = wallTop + 0.6
	Kit.box(roof, "Eave", cx - hw - 2.6, cx + hw + 2.6, ry, ry + 0.7, cz - hd - 2.6, cz + hd + 2.6, G.shrineRed, { Pattern = "StudsNoGrid" })
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local tx, tz = cx + sx * (hw + 2.1), cz + sz * (hd + 2.1)
			Kit.box(roof, "EaveTip", tx - 0.5, tx + 0.5, ry + 0.7, ry + 1.3, tz - 0.5, tz + 0.5, G.shrineRed2, { Pattern = "Weld" })
		end
	end
	local rowY = ry + 0.7
	for i = 1, 5 do
		local w, d = hw + 1.5 - (i - 1) * 1.7, hd + 1.5 - (i - 1) * 1.6
		if w < 1.5 then break end
		Kit.box(roof, "RoofStep" .. i, cx - w, cx + w, rowY, rowY + 1.1, cz - d, cz + d - 0.0001 * i, if i % 2 == 0 then G.shrineRed2 else G.shrineRed, { Pattern = "StudsNoGrid" })
		rowY += 1.1
	end
	Kit.box(roof, "Ridge", cx - 1.2, cx + 1.2, rowY, rowY + 0.6, cz - 0.6, cz + 0.6, G.shrineRed2, { Pattern = "Weld" })
	Kit.brick(roof, "Crystal", Vector3.new(1, 1.6, 1), CFrame.new(cx, rowY + 1.4, cz) * CFrame.Angles(0, math.rad(45), 0), G.crystal, { Material = Enum.Material.Neon, CastShadow = false })
	-- wall lantern on the front-left corner post, candles on the steps
	local lm = Kit.model(m, "WallLantern")
	local lx, lz = cx - hw - 1.4, cz + hd + 0.3
	Kit.box(lm, "Bracket", lx - 0.2, cx - hw - 0.5, y0 + 5.6, y0 + 6, lz - 0.2, lz + 0.2, G.iron, { Pattern = "Smooth" })
	Kit.box(lm, "Cap", lx - 0.6, lx + 0.6, y0 + 5.2, y0 + 5.5, lz - 0.6, lz + 0.6, G.iron, { Pattern = "Weld" })
	Kit.box(lm, "Glow", lx - 0.4, lx + 0.4, y0 + 3.9, y0 + 5.25, lz - 0.4, lz + 0.4, G.lantern, { Material = Enum.Material.Neon, CastShadow = false })
	Kit.box(lm, "Base", lx - 0.5, lx + 0.5, y0 + 3.7, y0 + 3.95, lz - 0.5, lz + 0.5, G.iron, { Pattern = "Weld" })
	candles(m, Vector3.new(cx - 2.6, 1.2, cz + hd + 2.1), 3, rng, 0.4)
	candles(m, Vector3.new(cx + 2.6, 0.6, cz + hd + 3.3), 2, rng, 0.4)
	return m
end

local function cauldron(parent, cx: number, cz: number, rng)
	local m = Kit.model(parent, "Cauldron")
	-- two stepped stone rings (cross-shaped slabs read as chamfered octagons)
	local function cross(nm, w, cut, ya, yb, col, pat)
		Kit.box(m, nm .. "A", cx - w, cx + w, ya, yb, cz - w + cut, cz + w - cut, col, { Pattern = pat })
		Kit.box(m, nm .. "B", cx - w + cut, cx + w - cut, ya + 0.0001, yb + 0.0001, cz - w, cz + w, col, { Pattern = pat })
	end
	cross("Ring1", 4.2, 1.2, 0, 0.8, G.stone2, "Weld")
	cross("Ring2", 3.4, 1.0, 0.8, 1.6, G.stone, "Weld")
	-- pot: chamfered body, darker rim, glowing brew sunk just below the rim
	cross("Pot", 2.2, 0.6, 1.6, 4.0, G.pot, "Studs")
	cross("PotRim", 2.5, 0.7, 4.0, 4.4, G.iron, "Weld")
	cross("Brew", 2.0, 0.5, 4.2, 4.5, G.brew, "Smooth")
	for _, d in m:GetChildren() do
		if d.Name:sub(1, 4) == "Brew" then
			d.Material = Enum.Material.Neon
			d.CastShadow = false
		end
	end
	for k = 1, 5 do
		local s = rng:NextNumber(0.3, 0.6)
		Kit.brick(m, "Bubble", Vector3.new(s, s, s), CFrame.new(cx + rng:NextNumber(-1.3, 1.3), 4.6 + rng:NextNumber(0, 1.6), cz + rng:NextNumber(-1.3, 1.3)), G.glowA, { Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	end
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 1
	light.Color = G.brew
	light.Parent = m:FindFirstChild("BrewA")
	-- spilled potion puddle + a stack of logs by the ring
	Kit.box(m, "Puddle", cx + 4.4, cx + 6.8, 0, 0.08, cz + 1.2, cz + 3.1, G.brew, { Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	for k, lg in { { 0, -3.4 }, { 0, -2.6 }, { 0.7, -3.0 } } do
		Kit.box(m, "Log", cx - 7.2, cx - 4.7 + 0.0001 * k, lg[1], lg[1] + 0.7 + 0.0001 * k, cz + lg[2] - 0.35, cz + lg[2] + 0.35, if k % 2 == 0 then G.wood else G.wood2, { Pattern = "Weld" })
	end
	return m
end

return function(world: Instance, def)
	local rng = Random.new(3131)
	local arena, F = Frame.build(world, def, THEME, rng)
	local X, Z, FX, OUT, HZ = F.X, F.Z, F.FX, F.OUT, F.HZ
	local fen, isl = F.fence, F.island
	-- neon decoration that must never block gameplay raycasts or touches
	local function glowOpts()
		return { Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
	end

	-- props stay out of each other: circles { x, z, r } already used
	local taken = {}
	local function free(x, z, r)
		for _, t in taken do
			if (Vector2.new(x, z) - Vector2.new(t[1], t[2])).Magnitude < r + t[3] then
				return false
			end
		end
		return true
	end
	local function take(x, z, r)
		table.insert(taken, { x, z, r })
	end
	local function takeLine(a: Vector3, b: Vector3, r)
		local n = math.max(1, math.ceil((b - a).Magnitude / 2))
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			take(p.X, p.Z, r)
		end
	end

	-- ===== the zone edge is the end of the field block: no chalk lines =====
	local chalk = arena:FindFirstChild("ChalkLines")
	if chalk then
		chalk:Destroy()
	end
	-- field checker on a 4-stud tile so the patches below sit on its grid
	local checker = arena.Ground.Field:FindFirstChild("Checker")
	if checker then
		checker.StudsPerTileU = 8
		checker.StudsPerTileV = 8
		checker.Transparency = 0.95
	end
	local paving = arena.Ground.Island.GroundTop:FindFirstChild("Checker")
	if paving then
		paving.Transparency = 0.94
	end

	-- ===== glowing safe-zone lanes, low stone kerb behind them, lantern posts instead of flags =====
	local zones = arena.SafeZones
	local lamps = Kit.model(arena, "LanternPosts")
	for _, z in { { "A", -1, G.laneA, G.glowA }, { "B", 1, G.laneB, G.glowB } } do
		local side, sx, lane, glow = z[1], z[2], z[3], z[4]
		local zm = zones:FindFirstChild("Zone" .. side)
		for _, d in zm:GetChildren() do
			if d.Name == "Flag" or d.Name == "FlagPost" then
				d:Destroy()
			end
		end
		zm.Pad.Color = lane
		-- glow strips along both long edges of the lane, on the Pad (CanQuery off: zone raycasts hit the Pad)
		for _, ex in { X + sx * (FX + 0.35), X + sx * (OUT - 0.65) } do
			Kit.box(zm, "GlowEdge", ex - 0.25, ex + 0.25, 0.2, 0.26, Z - HZ, Z + HZ, glow, glowOpts())
		end
		local wall = zm.BackWall
		wall.Size = Vector3.new(wall.Size.X, 0.6, wall.Size.Z)
		wall.Position = Vector3.new(wall.Position.X, 0.3, wall.Position.Z)
		local cap = zm.BackWallCap
		cap.Size = Vector3.new(cap.Size.X, 0.3, cap.Size.Z)
		cap.Position = Vector3.new(cap.Position.X, 0.75, cap.Position.Z)
		for _, sz in { -1, 1 } do
			lanternPost(lamps, Vector3.new(X + sx * FX, 0.19, Z + sz * (HZ + 1.5)), Vector3.new(sx, 0, 0))
		end
	end

	-- ===== coloured tile patches on the field (flat, on the 4-stud grid, never touching) =====
	local patches = Kit.model(arena.Ground, "FieldPatches")
	local CELL = 4
	local nx, nz = math.floor(2 * FX / CELL), math.floor(2 * HZ / CELL)
	local used = {}
	local placed, tries = 0, 0
	while placed < 72 and tries < 600 do
		tries += 1
		local w = if rng:NextNumber() < 0.45 then 2 else 1
		local d = if rng:NextNumber() < 0.35 then 2 else 1
		local i0, j0 = rng:NextInteger(0, nx - w), rng:NextInteger(0, nz - d)
		local ok = true
		for i = i0 - 1, i0 + w do
			for j = j0 - 1, j0 + d do
				if used[i .. "," .. j] then
					ok = false
				end
			end
		end
		if ok then
			for i = i0, i0 + w - 1 do
				for j = j0, j0 + d - 1 do
					used[i .. "," .. j] = true
				end
			end
			local x0, z0 = X - FX + i0 * CELL, Z - HZ + j0 * CELL
			Kit.box(patches, "Patch", x0, x0 + w * CELL, 0.2, 0.26, z0, z0 + d * CELL, PATCH[rng:NextInteger(1, #PATCH)], { Pattern = "Universal", CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
			placed += 1
		end
	end

	-- ===== fence: every 4th post becomes a stone pillar with a candle on top and candles at its foot =====
	for _, f in arena.Perimeter:GetChildren() do
		if f.Name == "Fence" then
			local posts = {}
			for _, p in f:GetChildren() do
				if p.Name == "Post" then
					table.insert(posts, p)
				end
			end
			local alongX = math.abs(posts[1].Position.X - posts[#posts].Position.X) > 1
			table.sort(posts, function(a, b)
				return if alongX then a.Position.X < b.Position.X else a.Position.Z < b.Position.Z
			end)
			for i, p in posts do
				if i > 1 and i < #posts and (i - 1) % 4 == 0 then
					local pos = p.Position
					p:Destroy()
					local pil = Kit.model(f, "CandlePillar")
					Kit.box(pil, "Pillar", pos.X - 0.9, pos.X + 0.9, 0, 4, pos.Z - 0.9, pos.Z + 0.9, G.stone2, { Pattern = "Weld" })
					Kit.box(pil, "PillarCap", pos.X - 1.1, pos.X + 1.1, 4, 4.4, pos.Z - 1.1, pos.Z + 1.1, G.stoneDark, { Pattern = "Weld" })
					Kit.box(pil, "Candle", pos.X - 0.35, pos.X + 0.35, 4.4, 5.3, pos.Z - 0.35, pos.Z + 0.35, G.candle, { Pattern = "Smooth" })
					Kit.brick(pil, "Flame", Vector3.new(0.3, 0.45, 0.3), CFrame.new(pos.X, 5.52, pos.Z), G.flame, { Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
					local out = if alongX then Vector3.new(0, 0, if pos.Z > Z then 1 else -1) else Vector3.new(if pos.X > X then 1 else -1, 0, 0)
					local cpos = Vector3.new(pos.X, 0, pos.Z) + out * 1.9 + (if alongX then Vector3.new(0.6, 0, 0) else Vector3.new(0, 0, 0.6))
					candles(pil, cpos, 3, rng)
					take(cpos.X, cpos.Z, 1.2)
				end
			end
		end
	end
	for _, f in arena.Perimeter:GetChildren() do
		if f.Name == "Fence" then
			local zs, xs = {}, {}
			for _, p in f:GetChildren() do
				if p.Name == "Post" then
					table.insert(zs, p.Position.Z)
					table.insert(xs, p.Position.X)
				end
			end
			if #xs > 1 and math.abs(xs[1] - xs[#xs]) < 1 then -- runs along Z (west / east side)
				for _, p in f:GetChildren() do
					if p.Name == "Post" and (math.abs(p.Position.Z - fen.z0) < 0.5 or math.abs(p.Position.Z - fen.z1) < 0.5) then
						p:Destroy()
					elseif p.Name == "Rail1" or p.Name == "Rail2" then
						p.Position += Vector3.new(0, 0.002, 0)
					end
				end
			end
		end
	end
	takeLine(Vector3.new(fen.x0, 0, fen.z0), Vector3.new(fen.x1, 0, fen.z0), 1.2)
	takeLine(Vector3.new(fen.x0, 0, fen.z1), Vector3.new(fen.x1, 0, fen.z1), 1.2)
	takeLine(Vector3.new(fen.x0, 0, fen.z0), Vector3.new(fen.x0, 0, fen.z1), 1.2)
	takeLine(Vector3.new(fen.x1, 0, fen.z0), Vector3.new(fen.x1, 0, fen.z1), 1.2)

	-- ===== chunky stone columns hanging under the island edge, alternating depth and proudness =====
	local cols = Kit.model(arena.Ground.Island, "CliffColumns")
	local function columnRun(alongX, fixed, from, to, outward)
		local p = from
		local k = 0
		while p < to - 0.5 do
			k += 1
			local w = math.min(rng:NextNumber(6, 12), to - p)
			local bottom = -rng:NextNumber(9, 22)
			local proud = if k % 2 == 0 then 0.3 else 0.8
			local o1, o0 = fixed + outward * proud, fixed + outward * (proud - 5)
			local lo, hi = math.min(o0, o1), math.max(o0, o1)
			local col = if k % 2 == 0 then G.cliff1 else G.cliff2
			if alongX then
				Kit.box(cols, "Column", p, p + w, bottom, -2.0002, lo, hi, col, { Pattern = "Studs" })
			else
				Kit.box(cols, "Column", lo, hi, bottom, -2.0002, p, p + w, col, { Pattern = "Studs" })
			end
			p += w
		end
	end
	columnRun(true, isl.z0 + 0.5, isl.x0 + 0.5, isl.x1 - 0.5, -1)
	columnRun(true, isl.z1 - 0.5, isl.x0 + 0.5, isl.x1 - 0.5, 1)
	columnRun(false, isl.x0 + 0.5, isl.z0 + 6, isl.z1 - 6, -1)
	columnRun(false, isl.x1 - 0.5, isl.z0 + 6, isl.z1 - 6, 1)

	local scen = Kit.model(arena, "Scenery")
	local graves = Kit.model(scen, "Graveyard")
	local toCam = Vector3.new(0, 0, 1) -- the concept camera (and the lobby) is on the +Z side

	-- ===== glowing purple pool on the lobby side: stone rim, a broken fence and candles in it =====
	local pool = Kit.model(scen, "GlowPool")
	local px0, px1, pz0, pz1 = X + 8, X + 88, fen.z1 + 5, fen.z1 + 17
	Kit.box(pool, "Water", px0 + 1, px1 - 1, 0, 0.1, pz0 + 1, pz1 - 1, G.laneA, { Pattern = "Studs" })
	Kit.box(pool, "GlowN", px0 + 1, px1 - 1, 0.1, 0.16, pz0 + 1, pz0 + 1.4, G.glowA, glowOpts())
	Kit.box(pool, "GlowS", px0 + 1, px1 - 1, 0.1, 0.16, pz1 - 1.4, pz1 - 1, G.glowA, glowOpts())
	local x = px0
	local k = 0
	while x < px1 - 0.5 do
		k += 1
		local w = math.min(rng:NextNumber(3, 5), px1 - x)
		local h = 0.5 + (k % 2) * 0.1
		Kit.box(pool, "RimN", x, x + w, 0, h, pz0, pz0 + 1, if k % 2 == 0 then G.stone else G.stone2, { Pattern = "Weld" })
		Kit.box(pool, "RimS", x, x + w, 0, h + 0.0001, pz1 - 1, pz1, if k % 2 == 0 then G.stone2 else G.stone, { Pattern = "Weld" })
		x += w
	end
	Kit.box(pool, "RimW", px0, px0 + 1, 0, 0.55, pz0 + 1, pz1 - 1, G.stone2, { Pattern = "Weld" })
	Kit.box(pool, "RimE", px1 - 1, px1, 0, 0.55, pz0 + 1, pz1 - 1, G.stone2, { Pattern = "Weld" })
	looseFence(pool, Vector3.new(px0 + 18, 0.1, pz1 - 2.6), Vector3.new(px0 + 25, 0.1, pz1 - 2.6), rng, true)
	candles(pool, Vector3.new(px0 + 34, 0.1, pz1 - 2.4), 4, rng, 0.6)
	for zz = pz0 - 1.5, pz1 + 2, 2 do
		takeLine(Vector3.new(px0 - 2, 0, zz), Vector3.new(px1 + 2, 0, zz), 1.2)
	end
	lanternPost(lamps, Vector3.new(px1 + 3, 0, (pz0 + pz1) / 2), Vector3.new(-1, 0, 0))
	take(px1 + 3, (pz0 + pz1) / 2, 1.5)
	crossGrave(graves, Vector3.new(px0 - 3.5, 0, (pz0 + pz1) / 2 + 2), toCam, rng)
	take(px0 - 3.5, (pz0 + pz1) / 2, 2.8)

	-- ===== set pieces: shrine (back-left corner, door to the arena side) and cauldron (east) =====
	local scx, scz = X - 138, Z - 88
	shrine(scen, scx, scz, rng)
	for xx = scx - 9, scx + 9, 2 do
		takeLine(Vector3.new(xx, 0, scz - 9), Vector3.new(xx, 0, scz + 11), 1.2)
	end
	lanternPost(lamps, Vector3.new(X - 128.5, 0, Z - 77.5), Vector3.new(-1, 0, 0))
	take(X - 128.5, Z - 77.5, 1.5)
	local ccx, ccz = X + 135, Z - 47
	cauldron(scen, ccx, ccz, rng)
	take(ccx, ccz, 5.2)
	take(ccx - 6, ccz - 3, 1.8)
	take(ccx + 5, ccz + 2, 1.8)

	-- ===== loose fence pieces near the boundaries (move / copy these freely) =====
	local loose = Kit.model(scen, "LooseFences")
	for _, lf in {
		{ Vector3.new(X - 112, 0, fen.z1 + 9), Vector3.new(X - 102, 0, fen.z1 + 9), false },
		{ Vector3.new(X - 40, 0, fen.z0 - 10), Vector3.new(X - 33, 0, fen.z0 - 10), true },
		{ Vector3.new(X + 60, 0, fen.z0 - 8), Vector3.new(X + 70, 0, fen.z0 - 8), false },
		{ Vector3.new(fen.x0 - 9, 0, Z + 20), Vector3.new(fen.x0 - 9, 0, Z + 30), false },
		{ Vector3.new(fen.x1 + 8, 0, Z - 20), Vector3.new(fen.x1 + 8, 0, Z - 13), true },
	} do
		looseFence(loose, lf[1], lf[2], rng, lf[3])
		takeLine(lf[1], lf[2], 1.4)
	end

	-- ===== graves, crosses, jack-o'-lanterns and candles scattered along every walkway =====
	local R = { grave = 2.6, cross = 3.2, pumpkin = 2.6, candles = 1.2, ruin = 3.2 }
	local function scatter(x0, x1, z0, z1, counts, face)
		local kinds = {}
		for _, kc in counts do
			for _ = 1, kc[2] do
				table.insert(kinds, kc[1])
			end
		end
		for i = #kinds, 2, -1 do
			local j = rng:NextInteger(1, i)
			kinds[i], kinds[j] = kinds[j], kinds[i]
		end
		for _, kind in kinds do
			local r = R[kind]
			for _ = 1, 60 do
				local px, pz = rng:NextNumber(x0 + r, x1 - r), rng:NextNumber(z0 + r, z1 - r)
				if free(px, pz, r + 0.6) then
					take(px, pz, r)
					local dir = face + Vector3.new(rng:NextNumber(-0.3, 0.3), 0, 0)
					local base = Vector3.new(px, 0, pz)
					if kind == "grave" then
						gravestone(graves, base, dir, rng:NextNumber(1.15, 1.5), rng)
					elseif kind == "cross" then
						crossGrave(graves, base, dir, rng)
					elseif kind == "pumpkin" then
						pumpkin(graves, base, dir, rng:NextNumber(1.2, 1.75))
					elseif kind == "ruin" then
						ruin(graves, base, dir, rng)
					else
						candles(graves, base, rng:NextInteger(3, 5), rng)
					end
					break
				end
			end
		end
	end
	-- front walkway (lobby side), back walkway, both side strips
	scatter(fen.x0 - 2, fen.x1 + 2, fen.z1 + 1.5, isl.z1 - 3, { { "grave", 10 }, { "cross", 5 }, { "pumpkin", 9 }, { "candles", 12 }, { "ruin", 3 } }, toCam)
	scatter(fen.x0 - 2, fen.x1 + 2, isl.z0 + 3, fen.z0 - 1.5, { { "grave", 14 }, { "cross", 9 }, { "pumpkin", 9 }, { "candles", 12 }, { "ruin", 8 } }, toCam)
	scatter(isl.x0 + 3, fen.x0 - 1.5, isl.z0 + 3, isl.z1 - 3, { { "grave", 7 }, { "cross", 5 }, { "pumpkin", 5 }, { "candles", 6 }, { "ruin", 4 } }, Vector3.new(0.7, 0, 0.7))
	scatter(fen.x1 + 1.5, isl.x1 - 3, isl.z0 + 3, isl.z1 - 3, { { "grave", 7 }, { "cross", 5 }, { "pumpkin", 5 }, { "candles", 6 }, { "ruin", 4 } }, Vector3.new(-0.7, 0, 0.7))

	return arena
end
