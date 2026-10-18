--!nocheck
-- LobbyProps: the set pieces of the Oct 2026 lobby redo. Each builder takes a local frame F
-- (a CFrame at ground level whose -Z / LookVector faces the way the piece faces).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.EOS.Shared
local EggModel = require(Shared.EggModel)
local Kit = require(script.Parent.WorldKit)
local PAL = Kit.PAL
local INK = PAL.ink
local FRONT = Enum.NormalId.Front

local Props = {}

local GOLD = Color3.fromRGB(236, 186, 70)
local GOLD2 = Color3.fromRGB(206, 152, 52)
local GOLD3 = Color3.fromRGB(252, 214, 110)
local BOARD = INK:Lerp(PAL.blueDark, 0.35)
Props.GOLD = GOLD

-- Palette sampled from the toolkit's hub references (pastel island hub, market street, plot islands):
-- vivid lime grass, rose cliffs, periwinkle/lavender paving, coral-pink wood, candy accents.
local REF = {
	lime = Color3.fromRGB(144, 228, 74),
	limeDark = Color3.fromRGB(118, 206, 58),
	limeLight = Color3.fromRGB(168, 240, 96),
	blade = Color3.fromRGB(96, 196, 56),
	rose = { Color3.fromRGB(232, 124, 126), Color3.fromRGB(216, 104, 112), Color3.fromRGB(196, 88, 100) },
	peri = Color3.fromRGB(160, 166, 238),
	periLight = Color3.fromRGB(184, 190, 248),
	periDark = Color3.fromRGB(122, 128, 208),
	coral = Color3.fromRGB(232, 134, 112),
	coralDark = Color3.fromRGB(206, 108, 96),
	salmonTile = Color3.fromRGB(236, 140, 124),
	pink = Color3.fromRGB(240, 96, 200),
	mint = Color3.fromRGB(110, 226, 130),
}
Props.REF = REF

local function label(parent, name, text, color, align, posY, height, stroke)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, height or 0.1)
	t.Position = UDim2.fromScale(0, posY or 0)
	t.FontFace = Kit.FONT
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextXAlignment = align or Enum.TextXAlignment.Center
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = stroke or 3
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.Parent = t
	t.Parent = parent
	return t
end
Props.label = label

local function gui(part, ppx, maxDist)
	local sg = Instance.new("SurfaceGui")
	sg.Face = FRONT
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = ppx or 40
	sg.LightInfluence = 0
	sg.MaxDistance = maxDist or 220
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = sg
	sg.Parent = part
	return holder, sg
end

