--!nocheck
-- HOS-LOBBY-005 (18 Oct 2026, Matthew): a few jack-o'-lanterns scattered round the lobby's graveyard edge, among the trees
-- and the graves. Kept subtle: small and a bit varied, at the foot of each tree (a tiny one beside some) and beside a few
-- graves, faces turned roughly towards the plaza. The bigger ones keep the kit pumpkin's warm orange light (its full
-- range, whatever their size); the tiny ones have none. Rebuildable: clears Workspace.LobbyPumpkins and places them again (same spots every time).
-- Needs the kit pumpkin, ServerStorage.HalloweenLobbyKit.A04_JackOLantern (tools/build/HOS-LOBBY-005_jack_o_lantern.lua).
local ServerStorage = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local template = ServerStorage.HalloweenLobbyKit:FindFirstChild("A04_JackOLantern")
assert(template and template:FindFirstChild("A04_Light_OPTIONAL"), "no kit pumpkin: run HOS-LOBBY-005_jack_o_lantern.lua first")
local trees = workspace:WaitForChild("Trees")
local graves = workspace:WaitForChild("Graves_Fences")
local ground = workspace:WaitForChild("Ground")
local CENTRE = Vector3.new(0, 10, 1500)

local old = workspace:FindFirstChild("LobbyPumpkins")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "LobbyPumpkins"
folder.Parent = workspace

local rng = Random.new(1005)
local down = RaycastParams.new()
down.FilterType = Enum.RaycastFilterType.Include
down.FilterDescendantsInstances = { ground }
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = { ground, trees } -- a tree's collision hull is far wider than its trunk

-- the foot of a model: the middle of its parts that reach down to the ground (a tree's trunk)
local function footOf(model: Model): Vector3
	local _, sz = model:GetBoundingBox()
	local cf = model:GetBoundingBox()
	local bottom = cf.Position.Y - sz.Y / 2
	local sum, n = Vector3.zero, 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Position.Y - p.Size.Y / 2 < bottom + 1 then
			sum += p.Position
			n += 1
		end
	end
	return if n > 0 then sum / n else cf.Position
end

-- a pumpkin at (x, z) on the ground, `height` tall, face towards the plaza give or take; nudged sideways off anything solid
local function place(at: Vector3, height: number, lit: boolean, name: string)
	local inward = (CENTRE - at) * Vector3.new(1, 0, 1)
	inward = inward.Unit
	local side = Vector3.yAxis:Cross(inward)
	local j = template:Clone()
	j.Name = name
	local _, tsz = template:GetBoundingBox()
	j:ScaleTo(height / tsz.Y)
	local _, sz = j:GetBoundingBox()
	if lit then
		j.A04_Light_OPTIONAL.PointLight.Range = template.A04_Light_OPTIONAL.PointLight.Range -- ScaleTo shrinks it with the model
	else
		j.A04_Light_OPTIONAL:Destroy()
	end
	local f = (inward + side * rng:NextNumber(-0.7, 0.7)).Unit
	local yaw = math.atan2(-f.X, -f.Z) -- turns the kit's -Z face onto f
	for try = 0, 6 do
		local p = at + side * (if try % 2 == 1 then 1 else -1) * math.ceil(try / 2) * 0.8
		local hit = workspace:Raycast(Vector3.new(p.X, 60, p.Z), Vector3.new(0, -100, 0), down)
		if hit then
			local cf = CFrame.new(p.X, hit.Position.Y + sz.Y / 2, p.Z) * CFrame.Angles(0, yaw, 0)
			local blockers = workspace:GetPartBoundsInBox(cf, sz * Vector3.new(0.9, 0.8, 0.9), overlap)
			local clear = true
			for _, b in blockers do
				if b.CanCollide and b.Transparency < 1 then
					clear = false
					break
				end
			end
			if clear then
				j:PivotTo(cf)
				j.Parent = folder
				return true
			end
		end
	end
	j:Destroy()
	return false
end

local placed, skipped = 0, {}
local function put(at, h, lit, name)
	if place(at, h, lit, name) then placed += 1 else table.insert(skipped, name) end
end

-- at each tree's foot, on the plaza side, alternating left and right; a tiny one beside every other tree
for i, t in trees:GetChildren() do
	if t:IsA("Model") then
		local foot = footOf(t)
		local inward = ((CENTRE - foot) * Vector3.new(1, 0, 1)).Unit
		local side = Vector3.yAxis:Cross(inward) * (if i % 2 == 0 then 1 else -1)
		local at = foot + inward * 4 + side * rng:NextNumber(1.6, 2.6)
		put(at, rng:NextNumber(1.9, 2.3), true, "Pumpkin_" .. t.Name)
		if i % 2 == 1 then
			put(at + side * 1.9 + inward * 0.6, rng:NextNumber(1.1, 1.35), false, "PumpkinSmall_" .. t.Name)
		end
	end
end

-- beside a few of the graves
for _, name in { "Grave_02", "Grave_05", "Grave_08", "Grave_12", "Grave_15" } do
	local g = graves:FindFirstChild(name)
	if g then
		local cf = g:GetBoundingBox()
		local inward = ((CENTRE - cf.Position) * Vector3.new(1, 0, 1)).Unit
		local side = Vector3.yAxis:Cross(inward) * (if rng:NextNumber() < 0.5 then 1 else -1)
		-- level with the grave, not in front of it (on the west side the graves are outside the fence)
		put(cf.Position + inward * 0.3 + side * 2, rng:NextNumber(1.5, 1.9), true, "Pumpkin_" .. name)
	end
end

pcall(CHS.SetWaypoint, CHS, "HOS-LOBBY-005: graveyard pumpkins")
return ("placed %d pumpkins in Workspace.LobbyPumpkins; skipped (no clear ground): %s"):format(placed, table.concat(skipped, ", "))
