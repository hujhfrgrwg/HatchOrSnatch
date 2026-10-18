--!nonstrict
-- BackpackController (HOS-INV-001, 17 Oct): the Backpack, one place to equip what you own.
-- Hunter: "I like replacing pets with the backpack button. Pets will just be a tab in the backpack" and
-- "Emotes needs to stay" (Emotes keeps its own rail button and My Emotes).
--
--   ClientMain: task.spawn(require(Controllers.BackpackController).init)   (after UIController.init)
--
-- * No new screen and no new save data. The Pets screen (EOSUI Root.Pets) becomes the Backpack: the banner says
--   BACKPACK, three tabs sit in the header (Pets, Weapons, Cosmetics). The Pets tab is the old Pets panel as it
--   was (UIController still fills and wires it); its pieces move into a PetsLayer frame so a tab can hide them.
-- * Weapons and Cosmetics show owned items only, as cards cloned from the Weapons tab's own exported pieces
--   (ReplicatedStorage.WeaponUITemplates: collection card donors per rarity, rarity chips, the preview card),
--   so they look like the Shop's Weapons tab. Hover a card (tap its picture on a phone) = the preview card shows
--   it; for a weapon that is your character holding it, idle then a swing (same staging as WeaponShopUI).
-- * Equip calls are the existing ones: RequestSetCosmetic(knifeSkin / case / trailNext / riftSkin, id or "")
--   and RequestUseItem (Confetti Burst). Items with no slot (Rainbow Trail, Gold Ability Colors, Bolt Entrance,
--   Royal Hatching) are always on and say so.
-- * The rail's PETS button becomes BACKPACK (label + icon), changed on the PlayerGui copy at runtime; it still
--   opens the same screen. StarterGui.EOSUI is not edited.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local AnimConfig = require(Shared:WaitForChild("AnimConfig"))
local Net = require(Shared:WaitForChild("Net"))

local UIC = require(script.Parent.UIController)

local Backpack = {}

local player = Players.LocalPlayer
local TABS = {
	{ key = "pets", label = "Pets", icon = "pets" },
	{ key = "weapons", label = "Weapons", icon = "catcher" },
	{ key = "cosmetics", label = "Cosmetics", icon = "sparkle" },
}
local TAB_W, TAB_H, TAB_GAP, TAB_X0, TAB_Y = 196, 60, 8, 748, 23 -- in the header, between the banner and the X
local BODY_X, CHIPS_Y, GRID_Y, BODY_BOTTOM, BODY_RIGHT = 29, 137, 187, 773, 1397 -- the old Pets panel's body box
local CARD_W, CARD_H, GAP_X, GAP_Y, PER_ROW = 132, 214, 7, 8, 7
local PHONE_CARD_SCALE, PHONE_PER_ROW = 1.4, 5 -- phones: five bigger cards a row (names and buttons stay readable)
local PREVIEW_SCALE = 0.95 -- the Weapons preview card (400 x 668) fits the body height (636)
local DONOR = { legendary = "Coll_spirit_blast", epic = "Coll_rb_darkheart", rare = "Coll_rb_firebrand", common = "Coll_rb_orc_blade" }
local RANK = { legendary = 1, epic = 2, rare = 3, common = 4 }
local CHIPS = {
	weapons = { { "FilterAll", "All", "all" }, { "FilterLegendary", "Legendary", "legendary" }, { "FilterEpic", "Epic", "epic" },
		{ "FilterRare", "Rare", "rare" }, { "FilterCommon", "Common", "common" }, { "FilterTwin", "Twin", "twin" } },
	cosmetics = { { "FilterAll", "All", "all" }, { "FilterLegendary", "Egg Cases", "cases" }, { "FilterEpic", "Trails", "trails" },
		{ "FilterRare", "Effects", "effects" } },
}
-- cosmetics: the card frame colour (a rarity donor), icon, what it is, and how it is worn
local COS = {
	case_frost = { tier = "rare", icon = "case_frost", group = "cases", what = "Egg case" },
	case_sunset = { tier = "epic", icon = "case_sunset", group = "cases", what = "Egg case" },
	trail_spark = { tier = "common", icon = "trail", group = "trails", what = "Trail for one match" },
	trail_ember = { tier = "common", icon = "trail_ember", group = "trails", what = "Trail for one match" },
	trailp_rainbow = { tier = "legendary", icon = "trail_rainbow", group = "trails", what = "Trail in every match" },
	fx_rift_void = { tier = "epic", icon = "ab_rift", group = "effects", what = "Rift portal skin", tint = Color3.fromRGB(190, 140, 255) },
	fx_rift_inferno = { tier = "epic", icon = "ab_rift", group = "effects", what = "Rift portal skin", tint = Color3.fromRGB(255, 150, 90) },
	fx_rift_frost = { tier = "epic", icon = "ab_rift", group = "effects", what = "Rift portal skin", tint = Color3.fromRGB(140, 220, 255) },
	fx_gold = { tier = "legendary", icon = "abilityfx_gold", group = "effects", what = "Ability colours" },
	entrance_bolt = { tier = "rare", icon = "entrance", group = "effects", what = "Lobby entrance" },
	hatch_royal = { tier = "legendary", icon = "hatchfx", group = "effects", what = "Hatching ceremony" },
	burst_confetti = { tier = "common", icon = "burst", group = "effects", what = "Use it in the lobby" },
}
local SWING_EVERY = 2.4
local BACKPACK_ICON = "rbxassetid://137255061386763" -- Hunter's brown ChatGPT backpack (decal 82952250089659), 18 Oct