-- ===================================================================================
-- Statue: a blocky player mid-dive, arms out, about to catch an egg. All gold, on a stepped
-- plinth standing in a wishing-fountain basin. Profile faces the spawn (dives toward +X).
-- ===================================================================================
function Props.statue(parent, center: Vector3, rng)
	local m = Kit.model(parent, "DivingCatchStatue")
	local cx, cz = center.X, center.Z
	-- fountain basin: dark bed, transparent water, low stone rim (rim embedded into the water edge)
	local basin = Kit.model(m, "Fountain")
	local R = 12
	Kit.box(basin, "Bed", cx - R, cx + R, 0.15, 0.3, cz - R, cz + R, Color3.fromRGB(70, 140, 210), { Pattern = "Universal" })
	Kit.box(basin, "Water", cx - R - 0.2, cx + R + 0.2, 0.3, 1.1, cz - R - 0.2, cz + R + 0.2, Color3.fromRGB(110, 210, 245), { Pattern = "Smooth", Transparency = 0.35, CanCollide = false, CastShadow = false })
	for _, e in { { "N", cx - R - 1.4, cx + R + 1.4, cz - R - 1.4, cz - R + 0.2 }, { "S", cx - R - 1.4, cx + R + 1.4, cz + R - 0.2, cz + R + 1.4 }, { "W", cx - R - 1.4, cx - R + 0.2, cz - R + 0.2, cz + R - 0.2 }, { "E", cx + R - 0.2, cx + R + 1.4, cz - R + 0.2, cz + R - 0.2 } } do
		Kit.box(basin, "Rim" .. e[1], e[2], e[3], 0.15, 1.6, e[4], e[5], PAL.stone2, { Pattern = "Weld" })
		Kit.box(basin, "RimCap" .. e[1], e[2] - 0.2, e[3] + 0.2, 1.6, 2.0, e[4] - 0.2, e[5] + 0.2, PAL.stone, { Pattern = "Studs" })
	end
	-- wishing coins on the bed + lily pads on the surface
	for i = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8.4, 11)
		Kit.brick(basin, "Coin", Vector3.new(0.8, 0.1, 0.8), CFrame.new(cx + math.cos(a) * r, 0.36, cz + math.sin(a) * r) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 5) * 15), 0), GOLD3, { Pattern = "Smooth" })
	end
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + 0.4
		local pad = Kit.model(basin, "LilyPad")
		Kit.brick(pad, "Pad", Vector3.new(2, 0.15, 2), CFrame.new(cx + math.cos(a) * 10, 1.15, cz + math.sin(a) * 10) * CFrame.Angles(0, math.rad(i * 15), 0), PAL.leaf2, { Pattern = "Smooth" })
		if i % 2 == 0 then
			Kit.brick(pad, "Bloom", Vector3.new(0.6, 0.4, 0.6), CFrame.new(cx + math.cos(a) * 10, 1.4, cz + math.sin(a) * 10), PAL.pink, { Pattern = "Smooth" })
		end
	end
	-- stepped plinth with gold trim
	local plinth = Kit.model(m, "Plinth")
	local y = 0.3
	for i, w in { 13, 10.6, 8.4 } do
		local h = if i == 3 then 1.6 else 1.4
		Kit.brick(plinth, "Step" .. i, Vector3.new(w, h, w), CFrame.new(cx, y + h / 2, cz), if i == 2 then PAL.stone2 else PAL.stone, { Pattern = "Studs" })
		Kit.brick(plinth, "Trim" .. i, Vector3.new(w + 0.3, 0.35, w + 0.3), CFrame.new(cx, y + h - 0.175 + 0.0001 * i, cz), GOLD2, { Pattern = "Weld" })
		y += h
	end
	local top = y
	-- plaque on the south face (toward the spawn)
	local plaque = Kit.brick(plinth, "Plaque", Vector3.new(7, 1.6, 0.3), CFrame.new(cx, 0.3 + 1.4 + 0.75, cz + 5.3 + 0.15) * CFrame.Angles(0, math.rad(180), 0), GOLD, { Pattern = "Smooth" })
	local ph = gui(plaque, 60)
	label(ph, "Line1", "THE GREAT CATCH", INK, nil, 0.08, 0.5, 0)
	label(ph, "Line2", "never stop diving", INK:Lerp(GOLD2, 0.4), nil, 0.58, 0.34, 0)

	-- the figure: a blocky avatar mid-dive. Body frame: +Y = head direction (dive line, 10 deg up
	-- toward +X), LookVector = chest (facing the ground), +Z = back (facing the sky).
	local fig = Kit.model(m, "Figure")
	local SKIN = Color3.fromRGB(234, 180, 134)
	local SHIRT = Color3.fromRGB(70, 150, 255)
	local PANTS = Color3.fromRGB(44, 62, 128)
	local SHOE = PAL.white
	local HAIR = Color3.fromRGB(110, 70, 44)
	local S = 2.6
	local ang = math.rad(10)
	local d = Vector3.new(math.cos(ang), math.sin(ang), 0)
	local torsoPos = Vector3.new(cx - 2.2, top + 5.2, cz)
	local B = CFrame.fromMatrix(torsoPos, Vector3.new(0, 0, 1), d)
	local function limb(name, size, offset, extra, col, pat)
		local cf = B * CFrame.new(offset * S) * (extra or CFrame.identity)
		return Kit.brick(fig, name, size * S, cf, col, { Pattern = pat or "Universal" })
	end
	limb("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), nil, SHIRT, "Studs")
	limb("BackStripe", Vector3.new(2.04, 0.35, 0.1), Vector3.new(0, 0.35, 0.52), nil, PAL.white, "Smooth")
	limb("Belt", Vector3.new(2.05, 0.22, 1.05), Vector3.new(0, -0.9, 0), nil, PANTS:Lerp(PAL.ink, 0.3), "Weld")
	limb("Neck", Vector3.new(0.6, 0.3, 0.6), Vector3.new(0, 1.05, 0), nil, SKIN)
	-- head tipped back 35 deg so the face looks along the arms at the egg
	local headCF = B * CFrame.new(Vector3.new(0, 1.65, 0) * S) * CFrame.Angles(math.rad(35), 0, 0)
	Kit.brick(fig, "Head", Vector3.new(1.2, 1.2, 1.2) * S, headCF, SKIN, { Pattern = "Universal" })
	Kit.brick(fig, "Hair", Vector3.new(1.26, 0.45, 1.26) * S, headCF * CFrame.new(0, 0.5 * S, 0.06 * S), HAIR, { Pattern = "Studs" })
	Kit.brick(fig, "HairBack", Vector3.new(1.26, 0.9, 0.3) * S, headCF * CFrame.new(0, 0.2 * S, 0.5 * S), HAIR, { Pattern = "Studs" })
	for _, ex in { -0.24, 0.24 } do
		Kit.brick(fig, "Eye", Vector3.new(0.18, 0.28, 0.08) * S, headCF * CFrame.new(ex * S, 0.08 * S, -0.62 * S), PAL.ink, { Pattern = "Smooth" })
	end
	Kit.brick(fig, "Smile", Vector3.new(0.5, 0.12, 0.08) * S, headCF * CFrame.new(0, -0.24 * S, -0.62 * S), PAL.ink, { Pattern = "Smooth" })
	-- arms stretched past the head, hands spread around the egg
	for _, sx in { -1, 1 } do
		limb("Arm", Vector3.new(1, 2, 1), Vector3.new(sx * 1.5, 1.7, 0), CFrame.Angles(0, 0, math.rad(sx * 6)), SHIRT, "Studs")
		limb("Hand", Vector3.new(1.02, 0.55, 1.02), Vector3.new(sx * 1.6, 2.92, 0), CFrame.Angles(0, 0, math.rad(sx * 6)), SKIN)
		limb("Cuff", Vector3.new(1.04, 0.2, 1.04), Vector3.new(sx * 1.58, 2.6, 0), CFrame.Angles(0, 0, math.rad(sx * 6)), PAL.white, "Smooth")
	end
	-- legs trail behind; the right one kicks up 15 deg
	limb("LegL", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), nil, PANTS)
	limb("ShoeL", Vector3.new(1.04, 0.55, 1.15), Vector3.new(-0.5, -2.85, 0.03), nil, SHOE, "Weld")
	local kick = CFrame.new(Vector3.new(0.5, -1, 0) * S) * CFrame.Angles(math.rad(15), 0, 0)
	Kit.brick(fig, "LegR", Vector3.new(1, 2, 1) * S, B * kick * CFrame.new(0, -1 * S, 0), PANTS, { Pattern = "Universal" })
	Kit.brick(fig, "ShoeR", Vector3.new(1.04, 0.55, 1.15) * S, B * kick * CFrame.new(0, -1.85 * S, 0.03 * S), SHOE, { Pattern = "Weld" })
	for _, sx in { -0.5, 0.5 } do
		Kit.brick(fig, "Sole", Vector3.new(1.06, 0.18, 1.17) * S, (if sx < 0 then B * CFrame.new(Vector3.new(-0.5, -3.1, 0.03) * S) else B * kick * CFrame.new(0, -2.1 * S, 0.03 * S)), PAL.red, { Pattern = "Smooth" })
	end
	-- the egg, upright, just at the fingertips (tier 4 so it pops against the blue)
	local egg = EggModel.build(4, false, 1.9)
	egg.Name = "StatueEgg"
	local hands = B * (Vector3.new(0, 3.35, 0) * S)
	local _, eggSize = egg:GetBoundingBox()
	egg:PivotTo(CFrame.new(hands - Vector3.new(0, eggSize.Y * 0.45, 0)))
	egg.Parent = fig
	-- what holds it up: a white dust cloud kicked up under the belly (chunky puffs, plinth to body)
	local support = Kit.model(fig, "DustCloud")
	local belly = B * (Vector3.new(0, -0.3, -0.5) * S)
	local py = top
	local puffs = { { 4.4, 1.6, 0.6, 0 }, { 3.6, 1.6, -0.4, 15 }, { 3.0, 1.4, 0.3, 30 } }
	for i, p in puffs do
		local h = if i == #puffs then math.max(1.2, belly.Y - py + 0.6) else p[2]
		Kit.brick(support, "Puff" .. i, Vector3.new(p[1], h, p[1] * 0.9), CFrame.new(belly.X + p[3], py + h / 2, cz) * CFrame.Angles(0, math.rad(p[4]), 0), if i % 2 == 0 then PAL.cream else PAL.white, { Pattern = "Studs" })
		py += h - 0.1
	end
	for k = 1, 3 do
		Kit.brick(support, "Wisp", Vector3.new(1.4, 1.2, 1.4), CFrame.new(belly.X - 3 - k * 1.6, top + 0.6 + k * 0.4, cz + (k - 2) * 1.4) * CFrame.Angles(0, math.rad(k * 15), 0), PAL.white, { Pattern = "Studs" })
	end
	-- speed lines trailing off the feet
	local feet = B * (Vector3.new(0, -3.1, 0) * S)
	for k, dz in { -1.6, 0, 1.6 } do
		Kit.brick(fig, "SpeedLine", Vector3.new(3.4 + k * 0.6, 0.3, 0.3), CFrame.new(feet + Vector3.new(-2.6 - k * 0.3, 0.2 + k * 0.4, dz)) * CFrame.Angles(0, 0, ang), PAL.white, { Pattern = "Smooth" })
	end
	return m
