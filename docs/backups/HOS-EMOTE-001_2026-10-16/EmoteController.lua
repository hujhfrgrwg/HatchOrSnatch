-- EmoteController: the Emotes panel (Emote Crate odds board + reel, My Emotes) and emote playback.
--  * your emote: the server confirms by setting your character's EOS_Emote; this plays the clip on
--    your Animator (it replicates) and stops it the moment you move or jump
--  * every character with EOS_Emote set gets its song as a 3D sound at its root (heard nearby)
-- Odds, prices, songs: Shared/EmoteConfig. Clips: ReplicatedStorage.EOS_Emotes (Studio fallback).

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EOS = ReplicatedStorage:WaitForChild("EOS")
local Shared = EOS:WaitForChild("Shared")
local EmoteConfig = require(Shared:WaitForChild("EmoteConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Theme = require(EOS:WaitForChild("UI"):WaitForChild("Theme"))
local UIKit = require(EOS.UI:WaitForChild("UIKit"))

local Sound = require(script.Parent.Sound)
local UI = require(script.Parent.UIController)

local EmoteController = {}

local player = Players.LocalPlayer
local panel: Frame
local body: Frame
local tab = "crate"
local wasOpen = false
local profile: any = nil
local oddsCards: { [string]: Frame } = {}
local mineSig = ""
local rolling = false
local pendingResult: any = nil

-- ===== clip ids =====

local idCache: { [string]: string } = {}
local function clipId(id: string): string?
	local e = EmoteConfig.get(id)
	if not e then
		return nil
	end
	if e.animId ~= nil and e.animId ~= "" then
		return "rbxassetid://" .. tostring(e.animId)
	end
	if idCache[id] then
		return idCache[id]
	end
	if not RunService:IsStudio() then
		warn("[EOS] emote '" .. id .. "' has no published animation id yet (Shared/EmoteConfig)")
		return nil
	end
	local lib = ReplicatedStorage:FindFirstChild(EmoteConfig.LIBRARY)
	local seq = lib and lib:FindFirstChild(id)
	if not seq then
		return nil
	end
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
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local cid = clipId(id)
	if not animator or not cid then
		return
	end
	local a = Instance.new("Animation")
	a.AnimationId = cid
	local t = animator:LoadAnimation(a)
	t.Priority = Enum.AnimationPriority.Action4
	t.Looped = true
	t:Play(0.2)
	track = t
	trackId = id
	startedAt = os.clock()
end

function EmoteController.play(id: string)
	if player:GetAttribute("EOS_InMatch") == true then
		return UI.toast("Emotes play in the lobby", "info")
	end
	Net.event("RequestEmote"):FireServer(id)
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
	if not track then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
		return stopTrack()
	end
	if os.clock() - startedAt < 0.3 then
		return
	end
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
	if not root then
		return
	end
	local old = root:FindFirstChild("EOS_EmoteMusic")
	local id = char:GetAttribute("EOS_Emote")
	local e = type(id) == "string" and EmoteConfig.get(id) or nil
	if not e or not e.music then
		if old then
			old:Destroy()
		end
		return
	end
	if old and old:GetAttribute("Emote") == id then
		return
	end
	if old then
		old:Destroy()
	end
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
	if plr.Character then
		watchCharacter(plr.Character)
	end
	plr.CharacterAdded:Connect(watchCharacter)
end

-- ===== live previews (a copy of your avatar doing each emote, inside each card's viewport) =====

local previewRig: Model? = nil
local previews: { { vp: ViewportFrame, track: AnimationTrack? } } = {}

local STRIP = { "LuaSourceContainer", "Sound", "BillboardGui", "SurfaceGui", "ParticleEmitter", "Trail", "Beam", "Highlight", "ForceField", "Tool", "ProximityPrompt", "ClickDetector" }

local function makeRig(): Model?
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return nil
	end
	local was = char.Archivable
	char.Archivable = true
	local ok, c = pcall(function()
		return char:Clone()
	end)
	char.Archivable = was
	if not ok or not c then
		return nil
	end
	for _, d in ipairs(c:GetDescendants()) do
		local kill = d.Name:sub(1, 4) == "EOS_"
		for _, cls in ipairs(STRIP) do
			if d:IsA(cls) then
				kill = true
			end
		end
		if d:IsA("Constraint") and not d:IsA("WeldConstraint") then
			kill = true -- movement drivers (LinearVelocity, AlignOrientation...)
		end
		if kill and d.Parent then
			d:Destroy()
		end
	end
	for k in pairs(c:GetAttributes()) do
		c:SetAttribute(k, nil)
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hum then
		c:Destroy()
		return nil
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	if not hum:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = hum
	end
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

-- put a looping preview of emote `id` into viewport `vp`; dist = camera distance in studs
local function attachPreview(vp: ViewportFrame, id: string, dist: number)
	if not previewRig then
		return
	end
	for _, ch in ipairs(vp:GetChildren()) do
		if ch:IsA("WorldModel") or ch:IsA("Camera") then
			ch:Destroy()
		end
	end
	for i = #previews, 1, -1 do
		if previews[i].vp == vp or not previews[i].vp.Parent then
			table.remove(previews, i)
		end
	end
	local wm = Instance.new("WorldModel")
	wm.Parent = vp
	local rig = previewRig:Clone()
	rig.Parent = wm
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	-- the rig faces -Z: stand the camera in front of it, a touch above the waist
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, -dist), Vector3.new(0, 0.15, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Ambient = Color3.fromRGB(205, 205, 212)
	vp.LightColor = Color3.fromRGB(255, 250, 240)
	vp.LightDirection = Vector3.new(0.4, -1, 0.8)
	local entry: { vp: ViewportFrame, track: AnimationTrack? } = { vp = vp, track = nil }
	table.insert(previews, entry)
	local cid = clipId(id)
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if cid and animator then
		local a = Instance.new("Animation")
		a.AnimationId = cid
		local ok, t = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok and t then
			t.Looped = true
			t.Priority = Enum.AnimationPriority.Action4
			t:Play(0)
			t.TimePosition = math.random() * math.max(0.1, t.Length * 0.5) -- not all in lockstep
			entry.track = t
		end
	end
end

-- previews only move while the Emotes panel is open
local previewsRunning = true
local function stepPreviews()
	local on = UI.openName() == "Emotes"
	if on == previewsRunning then
		return
	end
	previewsRunning = on
	for _, e in ipairs(previews) do
		if e.track then
			e.track:AdjustSpeed(if on then 1 else 0)
		end
	end
end

-- ===== panel =====

local function pct(n: number): string
	local s = string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
	return s .. "%"
end

local function owned(id: string): boolean
	return profile ~= nil and type(profile.emotes) == "table" and profile.emotes[id] == true
end

local function ownedCount(): number
	local n = 0
	for _, e in ipairs(EmoteConfig.LIST) do
		if owned(e.id) then
			n += 1
		end
	end
	return n
end

local function setTab(t: string)
	tab = t
	body.Crate.Visible = t == "crate"
	body.Mine.Visible = t == "mine"
	UIKit.setRamp(body.Tabs.CrateTab, if t == "crate" then "purple" else "grey")
	UIKit.setRamp(body.Tabs.MineTab, if t == "mine" then "blue" else "grey")
end

local function buildOdds()
	local grid = body.Crate.Grid
	local tpl = grid.OddsCard
	tpl.Visible = false
	for _, e in ipairs(EmoteConfig.LIST) do
		local r = EmoteConfig.RARITY[e.rarity]
		local c = tpl:Clone()
		c.Name = "Odds_" .. e.id
		c.LayoutOrder = r.order * 100 + e.order
		c.Visible = true
		c.Edge.Color = r.color
		c.Strip.BackgroundColor3 = r.color
		c.Strip.Square.BackgroundColor3 = r.color
		c.Rarity.Text = r.name .. "  ·  " .. pct(r.odds)
		c.EmoteName.Text = e.name
		c.Music.Visible = e.music ~= nil
		c.Glow.Visible = false
		c.Parent = grid
		oddsCards[e.id] = c
	end
end

local function refreshMine()
	local grid = body.Mine.Grid
	local sig = ""
	for _, e in ipairs(EmoteConfig.LIST) do
		sig ..= if owned(e.id) then "1" else "0"
	end
	if sig == mineSig then
		return
	end
	mineSig = sig
	for _, c in ipairs(grid:GetChildren()) do
		if c.Name:sub(1, 5) == "Mine_" then
			c:Destroy()
		end
	end
	local any = false
	for _, e in ipairs(EmoteConfig.LIST) do
		if owned(e.id) then
			any = true
			local r = EmoteConfig.RARITY[e.rarity]
			local c = grid.MineCard:Clone()
			c.Name = "Mine_" .. e.id
			c.LayoutOrder = -(r.order * 100) + e.order
			c.Visible = true
			c.Edge.Color = r.color
			c.Rarity.Text = r.name
			c.Rarity.TextColor3 = r.color
			c.EmoteName.Text = e.name
			c.Song.Text = e.song or ""
			c.Note.Visible = e.song ~= nil
			c.Parent = grid
			attachPreview(c.View, e.id, 9.5)
			UI.juicy(c.Play, function()
				UI.close()
				EmoteController.play(e.id)
			end)
		end
	end
	body.Mine.Empty.Visible = not any
	grid.Visible = any
end

local function refreshCrate()
	local gems = if profile then profile.gems or 0 else 0
	body.Wallet.Gems.Amount.Text = tostring(gems)
	body.Crate.Balance.Text = ("Your balance: %d gems  ·  Emotes you win join My Emotes"):format(gems)
	for id, c in pairs(oddsCards) do
		c.Owned.Visible = owned(id)
	end
	local open = body.Crate.Open
	open.Face.Label.Text = tostring(EmoteConfig.CRATE_GEMS)
	UIKit.setRamp(open, if gems >= EmoteConfig.CRATE_GEMS and not rolling then "green" else "grey")
	-- Robux openings show only once every one has a product id
	local robuxReady = true
	for _, r in ipairs(EmoteConfig.ROBUX) do
		if not r.productId then
			robuxReady = false
		end
	end
	body.Crate.Robux.Visible = robuxReady
end

local function onRefresh(view: any, isOpen: boolean)
	profile = view
	if not panel then
		return
	end
	if isOpen and not wasOpen then
		panel.Reveal.Visible = rolling and panel.Reveal.Visible
		panel.Body.Visible = true
		panel.Header.Visible = true
		panel.Close.Visible = true
		setTab(if ownedCount() > 0 and not rolling then "mine" else "crate")
		-- first open: copy your avatar once and start every card's preview
		if not previewRig then
			previewRig = makeRig()
			if previewRig then
				for id, c in pairs(oddsCards) do
					attachPreview(c.View, id, 9.5)
				end
				mineSig = ""
			end
		end
	end
	wasOpen = isOpen
	refreshCrate()
	refreshMine()
end

-- ===== the reel =====

local function glowOnly(id: string?)
	for eid, c in pairs(oddsCards) do
		c.Glow.Visible = eid == id
	end
end

local function showReveal(t: any)
	local e = EmoteConfig.get(t.emote)
	if not e then
		return
	end
	local r = EmoteConfig.RARITY[e.rarity]
	local rv = panel.Reveal
	rv.Card.Edge.Color = r.color
	rv.Card.Rarity.Text = r.name
	rv.Card.Rarity.TextColor3 = r.color
	rv.Card.EmoteName.Text = e.name
	rv.Card.Song.Text = if e.song then ("Song: " .. e.song) else ""
	rv.Burst.ImageColor3 = r.color
	if t.dupe then
		rv.Title.Text = "DUPLICATE"
		rv.Sub.Text = ("+%d GEMS REFUNDED"):format(t.refund or 0)
	else
		rv.Title.Text = if e.rarity == "legendary" then "LEGENDARY EMOTE!" else "NEW EMOTE!"
		rv.Sub.Text = "ADDED TO MY EMOTES"
	end
	panel.Body.Visible = false
	panel.Header.Visible = false
	panel.Close.Visible = false
	rv.Visible = true
	attachPreview(rv.Card.View, e.id, 9)
	Sound.play(if e.rarity == "legendary" or e.rarity == "epic" then "evolve" else "reward")
	local card = rv.Card
	card.Size = UDim2.fromOffset(330, 330)
	card:TweenSize(UDim2.fromOffset(440, 440), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.35, true)
	rv.PlayNow:SetAttribute("Emote", e.id)
end

local function runReel()
	local ids = {}
	for _, e in ipairs(EmoteConfig.LIST) do
		table.insert(ids, e.id)
	end
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
	while (pendingResult == nil or os.clock() - t0 < 1.1) and os.clock() - t0 < 8 do
		hop(0.07)
	end
	local res = pendingResult
	pendingResult = nil
	if not res or not res.ok then
		glowOnly(nil)
		rolling = false
		refreshCrate()
		return
	end
	for _, d in ipairs({ 0.09, 0.12, 0.16, 0.21, 0.28, 0.36 }) do
		hop(d)
	end
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
	if rolling then
		return
	end
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

function EmoteController.init()
	local menus = player:WaitForChild("PlayerGui"):WaitForChild("EOS_Menus")
	panel = menus:WaitForChild("Emotes"):WaitForChild("Panel")
	body = panel:WaitForChild("Body")
	panel.Reveal.Visible = false
	body.Mine.Grid.MineCard.Visible = false
	buildOdds()
	setTab("crate")
	UI.onEmotesRefresh = onRefresh
	local juicy = UI.juicy or function(b: GuiButton, f: () -> ())
		b.Activated:Connect(f)
	end
	juicy(body.Tabs.CrateTab, function()
		setTab("crate")
	end)
	juicy(body.Tabs.MineTab, function()
		setTab("mine")
	end)
	juicy(body.Mine.Empty.Go, function()
		setTab("crate")
	end)
	juicy(body.Crate.Open, openCrate)
	juicy(panel.Reveal.Done, function()
		panel.Reveal.Visible = false
		panel.Body.Visible = true
		panel.Header.Visible = true
		panel.Close.Visible = true
	end)
	juicy(panel.Reveal.PlayNow, function()
		local id = panel.Reveal.PlayNow:GetAttribute("Emote")
		panel.Reveal.Visible = false
		panel.Body.Visible = true
		panel.Header.Visible = true
		panel.Close.Visible = true
		UI.close()
		if type(id) == "string" then
			EmoteController.play(id)
		end
	end)
	Net.event("CrateResult").OnClientEvent:Connect(function(t)
		if type(t) == "table" then
			pendingResult = t
		end
	end)
	-- your character
	if player.Character then
		watchOwn(player.Character)
	end
	player.CharacterAdded:Connect(watchOwn)
	RunService.Heartbeat:Connect(function()
		stepOwn()
		stepPreviews()
	end)
	-- everyone's songs
	for _, plr in ipairs(Players:GetPlayers()) do
		watchPlayer(plr)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return EmoteController