local mounted = false
local profile: any = nil
local assets: any = nil
local screen: Frame? = nil
local panel: Frame? = nil
local petsLayer: Frame? = nil
local itemsLayer: Frame? = nil
local grid: ScrollingFrame? = nil
local previewCard: GuiObject? = nil
local emptyNote: GuiObject? = nil
local chipsFrame: GuiObject? = nil
local tabButtons: { [string]: GuiObject } = {}
local donors: { [string]: Frame } = {}
local tab = "pets"
local filter = "all"
local cards: { { frame: Frame, item: any, built: boolean } } = {}
local stageToken = 0
local lastSig = ""

-- ===== small helpers (same contracts as WeaponShopUI / UIController)

local function find(scope: Instance?, name: string): Instance?
	return scope and scope:FindFirstChild(name, true)
end

local function show(inst: Instance?, on: boolean)
	if inst and inst:IsA("GuiObject") then
		inst.Visible = on
	end
end

local function setDual(d: Instance?, on: boolean)
	if d then
		show(d:FindFirstChild("On"), on)
		show(d:FindFirstChild("Off"), not on)
	end
end

local function setLabels(scope: Instance?, text: string, filterName: string?)
	if not scope then
		return
	end
	for _, d in scope:GetDescendants() do
		if d:IsA("TextLabel") and (not filterName or d.Name == filterName or d.Name == filterName .. "Shadow") then
			d.Text = text
		end
	end
end

local function onClick(b: Instance?, fn: () -> ())
	if not b then
		return
	end
	if b:IsA("GuiButton") then
		UIC.juicy(b, fn)
	end
	for _, c in b:GetChildren() do
		if c:IsA("GuiButton") and (c.Name == "On" or c.Name == "Off") then
			c.Activated:Connect(fn)
		end
	end
end

local function icon(slug: string): string
	return (assets and assets.icons and assets.icons[slug]) or ""
end

local function templates(): Instance?
	return ReplicatedStorage:FindFirstChild("WeaponUITemplates")
end

local function isTwin(item: any): boolean
	return type(item.skin) == "string" and item.skin:sub(1, 5) == "dual_"
end

