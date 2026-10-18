--!nocheck
-- HOS-LOBBY-005 (18 Oct 2026, Matthew): the low-poly jack-o'-lantern. Run in Studio (edit, command bar or the MCP's
-- execute_luau) after File -> Import 3D of docs/HOS-LOBBY-005/JackOLantern.glb.
--   1. finds the imported model (MeshParts JackBody, JackRim, JackGlow, JackStem; the importer wraps each in a <Name>_Node
--      model) and turns it into the kit pumpkin: colours and materials, a warm PointLight, face along -Z, pivot at the
--      bounding-box centre, the old kit pumpkin's height (2.88) at scale factor 1
--   2. puts it in ServerStorage.HalloweenLobbyKit as A04_JackOLantern (the altar rebuild, tools/build/HOS-LOBBY-002_pro_altar.lua,
--      clones it from there; the incubator dais, tools/build/HOS-INC-001_pedestal.lua, clones the altar's)
--   3. swaps every block jack-o'-lantern in the lobby (ProAltar Side_1..4 corners, the incubator dais, FloorProps.Prop_Pumpkin)
--      for a copy: same name, parent, height, ground and the way its face looked
-- The old ones, and the old kit pumpkin, go to ServerStorage._Backups.HOS-LOBBY-005_2026-10-18_BlockJackOLanterns.
local ServerStorage = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local KIT_HEIGHT = 2.877 -- the old kit pumpkin's height, stem included
local LOOK = {
	JackBody = { Color3.fromRGB(255, 112, 24), Enum.Material.SmoothPlastic },
	JackRim = { Color3.fromRGB(96, 34, 8), Enum.Material.SmoothPlastic },
	JackGlow = { Color3.fromRGB(255, 210, 58), Enum.Material.Neon },
	JackStem = { Color3.fromRGB(92, 98, 44), Enum.Material.SmoothPlastic },
}

local kit = ServerStorage:WaitForChild("HalloweenLobbyKit")
local backups = ServerStorage:FindFirstChild("_Backups") or Instance.new("Folder")
backups.Name = "_Backups"
backups.Parent = ServerStorage
local backup = backups:FindFirstChild("HOS-LOBBY-005_2026-10-18_BlockJackOLanterns")
if not backup then
	backup = Instance.new("Folder")
	backup.Name = "HOS-LOBBY-005_2026-10-18_BlockJackOLanterns"
	backup.Parent = backups
end

-- the way a model's glowing side faces, flat (nil when it has no glow)
local function faceOf(model: Model): Vector3?
	local cf = model:GetBoundingBox()
	local sum, n = Vector3.zero, 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
			sum += p.Position
			n += 1
		end
	end
	if n == 0 then return nil end
	local d = (sum / n - cf.Position) * Vector3.new(1, 0, 1)
	return if d.Magnitude > 0.05 then d.Unit else nil
end

---------------------------------------------------------------- 1. the imported mesh -> the kit pumpkin
local function findImport(): Model?
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == "JackBody" then
			local top = d
			while top.Parent ~= workspace do top = top.Parent end
			if top:IsA("Model") then return top end
		end
	end
	return nil
end

local imported = findImport()
assert(imported, "no imported JackBody in the workspace: import docs/HOS-LOBBY-005/JackOLantern.glb first")
local parts = {}
for _, d in imported:GetDescendants() do
	if d:IsA("MeshPart") and LOOK[d.Name] then parts[d.Name] = d end
end
for name in LOOK do assert(parts[name], "the import has no " .. name) end

local build = Instance.new("Model")
build.Name = "A04_JackOLantern"
for name, p in parts do
	p.Parent = build
	p.Color, p.Material = LOOK[name][1], LOOK[name][2]
	p.Anchored = true
	p.CanCollide, p.CanTouch = name == "JackBody", false
	p.CanQuery = name == "JackBody"
	p.CastShadow = name == "JackBody" or name == "JackStem"
	p.TextureID = ""
	for _, c in p:GetChildren() do
		if c:IsA("SurfaceAppearance") or c:IsA("Decal") then c:Destroy() end
	end
	pcall(function() p.CollisionFidelity = Enum.CollisionFidelity.Hull end)
end
imported:Destroy()
build.PrimaryPart = parts.JackBody

-- face along -Z, centred on the origin
local face = assert(faceOf(build), "no glow to read the face from")
local turn = math.atan2(face.X, face.Z) - math.atan2(0, -1)
local body = parts.JackBody
local c0 = build:GetBoundingBox().Position
for _, p in parts do
	p.CFrame = CFrame.Angles(0, -turn, 0) * (p.CFrame - c0)
end
local cf, size = build:GetBoundingBox()
for _, p in parts do p.CFrame -= cf.Position end
build.WorldPivot = CFrame.new()
build:ScaleTo(KIT_HEIGHT / size.Y)

-- warm light inside, like the old one
local light = Instance.new("Part")
light.Name = "A04_Light_OPTIONAL"
light.Size = Vector3.new(0.2, 0.2, 0.2)
light.Transparency = 1
light.Anchored, light.CanCollide, light.CanQuery, light.CanTouch, light.CastShadow = true, false, false, false, false
light.CFrame = CFrame.new(body.Position)
light.Parent = build
local pl = Instance.new("PointLight")
pl.Color, pl.Range, pl.Brightness, pl.Shadows = Color3.new(1, 0.604, 0.165), 8, 0.25, false
pl.Parent = light

-- a fresh model holds the scaled parts at scale factor 1, so kitClone(..., 0.85) means 85% of the kit size
local template = Instance.new("Model")
template.Name = "A04_JackOLantern"
for _, c in build:GetChildren() do c.Parent = template end
template.PrimaryPart = body
template.WorldPivot = CFrame.new(template:GetBoundingBox().Position)
template:SetAttribute("HOS", "HOS-LOBBY-005 low-poly jack-o'-lantern; face along -Z")
build:Destroy()

---------------------------------------------------------------- 2. into the kit
local oldKit = kit:FindFirstChild("A04_JackOLantern")
if oldKit then
	oldKit.Name = "Kit_A04_JackOLantern"
	oldKit.Parent = backup
end
template.Parent = kit

---------------------------------------------------------------- 3. the lobby's block pumpkins
local targets = {}
local altar = workspace:FindFirstChild("CentralAltar") and workspace.CentralAltar:FindFirstChild("ProAltar")
if altar then
	for i = 1, 4 do
		local side = altar:FindFirstChild("Side_" .. i)
		local j = side and side:FindFirstChild("Corner") and side.Corner:FindFirstChild("JackOLantern")
		if j then table.insert(targets, j) end
	end
end
local inc = workspace:FindFirstChild("Incubator") and workspace.Incubator:FindFirstChild("Incubator")
local dais = inc and inc:FindFirstChild("A09_Dais")
if dais then
	for _, j in dais:GetChildren() do
		if j.Name == "JackOLantern" then table.insert(targets, j) end
	end
end
local prop = workspace:FindFirstChild("FloorProps") and workspace.FloorProps:FindFirstChild("Prop_Pumpkin")
if prop then table.insert(targets, prop) end

local _, tSize = template:GetBoundingBox()
local swapped = {}
for _, old in targets do
	if old:FindFirstChild("A04_Shell") then -- still a block one
		local ocf, osz = old:GetBoundingBox()
		local f = faceOf(old) or Vector3.new(0, 0, -1)
		local new = template:Clone()
		new.Name = old.Name
		new:ScaleTo(osz.Y / tSize.Y)
		local _, nsz = new:GetBoundingBox()
		local theta = math.atan2(-f.X, -f.Z) -- turns -Z onto f
		new:PivotTo(CFrame.new(ocf.Position.X, ocf.Position.Y - osz.Y / 2 + nsz.Y / 2, ocf.Position.Z) * CFrame.Angles(0, theta, 0))
		new.Parent = old.Parent
		old:SetAttribute("HOS_WasAt", old:GetFullName())
		old.Parent = backup
		table.insert(swapped, new:GetFullName())
	end
end

pcall(CHS.SetWaypoint, CHS, "HOS-LOBBY-005: low-poly jack-o'-lanterns")
return ("kit pumpkin %s; swapped %d: %s"):format(tostring(tSize), #swapped, table.concat(swapped, ", "))
