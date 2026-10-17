--!nocheck
-- BuildLobby (Oct 2026, v4): a floating lobby island right beside the arena, raised 55 studs, with
-- OPEN edges (invisible safety walls + a low kerb only) so people in the lobby can look down and
-- watch the match. Styled on the toolkit's hub references: lime ground with grass patches,
-- lavender tile roads, coral-pink wood, candy accents.
--   north edge (faces the arena): spectator terrace, bleachers, coin binoculars, team flags
--   middle: diving-catch statue fountain; spawn just south of it
--   east: shop stall · west: event board · south-west: incubator · south-east: treasure chest
--   south edge: 4 swivelling leaderboards facing north
-- Built in Layout.LobbyLocal coordinates, then moved to Layout.Lobby.ORIGIN.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.EOS.Shared
local Layout = require(Shared.Layout)
local TierConfig = require(Shared.TierConfig)
local Kit = require(script.Parent.WorldKit)
local Props = require(script.Parent.LobbyProps)
local Frame = require(script.Parent.Maps.ArenaFrame)
local PAL = Kit.PAL
local REF = Props.REF

local function frame(x: number, z: number, face: Vector3): CFrame
	local f = Vector3.new(face.X, 0, face.Z).Unit
	return CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + f)
end

local ISLAND_THEME = { ground = REF.lime, groundEdge = REF.limeLight, strata = REF.rose, openNorth = true }
local LEAVES = { REF.lime, REF.limeDark, Color3.fromRGB(128, 218, 66) }

