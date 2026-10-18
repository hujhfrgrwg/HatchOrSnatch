--!strict
-- EmoteShowcase (client), HOS-EMOTE-002 (Matthew, 18 Oct): "Using the obelisk podium, let's have it be a rig for cycling
-- through all the emotes. we can have it be it's own player as a ghost (forcefield) purple and have a beam below it kinda
-- as if it's showing a hologram projection light from the ground."
--  * Any podium tagged HOS_EmoteShowcase (the Obelisk podium, HOS-POD-001) shows a copy of YOUR avatar as a purple
--    ForceField hologram on its StandGlow.RigStand, facing the way the podium's Dummy faces, playing every emote in
--    EmoteConfig.LIST in order (published ids, so live too). A looping emote shows for about one or two loops (4-9 s),
--    a once-only emote plays through. Emotes that mime a prop get their light construct (EmoteFX, via EOS_Emote on the
--    copy, the way the results podium does it). No songs: only players and lobby NPCs carry those.
--  * The projector: a soft cone of purple light from the podium's glow disc, fading out by the chest (two camera-facing
--    Beams, kept dim so the figure reads through them), specks drifting up and a soft light. Each body part and accessory
--    has its own purple Highlight (outline + a fairly solid fill), so every limb and hat is outlined, not just the
--    silhouette; at most GLOW_MAX of them (Roblox draws 31 Highlights at once), off while the showcase rests (in a match
--    the game's outlines need them). It floats a little above the disc with a slow bob,
--    flickers now and then, and between emotes it sucks down into the projector and grows back out of it.
--  * A sign above shows the emote's name in its rarity colour.
--  * The copy is built like the lobby pedestals' (WeaponPedestals.makeAvatarTemplate), then turned to a hologram:
--    clothes, faces and surface looks off, every part ForceField in the hologram colour.
--  * Looks only, nothing goes to the server. Rests while LobbyGate says the lobby isn't in use or you're far away.
--   EmoteShowcase.start()   WeaponFXBoot, once

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EmoteConfig = require(Shared:WaitForChild("EmoteConfig"))
local LobbyGate = require(script.Parent:WaitForChild("LobbyGate")) -- HOS-LOBBY-004
local WeaponPedestals = require(script.Parent:WaitForChild("WeaponPedestals")) :: any
local EmoteFX = require(script.Parent:WaitForChild("EmoteFX")) :: any

local EmoteShowcase = {}

local TAG = "HOS_EmoteShowcase"
local SCAN_EVERY = 1 -- seconds between looks for podiums and dummies (streaming can bring either back)
local GHOST = Color3.fromRGB(176, 98, 255) -- the hologram's purple
local BEAM_TOP = 5.2 -- studs above the stand where the light cone fades out (about the chest)
local SIGN_UP = 7.4 -- studs from the stand to the sign
local SHOW_MIN, SHOW_TARGET, SHOW_MAX = 4, 5.5, 9 -- seconds a looping emote shows (whole loops, about SHOW_TARGET)
local ONCE_HOLD = 0.6 -- after a once-only emote ends
local LOAD_WAIT = 6 -- seconds to wait for a clip to load before skipping it
local HOVER, BOB, BOB_SPEED = 0.9, 0.15, 1.6 -- studs it floats above the disc, bob height, bob speed (radians/s)
local SUCK_IN, SUCK_OUT, MIN_SCALE = 0.22, 0.3, 0.05 -- seconds down into the projector and back out; scale at the bottom
local GLOW_MAX = 16 -- per-part Highlights at most: the body first, then the biggest accessories

type Show = {
	podium: Model,
	stand: CFrame?,
	dummy: Model?,
	avatar: Model?,
	parts: { BasePart },
	idx: number, -- which emote of the list
	track: AnimationTrack?,
	tracks: { [string]: AnimationTrack },
	t: number, -- seconds into this emote
	len: number?, -- how long this emote shows (nil until its clip has loaded)
	nextFlicker: number,
	flickerUntil: number,
	lift: number, -- studs from the feet to the root at full size
	glows: { Highlight },
	glowOn: boolean,
	scale: number,
	swap: string?, -- "in" (sucking down) / "out" (growing back) between emotes
	swapT: number,
	projector: BasePart?,
	sign: BillboardGui?,
}

local shows: { [Model]: Show } = {}
local avatarTpl: Model? = nil
local folder: Folder? = nil
local started = false
local player = Players.LocalPlayer

local function holder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "HOS_EmoteShowcase" -- this client's hologram, projector and sign (never replicated)
	f.Parent = workspace
	folder = f
	return f
end

-- ===== the hologram

local function ghostify(av: Model): { BasePart }
	local parts = {}
	for _, d in av:GetDescendants() do
		if d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance")
			or d:IsA("BodyColors") then
			d:Destroy()
		elseif d:IsA("SpecialMesh") then
			d.TextureId = "" -- (the field takes the part's colour instead of the texture)
		end
	end
	for _, d in av:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Material = Enum.Material.ForceField
			d.Color = GHOST
			d.Transparency = 0
			d.CastShadow = false
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
			table.insert(parts, d)
		end
	end
	return parts
end

local function setFade(s: Show, a: number)
	for _, p in s.parts do
		p.LocalTransparencyModifier = a
	end
end

local function buildProjector(s: Show)
	if s.projector and s.projector.Parent then
		return
	end
	local stand = s.stand :: CFrame
	local base = Instance.new("Part")
	base.Name = "HologramProjector"
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.Transparency = 1
	base.Size = Vector3.new(2, 0.1, 2) -- the specks rise from this disc
	base.CFrame = stand + Vector3.new(0, 0.08, 0)
	local a0 = Instance.new("Attachment")
	a0.Name = "Floor"
	a0.Parent = base
	local a1 = Instance.new("Attachment")
	a1.Name = "Top"
	a1.Position = Vector3.new(0, BEAM_TOP, 0)
	a1.Parent = base
	-- the cone: a wide soft beam and a brighter core, both fading out toward the top
	local function beam(name: string, w0: number, w1: number, t0: number, b: number)
		local bm = Instance.new("Beam")
		bm.Name = name
		bm.Attachment0, bm.Attachment1 = a0, a1
		bm.Width0, bm.Width1 = w0, w1
		bm.FaceCamera = true
		bm.LightEmission = 1
		bm.LightInfluence = 0
		bm.Brightness = b
		bm.Color = ColorSequence.new(GHOST:Lerp(Color3.new(1, 1, 1), 0.25), GHOST)
		bm.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, t0),
			NumberSequenceKeypoint.new(0.55, (t0 + 1) / 2),
			NumberSequenceKeypoint.new(1, 1),
		})
		bm.Segments = 8
		bm.Parent = base
	end
	beam("Cone", 2.4, 3.8, 0.82, 1)
	beam("Core", 1.2, 1.9, 0.74, 1.2)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Specks"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(GHOST:Lerp(Color3.new(1, 1, 1), 0.4))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.EmissionDirection = Enum.NormalId.Top
	e.Speed = NumberRange.new(1.2, 2.6)
	e.Lifetime = NumberRange.new(1.6, 2.6)
	e.Rate = 7
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = base
	local light = Instance.new("PointLight")
	light.Color = GHOST
	light.Brightness = 1.4
	light.Range = 10
	light.Parent = a1
	base.Parent = holder()
	-- the sign
	local a = Instance.new("Attachment")
	a.Name = "SignAt"
	a.Position = Vector3.new(0, SIGN_UP, 0)
	a.Parent = base
	local g = Instance.new("BillboardGui")
	g.Name = "EmoteShowcaseSign"
	g.Size = UDim2.fromScale(7, 1)
	g.LightInfluence = 0
	g.MaxDistance = 90
	g.ResetOnSpawn = false
	local t = Instance.new("TextLabel")
	t.Name = "EmoteName"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold) -- the game's UI face
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.TextStrokeColor3 = Color3.fromRGB(20, 12, 30)
	t.Text = ""
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 40
	c.Parent = t
	t.Parent = g
	g.Adornee = a
	g.Parent = base
	s.projector, s.sign = base, g
