--!nocheck
-- EggPieces (HOS-INC-001, 17 Oct 2026, Matthew): the incubator egg as a cracked-shell puzzle. The egg is cut along
-- jagged crack lines into COUNT pieces that fit together exactly: a bottom cap, three rings of pieces (5, 6, 5) and a
-- top cap. Each piece is a curved shell with thickness, UV-mapped to the egg shard atlas (ReplicatedStorage.EggShardKit
-- SA_<rarity>: outer face top-left, inner face top-right, rim band below) so it wears the same rarity look as the
-- shards. A thin crack is left between neighbours.
-- The meshes are baked once in Studio (ServerStorage.EOSBuild.BakeIncubatorEgg uploads them and stores the MeshParts
-- in ReplicatedStorage.IncubatorEggPieces): EditableMesh is too memory-hungry to build 18 of on a player's device.
-- Without the baked folder, each piece is drawn from wedge parts in the rarity's colour instead.
-- Pieces come back in fill order (bottom up). All positions are relative to the egg's centre (A09_EggCentre).
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pieces = {}
Pieces.COUNT = 18
Pieces.BAKED = "IncubatorEggPieces" -- ReplicatedStorage folder: MeshParts Piece1..Piece18, attributes Centre, Mid, MeshTurn

local TAU = math.pi * 2
local H, R, BULGE, YC = 2.2, 1.78, 0.08, -0.12 -- half-height, waist radius, wider bottom, egg middle below the centre
local TH = 0.16 -- shell thickness
local GAP = 0.025 -- half the crack between neighbours (studs)
local RINGS = { -- crack rings: angle from the bottom pole, zigzag knots, zigzag size (radians)
	{ phi = 0.55, knots = 10, amp = 0.08 },
	{ phi = 1.35, knots = 18, amp = 0.09 },
	{ phi = 2.05, knots = 18, amp = 0.09 },
	{ phi = 2.62, knots = 10, amp = 0.08 },
}
local BANDS = { 5, 6, 5 } -- pieces in each ring band, bottom up
local ORDER = { [5] = { 1, 3, 5, 2, 4 }, [6] = { 1, 4, 2, 5, 3, 6 } } -- fill order round a band: spread out

-- the egg's surface (outer or inner) at longitude u, angle phi from the bottom pole
local function point(u: number, phi: number, inner: boolean?): Vector3
	local rs = if inner then (R - TH) / R else 1
	local hs = if inner then (H - TH) / H else 1
	local r = R * rs * math.sin(phi) * (1 + BULGE * math.cos(phi))
	return Vector3.new(r * math.cos(u), YC - H * hs * math.cos(phi), r * math.sin(u))
end

local function radiusAt(phi: number): number
	return math.max(0.35, R * math.sin(phi) * (1 + BULGE * math.cos(phi)))
end

-- a crack ring: phi as a zigzag function of u (periodic)
local function ring(rng: Random, spec: any)
	local ks = {}
	for j = 0, spec.knots - 1 do
		local u = ((j + rng:NextNumber(-0.3, 0.3)) / spec.knots * TAU) % TAU
		local d = (if j % 2 == 0 then 1 else -1) * spec.amp * rng:NextNumber(0.45, 1)
		table.insert(ks, { u = u, phi = spec.phi + d })
	end
	table.sort(ks, function(a, b) return a.u < b.u end)
	local n = #ks
	return function(u: number): number
		u %= TAU
		local a, b
		if u < ks[1].u then
			a, b = { u = ks[n].u - TAU, phi = ks[n].phi }, ks[1]
		elseif u >= ks[n].u then
			a, b = ks[n], { u = ks[1].u + TAU, phi = ks[1].phi }
		else
			for j = 1, n - 1 do
				if u < ks[j + 1].u then
					a, b = ks[j], ks[j + 1]
					break
				end
			end
		end
		return a.phi + (b.phi - a.phi) * (u - a.u) / math.max(1e-6, b.u - a.u)
	end
end

