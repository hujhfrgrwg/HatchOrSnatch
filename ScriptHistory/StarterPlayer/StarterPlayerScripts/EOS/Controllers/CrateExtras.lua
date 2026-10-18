--!nonstrict
-- CrateExtras (HOS-INV-001, Hunter 18 Oct "Go" on: open x10, Weapon Crate for Robux, an Emote Crate guarantee).
--   ClientMain: task.spawn(require(Controllers.CrateExtras).init)
-- * OPEN x10 buttons: the Shop's Weapon Crate card (under the Gems / Robux pair) and Emote Crate card (left half of
--   the SEE ALL row). 10 openings for 2,250 Gems with one Epic or better guaranteed; a confirm first, the Gems offer
--   when short. The server answers with the best pull (the usual reel / stage plays it) plus `multi`, every result.
-- * 10 PULLS screen: after the reel, all ten cards pop in one by one, rarest glowing, NEW or the Gems refunded.
-- * Emote Crate guarantee lines (EmoteConfig.PITY, profile.emotePity): "Epic+ within N  ·  Legendary within M" on the
--   Shop card and the Emotes panel's crate detail.
-- The Weapon Crate's 149 Robux button lives in WeaponShopUI (its own button); the grant in WeaponCrateService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local EmoteConfig = require(Shared:WaitForChild("EmoteConfig"))
local Net = require(Shared:WaitForChild("Net"))

local UIC = require(script.Parent.UIController)

local CrateExtras = {}

local player = Players.LocalPlayer
local profile: any = nil
local RARITY = {
	common = { "COMMON", Color3.fromRGB(190, 198, 206) },
	rare = { "RARE", Color3.fromRGB(47, 168, 255) },
	epic = { "EPIC", Color3.fromRGB(180, 77, 255) },
	legendary = { "LEGENDARY", Color3.fromRGB(255, 194, 28) },
}
local RANK = { common = 1, rare = 2, epic = 3, legendary = 4 }
local GOLD = Color3.fromRGB(255, 210, 58)

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			return s
		end
	end
end

local function setLabels(scope: Instance?, text: string, only: string?)
	if not scope then
		return
	end
	for _, d in scope:GetDescendants() do
		if d:IsA("TextLabel") and (not only or d.Name == only or d.Name == only .. "Shadow") then
			d.Text = text
		end
	end
end

local function icons(): any
	local gui = player.PlayerGui:FindFirstChild("EOSUI")
	local m = gui and gui:FindFirstChild("AssetIds")
	local ok, a = pcall(function()
		return m and require(m)
	end)
	return if ok and a then a.icons or {} else {}
end

-- ===== OPEN x10

local function confirmMulti(kind: string)
	local C = if kind == "weapon" then EconomyConfig.KNIFE_CRATE.multi else EmoteConfig.MULTI
	local gems = (profile and profile.gems) or 0
	if gems < C.gems then
		if UIC.offerGems and UIC.offerGems(C.gems - gems, "10 crates") then
			return
		end
		UIC.toast(("Not enough Gems: 10 crates are %s"):format(fmt(C.gems)), "warn")
		return
	end
	UIC.confirm({
		title = "Open 10 crates?",
		body1 = ("10 %s for %s Gems."):format(if kind == "weapon" then "Weapon Crates" else "Emote Crates", fmt(C.gems)),
		body2 = "At least one Epic or better, guaranteed.",
		yes = "OPEN 10",
		no = "CANCEL",
	}, function()
		if kind == "weapon" then
			Net.event("RequestWeaponCrate"):FireServer(C.count)
		else
			Net.event("RequestOpenCrate"):FireServer(C.count)
		end
	end)
end

-- a slice-friendly copy of a button: the exported art is a 2x raster, so it stretches by its edges, not its middle
local function sliceArt(b: Instance)
	for _, d in b:GetDescendants() do
		if d:IsA("ImageLabel") and d.Name == "Art" then
			local w, h = d.Size.X.Offset, d.Size.Y.Offset
			d.ScaleType = Enum.ScaleType.Slice
			d.SliceCenter = Rect.new(24, 24, math.max(25, w * 2 - 24), math.max(25, h * 2 - 24))
			d.SliceScale = 0.5
		end
	end
end

-- reshape a cloned button: new size, its art follows, the label row re-centred
local function resize(b: GuiObject, w: number, h: number)
	local ow, oh = b.Size.X.Offset, b.Size.Y.Offset
	sliceArt(b)
	b.Size = UDim2.fromOffset(w, h)
	for _, d in b:GetChildren() do
		if d:IsA("GuiObject") then
			if d.Name == "Art" then
				d.Size = UDim2.fromOffset(w, h + (d.Size.Y.Offset - oh))
			else
				d.Position = d.Position + UDim2.fromOffset((w - ow) / 2, (h - oh) / 2)
			end
		end
	end
