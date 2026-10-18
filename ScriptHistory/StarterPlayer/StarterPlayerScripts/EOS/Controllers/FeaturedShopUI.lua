--!nonstrict
-- FeaturedShopUI (client): the Shop's Featured tab, v3 (HOS-FEAT-001, Hunter 18 Oct 03:34 "Featured approved").
-- Hunter: "it should be one pet, the bone dragon, it should be a weapon crate, and maybe a specific halloween weapon";
-- 03:25 "the jackolantern, witchs cat, and mummy should be available in the featured daily. the featured shop should
-- have items that cycle every day"; layout from his item-shop reference (structure only).
--
--   Controllers.HalloweenShopUI.slots(sc): one line hands Featured to FeaturedShopUI.slots(sc) (UIController untouched)
--
-- * FEATURED ITEMS (left): two tall cards that never change: the Bone Dragon (Robux, pet + Tempest ability) and All
--   Hallow's Sword (EconomyConfig.KNIFE_FEATURED, Gems).
-- * DAILY ITEMS (right): a 2x2 grid, new every day at 00:00 UTC and the same for everyone (FeaturedShopUI.daily(day)):
--   until HalloweenShop.ENDS_AT one slot always holds a Halloween pet (Jack-o'-Lantern, Witch's Cat, Mummy in turn, a
--   second one every other day), one slot today's best daily weapon (EconomyConfig.knifeDaily, so the server sells it
--   today), the rest premium effects / trails. Countdown in the header.
-- * Weapon Crate banner (bottom): OPEN buys one Weapon Crate here (RequestWeaponCrate, the prize pops up with
--   UIC.showReward); ALL opens the Weapons tab when UIController offers UIC.openShopTab; what it can drop shows only
--   on hover / tap of the banner.
-- * Looks: roblox-ui-maker templates (ReplicatedStorage.FeaturedUITemplates from UI/build_featured.py s_templates via
--   ui_feat/rbx.json). Prices, buttons and their clicks come from UIController's Featured loop (fillButtons /
--   wireButtons_), keyed through EconomyConfig.FEATURED["feat_<item id>"] (registered here, client only).
-- * Previews stay inside the hovered card (tap the picture on a touch screen): pets through ShopPetPreview (StageInPlace),
--   effects / trails through ShopItemPreview.attachCard, weapons here (your character holding it, idle then swing).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local AnimConfig = require(Shared:WaitForChild("AnimConfig"))
local HalloweenShop = require(Shared:WaitForChild("HalloweenShop"))
local Net = require(Shared:WaitForChild("Net"))

local FeaturedShopUI = {}

