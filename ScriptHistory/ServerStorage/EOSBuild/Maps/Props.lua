--!nocheck
-- Props: themed stud-style props for the arena maps. Each returns a Model built from simple
-- anchored parts (Plastic, pattern by role), curves made from 15-degree chained segments.
local Kit = require(script.Parent.Parent.WorldKit)
local PAL = Kit.PAL

local Props = {}

local C = {
	palmTrunk = Color3.fromRGB(206, 164, 112),
	palmTrunk2 = Color3.fromRGB(178, 134, 90),
	coconut = Color3.fromRGB(122, 84, 56),
	palmLeaf = { Color3.fromRGB(96, 196, 72), Color3.fromRGB(80, 178, 70), Color3.fromRGB(116, 210, 80) },
	pine = { Color3.fromRGB(60, 150, 96), Color3.fromRGB(48, 132, 88), Color3.fromRGB(74, 166, 104) },
	pineTrunk = Color3.fromRGB(150, 96, 70),
	snow = Color3.fromRGB(248, 251, 255),
	snowShade = Color3.fromRGB(226, 236, 250),
	ice = Color3.fromRGB(150, 210, 245),
	ice2 = Color3.fromRGB(122, 192, 240),
	ice3 = Color3.fromRGB(184, 228, 252),
	carrot = Color3.fromRGB(255, 140, 50),
	coal = Color3.fromRGB(40, 40, 52),
}
Props.C = C

