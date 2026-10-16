--!nocheck
-- UIBuilder: bakes the game's ScreenGuis into StarterGui in EDIT mode so they can be seen,
-- screenshotted and tweaked in Studio. The client UIController finds every live element by NAME
-- (never by child order) and overwrites every placeholder on its first draw.
--   require(game.ServerStorage.EOSBuild.UIBuilder)()          -- rebuild all three guis
--   require(game.ServerStorage.EOSBuild.UIBuilder).preview(s)  -- set every Fit scale (edit view)
-- Design canvas: 1920x1080 units; each anchored group carries a UIScale named "Fit".
-- Oct 2026 layout (the developer's reference): pills top-left next to Roblox's buttons, wide
-- buttons top-right, a square icon rail on the left, Gold/Gems bottom-left, the equipped pet's
-- ability card bottom-centre over the dash bar, plain outlined status text top-centre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local UIFolder = ReplicatedStorage.EOS.UI
local Theme = require(UIFolder.Theme)
local UIKit = require(UIFolder.UIKit)
local new = UIKit.new

local PREVIEW_SCALE = 0.62
local LEFT = Enum.TextXAlignment.Left
local RIGHT = Enum.TextXAlignment.Right

local function screen(name: string, order: number, insets: Enum.ScreenInsets): ScreenGui
	local old = StarterGui:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	return new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		ScreenInsets = insets,
	})
end

local function group(parent: Instance, name: string, anchor: Vector2, pos: UDim2, size: Vector2, visible: boolean?): Frame
	local g = new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = anchor,
		Position = pos,
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = if visible == nil then true else visible,
	}, parent)
	UIKit.fit(g, PREVIEW_SCALE)
	return g
end

local function list(parent: Instance, padding: number, horizontal: boolean?, align: Enum.HorizontalAlignment?)
	return new("UIListLayout", {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, parent)
end

-- red "!" (or a number) badge in a button's top-right corner, data-driven (hidden by default)
local function badge(parent: GuiObject, text: string?)
	local b = new("Frame", { Name = "Badge", BackgroundColor3 = Theme.badge, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -6, 0, 4), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 8 }, parent)
	UIKit.corner(b, UDim.new(0.5, 0))
	UIKit.stroke(b, Theme.ink, 2)
	UIKit.text(b, { Name = "Count", Text = text or "!", TextSize = 22, Size = UDim2.fromScale(1, 1), ZIndex = 9, Stroke = 1.5 })
	return b
end

-- dark pill with a glyph and a word (QUESTS, INCUBATOR)
local function pill(parent: Instance, name: string, glyph: string, text: string, width: number, order: number)
	local root = UIKit.plate(parent, { Name = name, Text = "", Size = UDim2.fromOffset(width, 54), Radius = 27, Button = true, Accent = false, LayoutOrder = order })
	UIKit.glyph(root.Face, glyph, { Name = "Icon", Size = 30, Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 5 })
	local label = root.Face.Label
	label.Text = text
	label.TextXAlignment = LEFT
	label.Position = UDim2.fromOffset(56, 0)
	label.Size = UDim2.new(1, -70, 1, 0)
	label.TextSize = 26
	label.UITextSizeConstraint.MaxTextSize = 26
	badge(root)
	return root
end

-- square rail tile (glyph + a small word under it)
local function tile(parent: Instance, name: string, glyph: string, text: string, order: number)
	local root = UIKit.plate(parent, { Name = name, Text = "", Size = UDim2.fromOffset(92, 92), Radius = 14, Button = true, Accent = false, LayoutOrder = order })
	UIKit.glyph(root.Face, glyph, { Name = "Icon", Size = 44, Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 5 })
	local label = root.Face.Label
	label.Text = text
	label.Size = UDim2.new(1, -8, 0, 24)
	label.Position = UDim2.new(0, 4, 1, -30)
	label.TextSize = 18
	label.UITextSizeConstraint.MaxTextSize = 18
	badge(root)
	return root
end

-- wide top-right button with an accent underline (STATS, SETTINGS)
local function wideButton(parent: Instance, name: string, glyph: string, text: string, ramp: string, order: number)
	local root = UIKit.plate(parent, { Name = name, Text = "", Ramp = ramp, Size = UDim2.fromOffset(210, 56), Radius = 12, Button = true, LayoutOrder = order, AccentHeight = 4 })
	UIKit.glyph(root.Face, glyph, { Name = "Icon", Size = 28, Position = UDim2.new(0, 18, 0.5, -2), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 5 })
	local label = root.Face.Label
	label.Text = text
	label.TextXAlignment = LEFT
	label.Position = UDim2.fromOffset(58, -2)
	label.Size = UDim2.new(1, -70, 1, 0)
	label.TextSize = 26
	label.UITextSizeConstraint.MaxTextSize = 26
	return root
end

