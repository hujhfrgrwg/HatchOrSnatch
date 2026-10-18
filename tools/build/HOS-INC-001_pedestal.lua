--!nocheck
-- HOS-INC-001 (18 Oct 2026, Matthew: "not as blocky, have some curve to the podium, not bricks"): the incubator's
-- stand as smooth stacked domes instead of stepped tiers and blocks. Builds Workspace.Incubator.Incubator.A09_Pedestal.
-- The first run moves the old A09_PedestalTiers and A09_PedestalCrenels to
-- ServerStorage._Backups.HOS-INC-001_2026-10-18_IncubatorPedestal (and drops the earlier A09_PedestalTrim);
-- re-running just rebuilds A09_Pedestal. The glowing disc (A09_CoreEmitter) stays where it is, on top.
--   base dome   a wide, low dome (an ellipsoid half sunk into the platform), a glowing ring at its foot
--   mid dome    a smaller dome on top of it, with a gold band where it rises out of the base
--   plinth      a short round plinth the glowing disc sits on: gold rim, gold collar and a neon ring round the disc
local STONE = Color3.fromRGB(74, 63, 99) -- the tiers' colour (4a3f63)
local GOLD = Color3.fromRGB(222, 170, 64)
local GOLD_MAT = Enum.Material.Foil
local NEON = Color3.fromRGB(180, 92, 255) -- the incubator's neon (b45cff)

local CHS = game:GetService("ChangeHistoryService")
local m = workspace.Incubator.Incubator
pcall(CHS.SetWaypoint, CHS, "HOS-INC-001: before curved pedestal")

-- the old stand: keep it once in the backups
local bkRoot = game.ServerStorage:FindFirstChild("_Backups") or Instance.new("Folder")
bkRoot.Name = "_Backups"
bkRoot.Parent = game.ServerStorage
local bk = bkRoot:FindFirstChild("HOS-INC-001_2026-10-18_IncubatorPedestal")
if not bk then
	bk = Instance.new("Folder")
	bk.Name = "HOS-INC-001_2026-10-18_IncubatorPedestal"
	bk.Parent = bkRoot
end
for _, nm in { "A09_PedestalTiers", "A09_PedestalCrenels" } do
	local x = m:FindFirstChild(nm)
	if x then x.Parent = bk end
end
for _, nm in { "A09_PedestalTrim", "A09_Pedestal" } do
	local x = m:FindFirstChild(nm)
	if x then x:Destroy() end
end

local tiers = bk.A09_PedestalTiers
local bottomTier = tiers:GetChildren()[1]
for _, p in tiers:GetChildren() do
	if p.Size.Y > bottomTier.Size.Y then bottomTier = p end
end
local up = bottomTier.CFrame.Rotation -- a cylinder standing up (its axis is X)
local C = bottomTier.Position
local FLOOR = bottomTier.Position.Y - bottomTier.Size.X / 2 -- the platform's top
local emitter = m.A09_CoreEmitter:GetBoundingBox()
local DISC_BOTTOM = emitter.Position.Y - 0.14 -- the glowing disc's underside

local model = Instance.new("Model")
model.Name = "A09_Pedestal"

local function part(name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = material ~= Enum.Material.Neon
	p.CanQuery, p.CanTouch = true, false
	p.CastShadow = material ~= Enum.Material.Neon
	if shape then p.Shape = shape end
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, material
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end
local function disc(name, r, yMid, h, color, material)
	return part(name, Vector3.new(h, r * 2, r * 2), CFrame.new(C.X, yMid, C.Z) * up, color, material, Enum.PartType.Cylinder)
end
-- an ellipsoid (radius r across, half-height hy), centred at height y
local function dome(name, r, y, hy, color, material)
	local p = part(name, Vector3.new(r * 2, hy * 2, r * 2), CFrame.new(C.X, y, C.Z), color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
-- the radius of a dome (centre y0, radius r, half-height hy) at height y
local function radiusAt(r, y0, hy, y)
	local t = (y - y0) / hy
	return if math.abs(t) < 1 then r * math.sqrt(1 - t * t) else 0
end

-- base dome: radius 4.6 (clear of the leaned sign's back edge), rising 1.0 above the platform
local BASE_R, BASE_H = 4.6, 1.0
dome("BaseDome", BASE_R, FLOOR, BASE_H, STONE, Enum.Material.SmoothPlastic)
disc("FootGlow", BASE_R + 0.06, FLOOR + 0.05, 0.1, NEON, Enum.Material.Neon)

-- mid dome: 3.4 across, centred so it rises out of the base and its top meets the plinth
local PLINTH_R, PLINTH_H = 2.3, 0.35
local plinthBottom = DISC_BOTTOM - PLINTH_H
local MID_R, MID_H = 3.4, 0.9
local midY = plinthBottom + 0.15 - MID_H -- its top just under the plinth's bottom
dome("MidDome", MID_R, midY, MID_H, STONE, Enum.Material.SmoothPlastic)
-- gold band where the mid dome rises out of the base: at the height where the two surfaces cross
local bandY = midY
for y = FLOOR, FLOOR + BASE_H, 0.01 do
	if radiusAt(MID_R, midY, MID_H, y) > radiusAt(BASE_R, FLOOR, BASE_H, y) then
		bandY = y
		break
	end
end
disc("GoldBand", radiusAt(MID_R, midY, MID_H, bandY) + 0.04, bandY + 0.03, 0.08, GOLD, GOLD_MAT)

-- plinth: the glowing disc's seat
disc("Plinth", PLINTH_R, plinthBottom + PLINTH_H / 2, PLINTH_H, STONE, Enum.Material.SmoothPlastic)
disc("PlinthRim", PLINTH_R + 0.05, DISC_BOTTOM - 0.06, 0.1, GOLD, GOLD_MAT)
disc("TopRingNeon", 2.0, DISC_BOTTOM + 0.012, 0.024, NEON, Enum.Material.Neon)
disc("TopRingInner", 1.85, DISC_BOTTOM + 0.02, 0.04, STONE, Enum.Material.SmoothPlastic)
disc("EmitterCollar", 1.56, DISC_BOTTOM + 0.06, 0.12, GOLD, GOLD_MAT)

model.Parent = m
pcall(CHS.SetWaypoint, CHS, "HOS-INC-001: curved pedestal")
return ("curved pedestal: floor %.2f, disc at %.2f, mid dome centre %.2f, gold band at %.2f"):format(FLOOR, DISC_BOTTOM, midY, bandY)