FeaturedShopUI.BIG = { "hwn_dragon", "knife_" .. EconomyConfig.KNIFE_FEATURED.skin }
FeaturedShopUI.PETS = { "hwn_wraith", "hwn_cat", "hwn_mummy" }
FeaturedShopUI.COSMETICS = { "hatch_royal", "fx_gold", "trailp_rainbow", "fx_rift_void", "fx_rift_inferno", "fx_rift_frost" }
FeaturedShopUI.RARITY = { hatch_royal = "epic", fx_gold = "epic", trailp_rainbow = "rare", fx_rift_void = "rare", fx_rift_inferno = "rare", fx_rift_frost = "rare" }
FeaturedShopUI.RIBBON = { hwn_dragon = "RibbonNew", ["knife_" .. EconomyConfig.KNIFE_FEATURED.skin] = "RibbonLimited" }
local TYPE_WORDS = { trailPerm = "Egg trail", abilityFx = "Ability effect", hatchFx = "Hatch effect", abilitySkin = "Rift colour", knifeSkin = "Weapon" }
local TEMPLATE_RARITY = { legendary = "Legendary", epic = "Epic", rare = "Rare", common = "Rare" }
-- page geometry (PageFeatured's own coordinates; UI/build_featured.py FX / DX / BY minus its 26, 102 origin)
local HEADER_POS = UDim2.fromOffset(0, 2)
local BIG_POS = { UDim2.fromOffset(0, 44), UDim2.fromOffset(408, 44) }
local DAILY_POS = { UDim2.fromOffset(820, 44), UDim2.fromOffset(1180, 44), UDim2.fromOffset(820, 312), UDim2.fromOffset(1180, 312) }
local BANNER_POS = UDim2.fromOffset(0, 581) -- ends 26 px above the panel edge (the side gutter), Hunter 04:17
local DWELL = 0.08
local FULL_INSET = 6 -- a daily card's preview covers the card, this far in from its edge
local SCENE_BOTTOM = 0.55 -- a daily card's name, subtitle and buttons start this far down its preview (ShopItemPreview frames above it)
local SWING_EVERY = 2.4
local OURS = { "FeatHeader", "Feat1", "Feat2", "Daily1", "Daily2", "Daily3", "Daily4", "FeatCrate" }
local OLD = { "FeatA", "FeatB", "HwnCardWraith", "HwnCardCat", "HwnCardMummy", "HwnCardDragon" }

local player = Players.LocalPlayer
local lastProfile: any = nil
local pendingCrate = 0
local timerOn = false

local function templates(): Instance?
	return ReplicatedStorage:FindFirstChild("FeaturedUITemplates") or script:FindFirstChild("Templates")
end

local function uic(): any
	local ok, m = pcall(function()
		return require(script.Parent:FindFirstChild("UIController") :: ModuleScript)
	end)
	return if ok then m else nil
end

local function setText(scope: Instance?, name: string, text: string)
	if not scope then
		return
	end
	for _, d in scope:GetDescendants() do
		if d:IsA("TextLabel") and (d.Name == name or d.Name == name .. "Shadow") then
			d.Text = text
		end
	end
end

local function show(inst: Instance?, on: boolean)
	if inst and inst:IsA("GuiObject") then
		inst.Visible = on
	end
end

-- an exported element and the DropShadow twin the exporter put beside it (same size, 4 px lower)
local function shadowOf(g: GuiObject): GuiObject?
	local p = g.Parent
	if not p then
		return nil
	end
	for _, s in p:GetChildren() do
		if s.Name == "DropShadow" and s:IsA("GuiObject") and math.abs(s.Size.X.Offset - g.Size.X.Offset) <= 6
			and math.abs(s.Size.Y.Offset - g.Size.Y.Offset) <= 6 and math.abs(s.Position.X.Offset - g.Position.X.Offset) <= 4
			and math.abs(s.Position.Y.Offset - g.Position.Y.Offset) <= 6 then
			return s
		end
	end
	return nil
end

local function showWithShadow(g: Instance?, on: boolean)
	if g and g:IsA("GuiObject") then
		g.Visible = on
		local s = shadowOf(g)
		if s then
			s.Visible = on
		end
	end
end

local function destroyWithShadow(g: Instance?)
	if g and g:IsA("GuiObject") then
		local s = shadowOf(g)
		if s then
			s:Destroy()
		end
		g:Destroy()
	end
end

local function touchFirst(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function commas(n: number): string
	local t = tostring(math.floor(n))
	while true do
		local k
		t, k = t:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			return t
		end
	end
end

-- short of Gems (Hunter 04:38 "just prompt the gem dev product if they dont have enough when clicking"): Roblox's own
-- purchase prompt for the smallest Gem pack that covers the gap (the biggest if none does), the packs the Gems tab sells.
-- No auto-buy afterwards: the player taps the item again once the Gems land.
function FeaturedShopUI.promptGems(need: number)
	local GC = require(Shared:WaitForChild("GameConfig"))
	if not (GC.Features and GC.Features.SHOP_PURCHASES) then
		local C = uic()
		if C and C.toast then
			C.toast(("Need %s more Gems"):format(commas(need)), "bad")
		end
		return
	end
	local pick = nil
	for _, pack in ipairs(EconomyConfig.GEM_PACKS or {}) do
		if pack.productId then
			pick = pack
			if pack.gems >= need then
				break
			end
		end
	end
	if pick then
		pcall(function()
			game:GetService("MarketplaceService"):PromptProductPurchase(player, pick.productId)
		end)
	end
end

-- ===== the daily pick (same for everyone: a pure function of the UTC day)

function FeaturedShopUI.utcDay(now: number?): number
	return math.floor((now or HalloweenShop.now()) / 86400)
end

function FeaturedShopUI.daily(day: number): { string }
	local C, P = FeaturedShopUI.COSMETICS, FeaturedShopUI.PETS
	local event = day * 86400 < HalloweenShop.ENDS_AT
	local weapons = EconomyConfig.knifeDaily(day) -- { epic, rare, common, common }: the store's draw, so the server sells it today
	local out = {}
	table.insert(out, if event then P[day % #P + 1] else (weapons[2] or C[(day + 4) % #C + 1]))
	table.insert(out, C[day % #C + 1])
	table.insert(out, weapons[1] or C[(day + 2) % #C + 1])
	if event and day % 2 == 1 then
		table.insert(out, P[(day + 1) % #P + 1])
	else
		table.insert(out, C[(day + 3) % #C + 1])
	end
	return out
end

local function rarityOf(it: any): string
	return FeaturedShopUI.RARITY[it.id] or it.rarity or "rare"
end

local function typeWords(it: any): string
	if it.kind == "pet" then
		return ("·  Pet  ·  %s ability"):format(it.family or "")
	end
	return "·  " .. (TYPE_WORDS[it.kind] or "Keep forever")
end

local RARITY_HEX = { legendary = "#ffc83a", epic = "#c77dff", rare = "#3fb4ff", common = "#9be05a" }

local SHORT_WORDS = { pet = "Pet", knifeSkin = "Weapon", trailPerm = "Trail", abilityFx = "Effect", hatchFx = "Effect", abilitySkin = "Rift colour" }
local MIN_SCREEN_PX = 11 -- the subtitle never renders smaller than this (tiny Fredoka text lost its letter spacing on phones)

-- "LEGENDARY  ·  Pet  ·  Tempest ability": one rich-text label, the rarity word in its colour (the shadow twin plain).
-- On a small screen it switches to the short form ("LEGENDARY  ·  Pet") at a size that stays >= MIN_SCREEN_PX.
local function setTypeLine(card: Instance, rarity: string, words: string, short: string)
	local up = string.upper(rarity)
	local labels = {}
	for _, d in card:GetDescendants() do
		if d:IsA("TextLabel") and (d.Name == "TypeLine" or d.Name == "TypeLineShadow") then
			table.insert(labels, d)
			if d:GetAttribute("FeatTS") == nil then
				d:SetAttribute("FeatTS", d.TextSize)
				d:SetAttribute("FeatH", d.Size.Y.Offset)
			end
		end
	end
	local function apply()
		for _, d in labels do
			local design = d:GetAttribute("FeatTS") :: number
			local scale = d.AbsoluteSize.X / math.max(d.Size.X.Offset, 1)
			local small = scale > 0 and design * scale < MIN_SCREEN_PX
			local w = if small then "·  " .. short else words
			local size = if small then math.ceil(MIN_SCREEN_PX / scale) else design
			-- the item name above stays a step bigger: on small screens it grows to MIN_SCREEN_PX + 3 (fitted to its width)
			if small then
				for _, nm in card:GetChildren() do
					if nm:IsA("TextLabel") and (nm.Name == "ItemName" or nm.Name == "ItemNameShadow" or nm.Name == "Title" or nm.Name == "TitleShadow") then
						local want = math.ceil((MIN_SCREEN_PX + 2) / scale)
						if nm.TextScaled or nm.TextSize < want then
							local ns = want
							while ns > size + 1 and #nm.Text * ns * 0.58 > nm.Size.X.Offset do
								ns -= 1
							end
							nm.TextScaled = false
							nm.TextSize = math.max(ns, size + 1)
							local oh = nm:GetAttribute("FeatH0") :: number?
							if not oh then
								oh = nm.Size.Y.Offset
								nm:SetAttribute("FeatH0", oh)
								nm:SetAttribute("FeatY0", nm.Position.Y.Offset)
							end
							local nh = math.max(oh :: number, nm.TextSize + 2)
							-- grow upward, keeping its bottom edge, so it never runs into the subtitle below
							nm.Size = UDim2.fromOffset(nm.Size.X.Offset, nh)
							nm.Position = UDim2.fromOffset(nm.Position.X.Offset, (nm:GetAttribute("FeatY0") :: number) + (oh :: number) - nh)
						end
					end
				end
			end
			local plainLen = #up + 2 + #w
			while size > design and plainLen * size * 0.66 > d.Size.X.Offset do -- Montserrat runs wider -- keep it on one line inside the card
				size -= 1
			end
			d.TextScaled = false
			d.TextWrapped = false
			d.TextSize = size
			d.Size = UDim2.fromOffset(d.Size.X.Offset, math.max(d:GetAttribute("FeatH") :: number, size + 4))
			-- plain text in the rarity's colour, in the kit's Montserrat ExtraBold: Fredoka split letters at small sizes
			-- ("E PIC", "RA RE"; Hunter's reviews 04:54, 05:08)
			d.RichText = false
			d.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
			d.Text = up .. "  " .. w
			if d.Name == "TypeLine" then
				local g = d:FindFirstChildOfClass("UIGradient")
				if g then
					g.Enabled = false
				end
				d.TextColor3 = Color3.fromHex(RARITY_HEX[rarity] or "#ffffff")
			end
		end
	end
	apply()
	if labels[1] then
		labels[1]:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	end
end

-- ===== weapons: a clean render at rest, your character holding it on hover (Controllers.WeaponShopUI's stage, in the card)

local function strip(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Sound") or d:IsA("BaseScript") then
			d:Destroy()
		end
	end
end

local function arm(char: Model, skinTpl: BasePart, armName: string, motorName: string, partName: string)
	local a = char:FindFirstChild(armName) :: BasePart?
	if not a then
		return
	end
	local w = skinTpl:Clone() :: BasePart
	strip(w)
	w.Name = partName
	for _, d in w:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
		end
	end
	w.Anchored = false
	local m = w:FindFirstChildOfClass("Motor6D")
	if not m then
		w:Destroy()
		return
	end
	m.Name = motorName
	m.Part0 = a
	m.Part1 = w
	w.CFrame = a.CFrame * m.C0 * m.C1:Inverse()
	m.Parent = a
	for _, k in w:GetChildren() do
		local sw = k:IsA("BasePart") and k:FindFirstChild("SkinWeld") :: Weld?
		if sw then
			local j = Instance.new("Motor6D")
			j.Part0, j.Part1, j.C0 = w, k :: BasePart, sw.C0
			j.Parent = k
			sw:Destroy()
		end
	end
	w.Parent = char
end

local controls: { [Instance]: { open: () -> (), close: () -> () } } = {}

local function weaponStage(card: GuiObject, art: GuiObject, it: any)
	local token = 0
	local hovering = false
	local stage: Frame? = nil

	local function close()
		token += 1
		if stage then
			stage:Destroy()
			stage = nil
		end
	end

	local function open()
		if stage or not card.Visible then
			return
		end
		local lib = ReplicatedStorage:FindFirstChild("EOS_KnifeSkinPreviews")
		local tpl = lib and lib:FindFirstChild(it.skin)
		if not tpl or not tpl:IsA("BasePart") then
			return
		end
		token += 1
		local my = token
		local s = Instance.new("Frame") -- runtime stage over the art box (a viewport host, no look of its own)
		s.Name = "WeaponStage"
		s.Position = art.Position
		s.Size = art.Size
		if card.Size.Y.Offset <= 300 then -- daily card: the whole card (blendStage keeps it there)
			s.Position = UDim2.fromOffset(FULL_INSET, FULL_INSET)
			s.Size = UDim2.fromOffset(card.Size.X.Offset - 2 * FULL_INSET, card.Size.Y.Offset - 2 * FULL_INSET)
		end
		s.BackgroundColor3 = Color3.fromRGB(18, 14, 36)
		s.ClipsDescendants = true
		s.ZIndex = 30
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = s
		local okP, SPP = pcall(require, script.Parent:FindFirstChild("ShopPetPreview"))
		local bd = Instance.new("ImageLabel")
		bd.Name = "Backdrop"
		bd.BackgroundTransparency = 1
		bd.Size = UDim2.fromScale(1, 1)
		bd.ScaleType = Enum.ScaleType.Crop
		bd.Image = if okP and SPP and SPP.BACKDROP then SPP.BACKDROP.violet else ""
		bd.ZIndex = 30
		bd.Parent = s
		local vf = Instance.new("ViewportFrame")
		vf.Name = "Stage3D"
		vf.BackgroundTransparency = 1
		vf.Size = UDim2.fromScale(1, 1)
		vf.Ambient = Color3.fromRGB(205, 200, 220)
		vf.LightColor = Color3.fromRGB(255, 250, 240)
		vf.LightDirection = Vector3.new(-0.6, -1, -0.7)
		vf.ZIndex = 31
		vf.Parent = s
		s.Parent = card
		stage = s
		-- the weapon on its own, filling the stage, turning slowly with a gentle bob (a held weapon was too small to read)
		local skin = tpl:Clone() :: BasePart
		strip(skin)
		local motor = skin:FindFirstChildOfClass("Motor6D")
		if motor then
			motor:Destroy()
		end
		local lean = CFrame.Angles(0, 0, math.rad(-35))
		local function place(cf: CFrame)
			skin.Anchored = true
			skin.CFrame = cf
			for _, k in skin:GetChildren() do
				if k:IsA("BasePart") then
					local w = k:FindFirstChild("SkinWeld") :: Weld?
					k.Anchored = true
					if w then
						k.CFrame = cf * w.C0
					end
				end
			end
		end
		-- centre the blade on the origin (SkinCenter when the publisher measured it)
		local ctr = (tpl:GetAttribute("SkinCenter") :: Vector3?) or Vector3.zero
		local base = lean * CFrame.new(-ctr)
		place(base)
		skin.Parent = vf
		local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, q in skin:GetDescendants() do
			if q:IsA("BasePart") then
				local h = q.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local w = q.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
							mn, mx = mn:Min(w), mx:Max(w)
						end
					end
				end
			end
		end
		local h0 = skin.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local w = skin.CFrame * Vector3.new(h0.X * sx, h0.Y * sy, h0.Z * sz)
					mn, mx = mn:Min(w), mx:Max(w)
				end
			end
		end
		local size = mx - mn
		local radius = math.max(size.X, size.Y, size.Z) * 0.5 -- whatever way it faces while it turns
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		local aspect = math.max(s.AbsoluteSize.X, 1) / math.max(s.AbsoluteSize.Y, 1)
		local halfV = math.tan(math.rad(cam.FieldOfView / 2))
		local dist = (radius * (if aspect > 1.6 then 0.85 else 1.05)) / (halfV * math.min(1, aspect)) + radius * 0.25 -- wide daily boxes: closer
		local centre = (mn + mx) / 2
		cam.CFrame = CFrame.lookAt(centre + Vector3.new(0, size.Y * 0.04, dist), centre)
		cam.Parent = vf
		vf.CurrentCamera = cam
		local t0 = os.clock()
		local conn: RBXScriptConnection? = nil
		conn = game:GetService("RunService").RenderStepped:Connect(function()
			if token ~= my or not stage or not card.Visible then
				if conn then
					conn:Disconnect()
				end
				return
			end
			local t = os.clock() - t0
			local turn = CFrame.new(centre) * CFrame.Angles(0, t * 0.9, 0) * CFrame.new(0, math.sin(t * 1.6) * radius * 0.04, 0) * CFrame.new(-centre)
			place(turn * base)
		end)
	end

	controls[card] = { open = open, close = close }
	card.Destroying:Connect(function()
		controls[card] = nil
	end)
	card.MouseEnter:Connect(function()
		if touchFirst() then
			return
		end
		hovering = true
		task.delay(DWELL, function()
			if hovering then
				open()
			end
		end)
	end)
	card.MouseLeave:Connect(function()
		hovering = false
		close()
	end)
	art.Active = true
	art.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			if stage then
				close()
			else
				open()
			end
		end
	end)
	card:GetPropertyChangedSignal("Visible"):Connect(function()
		if not card.Visible then
			close()
		end
	end)
	local screen = card:FindFirstAncestor("Shop")
	if screen and screen:IsA("GuiObject") then
		screen:GetPropertyChangedSignal("Visible"):Connect(function()
			if not screen.Visible then
				close()
			end
		end)
	end
end

-- ===== one card

local function buildCard(pf: Instance, tf: Instance, id: string, slotName: string, pos: UDim2, big: boolean, n: number?)
	local it = EconomyConfig.item(id)
	if not it then
		return nil
	end
	local rar = rarityOf(it)
	local tplName = if big then "FeatBigLegendary" else ("FeatSmall" .. (TEMPLATE_RARITY[rar] or "Rare"))
	local tpl = tf:FindFirstChild(tplName)
	if not tpl then
		return nil
	end
	local root = tpl:Clone() :: GuiObject
	root.Name = slotName
	root.Position = pos
	root.Visible = true
	local card = root:FindFirstChild("Card") :: GuiObject
	local art = card:FindFirstChild("ArtBox") :: GuiObject
	setText(card, if big then "Title" else "ItemName", if big then string.upper(it.name) else it.name)
	for _, d in card:GetChildren() do -- one line always: scaled text shrinks to fit instead of wrapping out of sight (phones)
		if d:IsA("TextLabel") and (d.Name == "Title" or d.Name == "TitleShadow" or d.Name == "ItemName" or d.Name == "ItemNameShadow") then
			d.TextWrapped = false
			d:GetPropertyChangedSignal("TextWrapped"):Connect(function() -- the gui's fit pass turns it back on
				if d.TextWrapped then
					d.TextWrapped = false
				end
			end)
		end
	end
	setTypeLine(card, rar, typeWords(it), SHORT_WORDS[it.kind] or "Item")
	-- ribbon
	local rib = FeaturedShopUI.RIBBON[id] or (if it.kind == "pet" then "RibbonEvent" else nil)
	for _, r in { "RibbonNew", "RibbonLimited", "RibbonEvent" } do
		local g = card:FindFirstChild(r)
		showWithShadow(g, r == rib)
		if g and g:IsA("GuiObject") then
			g.ZIndex += 70 -- over the preview stages, and over its own drop (ShopPetPreview raises every DropShadow by 20)
			local s = shadowOf(g)
			if s then
				s.ZIndex += 40
			end
		end
	end
	local badge = card:FindFirstChild("CountBadge")
	if badge and badge:IsA("GuiObject") then
		local sh = shadowOf(badge)
		if sh then
			sh:Destroy() -- the exported drop sat off to one side in Roblox (Hunter's capture 03:54)
		end
		setText(badge, "Label", ("%d OF 2"):format(n or 1))
		for _, d in badge:GetDescendants() do
			if d:IsA("TextLabel") then
				d.Text = ("%d OF 2"):format(n or 1)
			end
		end
	end
	-- short of Gems: our own green button (UIController doesn't know it, so its confirm dialog never shows)
	local poorB = card:FindFirstChild("BtnPoor")
	if poorB then
		poorB.Name = "BtnShort"
		if it.wallet ~= "robux" and poorB:IsA("GuiButton") then
			setText(poorB, "Price", commas(it.price))
			local C = uic()
			if C and C.juicy then
				pcall(C.juicy, poorB)
			end
			poorB.Activated:Connect(function()
				FeaturedShopUI.promptGems(math.max(1, it.price - ((lastProfile and lastProfile.gems) or 0)))
			end)
		end
	end
	-- the price strip: Robux-only items get the full-width purple strip
	if it.wallet == "robux" then
		for _, nm in { "BtnPrice", "BtnShort", "BtnRobux" } do
			local b = card:FindFirstChild(nm)
			if b then
				b:Destroy()
			end
		end
		local full = card:FindFirstChild("BtnRobuxFull")
		if full then
			full.Name = "BtnRobux"
		end
	else
		local full = card:FindFirstChild("BtnRobuxFull")
		if full then
			full:Destroy()
		end
	end
	root.Parent = pf
	-- picture + preview
	if it.kind == "knifeSkin" then
		for _, nm in { "Icon", "IconShadow" } do
			local g = card:FindFirstChild(nm)
			if g then
				g:Destroy() -- UIController's setIcon would put a gift there
			end
		end
		task.spawn(function()
			local ok, W = pcall(require, script.Parent:FindFirstChild("WeaponShopUI"))
			if ok and W and W.renderSkin then
				pcall(W.renderSkin, art, it.skin)
			end
		end)
		weaponStage(card, art, it)
	elseif it.kind == "pet" then
		-- our PREVIEW button (tag row) replaces ShopPetPreview's own tag
		card:SetAttribute("StageInPlace", true)
		card:SetAttribute("ChipsY", art.Position.Y.Offset + 6) -- top of the picture, clear of the "1 OF 2" badge
		local ok, SPP = pcall(require, script.Parent:FindFirstChild("ShopPetPreview"))
		if ok and SPP then
			pcall(SPP.attach, root, id)
		end
		local hint = card:FindFirstChild("PreviewHint")
		if hint then
			hint:Destroy()
		end
	else
		local ok, SIP = pcall(require, script.Parent:FindFirstChild("ShopItemPreview"))
		if ok and SIP and SIP.attachCard then
			pcall(SIP.attachCard, card, id)
		end
	end
	FeaturedShopUI._wirePreview(root, card, it)
	FeaturedShopUI._watchStages(card)
	return card
end

-- a preview stage inside a card (ShopPetPreview "PreviewStage", ShopItemPreview "ItemPreview", ours "WeaponStage"):
-- the backdrop and the stage's own fill fade out toward the card (most at the bottom, where the title is), the bright
-- outline goes, and the backdrop is toned down a step. The model / viewport itself stays fully opaque.
local STAGES = { PreviewStage = true, ItemPreview = true, WeaponStage = true }

-- a daily card (short): its preview covers the whole card, under the name / subtitle / buttons (drawn over its faded
-- bottom); the card's art box hides while it is open
local function fullCard(stage: GuiObject): boolean
	local card = stage.Parent :: GuiObject?
	if not card or not card:IsA("GuiObject") then
		return false
	end
	-- every card: its static picture hides while the (now see-through-edged) preview is open
	local art0 = card:FindFirstChild("ArtBox") :: GuiObject?
	if art0 then
		art0.Visible = false
		stage.AncestryChanged:Connect(function()
			if not stage:IsDescendantOf(card) then
				art0.Visible = true
			end
		end)
	end
	if card.Size.Y.Offset > 300 then
		return false
	end
	local goal = {
		Position = UDim2.fromOffset(FULL_INSET, FULL_INSET),
		Size = UDim2.fromOffset(card.Size.X.Offset - 2 * FULL_INSET, card.Size.Y.Offset - 2 * FULL_INSET),
	}
	stage.ZIndex = 5 -- over the art box (2-4), under the name (15), subtitle (17) and buttons (18+)
	stage:SetAttribute("SceneBottom", SCENE_BOTTOM)
	-- grow straight out to the whole card. This tween replaces the preview module's own 0.25 s open tween to the art box
	-- (the newer tween on a property cancels the older), which shrank the scene and then snapped it to the whole card
	-- (HOS-PREV-001, Matthew: "it zooms out then zooms in as if the zoom is tweaking on tween")
	TweenService:Create(stage, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	task.delay(0.3, function() -- (in case anything else moved it meanwhile)
		if stage.Parent then
			stage.Position, stage.Size, stage.ZIndex = goal.Position, goal.Size, 5
		end
	end)
	return true
end

local function blendStage(stage: Instance)
	if not stage:IsA("GuiObject") then
		return
	end
	local full = fullCard(stage)
	require(script.Parent:WaitForChild("PreviewBlend")).blend(stage) -- the shared four-side fade (all previews)
	-- a short, wide daily box: the item scenes were framed for tall boxes, so bring their camera in to fill it
	if stage.Name == "ItemPreview" and not full then
		task.delay(0.3, function()
			if not stage.Parent then
				return
			end
			local aspect = stage.AbsoluteSize.X / math.max(stage.AbsoluteSize.Y, 1)
			if aspect > 1.8 then
				for _, v in stage:GetDescendants() do
					if v:IsA("ViewportFrame") and v.CurrentCamera then
						v.CurrentCamera.FieldOfView = math.max(14, v.CurrentCamera.FieldOfView * 0.62)
					end
				end
			end
		end)
	end
end

function FeaturedShopUI._watchStages(card: GuiObject) -- a table field: buildCard (above) calls it
	card.ChildAdded:Connect(function(c)
		if STAGES[c.Name] then
			task.defer(blendStage, c)
		elseif c.Name == "PreviewClips" and card.Size.Y.Offset <= 300 and c:IsA("GuiObject") then
			c.Visible = false -- daily cards: the IDLE / MOVE / CAST labels covered too much of the scene (Hunter 05:02)
		end
	end)
end

-- the PREVIEW button (tag row, top-right) toggles the card's own preview; hover / tapping the picture do too
function FeaturedShopUI._wirePreview(root: GuiObject, card: GuiObject, it: any) -- defined after buildCard, so a table field
	local b = card:FindFirstChild("PreviewChip")
	if not b or not b:IsA("GuiButton") then
		return
	end
	local C = uic()
	if C and C.juicy then
		pcall(C.juicy, b)
	end
	local on = false
	b.Activated:Connect(function()
		on = not on
		if it.kind == "knifeSkin" then
			FeaturedShopUI.preview(card, on)
		elseif it.kind == "pet" then
			local ok, SPP = pcall(require, script.Parent:FindFirstChild("ShopPetPreview"))
			if ok and SPP and SPP.toggle then
				SPP.toggle(root)
			end
		else
			local ok, SIP = pcall(require, script.Parent:FindFirstChild("ShopItemPreview"))
			if ok and SIP and SIP.preview then
				SIP.preview(card, on)
			end
		end
	end)
end

-- after UIController's fill: when it hid the buy button for want of Gems (no owned / equip state showing), our green
-- BtnShort takes its exact place and size (UIController widened BtnPrice already)
local function afterFill(cards: { [string]: any }, _have: number?)
	task.defer(function()
		for _, rec in cards do
			local card = rec.card
			local short = card and card:FindFirstChild("BtnShort") :: GuiObject?
			local price = card and card:FindFirstChild("BtnPrice") :: GuiObject?
			if short and price then
				local busy = price.Visible
				for _, nm in { "BtnOwned", "BtnWear", "BtnTakeOff", "BtnUse" } do
					local g = card:FindFirstChild(nm) :: GuiObject?
					busy = busy or (g ~= nil and g.Visible)
				end
				short.Visible = not busy
				short.Position = price.Position
				short.Size = price.Size
				if short:GetAttribute("JuiceRest") ~= nil then
					short:SetAttribute("JuiceRest", short.Position) -- UI.juicy springs back here on hover / press
				end
				for _, c in short:GetDescendants() do
					if c:IsA("ImageLabel") and c.Name == "Art" then
						c.Size = UDim2.new(1, 0, c.Size.Y.Scale, c.Size.Y.Offset)
					end
				end
			end
		end
	end)
end

-- Gems in the wallet: the newest profile, else the Shop's own wallet label
local function gemsNow(sc: Instance): number?
	if lastProfile and lastProfile.gems then
		return lastProfile.gems
	end
	local l = sc:FindFirstChild("GemsText", true)
	local n = l and l:IsA("TextLabel") and tonumber((string.gsub(l.Text, "%D", ""))) or nil
	return n
end

-- ===== the crate banner

local function crateDef(): any
	local K = EconomyConfig.KNIFE_CRATES
	return (K and K.weapon) or { name = "Weapon Crate", gems = 250 }
end

local function fillBanner(b: Instance, have: number?)
	local def = crateDef()
	local poor = have ~= nil and have < def.gems
	show(b:FindFirstChild("BtnOpen", true), not poor)
	show(b:FindFirstChild("BtnOpenPoor", true), poor)
	setText(b, "Price", tostring(def.gems))
	local C = uic()
	show(b:FindFirstChild("BtnAllCrates", true), C ~= nil and C.openShopTab ~= nil)
end

local function buildBanner(pf: Instance, tf: Instance)
	local tpl = tf:FindFirstChild("FeatCrateBanner")
	if not tpl then
		return
	end
	local root = tpl:Clone() :: GuiObject
	root.Name = "FeatCrate"
	root.Position = BANNER_POS
	root.Visible = true
	root.Parent = pf
	local b = root:FindFirstChild("Banner") :: GuiObject
	local contents = b:FindFirstChild("Contents") :: GuiObject?
	-- odds from the crate's own table when it has one
	local odds = EconomyConfig.KNIFE_CRATE and EconomyConfig.KNIFE_CRATE.odds
	if type(odds) == "table" and odds.legendary then
		local function pct(x: number): string -- the table holds percents (3) or fractions (0.03)
			return tostring(math.floor((if x <= 1 then x * 100 else x) + 0.5)) .. "%"
		end
		-- two short lines, each rarity in its colour, so nothing runs into SEE INSIDE on a phone (Hunter's review, 04:29)
		local function line(name: string, a: string, pa: string, ca: string, bb: string, pb: string, cb: string)
			for _, d in b:GetDescendants() do
				if d:IsA("TextLabel") and (d.Name == name or d.Name == name .. "Shadow") then
					local shadow = d.Name ~= name
					d.RichText = not shadow
					d.Text = if shadow then ("%s %s     %s %s"):format(a, pa, bb, pb)
						else ('<font color="%s">%s %s</font>     <font color="%s">%s %s</font>'):format(ca, a, pa, cb, bb, pb)
					d.TextXAlignment = Enum.TextXAlignment.Left
					d.TextScaled = false
					d.TextSize = 13
					d.Size = UDim2.fromOffset(176, d.Size.Y.Offset)
				end
			end
		end
		line("OddsTop", "LEGENDARY", pct(odds.legendary), "#ffc83a", "EPIC", pct(odds.epic or 0), "#c77dff")
		line("OddsRest", "RARE", pct(odds.rare or 0), "#3fb4ff", "COMMON", pct(odds.common or 0), "#9be05a")
	end
	-- sample renders, one per rarity (Weapon Crate pool only)
	local built = false
	-- one weapon render per slot (top of each rarity in the Weapon Crate pool); a slot whose render can't load is
	-- hidden, never left as an empty box (Hunter rejected empty boxes). Built when the banner is made, retried on open.
	local function buildTiles()
		if built or not contents then
			return
		end
		local ok, W = pcall(require, script.Parent:FindFirstChild("WeaponShopUI"))
		if not (ok and W and W.renderSkin) or not ReplicatedStorage:FindFirstChild("EOS_KnifeSkinPreviews") then
			return -- the server publishes the previews a moment after join: try again on the next open
		end
		built = true
		local want = { "legendary", "epic", "rare", "common", "legendary" }
		local used = {}
		for i, r in want do
			local tile = contents:FindFirstChild("Tile" .. i, true) :: GuiObject?
			local pic = tile and tile:FindFirstChild("Pic") :: GuiObject?
			local done = false
			for _, it in ipairs(EconomyConfig.SHOP) do
				if pic and it.kind == "knifeSkin" and it.rarity == r and (it.crate or "weapon") == "weapon" and not used[it.id] then
					used[it.id] = true
					local okR, vf = pcall(W.renderSkin, pic, it.skin)
					if okR and vf then
						done = true
						break
					end
				end
			end
			if tile then
				tile.Visible = done
			end
		end
	end
	task.spawn(function()
		ReplicatedStorage:WaitForChild("EOS_KnifeSkinPreviews", 20)
		buildTiles()
	end)
	local function open(on: boolean)
		if on then
			buildTiles()
		end
		show(contents, on)
	end
	local hovering = false
	b.MouseEnter:Connect(function()
		if touchFirst() then
			return
		end
		hovering = true
		task.delay(DWELL, function()
			if hovering then
				open(true)
			end
		end)
	end)
	b.MouseLeave:Connect(function()
		hovering = false
		open(false)
	end)
	b.Active = true
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			open(not (contents and contents.Visible))
		end
	end)
	for _, d in b:GetDescendants() do
		if d:IsA("GuiButton") and d:GetAttribute("Button") then
			local C = uic()
			if C and C.juicy then
				pcall(C.juicy, d)
			end
		end
	end
	local function click(name: string, fn: () -> ())
		local btn = b:FindFirstChild(name, true)
		if btn and btn:IsA("GuiButton") then
			btn.Activated:Connect(fn)
		end
	end
	click("BtnSeeInside", function()
		open(not (contents and contents.Visible))
	end)
	click("BtnOpen", function()
		pendingCrate = os.clock()
		Net.event("RequestWeaponCrate"):FireServer(1, "weapon")
	end)
	click("BtnOpenPoor", function()
		local def = crateDef()
		FeaturedShopUI.promptGems(math.max(1, def.gems - ((lastProfile and lastProfile.gems) or 0)))
	end)
	click("BtnAllCrates", function()
		local C = uic()
		if C and C.openShopTab then
			C.openShopTab("weapons")
		end
	end)
	fillBanner(b, lastProfile and lastProfile.gems)
end

local function startTimer(header: Instance)
	if timerOn then
		return
	end
	timerOn = true
	task.spawn(function()
		while header.Parent do
			local now = HalloweenShop.now()
			local left = 86400 - (now % 86400)
			setText(header, "DailyTimer", ("NEW IN %02d:%02d:%02d"):format(left // 3600, (left % 3600) // 60, left % 60))
			task.wait(1)
		end
		timerOn = false
	end)
end

-- open / close a weapon card's stage by hand (the hover does the same; checks and screenshots)
function FeaturedShopUI.preview(card: Instance, on: boolean)
	local c = controls[card]
	if c then
		if on then
			c.open()
		else
			c.close()
		end
	end
end

-- ===== the hook (Controllers.HalloweenShopUI.slots): build / refresh the page, return { slot = FEATURED key }
function FeaturedShopUI.slots(sc: Instance): { [string]: string }?
	local pf = sc:FindFirstChild("PageFeatured", true)
	local tf = templates()
	if not pf or not tf then
		return nil -- no templates: the old Featured stays
	end
	for _, nm in OLD do
		show(pf:FindFirstChild(nm), false)
	end
	local day = FeaturedShopUI.utcDay()
	if pf:GetAttribute("FeatDay") ~= day or not pf:FindFirstChild("Feat1") then
		for _, nm in OURS do
			local o = pf:FindFirstChild(nm)
			if o then
				o:Destroy()
			end
		end
		pf:SetAttribute("FeatDay", day)
		local h = (tf:FindFirstChild("FeatHeader") :: GuiObject):Clone()
		h.Position = HEADER_POS
		h.Visible = true
		h.Parent = pf
		for i, id in FeaturedShopUI.BIG do
			buildCard(pf, tf, id, "Feat" .. i, BIG_POS[i], true, i)
		end
		for i, id in FeaturedShopUI.daily(day) do
			buildCard(pf, tf, id, "Daily" .. i, DAILY_POS[i], false)
		end
		buildBanner(pf, tf)
	end
	local header = pf:FindFirstChild("FeatHeader")
	if header then
		startTimer(header)
	end
	local banner = pf:FindFirstChild("FeatCrate")
	if banner then
		fillBanner(banner, gemsNow(sc))
	end
	local map, recs = {}, {}
	local ids = table.clone(FeaturedShopUI.BIG)
	local slots = { "Feat1", "Feat2" }
	for i, id in FeaturedShopUI.daily(day) do
		table.insert(ids, id)
		table.insert(slots, "Daily" .. i)
	end
	for i, slot in slots do
		local id = ids[i]
		local root = pf:FindFirstChild(slot)
		local it = EconomyConfig.item(id)
		if root and it then
			EconomyConfig.FEATURED["feat_" .. id] = id
			map[slot] = "feat_" .. id
			recs[slot] = { card = root:FindFirstChild("Card"), item = it }
		end
	end
	afterFill(recs, gemsNow(sc))
	return map
end

-- the newest profile (Gems for the banner and the "need more" line)
Net.event("ProfileState").OnClientEvent:Connect(function(view)
	if type(view) == "table" then
		lastProfile = view
	end
end)

-- a crate opened from the banner: show what came out (the Weapons tab shows it on its own stage)
Net.event("WeaponCrateResult").OnClientEvent:Connect(function(r)
	if type(r) ~= "table" or not r.ok or os.clock() - pendingCrate > 15 then
		return
	end
	pendingCrate = 0
	local it = EconomyConfig.item(r.itemId)
	local C = uic()
	if not it or not C or not C.showReward then
		return
	end
	pcall(C.showReward, {
		icon = "weapon_crate",
		title = if r.dupe then "DUPLICATE" else "NEW!",
		name = it.name,
		kind = string.upper(it.rarity or ""),
		sub = if r.dupe then ("+%d Weapon Shards"):format(r.shards or 0) else "Equipped. Yours to keep.",
		skin = it.skin,
	})
end)

return FeaturedShopUI
