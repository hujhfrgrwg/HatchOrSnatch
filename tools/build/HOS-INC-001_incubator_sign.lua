--!nocheck
-- HOS-INC-001 (18 Oct 2026, Matthew): the incubator's INCUBATOR sign as a trapezoid, leaned back so it faces up.
-- Run in Studio edit mode (command bar / execute_luau). Re-runnable: the first run keeps the original sign parts in
-- ServerStorage._Backups.HOS-INC-001_2026-10-18_IncubatorSign, and every run rebuilds from those.
--   plaque   the 6.6 x 1.6 x 1.2 sign box, cut to a trapezoid (TOP_WIDTH across the top) with SubtractAsync, then
--            turned back LEAN degrees about its front-bottom edge; the text panel and the sparkles go with it
--   panel    narrowed to PANEL_WIDTH so it sits inside the trapezoid; the sparkles move in to match
--   icon     the egg-icon block that sat on the sign moves back to just behind the plaque's top edge and now stands
--            on the platform (same top, icon glow at the same height)
local LEAN = 40
local TOP_WIDTH = 5.0
local PANEL_WIDTH = 5.0

local CHS = game:GetService("ChangeHistoryService")
local m = workspace.Incubator.Incubator
pcall(CHS.SetWaypoint, CHS, "HOS-INC-001: before incubator sign")

-- originals: back them up once, then always start from them
local bkRoot = game.ServerStorage:FindFirstChild("_Backups") or Instance.new("Folder")
bkRoot.Name = "_Backups"
bkRoot.Parent = game.ServerStorage
local bk = bkRoot:FindFirstChild("HOS-INC-001_2026-10-18_IncubatorSign")
local NAMES = { "A09_Sign", "A09_SignPanel", "A09_SignGlow" }
if not bk then
	bk = Instance.new("Folder")
	bk.Name = "HOS-INC-001_2026-10-18_IncubatorSign"
	for _, nm in NAMES do m[nm]:Clone().Parent = bk end
	bk.Parent = bkRoot
else
	for _, nm in NAMES do
		local cur = m:FindFirstChild(nm)
		if cur then cur:Destroy() end
		bk[nm]:Clone().Parent = m
	end
end

local sign, panel, glow = m.A09_Sign, m.A09_SignPanel, m.A09_SignGlow
local board, icon
for _, p in sign:GetChildren() do
	if p:IsA("BasePart") then
		if p.Size.X > 5 then board = p else icon = p end
	end
end
assert(board and icon, "sign parts not found")
local B = board.CFrame -- board space: +Z is the front (the text side), X across, Y up
local W, H, D = board.Size.X, board.Size.Y, board.Size.Z

-- the trapezoid: cut the two top corners off along lines from the bottom corners to the narrower top
local inset = (W - TOP_WIDTH) / 2
local cutters = {}
for _, side in { 1, -1 } do
	local a = Vector2.new(side * W / 2, -H / 2) -- bottom corner
	local b = Vector2.new(side * TOP_WIDTH / 2, H / 2) -- top corner
	local along = (b - a).Unit
	local n = Vector2.new(along.Y, -along.X) * side -- outward
	if n.X * side < 0 then n = -n end
	local mid = (a + b) / 2 + n * 2
	local c = Instance.new("Part")
	c.Size = Vector3.new(4, 6, D + 2)
	c.CFrame = B * CFrame.new(mid.X, mid.Y, 0) * CFrame.Angles(0, 0, math.atan2(n.Y, n.X))
	c.Anchored = true
	c.Parent = workspace
	table.insert(cutters, c)
end
local plaque = board:SubtractAsync(cutters, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
for _, c in cutters do c:Destroy() end
plaque.Name = "A09_SignPlaque"
plaque.UsePartColor = true
plaque.Color, plaque.Material = board.Color, board.Material
plaque.Anchored = true
plaque.Parent = sign
board:Destroy()

-- the panel and sparkles: narrower to fit the trapezoid (panel width and sparkle spread scale together)
local k = PANEL_WIDTH / panel.Size.X
panel.Size = Vector3.new(PANEL_WIDTH, panel.Size.Y, panel.Size.Z)
local plaqueGlow, iconGlow = {}, {}
local iconBottom = (B:Inverse() * icon.CFrame).Y - icon.Size.Y / 2
for _, p in glow:GetDescendants() do
	if p:IsA("BasePart") then
		local l = B:Inverse() * p.CFrame
		if l.Y < iconBottom then
			p.CFrame = B * (CFrame.new(l.X * k, l.Y, l.Z) * l.Rotation)
			table.insert(plaqueGlow, p)
		else
			table.insert(iconGlow, p)
		end
	end
end

-- lean back about the front-bottom edge (the top goes back, the face turns up)
local pivot = CFrame.new(0, -H / 2, D / 2)
local T = B * pivot * CFrame.Angles(-math.rad(LEAN), 0, 0) * pivot:Inverse() * B:Inverse()
plaque.CFrame = T * plaque.CFrame
panel.CFrame = T * panel.CFrame
for _, p in plaqueGlow do p.CFrame = T * p.CFrame end

-- the icon block: back behind the plaque's top edge, standing on the platform
local topFrontZ = D / 2 - H * math.sin(math.rad(LEAN)) -- board space, after the lean
local li = B:Inverse() * icon.CFrame
local shiftZ = (topFrontZ - 0.02) - (li.Z + icon.Size.Z / 2)
local top = li.Y + icon.Size.Y / 2
local bottom = -H / 2
icon.Size = Vector3.new(icon.Size.X, top - bottom, icon.Size.Z)
icon.CFrame = B * CFrame.new(li.X, (top + bottom) / 2, li.Z + shiftZ) * li.Rotation
local shift = B:VectorToWorldSpace(Vector3.new(0, 0, shiftZ))
for _, p in iconGlow do p.CFrame = p.CFrame + shift end

pcall(CHS.SetWaypoint, CHS, "HOS-INC-001: incubator sign")
return ("sign: trapezoid %.1f -> %.1f wide, leaned %d deg; panel %.1f wide; %d sparkle parts, %d icon glow parts; icon moved %.2f back"):format(W, TOP_WIDTH, LEAN, PANEL_WIDTH, #plaqueGlow, #iconGlow, -shiftZ)
