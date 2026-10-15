--!strict
-- Layers: the ONE table of heights for everything stacked flat on the ground.
--
-- Why: ground, roads, land overlays, border strips, decals and the build ghost are all thin plates lying
-- on each other. Each system picking its own "+0.01" ends with two of them on the same plane, which
-- flickers (z-fighting). Measured in Studio: a 0.001-stud gap renders clean even 1,500 studs away at a
-- grazing angle; exactly coplanar (or +-0.0001) faces break into triangles. Gaps of 0.025+ start to show
-- as visible lips on walls.
--
-- Rules:
--   * Values are WORLD studs. Never multiply them by a world-scale factor: depth precision does not shrink
--     when the world does.
--   * Keep every layer >= EPS apart. Stay ~0.005 away from multiples of 0.01, because template parts are
--     usually authored on a 0.1 / 0.01 grid and an offset that lands on that grid re-creates the fight.
--   * Pieces that overlap end to end (wall segments, crossing strips) share a top: give neighbours
--     different lifts with Layers.stagger(i).
--   * Read heights from here everywhere (server, client, cutscenes). One drifting copy is enough to flicker.

local Layers = {}

Layers.EPS = 0.012

-- tune these names and values to your game; keep the ordering and the spacing
Layers.GROUND = 0.000 -- top of the terrain/chunk ground plates
Layers.DECOR_MAX = 0.080 -- highest flat decor baked into ground templates; nothing flat between this and ROAD
Layers.ROAD = 0.092 -- top of every road surface
Layers.LAND = 0.105 -- top of territory/owner overlays; buildings stand here
Layers.BORDER_Z = 0.1395 -- border strips on +Z/-Z cell sides
Layers.BORDER_X = 0.1515 -- border strips on +X/-X sides (they cross at corners, so tops must differ)
Layers.PLATE = Layers.LAND + Layers.EPS -- foundations, scorch marks, anything laid on LAND
Layers.DECAL = Layers.PLATE + Layers.EPS -- markers laid on PLATE
Layers.GHOST = Layers.LAND + 0.04 + 2 * Layers.EPS -- build ghost: above the thin pads inside building templates

Layers.SIDE_OUT = 0.01 -- vertical faces: push border pieces this far outside the cell edge

-- distinct lift for neighbouring pieces whose tops overlap: 0, EPS/2, EPS, 3*EPS/2, then repeats
function Layers.stagger(i: number): number
	return (i % 4) * Layers.EPS / 2
end

-- lift needed to put a template whose surface was authored at `authoredTop` onto `layer`
function Layers.lift(layer: number, authoredTop: number): number
	return math.max(0, layer - authoredTop)
end

-- self-check: every named layer is >= minGap apart from every other (call from a test or on boot)
function Layers.check(minGap: number?): { string }
	local gap = minGap or 0.0075
	local names = { "GROUND", "DECOR_MAX", "ROAD", "LAND", "BORDER_Z", "BORDER_X", "DECAL", "GHOST" }
	local bad = {}
	for i = 1, #names do
		for j = i + 1, #names do
			local a, b = (Layers :: any)[names[i]], (Layers :: any)[names[j]]
			if math.abs(a - b) < gap then
				table.insert(bad, `{names[i]} ({a}) vs {names[j]} ({b})`)
			end
		end
	end
	return bad
end

return Layers
