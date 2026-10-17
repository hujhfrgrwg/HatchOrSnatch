--!nocheck
-- BuildLobbyUnderside (HOS-MAP-002, 17 Oct 2026, Matthew): the floating-island underside of the Halloween
-- lobby (workspace.Ground), in the Haunted Graveyard's cliff-column style. Hanging stone columns follow the
-- lobby disc's outline exactly and get longer toward the middle, so the sides slope in and meet under the
-- centre like an upside-down pyramid, with random depth per column for a rough edge.
-- Run from the command bar / execute_luau:  require(game.ServerStorage.EOSBuild.BuildLobbyUnderside)()
-- Idempotent: replaces workspace.Ground.Ground_Underside. Reads the outline from workspace.Ground.Ground_Outer.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Kit = require(script.Parent.WorldKit)

local CELL = 2 -- the lobby disc is built from 2-stud rows
local BAND = 3 -- cells per column band along Z (6 studs)
local SLOPE = 1.0 -- studs of depth per stud in from the rim (45 degrees)
local ROUGH = 2.5 -- +- random depth per column
local CLIFF = {
	Color3.fromRGB(92, 72, 128), -- the graveyard's cliff1 / cliff2 / cliff3
	Color3.fromRGB(74, 56, 110),
	Color3.fromRGB(58, 44, 92),
}

return function()
	pcall(ChangeHistoryService.SetWaypoint, ChangeHistoryService, "HOS-MAP-002: before lobby underside")
	local ground = workspace:FindFirstChild("Ground")
	assert(ground and ground:FindFirstChild("Ground_Outer"), "workspace.Ground.Ground_Outer not found")
	local rng = Random.new(4242)

	-- the disc's rows (axis-aligned slabs) and the level of its underside
	local rows = {}
	local yTop = math.huge
	local x0b, x1b, z0b, z1b = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ground.Ground_Outer:GetDescendants() do
		if p:IsA("BasePart") then
			local hx, hz = p.Size.X / 2, p.Size.Z / 2
			local r = { x0 = p.Position.X - hx, x1 = p.Position.X + hx, z0 = p.Position.Z - hz, z1 = p.Position.Z + hz }
			table.insert(rows, r)
			yTop = math.min(yTop, p.Position.Y - p.Size.Y / 2)
			x0b, x1b, z0b, z1b = math.min(x0b, r.x0), math.max(x1b, r.x1), math.min(z0b, r.z0), math.max(z1b, r.z1)
		end
	end
	local nx, nz = math.floor((x1b - x0b) / CELL + 0.5), math.floor((z1b - z0b) / CELL + 0.5)
	local function cx(i) return x0b + (i + 0.5) * CELL end
	local function cz(j) return z0b + (j + 0.5) * CELL end

	-- inside mask on the 2-stud grid, plus every outside cell (with a one-cell border) for the distance field
	local inside, outside = {}, {}
	for i = -1, nx do
		inside[i] = {}
		for j = -1, nz do
			local x, z = cx(i), cz(j)
			local hit = false
			for _, r in rows do
				if x > r.x0 and x < r.x1 and z > r.z0 and z < r.z1 then
					hit = true
					break
				end
			end
			inside[i][j] = hit
			if not hit then
				table.insert(outside, Vector2.new(x, z))
			end
		end
	end
	-- distance (studs) from a point to the nearest cell outside the disc
	local function rimDist(x, z)
		local best = math.huge
		local p = Vector2.new(x, z)
		for _, o in outside do
			local d = (o - p).Magnitude
			if d < best then
				best = d
			end
		end
		return best
	end

	local old = ground:FindFirstChild("Ground_Underside")
	if old then
		old:Destroy()
	end
	local model = Kit.model(ground, "Ground_Underside")
	local parts, deepest, deepBlock = 0, math.huge, nil

	-- columns: bands of 3 rows along Z, each split along X into chunks 2..5 cells wide (staggered per band)
	local k = 0
	for j0 = 0, nz - 1, BAND do
		local j1 = math.min(j0 + BAND - 1, nz - 1)
		local i = -rng:NextInteger(0, 2) -- stagger the joints between bands
		while i < nx do
			local w = rng:NextInteger(2, 5)
			local ia, ib = math.max(i, 0), math.min(i + w - 1, nx - 1)
			i += w
			-- this chunk's inside cells, row by row (each row of the disc is one contiguous run)
			local runs, sum, cnt = {}, 0, 0
			for j = j0, j1 do
				local a, b = nil, nil
				for ii = ia, ib do
					if inside[ii][j] then
						a = a or ii
						b = ii
						sum += rimDist(cx(ii), cz(j))
						cnt += 1
					end
				end
				if a then
					table.insert(runs, { j = j, a = a, b = b })
				end
			end
			if cnt > 0 then
				k += 1
				local avg = sum / cnt
				local bottom = math.min(yTop - 1.5, yTop - (1 + avg * SLOPE + rng:NextNumber(-ROUGH, ROUGH)))
				bottom = math.floor(bottom * 10 + 0.5) / 10 + 0.0001 * (k % 7) -- 0.1 grid, never two equal bottoms side by side
				local col = if avg > 30 then CLIFF[2 + k % 2] else CLIFF[1 + k % 2]
				-- merge consecutive rows with the same run into one box
				local s = 1
				while s <= #runs do
					local e = s
					while e < #runs and runs[e + 1].a == runs[s].a and runs[e + 1].b == runs[s].b and runs[e + 1].j == runs[e].j + 1 do
						e += 1
					end
					local r0, r1 = runs[s], runs[e]
					Kit.box(model, "Column", x0b + r0.a * CELL, x0b + (r0.b + 1) * CELL, bottom, yTop, z0b + r0.j * CELL, z0b + (r1.j + 1) * CELL, col, { Pattern = "Studs" })
					parts += 1
					s = e + 1
				end
				if bottom < deepest then
					deepest = bottom
					deepBlock = { x = x0b + (ia + ib + 1) * CELL / 2, z = z0b + (j0 + j1 + 1) * CELL / 2 }
				end
			end
		end
	end

	-- the point: two shrinking chunks hanging under the deepest column
	if deepBlock then
		local y = deepest
		for t, s in { { 5, 4 }, { 2.6, 3 } } do
			local px, pz = deepBlock.x + rng:NextNumber(-0.6, 0.6), deepBlock.z + rng:NextNumber(-0.6, 0.6)
			Kit.box(model, "Tip" .. t, px - s[1] / 2, px + s[1] / 2, y - s[2], y + 0.3, pz - s[1] / 2, pz + s[1] / 2, CLIFF[3], { Pattern = "Studs" })
			parts += 1
			y -= s[2]
		end
		deepest = y
	end

	pcall(ChangeHistoryService.SetWaypoint, ChangeHistoryService, "HOS-MAP-002: lobby underside built")
	return ("lobby underside: %d parts, %d columns, top y %.2f, point at y %.1f"):format(parts, k, yTop, deepest)
end