end

local function makeMulti(src: GuiButton, name: string, x: number, y: number, w: number, h: number, kind: string): GuiButton
	local b = src:Clone() :: GuiButton
	b.Name = name
	for _, a in { "Opens", "OpensVia", "JuiceRest", "Wired" } do
		b:SetAttribute(a, nil)
	end
	b.AnchorPoint = Vector2.zero
	b.Position = UDim2.fromOffset(x, y)
	resize(b, w, h)
	local C = if kind == "weapon" then EconomyConfig.KNIFE_CRATE.multi else EmoteConfig.MULTI
	-- one centred label: "OPEN 10  ·  2,250 GEMS" (the currency icon goes; the words say it)
	for _, d in b:GetDescendants() do
		if d:IsA("ImageLabel") and d.Name ~= "Art" then
			d.Visible = false
		elseif d:IsA("TextLabel") then
			local shadow = d.Name:find("Shadow$") ~= nil
			d.Text = ("OPEN 10  ·  %s GEMS"):format(fmt(C.gems))
			d.TextScaled = false
			d.TextWrapped = false
			d.AnchorPoint = Vector2.new(0.5, 0.5)
			d.Size = UDim2.fromOffset(w - 24, d.Size.Y.Offset)
			d.Position = UDim2.fromOffset(w / 2, h / 2 + (if shadow then 2 else 0))
			d.TextXAlignment = Enum.TextXAlignment.Center
			d.TextSize = math.min(d.TextSize, math.floor(h * 0.5))
		end
	end
	b.Parent = src.Parent
	b.Visible = true
	UIC.juicy(b, function()
		confirmMulti(kind)
	end)
	return b
end