-- a currency panel (coin / gem glyph, big number, small word); faint studs
local function currency(parent: Instance, name: string, glyph: string, word: string, color: Color3, order: number)
	local c = UIKit.card(parent, { Name = name, Size = UDim2.fromOffset(330, 84), Radius = 12, LayoutOrder = order, Studs = true, TileSize = 40 })
	UIKit.glyph(c, glyph, { Name = "Icon", Size = 50, Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
	UIKit.text(c, { Name = "Value", Text = "0", TextSize = 44, Size = UDim2.new(1, -96, 0, 50), Position = UDim2.fromOffset(80, 6), Align = LEFT, Color = color, Scaled = true, ZIndex = 3 })
	UIKit.text(c, { Name = "Label", Text = word, TextSize = 18, Size = UDim2.new(1, -96, 0, 22), Position = UDim2.fromOffset(82, 54), Align = LEFT, Color = Theme.mutedText, Stroke = 1.5, ZIndex = 3 })
	return c
end

-- the equipped pet's ability card (reference: ABILITY tag, round icon, name, EQUIPPED line)
local function abilityCard(parent: Instance)
	local c = UIKit.card(parent, { Name = "Card", Size = UDim2.fromOffset(420, 104), Radius = 12, Tint = "orange" })
	local ring = new("Frame", { Name = "IconRing", BackgroundColor3 = Color3.fromRGB(10, 12, 16), BackgroundTransparency = 0.3, Size = UDim2.fromOffset(78, 78), Position = UDim2.new(0, 12, 0.5, 2), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 }, c)
	UIKit.corner(ring, UDim.new(0.5, 0))
	UIKit.stroke(ring, Theme.edge, 2).Transparency = 0.7
	local vp = new("ViewportFrame", { Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, ring)
	UIKit.corner(vp, UDim.new(0.5, 0))
	UIKit.glyph(ring, "paw", { Name = "Empty", Size = 40, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Theme.mutedText, ZIndex = 4 })
	UIKit.text(c, { Name = "Tag", Text = "ABILITY", TextSize = 16, Size = UDim2.fromOffset(120, 20), Position = UDim2.fromOffset(10, 4), Align = LEFT, Stroke = 1.5, ZIndex = 5 })
	UIKit.text(c, { Name = "AbilityName", Text = "DECOY", TextSize = 30, Size = UDim2.new(1, -170, 0, 36), Position = UDim2.fromOffset(104, 20), Align = LEFT, Scaled = true, ZIndex = 3 })
	UIKit.text(c, { Name = "Sub", Text = "EQUIPPED · MOUSE", TextSize = 18, Size = UDim2.new(1, -170, 0, 24), Position = UDim2.fromOffset(104, 58), Align = LEFT, Scaled = true, Color = Theme.ramps.orange.top, Stroke = 1.5, ZIndex = 3 })
	local key = UIKit.plate(c, { Name = "Key", Text = "Q", TextSize = 30, Size = UDim2.fromOffset(52, 52), Position = UDim2.new(1, -14, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Radius = 10, Accent = false, Studs = false, ZIndex = 4 })
	local track = new("Frame", { Name = "Cooldown", BackgroundColor3 = Color3.fromRGB(8, 10, 14), BackgroundTransparency = 0.3, BorderSizePixel = 0, Size = UDim2.new(1, -24, 0, 5), Position = UDim2.new(0, 12, 1, -9), ZIndex = 4 }, c)
	UIKit.corner(track, 3)
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = Theme.ramps.orange.mid, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, track)
	UIKit.corner(fill, 3)
	return c, key
end

-- ======================= HUD =======================
local function buildHUD(): ScreenGui
	local gui = screen("EOS_HUD", 5, Enum.ScreenInsets.DeviceSafeInsets)

	-- top-left pills, beside Roblox's own buttons (the client adds the topbar's width at runtime)
	local tl = group(gui, "TopLeft", Vector2.new(0, 0), UDim2.new(0, 10, 0, 6), Vector2.new(470, 60))
	list(tl, 10, true, Enum.HorizontalAlignment.Left)
	pill(tl, "QuestsPill", "list", "QUESTS", 190, 1)
	pill(tl, "IncubatorPill", "egg", "INCUBATOR", 250, 2)

	-- top-right: wide buttons with accent underlines
	local tr = group(gui, "TopRight", Vector2.new(1, 0), UDim2.new(1, -12, 0, 8), Vector2.new(440, 60))
	list(tr, 12, true, Enum.HorizontalAlignment.Right)
	wideButton(tr, "StatsBtn", "bars", "STATS", "blue", 1)
	wideButton(tr, "SettingsBtn", "gear", "SETTINGS", "yellow", 2)

	-- left rail: square tiles
	local rail = group(gui, "LeftRail", Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, 0), Vector2.new(96, 522))
	list(rail, 10)
	tile(rail, "ShopBtn", "bag", "SHOP", 1)
	tile(rail, "PetsBtn", "paw", "PETS", 2)
	tile(rail, "EmotesBtn", "note", "EMOTES", 3)
	tile(rail, "AFKToggle", "zz", "AFK: OFF", 4)
	tile(rail, "VolunteerToggle", "target", "HUNT: OFF", 5)

	-- touch: MENU opens the rail as a drawer (keeps the thumbstick zone clear)
	local menuBtn = group(gui, "MenuButton", Vector2.new(0, 0), UDim2.new(0, 10, 0, 6), Vector2.new(150, 60), false)
	UIKit.plate(menuBtn, { Name = "Button", Text = "MENU", TextSize = 28, Size = UDim2.fromOffset(150, 60), Button = true, Radius = 30, Accent = false })

	-- top centre: status text (lobby) / match bar (in match) / direction arrow
	local top = group(gui, "TopCenter", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 6), Vector2.new(1100, 420))
	local status = new("Frame", { Name = "StatusPill", BackgroundTransparency = 1, Size = UDim2.fromOffset(1100, 130), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0) }, top)
	UIKit.text(status, { Name = "Place", Text = "LOBBY", TextSize = 24, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4), Stroke = 2 })
	UIKit.text(status, { Name = "Title", Text = "NEXT MATCH IN 0:12", TextSize = 50, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 34), Scaled = true, Stroke = 3 })
	UIKit.text(status, { Name = "Sub", Text = "4 PLAYERS READY", TextSize = 26, Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 96), Scaled = true, Stroke = 2 })

	local bar = new("Frame", { Name = "MatchBar", BackgroundTransparency = 1, Size = UDim2.fromOffset(820, 120), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), Visible = false }, top)
	UIKit.plate(bar, { Name = "WaveTag", Ramp = "purple", Text = "CROSSING 1", TextSize = 28, Size = UDim2.fromOffset(250, 62), Position = UDim2.fromOffset(0, 18), Radius = 31 })
	-- the clean run: crossings in a row with nobody caught (3 = Runners win)
	local streak = new("Frame", { Name = "Streak", BackgroundTransparency = 1, Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(0, 86) }, bar)
	list(streak, 6, true, Enum.HorizontalAlignment.Center)
	UIKit.text(streak, { Name = "Label", Text = "CLEAN RUN", TextSize = 20, Size = UDim2.fromOffset(120, 30), LayoutOrder = 0, Stroke = 1.5 })
	for i = 1, 3 do
		local dot = new("Frame", { Name = "Dot" .. i, BackgroundColor3 = Color3.fromRGB(20, 24, 32), BackgroundTransparency = 0.2, Size = UDim2.fromOffset(24, 24), LayoutOrder = i }, streak)
		UIKit.corner(dot, 6)
		local e = UIKit.stroke(dot, Theme.edge, 2)
		e.Transparency = 0.5
	end
	local timer = UIKit.card(bar, { Name = "TimerCard", Size = UDim2.fromOffset(230, 116), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), Radius = 18, Studs = true })
	UIKit.text(timer, { Name = "Timer", Text = "0:30", TextSize = 72, Size = UDim2.new(1, 0, 0, 82), Position = UDim2.fromOffset(0, 4), Stroke = 3 })
	UIKit.text(timer, { Name = "PhaseLabel", Text = "CROSS!", TextSize = 22, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 84), Color = Theme.mutedText, Scaled = true, Stroke = 1.5 })
	local counts = UIKit.card(bar, { Name = "Counts", Size = UDim2.fromOffset(250, 80), Position = UDim2.new(1, 0, 0, 18), AnchorPoint = Vector2.new(1, 0), Radius = 14 })
	UIKit.text(counts, { Name = "Runners", Text = "5 RUNNERS", TextSize = 26, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 5), Color = Theme.ramps.blue.top, Scaled = true, Stroke = 2 })
	UIKit.text(counts, { Name = "Catchers", Text = "2 CATCHERS", TextSize = 26, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 40), Color = Theme.ramps.red.top, Scaled = true, Stroke = 2 })

	local afk = UIKit.text(top, { Name = "AFKBanner", Text = "AFK ON: you'll sit out matches until you turn it off", TextSize = 26, Size = UDim2.fromOffset(900, 34), Position = UDim2.new(0.5, 0, 0, 132), AnchorPoint = Vector2.new(0.5, 0), Color = Theme.ramps.orange.top, Visible = false, Stroke = 2 })

	local arrowHolder = new("Frame", { Name = "ArrowHolder", BackgroundTransparency = 1, Size = UDim2.fromOffset(260, 220), Position = UDim2.new(0.5, 0, 0, 140), AnchorPoint = Vector2.new(0.5, 0), Visible = false }, top)
	UIKit.arrow(arrowHolder, { Name = "Arrow", Size = 130, Position = UDim2.new(0.5, 0, 0, 72), AnchorPoint = Vector2.new(0.5, 0.5) })
	UIKit.text(arrowHolder, { Name = "ArrowLabel", Text = "SIDE B  ·  64", TextSize = 30, Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 150), Color = Theme.ramps.green.top, Scaled = true, Stroke = 2 })

	-- bottom left: Gold + Gems (hidden during a match: GDD 14 keeps economy counters off the chase)
	local wallet = group(gui, "Wallet", Vector2.new(0, 1), UDim2.new(0, 12, 1, -12), Vector2.new(330, 180))
	list(wallet, 10)
	currency(wallet, "GoldCard", "coin", "GOLD", Theme.goldText, 1)
	currency(wallet, "GemsCard", "gem", "GEMS", Theme.gemText, 2)

	-- bottom left, in a match: your role and egg level
	local role = group(gui, "RolePanel", Vector2.new(0, 1), UDim2.new(0, 12, 1, -12), Vector2.new(560, 170), false)
	local rc = UIKit.card(role, { Name = "Card", Size = UDim2.fromOffset(560, 136), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), Radius = 14, Studs = true })
	UIKit.plate(role, { Name = "RoleTag", Ramp = "blue", Solid = true, Text = "RUNNER", TextSize = 28, Size = UDim2.fromOffset(190, 50), Position = UDim2.fromOffset(16, 6), Radius = 25, ZIndex = 3 })
	UIKit.eggIcon(rc, { Name = "Egg", Width = 64, Height = 80, Position = UDim2.fromOffset(22, 44), Tier = 2 })
	UIKit.text(rc, { Name = "Line1", Text = "YOUR EGG: LEVEL 2", TextSize = 32, Size = UDim2.fromOffset(440, 40), Position = UDim2.fromOffset(104, 30), Align = LEFT, Scaled = true, Stroke = 2 })
	UIKit.text(rc, { Name = "Line2", Text = "SECURED: LEVEL 2", TextSize = 22, Size = UDim2.fromOffset(440, 28), Position = UDim2.fromOffset(104, 68), Align = LEFT, Scaled = true, Color = Theme.mutedText, Stroke = 1.5 })
	UIKit.text(rc, { Name = "Objective", Text = "CROSS TO SIDE B!", TextSize = 24, Size = UDim2.fromOffset(440, 30), Position = UDim2.fromOffset(104, 98), Align = LEFT, Scaled = true, Color = Theme.gold, Stroke = 2 })

	-- bottom centre: the ability card, over the dash bar
	local ability = group(gui, "AbilityBar", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -86), Vector2.new(420, 104))
	abilityCard(ability)

	-- PC / gamepad: slim dash meter along the bottom edge
	local meter = group(gui, "DashBar", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -8), Vector2.new(720, 64), false)
	local track, fill, label = UIKit.bar(meter, { Name = "Track", Ramp = "grey", Value = 1, Text = "", Size = UDim2.fromOffset(720, 12), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1) })
	label.Visible = false
	UIKit.text(meter, { Name = "Key", Text = "SPACE  ·  DASH", TextSize = 28, Size = UDim2.fromOffset(300, 34), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), Scaled = true, Stroke = 2 })
	UIKit.text(meter, { Name = "Status", Text = "DASH READY", TextSize = 18, Size = UDim2.fromOffset(220, 22), Position = UDim2.fromOffset(2, 26), Align = LEFT, Scaled = true, Stroke = 1.5 })
	UIKit.text(meter, { Name = "Tip", Text = "SIDE/BACK + SPACE = DODGE", TextSize = 18, Size = UDim2.fromOffset(280, 22), Position = UDim2.new(1, -2, 0, 26), AnchorPoint = Vector2.new(1, 0), Align = RIGHT, Scaled = true, Stroke = 1.5 })

	-- touch: round buttons (TAG for Catchers, ABILITY, DASH where the jump button was)
	local tag = group(gui, "TagButton", Vector2.new(1, 1), UDim2.new(1, -40, 1, -250), Vector2.new(190, 190), false)
	local tb = UIKit.plate(tag, { Name = "Button", Ramp = "red", Solid = true, Text = "TAG", TextSize = 56, Size = UDim2.fromOffset(190, 190), Button = true, Radius = 95, TileSize = 64 })
	local cd = new("Frame", { Name = "Cooldown", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 6 }, tb)
	UIKit.corner(cd, UDim.new(0.5, 0))

	local dash = group(gui, "DashButton", Vector2.new(1, 1), UDim2.new(1, -40, 1, -36), Vector2.new(190, 190), false)
	local db = UIKit.plate(dash, { Name = "Button", Ramp = "blue", Solid = true, Text = "DASH", TextSize = 50, Size = UDim2.fromOffset(190, 190), Button = true, Radius = 95, TileSize = 64 })
	local dcd = new("Frame", { Name = "Cooldown", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 8 }, db)
	UIKit.corner(dcd, UDim.new(0.5, 0))
	UIKit.text(dcd, { Name = "Count", Text = "", TextSize = 60, Size = UDim2.fromScale(1, 1), ZIndex = 9 })

	local abilityBtn = group(gui, "AbilityButton", Vector2.new(1, 1), UDim2.new(1, -250, 1, -36), Vector2.new(150, 150), false)
	local ab = UIKit.plate(abilityBtn, { Name = "Button", Ramp = "orange", Solid = true, Text = "", TextSize = 30, Size = UDim2.fromOffset(150, 150), Button = true, Radius = 75, TileSize = 64 })
	ab.Face.Label.Text = "DECOY"
	ab.Face.Label.Size = UDim2.new(1, -20, 0, 40)
	ab.Face.Label.Position = UDim2.new(0, 10, 0.5, -20)
	local acd = new("Frame", { Name = "Cooldown", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 8 }, ab)
	UIKit.corner(acd, UDim.new(0.5, 0))
	UIKit.text(acd, { Name = "Count", Text = "", TextSize = 52, Size = UDim2.fromScale(1, 1), ZIndex = 9 })

	-- right: capture feed
	local feed = group(gui, "Feed", Vector2.new(1, 0), UDim2.new(1, -12, 0, 90), Vector2.new(560, 330))
	list(feed, 8, false, Enum.HorizontalAlignment.Right)

	-- centre banner for big moments (evolve, caught, timeout, crossing start, hatch)
	local banner = group(gui, "Banner", Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.42, 0), Vector2.new(1400, 320), false)
	new("ImageLabel", { Name = "Burst", BackgroundTransparency = 1, Image = Theme.img.sunburst, ImageColor3 = Theme.gold, ImageTransparency = 0.6, Size = UDim2.fromOffset(420, 420), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 1 }, banner)
	UIKit.text(banner, { Name = "Title", Text = "SAFE! LEVEL 3", TextSize = 92, Size = UDim2.new(1, 0, 0, 116), Position = UDim2.fromOffset(0, 60), Scaled = true, ZIndex = 3, Stroke = 4 })
	UIKit.text(banner, { Name = "Sub", Text = "Your egg evolved", TextSize = 40, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 184), Scaled = true, ZIndex = 3, Color = Theme.gold, Stroke = 2.5 })

	-- control hint line
	local hint = group(gui, "Hint", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -206), Vector2.new(1100, 44))
	UIKit.text(hint, { Name = "Text", Text = "", TextSize = 24, Size = UDim2.fromScale(1, 1), Scaled = true, Stroke = 2 })

	-- runtime templates (cloned by the client; never shown in place)
	local templates = new("Folder", { Name = "Templates" }, gui)
	local toast = UIKit.card(templates, { Name = "Toast", Size = UDim2.fromOffset(760, 64), Radius = 14, Transparency = 0.12 })
	UIKit.text(toast, { Name = "Text", Text = "Toast", TextSize = 28, Size = UDim2.new(1, -44, 1, -8), Position = UDim2.fromOffset(30, 4), Scaled = true, Stroke = 2 })
	local accent = new("Frame", { Name = "Accent", BackgroundColor3 = Theme.gold, BorderSizePixel = 0, Size = UDim2.new(0, 6, 1, -20), Position = UDim2.fromOffset(12, 10) }, toast)
	UIKit.corner(accent, 3)
	local line = UIKit.card(templates, { Name = "FeedLine", Size = UDim2.fromOffset(540, 52), Radius = 12, Transparency = 0.25 })
	UIKit.text(line, { Name = "Text", Text = "A caught B", TextSize = 24, Size = UDim2.new(1, -24, 1, -6), Position = UDim2.fromOffset(12, 3), Scaled = true, RichText = true, Align = RIGHT, Stroke = 1.5 })
	toast.Visible = false -- templates never render in place (a Folder does not hide GuiObjects)
	line.Visible = false
	return gui
