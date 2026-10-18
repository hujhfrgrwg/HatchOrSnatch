--!nocheck
-- EggUIController (HOS-EGG-002, 17 Oct 2026): the egg plan's screens, driving StarterGui.EggUI (built from the
-- approved HTML by roblox-ui-maker: ui/build.py egg_x_* -> ui_egg/rbx.json -> roblox/ui_egg -> Builder).
-- Started by one line at the end of UIController's UIC.init (UIController gets no new top-level locals).
--   EggHUD       the match egg card (rarity, 4-segment charge meter, glow; a Catcher's stash and snatch cap), the roll
--                flicker at safety, BONUS ROLLS xN on an early Runners win, the one-time tip on the first charge
--   EggIncubator replaces EOSUI's Incubator while EggConfig.ENABLED: fill ring, shards, exact odds, focus, Hatch
--   EggFirstPet  the free first pet (after the first egg won)
--   templates    +CHARGE beside the +PTS pop, RARE / EPIC / LEGENDARY EGG! banners (replace SAFE! on an upgrade),
--                READY TO HATCH on the incubator button, the shard row's small incubator egg on the results card
-- Data: ReplicatedStorage.EOS_Egg (Charged, Rolled, Stash; HatchIncubator, SetFocus, ClaimFirstPet), ProfileState
-- .incubator (IncubatorLogic.view: need, ready, odds, focusOpen, first pet), player attributes EOS_Role, EOS_Tier,
-- EOS_InMatch, EOS_EggCharge (0..CHARGE.CAP, lasts the match), EOS_EggMarks (marks spent), EOS_EggStash, EOS_EggCap. Runtime edits to other screens: see Dev/UI Runtime Changes.md.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EggConfig = require(Shared:WaitForChild("EggConfig"))
local EggLogic = require(Shared:WaitForChild("EggLogic"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local EggUIController = {}

local UIC: any -- UIController (toast, banner)
local gui: ScreenGui
local EUI: any -- EggUI's runtime module
local K: any -- EggUI's UIKit
local root: Frame
local fx: Frame -- runtime layer for pops and banners (inside Root, shares FitScale)
local remotes: Folder

local view: any = nil -- ProfileState.incubator
local firstCommonFree = false
local charge = 0
local hatching = false
local tipShown = false
local flickerToken = 0
local pickFamily: string? = nil
local lastShard: string? = nil
local showRarity: string? = nil -- the card's look while a roll flickers
local bonusShowing = false -- the card's BonusTag shows "BONUS ROLLS xN" (else it's the full meter's tag)
local guaranteedThisMatch = false -- a full meter gave this player's egg its step (results: GUARANTEED UPGRADE)

local RARITIES = EggConfig.RARITIES
local WORD = { common = "COMMON", rare = "RARE", epic = "EPIC", legendary = "LEGENDARY" }
local EGG_ICON = { common = "piece_common", rare = "piece_rare", epic = "piece_epic", legendary = "piece_crowned" } -- the shard art (shard approved 17 Oct)
local SHARD_ICON = { common = "piece_common", rare = "piece_rare", epic = "piece_epic", legendary = "piece_crowned" }
local FILL_GREEN, FILL_GOLD = Color3.fromRGB(124, 240, 90), Color3.fromRGB(255, 210, 58)

local function colorOf(r: string?): Color3
	local i = r and EggConfig.RARITY_INFO[r]
	return if i then Color3.fromRGB(i.rgb[1], i.rgb[2], i.rgb[3]) else Color3.new(1, 1, 1)
end

local function num(n: number): string
	local s = string.format("%.1f", n)
	return (s:gsub("%.0$", ""))
end

local function find(scope: Instance?, name: string): Instance?
	return scope and scope:FindFirstChild(name, true)
end

-- a label's fill colour (exported text fills are a UIGradient on the label; its Shadow twin stays dark)
local function tint(label: Instance?, c: Color3)
	if not (label and label:IsA("TextLabel")) then return end
	local g = label:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(c)
	else
		label.TextColor3 = c
	end
end

local function setText(scope: Instance?, name: string, text: string)
	local l = find(scope, name)
	if l then K.set(l, text) end
end

local function setIcon(scope: Instance?, name: string, slug: string)
	local l = find(scope, name)
	if l then K.icon(l, slug) end
end

local function show(g: Instance?, on: boolean)
	if not (g and g:IsA("GuiObject")) then return end
	g.Visible = on
	-- the export puts a plate's box-shadow (DropShadow) just before it among its siblings: keep the pair in step, or a
	-- state built visible leaves its opaque shadow over the state shown in its place (seen live: a black focus chip)
	local prev: Instance? = nil
	for _, k in (g.Parent :: Instance):GetChildren() do
		if k == g then break end
		prev = k
	end
	if prev and prev.Name == "DropShadow" and prev:IsA("GuiObject") then prev.Visible = on end
end

-- Builder's "Cooldown" wedge is square; a ring needs it clipped round. Only a CanvasGroup clips to a UICorner, so the
-- wedge moves into one (runtime edit, logged in ui_runtime_changes.md). The Hole disc stays on top.
local function roundRing(ringFrame: Instance?)
	local cd = ringFrame and ringFrame:FindFirstChild("Cooldown")
	if not (cd and cd:IsA("GuiObject")) then return end
	local cg = Instance.new("CanvasGroup")
	cg.Name = "CooldownClip"
	cg.BackgroundTransparency = 1
	cg.Size = cd.Size
	cg.Position = cd.Position
	cg.AnchorPoint = cd.AnchorPoint
	cg.ZIndex = cd.ZIndex
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = cg
	cg.Parent = ringFrame
	cd.Position = UDim2.fromOffset(0, 0)
	cd.AnchorPoint = Vector2.zero
	cd.Parent = cg
	local hole = ringFrame:FindFirstChild("Hole")
	if hole and hole:IsA("GuiObject") then hole.ZIndex = math.max(hole.ZIndex, cg.ZIndex + 1) end
end

-- the conic fill ring (Builder "Cooldown": two clipped halves with rotating planes), filled clockwise to frac
local function ring(frame: Instance?, frac: number, color: Color3)
	if not frame then return end
	local cd = frame:FindFirstChild("Cooldown", true) or frame
	local a = math.clamp(frac, 0, 1) * 360
	for _, n in { "R", "L" } do
		local half = cd:FindFirstChild(n)
		local rotor = half and half:FindFirstChild("Rotor")
		local plane = rotor and rotor:FindFirstChild("Plane")
		if half and rotor then
			if plane then plane.BackgroundColor3 = color end
			if n == "R" then
				half.Visible = a > 0
				rotor.Rotation = math.min(a, 180)
			else
				half.Visible = a > 180
				rotor.Rotation = math.max(a - 180, 0)
			end
		end
	end
	cd:SetAttribute("Frac", frac)
end

local function reduceEffects(): boolean
	local ok, CameraFX = pcall(function()
		return require(script.Parent:WaitForChild("CameraFX", 2))
	end)
	return ok and CameraFX and CameraFX.reduceEffects == true
end

-- a template in the fx layer at a design position (anchor 0.5 when centred)
local function place(name: string, x: number, y: number, centred: boolean?): GuiObject?
	local t = K.template(name)
	if not t then return nil end
	if centred then
		t.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	t.Position = UDim2.fromOffset(x, y)
	t.ZIndex = 50
	t.Parent = fx
	return t
end

---------------------------------------------------------------- the match egg card
local function card(): Instance?
	return find(root, "EggCard")
end

local function inMatch(): boolean
	return player:GetAttribute("EOS_InMatch") == true
end

local function myRarity(): string
	return EggLogic.rarityForLevel(player:GetAttribute("EOS_Tier") or 1)
end

-- c = the meter's fill toward EggConfig.CHARGE.FULL (0..1)
local function setMeter(scope: Instance?, c: number)
	local meter = find(scope, "Charge")
	if not meter then return end
	for i = 1, 4 do
		local seg = meter:FindFirstChild("Seg" .. i)
		local fill = seg and seg:FindFirstChild("Fill")
		if fill then
			local full = fill:GetAttribute("FullW") or fill.Size.X.Offset
			fill:SetAttribute("FullW", full)
			local part = math.clamp(c * 4 - (i - 1), 0, 1)
			fill.ClipsDescendants = true
			fill.Visible = part > 0.01
			fill.Size = UDim2.new(0, math.max(2, full * part), fill.Size.Y.Scale, fill.Size.Y.Offset)
		end
	end
	local glow = find(scope, "ChargeGlow")
	if glow and glow:IsA("ImageLabel") then
		glow.Visible = c > 0 -- Reduce effects keeps the glow (the one charge cue it allows)
		glow.ImageTransparency = if c >= 1 then 0.05 else 0.5
	end
end

-- phones: the design scale is ~0.36, so the card's 14-16 px lines render at 5-6 px (garbled). There the card keeps the
-- slot, the rarity word and the meter, and drops the small lines (title, "pays +1 ... SHARD", the Catcher's cap/hint)
local function compact(): boolean
	return true -- HOS-INV-001 clutter 8 (Hunter 18 Oct "do all"): the compact card on every screen, PC too
end

local function applyCompact(c: Instance)
	local on = compact()
	if c:GetAttribute("Compact") == on then return end
	c:SetAttribute("Compact", on)
	for _, d in c:GetDescendants() do
		local small = not d:FindFirstAncestor("BonusTag")
			and ((d:IsA("TextLabel") and d.TextSize < 30) or (d:IsA("ImageLabel") and d.Name:match("^PaysIcon") ~= nil))
		if small then
			if d:GetAttribute("WasVisible") == nil then d:SetAttribute("WasVisible", d.Visible) end
			d.Visible = if on then false else d:GetAttribute("WasVisible")
		end
	end
end

-- the touch thumbstick's frame in EggUI's screen space (nil without one)
local function thumbTop(): number?
	local tg = player.PlayerGui:FindFirstChild("TouchGui")
	if not (tg and tg.Enabled) then return nil end
	local best
	for _, n in { "ThumbstickFrame", "DynamicThumbstickFrame" } do
		local f = tg:FindFirstChild(n, true)
		if f and f:IsA("GuiObject") and f.Visible and f.AbsoluteSize.Y > 0 then
			local y = f.AbsolutePosition.Y
			if not tg.IgnoreGuiInset and gui.IgnoreGuiInset then
				y += game:GetService("GuiService"):GetGuiInset().Y
			end
			best = if best then math.min(best, y) else y
		end
	end
	return best
end

local function refreshCard()
	local c = card()
	if not c then return end
	local r = player:GetAttribute("EOS_Role")
	-- HOS-INV-001 clutter 9: a Catcher with no snatched egg has nothing to show (no EMPTY card)
	local on = inMatch() and (r == "RUNNER" or ((r == "CATCHER" or r == "CAUGHT") and player:GetAttribute("EOS_EggStash") ~= nil))
	EUI.setGroupHidden("EggCard", not on) -- through the runtime: its refreshHud re-shows hud groups when a panel closes
	show(c, on)
	if not on then return end
	local variant
	if r == "RUNNER" then
		variant = "Runner_" .. (showRarity or myRarity())
	else
		variant = if player:GetAttribute("EOS_EggStash") then "Catcher" else "CatcherEmpty"
	end
	for _, v in { "Runner_common", "Runner_rare", "Runner_epic", "Runner_legendary", "Catcher", "CatcherEmpty" } do
		show(c:FindFirstChild(v), v == variant)
	end
	local cur = c:FindFirstChild(variant)
	applyCompact(c)
	require(script.Parent.EggShardMeter).compact(c) -- phones: the plate hugs its content, chip-sized
	local tag = c:FindFirstChild("BonusTag")
	if r == "RUNNER" then
		require(script.Parent.EggShardMeter).card(cur, tag, charge, bonusShowing, { find = find, show = show, setText = setText }) -- two marks, NEXT SAFE (no roll)
	else
		if tag and not bonusShowing then show(tag, false) end
		local stash = player:GetAttribute("EOS_EggStash")
		local cap = player:GetAttribute("EOS_EggCap") or EggConfig.SNATCH.STARTING_CATCHER_CAP
		setText(cur, "CapText", WORD[cap] or "EPIC")
		tint(find(cur, "CapText"), colorOf(cap))
		if stash then
			setText(cur, "EggLevel", WORD[stash] or "RARE")
			tint(find(cur, "EggLevel"), colorOf(stash))
			setIcon(cur, "Icon", EGG_ICON[stash])
			setIcon(cur, "PaysIcon", SHARD_ICON[stash])
			setText(cur, "PaysText", ("+1 %s SHARD"):format(WORD[stash]))
			tint(find(cur, "PaysText"), colorOf(stash))
		end
	end
end

-- the egg card replaces EOSUI's MatchHUD.Egg while it shows (UIController keeps refreshing its own; keep it hidden)
-- and sits exactly where EOSUI lays its card out (runtime edit, logged)
local function hideOldCard()
	local eosui = player.PlayerGui:FindFirstChild("EOSUI")
	local old = eosui and eosui:FindFirstChild("Root") and eosui.Root:FindFirstChild("MatchHUD")
	old = old and old:FindFirstChild("Egg")
	if old and old.Visible and inMatch() then -- the egg card owns the match, panels open or not
		old.Visible = false
	end
	-- EOSUI's lobby goal pill counts recipe pieces ("NEXT HATCH 0 / 2 COMMON PIECES"), which no longer exist: hide it
	-- while the egg plan is on (READY TO HATCH on the incubator button says when to hatch)
	local goal = eosui and eosui:FindFirstChild("Root") and eosui.Root:FindFirstChild("HUD")
	goal = goal and goal:FindFirstChild("Goal")
	if goal and goal.Visible then
		goal.Visible = false
	end
	-- follow EOSUI's layout of its (hidden) card: phones raise it clear of the thumbstick; keep ours on that spot
	local c = card()
	if old and c and c.Visible then
		local shown
		for _, v in c:GetChildren() do
			if v:IsA("GuiObject") and v.Visible and v.Name ~= "BonusTag" then shown = v break end
		end
		local fit = root:FindFirstChildOfClass("UIScale")
		local k = (fit and fit.Scale) or 1
		-- align the glass plates (a variant's own frame is the union of its children, glow included: taller than the card)
		local mine = shown and (shown:FindFirstChild("Glass") or shown)
		local ref = old:FindFirstChild("Glass") or old
		if mine and k > 0 then
			local target = ref.AbsolutePosition
			-- phones: sit above the thumbstick (EOSUI's spot overlaps its top edge)
			local top = thumbTop()
			if top and target.Y + mine.AbsoluteSize.Y > top - 6 then
				target = Vector2.new(target.X, top - 6 - mine.AbsoluteSize.Y)
			end
			local d = (target - mine.AbsolutePosition) / k
			if math.abs(d.X) > 1 or math.abs(d.Y) > 1 then
				c.Position = c.Position + UDim2.fromOffset(d.X, d.Y)
			end
			applyCompact(c)
			require(script.Parent.EggShardMeter).compact(c)
		end
	end
	require(script.Parent.EggShardMeter).clearTopbar(c, root) -- below Roblox's top-left buttons
end

local function onCharged(t: any)
	if type(t) ~= "table" then return end
	charge = tonumber(t.charge) or charge
	refreshCard()
	local c = card()
	local meter = c and find(c:FindFirstChild("Runner_" .. myRarity()), "Charge")
	if meter and meter:IsA("GuiObject") then EUI.pulse(meter, 0.12) end
	local pop = place("ChargePop", 1346, 430)
	if pop then
		local tint_ = colorOf(t.rarity or myRarity())
		tint(find(pop, "ChargeText"), tint_)
		EUI.popFrom(pop, 0.3)
		task.delay(1.1, function()
			if pop.Parent then
				TweenService:Create(pop, TweenInfo.new(0.25), { Position = pop.Position - UDim2.fromOffset(0, 30) }):Play()
				task.delay(0.25, function() pop:Destroy() end)
			end
		end)
	end
	if not tipShown then -- once, on the first charge
		tipShown = true
		local tip = find(root, "Tip")
		if tip then
			setText(tip, "Line1", "Brave plays fill your meter.")
			setText(tip, "Line2", "Pass a mark: your shard steps up at the next safe.")
			show(tip, true)
			EUI.popFrom(tip, 0.6)
			task.delay(4, function() show(tip, false) end)
		end
	end
end

-- hide UIController's SAFE! banner when our upgrade banner replaces it (keep its queue running: Visible only)
local function hideSafeBannerSoon()
	local eosui = player.PlayerGui:FindFirstChild("EOSUI")
	local overlay = eosui and eosui:FindFirstChild("Root") and eosui.Root:FindFirstChild("Overlay")
	if not overlay then return end
	local function check(ch: Instance)
		for _, d in ch:GetDescendants() do
			if d:IsA("TextLabel") and d.Text == "SAFE!" then
				if ch:IsA("GuiObject") then ch.Visible = false end
				return true
			end
		end
		return false
	end
	for _, ch in overlay:GetChildren() do check(ch) end
	local conn
	conn = overlay.ChildAdded:Connect(function(ch)
		task.defer(function()
			if check(ch) and conn then conn:Disconnect() conn = nil end
		end)
	end)
	task.delay(2.5, function() if conn then conn:Disconnect() end end)
end

local function upgradeBanner(to: string, guaranteed: boolean?)
	if not require(script.Parent.EggResultsRow).whenSettled(function() upgradeBanner(to, guaranteed) end) then return end -- never over the results opening (fixes)
	local b = place("EggBanner_" .. to, (root.Size.X.Offset) / 2, 300, true)
	if not b then return end
	require(script.Parent.EggResultsRow).bannerText(b, to, { setText = setText, find = find }) -- "SHARD UPGRADED: EPIC" (no-roll wording)
	EUI.popFrom(b, 0.2)
	b.Rotation = -4
	TweenService:Create(b, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	task.delay(1.6, function()
		if b.Parent then
			TweenService:Create(b, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = b.Position - UDim2.fromOffset(0, 70) }):Play()
			task.delay(0.3, function() b:Destroy() end)
		end
	end)
end

local function onRolled(t: any)
	if type(t) ~= "table" or t.userId ~= player.UserId then return end
	local upgraded = t.from ~= t.to
	if upgraded and not t.bonus then hideSafeBannerSoon() end
	if t.guaranteed then -- a meter mark gave this step (the meter keeps its charge)
		guaranteedThisMatch = true
	end
	flickerToken += 1
	local my = flickerToken
	local secs = (tonumber(t.seconds) or 0) * (if t.bonus then (tonumber(t.rolls) or 1) else 1) -- no roll: 0, no flicker
	local c = card()
	local tag = c and c:FindFirstChild("BonusTag")
	if t.bonus and tag then
		bonusShowing = true
		setText(tag, "BonusText", ("RUNNERS WIN: BONUS ROLLS x%d"):format(tonumber(t.rolls) or 1))
		show(tag, true)
	end
	task.spawn(function()
		if not reduceEffects() then
			local i, t0 = 0, os.clock()
			while flickerToken == my and os.clock() - t0 < secs do
				i += 1
				showRarity = RARITIES[(i % 3) + 2] -- rare / epic / legendary
				refreshCard()
				task.wait(0.12)
			end
		end
		if flickerToken ~= my then return end
		showRarity = nil
		refreshCard()
		if tag and t.bonus then
			task.delay(1.2, function()
				bonusShowing = false
				show(tag, false)
				refreshCard()
			end)
		end
		if upgraded then upgradeBanner(t.to, t.guaranteed) end
	end)
end

---------------------------------------------------------------- the incubator egg
local function incubator(): Instance?
	return find(root, "EggIncubator")
end

local function refreshIncubator()
	local scr = incubator()
	if not (scr and view and view.need) then return end
	local ready = view.ready == true
	ring(find(scr, "FillRing"), math.min(1, view.fill / view.need), if ready then FILL_GOLD else FILL_GREEN)
	setIcon(scr, "BigEgg", if ready then "egg_golden" else "egg_starter")
	show(find(scr, "Sparkle"), ready)
	show(find(scr, "Sparkle2"), ready)
	setText(scr, "FillText", ("%s / %s FILL"):format(num(view.fill), num(view.need)))
	tint(find(scr, "FillText"), if ready then FILL_GOLD else Color3.new(1, 1, 1))
	setText(scr, "FillSub", if ready then "READY TO HATCH!" else ("%s more fill to hatch"):format(num(view.need - view.fill)))
	for _, r in { "rare", "epic", "legendary" } do
		local s = find(scr, "Shard_" .. r)
		local n = (view.shards and view.shards[r]) or 0
		if s then
			show(s:FindFirstChild("On"), n > 0)
			show(s:FindFirstChild("Off"), n == 0)
			setText(s:FindFirstChild("On"), "CountText", "x" .. n)
		end
	end
	-- the Lucky Egg pass (server-verified attribute): the same multiplier the hatch applies, so shown = rolled
	local o = if view.fill then EggLogic.hatchOdds({ fill = view.fill, focus = view.focus, boost = view.boost or 0 }, view.legendaryOpen == true,
		player:GetAttribute("EOS_LuckyEgg") == true) else { rare = 1, epic = 0, legendary = 0 } -- the hatch's own odds (fill, focus, pass, boost, cap)
	for _, r in { "rare", "epic", "legendary" } do
		K.bar(find(scr, "OddsBar_" .. r), o[r])
		setText(scr, "OddsText_" .. r, (string.format("%.1f%%", o[r] * 100):gsub("%.0%%", "%%")))
	end
	local W = EggConfig.SHARD_WEIGHT -- the weights line follows the config (built from the mockup's old numbers)
	setText(scr, "WeightLine2", ("Rare %s · Epic %s · Legendary %s"):format(num(W.rare), num(W.epic), num(W.legendary)))
	show(find(scr, "OddsSoon"), not view.legendaryOpen)
	setText(scr, "OddsNote", if view.legendaryOpen then "These are the exact odds of your hatch" else "Legendary pets are coming: until then their chance goes to Epic")
	local chips = { "Any" }
	for _, f in EggConfig.FAMILIES do table.insert(chips, f) end
	for _, fam in chips do
		local chip = find(scr, "Focus_" .. fam)
		if chip then
			local sel = view.focus == fam
			local open = fam == "Any" or (view.focusOpen and view.focusOpen[fam])
			show(chip:FindFirstChild("Sel"), sel)
			show(chip:FindFirstChild("Open"), not sel and open)
			show(chip:FindFirstChild("Locked"), not sel and not open)
			if sel then
				local ringF = find(scr, "FocusSel")
				local selPlate = chip:FindFirstChild("Sel")
				if ringF and selPlate and ringF:IsA("GuiObject") and selPlate:IsA("GuiObject") and chip:IsA("GuiObject") then
					-- the white ring is FocusSel's exported outline twins (ShadowRing): move them all. Chips are re-anchored
					-- at their centre by the juicy-button setup, so take the chip's left edge from its AnchorPoint
					local x = chip.Position.X.Offset - chip.AnchorPoint.X * chip.Size.X.Offset + selPlate.Position.X.Offset - 4
					for _, r in (ringF.Parent :: Instance):GetChildren() do
						if (r == ringF or r.Name == "ShadowRing") and r:IsA("GuiObject") then
							r.Position = UDim2.fromOffset(x, r.Position.Y.Offset)
						end
					end
				end
			end
		end
	end
	local anyLocked = false -- "Locked families get pets soon" only while a family is still locked
	for _, f in EggConfig.FAMILIES do anyLocked = anyLocked or not (view.focusOpen and view.focusOpen[f]) end
	for _, n in { "T_LockedFamiliesGetPetsSoo", "T_LockedFamiliesGetPetsSooShadow" } do show(find(scr, n), anyLocked) end
	tint(find(scr, "FocusCost"), if view.focus ~= "Any" then FILL_GOLD else Color3.fromRGB(210, 210, 216))
	show(find(scr, "BtnHatch"), ready and not hatching)
	show(find(scr, "BtnHatchOff"), not ready or hatching)
	local off = find(scr, "BtnHatchOff")
	if off then
		local lbl = find(off, "Label")
		if lbl then K.set(lbl, if hatching then "HATCHING..." else "HATCH") end
	end
	require(script.Parent.EggIncubatorView).refresh(scr, view, hatching, { ring = ring, setText = setText, show = show, tint = tint, num = num, find = find, K = K }) -- overfill, Lucky, boost (fixes)
end

local function refreshFirstPet()
	local scr = find(root, "EggFirstPet")
	if not (scr and view) then return end
	local fams = view.firstPetFamilies or {}
	pickFamily = pickFamily or fams[1]
	for _, fam in { "Decoy", "Invisibility" } do
		show(find(scr, "Pick_" .. fam), table.find(fams, fam) ~= nil)
	end
	local sel = find(scr, "PickSel")
	local tile = pickFamily and find(find(scr, "Pick_" .. pickFamily), "Tile")
	if sel and tile and sel:IsA("GuiObject") and tile:IsA("GuiObject") then
		sel.Position = UDim2.fromOffset(tile.Position.X.Offset - 4, sel.Position.Y.Offset)
	end
end

local function openIncubator()
	if view and view.firstPetClaimable and firstCommonFree then
		refreshFirstPet()
		EUI.open("EggFirstPet")
	else
		refreshIncubator()
		EUI.open("EggIncubator")
	end
end

local function readyBadge()
	local eosui = player.PlayerGui:FindFirstChild("EOSUI")
	local btn = eosui and find(eosui, "IncubatorButton")
	if not btn then return end
	local b = btn:FindFirstChild("EggReadyBadge")
	if not b then
		b = K.template("ReadyBadge")
		if not b then return end
		b.Name = "EggReadyBadge"
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, 8, 1, -6) -- just under the button: the top row sits on the screen edge
		b.ZIndex = 20
		b.Parent = btn
	end
	b.Visible = view ~= nil and view.ready == true and not inMatch()
end

---------------------------------------------------------------- results: the shard replaces the piece
local resultsToken = 0
local animatedToken = -1

-- the egg icon cracks, its glowing core flies to the small incubator egg (UI space; Reduce effects: skipped)
local function crackAndFly(lb: Instance, mini: Instance?, shard: string)
	if reduceEffects() then return end
	local slot = find(lb, "EggSlot")
	local icon = slot and find(slot, "Icon")
	if not (icon and icon:IsA("GuiObject")) then return end
	local Sound = (function()
		local ok, s = pcall(require, script.Parent:WaitForChild("Sound", 2))
		return if ok then s else nil
	end)()
	task.spawn(function()
		if Sound then Sound.play("crack") end
		for _, r in { -9, 8, -6, 5, 0 } do -- the shake
			TweenService:Create(icon, TweenInfo.new(0.06), { Rotation = r }):Play()
			task.wait(0.06)
		end
		K.icon(icon, SHARD_ICON[shard]) -- cracked: the shard
		local ring = mini and find(mini, "MiniRing")
		local src = card() and find(card():FindFirstChild("Runner_" .. shard), "ChargeGlow")
		if not (ring and src and ring:IsA("GuiObject") and icon.Parent) then return end
		local well = ring:FindFirstAncestorWhichIsA("GuiObject")
		while well and not well:FindFirstChild("EggMini") do well = well.Parent end
		if not well then return end
		local sc = well.AbsoluteSize.X / math.max(1, well.Size.X.Offset)
		local function local_(abs: Vector2): UDim2
			local p = (abs - well.AbsolutePosition) / sc
			return UDim2.fromOffset(p.X, p.Y)
		end
		local core = src:Clone()
		core.Name = "EggCore"
		core.Visible = true
		core.ImageTransparency = 0.05
		core.AnchorPoint = Vector2.new(0.5, 0.5)
		core.Size = UDim2.fromOffset(90, 90)
		core.Position = local_(icon.AbsolutePosition + icon.AbsoluteSize / 2)
		core.ZIndex = 30
		core.Parent = well
		local to = local_(ring.AbsolutePosition + ring.AbsoluteSize / 2)
		local tw = TweenService:Create(core, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = to, Size = UDim2.fromOffset(34, 34) })
		tw:Play()
		tw.Completed:Wait()
		core:Destroy()
		EUI.pulse(ring, 0.2)
	end)
end

local function applyResults(you: any)
	local pg = player.PlayerGui
	local pts = pg:FindFirstChild("PointsUI")
	local pieceText = pts and find(pts, "PieceText")
	if not pieceText then return end
	local lb = pieceText.Parent
	while lb and not lb:FindFirstChild("EggText", true) do lb = lb.Parent end
	if not lb then return end
	local shard = you and you.shard
	lastShard = shard
	if shard then
		setText(lb, "EggText", WORD[shard] .. " SHARD")
		tint(find(lb, "EggText"), colorOf(shard))
		local slot = find(lb, "EggSlot")
		if slot then setIcon(slot, "Icon", EGG_ICON[shard]) end
		-- one short line on where the shard came from (PointsController's "Common to Rare on crossing N" ran off the card)
		-- where the shard came from: EOS_Role is already LOBBY when Results land, so read the stash (a Catcher's shard is
		-- their stash; a survivor never has one; the server clears it at the next match's start)
		local runner = player:GetAttribute("EOS_EggStash") == nil
		setText(lb, "EggHow", if runner and guaranteedThisMatch then "Upgraded by your meter" elseif runner then "Safe to the end" else "Your best snatch")
		K.set(pieceText, ("+1 %s SHARD"):format(WORD[shard]))
		tint(pieceText, colorOf(shard))
		local pi = find(lb, "PieceIcon")
		if pi then K.icon(pi, SHARD_ICON[shard]) show(pi, true) end
	else
		setText(lb, "EggText", "NO EGG THIS MATCH")
		tint(find(lb, "EggText"), Color3.fromRGB(210, 210, 216))
		setText(lb, "EggHow", "Snatch an egg as a Catcher to keep one")
		K.set(pieceText, "")
		show(find(lb, "PieceIcon"), false)
	end
	require(script.Parent.EggResultsRow).apply(lb, shard, { ring = ring, setText = setText, show = show, tint = tint, num = num, find = find, K = K }) -- "+N FILL" in Results v2's EggBlock (fixes)
	-- the small incubator egg the shard flies to (fills when the settlement's ProfileState lands)
	local mini = lb:FindFirstChild("EggMini", true)
	if not mini then
		local row = K.template("ShardRow")
		local well = pieceText:FindFirstAncestor("You") or pieceText.Parent
		if row and well and well:IsA("GuiObject") then
			for _, n in { "ShardIcon", "ShardText", "ShardIconShadow", "ShardTextShadow" } do
				local x = row:FindFirstChild(n, true)
				if x then x:Destroy() end
			end
			row.Name = "EggMini"
			row.ZIndex = 20
			row.Parent = well
			roundRing(row:FindFirstChild("MiniRing", true))
			-- centre the mini ring at the well's right edge, level with the shard line (measured, any scale)
			local mr = row:FindFirstChild("MiniRing", true)
			if mr and mr:IsA("GuiObject") then
				local sc = well.AbsoluteSize.X / math.max(1, well.Size.X.Offset)
				local target = Vector2.new(well.AbsolutePosition.X + well.AbsoluteSize.X - 30 * sc,
					pieceText.AbsolutePosition.Y + pieceText.AbsoluteSize.Y / 2)
				local at = mr.AbsolutePosition + mr.AbsoluteSize / 2
				local d = (target - at) / sc
				row.Position = row.Position + UDim2.fromOffset(d.X, d.Y)
			end
			mini = row
		end
	end
	if mini and shard and animatedToken ~= resultsToken then
		animatedToken = resultsToken
		if require(script.Parent.EggResultsRow).whenSettled(function() crackAndFly(lb, mini, shard) end) then crackAndFly(lb, mini, shard) end -- after the egg box fades in (fixes)
	end
	if mini then
		show(mini, shard ~= nil)
		require(script.Parent.EggResultsRow).mini(mini, view, { ring = ring, setText = setText, show = show, tint = tint, num = num, find = find, K = K }) -- x / 18, then x / 36 FILL (fixes)
	end
end

---------------------------------------------------------------- init
local pendingProfile: any = nil -- a ProfileState that landed before the screens were ready
local onProfile: ((any) -> ())? = nil

-- every template image is drawn once, invisibly, at start: a first draw takes 1-2 s, longer than a banner shows
-- (ui-maker LESSONS: PreloadAsync fetches but doesn't decode)
local function warmImages()
	local seen = {}
	local holder = Instance.new("Frame")
	holder.Name = "EggImageWarm"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(4, 4)
	holder.Position = UDim2.fromOffset(0, 0) -- on screen: an off-screen image is never decoded (tested live: 0/9 vs 9/9)
	holder.Parent = fx
	local folder = ReplicatedStorage:FindFirstChild("EggUITemplates")
	for _, d in (folder and folder:GetDescendants() or {}) do
		if d:IsA("ImageLabel") and d.Image ~= "" and not seen[d.Image] then
			seen[d.Image] = true
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromOffset(4, 4)
			img.ImageTransparency = 0.98
			img.Image = d.Image
			img.Parent = holder
		end
	end
end

function EggUIController.init(uic: any)
	if not EggConfig.ENABLED then return end
	-- listen for the profile first, before anything below can yield (the first ProfileState can land early)
	Net.event("ProfileState").OnClientEvent:Connect(function(p)
		if onProfile then onProfile(p) else pendingProfile = p end
	end)
	UIC = uic
	local pg = player:WaitForChild("PlayerGui")
	gui = pg:WaitForChild("EggUI", 30) :: ScreenGui
	remotes = ReplicatedStorage:WaitForChild("EOS_Egg", 30) :: Folder
	if not (gui and remotes) then
		warn("[EggUI] missing EggUI or EOS_Egg: rebuild ServerStorage.EggUIBuild / check EggService")
		return
	end
	K = require(gui:WaitForChild("UIKit"))
	K.init("EggUITemplates", gui:WaitForChild("AssetIds"))
	EUI = require(gui:WaitForChild("UI"))
	EUI.init(gui)
	root = gui:WaitForChild("Root") :: Frame
	local eosui = pg:FindFirstChild("EOSUI")
	gui.DisplayOrder = (eosui and eosui.DisplayOrder or 0) + 2
	gui.Enabled = true
	fx = Instance.new("Frame")
	fx.Name = "EggFX"
	fx.BackgroundTransparency = 1
	fx.Size = UDim2.fromScale(1, 1)
	fx.ZIndex = 50
	fx.Parent = root
	for _, d in root:GetDescendants() do
		if d.Name == "FillRing" or d.Name == "MiniRing" then roundRing(d) end
	end
	warmImages()
	require(script.Parent.EggIncubatorView).init(EUI, function() return view end) -- boost / Lucky purchase prompts (fixes)

	-- EOSUI's Incubator opens the egg screen instead (every path goes through EOSUI's UI.open)
	local eosUI = eosui and eosui:FindFirstChild("UI")
	if eosUI then
		local M = require(eosUI)
		local orig = M.open
		M.open = function(name: string, ...)
			if name == "Incubator" and EggConfig.ENABLED then
				openIncubator()
				return
			end
			return orig(name, ...)
		end
	end

	remotes:WaitForChild("Charged").OnClientEvent:Connect(onCharged)
	remotes:WaitForChild("Rolled").OnClientEvent:Connect(onRolled)
	remotes:WaitForChild("Stash").OnClientEvent:Connect(function() refreshCard() end)
	player:GetAttributeChangedSignal("EOS_InMatch"):Connect(function()
		if player:GetAttribute("EOS_InMatch") == true then guaranteedThisMatch = false end -- a new match
	end)
	player:GetAttributeChangedSignal("EOS_LuckyEgg"):Connect(function() refreshIncubator() end)
	for _, a in { "EOS_Role", "EOS_Tier", "EOS_InMatch", "EOS_EggStash", "EOS_EggCap", "EOS_EggMarks" } do
		player:GetAttributeChangedSignal(a):Connect(function()
			refreshCard()
			readyBadge()
		end)
	end
	player:GetAttributeChangedSignal("EOS_EggCharge"):Connect(function()
		charge = tonumber(player:GetAttribute("EOS_EggCharge")) or 0
		refreshCard()
	end)
	onProfile = function(p)
		if type(p) ~= "table" then return end
		view = p.incubator
		firstCommonFree = p.firstCommonFree == true
		hatching = false
		refreshIncubator()
		refreshFirstPet()
		readyBadge()
		if lastShard ~= nil or (player.PlayerGui:FindFirstChild("PointsUI") and find(player.PlayerGui.PointsUI, "EggMini")) then
			local mini = find(player.PlayerGui.PointsUI, "EggMini")
			require(script.Parent.EggResultsRow).mini(mini, view, { ring = ring, setText = setText, show = show, tint = tint, num = num, find = find, K = K }) -- x / 18, then x / 36 FILL (fixes)
		end
	end
	if pendingProfile then onProfile(pendingProfile) pendingProfile = nil end
	task.delay(3, function() -- still nothing: ask once (the device argument is the player's own, so nothing changes)
		if view == nil then Net.event("RequestProfile"):FireServer(player:GetAttribute("EOS_Device")) end
	end)
	Net.event("HatchResult").OnClientEvent:Connect(function(t)
		if type(t) ~= "table" or not (t.incubator or t.firstPet) then return end
		hatching = false
		if t.ok then
			EUI.close() -- the existing hatch ceremony (UIController) plays on EOSUI
		end
		refreshIncubator()
	end)
	Net.event("Results").OnClientEvent:Connect(function(data)
		local you = type(data) == "table" and data.you
		if not you then return end
		resultsToken += 1
		for _, d in { 0.3, 1.0, 2.0 } do
			task.delay(d, applyResults, you) -- PointsController fills the card first; ours lands on top
		end
	end)
	EUI.Action:Connect(function(name: string, _screen: string?, b: Instance?)
		if name == "BtnHatch" and view and view.ready and not hatching then
			hatching = true
			refreshIncubator()
			remotes.HatchIncubator:FireServer()
			task.delay(6, function()
				if hatching then hatching = false refreshIncubator() end
			end)
		elseif name:match("^Focus_") then
			local fam = name:sub(7)
			local open = fam == "Any" or (view and view.focusOpen and view.focusOpen[fam])
			if open then
				remotes.SetFocus:FireServer(fam)
			elseif UIC and UIC.toast then
				UIC.toast(fam .. " pets are coming soon", "info")
			end
		elseif name:match("^Pick_") then
			pickFamily = name:sub(6)
			refreshFirstPet()
		elseif name == "BtnClaim" and pickFamily then
			remotes.ClaimFirstPet:FireServer(pickFamily)
		end
	end)
	RunService.Heartbeat:Connect(hideOldCard)
	task.spawn(require(script.Parent:WaitForChild("EggFX")).init) -- stage 5: glow, pulse, roll flicker, upgrade burst
	task.spawn(require(script.Parent:WaitForChild("EggShardIntro")).init) -- start-of-match shard intro (approved 17 Oct)
	task.spawn(require(script.Parent:WaitForChild("IncubatorWorld")).init, { view = function() return view end, open = openIncubator, ui = EUI, remotes = remotes }) -- HOS-INC-001: the lobby incubator (animation, your egg built from its shards, walk-up)
	refreshCard()
end

return EggUIController