local function mountWeaponMulti(shop: Instance)
	local page = shop:FindFirstChild("PageWeapons", true)
	local card = page and page:FindFirstChild("CrateCard")
	local gems = card and card:FindFirstChild("BtnCrateGems")
	if not (card and gems and gems:IsA("GuiButton")) or card:FindFirstChild("BtnCrateMulti") then
		return
	end
	-- the pair moves up a little; x10 goes full width under it; the two footer lines become one
	local y0 = 524
	for _, n in { "BtnCrateGems", "BtnCrateRobux" } do
		local b = card:FindFirstChild(n)
		if b and b:IsA("GuiObject") then
			b.Position = UDim2.new(b.Position.X.Scale, b.Position.X.Offset, 0, y0 + b.Size.Y.Offset * b.AnchorPoint.Y)
			if b:GetAttribute("JuiceRest") ~= nil then
				b:SetAttribute("JuiceRest", b.Position)
			end
		end
	end
	makeMulti(gems, "BtnCrateMulti", 27, y0 + 80, 352, 52, "weapon")
	-- the two footer lines make room; "looks only" moves up into the line under the title
	for _, d in card:GetChildren() do
		if d:IsA("TextLabel") and (d.Name:find("^T_ADuplicateRefunds") or d.Name:find("^T_EveryWeaponTags")) then
			d.Visible = false
		elseif d:IsA("TextLabel") and d.Name:find("^CrateSub") then
			d.Text = ("One of %d weapon skins  ·  looks only"):format(#EconomyConfig.KNIFE_SKINS)
		end
	end
end

local function mountEmoteMulti(shop: Instance)
	local page = shop:FindFirstChild("PageEmotes", true)
	local card = page and page:FindFirstChild("CrateCard")
	local gems = card and card:FindFirstChild("BtnCrateGems")
	local see = card and card:FindFirstChild("BtnSeeEmotes")
	if not (card and gems and gems:IsA("GuiButton") and see and see:IsA("GuiObject")) or card:FindFirstChild("BtnCrateMulti") then
		return
	end
	-- SEE ALL keeps the right half of its row; x10 takes the left
	local half = 340
	local sx = see.Position.X.Offset - see.AnchorPoint.X * see.Size.X.Offset
	local sy = see.Position.Y.Offset - see.AnchorPoint.Y * see.Size.Y.Offset
	makeMulti(gems, "BtnCrateMulti", sx, sy, half, see.Size.Y.Offset, "emote")
	resize(see, half, see.Size.Y.Offset)
	local rest = UDim2.fromOffset(sx + half + 16 + see.AnchorPoint.X * half, see.Position.Y.Offset)
	see.Position = rest
	if see:GetAttribute("JuiceRest") ~= nil then
		see:SetAttribute("JuiceRest", rest)
	end
end

-- ===== the Emote Crate guarantee lines

local function pityText(): string
	local P = profile and profile.emotePity or {}
	local e = math.max(1, EmoteConfig.PITY.epic - (tonumber(P.epic) or 0))
	local l = math.max(1, EmoteConfig.PITY.legendary - (tonumber(P.legendary) or 0))
	return ("Epic+ within %d  ·  Legendary within %d"):format(e, l)
end

local function refreshPity()
	local root = player.PlayerGui:FindFirstChild("EOSUI") and player.PlayerGui.EOSUI:FindFirstChild("Root")
	if not root then
		return
	end
	local shopCard = root:FindFirstChild("Shop") and root.Shop:FindFirstChild("PageEmotes", true)
	shopCard = shopCard and shopCard:FindFirstChild("CrateCard")
	for _, d in (shopCard and shopCard:GetChildren()) or {} do
		if d:IsA("TextLabel") and d.Name:find("^T_ADuplicateRefundsGemsEmo") then
			d.Text = pityText() .. "  ·  duplicates refund Gems"
		end
	end
	local detail = root:FindFirstChild("Emotes") and root.Emotes:FindFirstChild("Detail", true)
	for _, d in (detail and detail:GetChildren()) or {} do
		if d:IsA("TextLabel") and d.Name:find("^T_ADuplicateRefundsGems") then
			d.Text = pityText()
			d.TextScaled = false
			d.TextWrapped = false
			d.Size = UDim2.fromOffset(300, d.Size.Y.Offset)
			d.Position = UDim2.fromOffset(20, d.Position.Y.Offset)
			d.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
end

-- ===== the 10 PULLS screen

local screen: ScreenGui? = nil

local function tilePicture(tile: Frame, kind: string, r: any, color: Color3)
	if kind == "weapon" then
		local item = EconomyConfig.item(r.itemId)
		local lib = ReplicatedStorage:FindFirstChild("EOS_KnifeSkinPreviews")
		local tpl = item and lib and lib:FindFirstChild((item :: any).skin)
		if tpl and tpl:IsA("BasePart") then
			local vf = Instance.new("ViewportFrame")
			vf.BackgroundTransparency = 1
			vf.Size = UDim2.new(1, -16, 0.52, 0)
			vf.Position = UDim2.fromOffset(8, 34)
			vf.Ambient = Color3.fromRGB(205, 200, 220)
			vf.LightDirection = Vector3.new(-0.6, -1, -0.7)
			vf.ZIndex = tile.ZIndex + 1
			vf.Parent = tile
			local skin = tpl:Clone()
			for _, d in skin:GetDescendants() do
				if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Sound") or d:IsA("BaseScript") or d:IsA("Motor6D") then
					d:Destroy()
				end
			end
			skin.Anchored = true
			skin.CFrame = CFrame.Angles(0, 0, math.rad(-35))
			for _, k in skin:GetChildren() do
				if k:IsA("BasePart") then
					local w = k:FindFirstChild("SkinWeld") :: Weld?
					k.Anchored = true
					if w then
						k.CFrame = skin.CFrame * w.C0
					end
				end
			end
			skin.Parent = vf
			local cf, size = skin.CFrame, skin.Size
			local okB, bcf, bsz = pcall(function()
				local m = Instance.new("Model")
				skin.Parent = m
				local a, b = m:GetBoundingBox()
				skin.Parent = vf
				m:Destroy()
				return a, b
			end)
			if okB then
				cf, size = bcf, bsz
			end
			local cam = Instance.new("Camera")
			cam.FieldOfView = 26
			local need = math.max(size.X, size.Y) * 0.92
			cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, 0, need / 2 / math.tan(math.rad(13)) + size.Z), cf.Position)
			cam.Parent = vf
			vf.CurrentCamera = cam
			return
		end
	end
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.new(0.5, 0, 0.38, 0)
	img.Size = UDim2.fromScale(0.62, 0.62)
	img.SizeConstraint = Enum.SizeConstraint.RelativeXX
	img.Image = icons()[if kind == "weapon" then "catcher" else "emote"] or ""
	img.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
	img.ZIndex = tile.ZIndex + 1
	img.Parent = tile
end