end

-- ======================= MENUS =======================
local function toggleRow(parent: Instance, name: string, labelText: string, order: number)
	local row = new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 96), LayoutOrder = order }, parent)
	UIKit.text(row, { Name = "Label", Text = labelText, TextSize = 32, Size = UDim2.new(1, -260, 1, 0), Align = LEFT, Scaled = true, Wrapped = true, Stroke = 2 })
	UIKit.plate(row, { Name = "Toggle", Ramp = "green", Solid = true, Text = "ON", TextSize = 34, Size = UDim2.fromOffset(220, 84), Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Button = true, Radius = 16 })
	return row
end

-- price row: coin / gem glyph + number (one label: no gap)
local function price(parent: Instance, wallet: string, amount: number, pos: UDim2, anchor: Vector2?)
	local f = new("Frame", { Name = "Price", BackgroundTransparency = 1, Size = UDim2.fromOffset(170, 40), Position = pos, AnchorPoint = anchor or Vector2.new() }, parent)
	-- both glyphs exist so a cloned card can show either wallet
	local coin = UIKit.glyph(f, "coin", { Name = "Coin", Size = 34, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 4 })
	local gem = UIKit.glyph(f, "gem", { Name = "Gem", Size = 34, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 4 })
	coin.Visible = wallet ~= "gems"
	gem.Visible = wallet == "gems"
	UIKit.text(f, { Name = "Amount", Text = tostring(amount), TextSize = 30, Size = UDim2.new(1, -42, 1, 0), Position = UDim2.fromOffset(42, 0), Align = LEFT, Color = if wallet == "gems" then Theme.gemText else Theme.goldText, Scaled = true, Stroke = 2, ZIndex = 4 })
	return f
end

