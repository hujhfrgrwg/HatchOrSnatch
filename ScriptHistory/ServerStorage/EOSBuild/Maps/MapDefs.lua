--!nocheck
-- MapDefs: one entry per arena map. Every map keeps the same shape as Shared/Layout.Arena
-- (two safe strips on the X axis, field between them, same width), so MatchService, NpcService
-- and the zone checks work unchanged once Layout points at the chosen map's numbers.
-- Only the length (FIELD_HALF_X) and the decoration change.
local MapDefs = {}

local CENTER = Vector3.new(0, 0, -390) -- same spot as the current arena, so maps swap in place
-- 16 Oct 2026: the lobby (workspace.LobbyProto, 80x80, centre x 23.25 z -222.5, top y 16) never
-- moves. A map may sit at its own CENTER to line up with it (MapService tells Layout), and each map
-- paints the lobby: LOBBY_TOP = the field colour, LOBBY_BASE = the earth/stone just below it.
local LOBBY_X = 23.25
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
MapDefs.LOBBY = { CENTER = Vector3.new(LOBBY_X, 0, -222.5), HALF = 40, TOP_Y = 16, BOTTOM_Y = -21.25 }

MapDefs.Farm = { -- the current arena (BuildArena.luau), for reference
	name = "Farm", title = "Hatchery Farm",
	CENTER = CENTER, FIELD_HALF_X = 88, ZONE_DEPTH = 24, HALF_Z = 70, WALL_HEIGHT = 40,
	LOBBY_TOP = rgb(117, 203, 65), LOBBY_BASE = rgb(236, 142, 112),
}
MapDefs.SunnyCove = {
	name = "SunnyCove", title = "Sunny Cove",
	CENTER = CENTER, FIELD_HALF_X = 100, ZONE_DEPTH = 24, HALF_Z = 70, WALL_HEIGHT = 40,
	LOBBY_TOP = rgb(250, 232, 190), LOBBY_BASE = rgb(226, 180, 128), -- set by hand in Studio
}
MapDefs.FrostyPass = {
	name = "FrostyPass", title = "Frosty Pass",
	-- slid east so the ice-fishing cabin (field centre) lines up with the middle of the lobby
	CENTER = Vector3.new(LOBBY_X, 0, -390), FIELD_HALF_X = 106, ZONE_DEPTH = 24, HALF_Z = 70, WALL_HEIGHT = 40,
	LOBBY_TOP = rgb(234, 243, 254), LOBBY_BASE = rgb(156, 166, 226),
}

MapDefs.Stadium = {
	name = "Stadium", title = "Egg Bowl Stadium",
	-- centred on the lobby: the north stand climbs up to a concourse that meets the lobby's south face
	CENTER = Vector3.new(LOBBY_X, 0, -390), FIELD_HALF_X = 96, ZONE_DEPTH = 24, HALF_Z = 70, WALL_HEIGHT = 40,
	-- the lobby is lifted 12 studs to be the stadium's upper deck: concrete top like the seat rows, navy
	-- base like the stand walls, held up by navy columns (part of the stadium) above the concourse
	LOBBY_TOP = rgb(196, 200, 210), LOBBY_BASE = rgb(34, 52, 104), LOBBY_LIFT = 12,
}

MapDefs.Graveyard = { -- HOS-MAP-001 (Matthew, 17 Oct): halloween arena, Stadium-sized, no cover
	name = "Graveyard", title = "Haunted Graveyard",
	CENTER = Vector3.new(LOBBY_X, 0, -390), FIELD_HALF_X = 96, ZONE_DEPTH = 24, HALF_Z = 70, WALL_HEIGHT = 40,
	LOBBY_TOP = rgb(88, 62, 128), LOBBY_BASE = rgb(92, 72, 128),
}

-- Keep clear for gameplay (see Layout.catcherSpawns): catchers spawn at x in {-12, 0, 12},
-- |z| 28..60, and the centre structure must stay inside |z| < 16.
MapDefs.CATCHER_LANE = { halfX = 16, z0 = 24, z1 = 64 }

return MapDefs
