--!strict
-- WeaponPedestals (client), HOS-WEP-001: the lobby pedestals that show off the weapons.
-- v1 (Hunter 17 Oct 23:35 "Handle it"): today's daily store (EconomyConfig.knifeDaily) on Pedestal_1..4, the Weapon
-- Crate on Pedestal_Crate, signs from the approved templates (WeaponUITemplates.PedestalSigns).
-- v2 (23:53 "like huss valley where it's your player holding the weapon, doing attack animations and whatnot. And if
-- you walk close to it, it attacks you and makes you do the knocked down animation and you get back up"; mockup
-- approved 18 Oct 00:01 "Ok"):
--  * On each pedestal stands a copy of YOUR avatar (this client's own character) holding that pedestal's weapon on
--    its real joint, idling and then throwing an attack combo on a loop (SwingSlash + SwingJab; SwingDual for twins).
--    WeaponFXBoot adds the slash (Epic / Legendary) and the Legendary hand aura to these copies like to anyone.
--    The crate pedestal's copy changes Legendary every few seconds.
--  * Walk within HIT_RANGE: that copy turns to you and swings; at the hit this client asks the server
--    (Net "PedestalHit", slot) to knock you down. The server (WeaponCrateService) checks you're really there, in the
--    lobby, not already down and not hit in the last 8 s, then uses CharacterService.ragdoll (the fall a caught Runner
--    does) for 2 s, pushed toward the middle of the lobby. Looks only: no Gems, egg or match state change.
--  * Signs: rarity, name, today's Gem price or OWNED (ProfileState). Walk-up "View" prompt (LobbyService, EOS_Prompt
--    tag on each Top) opens the Shop on the Weapons tab.
--   WeaponPedestals.start()            WeaponFXBoot, once
--   WeaponPedestals.setProfile(p)      on every ProfileState (and from WeaponShopUI.refresh): OWNED on the signs

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local AnimConfig = require(Shared:WaitForChild("AnimConfig"))
local Net = require(Shared:WaitForChild("Net"))

local WeaponPedestals = {}

local CRATE_EVERY = 6 -- seconds per Legendary on the crate pedestal
local PPS = 72 -- sign pixels per stud (the 300 x 130 px sign is about 4.2 studs wide)
local HIT_RANGE = 6 -- studs (flat) from the pedestal's middle
local HIT_COOLDOWN = 8 -- seconds between two hits on you (the server keeps the same rule)
local HIT_DELAY = 0.2 -- seconds into the swing: the blade's fastest part
local COMBO_GAP = { 2.2, 3.4 } -- seconds between two showing-off combos

type Ped = {
	model: Model,
	slot: number,
	top: BasePart,
	stand: CFrame, -- where the copy's root stands (facing the middle of the lobby)
	avatar: Model?,
	tracks: { [string]: AnimationTrack },
	skin: string?,
	sign: SurfaceGui?,
	itemId: string?,
	busyUntil: number, -- a swing at you: the combo loop waits
	nextCombo: number,
}

local peds: { Ped } = {}
local profile: any = nil
local started = false
local day = -1
local crateIdx = 0
local legendaries: { string } = {}
local avatarTpl: Model? = nil
local nextHitAt = 0
local player = Players.LocalPlayer

-- ===== the sign

local function templates(): Instance?
	return ReplicatedStorage:FindFirstChild("WeaponUITemplates")
end

local function signDonor(name: string): GuiObject?
	local t = templates()
	local ps = t and t:FindFirstChild("PedestalSigns")
	local d = ps and ps:FindFirstChild(name, true)
	return if d and d:IsA("GuiObject") then d else nil
end

local function setText(scope: Instance, name: string, text: string)
	for _, d in scope:GetDescendants() do
		if d:IsA("TextLabel") and (d.Name == name or d.Name == name .. "Shadow") then
			d.Text = text
		end
	end
end

local function show(scope: Instance, name: string, on: boolean)
	local g = scope:FindFirstChild(name, true)
	if g and g:IsA("GuiObject") then
		g.Visible = on
	end
end

local function setSign(p: Ped, donorName: string)
	local part = p.model:FindFirstChild("Sign") :: BasePart?
	if not part then
		return
	end
	local sg = p.sign
	if sg and sg:GetAttribute("Donor") == donorName then
		return
	end
	if sg then
		sg:Destroy()
	end
	local donor = signDonor(donorName)
	if not donor then
		return
	end
	local g = Instance.new("SurfaceGui")
	g.Name = "PedestalSign"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = PPS
	g.LightInfluence = 0
	g.Brightness = 1.4
	g.AlwaysOnTop = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- (as the exported screens: tag labels sit on their plates)
	g.MaxDistance = 140
	g:SetAttribute("Donor", donorName)
	local f = donor:Clone()
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Visible = true
	f.Parent = g
	g.Parent = part
	p.sign = g
