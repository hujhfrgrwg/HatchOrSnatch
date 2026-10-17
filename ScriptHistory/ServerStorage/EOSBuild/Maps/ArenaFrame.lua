--!nocheck
-- ArenaFrame: the gameplay skeleton every arena map shares, lifted from BuildArena so new maps
-- behave exactly like the farm: themed island ground, field, safe-zone pads (Attr Side), gates
-- (tag/collision group EOS_Gate), Catcher-only walls (EOS_CatcherWall), chalk lines, floor
-- lettering, flags, back walls with SIDE boards, a fence ring and the invisible ArenaWalls.
-- Hierarchy matches BuildArena (Arena/SafeZones/ZoneA...) so WorldFX finds the zones.
--
-- frame(parent, def, theme, rng) -> arena model, info { X, Z, FX, HZ, ZD, OUT, fence = {x0,x1,z0,z1}, island = {...} }
local Kit = require(script.Parent.Parent.WorldKit)
local PAL = Kit.PAL

local Frame = {}

-- Floating-island ground in theme colours (Kit.island with a palette): cap on top (y = 0),
-- three strata stepping inward, stepped edge nibs so the outline is never one rectangle.
function Frame.island(parent, x0, x1, z0, z1, rng, th)
	local m = Kit.model(parent, "Island")
	local top = Kit.box(m, "GroundTop", x0, x1, -2, 0, z0, z1, th.ground, { Pattern = "Universal" })
	Kit.checker(top, 8, 0.88)
	Kit.box(m, "Strata1", x0 + 0.6, x1 - 0.6, -6, -2.0001, z0 + 0.6, z1 - 0.6, th.strata[1], { Pattern = "Studs" })
	Kit.box(m, "Strata2", x0 + 3, x1 - 3, -11, -6.0001, z0 + 3, z1 - 3, th.strata[2], { Pattern = "Studs" })
	Kit.box(m, "Strata3", x0 + 7, x1 - 7, -16, -11.0001, z0 + 7, z1 - 7, th.strata[3], { Pattern = "Studs" })
	local function nibs(ax, fixed, from, to, outward)
		local pos = from + rng:NextNumber(2, 8)
		while pos < to - 6 do
			local len = rng:NextNumber(6, 16)
			local out = rng:NextNumber(2, 5)
			local depthBelow = rng:NextNumber(4, 9)
			local a, b = pos, math.min(pos + len, to - 2)
			local o0, o1 = fixed - (if outward > 0 then 0.5 else -0.5), fixed + outward * out
			local lo, hi = math.min(o0, o1), math.max(o0, o1)
			local drop = if rng:NextNumber() < 0.3 then 0.4 else 0
			if ax == "x" then
				Kit.box(m, "NibTop", a, b, -2 + 0.0003, -0.0003 - drop, lo, hi, th.groundEdge, { Pattern = "Universal" })
				Kit.box(m, "NibBody", a + 0.5, b - 0.5, -2 - depthBelow, -2, lo + (if outward > 0 then 0 else 0.6), hi - (if outward > 0 then 0.6 else 0), th.strata[1], { Pattern = "Studs" })
			else
				Kit.box(m, "NibTop", lo, hi, -2 + 0.0003, -0.0003 - drop, a, b, th.groundEdge, { Pattern = "Universal" })
				Kit.box(m, "NibBody", lo + (if outward > 0 then 0 else 0.6), hi - (if outward > 0 then 0.6 else 0), -2 - depthBelow, -2, a + 0.5, b - 0.5, th.strata[1], { Pattern = "Studs" })
			end
			pos = b + rng:NextNumber(3, 10)
		end
	end
	if not th.openNorth then -- (the lobby keeps its north edge clean: it is the spectator rail)
		nibs("x", z0, x0, x1, -1)
	end
	nibs("x", z1, x0, x1, 1)
	nibs("z", x0, z0, z1, -1)
	nibs("z", x1, z0, z1, 1)
	return top
end

