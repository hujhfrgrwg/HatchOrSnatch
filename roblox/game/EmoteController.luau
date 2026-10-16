-- EmoteController (HOS-EMOTE-001, 16 Oct): emotes on the new UI (EOSUI) and their playback.
--  * Emotes panel: My Emotes (cards with a live preview of your avatar, PLAY, EQUIP onto your wheel) and
--    the Emote Crate (odds board for all 51, open for Gems, a reel, then the new-emote reveal)
--  * EmoteWheel (G in the lobby): your six wheel emotes around a centre disc; 1-6 play a slot
--  * your emote: the server confirms by setting your character's EOS_Emote; this plays the clip on your
--    Animator (it replicates) and stops it the moment you move or jump. once = true clips play one time
--  * every character with EOS_Emote set gets its song as a 3D sound at its root (heard nearby)
-- Odds, prices, songs: Shared/EmoteConfig. Clips: ReplicatedStorage.EOS_Emotes (R6; Studio fallback).

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local EOS = ReplicatedStorage:WaitForChild("EOS")
local Shared = EOS:WaitForChild("Shared")
local EmoteConfig = require(Shared:WaitForChild("EmoteConfig"))
local Net = require(Shared:WaitForChild("Net"))

local Sound = require(script.Parent.Sound)
local UI = require(script.Parent.UIController)

local EmoteController = {}

local player = Players.LocalPlayer
local profile: any = nil
local panel: Instance? = nil -- Root.Emotes.Emotes
local wheelScreen: Instance? = nil -- Root.EmoteWheel.Wheel
local tab = "mine"
local nextTab: string? = nil -- the tab the next open shows (GET EMOTES -> crate, MY EMOTES -> mine)
local selSlot = 1
local rolling = false
local pendingResult: any = nil
local mineSig = ""
local oddsCards: { [string]: GuiObject } = {}
local wheelSent = false
local crateBlocked = false -- paid random items restricted for this player (PolicyService)

local lazyOddsRef: () -> () = function() end -- set once lazyOdds exists (setTab is defined first)
local PROTO = { common = "common", rare = "rare", epic = "epic", legendary = "crowned" }

local function find(scope: Instance?, name: string): Instance?
	return scope and scope:FindFirstChild(name, true)
end
local function setText(scope: Instance?, name: string, text: string)
	local t = find(scope, name)
	if t and (t:IsA("TextLabel") or t:IsA("TextButton")) then
		t.Text = text
		local sh = t.Parent and t.Parent:FindFirstChild(name .. "Shadow")
		if sh and sh:IsA("TextLabel") then sh.Text = text end
	end
end
local function show(g: Instance?, on: boolean)
	if g and g:IsA("GuiObject") then g.Visible = on end
end
-- recolour a label: the export baked its design colour into a UIGradient, which would tint the new colour
local function tint(label: Instance?, colour: Color3)
	if not label or not label:IsA("TextLabel") then return end
	label.TextColor3 = colour
	local g = label:FindFirstChildOfClass("UIGradient")
	if g then g.Color = ColorSequence.new(Color3.new(1, 1, 1)) end
end

local function inMatch(): boolean
	return player:GetAttribute("EOS_InMatch") == true
end

-- ===== clip ids =====

local idCache: { [string]: string } = {}
local function clipId(id: string): string?
	local e = EmoteConfig.get(id)
	if not e then return nil end
	if e.animId ~= nil and e.animId ~= "" then
		return "rbxassetid://" .. tostring(e.animId)
	end
	if idCache[id] then return idCache[id] end
	if not RunService:IsStudio() then
		warn("[EOS] emote '" .. id .. "' has no published animation id yet (Shared/EmoteConfig)")
		return nil
	end
	local lib = ReplicatedStorage:FindFirstChild(EmoteConfig.LIBRARY)
	local seq = lib and lib:FindFirstChild(id)
	if not seq then return nil end
	local ok, cid = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(seq)
	end)
	if ok and cid then
		idCache[id] = cid
		return cid
	end
	return nil
end

-- ===== your emote =====

local track: AnimationTrack? = nil
local trackId = ""
local startedAt = 0

local function stopTrack()
	if track then
		track:Stop(0.2)
		track = nil
	end
	trackId = ""
end

local function playOwn(id: string)
	stopTrack()
	local e = EmoteConfig.get(id)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local cid = clipId(id)
	if not animator or not cid or not e then return end
	local a = Instance.new("Animation")
	a.AnimationId = cid
	local t = animator:LoadAnimation(a)
	t.Priority = Enum.AnimationPriority.Action4
	t.Looped = not e.once
	t:Play(0.2)
	track = t
	trackId = id
	startedAt = os.clock()
	if e.once then
		t.Stopped:Once(function()
			if track == t then
				track = nil
				trackId = ""
				Net.event("RequestEmote"):FireServer("")
			end
		end)
	end
