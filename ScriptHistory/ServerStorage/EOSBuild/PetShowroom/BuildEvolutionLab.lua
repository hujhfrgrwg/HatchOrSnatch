--!nocheck
-- BuildEvolutionLab (Oct 15 2026): mock-ups of every kept pet's three evolution stages, built on the
-- ported Fishing with Pets! meshes with EvolutionKits add-ons, for judging the direction in Studio.
--   require(game.ServerStorage.EOSBuild.PetShowroom.BuildEvolutionLab)()
-- Output: workspace.EOS_EvolutionLab, south of the pet showroom. One row per ability, each pet shown
-- Level 1 -> Level 2 -> Level 3 (left to right, seen from the north), then a row of the pets to toss.
-- Level 2 = the pet's ★★ colourway + first add-ons; Level 3 = ★★★ colourway + full add-ons, glow,
-- particles, a bit bigger, new name. "Base redo" pets also get the Level 1 fixes (name, brows).
-- These are mock-ups: real evolved forms would be new meshes. Press Run to see them animate.

local ServerStorage = game:GetService("ServerStorage")
local Kits = require(script.Parent.EvolutionKits)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local GOLD, SILVER, BLACK, WHITE = rgb(255, 196, 40), rgb(176, 184, 198), rgb(30, 30, 38), rgb(240, 244, 250)
local RED, ORANGE, YELLOW = rgb(235, 52, 52), rgb(255, 128, 32), rgb(255, 226, 40)
local CYAN, ICE, BLUE, TEAL = rgb(70, 230, 255), rgb(170, 230, 255), rgb(40, 110, 230), rgb(30, 190, 170)
local PURPLE, MAGENTA, GREEN, IVORY = rgb(130, 60, 220), rgb(255, 60, 220), rgb(110, 255, 70), rgb(240, 228, 200)
local DARK = rgb(46, 44, 56)

-- per pet: names L1..L3, base fixes, L2/L3 add-ons, L3 effects, aura colour, ghost = see-through L3
local R = {}
-- Double Dash
R.ShadesShark = { names = { "Shades Shark", "Surf Shark", "Riptide Shark" },
	l2 = { { "spikes", WHITE } }, fx2 = { { "water", CYAN, "tail" } },
	l3 = { { "spikes", CYAN }, { "visor", CYAN } }, fx3 = { { "water", CYAN, "tail" }, { "sparks", CYAN } }, aura = CYAN }
R.SurferDog = { names = { "Surfer Dog", "Wave Dog", "Wave Rider" },
	l2 = { { "cape", TEAL, WHITE } }, fx2 = { { "water", CYAN, "tail" } },
	l3 = { { "cape", BLUE, CYAN }, { "visor", CYAN }, { "wings", CYAN, WHITE } }, fx3 = { { "water", CYAN }, { "sparks", CYAN } }, aura = CYAN }
R.ThunderWolf = { names = { "Thunder Wolf", "Storm Wolf", "Stormfang" },
	l2 = { { "mane", YELLOW, SILVER } }, fx2 = { { "sparks", YELLOW, "head" } },
	l3 = { { "mane", YELLOW, BLUE }, { "horns", DARK, YELLOW }, { "eyes", YELLOW } }, fx3 = { { "sparks", YELLOW }, { "sparks", CYAN, "tail" } }, aura = YELLOW }
R.PhoenixGull = { base = "rename to Phoenix + attitude brows", baseKits = { { "brows" } }, names = { "Phoenix", "Blaze Phoenix", "Sunfire Phoenix" },
	l2 = { { "brows" }, { "wings", ORANGE, YELLOW } }, fx2 = { { "fire", ORANGE, "tail" } },
	l3 = { { "brows" }, { "wings", ORANGE, YELLOW }, { "crown", GOLD, RED }, { "eyes", YELLOW } }, fx3 = { { "fire", ORANGE }, { "fire", YELLOW, "tail" } }, aura = ORANGE }
