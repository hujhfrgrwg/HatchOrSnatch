--!nocheck
-- Sunny Cove: beach arena, field 200 long (farm is 176). NO cover: bare sand between the zones.
-- Scenery only outside the fence: dunes with palms, a red/white lighthouse, a pier out into the
-- sea, beach umbrellas, sandcastles, crabs and starfish, egg nests behind both safe zones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggModel = require(ReplicatedStorage.EOS.Shared.EggModel)
local Kit = require(script.Parent.Parent.WorldKit)
local Frame = require(script.Parent.ArenaFrame)
local Props = require(script.Parent.Props)
local PAL = Kit.PAL

local SAND = Color3.fromRGB(244, 220, 166)
local SAND2 = Color3.fromRGB(232, 202, 146)
local WET = Color3.fromRGB(214, 182, 132)
local DRIFT = Color3.fromRGB(200, 172, 132)
local DRIFT2 = Color3.fromRGB(172, 142, 104)
local GRASS = Color3.fromRGB(150, 206, 92)

local THEME = {
	ground = SAND, groundEdge = SAND2,
	strata = { Color3.fromRGB(236, 172, 124), Color3.fromRGB(220, 142, 108), Color3.fromRGB(196, 112, 92) },
	field = Color3.fromRGB(250, 232, 190), apron = SAND2, line = PAL.white,
	flagPost = PAL.white, fencePost = DRIFT, fenceRail = DRIFT2,
	backWall = SAND2, backWallCap = GRASS,
	plateauName = "Dune", plateauTiers = { Color3.fromRGB(226, 180, 128), Color3.fromRGB(236, 196, 142), SAND2 }, plateauCap = SAND,
}