end

function EmoteController.play(id: string)
	if inMatch() then
		return UI.toast("Emotes play in the lobby", "info")
	end
	Net.event("RequestEmote"):FireServer(id)
end

function EmoteController.stop()
	Net.event("RequestEmote"):FireServer("")
end

local function watchOwn(char: Model)
	stopTrack()
	char:GetAttributeChangedSignal("EOS_Emote"):Connect(function()
		local id = char:GetAttribute("EOS_Emote")
		if type(id) == "string" and id ~= "" then
			playOwn(id)
		else
			stopTrack()
		end
	end)
end

-- moving or jumping ends your dance
local function stepOwn()
	if not track then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then return stopTrack() end
	if os.clock() - startedAt < 0.3 then return end
	local v = root.AssemblyLinearVelocity
	local planar = Vector3.new(v.X, 0, v.Z).Magnitude
	if hum.MoveDirection.Magnitude > 0.1 or planar > 3 or hum.Jump or hum:GetState() == Enum.HumanoidStateType.Jumping then
		stopTrack()
		Net.event("RequestEmote"):FireServer("")
	end
end

-- ===== songs (everyone) =====

local function setSong(char: Model)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local old = root:FindFirstChild("EOS_EmoteMusic")
	local id = char:GetAttribute("EOS_Emote")
	local e = type(id) == "string" and EmoteConfig.get(id) or nil
	if not e or not e.music then
		if old then old:Destroy() end
		return
	end
	if old and old:GetAttribute("Emote") == id then return end
	if old then old:Destroy() end
	local s = Instance.new("Sound")
	s.Name = "EOS_EmoteMusic"
	s.SoundId = "rbxassetid://" .. tostring(e.music)
	s.Looped = true
	s.Volume = if Sound.enabled then EmoteConfig.MUSIC_VOLUME else 0
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 12
	s.RollOffMaxDistance = EmoteConfig.MUSIC_RANGE
	s:SetAttribute("Emote", id)
	s.Parent = root
	s:Play()
end

local function watchCharacter(char: Model)
	setSong(char)
	char:GetAttributeChangedSignal("EOS_Emote"):Connect(function()
		setSong(char)
	end)
end

local function watchPlayer(plr: Player)
	if plr.Character then watchCharacter(plr.Character) end
	plr.CharacterAdded:Connect(watchCharacter)
end

-- ===== live previews (a copy of your avatar doing each emote, in a card's View) =====

local previewRig: Model? = nil
local previews: { { vp: ViewportFrame, track: AnimationTrack? } } = {}
local STRIP = { "LuaSourceContainer", "Sound", "BillboardGui", "SurfaceGui", "ParticleEmitter", "Trail", "Beam", "Highlight", "ForceField", "Tool", "ProximityPrompt", "ClickDetector" }

local function makeRig(): Model?
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
	local was = char.Archivable
	char.Archivable = true
	local ok, c = pcall(function() return char:Clone() end)
	char.Archivable = was
	if not ok or not c then return nil end
	for _, d in ipairs(c:GetDescendants()) do
		local kill = d.Name:sub(1, 4) == "EOS_"
		for _, cls in ipairs(STRIP) do
			if d:IsA(cls) then kill = true end
		end
		if d:IsA("Constraint") and not d:IsA("WeldConstraint") then kill = true end
		if kill and d.Parent then d:Destroy() end
	end
	for k in pairs(c:GetAttributes()) do c:SetAttribute(k, nil) end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hum then
		c:Destroy()
		return nil
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	if not hum:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = hum end
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	local root = c:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	root.Transparency = 1
	c.PrimaryPart = root
	c:PivotTo(CFrame.new())
	return c
end

-- a looping preview of emote `id` inside `holder` (the exported View image; its placeholder icon hides)
local function attachPreview(holder: Instance?, id: string, dist: number)
	if not holder or not holder:IsA("GuiObject") then return end
	if not previewRig then previewRig = makeRig() end
	if not previewRig then return end
	local vp = holder:FindFirstChild("EOS_Preview") :: ViewportFrame?
	if not vp then
		local v = Instance.new("ViewportFrame")
		v.Name = "EOS_Preview"
		v.BackgroundTransparency = 1
		v.Size = UDim2.fromScale(1, 1)
		v.ZIndex = holder.ZIndex + 1
		v.Parent = holder
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = v
		vp = v
	end
	local ph = holder:FindFirstChild("Placeholder")
	if ph and ph:IsA("GuiObject") then ph.Visible = false end
	local view = vp :: ViewportFrame
	for _, ch in ipairs(view:GetChildren()) do
		if ch:IsA("WorldModel") or ch:IsA("Camera") then ch:Destroy() end
	end
	for i = #previews, 1, -1 do
		if previews[i].vp == view or not previews[i].vp.Parent then table.remove(previews, i) end
	end
	local wm = Instance.new("WorldModel")
	wm.Parent = view
	local rig = previewRig:Clone()
	rig.Parent = wm
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, -dist), Vector3.new(0, 0.15, 0))
	cam.Parent = view
	view.CurrentCamera = cam
	view.Ambient = Color3.fromRGB(205, 205, 212)
	view.LightColor = Color3.fromRGB(255, 250, 240)
	view.LightDirection = Vector3.new(0.4, -1, 0.8)
	local entry: { vp: ViewportFrame, track: AnimationTrack? } = { vp = view, track = nil }
	table.insert(previews, entry)
	local cid = clipId(id)
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if cid and animator then
		local a = Instance.new("Animation")
		a.AnimationId = cid
		local ok, t = pcall(function() return animator:LoadAnimation(a) end)
		if ok and t then
			t.Looped = true
			t.Priority = Enum.AnimationPriority.Action4
			t:Play(0)
			t.TimePosition = math.random() * math.max(0.1, t.Length * 0.5)
			entry.track = t
		end
	end