local function text(parent: Instance, s: string, size: number, color: Color3, pos: UDim2, w: UDim, z: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = pos
	l.Size = UDim2.new(w, UDim.new(0, size + 6))
	l.Font = Enum.Font.FredokaOne
	l.Text = s
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = false
	l.TextScaled = false
	l.ZIndex = z
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Parent = l
	l.Parent = parent
	return l
end

local function showPulls(kind: string, results: { any })
	if screen then
		screen:Destroy()
	end
	local g = Instance.new("ScreenGui")
	g.Name = "CratePullsUI"
	g.DisplayOrder = 9
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen = g
	local dim = Instance.new("TextButton")
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.BackgroundColor3 = Color3.fromRGB(8, 6, 16)
	dim.BackgroundTransparency = 1
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = g
	TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 0.35 }):Play()
	-- design 1920x1080, scaled to the screen like every EOSUI panel
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromOffset(1920, 1080)
	stage.Parent = g
	local sc = Instance.new("UIScale")
	sc.Parent = stage
	local function fit()
		local v = workspace.CurrentCamera.ViewportSize
		sc.Scale = math.min(v.X / 1920, v.Y / 1080) * (if v.Y < 500 then 1.25 else 1)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(1500, 760)
	panel.BackgroundColor3 = Color3.fromRGB(44, 30, 74)
	panel.Parent = stage
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 18)
	pc.Parent = panel
	local ps = Instance.new("UIStroke")
	ps.Color = GOLD
	ps.Thickness = 4
	ps.Parent = panel
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 140, 170)) -- a soft top-lit shade of the panel colour
	grad.Parent = panel
	local new, refund = 0, 0
	for _, r in results do
		if r.dupe then
			refund += r.refund or 0
		else
			new += 1
		end
	end
	text(panel, "10 PULLS!", 72, GOLD, UDim2.new(0.5, 0, 0, 22), UDim.new(1, 0), 3)
	text(panel, ("%s  ·  %d new  ·  +%s Gems from duplicates"):format(if kind == "weapon" then "Weapon Crate" else "Emote Crate", new, fmt(refund)),
		26, Color3.fromRGB(225, 225, 235), UDim2.new(0.5, 0, 0, 108), UDim.new(1, 0), 3)
	-- rarest first
	local list = table.clone(results)
	local function rarityOf(r: any): string
		if kind == "weapon" then
			local it = EconomyConfig.item(r.itemId)
			return it and (it :: any).rarity or "common"
		end
		local e = EmoteConfig.get(r.emote)
		return e and e.rarity or "common"
	end
	local function nameOf(r: any): string
		if kind == "weapon" then
			local it = EconomyConfig.item(r.itemId)
			return it and it.name or "?"
		end
		local e = EmoteConfig.get(r.emote)
		return e and e.name or "?"
	end
	table.sort(list, function(a, b)
		return (RANK[rarityOf(a)] or 0) > (RANK[rarityOf(b)] or 0)
	end)
	local TW, TH, GX, GY = 262, 228, 20, 20
	local x0 = (1500 - (5 * TW + 4 * GX)) / 2
	for i, r in list do
		local rar = rarityOf(r)
		local R = RARITY[rar] or RARITY.common
		local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
		local tile = Instance.new("Frame")
		tile.AnchorPoint = Vector2.new(0.5, 0.5)
		tile.Position = UDim2.fromOffset(x0 + col * (TW + GX) + TW / 2, 160 + row * (TH + GY) + TH / 2)
		tile.Size = UDim2.fromOffset(TW * 0.2, TH * 0.2)
		tile.BackgroundColor3 = R[2]:Lerp(Color3.fromRGB(14, 12, 22), 0.72)
		tile.ZIndex = 3
		tile.ClipsDescendants = true
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(0, 14)
		tc.Parent = tile
		local ts = Instance.new("UIStroke")
		ts.Color = R[2]
		ts.Thickness = if rar == "legendary" then 5 else 3
		ts.Parent = tile
		tile.Parent = panel
		local tag = text(tile, R[1], 22, R[2], UDim2.new(0.5, 0, 0, 6), UDim.new(1, 0), 5)
		tag.TextStrokeTransparency = 1
		tilePicture(tile, kind, r, R[2])
		local nm = text(tile, nameOf(r), 28, Color3.new(1, 1, 1), UDim2.new(0.5, 0, 1, -72), UDim.new(1, -12), 5)
		task.defer(function()
			if nm.TextBounds.X > nm.AbsoluteSize.X and nm.TextBounds.X > 0 then
				nm.TextSize = math.max(12, math.floor(nm.TextSize * nm.AbsoluteSize.X / nm.TextBounds.X))
			end
		end)
		text(tile, if r.dupe then ("+%d GEMS"):format(r.refund or 0) else "NEW!", 26,
			if r.dupe then Color3.fromRGB(160, 240, 110) else GOLD, UDim2.new(0.5, 0, 1, -38), UDim.new(1, 0), 5)
		task.delay(0.15 + (i - 1) * 0.12, function()
			TweenService:Create(tile, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(TW, TH) }):Play()
		end)
		if rar == "legendary" or rar == "epic" then
			task.spawn(function()
				task.wait(0.4 + (i - 1) * 0.12)
				while tile.Parent do
					TweenService:Create(ts, TweenInfo.new(0.6), { Transparency = 0.5 }):Play()
					task.wait(0.6)
					TweenService:Create(ts, TweenInfo.new(0.6), { Transparency = 0 }):Play()
					task.wait(0.6)
				end
			end)
		end
	end
	-- NICE! closes (or a click on the dim)
	local ok = Instance.new("TextButton")
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.new(0.5, 0, 1, -26)
	ok.Size = UDim2.fromOffset(320, 72)
	ok.BackgroundColor3 = Color3.fromRGB(110, 210, 40)
	ok.Font = Enum.Font.FredokaOne
	ok.Text = "NICE!"
	ok.TextSize = 36
	ok.TextColor3 = Color3.new(1, 1, 1)
	ok.ZIndex = 4
	local oc = Instance.new("UICorner")
	oc.CornerRadius = UDim.new(0, 14)
	oc.Parent = ok
	local os_ = Instance.new("UIStroke")
	os_.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	os_.Color = Color3.fromRGB(10, 8, 18)
	os_.Thickness = 3
	os_.Parent = ok
	local ots = Instance.new("UIStroke")
	ots.Thickness = 2.5
	ots.Parent = ok
	ok.Parent = panel
	local function close()
		if screen == g then
			screen = nil
		end
		g:Destroy()
	end
	ok.Activated:Connect(close)
	dim.Activated:Connect(close)
	pcall(function()
		UIC.juicy(ok)
	end)
	g.Parent = player.PlayerGui
	pcall(function()
		require(script.Parent.Sound).play("reveal")
	end)