end

-- ===================================================================================
-- Swivelling leaderboard: fixed stone base + a "SwivelHead" model (tag EOS_FacePlayer) that the
-- client turns to face the local player. The board slab keeps tag EOS_Board + Stat attribute and
-- the same SurfaceGui rows LobbyService fills (Title / Scope / Row1..8 with PlayerName + Value).
-- ===================================================================================
function Props.swivelBoard(parent, F: CFrame, stat, title, color: Color3)
	local m = Kit.model(parent, "Board_" .. stat)
	-- base (static)
	Kit.brick(m, "Plinth", Vector3.new(5.6, 1.4, 5.6), F * CFrame.new(0, 0.7, 0), REF.peri, { Pattern = "Studs" })
	Kit.brick(m, "PlinthTrim", Vector3.new(5.9, 0.35, 5.9), F * CFrame.new(0, 1.25, 0), color, { Pattern = "Weld" })
	Kit.brick(m, "Collar", Vector3.new(3.4, 0.8, 3.4), F * CFrame.new(0, 1.8, 0), PAL.stone2, { Pattern = "Weld" })
	for _, sx in { -1, 1 } do
		local f = Kit.model(m, "Flowers")
		Kit.brick(f, "Bed", Vector3.new(2.2, 0.6, 4.4), F * CFrame.new(sx * 4.2, 0.3, 0), PAL.dirt2, { Pattern = "Universal" })
		for k = -1, 1 do
			Kit.flower(f, (F * CFrame.new(sx * 4.2, 0.6, k * 1.4)).Position, if k == 0 then PAL.gold else PAL.pink)
		end
	end
	-- head (turns)
	local head = Kit.model(m, "SwivelHead")
	local pivot = Kit.brick(head, "Pivot", Vector3.new(1, 1, 1), F * CFrame.new(0, 2.2, 0), PAL.stoneDark, { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, Pattern = "Smooth" })
	head.PrimaryPart = pivot
	head:AddTag("EOS_FacePlayer")
	Kit.brick(head, "Post", Vector3.new(1.8, 3.4, 1.8), F * CFrame.new(0, 3.6, 0.4), PAL.stoneDark, { Pattern = "Weld" })
	local board = Kit.brick(head, "Board", Vector3.new(14, 13, 1.2), F * CFrame.new(0, 11.4, 0.4), BOARD, { Pattern = "Studs", Tags = { "EOS_Board" }, Attrs = { Stat = stat } })
	-- chunky frame proud of the board on every side (one per side, corners overlap inside the model)
	Kit.brick(head, "FrameTop", Vector3.new(15.6, 1.2, 1.8), F * CFrame.new(0, 18.5, 0.4), REF.coral, { Pattern = "Weld" })
	Kit.brick(head, "FrameBottom", Vector3.new(15.6001, 1.2001, 1.8001), F * CFrame.new(0, 4.3, 0.4), REF.coral, { Pattern = "Weld" })
	for _, sx in { -1, 1 } do
		Kit.brick(head, "FrameSide", Vector3.new(1.2, 13.4, 1.7), F * CFrame.new(sx * 7.2, 11.4, 0.4), REF.coralDark, { Pattern = "Weld" })
		Kit.brick(head, "FrameCap", Vector3.new(1.8, 0.8, 2.2), F * CFrame.new(sx * 7.2, 19.4, 0.4), REF.periDark, { Pattern = "Studs" })
		Kit.brick(head, "FrameFoot", Vector3.new(1.8, 0.8, 2.2), F * CFrame.new(sx * 7.2, 3.5, 0.4), REF.periDark, { Pattern = "Studs" })
	end
	-- crest on top: stepped block with a gold medal
	Kit.brick(head, "Crest", Vector3.new(7, 1.6, 1.8), F * CFrame.new(0, 19.7, 0.4), color, { Pattern = "Studs" })
	Kit.brick(head, "CrestTop", Vector3.new(4, 1.2, 1.7), F * CFrame.new(0, 21.1, 0.4), color:Lerp(PAL.white, 0.2), { Pattern = "Studs" })
	Kit.brick(head, "Medal", Vector3.new(2, 2, 0.6), F * CFrame.new(0, 19.9, -0.45) * CFrame.Angles(0, 0, math.rad(45)), GOLD3, { Pattern = "Smooth" })
	Kit.floatingText(board, title, color, 15, 11.5)
	-- back panel so the reverse isn't bare while it turns
	Kit.brick(head, "BackPanel", Vector3.new(12, 11, 0.3), F * CFrame.new(0, 11.4, 1.1), color:Lerp(INK, 0.45), { Pattern = "Weld" })
	-- SurfaceGui identical in structure to the old boards (LobbyService fills it)
	local holder = gui(board, 40, 220)
	label(holder, "Title", title, color, nil, 0.03, 0.12)
	label(holder, "Scope", "THIS SERVER  ·  LIVE", Color3.fromRGB(190, 200, 220), nil, 0.15, 0.06)
	for r = 1, 8 do
		local row = Instance.new("Frame")
		row.Name = "Row" .. r
		row.BackgroundColor3 = if r == 1 then GOLD3 elseif r == 2 then Color3.fromRGB(210, 220, 236) elseif r == 3 then Color3.fromRGB(236, 160, 100) else Color3.new(1, 1, 1)
		row.BackgroundTransparency = if r <= 3 then 0.7 else (if r % 2 == 0 then 0.94 else 0.88)
		row.Position = UDim2.fromScale(0.05, 0.23 + (r - 1) * 0.095)
		row.Size = UDim2.fromScale(0.9, 0.085)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = row
		local n = label(row, "PlayerName", "", Color3.new(1, 1, 1), Enum.TextXAlignment.Left, 0.1, 0.8)
		n.Size = UDim2.fromScale(0.68, 0.8)
		n.Position = UDim2.fromScale(0.03, 0.1)
		local v = label(row, "Value", "", color, Enum.TextXAlignment.Right, 0.1, 0.8)
		v.Size = UDim2.fromScale(0.28, 0.8)
		v.Position = UDim2.fromScale(0.69, 0.1)
		row.Parent = holder
	end
	return m, board