-- Palm: bent trunk of chained segments (each starts buried 0.3 in the last and leans a further
-- 15 deg every second segment), frond cross of two-piece drooping leaves, coconuts.
function Props.palm(parent, base: Vector3, height: number, yaw: number, rng, leafIdx: number?)
	local m = Kit.model(parent, "Palm")
	local leaf = C.palmLeaf[leafIdx or rng:NextInteger(1, #C.palmLeaf)]
	local segs = math.max(5, math.floor(height / 1.7))
	local segH = height / segs + 0.3
	local cf = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
	-- a root flare on the sand
	Kit.brick(m, "Root", Vector3.new(2.4, 0.6, 2.4), cf * CFrame.new(0, 0.3, 0), C.palmTrunk2, { Pattern = "Weld" })
	for i = 1, segs do
		if i > 2 and i % 2 == 1 and i <= 7 then
			cf = cf * CFrame.Angles(math.rad(-15), 0, 0) -- lean toward local -Z, 15 deg per step
		end
		local w = (if i % 2 == 0 then 1.5 else 1.3) - i * 0.03
		Kit.brick(m, "Trunk" .. i, Vector3.new(w, segH, w), cf * CFrame.new(0, segH / 2, 0), if i % 2 == 0 then C.palmTrunk2 else C.palmTrunk, { Pattern = "Weld" })
		cf = cf * CFrame.new(0, segH - 0.3, 0)
	end
	local top = CFrame.new(cf.Position) * CFrame.Angles(0, math.rad(yaw), 0)
	Kit.brick(m, "CrownHub", Vector3.new(2.2, 1.2, 2.2), top * CFrame.new(0, 0.4, 0), leaf:Lerp(Color3.new(0, 0, 0), 0.12), { Pattern = "Studs" })
	for k = 0, 5 do
		local a = top * CFrame.Angles(0, math.rad(k * 60 + 15), 0) * CFrame.new(0, 0.6, 0)
		local p1 = a * CFrame.Angles(math.rad(-15), 0, 0)
		Kit.brick(m, "Frond", Vector3.new(1.6, 0.4, 4.6), p1 * CFrame.new(0, 0, -2.1), leaf, { Pattern = "Studs" })
		local p2 = p1 * CFrame.new(0, 0, -4.1) * CFrame.Angles(math.rad(-30), 0, 0)
		Kit.brick(m, "FrondTip", Vector3.new(1.2, 0.36, 3.6), p2 * CFrame.new(0, 0, -1.6), leaf, { Pattern = "Studs" })
	end
	for k = 0, 2 do
		local a = top * CFrame.Angles(0, math.rad(k * 120), 0) * CFrame.new(0, -0.5, -0.9)
		Kit.brick(m, "Coconut", Vector3.new(0.8, 0.8, 0.8), a, C.coconut, { Pattern = "Smooth" })
	end
	return m
end

-- Tiered pine (cake rhythm 8,5,7,4,2 scaled), a snow cap on every tier when snowy.
function Props.pine(parent, base: Vector3, height: number, rng, snowy: boolean, shade: number?)
	local m = Kit.model(parent, "Pine")
	local leaf = C.pine[shade or rng:NextInteger(1, #C.pine)]
	local s = height / 12
	Kit.brick(m, "Trunk", Vector3.new(1.4 * s, 3 * s, 1.4 * s), CFrame.new(base + Vector3.new(0, 1.5 * s, 0)), C.pineTrunk, { Pattern = "Weld" })
	local widths = { 8, 5, 7, 4, 2 }
	local y = base.Y + 2.4 * s
	local tierH = 1.9 * s
	for i, w in widths do
		local ww = w * s
		Kit.brick(m, "Tier" .. i, Vector3.new(ww, tierH, ww), CFrame.new(base.X, y + tierH / 2, base.Z), leaf, { Pattern = "Studs" })
		if snowy then
			Kit.brick(m, "Snow" .. i, Vector3.new(ww - 0.6 * s + 0.05, 0.35 * s, ww - 0.6 * s + 0.05), CFrame.new(base.X, y + tierH + 0.175 * s, base.Z), C.snow, { Pattern = "Universal" })
		end
		y += tierH * 0.82
	end
	Kit.brick(m, "Tip", Vector3.new(0.8 * s, 1.2 * s, 0.8 * s), CFrame.new(base.X, y + 0.6 * s, base.Z), if snowy then C.snow else leaf, { Pattern = "Smooth" })
	return m
end

-- Snowman: three stacked chunky blocks, coal eyes + buttons, carrot nose, stick arms, hat, scarf.
function Props.snowman(parent, base: Vector3, yaw: number, scale: number?)
	local m = Kit.model(parent, "Snowman")
	local s = scale or 1
	local cf = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
	local sizes = { 3.6, 2.7, 2.0 }
	local y = 0
	local heads = {}
	for i, w in sizes do
		local h = w * 0.92
		local b = Kit.brick(m, ({ "Base", "Body", "Head" })[i], Vector3.new(w, h, w) * s, cf * CFrame.new(0, (y + h / 2) * s, 0), if i == 2 then C.snowShade else C.snow, { Pattern = "Universal" })
		heads[i] = { y = y, h = h, w = w, part = b }
		y += h - 0.15
	end
	local hd = heads[3]
	local face = cf * CFrame.new(0, (hd.y + hd.h * 0.55) * s, -(hd.w / 2) * s)
	for _, ex in { -0.45, 0.45 } do
		Kit.brick(m, "Eye", Vector3.new(0.3, 0.3, 0.2) * s, face * CFrame.new(ex * s, 0.2 * s, -0.05 * s), C.coal, { Pattern = "Smooth" })
	end
	Kit.brick(m, "Nose", Vector3.new(0.35, 0.35, 1.1) * s, face * CFrame.new(0, -0.15 * s, -0.5 * s), C.carrot, { Pattern = "Smooth" })
	local bd = heads[2]
	for k = 0, 2 do
		Kit.brick(m, "Button", Vector3.new(0.35, 0.35, 0.2) * s, cf * CFrame.new(0, (bd.y + bd.h * (0.3 + k * 0.22)) * s, -(bd.w / 2 + 0.05) * s), C.coal, { Pattern = "Smooth" })
	end
	-- scarf ring between body and head + a tail
	local sy = (hd.y + 0.1) * s
	Kit.brick(m, "Scarf", Vector3.new(2.2, 0.5, 2.2) * s, cf * CFrame.new(0, sy, 0), PAL.red, { Pattern = "Weld" })
	Kit.brick(m, "ScarfTail", Vector3.new(0.6, 1.6, 0.25) * s, cf * CFrame.new(0.6 * s, sy - 0.7 * s, -1.15 * s) * CFrame.Angles(0, 0, math.rad(15)), PAL.red, { Pattern = "Weld" })
	-- hat
	local hatY = (hd.y + hd.h) * s
	Kit.brick(m, "HatBrim", Vector3.new(2.4, 0.25, 2.4) * s, cf * CFrame.new(0, hatY + 0.12 * s, 0), C.coal, { Pattern = "Smooth" })
	Kit.brick(m, "HatCrown", Vector3.new(1.5, 1.3, 1.5) * s, cf * CFrame.new(0, hatY + 0.9 * s, 0), C.coal, { Pattern = "Weld" })
	Kit.brick(m, "HatBand", Vector3.new(1.6, 0.3, 1.6) * s, cf * CFrame.new(0, hatY + 0.45 * s, 0), PAL.red, { Pattern = "Smooth" })
	-- stick arms, raised 30 deg
	for _, sx in { -1, 1 } do
		local sh = cf * CFrame.new(sx * (bd.w / 2) * s, (bd.y + bd.h * 0.7) * s, 0)
		Kit.brick(m, "Arm", Vector3.new(2.4, 0.3, 0.3) * s, sh * CFrame.Angles(0, 0, math.rad(30 * sx)) * CFrame.new(sx * 1.1 * s, 0, 0), C.coal:Lerp(PAL.wood2, 0.6), { Pattern = "Smooth" })
	end
	return m
end

-- Beach umbrella: pole + stepped two-colour canopy + a striped towel and a little cooler.
function Props.umbrella(parent, base: Vector3, colA: Color3, colB: Color3, yaw: number)
	local m = Kit.model(parent, "BeachSpot")
	local cf = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
	Kit.brick(m, "Pole", Vector3.new(0.4, 7, 0.4), cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(15)), PAL.white, { Pattern = "Smooth" })
	local top = cf * CFrame.Angles(0, 0, math.rad(15)) * CFrame.new(0, 6.8, 0)
	local widths = { 7, 5, 3, 1.4 }
	for i, w in widths do
		Kit.brick(m, "Canopy" .. i, Vector3.new(w, 0.5, w), top * CFrame.new(0, (i - 1) * 0.5, 0), if i % 2 == 1 then colA else colB, { Pattern = "Studs" })
	end
	-- towel: 3 stripes
	for k = -1, 1 do
		Kit.brick(m, "Towel", Vector3.new(1.0, 0.1, 4.6), cf * CFrame.new(2.2 + k * 1.0, 0.05, 1.5), if k == 0 then PAL.white else colA, { Pattern = "Smooth" })
	end
	-- cooler
	local cc = cf * CFrame.new(-2.4, 0, 1.2)
	Kit.brick(m, "Cooler", Vector3.new(2, 1.4, 1.3), cc * CFrame.new(0, 0.7, 0), PAL.blue, { Pattern = "Weld" })
	Kit.brick(m, "CoolerLid", Vector3.new(2.1, 0.3, 1.4), cc * CFrame.new(0, 1.55, 0), PAL.white, { Pattern = "Weld" })
	return m
end

-- Starfish: a flat plus of five arms around a centre.
function Props.starfish(parent, base: Vector3, color: Color3, yaw: number)
	local m = Kit.model(parent, "Starfish")
	local cf = CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, math.rad(yaw), 0)
	Kit.brick(m, "Center", Vector3.new(0.7, 0.2, 0.7), cf, color:Lerp(PAL.white, 0.25), { Pattern = "Smooth" })
	for k = 0, 4 do
		Kit.brick(m, "Arm", Vector3.new(0.45, 0.19, 1.0), cf * CFrame.Angles(0, math.rad(k * 72), 0) * CFrame.new(0, 0, -0.75), color, { Pattern = "Smooth" })
	end
	return m
end

-- Little crab: body, two claws, eye stalks, legs.
function Props.crab(parent, base: Vector3, yaw: number)
	local m = Kit.model(parent, "Crab")
	local cf = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
	local red = Color3.fromRGB(236, 84, 64)
	Kit.brick(m, "Shell", Vector3.new(1.6, 0.6, 1.1), cf * CFrame.new(0, 0.5, 0), red, { Pattern = "Studs" })
	for _, sx in { -1, 1 } do
		Kit.brick(m, "Claw", Vector3.new(0.6, 0.5, 0.6), cf * CFrame.new(sx * 1.1, 0.45, -0.7) * CFrame.Angles(0, math.rad(15 * sx), 0), red, { Pattern = "Smooth" })
		Kit.brick(m, "EyeStalk", Vector3.new(0.2, 0.5, 0.2), cf * CFrame.new(sx * 0.3, 1.0, -0.35), PAL.white, { Pattern = "Smooth" })
		for k = -1, 1 do
			Kit.brick(m, "Leg", Vector3.new(0.6, 0.15, 0.15), cf * CFrame.new(sx * 0.95, 0.25, k * 0.35) * CFrame.Angles(0, 0, math.rad(-30 * sx)), red:Lerp(Color3.new(0, 0, 0), 0.15), { Pattern = "Smooth" })
		end
	end
	return m
end

-- Mini sandcastle (decor): stepped keep, four corner turrets with crenels, a flag.
function Props.sandcastle(parent, base: Vector3, yaw: number)
	local m = Kit.model(parent, "Sandcastle")
	local sandA, sandB = Color3.fromRGB(232, 200, 140), Color3.fromRGB(220, 184, 124)
	local cf = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
	Kit.brick(m, "Keep", Vector3.new(4, 2.2, 4), cf * CFrame.new(0, 1.1, 0), sandA, { Pattern = "Studs" })
	Kit.brick(m, "KeepTop", Vector3.new(2.6, 1.4, 2.6), cf * CFrame.new(0, 2.9, 0), sandB, { Pattern = "Studs" })
	for _, p in { { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } } do
		Kit.brick(m, "Turret", Vector3.new(1.4, 3.2, 1.4), cf * CFrame.new(p[1], 1.6, p[2]), sandB, { Pattern = "Studs" })
		Kit.brick(m, "Crenel", Vector3.new(1.6, 0.5, 1.6), cf * CFrame.new(p[1], 3.45, p[2]), sandA, { Pattern = "Studs" })
	end
	Kit.brick(m, "FlagPole", Vector3.new(0.2, 2.2, 0.2), cf * CFrame.new(0, 4.7, 0), PAL.white, { Pattern = "Smooth" })
	Kit.brick(m, "Flag", Vector3.new(0.1, 0.8, 1.2), cf * CFrame.new(0, 5.4, -0.6), PAL.red, { Pattern = "Smooth" })
	-- bucket + spade beside it
	Kit.brick(m, "Bucket", Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(3.6, 0.6, 1.2), PAL.pink, { Pattern = "Weld" })
	Kit.brick(m, "BucketRim", Vector3.new(1.4, 0.2, 1.4), cf * CFrame.new(3.6, 1.25, 1.2), PAL.white, { Pattern = "Smooth" })
	Kit.brick(m, "Spade", Vector3.new(0.2, 2, 0.2), cf * CFrame.new(4.4, 1.0, -0.4) * CFrame.Angles(math.rad(15), 0, 0), PAL.blue, { Pattern = "Smooth" })
	return m
end

-- Ice blocks stacked into an L (cover piece). sx/sz: which quadrant, arms open toward the centre line.
function Props.iceWall(parent, cx: number, cz: number, sx: number, sz: number, rng)
	local m = Kit.model(parent, "IceWallCorner")
	local tones = { C.ice, C.ice2, C.ice3 }
	local function block(name, cf, size)
		return Kit.brick(m, name, size, cf, tones[rng:NextInteger(1, 3)], { Pattern = "Universal" })
	end
	-- arm along Z (outer side): 3 blocks long, 2 courses
	for k = -1, 1 do
		block("IceBlock", CFrame.new(cx + sx * 4, 0.2 + 1.7, cz - sz * 1 + k * 3.4), Vector3.new(3.4, 3.4, 3.4))
		if k <= 0 then
			block("IceBlock", CFrame.new(cx + sx * 4, 0.2 + 3.4 + 1.5, cz - sz * 1 + k * 3.4 + 0.2) * CFrame.Angles(0, math.rad(15 * (k + 1)), 0), Vector3.new(3.0, 3.0, 3.0))
		end
	end
	-- arm along X (toward the field edge): 2 blocks
	for k = 0, 1 do
		block("IceBlock", CFrame.new(cx + sx * (4 - 3.4 - k * 3.4), 0.2 + 1.7, cz + sz * 3.2 + sz * 0.8), Vector3.new(3.4001, 3.4001, 3.4001))
	end
	-- snow drift along the base and a cap of snow on the high blocks
	Kit.box(m, "Drift", cx + sx * 4 - 2.2, cx + sx * 4 + 2.2, 0.2, 0.9, cz - sz * 1 - 5.6, cz - sz * 1 + 5.6, C.snow, { Pattern = "Universal" })
	Kit.brick(m, "SnowCap", Vector3.new(3.2, 0.4, 6.6), CFrame.new(cx + sx * 4, 0.2 + 3.4 + 3.0 + 0.2, cz - sz * 1 - 1.5), C.snow, { Pattern = "Universal" })
	return m
end

return Props
