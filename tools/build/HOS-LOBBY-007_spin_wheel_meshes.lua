--!nocheck
-- HOS-LOBBY-007 (18 Oct 2026, Matthew): assembles the mesh spin wheel after File -> Import 3D of
-- docs/HOS-LOBBY-007/SpinWheel.glb (made by tools/build/HOS-LOBBY-007_spin_wheel_meshes.py). Run in Studio (edit, command
-- bar or the MCP's execute_luau).
--   1. finds the import (its WheelRim), turns it so its front (the crystal, ahead of the back frame) faces the altar (+Z)
--      and sets it where the block wheel stood: the base's middle on the ground at ORIGIN
--   2. copies the one Sector and Divider round the wheel (8 each, Sector_1 at the top under the pointer, then clockwise as
--      you face it) and the one Gem round the rim (11, none at the top under the crystal)
--   3. colours and materials (stone Plastic, neon accents), collisions (only the stone and wheel body collide), and studs:
--      the stone, rim, hub and sectors wear MaterialVariant HOS_StudsMesh (made here from the plaza floor's HOS_Studs
--      textures, HOS-LOBBY-008), which the GLB's one-UV-per-stud mapping lays out like the Studs surfaces on parts
--   4. adds a kit pumpkin as the hub's emblem, a tree lantern on each post's hook, and pumpkins and candles on the base's
--      top either side of the steps, sized and placed as in the concept (the two big pumpkins and the lanterns are the
--      only lights)
--   5. groups it as Workspace.SpinWheel: Base, Posts, Frame, Wheel (PrimaryPart Hub; spin it about the Hub's Z axis), Props
-- The block version (Workspace.SpinWheel before this) goes to ServerStorage._Backups.HOS-LOBBY-007_2026-10-18_BlockSpinWheel.
local ServerStorage = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local ORIGIN = CFrame.new(0, 10, 1451)
local RIM_LOCAL = Vector3.new(0, 10.72, -0.05) -- WheelRim's centre in the GLB (the wheel's axis runs through it along Z)
local HOOK_LOCAL = Vector3.new(10.1, 16.6, -1.75) -- the posts' lantern hooks (x mirrored for the left)
local LEDGE_TOP = 3.0 -- the base's top, where the pumpkins and candles stand
local HUB_FRONT = 0.23 -- the hub's recessed face, in front of the rim's centre
local LANTERN_H = 4.4 -- the concept's lanterns, ring to base

local STONE_DARK = Color3.fromRGB(74, 63, 99)
local NEON = Color3.fromRGB(180, 92, 255)
local LOOK = { -- name: colour, material, collides
	BaseStone = { STONE_DARK, Enum.Material.Plastic, true },
	BaseBlocks = { Color3.fromRGB(93, 83, 121), Enum.Material.Plastic, true },
	StepGlow = { NEON, Enum.Material.Neon, false },
	PostL = { Color3.fromRGB(98, 88, 124), Enum.Material.Plastic, true },
	PostR = { Color3.fromRGB(98, 88, 124), Enum.Material.Plastic, true },
	Cracks = { Color3.fromRGB(40, 34, 58), Enum.Material.Plastic, false },
	BackFrame = { Color3.fromRGB(40, 36, 62), Enum.Material.Plastic, true },
	Axle = { Color3.fromRGB(58, 48, 54), Enum.Material.Plastic, false },
	Crystal = { Color3.fromRGB(200, 110, 255), Enum.Material.Neon, false },
	WheelBacking = { Color3.fromRGB(17, 18, 38), Enum.Material.Plastic, true },
	WheelRim = { Color3.fromRGB(32, 28, 52), Enum.Material.Plastic, true },
	WheelRimInner = { Color3.fromRGB(58, 40, 92), Enum.Material.Plastic, false },
	Sector = { Color3.fromRGB(255, 150, 30), Enum.Material.Plastic, false },
	Divider = { Color3.fromRGB(170, 90, 255), Enum.Material.Neon, false },
	Gem = { Color3.fromRGB(150, 75, 235), Enum.Material.Plastic, false },
	Hub = { Color3.fromRGB(32, 28, 52), Enum.Material.Plastic, true },
}
local SECTOR_COLORS = { -- clockwise from the top, as in the concept
	Color3.fromRGB(80, 40, 130), Color3.fromRGB(150, 70, 230), Color3.fromRGB(40, 32, 58), Color3.fromRGB(40, 32, 58),
	Color3.fromRGB(120, 60, 210), Color3.fromRGB(255, 150, 30), Color3.fromRGB(80, 40, 130), Color3.fromRGB(255, 150, 30),
}

local kit = ServerStorage:WaitForChild("HalloweenLobbyKit")

-- studs on the meshes (Matthew: "Can you stud the parts"): everything solid except the gems, crystal, cracks and glows
local STUDDED = { BaseStone = true, BaseBlocks = true, PostL = true, PostR = true, BackFrame = true, WheelBacking = true, WheelRim = true, WheelRimInner = true, Sector = true, Hub = true }
local STUDS_PER_TILE = 1 -- one stud per stud, as the GLB's UVs are in studs
local MaterialService = game:GetService("MaterialService")
local studs = MaterialService:FindFirstChild("HOS_StudsMesh")
if not studs then
	local src = MaterialService:FindFirstChild("HOS_Studs")
	assert(src, "no MaterialService.HOS_Studs to copy the stud textures from")
	studs = Instance.new("MaterialVariant")
	studs.Name = "HOS_StudsMesh"
	studs.BaseMaterial = Enum.Material.Plastic
	studs.ColorMap, studs.NormalMap = src.ColorMap, src.NormalMap
	studs.MaterialPattern = Enum.MaterialPattern.Regular
	studs.Parent = MaterialService
end
studs.StudsPerTile = STUDS_PER_TILE

---------------------------------------------------------------- 1. the import, turned and placed
local imported
for _, d in workspace:GetDescendants() do
	if d:IsA("MeshPart") and d.Name == "WheelRim" and d.Parent and d.Parent.Name == "WheelRim_Node" then -- the import (not an assembled wheel)
		imported = d
		while imported.Parent ~= workspace do imported = imported.Parent end
		break
	end
end
assert(imported and imported:IsA("Model"), "no imported WheelRim in the workspace: import docs/HOS-LOBBY-007/SpinWheel.glb first")
local P = {}
for _, d in imported:GetDescendants() do
	if d:IsA("MeshPart") and LOOK[d.Name] then P[d.Name] = d end
end
for name in LOOK do assert(P[name], "the import has no " .. name) end

local front = (P.Crystal.Position - P.BackFrame.Position) * Vector3.new(1, 0, 1)
local heading = math.atan2(front.X, front.Z)
local target = ORIGIN * CFrame.new(RIM_LOCAL)
local T = CFrame.new(target.Position) * CFrame.Angles(0, -heading, 0) * CFrame.new(-P.WheelRim.Position)
for _, p in P do
	p.CFrame = T * p.CFrame
end
local mirrored = P.PostL.Position.X > P.PostR.Position.X -- the left post must end up at -X (it would only flip if the importer mirrored)

local root = Instance.new("Model")
root.Name = "SpinWheel"
local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
local base, posts, frame, wheel, props = model("Base", root), model("Posts", root), model("Frame", root), model("Wheel", root), model("Props", root)

local function style(p: MeshPart, name: string)
	local l = LOOK[name]
	p.Color, p.Material = l[1], l[2]
	p.MaterialVariant = if STUDDED[name] then "HOS_StudsMesh" else ""
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = l[3], l[3], false
	p.CastShadow = l[2] ~= Enum.Material.Neon and name ~= "Cracks"
	p.TextureID = ""
	for _, c in p:GetChildren() do
		if c:IsA("SurfaceAppearance") or c:IsA("Decal") then c:Destroy() end
	end
end
for name, p in P do
	style(p, name)
end

---------------------------------------------------------------- 2. copies round the wheel
local c = target.Position
local function about(theta: number, cf: CFrame): CFrame -- turn `cf` about the wheel's axis (world Z through c)
	return CFrame.new(c) * CFrame.Angles(0, 0, theta) * CFrame.new(-c) * cf
end
local sectors, dividers, gems = model("Sectors", wheel), model("Dividers", wheel), model("Gems", wheel)
for k = 1, 8 do
	local theta = -math.rad(45 * (k - 1)) -- clockwise as you face the wheel
	local s = P.Sector:Clone()
	s.Name = "Sector_" .. k
	s.CFrame = about(theta, P.Sector.CFrame)
	s.Color = SECTOR_COLORS[k]
	s:SetAttribute("Slot", k)
	s.Parent = sectors
	local d = P.Divider:Clone()
	d.Name = "Divider"
	d.CFrame = about(theta, P.Divider.CFrame)
	d.Parent = dividers
end
for k = 0, 11 do
	if k ~= 1 then -- the gem mesh sits at 60 degrees; k = 1 would be the top, under the crystal
		local g = P.Gem:Clone()
		g.Name = "Gem"
		g.CFrame = about(math.rad(30 * k), P.Gem.CFrame)
		g.Parent = gems
	end
end
P.Sector:Destroy()
P.Divider:Destroy()
P.Gem:Destroy()

---------------------------------------------------------------- 3. grouping
for _, n in { "BaseStone", "BaseBlocks", "StepGlow", "Cracks" } do P[n].Parent = base end
for _, n in { "BackFrame", "Axle", "Crystal" } do P[n].Parent = frame end
for _, n in { "WheelBacking", "WheelRim", "WheelRimInner", "Hub" } do P[n].Parent = wheel end
local postL, postR = model("Post_L", posts), model("Post_R", posts)
P.PostL.Parent, P.PostR.Parent = postL, postR
wheel.PrimaryPart = P.Hub
P.Hub:SetAttribute("SpinAxis", "Z (the wheel turns about the Hub's front-back axis)")
imported:Destroy()

---------------------------------------------------------------- 4. emblem, lanterns, props
local function at(x, y, z)
	return ORIGIN * CFrame.new(x, y, z)
end
local function prop(parent, src, height, x, z, onY, yaw, keepLight)
	local m = src:Clone()
	local _, sz = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * height / sz.Y)
	if keepLight then
		local pl, spl = m:FindFirstChildWhichIsA("PointLight", true), src:FindFirstChildWhichIsA("PointLight", true)
		if pl and spl then pl.Range = spl.Range end -- ScaleTo shrinks it with the model
	else
		for _, d in m:GetDescendants() do
			if d:IsA("Light") then d.Parent:Destroy() end
		end
	end
	local _, nsz = m:GetBoundingBox()
	m:PivotTo(at(x, onY + nsz.Y / 2, z) * CFrame.Angles(0, yaw, 0))
	m.Parent = parent
	return m
