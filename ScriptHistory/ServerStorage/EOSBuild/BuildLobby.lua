--!nocheck
-- BuildLobby (Oct 2026, v5): a deliberately simple lobby. The top is one flat grass brick on a dirt
-- brick, with nothing on it but things you walk up to: the spawn, two shops (gold, gems), the
-- incubator and the swivelling leaderboards. No trees, paths, decor or railings: the edges are open
-- (invisible safety walls only) so people can look down at the match.
-- The detail goes underneath instead: the island's underside is a big stepped rock cone with roots,
-- vines, stalactites, glowing crystals, small floating rocks and a waterfall that turns to mist.
-- Built in Layout.LobbyLocal coordinates (top surface y = 0), then moved to Layout.Lobby.ORIGIN.
-- The underside stays shallow on the north half, which hangs over the arena's south scenery.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.EOS.Shared
local Layout = require(Shared.Layout)
local TierConfig = require(Shared.TierConfig)
local Kit = require(script.Parent.WorldKit)
local Props = require(script.Parent.LobbyProps)
local PAL = Kit.PAL
local REF = Props.REF

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local GRASS, GRASS_LIP, GRASS_DARK = rgb(108, 194, 66), rgb(94, 176, 56), rgb(76, 150, 46)
local DIRT, DIRT2, DIRT3 = rgb(150, 104, 62), rgb(132, 90, 56), rgb(116, 78, 50)
local ROCK, ROCK2, ROCK3 = rgb(156, 144, 130), rgb(134, 124, 116), rgb(112, 106, 102)
local ROOT, VINE = rgb(92, 60, 36), rgb(70, 150, 52)
local CRYSTAL_A, CRYSTAL_B = rgb(90, 230, 255), rgb(190, 110, 255)
local WATER, FOAM = rgb(84, 190, 255), rgb(230, 248, 255)

local function frame(x: number, z: number, face: Vector3): CFrame
	local f = Vector3.new(face.X, 0, face.Z).Unit
	return CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + f)
end

-- relabel a cloned shop: which tab it opens and what its sign says
local function relabel(m: Instance, tab: string, label: string, title: string, color: Color3)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Screen") == "Shop" then
			d:SetAttribute("Tab", tab)
			d:SetAttribute("Label", label)
		elseif d:IsA("TextLabel") and d.Parent and d.Parent.Name == "FloatingSign" then
			d.Text = title
			d.TextColor3 = color
		end
	end
end

