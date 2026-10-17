--!nocheck
-- BuildLobby: the compact lobby island (Oct 2026, the developer's reference: "make the lobby
-- smaller ... game loop features and cosmetics surrounding on the outside").
-- A 132-stud square island, open grass in the middle with the spawn, every feature on the edge
-- facing in: leaderboards (north), arena portal + match status (north-east), Gold and Gem shop
-- stalls (east), pet display (south-east), incubator (south), practice field (south-west), daily
-- quests and the last match's Top 3 podium (west). Walk-up prompts open the matching screens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.EOS.Shared
local Layout = require(Shared.Layout)
local TierConfig = require(Shared.TierConfig)
local EggModel = require(Shared.EggModel)
local PetModel = require(Shared.PetModel)
local Kit = require(script.Parent.WorldKit)
local PAL = Kit.PAL

local INK = PAL.ink
local FONT = Kit.FONT
local FRONT = Enum.NormalId.Front -- every feature is built in a local frame whose -Z faces the middle

local function label(parent, name, text, color, align, posY, height)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, height or 0.1)
	t.Position = UDim2.fromScale(0, posY or 0)
	t.FontFace = FONT
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextXAlignment = align or Enum.TextXAlignment.Center
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = 3
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.Parent = t
	t.Parent = parent
	return t
end

-- a local frame at (x, z) turned so its -Z faces `face` (a flat world direction)
local function frame(x: number, z: number, face: Vector3): CFrame
	local f = Vector3.new(face.X, 0, face.Z).Unit
	return CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + f)
end

local function toMiddle(x: number, z: number): Vector3
	return Vector3.new(-x, 0, -z)
end

