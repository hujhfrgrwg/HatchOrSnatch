--!nocheck
-- HOS-INC-001 (18 Oct 2026, Matthew: "make the bottom like this", the incubator concept art): the incubator's base as
-- the concept's stepped dais. Builds Workspace.Incubator.Incubator.A09_Dais:
--   steps     three octagonal stone steps (each a square block plus the same block turned 45 degrees), studded like
--             the rest of the incubator, darker at the bottom
--   crown     eight chunky capped stone blocks ringing the top step, one against each face
--   glow      a soft purple light column rising off the glowing disc (A09_CoreEmitter, left as is)
--   props     candle clusters either side of the sign and jack-o'-lanterns on the front corners, cloned from the lobby
--             altar's own props (Workspace.CentralAltar.ProAltar ... Corner)
-- The first run moves the old A09_PedestalTiers and A09_PedestalCrenels to
-- ServerStorage._Backups.HOS-INC-001_2026-10-18_IncubatorPedestal; re-running just rebuilds A09_Dais.
local STEPS = { -- inscribed radius, height, colour (bottom up); the top step's top is where the glowing disc sits
	{ a = 5.0, h = 0.65, color = Color3.fromRGB(59, 52, 82) },
	{ a = 3.95, h = 0.65, color = Color3.fromRGB(68, 60, 94) },
	{ a = 2.75, h = 0.7, color = Color3.fromRGB(74, 63, 99) },
}
local CROWN = { size = Vector3.new(1.15, 0.85, 1.05), cap = Vector3.new(0.9, 0.14, 0.82), color = Color3.fromRGB(64, 57, 88), capColor = Color3.fromRGB(93, 83, 121) }
local NEON = Color3.fromRGB(180, 92, 255) -- the incubator's neon (b45cff)

local CHS = game:GetService("ChangeHistoryService")
local m = workspace.Incubator.Incubator
pcall(CHS.SetWaypoint, CHS, "HOS-INC-001: before dais")

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
for _, nm in { "A09_PedestalTrim", "A09_Pedestal", "A09_Dais" } do
	local x = m:FindFirstChild(nm)
	if x then x:Destroy() end
end

local platform = m.A09_PlatformBase
local R = platform.CFrame.Rotation -- the incubator's facing (its front is the sign's side)
local C = Vector3.new(platform.Position.X, 0, platform.Position.Z)
local FLOOR = platform.Position.Y + platform.Size.Y / 2
local front = (m.A09_Sign:GetPivot().Position - platform.Position) * Vector3.new(1, 0, 1)
front = front.Unit
local side = Vector3.yAxis:Cross(front) -- along the sign

local dais = Instance.new("Model")
dais.Name = "A09_Dais"

local function studs(p)
	for _, f in { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" } do
		p[f] = Enum.SurfaceType.Studs
	end
end
local function block(name, size, cf, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Material = Enum.Material.Plastic
	studs(p)
	p.Parent = parent or dais
	return p
end

-- steps: an octagon is a square plus the square turned 45 degrees (that one a hair shorter, so the tops never fight)
local y = FLOOR
for i, s in STEPS do
	local mid = y + s.h / 2
	block("Step" .. i, Vector3.new(s.a * 2, s.h, s.a * 2), CFrame.new(C.X, mid, C.Z) * R, s.color)
	block("Step" .. i .. "Turned", Vector3.new(s.a * 2, s.h - 0.02, s.a * 2), CFrame.new(C.X, mid, C.Z) * R * CFrame.Angles(0, math.rad(45), 0), s.color)
	y += s.h
end
local TOP = y

-- crown: a chunky capped block against each face of the top step, on the middle step
local top, midStep = STEPS[#STEPS], STEPS[#STEPS - 1]
local crownR = (top.a + midStep.a) / 2 + 0.05
local crownBottom = TOP - top.h
for k = 0, 7 do
	local rot = R * CFrame.Angles(0, math.rad(45 * k), 0)
	local pos = Vector3.new(C.X, crownBottom + CROWN.size.Y / 2, C.Z) + rot.LookVector * crownR
	local cf = CFrame.new(pos) * rot
	block("Crown" .. k, CROWN.size, cf, CROWN.color)
	block("CrownCap" .. k, CROWN.cap, cf * CFrame.new(0, CROWN.size.Y / 2 + CROWN.cap.Y / 2 - 0.01, 0), CROWN.capColor)
end

-- glow: a soft light column off the disc
local glow = Instance.new("Part")
glow.Name = "GlowColumn"
glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch, glow.CastShadow = true, false, false, false, false
glow.Shape = Enum.PartType.Cylinder
glow.Material, glow.Color, glow.Transparency = Enum.Material.Neon, NEON, 0.75
glow.Size = Vector3.new(0.5, 2.5, 2.5)
glow.CFrame = CFrame.new(C.X, TOP + 0.3 + 0.25, C.Z) * CFrame.Angles(0, 0, math.rad(90))
glow.Parent = dais

-- props from the lobby altar: candles either side of the sign, jack-o'-lanterns on the front corners
local corner = workspace:FindFirstChild("CentralAltar") and workspace.CentralAltar:FindFirstChild("ProAltar")
corner = corner and corner:FindFirstChild("Side_1") and corner.Side_1:FindFirstChild("Corner")
-- the way a model's glowing side faces (a jack-o'-lantern's carved face), flat
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
-- clone a prop, turn it about Y so its face points along `facing` (when it has one), and stand it on the platform
local function placeOnFloor(model: Model, at: Vector3, facing: Vector3)
	local c = model:Clone()
	c.Parent = dais
	local face = faceOf(c)
	if face then
		local turn = math.atan2(face.X, face.Z) - math.atan2(facing.X, facing.Z)
		local pivot = c:GetPivot()
		c:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, -turn, 0) * pivot.Rotation)
	end
	local cf, sz = c:GetBoundingBox()
	c:PivotTo(c:GetPivot() + (Vector3.new(at.X, FLOOR + sz.Y / 2, at.Z) - cf.Position))
	return c
end
local placed = 0
if corner then
	local candles = corner:FindFirstChild("Candles")
	local jack = corner:FindFirstChild("JackOLantern")
	local signDepth = 1.6
	for _, s in { 1, -1 } do
		-- candle cluster just past the sign's end
		local base = C + front * (STEPS[1].a + signDepth * 0.5) + side * s * 4.3
		if candles then
			local spots = { { "A05_Candle_Large", Vector3.zero }, { "A05_Candle_Medium", side * s * 0.75 + front * 0.35 }, { "A05_Candle_Small", front * 0.85 - side * s * 0.1 } }
			for _, sp in spots do
				local src = candles:FindFirstChild(sp[1])
				if src then
					placeOnFloor(src, base + sp[2], front)
					placed += 1
				end
			end
		end
		-- jack-o'-lantern beside the bottom step (clear of the loose corner stones and the pillars), turned a little outward
		if jack then
			local at = C + front * 3.3 + side * s * 6.1
			placeOnFloor(jack, at, (front + side * s * 0.45).Unit)
			placed += 1
		end
	end
end

dais.Parent = m
pcall(CHS.SetWaypoint, CHS, "HOS-INC-001: dais")
return ("dais: top at %.2f (disc at %.2f), %d props placed"):format(TOP, m.A09_CoreEmitter:GetBoundingBox().Position.Y - 0.14, placed)