return function(world: Instance)
	local rng = Random.new(5150)
	local L = Layout.LobbyLocal
	local lobby = Kit.model(world, "Lobby")
	local H = L.HALF.X -- walkable half size (walls)
	local E = H + 2 -- edge of the grass brick

	-- ===== the brick: grass on dirt =====
	local ground = Kit.model(lobby, "Ground")
	Kit.box(ground, "Grass", -E, E, -2, 0, -E, E, GRASS, { Pattern = "Studs" })
	Kit.box(ground, "Dirt", -E + 0.4, E - 0.4, -8, -2, -E + 0.4, E - 0.4, DIRT, { Pattern = "Studs" })
	-- grass lip: little drips of grass hanging over the dirt, all the way round
	local function lip(alongX: boolean, fixed: number, outward: number)
		local p = -E + rng:NextNumber(1, 4)
		while p < E - 3 do
			local len = rng:NextNumber(3, 8)
			local drop = rng:NextNumber(0.6, 1.8)
			local a, b = p, math.min(p + len, E - 0.5)
			local o0, o1 = fixed - outward * 0.35, fixed + outward * 0.15
			if alongX then
				Kit.box(ground, "GrassLip", a, b, -2 - drop, -1.999, math.min(o0, o1), math.max(o0, o1), GRASS_LIP, { Pattern = "Studs" })
			else
				Kit.box(ground, "GrassLip", math.min(o0, o1), math.max(o0, o1), -2 - drop, -1.999, a, b, GRASS_LIP, { Pattern = "Studs" })
			end
			p = b + rng:NextNumber(2, 7)
		end
	end
	lip(true, -E, -1)
	lip(true, E, 1)
	lip(false, -E, -1)
	lip(false, E, 1)

	-- ===== the underside: a stepped rock cone, deeper toward the south =====
	local under = Kit.model(ground, "Underside")
	-- each layer: { top, bottom, half size, centre z offset, colour }; the north edge of every layer
	-- below the first stays south of local z = -10 except the shallow ones (north half overhangs arena)
	local layers = {
		{ -8, -13, E - 3, 0, DIRT2 },
		{ -13, -18, E - 10, 3, DIRT3 },
		{ -18, -23, 40, 12, ROCK },
		{ -23, -28, 30, 18, ROCK2 },
		{ -28, -33, 20, 22, ROCK2 },
		{ -33, -38, 11, 24, ROCK3 },
	}
	local bottoms = {}
	for i, ly in layers do
		local top, bot, half, cz, col = ly[1], ly[2], ly[3], ly[4], ly[5]
		local z0 = cz - half
		if i >= 3 then
			z0 = math.max(z0, -10)
		end
		local z1 = cz + half
		-- core block plus chunky bumps so the outline is never one rectangle
		Kit.box(under, "Layer" .. i, -half, half, bot, top, z0, z1, col, { Pattern = "Studs" })
		for k = 1, 6 do
			local onX = k % 2 == 0
			local s = rng:NextNumber(4, 10)
			local along = rng:NextNumber(-half + s, half - s)
			local bump = rng:NextNumber(1.5, 3.5)
			local drop = rng:NextNumber(0.5, 2.5)
			if onX then
				local side = if rng:NextNumber() < 0.5 then z0 else z1
				local out = if side == z0 then -bump else bump
				Kit.box(under, "Bump", along - s, along + s, bot - drop, top - 0.5, math.min(side, side + out), math.max(side, side + out), col, { Pattern = "Studs" })
			else
				local side = if rng:NextNumber() < 0.5 then -half else half
				local out = if side < 0 then -bump else bump
				Kit.box(under, "Bump", math.min(side, side + out), math.max(side, side + out), bot - drop, top - 0.5, math.max(z0, along - s), math.min(z1, along + s), col, { Pattern = "Studs" })
			end
		end
		table.insert(bottoms, { y = bot, x0 = -half, x1 = half, z0 = z0, z1 = z1 })
	end
	-- stalactites hanging from every layer's underside
	local stal = Kit.model(under, "Stalactites")
	for i, b in bottoms do
		for k = 1, (if i <= 2 then 6 else 4) do
			local x = rng:NextNumber(b.x0 + 2, b.x1 - 2)
			local z = rng:NextNumber(b.z0 + 2, b.z1 - 2)
			local len = rng:NextNumber(3, 7)
			if i <= 2 and z < -10 then
				len = math.min(len, 3.5) -- shallow over the arena
			end
			local w = rng:NextNumber(1.6, 3)
			local col = if i <= 2 then DIRT3 else ROCK3
			Kit.brick(stal, "Stalactite", Vector3.new(w, len * 0.55, w), CFrame.new(x, b.y - len * 0.275, z), col, { Pattern = "Studs" })
			Kit.brick(stal, "StalTip", Vector3.new(w * 0.55, len * 0.45, w * 0.55), CFrame.new(x, b.y - len * 0.55 - len * 0.225, z), col, { Pattern = "Studs" })
		end
	end
	-- the very tip: a long point under the deepest layer
	local tipY = layers[#layers][2]
	Kit.brick(stal, "TipBig", Vector3.new(7, 5, 7), CFrame.new(0, tipY - 2.5, 24), ROCK3, { Pattern = "Studs" })
	Kit.brick(stal, "TipBig2", Vector3.new(3.5, 3, 3.5), CFrame.new(0.5, tipY - 6.5, 24.5), ROCK3, { Pattern = "Studs" })

	-- roots and vines dangling from the dirt
	local roots = Kit.model(under, "Roots")
	for k = 1, 26 do
		local onEdge = k <= 16
		local x, z, y
		if onEdge then
			local side = k % 4
			local t = rng:NextNumber(-E + 4, E - 4)
			x = if side == 0 then -E + 1 elseif side == 1 then E - 1 else t
			z = if side == 2 then -E + 1 elseif side == 3 then E - 1 else t
			y = -8
		else
			local b = bottoms[rng:NextInteger(1, 3)]
			x, z, y = rng:NextNumber(b.x0 + 2, b.x1 - 2), rng:NextNumber(b.z0 + 2, b.z1 - 2), b.y
		end
		local len = if z < -10 then rng:NextNumber(2.5, 4) else rng:NextNumber(5, 12) -- short over the arena
		local vine = k % 3 == 0
		local col = if vine then VINE else ROOT
		local seg1 = len * 0.6
		Kit.brick(roots, if vine then "Vine" else "Root", Vector3.new(0.5, seg1, 0.5), CFrame.new(x, y - seg1 / 2, z) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))), col, { Pattern = "Smooth", CanCollide = false })
		local seg2 = len * 0.4
		Kit.brick(roots, if vine then "Vine" else "Root", Vector3.new(0.4, seg2, 0.4), CFrame.new(x + rng:NextNumber(-0.6, 0.6), y - seg1 - seg2 / 2, z + rng:NextNumber(-0.6, 0.6)), col, { Pattern = "Smooth", CanCollide = false })
		if vine then
			for j = 1, 3 do
				Kit.brick(roots, "Leaf", Vector3.new(0.9, 0.5, 0.9), CFrame.new(x + rng:NextNumber(-0.5, 0.5), y - rng:NextNumber(1, len), z + rng:NextNumber(-0.5, 0.5)) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 3) * 30), 0), GRASS, { Pattern = "Smooth", CanCollide = false })
			end
		end
	end

	-- glowing crystals poking out of the rock (south half, deeper layers)
	local crystals = Kit.model(under, "Crystals")
	for k = 1, 14 do
		local b = bottoms[rng:NextInteger(3, #bottoms)]
		local x = rng:NextNumber(b.x0 + 1, b.x1 - 1)
		local z = rng:NextNumber(math.max(b.z0, 0) + 1, b.z1 - 1)
		local col = if k % 2 == 0 then CRYSTAL_A else CRYSTAL_B
		local cluster = Kit.model(crystals, "CrystalCluster")
		for j = 1, 3 do
			local h = rng:NextNumber(2.2, 4.5)
			local tilt = CFrame.Angles(math.rad(rng:NextNumber(-30, 30)), math.rad(rng:NextNumber(0, 90)), math.rad(rng:NextNumber(-30, 30)))
			local c = Kit.brick(cluster, "Crystal", Vector3.new(1.3, h, 1.3), CFrame.new(x + rng:NextNumber(-1, 1), b.y - h * 0.35, z + rng:NextNumber(-1, 1)) * tilt, col, { Pattern = "Smooth", CanCollide = false, Material = Enum.Material.Neon, CastShadow = false })
			c.Transparency = 0.1
			if j == 1 then
				local l = Instance.new("PointLight")
				l.Color = col
				l.Range = 12
				l.Brightness = 1.5
				l.Parent = c
			end
		end
	end

	-- small floating rocks drifting under the south half
	local bits = Kit.model(under, "FloatingRocks")
	for k = 1, 7 do
		local a = (k / 7) * math.pi * 1.2 - math.pi * 0.1
		local r = rng:NextNumber(30, 48)
		local x, z = math.cos(a) * r, 12 + math.sin(a) * r * 0.6
		local y = rng:NextNumber(-34, -18)
		local s = rng:NextNumber(3, 6)
		local rock = Kit.model(bits, "FloatingRock")
		Kit.brick(rock, "Grass", Vector3.new(s, 0.8, s), CFrame.new(x, y, z), GRASS, { Pattern = "Studs" })
		Kit.brick(rock, "Dirt", Vector3.new(s * 0.8, s * 0.5, s * 0.8), CFrame.new(x, y - 0.4 - s * 0.25, z), DIRT2, { Pattern = "Studs" })
		Kit.brick(rock, "Point", Vector3.new(s * 0.4, s * 0.45, s * 0.4), CFrame.new(x, y - 0.4 - s * 0.5 - s * 0.22, z), ROCK3, { Pattern = "Studs" })
	end

	-- a waterfall pouring off the south edge, fading into mist on the way down
	local falls = Kit.model(under, "Waterfall")
	local wx = 8
	Kit.box(falls, "Notch", wx - 4, wx + 4, -1.6, 0.05, E - 1.5, E + 0.2, WATER, { Pattern = "Smooth", CanCollide = false, Transparency = 0.15 })
	for k = 0, 5 do
		local y0 = -2 - k * 5
		local seg = Kit.box(falls, "Fall", wx - 3.4 + k * 0.2, wx + 3.4 - k * 0.2, y0 - 5, y0, E + 0.2, E + 1.4, WATER, { Pattern = "Smooth", CanCollide = false, CastShadow = false })
		seg.Transparency = 0.2 + k * 0.13
		seg.Material = Enum.Material.Glass
	end
	local mist = Kit.brick(falls, "MistSource", Vector3.new(6, 1, 1.5), CFrame.new(wx, -30, E + 0.8), FOAM, { Pattern = "Smooth", CanCollide = false, Transparency = 1 })
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Color = ColorSequence.new(FOAM)
	pe.Size = NumberSequence.new(3, 7)
	pe.Transparency = NumberSequence.new(0.55, 1)
	pe.Lifetime = NumberRange.new(1.6, 2.4)
	pe.Rate = 10
	pe.Speed = NumberRange.new(1, 3)
	pe.SpreadAngle = Vector2.new(60, 60)
	pe.Acceleration = Vector3.new(0, -2, 0)
	pe.Parent = mist
	Kit.box(falls, "Foam", wx - 4, wx + 4, -1.9, -1.4, E - 0.2, E + 1.6, FOAM, { Pattern = "Smooth", CanCollide = false })

	-- invisible safety walls: nothing visible blocks the view of the match
	Kit.boundary(lobby, -H, H, -H, H, 40, { Name = "LobbyWalls" })

	-- ===== spawn =====
	local S = L.SPAWN
	local sp = Kit.model(lobby, "Spawn")
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "EOS_LobbySpawn"
	spawnLoc.Anchored = true
	spawnLoc.Size = Vector3.new(12, 0.4, 12)
	spawnLoc.CFrame = CFrame.new(S.X, 0.2, S.Z)
	spawnLoc.Color = GRASS_DARK
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

	-- ===== walk-up stations =====
	local stations = Kit.model(lobby, "Stations")
	-- leaderboards along the south edge (they turn to face each player)
	local boards = Kit.model(stations, "Leaderboards")
	local stats = {
		{ stat = "wins", title = "MOST WINS", color = PAL.gold },
		{ stat = "captures", title = "MOST CATCHES", color = rgb(255, 96, 96) },
		{ stat = "bestTier", title = "BEST EGG", color = TierConfig.get(4).shell },
		{ stat = "petsHatched", title = "PETS HATCHED", color = REF.mint },
	}
	for i, s in stats do
		Props.swivelBoard(boards, frame(L.BOARD_X[i], L.BOARDS_Z, Vector3.new(0, 0, -1)), s.stat, s.title, s.color)
	end
	-- gold shop (east) and gem shop (west), facing the middle
	local gold = Kit.model(stations, "GoldShop")
	Props.shopBooth(gold, frame(L.SHOP.X, L.SHOP.Z, Vector3.new(-1, 0, 0)))
	relabel(gold, "gold", "Gold Shop", "GOLD SHOP", PAL.gold)
	local gems = Kit.model(stations, "GemShop")
	Props.shopBooth(gems, frame(-L.SHOP.X, L.SHOP.Z, Vector3.new(1, 0, 0)))
	relabel(gems, "gems", "Gem Shop", "GEM SHOP", REF.mint)
	-- incubator in the middle, facing the spawn
	Props.incubator(stations, frame(L.STATUE.X, L.STATUE.Z - 2, Vector3.new(0, 0, 1)))

	-- ===== move the finished island beside the arena =====
	lobby:PivotTo(lobby:GetPivot() + Layout.Lobby.ORIGIN)
	return lobby
end