local function buildMenus(): ScreenGui
	local gui = screen("EOS_Menus", 10, Enum.ScreenInsets.CoreUISafeInsets)
	local scrim = new("TextButton", { Name = "Scrim", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.new(1, 0, 1, 120), Position = UDim2.fromOffset(0, -120), Visible = false, Selectable = false }, gui) -- reaches up under the topbar strip

	local function panelGroup(name: string, size: Vector2, title: string, ramp: string)
		local g = group(gui, name, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.52), size, false)
		local p, body, close = UIKit.panel(g, { Name = "Panel", Title = title, Ramp = ramp, Size = UDim2.fromOffset(size.X, size.Y), Position = UDim2.fromScale(0.5, 0.5) })
		return g, body, p
	end

	-- Quests
	local _, qb = panelGroup("Quests", Vector2.new(1120, 700), "DAILY QUESTS", "green")
	UIKit.text(qb, { Name = "ResetTimer", Text = "NEW QUESTS IN 5h 12m", TextSize = 26, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 0), Align = LEFT, Color = Theme.mutedText, Stroke = 2 })
	local ql = new("Frame", { Name = "List", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -100), Position = UDim2.fromOffset(0, 46) }, qb)
	list(ql, 16)
	for i = 1, 2 do
		local card = UIKit.card(ql, { Name = "Quest" .. i, Size = UDim2.new(1, 0, 0, 200), Radius = 16, LayoutOrder = i, Transparency = 0.35, Studs = true })
		UIKit.text(card, { Name = "Title", Text = "Complete 1 crossing", TextSize = 38, Size = UDim2.new(1, -330, 0, 50), Position = UDim2.fromOffset(28, 18), Align = LEFT, Scaled = true })
		local reward = new("Frame", { Name = "RewardRow", BackgroundTransparency = 1, Size = UDim2.fromOffset(300, 40), Position = UDim2.fromOffset(28, 76) }, card)
		UIKit.glyph(reward, "coin", { Name = "Icon", Size = 34, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
		UIKit.text(card, { Name = "Reward", Text = "+15 GOLD", TextSize = 30, Size = UDim2.fromOffset(250, 40), Position = UDim2.fromOffset(72, 76), Align = LEFT, Color = Theme.goldText, Scaled = true })
		UIKit.bar(card, { Name = "Progress", Ramp = "green", Text = "0 / 1", Size = UDim2.new(1, -330, 0, 46), Position = UDim2.fromOffset(28, 132), Value = 0 })
		UIKit.plate(card, { Name = "Claim", Ramp = "grey", Solid = true, Text = "CLAIM", TextSize = 38, Size = UDim2.fromOffset(240, 100), Position = UDim2.new(1, -24, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Button = true, Radius = 18 })
	end
	UIKit.text(qb, { Name = "Footer", Text = "Progress counts in real matches only  ·  resets 00:00 UTC", TextSize = 24, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 1, -36), Color = Theme.mutedText, Scaled = true, Stroke = 1.5 })

	-- Incubator: egg pieces -> pets
	local _, ib, ip = panelGroup("Incubator", Vector2.new(1320, 780), "INCUBATOR", "yellow")
	UIKit.text(ib, { Name = "Intro", Text = "Every match you finish wins one egg piece. Hatch pieces into a pet: one pet = one ability.", TextSize = 26, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 0), Align = LEFT, Color = Theme.mutedText, Scaled = true, Stroke = 1.5 })
	local tiers = new("Frame", { Name = "Tiers", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 470), Position = UDim2.fromOffset(0, 54) }, ib)
	list(tiers, 24, true)
	for i, m in ipairs({ "common", "rare", "epic" }) do
		local card = UIKit.card(tiers, { Name = "Tier_" .. m, Size = UDim2.fromOffset(392, 470), Radius = 18, LayoutOrder = i, Transparency = 0.3, Studs = true })
		UIKit.eggIcon(card, { Name = "Egg", Width = 110, Height = 138, Position = UDim2.new(0.5, 0, 0, 24), AnchorPoint = Vector2.new(0.5, 0), Tier = ({ 1, 3, 4 })[i] })
		UIKit.text(card, { Name = "TierName", Text = string.upper(m) .. " PIECES", TextSize = 34, Size = UDim2.new(1, -24, 0, 42), Position = UDim2.fromOffset(12, 172), Scaled = true })
		UIKit.text(card, { Name = "Count", Text = "x 0", TextSize = 46, Size = UDim2.new(1, -24, 0, 54), Position = UDim2.fromOffset(12, 214), Scaled = true, Color = Theme.goldText })
		UIKit.text(card, { Name = "Recipe", Text = "HATCH: 2  ·  PICK FAMILY: 3", TextSize = 22, Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 270), Scaled = true, Color = Theme.mutedText, Stroke = 1.5 })
		UIKit.bar(card, { Name = "Progress", Ramp = "yellow", Text = "0 / 2", TextSize = 22, Size = UDim2.new(1, -48, 0, 34), Position = UDim2.fromOffset(24, 308), Value = 0 })
		UIKit.plate(card, { Name = "HatchRandom", Ramp = "yellow", Solid = true, Text = "HATCH", TextSize = 30, Size = UDim2.fromOffset(166, 78), Position = UDim2.new(0, 22, 1, -20), AnchorPoint = Vector2.new(0, 1), Button = true, Radius = 16 })
		UIKit.plate(card, { Name = "HatchPick", Ramp = "purple", Solid = true, Text = "PICK", TextSize = 30, Size = UDim2.fromOffset(166, 78), Position = UDim2.new(1, -22, 1, -20), AnchorPoint = Vector2.new(1, 1), Button = true, Radius = 16 })
	end
	UIKit.text(ib, { Name = "Note", Text = "Missing a few? Higher pieces can fill lower recipes (you'll be asked first).", TextSize = 24, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 540), Color = Theme.mutedText, Scaled = true, Stroke = 1.5 })
	UIKit.text(ib, { Name = "FirstFree", Text = "YOUR FIRST COMMON PET: PICK ITS FAMILY FOR FREE", TextSize = 28, Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 580), Color = Theme.goldText, Scaled = true, Stroke = 2 })

	-- family picker (overlay inside the incubator panel)
	local picker = new("Frame", { Name = "Picker", BackgroundColor3 = Theme.panel, BackgroundTransparency = 0.02, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 20, Active = true }, ip)
	UIKit.corner(picker, 24)
	UIKit.text(picker, { Name = "Title", Text = "PICK A FAMILY", TextSize = 50, Size = UDim2.new(1, -200, 0, 60), Position = UDim2.fromOffset(40, 24), Align = LEFT, Scaled = true, ZIndex = 21 })
	UIKit.text(picker, { Name = "Cost", Text = "COSTS 3 COMMON PIECES", TextSize = 26, Size = UDim2.new(1, -200, 0, 34), Position = UDim2.fromOffset(40, 88), Align = LEFT, Color = Theme.goldText, Scaled = true, ZIndex = 21, Stroke = 2 })
	UIKit.plate(picker, { Name = "Back", Ramp = "red", Solid = true, Text = "X", TextSize = 44, Size = UDim2.fromOffset(76, 76), Position = UDim2.new(1, -22, 0, 22), AnchorPoint = Vector2.new(1, 0), Radius = 18, Button = true, ZIndex = 22 })
	local fams = new("Frame", { Name = "Families", BackgroundTransparency = 1, Size = UDim2.new(1, -80, 0, 560), Position = UDim2.fromOffset(40, 150), ZIndex = 21 }, picker)
	list(fams, 24, true)
	for i, fam in ipairs({ "Decoy", "Scout", "Brake" }) do
		local card = UIKit.card(fams, { Name = fam, Size = UDim2.fromOffset(392, 560), Radius = 18, LayoutOrder = i, Transparency = 0.3, ZIndex = 21 })
		local vp = new("ViewportFrame", { Name = "View", BackgroundColor3 = Color3.fromRGB(10, 12, 16), BackgroundTransparency = 0.4, Size = UDim2.fromOffset(240, 220), Position = UDim2.new(0.5, 0, 0, 16), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 22 }, card)
		UIKit.corner(vp, 16)
		UIKit.text(card, { Name = "Ability", Text = string.upper(fam), TextSize = 40, Size = UDim2.new(1, -24, 0, 48), Position = UDim2.fromOffset(12, 244), Scaled = true, ZIndex = 22 })
		UIKit.text(card, { Name = "Species", Text = "Mouse", TextSize = 26, Size = UDim2.new(1, -24, 0, 32), Position = UDim2.fromOffset(12, 292), Scaled = true, Color = Theme.mutedText, ZIndex = 22, Stroke = 1.5 })
		UIKit.text(card, { Name = "Desc", Text = "Sends a copy of you running ahead.", TextSize = 24, Size = UDim2.new(1, -36, 0, 110), Position = UDim2.fromOffset(18, 330), Wrapped = true, ZIndex = 22, Stroke = 1.5 })
		UIKit.plate(card, { Name = "Pick", Ramp = "green", Solid = true, Text = "PICK", TextSize = 34, Size = UDim2.fromOffset(220, 80), Position = UDim2.new(0.5, 0, 1, -18), AnchorPoint = Vector2.new(0.5, 1), Button = true, Radius = 16, ZIndex = 22 })
	end

	-- confirm using higher pieces
	local confirm = new("Frame", { Name = "Confirm", BackgroundColor3 = Theme.panel, BackgroundTransparency = 0.02, Size = UDim2.fromOffset(820, 360), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 30, Active = true }, ip)
	UIKit.corner(confirm, 20)
	UIKit.stroke(confirm, Theme.edge, 2).Transparency = 0.7
	UIKit.text(confirm, { Name = "Title", Text = "USE HIGHER PIECES?", TextSize = 44, Size = UDim2.new(1, -60, 0, 56), Position = UDim2.fromOffset(30, 26), Scaled = true, ZIndex = 31 })
	UIKit.text(confirm, { Name = "Body", Text = "This hatch uses 1 Rare piece as a Common piece.", TextSize = 28, Size = UDim2.new(1, -60, 0, 110), Position = UDim2.fromOffset(30, 92), Wrapped = true, Scaled = true, Color = Theme.mutedText, ZIndex = 31, Stroke = 1.5 })
	UIKit.plate(confirm, { Name = "Yes", Ramp = "green", Solid = true, Text = "USE THEM", TextSize = 32, Size = UDim2.fromOffset(300, 86), Position = UDim2.new(0.5, -16, 1, -28), AnchorPoint = Vector2.new(1, 1), Button = true, Radius = 16, ZIndex = 31 })
	UIKit.plate(confirm, { Name = "No", Ramp = "grey", Solid = true, Text = "NOT NOW", TextSize = 32, Size = UDim2.fromOffset(300, 86), Position = UDim2.new(0.5, 16, 1, -28), AnchorPoint = Vector2.new(0, 1), Button = true, Radius = 16, ZIndex = 31 })

	-- hatch reveal
	local reveal = new("Frame", { Name = "Reveal", BackgroundColor3 = Theme.panel, BackgroundTransparency = 0.02, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 40, Active = true }, ip)
	UIKit.corner(reveal, 24)
	new("ImageLabel", { Name = "Burst", BackgroundTransparency = 1, Image = Theme.img.sunburst, ImageColor3 = Theme.gold, ImageTransparency = 0.55, Size = UDim2.fromOffset(700, 700), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 41 }, reveal)
	UIKit.eggIcon(reveal, { Name = "Egg", Width = 200, Height = 250, Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Tier = 1, ZIndex = 43 })
	local rvp = new("ViewportFrame", { Name = "View", BackgroundTransparency = 1, Size = UDim2.fromOffset(420, 380), Position = UDim2.fromScale(0.5, 0.4), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 44 }, reveal)
	UIKit.text(reveal, { Name = "Title", Text = "NEW PET!", TextSize = 64, Size = UDim2.new(1, -60, 0, 76), Position = UDim2.new(0.5, 0, 1, -250), AnchorPoint = Vector2.new(0.5, 0), Scaled = true, ZIndex = 45, Stroke = 3 })
	UIKit.text(reveal, { Name = "Sub", Text = "COMMON MOUSE  ·  DECOY", TextSize = 32, Size = UDim2.new(1, -60, 0, 42), Position = UDim2.new(0.5, 0, 1, -170), AnchorPoint = Vector2.new(0.5, 0), Scaled = true, Color = Theme.goldText, ZIndex = 45, Stroke = 2 })
	UIKit.plate(reveal, { Name = "Done", Ramp = "green", Solid = true, Text = "NICE!", TextSize = 36, Size = UDim2.fromOffset(280, 86), Position = UDim2.new(0.5, 0, 1, -28), AnchorPoint = Vector2.new(0.5, 1), Button = true, Radius = 16, ZIndex = 45 })

	-- Pets (collection + equip)
	local _, pb = panelGroup("Pets", Vector2.new(1320, 780), "YOUR PETS", "orange")
	UIKit.text(pb, { Name = "Equipped", Text = "EQUIPPED: NONE", TextSize = 28, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 0), Align = LEFT, Color = Theme.goldText, Scaled = true, Stroke = 2 })
	local scroll = new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -56), Position = UDim2.fromOffset(0, 50), ScrollBarThickness = 8, ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.new(), ScrollBarImageColor3 = Theme.mutedText }, pb)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(292, 370), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	local pc = UIKit.card(scroll, { Name = "PetCard", Size = UDim2.fromOffset(292, 370), Radius = 16, Transparency = 0.3, Studs = true, Visible = false })
	local pvp = new("ViewportFrame", { Name = "View", BackgroundColor3 = Color3.fromRGB(10, 12, 16), BackgroundTransparency = 0.45, Size = UDim2.fromOffset(250, 170), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 2 }, pc)
	UIKit.corner(pvp, 14)
	UIKit.text(pc, { Name = "PetName", Text = "Mouse", TextSize = 32, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 190), Scaled = true })
	UIKit.text(pc, { Name = "Rarity", Text = "COMMON", TextSize = 22, Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 230), Scaled = true, Stroke = 1.5 })
	UIKit.text(pc, { Name = "Ability", Text = "ABILITY: DECOY", TextSize = 22, Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 258), Scaled = true, Color = Theme.mutedText, Stroke = 1.5 })
	UIKit.plate(pc, { Name = "Equip", Ramp = "green", Solid = true, Text = "EQUIP", TextSize = 30, Size = UDim2.fromOffset(220, 66), Position = UDim2.new(0.5, 0, 1, -14), AnchorPoint = Vector2.new(0.5, 1), Button = true, Radius = 14 })
	local empty = new("Frame", { Name = "Empty", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -56), Position = UDim2.fromOffset(0, 50), Visible = false }, pb)
	UIKit.glyph(empty, "paw", { Name = "Icon", Size = 120, Position = UDim2.new(0.5, 0, 0, 90), AnchorPoint = Vector2.new(0.5, 0), Color = Theme.mutedText })
	UIKit.text(empty, { Name = "Text", Text = "NO PETS YET", TextSize = 50, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 240), Scaled = true })
	UIKit.text(empty, { Name = "Sub", Text = "Finish matches to win egg pieces, then hatch them at the INCUBATOR. Your first Common pet takes 2 pieces.", TextSize = 28, Size = UDim2.new(1, -200, 0, 90), Position = UDim2.new(0.5, 0, 0, 312), AnchorPoint = Vector2.new(0.5, 0), Wrapped = true, Scaled = true, Color = Theme.mutedText, Stroke = 1.5 })
	UIKit.plate(empty, { Name = "Go", Ramp = "yellow", Solid = true, Text = "INCUBATOR", TextSize = 32, Size = UDim2.fromOffset(300, 84), Position = UDim2.new(0.5, 0, 0, 430), AnchorPoint = Vector2.new(0.5, 0), Button = true, Radius = 16 })

	-- Shop: Gold / Gem tabs, data-driven item cards
	local _, shb = panelGroup("Shop", Vector2.new(1320, 800), "SHOP", "pink")
	local tabs = new("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 0) }, shb)
	list(tabs, 14, true, Enum.HorizontalAlignment.Left)
	UIKit.plate(tabs, { Name = "GoldTab", Ramp = "yellow", Text = "GOLD SHOP", TextSize = 28, Size = UDim2.fromOffset(260, 60), Button = true, Radius = 30, LayoutOrder = 1 })
	UIKit.plate(tabs, { Name = "GemTab", Ramp = "green", Text = "GEM SHOP", TextSize = 28, Size = UDim2.fromOffset(260, 60), Button = true, Radius = 30, LayoutOrder = 2 })
	local walletRow = new("Frame", { Name = "Wallet", BackgroundTransparency = 1, Size = UDim2.fromOffset(420, 60), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0) }, shb)
	price(walletRow, "gold", 0, UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5)).Name = "Gold"
	price(walletRow, "gems", 0, UDim2.new(0, 220, 0.5, 0), Vector2.new(0, 0.5)).Name = "Gems"
	local sgrid = new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -130), Position = UDim2.fromOffset(0, 80), ScrollBarThickness = 8, ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.new(), ScrollBarImageColor3 = Theme.mutedText }, shb)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(392, 250), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }, sgrid)
	local ic = UIKit.card(sgrid, { Name = "ItemCard", Size = UDim2.fromOffset(392, 250), Radius = 16, Transparency = 0.3, Studs = true, Visible = false })
	local sw = new("Frame", { Name = "Swatch", BackgroundColor3 = Theme.gold, Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(18, 18), ZIndex = 2 }, ic)
	UIKit.corner(sw, 16)
	UIKit.stroke(sw, Theme.ink, 3)
	UIKit.studs(sw, 0.55, 28, 16)
	UIKit.text(ic, { Name = "ItemName", Text = "Sparkle Trail", TextSize = 32, Size = UDim2.new(1, -136, 0, 40), Position = UDim2.fromOffset(118, 18), Align = LEFT, Scaled = true })
	UIKit.text(ic, { Name = "Kind", Text = "ONE MATCH", TextSize = 20, Size = UDim2.new(1, -136, 0, 26), Position = UDim2.fromOffset(118, 60), Align = LEFT, Scaled = true, Color = Theme.mutedText, Stroke = 1.5 })
	UIKit.text(ic, { Name = "Desc", Text = "Your egg leaves sparkles. One match.", TextSize = 22, Size = UDim2.new(1, -36, 0, 60), Position = UDim2.fromOffset(18, 110), Wrapped = true, Scaled = true, Align = LEFT, YAlign = Enum.TextYAlignment.Top, Stroke = 1.5 })
	price(ic, "gold", 40, UDim2.new(0, 18, 1, -46), Vector2.new(0, 0.5))
	UIKit.plate(ic, { Name = "Buy", Ramp = "green", Solid = true, Text = "BUY", TextSize = 28, Size = UDim2.fromOffset(150, 64), Position = UDim2.new(1, -16, 1, -14), AnchorPoint = Vector2.new(1, 1), Button = true, Radius = 14 })
	UIKit.plate(ic, { Name = "Use", Ramp = "orange", Solid = true, Text = "USE", TextSize = 28, Size = UDim2.fromOffset(96, 64), Position = UDim2.new(1, -174, 1, -14), AnchorPoint = Vector2.new(1, 1), Button = true, Radius = 14, Visible = false })
	UIKit.text(ic, { Name = "Owned", Text = "x2", TextSize = 22, Size = UDim2.fromOffset(150, 26), Position = UDim2.new(1, -16, 1, -84), AnchorPoint = Vector2.new(1, 0), Align = RIGHT, Color = Theme.gemText, Visible = false, Stroke = 1.5 })
	UIKit.text(shb, { Name = "Footer", Text = "Gold is earned by playing. Everything here is looks only: nothing makes you faster or tag farther.", TextSize = 22, Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 1, -32), Color = Theme.mutedText, Scaled = true, Stroke = 1.5 })

	-- Emotes: the Emote Crate (odds board + open) and My Emotes (play). Cards are data-driven
	-- templates; the client (EmoteController) fills them from Shared/EmoteConfig.
	local _, eb, ep = panelGroup("Emotes", Vector2.new(1360, 920), "EMOTES", "purple")
	local etabs = new("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 0) }, eb)
	list(etabs, 14, true, Enum.HorizontalAlignment.Left)
	UIKit.plate(etabs, { Name = "CrateTab", Ramp = "purple", Text = "EMOTE CRATE", TextSize = 28, Size = UDim2.fromOffset(280, 60), Button = true, Radius = 30, LayoutOrder = 1 })
	UIKit.plate(etabs, { Name = "MineTab", Ramp = "blue", Text = "MY EMOTES", TextSize = 28, Size = UDim2.fromOffset(280, 60), Button = true, Radius = 30, LayoutOrder = 2 })
	local ewallet = new("Frame", { Name = "Wallet", BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 60), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0) }, eb)
	price(ewallet, "gems", 0, UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5)).Name = "Gems"

	-- crate tab
	local crate = new("Frame", { Name = "Crate", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -80), Position = UDim2.fromOffset(0, 80) }, eb)
	local odds = new("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 534), Position = UDim2.fromOffset(0, 0) }, crate)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(244, 170), CellPadding = UDim2.fromOffset(15, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, odds)
	local oc = UIKit.card(odds, { Name = "OddsCard", Size = UDim2.fromOffset(244, 170), Radius = 14, Transparency = 0.25, Studs = true, Outline = 3, Visible = false })
	oc.Edge.Color = Theme.ramps.grey.mid
	oc.Edge.Transparency = 0
	local strip = new("Frame", { Name = "Strip", BackgroundColor3 = Theme.ramps.grey.mid, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 34), ZIndex = 2 }, oc)
	UIKit.corner(strip, 14)
	new("Frame", { Name = "Square", BackgroundColor3 = Theme.ramps.grey.mid, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), ZIndex = 2 }, strip)
	UIKit.text(oc, { Name = "Rarity", Text = "COMMON  ·  10%", TextSize = 20, Size = UDim2.new(1, -50, 0, 30), Position = UDim2.fromOffset(12, 2), Align = LEFT, Scaled = true, Stroke = 1.5, ZIndex = 3 })
	UIKit.glyph(oc, "speaker", { Name = "Music", Size = 26, Position = UDim2.new(1, -10, 0, 4), AnchorPoint = Vector2.new(1, 0), ZIndex = 3 })
	-- live preview: the client puts your avatar doing this emote in here (WorldModel)
	local ov = new("ViewportFrame", { Name = "View", BackgroundColor3 = Color3.fromRGB(10, 12, 16), BackgroundTransparency = 0.5, Size = UDim2.new(1, -8, 0, 104), Position = UDim2.fromOffset(4, 34), Ambient = Color3.fromRGB(170, 170, 180), LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-1, -1, -1), ZIndex = 2 }, oc)
	UIKit.corner(ov, 10)
	UIKit.text(oc, { Name = "EmoteName", Text = "Snappy Skipping", TextSize = 26, Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 1, -31), Scaled = true, ZIndex = 3 })
	UIKit.text(oc, { Name = "Owned", Text = "OWNED", TextSize = 16, Size = UDim2.fromOffset(70, 20), Position = UDim2.fromOffset(10, 38), Align = LEFT, Scaled = true, Color = Theme.ramps.green.top, Stroke = 1.5, ZIndex = 4, Visible = false })
	local glow = new("Frame", { Name = "Glow", BackgroundColor3 = Theme.white, BackgroundTransparency = 0.82, Size = UDim2.fromScale(1, 1), ZIndex = 6, Visible = false }, oc)
	UIKit.corner(glow, 14)
	UIKit.stroke(glow, Theme.white, 5)

	UIKit.text(crate, { Name = "OnePer", Text = "ONE EMOTE PER OPENING", TextSize = 38, Size = UDim2.fromOffset(620, 42), Position = UDim2.fromOffset(0, 550), Align = LEFT, Scaled = true, Stroke = 2.5 })
	UIKit.text(crate, { Name = "Balance", Text = "Your balance: 0 gems  ·  Emotes you win join My Emotes", TextSize = 24, Size = UDim2.fromOffset(700, 28), Position = UDim2.fromOffset(0, 596), Align = LEFT, Scaled = true, Color = Theme.mutedText, Stroke = 1.5 })
	local open = UIKit.plate(crate, { Name = "Open", Ramp = "green", Solid = true, Text = "250", TextSize = 40, Size = UDim2.fromOffset(300, 86), Position = UDim2.new(1, 0, 0, 548), AnchorPoint = Vector2.new(1, 0), Button = true, Radius = 18 })
	UIKit.glyph(open.Face, "gem", { Name = "Gem", Size = 52, Position = UDim2.new(0, 34, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 4 })
	open.Face.Label.Position = UDim2.fromOffset(96, 0)
	open.Face.Label.Size = UDim2.new(1, -120, 1, -6)
	open.Face.Label.TextXAlignment = LEFT
	-- Robux openings (hidden until each has a developer product id)
	local robux = new("Frame", { Name = "Robux", BackgroundTransparency = 1, Size = UDim2.fromOffset(560, 70), Position = UDim2.new(1, -316, 0, 556), AnchorPoint = Vector2.new(1, 0), Visible = false }, crate)
	list(robux, 10, true, Enum.HorizontalAlignment.Right)
	for i, r in ipairs({ { "X1", "R$ 149" }, { "X3", "×3  R$ 499" }, { "X10", "×10  R$ 1399" } }) do
		UIKit.plate(robux, { Name = "Robux" .. r[1], Ramp = "blue", Solid = true, Text = r[2], TextSize = 26, Size = UDim2.fromOffset(176, 70), Button = true, Radius = 16, LayoutOrder = i })
	end
	UIKit.text(crate, { Name = "Footer", Text = "Duplicates refund Gems: Common +10  ·  Rare +20  ·  Epic +40  ·  Legendary +75.  Odds never change with ownership.", TextSize = 22, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -30), Color = Theme.mutedText, Scaled = true, Stroke = 1.5 })

	-- my emotes tab
	local mine = new("Frame", { Name = "Mine", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -80), Position = UDim2.fromOffset(0, 80), Visible = false }, eb)
	local mgrid = new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -44), ScrollBarThickness = 8, ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarImageColor3 = Theme.mutedText }, mine)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(244, 260), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }, mgrid)
	local mc = UIKit.card(mgrid, { Name = "MineCard", Size = UDim2.fromOffset(244, 260), Radius = 14, Transparency = 0.25, Studs = true, Outline = 3, Visible = false })
	mc.Edge.Transparency = 0
	local mv = new("ViewportFrame", { Name = "View", BackgroundColor3 = Color3.fromRGB(10, 12, 16), BackgroundTransparency = 0.5, Size = UDim2.new(1, -16, 0, 118), Position = UDim2.fromOffset(8, 8), Ambient = Color3.fromRGB(170, 170, 180), LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-1, -1, -1), ZIndex = 2 }, mc)
	UIKit.corner(mv, 10)
	UIKit.text(mc, { Name = "Rarity", Text = "COMMON", TextSize = 18, Size = UDim2.fromOffset(150, 22), Position = UDim2.fromOffset(14, 12), Align = LEFT, Scaled = true, Stroke = 1.5, ZIndex = 4 })
	UIKit.text(mc, { Name = "EmoteName", Text = "Snappy Skipping", TextSize = 28, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 130), Scaled = true, ZIndex = 3 })
	UIKit.glyph(mc, "note", { Name = "Note", Size = 20, Position = UDim2.fromOffset(14, 166), ZIndex = 3, Color = Theme.mutedText })
	UIKit.text(mc, { Name = "Song", Text = "Clap Your Hands And Smile", TextSize = 18, Size = UDim2.new(1, -52, 0, 22), Position = UDim2.fromOffset(40, 165), Align = LEFT, Scaled = true, Color = Theme.mutedText, Stroke = 1.5, ZIndex = 3 })
	UIKit.plate(mc, { Name = "Play", Ramp = "green", Solid = true, Text = "PLAY", TextSize = 28, Size = UDim2.fromOffset(200, 52), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), Button = true, Radius = 14, ZIndex = 3 })
	local mempty = new("Frame", { Name = "Empty", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -44), Visible = false }, mine)
	UIKit.glyph(mempty, "note", { Name = "Icon", Size = 120, Position = UDim2.new(0.5, 0, 0, 70), AnchorPoint = Vector2.new(0.5, 0), Color = Theme.mutedText })
	UIKit.text(mempty, { Name = "Text", Text = "NO EMOTES YET", TextSize = 50, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 220), Scaled = true })
	UIKit.text(mempty, { Name = "Sub", Text = "Open the Emote Crate to win dances with their own songs.", TextSize = 28, Size = UDim2.new(1, -200, 0, 40), Position = UDim2.new(0.5, 0, 0, 290), AnchorPoint = Vector2.new(0.5, 0), Scaled = true, Color = Theme.mutedText, Stroke = 1.5 })
	UIKit.plate(mempty, { Name = "Go", Ramp = "purple", Solid = true, Text = "EMOTE CRATE", TextSize = 32, Size = UDim2.fromOffset(320, 84), Position = UDim2.new(0.5, 0, 0, 370), AnchorPoint = Vector2.new(0.5, 0), Button = true, Radius = 16 })
	UIKit.text(mine, { Name = "Footer", Text = "Emotes play in the lobby  ·  move to stop  ·  players near you hear your song", TextSize = 22, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -30), Color = Theme.mutedText, Scaled = true, Stroke = 1.5 })

	-- crate reveal (overlay inside the panel)
	local ereveal = new("Frame", { Name = "Reveal", BackgroundColor3 = Theme.panel, BackgroundTransparency = 0.02, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 40, Active = true }, ep)
	UIKit.corner(ereveal, 24)
	new("ImageLabel", { Name = "Burst", BackgroundTransparency = 1, Image = Theme.img.sunburst, ImageColor3 = Theme.gold, ImageTransparency = 0.5, Size = UDim2.fromOffset(760, 760), Position = UDim2.fromScale(0.5, 0.4), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 41 }, ereveal)
	local rc = UIKit.card(ereveal, { Name = "Card", Size = UDim2.fromOffset(440, 440), Position = UDim2.fromScale(0.5, 0.37), AnchorPoint = Vector2.new(0.5, 0.5), Radius = 20, Transparency = 0.05, Studs = true, Outline = 5, ZIndex = 43 })
	rc.Edge.Transparency = 0
	local rv = new("ViewportFrame", { Name = "View", BackgroundColor3 = Color3.fromRGB(10, 12, 16), BackgroundTransparency = 0.4, Size = UDim2.new(1, -32, 0, 270), Position = UDim2.fromOffset(16, 16), Ambient = Color3.fromRGB(170, 170, 180), LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-1, -1, -1), ZIndex = 44 }, rc)
	UIKit.corner(rv, 14)
	UIKit.text(rc, { Name = "Rarity", Text = "LEGENDARY", TextSize = 30, Size = UDim2.new(1, -40, 0, 36), Position = UDim2.fromOffset(20, 294), Scaled = true, Stroke = 2, ZIndex = 44 })
	UIKit.text(rc, { Name = "EmoteName", Text = "E Dance Supreme", TextSize = 50, Size = UDim2.new(1, -40, 0, 56), Position = UDim2.fromOffset(20, 328), Scaled = true, ZIndex = 44, Stroke = 3 })
	UIKit.text(rc, { Name = "Song", Text = "Song: Accelerator", TextSize = 22, Size = UDim2.new(1, -40, 0, 30), Position = UDim2.new(0, 20, 1, -44), Scaled = true, Color = Theme.mutedText, Stroke = 1.5, ZIndex = 44 })
	UIKit.text(ereveal, { Name = "Title", Text = "NEW EMOTE!", TextSize = 64, Size = UDim2.new(1, -60, 0, 70), Position = UDim2.new(0.5, 0, 1, -230), AnchorPoint = Vector2.new(0.5, 0), Scaled = true, ZIndex = 45, Stroke = 3 })
	UIKit.text(ereveal, { Name = "Sub", Text = "ADDED TO MY EMOTES", TextSize = 32, Size = UDim2.new(1, -60, 0, 40), Position = UDim2.new(0.5, 0, 1, -158), AnchorPoint = Vector2.new(0.5, 0), Scaled = true, Color = Theme.goldText, ZIndex = 45, Stroke = 2 })
	UIKit.plate(ereveal, { Name = "PlayNow", Ramp = "purple", Solid = true, Text = "DANCE!", TextSize = 36, Size = UDim2.fromOffset(280, 86), Position = UDim2.new(0.5, -14, 1, -30), AnchorPoint = Vector2.new(1, 1), Button = true, Radius = 16, ZIndex = 45 })
	UIKit.plate(ereveal, { Name = "Done", Ramp = "green", Solid = true, Text = "NICE!", TextSize = 36, Size = UDim2.fromOffset(280, 86), Position = UDim2.new(0.5, 14, 1, -30), AnchorPoint = Vector2.new(0, 1), Button = true, Radius = 16, ZIndex = 45 })

	-- Stats
	local _, sb = panelGroup("Stats", Vector2.new(920, 760), "YOUR STATS", "blue")
	local sl = new("Frame", { Name = "List", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -10), Position = UDim2.fromOffset(0, 0) }, sb)
	list(sl, 6)
	local statRows = { { "Wins", "WINS" }, { "Matches", "MATCHES FINISHED" }, { "Crossings", "CROSSINGS" }, { "Captures", "CAPTURES" }, { "BestTier", "BEST EGG LEVEL" }, { "Pets", "PETS HATCHED" }, { "GoldEarned", "GOLD EARNED" }, { "FirstHunter", "TIMES FIRST CATCHER" } }
	for i, s in ipairs(statRows) do
		local r = UIKit.card(sl, { Name = s[1], Size = UDim2.new(1, 0, 0, 64), Radius = 12, LayoutOrder = i, Transparency = if i % 2 == 0 then 0.6 else 0.42 })
		UIKit.text(r, { Name = "Label", Text = s[2], TextSize = 28, Size = UDim2.new(0.66, -20, 1, 0), Position = UDim2.fromOffset(20, 0), Align = LEFT, Scaled = true, Stroke = 2 })
		UIKit.text(r, { Name = "Value", Text = "0", TextSize = 32, Size = UDim2.new(0.34, -20, 1, 0), Position = UDim2.new(0.66, 0, 0, 0), Align = RIGHT, Scaled = true, Color = Theme.goldText })
	end

	-- Settings
	local _, setb = panelGroup("Settings", Vector2.new(940, 620), "SETTINGS", "yellow")
	local stl = new("Frame", { Name = "List", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -80), Position = UDim2.fromOffset(0, 0) }, setb)
	list(stl, 14)
	toggleRow(stl, "Sfx", "SOUND EFFECTS", 1)
	toggleRow(stl, "ReduceEffects", "REDUCE EFFECTS (no camera zoom kick or shake)", 2)
	toggleRow(stl, "ShowHints", "SHOW CONTROL HINTS", 3)
	UIKit.text(setb, { Name = "Controls", Text = "RUN: WASD / stick   ·   DASH: Space / A   ·   TAG: click, E, R2   ·   PET ABILITY: Q / Y", TextSize = 22, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 1, -36), Color = Theme.mutedText, Scaled = true, Stroke = 1.5 })
	return gui
