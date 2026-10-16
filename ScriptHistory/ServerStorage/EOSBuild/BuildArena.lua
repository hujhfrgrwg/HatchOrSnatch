--!nocheck
-- BuildArena: the crossing arena island (GDD 6). Symmetric under X and Z mirroring.
-- Side A (-X, blue) and Side B (+X, orange) safe strips, a central hatchery coop, four hay stacks
-- and two hedge planters as broad juke structures with open lanes between them. Gameplay volumes
-- come from Shared/Layout; these parts are the visuals + the gate / Catcher-wall colliders.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.EOS.Shared
local Layout = require(Shared.Layout)
local EggModel = require(Shared.EggModel)
local Kit = require(script.Parent.WorldKit)
local PAL = Kit.PAL

return function(world: Instance)
	local rng = Random.new(4242)
	local A = Layout.Arena
	local C = A.CENTER
	local X, Z = C.X, C.Z
	local FX, HZ, ZD = A.FIELD_HALF_X, A.HALF_Z, A.ZONE_DEPTH
	local OUT = FX + ZD -- 112: outer edge of the safe zones

	local arena = Kit.model(world, "Arena")

	-- ===== ground =====
	local ground = Kit.model(arena, "Ground")
	Kit.island(ground, X - 152, X + 152, Z - 106, Z + 106, rng)
	local field = Kit.box(ground, "Field", X - FX, X + FX, 0, 0.2, Z - HZ, Z + HZ, PAL.grass:Lerp(PAL.leaf3, 0.25), { Pattern = "Universal" })
	Kit.checker(field, 12, 0.86)
	-- apron around the play area (between fence and zones/field)
	Kit.box(ground, "ApronN", X - OUT - 2, X + OUT + 2, 0, 0.19, Z - HZ - 4, Z - HZ, PAL.sand, { Pattern = "Universal" })
	Kit.box(ground, "ApronS", X - OUT - 2, X + OUT + 2, 0, 0.19, Z + HZ, Z + HZ + 4, PAL.sand, { Pattern = "Universal" })

	-- chalk lines (flat plates)
	local lines = Kit.model(arena, "ChalkLines")
	for _, sx in ipairs({ -1, 1 }) do
		Kit.box(lines, "ZoneEdge", X + sx * FX - 0.6, X + sx * FX + 0.6, 0.2, 0.26, Z - HZ, Z + HZ, PAL.white, { Pattern = "Smooth", CanCollide = false })
	end
	Kit.box(lines, "CenterLine", X - 0.4, X + 0.4, 0.2, 0.25, Z - HZ, Z + HZ, PAL.white:Lerp(PAL.grass, 0.35), { Pattern = "Smooth", CanCollide = false })

	-- ===== safe zones =====
	local zones = Kit.model(arena, "SafeZones")
	local function zone(side: string, sx: number, color: Color3)
		local zm = Kit.model(zones, "Zone" .. side)
		local x0, x1 = if sx < 0 then X - OUT else X + FX, if sx < 0 then X - FX else X + OUT
		local pad = Kit.box(zm, "Pad", x0, x1, 0, 0.2, Z - HZ, Z + HZ, color, { Pattern = "Studs", Attrs = { Side = side } })
		-- stripes across the pad
		for k = -3, 3 do
			Kit.box(zm, "Stripe", x0 + 1, x1 - 1, 0.2, 0.26, Z + k * 18 - 2, Z + k * 18 + 2, color:Lerp(PAL.white, 0.45), { Pattern = "Smooth", CanCollide = false })
		end
		-- floor lettering: readable from the field
		local sign = Kit.box(zm, "FloorSign", x0 + 2, x1 - 2, 0.26, 0.3, Z - 26, Z + 26, color, { Pattern = "Smooth", CanCollide = false, Transparency = 1 })
		local sg = Kit.surfaceText(sign, Enum.NormalId.Top, {
			{ text = "SAFE ZONE " .. side, size = 0.6 },
			{ text = "CROSS HERE WITH YOUR EGG", size = 0.3, color = PAL.cream },
		}, { PixelsPerStud = 20 })
		-- Top-face SurfaceGui: GUI right = part -Z, GUI up = part -X (measured in Studio).
		-- Side A reads correctly unrotated for a player in the field looking -X; B is mirrored.
		if sx > 0 then
			sign.CFrame = CFrame.new(sign.Position) * CFrame.Angles(0, math.rad(180), 0)
		end
		-- stepped chevrons pointing INTO the zone (flat plates, never wedges)
		for row = -2, 2 do
			local cz = Z + row * 28 + 9
			for step = 0, 2 do
				local w = 7 - step * 2.4
				local px = (if sx < 0 then x1 - 3 - step * 1.4 else x0 + 3 + step * 1.4)
				Kit.box(zm, "Chevron", px - 0.7, px + 0.7, 0.2, 0.27, cz - w / 2, cz + w / 2, PAL.white, { Pattern = "Smooth", CanCollide = false })
			end
		end
		-- gate (closed between waves; MatchService toggles it) + the zone wall (Catchers always, and
		-- Runners who already made it across). Both invisible (developer, Oct 15)
		local gx = X + sx * FX
		Kit.box(zm, "Gate", gx - 0.25, gx + 0.25, 0, 12, Z - HZ, Z + HZ, color:Lerp(PAL.white, 0.3), { Pattern = "Smooth", Transparency = 1, CastShadow = false, Tags = { "EOS_Gate" }, CollisionGroup = "EOS_Gate", CanQuery = false })
		local wx0 = if sx < 0 then gx - 1.5 else gx
		local wx1 = if sx < 0 then gx else gx + 1.5
		Kit.box(zm, "CatcherWall", wx0, wx1, 0, A.WALL_HEIGHT, Z - HZ, Z + HZ, PAL.red, { Pattern = "Smooth", Transparency = 1, CastShadow = false, CanQuery = false, Tags = { "EOS_CatcherWall" }, CollisionGroup = "EOS_CatcherWall" })
		-- end posts with flags
		for _, sz in ipairs({ -1, 1 }) do
			local post = Kit.brick(zm, "FlagPost", Vector3.new(1.2, 14, 1.2), CFrame.new(gx, 7, Z + sz * (HZ + 1.5)), PAL.white, { Pattern = "Weld" })
			Kit.brick(zm, "Flag", Vector3.new(0.3, 3, 5), CFrame.new(gx, 12, Z + sz * (HZ + 1.5) - sz * 3), color, { Pattern = "Studs" })
		end
		-- back hedge behind the zone with a big egg sign
		local bx0 = if sx < 0 then X - OUT - 4 else X + OUT
		local bx1 = bx0 + 4
		Kit.box(zm, "BackHedge", bx0, bx1, 0, 4, Z - HZ - 2, Z + HZ + 2, PAL.leaf2, { Pattern = "Studs" })
		Kit.box(zm, "BackHedgeCap", bx0 - 0.3, bx1 + 0.3, 4, 4.8, Z - HZ - 2.3, Z + HZ + 2.3, PAL.leaf3, { Pattern = "Studs" })
		local board = Kit.brick(zm, "SideBoard", Vector3.new(1, 10, 34), CFrame.new((bx0 + bx1) / 2, 10, Z), color, { Pattern = "Weld" })
		Kit.surfaceText(board, if sx < 0 then Enum.NormalId.Right else Enum.NormalId.Left, {
			{ text = "SIDE " .. side, size = 0.62 },
			{ text = "SAFE", size = 0.3, color = PAL.cream },
		}, { PixelsPerStud = 16 })
		for _, sz in ipairs({ -1, 1 }) do
			Kit.brick(zm, "BoardLeg", Vector3.new(1.2, 6, 1.2), CFrame.new((bx0 + bx1) / 2, 3, Z + sz * 14), PAL.wood2, { Pattern = "Weld" })
		end
		-- subtle zones (developer, Oct 15): no floor lettering, stripes, chevrons or SIDE board, and the pad
		-- is muted toward the field colour so the ends don't read as flashy touchdown zones
		for _, d in ipairs(zm:GetChildren()) do
			if d.Name == "Stripe" or d.Name == "FloorSign" or d.Name == "Chevron" or d.Name == "SideBoard" or d.Name == "BoardLeg" then
				d:Destroy()
			end
		end
		local padPart = zm:FindFirstChild("Pad")
		if padPart then
			padPart.Color = color:Lerp(field.Color, 0.55)
		end
		return pad
	end
	zone("A", -1, PAL.zoneA)
	zone("B", 1, PAL.zoneB)

	-- ===== perimeter: ranch fence + invisible walls =====
	local per = Kit.model(arena, "Perimeter")
	local fx0, fx1, fz0, fz1 = X - OUT - 6, X + OUT + 6, Z - HZ - 4, Z + HZ + 4
	Kit.fence(per, Vector3.new(fx0, 0, fz0), Vector3.new(fx1, 0, fz0), rng, { spacing = 7 })
	Kit.fence(per, Vector3.new(fx0, 0, fz1), Vector3.new(fx1, 0, fz1), rng, { spacing = 7 })
	Kit.fence(per, Vector3.new(fx0, 0, fz0), Vector3.new(fx0, 0, fz1), rng, { spacing = 7 })
	Kit.fence(per, Vector3.new(fx1, 0, fz0), Vector3.new(fx1, 0, fz1), rng, { spacing = 7 })
	Kit.boundary(per, fx0 + 0.6, fx1 - 0.6, fz0 + 0.6, fz1 - 0.6, A.WALL_HEIGHT, { Name = "ArenaWalls" })

	-- ===== juke structures =====
	local juke = Kit.model(arena, "JukeStructures")

	-- 1) central hatchery coop (blocks the centre line of sight)
	local coop = Kit.model(juke, "HatcheryCoop")
	local cw, cd, chh = 18, 24, 8 -- x width, z depth, wall height
	local cx0, cx1, cz0, cz1 = X - cw / 2, X + cw / 2, Z - cd / 2, Z + cd / 2
	Kit.box(coop, "Base", cx0 - 1, cx1 + 1, 0.2, 1.2, cz0 - 1, cz1 + 1, PAL.stoneDark, { Pattern = "Weld" })
	Kit.box(coop, "Walls", cx0, cx1, 1.2, 1.2 + chh, cz0, cz1, PAL.red, { Pattern = "Studs" })
	-- white corner posts + trim band (proud of the walls)
	for _, px in ipairs({ cx0, cx1 }) do
		for _, pz in ipairs({ cz0, cz1 }) do
			Kit.box(coop, "CornerPost", px - 0.7, px + 0.7, 1.2, 1.25 + chh, pz - 0.7, pz + 0.7, PAL.white, { Pattern = "Weld" })
		end
	end
	Kit.box(coop, "TrimBand", cx0 - 0.25, cx1 + 0.25, 1.2 + chh - 0.8, 1.2 + chh, cz0 - 0.25, cz1 + 0.25, PAL.white, { Pattern = "Weld" })
	-- barn doors on both X faces (framed panels with X braces), facing the zones
	for _, sx in ipairs({ -1, 1 }) do
		local fxp = if sx < 0 then cx0 else cx1
		local d = Kit.model(coop, "BarnDoor")
		-- everything stacks OUTWARD from the wall face (sx = outward direction)
		local function slab(name, from, thick, y0, y1, hw, color, pattern)
			local a, b = fxp + sx * from, fxp + sx * (from + thick)
			Kit.box(d, name, math.min(a, b), math.max(a, b), y0, y1, Z - hw, Z + hw, color, { Pattern = pattern })
		end
		slab("Frame", -0.1, 0.6, 1.2, 7.4, 4.8, PAL.white, "Weld") -- embedded 0.1 into the wall
		slab("Leaf", 0.45, 0.3, 1.4, 6.8, 4.0, PAL.redDark, "Weld")
		local leafX = fxp + sx * 0.85
		for _, ang in ipairs({ 56, -56 }) do
			Kit.brick(d, "Brace", Vector3.new(0.3, 9.2, 0.6), CFrame.new(leafX, 4.1, Z) * CFrame.Angles(math.rad(ang), 0, 0), PAL.white, { Pattern = "Smooth" })
		end
		slab("BraceTop", 0.7, 0.3, 6.3, 6.8, 4.0, PAL.white, "Smooth")
		slab("BraceBot", 0.7, 0.3, 1.4, 1.9, 4.0, PAL.white, "Smooth")
		-- egg window above the door
		slab("EggWindowFrame", -0.1, 0.5, 7.7, 9.3, 1.3, PAL.white, "Weld")
		slab("EggWindow", 0.35, 0.2, 7.9, 9.1, 0.95, PAL.cream, "Smooth")
	end
	-- stepped roof
	local ry = 1.2 + chh
	for i = 1, 5 do
		local inset = (i - 1) * 2
		Kit.box(coop, "RoofStep" .. i, cx0 - 1.5 + inset, cx1 + 1.5 - inset, ry + (i - 1) * 1.2, ry + i * 1.2, cz0 - 1.5, cz1 + 1.5 - 0.0001 * i, if i % 2 == 0 then PAL.roofTeal:Lerp(PAL.white, 0.15) else PAL.roofTeal, { Pattern = "Studs" })
	end
	-- giant egg on the roof ridge
	local roofEgg = EggModel.build(3, false, 2.2)
	roofEgg:PivotTo(CFrame.new(X, ry + 6.0, Z))
	roofEgg.Parent = coop
	-- straw scatter at the base
	for k = 1, 6 do
		local a = (k / 6) * math.pi * 2
		Kit.hayBale(coop, CFrame.new(X + math.cos(a) * 12.5, 1.2, Z + math.sin(a) * 15.5) * CFrame.Angles(0, a, 0), Vector3.new(2.4, 1.6, 1.6))
	end

	-- 2) four hay-bale L-corners (cover for bait / cut-off plays; open side faces the centre line)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local stack = Kit.model(juke, "HayCorner")
			local hx, hz = X + sx * 44, Z + sz * 40
			-- arm along Z (outer side, away from the centre line)
			Kit.hayBale(stack, CFrame.new(hx + sx * 4, 0.2 + 1.6, hz - sz * 1) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(10, 3.2, 4))
			-- arm along X (toward the nearer field edge)
			Kit.hayBale(stack, CFrame.new(hx - sx * 1.5, 0.2 + 1.6, hz + sz * 4.05), Vector3.new(7, 3.2, 4))
			-- one bale on top of the corner, yawed 15 deg (prop imperfection)
			Kit.hayBale(stack, CFrame.new(hx + sx * 3.2, 0.2 + 3.2 + 1.6, hz + sz * 3) * CFrame.Angles(0, math.rad(15 * sx * sz), 0), Vector3.new(5, 3.2, 4))
			-- a pitchfork leaning on the stack (small-object detail)
			local fork = Kit.model(stack, "Pitchfork")
			local base = Vector3.new(hx - sx * 2.5, 0.2, hz - sz * 2.6)
			Kit.brick(fork, "Handle", Vector3.new(0.25, 6, 0.25), CFrame.new(base + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(15 * sx)), PAL.wood, { Pattern = "Smooth" })
			Kit.brick(fork, "Head", Vector3.new(1.4, 0.25, 0.25), CFrame.new(base + Vector3.new(-sx * 0.8, 5.9, 0)) * CFrame.Angles(0, 0, math.rad(15 * sx)), PAL.stoneDark, { Pattern = "Smooth" })
		end
	end

	-- 3) two hedge planters near the zones (last-second juke options)
	for _, sx in ipairs({ -1, 1 }) do
		local pl = Kit.model(juke, "HedgePlanter")
		local px = X + sx * 64
		Kit.box(pl, "Box", px - 3, px + 3, 0.2, 2.2, Z - 10, Z + 10, PAL.wood, { Pattern = "Weld" })
		Kit.box(pl, "BoxRim", px - 3.3, px + 3.3, 2.2, 2.6, Z - 10.3, Z + 10.3, PAL.wood2, { Pattern = "Weld" })
		Kit.box(pl, "Hedge", px - 2.4, px + 2.4, 2.6, 5.6, Z - 9.4, Z + 9.4, PAL.leaf2, { Pattern = "Studs" })
		Kit.box(pl, "HedgeTop", px - 2.0, px + 2.0, 5.6, 6.4, Z - 8.6, Z + 8.6, PAL.leaf3, { Pattern = "Studs" })
		for k = -2, 2 do
			Kit.flower(pl, Vector3.new(px + sx * 3.4, 0.2, Z + k * 4), if k % 2 == 0 then PAL.pink else PAL.white)
		end
	end

	-- ===== scenery ring (outside the fence) =====
	local scen = Kit.model(arena, "Scenery")
	local ringSpots = {
		{ -136, -88, 30, 20, 16 }, { -100, -95, 40, 14, 12 }, { -44, -96, 30, 14, 10 }, { 58, -95, 28, 14, 14 }, { 98, -94, 32, 16, 12 }, { 138, -84, 26, 22, 18 },
		{ -138, 86, 26, 22, 18 }, { -92, 96, 40, 14, 12 }, { -20, 96, 30, 14, 10 }, { 44, 95, 38, 14, 14 }, { 104, 94, 34, 16, 12 }, { 140, 80, 24, 20, 16 },
		{ -140, -20, 20, 34, 14 }, { -142, 30, 18, 28, 12 }, { 140, -28, 20, 30, 14 }, { 142, 26, 18, 30, 12 },
	}
	for i, s in ipairs(ringSpots) do
		local p = Kit.plateau(scen, Vector3.new(X + s[1], 0, Z + s[2]), Vector3.new(s[3], s[5], s[4]), if s[5] >= 14 then 3 else 2, rng, (i % 3) * 15)
		if i % 2 == 0 then
			local topY = p:GetAttribute("TopY")
			Kit.tree(scen, Vector3.new(X + s[1], topY, Z + s[2]), rng:NextNumber(13, 17), rng, if i % 4 == 0 then PAL.leaf2 else PAL.leaf)
		end
	end
	-- a big barn + silo backdrop on the north side
	local barn = Kit.model(scen, "BackdropBarn")
	local bz = Z - 92
	Kit.box(barn, "Body", X - 18, X + 18, 0, 16, bz - 10, bz + 6, PAL.red, { Pattern = "Studs" })
	for i = 1, 6 do
		local inset = (i - 1) * 3
		Kit.box(barn, "Roof" .. i, X - 20 + inset, X + 20 - inset, 16 + (i - 1) * 1.6, 16 + i * 1.6, bz - 11.5, bz + 7.5 - 0.0001 * i, PAL.white:Lerp(PAL.stone, 0.2), { Pattern = "Studs" })
	end
	Kit.box(barn, "DoorFrame", X - 6, X + 6, 0, 11, bz + 6, bz + 6.6, PAL.white, { Pattern = "Weld" })
	Kit.box(barn, "Door", X - 5, X + 5, 0, 10, bz + 6.5, bz + 7, PAL.redDark, { Pattern = "Weld" })
	local silo = Kit.model(scen, "Silo")
	for i = 1, 6 do
		Kit.brick(silo, "Ring" .. i, Vector3.new(10 - (i > 5 and 3 or 0), 4, 10 - (i > 5 and 3 or 0)), CFrame.new(X + 30, (i - 0.5) * 4, bz - 2), if i % 2 == 0 then PAL.stone else PAL.white, { Pattern = "Studs" })
	end

	-- ===== the egg nests at both zone backs (theme) =====
	for _, sx in ipairs({ -1, 1 }) do
		local nest = Kit.model(scen, "ZoneNest")
		local nx = X + sx * (OUT + 14)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			Kit.hayBale(nest, CFrame.new(nx + math.cos(a) * 4.5, 1.2, Z + math.sin(a) * 4.5) * CFrame.Angles(0, -a, 0), Vector3.new(3, 2, 2))
		end
		local egg = EggModel.build(if sx < 0 then 2 else 4, false, 2.6)
		egg:PivotTo(CFrame.new(nx, 0.6, Z))
		egg.Parent = nest
	end

	-- small set dressing: tufts, rocks, flowers inside the apron edges (never in lanes)
	local dress = Kit.model(arena, "Dressing")
	for i = 1, 40 do
		local side = if i % 2 == 0 then 1 else -1
		local px = X + rng:NextNumber(-OUT, OUT)
		local pz = Z + side * rng:NextNumber(HZ + 7, HZ + 16)
		Kit.tuft(dress, Vector3.new(px, 0, pz), rng)
		if i % 4 == 0 then
			Kit.rock(dress, Vector3.new(px + 3, 0, pz), rng:NextNumber(1.6, 3), rng)
		end
		if i % 5 == 0 then
			Kit.flower(dress, Vector3.new(px - 2, 0, pz), if i % 10 == 0 then PAL.pink else PAL.gold)
		end
	end

	return arena
end