end

-- previews only move while the Emotes panel is open
local previewsRunning = true
local function stepPreviews()
	local on = UI.openName() == "Emotes"
	if on == previewsRunning then return end
	previewsRunning = on
	for _, e in ipairs(previews) do
		if e.track then e.track:AdjustSpeed(if on then 1 else 0) end
	end
end

-- ===== data =====

local function owned(id: string): boolean
	return profile ~= nil and type(profile.emotes) == "table" and profile.emotes[id] == true
end

local function ownedList(): { any }
	local out = {}
	for _, e in ipairs(EmoteConfig.LIST) do
		if owned(e.id) then table.insert(out, e) end
	end
	table.sort(out, function(a, b)
		local ra, rb = EmoteConfig.RARITY[a.rarity].order, EmoteConfig.RARITY[b.rarity].order
		if ra ~= rb then return ra > rb end
		return a.order < b.order
	end)
	return out
end

local function wheel(): { string }
	return EmoteConfig.cleanWheel(profile and profile.emoteWheel, profile and profile.emotes)
end

local function sendWheel(w: { string })
	if profile then profile.emoteWheel = w end
	Net.event("RequestEmoteWheel"):FireServer(w)
end

-- older saves have no wheel: fill it with the first six emotes you own, once
local function defaultWheel()
	if wheelSent or not profile then return end
	local w = wheel()
	for _, id in ipairs(w) do
		if id ~= "" then return end
	end
	local list = ownedList()
	if #list == 0 then return end
	for i = 1, math.min(#list, EmoteConfig.WHEEL_SLOTS) do w[i] = list[i].id end
	wheelSent = true
	sendWheel(w)
end

local function rarityColour(e: any): Color3
	return EmoteConfig.RARITY[e.rarity].color
end

-- wheel tiles share one dark plate; the rim shows the rarity
local function styleTile(tile: Instance?, e: any)
	if not tile or not tile:IsA("GuiObject") then return end
	local art = tile:FindFirstChild("Art")
	local target = if art and art:IsA("GuiObject") then art else tile
	local stroke = target:FindFirstChild("EOS_Rim") :: UIStroke?
	if not stroke then
		local s = Instance.new("UIStroke")
		s.Name = "EOS_Rim"
		s.Thickness = 3
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = target
		if not target:FindFirstChildOfClass("UICorner") then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 12)
			c.Parent = target
		end
		stroke = s
	end
	local st = stroke :: UIStroke
	st.Enabled = e ~= nil
	if e then st.Color = rarityColour(e) end
end

local emptyArt = "" -- the dark "empty slot" plate, copied onto every wheel tile
local function plateAll(scope: Instance?, prefix: string)
	if not scope then return end
	if emptyArt == "" then
		for i = 1, 6 do
			local s = scope:FindFirstChild(prefix .. i)
			local tile = s and s:FindFirstChild("Tile")
			local art = tile and tile:FindFirstChild("Art")
			local name = tile and tile:FindFirstChild("EmoteName")
			if art and art:IsA("ImageLabel") and name and name:IsA("TextLabel") and (name.Text == "Empty" or name.Text == "EMPTY") then
				emptyArt = art.Image
				break
			end
		end
	end
	if emptyArt == "" then return end
	for i = 1, 6 do
		local s = scope:FindFirstChild(prefix .. i)
		local tile = s and s:FindFirstChild("Tile")
		local art = tile and tile:FindFirstChild("Art")
		if art and art:IsA("ImageLabel") then art.Image = emptyArt end
	end