end

-- ===================================================================================
-- Shop stall (the references' universal shop): coral-wood deck and posts, an L counter, a
-- green/white striped GABLE awning, crates of wares, big floating title. Counter = prompt.
-- ===================================================================================
function Props.shopBooth(parent, F: CFrame)
	local m = Kit.model(parent, "ShopStall")
	local A, B = REF.mint, PAL.white
	-- deck on periwinkle footings
	Kit.brick(m, "Deck", Vector3.new(20, 0.8, 14), F * CFrame.new(0, 0.7, 1), REF.coral, { Pattern = "Weld" })
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.brick(m, "Footing", Vector3.new(1.6, 0.4, 1.6), F * CFrame.new(sx * 9, 0.2, 1 + sz * 6), REF.periDark, { Pattern = "Studs" })
		end
	end
	Kit.brick(m, "Step", Vector3.new(8, 0.4, 2), F * CFrame.new(0, 0.2, -7), REF.peri, { Pattern = "Studs" })
	-- four chunky posts + top beams
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.brick(m, "Post", Vector3.new(1.2, 10, 1.2), F * CFrame.new(sx * 9, 6.1, 1 + sz * 5.8), REF.coral, { Pattern = "Weld" })
		end
		Kit.brick(m, "BeamSide", Vector3.new(1.0, 1.0, 13.2), F * CFrame.new(sx * 9, 11.4, 1), REF.coralDark, { Pattern = "Weld" })
	end
	for _, sz in { -1, 1 } do
		Kit.brick(m, "BeamFront", Vector3.new(19.4, 1.0, 1.0), F * CFrame.new(0, 11.4001, 1 + sz * 5.8), REF.coralDark, { Pattern = "Weld" })
	end
	-- gable awning: stripes along X, two pitched sides meeting at a ridge beam
	local ridgeY = 14.6
	for _, side in { -1, 1 } do
		for k = 0, 9 do
			local x = -9.9 + 2.2 * (k + 0.5)
			local cf = F * CFrame.new(x, ridgeY, 1) * CFrame.Angles(math.rad(30 * side), 0, 0) * CFrame.new(0, -0.2, side * 4.1)
			Kit.brick(m, "Awning", Vector3.new(2.21, 0.5, 8.4), cf, if k % 2 == 0 then A else B, { Pattern = "Studs" })
		end
		-- scalloped valance along the eave
		for k = 0, 9 do
			local x = -9.9 + 2.2 * (k + 0.5)
			local eave = F * CFrame.new(x, ridgeY, 1) * CFrame.Angles(math.rad(30 * side), 0, 0) * CFrame.new(0, -0.6, side * 8.2)
			Kit.brick(m, "Valance", Vector3.new(2.21, if k % 2 == 0 then 1.4 else 0.9, 0.4), CFrame.new(eave.Position) * F.Rotation, if k % 2 == 0 then A else B, { Pattern = "Smooth" })
		end
	end
	Kit.brick(m, "Ridge", Vector3.new(20.6, 0.8, 0.8), F * CFrame.new(0, ridgeY + 0.2, 1), REF.coralDark, { Pattern = "Weld" })
	-- L counter (front run is the prompt) with a lighter plank top and a periwinkle kick panel
	local counter = Kit.brick(m, "Counter", Vector3.new(14, 3, 1.8), F * CFrame.new(0, 2.6, -3.6), REF.coral, { Pattern = "Weld", Tags = { "EOS_Prompt" }, Attrs = { Screen = "Shop", Tab = "gold", Label = "Shop", Action = "Browse" } })
	Kit.brick(m, "CounterTop", Vector3.new(14.6, 0.4, 2.4), F * CFrame.new(0, 4.3, -3.6), PAL.cream, { Pattern = "Weld" })
	Kit.brick(m, "CounterKick", Vector3.new(14.2, 0.8, 0.3), F * CFrame.new(0, 1.5, -4.6), REF.peri, { Pattern = "Studs" })
	Kit.brick(m, "CounterSide", Vector3.new(1.8, 3, 6), F * CFrame.new(-7.6, 2.6, -0.3), REF.coral, { Pattern = "Weld" })
	Kit.brick(m, "CounterSideTop", Vector3.new(2.4, 0.4, 6.6), F * CFrame.new(-7.6, 4.3, -0.3), PAL.cream, { Pattern = "Weld" })
	-- wares on the counter: coin stacks, gems, a little gift box
	for c = 0, 2 do
		Kit.brick(m, "Coins", Vector3.new(1.3, 0.35, 1.3), F * CFrame.new(-4.5, 4.7 + c * 0.35, -3.6) * CFrame.Angles(0, math.rad(c * 15), 0), if c % 2 == 0 then GOLD else GOLD3, { Pattern = "Smooth" })
	end
	for k, col in { Color3.fromRGB(60, 220, 130), Color3.fromRGB(110, 170, 255), REF.pink } do
		Kit.brick(m, "Gem", Vector3.new(1, 1, 1), F * CFrame.new(-1 + (k - 1) * 1.6, 5.1, -3.6) * CFrame.Angles(math.rad(45), 0, math.rad(45)), col, { Pattern = "Smooth" })
	end
	local gift = Kit.model(m, "Gift")
	Kit.brick(gift, "Box", Vector3.new(1.8, 1.6, 1.8), F * CFrame.new(4.6, 5.3, -3.6), PAL.red, { Pattern = "Studs" })
	Kit.brick(gift, "RibbonA", Vector3.new(0.4, 1.7, 1.9), F * CFrame.new(4.6, 5.3, -3.6), GOLD3, { Pattern = "Smooth" })
	Kit.brick(gift, "RibbonB", Vector3.new(1.9, 1.7, 0.4), F * CFrame.new(4.6, 5.3, -3.6), GOLD3, { Pattern = "Smooth" })
	-- back shelf with crates (crate = gold cube + dark corner trims + X brace)
	Kit.brick(m, "Shelf", Vector3.new(16, 0.5, 2), F * CFrame.new(0, 5.2, 5.6), REF.coralDark, { Pattern = "Weld" })
	for k = 0, 3 do
		local cx = -6 + k * 4
		local crate = Kit.model(m, "Crate")
		local ccf = F * CFrame.new(cx, 6.6, 5.6) * CFrame.Angles(0, math.rad((k % 2) * 15), 0)
		Kit.brick(crate, "Body", Vector3.new(2.4, 2.4, 2.4), ccf, if k % 2 == 0 then GOLD else REF.salmonTile, { Pattern = "Weld" })
		Kit.brick(crate, "BraceA", Vector3.new(0.3, 3.1, 2.5), ccf * CFrame.Angles(math.rad(45), 0, 0) * CFrame.new(-1.15, 0, 0), INK:Lerp(REF.coralDark, 0.5), { Pattern = "Smooth" })
		Kit.brick(crate, "BraceB", Vector3.new(0.3, 3.1, 2.5), ccf * CFrame.Angles(math.rad(45), 0, 0) * CFrame.new(1.15, 0, 0), INK:Lerp(REF.coralDark, 0.5), { Pattern = "Smooth" })
	end
	-- crates stacked beside the stall on the deck
	for k, o in { { 7, -5, 0 }, { 7.6, -5, 2.4 } } do
		local ccf = F * CFrame.new(o[1] + 4, 1.1 + 1.2 + o[3], o[2] + 2) * CFrame.Angles(0, math.rad(k * 15), 0)
		Kit.brick(m, "SideCrate", Vector3.new(2.4, 2.4, 2.4), ccf, GOLD, { Pattern = "Weld" })
	end
	-- hanging sign under the front beam
	local sign = Kit.brick(m, "Sign", Vector3.new(9, 2.4, 0.5), F * CFrame.new(0, 9.4, -5.6), BOARD, { Pattern = "Weld" })
	Kit.surfaceText(sign, FRONT, { { text = "SHOP", size = 0.8, color = GOLD3 } }, { PixelsPerStud = 40 })
	for _, sx in { -3.6, 3.6 } do
		Kit.brick(m, "SignChain", Vector3.new(0.2, 1.4, 0.2), F * CFrame.new(sx, 11.0, -5.6), INK, { Pattern = "Smooth" })
	end
	Kit.floatingText(counter, "SHOP", REF.mint, 18, 15)
	return m
end

-- ===================================================================================
-- Event board: a wide noticeboard with a header banner, bunting, three pinned cards.
-- Board part tagged EOS_EventBoard with a Title/Body SurfaceGui for a future events system.
-- ===================================================================================
function Props.eventBoard(parent, F: CFrame)
	local m = Kit.model(parent, "EventBoard")
	local BLUE, PINK = Color3.fromRGB(176, 96, 236), Color3.fromRGB(255, 120, 170)
	Kit.brick(m, "Platform", Vector3.new(26, 0.6, 8), F * CFrame.new(0, 0.3, 1), REF.peri, { Pattern = "Studs" })
	for _, sx in { -1, 1 } do
		Kit.brick(m, "Post", Vector3.new(1.6, 15, 1.6), F * CFrame.new(sx * 11.6, 8.1, 1), REF.coral, { Pattern = "Weld" })
		Kit.brick(m, "PostCap", Vector3.new(2.2, 0.8, 2.2), F * CFrame.new(sx * 11.6, 16, 1), GOLD, { Pattern = "Studs" })
		local pl = Kit.model(m, "Planter")
		Kit.brick(pl, "Box", Vector3.new(3.4, 1.8, 3.4), F * CFrame.new(sx * 11.6, 1.5, -2.2), REF.coralDark, { Pattern = "Weld" })
		Kit.brick(pl, "Soil", Vector3.new(3, 0.3, 3), F * CFrame.new(sx * 11.6, 2.45, -2.2), PAL.dirt3, { Pattern = "Universal" })
		for k = 0, 2 do
			Kit.flower(pl, (F * CFrame.new(sx * 11.6 + (k - 1) * 0.9, 2.6, -2.2 + (k - 1) * 0.6)).Position, if k == 1 then PAL.gold else PINK)
		end
	end
	local board = Kit.brick(m, "Board", Vector3.new(21.6, 11, 0.8), F * CFrame.new(0, 8.5, 1), PAL.cream, { Pattern = "Studs", Tags = { "EOS_EventBoard" } })
	Kit.brick(m, "FrameTop", Vector3.new(22.2, 0.8, 1.2), F * CFrame.new(0, 14.2, 1), BLUE, { Pattern = "Weld" })
	Kit.brick(m, "FrameBottom", Vector3.new(22.2, 0.8, 1.2), F * CFrame.new(0, 2.8, 1), BLUE, { Pattern = "Weld" })
	-- header banner with a stepped top
	local header = Kit.brick(m, "Header", Vector3.new(14, 3.2, 1.2), F * CFrame.new(0, 16.4, 1), BLUE, { Pattern = "Studs" })
	Kit.brick(m, "HeaderTop", Vector3.new(9, 1, 1.1), F * CFrame.new(0, 18.5, 1), BLUE:Lerp(PAL.white, 0.2), { Pattern = "Studs" })
	Kit.brick(m, "Star", Vector3.new(1.6, 1.6, 0.4), F * CFrame.new(0, 18.6, 0.4) * CFrame.Angles(0, 0, math.rad(45)), GOLD3, { Pattern = "Smooth" })
	Kit.surfaceText(header, FRONT, { { text = "EVENTS", size = 0.8, color = GOLD3 } }, { PixelsPerStud = 40 })
	-- three pinned cards (relief plates on the board) with pins
	for k, col in { PINK, Color3.fromRGB(110, 210, 200), GOLD } do
		local x = (k - 2) * 7
		Kit.brick(m, "Card", Vector3.new(5.6, 6.4, 0.3), F * CFrame.new(x, 8.2, 0.5) * CFrame.Angles(0, 0, math.rad((k - 2) * -5)), col, { Pattern = "Weld" })
		Kit.brick(m, "CardStripe", Vector3.new(4.4, 0.6, 0.15), F * CFrame.new(x, 10.4, 0.3) * CFrame.Angles(0, 0, math.rad((k - 2) * -5)), PAL.white, { Pattern = "Smooth" })
		Kit.brick(m, "Pin", Vector3.new(0.5, 0.5, 0.3), F * CFrame.new(x, 11.1, 0.25), PAL.red, { Pattern = "Smooth" })
	end
	-- text layer on the board (front): placeholder until events exist
	local holder = gui(board, 30)
	label(holder, "Title", "", PAL.ink, nil, 0.02, 0.1, 0)
	label(holder, "Body", "NEW EVENTS SOON", PAL.redDark, nil, 0.86, 0.12, 0)
	-- bunting between the post caps: sagging chain of little flags
	local bunt = Kit.model(m, "Bunting")
	local a, b = (F * CFrame.new(-11.6, 15.6, 0.4)).Position, (F * CFrame.new(11.6, 15.6, 0.4)).Position
	local N = 12
	local cols = { PINK, GOLD, PAL.blue, Color3.fromRGB(120, 236, 140) }
	local prev = a
	for i = 1, N do
		local t = i / N
		local p = a:Lerp(b, t) + Vector3.new(0, -math.sin(t * math.pi) * 1.4, 0)
		local mid = (prev + p) / 2
		Kit.brick(bunt, "String", Vector3.new(0.15, 0.15, (p - prev).Magnitude + 0.2), CFrame.lookAt(mid, p), PAL.white, { Pattern = "Smooth" })
		if i < N then
			Kit.brick(bunt, "Flag", Vector3.new(1.1, 1.1, 0.15), CFrame.new(p + Vector3.new(0, -0.65, 0)) * F.Rotation * CFrame.Angles(0, 0, math.rad(45)), cols[i % #cols + 1], { Pattern = "Smooth" })
		end
		prev = p
	end
	Kit.floatingText(header, "EVENTS", REF.pink, 16, 6)
	return m, board
end

-- ===================================================================================
-- Treasure chest on a stepped dais: banded wooden chest, lid propped open, glowing inside,
-- coins and gems spilling. Body tagged EOS_Chest (no prompt yet: no chest system in the game).
-- ===================================================================================
function Props.chest(parent, F: CFrame, rng)
	local m = Kit.model(parent, "TreasureChest")
	local WOOD, WOOD2 = Color3.fromRGB(168, 100, 58), Color3.fromRGB(138, 80, 48)
	local y = 0
	for i, w in { 16, 13, 10 } do
		Kit.brick(m, "Dais" .. i, Vector3.new(w, 0.8, w), F * CFrame.new(0, y + 0.4, 0), if i == 2 then PAL.stone2 else PAL.stone, { Pattern = "Studs" })
		y += 0.8
	end
	local base = y
	local W, H, D = 7, 4, 5
	local body = Kit.brick(m, "Body", Vector3.new(W, H, D), F * CFrame.new(0, base + H / 2, 0), WOOD, { Pattern = "Weld", Tags = { "EOS_Chest" } })
	-- planks: horizontal relief strips on the front
	for k = 0, 2 do
		Kit.brick(m, "Plank", Vector3.new(W - 0.6, 0.2, 0.2), F * CFrame.new(0, base + 0.9 + k * 1.2, -D / 2 - 0.05), WOOD2, { Pattern = "Smooth" })
	end
	-- gold bands wrapping the body (proud 0.15) and corner caps
	for _, bx in { -2.4, 2.4 } do
		Kit.brick(m, "Band", Vector3.new(0.7, H + 0.1, D + 0.3), F * CFrame.new(bx, base + H / 2, 0), GOLD, { Pattern = "Weld" })
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.brick(m, "Corner", Vector3.new(0.8, 0.8, 0.8), F * CFrame.new(sx * (W / 2 - 0.25), base + 0.4, sz * (D / 2 - 0.25)), GOLD2, { Pattern = "Smooth" })
		end
	end
	-- lock plate + keyhole on the front
	Kit.brick(m, "Lock", Vector3.new(1.6, 1.8, 0.4), F * CFrame.new(0, base + H - 0.9, -D / 2 - 0.15), GOLD3, { Pattern = "Weld" })
	Kit.brick(m, "Keyhole", Vector3.new(0.35, 0.7, 0.1), F * CFrame.new(0, base + H - 1.0, -D / 2 - 0.4), INK, { Pattern = "Smooth" })
	-- glowing treasure filling the open top (sits just inside the rim)
	Kit.brick(m, "Glow", Vector3.new(W - 0.8, 0.5, D - 0.8), F * CFrame.new(0, base + H - 0.1, 0), Color3.fromRGB(255, 214, 110), { Material = Enum.Material.Neon })
	for i = 1, 6 do
		Kit.brick(m, "TopCoin", Vector3.new(0.9, 0.25, 0.9), F * CFrame.new(rng:NextNumber(-2.6, 2.6), base + H + 0.25, rng:NextNumber(-1.6, 1.6)) * CFrame.Angles(math.rad(rng:NextInteger(-1, 1) * 15), math.rad(rng:NextInteger(0, 5) * 15), 0), GOLD3, { Pattern = "Smooth" })
	end
	-- lid: hinged at the back top edge, propped open 60 deg
	local hinge = F * CFrame.new(0, base + H, D / 2)
	local lidCF = hinge * CFrame.Angles(math.rad(60), 0, 0) * CFrame.new(0, 0.7, -D / 2 - 0.1)
	Kit.brick(m, "Lid", Vector3.new(W + 0.2, 1.4, D + 0.2), lidCF, WOOD2, { Pattern = "Weld" })
	for _, bx in { -2.4, 2.4 } do
		Kit.brick(m, "LidBand", Vector3.new(0.7, 1.5, D + 0.4), lidCF * CFrame.new(bx, 0, 0), GOLD, { Pattern = "Weld" })
	end
	-- spill: coins and a couple of gems on the dais in front
	for i = 1, 10 do
		Kit.brick(m, "SpillCoin", Vector3.new(0.9, 0.2, 0.9), F * CFrame.new(rng:NextNumber(-4, 4), base + 0.1, rng:NextNumber(-5, -3)) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 5) * 15), 0), if i % 3 == 0 then GOLD else GOLD3, { Pattern = "Smooth" })
	end
	Kit.brick(m, "Gem", Vector3.new(1, 1, 1), F * CFrame.new(-3, base + 0.6, -3.8) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color3.fromRGB(110, 170, 255), { Pattern = "Smooth" })
	Kit.brick(m, "Gem", Vector3.new(0.9, 0.9, 0.9), F * CFrame.new(3.2, base + 0.55, -3.4) * CFrame.Angles(math.rad(45), 0, math.rad(45)), PAL.red, { Pattern = "Smooth" })
	-- lamps at the back corners of the dais
	for _, sx in { -1, 1 } do
		Kit.lamp(m, (F * CFrame.new(sx * 6.4, 0.8, 6.4)).Position)
	end
	return m, body
