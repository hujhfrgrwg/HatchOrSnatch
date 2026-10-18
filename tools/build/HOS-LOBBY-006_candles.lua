--!nocheck
-- HOS-LOBBY-006 (18 Oct 2026, Matthew): the low-poly candles. Run in Studio (edit, command bar or the MCP's execute_luau)
-- after File -> Import 3D of docs/HOS-LOBBY-006/Candles.glb.
--   1. finds the imported model (MeshParts CandleWaxLarge, CandleWaxMedium, CandleWaxSmall, CandleFlame, CandleWick; the
--      importer wraps each in a <Name>_Node model) and builds the three kit candles from it, named like the old ones:
--      A05_Candle_<Size> with parts A05_Candle_<Size>_Wax (peach-tinted cream), _Wick, _Flame (pale warm neon) and
--      _Light_OPTIONAL (a warm PointLight at the flame), each the old kit candle's height at scale factor 1, pivot at the
--      bounding-box centre (the altar rebuild, tools/build/HOS-LOBBY-002_pro_altar.lua, stands them by it)
--   2. puts them in ServerStorage.HalloweenLobbyKit (A05_Candle_Large/Medium/Small, and as A05_Cluster_Large/Medium/Small
--      in A05_CandleCluster)
--   3. swaps every block candle in the lobby (ProAltar corners, the incubator dais, FloorProps) for a copy: same name,
--      parent, height and ground
--   4. keeps one light per group of candles: the tallest candle's, and only where no other kept light is within LIGHT_GAP
-- The old candles and the old kit candles go to ServerStorage._Backups.HOS-LOBBY-006_2026-10-18_BlockCandles.
local ServerStorage = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local SIZES = { Large = 2.963, Medium = 2.262, Small = 1.377 } -- the old kit candles' heights, flame included
local WAX = Color3.fromRGB(247, 210, 160) -- cream with a hint of orange (Matthew: "so it's not full white")
local FLAME = Color3.fromRGB(255, 232, 170) -- a light, warm neon
local WICK = Color3.fromRGB(40, 30, 25)
local LIGHT_COLOR, LIGHT_RANGE, LIGHT_BRIGHTNESS = Color3.fromRGB(255, 170, 90), 7, 1.4
local LIGHT_GAP = 5 -- studs: candles closer than this to a lit one share its light

local kit = ServerStorage:WaitForChild("HalloweenLobbyKit")
local backups = ServerStorage:FindFirstChild("_Backups") or Instance.new("Folder")
backups.Name = "_Backups"
backups.Parent = ServerStorage
local backup = backups:FindFirstChild("HOS-LOBBY-006_2026-10-18_BlockCandles")
if not backup then
	backup = Instance.new("Folder")
	backup.Name = "HOS-LOBBY-006_2026-10-18_BlockCandles"
	backup.Parent = backups
end

---------------------------------------------------------------- 1. the imported meshes -> three kit candles
local imported
for _, d in workspace:GetDescendants() do
	if d:IsA("MeshPart") and d.Name == "CandleWaxLarge" then
		imported = d
		while imported.Parent ~= workspace do imported = imported.Parent end
		break
	end
end
assert(imported and imported:IsA("Model"), "no imported CandleWaxLarge in the workspace: import docs/HOS-LOBBY-006/Candles.glb first")
local src = {}
for _, d in imported:GetDescendants() do
	if d:IsA("MeshPart") then src[d.Name] = d end
end
for _, n in { "CandleWaxLarge", "CandleWaxMedium", "CandleWaxSmall", "CandleFlame", "CandleWick" } do
	assert(src[n], "the import has no " .. n)
end

local function style(p: BasePart, name: string, color: Color3, material: Enum.Material, solid: boolean)
	p.Name = name
	p.Color, p.Material = color, material
	p.Anchored, p.CanTouch = true, false
	p.CanCollide, p.CanQuery = solid, solid
	p.CastShadow = material ~= Enum.Material.Neon
	p.TextureID = ""
	for _, c in p:GetChildren() do
		if c:IsA("SurfaceAppearance") or c:IsA("Decal") then c:Destroy() end
	end
	if solid then pcall(function() p.CollisionFidelity = Enum.CollisionFidelity.Hull end) end
end

local templates = {}
for size, height in SIZES do
	local pre = "A05_Candle_" .. size
	local build = Instance.new("Model")
	local wax = src["CandleWax" .. size]:Clone()
	style(wax, pre .. "_Wax", WAX, Enum.Material.SmoothPlastic, true)
	wax.CFrame = CFrame.new(0, wax.Size.Y / 2, 0) * wax.CFrame.Rotation
	wax.Parent = build
	local top = wax.Size.Y - 0.11 -- the melted pool, a little below the lip
	local wick = src.CandleWick:Clone()
	style(wick, pre .. "_Wick", WICK, Enum.Material.SmoothPlastic, false)
	wick.CFrame = CFrame.new(0, top + wick.Size.Y / 2, 0)
	wick.Parent = build
	local flame = src.CandleFlame:Clone()
	style(flame, pre .. "_Flame", FLAME, Enum.Material.Neon, false)
	flame.CFrame = CFrame.new(0, top + wick.Size.Y - 0.03 + flame.Size.Y / 2, 0)
	flame.Parent = build
	local lp = Instance.new("Part")
	lp.Name = pre .. "_Light_OPTIONAL"
	lp.Size = Vector3.new(0.2, 0.2, 0.2)
	lp.Transparency = 1
	lp.Anchored, lp.CanCollide, lp.CanQuery, lp.CanTouch, lp.CastShadow = true, false, false, false, false
	lp.CFrame = CFrame.new(flame.Position)
	lp.Parent = build
	local pl = Instance.new("PointLight")
	pl.Color, pl.Range, pl.Brightness, pl.Shadows = LIGHT_COLOR, LIGHT_RANGE, LIGHT_BRIGHTNESS, false
	pl.Parent = lp
	local _, sz = build:GetBoundingBox()
	build.WorldPivot = CFrame.new()
	build:ScaleTo(height / sz.Y)
	pl.Range = LIGHT_RANGE
	-- a fresh model holds the scaled parts at scale factor 1
	local t = Instance.new("Model")
	t.Name = pre
	for _, c in build:GetChildren() do c.Parent = t end
	build:Destroy()
	t.WorldPivot = CFrame.new(t:GetBoundingBox().Position)
	t:SetAttribute("HOS", "HOS-LOBBY-006 low-poly candle")
	templates[size] = t
end
imported:Destroy()

---------------------------------------------------------------- 2. into the kit
for size, t in templates do
	local old = kit:FindFirstChild(t.Name)
	if old then
		old.Name = "Kit_" .. old.Name
		old.Parent = backup
	end
	t.Parent = kit
	local cluster = kit:FindFirstChild("A05_CandleCluster")
	local oldC = cluster and cluster:FindFirstChild("A05_Cluster_" .. size)
	if oldC then
		local new = t:Clone()
		new.Name = oldC.Name
		local ocf, osz = oldC:GetBoundingBox()
		local _, nsz = new:GetBoundingBox()
		new:PivotTo(CFrame.new(ocf.Position.X, ocf.Position.Y - osz.Y / 2 + nsz.Y / 2, ocf.Position.Z))
		new.Parent = cluster
		oldC.Name = "KitCluster_" .. oldC.Name
		oldC.Parent = backup
	end
end

---------------------------------------------------------------- 3. the lobby's block candles
local skip = workspace:FindFirstChild("_MapPreview")
local targets = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("Model") and not (skip and d:IsDescendantOf(skip)) then
		local size = d.Name:match("^A05_Candle_(%a+)$") or d.Name:match("^A05_Cluster_(%a+)$")
		if size and templates[size] and d:FindFirstChild("A05_Candle_" .. size .. "_Wax") and d:FindFirstChild("A05_Candle_" .. size .. "_Wax"):IsA("Model") then
			table.insert(targets, { d, size })
		end
	end
end
local swapped = {}
for _, tgt in targets do
	local old, size = tgt[1], tgt[2]
	local ocf, osz = old:GetBoundingBox()
	local new = templates[size]:Clone()
	new.Name = old.Name
	local _, tsz = new:GetBoundingBox()
	new:ScaleTo(osz.Y / tsz.Y)
	new:FindFirstChildWhichIsA("PointLight", true).Range = LIGHT_RANGE
	local _, nsz = new:GetBoundingBox()
	local _, yaw = ocf:ToOrientation()
	new:PivotTo(CFrame.new(ocf.Position.X, ocf.Position.Y - osz.Y / 2 + nsz.Y / 2, ocf.Position.Z) * CFrame.Angles(0, yaw, 0))
	new.Parent = old.Parent
	old:SetAttribute("HOS_WasAt", old:GetFullName())
	old.Parent = backup
	table.insert(swapped, new)
end

---------------------------------------------------------------- 4. one light per group
table.sort(swapped, function(a, b)
	local _, sa = a:GetBoundingBox()
	local _, sb = b:GetBoundingBox()
	return sa.Y > sb.Y
end)
local lit = {}
for _, c in swapped do
	local lp = c:FindFirstChildWhichIsA("PointLight", true).Parent
	local near = false
	for _, p in lit do
		if (p - lp.Position).Magnitude < LIGHT_GAP then
			near = true
			break
		end
	end
	if near then lp:Destroy() else table.insert(lit, lp.Position) end
end

pcall(CHS.SetWaypoint, CHS, "HOS-LOBBY-006: low-poly candles")
return ("swapped %d candles, %d lights"):format(#swapped, #lit)