end

-- ===== Emotes panel =====

local function setTab(t: string)
	tab = t
	if not panel then return end
	for _, pair in ipairs({ { "TabMine", "mine" }, { "TabCrate", "crate" } }) do
		local b = find(panel, pair[1])
		show(b and b:FindFirstChild("On"), t == pair[2])
		show(b and b:FindFirstChild("Off"), t ~= pair[2])
	end
	show(find(panel, "MinePage"), t == "mine")
	show(find(panel, "CratePage"), t == "crate")
	if t == "crate" then task.delay(0.15, function() lazyOddsRef() end) end
end

-- a scrolling list inside an exported well; design cards hide, prototypes are cloned in
local function scrollIn(grid: Instance?): ScrollingFrame?
	if not grid or not grid:IsA("GuiObject") then return nil end
	local sc = grid:FindFirstChild("Scroll") :: ScrollingFrame?
	if sc then return sc end
	local s = Instance.new("ScrollingFrame")
	s.Name = "Scroll"
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = UDim2.fromScale(1, 1)
	s.ScrollBarThickness = 8
	s.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
	s.ScrollBarImageTransparency = 0.4
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.CanvasSize = UDim2.new()
	s.ZIndex = grid.ZIndex + 1
	s.Parent = grid
	grid.ClipsDescendants = true
	return s
end

local function protoCard(grid: Instance?, rarity: string): GuiObject?
	local p = grid and grid:FindFirstChild("Proto_" .. (PROTO[rarity] or rarity))
	local c = p and p:FindFirstChild("Card")
	return if c and c:IsA("GuiObject") then c else nil
end

local function equip(id: string)
	local w = wheel()
	for i = 1, #w do
		if w[i] == id then w[i] = "" end
	end
	if selSlot < 1 or selSlot > #w then selSlot = 1 end
	w[selSlot] = id
	sendWheel(w)
	Sound.play("toggle")
	-- next empty slot is selected for the next EQUIP
	for i = 1, #w do
		if w[i] == "" then
			selSlot = i
			break
		end
	end
	EmoteController.refresh()
end

local function unequip(id: string)
	local w = wheel()
	for i = 1, #w do
		if w[i] == id then
			w[i] = ""
			selSlot = i
		end
	end
	sendWheel(w)
	Sound.play("toggle")
	EmoteController.refresh()
end