end

-- ===================================================================================
-- Incubator: octagonal stepped base, stepped clear "dome" of tinted panes on four posts,
-- heat lamps, a control desk (the prompt) piped to the dome.
-- ===================================================================================
function Props.incubator(parent, F: CFrame)
	local m = Kit.model(parent, "Incubator")
	local y = 0
	for i, w in { 17, 13.5, 10.5 } do
		local h = if i == 3 then 1.2 else 1.4
		local col = if i == 2 then PAL.stone2 else PAL.stone
		-- octagon from a square + the same square turned 45 deg (inside one model)
		Kit.brick(m, "Base" .. i, Vector3.new(w, h, w), F * CFrame.new(0, y + h / 2, 3), col, { Pattern = "Studs" })
		Kit.brick(m, "Base" .. i .. "b", Vector3.new(w * 0.83, h + 0.0002, w * 0.83), F * CFrame.new(0, y + h / 2, 3) * CFrame.Angles(0, math.rad(45), 0), col, { Pattern = "Studs" })
		y += h
	end
	local egg = EggModel.build(3, false, 3.2)
	egg.Name = "IncubatingEgg"
	egg:PivotTo(F * CFrame.new(0, y + 0.1, 3))
	egg.Parent = m
	-- the clear dome: stacked shrinking panes, tinted, no collision (stepped silhouette)
	local dy = y
	for i, w in { 10, 9, 7.6, 5.4 } do
		local h = if i == 4 then 1.2 else 3
		Kit.brick(m, "Dome" .. i, Vector3.new(w, h, w), F * CFrame.new(0, dy + h / 2, 3), Color3.fromRGB(196, 232, 252), { Pattern = "Smooth", Transparency = 0.6, CanCollide = false, CanQuery = false, CastShadow = false })
		dy += h
	end
	Kit.brick(m, "DomeCap", Vector3.new(3, 0.8, 3), F * CFrame.new(0, dy + 0.4, 3), PAL.stoneDark, { Pattern = "Weld" })
	-- four corner posts with heat lamps leaning in
	for _, c in { { -5.6, -2.6 }, { 5.6, -2.6 }, { -5.6, 8.6 }, { 5.6, 8.6 } } do
		Kit.brick(m, "Post", Vector3.new(0.9, 12, 0.9), F * CFrame.new(c[1], 6, c[2]), INK:Lerp(PAL.stoneDark, 0.6), { Pattern = "Weld" })
		local inward = F * CFrame.new(c[1] * 0.8, 11.2, 3 + (c[2] - 3) * 0.8)
		local bulb = Kit.brick(m, "HeatLamp", Vector3.new(1.4, 1, 1.4), inward, Color3.fromRGB(255, 170, 90), { Material = Enum.Material.Neon })
		Kit.brick(m, "LampHood", Vector3.new(1.8, 0.5, 1.8), inward * CFrame.new(0, 0.7, 0), INK:Lerp(PAL.stoneDark, 0.6), { Pattern = "Smooth" })
		local light = Instance.new("PointLight")
		light.Range = 12
		light.Brightness = 0.9
		light.Color = Color3.fromRGB(255, 190, 120)
		light.Parent = bulb
	end
	-- control desk (prompt) with a slanted screen and three sample eggs
	local desk = Kit.brick(m, "Desk", Vector3.new(10, 3, 2.4), F * CFrame.new(0, 1.5, -6.6), PAL.white, { Pattern = "Weld", Tags = { "EOS_Prompt" }, Attrs = { Screen = "Incubator", Label = "Incubator", Action = "Hatch pets" } })
	Kit.brick(m, "DeskTop", Vector3.new(10.6, 0.4, 3), F * CFrame.new(0, 3.2, -6.6), PAL.stone2, { Pattern = "Weld" })
	local screen = Kit.brick(m, "Screen", Vector3.new(4, 2.2, 0.4), F * CFrame.new(-3, 4.6, -6.2) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(60, 200, 190), { Pattern = "Smooth" })
	Kit.surfaceText(screen, FRONT, { { text = "HATCH", size = 0.6, color = PAL.white } }, { PixelsPerStud = 50 })
	for k = 1, 2 do
		local small = EggModel.build(if k == 1 then 1 else 4, false, 1)
		small:PivotTo(F * CFrame.new(1 + (k - 1) * 2.6, 3.45, -6.6))
		small.Parent = m
	end
	-- two pipes from the desk back to the base (chained segments, ends embedded)
	for _, px in { -4, 4 } do
		local a = (F * CFrame.new(px, 2.2, -5.3)).Position
		local b = (F * CFrame.new(px * 0.7, 1.6, -3)).Position
		Kit.brick(m, "Pipe", Vector3.new(0.6, 0.6, (b - a).Magnitude + 0.4), CFrame.lookAt((a + b) / 2, b), PAL.stoneDark, { Pattern = "Smooth" })
	end
	-- sign on two posts behind
	local sign = Kit.brick(m, "Sign", Vector3.new(16, 3, 0.6), F * CFrame.new(0, 15.6, 9.6), BOARD, { Pattern = "Weld" })
	Kit.surfaceText(sign, FRONT, { { text = "INCUBATOR", size = 0.5, color = GOLD3 }, { text = "Hatch egg pieces into pets", size = 0.32, color = PAL.cream } }, { PixelsPerStud = 40 })
	for _, lx in { -7.6, 7.6 } do
		Kit.brick(m, "SignPost", Vector3.new(0.8, 14.2, 0.8), F * CFrame.new(lx, 7.1, 9.6), PAL.wood2, { Pattern = "Weld" })
	end
	Kit.floatingText(desk, "INCUBATOR", GOLD3, 14, 9)
	return m, desk
