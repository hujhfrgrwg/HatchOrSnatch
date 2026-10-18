--!strict
-- WeaponShowcase (client), HOS-WEP-002 (Matthew, 18 Oct): "put the hallow's sword on the rig. Have the showcase of it be
-- the weapon equipped by the person's own avatar in the rig and have it loop through the jab animation, lunge animation,
-- and idle."
--  * Any podium tagged HOS_WeaponShowcase (the Halloween Harvest podium, HOS-POD-001) shows the skin in its ShowcaseSkin
--    attribute (rb_all_hallow_s_sword) held by a copy of YOUR avatar standing on its StandGlow.RigStand, facing the
--    way the podium's Dummy faces. The Dummy stays in the place to mark the spot in Studio; this client takes it out.
--  * The copy and the weapon come from WeaponPedestals (makeAvatarTemplate / wield), so WeaponFXBoot gives it the
--    Legendary slash and hand aura like the lobby pedestals. No R6 look to copy: the Dummy itself holds the weapon.
--  * Loop: idle, jab (SwingJab), a short idle, lunge (LungeStab), back to idle. LungeStab has no published id yet
--    (AnimConfig.ids.LungeStab = ""): Studio plays the local KeyframeSequence, a live server skips the lunge until the
--    clip is published and its id filled in.
--  * Looks only, nothing goes to the server. Rests while LobbyGate says the lobby isn't in use.
--   WeaponShowcase.start()   WeaponFXBoot, once

local CollectionService = game:GetService("CollectionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local AnimConfig = require(Shared:WaitForChild("AnimConfig"))
local LobbyGate = require(script.Parent:WaitForChild("LobbyGate")) -- HOS-LOBBY-004
local WeaponPedestals = require(script.Parent:WaitForChild("WeaponPedestals")) :: any

local WeaponShowcase = {}

local TAG = "HOS_WeaponShowcase"
local SCAN_EVERY = 1 -- seconds between looks for podiums and dummies (streaming can bring either back)
-- the loop: { clip, seconds to wait after it starts (a clip waits its own length plus this) }
local STEPS = {
	{ clip = "Idle", hold = 1.6 },
	{ clip = "SwingJab", hold = 0.25 },
	{ clip = "Idle", hold = 0.7 },
	{ clip = "LungeStab", hold = 0.45 },
}

type Show = {
	podium: Model,
	skin: string,
	stand: CFrame?, -- where the copy's root stands
	dummy: Model?, -- the podium's Dummy, out of the world on this client
	avatar: Model?,
	tracks: { [string]: AnimationTrack },
	step: number,
	nextAt: number,
}

local shows: { [Model]: Show } = {}
local avatarTpl: Model? = nil
local folder: Folder? = nil
local lungeId: string? = nil
local started = false
local player = Players.LocalPlayer

-- the lunge's id: published, else (Studio only) a temporary id for the local KeyframeSequence
local function resolveLunge(): string?
	local id = AnimConfig.ids.LungeStab
	if type(id) == "string" and id ~= "" then
		return id
	end
	if not RunService:IsStudio() then
		return nil
	end
	local lib = ReplicatedStorage:FindFirstChild(AnimConfig.LIBRARY)
	local seq = lib and lib:FindFirstChild("LungeStab")
	if not seq or not seq:IsA("KeyframeSequence") then
		return nil
	end
	local ok, res = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(seq)
	end)
	return if ok then res else nil
end

local function holder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "HOS_WeaponShowcase" -- this client's copies (never replicated)
	f.Parent = workspace
	folder = f
	return f
end

local function loadTracks(s: Show)
	local hum = s.avatar and s.avatar:FindFirstChildOfClass("Humanoid")
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
			s.tracks[key] = t
		end
	end
	load("Idle", AnimConfig.builtin and AnimConfig.builtin.Idle, Enum.AnimationPriority.Idle, true)
	load("SwingJab", AnimConfig.ids.SwingJab, Enum.AnimationPriority.Action, false)
	load("LungeStab", lungeId, Enum.AnimationPriority.Action2, false)
	if s.tracks.Idle then
		s.tracks.Idle:Play()
	end
end

local function buildAvatar(s: Show)
	if s.avatar then
		s.avatar:Destroy()
		s.avatar = nil
	end
	table.clear(s.tracks)
	local stand = s.stand
	local tpl = avatarTpl or (s.dummy and WeaponPedestals.makeAvatarTemplate(s.dummy))
	if not stand or not tpl then
		return
	end
	local av = if tpl == avatarTpl then tpl:Clone() else tpl
	av.Name = "ShowcaseAvatar"
	local root = av:FindFirstChild("HumanoidRootPart") :: BasePart
	local torso = av:FindFirstChild("Torso") :: BasePart?
	local leg = av:FindFirstChild("Left Leg") :: BasePart?
	-- R6: the root sits a leg and half a torso above the feet
	local lift = if torso and leg then leg.Size.Y + torso.Size.Y / 2 else 3
	root.Anchored = true
	root.CFrame = stand + Vector3.new(0, lift, 0)
	av.Parent = holder()
	s.avatar = av
	WeaponPedestals.wield(av, s.skin)
	loadTracks(s)
	s.step, s.nextAt = 1, os.clock() + STEPS[1].hold
end

-- the podium's stand and facing (the Dummy's, else toward the middle of the lobby), and the Dummy out of the world,
-- as they stream in
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
	local skin = p:GetAttribute("ShowcaseSkin")
	if type(skin) ~= "string" or skin == "" then
		return
	end
	local s: Show = { podium = p, skin = skin, stand = nil, dummy = nil, avatar = nil, tracks = {}, step = 1, nextAt = 0 }
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
		s.avatar:Destroy()
	end
end

-- one step of the loop: play its clip, wait its length plus its hold
local function advance(s: Show, now: number)
	s.step = s.step % #STEPS + 1
	local step = STEPS[s.step]
	local t = s.tracks[step.clip]
	if step.clip == "Idle" or not t then
		s.nextAt = now + (if t then step.hold else 0)
		return
	end
	t:Play(0.08)
	local len = if t.Length > 0 then t.Length else 0.8 -- (Length reads 0 until the clip has loaded)
	s.nextAt = now + len + step.hold
end

function WeaponShowcase.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		lungeId = resolveLunge()
		ReplicatedStorage:WaitForChild("EOS_KnifeSkinPreviews", 60)
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
		RunService.Heartbeat:Connect(function()
			if not LobbyGate.active() then
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
				if s.avatar and now >= s.nextAt then
					advance(s, now)
				end
			end
		end)
	end)
end

return WeaponShowcase