-- Themed plateau (barrier / scenery mass): stacked shrinking tiers with overhanging caps.
function Frame.plateau(parent, center, size, tiers, rng, yaw, th)
	local m = Kit.model(parent, th.plateauName or "Plateau")
	local rot = CFrame.Angles(0, math.rad(yaw or 0), 0)
	local y = center.Y
	local w, d = size.X, size.Z
	local tierH = size.Y / tiers
	for i = 1, tiers do
		local off = Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
		local body = CFrame.new(center.X, y + tierH / 2, center.Z) * rot * CFrame.new(off)
		local col = th.plateauTiers[math.min(i, #th.plateauTiers)]
		Kit.brick(m, "Tier" .. i, Vector3.new(w, tierH, d), body, col, { Pattern = "Studs" })
		local cap = Kit.brick(m, "Cap" .. i, Vector3.new(w + 1.6, 1.4, d + 1.6), CFrame.new(center.X, y + tierH + 0.7, center.Z) * rot * CFrame.new(off), th.plateauCap, { Pattern = "Universal" })
		Kit.checker(cap, 8, 0.9)
		Kit.brick(m, "Nib" .. i, Vector3.new(4, tierH * 0.7, 3), body * CFrame.new(w / 2 - 1, -tierH * 0.15, d / 4), col, { Pattern = "Studs" })
		y += tierH
		w *= rng:NextNumber(0.62, 0.78)
		d *= rng:NextNumber(0.62, 0.78)
	end
	m:SetAttribute("TopY", y + 1.4)
	return m
end

function Frame.build(parent, def, th, rng)
	local C = def.CENTER
	local X, Z = C.X, C.Z
	local FX, HZ, ZD = def.FIELD_HALF_X, def.HALF_Z, def.ZONE_DEPTH
	local OUT = FX + ZD
	local arena = Kit.model(parent, "Arena_" .. def.name)
	arena:SetAttribute("Map", def.name)
	arena:SetAttribute("MapTitle", def.title)
	arena:SetAttribute("FIELD_HALF_X", FX)
	arena:SetAttribute("ZONE_DEPTH", ZD)
	arena:SetAttribute("HALF_Z", HZ)
	arena:SetAttribute("WALL_HEIGHT", def.WALL_HEIGHT)
	arena:SetAttribute("CENTER", C) -- MapService points Layout here (maps can sit off the default centre)
	if def.LOBBY_TOP then
		arena:SetAttribute("LobbyTop", def.LOBBY_TOP) -- LobbyProto colours while this map is live
		arena:SetAttribute("LobbyBase", def.LOBBY_BASE)
		arena:SetAttribute("LobbyLift", def.LOBBY_LIFT or 0)
	end

	-- ground
	local ground = Kit.model(arena, "Ground")
	local ix, iz = OUT + 40, HZ + 36
	Frame.island(ground, X - ix, X + ix, Z - iz, Z + iz, rng, th)
	local field = Kit.box(ground, "Field", X - FX, X + FX, 0, 0.2, Z - HZ, Z + HZ, th.field, { Pattern = "Universal" })
	Kit.checker(field, 12, 0.86)
	Kit.box(ground, "ApronN", X - OUT - 2, X + OUT + 2, 0, 0.19, Z - HZ - 4, Z - HZ, th.apron, { Pattern = "Universal" })
	Kit.box(ground, "ApronS", X - OUT - 2, X + OUT + 2, 0, 0.19, Z + HZ, Z + HZ + 4, th.apron, { Pattern = "Universal" })

	-- chalk lines
	local lines = Kit.model(arena, "ChalkLines")
	for _, sx in ipairs({ -1, 1 }) do
		Kit.box(lines, "ZoneEdge", X + sx * FX - 0.6, X + sx * FX + 0.6, 0.2, 0.26, Z - HZ, Z + HZ, th.line, { Pattern = "Smooth", CanCollide = false })
	end
	Kit.box(lines, "CenterLine", X - 0.4, X + 0.4, 0.2, 0.25, Z - HZ, Z + HZ, th.line:Lerp(th.field, 0.35), { Pattern = "Smooth", CanCollide = false })

	-- safe zones (identical gameplay pieces to BuildArena)
	local zones = Kit.model(arena, "SafeZones")
	local function zone(side, sx, color)
		local zm = Kit.model(zones, "Zone" .. side)
		local x0, x1 = if sx < 0 then X - OUT else X + FX, if sx < 0 then X - FX else X + OUT
		Kit.box(zm, "Pad", x0, x1, 0, 0.2, Z - HZ, Z + HZ, color, { Pattern = "Studs", Attrs = { Side = side } })
		for k = -3, 3 do
			Kit.box(zm, "Stripe", x0 + 1, x1 - 1, 0.2, 0.26, Z + k * 18 - 2, Z + k * 18 + 2, color:Lerp(PAL.white, 0.45), { Pattern = "Smooth", CanCollide = false })
		end
		local sign = Kit.box(zm, "FloorSign", x0 + 2, x1 - 2, 0.26, 0.3, Z - 26, Z + 26, color, { Pattern = "Smooth", CanCollide = false, Transparency = 1 })
		Kit.surfaceText(sign, Enum.NormalId.Top, {
			{ text = "SAFE ZONE " .. side, size = 0.6 },
			{ text = "CROSS HERE WITH YOUR EGG", size = 0.3, color = PAL.cream },
		}, { PixelsPerStud = 20 })
		if sx > 0 then
			sign.CFrame = CFrame.new(sign.Position) * CFrame.Angles(0, math.rad(180), 0)
		end
		for row = -2, 2 do
			local cz = Z + row * 28 + 9
			for step = 0, 2 do
				local w = 7 - step * 2.4
				local px = (if sx < 0 then x1 - 3 - step * 1.4 else x0 + 3 + step * 1.4)
				Kit.box(zm, "Chevron", px - 0.7, px + 0.7, 0.2, 0.27, cz - w / 2, cz + w / 2, PAL.white, { Pattern = "Smooth", CanCollide = false })
			end
		end
		local gx = X + sx * FX
		Kit.box(zm, "Gate", gx - 0.25, gx + 0.25, 0, 12, Z - HZ, Z + HZ, color:Lerp(PAL.white, 0.3), { Pattern = "Smooth", Transparency = 1, CastShadow = false, Tags = { "EOS_Gate" }, CollisionGroup = "EOS_Gate", CanQuery = false })
		local wx0 = if sx < 0 then gx - 1.5 else gx
		local wx1 = if sx < 0 then gx else gx + 1.5
		Kit.box(zm, "CatcherWall", wx0, wx1, 0, def.WALL_HEIGHT, Z - HZ, Z + HZ, PAL.red, { Pattern = "Smooth", Transparency = 1, CastShadow = false, CanQuery = false, Tags = { "EOS_CatcherWall" }, CollisionGroup = "EOS_CatcherWall" })
		for _, sz in ipairs({ -1, 1 }) do
			Kit.brick(zm, "FlagPost", Vector3.new(1.2, 14, 1.2), CFrame.new(gx, 7, Z + sz * (HZ + 1.5)), th.flagPost, { Pattern = "Weld" })
			Kit.brick(zm, "Flag", Vector3.new(0.3, 3, 5), CFrame.new(gx, 12, Z + sz * (HZ + 1.5) - sz * 3), color, { Pattern = "Studs" })
		end
		-- back wall behind the zone (theme: hedge / dune / snowbank) + SIDE board
		local bx0 = if sx < 0 then X - OUT - 4 else X + OUT
		local bx1 = bx0 + 4
		Kit.box(zm, "BackWall", bx0, bx1, 0, 4, Z - HZ - 2, Z + HZ + 2, th.backWall, { Pattern = "Studs" })
		Kit.box(zm, "BackWallCap", bx0 - 0.3, bx1 + 0.3, 4, 4.8, Z - HZ - 2.3, Z + HZ + 2.3, th.backWallCap, { Pattern = "Studs" })
		local board = Kit.brick(zm, "SideBoard", Vector3.new(1, 10, 34), CFrame.new((bx0 + bx1) / 2, 10, Z), color, { Pattern = "Weld" })
		Kit.surfaceText(board, if sx < 0 then Enum.NormalId.Right else Enum.NormalId.Left, {
			{ text = "SIDE " .. side, size = 0.62 },
			{ text = "SAFE", size = 0.3, color = PAL.cream },
		}, { PixelsPerStud = 16 })
		for _, sz in ipairs({ -1, 1 }) do
			Kit.brick(zm, "BoardLeg", Vector3.new(1.2, 6, 1.2), CFrame.new((bx0 + bx1) / 2, 3, Z + sz * 14), th.fenceRail, { Pattern = "Weld" })
		end
		-- subtle zones (developer, Oct 15): no floor lettering, stripes, chevrons or SIDE board, and the pad
		-- is muted toward the field colour so the ends don't read as flashy touchdown zones
		for _, d in ipairs(zm:GetChildren()) do
			if d.Name == "Stripe" or d.Name == "FloorSign" or d.Name == "Chevron" or d.Name == "SideBoard" or d.Name == "BoardLeg" then
				d:Destroy()
			end
		end
		local padPart = zm:FindFirstChild("Pad")
		if padPart then
			padPart.Color = color:Lerp(th.field, 0.55)
		end
	end
	zone("A", -1, PAL.zoneA)
	zone("B", 1, PAL.zoneB)

	-- perimeter fence + invisible walls
	local per = Kit.model(arena, "Perimeter")
	local fx0, fx1, fz0, fz1 = X - OUT - 6, X + OUT + 6, Z - HZ - 4, Z + HZ + 4
	local fopts = { spacing = 7, postColor = th.fencePost, railColor = th.fenceRail }
	local fences = {
		Kit.fence(per, Vector3.new(fx0, 0, fz0), Vector3.new(fx1, 0, fz0), rng, fopts),
		Kit.fence(per, Vector3.new(fx0, 0, fz1), Vector3.new(fx1, 0, fz1), rng, fopts),
		Kit.fence(per, Vector3.new(fx0, 0, fz0), Vector3.new(fx0, 0, fz1), rng, fopts),
		Kit.fence(per, Vector3.new(fx1, 0, fz0), Vector3.new(fx1, 0, fz1), rng, fopts),
	}
	if th.fencePostCap then
		-- e.g. snow caps sitting on every post top
		for _, f in fences do
			for _, p in f:GetChildren() do
				if p.Name == "Post" then
					local top = p.CFrame * CFrame.new(0, p.Size.Y / 2 + 0.2, 0)
					Kit.brick(f, "PostCap", Vector3.new(1.3, 0.4, 1.3), top, th.fencePostCap, { Pattern = "Universal" })
				end
			end
		end
	end
	Kit.boundary(per, fx0 + 0.6, fx1 - 0.6, fz0 + 0.6, fz1 - 0.6, def.WALL_HEIGHT, { Name = "ArenaWalls" })

	return arena, {
		X = X, Z = Z, FX = FX, HZ = HZ, ZD = ZD, OUT = OUT,
		fence = { x0 = fx0, x1 = fx1, z0 = fz0, z1 = fz1 },
		island = { x0 = X - ix, x1 = X + ix, z0 = Z - iz, z1 = Z + iz },
	}
end

return Frame
