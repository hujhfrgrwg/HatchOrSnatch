--!strict
-- WorldExtent: the real world-axis size of rotated parts.
--
-- Why: Part.Size is in the part's LOCAL axes. Geometry imported from Blender often arrives rotated, so a
-- bar authored 174 x 3 x 2.5 can stand 174 studs TALL. Code that reads Size.X as "width" then slides a
-- hazard along the wrong axis. Compute the extent from the CFrame axes instead.

local WorldExtent = {}

-- World-axis-aligned size of one box part (exact for blocks; a bound for wedges/meshes).
function WorldExtent.ofPart(part: BasePart): Vector3
	local cf, s = part.CFrame, part.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return Vector3.new(
		math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z,
		math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z,
		math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z
	)
end

-- World-axis-aligned box (min, max) around every visible BasePart under root. Unlike
-- Model:GetBoundingBox, this ignores invisible helper parts (footprints, hitboxes) so it measures what
-- the player SEES; pass includeInvisible to count them.
function WorldExtent.ofModel(root: Instance, includeInvisible: boolean?): (Vector3?, Vector3?)
	local lo: Vector3?, hi: Vector3?
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and (includeInvisible or d.Transparency < 0.98) then
			local half = WorldExtent.ofPart(d) / 2
			local a, b = d.Position - half, d.Position + half
			lo = if lo then lo:Min(a) else a
			hi = if hi then hi:Max(b) else b
		end
	end
	return lo, hi
end

-- Which world axis ("X", "Y", "Z") a part's local axis ("X", "Y", "Z") points along. Handy when an
-- imported part's "length" must be found: WorldExtent.longAxis(part) tells you where it actually runs.
function WorldExtent.longAxis(part: BasePart): string
	local e = WorldExtent.ofPart(part)
	if e.X >= e.Y and e.X >= e.Z then
		return "X"
	elseif e.Y >= e.Z then
		return "Y"
	end
	return "Z"
end

return WorldExtent
