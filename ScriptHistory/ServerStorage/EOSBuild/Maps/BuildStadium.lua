--!nocheck
-- Egg Bowl Stadium (Oct 15 2026): a small football-style stadium. Field 192 long (farm 176).
-- NO cover: open turf, like the reference art (a Runner sprinting a golden egg across a lit field).
--   * mowed turf stripes, subtle yard lines every 20 studs with numbers (10..50..10), hash marks,
--     glowing cyan sidelines
--   * small bleachers along both long sides, five stepped rows, a blocky crowd (classic yellow heads)
--   * four tall light towers at the corners, panels of bulbs angled at the field
--   * yellow goalposts and a golden-egg trophy behind each safe zone, a scoreboard over the east end
-- Everything outside the fence is scenery; the play area is the shared ArenaFrame skeleton.
-- 16 Oct 2026: fitted to the lobby. The stadium is centred on LobbyProto (MapDefs.Stadium.CENTER)
-- and the north stand (the lobby side) is deeper: seven rows climb to a concourse deck, and the lobby
-- (lifted 12 studs by MapService on this map) becomes the upper deck above it, on navy columns.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggModel = require(ReplicatedStorage.EOS.Shared.EggModel)
local Kit = require(script.Parent.Parent.WorldKit)
local Frame = require(script.Parent.ArenaFrame)
local MapDefs = require(script.Parent.MapDefs)
local PAL = Kit.PAL

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local TURF, TURF_DARK = rgb(92, 190, 74), rgb(78, 172, 62)
local GRASS, GRASS2 = rgb(120, 206, 92), rgb(104, 190, 80)
local CONCRETE, CONCRETE2, CONCRETE3 = rgb(196, 200, 210), rgb(170, 174, 188), rgb(146, 150, 166)
local NAVY, NAVY2 = rgb(34, 52, 104), rgb(52, 76, 140)
local SEAT_A, SEAT_B = rgb(44, 112, 220), rgb(238, 242, 250)
local STEEL, STEEL2 = rgb(150, 156, 170), rgb(110, 116, 132)
local BULB, GOALPOST = rgb(255, 248, 214), rgb(255, 208, 40)
local NEON_LINE = rgb(90, 236, 255)

local THEME = {
	ground = GRASS, groundEdge = GRASS2,
	strata = { CONCRETE, CONCRETE2, CONCRETE3 },
	field = TURF, apron = rgb(70, 150, 60), line = PAL.white,
	flagPost = PAL.white, fencePost = NAVY, fenceRail = NAVY2,
	backWall = NAVY, backWallCap = NAVY2,
	plateauName = "Terrace", plateauTiers = { CONCRETE2, CONCRETE, CONCRETE }, plateauCap = GRASS,
}

-- crowd colours: shirts in the two team colours plus a few others, classic yellow / skin heads
local SHIRTS = { PAL.zoneA, PAL.zoneB, rgb(235, 60, 60), rgb(60, 180, 90), rgb(250, 250, 250), rgb(255, 200, 40), rgb(150, 90, 220) }
local HEADS = { rgb(255, 214, 40), rgb(255, 214, 40), rgb(234, 184, 146), rgb(160, 110, 80), rgb(255, 214, 40) }

