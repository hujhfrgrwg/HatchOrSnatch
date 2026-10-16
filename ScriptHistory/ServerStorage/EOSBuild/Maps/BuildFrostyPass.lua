--!nocheck
-- Frosty Pass: snow arena, field 212 long (farm is 176). Exactly 3 pieces of cover, placed
-- point-symmetric so an A->B wave and a B->A wave play the same:
--   1) the ice-fishing cabin on the centre line (inside |z| < 14, clear of Catcher spawns)
--   2) an ice-block L wall in the north-west quadrant
--   3) the mirrored ice-block L wall in the south-east quadrant
-- Scenery outside the fence: snowy mountain range (north), ski lodge, frozen pond with a
-- skating snowman, pine forests, snowmen, drifts along the fence, egg nests behind both zones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggModel = require(ReplicatedStorage.EOS.Shared.EggModel)
local Kit = require(script.Parent.Parent.WorldKit)
local Frame = require(script.Parent.ArenaFrame)
local Props = require(script.Parent.Props)
local PAL = Kit.PAL
local C = Props.C

local SNOW = C.snow
local SNOW2 = Color3.fromRGB(230, 239, 252)
local LOG = Color3.fromRGB(168, 104, 66)
local LOG2 = Color3.fromRGB(140, 86, 58)
local GLOW = Color3.fromRGB(255, 220, 140)

local THEME = {
	ground = SNOW, groundEdge = SNOW2,
	strata = { PAL.stone, PAL.stone2, PAL.stoneDark },
	field = Color3.fromRGB(234, 243, 254), apron = Color3.fromRGB(214, 228, 247), line = Color3.fromRGB(112, 168, 234),
	flagPost = PAL.white, fencePost = PAL.wood2, fenceRail = PAL.wood, fencePostCap = SNOW,
	backWall = C.ice, backWallCap = SNOW,
}
local MOUNTAIN = {
	plateauName = "Mountain",
	plateauTiers = { PAL.stone2, PAL.stone, Color3.fromRGB(200, 208, 240), SNOW2, SNOW },
	plateauCap = SNOW,
}

