--!nocheck
-- HOS-INC-001 (18 Oct 2026, Matthew: "make the stand a bit more premium"): trim for the incubator's stepped
-- pedestal, built into Workspace.Incubator.Incubator.A09_PedestalTrim. Nothing of the original model is changed, so
-- deleting that model undoes it; re-running rebuilds it.
--   gold lips      a thin gold band round the top edge of each tier
--   neon inlays    a glowing band round the middle of the two lower tiers
--   emitter        a gold collar round the glowing disc, and a neon ring inlaid in the top tier around it
--   caps           a gold cap on each of the 8 blocks round the middle tier
local GOLD = Color3.fromRGB(222, 170, 64)
local GOLD_MAT = Enum.Material.Foil
local NEON = Color3.fromRGB(180, 92, 255) -- the incubator's neon (b45cff)

local CHS = game:GetService("ChangeHistoryService")
local m = workspace.Incubator.Incubator
pcall(CHS.SetWaypoint, CHS, "HOS-INC-001: before pedestal trim")
local old = m:FindFirstChild("A09_PedestalTrim")
if old then old:Destroy() end
local trim = Instance.new("Model")
trim.Name = "A09_PedestalTrim"

local function part(name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = material ~= Enum.Material.Neon
	if shape then p.Shape = shape end
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, material
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = trim
	return p
end

-- the tiers, bottom up: { centre, radius, top, bottom }
local tiers = {}
for _, p in m.A09_PedestalTiers:GetChildren() do
	if p:IsA("BasePart") then
		table.insert(tiers, { p = p, r = p.Size.Y / 2, top = p.Position.Y + p.Size.X / 2, bottom = p.Position.Y - p.Size.X / 2 })
	end
end
table.sort(tiers, function(a, b) return a.bottom < b.bottom end)
local up = tiers[1].p.CFrame.Rotation -- a cylinder standing up (its axis is X)
local C = tiers[1].p.Position

local function disc(name, r, yMid, h, color, material)
	return part(name, Vector3.new(h, r * 2, r * 2), CFrame.new(C.X, yMid, C.Z) * up, color, material, Enum.PartType.Cylinder)
end

for i, t in tiers do
	-- gold lip: a band a hair wider than the tier, just under its top edge (a solid disc, so its top stays below the
	-- tier's or it would cover the whole step)
	disc("GoldLip" .. i, t.r + 0.06, t.top - 0.07, 0.12, GOLD, GOLD_MAT)
	-- neon inlay round the riser of the lower tiers
	if i < #tiers then
		disc("NeonInlay" .. i, t.r + 0.03, (t.top + t.bottom) / 2 - 0.04, 0.08, NEON, Enum.Material.Neon)
	end
end

-- the emitter: a gold collar under the glowing disc, and a neon ring inlaid in the top tier
local top = tiers[#tiers]
disc("EmitterCollar", 1.56, top.top + 0.06, 0.12, GOLD, GOLD_MAT)
disc("TopRingNeon", 2.3, top.top + 0.012, 0.024, NEON, Enum.Material.Neon)
disc("TopRingInner", 2.12, top.top + 0.02, 0.04, top.p.Color, top.p.Material)

-- gold caps on the blocks round the middle tier
for i, b in m.A09_PedestalCrenels:GetChildren() do
	if b:IsA("BasePart") then
		local s = b.Size
		part("GoldCap" .. i, Vector3.new(s.X + 0.1, 0.1, s.Z + 0.1), b.CFrame * CFrame.new(0, s.Y / 2 + 0.03, 0), GOLD, GOLD_MAT)
	end
end

trim.Parent = m
pcall(CHS.SetWaypoint, CHS, "HOS-INC-001: pedestal trim")
local n = 0
for _, d in trim:GetChildren() do n += 1 end
return ("pedestal trim: %d parts over %d tiers"):format(n, #tiers)