end

local function setRim(p: Ped, rarity: string?)
	local r = rarity and EconomyConfig.KNIFE_RARITY[rarity]
	local c = r and r.color or Color3.fromRGB(255, 194, 28)
	for _, n in { "Rim", "ColumnGlow" } do
		local part = p.model:FindFirstChild(n)
		if part and part:IsA("BasePart") then
			part.Color = c
		end
	end
	local col = p.model:FindFirstChild("Column")
	if col and col:IsA("BasePart") then
		col.Color = c:Lerp(Color3.new(0, 0, 0), 0.5) -- the pillar in a deep shade of the rarity, the bands lit
	end
end

-- ===== the avatar copy

-- your character, without what only the real one should have (scripts, tags, the knife, egg, pets, outline)
local function makeAvatarTemplate(char: Model): Model?
	local was = char.Archivable
	char.Archivable = true
	local ok, c = pcall(function()
		return char:Clone()
	end)
	char.Archivable = was
	if not ok or not c then
		return nil
	end
	local m = c :: Model
	for _, d in m:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Highlight") or d:IsA("BillboardGui") or d:IsA("ForceField") or d:IsA("Sound")
			or d:IsA("Trail") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	for _, d in m:GetChildren() do
		if (d:IsA("Model") and not d:FindFirstChildOfClass("Humanoid")) or d:IsA("Folder")
			or (d:IsA("BasePart") and (string.find(d.Name, "Dagger") ~= nil or d:GetAttribute("EOS_Holstered") ~= nil
				or d:GetAttribute("EOS_Knife") ~= nil or d:GetAttribute("EOS_Egg") ~= nil)) then
			d:Destroy() -- (egg, pet, knife and holster copies, ragdoll rigs)
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("Motor6D") and (d.Name == "Minute Sword" or d.Name == "Off Sword") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.Anchored = false
			d.LocalTransparencyModifier = 0
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hum or not m:FindFirstChild("HumanoidRootPart") or not m:FindFirstChild("Right Arm") then
		m:Destroy()
		return nil -- (R6 only, like the game's knife)
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.NameDisplayDistance = 0
	hum.HealthDisplayDistance = 0
	hum.BreakJointsOnDeath = false
	for k in m:GetAttributes() do
		m:SetAttribute(k, nil) -- (no EOS_Role / EOS_InMatch / ragdoll state on a copy)
	end
	m.Name = "PedestalAvatar"
	return m
end

local function mirror(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- a weapon on the copy, on the same joint the clips pose (the part must be called Minute Dagger / Off Dagger)
local function wield(av: Model, skin: string)
	for _, n in { "Minute Dagger", "Off Dagger" } do
		local old = av:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	for _, armName in { "Right Arm", "Left Arm" } do
		local a = av:FindFirstChild(armName)
		for _, n in { "Minute Sword", "Off Sword" } do
			local m = a and a:FindFirstChild(n)
			if m then
				m:Destroy()
			end
		end
	end
	local lib = ReplicatedStorage:FindFirstChild("EOS_KnifeSkinPreviews")
	local tpl = lib and lib:FindFirstChild(skin)
	if not tpl or not tpl:IsA("BasePart") or not tpl:FindFirstChild("Minute Sword") then
		return
	end
	local function one(armName: string, motorName: string, partName: string, mirrored: boolean)
		local arm = av:FindFirstChild(armName) :: BasePart?
		if not arm then
			return
		end
		local w = (tpl :: BasePart):Clone()
		w.Name = partName
		for _, k in { "HolsterSlot", "EOS_Knife", "EOS_Weapon" } do
			w:SetAttribute(k, nil) -- (the holster would put it away: these copies always hold theirs)
		end
		for _, d in w:GetDescendants() do
			if d:IsA("Trail") then
				d.Enabled = false -- (a swing streak from a copy that never moves smears on the spot)
			elseif d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
			end
		end
		w.Anchored = false
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.Massless = true
		local m = w:FindFirstChild("Minute Sword") :: Motor6D
		m.Name = motorName
		if mirrored then
			m.C0, m.C1 = mirror(m.C0), mirror(m.C1)
		end
		m.Part0 = arm
		m.Part1 = w
		w.CFrame = arm.CFrame * m.C0 * m.C1:Inverse()
		m.Parent = arm
		w.Parent = av
	end
	one("Right Arm", "Minute Sword", "Minute Dagger", false)
	if tpl:GetAttribute("Dual") then
		one("Left Arm", "Off Sword", "Off Dagger", true)
	end
end

local function loadTracks(p: Ped)
	local av = p.avatar
	local hum = av and av:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local an = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	an.Parent = hum
	local function load(key: string, id: string?, pri: Enum.AnimationPriority, looped: boolean)
		if type(id) ~= "string" or id == "" then
			return
		end
		local a = Instance.new("Animation")
		a.Name = key -- (WeaponFX recognises a swing by its clip name too)
		a.AnimationId = id
		local ok, t = pcall(function()
			return an:LoadAnimation(a)
		end)
		if ok and t then
			t.Priority = pri
			t.Looped = looped
			p.tracks[key] = t
		end
	end
	load("Idle", AnimConfig.builtin and AnimConfig.builtin.Idle, Enum.AnimationPriority.Idle, true)
	load("SwingSlash", AnimConfig.ids.SwingSlash, Enum.AnimationPriority.Action, false)
	load("SwingJab", AnimConfig.ids.SwingJab, Enum.AnimationPriority.Action, false)
	load("SwingDual", AnimConfig.ids.SwingDual, Enum.AnimationPriority.Action2, false)
	if p.tracks.Idle then
		p.tracks.Idle:Play()
	end
end

local function standAvatar(p: Ped, faceTo: Vector3?)
	local av = p.avatar
	local root = av and av:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not av or not root then
		return
	end
	local cf = p.stand
	if faceTo then
		local at = cf.Position
		local flat = Vector3.new(faceTo.X, at.Y, faceTo.Z)
		if (flat - at).Magnitude > 0.1 then
			cf = CFrame.lookAt(at, flat)
		end
	end
	root.CFrame = cf
end

local function buildAvatar(p: Ped)
	if p.avatar then
		p.avatar:Destroy()
		p.avatar = nil
	end
	table.clear(p.tracks)
	local tpl = avatarTpl
	if not tpl then
		return
	end
	local av = tpl:Clone()
	local root = av:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	av.Parent = p.model
	p.avatar = av
	standAvatar(p, nil)
	if p.skin then
		wield(av, p.skin)
	end
	loadTracks(p)
end

local function setSkin(p: Ped, skin: string?)
	if p.skin == skin then
		return
	end
	p.skin = skin
	if p.avatar and skin then
		wield(p.avatar, skin)
	end
end

local function isTwin(p: Ped): boolean
	return p.avatar ~= nil and p.avatar:FindFirstChild("Off Dagger") ~= nil
end

-- one swing (or the twins' double swing); `second` = the combo's follow-up
local function swing(p: Ped, second: boolean?)
	local key = if isTwin(p) then "SwingDual" elseif second then "SwingJab" else "SwingSlash"
	local t = p.tracks[key] or p.tracks.SwingSlash
	if t then
		t:Play(0.05)
	end
end

-- ===== filling the pedestals

local function fillDaily(p: Ped)
	local id = p.itemId
	local item = id and EconomyConfig.item(id) :: any
	if not item then
		return
	end
	setSkin(p, item.skin)
	setRim(p, item.rarity)
	local owned = profile and profile.cosmetics and profile.cosmetics.owned and profile.cosmetics.owned[item.id] == true
	setSign(p, "Sign_" .. item.rarity)
	local sg = p.sign
	if sg then
		setText(sg, "ItemName", item.name)
		setText(sg, "Price", ("%d"):format(item.price))
		show(sg, "PriceRow", not owned)
		show(sg, "Owned", owned == true)
	end
end

local function refreshDay()
	local d = math.floor(os.time() / 86400)
	if d == day then
		return
	end
	day = d
	local ids = EconomyConfig.knifeDaily(d)
	for _, p in peds do
		if p.slot >= 1 then
			p.itemId = ids[p.slot]
			fillDaily(p)
		end
	end
end

local function nextLegendary()
	if #legendaries == 0 then
		for _, k in EconomyConfig.KNIFE_SKINS do
			if k[3] == "legendary" then
				table.insert(legendaries, k[1])
			end
		end
	end
	crateIdx = crateIdx % math.max(1, #legendaries) + 1
	for _, p in peds do
		if p.slot == 0 then
			setSkin(p, legendaries[crateIdx])
			setRim(p, "legendary")
			setSign(p, "CrateSign")
			if p.sign then
				setText(p.sign, "CratePrice", tostring(EconomyConfig.KNIFE_CRATE.gems))
			end
		end
	end
end

function WeaponPedestals.setProfile(p: any)
	profile = p
	for _, ped in peds do
		if ped.slot >= 1 then
			fillDaily(ped)
		end
	end
end

-- ===== walk-up

local function myRoot(): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function tryHit(p: Ped, now: number)
	local root = myRoot()
	local c = player.Character
	if not root or not c or player:GetAttribute("EOS_InMatch") == true or c:GetAttribute("EOS_Ragdoll") == true then
		return
	end
	local mid = p.top.Position
	local d = Vector3.new(root.Position.X - mid.X, 0, root.Position.Z - mid.Z).Magnitude
	if d > HIT_RANGE or math.abs(root.Position.Y - mid.Y) > 8 or now < nextHitAt then
		return
	end
	nextHitAt = now + HIT_COOLDOWN
	p.busyUntil = now + 1.6
	standAvatar(p, root.Position) -- it turns to you
	swing(p, false)
	task.delay(HIT_DELAY, function()
		Net.event("PedestalHit"):FireServer(p.slot)
	end)
	task.delay(1.4, function()
		standAvatar(p, nil) -- back to facing the lobby
	end)
end

function WeaponPedestals.start()
	if started then
		return
	end
	started = true
	Net.event("ProfileState").OnClientEvent:Connect(function(view)
		if type(view) == "table" then
			WeaponPedestals.setProfile(view)
		end
	end)
	task.spawn(function()
		local lobby = workspace:WaitForChild("LobbyProto", 60)
		local root = lobby and lobby:WaitForChild("WeaponPedestals", 30)
		ReplicatedStorage:WaitForChild("EOS_KnifeSkinPreviews", 60)
		if not root then
			return
		end
		-- your look: taken once your character has loaded, again on every new character (outfit changes)
		local function takeLook(char: Model)
			-- (a StarterCharacter never fires CharacterAppearanceLoaded: wait a little for it, then take what's there)
			local t0 = os.clock()
			while not player:HasAppearanceLoaded() and os.clock() - t0 < 4 do
				task.wait(0.2)
			end
			task.wait(0.5)
			if char.Parent == nil then
				return
			end
			local tpl = makeAvatarTemplate(char)
			if tpl then
				if avatarTpl then
					avatarTpl:Destroy()
				end
				avatarTpl = tpl
				for _, p in peds do
					buildAvatar(p)
				end
			end
		end
		player.CharacterAdded:Connect(function(c)
			task.spawn(takeLook, c)
		end)
		if player.Character then
			task.spawn(takeLook, player.Character)
		end
		-- (the models are Persistent for streaming, but their parts can land later: picked up as they arrive)
		local function scan()
			for _, m in root:GetChildren() do
				local known = false
				for _, p in peds do
					if p.model == m then
						known = true
					end
				end
				local top = m:FindFirstChild("Top")
				if not known and m:IsA("Model") and top and top:IsA("BasePart") and m:FindFirstChild("Sign") then
					-- the copy stands on the top, facing where the pedestal faces (the middle of the lobby)
					local base = m:FindFirstChild("Base") :: BasePart?
					local face = if base then (base.CFrame * CFrame.Angles(0, 0, math.rad(-90))).LookVector else Vector3.new(1, 0, 0)
					local topY = top.Position.Y + top.Size.X / 2
					local at = Vector3.new(top.Position.X, topY + 3, top.Position.Z)
					local p: Ped = {
						model = m, slot = (m:GetAttribute("Slot") :: number?) or 0, top = top,
						stand = CFrame.lookAt(at, at + Vector3.new(face.X, 0, face.Z)), avatar = nil, tracks = {},
						skin = nil, sign = nil, itemId = nil, busyUntil = 0, nextCombo = os.clock() + math.random() * 2,
					}
					table.insert(peds, p)
					if p.slot >= 1 then
						p.itemId = EconomyConfig.knifeDaily(math.floor(os.time() / 86400))[p.slot]
						fillDaily(p)
					end
					buildAvatar(p)
				end
			end
		end
		scan()
		refreshDay()
		nextLegendary()
		local lastCrate, lastDay = os.clock(), os.clock()
		RunService.Heartbeat:Connect(function()
			local t = os.clock()
			if t - lastCrate >= CRATE_EVERY then
				lastCrate = t
				nextLegendary()
			end
			if t - lastDay >= 5 then
				lastDay = t
				scan()
				refreshDay()
			end
			for _, p in peds do
				if p.avatar then
					-- showing off: a two-hit combo now and then (one double swing for twins)
					if t >= p.nextCombo and t >= p.busyUntil then
						p.nextCombo = t + COMBO_GAP[1] + math.random() * (COMBO_GAP[2] - COMBO_GAP[1])
						swing(p, false)
						if not isTwin(p) then
							task.delay(0.55, function()
								if os.clock() >= p.busyUntil then
									swing(p, true)
								end
							end)
						end
					end
					tryHit(p, t)
				end
			end
		end)
	end)
end

return WeaponPedestals