-- ===== 3D (the Weapons tab's staging, copied so the two tabs can change apart)

local function strip(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Sound") or d:IsA("BaseScript") then
			d:Destroy()
		end
	end
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

local function knifeTemplate(item: any): BasePart?
	local lib = ReplicatedStorage:FindFirstChild("EOS_KnifeSkinPreviews")
	local t = lib and lib:FindFirstChild(item.skin)
	return if t and t:IsA("BasePart") then t else nil
end

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

local function cardPose(skin: BasePart): CFrame
	local lean = CFrame.Angles(0, 0, math.rad(-35))
	local tip = skin:GetAttribute("SkinTip") :: Vector3?
	local thin = skin:GetAttribute("SkinThin") :: Vector3?
	local ctr = (skin:GetAttribute("SkinCenter") :: Vector3?) or Vector3.zero
	if not tip or not thin then
		return lean
	end
	local right = thin:Cross(tip).Unit
	return lean * CFrame.fromMatrix(ctr, right, tip, right:Cross(tip)):Inverse()
end

-- a card's picture: a still render of the blade, or the cosmetic's icon
local function buildPicture(rec: any)
	if rec.built then
		return
	end
	local box = find(rec.frame, "Preview") :: GuiObject?
	if not box then
		return
	end
	rec.built = true
	local item = rec.item
	if item.kind == "knifeSkin" then
		local tpl = knifeTemplate(item)
		if not tpl then
			return
		end
		local vf = newViewport(box, "Render")
		local skin = tpl:Clone()
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
		local aspect = 120 / 110
		local need = math.max(s.Y, s.X / aspect) * (if tpl:GetAttribute("NoHolster") then 3.2 else 1.12)
		cam.CFrame = CFrame.lookAt(c + Vector3.new(0, 0, need / 2 / math.tan(math.rad(12)) + s.Z / 2), c)
		cam.Parent = vf
		vf.CurrentCamera = cam
	else
		local cos = COS[item.id] or {}
		local img = Instance.new("ImageLabel")
		img.Name = "Pic"
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(0.86, 0.86)
		img.SizeConstraint = Enum.SizeConstraint.RelativeYY
		img.Image = icon(cos.icon or "sparkle")
		img.ImageColor3 = cos.tint or Color3.new(1, 1, 1)
		img.ZIndex = box.ZIndex + 1
		img.Parent = box
	end
end

-- ===== the preview card

local function clearStage()
	stageToken += 1
	local st = previewCard and previewCard:FindFirstChild("Stage")
	if st then
		for _, c in st:GetChildren() do
			if c.Name == "Stage3D" or c.Name == "Pic" then
				c:Destroy()
			end
		end
	end
end

local function stageCharacter(stage: GuiObject, item: any, token: number)
	local tpl = knifeTemplate(item)
	local me = player.Character
	if not tpl or not me then
		return
	end
	local vf = newViewport(stage, "Stage3D")
	local wm = Instance.new("WorldModel")
	wm.Parent = vf
	local was = me.Archivable
	me.Archivable = true
	local char = me:Clone()
	me.Archivable = was
	if not char then
		vf:Destroy()
		return
	end
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
	for _, d in char:GetDescendants() do
		if d:IsA("Motor6D") and (d.Name == "Minute Sword" or d.Name == "Off Sword") then
			d:Destroy()
		end
	end
	-- accessories hang on welds a WorldModel never solves: re-hang them on Motor6Ds so they follow the swing
	for _, d in char:GetDescendants() do
		if d:IsA("Weld") or d:IsA("ManualWeld") or d:IsA("RigidConstraint") or d:IsA("WeldConstraint") then
			local p0 = if d:IsA("RigidConstraint") then (d.Attachment0 and d.Attachment0.Parent) else (d :: any).Part0
			local p1 = if d:IsA("RigidConstraint") then (d.Attachment1 and d.Attachment1.Parent) else (d :: any).Part1
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
	local function mirror(cf: CFrame): CFrame
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
	end
	local function arm(armName: string, motorName: string, partName: string, mirrored: boolean)
		local a = char:FindFirstChild(armName) :: BasePart?
		if not a then
			return
		end
		local w = tpl:Clone()
		strip(w)
		w.Name = partName
		for _, d in w:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.Massless = false, false, true
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
			m.C0, m.C1 = mirror(m.C0), mirror(m.C1)
		end
		m.Part0, m.Part1 = a, w
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
	arm("Right Arm", "Minute Sword", "Minute Dagger", false)
	if isTwin(item) then
		arm("Left Arm", "Off Sword", "Off Dagger", true)
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
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
	local swing = load(AnimConfig.ids and AnimConfig.ids[if isTwin(item) then "SwingDual" else "SwingJab"])
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
		while stageToken == token and vf.Parent do
			if swing then
				setLabels(previewCard, "SWING", "Phase")
				swing:Play(0.05)
				task.wait(1.1)
			end
			if stageToken ~= token then
				break
			end
			setLabels(previewCard, "IDLE", "Phase")
			task.wait(SWING_EVERY - 1.1)
		end
	end)
end

local function itemState(item: any): string
	local c = profile and profile.cosmetics or {}
	local owned = c.owned or {}
	if item.kind == "trail" or item.kind == "burst" then
		local n = (c.consumables or {})[item.id] or 0
		if item.kind == "trail" and c.trailNext == item.id then
			return "armed"
		end
		return if n > 0 then "use" else "none"
	end
	if not owned[item.id] then
		return "none"
	end
	local slot = item.slot or (if item.kind == "case" then "case" else nil)
	if not slot then -- no slot: always on, unless switched off here (cosmetics.off, HOS-INV-001)
		return if (c.off or {})[item.id] then "off" else "always"
	end
	return if c[slot] == item.id then "worn" else "wear"
end

local function hintFor(item: any, st: string): string
	if item.kind == "knifeSkin" then
		return if isTwin(item) then "A blade in each hand, same reach and timing" else "Your Catcher with it, same reach and timing"
	end
	local n = ((profile and profile.cosmetics and profile.cosmetics.consumables) or {})[item.id] or 0
	if item.kind == "trail" then
		return ("You have %d.  One goes on your egg %s."):format(n, if st == "armed" then "next match" else "when you pick it")
	elseif item.kind == "burst" then
		return ("You have %d.  Pops over your head in the lobby."):format(n)
	elseif st == "always" then
		return "On in every match.  Tap ON to switch it off."
	elseif st == "off" then
		return "Switched off.  Tap TURN ON to wear it again."
	end
	return item.desc or ""
end

local function showPreview(item: any?)
	local pc = previewCard
	if not pc then
		return
	end
	clearStage()
	if not item then
		pc.Visible = false
		return
	end
	pc.Visible = true
	pc:SetAttribute("ItemId", item.id)
	local token = stageToken
	local st = itemState(item)
	setLabels(pc, string.upper(item.name), "Title")
	setLabels(pc, hintFor(item, st), "Hint")
	setLabels(pc, if item.kind == "knifeSkin" then "IDLE  ·  SWING" else string.upper((COS[item.id] or {}).what or ""), "Phase")
	local rt = pc:FindFirstChild("RarityTag")
	local dsh = rt and rt.Parent and rt.Parent:FindFirstChild("DropShadow")
	local hasRarity = item.kind == "knifeSkin"
	show(rt, hasRarity)
	show(dsh, hasRarity)
	if rt and hasRarity then
		for _, d in rt:GetDescendants() do
			if d:IsA("TextLabel") then
				d.Text = string.upper(item.rarity or "")
			end
		end
	end
	local stage = pc:FindFirstChild("Stage") :: GuiObject?
	if not stage then
		return
	end
	if item.kind == "knifeSkin" then
		stageCharacter(stage, item, token)
	else
		local cos = COS[item.id] or {}
		local img = Instance.new("ImageLabel")
		img.Name = "Pic"
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.45)
		img.Size = UDim2.fromScale(0.8, 0.8)
		img.SizeConstraint = Enum.SizeConstraint.RelativeXX
		img.Image = icon(cos.icon or "sparkle")
		img.ImageColor3 = cos.tint or Color3.new(1, 1, 1)
		img.ZIndex = stage.ZIndex + 1
		img.Parent = stage
	end