end

-- bench facing along the frame's -Z
function Props.bench(parent, F: CFrame)
	local m = Kit.model(parent, "Bench")
	Kit.brick(m, "Seat", Vector3.new(5, 0.4, 1.6), F * CFrame.new(0, 1.6, 0), PAL.wood, { Pattern = "Weld" })
	Kit.brick(m, "Back", Vector3.new(5, 1.6, 0.4), F * CFrame.new(0, 2.6, 0.7), PAL.wood2, { Pattern = "Weld" })
	for _, sx in { -1, 1 } do
		Kit.brick(m, "Leg", Vector3.new(0.6, 1.4, 1.4), F * CFrame.new(sx * 2, 0.7, 0), PAL.stoneDark, { Pattern = "Weld" })
	end
	return m
end

-- Tile field: axis-aligned 4-stud tiles filling a band from (x0,z0) to (x1,z1), the edges
-- wobbling a tile in/out along the band so they step naturally. Two-tone checker by parity.
-- alongX: the band runs along X (edges wobble in Z) or along Z.
function Props.tiles(parent, name, x0, x1, z0, z1, alongX: boolean, colA: Color3, colB: Color3, rng, wobble: number?)
	local m = Kit.model(parent, name)
	local T = 4
	wobble = wobble or 1
	local phase = rng:NextNumber(0, math.pi * 2)
	local nx, nz = math.floor((x1 - x0) / T + 0.5), math.floor((z1 - z0) / T + 0.5)
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local along, across, nAcross = if alongX then i else j, if alongX then j else i, if alongX then nz else nx
			-- drop edge tiles on a sine wobble so the outline steps in and out
			local w = math.sin(along * 0.9 + phase) + rng:NextNumber(-0.4, 0.4)
			local skip = (across == 0 and w * wobble > 0.55) or (across == nAcross - 1 and w * wobble < -0.55)
			if not skip then
				local x, z = x0 + (i + 0.5) * T, z0 + (j + 0.5) * T
				local par = (i + j) % 2
				Kit.brick(m, "Tile", Vector3.new(T + 0.0002 * par, 0.3 + 0.0004 * par, T + 0.0002 * par), CFrame.new(x, 0.15 + 0.0002 * par, z), if par == 0 then colA else colB, { Pattern = "Universal" })
			end
		end
	end
	return m
