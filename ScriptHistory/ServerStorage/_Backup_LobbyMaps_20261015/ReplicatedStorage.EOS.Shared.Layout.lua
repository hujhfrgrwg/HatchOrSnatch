--!strict
-- Layout: world coordinates shared by the world builder and the game services.
-- Gameplay volumes (safe zones, arena bounds) are defined HERE, not discovered from parts, so a
-- decorative rebuild can never silently break zone checks.
-- Ground top is Y = 0 on both islands. Travel axis in the arena is X (Side A = -X, Side B = +X).

local Layout = {}

Layout.GROUND_Y = 0

-- ===== Lobby island =====
-- Oct 2026: a compact square island (the developer's reference), open in the middle, with every
-- game-loop feature around the edge facing in: leaderboards north, the arena portal north-east,
-- Gold / Gem shops east, pets south-east, the incubator south, practice south-west, quests and the
-- Top-3 podium west. Spawn in the middle facing north.
Layout.Lobby = {
	CENTER = Vector3.new(0, 0, 0),
	HALF = Vector3.new(60, 0, 60), -- walkable half extents (boundary walls)
	ISLAND_HALF = 66,
	SPAWN = Vector3.new(0, 0, 8),
	CENTERPIECE = Vector3.new(0, 0, -40), -- what arrivals face (the leaderboards)
	BOARDS_Z = -54, -- north row, facing south
	BOARD_X = { -36, -18, 0, 18 },
	PORTAL = Vector3.new(44, 0, -44), -- north-east corner, faces the middle
	SHOP_X = 54, -- east edge stalls, facing west
	GOLD_SHOP_Z = -16,
	GEM_SHOP_Z = 6,
	PETS = Vector3.new(40, 0, 44), -- south-east
	INCUBATOR = Vector3.new(0, 0, 50), -- south edge, faces north
	PODIUM = Vector3.new(-52, 0, -16), -- west edge, faces east
	QUESTS = Vector3.new(-54, 0, 10), -- west edge, faces east
	PRACTICE_CENTER = Vector3.new(-36, 0, 42),
	PRACTICE_HALF = Vector3.new(20, 0, 12),
	-- lobby NPCs wander here (clear of the stalls and the practice field)
	WANDER_MIN = Vector3.new(-38, 0, -38),
	WANDER_MAX = Vector3.new(36, 0, 26),
}

-- ===== Arena island =====
local AC = Vector3.new(0, 0, -390)
Layout.Arena = {
	CENTER = AC,
	FIELD_HALF_X = 88, -- inner edge of each safe zone
	ZONE_DEPTH = 24, -- safe strip depth along X
	HALF_Z = 70, -- playable half width
	WALL_HEIGHT = 40,
}
local A = Layout.Arena

-- Safe zone boxes (center, size). Side A is the -X strip, Side B the +X strip.
Layout.Zones = {
	A = { center = AC + Vector3.new(-(A.FIELD_HALF_X + A.ZONE_DEPTH / 2), 6, 0), size = Vector3.new(A.ZONE_DEPTH, 16, A.HALF_Z * 2) },
	B = { center = AC + Vector3.new(A.FIELD_HALF_X + A.ZONE_DEPTH / 2, 6, 0), size = Vector3.new(A.ZONE_DEPTH, 16, A.HALF_Z * 2) },
}

-- Whole legal play volume (field + both zones)
Layout.ArenaBounds = {
	center = AC + Vector3.new(0, 10, 0),
	size = Vector3.new((A.FIELD_HALF_X + A.ZONE_DEPTH) * 2, 30, A.HALF_Z * 2),
}

-- Practice field pads (lobby)
local P = Layout.Lobby.PRACTICE_CENTER
local PH = Layout.Lobby.PRACTICE_HALF
Layout.Practice = {
	bounds = { center = P + Vector3.new(0, 6, 0), size = Vector3.new(PH.X * 2, 16, PH.Z * 2) },
	padA = { center = P + Vector3.new(-PH.X + 4, 4, 0), size = Vector3.new(8, 10, PH.Z * 2) },
	padB = { center = P + Vector3.new(PH.X - 4, 4, 0), size = Vector3.new(8, 10, PH.Z * 2) },
}

-- Wave 1 runs A -> B, wave 2 B -> A, wave 3 A -> B ...
function Layout.directionForWave(wave: number): (string, string)
	if wave % 2 == 1 then
		return "A", "B"
	end
	return "B", "A"
end

function Layout.inBox(pos: Vector3, box: { center: Vector3, size: Vector3 }): boolean
	local d = pos - box.center
	local h = box.size / 2
	return math.abs(d.X) <= h.X and math.abs(d.Y) <= h.Y and math.abs(d.Z) <= h.Z
end

-- How far inside a safe zone `pos` is, from the zone's edge on the field side (negative = in the field)
function Layout.zoneDepth(pos: Vector3, zone: string): number
	local box = Layout.Zones[zone]
	local half = box.size.X / 2
	if box.center.X < Layout.Arena.CENTER.X then
		return (box.center.X + half) - pos.X -- zone A, west of the field
	end
	return pos.X - (box.center.X - half) -- zone B, east of the field
end

-- Spread n spawn points inside a safe zone (deterministic grid, ground level)
function Layout.zoneSpawns(zone: string, n: number): { Vector3 }
	local box = Layout.Zones[zone]
	local out = {}
	local cols = math.max(1, math.ceil(math.sqrt(n / 3)))
	local rows = math.ceil(n / cols)
	for i = 0, n - 1 do
		local c = i % cols
		local r = math.floor(i / cols)
		local x = box.center.X + ((c + 0.5) / cols - 0.5) * (box.size.X - 8)
		local z = box.center.Z + ((r + 0.5) / rows - 0.5) * (box.size.Z - 16)
		table.insert(out, Vector3.new(x, Layout.GROUND_Y + 3, z))
	end
	return out
end

-- Catcher interception spawns: along the centre line (X ~ 0) north and south of the central
-- structure (which occupies |z| < 16), never on a safe pad. Up to 30 distinct slots.
Layout.CENTER_STRUCTURE_HALF_Z = 16
function Layout.catcherSpawns(n: number): { Vector3 }
	local out = {}
	for i = 0, n - 1 do
		local side = (i % 2 == 0) and -1 or 1
		local k = math.floor(i / 2)
		local z = side * (28 + (k % 5) * 8)
		local x = ((math.floor(k / 5) % 3) - 1) * 12
		table.insert(out, AC + Vector3.new(x, 3, z))
	end
	return out
end

return Layout