end

-- ===== cards

local function ownedItems(): { any }
	local list = {}
	local c = profile and profile.cosmetics or {}
	for _, it in EconomyConfig.SHOP do
		if tab == "weapons" and it.kind == "knifeSkin" and (c.owned or {})[it.id] then
			table.insert(list, it)
		elseif tab == "cosmetics" and COS[it.id] and itemState(it) ~= "none" then
			table.insert(list, it)
		end
	end
	local function rank(it: any): number
		local st = itemState(it)
		return if st == "worn" or st == "armed" then 0 else 1
	end
	table.sort(list, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		local ta = RANK[a.rarity or (COS[a.id] or {}).tier or "common"] or 5
		local tb = RANK[b.rarity or (COS[b.id] or {}).tier or "common"] or 5
		if ta ~= tb then
			return ta < tb
		end
		return a.name < b.name
	end)
	return list
end

local function passes(it: any): boolean
	if filter == "all" then
		return true
	end
	if tab == "weapons" then
		return if filter == "twin" then isTwin(it) else it.rarity == filter
	end
	return (COS[it.id] or {}).group == filter
end

local function act(item: any)
	local st = itemState(item)
	if item.kind == "burst" then
		Net.event("RequestUseItem"):FireServer(item.id)
		UIC.close()
	elseif st == "wear" then
		Net.event("RequestSetCosmetic"):FireServer(item.slot or "case", item.id)
	elseif st == "worn" then
		Net.event("RequestSetCosmetic"):FireServer(item.slot or "case", "")
	elseif st == "use" and item.kind == "trail" then
		Net.event("RequestSetCosmetic"):FireServer("trailNext", item.id)
	elseif st == "armed" then
		Net.event("RequestSetCosmetic"):FireServer("trailNext", "")
	elseif st == "always" then
		Net.event("RequestSetCosmetic"):FireServer("off", item.id)
	elseif st == "off" then
		Net.event("RequestSetCosmetic"):FireServer("on", item.id)
	end
end

local fitName: (Instance) -> ()

local function styleCard(rec: any)
	local f, item = rec.frame, rec.item
	local st = itemState(item)
	local wear, off = find(f, "BtnWear"), find(f, "BtnTakeOff")
	local n = ((profile and profile.cosmetics and profile.cosmetics.consumables) or {})[item.id] or 0
	local on = st == "worn" or st == "armed" or st == "always"
	show(wear, not on)
	show(off, on)
	setLabels(wear, if item.kind == "burst" then ("USE  x%d"):format(n) elseif st == "use" then ("USE  x%d"):format(n) elseif st == "off" then "TURN ON" else "EQUIP", "Label")
	setLabels(off, if st == "always" then "ON" elseif st == "armed" then "NEXT MATCH" else "EQUIPPED", "Label")
end

