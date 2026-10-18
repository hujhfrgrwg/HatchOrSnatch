--!nocheck
-- HOS-LOBBY-006 (18 Oct 2026, Matthew): small groups of candles beside the lobby graves that have no pumpkin (the pumpkins
-- are HOS-LOBBY-005) and at least PUMPKIN_GAP from any pumpkin, two or three candles each, a bit smaller than the kit ones. Only the tallest candle in a group keeps
-- its light. Rebuildable: clears Workspace.LobbyCandles and places them again (same spots every time).
-- Needs the kit candles, ServerStorage.HalloweenLobbyKit.A05_Candle_Large/Medium/Small (tools/build/HOS-LOBBY-006_candles.lua).
local ServerStorage = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local kit = ServerStorage.HalloweenLobbyKit
for _, s in { "Large", "Medium", "Small" } do
	local t = kit:FindFirstChild("A05_Candle_" .. s)
	assert(t and t:FindFirstChildWhichIsA("MeshPart"), "no mesh kit candle: run HOS-LOBBY-006_candles.lua first")
end
local graves = workspace:WaitForChild("Graves_Fences")
local ground = workspace:WaitForChild("Ground")
local CENTRE = Vector3.new(0, 10, 1500)
local GRAVES = { "Grave_03", "Grave_06", "Grave_09", "Grave_13", "Grave_17" }
local GROUPS = { { "Large", "Small" }, { "Medium", "Small", "Small" }, { "Large", "Medium" } }
local PUMPKIN_GAP = 4

local pumpkins = {}
local pf = workspace:FindFirstChild("LobbyPumpkins")
for _, p in (pf and pf:GetChildren() or {}) do
	table.insert(pumpkins, p:GetPivot().Position)
end
local function nearPumpkin(at: Vector3): boolean
	for _, p in pumpkins do
		if Vector3.new(p.X - at.X, 0, p.Z - at.Z).Magnitude < PUMPKIN_GAP then return true end
	end
	return false
end

local old = workspace:FindFirstChild("LobbyCandles")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "LobbyCandles"
folder.Parent = workspace

local rng = Random.new(1006)
local down = RaycastParams.new()
down.FilterType = Enum.RaycastFilterType.Include
down.FilterDescendantsInstances = { ground }
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = { ground, workspace:FindFirstChild("Trees") } -- a tree's collision hull is far wider than its trunk

-- stand a candle at `at` (x, z) on the ground if there's room; nil when there isn't
local function stand(group: Model, size: string, at: Vector3, scale: number): Model?
	local c = kit["A05_Candle_" .. size]:Clone()
	c:ScaleTo(scale)
	local pl = c:FindFirstChildWhichIsA("PointLight", true)
	pl.Range = kit["A05_Candle_" .. size]:FindFirstChildWhichIsA("PointLight", true).Range -- ScaleTo shrinks it with the model
	local _, sz = c:GetBoundingBox()
	local hit = workspace:Raycast(Vector3.new(at.X, 60, at.Z), Vector3.new(0, -100, 0), down)
	if not hit then
		c:Destroy()
		return nil
	end
	local cf = CFrame.new(at.X, hit.Position.Y + sz.Y / 2, at.Z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	for _, b in workspace:GetPartBoundsInBox(cf, sz * Vector3.new(0.9, 0.8, 0.9), overlap) do
		if b.CanCollide and b.Transparency < 1 and not b:IsDescendantOf(group) then
			c:Destroy()
			return nil
		end
	end
	c:PivotTo(cf)
	c.Parent = group
	return c
end

local placed, groups = 0, 0
for gi, name in GRAVES do
	local g = graves:FindFirstChild(name)
	if g then
		local gcf = g:GetBoundingBox()
		local inward = ((CENTRE - gcf.Position) * Vector3.new(1, 0, 1)).Unit
		local side = Vector3.yAxis:Cross(inward) * (if gi % 2 == 0 then 1 else -1)
		local sizes = GROUPS[(gi - 1) % #GROUPS + 1]
		local group = Instance.new("Model")
		group.Name = "Candles_" .. name
		group.Parent = folder
		-- try a few spots either side of the grave until the whole group fits, clear of the pumpkins
		for try = 0, 9 do
			local s = side * (if try % 2 == 0 then 1 else -1)
			local base = gcf.Position + inward * 0.4 + s * (1.6 + math.floor(try / 2) * 0.7)
			local spots = { base, base + s * 0.7 + inward * 0.35, base - s * 0.15 + inward * 0.75 }
			local ok = not nearPumpkin(base)
			for k, sz in sizes do
				if not ok then break end
				if not stand(group, sz, spots[k], rng:NextNumber(0.7, 0.85)) then
					ok = false
					break
				end
			end
			if ok then break end
			group:ClearAllChildren()
		end
		if #group:GetChildren() == 0 then
			group:Destroy()
		else
			-- one light per group: the tallest candle's
			local tallest, th = nil, -1
			for _, c in group:GetChildren() do
				local _, sz = c:GetBoundingBox()
				if sz.Y > th then tallest, th = c, sz.Y end
			end
			for _, c in group:GetChildren() do
				if c ~= tallest then c:FindFirstChildWhichIsA("PointLight", true).Parent:Destroy() end
			end
			placed += #group:GetChildren()
			groups += 1
		end
	end
end

pcall(CHS.SetWaypoint, CHS, "HOS-LOBBY-006: graveyard candles")
return ("placed %d candles in %d groups in Workspace.LobbyCandles"):format(placed, groups)
