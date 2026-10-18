-- HOS-POD-001: rig podiums in the incubator pedestal's style (Workspace.Incubator A09 steps/crown/core).
-- Four models: Crown, Obelisk, Rune, Harvest. Masters go to ServerStorage.HOS_RigPodiums; a preview row
-- (with a dummy standing on each) goes to Workspace._PodiumPreview, off the island.
-- Lobby style: Plastic + Studs surfaces, the incubator's stone purples, Neon only for glow accents.
-- Each podium's pivot is its bottom centre; attachment "RigStand" marks where a rig's feet go and the
-- "StandHeight" attribute holds that height above the pivot.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local C = {
	slab = Color3.fromRGB(47, 41, 68), -- A09_PlatformBase
	step1 = Color3.fromRGB(59, 52, 82),
	step2 = Color3.fromRGB(68, 60, 94),
	step3 = Color3.fromRGB(74, 63, 99),
	crown = Color3.fromRGB(64, 57, 88),
	cap = Color3.fromRGB(93, 83, 121),
	glow = Color3.fromRGB(180, 92, 255), -- the incubator's neon purple
	orange = Color3.fromRGB(255, 122, 26),
	gold = Color3.fromRGB(255, 194, 58),
	crystal = Color3.fromRGB(122, 70, 190),
	crystalLight = Color3.fromRGB(160, 110, 230),
	-- harvest
	pumpkin = Color3.fromRGB(232, 112, 24),
	pumpkinDark = Color3.fromRGB(196, 82, 10),
	stem = Color3.fromRGB(92, 98, 44),
	leaf = Color3.fromRGB(74, 120, 46),
	stalk = Color3.fromRGB(104, 140, 58),
	husk = Color3.fromRGB(150, 160, 80),
	cob = Color3.fromRGB(244, 196, 64),
	wheat = Color3.fromRGB(214, 176, 104),
	wheatDark = Color3.fromRGB(176, 136, 72),
	hay = Color3.fromRGB(206, 170, 96),
	twine = Color3.fromRGB(120, 84, 50),
	leafRed = Color3.fromRGB(176, 52, 32),
	leafOrange = Color3.fromRGB(222, 112, 34),
	leafYellow = Color3.fromRGB(226, 170, 52),
}

