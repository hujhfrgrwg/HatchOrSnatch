--!nocheck
-- UIController (HOS-UI-IMPORT-001, Oct 2026): drives the new EOSUI ScreenGui (round-3 "sport" UI, built from
-- the approved HTML by roblox-ui-maker: ui/build.py -> export -> roblox/ui/Data_* -> Builder).
-- Same public API as the old controller (toast, feed, banner, open, close, openName, isOpen, refreshPanels,
-- juicy, onEmotesRefresh) so ClientMain, EmoteController and the gameplay hooks keep working.
-- Source of truth: roblox/game/UIController.luau in the repo. Wiring facts: Dev/UI Wiring Map.md.
-- Runtime edits to imported screens are listed in Dev/UI Runtime Changes.md.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")

local EOS = ReplicatedStorage:WaitForChild("EOS")
local Shared = EOS:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local MarketplaceService = game:GetService("MarketplaceService")
local TierConfig = require(Shared:WaitForChild("TierConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local AbilityConfig = require(Shared:WaitForChild("AbilityConfig"))
local AbilityCosmetics = require(Shared:WaitForChild("AbilityCosmetics"))
local Layout = require(Shared:WaitForChild("Layout"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local Sound = require(script.Parent.Sound)
local CameraFX = require(script.Parent.CameraFX)
local WorldFX = require(script.Parent.WorldFX)
local Tag = require(script.Parent.Tag)
local Movement = require(script.Parent.Movement)
local NpcSkins = require(script.Parent.NpcSkins)
local Pets = require(script.Parent.Pets)

local UIC = {}
UIC.onEmotesRefresh = nil :: ((any, boolean) -> ())?
UIC.onOpen = {} :: { [string]: () -> () } -- screens owned by other controllers refresh themselves when opened
UIC.spectating = function(): boolean return false end -- SpectateController fills these two in
UIC.startSpectate = function() end

local player = Players.LocalPlayer
local state = Net.state()

local gui: ScreenGui
local UI -- the gui's runtime module (screens, juicy buttons, count-ups, motion helpers)
local assets -- AssetIds (icons by slug, art by key)
local root: Frame
local S = {} -- screens by name
local overlay: Frame -- toasts, banners, confirm (above every screen)
local templates: Folder

local profile: any = nil
local settings = { sfx = true, music = true, reduceEffects = false, showHints = true, uiColour = "" }
local settingsInit = false
local shopTab = "featured"
local resultsData: any = nil
local resultsOpen = false
local shownLevel: number? = nil -- the account level last shown (a rise opens LEVEL UP!)
local trackedQuest: string? = nil
local joinedAt = os.clock()

----------------------------------------------------------------------------------------------- data
-- HOS-PET-001: Scout and Brake are gone (their incubator tiles are hidden at init). Per-role text for
-- the five ability archetypes comes from AbilityConfig where it has the family.
local ORDER = { "DoubleDash", "Decoy", "Invisibility", "Wall", "Shield", "Spring", "PetTackle" }
local REMOVED_FAMILIES = { "Scout", "Brake" }
local FAMILY = { -- the design's families (HOS-ABIL-001); EconomyConfig / AbilityConfig win where the game has the family
	DoubleDash = { title = "Double Dash", icon = "ab_dash", blurb = "Two quick dashes in a row", run = "escape burst", catch = "close the gap", wave = 1 },
	Decoy = { title = "Decoy", icon = "ab_decoy", blurb = "A running copy of you", run = "fake out chasers", catch = "fake out runners", wave = 1 },
	Invisibility = { title = "Invisibility", icon = "ab_invis", blurb = "Fade out for a few seconds", run = "slip past", catch = "sneak up", wave = 2 },
	Wall = { title = "Wall", icon = "ab_wall", blurb = "Drop a wall in a lane", run = "block the chaser", catch = "block the escape lane", wave = 2 },
	Shield = { title = "Shield", icon = "ab_shield", blurb = "A bubble that blocks one hit", run = "blocks one tag", catch = "to be decided", wave = 3 },
	Spring = { title = "Spring", icon = "ab_spring", blurb = "Leap forward", run = "leap ahead", catch = "leap onto a Runner", wave = 3 },
	PetTackle = { title = "Pet Tackle", icon = "ab_tackle", blurb = "Your pet bowls someone over", run = "knock a Catcher over", catch = "to be decided", wave = 3 },
	-- HOS-PET-002: the new archetypes' icons (no incubator tiles yet; the ability card and touch button use them)
	Guardian = { title = "Guardian", icon = "ab_shield", blurb = "Block one tag", wave = 3 },
	Tempest = { title = "Tempest", icon = "ab_tempest", blurb = "A storm that pushes back", wave = 3 },
	Rift = { title = "Rift", icon = "ab_rift", blurb = "Hop through a portal", wave = 3 },
}
-- showroom pets (Workspace.FWP_PetShowroom / FWPPetData.Pools) that skin each family, common -> epic
local PET_ART = {
	DoubleDash = { "shades_shark", "surfer_dog", "thunder_wolf" },
	Decoy = { "gamer_axolotl", "crow", "kitsune" }, -- rare Crow, epic Kitsune (the game's own pets)
	Invisibility = { "prism_chameleon", "prism_chameleon", "mirage_manta" }, -- epic Mirage Manta
	Wall = { "sand_crab", "robo_crab", "armored_rex" },
	Shield = { "pebble_frog", "puffer_pup", "hermit_knight" },
	PetTackle = { "viking_walrus", "cozy_lion", "narwhal_calf" },
}
local RARITIES = { "common", "rare", "epic" }
local RARITY_NAME = { common = "Common", rare = "Rare", epic = "Epic", crowned = "Crowned" }
local RARITY_COLOR = {
	common = Color3.fromRGB(142, 240, 122), rare = Color3.fromRGB(92, 200, 255),
	epic = Color3.fromRGB(200, 138, 255), crowned = Color3.fromRGB(255, 210, 58),
}
local ACCENT_TINT = { -- UI Colour setting -> tint for the greyscale banner/glow copies
	purple = Color3.fromRGB(160, 100, 255), pink = Color3.fromRGB(240, 100, 190), sky = Color3.fromRGB(70, 170, 255),
	lime = Color3.fromRGB(120, 220, 50), gold = Color3.fromRGB(255, 185, 45), coral = Color3.fromRGB(255, 85, 85),
	steel = Color3.fromRGB(160, 175, 200),
}
local SWATCH_KEY = { Default = "", Purple = "purple", Pink = "pink", Blue = "sky", Green = "lime", Gold = "gold", Red = "coral", Steel = "steel" }
local PANELS = { "Quests", "Incubator", "Pets", "Shop", "Stats", "Settings" }
local PURCHASES = (GameConfig.Features and GameConfig.Features.SHOP_PURCHASES) == true -- Robux Gem packs live
local LOBBY_ONLY = { Incubator = true, Shop = true, Pets = true, Emotes = true, EmoteWheel = true }
local SHOP_ICON = {
	trail_spark = "trail", trail_ember = "trail_ember", burst_confetti = "burst", case_frost = "case_frost",
	entrance_bolt = "entrance", case_sunset = "case_sunset", trailp_rainbow = "trail_rainbow", fx_gold = "abilityfx_gold",
	hatch_royal = "hatchfx", hwn_wraith = "rbxassetid://96536209861678", hwn_cat = "rbxassetid://107962292207270", hwn_mummy = "rbxassetid://90853167732351", hwn_dragon = "rbxassetid://89039949824796", -- HOS-HWN-001
	fx_rift_void = "ab_blink", fx_rift_inferno = "ab_blink", fx_rift_frost = "ab_blink", -- HOS-VFX-RES-001
}
local KIND_WORDS = { trail = "One match", burst = "Lobby, once", case = "Keep forever", entrance = "Keep forever", trailPerm = "Keep forever", abilityFx = "Keep forever", hatchFx = "Keep forever", abilitySkin = "Keep forever" }
local QUEST_TEXT = {
	cross1 = { "Make it across to the safe zone as a Runner.", "Each crossing that ends safe counts." },
	cross3 = { "Make it across to the safe zone as a Runner.", "Each crossing that ends safe counts." },
	capture1 = { "Tag a Runner while you're a Catcher.", "Each tag that lands counts." },
	capture3 = { "Tag Runners while you're a Catcher.", "Each tag that lands counts." },
	match1 = { "Play a match to the end.", "Stay in until the results show." },
	match3 = { "Play matches to the end.", "Stay in until the results show." },
	tier2 = { "Grow your egg to Level 2 in one match.", "Cross safely to level your egg up." },
	tier3 = { "Grow your egg to Level 3 in one match.", "Cross safely to level your egg up." },
}
local REASONS = {
	LAST_ONE_STANDING = "The last Runner made it across alone",
	CLEAN_STREAK = "Nobody was caught 3 crossings in a row",
	SAFETY_CAP = "The match ran long",
	FINAL_WAVE = "Runners survived every crossing",
	ALL_RUNNERS_GONE = "Every Runner was caught",
}

----------------------------------------------------------------------------------------------- helpers
local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function deviceClass(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "touch"
	end
	if GuiService:IsTenFootInterface() then
		return "console"
	end
	local last = UserInputService:GetLastInputType()
	if last.Name:find("Gamepad") then
		return "gamepad"
	end
	return "pc"
end

local function find(scope: Instance?, name: string): Instance?
	return scope and scope:FindFirstChild(name, true)
end

local function npcName(slot: number?, fallback: string?): string
	return NpcSkins.nameForSlot(slot) or fallback or "?"
end

local function setText(scope: Instance?, name: string, text: string)
	if scope then
		UI.setText(scope, name, text)
	end
end

local function strip(s: string): string
	return (s:gsub("<[^>]->", ""))
end

-- RichText on the label, plain text on its drop-shadow twin (a coloured shadow would show through)
local function setRich(scope: Instance?, name: string, rich: string)
	if not scope then return end
	UI.setText(scope, name, strip(rich))
	for _, d in scope:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == name then
			d.RichText = true
			d.Text = rich
		end
	end
end

local function hex(c: Color3): string
	return c:ToHex()
end
local function font(c: Color3, s: string): string
	return ('<font color="#%s">%s</font>'):format(hex(c), s)
end

local function setColor(scope: Instance?, name: string, c: Color3)
	if not scope then return end
	for _, d in scope:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == name then
			d.TextColor3 = c
			local g = d:FindFirstChildOfClass("UIGradient")
			if g then g.Enabled = false end
		end
	end
end

local function iconId(slug: string?): string
	if not slug then return "" end
	return assets.icons[slug] or ""
end

-- set an exported icon (and its "<name>Shadow" twin) to another slug, or to any image url
-- shrink-to-fit for labels whose text varies (names, long toasts): never cut off, never bigger than designed
local function fitText(scope: Instance?, name: string)
	if not scope then return end
	for _, d in scope:GetDescendants() do
		if d:IsA("TextLabel") and (d.Name == name or d.Name == name .. "Shadow") then
			if not d:FindFirstChild("FitMax") then
				local c = Instance.new("UITextSizeConstraint")
				c.Name = "FitMax"
				c.MaxTextSize = math.max(8, math.floor(d.TextSize))
				c.MinTextSize = 8
				c.Parent = d
			end
			d.TextScaled = true
		end
	end
end

local function setIcon(scope: Instance?, name: string, slugOrUrl: string)
	if not scope then return end
	local img = if string.find(slugOrUrl, "://") then slugOrUrl else iconId(slugOrUrl)
	for _, d in scope:GetDescendants() do
		if d:IsA("ImageLabel") and (d.Name == name or d.Name == name .. "Shadow") then
			d.Image = img
		end
	end
end

-- show/hide an element together with the drop-shadow / ring frames the exporter put beside it
local function show(g: Instance?, on: boolean)
	if not g or not g:IsA("GuiObject") then return end
	g.Visible = on
	local p = g.Parent
	if not p then return end
	for _, s in p:GetChildren() do
		if s ~= g and s:IsA("GuiObject") and (s.Name == "DropShadow" or s.Name == "ShadowRing" or s.Name == "Outline") then
			local dx = math.abs(s.Position.X.Offset - g.Position.X.Offset)
			local dy = math.abs(s.Position.Y.Offset - g.Position.Y.Offset)
			if dx <= 6 and dy <= 8 and math.abs(s.Size.X.Offset - g.Size.X.Offset) <= 10 then
				s.Visible = on
			end
		end
	end
end

-- progress bar exported as <Bar> with a fill child F (CSS width %): set the fill fraction
local function setBar(bar: Instance?, frac: number)
	if not bar then return end
	local f = bar:FindFirstChild("F")
	if not f or not f:IsA("GuiObject") then return end
	local inset = f.Position.X.Offset
	local full = bar.Size.X.Offset - inset * 2
	frac = math.clamp(frac, 0, 1)
	f.Size = UDim2.new(0, math.max(0, full * frac), f.Size.Y.Scale, f.Size.Y.Offset)
	f.Visible = frac > 0.001
end

-- a dual-state export (<name>.On / <name>.Off): show one
local function setDual(d: Instance?, on: boolean)
	if not d then return end
	local a, b = d:FindFirstChild("On"), d:FindFirstChild("Off")
	if a then a.Visible = on end
	if b then b.Visible = not on end
end

-- plain buttons inside dual exports: wire both halves (the top-most button gets the click)
local function onClick(b: Instance?, fn: () -> ())
	if not b then return end
	if b:IsA("GuiButton") then
		b.Activated:Connect(fn)
	end
	for _, c in b:GetChildren() do
		if c:IsA("GuiButton") and (c.Name == "On" or c.Name == "Off") then
			c.Activated:Connect(fn)
		end
	end
end

-- a transparent hit area over a card that is a plain Frame in the export (selection clicks)
local function hitArea(card: GuiObject, fn: () -> ())
	local hit = card:FindFirstChild("Hit") :: TextButton?
	if not hit then
		local b = Instance.new("TextButton")
		b.Name = "Hit"
		b.BackgroundTransparency = 1
		b.Text = ""
		b.Size = UDim2.fromScale(1, 1)
		b.ZIndex = 1
		b.AutoButtonColor = false
		b.Parent = card
		hit = b
	end
	hit.Activated:Connect(fn)
end

-- design-space top-left of target inside ancestor (sums offsets; juicy buttons are centre-anchored)
local function relPos(target: Instance, ancestor: Instance): (number, number)
	local x, y = 0, 0
	local g: Instance? = target
	while g and g ~= ancestor do
		if g:IsA("GuiObject") then
			x += g.Position.X.Offset - g.AnchorPoint.X * g.Size.X.Offset
			y += g.Position.Y.Offset - g.AnchorPoint.Y * g.Size.Y.Offset
		end
		g = g.Parent
	end
	return x, y
end

-- slide a selection ring onto a tile (ring and tile can sit at different depths of the same container)
local function moveRing(ring: Instance?, target: Instance?, pad: number?)
	if not ring or not ring:IsA("GuiObject") then return end
	if not target or not target:IsA("GuiObject") or not ring.Parent then
		ring.Visible = false
		return
	end
	local p = pad or 4
	local x, y = relPos(target, ring.Parent)
	local goal = UDim2.fromOffset(x - p, y - p)
	ring.Size = UDim2.fromOffset(target.Size.X.Offset + p * 2, target.Size.Y.Offset + p * 2)
	ring.AnchorPoint = Vector2.zero
	if not ring.Visible then
		ring.Position = goal
		ring.Visible = true
	else
		TweenService:Create(ring, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = goal }):Play()
	end
end

local function launchFamilies(): { string }
	return EconomyConfig.LAUNCH_FAMILIES or { "Decoy" }
end
local function isLive(f: string): boolean
	return table.find(launchFamilies(), f) ~= nil
end
local function familyTitle(f: string): string
	return (FAMILY[f] and FAMILY[f].title) or f
end
local function familyAbility(f: string, r: string?): string
	local rd = r and AbilityConfig.forRole(f, r) -- in a match: the ability for your role (HOS-PET-001)
	if rd then
		return rd.name
	end
	local ef = EconomyConfig.FAMILIES[f]
	return (ef and ef.ability) or string.upper(familyTitle(f))
end
local function familyShort(f: string): string
	local ef = EconomyConfig.FAMILIES[f]
	return (ef and ef.short) or (FAMILY[f] and FAMILY[f].blurb) or ""
end
local function familyIcon(f: string?, r: string?): string
	-- HOS-PET-003: in a match, the icon for your role (AbilityConfig); a role icon that isn't uploaded yet
	-- falls back to the archetype's Runner icon, then to the design's family icon
	local rd = f and r and AbilityConfig.forRole(f, r)
	if rd and rd.icon and iconId(rd.icon) ~= "" then
		return rd.icon
	end
	local run = f and AbilityConfig.forRole(f, "Runner")
	if run and run.icon and iconId(run.icon) ~= "" then
		return run.icon
	end
	return (f and FAMILY[f] and FAMILY[f].icon) or "pets"
end

local function titleCase(slug: string): string
	return (slug:gsub("_", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end
-- (icon slug, display name) for a pet: the showroom pet that skins this family/rarity; the game's
-- species name when the family has no showroom pet yet
local function petArt(family: string?, rarity: string?, variant: number?): (string, string)
	local list = family and PET_ART[family]
	local idx = table.find(RARITIES, rarity or "common") or 1
	-- a roster pet hatched for this family/rarity goes by its roster name (HOS-PET-012); art unchanged
	local rosterName = family and EconomyConfig.DISPLAY_NAMES[EconomyConfig.speciesFor(family, rarity or "common")]
	if list then
		local slug = list[math.min(idx, #list)]
		local v = variant or (if idx > #list then idx else 1)
		return ("pet_%s_t%d"):format(slug, math.clamp(v, 1, 3)), rosterName or titleCase(slug)
	end
	local species = family and EconomyConfig.speciesFor(family, rarity or "common") or "Pet"
	return familyIcon(family), EconomyConfig.displayName(species)
end

local function eggSlug(level: number): string
	return if level >= 4 then "egg_golden" elseif level == 3 then "egg_cosmic" elseif level == 2 then "egg_shiny" else "egg_basic"
end

local function materialName(m: string): string
	local i = EconomyConfig.MATERIAL_INFO[m]
	return (i and i.name) or RARITY_NAME[m] or m
end

local function have(m: string): number
	return (profile and profile.materials and profile.materials[m]) or 0
end
-- pieces usable for a tier-m recipe: m and every tier above it (the server asks before using higher ones)
local function haveFor(m: string): number
	local i = EconomyConfig.materialIndex(m) or 1
	local n = 0
	for j = i, #EconomyConfig.MATERIALS do
		n += have(EconomyConfig.MATERIALS[j])
	end
	return n
end
local function costFor(m: string, focused: boolean): number
	local r = EconomyConfig.RECIPES[m]
	if not r then return 99 end
	if profile and profile.firstCommonFree and m == "common" then
		return r.base
	end
	return if focused then r.focus else r.base
end
local function hatchReady(): boolean
	if not profile then return false end
	for _, m in ipairs(EconomyConfig.MATERIALS) do
		if haveFor(m) >= costFor(m, false) then
			return true
		end
	end
	return false
end

local function inMatch(): boolean
	return player:GetAttribute("EOS_InMatch") == true
end
local function role(): string
	return player:GetAttribute("EOS_Role") or "LOBBY"
end

----------------------------------------------------------------------------------------------- overlay: toasts, banners, confirm
local toasts: { Frame } = {}
local function template(name: string): Instance?
	local t = templates and templates:FindFirstChild(name)
	if not t then
		warn("[EOSUI] missing template " .. name)
	end
	return t
end
-- the visible card of a template group (the group frame itself is a full-canvas holder)
local function cloneCard(name: string, child: string): GuiObject?
	local t = template(name)
	local c = t and t:FindFirstChild(child, true)
	if not c then return nil end
	local k = c:Clone()
	k.Visible = true
	return k
end

local function layoutToasts()
	local inm = inMatch()
	-- a panel's close button sits top right: with a panel open, toasts stack top centre instead
	local panel = UI and UI.current() ~= nil
	for i, t in ipairs(toasts) do
		-- lobby: under the top-right goal box (y 86-160) since it moved there (16 Oct)
		local y = if inm then 176 + (i - 1) * 96 elseif panel then 18 + (i - 1) * 96 else 178 + (i - 1) * 96
		local x = if inm or panel then root.Size.X.Offset / 2 - 325 else root.Size.X.Offset - 670
		TweenService:Create(t, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(x, y) }):Play()
		t:SetAttribute("RestPos", UDim2.fromOffset(x, y))
	end
end

local function toastKind(text: string, kind: string?): (string, string)
	local low = string.lower(text)
	local icon = "info"
	if low:find("gold") then icon = "gold" elseif low:find("gem") then icon = "gem" elseif low:find("piece") then icon = "piece_rare" end
	if kind == "bad" or kind == "warn" or low:find("not enough") or low:find("can't") or low:find("need ") then
		return "Toast_error", (if icon == "info" then "info" else icon)
	end
	if kind == "reward" or low:find("claimed") then
		return "Toast_reward", (if icon == "info" then "gift" else icon)
	end
	if low:find("added") or low:find("unlocked") or low:find("bought") then
		return "Toast_good", "check"
	end
	return "Toast_info", "info"
end

function UIC.toast(text: string, kind: string?, force: boolean?)
	if not text or text == "" then return end
	if inMatch() and not force then
		return -- minimal match HUD: only forced toasts
	end
	-- merge repeats: restart the existing one
	for _, t in ipairs(toasts) do
		if t:GetAttribute("Msg") == text then
			t:SetAttribute("Born", os.clock())
			UI.pulse(t, 0.08)
			return
		end
	end
	local tname, icon = toastKind(text, kind)
	local card = cloneCard(tname, "Toast")
	if not card then return end
	card:SetAttribute("Msg", text)
	card:SetAttribute("Born", os.clock())
	setText(card, "Msg", text)
	fitText(card, "Msg")
	setIcon(card, "Icon", icon)
	card.ZIndex = 5
	card.Parent = overlay
	table.insert(toasts, 1, card)
	while #toasts > 3 do
		local old = table.remove(toasts)
		if old then old:Destroy() end
	end
	layoutToasts()
	UI.slideIn(card, 120, 0, 0, 0.35)
	if kind == "reward" then
		Sound.play("reward", 1.05)
	elseif tname == "Toast_error" then
		Sound.play("error")
	else
		Sound.play("pop")
	end
	local life = if #text > 50 then 6 else 3.5
	local bar = find(card, "Time")
	task.spawn(function()
		while card.Parent do
			local born = card:GetAttribute("Born") or os.clock()
			local left = life - (os.clock() - born)
			setBar(bar, left / life)
			if left <= 0 then break end
			task.wait(0.05)
		end
		if card.Parent then
			local i = table.find(toasts, card)
			if i then table.remove(toasts, i) end
			local at = card.Position
			local t = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = at + UDim2.fromOffset(160, 0) })
			t.Completed:Once(function() card:Destroy() end)
			t:Play()
			layoutToasts()
		end
	end)
end

-- match feed (HOS-FEED-001): each line is a clone of the hidden Feed1 row. It eases in from the right while
-- fading up, holds, then eases out; the stack glides to its new slots whenever a line arrives or leaves.
do -- (one block: keeps UIController under Luau's 200 top-level locals; only UIC.feed uses these)
local FEED_HOLD, FEED_MAX = 8, 3
local FEED_MOVE = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local FEED_OUT = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FADE_PROPS = { Frame = "BackgroundTransparency", ImageLabel = "ImageTransparency", TextLabel = "TextTransparency", UIStroke = "Transparency" }
local feedRows: { GuiObject } = {} -- newest first
local feedStep = 50

-- a = 0 puts every part of the row back at its own look, a = 1 makes it fully clear
local function fadeRow(row: Instance, a: number, info: TweenInfo?)
	for _, d in row:GetDescendants() do
		local p = FADE_PROPS[d.ClassName]
		if p then
			local base = d:GetAttribute("FadeBase")
			if base == nil then
				base = d[p]
				d:SetAttribute("FadeBase", base)
			end
			local v = base + (1 - base) * a
			if info then TweenService:Create(d, info, { [p] = v }):Play() else d[p] = v end
		end
	end
end

local function feedReflow()
	for i, row in feedRows do
		TweenService:Create(row, FEED_MOVE, { Position = UDim2.fromOffset(0, (i - 1) * feedStep) }):Play()
	end
end

-- overflow lines sink below the stack as they fade; expired lines slide off to the right
local function feedDrop(row: GuiObject, overflow: boolean?)
	local i = table.find(feedRows, row)
	if not i then return end
	table.remove(feedRows, i)
	fadeRow(row, 1, FEED_OUT)
	local goal = if overflow then UDim2.fromOffset(0, FEED_MAX * feedStep) else row.Position + UDim2.fromOffset(60, 0)
	local t = TweenService:Create(row, FEED_OUT, { Position = goal })
	t.Completed:Once(function() row:Destroy() end)
	t:Play()
	feedReflow()
end

function UIC.feed(rich: string, icon: string?)
	local feed = S.MatchHUD and S.MatchHUD:FindFirstChild("Feed")
	local template = feed and feed:FindFirstChild("Feed1")
	if not template then return end
	local f2 = feed:FindFirstChild("Feed2")
	if f2 then feedStep = f2.Position.Y.Offset - template.Position.Y.Offset end
	local row = template:Clone()
	row.Name = "FeedLine"
	setRich(row, "FeedText", rich)
	for _, d in row:GetDescendants() do if d:IsA("TextLabel") and (d.Name == "FeedText" or d.Name == "FeedTextShadow") then d.TextWrapped = false d.TextScaled = true d.Size -= UDim2.fromOffset(14, 0) local c = d:FindFirstChild("UIFitCap") if c then c.MinTextSize = math.min(10, c.MaxTextSize) end end end -- HOS-PTS-001: one line, shrinks to fit ("stole Mia's Legendary egg")
	setIcon(row, "FeedIcon", icon or "steal")
	fadeRow(row, 1)
	row.Position = UDim2.fromOffset(80, 0)
	row.Visible = true
	row.Parent = feed
	table.insert(feedRows, 1, row)
	while #feedRows > FEED_MAX do feedDrop(feedRows[#feedRows], true) end
	feedReflow()
	fadeRow(row, 0, FEED_MOVE)
	task.delay(FEED_HOLD, feedDrop, row)
end
end -- feed block

local bannerQueue: { () -> () } = {}
local bannerBusy = false
local function nextBanner()
	local fn = table.remove(bannerQueue, 1)
	if fn then
		bannerBusy = true
		task.spawn(fn)
	else
		bannerBusy = false
	end
end
-- kind: Runner | Catcher | Safe | Caught | Stole | Last | Slow
function UIC.banner(kind: string, title: string?, sub: string?, icon: string?, hold: number?)
	if resultsOpen then return end
	local run = function()
		local card = cloneCard("Banner_" .. kind, "Banner")
		if not card then
			nextBanner()
			return
		end
		if title then setText(card, "Title", title) fitText(card, "Title") end
		if sub then setText(card, "Sub", sub) fitText(card, "Sub") else
			local s = find(card, "Sub")
			if s then setText(card, "Sub", "") end
		end
		if icon then setIcon(card, "Icon", icon) end
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.new(0, root.Size.X.Offset / 2, 0, 300)
		card.ZIndex = 6
		card.Parent = overlay
		UI.setRest(card)
		UI.popFrom(card, 0.2)
		card.Rotation = -4
		TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		task.wait(hold or 1.6)
		local t = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = card.Position - UDim2.fromOffset(0, 70) })
		local sc = card:FindFirstChildOfClass("UIScale")
		if sc then TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play() end
		t:Play()
		t.Completed:Wait()
		card:Destroy()
		nextBanner()
	end
	-- drop stale ones: keep at most 2 waiting
	while #bannerQueue >= 2 do table.remove(bannerQueue, 1) end
	table.insert(bannerQueue, run)
	if not bannerBusy then nextBanner() end
end

-- the one confirm dialog (Confirm template): title, two body lines, yes/no labels
function UIC.confirm(o: { title: string?, body1: string, body2: string?, yes: string?, no: string? }, onYes: () -> (), onNo: (() -> ())?)
	local card = cloneCard("Confirm", "Card")
	if not card then return end
	local scrim = Instance.new("TextButton")
	scrim.Name = "ConfirmScrim"
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.BackgroundColor3 = Color3.new(0, 0, 0)
	scrim.BackgroundTransparency = 1
	scrim.Size = UDim2.new(1, 4000, 1, 4000)
	scrim.Position = UDim2.fromOffset(-2000, -2000)
	scrim.ZIndex = 8
	scrim.Parent = overlay
	TweenService:Create(scrim, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	setText(card, "Title", o.title or "Are you sure?")
	setText(card, "Body1", o.body1)
	setText(card, "Body2", o.body2 or "")
	setText(card, "YesText", o.yes or "YES")
	setText(card, "NoText", o.no or "CANCEL")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromOffset(root.Size.X.Offset / 2, 540)
	card.ZIndex = 9
	card.Parent = overlay
	UI.setRest(card)
	UI.popFrom(card, 0.6)
	local done = false
	local function finish(yes: boolean)
		if done then return end
		done = true
		card:Destroy()
		scrim:Destroy()
		if yes then onYes() elseif onNo then onNo() end
	end
	for _, b in card:GetDescendants() do
		if b:IsA("GuiButton") and b:GetAttribute("Button") then UI.juicy(b) end
	end
	onClick(find(card, "BtnYes"), function() finish(true) end)
	onClick(find(card, "BtnNo"), function() finish(false) end)
	scrim.Activated:Connect(function() finish(false) end)
end

----------------------------------------------------------------------------------------------- settings + UI colour
local function applyUiColour()
	local tint = ACCENT_TINT[settings.uiColour or ""]
	for _, name in ipairs(PANELS) do
		local sc = S[name]
		local grp = sc and sc:FindFirstChild(name)
		if grp then
			for _, pair in ipairs({ { "Glow", "GlowMono" }, { "Fill", "FillMono" } }) do
				local orig, mono = find(grp, pair[1]), find(grp, pair[2])
				if orig and mono then
					orig.Visible = tint == nil
					mono.Visible = tint ~= nil
					if tint then
						local img = if mono:IsA("ImageLabel") then mono else mono:FindFirstChildWhichIsA("ImageLabel", true)
						if img then img.ImageColor3 = tint end
					end
				end
			end
		end
	end
	-- swatch selection
	local row = find(S.Settings, "Row5")
	local changed = row and row:GetAttribute("Shown") ~= (settings.uiColour or "")
	if row then row:SetAttribute("Shown", settings.uiColour or "") end
	if row and changed then
		for label, key in pairs(SWATCH_KEY) do
			if key == (settings.uiColour or "") then
				local sw = row:FindFirstChild("Swatch_" .. label)
				moveRing(row:FindFirstChild("SwatchSel"), sw, 4)
				local chk = row:FindFirstChild("SwatchCheck")
				local chs = row:FindFirstChild("SwatchCheckShadow")
				if sw and chk then
					-- swatches are juiced buttons (centre-anchored), so place by their real top-left
					local x, y = relPos(sw, row)
					chk.AnchorPoint = Vector2.zero
					local p = UDim2.fromOffset(x + sw.Size.X.Offset - 22, y - 10)
					chk.Position = p
					local top = 0
					for _, c in row:GetChildren() do
						if c:IsA("GuiObject") and c ~= chk and c ~= chs then top = math.max(top, c.ZIndex) end
					end
					chk.ZIndex = top + 2
					if chs then chs.AnchorPoint = Vector2.zero; chs.ZIndex = top + 1 end
					if chs then chs.Position = p + UDim2.fromOffset(0, 2) end
					UI.popFrom(chk, 0.3)
				end
			end
		end
	end
end

local function applySettings()
	Sound.enabled = settings.sfx ~= false
	Sound.setMusicEnabled(settings.music ~= false)
	CameraFX.reduceEffects = settings.reduceEffects == true
	WorldFX.reduceEffects = settings.reduceEffects == true
	applyUiColour()
end

----------------------------------------------------------------------------------------------- HUD
local groupHidden: { [string]: boolean } = {}
local function hideGroup(name: string, on: boolean)
	if groupHidden[name] ~= on then
		groupHidden[name] = on
		UI.setGroupHidden(name, on)
	end
end

local function hudGroup(screen: string, name: string): Instance?
	return S[screen] and S[screen]:FindFirstChild(name)
end

local lastPhaseTick = -1
local function phaseLeft(): number
	return math.max(0, (state:GetAttribute("PhaseEndsAt") or 0) - serverNow())
end

local function lobbyStatus()
	local hud = S.HUD
	local status = hud and hud:FindFirstChild("Status")
	if not status then return end
	local phase = state:GetAttribute("Phase") or "BOOT"
	local head, subl = "Lobby", ""
	setText(status, "Phase", if player:GetAttribute("EOS_InPractice") then "PRACTICE FIELD" else "LOBBY")
	if not player:GetAttribute("EOS_Loaded") then
		head = "Loading..."
		subl = player:GetAttribute("EOS_LoadStatus") or "Getting your save ready"
	elseif phase == "WAITING" then
		head = "Waiting for players"
		subl = if (state:GetAttribute("Needed") or 1) == math.huge then "Knife test: no matches here" else ("%d / %d ready"):format(state:GetAttribute("Ready") or 0, state:GetAttribute("Needed") or 1) -- HOS-LOBBY-001: sandbox Needed = math.huge
	elseif phase == "INTERMISSION" then
		head = "Next match in " .. Format.time(math.ceil(phaseLeft()))
		local n = state:GetAttribute("Ready") or 0
		subl = font(RARITY_COLOR.common, ("%d player%s ready"):format(n, if n == 1 then "" else "s"))
	elseif phase == "RESULTS" then
		head = "Match over"
		subl = "Next match soon"
	elseif phase == "BOOT" then
		head = "Starting up..."
	else
		head = "Match in progress"
		subl = "You'll join the next one"
	end
	if player:GetAttribute("EOS_AFK") then
		subl = font(Color3.fromRGB(255, 160, 64), "AFK on: you'll sit out matches") .. "  ·  tap AFK to play"
	end
	setText(status, "Headline", head)
	setRich(status, "SublineText", subl)
end

local function matchStatus()
	local m = S.MatchHUD
	local status = m and m:FindFirstChild("Status")
	if not status then return end
	local phase = state:GetAttribute("Phase") or ""
	local r = role()
	local left = phaseLeft()
	local wave = state:GetAttribute("Wave") or 0
	local label = if phase == "ROLE_REVEAL" then "GET READY" elseif phase == "WAVE_END" then "SIDES FLIP" else ("CROSSING %d"):format(math.max(1, wave))
	local head
	if phase == "ROLE_REVEAL" then
		head = if r == "CATCHER" then "You're a Catcher!" else "You're a Runner!"
	elseif phase == "WAVE_END" then
		head = "Get ready for the next crossing"
	elseif r == "CATCHER" then
		head = "Tag the Runners!"
	elseif r == "CAUGHT" then
		head = "You're out this crossing"
	elseif player:GetAttribute("EOS_Safe") then
		head = "Safe! Wait for the next crossing"
	else
		head = "Cross to the opposite safe side!"
	end
	setText(status, "Phase", label)
	setText(status, "Headline", head)
	local blue, red, dim = Color3.fromRGB(106, 216, 255), Color3.fromRGB(255, 90, 90), Color3.fromRGB(210, 210, 216)
	local roleTxt = if r == "CATCHER" then font(red, "Catcher") elseif r == "CAUGHT" then font(dim, "Out") else font(blue, "Runner")
	local secs = math.ceil(left)
	local timer = Format.time(secs)
	if phase == "CROSSING" and secs <= 5 then
		timer = font(red, timer)
		if secs ~= lastPhaseTick and secs > 0 then
			lastPhaseTick = secs
			Sound.play("tick")
			UI.pulse(status, 0.05)
		end
	end
	local runners, catchers = state:GetAttribute("RunnersLeft") or 0, state:GetAttribute("Catchers") or 0
	setRich(status, "SublineText", ("%s  ·  %s  ·  %s %s %s"):format(roleTxt, timer, font(blue, runners .. (if runners == 1 then " Runner" else " Runners")), font(dim, "vs"), font(red, catchers .. (if catchers == 1 then " Catcher" else " Catchers"))))
	-- clean streak pips
	local streak = state:GetAttribute("CleanStreak") or 0
	for i = 1, 3 do
		local pip = status:FindFirstChild("StreakPip" .. i)
		if pip then
			local on = i <= streak
			if pip:GetAttribute("On") ~= on then
				pip:SetAttribute("On", on)
				local g = pip:FindFirstChildOfClass("UIGradient")
				if g then g.Enabled = on end
				pip.BackgroundColor3 = if on then Color3.new(1, 1, 1) else Color3.fromRGB(44, 44, 48)
				if on then UI.popFrom(pip, 0.3) end
			end
		end
	end
end

local function eggCard()
	local egg = hudGroup("MatchHUD", "Egg")
	if not egg then return end
	local r = role()
	local level = if r == "RUNNER" then (player:GetAttribute("EOS_Tier") or 1) else (player:GetAttribute("EOS_Secured") or player:GetAttribute("EOS_Tier") or 1)
	if egg:GetAttribute("Level") == level and egg:GetAttribute("Role") == r then return end
	local grew = (egg:GetAttribute("Level") or level) < level
	egg:SetAttribute("Level", level)
	egg:SetAttribute("Role", r)
	setIcon(egg, "Icon", eggSlug(level))
	setText(egg, "EggTitle", if r == "RUNNER" then "YOUR EGG" else "BEST EGG")
	local PC = require(Shared:WaitForChild("PointsConfig")) -- HOS-PTS-001: egg ladder on = the card names the rarity and the piece it really pays
	if PC.Ladder and PC.Ladder.Enabled then
		local rar = PC.rarityForLevel(level)
		setText(egg, "EggLevel", string.upper(rar))
		setColor(egg, "EggLevel", RARITY_COLOR[if rar == "legendary" then "crowned" else rar] or Color3.new(1, 1, 1))
		local piece = PC.pieceFor(rar)
		setIcon(egg, "PaysIcon", "piece_" .. piece)
		setText(egg, "PaysText", materialName(piece))
		setColor(egg, "PaysText", RARITY_COLOR[piece] or Color3.new(1, 1, 1))
	else
	setText(egg, "EggLevel", "LEVEL " .. level)
	local tc = TierConfig.get(level)
	if tc and tc.text then setColor(egg, "EggLevel", tc.text) end
	local m = EconomyConfig.materialForTier(level)
	setIcon(egg, "PaysIcon", "piece_" .. m)
	setText(egg, "PaysText", materialName(m))
	setColor(egg, "PaysText", RARITY_COLOR[m] or Color3.new(1, 1, 1))
	end -- HOS-PTS-001
	for i = 1, 4 do
		local pip = egg:FindFirstChild("LevelPip" .. i)
		if pip then
			local on = i <= (if PC.Ladder and PC.Ladder.Enabled then (table.find({ "common", "rare", "epic", "legendary" }, PC.rarityForLevel(level)) or 1) else math.min(level, 4)) -- HOS-PTS-001: one diamond per rarity
			local g = pip:FindFirstChildOfClass("UIGradient")
			if g then g.Enabled = on end
			pip.BackgroundColor3 = if on then Color3.new(1, 1, 1) else Color3.fromRGB(44, 44, 48)
		end
	end
	if grew then
		UI.pulse(egg:FindFirstChild("EggSlot") or egg, 0.25)
	end
end

local abilityWasReady = true
local function abilityCard()
	-- Pets.family: nil for the match's starting Catcher (no pet ability) and for a removed family
	local fam = Pets.family() or ""
	local has = fam ~= ""
	hideGroup("Ability", not has)
	if not has then return end
	local species = player:GetAttribute("EOS_PetSpecies") or ""
	local rarity = string.lower(player:GetAttribute("EOS_PetRarity") or "common")
	local art, petName = petArt(fam, rarity)
	local dev = deviceClass()
	local charge = Pets.charge()
	local ready = charge >= 0.999
	for _, sc in ipairs({ "HUD", "MatchHUD" }) do
		local card = hudGroup(sc, "Ability")
		if card then
			local cr = if sc == "MatchHUD" and inMatch() then role() else nil
			if card:GetAttribute("Fam") ~= fam .. rarity .. (cr or "") then
				card:SetAttribute("Fam", fam .. rarity .. (cr or ""))
				setText(card, "AbilityName", familyAbility(fam, cr))
				setIcon(card, "AbilityIcon", familyIcon(fam, cr))
				setIcon(card, "PetIcon", art)
			end
			local key = card:FindFirstChild("Key")
			if key then key.Visible = dev ~= "touch" end
			if sc == "HUD" then
				-- a roster pet shows its own name (HOS-PET-012); others keep the showroom placeholder name
				local shown = EconomyConfig.DISPLAY_NAMES[species] or (if petName ~= "" then petName else EconomyConfig.displayName(species))
				setText(card, "Status", ("EQUIPPED  ·  %s"):format(string.upper(shown)))
				setBar(card:FindFirstChild("Cooldown"), 1)
				setText(card, "KeyText", if dev == "gamepad" or dev == "console" then "Y" else "Q")
			else
				local left = math.max(0, (Pets.readyAt or 0) - os.clock())
				if ready then
					setText(card, "Status", if dev == "touch" then "READY  ·  TAP ABILITY" else "READY")
					setText(card, "KeyText", if dev == "gamepad" or dev == "console" then "Y" else "Q")
				else
					setText(card, "Status", ("RECHARGING  %ds"):format(math.ceil(left)))
					setText(card, "KeyText", tostring(math.ceil(left)))
				end
				setBar(card:FindFirstChild("Cooldown"), charge)
			end
		end
	end
	if ready and not abilityWasReady and inMatch() then
		local card = hudGroup("MatchHUD", "Ability")
		if card then UI.pulse(card, 0.08) end
	end
	abilityWasReady = ready
end

local function dashBar()
	local dev = deviceClass()
	hideGroup("Dash", dev == "touch")
	local r = role()
	local catcher = inMatch() and r == "CATCHER"
	local charge, txt, hint
	if catcher then
		charge = Tag.lungeCharge()
		local left = math.max(0, Tag.lastLunge + ((GameConfig.Lunge and GameConfig.Lunge.COOLDOWN) or 2.5) - os.clock())
		txt = if charge >= 0.999 then "LUNGE READY" else ("LUNGE  %.1fs"):format(left)
		hint = "Lunge at a Runner, then tag"
	else
		charge = Movement.dashCharge()
		local why = Movement.blockedReason()
		if why == "OFF" then
			txt = "DASH OFF"
		elseif why == "PAUSED" then
			txt = "DASH PAUSED"
		elseif charge >= 0.999 then
			txt = "DASH READY"
		else
			txt = "DASH ON COOLDOWN"
		end
		hint = "Space to dash sideways or back"
		if os.clock() - (Movement.refusedAt or -math.huge) < 1.2 then
			hint = if Movement.refusedWhy == "FACING" then "Not the way you face: dash sideways or back" else "Sideways or back only"
		end
	end
	local key = if dev == "gamepad" or dev == "console" then "A" else "SPACE"
	for _, sc in ipairs({ "HUD", "MatchHUD" }) do
		local d = hudGroup(sc, "Dash")
		if d then
			setText(d, "DashTitle", ("%s  ·  %s"):format(key, if catcher then "LUNGE" else "DASH"))
			setText(d, "DashState", txt)
			setText(d, "DashHint", hint)
			setBar(d:FindFirstChild("DashBar"), charge)
		end
	end
end

local function touchButtons()
	local t = hudGroup("MatchHUD", "Touch")
	if not t then return end
	local touch = deviceClass() == "touch"
	hideGroup("Touch", not touch)
	if not touch then return end
	local r = role()
	local tagB, dashB, abB = t:FindFirstChild("TouchTag"), t:FindFirstChild("TouchDash"), t:FindFirstChild("TouchAbility")
	if tagB then tagB.Visible = r == "CATCHER" end
	if abB then
		local fam = Pets.family() or "" -- hidden for the starting Catcher
		abB.Visible = fam ~= ""
		if abB:GetAttribute("Fam") ~= fam .. r then
			abB:SetAttribute("Fam", fam .. r)
			setIcon(abB, "Icon", familyIcon(fam, r))
		end
	end
	local function shade(b: Instance?, frac: number, secs: number)
		if not b then return end
		local sh = b:FindFirstChild("Shade")
		local sl = find(b, "Secs")
		local holder = sl and sl.Parent
		local busy = frac < 0.999
		if sh then sh.Visible = busy end
		if holder and holder:IsA("GuiObject") then holder.Visible = busy end
		if busy then setText(b, "Secs", tostring(math.ceil(secs))) end
	end
	if dashB then
		if r == "CATCHER" then
			setText(dashB, "Label", "LUNGE")
			shade(dashB, Tag.lungeCharge(), Tag.lastLunge + ((GameConfig.Lunge and GameConfig.Lunge.COOLDOWN) or 2.5) - os.clock())
		else
			setText(dashB, "Label", "DASH")
			shade(dashB, Movement.dashCharge(), (Movement.dashReadyAt or 0) - os.clock())
		end
	end
	shade(abB, Pets.charge(), (Pets.readyAt or 0) - os.clock())
	shade(tagB, math.clamp((os.clock() - Tag.lastSwing) / ((GameConfig.Capture and GameConfig.Capture.TAG_COOLDOWN) or 1), 0, 1), Tag.lastSwing + ((GameConfig.Capture and GameConfig.Capture.TAG_COOLDOWN) or 1) - os.clock())
end

local SPECTATE_PHASES = { ROLE_REVEAL = true, CROSSING = true, WAVE_END = true }
local function watchPill()
	local w = hudGroup("HUD", "Watch")
	local b = w and w:FindFirstChild("SpectateButton")
	if b and b:IsA("GuiObject") then
		b.Visible = not inMatch() and SPECTATE_PHASES[state:GetAttribute("Phase") or ""] == true and not UIC.spectating()
	end
end

-- HUNT (Volunteer To Hunt) only in private servers: in public ones it's clutter, and the server ignores it
local PRIVATE = game.PrivateServerId ~= ""

local function railToggles()
	watchPill()
	local rail = hudGroup("HUD", "Rail")
	if not rail then return end
	local hunt = rail:FindFirstChild("VolunteerToggle")
	if hunt and hunt:IsA("GuiObject") then hunt.Visible = PRIVATE end
	-- one drawing per toggle: full colour on a coloured plate when on, the greyed "<slug>_off" copy on the grey
	-- plate when off (Hunter's pick, 16 Oct; the afk_on play moon is uploaded but unused)
	for name, t in pairs({ AFKToggle = { "EOS_AFK", "afk" }, VolunteerToggle = { "EOS_Volunteer", "hunt" } }) do
		local b = rail:FindFirstChild(name)
		if b then
			local on = player:GetAttribute(t[1]) == true
			local a, o = b:FindFirstChild("StateOn"), b:FindFirstChild("StateOff")
			if a then a.Visible = on end
			if o then o.Visible = not on end
			local slug = if on then t[2] else t[2] .. "_off"
			if iconId(slug) ~= "" then setIcon(b, "Icon", slug) end
			-- the coloured plate (AFK blue, Hunt purple) shows while the toggle is on; off is the grey plate
			local plateOn = b:FindFirstChild("PlateOn")
			if plateOn and plateOn:IsA("GuiObject") then plateOn.Visible = on end
		end
	end
end

local function claimable(): number
	local n = 0
	for _, q in ipairs((profile and profile.quests) or {}) do
		if not q.claimed and (q.progress or 0) >= (q.target or 1) then
			n += 1
		end
	end
	return n
end

local function goalPill()
	local tl = hudGroup("HUD", "Goal") -- its own top-right group since 16 Oct
	local pill = tl and tl:FindFirstChild("GoalPill")
	if not pill or not profile then return end
	local pets = profile.pets or {}
	if #pets == 0 then
		local need = costFor("common", false)
		local n = haveFor("common")
		setText(pill, "GoalTitle", "YOUR FIRST PET")
		setText(pill, "GoalCount", ("%d / %d"):format(math.min(n, need), need))
		setIcon(pill, "GoalIcon", "piece_common")
		setBar(pill:FindFirstChild("GoalBar"), n / need)
		setText(pill, "GoalState", if n >= need then "READY TO HATCH!" else "PLAY A MATCH TO EARN PIECES")
		pill:SetAttribute("OpensVia", "Incubator")
		return
	end
	local q
	for _, x in ipairs(profile.quests or {}) do
		if x.id == trackedQuest and not x.claimed then q = x end
	end
	if q then
		setText(pill, "GoalTitle", string.upper(q.title or "QUEST"))
		setText(pill, "GoalCount", ("%d / %d"):format(math.min(q.progress or 0, q.target or 1), q.target or 1))
		setIcon(pill, "GoalIcon", "quests")
		setBar(pill:FindFirstChild("GoalBar"), (q.progress or 0) / (q.target or 1))
		setText(pill, "GoalState", if (q.progress or 0) >= (q.target or 1) then "READY TO CLAIM!" else ("+%d GOLD"):format(q.reward or 0))
		pill:SetAttribute("OpensVia", "Quests")
		return
	end
	-- next hatch: the cheapest recipe you're closest to
	local best, bestFrac = "common", -1
	for _, m in ipairs(EconomyConfig.MATERIALS) do
		local f = have(m) / costFor(m, false)
		if f > bestFrac then best, bestFrac = m, f end
	end
	local need = costFor(best, false)
	setText(pill, "GoalTitle", "NEXT HATCH")
	setText(pill, "GoalCount", ("%d / %d"):format(math.min(have(best), need), need))
	setIcon(pill, "GoalIcon", "piece_" .. best)
	setBar(pill:FindFirstChild("GoalBar"), bestFrac)
	setText(pill, "GoalState", if bestFrac >= 1 then "READY TO HATCH!" else (materialName(best) .. " pieces"):upper())
	pill:SetAttribute("OpensVia", "Incubator")
end

-- account level + XP bar: the top plate of the bottom-left Level / Gold / Gems column (16 Oct: XP system)
local function levelPlate()
	local wal = hudGroup("HUD", "Wallet")
	local lp = wal and wal:FindFirstChild("LevelPlate")
	if not lp or not profile then return end
	local level, into, need = EconomyConfig.levelFor(profile.xp or 0)
	setText(lp, "LevelText", "LEVEL " .. level)
	setText(lp, "XpText", ("%s / %s XP"):format(Format.full(into), Format.full(need)))
	setBar(lp:FindFirstChild("XpBar"), into / need)
end

local function badges()
	local tl = hudGroup("HUD", "TopLeft")
	if not tl then return end
	local qb = find(tl:FindFirstChild("QuestsButton"), "Badge")
	local ib = find(tl:FindFirstChild("IncubatorButton"), "Badge")
	local q, h = claimable() > 0, hatchReady()
	if qb then
		if qb.Visible ~= q then qb.Visible = q; UI.breathe(qb, q) end
	end
	if ib then
		if ib.Visible ~= h then ib.Visible = h; UI.breathe(ib, h) end
	end
end

local tensionLatch = false
local resultsShownAt = -math.huge
local function updateHUD()
	local m = inMatch()
	-- music: lobby beds, crossing tracks, a tension track for the last 12 s of a crossing or the last two
	-- runners (latched until the crossing ends, so it can't flicker), silence under the results sting
	local music = "lobby"
	if resultsOpen and os.clock() - resultsShownAt < 9 then
		music = "results" -- the win / lose sting plays over silence, then the lobby bed comes back
	elseif UIC.spectating() then
		music = "match" -- watching the match from the lobby
	elseif m then
		if state:GetAttribute("Phase") == "CROSSING" then
			if phaseLeft() <= 12 or (state:GetAttribute("RunnersLeft") or 99) <= 2 then tensionLatch = true end
		else
			tensionLatch = false
		end
		music = if tensionLatch then "tension" else "match"
	end
	Sound.setMusic(music)
	if music == "lobby" then Sound.resetMatchMusic() end
	if S.HUD then S.HUD.Visible = not m and not UIC.spectating() end
	if S.MatchHUD then S.MatchHUD.Visible = m end
	if m then
		matchStatus()
		eggCard()
		touchButtons()
		-- feed lines time themselves out (UIC.feed)
	else
		lobbyStatus()
		railToggles()
		goalPill()
		levelPlate()
		badges()
	end
	abilityCard()
	dashBar()
	-- results: auto-close + countdown
	if resultsOpen and resultsData then
		local nm = resultsData.nextMatchAt or 0
		local left = nm - serverNow()
		local phase = state:GetAttribute("Phase")
		setText(S.Results, "NextText", if phase == "WAITING" then "Waiting for players" else ("Next match in %s"):format(Format.time(math.max(0, math.ceil(left)))))
		if phase == "ROLE_REVEAL" or left < -2 then
			UIC.closeResults()
		end
	end
	-- quests reset countdown
	if UI.current() == "Quests" then
		local t = 86400 - math.floor(serverNow()) % 86400
		setText(S.Quests, "ResetText", "Resets in " .. Format.time(t))
	end
end

----------------------------------------------------------------------------------------------- wallet
local function setWallet(kind: string, v: number)
	local hud = S.HUD
	if hud then
		local key = if kind == "gold" then "GoldText" else "GemsText"
		UI.countTo(kind, v, hud, key, Format.full)
	end
	if S.Shop then
		setText(S.Shop, if kind == "gold" then "GoldText" else "GemsText", Format.full(v))
	end
end

----------------------------------------------------------------------------------------------- Quests
local selQuest = 1
local questTab = "today"
local function questList(): { any }
	local out = {}
	for _, q in ipairs((profile and profile.quests) or {}) do
		if (questTab == "done") == (q.claimed == true) then
			table.insert(out, q)
		end
	end
	return out
end

local function refreshQuests()
	local sc = S.Quests
	if not sc or not profile then return end
	local all = profile.quests or {}
	local done = 0
	for _, q in ipairs(all) do if q.claimed then done += 1 end end
	setDual(find(sc, "TabToday"), questTab == "today")
	setDual(find(sc, "TabDone"), questTab == "done")
	for _, d in ipairs({ "TabToday", "TabDone" }) do
		local t = find(sc, d)
		if t then setText(t, "Label", if d == "TabToday" then ("Today  [%d]"):format(#all - done) else ("Done  [%d]"):format(done)) end
	end
	local list = questList()
	selQuest = math.clamp(selQuest, 1, math.max(1, #list))
	for i = 1, 2 do
		local card = find(sc, "Quest" .. i)
		local q = list[i]
		if card then
			show(card, q ~= nil)
			if q then
				local ready = not q.claimed and (q.progress or 0) >= (q.target or 1)
				setText(card, "QuestName", q.title or "Quest")
				setText(card, "ProgressText", ("%d / %d"):format(math.min(q.progress or 0, q.target or 1), q.target or 1))
				setColor(card, "ProgressText", if ready or q.claimed then Color3.fromRGB(150, 240, 60) else Color3.new(1, 1, 1))
				setBar(card:FindFirstChild("Progress"), (q.progress or 0) / (q.target or 1))
				local claim = card:FindFirstChild("Claim")
				if claim then
					claim.Visible = ready
					if ready and claim:GetAttribute("Breathing") ~= true then
						claim:SetAttribute("Breathing", true)
						UI.pulse(claim, 0.15)
					end
				end
				local dn = card:FindFirstChild("Done")
				if dn then dn.Visible = q.claimed == true end
			end
		end
	end
	local tom = find(sc, "Tomorrow")
	if tom then show(tom, #list < 2 and questTab == "today") end
	local claimAll = find(sc, "ClaimAll")
	if claimAll then claimAll.Visible = claimable() > 0 end
	moveRing(find(sc, "SelRing"), find(sc, "Quest" .. selQuest), 4)
	-- detail
	local q = list[selQuest]
	local detail = find(sc, "Detail")
	if detail then
		detail.Visible = q ~= nil
		if q then
			local txt = QUEST_TEXT[q.id] or { "Complete it in a match.", "" }
			setText(detail, "QuestTitle", q.title or "Quest")
			setText(detail, "QuestDesc", txt[1])
			setText(detail, "QuestDesc2", (txt[2] ~= "" and (txt[2] .. "  ") or "") .. "Counts with 4+ real players.")
			setText(detail, "ProgressText", ("%d / %d"):format(math.min(q.progress or 0, q.target or 1), q.target or 1))
			setBar(detail:FindFirstChild("Progress"), (q.progress or 0) / (q.target or 1))
			local r1 = detail:FindFirstChild("Reward1", true)
			if r1 then setText(r1, "CountText", "x" .. (q.reward or 0)) end
			local track = detail:FindFirstChild("Track")
			if track then
				track.Visible = not q.claimed
				setText(track, "Label", if trackedQuest == q.id then "TRACKING" else "TRACK")
			end
		end
	end
end

----------------------------------------------------------------------------------------------- Incubator
local selFamily: string? = nil
local selRarity = "common"
local function familyFound(f: string): (number, number)
	local seen = {}
	for _, p in ipairs((profile and profile.pets) or {}) do
		if p.family == f then seen[p.rarity] = true end
	end
	local n = 0
	for _ in pairs(seen) do n += 1 end
	return n, 3
end

local function refreshIncubator()
	local sc = S.Incubator
	if not sc or not profile then return end
	if not selFamily or not isLive(selFamily) then
		local eq = player:GetAttribute("EOS_PetFamily") or ""
		selFamily = if eq ~= "" and isLive(eq) then eq else launchFamilies()[1]
	end
	local first = profile.firstCommonFree == true or #(profile.pets or {}) == 0
	-- pieces
	for _, m in ipairs(EconomyConfig.MATERIALS) do
		local tile = find(sc, "Piece_" .. m)
		if tile then
			local n = have(m)
			setText(tile, "CountText", "x" .. n)
			-- the design baked each tile lit or dark for its sample count: use the real icon, dark when empty
			local art = find(find(tile, "Icon"), "Art")
			if art and art:IsA("ImageLabel") then
				art.Image = iconId("piece_" .. m)
				art.ImageColor3 = if n > 0 then Color3.new(1, 1, 1) else Color3.fromRGB(40, 40, 46)
			end
		end
	end
	-- top: first-pet path or collection
	local fp, coll = find(sc, "FirstPet"), find(sc, "CollectionWrap")
	if fp then fp.Visible = first end
	if coll then coll.Visible = not first end
	if first then
		local need = costFor("common", false)
		local got = haveFor("common")
		setBar(find(fp, "Track"), math.min(got, need) / need)
		-- steps light up as the pieces arrive (one per match); the hatch step breathes when it's ready
		for i = 1, 2 do
			local st = fp:FindFirstChild("Step" .. i)
			local lit = got >= math.ceil(need * i / 2)
			if st then
				local a, ic = st:FindFirstChild("Art"), st:FindFirstChild("Icon")
				if a and a:IsA("ImageLabel") then a.ImageColor3 = if lit then Color3.new(1, 1, 1) else Color3.fromRGB(70, 70, 76) end
				if ic and ic:IsA("ImageLabel") then ic.ImageTransparency = if lit then 0 else 0.6 end
			end
		end
		local hs = fp:FindFirstChild("Step3")
		if hs then UI.breathe(hs, got >= need) end
	elseif coll then
		for _, f in ipairs(ORDER) do
			local n, tot = familyFound(f)
			setText(coll, "FamCount_" .. f, if isLive(f) then ("%d / %d"):format(n, tot) else ("wave %d"):format(FAMILY[f].wave))
		end
	end
	-- family tiles: live vs coming soon (from the game's launch list, not the design)
	local fams = find(sc, "Families")
	for _, f in ipairs(ORDER) do
		local tile = fams and fams:FindFirstChild("Family_" .. f)
		if tile then
			local live = isLive(f)
			local l, s = find(tile, "Live"), find(tile, "Soon")
			if l then l.Visible = live end
			if s then s.Visible = not live end
		end
	end
	local selTile = fams and fams:FindFirstChild("Family_" .. selFamily)
	if fams then moveRing(fams:FindFirstChild("FamilySel"), selTile and find(selTile, "Live"), 4) end
	-- ladder for the selected family
	local lad = find(sc, "Ladder")
	if lad then
		local f = selFamily :: string
		local info = table.clone(FAMILY[f] or {})
		local arch = AbilityConfig.get(f) -- the game's per-role lines win over the design's
		if arch then
			info.run, info.catch = arch.Runner.text, arch.Catcher.text
		end
		-- the well's folder-tab title is unnamed in the export: init() tags it (and its shadow) LadderTitle
		for _, d in sc:GetDescendants() do
			if d:IsA("TextLabel") and d:GetAttribute("LadderTitle") then
				d.Text = ("%s  ·  %s"):format(familyTitle(f), familyShort(f))
			end
		end
		for i, m in ipairs(RARITIES) do
			local sp = lad:FindFirstChild("Species_" .. m)
			if sp then
				local art, nm = petArt(f, m)
				setIcon(sp, "Icon", art)
				setText(sp, "PetName", nm)
				local r = EconomyConfig.RECIPES[m]
				setText(sp, "RecipeText", ("%d random · %d pick"):format(r.base, r.focus))
			end
		end
		moveRing(lad:FindFirstChild("SpeciesSel"), find(lad:FindFirstChild("Species_" .. selRarity), "Tile"), 4)
		local roles = ("%s %s  ·  %s %s"):format(font(Color3.fromRGB(106, 216, 255), "AS RUNNER"), info.run or "", font(Color3.fromRGB(255, 90, 90), "AS CATCHER"), info.catch or "")
		if #(info.run or "") + #(info.catch or "") <= 28 then
			roles ..= "  ·  " .. font(Color3.fromRGB(210, 210, 216), "you keep it when caught")
		end
		setRich(lad, "RolesText", roles)
	end
	-- hatch bar
	local hf, hl = find(sc, "HatchFirst"), find(sc, "HatchLater")
	if hf then hf.Visible = first end
	if hl then hl.Visible = not first end
	if first and hf then
		local need = costFor("common", false)
		local ok = haveFor("common") >= need
		local art, nm = petArt(selFamily, "common")
		setText(hf, "HatchTitle", "HATCH YOUR FIRST PET")
		setText(hf, "HatchSub", ("%s  ·  %s  ·  costs %d Common pieces"):format(nm, familyTitle(selFamily :: string), need))
		for _, b in ipairs({ "BtnHatch", "BtnHatchPoor" }) do
			local bt = hf:FindFirstChild(b)
			if bt then
				setText(bt, "CostText", "x" .. need)
				bt.Visible = (b == "BtnHatch") == ok
			end
		end
		local ft = hf:FindFirstChild("FreeTag")
		if ft then ft.Visible = profile.firstCommonFree == true end
	elseif hl then
		local base, focus = costFor(selRarity, false), costFor(selRarity, true)
		local n = haveFor(selRarity)
		local rb = hl:FindFirstChild("BtnRandom")
		if rb then
			setText(rb, "CostText", "x" .. base)
			setIcon(rb, "CostIcon", "piece_" .. selRarity)
		end
		for _, b in ipairs({ "BtnFocus", "BtnFocusPoor" }) do
			local bt = hl:FindFirstChild(b)
			if bt then
				setText(bt, "Label", ("HATCH %s"):format(string.upper(familyTitle(selFamily :: string))))
				setText(bt, "CostText", "x" .. focus)
				setIcon(bt, "CostIcon", "piece_" .. selRarity)
				bt.Visible = (b == "BtnFocus") == (n >= focus)
			end
		end
		setText(hl, "HaveText", ("%d / %d %s pieces"):format(math.min(n, base), base, materialName(selRarity)))
	end
end

local function requestHatch(rarity: string, family: string?, allowHigher: boolean?)
	Net.event("RequestHatch"):FireServer(rarity, family, allowHigher == true)
end

local hatchPending = false
local function doHatch(focused: boolean)
	if not profile then return end
	local first = profile.firstCommonFree == true or #(profile.pets or {}) == 0
	local m = if first then "common" else selRarity
	local need = costFor(m, focused or first)
	if first then need = costFor("common", false) end
	local n = haveFor(m)
	if n < need then
		UIC.toast(("Need %d %s pieces (you have %d)"):format(need, materialName(m), have(m)), "bad")
		local hb = find(S.Incubator, "HatchBar")
		if hb then UI.shake(hb, 6, 0.3) end
		Sound.play("error")
		return
	end
	hatchPending = true
	requestHatch(m, if (focused or first) then selFamily else nil, false)
end

----------------------------------------------------------------------------------------------- Hatch reveal
local function showReveal(t: any)
	local pet = t.pet
	local sc = S.Hatch
	if not sc or not pet then return end
	local art, nm = petArt(pet.family, pet.rarity)
	nm = EconomyConfig.DISPLAY_NAMES[pet.species] or nm -- the hatched species' roster name (HOS-PET-012)
	setText(sc, "Title", if t.royal then "A ROYAL HATCH!" else "NEW PET!")
	setText(sc, "PetName", nm)
	setText(sc, "RarityText", RARITY_NAME[pet.rarity] or pet.rarity or "")
	setColor(sc, "RarityText", RARITY_COLOR[pet.rarity] or Color3.new(1, 1, 1))
	setIcon(sc, "AbilityIcon", familyIcon(pet.family))
	setText(sc, "AbilityText", familyTitle(pet.family))
	local equip = find(sc, "BtnEquip")
	-- the server auto-equips a new pet when nothing is equipped, and HatchResult lands before that ProfileState
	local eqd = profile and profile.equippedPet
	local isEquipped = eqd == pet.id or eqd == nil or eqd == ""
	if equip then equip.Visible = not isEquipped end
	-- alone, NICE! moves to the middle of the pair (both are juiced: centre-anchored, rest in JuiceRest)
	local nice = find(sc, "BtnClose")
	if equip and nice and equip:IsA("GuiObject") and nice:IsA("GuiObject") then
		if nice:GetAttribute("PairHome") == nil then
			nice:SetAttribute("PairHome", nice.Position)
			nice:SetAttribute("PairMid", nice.Position:Lerp(equip.Position, 0.5))
		end
		local at = (if isEquipped then nice:GetAttribute("PairMid") else nice:GetAttribute("PairHome")) :: UDim2
		nice.Position = at
		nice:SetAttribute("JuiceRest", at)
	end
	sc:SetAttribute("PetId", pet.id)
	UI.open("Hatch", { keepHistory = true })
	-- egg shake -> flash -> pet pop
	local petImg = find(sc, "Pet") :: ImageLabel?
	local reveal = find(sc, "Reveal") :: GuiObject?
	local title = find(sc, "TitleBig") or find(sc, "Title")
	local hidden = {}
	for _, n in ipairs({ "TitleBig", "PetName", "RarityText", "AbilityIcon", "AbilityText", "BtnEquip", "BtnClose", "Sparkle" }) do
		for _, d in (reveal or sc):GetDescendants() do
			if d:IsA("GuiObject") and (d.Name == n or d.Name == n .. "Shadow") and d.Visible then
				d.Visible = false
				table.insert(hidden, d)
			end
		end
	end
	setIcon(sc, "Pet", eggSlug(if pet.rarity == "epic" then 3 elseif pet.rarity == "rare" then 2 else 1))
	Sound.play("open")
	Sound.duck(0.25, if t.royal then 4.5 else 3.5)
	task.spawn(function()
		if petImg then UI.shake(petImg, 14, if t.royal then 2 else 1.2) end
		local shake = if t.royal then 2 else 1.2
		for k = 0, math.floor(shake / 0.4) - 1 do
			task.delay(k * 0.4, function() Sound.play("crack", 1 + k * 0.06) end)
		end
		task.wait(shake)
		Sound.play("reveal")
		Sound.play("applause")
		setIcon(sc, "Pet", art)
		if petImg then UI.popFrom(petImg, 0.2) end
		for _, d in ipairs(hidden) do d.Visible = true end
		if title and title:IsA("GuiObject") then UI.popFrom(title, 1.6) end
		for _, d in (reveal or sc):GetDescendants() do
			if d:IsA("ImageLabel") and d.Name == "Sparkle" then
				UI.popFrom(d, 0, math.random() * 0.4)
				UI.breathe(d, true)
			end
		end
	end)
end

----------------------------------------------------------------------------------------------- Pets
local selPet: any = nil
local petFilter = 0
local function petGroups(): { any }
	-- one entry per family+rarity; copies -> mastery stars (max 3)
	local groups, by = {}, {}
	for _, p in ipairs((profile and profile.pets) or {}) do
		local k = (p.family or "?") .. ":" .. (p.rarity or "common")
		local g = by[k]
		if not g then
			g = { family = p.family, rarity = p.rarity or "common", species = p.species, ids = {}, n = p.n or 0 }
			by[k] = g
			table.insert(groups, g)
		end
		table.insert(g.ids, p.id)
	end
	table.sort(groups, function(a, b)
		local ra, rb = table.find(RARITIES, a.rarity) or 1, table.find(RARITIES, b.rarity) or 1
		if ra ~= rb then return ra > rb end
		return a.n < b.n
	end)
	return groups
end

local petScroll: ScrollingFrame? = nil
local function gridScroll(grid: Frame, name: string): ScrollingFrame
	local s = grid:FindFirstChild(name) :: ScrollingFrame?
	if s then return s end
	local sf = Instance.new("ScrollingFrame")
	sf.Name = name
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Size = UDim2.fromScale(1, 1)
	sf.ScrollBarThickness = 6
	sf.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 210)
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.CanvasSize = UDim2.fromOffset(0, 0)
	sf.ZIndex = 2
	sf.Parent = grid
	return sf
end

local function refreshPets()
	local sc = S.Pets
	if not sc or not profile then return end
	local grid = find(sc, "Grid") :: Frame?
	if not grid then return end
	local scroll = gridScroll(grid, "Scroll")
	petScroll = scroll
	for _, c in grid:GetChildren() do
		if c:IsA("GuiObject") and c ~= scroll and (c.Name:match("^Pet%d") or c.Name:match("^Empty%d") or c.Name:match("^Proto_")) then
			c.Visible = false
		end
	end
	local ring = grid:FindFirstChild("PetSel") or scroll:FindFirstChild("PetSel")
	if ring and ring.Parent ~= scroll then ring.Parent = scroll end
	-- filter buttons: All + the launch families
	local fams = launchFamilies()
	for i = 0, 3 do
		local b = find(sc, "Filter" .. i)
		if b then
			if i == 0 then
				setText(b, "Label", ("All  %d"):format(#(profile.pets or {})))
			else
				b.Visible = fams[i] ~= nil
				if fams[i] then setText(b, "Label", familyTitle(fams[i])) end
			end
			setDual(b, i == petFilter)
		end
	end
	local groups = petGroups()
	local shown = {}
	for _, g in ipairs(groups) do
		if petFilter == 0 or g.family == fams[petFilter] then table.insert(shown, g) end
	end
	local empty = find(sc, "EmptyState")
	if empty then empty.Visible = #(profile.pets or {}) == 0 end
	grid.Visible = #(profile.pets or {}) > 0
	-- clear previous runtime tiles
	for _, c in scroll:GetChildren() do
		if c:GetAttribute("Runtime") then c:Destroy() end
	end
	local total = 0
	for _, f in ipairs(fams) do total += 3 end
	local function place(tile: GuiObject, i: number)
		local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
		-- a clone of a juiced prototype arrives centre-anchored: place by its top-left, juicy re-centres it
		tile.AnchorPoint = Vector2.zero
		tile.Position = UDim2.fromOffset(18 + col * 196, 18 + row * 210)
	end
	local eq = profile.equippedPet
	local slots = 0
	for i, g in ipairs(shown) do
		local proto = grid:FindFirstChild("Proto_" .. g.rarity) or grid:FindFirstChild("Proto_common")
		if proto then
			local tile = proto:Clone()
			tile:SetAttribute("Runtime", true)
			tile.Name = "PetTile" .. i
			tile.Visible = true
			local stars = math.min(#g.ids, 3)
			local art = petArt(g.family, g.rarity, stars)
			setIcon(tile, "Icon", art)
			for s = 1, 3 do
				local st = find(tile, "Star" .. s)
				if st and st:IsA("ImageLabel") then st.ImageColor3 = if s <= stars then Color3.new(1, 1, 1) else Color3.fromRGB(70, 70, 76) end
			end
			local et = find(tile, "EquippedTag")
			if et then et.Visible = table.find(g.ids, eq) ~= nil end
			tile.Parent = scroll
			place(tile, i)
			if tile:IsA("GuiButton") then UI.juicy(tile) end
			local gref = g
			onClick(tile, function()
				selPet = gref
				refreshPets()
			end)
			slots = i
			if not selPet or (selPet.family == g.family and selPet.rarity == g.rarity) then
				if not selPet then selPet = g end
			end
		end
	end
	-- unknown species: "?" tiles so the collection reads like a dex
	local proto = grid:FindFirstChild("Empty6") or grid:FindFirstChild("Empty7")
	if proto and petFilter == 0 then
		for k = 1, math.max(0, total - #groups) do
			local e = proto:Clone()
			e:SetAttribute("Runtime", true)
			e.Visible = true
			e.Parent = scroll
			place(e, slots + k)
		end
		slots += math.max(0, total - #groups)
	end
	scroll.CanvasSize = UDim2.fromOffset(0, 18 + math.ceil(math.max(slots, 1) / 4) * 210)
	setText(sc, "CountText", ("%d / %d found"):format(#groups, total))
	-- selection + preview
	local selIndex
	for i, g in ipairs(shown) do
		if selPet and g.family == selPet.family and g.rarity == selPet.rarity then selIndex = i end
	end
	if not selIndex and #shown > 0 then
		selPet = shown[1]
		selIndex = 1
	end
	local selTile = selIndex and scroll:FindFirstChild("PetTile" .. selIndex)
	if ring then
		ring.ZIndex = 5
		moveRing(ring, selTile and find(selTile, "Tile"), 4)
	end
	local pv = find(sc, "Preview")
	if pv then
		pv.Visible = selPet ~= nil
		if selPet then
			local stars = math.min(#selPet.ids, 3)
			local art, nm = petArt(selPet.family, selPet.rarity, stars)
			nm = EconomyConfig.DISPLAY_NAMES[selPet.species] or nm -- HOS-PET-012
			setIcon(pv, "Icon", art)
			setText(pv, "PetName", nm)
			setText(pv, "RarityText", RARITY_NAME[selPet.rarity] or "")
			setColor(pv, "RarityText", RARITY_COLOR[selPet.rarity] or Color3.new(1, 1, 1))
			for s = 1, 3 do
				local st = find(find(pv, "Stars"), "Star" .. s)
				if st and st:IsA("ImageLabel") then st.ImageColor3 = if s <= stars then Color3.new(1, 1, 1) else Color3.fromRGB(70, 70, 76) end
			end
			local n = #selPet.ids
			for _, d in pv:GetChildren() do
				if d:IsA("TextLabel") and (d.Name == "T_Copies" or d.Name == "T_CopiesShadow") then
					d.Text = ("%d %s"):format(n, if n == 1 then "copy" else "copies")
				end
			end
			setIcon(pv, "AbilityIcon", familyIcon(selPet.family))
			setText(pv, "AbilityName", familyAbility(selPet.family))
			local ef = EconomyConfig.FAMILIES[selPet.family]
			setText(pv, "AbilityDesc", ("%s  ·  cooldown %ds"):format(familyShort(selPet.family), (ef and ef.cooldown) or 0))
			local equipped = table.find(selPet.ids, eq) ~= nil
			local a, b = find(pv, "BtnEquipped"), find(pv, "BtnEquip")
			if a then a.Visible = equipped end
			if b then b.Visible = not equipped end
		end
	end
end

----------------------------------------------------------------------------------------------- Shop
local selItem: string? = nil
local function itemState(it: any): string
	local c = (profile and profile.cosmetics) or {}
	local owned = c.owned and c.owned[it.id]
	local count = (c.consumables and c.consumables[it.id]) or 0
	local wallet = (profile and profile[it.wallet]) or 0
	if EconomyConfig.isConsumable(it) then
		if it.kind == "burst" and count > 0 then return "use" end
		return if wallet >= it.price then "ok" else "poor"
	end
	if owned then
		if it.kind == "case" or it.slot then -- HOS-VFX-RES-001: skins wear from their own slot
			return if c[it.slot or "case"] == it.id then "takeoff" else "wear"
		end
		return "owned"
	end
	return if wallet >= it.price then "ok" else "poor"
end
local STATE_BTN = { ok = "BtnBuy", poor = "BtnPoor", owned = "BtnOwned", wear = "BtnWear", takeoff = "BtnTakeOff", use = "BtnUse" }

local function setButtons(scope: Instance, it: any, st: string)
	for s, nm in pairs(STATE_BTN) do
		local b = scope:FindFirstChild(nm)
		if b then
			b.Visible = s == st
			if s == "ok" or s == "poor" then
				setText(b, "Price", Format.full(it.price))
				setIcon(b, "CurrencyIcon", if it.wallet == "gems" then "gem" else "gold")
			elseif s == "use" then
				local c = (profile and profile.cosmetics and profile.cosmetics.consumables) or {}
				setText(b, "UseCount", "x" .. (c[it.id] or 0))
			end
		end
	end
end

local function splitTwo(s: string, max: number): (string, string)
	if #s <= max then return s, "" end
	local cut = max
	while cut > 1 and s:sub(cut, cut) ~= " " do cut -= 1 end
	if cut <= 1 then return s, "" end
	return s:sub(1, cut - 1), s:sub(cut + 1)
end

local buyItem -- forward
local function shopAction(it: any, st: string)
	if st == "ok" then
		buyItem(it)
	elseif st == "poor" then
		local wallet = (profile and profile[it.wallet]) or 0
		if it.wallet == "gems" and UIC.offerGems(it.price - wallet, it.name) then return end
		UIC.toast(("Need %s more %s"):format(Format.full(it.price - wallet), if it.wallet == "gems" then "Gems" else "Gold"), "bad")
		local hdr = find(S.Shop, "HeaderInfo")
		if hdr then UI.shake(hdr, 7, 0.3) end
	elseif st == "wear" then
		Net.event("RequestSetCosmetic"):FireServer(it.slot or "case", it.id)
	elseif st == "takeoff" then
		Net.event("RequestSetCosmetic"):FireServer(it.slot or "case", "")
	elseif st == "use" then
		Net.event("RequestUseItem"):FireServer(it.id)
	end
end

buyItem = function(it: any)
	local function go()
		Net.event("RequestBuy"):FireServer(it.id)
	end
	if EconomyConfig.isConsumable(it) then
		go()
	else
		UIC.confirm({
			title = "Are you sure?",
			body1 = ("Buy %s for %s %s?"):format(it.name, Format.full(it.price), if it.wallet == "gems" then "Gems" else "Gold"),
			body2 = if it.kind == "pet" then "Yours to keep, with its ability." else "Yours to keep. Looks only.", -- HOS-HWN-001
			yes = "BUY",
			no = "CANCEL",
		}, go)
	end
end

-- Shop by what you buy (16 Oct, after Huss Valley): Featured, Trails, Egg Cases, Effects, Emotes, Gems.
-- Gold items cost Gold; Gem items show a Gem price and (once its product exists) a Robux price.
local SHOP_TABS = { featured = "TabFeatured", cosmetics = "TabCosmetics", emotes = "TabEmotes", passes = "TabPasses", gems = "TabGems" }
-- Cosmetics (16 Oct, Hunter): Trails, Egg Cases and Effects in one tab; chips filter by EconomyConfig.TAB_OF_KIND
local COS_FILTERS = { all = "FilterAll", trails = "FilterTrails", cases = "FilterCases", effects = "FilterEffects" }
local COS_ORDER = { trails = 1, cases = 2, effects = 3 }
local cosFilter = "all"
local TAG_WORDS = { trail = "ONE MATCH", burst = "LOBBY, ONCE" } -- everything else keeps forever
local SUB_WORDS = { trail = "EGG TRAIL", trailPerm = "EGG TRAIL", case = "EGG CASE", burst = "LOBBY EFFECT", entrance = "ENTRANCE", abilityFx = "ABILITY FX", hatchFx = "HATCH FX", abilitySkin = "RIFT SKIN" }

----------------------------------------------------------------------------------------------- Reward reveal
-- Every buy gets its moment (Hunter, 16 Oct): a shop item (Gold, Gems or Robux) or a Gem pack opens the
-- Reward screen with the hatch reveal's beats: rays spin, the prize pops in, the title slams, sparkles twinkle.
-- (Emote Crate wins keep their own reveal in the Emotes panel; EmoteController gives it the same beats.)
local KEEP_WORDS = {
	trail = "It goes on your egg next match.",
	burst = "Pop it in the lobby. One use.",
	case = "Yours to keep. You're wearing it now.",
	trailPerm = "Yours to keep. It shows in every match.",
	entrance = "Yours to keep. Plays when you arrive in the lobby.",
	abilityFx = "Yours to keep. Your ability effects turn gold.",
	hatchFx = "Yours to keep. Plays at every hatch.",
}
local REWARD_LIME = Color3.fromRGB(150, 240, 60)
local rewardUse: (() -> ())? = nil

-- the title keeps its baked gradient for items; Gem packs flatten it to lime
local function rewardTitleTone(sc: Instance, c: Color3?)
	for _, d in sc:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "Title" then
			if d:GetAttribute("BaseColor") == nil then d:SetAttribute("BaseColor", d.TextColor3) end
			d.TextColor3 = c or d:GetAttribute("BaseColor") :: Color3
			local g = d:FindFirstChildOfClass("UIGradient")
			if g then g.Enabled = c == nil end
		end
	end
end

local function popPair(scope: Instance, name: string, from: number, delay: number)
	for _, d in scope:GetDescendants() do
		if d:IsA("GuiObject") and (d.Name == name or d.Name == name .. "Shadow") then UI.popFrom(d, from, delay) end
	end
end

-- the same beats for reveals other controllers own (EmoteController's crate win)
function UIC.revealBeats(scope: Instance)
	for _, d in scope:GetDescendants() do
		if d:IsA("GuiObject") and d.Name == "Rays" then UI.spin(d, 14) end
		if d:IsA("ImageLabel") and (d.Name == "Sparkle" or d.Name == "SparkleShadow") then
			UI.popFrom(d, 0, 0.25 + math.random() * 0.4)
			UI.breathe(d, true)
		end
	end
	popPair(scope, if find(scope, "TitleBig") then "TitleBig" else "Title", 1.6, 0)
end

function UIC.showReward(r: { icon: string, title: string, name: string, kind: string?, kindColor: Color3?, sub: string?, titleColor: Color3?, use: string?, onUse: (() -> ())?, levelUp: boolean? })
	local sc = S.Reward
	if not sc then
		UIC.toast(r.name, "reward")
		return
	end
	rewardTitleTone(sc, r.titleColor)
	setText(sc, "Title", r.title)
	setText(sc, "ItemName", r.name)
	fitText(sc, "ItemName")
	setText(sc, "KindText", r.kind or "")
	setColor(sc, "KindText", r.kindColor or REWARD_LIME)
	setText(sc, "SubText", r.sub or "")
	setIcon(sc, "Icon", r.icon)
	rewardUse = r.onUse
	local use, nice = find(sc, "BtnUse"), find(sc, "BtnClose")
	if use and use:IsA("GuiObject") then
		use.Visible = r.use ~= nil
		if r.use then setText(use, "Label", r.use) end
	end
	-- alone, NICE! moves to the middle of the pair (same as the hatch reveal)
	if use and nice and use:IsA("GuiObject") and nice:IsA("GuiObject") then
		if nice:GetAttribute("PairHome") == nil then
			nice:SetAttribute("PairHome", nice.Position)
			nice:SetAttribute("PairMid", nice.Position:Lerp(use.Position, 0.5))
		end
		local at = (if r.use then nice:GetAttribute("PairHome") else nice:GetAttribute("PairMid")) :: UDim2
		nice.Position = at
		nice:SetAttribute("JuiceRest", at)
	end
	if UI.current() ~= "Reward" then UI.open("Reward", { keepHistory = true }) end
	-- motion: rays spin, the prize pops, the title slams, the words follow, sparkles twinkle in
	-- sound: a buy rings the till then the bells; a level-up gets the bells and applause (no till)
	if r.levelUp then
		Sound.play("evolve")
		Sound.play("applause")
	else
		Sound.play("purchase")
	end
	Sound.duck(0.25, 2.5)
	task.delay(0.18, function() Sound.play("reveal") end)
	for _, d in sc:GetDescendants() do
		if d:IsA("GuiObject") and d.Name == "Rays" then UI.spin(d, 14) end
	end
	popPair(sc, "Icon", 0, 0.08)
	popPair(sc, "TitleBig", 1.6, 0)
	popPair(sc, "ItemName", 0.4, 0.22)
	popPair(sc, "KindText", 0.4, 0.3)
	popPair(sc, "SubText", 0.4, 0.36)
	for _, d in sc:GetDescendants() do
		if d:IsA("ImageLabel") and (d.Name == "Sparkle" or d.Name == "SparkleShadow") then
			UI.popFrom(d, 0, 0.3 + math.random() * 0.4)
			UI.breathe(d, true)
		end
	end
	local icon = find(sc, "Icon")
	if icon and icon:IsA("GuiObject") then task.delay(0.6, function() UI.breathe(icon :: GuiObject, true) end) end
end

-- a shop item just bought (Gold, Gems or Robux)
local function rewardItem(it: any)
	local consumable = EconomyConfig.isConsumable(it)
	local r: any = {
		icon = SHOP_ICON[it.id] or "gift",
		title = if consumable then "ADDED!" else "UNLOCKED!",
		name = it.name,
		kind = SUB_WORDS[it.kind] or "",
		sub = KEEP_WORDS[it.kind] or "Yours to keep.",
	}
	-- a bought case is worn straight away (ProfileLogic.buy); a burst can pop right here
	if it.kind == "burst" then
		r.use, r.onUse = "USE NOW", function() Net.event("RequestUseItem"):FireServer(it.id) end
	end
	UIC.showReward(r)
end

-- LEVEL UP!: waits for the results screen to close, then the reward reveal with the level-up pay
local LEVEL_SKY = Color3.fromRGB(110, 200, 255)
local function rewardLevelUp(from: number, to: number)
	task.spawn(function()
		local t0 = os.clock()
		while (resultsOpen or UI.current() == "Results") and os.clock() - t0 < 30 do task.wait(0.5) end
		local R = EconomyConfig.LEVEL_REWARD
		local gold, gems = 0, 0
		for L = from + 1, to do
			gold += R.gold
			if L % R.gemsEvery == 0 then gems += R.gems end
		end
		UIC.showReward({
			icon = "star",
			title = "LEVEL UP!",
			titleColor = LEVEL_SKY,
			levelUp = true,
			name = "Level " .. to,
			kind = ("+%s GOLD"):format(Format.full(gold)) .. (if gems > 0 then ("  ·  +%d GEMS"):format(gems) else ""),
			kindColor = Color3.fromRGB(255, 210, 58),
			sub = ("Keep playing to reach Level %d."):format(to + 1),
		})
	end)
end

-- a game pass: VIP or 2x XP
local function rewardPass(key: string)
	local pass = EconomyConfig.pass(key)
	if not pass then return end
	UIC.showReward({
		icon = if iconId(pass.icon) ~= "" then pass.icon elseif key == "vip" then "crown" else "star",
		title = "UNLOCKED!",
		name = pass.name,
		kind = "GAME PASS  ·  FOREVER",
		kindColor = Color3.fromRGB(255, 210, 58),
		sub = pass.desc,
	})
end

-- a Gem pack bought with Robux: its own art (gempack1..6), the Gems count up behind
local function rewardGems(gems: number)
	local idx = 1
	for i, p in ipairs(EconomyConfig.GEM_PACKS) do
		if p.gems == gems then idx = i end
	end
	UIC.showReward({
		icon = if iconId("gempack" .. idx) ~= "" then "gempack" .. idx else "gem",
		title = "GEMS ADDED!",
		titleColor = REWARD_LIME,
		name = ("+%s Gems"):format(Format.full(gems)),
		kind = "THANK YOU FOR YOUR SUPPORT!",
		kindColor = Color3.fromRGB(255, 210, 58),
		sub = "Spend them on looks and Emote Crates.",
	})
end

-- a tag pill takes new words and grows or shrinks to fit them (the export sized it for its sample text,
-- so "THIS WEEK'S COLOUR" ran past a pill made for "ONE MATCH")
local function tagText(frame: Instance?, text: string)
	if not frame then return end
	local label: TextLabel? = nil
	for _, l in frame:GetDescendants() do
		if l:IsA("TextLabel") then
			l.Text = text
			if not l.Name:match("Shadow$") then label = l end
		end
	end
	if not label or not frame:IsA("GuiObject") then return end
	local lb = label :: TextLabel
	if frame:GetAttribute("TagText") == text then return end
	frame:SetAttribute("TagText", text)
	task.spawn(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = lb.FontFace
		params.Size = lb.TextSize
		params.Width = 4000
		local ok, size = pcall(function() return TextService:GetTextBoundsAsync(params) end)
		if not ok or frame:GetAttribute("TagText") ~= text then return end
		local w = math.ceil(size.X) + 2
		for _, l in frame:GetDescendants() do
			if l:IsA("TextLabel") then l.Size = UDim2.new(l.Size.X.Scale, w, l.Size.Y.Scale, l.Size.Y.Offset) end
		end
		local f = frame :: GuiObject
		f.Size = UDim2.new(f.Size.X.Scale, w + lb.Position.X.Offset * 2, f.Size.Y.Scale, f.Size.Y.Offset)
	end)
end

-- a centre-anchored (juiced) button keeps its left edge when it is resized
local function widen(b: Instance?, w: number)
	if not b or not b:IsA("GuiObject") then return end
	if b:GetAttribute("FullW") == w then return end
	local left = b.Position.X.Offset - b.Size.X.Offset * b.AnchorPoint.X
	b.Size = UDim2.new(b.Size.X.Scale, w, b.Size.Y.Scale, b.Size.Y.Offset)
	b.Position = UDim2.new(b.Position.X.Scale, left + w * b.AnchorPoint.X, b.Position.Y.Scale, b.Position.Y.Offset)
	if b:GetAttribute("JuiceRest") then b:SetAttribute("JuiceRest", b.Position) end
	b:SetAttribute("FullW", w)
	for _, c in b:GetDescendants() do
		if c:IsA("ImageLabel") and c.Name == "Art" then c.Size = UDim2.new(1, 0, c.Size.Y.Scale, c.Size.Y.Offset) end
	end
end

local function canRobux(it: any): boolean
	return PURCHASES and it.productId ~= nil
end

local function promptItem(it: any)
	if not canRobux(it) then return end
	Sound.play("click")
	pcall(function()
		MarketplaceService:PromptProductPurchase(player, it.productId)
	end)
end

-- short on Gems: the item's Robux price if it has one, else the smallest Gem pack that covers it
local function poorItem(it: any)
	local wallet = (profile and profile[it.wallet]) or 0
	if it.wallet == "gems" and canRobux(it) then
		UIC.confirm({
			title = "Not enough Gems",
			body1 = ("You need %s more Gems for %s."):format(Format.full(it.price - wallet), it.name),
			body2 = ("Get it now for %s Robux?"):format(Format.full(it.robux)),
			yes = "BUY",
			no = "NOT NOW",
		}, function() promptItem(it) end)
		return
	end
	if it.wallet == "gems" and UIC.offerGems(it.price - wallet, it.name) then return end
	UIC.toast(("Need %s more %s"):format(Format.full(it.price - wallet), if it.wallet == "gems" then "Gems" else "Gold"), "bad")
	local hdr = find(S.Shop, "HeaderInfo")
	if hdr then UI.shake(hdr, 7, 0.3) end
end

-- the price / state buttons of a card or featured card, for item `it`
local function fillButtons(scope: Instance, it: any)
	local st = itemState(it)
	local buying = st == "ok" or st == "poor"
	local price, poor, rob = find(scope, "BtnPrice"), find(scope, "BtnPoor"), find(scope, "BtnRobux")
	if price and not price:GetAttribute("HalfW") then
		price:SetAttribute("HalfW", (price :: GuiObject).Size.X.Offset)
		if rob then
			local r = rob :: GuiObject
			local full = (r.Position.X.Offset + r.Size.X.Offset * (1 - r.AnchorPoint.X)) - ((price :: GuiObject).Position.X.Offset - (price :: GuiObject).Size.X.Offset * (price :: GuiObject).AnchorPoint.X)
			price:SetAttribute("FullSpan", full)
		end
	end
	local robux = canRobux(it)
	local w = if robux or not price then (price and price:GetAttribute("HalfW")) else (price:GetAttribute("FullSpan") or price:GetAttribute("HalfW"))
	if w then
		widen(price, w)
		widen(poor, w)
	end
	if price then (price :: GuiObject).Visible = buying and st == "ok" end
	if poor then (poor :: GuiObject).Visible = buying and st == "poor" end
	if rob then (rob :: GuiObject).Visible = buying and robux end
	for _, b in { price, poor } do
		if b then setText(b, "Price", Format.full(it.price)) end
	end
	if rob and robux then setText(rob, "RobuxPrice", Format.full(it.robux)) end
	for s2, nm in pairs({ owned = "BtnOwned", wear = "BtnWear", takeoff = "BtnTakeOff", use = "BtnUse" }) do
		local b = find(scope, nm)
		if b and b:IsA("GuiObject") then b.Visible = st == s2 end
	end
	if st == "use" then
		local c = (profile and profile.cosmetics and profile.cosmetics.consumables) or {}
		setText(find(scope, "BtnUse"), "UseCount", "x" .. (c[it.id] or 0))
	end
	local have = (profile and profile[it.wallet]) or 0
	setText(scope, "Have", if st == "owned" or st == "wear" or st == "takeoff" then "Yours to keep" else ("You have %s %s"):format(Format.full(have), if it.wallet == "gems" then "Gems" else "Gold"))
end

local function wireButtons_(scope: Instance, it: any)
	if scope:GetAttribute("Wired") == it.id then return end
	scope:SetAttribute("Wired", it.id)
	for _, b in scope:GetDescendants() do
		if b:IsA("GuiButton") and b:GetAttribute("Button") then UI.juicy(b) end
	end
	local itr = it
	onClick(find(scope, "BtnPrice"), function() buyItem(itr) end)
	onClick(find(scope, "BtnPoor"), function() poorItem(itr) end)
	onClick(find(scope, "BtnRobux"), function() promptItem(itr) end)
	onClick(find(scope, "BtnWear"), function() shopAction(itr, "wear") end)
	onClick(find(scope, "BtnTakeOff"), function() shopAction(itr, "takeoff") end)
	onClick(find(scope, "BtnUse"), function() shopAction(itr, "use") end)
end

-- seconds to the next Monday 00:00 UTC (the weekly colourway changes then)
local function weeklyLeft(): number
	local now = os.time()
	local wd = tonumber(os.date("!%w", now)) or 0 -- 0 = Sunday
	local secs = (tonumber(os.date("!%H", now)) or 0) * 3600 + (tonumber(os.date("!%M", now)) or 0) * 60 + (tonumber(os.date("!%S", now)) or 0)
	local days = (8 - wd) % 7
	if days == 0 then days = 7 end
	return days * 86400 - secs
end

local function fillCard(card: Instance, it: any)
	setIcon(card, "Icon", SHOP_ICON[it.id] or "gift")
	setText(card, "ItemName", it.name)
	setText(card, "Sub", SUB_WORDS[it.kind] or "")
	local l1, l2 = splitTwo(it.desc or "", 30)
	setText(card, "Desc", l1)
	setText(card, "Desc2", l2)
	tagText(find(card, "KindTag"), if it.id == EconomyConfig.FEATURED.weekly then "THIS WEEK'S COLOUR" else (TAG_WORDS[it.kind] or "KEEP FOREVER"))
	fillButtons(card, it)
	wireButtons_(card, it)
end

local PASS_CARDS = { vip = "PassVip", xp2x = "PassXp2x" }
local function refreshShop()
	local sc = S.Shop
	if not sc or not profile then return end
	if shopTab == "gold" then shopTab = "featured" end -- old tab names (lobby stalls)
	if shopTab == "getgems" then shopTab = "gems" end
	if COS_FILTERS[shopTab] then cosFilter, shopTab = shopTab, "cosmetics" end -- old tab names open the filtered Cosmetics
	if not SHOP_TABS[shopTab] or ((shopTab == "gems" or shopTab == "passes") and not PURCHASES) then shopTab = "featured" end
	for key, nm in pairs(SHOP_TABS) do
		local t = find(sc, nm)
		setDual(t, shopTab == key)
		if (key == "gems" or key == "passes") and t and t:IsA("GuiObject") then t.Visible = PURCHASES end
	end
	local pages = { PageFeatured = shopTab == "featured", PageItems = shopTab == "cosmetics", CosFilters = shopTab == "cosmetics",
		PageEmotes = shopTab == "emotes", PagePasses = shopTab == "passes", GetGemsPage = shopTab == "gems" }
	for nm, on in pairs(pages) do
		local pg = find(sc, nm)
		if pg and pg:IsA("GuiObject") then pg.Visible = on end
	end
	setText(sc, "GoldText", Format.full(profile.gold or 0))
	setText(sc, "GemsText", Format.full(profile.gems or 0))
	if shopTab == "featured" then
		for slot, key in pairs(require(script.Parent.HalloweenShopUI).slots(sc)) do -- HOS-HWN-001: Halloween cards until Nov 1, else FeatA / FeatB
			local card = find(sc, slot)
			local it = EconomyConfig.item(EconomyConfig.FEATURED[key])
			if card and it then
				setText(card, "Title", string.upper(it.name))
				setText(card, "Tagline", it.desc or "")
				setIcon(card, "Icon", SHOP_ICON[it.id] or "gift")
				if key == "weekly" then
					local left = weeklyLeft()
					tagText(find(card, "FeatTag"), ("THIS WEEK'S COLOURWAY  ·  NEW IN %dD %dH"):format(left // 86400, (left % 86400) // 3600))
				end
				fillButtons(card, it)
				wireButtons_(card, it)
			end
		end
	elseif pages.PageItems then
		local page = find(sc, "PageItems")
		if not page then return end
		local protoG = find(find(page, "ProtoGold"), "Card")
		local protoM = find(find(page, "ProtoGems"), "Card")
		for _, n in { "ProtoGold", "ProtoGems" } do
			local h = page:FindFirstChild(n)
			if h and h:IsA("GuiObject") then h.Visible = false end
		end
		for key, nm in pairs(COS_FILTERS) do setDual(find(sc, nm), cosFilter == key) end
		local items = {}
		for _, it in ipairs(EconomyConfig.SHOP) do
			local cat = EconomyConfig.TAB_OF_KIND[it.kind]
			if COS_ORDER[cat] and (cosFilter == "all" or cat == cosFilter) then table.insert(items, it) end
		end
		table.sort(items, function(a, b)
			local ca, cb = COS_ORDER[EconomyConfig.TAB_OF_KIND[a.kind]], COS_ORDER[EconomyConfig.TAB_OF_KIND[b.kind]]
			if ca ~= cb then return ca < cb end
			return (table.find(EconomyConfig.SHOP, a) or 0) < (table.find(EconomyConfig.SHOP, b) or 0)
		end)
		-- one row of cards across the 1528 px page: centred while it fits, scrolls sideways once it doesn't
		local rowF = page:FindFirstChild("Row") :: ScrollingFrame?
		if not rowF then
			local r = Instance.new("ScrollingFrame")
			r.Name = "Row"
			r.BackgroundTransparency = 1
			r.BorderSizePixel = 0
			r.Position = UDim2.fromOffset(0, 0)
			r.Size = UDim2.fromOffset(1528, 588 + 16)
			r.ScrollingDirection = Enum.ScrollingDirection.X
			r.ScrollBarThickness = 8
			r.ScrollBarImageColor3 = Color3.fromRGB(255, 196, 60)
			r.VerticalScrollBarInset = Enum.ScrollBarInset.None
			r.CanvasSize = UDim2.fromOffset(1528, 0)
			r.Parent = page
			rowF = r
		end
		local row = rowF :: ScrollingFrame
		local total = #items * 360 + math.max(0, #items - 1) * 24
		local fits = total <= 1528
		row.CanvasSize = UDim2.fromOffset(math.max(1528, total), 0)
		row.ScrollBarImageTransparency = if fits then 1 else 0
		if row:GetAttribute("Filter") ~= cosFilter then
			row:SetAttribute("Filter", cosFilter)
			row.CanvasPosition = Vector2.zero
		end
		local x0 = if fits then (1528 - total) // 2 else 0
		local keep = {}
		for i, it in ipairs(items) do
			local nm = "Card_" .. it.id
			local card = row:FindFirstChild(nm)
			local proto = if it.wallet == "gems" then protoM else protoG
			if not card and proto then
				card = proto:Clone()
				card.Name = nm
				card:SetAttribute("Runtime", true)
				card:SetAttribute("Wired", nil)
				card.Parent = row
			end
			if card and card:IsA("GuiObject") then
				keep[card] = true
				card.Visible = true
				card.Position = UDim2.fromOffset(x0 + (i - 1) * 384, 0)
				fillCard(card, it)
			end
		end
		for _, c in row:GetChildren() do
			if c:GetAttribute("Runtime") and not keep[c] then c.Visible = false end
		end
	elseif shopTab == "emotes" then
		local gems = profile.gems or 0
		setText(sc, "CrateSub", ("One of %d emotes per crate  ·  every chance shown inside"):format(UIC.emoteCount or 51))
		local rb = find(sc, "BtnCrateRobux")
		if rb and rb:IsA("GuiObject") then rb.Visible = PURCHASES and UIC.crateProduct ~= nil and not UIC.crateBlocked end
		local gb = find(sc, "BtnCrateGems")
		if gb and gb:IsA("GuiObject") then gb.Visible = not UIC.crateBlocked end
		setText(sc, "CrateGemsLabel", Format.full(gems))
	elseif shopTab == "passes" then
		for key, slot in pairs(PASS_CARDS) do
			local card = find(sc, slot)
			local pass = EconomyConfig.pass(key)
			if card and pass then
				local owned = player:GetAttribute(pass.attr) == true
				local buy, own = find(card, "BtnBuy"), find(card, "BtnOwned")
				if buy and buy:IsA("GuiObject") then buy.Visible = not owned end
				if own and own:IsA("GuiObject") then own.Visible = owned end
				setText(card, "Price", Format.full(pass.robux))
				setText(card, "Have", if owned then "You own this pass. Thank you!" else "Bought once, yours on every server.")
				if iconId(pass.icon) ~= "" then setIcon(card, "Icon", pass.icon) end
			end
		end
	elseif shopTab == "gems" then
		local packs = find(sc, "GetGemsPage")
		for i, pack in ipairs(EconomyConfig.GEM_PACKS) do
			local card = find(packs, "Pack" .. i)
			if card and card:IsA("GuiObject") then
				card.Visible = pack.productId ~= nil
				setText(card, "Amount", Format.full(pack.gems))
				setText(find(card, "BtnBuy"), "Price", Format.full(pack.robux))
				local tagF = find(card, "Tag")
				if tagF and tagF:IsA("GuiObject") then
					tagF.Visible = pack.tag ~= nil
					if pack.tag then tagText(tagF, pack.tag) end
				end
				if iconId("gempack" .. i) ~= "" then setIcon(card, "Icon", "gempack" .. i) end
			end
		end
	end
end

----------------------------------------------------------------------------------------------- Stats + Settings
local STAT_ROWS = {
	{ "Wins", function(s) return Format.full(s.wins or 0) end },
	{ "Safe crossings", function(s) return Format.full(s.successfulCrossings or 0) end },
	{ "Eggs stolen", function(s) return Format.full(s.captures or 0) end },
	{ "Best egg", function(s) return "Level " .. (s.lifetimeBestTier or 1) end },
	{ "Pets hatched", function(s) return Format.full(s.petsHatched or 0) end },
	{ "Started as Catcher", function(s) return Format.full(s.timesFirstHunter or 0) end },
	{ "Gold earned", function(s) return Format.full(s.goldEarned or 0) end },
	{ "Gems earned", function(s) return Format.full(s.gemsEarned or 0) end },
	{ "Matches played", function(s) return Format.full(s.matchesCompleted or 0) end },
}
local function refreshStats()
	local sc = S.Stats
	if not sc or not profile then return end
	local st = profile.stats or {}
	for i, r in ipairs(STAT_ROWS) do
		local tile = find(sc, "Stat" .. i)
		if tile then
			setText(tile, "Label", r[1])
			setText(tile, "Value", r[2](st))
		end
	end
end

local settingsTab = "game"
local function refreshSettings()
	local sc = S.Settings
	if not sc then return end
	local rows = { { "Row1", "sfx" }, { "RowMusic", "music" }, { "Row2", "reduceEffects" }, { "Row3", "showHints" } }
	for _, r in ipairs(rows) do
		local row = find(sc, r[1])
		if row then setDual(row:FindFirstChild("Toggle"), settings[r[2]] ~= false and settings[r[2]] ~= nil) end
	end
	local r4 = find(sc, "Row4")
	if r4 then setDual(r4:FindFirstChild("Toggle"), player:GetAttribute("EOS_Volunteer") == true) end
	local ctl = settingsTab == "controls"
	for _, n in ipairs({ "Row1", "RowMusic", "Row2", "Row3", "Row4", "Row5" }) do
		local row = find(sc, n)
		if row then row.Visible = not ctl and (n ~= "Row4" or PRIVATE) end
	end
	-- public servers: no Volunteer row, so UI Colour moves up into its place
	local r5 = find(sc, "Row5")
	if r4 and r5 and r4:IsA("GuiObject") and r5:IsA("GuiObject") and not PRIVATE and not r5:GetAttribute("Moved") then
		r5:SetAttribute("Moved", true)
		r5.Position = r4.Position
	end
	local page = find(sc, "ControlsPage")
	if page then page.Visible = ctl end
	setDual(find(sc, "TabGame"), not ctl)
	setDual(find(sc, "TabControls"), ctl)
	applyUiColour()
end

----------------------------------------------------------------------------------------------- Results
local function refreshRecipe()
	local sc = S.Results
	local you = resultsData and resultsData.you
	if not sc or not you then return end
	local m = you.material or "common"
	local base = costFor(m, false)
	local n = have(m)
	setBar(find(sc, "RecipeBar"), n / base)
	setText(sc, "RecipeText", if n >= base then "READY TO HATCH!" else ("%s pieces %d / %d"):format(materialName(m), n, base))
end

function UIC.closeResults()
	if not resultsOpen then return end
	resultsOpen = false
	if UI.current() == "Results" then UI.close() end
end

local function showResults(data: any)
	local sc = S.Results
	if not sc then return end
	resultsShownAt = os.clock()
	resultsData = data
	-- banner
	local runners = data.team == "RUNNERS"
	setText(sc, "TeamBanner", if runners then "RUNNERS WIN!" else "CATCHERS WIN!")
	setColor(sc, "TeamBanner", if runners then Color3.fromRGB(106, 216, 255) else Color3.fromRGB(255, 90, 90))
	setText(sc, "Reason", REASONS[data.endReason] or "Match over")
	local tn = find(sc, "TestNote")
	if tn then
		local holder = if tn.Parent and tn.Parent ~= sc and tn.Parent.Name == "F" then tn.Parent else tn
		holder.Visible = data.isTest == true
		tn.Visible = true
		local tsh = find(sc, "TestNoteShadow")
		if tsh then tsh.Visible = true end
	end
	-- podium: design order is 2nd (left), 1st (middle), 3rd (right)
	local slotFor = { [1] = 2, [2] = 1, [3] = 3 }
	local pod = find(sc, "Podium")
	for place = 1, 3 do
		local i = slotFor[place]
		local entry
		for _, r in ipairs(data.topRunners or {}) do
			if r.place == place then entry = r end
		end
		local tile, step = pod and pod:FindFirstChild("Podium" .. i), pod and pod:FindFirstChild("Step" .. i)
		if tile then show(tile, entry ~= nil) end
		if step then step.Visible = entry ~= nil end
		if entry and tile and step then
			local uid = if entry.npcSlot then NpcSkins.userIdForSlot(entry.npcSlot) else entry.userId
			local name = if entry.npcSlot then npcName(entry.npcSlot, entry.name) else entry.name
			if entry.userId == player.UserId then name = "You" end
			if uid and uid > 0 then
				setIcon(tile, "Icon", ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(uid))
			end
			require(script.Parent:WaitForChild("BotHeadshot")).fill(tile:FindFirstChild("Icon", true), if uid and uid > 0 then nil else entry.npcSlot) -- HOS-BOT-001: an NPC shows its own look
			setText(step, "Place", ({ "1st", "2nd", "3rd" })[place])
			setText(step, "PlayerName", name or "?")
		end
	end
	-- top thief
	local th = data.topThief
	local thief = find(sc, "Thief")
	if thief then thief.Visible = th ~= nil end
	if th then
		setText(sc, "ThiefName", if th.npcSlot then npcName(th.npcSlot, th.name) else (if th.userId == player.UserId then "You" else th.name))
		setText(sc, "ThiefCount", ("stole %d egg%s"):format(th.captures or 0, if (th.captures or 0) == 1 then "" else "s"))
	end
	-- your rewards
	local you = data.you
	local yourCard = find(sc, "You")
	if yourCard then yourCard.Visible = you ~= nil end
	if you then
		local parts = table.clone(you.goldParts or {})
		-- four lines on the card: with the 2x Gold pass line a fifth part folds into the one before it
		while #parts > 4 do
			local a, b = parts[#parts - 2], parts[#parts - 1]
			parts[#parts - 2] = { label = "BONUSES", amount = (a.amount or 0) + (b.amount or 0) }
			table.remove(parts, #parts - 1)
		end
		for i = 1, 4 do
			local line = find(sc, "Line" .. i)
			local p = parts[i]
			if line then
				line.Visible = p ~= nil
				if p then
					local label = p.label
					if label == "CROSSINGS" and (you.crossings or 0) > 0 then label = ("CROSSINGS  x%d"):format(you.crossings) end
					setText(line, "LineLabel", label)
					setText(line, "LineAmount", "+" .. p.amount)
				end
			end
		end
		-- no reward lines (practice match, or a match spent standing still): fill the gap instead of leaving it empty
		local l1, l4 = find(sc, "Line1"), find(sc, "Line4")
		if l1 and l4 and l1:IsA("GuiObject") and l4:IsA("GuiObject") and l1.Parent then
			local none = l1.Parent:FindFirstChild("NoLines") :: TextLabel?
			if not none then
				local n = Instance.new("TextLabel")
				n.Name = "NoLines"
				n.BackgroundTransparency = 1
				n.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
				n.TextColor3 = Color3.fromRGB(210, 210, 216)
				n.TextSize = 30
				n.ZIndex = l1.ZIndex + 1
				local st = Instance.new("UIStroke")
				st.Color = Color3.fromRGB(5, 5, 6)
				st.Thickness = 2
				st.Parent = n
				local top = l1.Position.Y.Offset - l1.AnchorPoint.Y * l1.Size.Y.Offset
				local bottom = l4.Position.Y.Offset + (1 - l4.AnchorPoint.Y) * l4.Size.Y.Offset
				n.Position = UDim2.fromOffset(l1.Position.X.Offset - l1.AnchorPoint.X * l1.Size.X.Offset, top)
				n.Size = UDim2.fromOffset(l1.Size.X.Offset, bottom - top)
				n.Parent = l1.Parent
				none = n
			end
			local nl = none :: TextLabel
			nl.Text = if #parts == 0 then (if data.isTest then "Practice match: nothing to bank" else "No gold this match") else ""
			nl.Visible = #parts == 0
			if #parts == 0 then UI.popFrom(nl, 0.6, 0.3) end
		end
		UI.setText(sc, "GoldTotal", "+0")
		UI.countTo("resultsGold", 0, sc, "GoldTotal", function(v) return "+" .. math.floor(v + 0.5) end)
		task.delay(0.6, function()
			UI.countTo("resultsGold", you.gold or 0, sc, "GoldTotal", function(v) return "+" .. math.floor(v + 0.5) end)
		end)
		local gems = find(sc, "GemsSlot")
		if gems then
			show(gems, (you.gems or 0) > 0)
			setText(gems, "CountText", "x" .. (you.gems or 0))
		end
		local piece = find(sc, "PieceSlot")
		if piece then
			show(piece, you.material ~= nil)
			if you.material then
				setIcon(piece, "Icon", "piece_" .. you.material)
				setText(piece, "CountText", "x1")
				setText(piece, "LabelText", materialName(you.material))
			end
		end
		local lvl = you.securedTier or 1
		setIcon(sc, "BestEggIcon", eggSlug(lvl))
		setText(sc, "BestEgg", ("Best egg: Level %d"):format(lvl))
		local tc = TierConfig.get(lvl)
		if tc and tc.text then setColor(sc, "BestEgg", tc.text) end
		local pays = if you.material then ("pays 1 %s piece"):format(materialName(you.material)) else "no piece this match"
		if you.nearMiss and you.nearMiss ~= "" then
			pays = pays .. "  ·  " .. string.lower((you.nearMiss:gsub("TIER", "LEVEL")))
		end
		setText(sc, "BestEggPays", pays)
		local inel = find(sc, "Ineligible")
		if inel then
			local h = if inel.Parent and inel.Parent.Name == "F" then inel.Parent else inel
			h.Visible = you.eligible == false
			inel.Visible = true
		end
		refreshRecipe()
	end
	resultsOpen = true
	UI.open("Results")
	-- motion: rays spin, title slams, podium rises, rewards card slides in
	for _, d in sc:GetDescendants() do
		if d:IsA("ImageLabel") and d.Name == "Rays" then UI.spin(d, 14) end
	end
	local tb = find(sc, "TeamBannerBig") or find(sc, "TeamBanner")
	if tb and tb:IsA("GuiObject") then UI.popFrom(tb, 1.8) end
	if pod then
		for i = 1, 3 do
			local t, s = pod:FindFirstChild("Podium" .. i), pod:FindFirstChild("Step" .. i)
			local delay = ({ 0.35, 0.15, 0.55 })[i]
			if s and s.Visible then UI.slideIn(s, 0, 260, delay, 0.55) end
			if t and t.Visible then UI.slideIn(t, 0, 260, delay, 0.6) end
		end
	end
	if yourCard and yourCard:IsA("GuiObject") and yourCard.Visible then UI.slideIn(yourCard, 420, 0, 0.25, 0.6) end
	if thief and thief:IsA("GuiObject") and thief.Visible then UI.slideIn(thief, -500, 0, 0.6, 0.5) end
	Sound.setMusic("results")
	if data.you then
		Sound.duck(0.2, 6)
		Sound.play(if data.you.win then "win" else "lose")
	end
	task.delay(0.9, function() Sound.play("reward") end)
end

----------------------------------------------------------------------------------------------- panels
function UIC.refreshPanels()
	refreshQuests()
	if UI.current() == "Incubator" then refreshIncubator() end
	if UI.current() == "Pets" then refreshPets() end
	if UI.current() == "Shop" then refreshShop() end
	refreshStats()
	refreshSettings()
	if UIC.onEmotesRefresh then
		pcall(UIC.onEmotesRefresh, profile, false)
	end
end

local function refreshOne(name: string)
	if name == "Quests" then refreshQuests()
	elseif name == "Incubator" then refreshIncubator()
	elseif name == "Pets" then refreshPets()
	elseif name == "Shop" then refreshShop()
	elseif name == "Stats" then refreshStats()
	elseif name == "Settings" then refreshSettings() end
end

-- panel entrance: the panel's wells and buttons arrive in reading order, a beat apart, on top of
-- UI's own pop (frames rise into place, buttons scale in so their hover springs keep their rest)
local SKIP_CASCADE = { Art = true, ShadowRing = true, SelRing = true, Glow = true, GlowMono = true, Rays = true }
local function cascade(name: string)
	if settings.reduceEffects or name == "Results" or name == "Hatch" or name == "Reward" then return end
	local sc = S[name]
	if not sc then return end
	local items = {}
	for _, top in sc:GetChildren() do
		local panel = top:IsA("GuiObject") and top.Name ~= "Dim" and top:FindFirstChild("Panel")
		if panel then
			for _, g in panel:GetChildren() do
				if g:IsA("GuiObject") and g.Visible and not SKIP_CASCADE[g.Name] and not g.Name:match("Sel$") then
					table.insert(items, g)
				end
			end
		end
	end
	table.sort(items, function(a, b)
		local ay, by = a.AbsolutePosition.Y, b.AbsolutePosition.Y
		if math.abs(ay - by) > 24 then return ay < by end
		return a.AbsolutePosition.X < b.AbsolutePosition.X
	end)
	for i, g in ipairs(items) do
		local delay = 0.06 + math.min(i - 1, 12) * 0.035
		if g:IsA("GuiButton") then
			UI.popFrom(g, 0.7, delay)
		else
			UI.slideIn(g, 0, 22, delay, 0.45)
			UI.popFrom(g, 0.94, delay)
		end
	end
end

-- images stream in on first use, so a panel opened cold drew piece by piece. Everything preloads at join;
-- a panel opened before that finishes waits (at most 0.6 s) for its own images first
local warmed: { [string]: boolean } = {}
local function warm(name: string)
	if warmed[name] or not S[name] then return end
	warmed[name] = true
	local list = {}
	for _, d in S[name]:GetDescendants() do
		if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" then table.insert(list, d.Image) end
	end
	local done = false
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync(list) end)
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 0.6 do task.wait() end
end
local function preloadAll()
	task.spawn(function()
		-- what's on screen first, then every panel, then every icon/art the controller may swap in
		local order = { "HUD", "MatchHUD" }
		for n in pairs(S) do
			if n ~= "HUD" and n ~= "MatchHUD" then table.insert(order, n) end
		end
		for _, n in ipairs(order) do
			local list = {}
			for _, d in S[n]:GetDescendants() do
				if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" then table.insert(list, d.Image) end
			end
			pcall(function() ContentProvider:PreloadAsync(list) end)
			warmed[n] = true
		end
		local rest = {}
		for _, group in ipairs({ assets.icons or {}, assets.art or {} }) do
			for _, id in pairs(group) do
				if id ~= "" then table.insert(rest, id) end
			end
		end
		pcall(function() ContentProvider:PreloadAsync(rest) end)
	end)
end

function UIC.open(name: string)
	if not S[name] then return end
	if LOBBY_ONLY[name] and inMatch() then
		UIC.toast("That opens between matches", "info", true)
		return
	end
	if UI.current() == name then
		UI.close()
		return
	end
	warm(name)
	refreshOne(name)
	local hook = UIC.onOpen[name]
	if hook then
		local ok, err = pcall(hook)
		if not ok then warn("[EOSUI] open " .. name .. ": " .. tostring(err)) end
	end
	UI.open(name)
	Sound.play("open")
	-- gamepad / TV: select the panel's first button
	local dev = deviceClass()
	if dev == "gamepad" or dev == "console" then
		for _, d in S[name]:GetDescendants() do
			if d:IsA("GuiButton") and d.Visible and d.Name ~= "CloseButton" and d:GetAttribute("Button") then
				GuiService.SelectedObject = d
				break
			end
		end
	end
end

function UIC.close()
	if resultsOpen and UI.current() == "Results" then
		UIC.closeResults()
		return
	end
	UI.close()
	GuiService.SelectedObject = nil
end

function UIC.openName(): string?
	return UI and UI.current()
end

function UIC.isOpen(): boolean
	return UI ~= nil and UI.anyOpen()
end

function UIC.juicy(b: GuiButton, fn: (() -> ())?)
	UI.juicy(b)
	if fn then b.Activated:Connect(fn) end
end

----------------------------------------------------------------------------------------------- Robux Gem packs (HOS-GEMS-001)
-- Roblox's purchase window; PurchaseService grants the Gems from the receipt (never from anything sent here)
function UIC.buyGems(pack: any)
	if not PURCHASES or not pack or not pack.productId then return end
	Sound.play("click")
	pcall(function()
		MarketplaceService:PromptProductPurchase(player, pack.productId)
	end)
end

-- the Shop on its Gems tab
function UIC.openGemShop()
	if not PURCHASES then return end
	shopTab = "gems"
	selItem = nil
	if UI.current() == "Shop" then
		refreshShop()
	else
		UIC.open("Shop")
	end
end

-- an Emote Crate opened with Robux (EmoteController fills crateProduct / crateBlocked / showEmoteCrate)
UIC.crateProduct = nil :: number?
UIC.crateBlocked = false
UIC.emoteCount = 51
UIC.showEmoteCrate = nil :: (() -> ())?
function UIC.buyCrate()
	if not PURCHASES or not UIC.crateProduct or UIC.crateBlocked then return end
	Sound.play("click")
	pcall(function()
		MarketplaceService:PromptProductPurchase(player, UIC.crateProduct)
	end)
end

-- not enough Gems for something: offer the smallest pack that covers it (true = offered)
function UIC.offerGems(need: number, forWhat: string?): boolean
	if not PURCHASES or need <= 0 then return false end
	local pick = nil -- packs run small to big: the first that covers it, else the biggest
	for _, pack in ipairs(EconomyConfig.GEM_PACKS) do
		if pack.productId then
			pick = pack
			if pack.gems >= need then break end
		end
	end
	if not pick then return false end
	UIC.confirm({
		title = "Not enough Gems",
		body1 = ("You need %s more Gems%s."):format(Format.full(need), if forWhat then " for " .. forWhat else ""),
		body2 = ("Get %s Gems for %s Robux?"):format(Format.full(pick.gems), Format.full(pick.robux)),
		yes = "GET GEMS",
		no = "NOT NOW",
	}, function()
		UIC.buyGems(pick)
	end)
	return true
end

----------------------------------------------------------------------------------------------- wiring
local function wireButtons()
	-- generic Opens buttons (pills, rail) go through UIC.open so lobby-only rules apply
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d:GetAttribute("Opens") then
			local target = d:GetAttribute("Opens")
			d:SetAttribute("Opens", nil) -- UI.juicy's own toggle would skip our rules
			d:SetAttribute("OpensVia", target)
			d.Activated:Connect(function()
				local to = d:GetAttribute("OpensVia")
				if to then UIC.open(to) end
			end)
		end
	end
	-- Gems "+" (bottom left): the Shop's Buy Gems tab
	local wal = hudGroup("HUD", "Wallet")
	local plus = wal and wal:FindFirstChild("GemsPlus")
	if plus and plus:IsA("GuiObject") then
		plus.Visible = PURCHASES
		plus:SetAttribute("OpensVia", nil)
		onClick(plus, function() UIC.openGemShop() end)
		-- the exported "+" is a button inside a button: the inner Btn sits on top and takes the click
		onClick(plus:FindFirstChild("Btn"), function() UIC.openGemShop() end)
	end
	-- SPECTATE pill (HUD.Watch)
	local watch = hudGroup("HUD", "Watch")
	onClick(watch and watch:FindFirstChild("SpectateButton"), function() UIC.startSpectate() end)
	-- rail toggles
	local rail = hudGroup("HUD", "Rail")
	if rail then
		onClick(rail:FindFirstChild("AFKToggle"), function()
			Net.event("RequestAFK"):FireServer(not (player:GetAttribute("EOS_AFK") == true))
		end)
		for _, n in ipairs({ "StateOn", "StateOff" }) do
			local b = find(rail:FindFirstChild("AFKToggle"), n)
			if b and b:IsA("GuiButton") then b.Activated:Connect(function() Net.event("RequestAFK"):FireServer(not (player:GetAttribute("EOS_AFK") == true)) end) end
			local v = find(rail:FindFirstChild("VolunteerToggle"), n)
			if v and v:IsA("GuiButton") then v.Activated:Connect(function() Net.event("RequestVolunteer"):FireServer(not (player:GetAttribute("EOS_Volunteer") == true)) end) end
		end
		onClick(rail:FindFirstChild("VolunteerToggle"), function()
			Net.event("RequestVolunteer"):FireServer(not (player:GetAttribute("EOS_Volunteer") == true))
		end)
	end
	-- close buttons + scrims go through UIC.close
	for _, name in ipairs({ "Quests", "Incubator", "Pets", "Shop", "Stats", "Settings", "Hatch", "Reward", "Results" }) do
		local sc = S[name]
		if sc then
			local dim = sc:FindFirstChild("Dim")
			local f = dim and dim:FindFirstChild("F")
			if f and f:IsA("GuiObject") then
				f.Active = true
				f.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						if UI.current() == name and name ~= "Hatch" then UIC.close() end
					end
				end)
			end
		end
	end
	-- Quests
	local q = S.Quests
	if q then
		onClick(find(q, "TabToday"), function() questTab = "today"; selQuest = 1; refreshQuests() end)
		onClick(find(q, "TabDone"), function() questTab = "done"; selQuest = 1; refreshQuests() end)
		for i = 1, 2 do
			local card = find(q, "Quest" .. i)
			if card and card:IsA("GuiObject") then
				hitArea(card, function() selQuest = i; Sound.play("click"); refreshQuests() end)
				onClick(card:FindFirstChild("Claim"), function()
					local item = questList()[i]
					if item then Net.event("RequestQuestClaim"):FireServer(item.id) end
				end)
			end
		end
		onClick(find(q, "ClaimAll"), function()
			for _, item in ipairs((profile and profile.quests) or {}) do
				if not item.claimed and (item.progress or 0) >= (item.target or 1) then
					Net.event("RequestQuestClaim"):FireServer(item.id)
				end
			end
		end)
		onClick(find(q, "Track"), function()
			local item = questList()[selQuest]
			if item then
				trackedQuest = if trackedQuest == item.id then nil else item.id
				refreshQuests()
				goalPill()
				if trackedQuest then
					UIC.toast("Tracking: " .. (item.title or "quest"), "info")
					local tl = hudGroup("HUD", "Goal")
					local pill2 = tl and tl:FindFirstChild("GoalPill")
					if pill2 then UI.pulse(pill2, 0.1) end
				end
			end
		end)
	end
	-- Incubator
	local inc = S.Incubator
	if inc then
		-- removed families (HOS-PET-001): their tiles and counts stay in the GUI, hidden
		for _, f in ipairs(REMOVED_FAMILIES) do
			for _, n in ipairs({ "Family_" .. f, "FamCount_" .. f, "FamCount_" .. f .. "Shadow" }) do
				local g = find(inc, n)
				if g and g:IsA("GuiObject") then g.Visible = false end
			end
		end
		for _, f in ipairs(ORDER) do
			onClick(find(inc, "Family_" .. f), function()
				if isLive(f) then
					selFamily = f
					Sound.play("click")
					refreshIncubator()
				else
					UIC.toast(("%s arrives in wave %d"):format(familyTitle(f), FAMILY[f].wave), "info")
					UI.shake(find(find(inc, "Family_" .. f), "Soon") or inc, 6, 0.25)
				end
			end)
		end
		for _, m in ipairs(RARITIES) do
			onClick(find(inc, "Species_" .. m), function()
				selRarity = m
				Sound.play("click")
				refreshIncubator()
			end)
		end
		onClick(find(inc, "BtnHatch"), function() doHatch(true) end)
		onClick(find(inc, "BtnHatchPoor"), function() doHatch(true) end)
		onClick(find(inc, "BtnRandom"), function() doHatch(false) end)
		onClick(find(inc, "BtnFocus"), function() doHatch(true) end)
		onClick(find(inc, "BtnFocusPoor"), function() doHatch(true) end)
	end
	-- Hatch reveal
	local h = S.Hatch
	if h then
		onClick(find(h, "BtnEquip"), function()
			local id = h:GetAttribute("PetId")
			if id then Net.event("RequestEquipPet"):FireServer(id) end
			UI.close()
		end)
		onClick(find(h, "BtnClose"), function() UI.close() end)
	end
	-- Reward reveal
	local rw = S.Reward
	if rw then
		onClick(find(rw, "BtnUse"), function()
			local fn = rewardUse
			rewardUse = nil
			UI.close()
			if fn then fn() end
		end)
		onClick(find(rw, "BtnClose"), function() UI.close() end)
	end
	-- Pets
	local pets = S.Pets
	if pets then
		for i = 0, 3 do
			onClick(find(pets, "Filter" .. i), function() petFilter = i; refreshPets() end)
		end
		onClick(find(pets, "BtnEquip"), function()
			if selPet and selPet.ids[1] then
				Net.event("RequestEquipPet"):FireServer(selPet.ids[1])
				UI.pulse(find(pets, "Preview") or pets, 0.05)
			end
		end)
		local fav = find(pets, "BtnFavourite")
		if fav then fav.Visible = false end
	end
	-- Shop: six tabs by what you buy
	local shop = S.Shop
	if shop then
		for key, nm in pairs(SHOP_TABS) do
			onClick(find(shop, nm), function() shopTab = key; refreshShop() end)
		end
		for key, nm in pairs(COS_FILTERS) do
			onClick(find(shop, nm), function() cosFilter = key; refreshShop() end)
		end
		local packs = find(shop, "GetGemsPage")
		for i, pack in ipairs(EconomyConfig.GEM_PACKS) do
			local card = find(packs, "Pack" .. i)
			onClick(card and find(card, "BtnBuy"), function() UIC.buyGems(pack) end)
		end
		onClick(find(shop, "BtnCrateGems"), function()
			local need = 250 - ((profile and profile.gems) or 0)
			if need > 0 then
				if UIC.crateProduct and PURCHASES and not UIC.crateBlocked then
					UIC.confirm({ title = "Not enough Gems", body1 = ("You need %s more Gems for an Emote Crate."):format(Format.full(need)),
						body2 = "Open one now for 149 Robux?", yes = "OPEN", no = "NOT NOW" }, function() UIC.buyCrate() end)
				elseif not UIC.offerGems(need, "an Emote Crate") then
					UIC.toast(("Need %s more Gems"):format(Format.full(need)), "bad")
				end
				return
			end
			if UIC.showEmoteCrate then UIC.showEmoteCrate() end
		end)
		onClick(find(shop, "BtnCrateRobux"), function() UIC.buyCrate() end)
		-- game passes: Roblox's own prompt; PassService grants on PromptGamePassPurchaseFinished
		for key, slot in pairs(PASS_CARDS) do
			local pass = EconomyConfig.pass(key)
			local card = find(shop, slot)
			onClick(card and find(card, "BtnBuy"), function()
				if not pass or not PURCHASES or player:GetAttribute(pass.attr) == true then return end
				Sound.play("click")
				pcall(function() MarketplaceService:PromptGamePassPurchase(player, pass.passId) end)
			end)
		end
		for _, pass in ipairs(EconomyConfig.PASSES) do
			player:GetAttributeChangedSignal(pass.attr):Connect(function()
				if UI.current() == "Shop" then refreshShop() end
			end)
		end
		onClick(find(shop, "BtnSeeEmotes"), function() if UIC.showEmoteCrate then UIC.showEmoteCrate() end end)
	end
	-- Settings
	local st = S.Settings
	if st then
		local keys = { Row1 = "sfx", RowMusic = "music", Row2 = "reduceEffects", Row3 = "showHints" }
		for rowName, key in pairs(keys) do
			onClick(find(find(st, rowName), "Toggle"), function()
				settings[key] = not settings[key]
				applySettings()
				refreshSettings()
				Net.event("RequestSettings"):FireServer({ [key] = settings[key] })
			end)
		end
		onClick(find(find(st, "Row4"), "Toggle"), function()
			Net.event("RequestVolunteer"):FireServer(not (player:GetAttribute("EOS_Volunteer") == true))
		end)
		local row5 = find(st, "Row5")
		if row5 then
			for label, key in pairs(SWATCH_KEY) do
				onClick(row5:FindFirstChild("Swatch_" .. label), function()
					settings.uiColour = key
					applySettings()
					Net.event("RequestSettings"):FireServer({ uiColour = key })
				end)
			end
		end
		onClick(find(st, "TabGame"), function() settingsTab = "game"; refreshSettings() end)
		onClick(find(st, "TabControls"), function() settingsTab = "controls"; refreshSettings() end)
	end
	-- Results
	local res = S.Results
	if res then
		onClick(find(res, "Continue"), function() UIC.closeResults() end)
	end
	-- touch buttons
	local touch = hudGroup("MatchHUD", "Touch")
	if touch then
		onClick(touch:FindFirstChild("TouchTag"), function() Tag.swing() end)
		onClick(touch:FindFirstChild("TouchDash"), function()
			if role() == "CATCHER" then Tag.lunge() else Movement.dash() end
		end)
		onClick(touch:FindFirstChild("TouchAbility"), function() Pets.use() end)
	end
end

local function connectEvents()
	Net.event("ProfileState").OnClientEvent:Connect(function(view)
		if type(view) ~= "table" then return end
		local lvl = (EconomyConfig.levelFor(tonumber(view.xp) or 0))
		if profile and shownLevel and lvl > shownLevel then rewardLevelUp(shownLevel, lvl) end
		shownLevel = lvl
		profile = view
		if not settingsInit and type(view.settings) == "table" then
			settingsInit = true
			for k, v in pairs(view.settings) do settings[k] = v end
			applySettings()
		end
		setWallet("gold", view.gold or 0)
		setWallet("gems", view.gems or 0)
		UIC.refreshPanels()
		if resultsOpen then refreshRecipe() end
	end)
	Net.event("Toast").OnClientEvent:Connect(function(t)
		if type(t) == "table" and type(t.text) == "string" then
			UIC.toast(t.text, t.kind)
		end
	end)
	Net.event("OpenScreen").OnClientEvent:Connect(function(t)
		if type(t) ~= "table" or not table.find(PANELS, t.name) then return end
		if t.name == "Shop" and type(t.tab) == "string" then -- lobby stalls: "gold" -> Featured, "gems" -> Gems
			shopTab = t.tab
			selItem = nil
			if UI.current() == "Shop" then
				refreshShop()
				return
			end
		end
		if UI.current() ~= t.name then UIC.open(t.name) end
	end)
	Net.event("HatchResult").OnClientEvent:Connect(function(t)
		hatchPending = false
		if type(t) ~= "table" then return end
		if t.ok and type(t.pet) == "table" then
			showReveal(t)
		elseif t.reason == "NEEDS_HIGHER" and t.plan then
			local parts, count = {}, 0
			for _, m in ipairs(EconomyConfig.MATERIALS) do
				local n = t.plan.take and t.plan.take[m]
				if n and n > 0 and m ~= t.plan.rarity then
					table.insert(parts, ("%d %s"):format(n, materialName(m)))
					count += n
				end
			end
			local plan = t.plan
			UIC.confirm({
				title = "Use higher pieces?",
				body1 = ("This uses %s piece%s for %s."):format(table.concat(parts, " + "), if count == 1 then "" else "s", materialName(plan.rarity)),
				body2 = "Higher pieces are worth more.",
				yes = "USE THEM",
				no = "CANCEL",
			}, function()
				requestHatch(plan.rarity, if plan.focused then selFamily else nil, true)
			end)
		elseif t.reason == "CHOOSE_FAMILY" then
			UIC.toast("Pick a family, then hatch", "info")
			local fams = find(S.Incubator, "Families")
			if fams then UI.pulse(fams, 0.06) end
		end
		refreshIncubator()
	end)
	Net.event("ShopResult").OnClientEvent:Connect(function(t)
		if type(t) ~= "table" or not t.ok then return end
		if type(t.gems) == "number" then
			rewardGems(t.gems)
		elseif type(t.pass) == "string" then
			rewardPass(t.pass)
		elseif type(t.itemId) == "string" and not t.refunded then
			local it = EconomyConfig.item(t.itemId)
			if it then rewardItem(it) else Sound.play("purchase") end
		else
			Sound.play("purchase")
		end
	end)
	Net.event("PracticeEvent").OnClientEvent:Connect(function(t)
		if type(t) ~= "table" then return end
		if t.kind == "crossed" then
			UIC.toast("Practice crossing! (no rewards in practice)", "reward")
			Sound.play("evolve", 1.1)
		elseif t.kind == "tagged" then
			UIC.toast("Tagged by the practice Catcher. Try again!", "warn")
			Sound.play("caught")
		end
	end)
	Net.event("RoleChanged").OnClientEvent:Connect(function(t)
		if type(t) ~= "table" then return end
		if t.cause == "START" then
			task.delay(0.15, function()
				local finish = state:GetAttribute("FinishSide") or "B"
				local target = if t.role == "RUNNER" then Layout.Zones[finish].center else Layout.Arena.CENTER
				CameraFX.lookToward(target)
			end)
			Sound.play("role")
			if t.role == "RUNNER" then
				UIC.banner("Runner", "YOU'RE A RUNNER!", "Carry your egg to the glowing safe zone", "runner", 2.4)
			else
				UIC.banner("Catcher", "YOU'RE A CATCHER!", ("Tag Runners to steal their eggs (up to Level %d)"):format(TierConfig.CATCHER_TIER_CAP or 3), "catcher", 2.4)
			end
		elseif t.cause == "CAPTURED" then
			Sound.play("caught")
			CameraFX.shake(1.2, 0.3)
			local by = if t.bySlot then npcName(t.bySlot, t.byName) else t.byName
			UIC.banner("Caught", "CAUGHT!", if by then ("%s got you. You're a Catcher now!"):format(by) else "You're a Catcher now. Go get them!", "catcher", 1.6)
		elseif t.cause == "TIMEOUT" then
			Sound.play("caught", 0.8)
			UIC.banner("Slow", "TOO SLOW!", "You missed the crossing: you hunt now", "clock", 1.6)
		end
	end)
	Net.event("RunnerEvolved").OnClientEvent:Connect(function(t)
		if type(t) ~= "table" then return end
		local who: any = if t.slot then NpcSkins.modelForSlot(t.slot) else Players:GetPlayerByUserId(t.userId)
		if who then WorldFX.evolve(who, TierConfig.get(t.newTier).shell) end
		if t.userId == player.UserId then
			Sound.play("evolve")
			local PC = require(Shared:WaitForChild("PointsConfig")) -- HOS-PTS-001: only say the egg grew when it did (ladder: by rarity)
			if PC.Ladder and PC.Ladder.Enabled then
				local was, now = PC.rarityForLevel(t.prevTier or t.newTier), PC.rarityForLevel(t.newTier)
				UIC.banner("Safe", "SAFE!", if was ~= now then ("Your shard grew to %s!"):format(now:sub(1, 1):upper() .. now:sub(2)) else "You made it across", eggSlug(t.newTier), 1.4)
			else
			UIC.banner("Safe", "SAFE!", ("Your egg grew to Level %d"):format(t.newTier), eggSlug(t.newTier), 1.4)
			end -- HOS-PTS-001
		else
			local PC = require(Shared:WaitForChild("PointsConfig")) -- HOS-PTS-001: ladder on = "with a Rare egg" (rarity in its colour)
			local rar = if PC.Ladder and PC.Ladder.Enabled then PC.rarityForLevel(t.newTier) else nil
			UIC.feed(("%s %s with %s"):format(npcName(t.slot, t.name), font(Color3.fromRGB(184, 255, 74), "is safe"), if rar then ("%s %s shard"):format(if rar == "epic" then "an" else "a", font(RARITY_COLOR[if rar == "legendary" then "crowned" else rar] or Color3.new(1, 1, 1), rar:sub(1, 1):upper() .. rar:sub(2))) else ("Level %d"):format(t.newTier)), "safe")
		end
	end)
	Net.event("CaptureFeedback").OnClientEvent:Connect(function(t)
		if type(t) ~= "table" then return end
		if typeof(t.position) == "Vector3" then WorldFX.capture(t.position) end
		if t.hunterId == player.UserId or t.victimId == player.UserId then
			Sound.play("capture")
		elseif typeof(t.position) == "Vector3" then
			Sound.playAt("capture", t.position, 0.7)
		end
		local hunter, victim = npcName(t.hunterSlot, t.hunterName), npcName(t.victimSlot, t.victimName)
		local PC = require(Shared:WaitForChild("PointsConfig")) -- HOS-PTS-001: ladder on = "stole Mia's Rare egg" (rarity in its colour)
		local rar = if PC.Ladder and PC.Ladder.Enabled then PC.rarityForLevel(t.stolenTier or 1) else nil
		UIC.feed(("%s %s %s's %s shard"):format(hunter, font(Color3.fromRGB(255, 90, 90), "stole"), victim, if rar then font(RARITY_COLOR[if rar == "legendary" then "crowned" else rar] or Color3.new(1, 1, 1), rar:sub(1, 1):upper() .. rar:sub(2)) else ("Lv %d"):format(t.stolenTier or 1)), "steal")
		if t.hunterId == player.UserId then
			UIC.banner("Stole", "STOLEN!", ("You took %s's Level %d egg"):format(victim, t.stolenTier or 1), "steal", 1.4)
			CameraFX.shake(0.6, 0.2)
		end
	end)
	Net.event("MatchState").OnClientEvent:Connect(function(t)
		if type(t) ~= "table" or not inMatch() then return end
		if t.phase == "CROSSING" then
			Sound.play("go")
			if t.lastStanding == player.UserId then
				Sound.play("alert")
				-- HOS-CINE-002: with the cut-scene on, the top pill (Controllers/LastStanding) replaces this pop
				if not (GameConfig.Cinematic and GameConfig.Cinematic.LAST_STANDING_ENABLED) then
					UIC.banner("Last", "LAST ONE STANDING!", "Make it across alone to win it for the Runners", "crown", 1.8)
				end
			end
		elseif t.phase == "WAVE_END" then
			local justFinished = t.finishSide or "B"
			local nextFinish = if justFinished == "A" then "B" else "A"
			task.delay(1.5, function()
				if player:GetAttribute("EOS_Role") == "RUNNER" then
					CameraFX.lookToward(Layout.Zones[nextFinish].center)
				else
					CameraFX.lookToward(Layout.Zones[justFinished].center)
				end
			end)
		end
	end)
	Net.event("Results").OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			showResults(data)
			-- match XP, with the VIP / 2x XP pass shares named
			local you = data.you
			if type(you) == "table" and (tonumber(you.xp) or 0) > 0 then
				local extra = {}
				for _, l in ipairs(you.xpExtra or {}) do table.insert(extra, ("%s +%d"):format(l.label, l.amount)) end
				local text = ("+%s XP"):format(Format.full(you.xp)) .. (if #extra > 0 then ("  (%s)"):format(table.concat(extra, "  ·  ")) else "")
				task.delay(1.2, function() UIC.toast(text, "reward", true) end)
			end
		end
	end)
end

----------------------------------------------------------------------------------------------- init
function UIC.init()
	local pg = player:WaitForChild("PlayerGui")
	gui = pg:WaitForChild("EOSUI", 30) :: ScreenGui
	if not gui then
		warn("[EOSUI] PlayerGui.EOSUI is missing: rebuild it (ServerStorage.EOSUIBuild.Builder.build())")
		return
	end
	-- the old UI (EOS_HUD / EOS_Menus / EOS_Results / EOS_Overlay, UIBuilder) is retired: keep its PlayerGui
	-- copies switched off so stale placeholders never draw over EOSUI (EmoteController still finds EOS_Menus)
	for _, name in ipairs({ "EOS_HUD", "EOS_Menus", "EOS_Results", "EOS_Overlay" }) do
		task.spawn(function()
			local og = pg:WaitForChild(name, 15)
			if og and og:IsA("ScreenGui") then
				og.Enabled = false
				og:GetPropertyChangedSignal("Enabled"):Connect(function()
					if og.Enabled then og.Enabled = false end
				end)
			end
		end)
	end
	UI = require(gui:WaitForChild("UI"))
	assets = require(gui:WaitForChild("AssetIds"))
	templates = ReplicatedStorage:WaitForChild(gui:GetAttribute("TemplatesFolder") or "EOSUITemplates", 10)
	UI.init(gui)
	root = gui:WaitForChild("Root") :: Frame
	for _, s in root:GetChildren() do
		if s:IsA("Frame") and s.Name ~= "Dim" then S[s.Name] = s end
	end
	-- sounds through the game's Sound controller (Roblox library sounds; respects the SFX setting)
	UI.play = function(name: string)
		if name == "hover" then return end
		Sound.play(if name == "click" then "click" else name)
	end
	-- overlay for toasts, banners and confirms: a frame in Root above every screen (shares FitScale)
	overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 40
	overlay.Parent = root
	-- a selection ring's box-shadow exports as ShadowRing siblings that would stay behind when the
	-- ring moves: fold them into the ring so they follow it (and its size) wherever moveRing sends it
	for _, ring in root:GetDescendants() do
		if ring:IsA("Frame") and (ring.Name:match("Sel$") or ring.Name == "SelRing") and ring.Parent then
			local rp, rs = ring.Position, ring.Size
			for _, sh in ring.Parent:GetChildren() do
				if sh:IsA("Frame") and sh.Name == "ShadowRing" and sh.AnchorPoint == ring.AnchorPoint
					and math.abs(sh.Position.X.Offset - rp.X.Offset) <= 12 and math.abs(sh.Position.Y.Offset - rp.Y.Offset) <= 12 then
					sh.Position = UDim2.fromOffset(sh.Position.X.Offset - rp.X.Offset + rs.X.Offset * ring.AnchorPoint.X, sh.Position.Y.Offset - rp.Y.Offset + rs.Y.Offset * ring.AnchorPoint.Y)
					sh.Size = UDim2.new(1, sh.Size.X.Offset - rs.X.Offset, 1, sh.Size.Y.Offset - rs.Y.Offset)
					sh.AnchorPoint = Vector2.zero
					sh.ZIndex = ring.ZIndex
					sh.Parent = ring
				end
			end
		end
	end
	-- each state of a two-state control (Live/Soon, On/Off, Buy/Poor...) and each card brings its own
	-- DropShadow / ShadowRing, drawn just below it. A hidden element's shadow must hide too, or it covers
	-- the visible state (black family tiles) or floats over another tab (lines across Controls)
	for _, sh in root:GetDescendants() do
		if sh:IsA("Frame") and (sh.Name == "DropShadow" or sh.Name == "ShadowRing") and sh.Parent then
			local partner: GuiObject? = nil
			for _, c in sh.Parent:GetChildren() do
				if c ~= sh and c:IsA("GuiObject") and c.ZIndex == sh.ZIndex + 1 then partner = c end
			end
			if partner then
				local p = partner :: GuiObject
				sh.Visible = p.Visible
				p:GetPropertyChangedSignal("Visible"):Connect(function() sh.Visible = p.Visible end)
			end
		end
	end
	-- close button: the export clipped the tilted box (and its corner tabs) to its layout rect. When the
	-- clean re-render (art close_clean, no tabs) is uploaded, swap it in, centred where the old art was
	local clean = assets and assets.art and assets.art["close_clean"]
	if clean and clean ~= "" then
		for _, x in root:GetDescendants() do
			if x:IsA("GuiButton") and x.Name == "CloseButton" then
				local art = x:FindFirstChild("Art")
				if art and art:IsA("ImageLabel") then
					local cx = art.Position.X.Offset + art.Size.X.Offset / 2
					local cy = art.Position.Y.Offset + art.Size.Y.Offset / 2
					art.Image = clean
					art.Size = UDim2.fromOffset(106.5, 98.5)
					art.Position = UDim2.fromOffset(cx - 53, cy - 51)
				end
			end
		end
	end
	-- the ability card's pet disc was flattened to a tinted glow and lost its pet image: rebuild the round
	-- slot (pet photo clipped to a circle, green rim, black outline) so abilityCard can fill PetIcon
	for _, disc in root:GetDescendants() do
		if disc:IsA("ImageLabel") and disc.Name == "PetDisc" and not disc:FindFirstChild("PetIcon") then
			local dc = Instance.new("UICorner")
			dc.CornerRadius = UDim.new(0.5, 0)
			dc.Parent = disc
			local rim = Instance.new("UIStroke")
			rim.Color = Color3.fromRGB(78, 212, 90)
			rim.Thickness = 3
			rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			rim.Parent = disc
			local outline = Instance.new("Frame")
			outline.Name = "Outline"
			outline.BackgroundTransparency = 1
			outline.Size = UDim2.new(1, 10, 1, 10)
			outline.Position = UDim2.fromOffset(-5, -5)
			outline.ZIndex = disc.ZIndex
			local oc = Instance.new("UICorner")
			oc.CornerRadius = UDim.new(0.5, 0)
			oc.Parent = outline
			local ostroke = Instance.new("UIStroke")
			ostroke.Color = Color3.fromRGB(5, 5, 6)
			ostroke.Thickness = 2
			ostroke.Parent = outline
			outline.Parent = disc
			local icon = Instance.new("ImageLabel")
			icon.Name = "PetIcon"
			icon.BackgroundTransparency = 1
			icon.ScaleType = Enum.ScaleType.Crop
			icon.Size = UDim2.new(1, -4, 1, -4)
			icon.Position = UDim2.fromOffset(2, 2)
			icon.ZIndex = disc.ZIndex
			local ic = Instance.new("UICorner")
			ic.CornerRadius = UDim.new(0.5, 0)
			ic.Parent = icon
			icon.Parent = disc
		end
	end
	-- rail toggles: the design hung the ON/OFF pill off the plate's corner, half over the world. Tuck it onto the
	-- plate's top-right corner like the B / P key badges (both states are juiced: centre-anchored, rest in JuiceRest)
	for _, t in root:GetDescendants() do
		local on, off, plate = t:FindFirstChild("StateOn"), t:FindFirstChild("StateOff"), t:FindFirstChild("Plate")
		if on and off and plate and plate:IsA("GuiObject") then
			local right = plate.Position.X.Offset + plate.Size.X.Offset
			local top = plate.Position.Y.Offset
			for _, pill in ipairs({ on, off }) do
				if pill:IsA("GuiObject") then
					pill.AnchorPoint = Vector2.new(0.5, 0.5)
					pill.Position = UDim2.fromOffset(right - pill.Size.X.Offset / 2 + 2, top + 2)
					pill:SetAttribute("JuiceRest", pill.Position)
				end
			end
		end
	end
	-- button plates: the export's 3 px radius read as round on the glossy right and square on the left.
	-- Clip every button plate to one clear radius (not the tilted close button or the rail's square plates)
	for _, b in root:GetDescendants() do
		if b:IsA("GuiButton") and b.Name ~= "CloseButton" and not b:FindFirstChild("Plate") then
			local art = b:FindFirstChild("Art")
			if art and art:IsA("ImageLabel") and not art:FindFirstChildOfClass("UICorner") and art.Size.Y.Offset <= 120 then
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0, 10)
				c.Parent = art
			end
		end
	end
	-- panel glows were exported clipped (alpha 44 at the edge = a hard line beside the panel). Until the
	-- soft-edged re-renders are uploaded, fade their left and right edges here
	for _, g in root:GetDescendants() do
		if (g.Name == "Glow" or g.Name == "GlowMono") and g:IsA("Frame") then
			local art = g:FindFirstChild("Art")
			if art and art:IsA("ImageLabel") and not art:FindFirstChild("EdgeFade") then
				local gr = Instance.new("UIGradient")
				gr.Name = "EdgeFade"
				gr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.025, 0),
					NumberSequenceKeypoint.new(0.975, 0), NumberSequenceKeypoint.new(1, 1) })
				gr.Parent = art
			end
		end
	end
	-- gamepad selection: a white rounded ring in the UI's style instead of Roblox's default blue box
	local selRing = Instance.new("Frame")
	selRing.Name = "EOS_SelectionRing"
	selRing.BackgroundTransparency = 1
	selRing.Size = UDim2.new(1, 8, 1, 8)
	selRing.Position = UDim2.fromOffset(-4, -4)
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 10)
	sc.Parent = selRing
	local ss = Instance.new("UIStroke")
	ss.Color = Color3.new(1, 1, 1)
	ss.Thickness = 3
	ss.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ss.Parent = selRing
	pg.SelectionImageObject = selRing
	-- tag the incubator ladder's folder-tab title (unnamed in the export) so refreshIncubator can rename it
	if S.Incubator then
		for _, d in S.Incubator:GetDescendants() do
			if d:IsA("TextLabel") and string.find(d.Text, "Two quick dashes", 1, true) then
				d:SetAttribute("LadderTitle", true)
			end
		end
	end
	-- each page's dim is a 1920x1080 design rect: stretch it past every edge so taller/wider screens are covered
	for _, sc in pairs(S) do
		local dim = sc:FindFirstChild("Dim")
		local f = dim and dim:FindFirstChild("F")
		if f and f:IsA("GuiObject") then
			dim.Size = UDim2.fromScale(1, 1)
			dim.Position = UDim2.fromScale(0, 0)
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			f.Size = UDim2.new(1, 600, 1, 600)
		end
	end
	-- placeholders from the mock never reach players: hide demo-only rows until data arrives
	local feed = hudGroup("MatchHUD", "Feed")
	if feed then
		for i = 1, 3 do
			local f = feed:FindFirstChild("Feed" .. i)
			if f then f.Visible = false end
		end
	end
	for _, n in ipairs({ "GoldText", "GemsText" }) do setText(S.HUD, n, "0") end
	hideGroup("Ability", true)
	gui.Enabled = true
	UI.PageChanged:Connect(function(name)
		if name ~= "Results" then resultsOpen = false end
		if name == nil and not resultsOpen then Sound.play("close") end
		layoutToasts()
	end)
	UI.Opened.Event:Connect(cascade)
	preloadAll()
	wireButtons()
	connectEvents()
	applySettings()
	-- hooks other controllers read
	Tag.isUIOpen = UIC.isOpen
	Tag.onDecoy = function()
		UIC.toast("THAT WAS A DECOY!", "warn", true)
	end
	Pets.onToast = function(text, kind)
		UIC.toast(text, kind)
	end
	Pets.onUsed = function()
		local fam = Pets.family()
		Sound.play(AbilityCosmetics.resolve(player:GetAttribute("EOS_PetSpecies"), fam).sound)
		local card = hudGroup("MatchHUD", "Ability")
		if card then UI.pulse(card, 0.1) end
	end
	CameraFX.lockBlocked = function()
		return UIC.isOpen() or resultsOpen
	end
	Movement.onDash(function()
		Sound.play("dash")
		local t = hudGroup("MatchHUD", "Touch")
		local b = t and t:FindFirstChild("TouchDash")
		if b then UI.pulse(b, -0.12) end
	end)
	Tag.onSwing = function()
		local t = hudGroup("MatchHUD", "Touch")
		local b = t and t:FindFirstChild("TouchTag")
		if b then UI.pulse(b, -0.12) end
	end
	-- no resetting your character mid-match (it would teleport you out of a tag)
	local function setReset()
		pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", not inMatch())
	end
	player:GetAttributeChangedSignal("EOS_InMatch"):Connect(function()
		setReset()
		if inMatch() then
			UIC.close()
			for _, t in ipairs(toasts) do t:Destroy() end
			table.clear(toasts)
		end
	end)
	task.delay(2, setReset)
	local acc, errs = 0, {}
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then return end
		acc = 0
		local ok, err = pcall(updateHUD)
		if not ok and not errs[err] then
			errs[err] = true
			warn("[EOSUI] " .. tostring(err))
		end
	end)
	task.spawn(require(script.Parent.EggUIController).init, UIC) -- HOS-EGG-002: the egg card, incubator egg, roll and shard UI (EggUI)
	local lastDevice = deviceClass()
	Net.event("RequestProfile"):FireServer(lastDevice)
	UserInputService.LastInputTypeChanged:Connect(function()
		local d = deviceClass()
		if d ~= lastDevice then
			lastDevice = d
			Net.event("RequestProfile"):FireServer(d)
		end
	end)
	-- first-visit hint toast (showHints)
	task.delay(4, function()
		if settings.showHints and not inMatch() and os.clock() - joinedAt < 30 then
			UIC.toast("Matches start on their own: hang out, or open a menu", "info")
		end
	end)
end

return UIC