return function(world: Instance, def)
	local rng = Random.new(9090)
	local arena, F = Frame.build(world, def, THEME, rng)
	local X, Z, OUT, HZ, FX = F.X, F.Z, F.OUT, F.HZ, F.FX
	local fen, isl = F.fence, F.island
	local scen = Kit.model(arena, "Scenery")
	local turf = Kit.model(arena, "TurfMarkings")

	-- ===== turf: mowed stripes, yard lines + numbers, hash marks, glowing sidelines =====
	-- (no checker on this field: the mow stripes are the pattern)
	local fieldPart = arena.Ground:FindFirstChild("Field")
	local checker = fieldPart and fieldPart:FindFirstChild("Checker")
	if checker then
		checker:Destroy()
	end
	local band = 10
	local i = 0
	for x = X - FX, X + FX - band, band do
		if i % 2 == 1 then
			Kit.box(turf, "MowStripe", x, x + band, 0.2, 0.205, Z - HZ, Z + HZ, TURF_DARK, { Pattern = "Universal", CanCollide = false, CastShadow = false })
		end
		i += 1
	end
	for k = -4, 4 do
		local x = X + k * 20
		if k ~= 0 then -- the centre line is the frame's own chalk line
			Kit.box(turf, "YardLine", x - 0.25, x + 0.25, 0.205, 0.24, Z - HZ + 3, Z + HZ - 3, PAL.white, { Pattern = "Smooth", CanCollide = false, CastShadow = false, Transparency = 0.35 })
		end
		local yard = 50 - math.abs(k) * 10
		for _, side in { -1, 1 } do
			local nz = Z + side * (HZ - 12)
			local num = Kit.box(turf, "YardNumber", x - 3, x + 3, 0.24, 0.26, nz - 6, nz + 6, PAL.white, { Pattern = "Smooth", CanCollide = false, Transparency = 1 })
			Kit.surfaceText(num, Enum.NormalId.Top, { { text = tostring(yard), size = 0.9, color = Color3.new(1, 1, 1) } }, { PixelsPerStud = 12 })
			-- read from the near sideline
			num.CFrame = CFrame.new(num.Position) * CFrame.Angles(0, math.rad(if side < 0 then 90 else -90), 0)
			for _, t in num:GetDescendants() do
				if t:IsA("TextLabel") then
					t.TextTransparency = 0.3
				end
			end
		end
	end
	-- hash marks: short ticks every 4 studs on two lines across the field
	for x = X - FX + 4, X + FX - 4, 4 do
		if (x - X) % 20 ~= 0 then
			for _, hz in { -HZ / 3, HZ / 3 } do
				Kit.box(turf, "Hash", x - 0.2, x + 0.2, 0.205, 0.23, Z + hz - 1, Z + hz + 1, PAL.white, { Pattern = "Smooth", CanCollide = false, CastShadow = false, Transparency = 0.45 })
			end
		end
	end
	for _, side in { -1, 1 } do
		local z = Z + side * HZ
		Kit.box(turf, "Sideline", X - OUT, X + OUT, 0.2, 0.3, z - side * 0.5 - 0.35, z - side * 0.5 + 0.35, NEON_LINE, { Pattern = "Smooth", CanCollide = false, CastShadow = false, Material = Enum.Material.Neon })
	end

	-- ===== bleachers along both long sides (seats facing the field) =====
	local stands = Kit.model(scen, "Stands")
	local crowd = Kit.model(scen, "Crowd")
	local ROWS, DEPTH, RISE = 5, 3.2, 2.2
	local sx0, sx1 = X - OUT + 4, X + OUT - 4
	local AISLES = { X - 60, X, X + 60 }
	local function inAisle(x)
		for _, a in AISLES do
			if math.abs(x - a) < 3 then
				return true
			end
		end
		return false
	end
	local LOBBY = MapDefs.LOBBY
	local lobbyZ0 = LOBBY.CENTER.Z - LOBBY.HALF -- the lobby's south face (the stand meets it)
	local lobbyX0, lobbyX1 = LOBBY.CENTER.X - LOBBY.HALF, LOBBY.CENTER.X + LOBBY.HALF
	local DECK_Y = LOBBY.TOP_Y - 0.1 -- concourse height: where the lobby top sits on the other maps
	local LIFT = def.LOBBY_LIFT or 0 -- the stadium lifts the lobby into an upper deck above the concourse
	local lobbyBottom = LOBBY.BOTTOM_Y + LIFT
	for _, side in { -1, 1 } do
		local z0 = (if side < 0 then fen.z0 else fen.z1) + side * 3 -- first row's front edge
		local function zr(k, d)
			return z0 + side * (k * DEPTH + d)
		end
		-- the lobby side gets the deep stand: rows climb to the deck height, bodies run down into the sea
		local north = side > 0 and lobbyZ0 > zr(ROWS, 0)
		local rows = if north then 7 else ROWS
		local rise = if north then (DECK_Y - 1) / rows else RISE
		local bodyY = if north then -14 else 0
		-- the stand body: one stepped block per row, then a back wall
		for k = 0, rows - 1 do
			local top = 1 + (k + 1) * rise
			local za, zb = zr(k, 0), zr(k, DEPTH)
			Kit.box(stands, "Row", sx0, sx1, bodyY, top, math.min(za, zb), math.max(za, zb), if k % 2 == 0 then CONCRETE else CONCRETE2, { Pattern = "Studs" })
			-- seat strips in alternating team colours (8-stud blocks), broken at the aisles
			local sa, sb = zr(k, 0.3), zr(k, 1.5)
			local seg = 0
			local x = sx0 + 0.5
			while x < sx1 - 0.5 do
				local x2 = math.min(x + 8, sx1 - 0.5)
				for _, a in AISLES do
					if a - 2.5 > x and a - 2.5 < x2 then
						x2 = a - 2.5
					end
				end
				if x2 - x > 0.5 then
					Kit.box(stands, "Seats", x, x2, top, top + 0.5, math.min(sa, sb), math.max(sa, sb), if (seg + k) % 2 == 0 then SEAT_A else SEAT_B, { Pattern = "Smooth" })
					seg += 1
				end
				x = x2
				if inAisle(x + 0.1) then
					x += 5
				end
			end
			-- fans on about a third of the seats
			for fx = sx0 + 1.2, sx1 - 1.2, 1.9 do
				if not inAisle(fx) and rng:NextNumber() < 0.34 then
					local cz = (sa + sb) / 2 + side * 0.4
					local shirt = SHIRTS[rng:NextInteger(1, #SHIRTS)]
					local fan = Kit.model(crowd, "Fan")
					Kit.brick(fan, "Body", Vector3.new(1.4, 1.5, 0.8), CFrame.new(fx, top + 0.5 + 0.75, cz), shirt, { Pattern = "Smooth", CanCollide = false })
					Kit.brick(fan, "Head", Vector3.new(1, 1, 1), CFrame.new(fx, top + 0.5 + 2, cz), HEADS[rng:NextInteger(1, #HEADS)], { Pattern = "Smooth", CanCollide = false })
					if rng:NextNumber() < 0.25 then -- cheering: arms up
						Kit.brick(fan, "Arms", Vector3.new(2, 0.4, 0.4), CFrame.new(fx, top + 0.5 + 2.9, cz), shirt, { Pattern = "Smooth", CanCollide = false })
					end
				end
			end
		end
		-- aisle steps (lighter) and the back wall with a navy cap
		for _, a in AISLES do
			for k = 0, rows - 1 do
				local za, zb = zr(k, 0), zr(k, DEPTH)
				Kit.box(stands, "Step", a - 2, a + 2, 1 + (k + 1) * rise, 1 + (k + 1) * rise + 0.2, math.min(za, zb), math.max(za, zb), CONCRETE3, { Pattern = "Universal" })
			end
		end
		-- a front rail along the first row
		Kit.box(stands, "FrontRail", sx0, sx1, 1, 3.4, math.min(z0, z0 + side * 0.5), math.max(z0, z0 + side * 0.5), NAVY2, { Pattern = "Weld" })
		if north then
			-- concourse deck from the top row back to the lobby's south face
			local dz0 = zr(rows, 0)
			local dz1 = lobbyZ0 - 0.02
			local deck = Kit.model(stands, "Concourse")
			Kit.box(deck, "Deck", sx0 - 1, sx1 + 1, bodyY, DECK_Y, dz0 - 0.0002, dz1, CONCRETE2, { Pattern = "Studs" })
			-- a walkway band along the front of the deck and a navy kerb under the top row's edge
			Kit.box(deck, "Walkway", sx0, sx1, DECK_Y, DECK_Y + 0.15, dz0 + 1, dz0 + 6, CONCRETE3, { Pattern = "Universal" })
			Kit.box(deck, "Fascia", sx0 - 1.3, sx1 + 1.3, bodyY, DECK_Y - 2, dz1 - 0.6, dz1, NAVY, { Pattern = "Studs" })
			-- back rails either side of the lobby, with EGG BOWL boards facing the field
			for _, seg in { { sx0 - 1, lobbyX0 - 0.6 }, { lobbyX1 + 0.6, sx1 + 1 } } do
				local a, b = seg[1], seg[2]
				if b - a > 4 then
					Kit.box(deck, "BackRail", a, b, DECK_Y, DECK_Y + 3.2, dz1 - 1, dz1, NAVY, { Pattern = "Weld" })
					Kit.box(deck, "BackRailCap", a - 0.2, b + 0.2, DECK_Y + 3.2, DECK_Y + 3.6, dz1 - 1.2, dz1 + 0.0002, NAVY2, { Pattern = "Weld" })
					local mid = (a + b) / 2
					local w = math.min(36, (b - a) - 8)
					local board = Kit.box(deck, "Banner", mid - w / 2, mid + w / 2, DECK_Y + 3.6, DECK_Y + 8.6, dz1 - 0.9, dz1 - 0.3, GOALPOST, { Pattern = "Smooth" })
					Kit.box(deck, "BannerFrame", mid - w / 2 - 0.4, mid + w / 2 + 0.4, DECK_Y + 3.6, DECK_Y + 9, dz1 - 0.3, dz1 + 0.0004, NAVY2, { Pattern = "Weld" })
					Kit.surfaceText(board, Enum.NormalId.Front, { { text = "EGG BOWL", size = 0.9, color = NAVY } }, { PixelsPerStud = 10 })
					-- lamp posts along the rail
					for lx = a + 6, b - 6, 24 do
						Kit.lamp(deck, Vector3.new(lx, DECK_Y, dz1 - 3))
					end
				end
			end
			-- short navy cheek walls where the deck meets the lobby's corners
			for _, ex in { lobbyX0 - 0.6, lobbyX1 + 0.6 } do
				Kit.box(deck, "LobbyCheek", ex - 0.6, ex + 0.6, DECK_Y, DECK_Y + 1.2, dz1 - 6, dz1, NAVY2, { Pattern = "Weld" })
			end
			-- the lobby is the upper deck: navy columns under it hold it up out of the sea
			if LIFT > 0 and lobbyBottom > bodyY then
				local cols = Kit.model(stands, "UpperDeckColumns")
				local cz0, cz1 = lobbyZ0 + 3, LOBBY.CENTER.Z + LOBBY.HALF - 3
				for _, cx in { lobbyX0 + 3, LOBBY.CENTER.X - 13, LOBBY.CENTER.X + 13, lobbyX1 - 3 } do
					for _, cz in { cz0, (cz0 + cz1) / 2, cz1 } do
						local c = Kit.model(cols, "Column")
						Kit.box(c, "Shaft", cx - 1.8, cx + 1.8, bodyY, lobbyBottom - 0.02, cz - 1.8, cz + 1.8, NAVY, { Pattern = "Studs" })
						Kit.box(c, "Capital", cx - 2.4, cx + 2.4, lobbyBottom - 1.4, lobbyBottom - 0.03, cz - 2.4, cz + 2.4, NAVY2, { Pattern = "Weld" })
					end
				end
			end
			-- end walls closing the stand + deck
			for _, ex in { sx0 - 1.6, sx1 + 1.6 } do
				Kit.box(stands, "EndWall", ex - 0.6, ex + 0.6, bodyY, DECK_Y + 3.6, z0, dz1, NAVY, { Pattern = "Studs" })
			end
			continue
		end
		local wa, wb = zr(ROWS, 0), zr(ROWS, 1.2)
		local wallTop = 1 + ROWS * RISE + 7
		Kit.box(stands, "BackWall", sx0 - 1, sx1 + 1, 0, wallTop, math.min(wa, wb), math.max(wa, wb), NAVY, { Pattern = "Studs" })
		Kit.box(stands, "BackWallCap", sx0 - 1.3, sx1 + 1.3, wallTop, wallTop + 0.6, math.min(wa, wb) - 0.3, math.max(wa, wb) + 0.3, NAVY2, { Pattern = "Studs" })
		-- end walls closing each stand
		for _, ex in { sx0 - 1, sx1 + 1 } do
			local zf, zb2 = z0, wb
			Kit.box(stands, "EndWall", ex - 0.6, ex + 0.6, 0, wallTop, math.min(zf, zb2), math.max(zf, zb2), NAVY, { Pattern = "Studs" })
		end
		-- banner along the back wall: EGG BOWL
		local bz = if side < 0 then math.max(wa, wb) else math.min(wa, wb)
		local banner = Kit.box(stands, "Banner", X - 40, X + 40, wallTop - 3.6, wallTop - 0.6, bz - side * 0.15 - 0.05, bz - side * 0.15 + 0.05, GOALPOST, { Pattern = "Smooth", CanCollide = false })
		Kit.surfaceText(banner, if side < 0 then Enum.NormalId.Back else Enum.NormalId.Front, {
			{ text = "EGG BOWL STADIUM", size = 0.9, color = NAVY },
		}, { PixelsPerStud = 10 })
	end

	-- ===== tall light towers at the four corners =====
	local lights = Kit.model(scen, "LightTowers")
	local TOWER_H = 46
	for _, sxs in { -1, 1 } do
		for _, szs in { -1, 1 } do
			local t = Kit.model(lights, "LightTower")
			local base = Vector3.new(X + sxs * (OUT + 14), 0, Z + szs * (HZ + 26))
			Kit.brick(t, "Footing", Vector3.new(5, 1.2, 5), CFrame.new(base + Vector3.new(0, 0.6, 0)), CONCRETE2, { Pattern = "Studs" })
			-- lattice: two posts with rungs
			for _, o in { -1.2, 1.2 } do
				Kit.brick(t, "Post", Vector3.new(0.7, TOWER_H, 0.7), CFrame.new(base + Vector3.new(o, TOWER_H / 2 + 1.2, 0)), STEEL, { Pattern = "Weld" })
			end
			for y = 4, TOWER_H - 2, 4 do
				Kit.brick(t, "Rung", Vector3.new(2.4, 0.3, 0.3), CFrame.new(base + Vector3.new(0, y, 0)), STEEL2, { Pattern = "Smooth" })
				Kit.brick(t, "Brace", Vector3.new(0.25, 4.6, 0.25), CFrame.new(base + Vector3.new(0, y + 2, 0)) * CFrame.Angles(0, 0, math.rad(if (y / 4) % 2 == 0 then 30 else -30)), STEEL2, { Pattern = "Smooth" })
			end
			-- the light panel, tipped down toward the middle of the field
			local headPos = base + Vector3.new(0, TOWER_H + 4, 0)
			local look = CFrame.lookAt(headPos, Vector3.new(X, 0, Z))
			local panel = CFrame.new(headPos) * CFrame.Angles(0, select(2, look:ToOrientation()), 0) * CFrame.Angles(math.rad(-25), 0, 0)
			Kit.brick(t, "Panel", Vector3.new(14, 8, 1), panel, STEEL2, { Pattern = "Studs" })
			Kit.brick(t, "PanelFrame", Vector3.new(14.6, 0.6, 1.4), panel * CFrame.new(0, 4.1, 0), STEEL, { Pattern = "Weld" })
			for r = 0, 2 do
				for c = 0, 4 do
							Kit.brick(t, "Bulb", Vector3.new(2, 1.8, 0.4), panel * CFrame.new(-5.2 + c * 2.6, -2.4 + r * 2.4, -0.6), BULB, { Pattern = "Smooth", CanCollide = false, Material = Enum.Material.Neon, CastShadow = false })
				end
			end
			local lamp = Kit.brick(t, "LightSource", Vector3.new(1, 1, 1), panel * CFrame.new(0, 0, -1), BULB, { Pattern = "Smooth", CanCollide = false, Transparency = 1 })
			local sl = Instance.new("SpotLight")
			sl.Face = Enum.NormalId.Front
			sl.Angle = 70
			sl.Range = 60
			sl.Brightness = 1.4
			sl.Color = BULB
			sl.Shadows = false
			sl.Parent = lamp
		end
	end

	-- ===== behind each safe zone: yellow goalposts and a golden-egg trophy =====
	for _, sx in { -1, 1 } do
		local gx = X + sx * (OUT + 13)
		local g = Kit.model(scen, "Goalpost")
		Kit.brick(g, "Base", Vector3.new(1.4, 9, 1.4), CFrame.new(gx, 4.5, Z), GOALPOST, { Pattern = "Smooth" })
		Kit.brick(g, "Crossbar", Vector3.new(1, 1, 22), CFrame.new(gx, 9, Z), GOALPOST, { Pattern = "Smooth" })
		for _, sz in { -1, 1 } do
			Kit.brick(g, "Upright", Vector3.new(1, 18, 1), CFrame.new(gx, 18, Z + sz * 10.5), GOALPOST, { Pattern = "Smooth" })
			Kit.brick(g, "Ribbon", Vector3.new(0.2, 2.4, 0.8), CFrame.new(gx, 27.6, Z + sz * 10.5), if sx < 0 then PAL.zoneA else PAL.zoneB, { Pattern = "Smooth", CanCollide = false })
		end
		local tx = X + sx * (OUT + 22)
		local trophy = Kit.model(scen, "EggTrophy")
		Kit.box(trophy, "Plinth", tx - 3, tx + 3, 0, 1.4, Z - 3, Z + 3, NAVY, { Pattern = "Studs" })
		Kit.box(trophy, "PlinthTop", tx - 2.2, tx + 2.2, 1.4, 1.9, Z - 2.2, Z + 2.2, GOALPOST, { Pattern = "Studs" })
		local egg = EggModel.build(4, false, 2.6)
		egg:PivotTo(CFrame.new(tx, 1.9, Z))
		egg.Parent = trophy
	end

	-- ===== scoreboard over the east end, facing the field =====
	local sb = Kit.model(scen, "Scoreboard")
	local bx = X + OUT + 30
	for _, sz in { -1, 1 } do
		Kit.brick(sb, "Leg", Vector3.new(1.4, 22, 1.4), CFrame.new(bx, 11, Z + sz * 12), STEEL, { Pattern = "Weld" })
	end
	local board = Kit.brick(sb, "Board", Vector3.new(1.4, 12, 30), CFrame.new(bx, 26, Z), NAVY, { Pattern = "Studs" })
	Kit.brick(sb, "BoardTrim", Vector3.new(1.8, 0.8, 31), CFrame.new(bx, 32.4, Z), GOALPOST, { Pattern = "Smooth" })
	Kit.surfaceText(board, Enum.NormalId.Left, {
		{ text = "EGG BOWL", size = 0.34, color = GOALPOST },
		{ text = "RUNNERS  vs  CATCHERS", size = 0.24, color = Color3.new(1, 1, 1) },
		{ text = "GO GO GO!", size = 0.26, color = NEON_LINE },
	}, { PixelsPerStud = 12 })

	-- ===== a few planters along the end strips so the island edge isn't bare =====
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local p = Frame.plateau(scen, Vector3.new(X + sx * (OUT + 26), 0, Z + sz * (HZ + 10)), Vector3.new(12, 3, 10), 2, rng, 0, THEME)
			local topY = p:GetAttribute("TopY")
			Kit.tree(scen, Vector3.new(X + sx * (OUT + 26), topY, Z + sz * (HZ + 10)), rng:NextNumber(9, 12), rng, GRASS)
		end
	end

	return arena
end