return function(world: Instance)
	local rng = Random.new(777)
	local L = Layout.Lobby
	local lobby = Kit.model(world, "Lobby")
	local H, IH = L.HALF.X, L.ISLAND_HALF

	-- ===== ground + boundary =====
	local ground = Kit.model(lobby, "Ground")
	Kit.island(ground, -IH, IH, -IH, IH, rng)
	Kit.boundary(lobby, -H, H, -H, H, 40, { Name = "LobbyWalls" })
	-- a low stud kerb just inside the edge (reads as the island rim, like the reference)
	local rim = Kit.model(lobby, "Rim")
	local RC = PAL.stone2
	Kit.box(rim, "N", -H - 1, H + 1, 0, 0.8, -H - 1, -H, RC, { Pattern = "Studs" })
	Kit.box(rim, "S", -H - 1, H + 1, 0, 0.8, H, H + 1, RC, { Pattern = "Studs" })
	Kit.box(rim, "W", -H - 1, -H, 0, 0.8, -H, H, RC, { Pattern = "Studs" })
	Kit.box(rim, "E", H, H + 1, 0, 0.8, -H, H, RC, { Pattern = "Studs" })

	-- ===== spawn (middle, facing north) =====
	local sp = Kit.model(lobby, "Spawn")
	local S = L.SPAWN
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "EOS_LobbySpawn"
	spawnLoc.Anchored = true
	spawnLoc.Size = Vector3.new(12, 0.4, 12)
	spawnLoc.CFrame = CFrame.new(S.X, 0.2, S.Z)
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
	Kit.box(sp, "Ring", S.X - 7, S.X + 7, 0, 0.3, S.Z - 7, S.Z + 7, PAL.stone, { Pattern = "Studs" })
	for _, sx in ipairs({ -1, 1 }) do
		Kit.lamp(sp, Vector3.new(S.X + sx * 24, 0, S.Z - 6))
		Kit.lamp(sp, Vector3.new(S.X + sx * 24, 0, S.Z + 16))
	end

	-- ===== NORTH: leaderboards (THIS SERVER), facing south =====
	local boards = Kit.model(lobby, "Leaderboards")
	local stats = {
		{ stat = "wins", title = "MOST WINS", color = PAL.gold },
		{ stat = "captures", title = "MOST CATCHES", color = PAL.red },
		{ stat = "bestTier", title = "BEST EGG", color = TierConfig.get(4).shell },
		{ stat = "petsHatched", title = "PETS HATCHED", color = Color3.fromRGB(120, 236, 140) },
	}
	for i, s in ipairs(stats) do
		local bm = Kit.model(boards, "Board_" .. s.stat)
		local F = frame(L.BOARD_X[i], L.BOARDS_Z, Vector3.new(0, 0, 1))
		for _, lx in ipairs({ -7.6, 7.6 }) do
			Kit.brick(bm, "Post", Vector3.new(1.2, 18, 1.2), F * CFrame.new(lx, 9, 0.6), PAL.wood, { Pattern = "Weld" })
		end
		local board = Kit.brick(bm, "Board", Vector3.new(14.6, 14, 1), F * CFrame.new(0, 10, 0), INK:Lerp(PAL.blueDark, 0.35), { Pattern = "Weld", Tags = { "EOS_Board" }, Attrs = { Stat = s.stat } })
		Kit.brick(bm, "Cap", Vector3.new(16, 1.2, 1.6), F * CFrame.new(0, 17.6, 0), s.color, { Pattern = "Studs" })
		Kit.brick(bm, "Kick", Vector3.new(15.2, 0.8, 1.4), F * CFrame.new(0, 2.6, 0), s.color, { Pattern = "Weld" })
		local sg = Instance.new("SurfaceGui")
		sg.Face = FRONT
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.LightInfluence = 0
		sg.MaxDistance = 220
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Parent = sg
		label(holder, "Title", s.title, s.color, nil, 0.03, 0.12)
		label(holder, "Scope", "THIS SERVER  ·  LIVE", Color3.fromRGB(190, 200, 220), nil, 0.15, 0.06)
		for r = 1, 8 do
			local row = Instance.new("Frame")
			row.Name = "Row" .. r
			row.BackgroundColor3 = Color3.new(1, 1, 1)
			row.BackgroundTransparency = if r % 2 == 0 then 0.94 else 0.88
			row.Position = UDim2.fromScale(0.05, 0.23 + (r - 1) * 0.095)
			row.Size = UDim2.fromScale(0.9, 0.085)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.2, 0)
			corner.Parent = row
			local n = label(row, "PlayerName", "", Color3.new(1, 1, 1), Enum.TextXAlignment.Left, 0.1, 0.8)
			n.Size = UDim2.fromScale(0.68, 0.8)
			n.Position = UDim2.fromScale(0.03, 0.1)
			local v = label(row, "Value", "", s.color, Enum.TextXAlignment.Right, 0.1, 0.8)
			v.Size = UDim2.fromScale(0.28, 0.8)
			v.Position = UDim2.fromScale(0.69, 0.1)
			row.Parent = holder
		end
		sg.Parent = board
		Kit.brick(bm, "Hedge", Vector3.new(16, 2, 3), F * CFrame.new(0, 1, -2.4), PAL.leaf2, { Pattern = "Studs" })
	end
	Kit.floatingText(Kit.brick(boards, "SignAnchor", Vector3.new(1, 1, 1), CFrame.new(-9, 22, L.BOARDS_Z), PAL.white, { Transparency = 1, CanCollide = false, CanQuery = false }), "LEADERBOARDS", PAL.gold, 26, 0)

	-- ===== NORTH-EAST: arena portal + match status =====
	local portal = Kit.model(lobby, "ArenaPortal")
	do
		local P = L.PORTAL
		local F = frame(P.X, P.Z, toMiddle(P.X, P.Z))
		Kit.brick(portal, "Base", Vector3.new(20, 1.2, 8), F * CFrame.new(0, 0.6, 0), PAL.stoneDark, { Pattern = "Studs" })
		Kit.brick(portal, "Step", Vector3.new(16, 0.6, 3), F * CFrame.new(0, 0.3, -5), PAL.stone, { Pattern = "Studs" })
		local center = F * CFrame.new(0, 9.4, 0)
		local R, N = 7.4, 18
		for k = 0, N - 1 do
			local a = k / N * math.pi * 2
			local col = if k % 2 == 0 then Color3.fromRGB(150, 70, 230) else Color3.fromRGB(110, 46, 190)
			Kit.brick(portal, "Ring", Vector3.new(2.8, 2.8, 2.2), center * CFrame.Angles(0, 0, a) * CFrame.new(0, R, 0), col, { Pattern = "Studs" })
		end
		Kit.brick(portal, "Swirl", Vector3.new(0.4, 13.2, 13.2), center * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(196, 140, 255), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Transparency = 0.15, CanCollide = false, CanQuery = false, Pattern = "Smooth" })
		Kit.brick(portal, "Glow", Vector3.new(0.2, 11, 11), center * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(0.3, 0, 0), Color3.fromRGB(120, 60, 210), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = false })
		local status = Kit.brick(portal, "StatusBoard", Vector3.new(20, 5.6, 0.8), F * CFrame.new(0, 20.6, 0), INK:Lerp(PAL.blueDark, 0.4), { Pattern = "Weld", Tags = { "EOS_StatusBoard" } })
		Kit.surfaceText(status, FRONT, {
			{ name = "Title", text = "WAITING FOR PLAYERS", size = 0.5, color = PAL.gold },
			{ name = "Sub", text = "", size = 0.28 },
		}, { PixelsPerStud = 30 })
		for _, lx in ipairs({ -9.4, 9.4 }) do
			Kit.brick(portal, "BoardPost", Vector3.new(0.8, 6, 0.8), F * CFrame.new(lx, 16.6, 0.6), PAL.stoneDark, { Pattern = "Weld" })
		end
		local plaque = Kit.brick(portal, "Plaque", Vector3.new(10, 1.8, 0.4), F * CFrame.new(0, 2.2, -2.6), PAL.cream, { Pattern = "Weld" })
		Kit.surfaceText(plaque, FRONT, { { text = "MATCHES START AUTOMATICALLY", size = 0.5, color = INK:Lerp(PAL.blueDark, 0.5) }, { text = "Turn AFK off to join", size = 0.36, color = PAL.wood2 } }, { PixelsPerStud = 40 })
		Kit.floatingText(status, "TO THE ARENA", Color3.fromRGB(206, 160, 255), 22, 6)
	end

	-- ===== stalls (shops, quests, pets): a booth with a counter that opens a screen =====
	local function stall(parent, name, F: CFrame, wall: Color3, awningA: Color3, awningB: Color3, title: string, titleColor: Color3, prompt: any)
		local m = Kit.model(parent, name)
		Kit.brick(m, "Floor", Vector3.new(16, 0.4, 12), F * CFrame.new(0, 0.2, 2), PAL.stoneDark, { Pattern = "Weld" })
		Kit.brick(m, "BackWall", Vector3.new(16, 10, 1), F * CFrame.new(0, 5.4, 7.5), wall, { Pattern = "Studs" })
		for _, lx in ipairs({ -7.5, 7.5 }) do
			Kit.brick(m, "SideWall", Vector3.new(1, 10, 9), F * CFrame.new(lx, 5.4, 3.5), wall, { Pattern = "Studs" })
			Kit.brick(m, "Post", Vector3.new(1, 10.4, 1), F * CFrame.new(lx, 5.6, -1.2), PAL.white, { Pattern = "Weld" })
		end
		Kit.brick(m, "Roof", Vector3.new(17.4, 1, 10.6), F * CFrame.new(0, 10.9, 3), wall:Lerp(INK, 0.15), { Pattern = "Studs" })
		local stripes = 8
		for k = 0, stripes - 1 do
			Kit.brick(m, "Awning", Vector3.new(2.02, 0.4, 5), F * CFrame.new(-8 + 2 * (k + 0.5), 10.2, -2.6) * CFrame.Angles(math.rad(-16), 0, 0), if k % 2 == 0 then awningA else awningB, { Pattern = "Studs" })
		end
		local counter = Kit.brick(m, "Counter", Vector3.new(12, 3.2, 2.2), F * CFrame.new(0, 2, -2.4), PAL.wood, { Pattern = "Weld", Tags = { "EOS_Prompt" }, Attrs = prompt })
		Kit.brick(m, "CounterTop", Vector3.new(12.6, 0.4, 2.8), F * CFrame.new(0, 3.8, -2.4), PAL.wood2, { Pattern = "Weld" })
		local sign = Kit.brick(m, "Sign", Vector3.new(14, 3, 0.6), F * CFrame.new(0, 13.2, -0.4), INK:Lerp(PAL.blueDark, 0.3), { Pattern = "Weld" })
		Kit.surfaceText(sign, FRONT, { { text = title, size = 0.7, color = titleColor } }, { PixelsPerStud = 40 })
		Kit.brick(m, "SignTrim", Vector3.new(14.6, 0.5, 0.8), F * CFrame.new(0, 11.6, -0.4), titleColor, { Pattern = "Studs" })
		return m, counter
	end

	-- ===== EAST: Gold shop + Gem shop =====
	local east = Kit.model(lobby, "Shops")
	local goldF = frame(L.SHOP_X, L.GOLD_SHOP_Z, Vector3.new(-1, 0, 0))
	local goldStall = stall(east, "GoldShop", goldF, Color3.fromRGB(255, 226, 150), PAL.gold, PAL.white, "GOLD SHOP", PAL.gold, { Screen = "Shop", Tab = "gold", Label = "Gold Shop", Action = "Browse" })
	-- wares on the counter: trail swatches + a confetti pot
	for k, col in ipairs({ Color3.fromRGB(255, 236, 140), Color3.fromRGB(255, 132, 64), Color3.fromRGB(255, 120, 200), Color3.fromRGB(170, 230, 255) }) do
		Kit.brick(goldStall, "Ware", Vector3.new(1.6, 1.6, 1.6), goldF * CFrame.new(-4.5 + (k - 1) * 3, 4.8, -2.4) * CFrame.Angles(0, math.rad(20 * k), 0), col, { Pattern = "Studs" })
	end
	local coinPile = Kit.model(goldStall, "Coins")
	for k = 1, 6 do
		Kit.brick(coinPile, "Coin", Vector3.new(0.3, 1.6, 1.6), goldF * CFrame.new(-6 + k * 0.5, 4.8, 4) * CFrame.Angles(0, 0, math.rad(90)), PAL.gold, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Pattern = "Smooth" })
	end
	Kit.floatingText(goldStall.Sign, "COSMETICS FOR GOLD", PAL.gold, 18, 4.5)
	local gemF = frame(L.SHOP_X, L.GEM_SHOP_Z, Vector3.new(-1, 0, 0))
	local gemStall = stall(east, "GemShop", gemF, Color3.fromRGB(180, 240, 214), Color3.fromRGB(60, 210, 130), PAL.white, "GEM SHOP", Color3.fromRGB(96, 236, 150), { Screen = "Shop", Tab = "gems", Label = "Gem Shop", Action = "Browse" })
	for k = 1, 3 do
		Kit.brick(gemStall, "Gem", Vector3.new(1.6, 1.6, 1.6), gemF * CFrame.new(-4 + (k - 1) * 4, 5, -2.4) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color3.fromRGB(60, 220, 130), { Material = Enum.Material.Glass, Transparency = 0.15, Pattern = "Smooth" })
	end
	Kit.floatingText(gemStall.Sign, "PREMIUM LOOKS", Color3.fromRGB(96, 236, 150), 16, 4.5)

	-- ===== SOUTH-EAST: pet display =====
	local petsArea = Kit.model(lobby, "PetDisplay")
	do
		local P = L.PETS
		local F = frame(P.X, P.Z, toMiddle(P.X, P.Z))
		Kit.brick(petsArea, "Platform", Vector3.new(22, 0.8, 14), F * CFrame.new(0, 0.4, 2), PAL.stone, { Pattern = "Studs" })
		local fams = { { "Decoy", "Mouse" }, { "Scout", "Sparrow" }, { "Brake", "Turtle" } }
		for k, fam in ipairs(fams) do
			local lx = (k - 2) * 7
			Kit.brick(petsArea, "Pedestal", Vector3.new(4.4, 2.6, 4.4), F * CFrame.new(lx, 2.1, 3), PAL.stone2, { Pattern = "Studs" })
			Kit.brick(petsArea, "PedestalCap", Vector3.new(5, 0.4, 5), F * CFrame.new(lx, 3.6, 3), PAL.white, { Pattern = "Weld" })
			local pet = PetModel.build(fam[2], 3)
			pet.Name = "Showcase_" .. fam[1]
			pet:PivotTo(F * CFrame.new(lx, 3.8, 3) * CFrame.Angles(0, math.rad(180), 0))
			pet.Parent = petsArea
			local tag = Kit.brick(petsArea, "Tag", Vector3.new(4.4, 1.2, 0.3), F * CFrame.new(lx, 1.4, 0.65), INK:Lerp(PAL.blueDark, 0.3), { Pattern = "Smooth" })
			Kit.surfaceText(tag, FRONT, { { text = string.upper(fam[1]), size = 0.8 } }, { PixelsPerStud = 50 })
		end
		local counter = Kit.brick(petsArea, "Counter", Vector3.new(8, 2.6, 2), F * CFrame.new(0, 1.7, -4.4), PAL.wood, { Pattern = "Weld", Tags = { "EOS_Prompt" }, Attrs = { Screen = "Pets", Label = "Your Pets", Action = "Equip a pet" } })
		Kit.brick(petsArea, "CounterTop", Vector3.new(8.6, 0.4, 2.6), F * CFrame.new(0, 3.2, -4.4), PAL.wood2, { Pattern = "Weld" })
		local sign = Kit.brick(petsArea, "Sign", Vector3.new(16, 3, 0.6), F * CFrame.new(0, 10.5, 7.8), INK:Lerp(PAL.blueDark, 0.3), { Pattern = "Weld" })
		Kit.surfaceText(sign, FRONT, { { text = "PETS", size = 0.5, color = Color3.fromRGB(255, 196, 92) }, { text = "One pet = one ability in matches", size = 0.32, color = PAL.cream } }, { PixelsPerStud = 40 })
		for _, lx in ipairs({ -7.6, 7.6 }) do
			Kit.brick(petsArea, "SignPost", Vector3.new(0.8, 9, 0.8), F * CFrame.new(lx, 4.9, 7.8), PAL.wood2, { Pattern = "Weld" })
		end
		Kit.floatingText(counter, "PETS", Color3.fromRGB(255, 196, 92), 12, 11)
	end

	-- ===== SOUTH: the incubator (pieces -> pets) =====
	local inc = Kit.model(lobby, "Incubator")
	do
		local P = L.INCUBATOR
		local F = frame(P.X, P.Z, Vector3.new(0, 0, -1))
		local y = 0
		for i, sz in ipairs({ 18, 14, 10.5 }) do
			local h = if i == 3 then 1.2 else 1.6
			Kit.brick(inc, "Base" .. i, Vector3.new(sz, h, sz * 0.8), F * CFrame.new(0, y + h / 2, 3), if i == 2 then PAL.stone2 else PAL.stone, { Pattern = "Studs" })
			y += h
		end
		local egg = EggModel.build(3, false, 3.2)
		egg.Name = "IncubatingEgg"
		egg:PivotTo(F * CFrame.new(0, y + 0.1, 3))
		egg.Parent = inc
		Kit.brick(inc, "Dome", Vector3.new(10.4, 10.4, 10.4), F * CFrame.new(0, y + 4.2, 3), Color3.fromRGB(200, 236, 255), { Shape = Enum.PartType.Ball, Material = Enum.Material.Glass, Transparency = 0.55, CanCollide = false, CanQuery = false, Pattern = "Smooth" })
		-- heat lamps on four posts
		for _, c in ipairs({ { -7, 0 }, { 7, 0 }, { -7, 6 }, { 7, 6 } }) do
			Kit.brick(inc, "LampPost", Vector3.new(0.8, 11, 0.8), F * CFrame.new(c[1], 5.5, c[2]), INK:Lerp(PAL.stoneDark, 0.6), { Pattern = "Weld" })
			local bulb = Kit.brick(inc, "HeatLamp", Vector3.new(1.4, 1, 1.4), F * CFrame.new(c[1] * 0.85, 10.6, c[2] + (3 - c[2]) * 0.15), Color3.fromRGB(255, 170, 90), { Material = Enum.Material.Neon })
			local light = Instance.new("PointLight")
			light.Range = 12
			light.Brightness = 0.9
			light.Color = Color3.fromRGB(255, 190, 120)
			light.Parent = bulb
		end
		-- control desk in front (the prompt)
		local desk = Kit.brick(inc, "Desk", Vector3.new(10, 3, 2.4), F * CFrame.new(0, 1.5, -6.4), PAL.white, { Pattern = "Weld", Tags = { "EOS_Prompt" }, Attrs = { Screen = "Incubator", Label = "Incubator", Action = "Hatch pets" } })
		Kit.brick(inc, "DeskTop", Vector3.new(10.6, 0.4, 3), F * CFrame.new(0, 3.2, -6.4), PAL.stone2, { Pattern = "Weld" })
		for k = 1, 3 do
			local small = EggModel.build(if k == 1 then 1 elseif k == 2 then 3 else 4, false, 1)
			small:PivotTo(F * CFrame.new(-3 + (k - 1) * 3, 3.45, -6.4))
			small.Parent = inc
		end
		local sign = Kit.brick(inc, "Sign", Vector3.new(16, 3, 0.6), F * CFrame.new(0, 14.4, 6.4), INK:Lerp(PAL.blueDark, 0.3), { Pattern = "Weld" })
		Kit.surfaceText(sign, FRONT, { { text = "INCUBATOR", size = 0.5, color = PAL.gold }, { text = "Hatch egg pieces into pets", size = 0.32, color = PAL.cream } }, { PixelsPerStud = 40 })
		for _, lx in ipairs({ -7.6, 7.6 }) do
			Kit.brick(inc, "SignPost", Vector3.new(0.8, 13, 0.8), F * CFrame.new(lx, 6.5, 6.4), PAL.wood2, { Pattern = "Weld" })
		end
		Kit.floatingText(desk, "INCUBATOR", PAL.gold, 14, 9)
	end

	-- ===== WEST: daily quests board =====
	local quests = Kit.model(lobby, "QuestBoard")
	do
		local Q = L.QUESTS
		local F = frame(Q.X, Q.Z, Vector3.new(1, 0, 0))
		for _, lx in ipairs({ -6, 6 }) do
			Kit.brick(quests, "Post", Vector3.new(1, 10, 1), F * CFrame.new(lx, 5, 0), PAL.wood, { Pattern = "Weld" })
		end
		local qboard = Kit.brick(quests, "Board", Vector3.new(11, 6, 0.8), F * CFrame.new(0, 6, 0), PAL.cream, { Pattern = "Weld", Tags = { "EOS_Prompt" }, Attrs = { Screen = "Quests", Label = "Daily Quests", Action = "Read quests" } })
		Kit.brick(quests, "Roof", Vector3.new(13.4, 0.8, 3), F * CFrame.new(0, 10.4, 0), PAL.redDark, { Pattern = "Studs" })
		Kit.surfaceText(qboard, FRONT, { { text = "DAILY QUESTS", size = 0.32, color = PAL.redDark }, { text = "2 new every day", size = 0.2, color = PAL.wood2 }, { text = "Rewards: Gold", size = 0.2, color = PAL.wood2 } }, { PixelsPerStud = 40 })
		Kit.floatingText(qboard, "QUESTS", PAL.gold, 12, 7)
	end

	-- ===== WEST: last match's Top 3 Runners (fenced podium) + Top Thief =====
	local pod = Kit.model(lobby, "Podium")
	do
		local P = L.PODIUM
		local F = frame(P.X, P.Z, Vector3.new(1, 0, 0))
		local front = Vector3.new(1, 0, 0)
		Kit.brick(pod, "Floor", Vector3.new(30, 0.4, 12), F * CFrame.new(0, 0.2, 1), PAL.stone, { Pattern = "Studs" })
		local spots = { { place = 1, x = 0, h = 5, color = PAL.gold }, { place = 2, x = -9, h = 3.6, color = Color3.fromRGB(196, 210, 230) }, { place = 3, x = 9, h = 2.4, color = Color3.fromRGB(232, 150, 92) } }
		for _, s in ipairs(spots) do
			local block = Kit.brick(pod, "Place" .. s.place, Vector3.new(8, s.h, 6), F * CFrame.new(s.x, 0.4 + s.h / 2, 2), s.color, { Pattern = "Studs", Tags = { "EOS_PodiumSpot" }, Attrs = { Place = s.place, Facing = front } })
			local sg = Instance.new("SurfaceGui")
			sg.Face = FRONT
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 40
			sg.LightInfluence = 0
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromScale(1, 1)
			holder.Parent = sg
			label(holder, "PlaceNumber", "#" .. s.place, Color3.new(1, 1, 1), nil, 0.02, if s.h > 3 then 0.36 else 0.42)
			label(holder, "PodiumName", "—", Color3.new(1, 1, 1), nil, if s.h > 3 then 0.42 else 0.46, 0.26)
			label(holder, "PodiumSub", "", PAL.cream, nil, if s.h > 3 then 0.7 else 0.74, 0.2)
			sg.Parent = block
		end
		-- low fence around the back and sides (the reference's fenced winners' corner)
		local function along(a: Vector3, b: Vector3)
			Kit.fence(pod, (F * CFrame.new(a)).Position, (F * CFrame.new(b)).Position, rng, { height = 2.6, spacing = 4 })
		end
		along(Vector3.new(-15, 0, 7), Vector3.new(15, 0, 7))
		along(Vector3.new(-15, 0, -5), Vector3.new(-15, 0, 7))
		along(Vector3.new(15, 0, -5), Vector3.new(15, 0, 7))
		local title = Kit.brick(pod, "TitleBoard", Vector3.new(24, 3, 0.6), F * CFrame.new(0, 12.5, 6), PAL.blueDark, { Pattern = "Weld", Tags = { "EOS_PodiumTitle" } })
		Kit.surfaceText(title, FRONT, { { name = "Title", text = "TOP RUNNERS: NO MATCH YET", size = 0.85 } }, { PixelsPerStud = 30 })
		for _, lx in ipairs({ -12.6, 12.6 }) do
			Kit.brick(pod, "TitlePost", Vector3.new(0.8, 11.4, 0.8), F * CFrame.new(lx, 5.7, 6.2), PAL.white, { Pattern = "Weld" })
		end
		local thief = Kit.brick(pod, "ThiefBoard", Vector3.new(8, 4.6, 0.6), F * CFrame.new(-21, 5.4, 2), PAL.redDark, { Pattern = "Weld", Tags = { "EOS_ThiefSign" } })
		Kit.surfaceText(thief, FRONT, {
			{ text = "TOP THIEF", size = 0.3, color = PAL.gold },
			{ name = "ThiefName", text = "—", size = 0.34 },
			{ name = "ThiefSub", text = "", size = 0.22, color = PAL.cream },
		}, { PixelsPerStud = 40 })
		Kit.brick(pod, "ThiefPost", Vector3.new(0.8, 3.2, 0.8), F * CFrame.new(-21, 1.6, 2.3), PAL.wood2, { Pattern = "Weld" })
	end

	-- ===== SOUTH-WEST: practice field =====
	local pr = Kit.model(lobby, "PracticeField")
	do
		local PC, PH = L.PRACTICE_CENTER, L.PRACTICE_HALF
		local px0, px1, pz0, pz1 = PC.X - PH.X, PC.X + PH.X, PC.Z - PH.Z, PC.Z + PH.Z
		local pg = Kit.box(pr, "Ground", px0, px1, 0, 0.25, pz0, pz1, PAL.sand, { Pattern = "Universal" })
		Kit.checker(pg, 6, 0.9)
		Kit.box(pr, "PadA", px0, px0 + 8, 0.25, 0.4, pz0, pz1, PAL.zoneA, { Pattern = "Studs" })
		Kit.box(pr, "PadB", px1 - 8, px1, 0.25, 0.4, pz0, pz1, PAL.zoneB, { Pattern = "Studs" })
		-- fence (the way in is on the north side, toward the middle)
		Kit.fence(pr, Vector3.new(px0 - 1, 0, pz1 + 1), Vector3.new(px1 + 1, 0, pz1 + 1), rng)
		Kit.fence(pr, Vector3.new(px0 - 1, 0, pz0 - 1), Vector3.new(px0 - 1, 0, pz1 + 1), rng)
		Kit.fence(pr, Vector3.new(px1 + 1, 0, pz0 - 1), Vector3.new(px1 + 1, 0, pz1 + 1), rng)
		Kit.fence(pr, Vector3.new(px0 - 1, 0, pz0 - 1), Vector3.new(PC.X - 6, 0, pz0 - 1), rng)
		Kit.fence(pr, Vector3.new(PC.X + 6, 0, pz0 - 1), Vector3.new(px1 + 1, 0, pz0 - 1), rng)
		Kit.hayBale(pr, CFrame.new(PC.X - 5, 1.85, PC.Z - 4), Vector3.new(4, 3.2, 3))
		Kit.hayBale(pr, CFrame.new(PC.X + 5, 1.85, PC.Z + 4), Vector3.new(4, 3.2, 3))
		local psign = Kit.brick(pr, "Sign", Vector3.new(11, 3.6, 0.6), CFrame.new(PC.X, 5, pz0 - 3), PAL.cream, { Pattern = "Weld" })
		Kit.surfaceText(psign, FRONT, { { text = "PRACTICE FIELD", size = 0.36, color = PAL.redDark }, { text = "Cross pad to pad, dodge the bot", size = 0.26, color = PAL.wood2 }, { text = "No rewards here", size = 0.22, color = PAL.wood2 } }, { PixelsPerStud = 40 })
		for _, dx in ipairs({ -5, 5 }) do
			Kit.brick(pr, "SignPost", Vector3.new(0.8, 3.4, 0.8), CFrame.new(PC.X + dx, 1.7, pz0 - 3), PAL.wood2, { Pattern = "Weld" })
		end
		Kit.floatingText(psign, "PRACTICE", PAL.zoneB, 14, 5)
	end

	-- ===== trees and scatter on the rim (the middle stays open) =====
	local decor = Kit.model(lobby, "Decor")
	local trees = { { -62, -62 }, { 62, 62 }, { -62, 62 }, { 63, -40 }, { -63, -34 }, { 24, -63 }, { -28, -63 }, { 63, 28 }, { -20, 63 }, { 20, 63 } }
	for i, t in ipairs(trees) do
		Kit.tree(decor, Vector3.new(t[1], 0, t[2]), rng:NextNumber(14, 18), rng, if i % 3 == 0 then PAL.leaf2 elseif i % 3 == 1 then PAL.leaf else PAL.leaf3)
	end
	local placed = 0
	local tries = 0
	while placed < 26 and tries < 400 do
		tries += 1
		local x, z = rng:NextNumber(-58, 58), rng:NextNumber(-58, 58)
		local edge = math.max(math.abs(x), math.abs(z)) > 50
		local inPractice = x < -14 and z > 26
		local nearFeature = (z < -44) or (x > 40) or (z > 38 and x > -16) or (x < -44)
		if edge and not inPractice and not nearFeature then
			placed += 1
			local roll = rng:NextNumber()
			if roll < 0.5 then
				Kit.tuft(decor, Vector3.new(x, 0, z), rng)
			else
				Kit.flower(decor, Vector3.new(x, 0, z), if roll < 0.75 then PAL.pink else PAL.white)
			end
		end
	end

	return lobby
end