end
local jack = kit:FindFirstChild("A04_JackOLantern")
if jack then
	local e = jack:Clone()
	e.Name = "Emblem"
	local _, sz = e:GetBoundingBox()
	e:ScaleTo(2.45 / sz.Y) -- fills the hub ring, as in the concept
	for _, d in e:GetDescendants() do
		if d:IsA("Light") then d.Parent:Destroy() end
	end
	local _, esz = e:GetBoundingBox()
	e:PivotTo(CFrame.new(c + Vector3.new(0, 0, HUB_FRONT + esz.Z / 2 - 0.4)) * CFrame.Angles(0, math.pi, 0)) -- kit pumpkins face -Z
	e.Parent = wheel
end
local lanternSrc
for _, d in workspace:WaitForChild("Trees"):GetDescendants() do
	if d:IsA("Model") and d:FindFirstChild("A03_Chain") then
		lanternSrc = d
		break
	end
end
if lanternSrc then
	for _, side in { -1, 1 } do
		local lan = lanternSrc:Clone()
		lan.Name = "Lantern"
		local _, lsz0 = lan:GetBoundingBox()
		lan:ScaleTo(lan:GetScale() * LANTERN_H / lsz0.Y)
		local _, lsz = lan:GetBoundingBox()
		local pv = lan:GetPivot()
		lan:PivotTo(CFrame.new(pv.Position) * CFrame.Angles(0, if side < 0 then 0 else math.pi, 0) * pv.Rotation)
		local hook = at(side * HOOK_LOCAL.X, HOOK_LOCAL.Y, HOOK_LOCAL.Z).Position
		local bc = lan:GetBoundingBox()
		lan:PivotTo(lan:GetPivot() + (hook - Vector3.new(0, 0.05 + lsz.Y / 2, 0) - bc.Position))
		lan.Parent = if side < 0 then postL else postR
	end
