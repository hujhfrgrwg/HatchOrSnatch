--!strict
-- Layout: world coordinates shared by the world builder and the game services.
-- Gameplay volumes (safe zones, arena bounds) are defined HERE, not discovered from parts, so a
-- decorative rebuild can never silently break zone checks.
-- Ground top is Y = 0 on both islands. Travel axis in the arena is X (Side A = -X, Side B = +X).

local Layout = {}

Layout.GROUND_Y = 0

-- ===== Lobby island =====
-- Oct 2026 (v4): the lobby floats right beside the arena, raised up, with open edges, so people
-- in the lobby can look down and watch the match. Its north edge sits over the arena island's
-- south edge. Everything below is built in LobbyLocal coordinates (island centre = 0,0,0) and the
-- whole lobby is moved to ORIGIN; Layout.Lobby holds the WORLD positions the game uses.
-- 16 Oct 2026 (HOS-LOBBY-001): the lobby in the "Hatch or Snatch" place sits higher and closer than v4
-- built it (EOS_LobbySpawn at 0, 133.7, -68; grass top Y = 133.5). Players were teleported to the old spot
-- in mid-air at the end of every round and fell off the map. Measured from the placed lobby:
local LOBBY_ORIGIN = Vector3.new(0, 133.5, -94)
Layout.LobbyLocal = {
	HALF = Vector3.new(60, 0, 60), -- walkable half extents (invisible boundary walls)
	ISLAND_HALF = 66,
	SPAWN = Vector3.new(0, 0, 26), -- bots spawn up to 24 studs north of here: clear of the fountain
	STATUE = Vector3.new(0, 0, -12), -- diving-catch statue fountain (centre of the plaza)
	TERRACE_Z = -50, -- north edge: spectator terrace looking at the arena
	BOARDS_Z = 52, -- south edge: swivelling leaderboards, facing north
	BOARD_X = { -27, -9, 9, 27 },
	SHOP = Vector3.new(46, 0, -10), -- east, faces west
	EVENTS = Vector3.new(-48, 0, -10), -- west, faces east
	CHEST = Vector3.new(40, 0, 34), -- south-east, faces the middle
	INCUBATOR = Vector3.new(-40, 0, 34), -- south-west, faces the middle
	WANDER_MIN = Vector3.new(-40, 0, -40),
	WANDER_MAX = Vector3.new(40, 0, 40),
	-- old practice field spot (practice is switched off, see Layout.Practice.enabled)
	PRACTICE_CENTER = Vector3.new(-36, 0, 42),
	PRACTICE_HALF = Vector3.new(20, 0, 12),
}
local LL = Layout.LobbyLocal
Layout.Lobby = {
	ORIGIN = LOBBY_ORIGIN,
	CENTER = LOBBY_ORIGIN,
	HALF = LL.HALF,
	ISLAND_HALF = LL.ISLAND_HALF,
	GROUND_Y = LOBBY_ORIGIN.Y, -- lobby floor height (the arena floor stays at Layout.GROUND_Y)
	SPAWN = LOBBY_ORIGIN + LL.SPAWN,
	CENTERPIECE = LOBBY_ORIGIN + Vector3.new(0, 0, -200), -- arrivals face north: statue, then the arena below
	STATUE = LOBBY_ORIGIN + LL.STATUE,
	SHOP = LOBBY_ORIGIN + LL.SHOP,
	EVENTS = LOBBY_ORIGIN + LL.EVENTS,
	CHEST = LOBBY_ORIGIN + LL.CHEST,
	INCUBATOR = LOBBY_ORIGIN + LL.INCUBATOR,
	PRACTICE_CENTER = LOBBY_ORIGIN + LL.PRACTICE_CENTER,
	PRACTICE_HALF = LL.PRACTICE_HALF,
	WANDER_MIN = LOBBY_ORIGIN + LL.WANDER_MIN,
	WANDER_MAX = LOBBY_ORIGIN + LL.WANDER_MAX,
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

-- ===== Map rotation =====
-- Every arena map has this same shape; only the field length (FIELD_HALF_X) changes. MapService
-- (server) swaps the map between matches and sets workspace attribute EOS_FieldHalfX; every copy of
-- this module (server and each client) follows it, updating Arena / Zones / ArenaBounds IN PLACE so
-- code holding these tables sees the new numbers.
Layout.DEFAULT_FIELD_HALF_X = A.FIELD_HALF_X
function Layout.setFieldHalfX(fx: number)
	A.FIELD_HALF_X = fx
	Layout.Zones.A.center = AC + Vector3.new(-(fx + A.ZONE_DEPTH / 2), 6, 0)
	Layout.Zones.B.center = AC + Vector3.new(fx + A.ZONE_DEPTH / 2, 6, 0)
	Layout.ArenaBounds.size = Vector3.new((fx + A.ZONE_DEPTH) * 2, 30, A.HALF_Z * 2)
end
pcall(function() -- (outside Roblox, e.g. Lune, there is no signal: the default map stays)
	local function follow()
		local v = workspace:GetAttribute("EOS_FieldHalfX")
		Layout.setFieldHalfX(if type(v) == "number" then v else Layout.DEFAULT_FIELD_HALF_X)
	end
	if workspace:GetAttribute("EOS_FieldHalfX") ~= nil then
		follow()
	end
	workspace:GetAttributeChangedSignal("EOS_FieldHalfX"):Connect(follow)
end)

-- Practice field pads (lobby)
local P = Layout.Lobby.PRACTICE_CENTER
local PH = Layout.Lobby.PRACTICE_HALF
Layout.Practice = {
	enabled = false, -- the practice field was removed from the lobby (Oct 2026); true + rebuild it to bring it back
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
