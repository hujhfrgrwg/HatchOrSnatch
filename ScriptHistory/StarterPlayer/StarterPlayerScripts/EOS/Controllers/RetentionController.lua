--!strict
-- RetentionController (HOS-RET-001): drives the RetentionUI ScreenGui (built by roblox-ui-maker from
-- ui/build.py pages gift_claim / starter_pack / wait_offer; source roblox/ui_retention).
--  * Welcome back gift: a returning player's daily gift (CLAIM), then "come back tomorrow" + countdown.
--  * Favorite: Roblox's own favorite prompt, once ever, over the come-back card after the first finished match.
--  * Event: Roblox's "Notify me" RSVP prompt, once per event id (RetentionConfig.EVENT_ID).
--  * Starter pack: once after the first pet, when RetentionConfig.STARTER.enabled.
--  * Waiting card: bottom right while you wait out a crossing you aren't in; cycles VIP / 2x XP / starter.
-- Lobby prompts go one at a time, RetentionConfig.GAP apart, only between matches and never over another panel.
-- The server (RetentionService) owns the gift and remembers what was shown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local RetentionConfig = require(Shared:WaitForChild("RetentionConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local player = Players.LocalPlayer
local RetentionController = {}

local UIC: any
local UI: any
local gui: ScreenGui
local S: { [string]: Frame } = {}
local icons: { [string]: string } = {}
local remotes: Folder
local state: any = nil
local clockOffset = 0 -- server os.time() - client os.time()
local matchState: Configuration

local session = {
	giftShown = false,
	favShown = false,
	eventShown = false,
	starterShown = false,
	waitDismissed = false,
	waitSeen = false,
}
local lastPromptAt = -math.huge
local idleSince: number? = nil
local giftMode: string? = nil -- "claim" | "wait" while the gift card is open

local GOLD = Color3.fromRGB(255, 205, 64)
local LOBBY_PHASES = { WAITING = true, INTERMISSION = true }

local function find(scope: Instance, name: string): Instance?
	return scope:FindFirstChild(name, true)
end

local function setText(scope: Instance, name: string, text: string)
	UI.setText(scope, name, text)
end

local function setIcon(scope: Instance, name: string, slug: string)
	local id = icons[slug]
	if not id then return end
	for _, d in scope:GetDescendants() do
		if d:IsA("ImageLabel") and (d.Name == name or d.Name == name .. "Shadow") then d.Image = id end
	end
end

local function show(scope: Instance, name: string, on: boolean)
	local g = find(scope, name)
	if g and g:IsA("GuiObject") then g.Visible = on end
end

local function serverNow(): number
	return os.time() + clockOffset
end

local function clock(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%02d:%02d:%02d", sec // 3600, sec % 3600 // 60, sec % 60)
end

local function seen(kind: string, id: string?)
	(remotes:WaitForChild("Seen") :: RemoteEvent):FireServer(kind, id)
end

local function phase(): string
	return (matchState:GetAttribute("Phase") :: string?) or "WAITING"
end

local function inMatch(): boolean
	return player:GetAttribute("EOS_InMatch") == true
end

-- free to show a lobby prompt now?
local function lobbyIdle(): boolean
	if not state or inMatch() or not LOBBY_PHASES[phase()] then return false end
	if player:GetAttribute("EOS_Loaded") ~= true then return false end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	if UIC.isOpen() or UI.current() ~= nil then return false end
	if UIC.spectating and UIC.spectating() then return false end
	if phase() == "INTERMISSION" then
		local ends = matchState:GetAttribute("PhaseEndsAt") :: number?
		if ends and ends - workspace:GetServerTimeNow() < RetentionConfig.MIN_PHASE_LEFT then return false end
	end
	return true
end

---------------------------------------------------------------- phone size
-- On a phone the whole UI scales to ~0.36, so the cards grow 1.3x (the approved phone mockup, gift_phone).
-- UI.popIn tweens each card's UIScale to its "Base" attribute, so the size is set there.
local PHONE_H, PHONE_SCALE = 500, 1.3
local function sizeCard(screen: Frame, card: string)
	local g = screen:FindFirstChild(card)
	if not g then return end
	local cam = workspace.CurrentCamera
	local k = if cam and cam.ViewportSize.Y < PHONE_H then PHONE_SCALE else 1
	local sc = g:FindFirstChild("PopScale") :: UIScale?
	if not sc then
		sc = Instance.new("UIScale")
		sc.Name = "PopScale";
		(sc :: UIScale).Parent = g
	end
	(sc :: UIScale):SetAttribute("Base", k)
	;(sc :: UIScale).Scale = k
end

---------------------------------------------------------------- gift card
local function giftTimer()
	local sc = S.Gift
	if giftMode == "claim" then
		setText(sc, "TimerText", "Ready now!")
	else
		setText(sc, "TimerText", "Next gift in " .. clock((state and state.nextGiftAt or RetentionConfig.nextDay(serverNow())) - serverNow()))
	end
end

local function setGiftMode(mode: string)
	local sc = S.Gift
	giftMode = mode
	local claim = mode == "claim"
	setText(sc, "Title", if claim then "WELCOME BACK!" else "FREE GIFT")
	setText(sc, "Head", if claim then "Thanks for coming back!" else "Come back tomorrow")
	setText(sc, "Sub", if claim then "Here's your free gift for today." else "for another FREE gift!")
	local sub = find(sc, "Sub")
	if sub and sub:IsA("TextLabel") then
		if sub:GetAttribute("BaseColor") == nil then sub:SetAttribute("BaseColor", sub.TextColor3) end
		sub.TextColor3 = if claim then sub:GetAttribute("BaseColor") :: Color3 else GOLD
	end
	setText(find(sc, "GoldSlot") :: Instance, "CountText", "x" .. RetentionConfig.GIFT.gold)
	setText(find(sc, "GemsSlot") :: Instance, "CountText", "x" .. RetentionConfig.GIFT.gems)
	show(sc, "BtnClaim", claim)
	show(sc, "BtnLater", not claim)
	local b = find(sc, "BtnClaim")
	if b and b:IsA("GuiButton") then b.Active = true; b.AutoButtonColor = false end
	giftTimer()
end

-- Roblox's favorite prompt (skipped if they already favorited). Once ever.
local function promptFavorite()
	if session.favShown or (state and state.favPrompted) then return end
	session.favShown = true
	seen("fav")
	task.spawn(function()
		local ok, fav = pcall(function()
			return AvatarEditorService:GetFavorite(game.PlaceId, Enum.AvatarItemType.Asset)
		end)
		if ok and fav == true then return end
		pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
	end)
end

local function openGift(mode: string)
	setGiftMode(mode)
	sizeCard(S.Gift, "GiftCard")
	UI.open("Gift")
	lastPromptAt = os.clock()
	if mode == "claim" then
		session.giftShown = true
		seen("gift")
	end
end

local claiming = false
local function claimGift()
	if claiming or giftMode ~= "claim" then return end
	claiming = true
	local ok, res = pcall(function()
		return (remotes:WaitForChild("Claim") :: RemoteFunction):InvokeServer()
	end)
	claiming = false
	if not ok or type(res) ~= "table" or not res.ok then
		UIC.toast("Couldn't claim the gift right now. Try again in a moment.", "info", true)
		return
	end
	UIC.toast(string.format("Daily gift claimed: +%d Gold, +%d Gems", res.gold, res.gems), "reward", true)
	if state then state.nextGiftAt = res.nextGiftAt; state.giftReady = false end
	setGiftMode("wait")
	UI.pulse(S.Gift, 0.06)
	-- the reference shows the favorite prompt over the come-back card
	promptFavorite()
end

---------------------------------------------------------------- starter pack
local function openStarter()
	local sc = S.Starter
	local cfg = RetentionConfig.STARTER
	for i, it in cfg.items do
		local slot = find(sc, "Item" .. i)
		if slot then
			setIcon(slot, "Icon", it.icon)
			setText(slot, "CountText", it.count)
			setText(slot, "LabelText", it.label)
		end
	end
	setText(sc, "PriceText", if cfg.robux then tostring(cfg.robux) else "???")
	show(sc, "Note", false)
	session.starterShown = true
	seen("starter")
	sizeCard(S.Starter, "StarterPack")
	UI.open("Starter")
	lastPromptAt = os.clock()
end

local function starterTimer()
	local ends = state and state.starterEndsAt
	setText(S.Starter, "TimerText", "Offer ends in " .. clock((ends or serverNow() + RetentionConfig.STARTER.hours * 3600) - serverNow()))
end

local function buyStarter()
	local id = RetentionConfig.STARTER.productId
	if not id then
		UIC.toast("The starter pack isn't on sale yet", "info", true)
		return
	end
	seen("offer_click", "starter")
	MarketplaceService:PromptProductPurchase(player, id)
end

---------------------------------------------------------------- event RSVP
local function promptEvent()
	local id = RetentionConfig.EVENT_ID
	session.eventShown = true
	seen("event", id)
	lastPromptAt = os.clock()
	task.spawn(function()
		local ok, status = pcall(function() return SocialService:GetEventRsvpStatusAsync(id) end)
		if ok and status == Enum.RsvpStatus.Going then return end
		pcall(function() SocialService:PromptRsvpToEventAsync(id) end)
	end)
end

---------------------------------------------------------------- lobby scheduler
local function nextPrompt(): (() -> ())?
	if not state then return nil end
	-- the gift comes first, a few seconds after spawning; everything else waits the gap
	if state.giftReady and not session.giftShown then
		return function() openGift("claim") end
	end
	if os.clock() - lastPromptAt < RetentionConfig.GAP then return nil end
	if state.matches >= 1 and not state.favPrompted and not session.favShown then
		return function()
			openGift("wait")
			task.delay(0.6, promptFavorite)
		end
	end
	if RetentionConfig.EVENT_ID ~= "" and state.matches >= 1 and not state.eventSeen and not session.eventShown then
		return promptEvent
	end
	if RetentionConfig.STARTER.enabled and state.hasPet and not state.starterShown and not session.starterShown then
		return openStarter
	end
	return nil
end

local function tickLobby()
	-- a lobby panel never stays up into a match
	local cur = UI.current()
	if (cur == "Gift" or cur == "Starter") and (inMatch() or not LOBBY_PHASES[phase()]) then
		UI.close()
	end
	if cur == "Gift" then giftTimer() elseif cur == "Starter" then starterTimer() end
	if not lobbyIdle() then
		idleSince = nil
		return
	end
	idleSince = idleSince or os.clock()
	if os.clock() - (idleSince :: number) < RetentionConfig.FIRST_DELAY then return end
	local fn = nextPrompt()
	if fn then fn() end
end

---------------------------------------------------------------- waiting card
local offerIdx, offerAt, offerKey = 1, 0, ""
local dotOn: Color3?, dotOff: Color3?

local function offers(): { any }
	local list = {}
	for _, o in RetentionConfig.WAIT_OFFERS do
		if o.pass then
			local p = EconomyConfig.pass(o.pass)
			if p and p.passId and player:GetAttribute(p.attr) ~= true then
				table.insert(list, { key = o.pass, title = p.name, price = tostring(p.robux), icon = o.icon, lines = o.lines, passId = p.passId })
			end
		elseif o.starter then
			local cfg = RetentionConfig.STARTER
			if cfg.enabled and cfg.productId and state and state.starterOpen then
				table.insert(list, { key = "starter", title = o.title, price = tostring(cfg.robux or "???"), icon = o.icon, lines = o.lines, productId = cfg.productId })
			end
		end
	end
	return list
end

local function waiting(): boolean
	if session.waitDismissed or not state or not state.hasPet then return false end
	if inMatch() or not RetentionConfig.WAIT_PHASES[phase()] then return false end
	local hero = matchState:GetAttribute("HeroUserId") :: number?
	if hero and hero == player.UserId then return false end
	return not UIC.isOpen() and UI.current() == nil
end

local function drawOffer(list: { any })
	local sc = S.WaitOffer
	local o = list[offerIdx]
	setText(sc, "Title", o.title)
	setText(sc, "PriceText", o.price)
	for i = 1, 3 do setText(sc, "Line" .. i, o.lines[i] or "") end
	setIcon(sc, "Icon", o.icon)
	for i = 1, 3 do
		local d = find(sc, "Dot" .. i)
		if d and d:IsA("GuiObject") then
			d.Visible = i <= #list and #list > 1
			if dotOn and dotOff then d.BackgroundColor3 = if i == offerIdx then dotOn else dotOff end
		end
	end
end

local function tickWait()
	local on = waiting()
	local list = if on then offers() else {}
	if #list == 0 then
		UI.setGroupHidden("WaitOffer", true)
		return
	end
	local key = table.concat((function()
		local k = {}
		for _, o in list do table.insert(k, o.key) end
		return k
	end)(), ",")
	if key ~= offerKey then offerKey, offerIdx, offerAt = key, 1, os.clock() end
	if os.clock() - offerAt >= RetentionConfig.WAIT_CYCLE then
		offerIdx = offerIdx % #list + 1
		offerAt = os.clock()
	end
	offerIdx = math.clamp(offerIdx, 1, #list)
	drawOffer(list)
	local hidden = find(S.WaitOffer, "WaitOffer")
	local was = hidden and (hidden :: GuiObject).Visible
	UI.setGroupHidden("WaitOffer", false)
	if not was and hidden then UI.popFrom(hidden :: GuiObject, 0.85) end
	if not session.waitSeen then
		session.waitSeen = true
		seen("offer")
	end
end

local function buyOffer()
	local list = offers()
	local o = list[offerIdx]
	if not o then return end
	seen("offer_click", o.key)
	if o.passId then
		MarketplaceService:PromptGamePassPurchase(player, o.passId)
	elseif o.productId then
		MarketplaceService:PromptProductPurchase(player, o.productId)
	end
end

---------------------------------------------------------------- init
function RetentionController.init(uiController: any)
	UIC = uiController
	matchState = ReplicatedStorage:WaitForChild("EOS_State") :: Configuration
	remotes = ReplicatedStorage:WaitForChild("EOS_Retention") :: Folder
	gui = player:WaitForChild("PlayerGui"):WaitForChild("RetentionUI") :: ScreenGui
	gui.DisplayOrder = 8 -- above EOSUI
	gui.Enabled = true
	UI = require(gui:WaitForChild("UI") :: ModuleScript)
	UI.init(gui)
	-- icons: this gui's own ids, then the main UI's (the waiting card swaps to icons it didn't export)
	local main = player.PlayerGui:FindFirstChild("EOSUI")
	local mainIds = main and main:FindFirstChild("AssetIds")
	if mainIds then
		for k, v in (require(mainIds :: ModuleScript) :: any).icons do icons[k] = v end
	end
	for k, v in (require(gui:WaitForChild("AssetIds") :: ModuleScript) :: any).icons do icons[k] = v end

	local root = gui:WaitForChild("Root")
	for _, n in { "Gift", "Starter", "WaitOffer" } do S[n] = root:WaitForChild(n) :: Frame end
	S.WaitOffer.Visible = true -- a HUD screen: its WaitOffer group is shown and hidden instead
	UI.setGroupHidden("WaitOffer", true)
	local d1, d2 = find(S.WaitOffer, "Dot1"), find(S.WaitOffer, "Dot2")
	if d1 and d2 and d1:IsA("GuiObject") and d2:IsA("GuiObject") then dotOn, dotOff = d1.BackgroundColor3, d2.BackgroundColor3 end

	UI.Action:Connect(function(name: string, screen: string)
		if screen == "Gift" then
			if name == "BtnClaim" then claimGift()
			elseif name == "BtnLater" then UI.close() end
		elseif screen == "Starter" then
			if name == "BtnBuy" then buyStarter()
			elseif name == "BtnNo" then seen("starter_no"); UI.close() end
		elseif screen == "WaitOffer" then
			if name == "BtnBuy" then buyOffer()
			elseif name == "CloseButton" then
				session.waitDismissed = true
				UI.setGroupHidden("WaitOffer", true)
			end
		end
	end)

	local stateEvent = remotes:WaitForChild("State") :: RemoteEvent
	stateEvent.OnClientEvent:Connect(function(v)
		if type(v) ~= "table" then return end
		state = v
		clockOffset = (tonumber(v.serverNow) or os.time()) - os.time()
	end);
	(remotes:WaitForChild("Ask") :: RemoteEvent):FireServer()

	-- a pass bought from the waiting card: the attribute flips and the card moves on by itself
	task.spawn(function()
		while gui.Parent do
			local ok, err = pcall(tickLobby)
			if not ok then warn("[Retention] lobby: " .. tostring(err)) end
			ok, err = pcall(tickWait)
			if not ok then warn("[Retention] wait card: " .. tostring(err)) end
			task.wait(0.5)
		end
	end)
end

return RetentionController