end
local rng = Random.new(1007)
-- sizes and spots read off the concept: a big and a small pumpkin and two candles on the left, two candles and a pumpkin
-- on the right; the candles stand in front of the rim's gems so the wheel can turn
local function candle(name, size, height, x, z)
	local src = kit:FindFirstChild("A05_Candle_" .. size)
	if src then prop(props, src, height, x, z, LEDGE_TOP, rng:NextNumber(0, 2 * math.pi), false).Name = name end
end
if jack then
	-- kit pumpkins face -Z: a half turn faces them to the front, a little more turns them outward
	prop(props, jack, 2.9, -7.58, 0.9, LEDGE_TOP, math.pi - math.rad(15), true).Name = "Pumpkin_L"
	prop(props, jack, 1.86, -10.2, 1.6, LEDGE_TOP, math.pi - math.rad(30), false).Name = "PumpkinSmall_L"
	prop(props, jack, 2.4, 9.3, 0.9, LEDGE_TOP, math.pi + math.rad(15), true).Name = "Pumpkin_R"
end
candle("Candle_L1", "Large", 3.0, -5.4, 1.4)
candle("Candle_L2", "Small", 1.9, -6.2, 1.75)
candle("Candle_R1", "Large", 3.6, 6.85, 1.4)
candle("Candle_R2", "Medium", 2.2, 7.45, 2.0)

---------------------------------------------------------------- 5. swap in
local backups = ServerStorage:FindFirstChild("_Backups") or Instance.new("Folder")
backups.Name = "_Backups"
backups.Parent = ServerStorage
local old = workspace:FindFirstChild("SpinWheel")
if old then
	local b = backups:FindFirstChild("HOS-LOBBY-007_2026-10-18_BlockSpinWheel")
	if b then
		old:Destroy() -- the block version is already backed up; this is a mesh rebuild
	else
		old.Name = "HOS-LOBBY-007_2026-10-18_BlockSpinWheel"
		old.Parent = backups
	end
end
root.WorldPivot = ORIGIN
root.Parent = workspace
pcall(CHS.SetWaypoint, CHS, "HOS-LOBBY-007: mesh spin wheel")

local n, lights = 0, 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then n += 1 end
	if d:IsA("PointLight") then lights += 1 end
end
local _, sz = root:GetBoundingBox()
return ("built Workspace.SpinWheel from meshes: %d parts, %d lights, size %s%s"):format(n, lights, tostring(sz), if mirrored then " -- WARNING: the import came in mirrored (left post on the right)" else "")
