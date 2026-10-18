--!nocheck
-- HOS-LOBBY-007 (18 Oct 2026, Matthew): the Halloween spin wheel, from Matthew's concept sheet
-- (docs/HOS-LOBBY-007/spin_wheel_concept.webp). Structure only: the wheel's 8 sectors are blank for now.
-- Run in Studio (edit, command bar or the MCP's execute_luau). Rebuildable: replaces Workspace.SpinWheel.
--
-- On the open south end of the island, facing the altar (+Z). Built like the incubator: Plastic with Studs surfaces in
-- its purple-grey stone, dark navy trim, purple neon only as accents; the kit pumpkins and candles (HOS-LOBBY-005/006)
-- and a tree lantern (swung by the client's LobbyAmbience) dress it.
--   Base     a stone slab with chunky edge blocks, a raised tier the wheel stands on, a front step with a neon strip
--   Posts    two stone posts that rise either side of the wheel and hook outward at the top, a lantern hanging off each
--   Frame    a pillar behind the wheel carrying the axle and an arm over the top that holds the crystal pointer,
--            and a cradle under the wheel
--   Wheel    a dark backing disc, 8 sectors (Sector_1 at the top under the pointer, then clockwise from the front),
--            spokes, a navy rim with purple studs, a hub with a pumpkin emblem. Wheel.PrimaryPart is the Hub; spin the
--            wheel model about the Hub's Z axis (its SpinAxis attribute says so)
--   Props    pumpkins and candle groups on the front corners. Only the two big pumpkins keep a light; candles beside a
--            pumpkin share its light (as in HOS-LOBBY-006)
local CHS = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

local kit = ServerStorage:WaitForChild("HalloweenLobbyKit")
local FLOOR_Y = 10
local ORIGIN = CFrame.new(0, FLOOR_Y, 1451) -- the base's centre on the ground; local +Z is the front (towards the altar)

local STONE = { Color3.fromRGB(74, 63, 99), Color3.fromRGB(93, 83, 121), Color3.fromRGB(64, 57, 88), Color3.fromRGB(68, 60, 94), Color3.fromRGB(59, 52, 82) }
local DARK = Color3.fromRGB(28, 26, 48) -- rim, spokes, hub
local DARKER = Color3.fromRGB(17, 18, 38) -- backing disc
local IRON = Color3.fromRGB(58, 48, 54)
local NEON = Color3.fromRGB(180, 92, 255)
local GEM = Color3.fromRGB(140, 70, 230)
local SECTOR = { Color3.fromRGB(255, 140, 26), Color3.fromRGB(138, 64, 214), Color3.fromRGB(255, 140, 26), Color3.fromRGB(52, 38, 84) }

local rng = Random.new(1007)

local old = workspace:FindFirstChild("SpinWheel")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "SpinWheel"

local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function at(x, y, z)
	return ORIGIN * CFrame.new(x, y, z)
end

-- a stone-style part: Plastic, Studs on every face (as the incubator); Neon parts stay smooth
local function brick(parent, name, size, cf, color, opts)
	opts = opts or {}
	local p = Instance.new(opts.class or "Part")
	if opts.shape then p.Shape = opts.shape end
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.CanTouch = false
	p.Material = opts.neon and Enum.Material.Neon or Enum.Material.Plastic
	local s = (opts.neon or opts.smooth) and Enum.SurfaceType.Smooth or Enum.SurfaceType.Studs
	p.TopSurface, p.BottomSurface, p.FrontSurface, p.BackSurface, p.LeftSurface, p.RightSurface = s, s, s, s, s, s
	if opts.neon then
		p.CastShadow = false
		p.CanCollide = false
	end
	if opts.noCollide then p.CanCollide = false end
	p.Parent = parent
	return p
end

-- a flat triangle a-b-c (world points) `thick` deep, from two wedges (the usual two-wedge triangle)
local function tri(parent, name, a, b, c, thick, color, opts)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local o = opts or {}
	o.class = "WedgePart"
	local w1 = brick(parent, name, Vector3.new(thick, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), color, o)
	local w2 = brick(parent, name, Vector3.new(thick, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, o)
	return w1, w2
end

-- a kit or lobby model: clone, scale to `height`, turn its face (the way its glow points; kit pumpkins face -Z) to
-- `facing`, stand it on y = FLOOR_Y + `onY` at local (x, z)
local function prop(parent, src, height, x, z, onY, yaw, keepLight)
	local m = src:Clone()
	local _, sz = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * height / sz.Y)
	if not keepLight then
		for _, d in m:GetDescendants() do
			if d:IsA("Light") then d.Parent:Destroy() end
		end
	else
		local pl = m:FindFirstChildWhichIsA("PointLight", true)
		local spl = src:FindFirstChildWhichIsA("PointLight", true)
		if pl and spl then pl.Range = spl.Range end -- ScaleTo shrinks it with the model
	end
	local _, nsz = m:GetBoundingBox()
	m:PivotTo(at(x, onY + nsz.Y / 2, z) * CFrame.Angles(0, yaw, 0))
	m.Parent = parent
	return m
end

---------------------------------------------------------------- base
local base = model("Base", root)
local SLAB_W, SLAB_D, SLAB_H = 26, 14, 0.8
local TIER_W, TIER_D, TIER_H, TIER_Z = 18, 7, 0.6, -1
local TIER_TOP = SLAB_H + TIER_H
brick(base, "Slab", Vector3.new(SLAB_W, SLAB_H, SLAB_D), at(0, SLAB_H / 2, 0), STONE[3])
brick(base, "Tier", Vector3.new(TIER_W, TIER_H, TIER_D), at(0, SLAB_H + TIER_H / 2, TIER_Z), STONE[1])
-- tier lip: a darker band round the tier, a hair proud of it
brick(base, "TierLip", Vector3.new(TIER_W + 0.3, 0.2, TIER_D + 0.3), at(0, SLAB_H + 0.1001, TIER_Z), DARK)
-- front step up onto the tier, with a neon strip on its riser and one on the tier's riser
local STEP_W, STEP_D, STEP_H = 8, 1.2, 0.3
local tierFront = TIER_Z + TIER_D / 2
brick(base, "Step", Vector3.new(STEP_W, STEP_H, STEP_D), at(0, SLAB_H + STEP_H / 2, tierFront + STEP_D / 2 - 0.1), STONE[2])
brick(base, "StepGlow", Vector3.new(STEP_W - 0.6, 0.08, 0.06), at(0, SLAB_H + STEP_H / 2, tierFront + STEP_D - 0.1 + 0.02), NEON, { neon = true })
brick(base, "TierGlow", Vector3.new(TIER_W - 1.2, 0.08, 0.06), at(0, SLAB_H + STEP_H + (TIER_H - STEP_H) / 2, tierFront + 0.03), NEON, { neon = true })
-- chunky edge blocks round the slab: back and sides all along; the front stays open for the step and the props
local edge = model("EdgeBlocks", base)
local function edgeRun(x0, z0, x1, z1)
	local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
	local n = math.max(1, math.floor(len / 3.4 + 0.5))
	for i = 0, n - 1 do
		local t = (i + 0.5) / n
		local x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
		do
			local along = Vector3.new(x1 - x0, 0, z1 - z0).Unit
			local w = len / n + 0.15
			local h = SLAB_H + rng:NextNumber(0.15, 0.45)
			local d = rng:NextNumber(1.3, 1.8)
			local yaw = math.atan2(-along.Z, along.X) + math.rad(if rng:NextNumber() < 0.25 then 15 * (rng:NextInteger(0, 1) * 2 - 1) else 0)
			brick(edge, "EdgeBlock", Vector3.new(w, h, d), at(x, h / 2 + 0.0001 * i, z) * CFrame.Angles(0, yaw, 0), STONE[rng:NextInteger(1, #STONE)])
		end
	end
end
local hx, hz = SLAB_W / 2 - 0.6, SLAB_D / 2 - 0.6
edgeRun(-hx, -hz, hx, -hz) -- back
edgeRun(-hx, -hz + 1.5, -hx, hz - 1.5) -- left
edgeRun(hx, -hz + 1.5, hx, hz - 1.5) -- right
for _, sx in { -1, 1 } do -- corner blocks, turned 45°
	for _, sz in { -1, 1 } do
		brick(edge, "CornerBlock", Vector3.new(2.4, SLAB_H + 0.6, 2.4), at(sx * (hx - 0.2), (SLAB_H + 0.6) / 2, sz * (hz - 0.2)) * CFrame.Angles(0, math.rad(45), 0), STONE[2])
	end
end

---------------------------------------------------------------- wheel
local WHEEL_R = 6.0 -- sector radius (under the rim)
local RIM_IN, RIM_OUT = 5.8, 7.1
local WC = Vector3.new(0, TIER_TOP + 1.0 + RIM_OUT, TIER_Z) -- wheel centre, local (the rim's bottom sits 1.0 over the tier)
local function W(x, y, z) -- a point in the wheel's plane, local to the wheel centre, as a world point
	return at(WC.X + x, WC.Y + y, WC.Z + z).Position
end
local wheel = model("Wheel", root)
local axisCF = at(WC.X, WC.Y, WC.Z) -- the wheel's axis is this CFrame's Z
brick(wheel, "Backing", Vector3.new(0.6, (RIM_OUT + 0.1) * 2, (RIM_OUT + 0.1) * 2), axisCF * CFrame.new(0, 0, -0.35) * CFrame.Angles(0, math.rad(90), 0), DARKER, { shape = Enum.PartType.Cylinder, smooth = true })
local sectors = model("Sectors", wheel)
for j = 0, 7 do
	-- sector j spans from the top (under the pointer) clockwise as you face the wheel
	local a0 = math.rad(90 + 22.5 - 45 * j)
	local a1 = math.rad(90 - 22.5 - 45 * j)
	local R = WHEEL_R + 0.1
	local s = model("Sector_" .. (j + 1), sectors)
	tri(s, "Face", W(0, 0, 0.05), W(math.cos(a0) * R, math.sin(a0) * R, 0.05), W(math.cos(a1) * R, math.sin(a1) * R, 0.05), 0.3, SECTOR[j % 4 + 1])
	s:SetAttribute("Slot", j + 1)
end
local spokes = model("Spokes", wheel)
for j = 0, 7 do
	local a = math.rad(90 + 22.5 - 45 * j)
	local r0, r1 = 1.6, RIM_IN + 0.15
	local mid = (r0 + r1) / 2
	brick(spokes, "Spoke", Vector3.new(0.24, r1 - r0, 0.3), axisCF * CFrame.new(math.cos(a) * mid, math.sin(a) * mid, 0.2) * CFrame.Angles(0, 0, a - math.pi / 2), DARK)
end
local rim = model("Rim", wheel)
local RIM_N = 16
for i = 0, RIM_N - 1 do
	local a = 2 * math.pi * i / RIM_N + math.pi / RIM_N
	local r = (RIM_IN + RIM_OUT) / 2
	local len = 2 * RIM_OUT * math.tan(math.pi / RIM_N) + 0.12
	local depth = 1.0 + (i % 2) * 0.0002 -- neighbours overlap at the corners: never the same face planes
	brick(rim, "RimBlock", Vector3.new(len, RIM_OUT - RIM_IN, depth), axisCF * CFrame.new(math.cos(a) * r, math.sin(a) * r, -0.05 + (i % 2) * 0.0001) * CFrame.Angles(0, 0, a - math.pi / 2), DARK)
	-- a purple stud on every block, turned to a diamond
	brick(rim, "RimStud", Vector3.new(0.7, 0.7, 0.3), axisCF * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0.55) * CFrame.Angles(0, 0, math.rad(45)), GEM)
end
local hub = brick(wheel, "Hub", Vector3.new(0.6, 3.6, 3.6), axisCF * CFrame.new(0, 0, 0.35) * CFrame.Angles(0, math.rad(90), 0), DARK, { shape = Enum.PartType.Cylinder, smooth = true })
brick(wheel, "HubGlow", Vector3.new(0.2, 3.95, 3.95), axisCF * CFrame.new(0, 0, 0.2) * CFrame.Angles(0, math.rad(90), 0), NEON, { shape = Enum.PartType.Cylinder, neon = true })
brick(wheel, "HubFace", Vector3.new(0.1, 3.0, 3.0), axisCF * CFrame.new(0, 0, 0.68) * CFrame.Angles(0, math.rad(90), 0), STONE[5], { shape = Enum.PartType.Cylinder, smooth = true })
hub:SetAttribute("SpinAxis", "Z (the wheel turns about the Hub's front-back axis)")
wheel.PrimaryPart = hub
-- the emblem: a kit pumpkin on the hub, face out, no light of its own
local jack = kit:FindFirstChild("A04_JackOLantern")
if jack then
	local e = jack:Clone()
	e.Name = "Emblem"
	local _, sz = e:GetBoundingBox()
	e:ScaleTo(2.3 / sz.Y)
	for _, d in e:GetDescendants() do
		if d:IsA("Light") then d.Parent:Destroy() end
	end
	local _, esz = e:GetBoundingBox()
	e:PivotTo(axisCF * CFrame.new(0, 0, 0.73 + esz.Z / 2 - 0.35) * CFrame.Angles(0, math.pi, 0)) -- kit faces -Z; turn it to the front
	e.Parent = wheel
end

---------------------------------------------------------------- frame: pillar, axle, arm, pointer, cradle
local frame = model("Frame", root)
local PILLAR_Z = WC.Z - 1.6
local ARM_Y = WC.Y + RIM_OUT + 1.75
local PILLAR_TOP = ARM_Y + 0.5 -- the pillar stops level with the arm's top: one L-shaped bracket over the wheel
brick(frame, "Pillar", Vector3.new(2.4, PILLAR_TOP - TIER_TOP, 1.8), at(0, TIER_TOP + (PILLAR_TOP - TIER_TOP) / 2, PILLAR_Z), STONE[1])
brick(frame, "Axle", Vector3.new(1.4, 1.6, 1.6), at(WC.X, WC.Y, (PILLAR_Z + WC.Z - 0.6) / 2) * CFrame.Angles(0, math.rad(90), 0), IRON, { shape = Enum.PartType.Cylinder, smooth = true })
brick(frame, "Arm", Vector3.new(1.4, 1.0, 3.2), at(0, ARM_Y, PILLAR_Z + 1.4), STONE[4])
brick(frame, "ArmCap", Vector3.new(1.8, 0.4, 1.8), at(0, ARM_Y + 0.7, WC.Z + 0.95), DARK)
-- the pointer: a faceted crystal hanging under the arm's tip, its point just over the top sector
local pointer = model("Pointer", frame)
local PZ = WC.Z + 0.95 -- in front of the rim's studs, so the wheel can turn under it
local top, bottom = Vector3.new(0, ARM_Y - 0.4, PZ), Vector3.new(0, WC.Y + RIM_IN - 0.15, PZ)
local midY = bottom.Y + (top.Y - bottom.Y) * 0.58
local L, Rt = Vector3.new(-0.85, midY, PZ), Vector3.new(0.85, midY, PZ)
local F, B = Vector3.new(0, midY, PZ + 0.45), Vector3.new(0, midY, PZ - 0.45)
local function P(v) return at(v.X, v.Y, v.Z).Position end
for _, f in { { top, L, F }, { top, F, Rt }, { bottom, F, L }, { bottom, Rt, F } } do
	tri(pointer, "CrystalFront", P(f[1]), P(f[2]), P(f[3]), 0.05, NEON, { neon = true })
end
for _, f in { { top, B, L }, { top, Rt, B }, { bottom, L, B }, { bottom, B, Rt } } do
	tri(pointer, "CrystalBack", P(f[1]), P(f[2]), P(f[3]), 0.05, GEM, { smooth = true })
end
-- cradle under the wheel, a glow strip on its front
local wheelBottom = WC.Y - RIM_OUT
brick(frame, "Cradle", Vector3.new(6, wheelBottom - TIER_TOP + 0.1, 1.8), at(0, TIER_TOP + (wheelBottom - TIER_TOP + 0.1) / 2, WC.Z - 0.05), STONE[2])
brick(frame, "CradleGlow", Vector3.new(5.4, 0.12, 0.06), at(0, TIER_TOP + (wheelBottom - TIER_TOP) / 2, WC.Z - 0.05 + 0.92), NEON, { neon = true })

---------------------------------------------------------------- posts and lanterns
local posts = model("Posts", root)
local lanternSrc
for _, d in workspace:WaitForChild("Trees"):GetDescendants() do
	if d:IsA("Model") and d:FindFirstChild("A03_Chain") then
		lanternSrc = d
		break
	end
end
local SEGS = { -- (degrees outward from upright, length, thickness): straight up, then hooking over and down
	{ 0, 3.4, 2.3 }, { 0, 3.2, 2.2 }, { 0, 3.0, 2.1 }, { 10, 2.6, 2.0 }, { 25, 2.2, 1.9 }, { 55, 1.8, 1.8 }, { 90, 1.6, 1.7 }, { 125, 1.4, 1.6 },
}
local POST_X, POST_Z = 9.5, -1.5
for _, side in { -1, 1 } do
	local post = model(if side < 0 then "Post_L" else "Post_R", posts)
	brick(post, "Foot", Vector3.new(3.4, 1.0, 3.4), at(side * POST_X, SLAB_H + 0.5, POST_Z), STONE[2])
	brick(post, "FootCap", Vector3.new(2.9, 0.4, 2.9), at(side * POST_X, SLAB_H + 1.2, POST_Z), STONE[4])
	local p = at(side * POST_X, SLAB_H + 1.2, POST_Z).Position
	local dir
	for i, s in SEGS do
		local th = math.rad(s[1])
		dir = (ORIGIN:VectorToWorldSpace(Vector3.new(side * math.sin(th), math.cos(th), 0))).Unit
		local centre = p + dir * (s[2] / 2)
		local vx = Vector3.new(dir.Y, -dir.X, 0)
		brick(post, "Segment" .. i, Vector3.new(s[3], s[2], s[3] + 0.0001 * i), CFrame.fromMatrix(centre, vx, dir), STONE[(i % 3) + 1])
		-- a knuckle block at each bend so the outside of the curve stays closed
		if i > 1 and s[1] ~= SEGS[i - 1][1] then
			brick(post, "Knuckle" .. i, Vector3.new(s[3] + 0.05, s[3] + 0.05, s[3] + 0.0003), CFrame.fromMatrix(p, vx, dir), STONE[(i % 3) + 1])
		end
		p = p + dir * (s[2] - 0.3)
	end
	-- iron bracket at the hook's tip, the lantern hanging from it
	local tip = p + dir * 0.3
	brick(post, "Bracket", Vector3.new(0.8, 0.5, 0.8), CFrame.new(tip), IRON)
	if lanternSrc then
		local lan = lanternSrc:Clone()
		lan.Name = "Lantern"
		local _, lsz = lan:GetBoundingBox()
		local pv = lan:GetPivot()
		lan:PivotTo(CFrame.new(pv.Position) * CFrame.Angles(0, if side < 0 then 0 else math.pi, 0) * pv.Rotation)
		local c = lan:GetBoundingBox()
		lan:PivotTo(lan:GetPivot() + (Vector3.new(tip.X, tip.Y - 0.25 - lsz.Y / 2, tip.Z) - c.Position))
		lan.Parent = post
	end
end

---------------------------------------------------------------- props: pumpkins and candles on the front corners
local props = model("Props", root)
local frontZ = SLAB_D / 2
local function candleGroup(cx, cz, sizes)
	local g = model("Candles", props)
	local spots = { Vector3.new(0, 0, 0), Vector3.new(0.75, 0, 0.45), Vector3.new(-0.35, 0, 0.8) }
	for k, s in sizes do
		local src = kit:FindFirstChild("A05_Candle_" .. s)
		if src then
			prop(g, src, select(2, src:GetBoundingBox()).Y * 0.85, cx + spots[k].X, cz + spots[k].Z, SLAB_H, rng:NextNumber(0, 2 * math.pi), false)
		end
	end
end
if jack then
	-- kit pumpkins face -Z; yaw pi turns them to the front, a little more turns them outward
	prop(props, jack, 2.6, -8.6, frontZ - 2.6, SLAB_H, math.pi - math.rad(20), true).Name = "Pumpkin_L"
	prop(props, jack, 1.5, -6.2, frontZ - 1.4, SLAB_H, math.pi + math.rad(10), false).Name = "PumpkinSmall_L"
	prop(props, jack, 2.2, 8.7, frontZ - 2.6, SLAB_H, math.pi + math.rad(20), true).Name = "Pumpkin_R"
end
candleGroup(-4.9, frontZ - 3.0, { "Large", "Small" })
candleGroup(5.4, frontZ - 2.8, { "Large", "Medium", "Small" })

root.WorldPivot = ORIGIN
root.Parent = workspace
pcall(CHS.SetWaypoint, CHS, "HOS-LOBBY-007: spin wheel")

local n = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then n += 1 end
end
local cf, sz = root:GetBoundingBox()
return ("built Workspace.SpinWheel: %d parts, %s at %s"):format(n, tostring(sz), tostring(cf.Position))