return function(world: Instance, def)
	local rng = Random.new(5151)
	local arena, F = Frame.build(world, def, THEME, rng)
	local X, Z, OUT, HZ = F.X, F.Z, F.OUT, F.HZ
	local fen, isl = F.fence, F.island
	local scen = Kit.model(arena, "Scenery")

	-- ===== wet-sand band + surf foam around the island =====
	local shore = Kit.model(scen, "Shore")
	local b = 3
	Kit.box(shore, "WetN", isl.x0, isl.x1, 0, 0.06, isl.z0, isl.z0 + b, WET, { Pattern = "Universal", CanCollide = false })
	Kit.box(shore, "WetS", isl.x0, isl.x1, 0, 0.06, isl.z1 - b, isl.z1, WET, { Pattern = "Universal", CanCollide = false })
	Kit.box(shore, "WetW", isl.x0, isl.x0 + b, 0.0001, 0.0601, isl.z0 + b, isl.z1 - b, WET, { Pattern = "Universal", CanCollide = false })
	Kit.box(shore, "WetE", isl.x1 - b, isl.x1, 0.0001, 0.0601, isl.z0 + b, isl.z1 - b, WET, { Pattern = "Universal", CanCollide = false })
	-- foam licks on the sea surface (sea top is y = -12)
	local function foamRun(ax, fixed, from, to)
		local p = from
		while p < to do
			local len = rng:NextNumber(6, 14)
			local w = rng:NextNumber(1.2, 2.2)
			local off = rng:NextNumber(5.5, 8)
			if ax == "x" then
				Kit.box(shore, "Foam", p, math.min(p + len, to), -12, -11.9, fixed + off * (if fixed > Z then 1 else -1) - w / 2, fixed + off * (if fixed > Z then 1 else -1) + w / 2, PAL.white, { Pattern = "Smooth", CanCollide = false, CastShadow = false })
			else
				Kit.box(shore, "Foam", fixed + off * (if fixed > X then 1 else -1) - w / 2, fixed + off * (if fixed > X then 1 else -1) + w / 2, -12, -11.9, p, math.min(p + len, to), PAL.white, { Pattern = "Smooth", CanCollide = false, CastShadow = false })
			end
			p += len + rng:NextNumber(4, 10)
		end
	end
	foamRun("x", isl.z0, isl.x0, isl.x1)
	foamRun("x", isl.z1, isl.x0, isl.x1)
	foamRun("z", isl.x0, isl.z0, isl.z1)
	foamRun("z", isl.x1, isl.z0, isl.z1)

	-- ===== dunes along the north and south strips, palms on every other one =====
	local zN, zS = (fen.z0 + isl.z0) / 2, (fen.z1 + isl.z1) / 2
	local dunes = {
		{ -150, zN, 26, 9, 18 }, { -112, zN - 1, 34, 7, 16 }, { -74, zN + 1, 24, 6, 14 },
		{ 92, zN, 30, 8, 16 }, { 140, zN - 1, 30, 10, 18 },
		{ -150, zS, 28, 9, 18 }, { -108, zS, 30, 6, 14 }, { 92, zS + 1, 26, 7, 14 }, { 142, zS, 28, 9, 18 },
	}
	for i, d in dunes do
		local p = Frame.plateau(scen, Vector3.new(X + d[1], 0, d[2]), Vector3.new(d[3], d[4], d[5]), if d[4] >= 8 then 3 else 2, rng, (i % 3) * 15, THEME)
		local topY = p:GetAttribute("TopY")
		for k = 1, 3 do
			Kit.tuft(p, Vector3.new(X + d[1] + rng:NextNumber(-d[3] / 4, d[3] / 4), topY, d[2] + rng:NextNumber(-3, 3)), rng)
		end
		if i % 2 == 1 then
			Props.palm(scen, Vector3.new(X + d[1] + rng:NextNumber(-3, 3), topY, d[2]), rng:NextNumber(12, 15), rng:NextInteger(0, 23) * 15, rng)
		end
	end

	-- ===== lighthouse (north, the landmark players see across the field) =====
	local lh = Kit.model(scen, "Lighthouse")
	local lx, lz = X + 30, zN - 2
	local rock = Kit.model(lh, "Rocks")
	for k = 1, 3 do
		local s = 14 - k * 3
		Kit.brick(rock, "Slab" .. k, Vector3.new(s, 1.4, s * 0.9), CFrame.new(lx + k * 0.3, (k - 0.5) * 1.4, lz) * CFrame.Angles(0, math.rad(k * 15), 0), ({ PAL.stone, PAL.stone2, PAL.stoneDark })[k], { Pattern = "Smooth", }).TopSurface = Enum.SurfaceType.Inlet
	end
	local ry = 4.2
	for i = 1, 8 do
		local w = 8.6 - i * 0.32
		Kit.brick(lh, "Ring" .. i, Vector3.new(w, 4, w), CFrame.new(lx, ry + (i - 0.5) * 4, lz), if i % 2 == 1 then PAL.white else PAL.red, { Pattern = "Studs" })
		-- trim band where rings meet (proud of both)
		if i > 1 then
			Kit.brick(lh, "Band", Vector3.new(w + 0.5, 0.4, w + 0.5), CFrame.new(lx, ry + (i - 1) * 4, lz), PAL.white:Lerp(PAL.stone, 0.3), { Pattern = "Weld" })
		end
	end
	local topY = ry + 32
	-- door + window frames on the arena-facing (south) side
	local dz = lz + 8.6 / 2 - 0.32
	Kit.brick(lh, "DoorFrame", Vector3.new(3.4, 5.4, 0.6), CFrame.new(lx, ry + 2.7, dz + 0.1), PAL.wood2, { Pattern = "Weld" })
	Kit.brick(lh, "Door", Vector3.new(2.6, 4.8, 0.5), CFrame.new(lx, ry + 2.4, dz + 0.25), PAL.blueDark, { Pattern = "Weld" })
	Kit.brick(lh, "DoorKnob", Vector3.new(0.3, 0.3, 0.3), CFrame.new(lx + 0.8, ry + 2.4, dz + 0.6), PAL.gold, { Pattern = "Smooth" })
	for k = 1, 3 do
		local wy = ry + 6 + k * 7.5
		local ringIdx = math.ceil((wy - ry) / 4)
		local wz = lz + (8.6 - ringIdx * 0.32) / 2
		Kit.brick(lh, "WindowFrame", Vector3.new(1.8, 2.4, 0.6), CFrame.new(lx, wy, wz + 0.05), PAL.white:Lerp(PAL.stone, 0.3), { Pattern = "Weld" })
		Kit.brick(lh, "WindowPane", Vector3.new(1.2, 1.8, 0.6), CFrame.new(lx, wy, wz + 0.1), Color3.fromRGB(168, 214, 246), { Pattern = "Smooth" })
	end
	-- gallery deck + rail
	Kit.brick(lh, "Gallery", Vector3.new(10, 0.8, 10), CFrame.new(lx, topY + 0.4, lz), PAL.stoneDark, { Pattern = "Weld" })
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local px, pz = math.clamp(math.cos(a) * 7, -4.6, 4.6), math.clamp(math.sin(a) * 7, -4.6, 4.6)
		Kit.brick(lh, "RailPost", Vector3.new(0.4, 2, 0.4), CFrame.new(lx + px, topY + 1.8, lz + pz), PAL.white, { Pattern = "Smooth" })
	end
	for _, e in { { 0, -4.6, 9.6, 0.4 }, { 0, 4.6, 9.6, 0.4 }, { -4.6, 0, 0.4, 9.6 }, { 4.6, 0, 0.4, 9.6 } } do
		Kit.brick(lh, "Rail", Vector3.new(e[3] + 0.01, 0.4, e[4] + 0.01), CFrame.new(lx + e[1], topY + 2.8, lz + e[2]), PAL.white, { Pattern = "Smooth" })
	end
	-- lamp room: corner posts, pale glass, glowing core, stepped red cap
	for _, c in { { -2.4, -2.4 }, { 2.4, -2.4 }, { -2.4, 2.4 }, { 2.4, 2.4 } } do
		Kit.brick(lh, "LampPost", Vector3.new(0.6, 4, 0.6), CFrame.new(lx + c[1], topY + 2.8, lz + c[2]), PAL.ink:Lerp(PAL.stoneDark, 0.6), { Pattern = "Weld" })
	end
	Kit.brick(lh, "LampGlass", Vector3.new(4.6, 3.8, 4.6), CFrame.new(lx, topY + 2.7, lz), Color3.fromRGB(190, 228, 250), { Pattern = "Smooth", Transparency = 0.35, CastShadow = false })
	Kit.brick(lh, "LampCore", Vector3.new(1.6, 1.6, 1.6), CFrame.new(lx, topY + 2.6, lz), Color3.fromRGB(255, 236, 160), { Material = Enum.Material.Neon })
	for i = 1, 3 do
		local w = 6.4 - (i - 1) * 2
		Kit.brick(lh, "Cap" .. i, Vector3.new(w, 1.1, w), CFrame.new(lx, topY + 4.7 + (i - 1) * 1.1, lz), PAL.red, { Pattern = "Studs" })
	end
	Kit.brick(lh, "Finial", Vector3.new(0.6, 1.4, 0.6), CFrame.new(lx, topY + 8.3, lz), PAL.gold, { Pattern = "Smooth" })

	-- ===== pier out into the sea (south-west) =====
	local pier = Kit.model(scen, "Pier")
	local px = X - 40
	local pz0, pz1 = fen.z1 + 3, isl.z1 + 46
	local deckY = 1.2
	local z = pz0
	local n = 0
	while z < pz1 do
		n += 1
		Kit.box(pier, "Plank", px - 4, px + 4, deckY - 0.4, deckY, z, z + 1.7, if n % 2 == 0 then DRIFT else DRIFT:Lerp(DRIFT2, 0.4), { Pattern = "Weld" })
		z += 1.8
	end
	-- stringers under the planks (embedded 0.1 into them)
	for _, sx in { -3, 3 } do
		Kit.box(pier, "Stringer", px + sx - 0.4, px + sx + 0.4, deckY - 1.2, deckY - 0.3, pz0, pz1, DRIFT2, { Pattern = "Weld" })
	end
	local pz = pz0 + 2
	while pz < pz1 do
		local overSea = pz > isl.z1
		for _, sx in { -4.2, 4.2 } do
			local bottom = if overSea then -14 else 0
			Kit.box(pier, "Post", px + sx - 0.5, px + sx + 0.5, bottom, deckY + 3, pz - 0.5, pz + 0.5, DRIFT2, { Pattern = "Weld" })
		end
		pz += 6
	end
	for _, sx in { -4.2, 4.2 } do
		Kit.box(pier, "Rail", px + sx - 0.3, px + sx + 0.3, deckY + 2.2, deckY + 2.7, pz0, pz1, DRIFT, { Pattern = "Weld" })
	end
	-- end of the pier: a life ring, a bench and a fishing rod
	local ez = pz1 - 3
	local ring = Kit.model(pier, "LifeRing")
	local rx, ryy = px - 4.95, deckY + 1.8
	for k, e in { { 0, 0.9, 0.6, 2.4 }, { 0, -0.9, 0.6, 2.4 }, { 0.9, 0, 2.4, 0.6 }, { -0.9, 0, 2.4, 0.6 } } do
		-- e = { z offset, y offset, height, depth } in the ring's YZ plane
		Kit.brick(ring, "Seg", Vector3.new(0.5 + 0.0002 * k, e[3] + 0.0001 * k, e[4]), CFrame.new(rx, ryy + e[2], ez + e[1]), if k % 2 == 0 then PAL.red else PAL.white, { Pattern = "Smooth" })
	end
	Kit.box(pier, "BenchSeat", px + 1, px + 3.2, deckY + 1.2, deckY + 1.6, ez - 3, ez + 1, DRIFT, { Pattern = "Weld" })
	Kit.box(pier, "BenchBack", px + 2.8, px + 3.2, deckY + 1.6, deckY + 3.2, ez - 3, ez + 1, DRIFT2, { Pattern = "Weld" })
	for _, bz in { ez - 2.5, ez + 0.5 } do
		Kit.box(pier, "BenchLeg", px + 1.2, px + 3.0, deckY, deckY + 1.2, bz - 0.25, bz + 0.25, DRIFT2, { Pattern = "Weld" })
	end
	Kit.brick(pier, "FishingRod", Vector3.new(0.2, 6, 0.2), CFrame.new(px + 3.6, deckY + 3, ez + 2) * CFrame.Angles(math.rad(-45), 0, 0), PAL.wood2, { Pattern = "Smooth" })

	-- ===== beach life on the south strip (outside the fence) =====
	local beach = Kit.model(scen, "Beach")
	local spots = { { -2, PAL.red, PAL.white }, { 22, PAL.blue, PAL.white }, { 46, PAL.pink, PAL.gold } }
	for i, s in spots do
		Props.umbrella(beach, Vector3.new(X + s[1], 0.06, zS - 2), s[2], s[3], (i - 2) * 15)
	end
	Props.sandcastle(beach, Vector3.new(X + 64, 0.06, zS + 2), 15)
	Props.sandcastle(beach, Vector3.new(X - 92, 0.06, zN + 4), -15)
	for i = 1, 8 do
		local sx = rng:NextNumber(-OUT + 10, OUT - 10)
		local sz = if i % 2 == 0 then zS + rng:NextNumber(-6, 8) else zN + rng:NextNumber(-8, 6)
		if math.abs(sx - (px - X)) > 8 then
			if i % 3 == 0 then
				Props.crab(beach, Vector3.new(X + sx, 0.06, sz), rng:NextInteger(0, 23) * 15)
			else
				Props.starfish(beach, Vector3.new(X + sx, 0.06, sz), if i % 2 == 0 then Color3.fromRGB(255, 132, 92) else PAL.pink, rng:NextInteger(0, 23) * 15)
			end
		end
	end
	-- shells and pebbles scattered on the wet band
	for i = 1, 30 do
		local side = i % 4
		local sx = if side < 2 then rng:NextNumber(isl.x0 + 4, isl.x1 - 4) else (if side == 2 then isl.x0 + 1.5 else isl.x1 - 1.5)
		local sz = if side == 0 then isl.z0 + 1.5 elseif side == 1 then isl.z1 - 1.5 else rng:NextNumber(isl.z0 + 4, isl.z1 - 4)
		Kit.brick(beach, "Shell", Vector3.new(0.7, 0.25, 0.6), CFrame.new(X - X + sx, 0.18, sz) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 11) * 15), 0), if i % 3 == 0 then PAL.pink:Lerp(PAL.white, 0.4) else PAL.cream, { Pattern = "Smooth" })
	end

	-- ===== palm groves + egg nests behind both safe zones =====
	for _, sx in { -1, 1 } do
		local gx = X + sx * (OUT + 24)
		for k, gz in { -54, -30, 26, 50 } do
			Props.palm(scen, Vector3.new(gx + rng:NextNumber(-4, 4), 0.06, Z + gz), rng:NextNumber(13, 17), (if sx < 0 then 90 else 270) + rng:NextInteger(-1, 1) * 15, rng, (k % 3) + 1)
		end
		local nest = Kit.model(scen, "ZoneNest")
		local nx = X + sx * (OUT + 16)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			Kit.brick(nest, "DriftLog", Vector3.new(3.2, 1.2, 1.2), CFrame.new(nx + math.cos(a) * 4.4, 0.66, Z + math.sin(a) * 4.4) * CFrame.Angles(0, -a + math.rad(90), 0), if k % 2 == 0 then DRIFT else DRIFT2, { Pattern = "Weld" })
		end
		local egg = EggModel.build(if sx < 0 then 2 else 4, false, 2.6)
		egg:PivotTo(CFrame.new(nx, 0.66, Z))
		egg.Parent = nest
		for k = 1, 3 do
			Kit.tuft(nest, Vector3.new(nx + rng:NextNumber(-7, 7), 0.06, Z + rng:NextNumber(10, 16) * (if k % 2 == 0 then 1 else -1)), rng)
		end
	end
	-- a beached rowboat on the east sand (decor, outside the fence)
	local boat = Kit.model(scen, "Rowboat")
	local bcf = CFrame.new(X + OUT + 20, 0.06, Z + 80) * CFrame.Angles(0, math.rad(30), 0) * CFrame.Angles(0, 0, math.rad(15))
	Kit.brick(boat, "Hull", Vector3.new(3.4, 0.8, 9), bcf * CFrame.new(0, 0.4, 0), PAL.white, { Pattern = "Weld" })
	for _, sx in { -1, 1 } do
		Kit.brick(boat, "Side", Vector3.new(0.6, 1.6, 9.6), bcf * CFrame.new(sx * 1.9, 1.1, 0), PAL.blue, { Pattern = "Weld" })
	end
	Kit.brick(boat, "Bow", Vector3.new(4.4, 1.6, 0.8), bcf * CFrame.new(0, 1.1, -4.8), PAL.blueDark, { Pattern = "Weld" })
	Kit.brick(boat, "Stern", Vector3.new(4.4, 1.6, 0.8), bcf * CFrame.new(0, 1.1, 4.8), PAL.blueDark, { Pattern = "Weld" })
	Kit.brick(boat, "Seat", Vector3.new(3.2, 0.4, 1.2), bcf * CFrame.new(0, 1.3, 0.5), DRIFT, { Pattern = "Weld" })
	Kit.brick(boat, "Oar", Vector3.new(0.3, 0.3, 6), bcf * CFrame.new(1.2, 1.8, 0) * CFrame.Angles(0, math.rad(15), 0), DRIFT2, { Pattern = "Smooth" })

	return arena
end