local function rebuild()
	local g = grid
	if not g then
		return
	end
	for _, rec in cards do
		rec.frame:Destroy()
	end
	table.clear(cards)
	local list = {}
	for _, it in ownedItems() do
		if passes(it) then
			table.insert(list, it)
		end
	end
	-- phones: the whole UI is scaled small (EOSUI Root's FitScale under 0.5), so cards grow
	local fs = screen and screen.Parent and screen.Parent:FindFirstChildOfClass("UIScale")
	local touch = fs ~= nil and fs.Scale < 0.5
	local k = if touch then PHONE_CARD_SCALE else 1
	local perRow = if touch then PHONE_PER_ROW else PER_ROW
	local stepX, stepY = CARD_W * k + GAP_X, CARD_H * k + GAP_Y
	for i, it in list do
		local tier = it.rarity or (COS[it.id] or {}).tier or "common"
		local donor = donors[tier] or donors.common
		if donor then
			local f = donor:Clone()
			f.Name = "Item_" .. it.id
			f.Visible = true
			f.AnchorPoint = Vector2.zero
			f.Position = UDim2.fromOffset(((i - 1) % perRow) * stepX, math.floor((i - 1) / perRow) * stepY)
			if k ~= 1 then
				local us = f:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
				us.Scale = k
				us.Parent = f
			end
			for _, nm in { "CrateOnly", "InStore", "NRotation", "LockMark", "Render", "Pic" } do
				local x = find(f, nm)
				if x then
					if nm == "Render" or nm == "Pic" then
						x:Destroy()
					else
						show(x, false)
					end
				end
			end
			setLabels(f, it.name, "ItemName")
			if it.kind ~= "knifeSkin" then -- cosmetics: the frame colour says the tier; no rarity word
				local rt = f:FindFirstChild("RarityTag")
				show(rt, false)
				for _, c in f:GetChildren() do
					if c.Name == "DropShadow" and c:IsA("GuiObject") and c.Size.Y.Offset < 40 then
						c.Visible = false
					end
				end
			end
			f.Parent = g
			fitName(f)
			local rec = { frame = f, item = it, built = false }
			table.insert(cards, rec)
			styleCard(rec)
			buildPicture(rec)
			onClick(find(f, "BtnWear"), function() act(it) end)
			onClick(find(f, "BtnTakeOff"), function() act(it) end)
			f.MouseEnter:Connect(function()
				if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
					showPreview(it)
				end
			end)
			local pic = find(f, "Preview") :: GuiObject?
			if pic then
				pic.Active = true
				pic.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
						showPreview(it)
					end
				end)
			end
		end
	end
	local rows = math.ceil(#list / perRow)
	g.CanvasSize = UDim2.fromOffset(0, math.max(0, rows * stepY - GAP_Y + 6))
	show(emptyNote, #list == 0)
	-- the preview starts on what you wear (or the first card)
	local first = nil
	for _, it in list do
		local st = itemState(it)
		if st == "worn" or st == "armed" then
			first = it
			break
		end
	end
	showPreview(first or list[1])
end

local function refreshStates()
	for _, rec in cards do
		styleCard(rec)
	end
	local pc = previewCard
	local shown = pc and pc.Visible and pc:GetAttribute("ItemId")
	for _, rec in cards do
		if rec.item.id == shown then
			setLabels(pc, hintFor(rec.item, itemState(rec.item)), "Hint")
		end
	end
end

-- ===== tabs

local function applyTab()
	for key, b in tabButtons do
		setDual(b, key == tab)
	end
	show(petsLayer, tab == "pets")
	show(itemsLayer, tab ~= "pets")
	if tab == "pets" then
		clearStage()
		return
	end
	local defs = CHIPS[tab]
	if chipsFrame then
		for _, c in chipsFrame:GetChildren() do
			if c:IsA("GuiObject") then
				c.Visible = false
			end
		end
		for _, d in defs do
			local chip = chipsFrame:FindFirstChild(d[1])
			if chip then
				show(chip, true)
				setLabels(chip, d[2])
				setDual(chip, d[3] == filter)
			end
		end
	end
	setLabels(emptyNote, if tab == "weapons" then "No weapons yet" else "No cosmetics yet", "Title")
	setLabels(emptyNote, if tab == "weapons" then "Open a Weapon Crate in the Shop" else "Get trails, egg cases and effects in the Shop", "Hint")
	rebuild()
end

local function setTab(key: string)
	tab = key
	filter = "all"
	applyTab()
end


-- ===== the Pets tab shows the real pets (HOS-INV-001 premium pass): the old Pets panel draws one sample picture per
-- family + rarity (a Witch's Cat showed as a fox, a Compass Hare as a portal). Each tile and the big preview get a
-- 3D render of the species itself (PetModel.viewport), matched to the tiles the way UIController.refreshPets lays
-- them out: one tile per family + rarity, rarest first, then hatch order, filtered by the active family chip.
local PET_RARITIES = { "common", "rare", "epic" } -- UIController's RARITIES (others sort with common)
local function petGroupsLikeUIC(): { any }
	local groups, by = {}, {}
	for _, p in (profile and profile.pets) or {} do
		local k = (p.family or "?") .. ":" .. (p.rarity or "common")
		local g = by[k]
		if not g then
			g = { family = p.family, rarity = p.rarity or "common", species = p.species, n = p.n or 0 }
			by[k] = g
			table.insert(groups, g)
		end
	end
	table.sort(groups, function(a, b)
		local ra, rb = table.find(PET_RARITIES, a.rarity) or 1, table.find(PET_RARITIES, b.rarity) or 1
		if ra ~= rb then
			return ra > rb
		end
		return a.n < b.n
	end)
	return groups
end

local function activeFamily(): string?
	for i = 1, 3 do
		local f = petsLayer and petsLayer:FindFirstChild("Filter" .. i)
		local on = f and f:FindFirstChild("On")
		if on and on:IsA("GuiObject") and on.Visible and (f :: GuiObject).Visible then
			local l = on:FindFirstChild("Label", true)
			return l and l:IsA("TextLabel") and l.Text or nil
		end
	end
	return nil
end

local function render3D(holder: GuiObject?, species: string?, yaw: number)
	if not holder or not species or species == "" then
		return
	end
	if holder:GetAttribute("Species3D") == species then
		return
	end
	local PetModel = require(Shared:WaitForChild("PetModel"))
	local vf = holder:FindFirstChild("Pet3D") :: ViewportFrame?
	if not vf then
		local v = Instance.new("ViewportFrame")
		v.Name = "Pet3D"
		v.BackgroundTransparency = 1
		v.ZIndex = holder.ZIndex + 1
		v.Parent = holder
		vf = v
	end
	local icon = holder:FindFirstChild("Icon") :: GuiObject?
	local view = vf :: ViewportFrame
	if icon then -- same box as the picture it replaces
		view.AnchorPoint = icon.AnchorPoint
		view.Position = icon.Position
		view.Size = icon.Size
		view.ZIndex = icon.ZIndex
	else
		view.Size = UDim2.fromScale(1, 1)
	end
	local ok = pcall(PetModel.viewport, view, species, yaw)
	if not ok then
		view:Destroy()
		return
	end
	holder:SetAttribute("Species3D", species)
	for _, n in { "Icon", "IconShadow" } do
		local g = holder:FindFirstChild(n)
		if g and g:IsA("GuiObject") then
			g.Visible = false
		end
	end
end

local petsQueued = false
local function petViews()
	if petsQueued or not petsLayer then
		return
	end
	petsQueued = true
	task.defer(function()
		petsQueued = false
		local grid = petsLayer and petsLayer:FindFirstChild("Grid", true)
		local scroll = grid and grid:FindFirstChild("Scroll")
		if not scroll then
			return
		end
		local fam = activeFamily()
		local shown = {}
		for _, g in petGroupsLikeUIC() do
			if not fam or g.family == fam then
				table.insert(shown, g)
			end
		end
		for i, g in shown do
			local tile = scroll:FindFirstChild("PetTile" .. i)
			local slot = tile and (tile:FindFirstChild("Tile") or tile)
			if slot and slot:IsA("GuiObject") then
				render3D(slot, g.species, 25)
			end
		end
		-- the big preview: whichever species the name shows
		local pv = petsLayer:FindFirstChild("Preview", true)
		local nameL = pv and pv:FindFirstChild("PetName")
		local slot = pv and pv:FindFirstChild("PreviewSlot")
		if nameL and nameL:IsA("TextLabel") and slot and slot:IsA("GuiObject") then
			local want = nil
			for _, g in petGroupsLikeUIC() do
				local display = EconomyConfig.DISPLAY_NAMES and EconomyConfig.DISPLAY_NAMES[g.species] or g.species
				if display == nameL.Text or g.species == nameL.Text then
					want = g.species
				end
			end
			if want then
				render3D(slot, want, 30)
			end
		end
	end)
end

-- ===== build (once)

local function mount(): boolean
	local pg = player:WaitForChild("PlayerGui")
	local gui = pg:WaitForChild("EOSUI", 30)
	local root = gui and gui:WaitForChild("Root", 10)
	screen = root and root:WaitForChild("Pets", 10) :: Frame?
	local group = screen and screen:FindFirstChild("Pets")
	panel = group and group:FindFirstChild("Panel") :: Frame?
	local tpl = templates()
	local page = tpl and tpl:FindFirstChild("PageWeapons")
	page = page and page:FindFirstChild("PageWeapons")
	local tabTpl = tpl and tpl:FindFirstChild("TabWeapons")
	tabTpl = tabTpl and tabTpl:FindFirstChild("TabWeapons")
	if not (screen and group and panel and page and tabTpl) then
		warn("[Backpack] Pets panel or WeaponUITemplates missing: the Pets panel stays as it is")
		return false
	end
	local ok, a = pcall(require, gui:FindFirstChild("AssetIds"))
	assets = if ok then a else nil
	-- banner: BACKPACK
	local banner = group:FindFirstChild("Banner")
	setLabels(banner, "BACKPACK", "Title")
	for _, nm in { "I_pets", "I_petsShadow" } do
		local im = banner and banner:FindFirstChild(nm)
		if im and im:IsA("ImageLabel") and true then
			im.Image = BACKPACK_ICON
		end
	end
	show(panel:FindFirstChild("HeaderInfo"), false) -- the All chip already counts
	-- Pets tab = the old panel body, moved as one layer
	local pl = Instance.new("Frame")
	pl.Name = "PetsLayer"
	pl.BackgroundTransparency = 1
	pl.Size = UDim2.fromScale(1, 1)
	pl.ZIndex = 2
	for _, c in panel:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "Art" and c.Name ~= "HeaderInfo" then
			c.Parent = pl
		end
	end
	pl.Parent = panel
	petsLayer = pl
	-- Weapons / Cosmetics layer
	local il = Instance.new("Frame")
	il.Name = "ItemsLayer"
	il.BackgroundTransparency = 1
	il.Size = UDim2.fromScale(1, 1)
	il.ZIndex = 2
	il.Visible = false
	il.Parent = panel
	itemsLayer = il
	-- rarity chips (the Weapons tab's own)
	local chips = page:FindFirstChild("WpnFilters")
	if chips then
		local c = chips:Clone()
		c.AnchorPoint = Vector2.zero
		c.Position = UDim2.fromOffset(BODY_X, CHIPS_Y)
		c.Parent = il
		chipsFrame = c
		for _, chip in c:GetChildren() do
			if chip:IsA("GuiButton") then
				onClick(chip, function()
					for _, d in CHIPS[tab] or {} do
						if d[1] == chip.Name then
							filter = d[3]
						end
					end
					applyTab()
				end)
			end
		end
	end
	-- donor cards, one per rarity
	local wgrid = page:FindFirstChild("WpnGrid")
	for r, nm in DONOR do
		local d = wgrid and wgrid:FindFirstChild(nm)
		if d and d:IsA("Frame") then
			donors[r] = d
		end
	end
	-- the preview card (right)
	local pv = page:FindFirstChild("PreviewCard")
	if pv and pv:IsA("GuiObject") then
		local p = pv:Clone()
		local w = math.floor(p.Size.X.Offset * PREVIEW_SCALE + 0.5)
		p.AnchorPoint = Vector2.zero
		p.Position = UDim2.fromOffset(BODY_RIGHT - w, CHIPS_Y)
		local sc = Instance.new("UIScale")
		sc.Scale = PREVIEW_SCALE
		sc.Parent = p
		p.Visible = false
		p.Parent = il
		previewCard = p
	end
	-- the grid
	local gridW = BODY_RIGHT - math.floor(400 * PREVIEW_SCALE + 0.5) - BODY_X - 14
	local sf = Instance.new("ScrollingFrame")
	sf.Name = "BackpackGrid"
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Position = UDim2.fromOffset(BODY_X, GRID_Y)
	sf.Size = UDim2.fromOffset(gridW, BODY_BOTTOM - GRID_Y)
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.ScrollBarThickness = 6
	sf.ScrollBarImageColor3 = Color3.fromRGB(225, 225, 232)
	sf.ElasticBehavior = Enum.ElasticBehavior.Never
	sf.ZIndex = 3
	sf.Parent = il
	grid = sf
	-- empty state: the preview card's own title + hint lines
	if pv then
		local holder = Instance.new("Frame")
		holder.Name = "EmptyNote"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(gridW, 160)
		holder.Position = UDim2.fromOffset(BODY_X, GRID_Y + 140)
		holder.ZIndex = 4
		holder.Visible = false
		for _, nm in { "TitleShadow", "Title", "HintShadow", "Hint" } do
			local l = pv:FindFirstChild(nm)
			if l and l:IsA("GuiObject") then
				local c = l:Clone()
				c.Position = UDim2.fromOffset((gridW - c.Size.X.Offset) / 2, c.Position.Y.Offset - 540)
				c.Parent = holder
			end
		end
		holder.Parent = il
		emptyNote = holder
	end
	-- tabs in the header, between the banner and the X (the Weapons tab button, re-dressed)
	for i, t in TABS do
		local b = tabTpl:Clone()
		b.Name = "BackpackTab" .. t.label
		b.AnchorPoint = Vector2.zero
		b.Size = UDim2.fromOffset(TAB_W, TAB_H)
		b.Position = UDim2.fromOffset(TAB_X0 + (i - 1) * (TAB_W + TAB_GAP), TAB_Y)
		b.ZIndex = 20
		for _, half in b:GetChildren() do
			if half:IsA("GuiObject") then
				half.Size = UDim2.fromOffset(TAB_W, TAB_H)
				for _, d in half:GetChildren() do
					if d:IsA("ImageLabel") and d.Name == "Art" then
						d.Size = UDim2.fromOffset(TAB_W, TAB_H + 4)
					elseif d:IsA("ImageLabel") then -- the icon (+ its shadow)
						d.Position = UDim2.fromOffset(16, d.Position.Y.Offset)
						if icon(t.icon) ~= "" then
							d.Image = icon(t.icon)
						end
					elseif d:IsA("TextLabel") then
						d.Text = t.label
						d.Position = UDim2.fromOffset(60, d.Position.Y.Offset)
						d.Size = UDim2.fromOffset(TAB_W - 70, d.Size.Y.Offset)
						d.TextXAlignment = Enum.TextXAlignment.Center
					end
				end
			end
		end
		b.Parent = panel
		tabButtons[t.key] = b
		onClick(b, function()
			setTab(t.key)
		end)
	end
	return true
end

-- the rail's PETS button reads BACKPACK (same screen, same key)
local function relabelRail()
	local gui = player.PlayerGui:FindFirstChild("EOSUI")
	local btn = gui and gui:FindFirstChild("PetsButton", true)
	if not btn then
		return
	end
	setLabels(btn, "BACKPACK", "Label")
	for _, d in btn:GetDescendants() do
		if d:IsA("ImageLabel") and (d.Name == "Icon" or d.Name == "IconShadow" or d.Name == "I_pets" or d.Name == "I_petsShadow") and true then
			d.Image = BACKPACK_ICON
		end
	end
end

-- what you own (not what you wear): cards keep their places while you equip, and only a new or used-up
-- item rebuilds the grid
local function sig(p: any): string
	local c = p and p.cosmetics or {}
	local keys = {}
	for k in c.owned or {} do
		table.insert(keys, k)
	end
	for k, n in c.consumables or {} do
		if (n or 0) > 0 then
			table.insert(keys, k .. "+")
		end
	end
	table.sort(keys)
	return table.concat(keys, ",")
end

local function onProfile(view: any)
	if type(view) ~= "table" then
		return
	end
	profile = view
	if not mounted or tab == "pets" or not (screen and screen.Visible) then
		return
	end
	local s = sig(view)
	if s ~= lastSig then -- something new, or a trail / confetti used up: rebuild
		lastSig = s
		rebuild()
	else
		refreshStates()
	end
end

-- long names shrink to fit their card (Roblox fonts run wider than the export measured)
function fitName(f: Instance)
	local labels = {}
	for _, d in f:GetDescendants() do
		if d:IsA("TextLabel") and (d.Name == "ItemName" or d.Name == "ItemNameShadow") then
			d.TextScaled = false
			d.TextWrapped = false
			table.insert(labels, d)
		end
	end
	task.spawn(function() -- TextBounds updates a frame after the text is set: measure, then scale the size to fit
		game:GetService("RunService").Heartbeat:Wait()
		for _, d in labels do
			if d.Parent then
				local k = math.min(1, d.AbsoluteSize.X / math.max(d.TextBounds.X, 1))
				d.TextSize = math.max(10, math.floor(d.TextSize * k))
			end
		end
	end)
end

-- open the Backpack on a tab ("pets" | "weapons" | "cosmetics"), e.g. from another screen
function Backpack.open(key: string?)
	if key then
		tab = key
		filter = "all"
	end
	if UIC.openName() ~= "Pets" then
		UIC.open("Pets") -- (opening an open screen would close it)
	end
	if UIC.openName() == "Pets" then
		applyTab()
	end
end

function Backpack.init()
	Net.event("ProfileState").OnClientEvent:Connect(onProfile)
	mounted = mount()
	if not mounted then
		return
	end
	relabelRail()
	-- Pets tab: real 3D pets on every refresh of the old panel (tiles are rebuilt each time)
	task.spawn(function()
		local grid = petsLayer and petsLayer:FindFirstChild("Grid", true)
		local scroll = grid and grid:WaitForChild("Scroll", 20)
		if scroll then
			scroll.ChildAdded:Connect(petViews)
		end
		local pv = petsLayer and petsLayer:FindFirstChild("Preview", true)
		local nameL = pv and pv:FindFirstChild("PetName")
		if nameL then
			nameL:GetPropertyChangedSignal("Text"):Connect(function()
				local slot = pv:FindFirstChild("PreviewSlot")
				if slot then
					slot:SetAttribute("Species3D", nil)
				end
				petViews()
			end)
		end
		petViews()
	end)
	local prev = UIC.onOpen.Pets
	UIC.onOpen.Pets = function()
		if prev then
			prev()
		end
		lastSig = sig(profile)
		applyTab()
		petViews()
	end
	applyTab()
	Net.event("RequestProfile"):FireServer()
end

return Backpack
