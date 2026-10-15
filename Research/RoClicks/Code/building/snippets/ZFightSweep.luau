--!strict
-- ZFightSweep: find (and optionally fix) faces that will z-fight inside a model or a built scene.
--
-- Two box faces fight when their outward normals agree, their planes are < TH apart, and their rectangles
-- overlap by more than MARGIN on both in-plane axes. Edge contact is fine. Only Block parts are checked
-- (MeshParts, unions, balls and SpecialMesh parts don't have box faces).
-- A pair is "visible" when the faces differ in colour/material/variant, or either carries a stud
-- MaterialVariant (texture origin is per part, so even identical studded parts disagree).
--
-- Fix: grow the part with the SMALLER face outward along that face normal until the planes are EPS apart
-- (its opposite face stays put). Run sweeps in edit mode; long loops on a playtest client can kill it.
--
--   local pairs_ = ZFightSweep.sweep(model)            -- read only
--   local fixed = ZFightSweep.fix(model)               -- returns count fixed
--
-- This is an O(n^2)-per-bin sketch: fine for templates (hundreds of parts) and scenes up to ~20k parts
-- with the grid binning. For bigger worlds, sweep per chunk.

local ZFightSweep = {}
ZFightSweep.TH = 0.005 -- planes closer than this fight
ZFightSweep.EPS = 0.01 -- fixed planes end up this far apart
ZFightSweep.MARGIN = 0.004 -- overlap must exceed this to count
ZFightSweep.BIN = 0.05 -- plane-offset bin size

type Face = {
	part: BasePart,
	n: Vector3, -- outward world normal
	c: Vector3, -- centre
	u: Vector3, v: Vector3, -- in-plane axes
	hu: number, hv: number, -- half sizes
	axis: number, sign: number,
	area: number,
}

local function eligible(p: BasePart): boolean
	if p.Transparency >= 0.98 then return false end
	if not p:IsA("Part") or p.Shape ~= Enum.PartType.Block then return false end
	if p:FindFirstChildWhichIsA("DataModelMesh") then return false end
	return true
end

local function faces(p: BasePart, out: { Face })
	local cf, s = p.CFrame, p.Size
	local ax = { cf.RightVector, cf.UpVector, -cf.LookVector }
	local half = { s.X / 2, s.Y / 2, s.Z / 2 }
	for a = 1, 3 do
		local b, c = a % 3 + 1, (a + 1) % 3 + 1
		for _, sg in { 1, -1 } do
			table.insert(out, {
				part = p, n = ax[a] * sg, c = cf.Position + ax[a] * sg * half[a],
				u = ax[b], v = ax[c], hu = half[b], hv = half[c],
				axis = a, sign = sg, area = 4 * half[b] * half[c],
			})
		end
	end
end

local function looksDifferent(a: BasePart, b: BasePart): boolean
	return a.Color ~= b.Color or a.Material ~= b.Material or a.MaterialVariant ~= b.MaterialVariant
		or a.MaterialVariant ~= "" or b.MaterialVariant ~= ""
end

-- overlap of face b's rectangle projected on face a's axes (both directions must exceed MARGIN)
local function overlaps(a: Face, b: Face): boolean
	local d = b.c - a.c
	local bu = math.abs(b.u:Dot(a.u)) * b.hu + math.abs(b.v:Dot(a.u)) * b.hv
	local bv = math.abs(b.u:Dot(a.v)) * b.hu + math.abs(b.v:Dot(a.v)) * b.hv
	local ou = a.hu + bu - math.abs(d:Dot(a.u))
	local ov = a.hv + bv - math.abs(d:Dot(a.v))
	return ou > ZFightSweep.MARGIN and ov > ZFightSweep.MARGIN
end

export type Pair = { a: Face, b: Face, sep: number, visible: boolean }

function ZFightSweep.sweep(root: Instance): { Pair }
	local all: { Face } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and eligible(d) then
			faces(d, all)
		end
	end
	-- bin by (rounded normal, plane offset) so only candidates are compared
	local bins: { [string]: { Face } } = {}
	for _, f in all do
		local n = f.n
		local key = string.format("%d,%d,%d|%d", math.round(n.X * 100), math.round(n.Y * 100),
			math.round(n.Z * 100), math.floor(f.c:Dot(n) / ZFightSweep.BIN))
		local list = bins[key]
		if not list then list = {}; bins[key] = list end
		table.insert(list, f)
	end
	local found: { Pair } = {}
	local seen: { [string]: boolean } = {}
	for key, list in bins do
		-- also compare against the neighbouring offset bin (planes straddling a bin edge)
		local head, off = key:match("^(.-)|(%-?%d+)$")
		local nxt = bins[`{head}|{tonumber(off) :: number + 1}`] or {}
		local cands = table.clone(list)
		table.move(nxt, 1, #nxt, #cands + 1, cands)
		for i, a in list do
			for j, b in cands do
				if (j > i or j > #list) and a.part ~= b.part and a.n:Dot(b.n) > 0.9995 then
					local sep = math.abs((b.c - a.c):Dot(a.n))
					if sep < ZFightSweep.TH and overlaps(a, b) then
						local id = `{a.part:GetDebugId()}{a.axis}{a.sign}/{b.part:GetDebugId()}{b.axis}{b.sign}`
						if not seen[id] then
							seen[id] = true
							table.insert(found, { a = a, b = b, sep = sep, visible = looksDifferent(a.part, b.part) })
						end
					end
				end
			end
		end
	end
	return found
end

-- Grow the smaller face's part outward so the planes end EPS apart. Jointed (unanchored) parts are skipped:
-- moving them would break weld offsets; report and fix those by hand.
function ZFightSweep.fix(root: Instance): number
	local fixed = 0
	for _, pr in ZFightSweep.sweep(root) do
		if pr.visible then
			local f = if pr.a.area <= pr.b.area then pr.a else pr.b
			local other = if f == pr.a then pr.b else pr.a
			local p = f.part
			if p.Anchored then
				-- distance f's plane must move outward to sit EPS beyond the other plane
				local grow = ZFightSweep.EPS - (f.c - other.c):Dot(f.n)
				if grow > 0 then
					local axisSize = { p.Size.X, p.Size.Y, p.Size.Z }
					axisSize[f.axis] += grow
					p.Size = Vector3.new(axisSize[1], axisSize[2], axisSize[3])
					p.CFrame = p.CFrame + f.n * (grow / 2)
					fixed += 1
				end
			end
		end
	end
	return fixed
end

return ZFightSweep