-- Log cabin: stone base, interlocking log courses, doors on the X faces, glowing windows with
-- shutters on the Z faces, stepped snowy roof with icicles, stone chimney, wall lanterns.
local function cabin(parent, name, cx, cz, hw, hd, courses, rng)
	local m = Kit.model(parent, name)
	local y0 = 0.2
	Kit.box(m, "Base", cx - hw - 1, cx + hw + 1, y0, y0 + 1, cz - hd - 1, cz + hd + 1, PAL.stone2, { Pattern = "Weld" })
	local wb = y0 + 1
	local wallTop = wb + courses
	Kit.box(m, "Core", cx - hw + 0.4, cx + hw - 0.4, wb, wallTop, cz - hd + 0.4, cz + hd - 0.4, LOG2, { Pattern = "Smooth" })
	local logs = Kit.model(m, "Logs")
	for c = 0, courses - 1 do
		local ly = wb + c
		local col = if c % 2 == 0 then LOG else LOG2
		local longNS = c % 2 == 0
		local nsx = if longNS then hw + 0.6 else hw - 0.8
		local ewz = if longNS then hd - 0.8 else hd + 0.6
		for _, sz in { -1, 1 } do
			local z0, z1 = cz + sz * (hd - 0.8), cz + sz * (hd + 0.2)
			Kit.box(logs, "LogNS", cx - nsx, cx + nsx, ly, ly + 1, math.min(z0, z1), math.max(z0, z1), col, { Pattern = "Weld" })
		end
		for _, sx in { -1, 1 } do
			local x0, x1 = cx + sx * (hw - 0.8), cx + sx * (hw + 0.2)
			Kit.box(logs, "LogEW", math.min(x0, x1), math.max(x0, x1), ly + 0.0001, ly + 1.0002, cz - ewz, cz + ewz, col:Lerp(LOG2, 0.3), { Pattern = "Weld" })
		end
	end
	-- doors on both X faces (they face the safe zones), proud of the logs
	for _, sx in { -1, 1 } do
		local fx = cx + sx * (hw + 0.2)
		local function slab(nm, from, thick, ya, yb, halfZ, col, pat)
			local a, b = fx + sx * from, fx + sx * (from + thick)
			Kit.box(m, nm, math.min(a, b), math.max(a, b), ya, yb, cz - halfZ, cz + halfZ, col, { Pattern = pat })
		end
		slab("DoorFrame", -0.1, 0.6, wb, wb + 6.6, 3.0, PAL.white, "Weld")
		slab("Door", 0.4, 0.3, wb + 0.2, wb + 6.1, 2.4, PAL.redDark, "Weld")
		slab("DoorRail", 0.65, 0.2, wb + 2.8, wb + 3.4, 2.4, PAL.red, "Smooth")
		slab("Handle", 0.8, 0.25, wb + 3.2, wb + 3.6, 0.3, PAL.gold, "Smooth")
		slab("Step", -0.1, 1.6, y0 + 1, y0 + 1.4, 3.4, PAL.stone, "Weld")
		-- lantern beside the door
		local lz = cz + 4.2
		local lantern = Kit.model(m, "Lantern")
		Kit.box(lantern, "Bracket", math.min(fx, fx + sx * 0.9), math.max(fx, fx + sx * 0.9), wb + 5.4, wb + 5.7, lz - 0.2, lz + 0.2, PAL.ink, { Pattern = "Smooth" })
		Kit.box(lantern, "Lamp", math.min(fx + sx * 0.5, fx + sx * 1.3), math.max(fx + sx * 0.5, fx + sx * 1.3), wb + 4.2, wb + 5.4, lz - 0.4, lz + 0.4, GLOW, { Material = Enum.Material.Neon })
	end
	-- windows on both Z faces: frame, glowing pane, sill, two shutters
	for _, sz in { -1, 1 } do
		local fz = cz + sz * (hd + 0.2)
		for _, wx in { -hw * 0.5, hw * 0.5 } do
			local function slab(nm, from, thick, xa, xb, ya, yb, col, pat, extra)
				local a, b = fz + sz * from, fz + sz * (from + thick)
				local o = extra or {}
				o.Pattern = pat
				Kit.box(m, nm, cx + wx + xa, cx + wx + xb, ya, yb, math.min(a, b), math.max(a, b), col, o)
			end
			slab("WindowFrame", -0.1, 0.5, -1.6, 1.6, wb + 2.2, wb + 5.4, PAL.white, "Weld")
			slab("WindowGlow", 0.2, 0.25, -1.1, 1.1, wb + 2.6, wb + 5.0, GLOW, "Smooth")
			slab("Mullion", 0.4, 0.15, -0.15, 0.15, wb + 2.6, wb + 5.0, PAL.white, "Smooth")
			slab("Sill", -0.1, 0.9, -1.9, 1.9, wb + 1.8, wb + 2.2, PAL.white, "Weld")
			slab("SillSnow", 0.3, 0.5, -1.8, 1.8, wb + 2.2, wb + 2.45, SNOW, "Universal")
			slab("ShutterL", -0.1, 0.4, -2.6, -1.6, wb + 2.2, wb + 5.4, PAL.roofTeal, "Weld")
			slab("ShutterR", -0.1, 0.4, 1.6, 2.6, wb + 2.2, wb + 5.4, PAL.roofTeal, "Weld")
		end
	end
	-- stepped roof, a snow layer on every step, icicles under the eaves
	local roof = Kit.model(m, "Roof")
	local steps = 5
	for i = 1, steps do
		local w = hw + 1.6 - (i - 1) * 2
		if w <= 0.6 then break end
		local ya = wallTop + (i - 1) * 1.2
		Kit.box(roof, "RoofStep" .. i, cx - w, cx + w, ya, ya + 1.2, cz - hd - 1.5, cz + hd + 1.5 - 0.0001 * i, if i % 2 == 0 then PAL.red else PAL.redDark, { Pattern = "Studs" })
		Kit.box(roof, "RoofSnow" .. i, cx - w - 0.1, cx + w + 0.1, ya + 1.2, ya + 1.5, cz - hd - 1.6, cz + hd + 1.6, SNOW, { Pattern = "Universal" })
	end
	for _, sz in { -1, 1 } do
		local x = cx - hw - 1
		while x < cx + hw + 1 do
			local len = rng:NextNumber(0.6, 1.5)
			local iz = cz + sz * (hd + 1.2)
			Kit.box(roof, "Icicle", x - 0.15, x + 0.15, wallTop - len, wallTop + 0.1, iz - 0.15, iz + 0.15, C.ice3, { Pattern = "Smooth" })
			x += rng:NextNumber(1.2, 2.2)
		end
	end
	-- chimney punching through the roof
	local chx, chz = cx + hw * 0.4, cz - hd * 0.45
	local chTop = wallTop + steps * 1.2 + 2.6
	Kit.box(m, "Chimney", chx - 1.2, chx + 1.2, wallTop, chTop, chz - 1.2, chz + 1.2, PAL.stone2, { Pattern = "Weld" })
	Kit.box(m, "ChimneyCap", chx - 1.5, chx + 1.5, chTop, chTop + 0.5, chz - 1.5, chz + 1.5, PAL.stoneDark, { Pattern = "Weld" })
	Kit.box(m, "ChimneySnow", chx - 1.4, chx + 1.4, chTop + 0.5, chTop + 0.8, chz - 1.4, chz + 1.4, SNOW, { Pattern = "Universal" })
	return m