R.FireDragon = { names = { "Fire Dragon", "Ember Drake", "Inferno Drake" },
	l2 = { { "horns", DARK, ORANGE }, { "spikes", DARK } }, fx2 = { { "fire", ORANGE, "head" } },
	l3 = { { "horns", BLACK, ORANGE, true }, { "spikes", ORANGE }, { "wings", RED, ORANGE }, { "eyes", YELLOW } }, fx3 = { { "fire", ORANGE }, { "fire", RED, "tail" } }, aura = RED }
-- Invisibility
R.KoiSpirit = { base = "sharper look: attitude brows", baseKits = { { "brows" } }, names = { "Koi Spirit", "Spectre Koi", "Phantom Koi" },
	l2 = { { "brows" }, { "halo", CYAN } }, fx2 = { { "void", TEAL } },
	l3 = { { "brows" }, { "halo", CYAN }, { "eyes", CYAN }, { "wings", CYAN, WHITE } }, fx3 = { { "void", TEAL }, { "sparks", CYAN } }, aura = CYAN, ghost = 0.4 }
R.SaucerPilot = { names = { "Saucer Pilot", "Stealth Saucer", "Cloak Saucer" },
	l2 = { { "visor", GREEN } }, fx2 = { { "sparks", GREEN } },
	l3 = { { "visor", MAGENTA }, { "halo", PURPLE } }, fx3 = { { "void", PURPLE }, { "sparks", MAGENTA } }, aura = PURPLE, ghost = 0.35 }
R.VoidOverlord = { names = { "Void Overlord", "Void Lord", "Void Emperor" },
	l2 = { { "crown", BLACK, PURPLE } }, fx2 = { { "void", PURPLE } },
	l3 = { { "crown", PURPLE, MAGENTA }, { "horns", BLACK, PURPLE, true }, { "eyes", MAGENTA } }, fx3 = { { "void", PURPLE }, { "void", MAGENTA, "head" } }, aura = PURPLE, ghost = 0.25 }
-- Decoy
R.GamerAxolotl = { names = { "Gamer Axolotl", "Streamer Axolotl", "Pro Axolotl" },
	l2 = { { "headset", BLACK, GREEN } }, fx2 = { { "glitch", GREEN } },
	l3 = { { "headset", BLACK, MAGENTA }, { "visor", CYAN } }, fx3 = { { "glitch", MAGENTA }, { "glitch", CYAN } }, aura = MAGENTA }
R.BanditRaccoon = { names = { "Bandit Raccoon", "Cat Burglar", "Master Thief" },
	l2 = { { "cape", BLACK, GOLD } }, fx2 = { { "void", DARK } },
	l3 = { { "cape", PURPLE, GOLD }, { "eyes", GOLD } }, fx3 = { { "void", DARK }, { "gold", GOLD } }, aura = GOLD }
R.NinjaPenguin = { names = { "Ninja Penguin", "Shadow Penguin", "Phantom Ninja" },
	l2 = { { "mask", BLACK } }, fx2 = { { "void", DARK } },
	l3 = { { "mask", BLACK }, { "eyes", RED }, { "cape", RED, RED } }, fx3 = { { "void", DARK }, { "sparks", RED } }, aura = RED }
R.LilAlien = { base = "rename to Alien (drop Lil') + attitude brows", baseKits = { { "brows" } }, names = { "Alien", "Clone Agent", "Clone Commander" },
	l2 = { { "brows" }, { "visor", GREEN } }, fx2 = { { "glitch", GREEN } },
	l3 = { { "visor", MAGENTA }, { "halo", GREEN }, { "armor", SILVER, GREEN } }, fx3 = { { "glitch", GREEN }, { "sparks", MAGENTA } }, aura = GREEN }
-- Shield
R.PufferPup = { base = "rename to Puffer + attitude brows", baseKits = { { "brows" } }, names = { "Puffer", "Spike Puffer", "Spikeball Puffer" },
	l2 = { { "brows" }, { "scutes", ORANGE } }, fx2 = { { "water", CYAN } },
	l3 = { { "brows" }, { "scutes", GOLD }, { "horns", GOLD, WHITE }, { "bubble", CYAN } }, fx3 = { { "sparks", CYAN } }, aura = CYAN }