end

-- ======================= RESULTS =======================
local function buildResults(): ScreenGui
	local gui = screen("EOS_Results", 20, Enum.ScreenInsets.CoreUISafeInsets)
	local root = group(gui, "Root", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), Vector2.new(1640, 980), false)
	new("Frame", { Name = "Dim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.new(4, 0, 4, 0), Position = UDim2.fromScale(-1.5, -1.5), ZIndex = 0 }, root)
	new("ImageLabel", { Name = "Burst", BackgroundTransparency = 1, Image = Theme.img.sunburst, ImageColor3 = Theme.gold, ImageTransparency = 0.65, Size = UDim2.fromOffset(820, 820), Position = UDim2.new(0.5, 0, 0, 70), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 1 }, root)
	UIKit.text(root, { Name = "TeamBanner", Text = "RUNNERS WIN!", TextSize = 92, Size = UDim2.fromOffset(1000, 110), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), Color = Theme.ramps.blue.top, ZIndex = 3, Stroke = 4 })
	UIKit.text(root, { Name = "Reason", Text = "THE LAST RUNNER MADE IT ACROSS", TextSize = 30, Size = UDim2.fromOffset(1000, 40), Position = UDim2.new(0.5, 0, 0, 114), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3, Stroke = 2 })
	UIKit.text(root, { Name = "TestNote", Text = "PRACTICE MATCH: REWARDS SAVE WITH 4+ REAL PLAYERS", TextSize = 26, Size = UDim2.fromOffset(1000, 34), Position = UDim2.new(0.5, 0, 0, 156), AnchorPoint = Vector2.new(0.5, 0), Color = Theme.ramps.orange.top, Visible = false, ZIndex = 3, Stroke = 2 })

	-- podium: 2nd (left), 1st (centre, raised), 3rd (right)
	local podium = new("Frame", { Name = "Podium", BackgroundTransparency = 1, Size = UDim2.fromOffset(1100, 400), Position = UDim2.new(0.5, -170, 0, 200), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 2 }, root)
	local spots = { { 1, 0.5, 0, "gold", "1ST" }, { 2, 0.17, 40, "grey", "2ND" }, { 3, 0.83, 60, "orange", "3RD" } }
	for _, s in ipairs(spots) do
		local card = UIKit.card(podium, { Name = "Place" .. s[1], Size = UDim2.fromOffset(340, 360 - s[3]), Position = UDim2.new(s[2], 0, 1, 0), AnchorPoint = Vector2.new(0.5, 1), Radius = 18, Transparency = 0.15, ZIndex = 2, Studs = true })
		local av = new("ImageLabel", { Name = "Avatar", BackgroundColor3 = Color3.fromRGB(40, 52, 70), Size = UDim2.fromOffset(140, 140), Position = UDim2.new(0.5, 0, 0, 34), AnchorPoint = Vector2.new(0.5, 0), Image = "", ZIndex = 3 }, card)
		UIKit.corner(av, UDim.new(0.5, 0))
		UIKit.stroke(av, Theme.edge, 3).Transparency = 0.5
		UIKit.text(card, { Name = "PlayerName", Text = "Player", TextSize = 34, Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 184), Scaled = true, ZIndex = 3 })
		UIKit.text(card, { Name = "Detail", Text = "SURVIVED  ·  LEVEL 4", TextSize = 24, Size = UDim2.new(1, -24, 0, 32), Position = UDim2.fromOffset(12, 230), Scaled = true, ZIndex = 3, Color = Theme.gold, Stroke = 2 })
		UIKit.plate(card, { Name = "PlaceTag", Ramp = s[4], Solid = true, Text = s[5], TextSize = 34, Size = UDim2.fromOffset(130, 58), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0.6), Radius = 29, ZIndex = 4 })
	end
	-- top thief
	local thief = UIKit.card(root, { Name = "Thief", Size = UDim2.fromOffset(380, 290), Position = UDim2.new(1, -10, 0, 290), AnchorPoint = Vector2.new(1, 0), Radius = 18, Transparency = 0.15, ZIndex = 2, Studs = true })
	UIKit.plate(thief, { Name = "Tag", Ramp = "red", Solid = true, Text = "TOP THIEF", TextSize = 30, Size = UDim2.fromOffset(220, 58), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0.6), Radius = 29, ZIndex = 4 })
	local tav = new("ImageLabel", { Name = "Avatar", BackgroundColor3 = Color3.fromRGB(60, 40, 48), Size = UDim2.fromOffset(110, 110), Position = UDim2.new(0.5, 0, 0, 44), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 }, thief)
	UIKit.corner(tav, UDim.new(0.5, 0))
	UIKit.stroke(tav, Theme.edge, 3).Transparency = 0.5
	UIKit.text(thief, { Name = "PlayerName", Text = "Player", TextSize = 32, Size = UDim2.new(1, -24, 0, 42), Position = UDim2.fromOffset(12, 166), Scaled = true, ZIndex = 3 })
	UIKit.text(thief, { Name = "Detail", Text = "3 CAPTURES  ·  STOLE LEVEL 3", TextSize = 24, Size = UDim2.new(1, -24, 0, 32), Position = UDim2.fromOffset(12, 212), Scaled = true, ZIndex = 3, Color = Theme.ramps.red.top, Stroke = 2 })

	-- your match breakdown (GDD 14): piece + recipe progress | Gold lines | Gems
	local you = UIKit.card(root, { Name = "You", Size = UDim2.fromOffset(1300, 250), Position = UDim2.new(0.5, 0, 0, 620), AnchorPoint = Vector2.new(0.5, 0), Radius = 18, Transparency = 0.1, ZIndex = 2, Studs = true })
	UIKit.eggIcon(you, { Name = "Egg", Width = 96, Height = 120, Position = UDim2.fromOffset(34, 30), Tier = 3, ZIndex = 3 })
	UIKit.text(you, { Name = "Headline", Text = "EPIC PIECE!", TextSize = 46, Size = UDim2.fromOffset(500, 56), Position = UDim2.fromOffset(150, 22), Align = LEFT, Scaled = true, ZIndex = 3 })
	UIKit.text(you, { Name = "Source", Text = "SURVIVED 5 CROSSINGS TO THE END", TextSize = 26, Size = UDim2.fromOffset(500, 34), Position = UDim2.fromOffset(150, 80), Align = LEFT, Scaled = true, ZIndex = 3, Color = Theme.mutedText, Stroke = 2 })
	UIKit.bar(you, { Name = "Recipe", Ramp = "purple", Text = "EPIC 1 / 5  ·  NEXT HATCH", TextSize = 22, Size = UDim2.fromOffset(500, 40), Position = UDim2.fromOffset(150, 124), Value = 0.2 })
	UIKit.text(you, { Name = "NearMiss", Text = "ONE MORE ESCAPE WOULD REACH LEVEL 4", TextSize = 24, Size = UDim2.fromOffset(620, 32), Position = UDim2.fromOffset(34, 184), Align = LEFT, Scaled = true, ZIndex = 3, Color = Theme.ramps.orange.top, Stroke = 2 })
	local goldBox = new("Frame", { Name = "Gold", BackgroundTransparency = 1, Size = UDim2.fromOffset(330, 210), Position = UDim2.fromOffset(700, 20), ZIndex = 3 }, you)
	UIKit.glyph(goldBox, "coin", { Name = "Icon", Size = 56, Position = UDim2.fromOffset(0, 0), ZIndex = 3 })
	UIKit.text(goldBox, { Name = "Total", Text = "+76", TextSize = 50, Size = UDim2.fromOffset(250, 58), Position = UDim2.fromOffset(68, 0), Align = LEFT, Color = Theme.goldText, ZIndex = 3 })
	UIKit.text(goldBox, { Name = "Lines", Text = "PLAYED +25\nCROSSINGS +36\nVICTORY +15", TextSize = 22, Size = UDim2.fromOffset(320, 130), Position = UDim2.fromOffset(4, 68), Align = LEFT, YAlign = Enum.TextYAlignment.Top, ZIndex = 3, Color = Theme.mutedText, Stroke = 1.5 })
	local gemBox = new("Frame", { Name = "Gems", BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 120), Position = UDim2.fromOffset(1050, 20), ZIndex = 3 }, you)
	UIKit.glyph(gemBox, "gem", { Name = "Icon", Size = 56, Position = UDim2.fromOffset(0, 0), ZIndex = 3 })
	UIKit.text(gemBox, { Name = "Total", Text = "+4", TextSize = 50, Size = UDim2.fromOffset(150, 58), Position = UDim2.fromOffset(68, 0), Align = LEFT, Color = Theme.gemText, ZIndex = 3 })
	UIKit.text(gemBox, { Name = "Label", Text = "GEMS", TextSize = 22, Size = UDim2.fromOffset(200, 30), Position = UDim2.fromOffset(4, 66), Align = LEFT, ZIndex = 3, Color = Theme.mutedText, Stroke = 1.5 })

	UIKit.text(root, { Name = "NextMatch", Text = "NEXT MATCH IN 0:22", TextSize = 38, Size = UDim2.fromOffset(700, 50), Position = UDim2.new(0.5, 0, 1, -30), AnchorPoint = Vector2.new(0.5, 1), Color = Theme.gold, ZIndex = 3, Stroke = 2.5 })
	UIKit.plate(root, { Name = "Continue", Ramp = "green", Solid = true, Text = "CONTINUE", TextSize = 36, Size = UDim2.fromOffset(270, 90), Position = UDim2.new(1, -20, 1, -10), AnchorPoint = Vector2.new(1, 1), Button = true, Radius = 18, ZIndex = 4 })
	return gui