end

local function afterReel(kind: string, results: { any })
	task.spawn(function()
		if kind == "emote" then
			-- the Emote Crate reel (EmoteCrateUI) plays the best pull first; the ten cards follow when it's done
			local gui = player.PlayerGui:FindFirstChild("EmoteCrateUI")
			local mod = gui and gui:FindFirstChild("EmoteCrateSpin")
			local ok, spin = pcall(function()
				return mod and require(mod)
			end)
			-- wait for the reel to land on the best pull (its Reveal shows), give it a beat, then the ten cards replace it
			local reveal = gui and gui:FindFirstChild("Reveal", true)
			local t0 = os.clock()
			task.wait(1)
			local frame = reveal and reveal.Parent
			while os.clock() - t0 < 12 and not (reveal and reveal:IsA("GuiObject") and reveal.Visible and frame and frame:IsA("GuiObject") and frame.Visible) do
				task.wait(0.1)
			end
			task.wait(1.4)
			if ok and spin and spin.isBusy and spin.isBusy() and spin.close then
				pcall(spin.close)
			end
		else
			task.wait(2.6) -- the Weapons tab stage shows the best pull first
		end
		showPulls(kind, results)
	end)
end

function CrateExtras.init()
	Net.event("ProfileState").OnClientEvent:Connect(function(view)
		if type(view) == "table" then
			profile = view
			refreshPity()
		end
	end)
	Net.event("CrateResult").OnClientEvent:Connect(function(t)
		if type(t) == "table" and t.ok and type(t.multi) == "table" then
			afterReel("emote", t.multi)
		end
	end)
	Net.event("WeaponCrateResult").OnClientEvent:Connect(function(t)
		if type(t) == "table" and t.ok and type(t.multi) == "table" then
			afterReel("weapon", t.multi)
		end
	end)
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("EOSUI", 30)
	local root = gui and gui:WaitForChild("Root", 10)
	local shop = root and root:WaitForChild("Shop", 10)
	if not shop then
		return
	end
	local function mountAll()
		pcall(mountWeaponMulti, shop)
		pcall(mountEmoteMulti, shop)
		refreshPity()
	end
	if shop:IsA("GuiObject") then
		shop:GetPropertyChangedSignal("Visible"):Connect(function()
			if shop.Visible then
				task.delay(0.1, mountAll)
			end
		end)
	end
	local emotes = root:FindFirstChild("Emotes")
	if emotes and emotes:IsA("GuiObject") then
		emotes:GetPropertyChangedSignal("Visible"):Connect(function()
			if emotes.Visible then
				task.delay(0.1, refreshPity)
			end
		end)
	end
	task.delay(2, mountAll)
	Net.event("RequestProfile"):FireServer()
end

return CrateExtras