R.HermitKnight = { names = { "Hermit Knight", "Shell Guard", "Paladin Crab" },
	l2 = { { "helmet", SILVER, RED } }, fx2 = {},
	l3 = { { "helmet", GOLD, WHITE }, { "armor", GOLD, CYAN }, { "bubble", GOLD } }, fx3 = { { "gold", GOLD } }, aura = GOLD }
R.TreasureGolem = { names = { "Treasure Golem", "Gold Golem", "Vault Golem" },
	l2 = { { "crown", GOLD, RED } }, fx2 = { { "gold", GOLD } },
	l3 = { { "crown", GOLD, CYAN }, { "armor", GOLD, CYAN }, { "bubble", GOLD } }, fx3 = { { "gold", GOLD } }, aura = GOLD }
-- Wall
R.RoboCrab = { names = { "Robo Crab", "Tank Crab", "Siege Crab" },
	l2 = { { "scutes", SILVER } }, fx2 = { { "sparks", ORANGE } },
	l3 = { { "scutes", DARK }, { "spikes", ORANGE }, { "visor", RED } }, fx3 = { { "sparks", ORANGE }, { "fire", ORANGE, "tail" } }, aura = ORANGE }
R.ArmoredRex = { names = { "Armored Rex", "Iron Rex", "Bastion Rex" },
	l2 = { { "spikes", SILVER } }, fx2 = {},
	l3 = { { "spikes", SILVER }, { "helmet", SILVER, RED }, { "armor", SILVER, RED }, { "eyes", RED } }, fx3 = { { "sparks", RED } }, aura = RED }
R.FrostYeti = { names = { "Frost Yeti", "Blizzard Yeti", "Glacier Yeti" },
	l2 = { { "horns", ICE, WHITE } }, fx2 = { { "frost", ICE } },
	l3 = { { "horns", ICE, CYAN, true }, { "crown", ICE, CYAN }, { "eyes", CYAN } }, fx3 = { { "frost", ICE }, { "frost", CYAN, "head" } }, aura = CYAN }
R.LavaScorpion = { names = { "Lava Scorpion", "Molten Scorpion", "Magma Scorpion" },
	l2 = { { "spikes", ORANGE } }, fx2 = { { "fire", ORANGE, "tail" } },
	l3 = { { "spikes", ORANGE }, { "horns", BLACK, ORANGE }, { "eyes", YELLOW } }, fx3 = { { "fire", ORANGE, "tail" }, { "fire", RED } }, aura = ORANGE }
R.MechaInvader = { names = { "Mecha Invader", "War Mech", "Titan Mech" },
	l2 = { { "armor", SILVER, MAGENTA } }, fx2 = { { "sparks", MAGENTA } },
	l3 = { { "armor", DARK, MAGENTA }, { "horns", DARK, MAGENTA }, { "visor", MAGENTA } }, fx3 = { { "sparks", MAGENTA }, { "fire", MAGENTA } }, aura = MAGENTA }
-- Pet Tackle
R.VikingWalrus = { names = { "Viking Walrus", "Raider Walrus", "Berserker Walrus" },
	l2 = { { "tusks", IVORY } }, fx2 = {},
	l3 = { { "tusks", IVORY }, { "horns", IVORY, GOLD, true }, { "eyes", RED }, { "cape", RED, GOLD } }, fx3 = { { "sparks", RED } }, aura = RED }
R.CozyLion = { base = "rename to Pride Lion + attitude brows", baseKits = { { "brows" } }, names = { "Pride Lion", "Lionheart", "King Lion" },
	l2 = { { "brows" }, { "mane", ORANGE, GOLD } }, fx2 = {},
	l3 = { { "brows" }, { "mane", GOLD, ORANGE }, { "crown", GOLD, RED }, { "eyes", GOLD } }, fx3 = { { "gold", GOLD }, { "fire", GOLD, "head" } }, aura = GOLD }
R.NarwhalCalf = { base = "rename to Narwhal (drop Calf) + attitude brows", baseKits = { { "brows" } }, names = { "Narwhal", "Narwhal Knight", "Lancer Narwhal" },
	l2 = { { "brows" }, { "lance", CYAN } }, fx2 = { { "water", CYAN } },
	l3 = { { "brows" }, { "lance", WHITE }, { "helmet", SILVER, CYAN }, { "eyes", CYAN } }, fx3 = { { "water", CYAN }, { "sparks", CYAN } }, aura = CYAN }
