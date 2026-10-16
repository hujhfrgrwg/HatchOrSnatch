-- UIController: drives the three baked ScreenGuis (EOS_HUD, EOS_Menus, EOS_Results).
-- Reads replicated state (EOS_State + player attributes) and server events; never trusts itself
-- for rewards. Every element is found by NAME, every placeholder is overwritten on first draw.
-- Oct 2026: reference-style HUD (pills, icon rail, Gold/Gems, ability card) and the GDD v0.4 screens
-- (incubator, pets, Gold/Gem shop, end-of-match breakdown). Economy counters hide during a match.

local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local EOS = ReplicatedStorage:WaitForChild("EOS")
local Shared = EOS:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TierConfig = require(Shared:WaitForChild("TierConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local PetModel = require(Shared:WaitForChild("PetModel"))
local Layout = require(Shared:WaitForChild("Layout"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Theme = require(EOS:WaitForChild("UI"):WaitForChild("Theme"))
local UIKit = require(EOS.UI:WaitForChild("UIKit"))

local Fit = require(script.Parent.Fit)
local Sound = require(script.Parent.Sound)
local CameraFX = require(script.Parent.CameraFX)
local WorldFX = require(script.Parent.WorldFX)
local Tag = require(script.Parent.Tag)
local Movement = require(script.Parent.Movement)
local NpcSkins = require(script.Parent.NpcSkins)
local Pets = require(script.Parent.Pets)

-- NPCs show up as this player's friends: swap in the friend's name when the server sent a slot
local function npcName(slot: number?, fallback: string?): string
	return NpcSkins.nameForSlot(slot) or fallback or "?"
end

local UI = {}

local player = Players.LocalPlayer
local state = Net.state()
local hud, menus, results, overlay
local profile: any = nil
local settings = { sfx = true, reduceEffects = false, showHints = true }
local settingsInit = false
local openName: string? = nil
local resultsData: any = nil
local resultsOpen = false
local joinedAt = os.clock()
local railOpen = false
local shopTab = "gold"

local MATERIALS = EconomyConfig.MATERIALS
local MATERIAL_EGG = { common = 1, rare = 3, epic = 4 } -- egg icon look per piece tier
local FAMILY_RAMP = { Decoy = "orange", Scout = "blue", Brake = "green" }

-- ===== small helpers =====

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

local function setText(label: Instance?, text: string)
	if label and label:IsA("TextLabel") and label.Text ~= text then
		label.Text = text
	end
end

local function plateLabel(plate: Instance): TextLabel?
	local face = plate:FindFirstChild("Face")
	return face and face:FindFirstChild("Label") :: TextLabel?
end

local function setPlate(plate: Instance, text: string, ramp: string?)
	setText(plateLabel(plate), text)
	if ramp then
		UIKit.setRamp(plate, ramp)
	end
end

-- lit = a toggle tile that's on: green edge
local function setLit(plate: Instance, on: boolean)
	local face = plate:FindFirstChild("Face")
	local edge = face and face:FindFirstChild("Edge") :: UIStroke?
	if edge then
		edge.Color = if on then Theme.ramps.green.mid else Theme.edge
		edge.Transparency = if on then 0 else Theme.edgeT
		edge.Thickness = if on then 3 else 2
	end
end

local function fitOf(g: Instance): UIScale?
	return g:FindFirstChild("Fit") :: UIScale?
end

-- open pop: tween the group's Fit scale from 60% to the current fit (Back ease-out)
local function pop(g: GuiObject, from: number?)
	local s = fitOf(g)
	if not s then
		return
	end
	local target = Fit.scaleFor(g)
	s.Scale = target * (from or Theme.motion.openFrom)
	TweenService:Create(s, TweenInfo.new(Theme.motion.openTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
end

-- juicy buttons: hover grow, press sink, release spring, click sound (STYLE.md motion)
local function juicy(button: GuiButton, onActivate: () -> ())
	local s = button:FindFirstChild("Press") :: UIScale?
	if not s then
		s = Instance.new("UIScale")
		s.Name = "Press"
		s.Parent = button
	end
	local function to(v: number, t: number, style: Enum.EasingStyle?)
		TweenService:Create(s, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = v }):Play()
	end
	button.MouseEnter:Connect(function()
		to(Theme.motion.hoverScale, 0.12)
	end)
	button.MouseLeave:Connect(function()
		to(1, 0.12)
	end)
	button.MouseButton1Down:Connect(function()
		to(Theme.motion.pressScale, 0.06)
	end)
	button.MouseButton1Up:Connect(function()
		to(1, 0.28, Enum.EasingStyle.Back)
	end)
	button.Activated:Connect(function()
		Sound.play("click")
		onActivate()
	end)
end

local function materialName(m: string?): string
	local info = m and EconomyConfig.MATERIAL_INFO[m]
	return info and string.upper(info.name) or "?"
end

local function have(m: string): number
	return (profile and profile.materials and profile.materials[m]) or 0
end

-- pieces available for a recipe of tier m (its own tier plus higher ones, which can fill in 1:1)
local function haveFor(m: string): number
	local idx = table.find(MATERIALS, m) or 1
	local n = 0
	for i = idx, #MATERIALS do
		n += have(MATERIALS[i])
	end
	return n
end

local function firstFree(): boolean
	return profile ~= nil and profile.firstCommonFree == true
end

local function costFor(m: string, focused: boolean): number
	local r = EconomyConfig.RECIPES[m]
	if m == "common" and firstFree() then
		return r.base
	end
	return if focused then r.focus else r.base
end

-- ===== toasts, feed, banner =====

local toastList: { { frame: Frame, text: string, untilT: number } } = {}
local TOAST_COLORS = { reward = Theme.gold, info = Theme.ramps.blue.mid, warn = Theme.ramps.orange.mid, bad = Theme.ramps.red.mid }

function UI.toast(text: string, kind: string?, force: boolean?)
	-- minimal HUD: no notifications during a match unless the moment can't be read any other way
	if player:GetAttribute("EOS_InMatch") and not force then
		return
	end
	local holder = overlay.Toasts
	for _, t in ipairs(toastList) do
		if t.text == text and t.frame.Parent then
			t.untilT = os.clock() + 3.5 -- dedupe: restart the timer
			pop(t.frame, 0.85)
			return
		end
	end
	local f = hud.Templates.Toast:Clone()
	f.Visible = true
	f.LayoutOrder = math.floor(os.clock() * 100)
	setText(f.Text, text)
	f.Accent.BackgroundColor3 = TOAST_COLORS[kind or "info"] or TOAST_COLORS.info
	f.Parent = holder
	table.insert(toastList, { frame = f, text = text, untilT = os.clock() + (if #text > 50 then 6 else 3.5) })
	while #toastList > 3 do
		local old = table.remove(toastList, 1)
		if old then
			old.frame:Destroy()
		end
	end
end

local feedList: { { frame: Frame, untilT: number } } = {}
local FEED_ENABLED = false -- minimal HUD: the kill feed is off
function UI.feed(rich: string)
	if not FEED_ENABLED then
		return
	end
	local f = hud.Templates.FeedLine:Clone()
	f.Visible = true
	f.LayoutOrder = math.floor(os.clock() * 100)
	f.Text.Text = rich
	f.Parent = hud.Feed
	table.insert(feedList, { frame = f, untilT = os.clock() + 6 })
	while #feedList > 5 do
		local old = table.remove(feedList, 1)
		if old then
			old.frame:Destroy()
		end
	end
end

local bannerQueue: { any } = {}
local bannerBusy = false
local function runBanners()
	if bannerBusy then
		return
	end
	bannerBusy = true
	task.spawn(function()
		while #bannerQueue > 0 do
			local b = table.remove(bannerQueue, 1)
			local g = hud.Banner
			setText(g.Title, b.title)
			setText(g.Sub, b.sub or "")
			g.Title.TextColor3 = b.color or Theme.white
			g.Burst.ImageColor3 = b.burst or Theme.gold
			g.Burst.Visible = b.burst ~= false
			g.Visible = true
			pop(g, 0.5)
			local t0 = os.clock()
			while os.clock() - t0 < (b.time or 1.9) do
				g.Burst.Rotation = (os.clock() * 30) % 360
				task.wait()
			end
			g.Visible = false
		end
		bannerBusy = false
	end)
end

function UI.banner(title: string, sub: string?, color: Color3?, burst: any, time: number?)
	-- one banner per moment: drop stale ones if the queue is backing up
	if #bannerQueue >= 2 then
		table.remove(bannerQueue, 1)
	end
	table.insert(bannerQueue, { title = title, sub = sub, color = color, burst = burst, time = time })
	runBanners()
end

-- ===== panels =====

local PANELS = { "Quests", "Incubator", "Pets", "Shop", "Emotes", "Stats", "Settings" }

local function firstButton(root: Instance): GuiObject?
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiButton") and d.Visible and d.Name ~= "Close" then
			return d
		end
	end
	return nil
end

local function incubatorOverlays(): (Frame, Frame, Frame)
	local p = menus.Incubator.Panel
	return p.Picker, p.Confirm, p.Reveal
end

-- while a picker / confirm / reveal shows, hide what's under it (text outlines bleed through frames)
local function syncIncubator()
	local p = menus.Incubator.Panel
	local any = p.Picker.Visible or p.Confirm.Visible or p.Reveal.Visible
	p.Body.Visible = not any
	p.Header.Visible = not any
	p.Close.Visible = not any or p.Confirm.Visible
end

function UI.close()
	if not openName then
		return
	end
	local g = menus:FindFirstChild(openName)
	if g then
		g.Visible = false
	end
	local picker, confirm, reveal = incubatorOverlays()
	picker.Visible = false
	confirm.Visible = false
	reveal.Visible = false
	syncIncubator()
	menus.Scrim.Visible = false
	openName = nil
	GuiService.SelectedObject = nil
	ContextActionService:UnbindAction("EOS_ClosePanel")
end

function UI.open(name: string)
	if openName == name then
		return UI.close()
	end
	UI.close()
	local g = menus:FindFirstChild(name)
	if not g then
		return
	end
	if player:GetAttribute("EOS_InMatch") and (name == "Incubator" or name == "Shop" or name == "Pets" or name == "Emotes") then
		UI.toast("That opens between matches", "info")
		return
	end
	railOpen = false
	openName = name
	UI.refreshPanels()
	menus.Scrim.Visible = true
	g.Visible = true
	pop(g)
	Sound.play("open")
	-- gamepad / TV: focus the first button; B closes
	local last = UserInputService:GetLastInputType()
	if last.Name:find("Gamepad") or GuiService:IsTenFootInterface() then
		GuiService.SelectedObject = firstButton(g) or g.Panel:FindFirstChild("Close")
	end
	ContextActionService:BindActionAtPriority("EOS_ClosePanel", function(_, s)
		if s == Enum.UserInputState.Begin then
			UI.close()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonB)
end

function UI.openName(): string?
	return openName
end

function UI.isOpen(): boolean
	return openName ~= nil or resultsOpen
end

local function questRows(): { any }
	return (profile and profile.quests) or {}
end

-- ----- incubator -----

local function refreshIncubator()
	local ib = menus.Incubator.Panel.Body
	for i, m in ipairs(MATERIALS) do
		local card = ib.Tiers:FindFirstChild("Tier_" .. m)
		if card then
			local n = have(m)
			local info = EconomyConfig.MATERIAL_INFO[m]
			if card.Egg:GetAttribute("Tier") ~= MATERIAL_EGG[m] then
				UIKit.setEggIcon(card.Egg, MATERIAL_EGG[m])
			end
			setText(card.TierName, string.upper(info.name) .. " PIECES")
			card.TierName.TextColor3 = info.text
			setText(card.Count, "x " .. Format.short(n))
			local free = m == "common" and firstFree()
			local base, focus = costFor(m, false), costFor(m, true)
			if free then
				setText(card.Recipe, "FIRST PET: " .. base .. " PIECES  ·  FREE PICK")
			else
				setText(card.Recipe, ("HATCH: %d  ·  PICK FAMILY: %d"):format(base, focus))
			end
			card.Progress.Fill.Size = UDim2.fromScale(math.clamp(n / base, 0, 1), 1)
			setText(card.Progress.Label, Format.full(math.min(n, 999)) .. " / " .. base)
			local canBase = haveFor(m) >= base
			local canFocus = haveFor(m) >= focus
			if free then
				setPlate(card.HatchRandom, "PICK FREE", if canBase then "yellow" else "grey")
				card.HatchPick.Visible = false
			else
				setPlate(card.HatchRandom, "HATCH", if canBase then "yellow" else "grey")
				card.HatchPick.Visible = true
				setPlate(card.HatchPick, "PICK +1", if canFocus then "purple" else "grey")
			end
			card:SetAttribute("Material", m)
			card:SetAttribute("Index", i)
		end
	end
	ib.FirstFree.Visible = firstFree()
end

local pending: { rarity: string, family: string? }? = nil

local function openPicker(m: string)
	local picker = menus.Incubator.Panel.Picker
	local free = m == "common" and firstFree()
	local cost = costFor(m, true)
	setText(picker.Title, if free then "YOUR FIRST PET: PICK A FAMILY" else "PICK A FAMILY")
	setText(picker.Cost, ("COSTS %d %s PIECES%s"):format(cost, materialName(m), if free then " (THE PICK IS FREE)" else ""))
	for _, fam in ipairs(EconomyConfig.LAUNCH_FAMILIES) do
		local card = picker.Families:FindFirstChild(fam)
		if card then
			local def = EconomyConfig.FAMILIES[fam]
			local species = EconomyConfig.speciesFor(fam, m)
			setText(card.Ability, def.ability)
			card.Ability.TextColor3 = def.color
			setText(card.Species, string.upper(materialName(m)) .. " " .. string.upper(species))
			setText(card.Desc, def.desc)
			PetModel.viewport(card.View, species)
			card:SetAttribute("Family", fam)
		end
	end
	picker:SetAttribute("Material", m)
	picker.Visible = true
	syncIncubator()
end

local function sendHatch(m: string, fam: string?, allowHigher: boolean)
	pending = { rarity = m, family = fam }
	Net.event("RequestHatch"):FireServer(m, fam, allowHigher)
end

local revealToken = 0
local function showReveal(t: any)
	local _, _, reveal = incubatorOverlays()
	local pet = t.pet
	revealToken += 1
	local token = revealToken
	local royal = t.royal == true
	reveal.Visible = true
	syncIncubator()
	reveal.View.Visible = false
	reveal.Done.Visible = false
	reveal.Title.Visible = false
	reveal.Sub.Visible = false
	reveal.Egg.Visible = true
	UIKit.setEggIcon(reveal.Egg, MATERIAL_EGG[pet.rarity] or 1)
	reveal.Burst.ImageColor3 = if royal then Theme.gold else Color3.fromRGB(255, 255, 255)
	reveal.Burst.ImageTransparency = if royal then 0.35 else 0.6
	task.spawn(function()
		local shake = if royal then 2.0 else 1.2
		local t0 = os.clock()
		while os.clock() - t0 < shake and token == revealToken do
			local k = (os.clock() - t0) / shake
			reveal.Egg.Rotation = math.sin(os.clock() * (18 + 30 * k)) * (6 + 14 * k)
			reveal.Burst.Rotation = (os.clock() * 40) % 360
			task.wait()
		end
		if token ~= revealToken then
			return
		end
		reveal.Egg.Rotation = 0
		reveal.Egg.Visible = false
		Sound.play("reward")
		PetModel.viewport(reveal.View, pet.species)
		reveal.View.Visible = true
		local def = EconomyConfig.FAMILIES[pet.family]
		setText(reveal.Title, if royal then "A ROYAL HATCH!" else "NEW PET!")
		setText(reveal.Sub, ("%s %s  ·  %s"):format(materialName(pet.rarity), string.upper(pet.species), def and def.ability or ""))
		reveal.Sub.TextColor3 = def and def.color or Theme.goldText
		reveal.Title.Visible = true
		reveal.Sub.Visible = true
		reveal.Done.Visible = true
		local spin0 = os.clock()
		while reveal.Visible and token == revealToken do
			local cam = reveal.View.CurrentCamera
			local model = reveal.View:FindFirstChildOfClass("Model")
			if model and cam then
				model:PivotTo(CFrame.Angles(0, math.rad(25) + (os.clock() - spin0) * 1.2, 0))
			end
			reveal.Burst.Rotation = (os.clock() * 25) % 360
			task.wait()
		end
	end)
end

-- ----- pets -----

local petCards: { [string]: Frame } = {}
local function refreshPets()
	local pb = menus.Pets.Panel.Body
	local pets = (profile and profile.pets) or {}
	pb.Empty.Visible = #pets == 0
	pb.Grid.Visible = #pets > 0
	local equipped = profile and profile.equippedPet or ""
	local eqPet = nil
	local seen: { [string]: boolean } = {}
	local order = table.clone(pets)
	table.sort(order, function(a, b)
		local ia, ib2 = table.find(MATERIALS, a.rarity) or 0, table.find(MATERIALS, b.rarity) or 0
		if ia ~= ib2 then
			return ia > ib2
		end
		return (a.n or 0) < (b.n or 0)
	end)
	for i, pet in ipairs(order) do
		seen[pet.id] = true
		local card = petCards[pet.id]
		if not card or not card.Parent then
			card = pb.Grid.PetCard:Clone()
			card.Name = "Pet_" .. pet.id
			card.Visible = true
			card.Parent = pb.Grid
			petCards[pet.id] = card
			PetModel.viewport(card.View, pet.species)
			juicy(card.Equip, function()
				if profile and profile.equippedPet == pet.id then
					return
				end
				Net.event("RequestEquipPet"):FireServer(pet.id)
			end)
		end
		card.LayoutOrder = i
		local info = EconomyConfig.MATERIAL_INFO[pet.rarity]
		local def = EconomyConfig.FAMILIES[pet.family]
		setText(card.PetName, pet.species)
		setText(card.Rarity, if info then string.upper(info.name) else "")
		card.Rarity.TextColor3 = info and info.text or Theme.white
		setText(card.Ability, "ABILITY: " .. (def and def.ability or "?"))
		if pet.id == equipped then
			eqPet = pet
			setPlate(card.Equip, "EQUIPPED", "dark")
		else
			setPlate(card.Equip, "EQUIP", "green")
		end
	end
	for id, card in pairs(petCards) do
		if not seen[id] then
			card:Destroy()
			petCards[id] = nil
		end
	end
	local rows = math.ceil(#order / 4)
	pb.Grid.CanvasSize = UDim2.fromOffset(0, rows * 384)
	if eqPet then
		local def = EconomyConfig.FAMILIES[eqPet.family]
		setText(pb.Equipped, ("EQUIPPED: %s  ·  %s"):format(string.upper(eqPet.species), def and def.ability or ""))
	else
		setText(pb.Equipped, "EQUIPPED: NONE  ·  pick a pet to bring its ability into matches")
	end
end

-- ----- shop -----

local KIND_WORDS = {
	trail = "ONE MATCH",
	burst = "LOBBY  ·  SINGLE USE",
	case = "EGG CASE  ·  KEEP",
	entrance = "ENTRANCE  ·  KEEP",
	trailPerm = "EGG TRAIL  ·  KEEP",
	abilityFx = "ABILITY COLORS  ·  KEEP",
	hatchFx = "HATCHING  ·  KEEP",
}
local shopCards: { [string]: Frame } = {}

local function itemAction(item: any)
	if not profile then
		return
	end
	local cos = profile.cosmetics
	local owned = cos.owned[item.id] == true
	if owned and item.kind == "case" then
		Net.event("RequestSetCosmetic"):FireServer("case", if cos.case == item.id then "" else item.id)
		return
	end
	if owned then
		return
	end
	local wallet = profile[item.wallet] or 0
	if wallet < item.price then
		UI.toast(("Need %d more %s"):format(item.price - wallet, if item.wallet == "gems" then "Gems" else "Gold"), "info")
		return
	end
	Net.event("RequestBuy"):FireServer(item.id)
end

local function refreshShop()
	local sb = menus.Shop.Panel.Body
	local tabs = sb.Tabs
	for tab, plate in pairs({ gold = tabs.GoldTab, gems = tabs.GemTab }) do
		local on = shopTab == tab
		plate.Face.BackgroundTransparency = if on then 0 else 0.55
		plate.Face.Accent.Visible = on
		plate.Face.Label.TextTransparency = if on then 0 else 0.4
	end
	setText(sb.Wallet.Gold.Amount, Format.short(profile and profile.gold or 0))
	setText(sb.Wallet.Gems.Amount, Format.short(profile and profile.gems or 0))
	local cos = profile and profile.cosmetics or { owned = {}, consumables = {}, case = "", trailNext = "" }
	local n = 0
	for i, item in ipairs(EconomyConfig.SHOP) do
		local card = shopCards[item.id]
		if not card or not card.Parent then
			card = sb.Grid.ItemCard:Clone()
			card.Name = "Item_" .. item.id
			card.Parent = sb.Grid
			shopCards[item.id] = card
			juicy(card.Buy, function()
				itemAction(item)
			end)
			juicy(card.Use, function()
				Net.event("RequestUseItem"):FireServer(item.id)
			end)
		end
		local show = item.wallet == shopTab
		card.Visible = show
		card.LayoutOrder = i
		if show then
			n += 1
			card.Swatch.BackgroundColor3 = item.color
			setText(card.ItemName, item.name)
			local kind = KIND_WORDS[item.kind] or ""
			setText(card.Desc, item.desc)
			setText(card.Price.Amount, Format.full(item.price))
			local gems = item.wallet == "gems"
			card.Price.Coin.Visible = not gems
			card.Price.Gem.Visible = gems
			card.Price.Amount.TextColor3 = if gems then Theme.gemText else Theme.goldText
			local owned = cos.owned[item.id] == true
			local count = cos.consumables[item.id] or 0
			local afford = (profile and profile[item.wallet] or 0) >= item.price
			card.Price.Visible = not owned
			card.Use.Visible = item.kind == "burst" and count > 0
			card.Owned.Visible = false
			if item.kind == "case" and owned then
				local worn = cos.case == item.id
				setPlate(card.Buy, if worn then "TAKE OFF" else "WEAR", if worn then "grey" else "blue")
				kind = if worn then "EGG CASE  ·  WORN" else "EGG CASE  ·  OWNED"
			elseif owned then
				setPlate(card.Buy, "OWNED", "dark")
				kind ..= "  ·  OWNED"
			else
				setPlate(card.Buy, "BUY", if afford then "green" else "grey")
				if count > 0 then
					kind ..= ("  ·  YOU HAVE %d%s"):format(count, if cos.trailNext == item.id then " (NEXT MATCH)" else "")
				end
			end
			setText(card.Kind, kind)
			card.Kind.TextColor3 = if owned or count > 0 then Theme.gemText else Theme.mutedText
		end
	end
	sb.Grid.CanvasSize = UDim2.fromOffset(0, math.ceil(n / 3) * 264)
	setText(sb.Footer, if shopTab == "gems" then "You earn a few Gems every match. Premium looks only: nothing makes you faster or tag farther." else "Gold is earned by playing. Everything here is looks only: nothing makes you faster or tag farther.")
end

function UI.refreshPanels()
	if not profile then
		return
	end
	-- quests
	local qb = menus.Quests.Panel.Body
	local secs = 86400 - (math.floor(serverNow()) % 86400)
	setText(qb.ResetTimer, "NEW QUESTS IN " .. Format.duration(secs))
	local rows = questRows()
	for i = 1, 2 do
		local card = qb.List:FindFirstChild("Quest" .. i)
		local q = rows[i]
		if card then
			card.Visible = q ~= nil
			if q then
				setText(card.Title, q.title)
				setText(card.Reward, "+" .. q.reward .. " GOLD")
				local pct = math.clamp(q.progress / math.max(q.target, 1), 0, 1)
				card.Progress.Fill.Size = UDim2.fromScale(pct, 1)
				setText(card.Progress.Label, Format.full(q.progress) .. " / " .. Format.full(q.target))
				if q.claimed then
					setPlate(card.Claim, "CLAIMED", "dark")
				elseif q.progress >= q.target then
					setPlate(card.Claim, "CLAIM!", "green")
				else
					setPlate(card.Claim, "CLAIM", "grey")
				end
				card.Claim:SetAttribute("QuestId", q.id)
			end
		end
	end
	refreshIncubator()
	if openName == "Pets" then
		refreshPets()
	end
	if openName == "Shop" then
		refreshShop()
	end
	if UI.onEmotesRefresh then
		UI.onEmotesRefresh(profile, openName == "Emotes") -- EmoteController draws the Emotes panel
	end
	-- stats
	local sl = menus.Stats.Panel.Body.List
	local st = profile.stats
	local vals = {
		Wins = Format.short(st.wins or 0),
		Matches = Format.short(st.matchesCompleted or 0),
		Crossings = Format.short(st.successfulCrossings or 0),
		Captures = Format.short(st.captures or 0),
		BestTier = "LEVEL " .. (st.lifetimeBestTier or 1),
		Pets = Format.short(st.petsHatched or 0),
		GoldEarned = Format.short(st.goldEarned or 0),
		FirstHunter = Format.short(st.timesFirstHunter or 0),
	}
	for name, v in pairs(vals) do
		local row = sl:FindFirstChild(name)
		if row then
			setText(row.Value, v)
		end
	end
	-- settings
	local set = menus.Settings.Panel.Body.List
	for key, rowName in pairs({ sfx = "Sfx", reduceEffects = "ReduceEffects", showHints = "ShowHints" }) do
		local row = set:FindFirstChild(rowName)
		if row then
			local on = settings[key] == true
			setPlate(row.Toggle, if on then "ON" else "OFF", if on then "green" else "grey")
		end
	end
end

-- ===== results =====

local function closeResults()
	resultsOpen = false
	results.Root.Visible = false
	hud.Enabled = true
end

local REASONS = {
	LAST_ONE_STANDING = "THE LAST RUNNER MADE IT ACROSS ALONE",
	CLEAN_STREAK = "NOBODY WAS CAUGHT 3 CROSSINGS IN A ROW",
	SAFETY_CAP = "THE MATCH RAN LONG: THE RUNNERS STILL GOING WIN",
	FINAL_WAVE = "RUNNERS SURVIVED ALL 3 CROSSINGS",
	ALL_RUNNERS_GONE = "EVERY RUNNER WAS CAUGHT",
}

-- the "next hatch" bar under the piece you just won (reads your profile, which lands just after)
local function refreshRecipe()
	if not resultsData or not resultsData.you then
		return
	end
	local you = resultsData.you
	local bar = results.Root.You.Recipe
	local m = you.material
	bar.Visible = m ~= nil
	if not m then
		return
	end
	local base = costFor(m, false)
	local n = have(m)
	bar.Fill.Size = UDim2.fromScale(math.clamp(n / base, 0, 1), 1)
	local word = if m == "common" and firstFree() then "FIRST PET" else "NEXT HATCH"
	if haveFor(m) >= base then
		setText(bar.Label, ("%s %d / %d  ·  READY TO HATCH!"):format(materialName(m), n, base))
	else
		setText(bar.Label, ("%s %d / %d  ·  %s"):format(materialName(m), n, base, word))
	end
end

local function showResults(data: any)
	resultsData = data
	local root = results.Root
	hud.Enabled = false -- the results card owns the screen (no HUD poking through the dim)
	local runnersWon = data.team == "RUNNERS"
	setText(root.TeamBanner, if runnersWon then "RUNNERS WIN!" else "CATCHERS WIN!")
	root.TeamBanner.TextColor3 = if runnersWon then Theme.ramps.blue.top else Theme.ramps.red.top
	setText(root.Reason, REASONS[data.endReason] or "")
	root.TestNote.Visible = data.isTest == true
	setText(root.TestNote, "PRACTICE MATCH: REWARDS SAVE WITH 4+ REAL PLAYERS")
	for place = 1, 3 do
		local card = root.Podium:FindFirstChild("Place" .. place)
		local entry = nil
		for _, r in ipairs(data.topRunners or {}) do
			if r.place == place then
				entry = r
			end
		end
		card.Visible = entry ~= nil
		if entry then
			local uid = if entry.npcSlot then NpcSkins.userIdForSlot(entry.npcSlot) else entry.userId
			card.Avatar.Image = if uid and uid > 0 then ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(uid) else ""
			setText(card.PlayerName, npcName(entry.npcSlot, entry.name))
			local how = if entry.survived and data.endReason == "LAST_ONE_STANDING" then "LAST STANDING" elseif entry.survived then "SURVIVED" else Format.plural(entry.crossings, "CROSSING")
			setText(card.Detail, how .. "  ·  LEVEL " .. entry.securedTier)
			card.Detail.TextColor3 = TierConfig.get(entry.securedTier).text
		end
	end
	local thief = data.topThief
	root.Thief.Visible = thief ~= nil
	if thief then
		local uid = if thief.npcSlot then NpcSkins.userIdForSlot(thief.npcSlot) else thief.userId
		root.Thief.Avatar.Image = if uid and uid > 0 then ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(uid) else ""
		setText(root.Thief.PlayerName, npcName(thief.npcSlot, thief.name))
		setText(root.Thief.Detail, Format.plural(thief.captures, "CAPTURE") .. "  ·  STOLE LEVEL " .. thief.bestStolenTier)
	end
	local you = data.you
	root.You.Visible = you ~= nil
	if you then
		local m = you.material
		local info = m and EconomyConfig.MATERIAL_INFO[m]
		UIKit.setEggIcon(root.You.Egg, if m then MATERIAL_EGG[m] or 1 else 1)
		root.You.Egg.Visible = m ~= nil
		if m and info then
			setText(root.You.Headline, string.upper(info.name) .. " EGG PIECE!")
			root.You.Headline.TextColor3 = info.text
		else
			setText(root.You.Headline, "NO EGG PIECE THIS MATCH")
			root.You.Headline.TextColor3 = Theme.mutedText
		end
		-- (practice matches already say so in TestNote; a suffix here only pushed the line off small screens)
		local src = if you.eligible then (you.source or "") else "Move, cross or tag to earn rewards"
		setText(root.You.Source, src)
		root.You.NearMiss.Visible = you.eligible == true and you.nearMiss ~= nil
		setText(root.You.NearMiss, (you.nearMiss or ""):gsub("TIER", "LEVEL"))
		setText(root.You.Gold.Total, "+" .. Format.full(you.gold or 0))
		local lines = {}
		for _, part in ipairs(you.goldParts or {}) do
			table.insert(lines, ("%s  +%d"):format(part.label, part.amount))
		end
		setText(root.You.Gold.Lines, table.concat(lines, "\n"))
		setText(root.You.Gems.Total, "+" .. Format.full(you.gems or 0))
		root.You.Gems.Visible = (you.gems or 0) > 0
		refreshRecipe()
		if you.win then
			Sound.play("reward")
		end
	end
	-- results own the screen: drop queued banners so nothing plays underneath
	table.clear(bannerQueue)
	hud.Banner.Visible = false
	resultsOpen = true
	root.Visible = true
	pop(root)
	UI.close()
end

-- ===== device layout =====
-- Top-left pills sit just right of Roblox's own buttons (GuiService.TopbarInset is the free strip).
-- Touch: the rail becomes a drawer under a MENU button (thumbstick zone stays clear).
local appliedLayout: boolean? = nil
local topDrop = 0 -- real px the lobby status drops by when the topbar row is too narrow for it
local topPlaced: number? = nil
local function isTouchLayout(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function applyLayout(force: boolean?)
	local touch = isTouchLayout()
	local inset = GuiService.TopbarInset
	local key = tostring(touch) .. tostring(inset.Min.X) .. tostring(inset.Max.Y) .. tostring(hud.AbsoluteSize) -- (a resize can cramp the top row)
	if key == appliedLayout and not force then
		return
	end
	appliedLayout = key :: any
	Fit.refreshAll() -- the scale depends on the device: settle it before placing by it
	-- pills in the topbar row, right after Roblox's buttons (real pixels, so they go in FitExtra)
	local s = Fit.scaleFor(hud.TopLeft)
	local rowY = math.max(inset.Min.Y, 0) + math.max(0, (inset.Height - 54 * s) / 2)
	Fit.setDesignPosition(hud.TopLeft, Vector2.new(0, 0), UDim2.new(0, 10, 0, 0), Vector2.new(math.max(inset.Min.X, 0), rowY))
	Fit.setDesignPosition(hud.TopRight, Vector2.new(1, 0), UDim2.new(1, -12, 0, 0), Vector2.new(0, rowY))
	-- the lobby status ("WAITING FOR PLAYERS", ~660 design px) is centred in that same row; on phones
	-- and small windows the pills reach under it, so it drops below Roblox's topbar instead
	local canvasX = hud.AbsoluteSize.X
	local tlRight = math.max(inset.Min.X, 0) + (10 + 450) * s
	local trLeft = canvasX - (12 + 432) * s
	local half = 330 * s + 10
	local cramped = canvasX / 2 - tlRight < half or trLeft - canvasX / 2 < half
	topDrop = if cramped then math.max(inset.Max.Y, 0) + 4 - 6 * s else 0
	topPlaced = nil
	if touch then
		-- the thumbstick owns the bottom-left: the wallet goes under the top-right buttons, the rail
		-- becomes a drawer under a MENU button
		local below = Vector2.new(0, math.max(inset.Max.Y, 0) + 4)
		Fit.setDesignPosition(hud.MenuButton, Vector2.new(0, 0), UDim2.new(0, 14, 0, 4), below)
		Fit.setDesignPosition(hud.LeftRail, Vector2.new(0, 0), UDim2.new(0, 14, 0, 76), below)
		Fit.setDesignPosition(hud.Wallet, Vector2.new(1, 0), UDim2.new(1, -12, 0, 6), below)
	else
		Fit.setDesignPosition(hud.LeftRail, Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, 0))
		Fit.setDesignPosition(hud.Wallet, Vector2.new(0, 1), UDim2.new(0, 12, 1, -12))
	end
end

-- ===== HUD update =====

local lastTick = -1
local function hatchReady(): boolean
	for _, m in ipairs(MATERIALS) do
		if haveFor(m) >= costFor(m, false) and have(m) > 0 then
			return true
		end
	end
	return false
end

local function updateAbility(inMatch: boolean, touch: boolean)
	local card = hud.AbilityBar.Card
	local fam = Pets.family()
	local species = player:GetAttribute("EOS_PetSpecies")
	local rarity = player:GetAttribute("EOS_PetRarity")
	local def = fam and EconomyConfig.FAMILIES[fam]
	local ramp = Theme.ramps[(fam and FAMILY_RAMP[fam]) or "grey"]
	if card:GetAttribute("Species") ~= (species or "") then
		card:SetAttribute("Species", species or "")
		if type(species) == "string" and species ~= "" then
			PetModel.viewport(card.IconRing.Icon, species)
		else
			card.IconRing.Icon:ClearAllChildren()
		end
		local tint = card:FindFirstChild("Tint")
		if tint then
			tint.Color = ColorSequence.new(Theme.panel:Lerp(ramp.lip, 0.35), Theme.panel:Lerp(ramp.lip, 0.12))
		end
	end
	card.IconRing.Empty.Visible = def == nil
	hud.AbilityBar.Visible = def ~= nil -- minimal HUD: no "NO PET YET" card, only a real ability
	if def then
		setText(card.AbilityName, def.ability)
		-- short enough for a phone at the minimum text size (longest: "EPIC MIRROR DRAGON")
		setText(card.Sub, ("%s %s"):format(materialName(rarity), string.upper(species or "")))
		card.Sub.TextColor3 = def.color
	else
		setText(card.AbilityName, "NO PET YET")
		setText(card.Sub, "VISIT THE INCUBATOR")
		card.Sub.TextColor3 = Theme.mutedText
	end
	local charge = if def and inMatch then Pets.charge() else 1
	card.Cooldown.Fill.Size = UDim2.fromScale(math.clamp(charge, 0, 1), 1)
	card.Cooldown.Fill.BackgroundColor3 = if charge >= 1 then ramp.mid else Theme.mutedText
	card.Cooldown.Visible = def ~= nil
	local dev = deviceClass()
	card.Key.Visible = def ~= nil and dev ~= "touch"
	local left = math.max(0, Pets.readyAt - os.clock())
	setPlate(card.Key, if inMatch and left > 0 then ("%d"):format(math.ceil(left)) elseif dev == "gamepad" or dev == "console" then "Y" else "Q")
	-- touch: round button while it can be used
	local btn = hud.AbilityButton
	btn.Visible = touch and inMatch and def ~= nil
	if btn.Visible and def then
		setText(btn.Button.Face.Label, def.ability)
		UIKit.setRamp(btn.Button, FAMILY_RAMP[fam :: string] or "orange")
		local cd = btn.Button:FindFirstChild("Cooldown", true)
		if cd then
			cd.Visible = left > 0
			setText(cd.Count, if left > 0 then ("%d"):format(math.ceil(left)) else "")
		end
	end
end

local function updateHUD()
	local phase = state:GetAttribute("Phase") or "BOOT"
	local endsAt = state:GetAttribute("PhaseEndsAt") or serverNow()
	local left = math.max(0, endsAt - serverNow())
	local inMatch = player:GetAttribute("EOS_InMatch") == true
	local role = player:GetAttribute("EOS_Role")
	local afk = player:GetAttribute("EOS_AFK") == true
	local practice = player:GetAttribute("EOS_InPractice") == true
	local top = hud.TopCenter
	local touch = isTouchLayout()

	-- lobby vs match layout (HUDs stay quiet: lobby menus and economy counters hide during matches)
	applyLayout()
	hud.MenuButton.Visible = touch and not inMatch
	hud.LeftRail.Visible = not inMatch and (not touch or railOpen)
	hud.TopLeft.Visible = not inMatch
	hud.TopRight.Visible = not inMatch
	local drop = if inMatch then 0 else topDrop -- in a match the pills are hidden: the bar keeps the row
	if drop ~= topPlaced then
		topPlaced = drop
		Fit.setDesignPosition(top, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 6), Vector2.new(0, drop))
	end
	hud.Wallet.Visible = not inMatch
	top.StatusPill.Visible = not inMatch
	top.MatchBar.Visible = inMatch
	hud.RolePanel.Visible = inMatch
	top.AFKBanner.Visible = afk and not inMatch
	if not inMatch then
		top.ArrowHolder.Visible = false
	end
	updateAbility(inMatch, touch)

	if not inMatch then
		local title, sub
		if phase == "BOOT" or not player:GetAttribute("EOS_Loaded") then
			title, sub = "LOADING...", player:GetAttribute("EOS_LoadStatus") or "Getting your save"
		elseif phase == "WAITING" then
			title = "WAITING FOR PLAYERS"
			sub = ("%d / %d READY  ·  TRY THE PRACTICE FIELD"):format(state:GetAttribute("Ready") or 0, state:GetAttribute("Needed") or 4)
		elseif phase == "INTERMISSION" then
			title = "NEXT MATCH IN " .. Format.time(left)
			sub = if afk then "AFK: YOU'RE STAYING IN THE LOBBY" else Format.plural(state:GetAttribute("Ready") or 0, "PLAYER") .. " READY"
		elseif phase == "RESULTS" then
			title, sub = "MATCH OVER", "NEXT MATCH SOON"
		else
			title = "MATCH IN PROGRESS"
			sub = if afk then "TURN AFK OFF TO JOIN THE NEXT ONE" else "YOU'RE IN THE NEXT ONE"
		end
		setText(top.StatusPill.Place, if practice then "PRACTICE FIELD" else "LOBBY")
		if practice then
			sub = "NO REWARDS HERE"
		end
		setText(top.StatusPill.Title, title)
		setText(top.StatusPill.Sub, sub)
	else
		local bar = top.MatchBar
		local wave = state:GetAttribute("Wave") or 0
		local lone = state:GetAttribute("LastStanding")
		local streak, toWin = state:GetAttribute("CleanStreak") or 0, state:GetAttribute("StreakToWin") or 3
		-- minimal HUD: the timer card is the whole bar (wave tag, clean-run dots and counts are off)
		local _ = wave
		bar.WaveTag.Visible = false
		bar.Streak.Visible = false
		bar.Counts.Visible = false
		setText(bar.TimerCard.Timer, Format.time(left))
		local urgent = phase == "CROSSING" and left <= 5
		bar.TimerCard.Timer.TextColor3 = if urgent then Theme.ramps.red.top else Theme.white
		if urgent and math.ceil(left) ~= lastTick then
			lastTick = math.ceil(left)
			Sound.play("tick", 1.2)
		end
		local phaseText = if phase == "ROLE_REVEAL" then "GET READY" elseif phase == "WAVE_END" then "SIDES FLIP" elseif role == "CATCHER" then "HUNT!" elseif role == "CAUGHT" then "YOU'RE OUT" else "CROSS!"
		setText(bar.TimerCard.PhaseLabel, phaseText)

		-- role panel (the egg level is the one number the chase keeps on screen)
		local rp = hud.RolePanel
		local card = rp.Card
		local finish = state:GetAttribute("FinishSide") or "B"
		local safe = player:GetAttribute("EOS_Safe") == true
		local secured = player:GetAttribute("EOS_Secured") or 1
		-- minimal HUD: role chip + one line (the egg level). Objectives live in the arrow and the timer label.
		card.Line2.Visible = false
		card.Objective.Visible = false
		local shownTier = if role == "RUNNER" then (player:GetAttribute("EOS_Tier") or 1) else secured
		if role == "RUNNER" then
			setPlate(rp.RoleTag, "RUNNER", "blue")
		elseif role == "CAUGHT" then
			setPlate(rp.RoleTag, "CAUGHT", "grey")
		else
			setPlate(rp.RoleTag, "CATCHER", "red")
		end
		if card.Egg:GetAttribute("Tier") ~= shownTier then
			UIKit.setEggIcon(card.Egg, shownTier)
		end
		setText(card.Line1, "EGG LEVEL " .. shownTier)
		card.Line1.TextColor3 = TierConfig.get(shownTier).text
		local _ = { lone, streak, toWin, safe }

		-- direction arrow (Runners, not yet safe)
		local holder = top.ArrowHolder
		local showArrow = role == "RUNNER" and not safe and (phase == "CROSSING" or phase == "ROLE_REVEAL")
		holder.Visible = showArrow
		if showArrow then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local cam = workspace.CurrentCamera
			if hrp and cam then
				local zone = Layout.Zones[finish]
				local edgeX = zone.center.X + (if finish == "A" then zone.size.X / 2 else -zone.size.X / 2)
				local targetPos = Vector3.new(edgeX, hrp.Position.Y, hrp.Position.Z)
				local dir = targetPos - hrp.Position
				local rel = cam.CFrame:VectorToObjectSpace(Vector3.new(dir.X, 0, dir.Z))
				holder.Arrow.Rotation = math.deg(math.atan2(rel.X, -rel.Z))
				holder.ArrowLabel.Visible = false -- minimal HUD: the arrow alone points the way
			end
		end
	end

	-- TAG button: touch players (Catchers in a match)
	hud.TagButton.Visible = inMatch and role == "CATCHER" and touch
	local cd = hud.TagButton.Button:FindFirstChild("Cooldown", true)
	if cd then
		cd.Visible = os.clock() - Tag.lastSwing < GameConfig.Capture.TAG_COOLDOWN
	end

	-- dash: round button on touch, slim meter on PC / gamepad (neither for Catchers: they can't dash)
	local blocked = Movement.blockedReason()
	-- Catchers don't dash: the same meter / button is their lunge (Space)
	local lungeMode = blocked == "CATCHER"
	local charge = if lungeMode then Tag.lungeCharge() else Movement.dashCharge()
	if lungeMode then
		blocked = if charge < 1 then "COOLDOWN" else nil
	end
	local canDash = true
	hud.DashButton.Visible = touch and canDash
	hud.DashBar.Visible = not touch and canDash
	local dashLabel = hud.DashButton.Button:FindFirstChild("Label", true)
	if dashLabel and dashLabel:IsA("TextLabel") then
		setText(dashLabel, if lungeMode then "LUNGE" else "DASH")
	end
	local dcd = hud.DashButton.Button:FindFirstChild("Cooldown", true)
	if dcd then
		dcd.Visible = blocked ~= nil and blocked ~= "OFF"
		local dleft = if lungeMode then math.max(0, Tag.lastLunge + GameConfig.Lunge.COOLDOWN - os.clock()) else math.max(0, Movement.dashReadyAt - os.clock())
		setText(dcd.Count, if blocked == "COOLDOWN" then ("%.1f"):format(dleft) else "")
	end
	local bar = hud.DashBar
	bar.Track.Fill.Size = UDim2.fromScale(math.clamp(charge, 0.02, 1), 1)
	local dev = deviceClass()
	local pad = dev == "gamepad" or dev == "console"
	setText(bar.Key, if pad then "A  ·  DASH" else "SPACE  ·  DASH")
	setText(bar.Tip, if pad then "SIDE/BACK + A = DODGE" else "SIDE/BACK + SPACE = DODGE")
	if blocked == "PAUSED" then
		setText(bar.Status, "DASH PAUSED")
		bar.Status.TextColor3 = Theme.mutedText
	elseif blocked == "COOLDOWN" then
		setText(bar.Status, "RECHARGING")
		bar.Status.TextColor3 = Theme.ramps.orange.top
	elseif os.clock() - Movement.refusedAt < 1.2 then
		-- no forward dash, against the camera or against the way the body faces: say why
		setText(bar.Status, if Movement.refusedWhy == "FACING" then "NOT THE WAY YOU FACE" else "SIDE OR BACK ONLY")
		bar.Status.TextColor3 = Theme.ramps.orange.top
	else
		setText(bar.Status, "DASH READY")
		bar.Status.TextColor3 = Theme.white
	end
	-- minimal HUD: just the meter; text only when a dash was refused (says why it didn't fire)
	bar.Key.Visible = false
	bar.Tip.Visible = false
	bar.Status.Visible = os.clock() - Movement.refusedAt < 1.2 and blocked == nil

	-- rail toggles (real state)
	local rail = hud.LeftRail
	-- phone-sized tiles can't fit "HUNT: OFF" at the smallest text size: the label drops the ON/OFF
	-- word there (the tile's lit state already shows it)
	local roomy = rail.AFKToggle.Face.Label.AbsoluteSize.X >= 48
	setPlate(rail.AFKToggle, if not roomy then "AFK" elseif afk then "AFK: ON" else "AFK: OFF")
	setLit(rail.AFKToggle, afk)
	local vol = player:GetAttribute("EOS_Volunteer") == true
	setPlate(rail.VolunteerToggle, if not roomy then "HUNT" elseif vol then "HUNT: ON" else "HUNT: OFF")
	setLit(rail.VolunteerToggle, vol)

	-- hint line
	local hint = ""
	if settings.showHints and not inMatch then -- minimal HUD: no hint text during a match
		if inMatch and role == "CATCHER" then
			hint = if dev == "touch" then "TAP TAG OR TOUCH A RUNNER  ·  YOU CAN'T ENTER SAFE ZONES" elseif pad then "R2 TO TAG  ·  YOU CAN'T ENTER SAFE ZONES" else "CLICK OR PRESS E TO TAG WHERE YOU AIM  ·  YOU CAN'T ENTER SAFE ZONES"
		elseif inMatch and role == "RUNNER" then
			hint = "REACH THE GLOWING SAFE ZONE  ·  NOBODY CAN TAG YOU INSIDE IT"
		elseif inMatch and role == "CAUGHT" then
			hint = "YOU'RE OUT THIS CROSSING  ·  WATCH, THEN HUNT AS A CATCHER NEXT ROUND"
		elseif practice then
			hint = "CROSS PAD TO PAD AND DODGE THE PRACTICE CATCHER"
		elseif os.clock() - joinedAt < 90 then
			hint = "MATCHES START AUTOMATICALLY  ·  WIN EGG PIECES, HATCH PETS AT THE INCUBATOR"
		end
	end
	setText(hud.Hint.Text, hint)

	-- badges: data-driven, only for something actionable
	local claimable = 0
	for _, q in ipairs(questRows()) do
		if not q.claimed and q.progress >= q.target then
			claimable += 1
		end
	end
	hud.TopLeft.QuestsPill.Badge.Visible = claimable > 0
	hud.TopLeft.IncubatorPill.Badge.Visible = hatchReady()

	-- results countdown / auto-close
	if resultsOpen and resultsData then
		local nm = resultsData.nextMatchAt or serverNow()
		local txt
		if phase == "WAITING" then
			txt = "WAITING FOR PLAYERS"
		else
			txt = "NEXT MATCH IN " .. Format.time(math.max(0, nm - serverNow()))
		end
		setText(results.Root.NextMatch, txt)
		if phase == "ROLE_REVEAL" or serverNow() > nm + 2 then
			closeResults()
		end
	end

	-- expire toasts / feed
	local now = os.clock()
	for i = #toastList, 1, -1 do
		if now > toastList[i].untilT then
			toastList[i].frame:Destroy()
			table.remove(toastList, i)
		end
	end
	for i = #feedList, 1, -1 do
		if now > feedList[i].untilT then
			feedList[i].frame:Destroy()
			table.remove(feedList, i)
		end
	end
end

-- ===== wallet (count-ups) =====

local shown = { gold = 0, gems = 0 }
local tweens: { [string]: RBXScriptConnection? } = {}
local function setWallet(key: string, target: number)
	local card = if key == "gold" then hud.Wallet.GoldCard else hud.Wallet.GemsCard
	local conn = tweens[key]
	if conn then
		conn:Disconnect()
		tweens[key] = nil
	end
	local from = shown[key]
	if target == from then
		setText(card.Value, Format.full(target))
		return
	end
	local t0 = os.clock()
	tweens[key] = RunService.Heartbeat:Connect(function()
		local k = math.clamp((os.clock() - t0) / Theme.motion.countUp, 0, 1)
		local v = if k >= 1 then target else math.floor(from + (target - from) * k)
		shown[key] = v
		setText(card.Value, Format.full(v))
		if k >= 1 then
			local c = tweens[key]
			if c then
				c:Disconnect()
				tweens[key] = nil
			end
		end
	end)
	if target > from and from > 0 then
		pop(hud.Wallet, 0.9)
	end
end

-- ===== settings =====

local function applySettings()
	Sound.enabled = settings.sfx ~= false
	CameraFX.reduceEffects = settings.reduceEffects == true
	WorldFX.reduceEffects = settings.reduceEffects == true
end

-- ===== events =====

local function tierColor(t: number): Color3
	return TierConfig.get(t).text
end

local function connectEvents()
	Net.event("ProfileState").OnClientEvent:Connect(function(view)
		if type(view) ~= "table" then
			return
		end
		profile = view
		if not settingsInit and type(view.settings) == "table" then
			settingsInit = true
			for k, v in pairs(view.settings) do
				settings[k] = v
			end
			applySettings()
		end
		setWallet("gold", view.gold or 0)
		setWallet("gems", view.gems or 0)
		UI.refreshPanels()
		if resultsOpen then
			refreshRecipe()
		end
	end)
	Net.event("QuestState").OnClientEvent:Connect(function() end)
	Net.event("Toast").OnClientEvent:Connect(function(t)
		if type(t) == "table" and type(t.text) == "string" then
			UI.toast(t.text, t.kind)
		end
	end)
	Net.event("OpenScreen").OnClientEvent:Connect(function(t)
		if type(t) == "table" and table.find(PANELS, t.name) then
			if t.name == "Shop" and (t.tab == "gold" or t.tab == "gems") then
				shopTab = t.tab
				if openName == "Shop" then
					refreshShop()
					return
				end
			end
			UI.open(t.name)
		end
	end)
	Net.event("HatchResult").OnClientEvent:Connect(function(t)
		if type(t) ~= "table" then
			return
		end
		local picker, confirm = incubatorOverlays()
		picker.Visible = false
		if t.ok and type(t.pet) == "table" then
			confirm.Visible = false
			showReveal(t)
		elseif t.reason == "NEEDS_HIGHER" and t.plan then
			-- say exactly which higher pieces it would use, then ask
			local parts, count = {}, 0
			for _, m in ipairs(MATERIALS) do
				local n = t.plan.take and t.plan.take[m]
				if n and n > 0 and m ~= t.plan.rarity then
					table.insert(parts, ("%d %s"):format(n, materialName(m)))
					count += n
				end
			end
			setText(confirm.Body, ("This hatch uses %s piece%s in place of %s pieces. Higher pieces are worth more: use them anyway?"):format(table.concat(parts, " + "), if count == 1 then "" else "s", materialName(t.plan.rarity)))
			confirm.Visible = true
		elseif t.reason == "CHOOSE_FAMILY" and t.plan then
			openPicker(t.plan.rarity)
		end
		syncIncubator()
	end)
	Net.event("ShopResult").OnClientEvent:Connect(function(t)
		if type(t) == "table" and t.ok then
			Sound.play("reward", 1.1)
		end
	end)
	Net.event("PracticeEvent").OnClientEvent:Connect(function(t)
		if t.kind == "crossed" then
			UI.toast("PRACTICE CROSSING! (no rewards in practice)", "reward")
			Sound.play("evolve", 1.1)
		elseif t.kind == "tagged" then
			UI.toast("Tagged by the practice Catcher. Try again!", "warn")
			Sound.play("caught")
		end
	end)
	Net.event("RoleChanged").OnClientEvent:Connect(function(t)
		if t.cause == "START" then
			task.delay(0.15, function()
				local finish = state:GetAttribute("FinishSide") or "B"
				local target = if t.role == "RUNNER" then Layout.Zones[finish].center else Layout.Arena.CENTER
				CameraFX.lookToward(target)
			end)
			if t.role == "RUNNER" then
				UI.banner("YOU'RE A RUNNER", "Carry your egg to the glowing safe zone. Each crossing = +1 level", Theme.ramps.blue.top, Theme.ramps.blue.mid, 2.6)
			else
				UI.banner("YOU'RE THE CATCHER", "Tag Runners to steal their eggs (up to level " .. TierConfig.CATCHER_TIER_CAP .. ")", Theme.ramps.red.top, Theme.ramps.red.mid, 2.6)
			end
		elseif t.cause == "CAPTURED" then
			Sound.play("caught")
			CameraFX.shake(1.2, 0.3)
			UI.banner("CAUGHT!", nil, Theme.ramps.red.top, Theme.ramps.red.mid, 1.6)
		elseif t.cause == "TIMEOUT" then
			Sound.play("caught", 0.8)
			UI.banner("TOO SLOW!", nil, Theme.ramps.orange.top, Theme.ramps.orange.mid, 1.6)
		end
		-- (NEXT_ROUND: no banner; the role chip flips to CATCHER)
	end)
	Net.event("RunnerEvolved").OnClientEvent:Connect(function(t)
		local who: any = if t.slot then NpcSkins.modelForSlot(t.slot) else Players:GetPlayerByUserId(t.userId)
		if who then
			WorldFX.evolve(who, TierConfig.get(t.newTier).shell)
		end
		if t.userId == player.UserId then
			Sound.play("evolve")
			UI.banner("SAFE! LEVEL " .. t.newTier, nil, tierColor(t.newTier), TierConfig.get(t.newTier).shell, 1.4)
		else
			UI.feed(('<font color="#%s">%s</font> is SAFE (Level %d)'):format(TierConfig.get(t.newTier).text:ToHex(), npcName(t.slot, t.name), t.newTier))
		end
	end)
	Net.event("CaptureFeedback").OnClientEvent:Connect(function(t)
		if typeof(t.position) == "Vector3" then
			WorldFX.capture(t.position)
		end
		Sound.play("capture")
		UI.feed(('<font color="#ff7a7a">%s</font> caught %s <font color="#%s">(Level %d)</font>'):format(npcName(t.hunterSlot, t.hunterName), npcName(t.victimSlot, t.victimName), TierConfig.get(t.stolenTier or 1).text:ToHex(), t.stolenTier or 1))
		if t.hunterId == player.UserId then
			UI.banner("STOLE LEVEL " .. (t.stolenTier or 1) .. "!", nil, Theme.gold, Theme.gold, 1.4)
			CameraFX.shake(0.6, 0.2)
		end
	end)
	Net.event("MatchState").OnClientEvent:Connect(function(t)
		if not player:GetAttribute("EOS_InMatch") then
			return
		end
		if t.phase == "CROSSING" then
			-- minimal HUD: no per-crossing banner (the timer label says CROSS!/HUNT!); only the one call that
			-- changes how you play
			if t.lastStanding == player.UserId then
				UI.banner("LAST ONE STANDING!", nil, Theme.gold, Theme.gold, 1.6)
			end
		elseif t.phase == "WAVE_END" then
			-- (no clean-run toast: minimal HUD)
			-- after the server repositions everyone, face the next objective
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
		end
	end)
end

-- ===== wiring =====

local function wireButtons()
	juicy(hud.TopLeft.QuestsPill, function()
		UI.open("Quests")
	end)
	juicy(hud.TopLeft.IncubatorPill, function()
		UI.open("Incubator")
	end)
	juicy(hud.TopRight.StatsBtn, function()
		UI.open("Stats")
	end)
	juicy(hud.TopRight.SettingsBtn, function()
		UI.open("Settings")
	end)
	local rail = hud.LeftRail
	juicy(rail.ShopBtn, function()
		UI.open("Shop")
	end)
	juicy(rail.PetsBtn, function()
		UI.open("Pets")
	end)
	juicy(rail.EmotesBtn, function()
		UI.open("Emotes")
	end)
	UI.juicy = juicy -- EmoteController wires its panel's buttons with the same press feel
	juicy(rail.AFKToggle, function()
		Net.event("RequestAFK"):FireServer(not (player:GetAttribute("EOS_AFK") == true))
	end)
	juicy(rail.VolunteerToggle, function()
		Net.event("RequestVolunteer"):FireServer(not (player:GetAttribute("EOS_Volunteer") == true))
	end)
	juicy(hud.MenuButton.Button, function()
		railOpen = not railOpen
		if railOpen then
			pop(hud.LeftRail, 0.8)
		end
	end)
	juicy(hud.TagButton.Button, function()
		Tag.swing()
	end)
	juicy(hud.DashButton.Button, function()
		if player:GetAttribute("EOS_InMatch") == true and player:GetAttribute("EOS_Role") == "CATCHER" then
			Tag.lunge()
		else
			Movement.dash()
		end
	end)
	juicy(hud.AbilityButton.Button, function()
		Pets.use()
	end)
	for _, name in ipairs(PANELS) do
		local close = menus[name].Panel:FindFirstChild("Close")
		if close then
			juicy(close, UI.close)
		end
	end
	menus.Scrim.Activated:Connect(UI.close)
	-- quests: claim
	for i = 1, 2 do
		local claim = menus.Quests.Panel.Body.List["Quest" .. i].Claim
		juicy(claim, function()
			local id = claim:GetAttribute("QuestId")
			for _, q in ipairs(questRows()) do
				if q.id == id then
					if q.claimed then
						UI.toast("Already claimed today", "info")
					elseif q.progress < q.target then
						UI.toast("Finish the quest in a match first", "info")
					else
						Net.event("RequestQuestClaim"):FireServer(id)
						Sound.play("reward")
					end
				end
			end
		end)
	end
	-- incubator
	local inc = menus.Incubator.Panel
	for _, m in ipairs(MATERIALS) do
		local card = inc.Body.Tiers:FindFirstChild("Tier_" .. m)
		juicy(card.HatchRandom, function()
			local base = costFor(m, false)
			if haveFor(m) < base then
				UI.toast(("Need %d %s pieces (you have %d)"):format(base, materialName(m), haveFor(m)), "info")
				return
			end
			if m == "common" and firstFree() then
				openPicker(m)
			else
				sendHatch(m, nil, false)
			end
		end)
		juicy(card.HatchPick, function()
			local focus = costFor(m, true)
			if haveFor(m) < focus then
				UI.toast(("Picking a family needs %d %s pieces (you have %d)"):format(focus, materialName(m), haveFor(m)), "info")
				return
			end
			openPicker(m)
		end)
	end
	juicy(inc.Picker.Back, function()
		inc.Picker.Visible = false
		syncIncubator()
	end)
	for _, fam in ipairs(EconomyConfig.LAUNCH_FAMILIES) do
		local card = inc.Picker.Families:FindFirstChild(fam)
		juicy(card.Pick, function()
			local m = inc.Picker:GetAttribute("Material")
			if type(m) == "string" then
				sendHatch(m, fam, false)
			end
		end)
	end
	juicy(inc.Confirm.Yes, function()
		inc.Confirm.Visible = false
		syncIncubator()
		if pending then
			sendHatch(pending.rarity, pending.family, true)
		end
	end)
	juicy(inc.Confirm.No, function()
		inc.Confirm.Visible = false
		syncIncubator()
	end)
	juicy(inc.Reveal.Done, function()
		revealToken += 1
		inc.Reveal.Visible = false
		syncIncubator()
	end)
	-- pets: empty state goes to the incubator
	juicy(menus.Pets.Panel.Body.Empty.Go, function()
		UI.open("Incubator")
	end)
	-- shop tabs
	local tabs = menus.Shop.Panel.Body.Tabs
	juicy(tabs.GoldTab, function()
		shopTab = "gold"
		refreshShop()
	end)
	juicy(tabs.GemTab, function()
		shopTab = "gems"
		refreshShop()
	end)
	-- settings toggles
	local set = menus.Settings.Panel.Body.List
	for key, rowName in pairs({ sfx = "Sfx", reduceEffects = "ReduceEffects", showHints = "ShowHints" }) do
		local row = set[rowName]
		juicy(row.Toggle, function()
			settings[key] = not settings[key]
			applySettings()
			UI.refreshPanels()
			Net.event("RequestSettings"):FireServer({ [key] = settings[key] })
		end)
	end
	-- results
	juicy(results.Root.Continue, closeResults)
	-- Escape closes panels / results (handled before the processed check: Escape is the Roblox menu key)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape and not UserInputService:GetFocusedTextBox() then
			if openName then
				UI.close()
			elseif resultsOpen then
				closeResults()
			end
		end
	end)
	GuiService.MenuOpened:Connect(function()
		UI.close()
	end)
	-- every panel is a SelectionGroup for gamepads
	for _, name in ipairs(PANELS) do
		local p = menus[name].Panel
		p.SelectionGroup = true
		p.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
		p.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
		p.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
		p.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	end
end

local function resetPlaceholders()
	-- overwrite every mock value from the builder before the first real draw (LESSONS 11)
	setText(hud.TopCenter.StatusPill.Title, "LOADING...")
	setText(hud.TopCenter.StatusPill.Sub, "")
	setText(hud.Wallet.GoldCard.Value, "0")
	setText(hud.Wallet.GemsCard.Value, "0")
	hud.Banner.Visible = false
	hud.TopCenter.MatchBar.Visible = false
	hud.TopCenter.ArrowHolder.Visible = false
	hud.RolePanel.Visible = false
	hud.TagButton.Visible = false
	hud.AbilityButton.Visible = false
	hud.TopLeft.QuestsPill.Badge.Visible = false
	hud.TopLeft.IncubatorPill.Badge.Visible = false
	for _, c in ipairs(hud.Feed:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for _, c in ipairs(overlay.Toasts:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	results.Root.Visible = false
	for _, name in ipairs(PANELS) do
		menus[name].Visible = false
	end
	local picker, confirm, reveal = incubatorOverlays()
	picker.Visible = false
	confirm.Visible = false
	reveal.Visible = false
	menus.Pets.Panel.Body.Grid.PetCard.Visible = false
	menus.Shop.Panel.Body.Grid.ItemCard.Visible = false
	menus.Scrim.Visible = false
end

function UI.init()
	local pg = player:WaitForChild("PlayerGui")
	hud = pg:WaitForChild("EOS_HUD")
	menus = pg:WaitForChild("EOS_Menus")
	results = pg:WaitForChild("EOS_Results")
	overlay = pg:WaitForChild("EOS_Overlay")
	for _, g in ipairs({ hud, menus, results, overlay }) do
		Fit.track(g)
	end
	resetPlaceholders()
	-- minimal HUD: the role card holds one line, so shrink it and sit the role chip on its top edge
	do
		local rp = hud.RolePanel
		local card = rp.Card
		card.Size = UDim2.fromOffset(360, 96)
		card.Egg.Size = UDim2.fromOffset(52, 64)
		card.Egg.Position = UDim2.fromOffset(20, 22)
		card.Line1.Position = UDim2.fromOffset(88, 32)
		card.Line1.Size = UDim2.fromOffset(256, 40)
		card.Line2.Visible = false
		card.Objective.Visible = false
		rp.RoleTag.Position = UDim2.new(rp.RoleTag.Position.X, UDim.new(0, rp.Size.Y.Offset - 96 - 28))
		hud.Hint.Visible = true
		hud.Feed.Visible = false
	end
	applyLayout(true)
	UserInputService.LastInputTypeChanged:Connect(function()
		applyLayout()
	end)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
		applyLayout(true)
	end)
	wireButtons()
	connectEvents()
	Tag.isUIOpen = UI.isOpen
	Tag.onDecoy = function()
		UI.toast("THAT WAS A DECOY!", "warn", true) -- kept in matches: explains a missed tag
	end
	Pets.onToast = UI.toast
	Pets.onUsed = function()
		pop(hud.AbilityBar, 0.9)
	end
	CameraFX.lockBlocked = function()
		return UI.isOpen() or resultsOpen
	end
	Movement.onDash(function()
		Sound.play("swing", 1.35)
		pop(hud.DashButton, 0.85)
	end)
	Tag.onSwing = function()
		pop(hud.TagButton, 0.85)
	end
	-- no resetting your character mid-match (it would teleport you out of a tag)
	local function setReset()
		local inMatch = player:GetAttribute("EOS_InMatch") == true
		pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", not inMatch)
	end
	player:GetAttributeChangedSignal("EOS_InMatch"):Connect(function()
		setReset()
		if player:GetAttribute("EOS_InMatch") then
			UI.close()
		end
	end)
	task.delay(2, setReset)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local ok, err = pcall(updateHUD)
		if not ok then
			-- rate-limited: one warning per message
			UI._lastErr = UI._lastErr or {}
			if not UI._lastErr[err] then
				UI._lastErr[err] = true
				warn("[EOS UI] " .. tostring(err))
			end
		end
	end)
	local lastDevice = deviceClass()
	Net.event("RequestProfile"):FireServer(lastDevice)
	UserInputService.LastInputTypeChanged:Connect(function()
		local d = deviceClass()
		if d ~= lastDevice then
			lastDevice = d
			Net.event("RequestProfile"):FireServer(d)
		end
	end)
end

return UI