return function(world: Instance)
	local rng = Random.new(780)
	local L = Layout.LobbyLocal
	local lobby = Kit.model(world, "Lobby")
	local H, IH = L.HALF.X, L.ISLAND_HALF
	local SC, S = L.STATUE, L.SPAWN
	local TZ = L.TERRACE_Z

	-- ===== floating island: ground, strata, hanging rock underneath (seen from the arena) =====
	local ground = Kit.model(lobby, "Ground")
	Frame.island(ground, -IH, IH, -H - 1, IH, rng, ISLAND_THEME) -- north edge flush with the kerb: clear view down
	local under = Kit.model(ground, "Underside")
	for i, u in { { -38, 6, 26, 22 }, { 30, 0, 30, 20 }, { -6, 26, 40, 30 }, { 34, 40, 24, 20 }, { -36, 42, 26, 18 } } do -- south half only: the north half overhangs the arena scenery
		local y = -16
		local w, d = u[3], u[4]
		for k = 1, 3 do
			local h = 4 + k
			Kit.brick(under, "Hang", Vector3.new(w, h, d), CFrame.new(u[1] + rng:NextNumber(-2, 2), y - h / 2 + 0.2, u[2] + rng:NextNumber(-2, 2)) * CFrame.Angles(0, math.rad((i + k) % 3 * 15), 0), REF.rose[math.min(3, k)], { Pattern = "Studs" })
			y -= h - 0.2
			w *= 0.62
			d *= 0.62
		end
		Kit.brick(under, "HangRock", Vector3.new(w * 0.9, 2.4, d * 0.9), CFrame.new(u[1], y - 1, u[2]), REF.periDark, { Pattern = "Studs" })
	end
	-- invisible safety walls and a low kerb: nothing blocks the view
	Kit.boundary(lobby, -H, H, -H, H, 40, { Name = "LobbyWalls" })
	local kerb = Kit.model(lobby, "Kerb")
	Kit.box(kerb, "N", -H - 0.8, H + 0.8, 0, 0.8, -H - 0.8, -H, REF.periDark, { Pattern = "Studs" })
	Kit.box(kerb, "S", -H - 0.8, H + 0.8, 0, 0.8, H, H + 0.8, REF.periDark, { Pattern = "Studs" })
	Kit.box(kerb, "W", -H - 0.8, -H, 0, 0.8, -H, H, REF.periDark, { Pattern = "Studs" })
	Kit.box(kerb, "E", H, H + 0.8, 0, 0.8, -H, H, REF.periDark, { Pattern = "Studs" })

	-- ===== north edge: spectator terrace facing the arena =====
	local terrace = Kit.model(lobby, "SpectatorTerrace")
	Props.tiles(terrace, "TerraceTiles", -40, 40, -H, TZ + 4, true, REF.peri, REF.periLight, rng, 0.6)
	-- bleachers: three stepped rows rising away from the edge, aisle in the middle
	for k = 0, 2 do
		local z0 = TZ + 6 + k * 3
		local top = 1 + k
		for _, seg in { { -34, -5 }, { 5, 34 } } do
			Kit.box(terrace, "Riser", seg[1], seg[2], 0, top, z0, z0 + 3, if k % 2 == 0 then REF.peri else REF.periDark, { Pattern = "Studs" })
			Kit.box(terrace, "Seat", seg[1] - 0.2, seg[2] + 0.2, top, top + 0.35, z0 - 0.2, z0 + 1.4, REF.coral, { Pattern = "Weld" })
		end
	end
	-- coin binoculars along the edge, tipped down at the field
	for _, bx in { -30, -12, 12, 30 } do
		local b = Kit.model(terrace, "Binoculars")
		local cf = CFrame.new(bx, 0, -H + 2.5)
		Kit.brick(b, "Foot", Vector3.new(1.8, 0.4, 1.8), cf * CFrame.new(0, 0.5, 0), REF.periDark, { Pattern = "Weld" })
		Kit.brick(b, "Post", Vector3.new(0.6, 3.6, 0.6), cf * CFrame.new(0, 2.5, 0), REF.periDark, { Pattern = "Weld" })
		local head = cf * CFrame.new(0, 4.8, 0) * CFrame.Angles(math.rad(-15), 0, 0)
		Kit.brick(b, "Head", Vector3.new(2.4, 1.4, 1.6), head, PAL.blue, { Pattern = "Studs" })
		for _, ex in { -0.6, 0.6 } do
			Kit.brick(b, "Lens", Vector3.new(0.8, 0.8, 0.6), head * CFrame.new(ex, 0.1, -1.0), Props.GOLD, { Pattern = "Smooth" })
			Kit.brick(b, "Eyepiece", Vector3.new(0.7, 0.7, 0.4), head * CFrame.new(ex, 0.1, 0.95), PAL.ink, { Pattern = "Smooth" })
		end
		Kit.brick(b, "CoinSlot", Vector3.new(0.8, 0.8, 0.3), cf * CFrame.new(0, 3.4, 0.4), Props.GOLD, { Pattern = "Smooth" })
	end
	-- team flags at the terrace corners (Side A blue, Side B orange)
	for _, f in { { -38, PAL.zoneA }, { 38, PAL.zoneB } } do
		local fl = Kit.model(terrace, "Flag")
		Kit.brick(fl, "Pole", Vector3.new(0.6, 14, 0.6), CFrame.new(f[1], 7, TZ - 6), PAL.white, { Pattern = "Smooth" })
		Kit.brick(fl, "Cloth", Vector3.new(0.3, 3.4, 5.4), CFrame.new(f[1], 12, TZ - 6 - 2.9), f[2], { Pattern = "Studs" })
		Kit.brick(fl, "Base", Vector3.new(2, 0.8, 2), CFrame.new(f[1], 0.7, TZ - 6), REF.periDark, { Pattern = "Weld" })
	end
	local anchor = Kit.brick(terrace, "SignAnchor", Vector3.new(1, 1, 1), CFrame.new(0, 9, -H + 3), PAL.white, { Transparency = 1, CanQuery = false, CastShadow = false })
	anchor.CanCollide = false
	Kit.floatingText(anchor, "WATCH THE MATCH", PAL.gold, 30, 0)

	-- ===== lavender tile roads + plaza =====
	local roads = Kit.model(lobby, "Roads")
	Props.tiles(roads, "Plaza", -16, 16, SC.Z - 16, SC.Z + 16, true, REF.peri, REF.periLight, rng, 0.8)
	Props.tiles(roads, "RoadNorth", -6, 6, TZ + 4, SC.Z - 16, false, REF.peri, REF.periLight, rng, 0)
	Props.tiles(roads, "RoadSouth", -6, 6, SC.Z + 16, S.Z - 8, false, REF.peri, REF.periLight, rng, 0)
	Props.tiles(roads, "RoadBoards", -6, 6, S.Z + 8, L.BOARDS_Z - 4, false, REF.peri, REF.periLight, rng, 0)
	Props.tiles(roads, "RoadEast", 16, L.SHOP.X - 8, L.SHOP.Z - 6, L.SHOP.Z + 6, true, REF.peri, REF.periLight, rng, 0.6)
	Props.tiles(roads, "RoadWest", L.EVENTS.X + 4, -16, L.EVENTS.Z - 6, L.EVENTS.Z + 6, true, REF.peri, REF.periLight, rng, 0.6)
	local steps = Kit.model(lobby, "SteppingTiles")
	local function stepRun(a: Vector3, b: Vector3, n)
		for k = 0, n - 1 do
			local t = (k + 0.5) / n
			local p = a:Lerp(b, t) + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
			local sz = rng:NextNumber(2.4, 3.6)
			Kit.brick(steps, "StepTile", Vector3.new(sz, 0.3 + 0.0002 * (k % 2), sz * rng:NextNumber(0.8, 1.2)), CFrame.new(p.X, 0.15, p.Z) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 2) * 15), 0), if k % 2 == 0 then REF.salmonTile else REF.coral, { Pattern = "Universal" })
		end
	end
	stepRun(Vector3.new(9, 0, S.Z), Vector3.new(L.CHEST.X - 9, 0, L.CHEST.Z - 6), 6)
	stepRun(Vector3.new(-9, 0, S.Z), Vector3.new(L.INCUBATOR.X + 9, 0, L.INCUBATOR.Z - 6), 6)

	-- ===== statue fountain =====
	local plaza = Kit.model(lobby, "StatuePlaza")
	Props.statue(plaza, SC, rng)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		Props.bench(plaza, frame(SC.X + c[1] * 14.6, SC.Z + c[2] * 14.6, Vector3.new(-c[1], 0, -c[2])) * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, math.rad(180), 0))
		Kit.lamp(plaza, Vector3.new(SC.X + c[1] * 18, 0, SC.Z + c[2] * 18))
	end

	-- ===== spawn =====
	local sp = Kit.model(lobby, "Spawn")
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "EOS_LobbySpawn"
	spawnLoc.Anchored = true
	spawnLoc.Size = Vector3.new(12, 0.4, 12)
	spawnLoc.CFrame = CFrame.new(S.X, 0.5, S.Z)
	spawnLoc.Color = PAL.gold
	spawnLoc.Material = Enum.Material.Plastic
	spawnLoc.TopSurface = Enum.SurfaceType.Studs
	spawnLoc.Duration = 0
	spawnLoc.Neutral = true
	spawnLoc.Enabled = true
	local decal = spawnLoc:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawnLoc.Parent = sp
	Kit.box(sp, "Ring", S.X - 7.5, S.X + 7.5, 0, 0.3, S.Z - 7.5, S.Z + 7.5, REF.periDark, { Pattern = "Studs" })
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		Kit.box(sp, "CornerGem", S.X + c[1] * 7 - 0.9, S.X + c[1] * 7 + 0.9, 0.3, 1.0, S.Z + c[2] * 7 - 0.9, S.Z + c[2] * 7 + 0.9, REF.pink, { Pattern = "Studs" })
	end

	-- ===== south edge: swivelling leaderboards (default facing north, toward the middle) =====
	local boards = Kit.model(lobby, "Leaderboards")
	local stats = {
		{ stat = "wins", title = "MOST WINS", color = PAL.gold },
		{ stat = "captures", title = "MOST CATCHES", color = Color3.fromRGB(255, 96, 96) },
		{ stat = "bestTier", title = "BEST EGG", color = TierConfig.get(4).shell },
		{ stat = "petsHatched", title = "PETS HATCHED", color = REF.mint },
	}
	for i, s in stats do
		Props.swivelBoard(boards, frame(L.BOARD_X[i], L.BOARDS_Z, Vector3.new(0, 0, -1)), s.stat, s.title, s.color)
	end

	-- ===== features =====
	Props.shopBooth(lobby, frame(L.SHOP.X, L.SHOP.Z, Vector3.new(-1, 0, 0)))
	Props.eventBoard(lobby, frame(L.EVENTS.X, L.EVENTS.Z, Vector3.new(1, 0, 0)))
	Props.chest(lobby, frame(L.CHEST.X, L.CHEST.Z, Vector3.new(-L.CHEST.X, 0, -L.CHEST.Z)), rng)
	Props.incubator(lobby, frame(L.INCUBATOR.X, L.INCUBATOR.Z, Vector3.new(-L.INCUBATOR.X, 0, -L.INCUBATOR.Z)))

	-- ===== set dressing (nothing tall along the north edge: that's the view) =====
	local decor = Kit.model(lobby, "Decor")
	local keepOut = {
		{ -42, 42, -60, TZ + 14 }, -- terrace + bleachers
		{ -19, 19, SC.Z - 19, SC.Z + 19 }, -- plaza
		{ -9, 9, S.Z - 9, S.Z + 9 }, -- spawn
		{ -36, 36, L.BOARDS_Z - 5, 60 }, -- boards
		{ 34, 60, L.SHOP.Z - 12, L.SHOP.Z + 10 }, -- shop
		{ -60, -40, L.EVENTS.Z - 15, L.EVENTS.Z + 15 }, -- events
		{ 26, 54, 20, 48 }, -- chest
		{ -54, -26, 20, 48 }, -- incubator
		{ -8, 8, -60, 60 }, -- north/south roads
		{ -46, 40, L.SHOP.Z - 8, L.SHOP.Z + 8 }, -- east/west roads
		{ 6, 32, S.Z - 4, 32 }, { -32, -6, S.Z - 4, 32 }, -- stepping spurs
	}
	local function free(x, z, pad)
		pad = pad or 0
		if math.abs(x) > 57 - pad or math.abs(z) > 57 - pad then
			return false
		end
		for _, r in keepOut do
			if x > r[1] - pad and x < r[2] + pad and z > r[3] - pad and z < r[4] + pad then
				return false
			end
		end
		return true
	end
	local treeSpots = { { -54, -30 }, { 54, -32 }, { -54, 14 }, { 54, 14 }, { -30, -26 }, { 30, -28 }, { 20, 38 }, { -20, 38 }, { -54, 54 }, { 54, 54 }, { -40, 56 }, { 40, 56 }, { 28, 6 }, { -28, 6 } }
	for i, t in treeSpots do
		if free(t[1], t[2], 0) then
			Kit.tree(decor, Vector3.new(t[1], 0, t[2]), rng:NextNumber(10, 14), rng, LEAVES[i % 3 + 1])
		end
	end
	local placed, tries = 0, 0
	while placed < 24 and tries < 800 do
		tries += 1
		local x, z = rng:NextNumber(-55, 55), rng:NextNumber(-30, 55)
		local w, d = rng:NextNumber(5, 12), rng:NextNumber(4, 9)
		if free(x, z, math.max(w, d) / 2 + 1) then
			placed += 1
			Kit.box(decor, "GrassPatch", x - w / 2, x + w / 2, 0, 0.25 + 0.0003 * (placed % 3), z - d / 2, z + d / 2, if placed % 2 == 0 then REF.limeLight else REF.limeDark, { Pattern = "Universal" })
		end
	end
	local function blades(x, z)
		local m = Kit.model(decor, "GrassBlades")
		for k = 1, rng:NextInteger(3, 5) do
			local h = rng:NextNumber(1.6, 3.2)
			local lean = math.rad(rng:NextInteger(-1, 1) * 15)
			Kit.brick(m, "Blade", Vector3.new(0.45, h, 0.45), CFrame.new(x + rng:NextNumber(-0.9, 0.9), h / 2, z + rng:NextNumber(-0.9, 0.9)) * CFrame.Angles(lean, 0, -lean), if k % 2 == 0 then REF.blade else REF.limeDark, { Pattern = "Smooth" })
		end
	end
	placed, tries = 0, 0
	while placed < 60 and tries < 1500 do
		tries += 1
		local x, z = rng:NextNumber(-56, 56), rng:NextNumber(-56, 56)
		if free(x, z, 1) then
			placed += 1
			local roll = rng:NextNumber()
			if roll < 0.45 then
				blades(x, z)
			elseif roll < 0.8 then
				Kit.flower(decor, Vector3.new(x, 0, z), if roll < 0.6 then REF.pink elseif roll < 0.7 then PAL.white else PAL.gold)
			else
				Kit.rock(decor, Vector3.new(x, 0, z), rng:NextNumber(1.8, 3.2), rng)
			end
		end
	end
	for k, c in { { 36, -22, 0 }, { 38.6, -22.4, 15 }, { 37.2, -22.2, 30, 2.4 } } do
		local cf = CFrame.new(c[1], 1.2 + (c[4] or 0), c[2]) * CFrame.Angles(0, math.rad(c[3]), 0)
		local crate = Kit.model(decor, "Crate")
		Kit.brick(crate, "Body", Vector3.new(2.4, 2.4, 2.4), cf, if k % 2 == 0 then REF.salmonTile else Props.GOLD, { Pattern = "Weld" })
		Kit.brick(crate, "Band", Vector3.new(2.5, 0.4, 2.5), cf, REF.coralDark, { Pattern = "Smooth" })
	end

	-- ===== move the finished island beside the arena =====
	lobby:PivotTo(lobby:GetPivot() + Layout.Lobby.ORIGIN)
	return lobby
end