R.KrakenHatchling = { base = "rename to Kraken (drop Hatchling) + attitude brows", baseKits = { { "brows" } }, names = { "Kraken", "Deep Kraken", "Abyss Kraken" },
	l2 = { { "brows" }, { "spikes", PURPLE } }, fx2 = { { "void", PURPLE } },
	l3 = { { "horns", DARK, MAGENTA }, { "eyes", MAGENTA }, { "spikes", MAGENTA } }, fx3 = { { "void", PURPLE }, { "water", MAGENTA } }, aura = PURPLE }
R.LeviathanPup = { base = "rename to Leviathan (drop Pup) + attitude brows", baseKits = { { "brows" } }, names = { "Leviathan", "Tide Leviathan", "Tidal Leviathan" },
	l2 = { { "brows" }, { "spikes", CYAN } }, fx2 = { { "water", CYAN } },
	l3 = { { "spikes", CYAN }, { "horns", WHITE, CYAN }, { "crown", GOLD, CYAN }, { "eyes", CYAN } }, fx3 = { { "water", CYAN }, { "sparks", CYAN } }, aura = CYAN }

local ROWS = {
	{ "Double Dash", rgb(255, 140, 60), { "ShadesShark", "SurferDog", "ThunderWolf", "PhoenixGull", "FireDragon" } },
	{ "Invisibility", rgb(150, 200, 255), { "KoiSpirit", "SaucerPilot", "VoidOverlord" } },
	{ "Decoy", rgb(255, 196, 92), { "GamerAxolotl", "BanditRaccoon", "NinjaPenguin", "LilAlien" } },
	{ "Shield", rgb(120, 236, 220), { "PufferPup", "HermitKnight", "TreasureGolem" } },
	{ "Wall", rgb(176, 150, 255), { "RoboCrab", "ArmoredRex", "FrostYeti", "LavaScorpion", "MechaInvader" } },
	{ "Pet Tackle", rgb(255, 96, 96), { "VikingWalrus", "CozyLion", "NarwhalCalf", "KrakenHatchling", "LeviathanPup" } },
}
local TOSS = {
	JellyWisp = "too babyish; Koi covers ghostly", MiniMothership = "a ship, not an animal", PebbleFrog = "most babyish design",
	SandCrab = "Robo Crab covers crabs", MiniFisherman = "fishing character", LilOtter = "plain", GoldenOtter = "recolour of Lil' Otter",
	SeagullScout = "no scout ability", ParrotPirate = "fishing/pirate theme", SushiCat = "food theme", FloatieGiraffe = "pool-floatie theme",
	CloudWhale = "Huge: lobby showpiece only",
}
local TOSS_ORDER = { "JellyWisp", "MiniMothership", "PebbleFrog", "SandCrab", "MiniFisherman", "LilOtter", "GoldenOtter", "SeagullScout", "ParrotPirate", "SushiCat", "FloatieGiraffe", "CloudWhale" }

local ORIGIN = Vector3.new(0, 1, 420) -- north-west corner; viewers stand on the north side looking south
local SCALES = { 2, 2.15, 2.4 }
local STAGE_GAP, FAMILY_GAP, ROW_DEPTH = 5, 12, 30
local LEVEL_COLOR = { rgb(235, 238, 245), rgb(120, 226, 255), rgb(255, 214, 70) }
local INK = rgb(20, 22, 30)