local STUDS, SMOOTH, INLET = Enum.SurfaceType.Studs, Enum.SurfaceType.Smooth, Enum.SurfaceType.Inlet
local function brick(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, opt: any?)
	opt = opt or {}
	local p = Instance.new(opt.class or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	local style = opt.style or "studs"
	p.Material = if style == "neon" then Enum.Material.Neon else Enum.Material.Plastic
	if style == "studs" then
		p.TopSurface, p.FrontSurface, p.BackSurface, p.LeftSurface, p.RightSurface = STUDS, STUDS, STUDS, STUDS, STUDS
		p.BottomSurface = INLET
	else
		p.TopSurface, p.BottomSurface = SMOOTH, SMOOTH
	end
	if style == "neon" then
		p.CastShadow = false
	end
	if opt.shape then
		(p :: any).Shape = opt.shape
	end
	if opt.collide == false then
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	end
	if opt.transparency then
		p.Transparency = opt.transparency
	end
	p.Parent = parent
	return p
end
local function model(name: string, parent: Instance)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- ===== shared pieces =====
-- pedestal sizes (the incubator's pedestal at about 2/3 scale)
local BASE, BASE_H = 9, 0.4
local TIERS = { { 6.6, C.step1 }, { 5.2, C.step2 }, { 3.8, C.step3 } }
local TIER_H = 0.45
local TOP = BASE_H + #TIERS * TIER_H -- top of the last tier

-- slab + three tiers, each a square plus the same square turned 45 (the incubator's 8-point star).
-- The turned copy is 0.02 lower so the two tops never share a plane.
local function starPedestal(m: Model, O: CFrame, base: number?)
	local b = base or BASE
	brick(m, "Slab", Vector3.new(b, BASE_H, b), O * CFrame.new(0, BASE_H / 2, 0), C.slab)
	for i, t in TIERS do
		local y0 = BASE_H + (i - 1) * TIER_H
		brick(m, "Tier" .. i, Vector3.new(t[1], TIER_H, t[1]), O * CFrame.new(0, y0 + TIER_H / 2, 0), t[2])
		brick(m, "Tier" .. i .. "Turned", Vector3.new(t[1] * 0.92, TIER_H - 0.02, t[1] * 0.92), O * CFrame.new(0, y0 + (TIER_H - 0.02) / 2, 0) * CFrame.Angles(0, math.rad(45), 0), t[2])
	end
end

-- glowing stand disc on top (the incubator's A09_CoreEmitter) + a soft light; sets the RigStand marker
local function standDisc(m: Model, O: CFrame, top: number, color: Color3)
	local cyl = Enum.PartType.Cylinder
	brick(m, "StandRim", Vector3.new(0.1, 2.9, 2.9), O * CFrame.new(0, top + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), C.slab, { shape = cyl, style = "smooth" })
	local disc = brick(m, "StandGlow", Vector3.new(0.12, 2.6, 2.6), O * CFrame.new(0, top + 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), color, { shape = cyl, style = "neon" })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 0.8
	light.Range = 10
	light.Parent = disc
	local stand = Instance.new("Attachment")
	stand.Name = "RigStand"
	stand.Parent = disc -- parent first: WorldCFrame set on an unparented attachment would turn with the disc
	stand.WorldCFrame = O * CFrame.new(0, top + 0.12, 0)
	m:SetAttribute("StandHeight", top + 0.12)
end

-- ===== A: Crown (the incubator pedestal in miniature) =====
local function buildCrown(O: CFrame)
	local m = Instance.new("Model")
	m.Name = "Podium_Crown"
	starPedestal(m, O)
	local ring = model("CrownRing", m)
	local y0 = BASE_H + 2 * TIER_H -- sits on tier 2, round tier 3
	for i = 0, 7 do
		local R = O * CFrame.Angles(0, math.rad(i * 45), 0)
		brick(ring, "Crown" .. i, Vector3.new(0.75, 0.6, 0.7), R * CFrame.new(0, y0 + 0.3, -2.35), C.crown)
		brick(ring, "CrownCap" .. i, Vector3.new(0.62, 0.1, 0.56), R * CFrame.new(0, y0 + 0.65, -2.35), C.cap)
		brick(ring, "CrownGem" .. i, Vector3.new(0.18, 0.18, 0.06), R * CFrame.new(0, y0 + 0.32, -2.71), C.glow, { style = "neon" })
	end
	standDisc(m, O, TOP, C.glow)
	return m
end

-- ===== B: Obelisk (four glowing mini obelisks at the diagonals, neon rim round the top) =====
local function buildObelisk(O: CFrame)
	local m = Instance.new("Model")
	m.Name = "Podium_Obelisk"
	starPedestal(m, O)
	for i = 0, 3 do
		local R = O * CFrame.Angles(0, math.rad(45 + i * 90), 0) * CFrame.new(0, 0, -5.4) -- slab corner, clear of tier 1
		local ob = model("Obelisk" .. (i + 1), m)
		brick(ob, "Base", Vector3.new(0.9, 0.3, 0.9), R * CFrame.new(0, BASE_H + 0.15, 0), C.slab)
		brick(ob, "Shaft", Vector3.new(0.6, 1.9, 0.6), R * CFrame.new(0, BASE_H + 0.3 + 0.95, 0), C.step3)
		brick(ob, "Panel", Vector3.new(0.24, 1.3, 0.05), R * CFrame.new(0, BASE_H + 0.3 + 0.95, -0.32), C.glow, { style = "neon" })
		brick(ob, "Band", Vector3.new(0.72, 0.14, 0.72), R * CFrame.new(0, BASE_H + 2.27, 0), C.crown)
		brick(ob, "Tip", Vector3.new(0.4, 0.3, 0.4), R * CFrame.new(0, BASE_H + 2.49, 0), C.cap, { style = "smooth" })
		brick(ob, "TipGlow", Vector3.new(0.16, 0.24, 0.16), R * CFrame.new(0, BASE_H + 2.76, 0), C.glow, { style = "neon" })
	end
	-- neon rim round the top tier (both the square and the turned square)
	local rim = model("Rim", m)
	local s, t = TIERS[3][1], TOP
	for i = 0, 3 do
		local R = O * CFrame.Angles(0, math.rad(i * 90), 0)
		brick(rim, "RimGlow", Vector3.new(s + 0.06, 0.08 + (i % 2) * 0.006, 0.08), R * CFrame.new(0, t - 0.03, -s / 2 - 0.01), C.glow, { style = "neon" }) -- alternate heights: the corners overlap
	end
	standDisc(m, O, TOP, C.glow)
	return m
end

-- ===== C: Rune (square tiers with gear-tooth edges, glowing runes, crystal clusters) =====
local function buildRune(O: CFrame)
	local m = Instance.new("Model")
	m.Name = "Podium_Rune"
	brick(m, "Slab", Vector3.new(BASE, BASE_H, BASE), O * CFrame.new(0, BASE_H / 2, 0), C.slab)
	local sizes = { 6.6, 5.0, 3.6 }
	for i, s in sizes do
		local y0 = BASE_H + (i - 1) * TIER_H
		brick(m, "Tier" .. i, Vector3.new(s, TIER_H, s), O * CFrame.new(0, y0 + TIER_H / 2, 0), TIERS[i][2])
	end
	-- gear teeth on tier 1: three per side, and runes on its faces between them
	local teeth = model("Teeth", m)
	local runes = model("Runes", m)
	for side = 0, 3 do
		local R = O * CFrame.Angles(0, math.rad(side * 90), 0)
		for _, x in { -2.2, 0, 2.2 } do
			brick(teeth, "Tooth", Vector3.new(0.8, TIER_H - 0.04, 0.35), R * CFrame.new(x, BASE_H + (TIER_H - 0.04) / 2, -3.3 - 0.17), TIERS[1][2])
		end
		for _, x in { -1.1, 1.1 } do
			brick(runes, "RuneV", Vector3.new(0.08, 0.3, 0.04), R * CFrame.new(x, BASE_H + TIER_H / 2, -3.31), C.glow, { style = "neon" })
			brick(runes, "RuneH", Vector3.new(0.26, 0.07, 0.044), R * CFrame.new(x, BASE_H + TIER_H / 2 + 0.06, -3.311), C.glow, { style = "neon" })
		end
		-- a glowing line round tier 2's top edge
		brick(runes, "TierLine", Vector3.new(sizes[2] + 0.04, 0.06 + (side % 2) * 0.006, 0.06), R * CFrame.new(0, BASE_H + 2 * TIER_H - 0.05, -sizes[2] / 2 - 0.01), C.glow, { style = "neon" })
	end
	-- crystal clusters on the slab corners: stacked turned blocks with a glowing tip
	for i = 0, 3 do
		local R = O * CFrame.Angles(0, math.rad(45 + i * 90), 0) * CFrame.new(0, 0, -5.4)
		local cl = model("Crystals" .. (i + 1), m)
		brick(cl, "Crystal", Vector3.new(0.55, 1.4, 0.55), R * CFrame.new(0, BASE_H + 0.7, 0) * CFrame.Angles(0, math.rad(45), math.rad(15)), C.crystal)
		brick(cl, "CrystalTip", Vector3.new(0.3, 0.35, 0.3), R * CFrame.new(-0.18, BASE_H + 1.45, 0) * CFrame.Angles(0, math.rad(45), math.rad(15)), C.glow, { style = "neon" })
		brick(cl, "CrystalSmall", Vector3.new(0.38, 0.8, 0.38), R * CFrame.new(0.38, BASE_H + 0.4, 0.2) * CFrame.Angles(0, math.rad(30), math.rad(-30)), C.crystalLight)
		brick(cl, "CrystalSmallTip", Vector3.new(0.2, 0.2, 0.2), R * CFrame.new(0.58, BASE_H + 0.78, 0.2) * CFrame.Angles(0, math.rad(30), math.rad(-30)), C.glow, { style = "neon" })
	end
	standDisc(m, O, BASE_H + #sizes * TIER_H, C.glow)
	return m
end

-- ===== D: Harvest (Halloween) =====
-- the lobby's own jack-o'-lantern (ServerStorage.HalloweenLobbyKit.A04_JackOLantern, HOS-LOBBY-005), face to
-- the front (-Z); s = size where 1 is about 1.8 studs wide (kit scale 0.55), seated on the surface at `at`
local KIT_PUMPKIN = SS:WaitForChild("HalloweenLobbyKit"):WaitForChild("A04_JackOLantern")
local function kitPumpkin(parent: Instance, at: CFrame, s: number)
	local p = KIT_PUMPKIN:Clone()
	p.Name = "JackOLantern"
	p:ScaleTo(0.55 * s)
	p:PivotTo(at)
	local cf, size = p:GetBoundingBox()
	p:PivotTo(p:GetPivot() + Vector3.new(0, at.Y - (cf.Y - size.Y / 2) + 0.002, 0))
	p.Parent = parent
	return p
end
-- voxel corn stalk: a thin stalk, two leaves and a cob in its husk
local function cornStalk(parent: Instance, at: CFrame, height: number)
	local c = model("Corn", parent)
	brick(c, "Stalk", Vector3.new(0.22, height, 0.22), at * CFrame.new(0, height / 2, 0), C.stalk, { style = "smooth" })
	brick(c, "LeafL", Vector3.new(0.9, 0.06, 0.24), at * CFrame.new(-0.42, height * 0.45, 0) * CFrame.Angles(0, 0, math.rad(-30)), C.leaf, { style = "smooth" })
	brick(c, "LeafR", Vector3.new(0.8, 0.06, 0.22), at * CFrame.new(0.38, height * 0.7, 0) * CFrame.Angles(0, 0, math.rad(30)), C.leaf, { style = "smooth" })
	brick(c, "Cob", Vector3.new(0.3, 0.6, 0.3), at * CFrame.new(0.2, height * 0.58, 0.05) * CFrame.Angles(0, 0, math.rad(-15)), C.cob, { style = "smooth" })
	brick(c, "Husk", Vector3.new(0.34, 0.32, 0.34), at * CFrame.new(0.15, height * 0.58 - 0.24, 0.05) * CFrame.Angles(0, 0, math.rad(-15)), C.husk, { style = "smooth" })
	brick(c, "Tassel", Vector3.new(0.12, 0.4, 0.12), at * CFrame.new(0.05, height + 0.15, 0) * CFrame.Angles(0, 0, math.rad(15)), C.wheat, { style = "smooth" })
	return c
end
-- wheat bundle: stalks fanned from a tie, each with a grain head
local function wheatBundle(parent: Instance, at: CFrame)
	local w = model("Wheat", parent)
	for i = -3, 3 do
		local lean = CFrame.Angles(math.rad((i % 2) * 8 - 4), 0, math.rad(i * 7.5))
		local stalk = at * CFrame.new(0, 0.05, 0) * lean
		brick(w, "Straw", Vector3.new(0.09, 1.5, 0.09), stalk * CFrame.new(0, 0.75, 0), C.wheatDark, { style = "smooth" })
		brick(w, "Grain", Vector3.new(0.17, 0.42, 0.17), stalk * CFrame.new(0, 1.62, 0), C.wheat, { style = "smooth" })
	end
	brick(w, "Tie", Vector3.new(0.48, 0.12, 0.3), at * CFrame.new(0, 0.55, 0), C.twine, { style = "smooth" })
	return w
end
local function hayBale(parent: Instance, at: CFrame)
	local b = model("HayBale", parent)
	brick(b, "Bale", Vector3.new(1.5, 0.8, 0.9), at * CFrame.new(0, 0.4, 0), C.hay)
	for _, x in { -0.4, 0.4 } do
		brick(b, "Band", Vector3.new(0.1, 0.84, 0.94), at * CFrame.new(x, 0.42, 0), C.twine, { style = "smooth" })
	end
	return b
end

local function buildHarvest(O: CFrame)
	local m = Instance.new("Model")
	m.Name = "Podium_Harvest"
	-- a wider slab (11) so the harvest has ground of its own outside tier 1 (square 6.6, turned diamond r 4.3)
	starPedestal(m, O, 11)
	local deco = model("Harvest", m)
	local slabTop = BASE_H
	-- the lobby's jack-o'-lanterns on the front corners, a small one up on tier 1
	kitPumpkin(deco, O * CFrame.new(-4.4, slabTop, -4.4) * CFrame.Angles(0, math.rad(15), 0), 1.0)
	kitPumpkin(deco, O * CFrame.new(-2.7, slabTop, -4.85) * CFrame.Angles(0, math.rad(-30), 0), 0.6)
	kitPumpkin(deco, O * CFrame.new(4.4, slabTop, -4.3) * CFrame.Angles(0, math.rad(-15), 0), 0.75)
	kitPumpkin(deco, O * CFrame.new(2.97, BASE_H + TIER_H, -2.97) * CFrame.Angles(0, math.rad(30), 0), 0.35)
	-- corn on the back corners, a wheat bundle and a hay bale on the sides
	cornStalk(deco, O * CFrame.new(-4.4, slabTop, 4.4) * CFrame.Angles(0, math.rad(30), 0), 2.6)
	cornStalk(deco, O * CFrame.new(-3.0, slabTop, 4.95) * CFrame.Angles(0, math.rad(-15), 0), 2.1)
	cornStalk(deco, O * CFrame.new(4.4, slabTop, 4.4) * CFrame.Angles(0, math.rad(-45), 0), 2.4)
	wheatBundle(deco, O * CFrame.new(4.85, slabTop, 0.8) * CFrame.Angles(0, math.rad(90), 0))
	hayBale(deco, O * CFrame.new(-4.95, slabTop, 0.6) * CFrame.Angles(0, math.rad(90 + 15), 0))
	-- autumn leaves scattered flat on the slab and tiers (only where that level's floor is showing)
	local rng = Random.new(7)
	local leafColors = { C.leafRed, C.leafOrange, C.leafYellow }
	local spots = {
		{ -1.6, 1, -4.7 }, { 0.4, 1, -4.9 }, { 1.8, 1, -4.6 }, { 4.9, 1, -1.8 }, { 4.8, 1, 2.2 }, { -4.9, 1, -1.9 },
		{ 0.9, 2, -3.0 }, { -2.7, 2, 0.8 }, { 2.9, 2, 1.1 }, { -0.8, 3, -2.3 }, { 2.2, 3, 1.0 },
	}
	for i, sp in spots do
		local topY = BASE_H + (sp[2] - 1) * TIER_H
		brick(deco, "Leaf", Vector3.new(0.42, 0.05, 0.3), O * CFrame.new(sp[1], topY + 0.025 + i * 0.001, sp[3]) * CFrame.Angles(0, math.rad(15 * rng:NextInteger(0, 11)), 0), leafColors[rng:NextInteger(1, 3)], { style = "smooth", collide = false })
	end
	standDisc(m, O, TOP, C.orange)
	return m
end

-- ===== build: masters in ServerStorage + a preview row with a dummy on each =====
local rec = CHS:TryBeginRecording("HOS-POD-001 rig podiums")
local folder = SS:FindFirstChild("HOS_RigPodiums")
if folder then
	folder:Destroy()
end
folder = Instance.new("Folder")
folder.Name = "HOS_RigPodiums"
folder:SetAttribute("Note", "HOS-POD-001: rig podiums in the incubator pedestal's style. Pivot = bottom centre; RigStand attachment / StandHeight attribute = where a rig's feet go.")
folder.Parent = SS

local preview = workspace:FindFirstChild("_PodiumPreview")
if preview then
	preview:Destroy()
end
preview = Instance.new("Folder")
preview.Name = "_PodiumPreview"
preview.Parent = workspace

local ROW = CFrame.new(0, 10, 1700) -- off the island (its edge is at z ~1562), facing the lobby (-Z)
brick(preview, "PreviewFloor", Vector3.new(62, 1, 18), ROW * CFrame.new(0, -0.5, 0), C.slab)

local builders = { buildCrown, buildObelisk, buildRune, buildHarvest }
local dummy = nil
pcall(function()
	dummy = game:GetService("Players"):CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
end)
local out = {}
for i, build in builders do
	local m = build(CFrame.new())
	m.WorldPivot = CFrame.new()
	m.Parent = folder
	local copy = m:Clone()
	copy:PivotTo(ROW * CFrame.new(-21 + (i - 1) * 14, 0, 0))
	copy.Parent = preview
	if dummy then
		local d = dummy:Clone()
		d.Name = "Dummy"
		for _, p in d:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
			elseif p:IsA("BodyColors") then -- light grey so the dummy reads against the dark stone
				for _, prop in { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" } do
					(p :: any)[prop] = Color3.fromRGB(205, 205, 210)
				end
			end
		end
		local _, size = d:GetBoundingBox()
		local stand = copy:FindFirstChild("RigStand", true)
		d:PivotTo(stand.WorldCFrame * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, math.pi, 0)) -- face the front (-Z)
		local cf2, size2 = d:GetBoundingBox()
		d:PivotTo(d:GetPivot() + Vector3.new(0, stand.WorldPosition.Y - (cf2.Y - size2.Y / 2), 0))
		d.Parent = copy
	end
	local n = 0
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			n += 1
		end
	end
	local _, size = m:GetBoundingBox()
	table.insert(out, ("%s: %d parts, %.1f x %.1f x %.1f, stand at %.2f"):format(m.Name, n, size.X, size.Y, size.Z, m:GetAttribute("StandHeight")))
end
if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return table.concat(out, "\n") .. "\ndummy: " .. tostring(dummy ~= nil)