local function refreshMine()
	if not panel then return end
	local page = find(panel, "MinePage")
	local grid = page and page:FindFirstChild("Grid")
	local list = ownedList()
	local w = wheel()
	local onWheel = {}
	for _, id in ipairs(w) do
		if id ~= "" then onWheel[id] = true end
	end
	show(find(page, "EmptyState"), #list == 0)
	show(grid, #list > 0)
	local sc = scrollIn(grid)
	if grid and sc then
		local sig = ""
		for _, e in ipairs(list) do sig ..= e.id .. "," end
		if sig ~= mineSig then
			mineSig = sig
			for _, c in ipairs(grid:GetChildren()) do
				if c:IsA("GuiObject") and (c.Name:sub(1, 5) == "Mine_" or c.Name:sub(1, 6) == "Proto_") then c.Visible = false end
			end
			for _, c in ipairs(sc:GetChildren()) do
				if c:IsA("GuiObject") then c:Destroy() end
			end
			for i, e in ipairs(list) do
				local proto = protoCard(grid, e.rarity)
				if proto then
					local c = proto:Clone()
					c.Name = "Mine_" .. e.id
					c.Visible = true
					c.Position = UDim2.fromOffset(18 + ((i - 1) % 4) * 262, 16 + math.floor((i - 1) / 4) * 288)
					c.Parent = sc
					setText(c, "EmoteName", e.name)
					setText(c, "Rarity", EmoteConfig.RARITY[e.rarity].name)
					setText(c, "Song", e.song or "")
					show(c:FindFirstChild("Note"), e.song ~= nil)
					local play, eq, on = c:FindFirstChild("BtnPlay"), c:FindFirstChild("BtnEquip"), c:FindFirstChild("BtnOnWheel")
					if play and play:IsA("GuiButton") then UI.juicy(play, function() UI.close(); EmoteController.play(e.id) end) end
					if eq and eq:IsA("GuiButton") then UI.juicy(eq, function() equip(e.id) end) end
					if on and on:IsA("GuiButton") then UI.juicy(on, function() unequip(e.id) end) end
					attachPreview(c:FindFirstChild("View"), e.id, 9.5)
				end
			end
			sc.CanvasSize = UDim2.fromOffset(0, 16 + math.ceil(#list / 4) * 288)
		end
		for _, c in ipairs(sc:GetChildren()) do
			local id = c.Name:sub(6)
			show(c:FindFirstChild("BtnEquip"), not onWheel[id])
			show(c:FindFirstChild("BtnOnWheel"), onWheel[id] == true)
		end
	end
	-- your wheel
	local wl = page and page:FindFirstChild("Wheel")
	if wl then
		plateAll(wl, "WSlot")
		for i = 1, 6 do
			local s = wl:FindFirstChild("WSlot" .. i)
			local e = EmoteConfig.get(w[i])
			setText(s, "EmoteName", if e then e.name else "Empty")
			setText(s, "Rarity", if e then EmoteConfig.RARITY[e.rarity].name else "pick an emote")
			tint(find(s, "Rarity"), if e then rarityColour(e) else Color3.fromRGB(150, 150, 160))
			show(find(s, "BtnClear"), e ~= nil)
			styleTile(s and s:FindFirstChild("Tile"), e)
		end
		local ring = find(wl, "WSlotSel")
		local tgt = wl:FindFirstChild("WSlot" .. selSlot)
		local tile = tgt and tgt:FindFirstChild("Tile")
		if ring and ring:IsA("GuiObject") and tile and tile:IsA("GuiObject") then
			if ring.Parent ~= tgt then ring.Parent = tgt end
			ring.Position = UDim2.fromOffset(tile.Position.X.Offset - 4 + ring.Size.X.Offset * ring.AnchorPoint.X, tile.Position.Y.Offset - 4 + ring.Size.Y.Offset * ring.AnchorPoint.Y)
			ring.ZIndex = tile.ZIndex + 5
		end
	end
end

-- odds-board previews are made only as cards scroll into view (51 live avatars at once is too heavy)
local function lazyOdds()
	local page = panel and find(panel, "CratePage")
	if not page or not (page :: GuiObject).Visible or UI.openName() ~= "Emotes" then return end
	for id, c in pairs(oddsCards) do
		local sc = c.Parent
		local view = c:FindFirstChild("View")
		if sc and sc:IsA("ScrollingFrame") and view and not view:FindFirstChild("EOS_Preview") then
			local y, h = c.AbsolutePosition.Y, c.AbsoluteSize.Y
			if y + h > sc.AbsolutePosition.Y - 20 and y < sc.AbsolutePosition.Y + sc.AbsoluteSize.Y + 20 then
				attachPreview(view, id, 9.5)
			end
		end
	end
end

lazyOddsRef = lazyOdds

local function refreshCrate()
	if not panel then return end
	local gems = if profile then profile.gems or 0 else 0
	setText(panel, "GemsText", tostring(gems))
	setText(panel, "HaveText", tostring(gems))
	if not crateBlocked then setText(panel, "CrateSub", ("One of %d emotes per crate"):format(#EmoteConfig.LIST)) end
	local can = gems >= EmoteConfig.CRATE_GEMS
	show(find(panel, "BtnOpen"), can and not rolling and not crateBlocked)
	show(find(panel, "BtnPoor"), not can and not rolling and not crateBlocked)
	show(find(panel, "BtnRolling"), rolling)
	if crateBlocked then setText(panel, "CrateSub", "Not available where you play") end
	for _, n in ipairs({ "BtnOpen", "BtnPoor" }) do setText(find(panel, n), "Price", tostring(EmoteConfig.CRATE_GEMS)) end
	local page = find(panel, "CratePage")
	local grid = page and page:FindFirstChild("OddsGrid")
	local sc = scrollIn(grid)
	if grid and sc and next(oddsCards) == nil then
		for _, c in ipairs(grid:GetChildren()) do
			if c:IsA("GuiObject") and (c.Name:sub(1, 5) == "Odds_" or c.Name:sub(1, 6) == "Proto_") then c.Visible = false end
		end
		for i, e in ipairs(EmoteConfig.LIST) do
			local proto = protoCard(grid, e.rarity)
			if proto then
				local c = proto:Clone()
				c.Name = "Odds_" .. e.id
				c.Visible = true
				c.Position = UDim2.fromOffset(18 + ((i - 1) % 5) * 210, 16 + math.floor((i - 1) / 5) * 194)
				c.Parent = sc
				setText(c, "EmoteName", e.name)
				local pct = string.format("%.2f", EmoteConfig.odds(e)):gsub("0+$", ""):gsub("%.$", "")
				setText(c, "Rarity", EmoteConfig.RARITY[e.rarity].name .. "  ·  " .. pct .. "%")
				show(c:FindFirstChild("Glow"), false)
				oddsCards[e.id] = c
			end
		end
		sc.CanvasSize = UDim2.fromOffset(0, 16 + math.ceil(#EmoteConfig.LIST / 5) * 194)
		sc:GetPropertyChangedSignal("CanvasPosition"):Connect(lazyOdds)
	end
	if tab == "crate" then task.defer(lazyOdds) end
	for id, c in pairs(oddsCards) do show(c:FindFirstChild("Owned"), owned(id)) end
end

function EmoteController.refresh()
	refreshCrate()
	refreshMine()
	-- the wheel screen
	if wheelScreen then
		local w = wheel()
		plateAll(wheelScreen, "Slot")
		for i = 1, 6 do
			local s = wheelScreen:FindFirstChild("Slot" .. i)
			local e = EmoteConfig.get(w[i])
			setText(s, "EmoteName", if e then e.name else "EMPTY")
			setText(s, "Rarity", if e then EmoteConfig.RARITY[e.rarity].name else "equip in My Emotes")
			tint(find(s, "Rarity"), if e then rarityColour(e) else Color3.fromRGB(150, 150, 160))
			styleTile(s and s:FindFirstChild("Tile"), e)
		end
	end
end

-- ===== the wheel screen =====

local hovered = 0
local function wheelInfo(i: number)
	if not wheelScreen then return end
	local w = wheel()
	local e = EmoteConfig.get(w[i] or "")
	local cur = player.Character and player.Character:GetAttribute("EOS_Emote")
	local playing = EmoteConfig.get(type(cur) == "string" and cur or "")
	local show_ = e or playing
	setText(wheelScreen, "SelName", if show_ then show_.name else "Pick an emote")
	setText(wheelScreen, "SelInfo", if show_ then (EmoteConfig.RARITY[show_.rarity].name .. (if show_.song then "  ·  " .. show_.song else "")) else "1-6 or click a slot")
	tint(find(wheelScreen, "SelInfo"), if show_ then rarityColour(show_) else Color3.fromRGB(170, 170, 180))
	-- one ring follows the hovered slot
	local ring = find(wheelScreen, "SlotSel")
	local slot = wheelScreen:FindFirstChild("Slot" .. math.max(i, 1))
	local tile = slot and slot:FindFirstChild("Tile")
	if ring and ring:IsA("GuiObject") and tile and tile:IsA("GuiObject") then
		ring.Visible = i > 0
		if ring.Parent ~= slot then ring.Parent = slot end
		ring.Position = UDim2.fromOffset(tile.Position.X.Offset - 4 + ring.Size.X.Offset * ring.AnchorPoint.X, tile.Position.Y.Offset - 4 + ring.Size.Y.Offset * ring.AnchorPoint.Y)
	end
end

local function playSlot(i: number)
	local id = wheel()[i]
	if id and id ~= "" then
		UI.close()
		EmoteController.play(id)
	else
		nextTab = "mine"
		selSlot = i
		UI.open("Emotes")
	end
end

-- show a tab of the Emotes panel ("mine" | "crate"); opens the panel if it's closed
function EmoteController.showTab(t: string)
	if UI.openName() ~= "Emotes" then
		nextTab = t
		UI.open("Emotes")
		return
	end
	setTab(t)
	EmoteController.refresh()
end

function EmoteController.toggleWheel()
	if UI.openName() == "EmoteWheel" then
		UI.close()
		return
	end
	if inMatch() then return end
	UI.open("EmoteWheel")
end

-- ===== the reel =====

local function glowOnly(id: string?)
	for eid, c in pairs(oddsCards) do show(c:FindFirstChild("Glow"), eid == id) end
	if id and oddsCards[id] then
		local c = oddsCards[id]
		local sc = c.Parent
		if sc and sc:IsA("ScrollingFrame") then
			local y = c.Position.Y.Offset - sc.AbsoluteSize.Y / 2 + c.Size.Y.Offset / 2
			sc.CanvasPosition = Vector2.new(0, math.max(0, y))
		end
	end
end

local function revealShown(on: boolean)
	if not panel then return end
	show(find(panel, "Reveal"), on)
	for _, n in ipairs({ "TabMine", "TabCrate", "WheelHint" }) do show(find(panel, n), not on) end
	if on then
		show(find(panel, "MinePage"), false)
		show(find(panel, "CratePage"), false)
	else
		setTab(tab)
	end
end

local function showReveal(t: any)
	local e = EmoteConfig.get(t.emote)
	if not e or not panel then return end
	local rv = find(panel, "Reveal")
	if not rv then return end
	local col = rarityColour(e)
	setText(rv, "EmoteName", e.name)
	setText(rv, "Rarity", EmoteConfig.RARITY[e.rarity].name)
	tint(find(rv, "Rarity"), col)
	setText(rv, "Song", if e.song then ("Song: " .. e.song) else "")
	if t.dupe then
		setText(rv, "Title", "DUPLICATE")
		setText(rv, "Sub", ("+%d GEMS REFUNDED"):format(t.refund or 0))
	else
		setText(rv, "Title", if e.rarity == "legendary" then "LEGENDARY EMOTE!" else "NEW EMOTE!")
		setText(rv, "Sub", "ADDED TO MY EMOTES")
	end
	revealShown(true)
	attachPreview(find(rv, "View"), e.id, 9)
	Sound.play(if e.rarity == "legendary" or e.rarity == "epic" then "evolve" else "reward")
	local card = find(rv, "Card")
	if card and card:IsA("GuiObject") then
		local s = card.Size
		card.Size = UDim2.fromOffset(s.X.Offset * 0.75, s.Y.Offset * 0.75)
		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = s }):Play()
	end
	local pn = find(rv, "PlayNow")
	if pn then pn:SetAttribute("Emote", e.id) end
end

local function runReel()
	local ids = {}
	for _, e in ipairs(EmoteConfig.LIST) do table.insert(ids, e.id) end
	local last = nil
	local function hop(delay: number, id: string?)
		local pick = id
		if not pick then
			repeat
				pick = ids[math.random(1, #ids)]
			until pick ~= last
		end
		last = pick
		glowOnly(pick)
		Sound.play("tick", 0.9 + math.random() * 0.3)
		task.wait(delay)
	end
	local t0 = os.clock()
	while (pendingResult == nil or os.clock() - t0 < 1.1) and os.clock() - t0 < 8 do hop(0.07) end
	local res = pendingResult
	pendingResult = nil
	if not res or not res.ok then
		glowOnly(nil)
		rolling = false
		refreshCrate()
		return
	end
	for _, d in ipairs({ 0.09, 0.12, 0.16, 0.21, 0.28, 0.36 }) do hop(d) end
	hop(0.7, res.emote)
	glowOnly(nil)
	rolling = false
	if UI.openName() == "Emotes" then
		showReveal(res)
	else
		local e = EmoteConfig.get(res.emote)
		UI.toast(if res.dupe then ("Duplicate %s: +%d Gems"):format(e and e.name or "emote", res.refund or 0) else ("New emote: %s!"):format(e and e.name or "?"), "reward")
	end
	refreshCrate()
end

local function openCrate()
	if rolling then return end
	local gems = if profile then profile.gems or 0 else 0
	if gems < EmoteConfig.CRATE_GEMS then
		return UI.toast(("Not enough Gems: a crate is %d"):format(EmoteConfig.CRATE_GEMS), "warn")
	end
	rolling = true
	pendingResult = nil
	refreshCrate()
	Net.event("RequestOpenCrate"):FireServer()
	task.spawn(runReel)
end

-- ===== init =====

local function onClick(b: Instance?, fn: () -> ())
	if b and b:IsA("GuiButton") then UI.juicy(b, fn) end
end

local function wire(root: Instance)
	local scr = root:FindFirstChild("Emotes")
	panel = scr and scr:FindFirstChild("Emotes")
	local ws = root:FindFirstChild("EmoteWheel")
	wheelScreen = ws and ws:FindFirstChild("Wheel")
	if panel then
		onClick(find(panel, "TabMine"), function() setTab("mine"); EmoteController.refresh() end)
		onClick(find(panel, "TabCrate"), function() setTab("crate"); EmoteController.refresh() end)
		onClick(find(panel, "GoCrate"), function() setTab("crate"); EmoteController.refresh() end)
		onClick(find(panel, "BtnOpen"), openCrate)
		onClick(find(panel, "BtnPoor"), function()
			local gems = if profile then profile.gems or 0 else 0
			if UI.offerGems and UI.offerGems(EmoteConfig.CRATE_GEMS - gems, "an Emote Crate") then return end
			UI.toast(("Not enough Gems: a crate is %d"):format(EmoteConfig.CRATE_GEMS), "warn")
		end)
		onClick(find(panel, "Done"), function() revealShown(false); EmoteController.refresh() end)
		onClick(find(panel, "PlayNow"), function()
			local pn = find(panel, "PlayNow")
			local id = pn and pn:GetAttribute("Emote")
			revealShown(false)
			UI.close()
			if type(id) == "string" then EmoteController.play(id) end
		end)
		local wl = find(panel, "Wheel")
		for i = 1, 6 do
			local s = wl and wl:FindFirstChild("WSlot" .. i)
			onClick(s, function() selSlot = i; Sound.play("click"); refreshMine() end)
			onClick(find(s, "BtnClear"), function()
				local w = wheel()
				w[i] = ""
				selSlot = i
				sendWheel(w)
				EmoteController.refresh()
			end)
		end
		show(find(panel, "Reveal"), false)
		local close = find(scr, "CloseButton")
		onClick(close, function() UI.close() end)
	end
	if wheelScreen then
		-- the wheel's backing and centre disc exported as soft glow blobs that vanish on a dark scene:
		-- make them solid circles (dark translucent ring behind the slots, a rimmed disc in the middle)
		for _, g in ipairs(wheelScreen:GetChildren()) do
			if g:IsA("ImageLabel") and g.Name == "Glow" then
				local disc = g.Size.X.Offset < 400
				g.BackgroundColor3 = g.ImageColor3
				g.BackgroundTransparency = if disc then 0 else 0.18
				g.Image = ""
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0.5, 0)
				c.Parent = g
				local st = Instance.new("UIStroke")
				st.Color = if disc then Color3.fromRGB(5, 5, 6) else Color3.new(1, 1, 1)
				st.Transparency = if disc then 0 else 0.85
				st.Thickness = if disc then 4 else 3
				st.Parent = g
			end
		end
		for i = 1, 6 do
			local s = wheelScreen:FindFirstChild("Slot" .. i)
			onClick(s, function() playSlot(i) end)
			if s and s:IsA("GuiButton") then
				s.MouseEnter:Connect(function() hovered = i; wheelInfo(i) end)
				s.SelectionGained:Connect(function() hovered = i; wheelInfo(i) end)
			end
		end
		onClick(find(wheelScreen, "BtnStop"), function() EmoteController.stop(); UI.close() end)
		onClick(find(wheelScreen, "BtnGet"), function() nextTab = "crate"; UI.open("Emotes") end)
		local mine = find(wheelScreen, "BtnMine")
		if mine then
			mine:SetAttribute("Opens", nil)
			mine:SetAttribute("OpensVia", nil)
			onClick(mine, function() nextTab = "mine"; UI.open("Emotes") end)
		end
		onClick(find(ws, "CloseButton"), function() UI.close() end)
		local dim = ws and ws:FindFirstChild("Dim")
		local f = dim and dim:FindFirstChild("F")
		if f and f:IsA("GuiObject") then
			f.Active = true
			f.InputBegan:Connect(function(input)
				if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and UI.openName() == "EmoteWheel" then
					UI.close()
				end
			end)
		end
	end
	-- the rail's EMOTES button opens the wheel (like G; phones have no G key); the wheel's MY EMOTES opens the panel
	local hud = root:FindFirstChild("HUD")
	local eb = hud and hud:FindFirstChild("EmotesButton", true)
	if eb then eb:SetAttribute("OpensVia", "EmoteWheel") end
	local edim = scr and scr:FindFirstChild("Dim")
	local ef = edim and edim:FindFirstChild("F")
	if ef and ef:IsA("GuiObject") then
		ef.Active = true
		ef.InputBegan:Connect(function(input)
			if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and UI.openName() == "Emotes" and not rolling then
				UI.close()
			end
		end)
	end
end

function EmoteController.init()
	task.spawn(function()
		local ok, info = false, nil
		for attempt = 1, 3 do
			ok, info = pcall(function()
				return PolicyService:GetPolicyInfoForPlayerAsync(player)
			end)
			if ok then break end
			task.wait(attempt)
		end
		crateBlocked = not ok or (type(info) == "table" and info.ArePaidRandomItemsRestricted == true)
		if crateBlocked then EmoteController.refresh() end
	end)
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("EOSUI", 30)
	local root = gui and gui:WaitForChild("Root", 10)
	if root then wire(root) end
	UI.onEmotesRefresh = function(view: any)
		profile = view
		defaultWheel()
		EmoteController.refresh()
	end
	UI.onOpen = UI.onOpen or {}
	UI.onOpen.Emotes = function()
		revealShown(false)
		setTab(nextTab or (if #ownedList() == 0 then "crate" else "mine"))
		nextTab = nil
		EmoteController.refresh()
	end
	UI.onOpen.EmoteWheel = function()
		EmoteController.refresh()
		hovered = 0
		wheelInfo(0)
	end
	Net.event("CrateResult").OnClientEvent:Connect(function(t)
		if type(t) == "table" then pendingResult = t end
	end)
	-- G opens the wheel; 1-6 play a slot while it's open
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.G then
			EmoteController.toggleWheel()
		elseif UI.openName() == "EmoteWheel" then
			local n = ({ [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6 })[input.KeyCode]
			if n then playSlot(n) end
		end
	end)
	if player.Character then watchOwn(player.Character) end
	player.CharacterAdded:Connect(function(c)
		watchOwn(c)
		previewRig = nil -- your avatar may have changed
	end)
	RunService.Heartbeat:Connect(function()
		stepOwn()
		stepPreviews()
	end)
	for _, plr in ipairs(Players:GetPlayers()) do watchPlayer(plr) end
	Players.PlayerAdded:Connect(watchPlayer)
	setTab("mine")
end

return EmoteController