end

-- ======================= OVERLAY (toasts over everything, menus included) =======================
local function buildOverlay(): ScreenGui
	local gui = screen("EOS_Overlay", 30, Enum.ScreenInsets.CoreUISafeInsets)
	local toasts = group(gui, "Toasts", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 200), Vector2.new(800, 320))
	list(toasts, 10)
	return gui
end

local UIBuilder = {}

function UIBuilder.preview(scale: number)
	for _, gui in ipairs(StarterGui:GetChildren()) do
		if gui:IsA("ScreenGui") and string.sub(gui.Name, 1, 4) == "EOS_" then
			for _, d in ipairs(gui:GetDescendants()) do
				if d:IsA("UIScale") and d.Name == "Fit" then
					d.Scale = scale
				end
			end
		end
	end
end

setmetatable(UIBuilder, {
	__call = function()
		local hud = buildHUD()
		local menus = buildMenus()
		local results = buildResults()
		local overlay = buildOverlay()
		hud.Parent = StarterGui
		menus.Parent = StarterGui
		results.Parent = StarterGui
		overlay.Parent = StarterGui
		local n = #hud:GetDescendants() + #menus:GetDescendants() + #results:GetDescendants() + #overlay:GetDescendants()
		return "UI built: " .. n .. " instances (EOS_HUD, EOS_Menus, EOS_Results, EOS_Overlay)"
	end,
})

return UIBuilder
