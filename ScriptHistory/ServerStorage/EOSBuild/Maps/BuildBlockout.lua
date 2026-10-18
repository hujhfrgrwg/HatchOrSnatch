--!nocheck
-- BuildBlockout: flat-colour placeholder volumes for a map layout (studify blockout checkpoint).
-- Every block is named BLOCKOUT_<what it becomes>. Positions are relative to the map centre.
local Kit = require(script.Parent.Parent.WorldKit)
local PAL = Kit.PAL

local THEMES = {
	Farm = { ground = PAL.grass, field = PAL.grass:Lerp(PAL.leaf3, 0.25), fence = PAL.wood, hill = PAL.dirt },
	SunnyCove = { ground = PAL.sand, field = PAL.sand:Lerp(PAL.white, 0.25), fence = PAL.wood, hill = PAL.sand:Lerp(PAL.dirt, 0.35) },
	FrostyPass = { ground = PAL.white, field = Color3.fromRGB(226, 240, 255), fence = PAL.wood2, hill = PAL.stone },
}

-- the juke + scenery plan per map: { name, x, z, sizeX, height, sizeZ, color }
local PLANS = {
	Farm = {
		{ "Coop", 0, 0, 18, 14, 24, PAL.red },
		{ "HayCorner", -44, -40, 10, 6, 10, PAL.hay }, { "HayCorner", 44, -40, 10, 6, 10, PAL.hay },
		{ "HayCorner", -44, 40, 10, 6, 10, PAL.hay }, { "HayCorner", 44, 40, 10, 6, 10, PAL.hay },
		{ "Planter", -64, 0, 6, 6, 20, PAL.leaf2 }, { "Planter", 64, 0, 6, 6, 20, PAL.leaf2 },
	},
	SunnyCove = { -- no cover: bare sand floor
		{ "Lighthouse", 30, -104, 12, 46, 12, PAL.white },
		{ "Boardwalk", -40, 98, 60, 2, 10, PAL.wood },
		{ "Dunes_N", -60, -98, 70, 8, 16, PAL.sand:Lerp(PAL.dirt, 0.35) },
		{ "Dunes_S", 70, 98, 60, 8, 16, PAL.sand:Lerp(PAL.dirt, 0.35) },
		{ "PalmCluster_W", -150, 0, 20, 16, 60, PAL.leaf },
		{ "PalmCluster_E", 150, 0, 20, 16, 60, PAL.leaf },
	},
	FrostyPass = {
		-- 3 pieces of cover, point-symmetric so both crossing directions play the same
		{ "IceFishingCabin", 0, 0, 18, 15, 24, PAL.redDark },
		{ "IceWallCorner", -52, -40, 11, 6, 11, Color3.fromRGB(150, 210, 245) },
		{ "IceWallCorner", 52, 40, 11, 6, 11, Color3.fromRGB(150, 210, 245) },
		-- scenery outside the fence
		{ "Mountains_N", 0, -112, 200, 40, 24, PAL.stone },
		{ "SkiLodge", -90, -100, 26, 18, 16, PAL.wood },
		{ "FrozenPond_S", 30, 100, 70, 1, 14, Color3.fromRGB(170, 225, 250) },
		{ "PineForest_S", -80, 100, 60, 18, 14, PAL.leaf2 },
		{ "PineForest_W", -156, 0, 20, 18, 70, PAL.leaf2 },
		{ "PineForest_E", 156, 0, 20, 18, 70, PAL.leaf2 },
	},
}

return function(parent: Instance, def): Model
	local th = THEMES[def.name]
	local C = def.CENTER
	local X, Z = C.X, C.Z
	local FX, HZ, ZD = def.FIELD_HALF_X, def.HALF_Z, def.ZONE_DEPTH
	local OUT = FX + ZD
	local root = Kit.model(parent, "EOS_Map_" .. def.name)
	root:SetAttribute("FIELD_HALF_X", FX)
	root:SetAttribute("ZONE_DEPTH", ZD)
	root:SetAttribute("HALF_Z", HZ)
	local bo = Kit.model(root, "Blockout")
	local function b(name, x0, x1, y0, y1, z0, z1, col)
		return Kit.box(bo, "BLOCKOUT_" .. name, X + x0, X + x1, y0, y1, Z + z0, Z + z1, col, { Pattern = "Smooth" })
	end
	-- ground island, field, zones, gates, fence line
	b("Island", -(OUT + 40), OUT + 40, -6, -0.0001, -(HZ + 40), HZ + 40, th.ground)
	b("Field", -FX, FX, 0, 0.2, -HZ, HZ, th.field)
	b("ZoneA", -OUT, -FX, 0, 0.25, -HZ, HZ, PAL.zoneA)
	b("ZoneB", FX, OUT, 0, 0.25, -HZ, HZ, PAL.zoneB)
	b("GateA", -FX - 0.3, -FX + 0.3, 0, 12, -HZ, HZ, PAL.zoneA:Lerp(PAL.white, 0.5))
	b("GateB", FX - 0.3, FX + 0.3, 0, 12, -HZ, HZ, PAL.zoneB:Lerp(PAL.white, 0.5))
	b("CenterLine", -0.4, 0.4, 0.2, 0.3, -HZ, HZ, PAL.white)
	local fx, fz = OUT + 6, HZ + 4
	b("Fence_N", -fx, fx, 0, 3.6, -fz - 0.5, -fz + 0.5, th.fence)
	b("Fence_S", -fx, fx, 0, 3.6, fz - 0.5, fz + 0.5, th.fence)
	b("Fence_W", -fx - 0.5, -fx + 0.5, 0, 3.6, -fz, fz, th.fence)
	b("Fence_E", fx - 0.5, fx + 0.5, 0, 3.6, -fz, fz, th.fence)
	for _, it in PLANS[def.name] do
		local name, x, z, sx, h, sz, col = table.unpack(it)
		b(name, x - sx / 2, x + sx / 2, 0.2, 0.2 + h, z - sz / 2, z + sz / 2, col)
	end
	return root
end