end

-- worn dirt path: a chain of overlapping rectangles that meanders half a stud, never gaps.
function Props.path(parent, a: Vector3, b: Vector3, width: number, rng)
	local m = Kit.model(parent, "Path")
	local alongX = math.abs(b.X - a.X) > math.abs(b.Z - a.Z)
	local len = if alongX then math.abs(b.X - a.X) else math.abs(b.Z - a.Z)
	local dir = if alongX then math.sign(b.X - a.X) else math.sign(b.Z - a.Z)
	local p = 0
	local i = 0
	while p < len do
		i += 1
		local seg = math.min(rng:NextNumber(4, 7), len - p + 0.5)
		local w = width + rng:NextNumber(-0.6, 0.6)
		local off = rng:NextNumber(-0.5, 0.5)
		local s0, s1 = p - 0.5, p + seg
		local col = if i % 3 == 0 then PAL.dirt:Lerp(PAL.sand, 0.3) else PAL.dirt:Lerp(PAL.sand, 0.15)
		local yTop = 0.22 + (i % 2) * 0.0003
		if alongX then
			local x0, x1 = a.X + dir * s0, a.X + dir * s1
			Kit.box(m, "PathSeg", math.min(x0, x1), math.max(x0, x1), 0, yTop, a.Z + off - w / 2, a.Z + off + w / 2, col, { Pattern = "Universal" })
		else
			local z0, z1 = a.Z + dir * s0, a.Z + dir * s1
			Kit.box(m, "PathSeg", a.X + off - w / 2, a.X + off + w / 2, 0, yTop, math.min(z0, z1), math.max(z0, z1), col, { Pattern = "Universal" })
		end
		p += seg
	end
	return m
end

return Props