-- a crack between two pieces of a band: u as a zigzag function of t (0 at the band's lower ring, 1 at the upper)
local function seam(rng: Random, u0: number, amp: number)
	local M = 5
	local ks = {}
	for j = 0, M do
		ks[j] = u0 + (if j % 2 == 0 then 1 else -1) * amp * rng:NextNumber(0.4, 1)
	end
	return function(t: number): number
		local x = math.clamp(t, 0, 1) * M
		local j = math.min(math.floor(x), M - 1)
		return ks[j] + (ks[j + 1] - ks[j]) * (x - j)
	end
end

-- the regions: f(s, t) -> (u, phi) over s, t in [0, 1]; caps wrap round in s and close at a pole
local function layout(): { any }
	local rng = Random.new(1031)
	local rings = {}
	for i, spec in RINGS do rings[i] = ring(rng, spec) end
	local gphi = GAP / 1.9
	local out = {}
	-- bottom cap
	table.insert(out, { wrap = true, pole0 = true, cap = -1, f = function(s, t)
		local u = s * TAU
		return u, t * (rings[1](u) - gphi)
	end })
	-- the ring bands
	for b, count in BANDS do
		local lo, hi = rings[b], rings[b + 1]
		local midPhi = (RINGS[b].phi + RINGS[b + 1].phi) / 2
		local gu = GAP / radiusAt(midPhi)
		local start = b * 0.37 -- each band's cracks offset from the last, like brickwork
		local seams = {}
		for k = 1, count do
			seams[k] = seam(rng, start + (k - 1) / count * TAU, 0.13)
		end
		local band = {}
		for k = 1, count do
			local s0, s1 = seams[k], seams[k % count + 1]
			local wrapAdd = if k == count then TAU else 0
			band[k] = { f = function(s, t)
				local u0, u1 = s0(t) + gu, s1(t) + wrapAdd - gu
				local u = u0 + (u1 - u0) * s
				local p0, p1 = lo(u) + gphi, hi(u) - gphi
				return u, p0 + (p1 - p0) * t
			end }
		end
		for _, k in ORDER[count] do table.insert(out, band[k]) end
	end
	-- top cap
	table.insert(out, { wrap = true, pole1 = true, cap = 1, f = function(s, t)
		local u = s * TAU
		local p0 = rings[#RINGS](u) + gphi
		return u, p0 + (math.pi - p0) * t
	end })
	return out
end

-- one piece's shell: positions, triangles (outward-facing), UVs, the outer triangles alone, and its centre
local function shell(reg: any, ns: number, nt: number): any
	local P, UV, T, OUTER = {}, {}, {}, {}
	local cols = if reg.wrap then ns else ns + 1
	local function add(p: Vector3, uv: Vector2): number
		table.insert(P, p)
		table.insert(UV, uv)
		return #P
	end
	local function surfaceUV(s, t, p, inner)
		if reg.cap then -- caps: planar from below / above
			local c = if inner then Vector2.new(0.83, 0.31) else Vector2.new(0.33, 0.32)
			local k = if inner then 0.13 else 0.28
			return c + Vector2.new(p.X, p.Z) / R * k
		end
		return if inner then Vector2.new(0.72 + 0.24 * s, 0.58 - 0.53 * t) else Vector2.new(0.03 + 0.6 * s, 0.6 - 0.56 * t)
	end
	local grid = { [false] = {}, [true] = {} }
	for _, inner in { false, true } do
		local g = grid[inner]
		local pole
		for j = 0, nt do
			g[j] = {}
			local t = j / nt
			for i = 0, cols - 1 do
				local s = i / ns
				if (reg.pole0 and j == 0) or (reg.pole1 and j == nt) then
					if not pole then
						local u, phi = reg.f(0, t)
						local p = point(u, phi, inner)
						pole = add(p, surfaceUV(s, t, p, inner))
					end
					g[j][i] = pole
				else
					local u, phi = reg.f(s, t)
					local p = point(u, phi, inner)
					g[j][i] = add(p, surfaceUV(s, t, p, inner))
				end
			end
		end
		if reg.pole0 or reg.pole1 then pole = nil end
	end
	local eggMid = Vector3.new(0, YC, 0)
	local function tri(a, b, c, outward: boolean, ref: Vector3?)
		if a == b or b == c or a == c then return end
		local pa, pb, pc = P[a], P[b], P[c]
		local n = (pb - pa):Cross(pc - pa)
		if n.Magnitude < 1e-7 then return end
		local dir = (pa + pb + pc) / 3 - (ref or eggMid)
		if (n:Dot(dir) > 0) ~= outward then b, c = c, b end
		table.insert(T, { a, b, c })
		return true
	end
	-- outer (faces out) and inner (faces in) surfaces
	for _, inner in { false, true } do
		local g = grid[inner]
		for j = 0, nt - 1 do
			for i = 0, (if reg.wrap then cols - 1 else cols - 2) do
				local i2 = if reg.wrap then (i + 1) % cols else i + 1
				local a, b, c, d = g[j][i], g[j][i2], g[j + 1][i2], g[j + 1][i]
				if tri(a, b, c, not inner) and not inner then table.insert(OUTER, { P[a], P[b], P[c] }) end
				if tri(a, c, d, not inner) and not inner then table.insert(OUTER, { P[a], P[c], P[d] }) end
			end
		end
	end
	-- the piece's centre on its outer face, for the rim walls' direction
	local sum, cnt = Vector3.zero, 0
	for j = 0, nt do
		for i = 0, cols - 1 do
			sum += P[grid[false][j][i]]
			cnt += 1
		end
	end
	local centre = sum / cnt
	-- rim walls round the border (the crack faces): their own vertices, on the atlas's rim band
	local loop = {}
	if reg.cap then
		local j = if reg.pole0 then nt else 0
		for i = 0, cols do table.insert(loop, { j, i % cols }) end
	else
		for i = 0, cols - 1 do table.insert(loop, { 0, i }) end
		for j = 1, nt do table.insert(loop, { j, cols - 1 }) end
		for i = cols - 2, 0, -1 do table.insert(loop, { nt, i }) end
		for j = nt - 1, 0, -1 do table.insert(loop, { j, 0 }) end
	end
	for e = 1, #loop - 1 do
		local A, B = loop[e], loop[e + 1]
		local oa, ob = P[grid[false][A[1]][A[2]]], P[grid[false][B[1]][B[2]]]
		local ia, ib = P[grid[true][A[1]][A[2]]], P[grid[true][B[1]][B[2]]]
		local x0, x1 = 0.05 + 0.9 * (e - 1) / (#loop - 1), 0.05 + 0.9 * e / (#loop - 1)
		local v1 = add(oa, Vector2.new(x0, 0.72))
		local v2 = add(ob, Vector2.new(x1, 0.72))
		local v3 = add(ib, Vector2.new(x1, 0.88))
		local v4 = add(ia, Vector2.new(x0, 0.88))
		local mid = (oa + ob + ia + ib) / 4
		local inward = (centre - mid)
		local ref = mid + inward.Unit * 0.5 -- a point inside the piece: the wall faces away from it
		tri(v1, v2, v3, true, ref)
		tri(v1, v3, v4, true, ref)
	end
	return { P = P, UV = UV, T = T, OUTER = OUTER, centre = centre }
end

-- one piece's shell as an EditableMesh, centred on its bounding box (returns the mesh and that centre)
local function editable(sh: any): (EditableMesh, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in sh.P do
		lo, hi = lo:Min(p), hi:Max(p)
	end
	local mid = (lo + hi) / 2
	local em = AssetService:CreateEditableMesh()
	assert(em, "EditableMesh budget exhausted")
	local vid, uvid = {}, {}
	for k, p in sh.P do
		vid[k] = em:AddVertex(p - mid)
		uvid[k] = em:AddUV(sh.UV[k])
	end
	for _, t in sh.T do
		local f = em:AddTriangle(vid[t[1]], vid[t[2]], vid[t[3]])
		em:SetFaceUVs(f, { uvid[t[1]], uvid[t[2]], uvid[t[3]] })
	end
	pcall(em.RemoveUnused, em)
	return em, mid
end

-- for the bake (Studio, edit mode): every piece in fill order as { em = EditableMesh, mid = its bounding-box centre,
-- centre = the centre of its outer face }, both relative to the egg's centre
function Pieces.editableMeshes(): { any }
	local out = {}
	for i, reg in layout() do
		local fine = if reg.cap then shell(reg, 20, 4) else shell(reg, 12, 6)
		local em, mid = editable(fine)
		out[i] = { em = em, mid = mid, centre = fine.centre }
	end
	return out
end

-- one triangle as two wedges (the fallback); a is moved in by half the thickness along -out
local function wedges(a: Vector3, b: Vector3, c: Vector3, out: Vector3, th: number): { any }
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local sink = -out * th / 2
	return {
		{ size = Vector3.new(th, height, math.abs(ab:Dot(back))), cf = CFrame.fromMatrix((a + b) / 2 + sink, right, up, back) },
		{ size = Vector3.new(th, height, math.abs(ac:Dot(back))), cf = CFrame.fromMatrix((a + c) / 2 + sink, -right, up, -back) },
	}
end

local function quiet(p: BasePart)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
end

-- builds the egg. Returns { model, baked = true when the baked meshes were used, pieces = { {
--   parts = { BasePart }, locals = { CFrame (relative to the egg centre) }, holo = { BasePart } (its ForceField
--   hologram), holoLocals, centre = Vector3, out = Vector3 } } }
-- partsOnly skips the baked meshes (to check the fallback).
function Pieces.build(parent: Instance?, partsOnly: boolean?): any
	local regions = layout()
	local model = Instance.new("Model")
	model.Name = "IncubatorEgg"
	local folder = ReplicatedStorage:FindFirstChild(Pieces.BAKED)
	local baked = not partsOnly and folder ~= nil
	if baked then
		for i = 1, #regions do
			local tpl = folder:FindFirstChild("Piece" .. i)
			if not (tpl and tpl:IsA("MeshPart") and typeof(tpl:GetAttribute("Centre")) == "Vector3" and typeof(tpl:GetAttribute("Mid")) == "Vector3") then
				baked = false
				break
			end
		end
	end
	local res = { model = model, pieces = {}, baked = baked }
	for i, reg in regions do
		local piece = { parts = {}, locals = {} }
		if baked then
			local tpl = folder["Piece" .. i]
			local mp = tpl:Clone()
			quiet(mp)
			mp.Material = Enum.Material.SmoothPlastic
			mp.Color = Color3.new(1, 1, 1)
			for _, sa in mp:GetChildren() do
				if sa:IsA("SurfaceAppearance") then sa:Destroy() end
			end
			mp.Parent = model
			piece.centre = tpl:GetAttribute("Centre")
			table.insert(piece.parts, mp)
			local turn = tpl:GetAttribute("MeshTurn") -- how the importer turned the mesh (undone here)
			table.insert(piece.locals, CFrame.new(tpl:GetAttribute("Mid")) * (if typeof(turn) == "CFrame" then turn else CFrame.identity))
		else
			local coarse = if reg.cap then shell(reg, 8, 2) else shell(reg, 4, 3)
			piece.centre = coarse.centre
			for _, t in coarse.OUTER do
				for _, w in wedges(t[1], t[2], t[3], coarse.centre.Unit, TH) do
					local p = Instance.new("WedgePart")
					p.Name = "Piece" .. i
					quiet(p)
					p.Material = Enum.Material.SmoothPlastic
					p.Size = w.size
					p.Parent = model
					table.insert(piece.parts, p)
					table.insert(piece.locals, w.cf)
				end
			end
		end
		-- its hologram: a ForceField copy (a hair larger, so it never flickers against the piece as they cross-fade)
		piece.holo, piece.holoLocals = {}, {}
		for k, p in piece.parts do
			local h = p:Clone()
			h.Name = "Holo" .. i
			h.Material = Enum.Material.ForceField
			if baked then h.Size = p.Size * 1.01 end
			h.Parent = model
			piece.holo[k] = h
			piece.holoLocals[k] = piece.locals[k]
		end
		piece.out = piece.centre.Unit
		res.pieces[i] = piece
	end
	model.Parent = parent
	return res
end

return Pieces
