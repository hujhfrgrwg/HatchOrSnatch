--!strict
-- Growth: one readable prop per upgrade level, placed automatically on any building model, with a pop-in.
--
-- Why: when a model only changes at tier steps, most upgrades look like nothing happened. Here level L
-- shows items 1..L-1 of the role's list, so L+1 = L plus exactly one piece and nothing jumps around.
--
-- Placement: the model is sampled once on a GRID x GRID raster with downward raycasts (only against the
-- model). A cell is a seat when its hit is flat (normal.Y > 0.98). Items take the first free rectangle of
-- seats in level order, ground items low, roof items high; front corners first. Layouts are cached per
-- template name, so the second building of a kind costs almost nothing.
--
--   Growth.ROLES.Farm = { "crate", "silo", "crate" }
--   Growth.ITEMS.silo = { size = Vector3.new(1.2, 3, 1.2), place = "ground", build = function(size) ... end }
--   local props = Growth.dress(model, "Farm", level)      -- returns a Model parented to `model`
--   Growth.pop(props:FindFirstChild("L3"))                -- the upgrade moment for the new piece

local TweenService = game:GetService("TweenService")

local Growth = {}
Growth.GRID = 32
Growth.SCALES = { 1, 0.8, 0.65 } -- try smaller when nothing fits
Growth.SINK = 0.012 -- sink into the seat so nothing hovers (off the 0.01 grid on purpose)

export type Item = { size: Vector3, place: "ground" | "roof" | "any", build: (size: Vector3) -> Model }
Growth.ROLES = {} :: { [string]: { string } }
Growth.ITEMS = {} :: { [string]: Item }

-- a simple default recipe: a stud-style box (replace with real props)
local function box(size: Vector3): Model
	local m = Instance.new("Model")
	local p = Instance.new("Part")
	p.Size, p.Anchored, p.Material = size, true, Enum.Material.Plastic
	p.PivotOffset = CFrame.new(0, -size.Y / 2, 0) -- pivot on the ground: placement and pop use it
	p.Parent = m
	m.PrimaryPart = p
	return m
end
Growth.ITEMS.crate = { size = Vector3.new(1, 1, 1), place = "ground", build = box }

type Seat = { y: number, flat: boolean, used: boolean }
type Layout = { [number]: { cf: CFrame, sc: number }? } -- index = item number in the role list; CFrames relative to the model pivot
type Raster = { cell: number, origin: CFrame, seats: { { Seat } }, ground: number }

local layouts: { [string]: Layout } = {}

-- Builds models must have their pivot on the ground at the footprint centre, and recipes must put their
-- own pivot at the bottom centre, for the cached relative layouts to fit every copy.
local function raster(model: Model): Raster
	local cf, size = model:GetBoundingBox()
	local cell = math.max(size.X, size.Z) / Growth.GRID
	local origin = cf * CFrame.new(-size.X / 2, size.Y / 2 + 1, -size.Z / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local seats, ground = {}, math.huge
	for i = 1, Growth.GRID do
		seats[i] = {}
		for j = 1, Growth.GRID do
			local p = origin * Vector3.new((i - 0.5) * cell, 0, (j - 0.5) * cell)
			local hit = workspace:Raycast(p, Vector3.new(0, -(size.Y + 2), 0), params)
			local y = if hit then hit.Position.Y else -math.huge
			local flat = hit ~= nil and hit.Normal.Y > 0.98 and hit.Instance.Transparency < 0.98
			seats[i][j] = { y = y, flat = flat, used = false }
			if flat then ground = math.min(ground, y) end
		end
	end
	return { cell = cell, origin = origin, seats = seats, ground = ground }
end

-- first free flat rectangle of w x d cells at one height, scanning front rows first
local function findSpot(r: Raster, w: number, d: number, place: string): (number?, number?, number?)
	local G = Growth.GRID
	for j = G - d + 1, 1, -1 do -- +Z rows first: treat +Z as the model's front (adjust to your models)
		for _, i in { 1, G - w + 1, (G - w) // 2 + 1 } do -- corners, then centre
			local s0 = r.seats[i][j]
			local ok = s0.flat and not s0.used
			local low = s0.y - r.ground < 0.3
			if place == "ground" and not low then ok = false end
			if place == "roof" and low then ok = false end
			for a = i, i + w - 1 do
				for b = j, j + d - 1 do
					local s = r.seats[a] and r.seats[a][b]
					if not ok or not s or not s.flat or s.used or math.abs(s.y - s0.y) > 0.02 then
						ok = false
						break
					end
				end
				if not ok then break end
			end
			if ok then return i, j, s0.y end
		end
	end
	return nil, nil, nil
end

local function layoutFor(model: Model, role: string): Layout
	local k = model.Name .. "|" .. role
	if layouts[k] then return layouts[k] end
	local r = raster(model)
	local toLocal = model:GetPivot():Inverse()
	local out: Layout = {}
	for n, kind in Growth.ROLES[role] or {} do
		local item = Growth.ITEMS[kind]
		if item then
			for _, sc in Growth.SCALES do
				local w = math.max(1, math.ceil(item.size.X * sc / r.cell))
				local d = math.max(1, math.ceil(item.size.Z * sc / r.cell))
				local i, j, y = findSpot(r, w, d, item.place)
				if i and j and y then
					for a = i, i + w - 1 do for b = j, j + d - 1 do r.seats[a][b].used = true end end
					local local_ = r.origin * Vector3.new((i - 1 + w / 2) * r.cell, 0, (j - 1 + d / 2) * r.cell)
					local at = Vector3.new(local_.X, y - Growth.SINK, local_.Z)
					out[n] = { cf = toLocal * CFrame.new(at), sc = sc }
					break
				end
			end
		end
		-- no spot: leave nil. In a real game place a slim FALLBACK piece so every level adds something.
	end
	layouts[k] = out
	return out
end

-- Build props for levels 2..level. The layout is computed on the first model of a name (it must be in
-- Workspace for the raycasts) and reused for every copy.
function Growth.dress(model: Model, role: string, level: number): Model
	local old = model:FindFirstChild("GrowthProps")
	if old then old:Destroy() end
	local props = Instance.new("Model")
	props.Name = "GrowthProps"
	local layout = layoutFor(model, role)
	for n = 1, math.min(level - 1, #(Growth.ROLES[role] or {})) do
		local spot = layout[n]
		local item = Growth.ITEMS[Growth.ROLES[role][n]]
		if spot and item then
			local m = item.build(item.size * spot.sc)
			m.Name = "L" .. (n + 1)
			m:PivotTo(model:GetPivot() * spot.cf)
			m.Parent = props
		end
	end
	props.Parent = model
	return props
end

-- The upgrade moment: grow from 5% with a Back bounce about the piece's ground point.
function Growth.pop(piece: Instance?, delay: number?)
	if not piece or not piece:IsA("Model") then return end
	local m = piece :: Model
	local full = m:GetScale()
	local v = Instance.new("NumberValue")
	v.Value = 0.05
	m:ScaleTo(full * 0.05)
	v.Changed:Connect(function(k) m:ScaleTo(full * math.max(k, 0.01)) end)
	local tw = TweenService:Create(v, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out,
		0, false, delay or 0), { Value = 1 })
	tw.Completed:Once(function() m:ScaleTo(full); v:Destroy() end)
	tw:Play()
	-- add: a sparkle ParticleEmitter:Emit(12) at the piece, a "Level N!" float, a sound, a small shake
end

return Growth