end

local function setSign(s: Show, e: any)
	local g = s.sign
	local t = g and g:FindFirstChild("EmoteName") :: TextLabel?
	if not t then
		return
	end
	local r = EmoteConfig.RARITY and EmoteConfig.RARITY[e.rarity]
	t.Text = e.name
	t.TextColor3 = (r and (r.color or r.colour)) or Color3.new(1, 1, 1)
end

-- ===== the emotes

local function trackFor(s: Show, e: any): AnimationTrack?
	if s.tracks[e.id] then
		return s.tracks[e.id]
	end
	local hum = s.avatar and s.avatar:FindFirstChildOfClass("Humanoid")
	if not hum or e.animId == nil or e.animId == "" then
		return nil
	end
	local an = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	an.Parent = hum
	local a = Instance.new("Animation")
	a.Name = e.id
	a.AnimationId = "rbxassetid://" .. tostring(e.animId)
	local ok, t = pcall(function()
		return an:LoadAnimation(a)
	end)
	if not ok or not t then
		return nil
	end
	t.Priority = Enum.AnimationPriority.Action4
	t.Looped = not e.once
	s.tracks[e.id] = t
	return t
end

local function playEmote(s: Show)
	local list = EmoteConfig.LIST
	if #list == 0 or not s.avatar then
		return
	end
	s.idx = (s.idx - 1) % #list + 1
	local e = list[s.idx]
	if s.track then
		s.track:Stop(0.15)
	end
	s.track = trackFor(s, e)
	s.t, s.len = 0, nil
	if s.track then
		s.track:Play(0.15)
	end
	-- the prop construct (EmoteFX reads EOS_Emote off the character)
	s.avatar:SetAttribute("EOS_Emote", e.id)
	pcall(EmoteFX.update, s.avatar)
	setSign(s, e)
	trackFor(s, list[s.idx % #list + 1]) -- (loading the next clip now, so it starts on time)
end

local function buildAvatar(s: Show)
	if s.avatar then
		pcall(EmoteFX.clear, s.avatar, true)
		s.avatar:Destroy()
		s.avatar = nil
	end
	table.clear(s.tracks)
	s.track = nil
	local stand = s.stand
	local tpl = avatarTpl or (s.dummy and WeaponPedestals.makeAvatarTemplate(s.dummy))
	if not stand or not tpl then
		return
	end
	local av = if tpl == avatarTpl then tpl:Clone() else tpl
	av.Name = "EmoteHologram"
	local root = av:FindFirstChild("HumanoidRootPart") :: BasePart
	local torso = av:FindFirstChild("Torso") :: BasePart?
	local leg = av:FindFirstChild("Left Leg") :: BasePart?
	local lift = if torso and leg then leg.Size.Y + torso.Size.Y / 2 else 3 -- R6: a leg and half a torso
	root.Anchored = true
	root.CFrame = stand + Vector3.new(0, lift, 0)
	s.lift, s.scale = lift, 1
	s.parts = ghostify(av)
	-- one Highlight per part (Matthew: every body part and accessory outlined, not just the whole figure)
	local order = table.clone(s.parts)
	table.sort(order, function(a, b)
		local ab, bb = a.Parent == av, b.Parent == av -- (body parts sit straight in the model, accessory handles don't)
		if ab ~= bb then
			return ab
		end
		return a.Size.Magnitude > b.Size.Magnitude
	end)
	s.glows = {}
	for i = 1, math.min(#order, GLOW_MAX) do
		local hl = Instance.new("Highlight")
		hl.Name = "HologramGlow"
		hl.Adornee = order[i]
		hl.FillColor = GHOST
		hl.FillTransparency = 0.35 -- (Matthew: the bare field read too see-through)
		hl.OutlineColor = GHOST:Lerp(Color3.new(1, 1, 1), 0.45)
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Enabled = s.glowOn
		hl.Parent = order[i]
		table.insert(s.glows, hl)
	end
	av.Parent = holder()
	s.avatar = av
	local hum = av:FindFirstChildOfClass("Humanoid")
	if hum then
		local an = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		an.Parent = hum
	end
	buildProjector(s)
	playEmote(s)
	s.swap, s.swapT = "out", 0 -- (it grows up out of the projector)
end

local function setScale(s: Show, k: number)
	local av = s.avatar
	if av and math.abs(av:GetScale() - k) > 0.001 then
		pcall(function()
			av:ScaleTo(k)
		end)
	end
	s.scale = k
end

-- the figure floats over the disc and bobs; shrunk (between emotes) it sinks into the projector
local function place(s: Show, now: number)
	local root = s.avatar and s.avatar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local stand = s.stand
	if root and stand then
		local up = HOVER + math.sin(now * BOB_SPEED) * BOB
		root.CFrame = stand + Vector3.new(0, (up + s.lift) * s.scale, 0)
	end
end

local function setGlow(s: Show, on: boolean)
	if s.glowOn == on then
		return
	end
	s.glowOn = on
	for _, hl in s.glows do
		hl.Enabled = on
	end
end

local function update(s: Show, dt: number, now: number)
	if not s.avatar then
		return
	end
	if s.swap == "in" then
		-- sucking down into the projector; the next emote starts at the bottom
		s.swapT += dt
		local a = math.min(1, s.swapT / SUCK_IN)
		setScale(s, 1 - (1 - MIN_SCALE) * a * a)
		setFade(s, 0.4 * a)
		if a >= 1 then
			s.idx += 1
			playEmote(s)
			s.swap, s.swapT = "out", 0
		end
		place(s, now)
		return
	elseif s.swap == "out" then
		-- growing back up out of it
		s.swapT += dt
		local a = math.min(1, s.swapT / SUCK_OUT)
		local k = 1 - (1 - a) * (1 - a)
		setScale(s, MIN_SCALE + (1 - MIN_SCALE) * k)
		setFade(s, 0.4 * (1 - a))
		if a >= 1 then
			s.swap = nil
		end
	end
	s.t += dt
	local e = EmoteConfig.LIST[s.idx]
	local t = s.track
	if not s.len then
		if t and t.Length > 0 then
			-- (counted from now: the clip only starts moving once it has loaded)
			if e and e.once then
				s.len = s.t + t.Length + ONCE_HOLD
			else
				local loops = math.max(1, math.floor(SHOW_TARGET / t.Length + 0.5))
				s.len = s.t + math.clamp(t.Length * loops, SHOW_MIN, SHOW_MAX)
			end
		elseif s.t >= LOAD_WAIT then
			s.len = 0 -- (a clip that won't load: on to the next)
		end
	end
	if not s.swap then
		if s.len and s.t >= s.len then
			s.swap, s.swapT = "in", 0
		end
		-- the hologram flickers now and then
		if now >= s.nextFlicker then
			s.nextFlicker = now + 2.5 + math.random() * 3
			s.flickerUntil = now + 0.07
		end
		setFade(s, if now < s.flickerUntil then 0.4 else 0)
	end
	place(s, now)
end

-- ===== podiums

local function refresh(s: Show)
	local p = s.podium
	local dummy = p:FindFirstChild("Dummy")
	local dr = dummy and dummy:FindFirstChild("HumanoidRootPart")
	if not s.stand then
		local glow = p:FindFirstChild("StandGlow")
		local att = glow and glow:FindFirstChild("RigStand")
		local at = if att and att:IsA("Attachment") then att.WorldPosition
			elseif dr and dr:IsA("BasePart") then dr.Position - Vector3.new(0, 3, 0)
			else nil
		if at then
			local look = if dr and dr:IsA("BasePart") then dr.CFrame.LookVector else LobbyGate.centre() - at
			look = Vector3.new(look.X, 0, look.Z)
			s.stand = CFrame.lookAt(at, at + (if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)))
		end
	end
	if s.stand and dummy and dummy:IsA("Model") then
		s.dummy = dummy
		dummy.Parent = nil -- (this client only; the place keeps it)
	end
	if s.stand and not s.avatar then
		buildAvatar(s)
	end
end

local function add(p: Instance)
	if not p:IsA("Model") or shows[p] then
		return
	end
	local s: Show = {
		podium = p, stand = nil, dummy = nil, avatar = nil, parts = {}, idx = 1, track = nil, tracks = {}, t = 0,
		len = nil, nextFlicker = 0, flickerUntil = 0, lift = 3, glows = {}, glowOn = true, scale = 1, swap = nil, swapT = 0, projector = nil,
		sign = nil,
	}
	shows[p] = s
	refresh(s)
end

local function remove(p: Instance)
	local s = shows[p :: Model]
	if not s then
		return
	end
	shows[p :: Model] = nil
	if s.avatar then
		pcall(EmoteFX.clear, s.avatar, true)
		s.avatar:Destroy()
	end
	if s.projector then
		s.projector:Destroy()
	end
end

function EmoteShowcase.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		-- your look: taken once your character has loaded, again on every new character (outfit changes)
		local function takeLook(char: Model)
			local t0 = os.clock()
			while not player:HasAppearanceLoaded() and os.clock() - t0 < 4 do
				task.wait(0.2)
			end
			task.wait(0.5)
			if char.Parent == nil then
				return
			end
			local tpl = WeaponPedestals.makeAvatarTemplate(char)
			if tpl then
				if avatarTpl then
					avatarTpl:Destroy()
				end
				avatarTpl = tpl
				for _, s in shows do
					buildAvatar(s)
				end
			end
		end
		player.CharacterAdded:Connect(function(c)
			task.spawn(takeLook, c)
		end)
		if player.Character then
			task.spawn(takeLook, player.Character)
		end
		CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
		for _, p in CollectionService:GetTagged(TAG) do
			add(p)
		end
		local lastScan = os.clock()
		RunService.Heartbeat:Connect(function(dt)
			if not LobbyGate.active() then
				for _, s in shows do
					setGlow(s, false) -- (the match's outlines need the Highlight budget)
				end
				return -- HOS-LOBBY-004: rests in a match and while the camera is away from the lobby
			end
			local now = os.clock()
			if now - lastScan >= SCAN_EVERY then
				lastScan = now
				for _, p in CollectionService:GetTagged(TAG) do
					add(p)
				end
				for _, s in shows do
					refresh(s)
				end
			end
			for _, s in shows do
				setGlow(s, true)
				local stand = s.stand
				if stand and LobbyGate.near(stand.Position, LobbyGate.ANIM_RANGE) then
					update(s, math.min(dt, 0.1), now)
				end
			end
		end)
	end)
end

return EmoteShowcase