local function anchored(parent, name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(adornee, lines, height, w, maxDist)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromScale(w or 7, 0.85 * #lines)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	bb.MaxDistance = maxDist or 110
	bb.LightInfluence = 0
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = bb
	for i, l in lines do
		local t = Instance.new("TextLabel")
		t.Name = l.name or ("Line" .. i)
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1 / #lines)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = l.text
		t.TextColor3 = l.color or Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0
		t.TextStrokeColor3 = INK
		t.LayoutOrder = i
		t.Parent = bb
	end
	bb.Parent = adornee
	return bb
end

local function findPet(lib, id)
	for _, f in lib.Pets:GetChildren() do
		local m = f:FindFirstChild(id)
		if m then
			return m
		end
	end
end

local function grow(m: Model, k: number)
	m:ScaleTo(m:GetScale() * k)
end

-- one stage of one pet, built at the origin facing -Z, add-ons fixed to bones, then scaled
local function stage(lib, variantData, id, level, rec)
	local m = findPet(lib, id):Clone()
	m.Name = ("%s_L%d"):format(id, level)
	m:PivotTo(CFrame.identity)
	m.Parent = workspace -- raycasts while measuring
	local vd = variantData.Pets[id]
	local v = level > 1 and vd and vd.Tiers and vd.Tiers[level]
	if v then
		local body = m:FindFirstChild(id)
		if body and body:IsA("MeshPart") and v.Texture then
			body.TextureID = v.Texture
		end
		local glow = m:FindFirstChild(id .. "_Glow")
		if glow and v.Glow then
			glow.Color = v.Glow
		end
	end
	local S = Kits.measure(m)
	if rec then
		local list = if level == 1 then rec.baseKits elseif level == 2 then rec.l2 else rec.l3
		if list then
			Kits.apply(m, S, list)
		end
		if level == 3 and rec.ghost then
			for _, d in m:GetDescendants() do
				if d:IsA("MeshPart") and not d.Name:find("Glow") then
					d.Transparency = rec.ghost
				end
			end
		end
	end
	grow(m, SCALES[level])
	if rec then
		local fx = if level == 2 then rec.fx2 elseif level == 3 then rec.fx3 else nil
		for _, f in fx or {} do
			Kits.emit(m, S, f[1], f[2], SCALES[level], f[3])
		end
		if level == 3 and rec.aura then
			Kits.aura(m, rec.aura, math.max(S.W, S.D) * SCALES[level] + 1.5)
		end
	end
	m:SetAttribute("ShowroomAnimate", true)
	m:SetAttribute("Level", level)
	return m
end

local function place(m: Model, x: number, top: number, z: number)
	local cf, size = m:GetBoundingBox()
	local pivot = m:GetPivot()
	local bottom = (cf.Position.Y - size.Y / 2) - pivot.Position.Y
	local dx, dz = cf.Position.X - pivot.Position.X, cf.Position.Z - pivot.Position.Z
	m:PivotTo(CFrame.new(x - dx, top - bottom, z - dz))
end

return function()
	local lib = ServerStorage:FindFirstChild("FWP_PetLibrary")
	assert(lib, "FWP_PetLibrary missing")
	local variantData = require(lib.Reference.PetVariantData)
	local old = workspace:FindFirstChild("EOS_EvolutionLab")
	if old then
		old:Destroy()
	end
	local lab = Instance.new("Model")
	lab.Name = "EOS_EvolutionLab"
	local deck = Instance.new("Folder")
	deck.Name = "Deck"
	deck.Parent = lab
	local displays = Instance.new("Folder")
	displays.Name = "Displays"
	displays.Parent = lab

	local z = ORIGIN.Z
	local maxX = 0
	local spans = {}
	local top = ORIGIN.Y + 1
	-- stages run left -> right as seen from the north (looking +Z), i.e. towards -X: build in +X, mirror
	local function rowOf(title, color, ids, tossRow)
		local x = 34
		for _, id in ids do
			local rec = R[id]
			local fam = Instance.new("Model")
			fam.Name = id
			local levels = if tossRow then { 1 } else { 1, 2, 3 }
			local x0 = x
			local tallest = 0
			for _, lv in levels do
				local m = stage(lib, variantData, id, lv, rec)
				local _, size = m:GetBoundingBox()
				local w = math.max(size.X, 4)
				local cx = x + w / 2
				local h = if tossRow then 0.6 else lv * 0.6
				local cz = z + 12
				anchored(fam, "Podium", Vector3.new(h, w + 2, w + 2), CFrame.new(-cx, top + h / 2, cz) * CFrame.Angles(0, 0, math.rad(90)), if tossRow then rgb(90, 90, 100) else color:Lerp(LEVEL_COLOR[lv], 0.35), nil, Enum.PartType.Cylinder)
				anchored(fam, "Rim", Vector3.new(0.3, w + 2.6, w + 2.6), CFrame.new(-cx, top + 0.15, cz) * CFrame.Angles(0, 0, math.rad(90)), if tossRow then RED else LEVEL_COLOR[lv], Enum.Material.Neon, Enum.PartType.Cylinder)
				place(m, -cx, top + h, cz)
				m.Parent = fam
				tallest = math.max(tallest, size.Y + h)
				local nm = if rec then rec.names[lv] else id
				label(m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart"), if tossRow then {
					{ text = nm, color = rgb(230, 230, 236) },
					{ text = "TOSS: " .. (TOSS[id] or ""), color = rgb(255, 110, 110) },
				} else {
					{ text = ("LV%d · %s"):format(lv, nm), color = LEVEL_COLOR[lv] },
					{ text = "▶ Idle", color = rgb(150, 255, 150), name = "Anim" },
				}, size.Y / 2 + 2.2, 8)
				if not tossRow and lv < 3 then
					-- arrow to the next stage
					anchored(fam, "Arrow", Vector3.new(1.6, 0.3, 0.5), CFrame.new(-(x + w + STAGE_GAP / 2), top + 2.5, cz), LEVEL_COLOR[lv + 1], Enum.Material.Neon)
				end
				x += w + STAGE_GAP
			end
			if rec and rec.base then
				local note = anchored(fam, "NoteAnchor", Vector3.new(1, 1, 1), CFrame.new(-(x0 + x - STAGE_GAP) / 2, top + tallest + 3.2, z + 12), Color3.new(1, 1, 1))
				note.Transparency = 1
				note.CanCollide = false
				note.CanQuery = false
				label(note, { { text = "LV1 base redo: " .. rec.base, color = rgb(255, 170, 120) } }, 0, 22, 150)
			end
			fam.Parent = displays
			x += FAMILY_GAP - STAGE_GAP
		end
		maxX = math.max(maxX, x)
		table.insert(spans, { z0 = z, z1 = z + 24, title = title, color = color })
		z += ROW_DEPTH
	end
	for _, row in ROWS do
		rowOf(string.upper(row[1]), row[2], row[3], false)
	end
	rowOf("TOSS", RED, TOSS_ORDER, true)

	local W = maxX + 6
	anchored(deck, "Deck", Vector3.new(W, 2, z - ORIGIN.Z + 6), CFrame.new(-W / 2 + 0, ORIGIN.Y, (ORIGIN.Z - 6 + z) / 2), rgb(52, 56, 76))
	for _, s in spans do
		local cz = (s.z0 + s.z1) / 2
		anchored(deck, "Strip", Vector3.new(W - 4, 0.2, s.z1 - s.z0), CFrame.new(-W / 2, ORIGIN.Y + 1.1, cz), s.color:Lerp(rgb(52, 56, 76), 0.75))
		local board = anchored(deck, "RowSign", Vector3.new(26, 6, 0.6), CFrame.new(-14, ORIGIN.Y + 5, cz), INK)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 30
		g.LightInfluence = 0
		g.Parent = board
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = s.title
		t.TextColor3 = s.color
		t.Parent = g
	end
	local title = anchored(deck, "TitleAnchor", Vector3.new(1, 1, 1), CFrame.new(-W / 2, ORIGIN.Y + 24, ORIGIN.Z - 4), Color3.new(1, 1, 1))
	title.Transparency = 1
	title.CanCollide = false
	label(title, {
		{ text = "EVOLUTION LAB", color = rgb(255, 214, 70) },
		{ text = "mock-ups: LV1 → LV2 → LV3 for every kept pet · press Run to see them move", color = rgb(220, 224, 236) },
	}, 0, 60, 700)
	script.Parent.ShowroomAnimator:Clone().Parent = lab
	lab.Parent = workspace
	local n = 0
	for _, d in lab:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("ShowroomAnimate") then
			n += 1
		end
	end
	return ("evolution lab: %d pet models, deck %.0f x %.0f at %s"):format(n, W, z - ORIGIN.Z, tostring(ORIGIN))
end