end

return function(world: Instance, def)
	local rng = Random.new(6262)
	local arena, F = Frame.build(world, def, THEME, rng)
	local X, Z, OUT, HZ = F.X, F.Z, F.OUT, F.HZ
	local fen, isl = F.fence, F.island

	-- ===== the 3 pieces of cover =====
	local cover = Kit.model(arena, "Cover")
	local cab = cabin(cover, "IceFishingCabin", X, Z, 9, 12, 8, rng)
	-- fishing rods leaning on the cabin's south wall + a little bucket of fish (against the wall)
	for k = 0, 1 do
		Kit.brick(cab, "FishingRod", Vector3.new(0.25, 7, 0.25), CFrame.new(X - 6.6 + k * 1.2, 4.4, Z + 12.6) * CFrame.Angles(math.rad(15), 0, 0), PAL.wood2, { Pattern = "Smooth" })
	end
	Kit.box(cab, "FishBucket", X + 6, X + 7.4, 1.2, 2.6, Z + 12.4, Z + 13.6, PAL.stoneDark, { Pattern = "Weld" })
	Kit.box(cab, "Fish", X + 6.3, X + 6.6, 2.4, 3.2, Z + 12.8, Z + 13.2, PAL.blue, { Pattern = "Smooth" })
	Props.iceWall(cover, X - 52, Z - 40, -1, -1, rng)
	Props.iceWall(cover, X + 52, Z + 40, 1, 1, rng)

	local scen = Kit.model(arena, "Scenery")
	local zN, zS = (fen.z0 + isl.z0) / 2, (fen.z1 + isl.z1) / 2

	-- ===== mountain range across the north strip =====
	local peaks = { { -150, 36, 30 }, { -102, 44, 44 }, { -48, 38, 34 }, { 8, 50, 52 }, { 64, 40, 38 }, { 116, 42, 46 }, { 158, 30, 28 } }
	for i, p in peaks do
		local range = Kit.model(scen, "MountainRun")
		Frame.plateau(range, Vector3.new(X + p[1], 0, zN - 1), Vector3.new(p[2], p[3], 24), 5, rng, 0, MOUNTAIN)
		-- a lower shoulder clipping into the peak so the skyline steps instead of repeating
		local side = if i % 2 == 0 then 1 else -1
		Frame.plateau(range, Vector3.new(X + p[1] + side * p[2] * 0.42, 0, zN + 3), Vector3.new(p[2] * 0.55, p[3] * 0.45, 16), 3, rng, 0, MOUNTAIN)
		-- pines at the foot, on the arena side
		for k = 1, 2 do
			Props.pine(scen, Vector3.new(X + p[1] + rng:NextNumber(-p[2] / 2.5, p[2] / 2.5), 0, zN + 12.5), rng:NextNumber(7, 10), rng, true, (k % 3) + 1)
		end
	end

	-- ===== ski lodge (west strip, north of the nest) =====
	cabin(scen, "SkiLodge", X - OUT - 28, Z - 58, 8, 7, 7, rng)
	Kit.lamp(scen, Vector3.new(X - OUT - 17, 0, Z - 46))
	-- skis leaning on the lodge
	for k = 0, 2 do
		Kit.brick(scen, "Ski", Vector3.new(0.5, 6, 0.2), CFrame.new(X - OUT - 22 + k * 0.9, 3.4, Z - 49.6) * CFrame.Angles(math.rad(15), 0, 0), if k == 1 then PAL.red else PAL.blue, { Pattern = "Smooth" })
	end

	-- ===== frozen pond (south strip) with a skating snowman =====
	local pond = Kit.model(scen, "FrozenPond")
	local p0, p1 = X + 6, X + 78
	Kit.box(pond, "Bed", p0, p1, 0, 0.1, zS - 9, zS + 9, Color3.fromRGB(64, 130, 200), { Pattern = "Universal" })
	for k = 1, 4 do
		Kit.box(pond, "Fish", p0 + 8 + k * 14, p0 + 9.6 + k * 14, 0.12, 0.3, zS - 3 + (k % 2) * 5, zS - 2.4 + (k % 2) * 5, PAL.zoneB, { Pattern = "Smooth" })
	end
	Kit.box(pond, "Ice", p0 - 0.1, p1 + 0.1, 0.1, 0.5, zS - 9.1, zS + 9.1, Color3.fromRGB(196, 234, 252), { Pattern = "Smooth", Transparency = 0.3 })
	for k = 1, 5 do
		local cx = rng:NextNumber(p0 + 6, p1 - 6)
		Kit.brick(pond, "Crack", Vector3.new(rng:NextNumber(3, 6), 0.05, 0.2), CFrame.new(cx, 0.525, zS + rng:NextNumber(-6, 6)) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 11) * 15), 0), PAL.white, { Pattern = "Smooth" })
	end
	-- snowy rim blocks (embedded into the ice edge)
	local x = p0 - 1.5
	while x < p1 + 1 do
		local w = rng:NextNumber(2.5, 4.5)
		for _, sz in { -1, 1 } do
			Kit.box(pond, "Rim", x, x + w, 0, rng:NextNumber(0.8, 1.4), zS + sz * 9 - 1, zS + sz * 9 + 1.6 * sz + (if sz < 0 then 0 else 0), SNOW2, { Pattern = "Universal" })
		end
		x += w - 0.3
	end
	for _, sx in { p0 - 1.2, p1 + 1.2 } do
		Kit.box(pond, "RimEnd", sx - 1.3, sx + 1.3, 0, 1.1, zS - 9.5, zS + 9.5, SNOW2, { Pattern = "Universal" })
	end
	Props.snowman(pond, Vector3.new(p0 + 30, 0.5, zS + 1), 200, 0.9)

	-- ===== pine forests =====
	local function forest(x0, x1, z0, z1, n)
		local placed = 0
		local tries = 0
		while placed < n and tries < n * 6 do
			tries += 1
			local px, pz = rng:NextNumber(x0, x1), rng:NextNumber(z0, z1)
			Props.pine(scen, Vector3.new(px, 0, pz), rng:NextNumber(10, 16), rng, true, (placed % 3) + 1)
			placed += 1
		end
	end
	forest(X - 162, X - 40, zS - 8, zS + 8, 12)
	forest(X + 96, X + 162, zS - 8, zS + 8, 6)
	forest(X + OUT + 14, X + OUT + 32, Z - 66, Z - 16, 5)
	forest(X + OUT + 14, X + OUT + 32, Z + 16, Z + 66, 5)
	forest(X - OUT - 32, X - OUT - 14, Z + 16, Z + 66, 5)

	-- ===== snowmen, a sled, drifts along the fence =====
	Props.snowman(scen, Vector3.new(X - 20, 0, zS + 2), 180, 1.1)
	Props.snowman(scen, Vector3.new(X + 90, 0, zS - 4), 195, 0.8)
	local sled = Kit.model(scen, "Sled")
	local scf = CFrame.new(X - 14, 0, zS + 4) * CFrame.Angles(0, math.rad(30), 0)
	Kit.brick(sled, "Deck", Vector3.new(2.4, 0.4, 5), scf * CFrame.new(0, 0.9, 0), PAL.red, { Pattern = "Weld" })
	for _, sx in { -1, 1 } do
		Kit.brick(sled, "Runner", Vector3.new(0.3, 0.3, 5.8), scf * CFrame.new(sx * 1, 0.15, -0.2), PAL.stoneDark, { Pattern = "Smooth" })
		Kit.brick(sled, "Strut", Vector3.new(0.3, 0.6, 0.3), scf * CFrame.new(sx * 1, 0.5, 1.6), PAL.stoneDark, { Pattern = "Smooth" })
		Kit.brick(sled, "Strut", Vector3.new(0.3, 0.6, 0.3), scf * CFrame.new(sx * 1, 0.5, -1.6), PAL.stoneDark, { Pattern = "Smooth" })
	end
	Kit.brick(sled, "Curl", Vector3.new(2.4, 1.2, 0.4), scf * CFrame.new(0, 1.0, -3.1) * CFrame.Angles(math.rad(-30), 0, 0), PAL.red, { Pattern = "Weld" })
	local drifts = Kit.model(scen, "Drifts")
	local function driftRun(alongX, fixed, from, to, outward)
		local p = from + rng:NextNumber(0, 6)
		while p < to - 4 do
			local len = rng:NextNumber(5, 12)
			local h = rng:NextNumber(0.6, 1.4)
			local d0, d1 = fixed + outward * 1.2, fixed + outward * rng:NextNumber(3, 5)
			if alongX then
				Kit.box(drifts, "Drift", p, math.min(p + len, to), 0, h, math.min(d0, d1), math.max(d0, d1), SNOW2, { Pattern = "Universal" })
			else
				Kit.box(drifts, "Drift", math.min(d0, d1), math.max(d0, d1), 0, h, p, math.min(p + len, to), SNOW2, { Pattern = "Universal" })
			end
			p += len + rng:NextNumber(3, 9)
		end
	end
	driftRun(true, fen.z1, fen.x0, X - 50, 1)
	driftRun(true, fen.z1, X + 100, fen.x1, 1)

	-- ===== egg nests behind both safe zones: a ring of ice blocks =====
	for _, sx in { -1, 1 } do
		local nest = Kit.model(scen, "ZoneNest")
		local nx = X + sx * (OUT + 16)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			Kit.brick(nest, "IceBlock", Vector3.new(2.2, 1.6 + 0.0001 * k, 2.2), CFrame.new(nx + math.cos(a) * 4.4, 0.8, Z + math.sin(a) * 4.4) * CFrame.Angles(0, -a, 0), ({ C.ice, C.ice2, C.ice3 })[k % 3 + 1], { Pattern = "Universal" })
		end
		Kit.box(nest, "SnowBed", nx - 3, nx + 3, 0, 0.4, Z - 3, Z + 3, SNOW2, { Pattern = "Universal" })
		local egg = EggModel.build(if sx < 0 then 2 else 4, false, 2.6)
		egg:PivotTo(CFrame.new(nx, 0.4, Z))
		egg.Parent = nest
	end

	return arena
end
