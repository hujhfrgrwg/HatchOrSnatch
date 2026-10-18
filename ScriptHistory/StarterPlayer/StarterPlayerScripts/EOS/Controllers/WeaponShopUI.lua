--!strict
-- WeaponShopUI (client): the Shop's Weapons tab, HOS-WEP-001 (Hunter 17 Oct: "I hope you added a weapon tab to the
-- shop"; 21:36 "the previews of the weapons need to be renders of them that look clean and focused in the panels.
-- Also, when you hover on them it should show a preview of your player with it animated").
--
--   WeaponShopUI.mount(shop)                     UIController, once, before it wires the Shop tabs (one line)
--   WeaponShopUI.refresh(sc, profile, active)    UIController.refreshShop, every refresh (one line)
--
-- * Look: roblox-ui-maker templates (ReplicatedStorage.WeaponUITemplates, from UI/build.py s_wpn_templates via
--   ui_weapons/rbx.json). mount() puts TabWeapons between Cosmetics and Emotes (the six tabs re-spaced to 244 px, as
--   the approved page) and PageWeapons where the other pages sit. The exported sample cards are style donors, one per
--   rarity (frame art + rarity tag); every skin in EconomyConfig.KNIFE_SKINS gets a copy of its rarity's donor.
-- * Each card's Preview box holds a ViewportFrame with the skin itself (ReplicatedStorage.EOS_KnifeSkinPreviews,
--   published by WeaponCrateService), tip up and leaning 35 degrees, framed to fill the box. Built once per skin.
-- * Hover a card (tap its picture on a touch screen): the crate card swaps for PreviewCard, your own character in a
--   WorldModel holding that skin (both hands for twins), idle, then its swing (SwingJab / SwingDual), on a loop.
-- * Daily store v2 (Hunter 17 Oct: "Most of them should only be acquirable from the crate ... You shouldnt be able to
--   just buy whatever you want"; layout approved 23:07 "Implement. All looks good"): TODAY'S WEAPONS = the 4 skins
--   EconomyConfig.knifeDaily(day) puts on sale (the only ones with a price), new at 00:00 UTC with a countdown. The
--   COLLECTION lists every skin: owned = EQUIP / EQUIPPED, on sale today = IN TODAY'S STORE, never sold = locked
--   CRATE ONLY, sold some days = SHOWS IN STORE. The crate card shows the guarantee (profile.weaponPity).
-- * Buttons: Gems price (RequestBuy), short -> the Gems tab, EQUIP / UNEQUIP (RequestSetCosmetic "knifeSkin").
-- * Weapon Crate: RequestWeaponCrate; the result shows on the preview stage (NEW or the duplicate refund).
-- Looks only: every skin tags with the same reach and timing (the hit is decided on the click, from the body).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local AnimConfig = require(Shared:WaitForChild("AnimConfig"))
local GameConfigShop = require(Shared:WaitForChild("GameConfig")) -- HOS-INV-001: SHOP_PURCHASES gates the Robux crate
local Net = require(Shared:WaitForChild("Net"))

local WeaponShopUI = {}

local TAB_ORDER = { "TabFeatured", "TabCosmetics", "TabWeapons", "TabEmotes", "TabPasses", "TabGems" }
local TAB_W, TAB_STEP, TAB_X0, OLD_TAB_W = 244, 254, 29, 290
local PAGE_POS = UDim2.fromOffset(29, 217)
local CARD_W, CARD_H, GAP_X, GAP_Y = 132, 214, 7, 8 -- collection cards
local PER_ROW = 8
local DAILY_W, DAILY_GAP = 262, 20
local LEAN = math.rad(-35)
local DONOR = { legendary = "Coll_spirit_blast", epic = "Coll_rb_darkheart", rare = "Coll_rb_firebrand", common = "Coll_rb_orc_blade" }
local DAILY_DONOR = { epic = "Card_rb_illumina", rare = "Card_shadow_katana", common = "Card_rb_orc_blade" }
local RARITY_RANK = { legendary = 1, epic = 2, rare = 3, common = 4 }
local DWELL = 0.08 -- hover this long before the stage opens (sweeping across the grid opens nothing)
local SWING_EVERY = 2.4 -- seconds between swings on the stage

type CardRec = { frame: Frame, item: any, skin: string, twin: boolean, built: boolean, daily: boolean? }

local mounted = false
local page: Frame? = nil
local crateCard: GuiObject? = nil
local previewCard: GuiObject? = nil
local scroll: ScrollingFrame? = nil
local cards: { CardRec } = {}
local dailyRecs: { CardRec } = {}
local dailyRow: Frame? = nil
local dailyDonors: { [string]: Frame } = {}
local dailyDay = -1
local subOk: ColorSequence? = nil -- the daily card's line under the name: plain / short of Gems (the sample
local subPoor: ColorSequence? = nil -- cards' text gradients)
local filter = "all"
local lastProfile: any = nil
local stageToken = 0
local stageConn: RBXScriptConnection? = nil
local crateHoldUntil = 0

local function templates(): Instance?
	return ReplicatedStorage:FindFirstChild("WeaponUITemplates") or script:FindFirstChild("Templates")
end

local function previews(): Instance?
	return ReplicatedStorage:FindFirstChild("EOS_KnifeSkinPreviews")
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

local function setDual(d: Instance?, on: boolean)
	if not d then
		return
	end
	show(d:FindFirstChild("On"), on)
	show(d:FindFirstChild("Off"), not on)
end

local function onClick(b: Instance?, fn: () -> ())
	if not b then
		return
	end
	if b:IsA("GuiButton") then
		b.Activated:Connect(fn)
	end
	for _, c in b:GetChildren() do
		if c:IsA("GuiButton") and (c.Name == "On" or c.Name == "Off") then
			c.Activated:Connect(fn)
		end
	end
end

-- ===== 3D: a skin clone placed and framed

-- the skin's parts placed (no physics in a ViewportFrame: welded parts are put where their welds say)
local function placeSkin(skin: BasePart, cf: CFrame)
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

-- skin frame in world: tip up and leaning right, the flat of the blade toward the camera (+Z)
local function cardPose(skin: BasePart): CFrame
	local tip = skin:GetAttribute("SkinTip") :: Vector3?
	local thin = skin:GetAttribute("SkinThin") :: Vector3?
	local ctr = (skin:GetAttribute("SkinCenter") :: Vector3?) or Vector3.zero
	if not tip or not thin then
		return CFrame.Angles(0, 0, LEAN)
	end
	local right = thin:Cross(tip).Unit
	local F = CFrame.fromMatrix(ctr, right, tip, right:Cross(tip)) -- skin space: Y = tip, Z = thin
	return CFrame.Angles(0, 0, LEAN) * F:Inverse()
end

local function bounds(root: Instance): (Vector3, Vector3)
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	local list = root:GetDescendants()
	if root:IsA("BasePart") then
		table.insert(list, root)
	end
	for _, p in list do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local h = p.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local w = p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
						mn = mn:Min(w)
						mx = mx:Max(w)
					end
				end
			end
		end
	end
	if mn.X == math.huge then
		return Vector3.new(-0.5, -0.5, -0.5), Vector3.new(0.5, 0.5, 0.5)
	end
	return mn, mx
end

local function strip(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Sound") or d:IsA("BaseScript") then
			d:Destroy()
		end
	end
end

local function newViewport(parent: GuiObject, name: string): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = name
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.fromScale(1, 1)
	vf.Ambient = Color3.fromRGB(205, 200, 220)
	vf.LightColor = Color3.fromRGB(255, 250, 240)
	vf.LightDirection = Vector3.new(-0.6, -1, -0.7)
	vf.ZIndex = parent.ZIndex + 1
	vf.Parent = parent
	return vf
end

-- one clean render of the skin in a card's Preview box
local function buildCardRender(rec: CardRec)
	if rec.built then
		return
	end
	local box = rec.frame:FindFirstChild("Preview", true) :: GuiObject?
	local lib = previews()
	local tpl = lib and lib:FindFirstChild(rec.skin)
	if not box or not tpl or not tpl:IsA("BasePart") then
		return
	end
	rec.built = true
	local vf = newViewport(box, "Render")
	local skin = tpl:Clone() :: BasePart
	strip(skin)
	local m = skin:FindFirstChildOfClass("Motor6D")
	if m then
		m:Destroy()
	end
	placeSkin(skin, cardPose(skin))
	skin.Parent = vf
	local mn, mx = bounds(skin)
	local c, s = (mn + mx) / 2, mx - mn
	local cam = Instance.new("Camera")
	cam.FieldOfView = 24
	local aspect = math.max(box.AbsoluteSize.X, 1) / math.max(box.AbsoluteSize.Y, 1)
	if aspect < 0.2 or aspect > 5 then
		aspect = 238 / 150
	end
	local halfV = math.tan(math.rad(cam.FieldOfView / 2))
	local need = math.max(s.Y, s.X / aspect) * (if tpl:GetAttribute("NoHolster") then 3.2 else 1.12) -- air round it; an orb's glow needs room
	local dist = need / 2 / halfV + s.Z / 2
	cam.CFrame = CFrame.lookAt(c + Vector3.new(0, 0, dist), c)
	cam.Parent = vf
	vf.CurrentCamera = cam
	if tpl:GetAttribute("NoHolster") then
		local n = 0
		for _, e in tpl:GetDescendants() do
			if e:IsA("ParticleEmitter") and e.LightEmission > 0 and e.Texture ~= "" and not e.FlipbookLayout.Name:find("Grid") and n < 4 then
				n += 1
				local img = Instance.new("ImageLabel")
				img.Name = "Glow" .. n
				img.BackgroundTransparency = 1
				img.Image = e.Texture
				img.ImageColor3 = e.Color.Keypoints[1].Value
				img.AnchorPoint = Vector2.new(0.5, 0.5)
				img.Position = UDim2.fromScale(0.5, 0.5)
				local k = math.clamp(e.Size.Keypoints[math.min(2, #e.Size.Keypoints)].Value / 1.0, 0.4, 1.2)
				img.Size = UDim2.fromScale(0.62 * k * 150 / 238, 0.62 * k)
				img.Rotation = n * 40
				img.ZIndex = vf.ZIndex + (if e.ZOffset < 0 then -1 else 1)
				img.Parent = box
				local spin = Instance.new("NumberValue")
				spin.Name = "Spin"
				spin.Value = if n % 2 == 0 then -60 else 90
				spin.Parent = img
			end
		end
	end
end

-- ===== the hover stage: your character holding the skin, animated

local function mirror(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

local function arm(char: Model, skinTpl: BasePart, armName: string, motorName: string, partName: string, mirrored: boolean)
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
	if mirrored then
		m.C0 = mirror(m.C0)
		m.C1 = mirror(m.C1)
	end
	m.Part0 = a
	m.Part1 = w
	w.CFrame = a.CFrame * m.C0 * m.C1:Inverse()
	m.Parent = a
	-- the skin's own welded parts: Motor6Ds too, so they follow the swing in the WorldModel
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

local function closeStage()
	stageToken += 1
	if stageConn then
		stageConn:Disconnect()
		stageConn = nil
	end
	local pc = previewCard
	if pc then
		local st = pc:FindFirstChild("Stage")
		local vf = st and st:FindFirstChild("Stage3D")
		if vf then
			vf:Destroy()
		end
		pc.Visible = false
	end
	show(crateCard, true)
end

local function rarityLabel(r: string?): string
	return string.upper(r or "")
end

local function openStage(item: any, phaseText: string?, hint: string?)
	local pc = previewCard
	local lib = previews()
	local tpl = lib and lib:FindFirstChild(item.skin)
	local me = Players.LocalPlayer.Character
	if not pc or not tpl or not tpl:IsA("BasePart") then
		return
	end
	closeStage()
	stageToken += 1
	local token = stageToken
	show(crateCard, false)
	pc.Visible = true
	setText(pc, "Title", string.upper(item.name))
	setText(pc, "Hint", hint or "Your Catcher with it, same reach and timing")
	setText(pc, "Phase", phaseText or "IDLE  ·  SWING")
	local rt = pc:FindFirstChild("RarityTag")
	if rt then
		setText(rt, "Label", rarityLabel(item.rarity))
		for _, d in rt:GetDescendants() do
			if d:IsA("TextLabel") then
				d.Text = rarityLabel(item.rarity)
			end
		end
	end
	local stage = pc:FindFirstChild("Stage") :: GuiObject?
	if not stage or not me then
		return
	end
	local vf = newViewport(stage, "Stage3D")
	local wm = Instance.new("WorldModel")
	wm.Parent = vf
	local was = me.Archivable
	me.Archivable = true
	local char = me:Clone()
	me.Archivable = was
	for _, d in char:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ForceField") or d:IsA("BillboardGui") or d:IsA("Highlight") then
			d:Destroy()
		elseif d:IsA("BasePart") and (d:GetAttribute("EOS_Knife") or d:GetAttribute("EOS_Holstered") or d:GetAttribute("EOS_Egg")) then
			d:Destroy()
		end
	end
	for _, c in char:GetChildren() do
		if c:IsA("Model") and c:GetAttribute("EOS_Egg") then
			c:Destroy()
		end
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		vf:Destroy()
		return
	end
	-- old arm joints for the knife
	for _, d in char:GetDescendants() do
		if d:IsA("Motor6D") and (d.Name == "Minute Sword" or d.Name == "Off Sword") then
			d:Destroy()
		end
	end
	-- accessories hang on welds / constraints that a WorldModel never solves (only animated Motor6Ds move):
	-- re-hang each one on a Motor6D so hats and hair follow the head through the swing
	for _, d in char:GetDescendants() do
		local isW = d:IsA("Weld") or d:IsA("ManualWeld")
		if isW or d:IsA("RigidConstraint") or d:IsA("WeldConstraint") then
			local p0: Instance? = if d:IsA("RigidConstraint") then (d.Attachment0 and d.Attachment0.Parent) else (d :: any).Part0
			local p1: Instance? = if d:IsA("RigidConstraint") then (d.Attachment1 and d.Attachment1.Parent) else (d :: any).Part1
			if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				local m = Instance.new("Motor6D")
				m.Name = "HangJoint"
				m.Part0, m.Part1 = p0, p1
				m.C0 = p0.CFrame:ToObjectSpace(p1.CFrame)
				m.Parent = p1
				d:Destroy()
			end
		end
	end
	char:PivotTo(CFrame.new(0, 3, 0))
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
		end
	end
	root.Anchored = true
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	char.Parent = wm
	arm(char, tpl, "Right Arm", "Minute Sword", "Minute Dagger", false)
	if item.twin then
		arm(char, tpl, "Left Arm", "Off Sword", "Off Dagger", true)
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	-- front three-quarter from the weapon side, far enough that the swing's forward lunge stays in frame
	cam.CFrame = CFrame.lookAt(Vector3.new(5.2, 4.6, -11.5), Vector3.new(0.4, 2.6, -1.4))
	cam.Parent = vf
	vf.CurrentCamera = cam
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local function load(id: string?): AnimationTrack?
		if not id or id == "" then
			return nil
		end
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, t = pcall(function()
			return animator:LoadAnimation(a)
		end)
		return if ok then t else nil
	end
	local idle = load(AnimConfig.builtin and AnimConfig.builtin.Idle)
	local swing = load(AnimConfig.ids[if item.twin then "SwingDual" else "SwingJab"])
	if idle then
		idle.Looped = true
		idle.Priority = Enum.AnimationPriority.Idle
		idle:Play(0)
	end
	if swing then
		swing.Priority = Enum.AnimationPriority.Action2
	end
	task.spawn(function()
		task.wait(0.5)
		while stageToken == token and pc.Visible do
			if swing then
				setText(pc, "Phase", phaseText or "SWING")
				swing:Play(0.05)
				task.wait(1.1)
			end
			if stageToken ~= token then
				break
			end
			setText(pc, "Phase", phaseText or "IDLE")
			task.wait(SWING_EVERY - 1.1)
		end
	end)
end

-- ===== cards

local function itemFor(skinId: string): any
	return EconomyConfig.item("knife_" .. skinId)
end

local function utcDay(): number
	return math.floor(os.time() / 86400)
end

local function onSaleToday(item: any): boolean
	return table.find(EconomyConfig.knifeDaily(utcDay()), item.id) ~= nil
end

-- takeoff / wear (owned), then for sale: ok / poor (today's store), else today / locked / rotation (collection)
local function cardState(item: any, p: any, daily: boolean?): string
	local c = p and p.cosmetics
	if c and c.owned and c.owned[item.id] then
		return if c.knifeSkin == item.id then "takeoff" else "wear"
	end
	if daily then
		return if (p and p.gems or 0) < item.price then "poor" else "ok"
	end
	if onSaleToday(item) then
		return "today"
	end
	return if item.crateOnly then "locked" else "rotation"
end

-- a tag and its DropShadow twin (a sibling 2 px up-left, 4 px bigger): shown, hidden and moved together
local function tagShow(card: Instance, name: string, on: boolean, y: number?)
	local t = card:FindFirstChild(name, true) :: GuiObject?
	if not t or not t.Parent then
		return
	end
	local sh: GuiObject? = t:GetAttribute("ShadowName") and t.Parent:FindFirstChild(t:GetAttribute("ShadowName") :: string) :: GuiObject? or nil
	if not sh then
		for _, d in t.Parent:GetChildren() do
			if d:IsA("GuiObject") and d.Name == "DropShadow" and d.Position.X.Offset == t.Position.X.Offset - 2
				and d.Position.Y.Offset == t.Position.Y.Offset - 2 then
				sh = d
				d.Name = name .. "Drop"
				t:SetAttribute("ShadowName", d.Name)
				break
			end
		end
	end
	t.Visible = on
	if y then
		t.Position = UDim2.fromOffset(t.Position.X.Offset, y)
	end
	if sh then
		sh.Visible = on
		sh.Position = UDim2.fromOffset(t.Position.X.Offset - 2, t.Position.Y.Offset - 2)
	end
end

local function fillCard(rec: CardRec, p: any)
	local f, item = rec.frame, rec.item
	local st = cardState(item, p, rec.daily)
	show(f:FindFirstChild("BtnWear", true), st == "wear")
	show(f:FindFirstChild("BtnTakeOff", true), st == "takeoff")
	if rec.daily then
		show(f:FindFirstChild("BtnBuy", true), st == "ok")
		show(f:FindFirstChild("BtnPoor", true), st == "poor")
		tagShow(f, "TwinTag", rec.twin, nil)
		tagShow(f, "WornTag", st == "takeoff", if rec.twin then 45 else 13)
		if st == "poor" then
			setText(f, "Sub", ("Need %d more Gems"):format(item.price - (p and p.gems or 0)))
		else
			setText(f, "Sub", if rec.twin then "A blade in each hand" else "Same reach and timing")
		end
		local sub = f:FindFirstChild("Sub", true)
		local grad = sub and sub:FindFirstChildOfClass("UIGradient")
		local col = if st == "poor" then subPoor else subOk
		if grad and col then
			grad.Color = col
		end
		for _, b in { "BtnBuy", "BtnPoor" } do
			setText(f:FindFirstChild(b, true), "Price", tostring(item.price))
		end
		return
	end
	show(f:FindFirstChild("LockMark", true), st == "locked")
	show(f:FindFirstChild("CrateOnly", true), st == "locked")
	show(f:FindFirstChild("InStore", true), st == "today")
	show(f:FindFirstChild("NRotation", true), st == "rotation")
	local vf = f:FindFirstChild("Render", true)
	if vf and vf:IsA("ViewportFrame") then
		vf.ImageColor3 = if st == "locked" or st == "rotation" then Color3.fromRGB(105, 100, 120) else Color3.new(1, 1, 1)
	end
end

local function layout()
	local sf = scroll
	if not sf then
		return
	end
	local n = 0
	for _, rec in cards do
		local r = rec.item.rarity
		local on = filter == "all" or (filter == "twin" and rec.twin) or (filter ~= "twin" and r == filter)
		rec.frame.Visible = on
		if on then
			rec.frame.Position = UDim2.fromOffset((n % PER_ROW) * (CARD_W + GAP_X), (n // PER_ROW) * (CARD_H + GAP_Y))
			n += 1
		end
	end
	local rows = math.max(1, math.ceil(n / PER_ROW))
	sf.CanvasSize = UDim2.fromOffset(0, rows * (CARD_H + GAP_Y) - GAP_Y + 4)
	sf.CanvasPosition = Vector2.zero
end

-- buttons + hover / tap stage on one card (collection or daily)
local function wireCard(f: Frame, item: any, skin: string, twin: boolean)
	onClick(f:FindFirstChild("BtnBuy", true), function()
		Net.event("RequestBuy"):FireServer(item.id)
	end)
	onClick(f:FindFirstChild("BtnPoor", true), function()
		local ok, UIC = pcall(require, script.Parent.UIController)
		if ok and UIC.openGemShop then
			UIC.openGemShop()
		end
	end)
	onClick(f:FindFirstChild("BtnWear", true), function()
		Net.event("RequestSetCosmetic"):FireServer("knifeSkin", item.id)
	end)
	onClick(f:FindFirstChild("BtnTakeOff", true), function()
		Net.event("RequestSetCosmetic"):FireServer("knifeSkin", "")
	end)
	local stageItem = { skin = skin, name = item.name, rarity = item.rarity, twin = twin }
	local over = 0
	f.MouseEnter:Connect(function()
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			return
		end
		over += 1
		local mine = over
		task.delay(DWELL, function()
			if over == mine and os.clock() >= crateHoldUntil then
				openStage(stageItem)
			end
		end)
	end)
	f.MouseLeave:Connect(function()
		over += 1
		task.delay(0.05, function()
			if os.clock() >= crateHoldUntil then
				closeStage()
			end
		end)
	end)
	local pv = f:FindFirstChild("Preview", true) :: GuiObject?
	if pv then
		pv.InputBegan:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.Touch then
				openStage(stageItem)
			end
		end)
	end
end

-- renders are built while the page is open, a few per frame
local function buildRenders(list: { CardRec })
	task.spawn(function()
		while true do
			local pg = page
			if pg and pg.Visible then
				local built = 0
				for _, rec in list do
					if not rec.built and rec.frame.Parent then
						buildCardRender(rec)
						built += 1
						if built >= 4 then
							break
						end
					end
				end
				if built == 0 then
					break
				end
			end
			task.wait(0.03)
		end
	end)
end

local function buildCards(grid: Frame)
	local sf = Instance.new("ScrollingFrame")
	sf.Name = "Scroll"
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Position = UDim2.fromOffset(0, 0)
	sf.Size = UDim2.fromOffset(PER_ROW * CARD_W + (PER_ROW - 1) * GAP_X + 14, 262)
	sf.ScrollBarThickness = 8
	sf.ScrollBarImageColor3 = Color3.fromRGB(255, 194, 28)
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.Parent = grid
	scroll = sf
	local donors: { [string]: Frame } = {}
	for r, n in DONOR do
		local d = grid:FindFirstChild(n)
		if d and d:IsA("Frame") then
			donors[r] = d
		end
	end
	for _, k in EconomyConfig.KNIFE_SKINS do
		local item = itemFor(k[1])
		local donor = item and donors[item.rarity]
		if item and donor then
			local f = donor:Clone()
			f.Name = "Coll_" .. k[1]
			f.Visible = true
			f.Parent = sf
			setText(f, "ItemName", item.name)
			local twin = string.sub(k[1], 1, 5) == "dual_"
			local rec: CardRec = { frame = f, item = item, skin = k[1], twin = twin, built = false }
			table.insert(cards, rec)
			wireCard(f, item, k[1], twin)
		end
	end
	for _, d in donors do
		d:Destroy()
	end
	for _, c in grid:GetChildren() do
		if c:IsA("GuiObject") and c ~= sf then
			c:Destroy() -- ProtoCard and the other samples
		end
	end
	buildRenders(cards)
end

-- TODAY'S WEAPONS: the 4 cards of the current UTC day (rebuilt when the day turns)
local function buildDaily()
	local row = dailyRow
	if not row then
		return
	end
	local day = utcDay()
	if day == dailyDay then
		return
	end
	dailyDay = day
	for _, rec in dailyRecs do
		rec.frame:Destroy()
	end
	table.clear(dailyRecs)
	for i, id in EconomyConfig.knifeDaily(day) do
		local item = EconomyConfig.item(id) :: any
		local donor = item and dailyDonors[item.rarity]
		if item and donor then
			local f = donor:Clone()
			f.Name = "Daily_" .. item.skin
			f.Position = UDim2.fromOffset((i - 1) * (DAILY_W + DAILY_GAP), 0)
			f.Visible = true
			f.Parent = row
			setText(f, "ItemName", item.name)
			local twin = string.sub(item.skin, 1, 5) == "dual_"
			local rec: CardRec = { frame = f, item = item, skin = item.skin, twin = twin, built = false, daily = true }
			table.insert(dailyRecs, rec)
			wireCard(f, item, item.skin, twin)
		end
	end
	buildRenders(dailyRecs)
	if lastProfile then
		for _, rec in dailyRecs do
			fillCard(rec, lastProfile)
		end
		for _, rec in cards do
			fillCard(rec, lastProfile)
		end
	end
end

-- the crate card's guarantee lines and bars, and the owned count
local function fillCrate(p: any)
	local pg = page
	if not pg then
		return
	end
	local C = EconomyConfig.KNIFE_CRATE
	local w = (p and p.weaponPity) or {}
	for _, key in { "epic", "legendary" } do
		local need = C.pity[key]
		local done = math.clamp(tonumber(w[key]) or 0, 0, need - 1)
		local left = need - done
		setText(pg, if key == "epic" then "GuaranteeEpic" else "GuaranteeLegend",
			if left <= 1 then "the next crate!" else ("%d more crates"):format(left))
		local bar = pg:FindFirstChild(if key == "epic" then "EpicBar" else "LegendBar", true)
		local fill = bar and bar:FindFirstChild("F") :: GuiObject?
		if bar and fill and bar:IsA("GuiObject") then
			local full = bar.Size.X.Offset - 2 * fill.Position.X.Offset
			fill.Size = UDim2.fromOffset(math.max(2, math.floor(full * done / need)), fill.Size.Y.Offset)
			local pic = false
			for _, a in fill:GetChildren() do -- (the gold bar's fill carries its own picture: it follows the fill)
				if a:IsA("GuiObject") then
					a.Size = UDim2.fromScale(1, 1)
					pic = true
				end
			end
			if not pic and fill.BackgroundTransparency >= 1 then -- (the violet one came out of the export see-through)
				fill.BackgroundColor3 = EconomyConfig.KNIFE_RARITY[key].color
				fill.BackgroundTransparency = 0
			end
		end
	end
	local owned = 0
	local c = p and p.cosmetics and p.cosmetics.owned
	for _, k in EconomyConfig.KNIFE_SKINS do
		if c and c["knife_" .. k[1]] then
			owned += 1
		end
	end
	setText(pg, "OwnedCount", ("%d / %d owned"):format(owned, #EconomyConfig.KNIFE_SKINS))
end

-- ===== mount / refresh

local function spaceTabs(panel: Instance)
	for i, nm in TAB_ORDER do
		local t = panel:FindFirstChild(nm)
		if t and t:IsA("GuiObject") then
			local wasW = t.Size.X.Offset
			-- juicy buttons are centre-anchored: keep the same top edge, put the left edge on the 254 px grid
			local top = t.Position.Y.Offset - t.AnchorPoint.Y * t.Size.Y.Offset
			t.Size = UDim2.fromOffset(TAB_W, t.Size.Y.Offset)
			t.Position = UDim2.fromOffset(TAB_X0 + (i - 1) * TAB_STEP + t.AnchorPoint.X * TAB_W, top + t.AnchorPoint.Y * t.Size.Y.Offset)
			if wasW == OLD_TAB_W then
				local dx = (TAB_W - OLD_TAB_W) // 2 -- keep icon + label centred
				for _, half in t:GetChildren() do
					if half:IsA("GuiObject") then
						half.Size = UDim2.fromOffset(TAB_W, half.Size.Y.Offset)
						for _, d in half:GetChildren() do
							if d:IsA("GuiObject") then
								if d.Name == "Art" then
									d.Size = UDim2.fromOffset(TAB_W, d.Size.Y.Offset)
								else
									d.Position = UDim2.fromOffset(d.Position.X.Offset + dx, d.Position.Y.Offset)
								end
							end
						end
					end
				end
			end
		end
	end
end

function WeaponShopUI.mount(shop: Instance)
	if mounted then
		return
	end
	local tf = shop:FindFirstChild("TabFeatured", true)
	local panel = tf and tf.Parent
	local tpl = templates()
	if not panel or not tpl then
		warn("[EOS] WeaponShopUI: no Shop panel or WeaponUITemplates")
		return
	end
	mounted = true
	-- the Shop header's wallet was drawn for "1,250 / 12": 4-5 digit Gems clipped to "5,0". Wider plate, each count in
	-- its own box, shrinking to fit (HOS-WEP-001: crate and daily prices put Gem counts in the thousands)
	local hi = panel:FindFirstChild("HeaderInfo") :: GuiObject?
	if hi and hi.Size.X.Offset < 320 then
		local grow = 330 - hi.Size.X.Offset
		hi.Position -= UDim2.fromOffset(grow, 0)
		hi.Size += UDim2.fromOffset(grow, 0)
		local placeX = { GoldText = { 79, 92 }, I_gem = { 178, 48 }, GemsText = { 234, 86 } }
		for _, d in hi:GetChildren() do
			if d:IsA("GuiObject") then
				if d.Name == "Art" then
					d.Size = UDim2.fromOffset(hi.Size.X.Offset, d.Size.Y.Offset)
				else
					local key = d.Name:gsub("Shadow$", "")
					local px = placeX[key]
					if px then
						d.Position = UDim2.fromOffset(px[1], d.Position.Y.Offset)
						d.Size = UDim2.fromOffset(px[2], d.Size.Y.Offset)
						if d:IsA("TextLabel") then
							local max = d.TextSize
							d.TextWrapped = false
							d.TextScaled = true
							local c = d:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
							c.MaxTextSize = max
							c.Parent = d
						end
					end
				end
			end
		end
	end
	-- (if a later main EOSUI export already carries a Weapons tab / page, those are replaced by the template ones)
	for _, n in { "TabWeapons", "PageWeapons" } do
		local dup = panel:FindFirstChild(n)
		if dup then
			dup:Destroy()
		end
	end
	local tabWrap = tpl:FindFirstChild("TabWeapons")
	local tab = tabWrap and tabWrap:FindFirstChild("TabWeapons")
	if tab then
		local t = tab:Clone() :: GuiObject
		local f = tf :: GuiObject
		t.AnchorPoint = f.AnchorPoint
		t.Position = UDim2.fromOffset(0, f.Position.Y.Offset)
		t.Parent = panel
	end
	spaceTabs(panel)
	local pageWrap = tpl:FindFirstChild("PageWeapons")
	local pg = pageWrap and pageWrap:FindFirstChild("PageWeapons")
	if pg then
		local p = pg:Clone() :: Frame
		p.Position = PAGE_POS
		p.Visible = false
		p.Parent = panel
		page = p
		crateCard = p:FindFirstChild("CrateCard") :: GuiObject?
		previewCard = p:FindFirstChild("PreviewCard") :: GuiObject?
		show(previewCard, false)
		-- HOS-INV-001: one opening for Robux (KNIFE_CRATE.productId); hidden where paid random items are restricted
		local robuxOn = EconomyConfig.KNIFE_CRATE.productId ~= nil and (GameConfigShop.Features and GameConfigShop.Features.SHOP_PURCHASES) == true
		local rbBtn = p:FindFirstChild("BtnCrateRobux", true) :: GuiObject?
		show(rbBtn, robuxOn)
		if robuxOn and rbBtn then
			setText(rbBtn, "Label", tostring(EconomyConfig.KNIFE_CRATE.robux or ""))
			onClick(rbBtn, function()
				local UIC = require(script.Parent.UIController) :: any
				if UIC.crateBlocked then
					return
				end
				pcall(function()
					game:GetService("MarketplaceService"):PromptProductPurchase(Players.LocalPlayer, EconomyConfig.KNIFE_CRATE.productId)
				end)
			end)
			task.spawn(function() -- the policy answer arrives a moment after join (EmoteController asks)
				task.wait(3)
				local UIC = require(script.Parent.UIController) :: any
				if UIC.crateBlocked then
					show(rbBtn, false)
				end
			end)
		end
		local gems = p:FindFirstChild("BtnCrateGems", true) :: GuiObject?
		if gems and not robuxOn then -- the Gem button takes the Robux one's room too
			local rb = p:FindFirstChild("BtnCrateRobux", true) :: GuiObject?
			if rb then
				gems.Size = UDim2.fromOffset(rb.Position.X.Offset + rb.Size.X.Offset - gems.Position.X.Offset, gems.Size.Y.Offset)
				for _, d in gems:GetDescendants() do
					if d:IsA("GuiObject") and d.Name == "Art" then
						d.Size = UDim2.fromOffset(gems.Size.X.Offset, d.Size.Y.Offset)
					end
				end
				local dx = (gems.Size.X.Offset - 170) // 2
				for _, d in gems:GetChildren() do
					if d:IsA("GuiObject") and d.Name ~= "Art" then
						d.Position = UDim2.fromOffset(d.Position.X.Offset + dx, d.Position.Y.Offset)
					end
				end
			end
		end
		setText(p, "CrateSub", ("One of %d weapon skins"):format(#EconomyConfig.KNIFE_SKINS))
		onClick(gems, function()
			Net.event("RequestWeaponCrate"):FireServer()
		end)
		for _, key in { "all", "legendary", "epic", "rare", "common", "twin" } do
			local chip = p:FindFirstChild("Filter" .. key:sub(1, 1):upper() .. key:sub(2), true)
			onClick(chip, function()
				filter = key
				for _, k2 in { "all", "legendary", "epic", "rare", "common", "twin" } do
					setDual(p:FindFirstChild("Filter" .. k2:sub(1, 1):upper() .. k2:sub(2), true), k2 == filter)
				end
				layout()
			end)
		end
		local grid = p:FindFirstChild("WpnGrid") :: Frame?
		if grid then
			buildCards(grid)
			layout()
		end
		for _, d in p:GetChildren() do
			if d:IsA("TextLabel") then
				local dx = if d.Name:find("^OwnedCount") then 26 elseif d.Name:find("^T_TheOnlyOnes") then 22 else 0
				d.Position += UDim2.fromOffset(dx, 0)
			end
		end
		if crateCard then
			for _, d in crateCard:GetChildren() do
				if d:IsA("TextLabel") then
					local n = d.Name
					local dx = if n:find("^GuaranteeEpic") or n:find("^GuaranteeLegend") then 12
						elseif n:find("^T_60") or n:find("^T_27") or n:find("^T_10") or n:find("^T_3") then 8 else 0
					d.Position += UDim2.fromOffset(dx, 0)
				end
			end
		end
		local row = p:FindFirstChild("DailyRow") :: Frame?
		if row then
			for r, n in DAILY_DONOR do
				local d = row:FindFirstChild(n)
				if d and d:IsA("Frame") then
					dailyDonors[r] = d:Clone()
				end
			end
			local function subColor(n: string): ColorSequence?
				local d = row:FindFirstChild(n)
				local l = d and d:FindFirstChild("Sub", true)
				local g = l and l:FindFirstChildOfClass("UIGradient")
				return if g then g.Color else nil
			end
			subOk, subPoor = subColor("Card_rb_illumina"), subColor("Card_shadow_katana") -- (samples: plain, short of Gems)
			for _, c in row:GetChildren() do
				if c:IsA("GuiObject") then
					c:Destroy() -- ProtoDaily and the samples
				end
			end
			dailyRow = row
			buildDaily()
		end
		-- the countdown to the next store, and the turn of the day
		task.spawn(function()
			while true do
				local pg2 = page
				if pg2 and pg2.Visible then
					local left = 86400 - (os.time() % 86400)
					setText(pg2, "DailyTimer", ("NEW IN %02d:%02d:%02d"):format(left // 3600, (left % 3600) // 60, left % 60))
					buildDaily()
				end
				task.wait(1)
			end
		end)
	end
	-- the orb skins' glow layers turn slowly while the page is open
	game:GetService("RunService").RenderStepped:Connect(function(dt)
		local pg = page
		if not pg or not pg.Visible then
			return
		end
		for _, rec in cards do
			if rec.built and rec.frame.Visible then -- (collection cards; daily ones never hold an orb glow: Legendaries aren't sold)
				local box = rec.frame:FindFirstChild("Preview", true)
				if box then
					for _, g in box:GetChildren() do
						local sp = g:FindFirstChild("Spin") :: NumberValue?
						if sp and g:IsA("GuiObject") then
							g.Rotation = (g.Rotation + sp.Value * dt) % 360
						end
					end
				end
			end
		end
	end)
	Net.event("WeaponCrateResult").OnClientEvent:Connect(function(r)
		if type(r) ~= "table" or not r.ok then
			return
		end
		local item = EconomyConfig.item(r.itemId)
		if not item then
			return
		end
		if type(r.pity) == "table" and lastProfile then -- the guarantee bars move with the result
			lastProfile.weaponPity = r.pity
			fillCrate(lastProfile)
		end
		local skin = (item :: any).skin
		crateHoldUntil = os.clock() + 4
		openStage({ skin = skin, name = item.name, rarity = (item :: any).rarity, twin = string.sub(skin, 1, 5) == "dual_" },
			if r.dupe then ("DUPLICATE  ·  +%d GEMS"):format(r.refund or 0) else "NEW!  ·  EQUIPPED",
			("From the Weapon Crate: %s"):format(string.upper((item :: any).rarity or "")))
		task.delay(4, function()
			if os.clock() >= crateHoldUntil then
				closeStage()
			end
		end)
	end)
end

function WeaponShopUI.refresh(sc: Instance, profile: any, active: boolean)
	if not mounted then
		WeaponShopUI.mount(sc)
	end
	lastProfile = profile
	do -- the lobby pedestals' signs show OWNED for what you have (HOS-WEP-001)
		local ok, WP = pcall(require, script.Parent:FindFirstChild("WeaponPedestals") :: ModuleScript)
		if ok and WP and WP.setProfile then
			WP.setProfile(profile)
		end
	end
	if not active then
		closeStage()
		return
	end
	buildDaily()
	for _, rec in dailyRecs do
		fillCard(rec, profile)
	end
	for _, rec in cards do
		fillCard(rec, profile)
	end
	fillCrate(profile)
end

return WeaponShopUI
