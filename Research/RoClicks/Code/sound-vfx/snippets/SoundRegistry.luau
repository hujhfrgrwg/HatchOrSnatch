--!strict
-- SoundRegistry.luau: a generic sound registry + client player in one file.
-- In a real game, split it: the CONFIG table goes in ReplicatedStorage.Sounds (data only),
-- the rest in a client controller. Gameplay code only ever calls Sound.play("name", pos).
--
-- Features: groups (UI / SFX / Ambience / Music), stingers kept out of Music, per-name voice
-- limits and cooldowns, `supersedes` (one reward sound per moment), ducking, ambience beds on
-- layers, fallback ids for uploads that fail moderation, and LOUD warnings for unknown names.

local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

export type Entry = {
	id: string,              -- "" = not uploaded yet (silent, warns once)
	fallback: string?,       -- last known working id, used if `id` fails to preload
	volume: number,
	pitch: { number }?,      -- {min, max} random PlaybackSpeed
	group: string,           -- "UI" | "SFX" | "Ambience" | "Music"
	voices: number?,         -- max simultaneous copies of this name
	cooldown: number?,       -- min seconds between starts
	rolloff: { number }?,    -- {min, max} studs for 3D plays; beyond max = culled
	duck: { number }?,       -- {amount 0..1, seconds}
	layer: string?,          -- ambience beds: same layer replaces
	loop: boolean?,
	supersedes: { string }?, -- names this one replaces within SUPERSEDE_WINDOW
}

local CONFIG: { [string]: Entry } = {
	ui_click        = { id = "", volume = 0.5, group = "UI", voices = 2, cooldown = 0.03 },
	ui_reward       = { id = "", volume = 0.6, group = "UI", voices = 2, cooldown = 0.1 },
	ui_levelup      = { id = "", volume = 0.7, group = "UI", voices = 1, cooldown = 0.5, supersedes = { "ui_reward" } },
	cash_collect    = { id = "", volume = 0.6, pitch = { 0.95, 1.08 }, group = "SFX", voices = 3, cooldown = 0.05, rolloff = { 20, 250 } },
	explosion_large = { id = "", volume = 0.8, pitch = { 0.9, 1.05 }, group = "SFX", voices = 3, cooldown = 0.08, rolloff = { 60, 900 }, duck = { 0.3, 2 } },
	engine_loop     = { id = "", volume = 0.4, pitch = { 0.95, 1.05 }, group = "SFX", voices = 6, rolloff = { 30, 400 }, loop = true },
	-- stingers live in UI, NOT Music: muting music must not mute the win sound
	victory_fanfare = { id = "", volume = 0.8, group = "UI", voices = 1, cooldown = 1.0, duck = { 0.85, 4 } },
	defeat_sting    = { id = "", volume = 0.8, group = "UI", voices = 1, cooldown = 1.0, duck = { 0.85, 4 } },
	birds_ambience  = { id = "", fallback = "", volume = 0.4, group = "Ambience", layer = "weather", loop = true },
	rain_loop       = { id = "", volume = 0.45, group = "Ambience", layer = "weather", loop = true },
	music_home      = { id = "", volume = 0.4, group = "Music", loop = true },
}

local SUPERSEDE_WINDOW = 0.3
local ROOT_NAME = "RuntimeSounds"

local Sound = {}
Sound.CONFIG = CONFIG

type Voice = { s: Sound, t: number, dist: number, att: Attachment? }
local root: Folder? = nil
local groups: { [string]: SoundGroup } = {}
local active: { [string]: { Voice } } = {}
local lastStart: { [string]: number } = {}
local warned: { [string]: boolean } = {}
local badIds: { [string]: boolean } = {}
local beds: { [string]: { name: string, s: Sound } } = {}
local ducks: { { number } } = {}
local duckNow = 0

local function warnOnce(key: string, msg: string)
	if warned[key] then return end
	warned[key] = true
	warn("[Sound] " .. msg)
end

local function setup(): Folder
	if root and root.Parent then return root end
	-- a pool saved into the place by an edit-mode run would play in every server: replace it
	local old = SoundService:FindFirstChild(ROOT_NAME)
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = ROOT_NAME
	if not RunService:IsRunning() then f.Archivable = false end
	for _, n in { "UI", "SFX", "Ambience", "Music" } do
		local g = Instance.new("SoundGroup")
		g.Name = n
		g.Parent = f
		groups[n] = g
	end
	-- beds sit in child groups so ducking never touches the player's chosen volume
	for parentName, childName in { Music = "MusicBed", Ambience = "AmbienceBed" } do
		local g = Instance.new("SoundGroup")
		g.Name = childName
		g.Parent = groups[parentName]
		groups[childName] = g
	end
	f.Parent = SoundService
	root = f
	return f
end

local function entry(name: string): Entry?
	local e = CONFIG[name]
	if not e then
		local src, line = debug.info(3, "sl")
		warnOnce("unknown:" .. name, ("unknown sound name %q (called from %s:%s)"):format(name, tostring(src), tostring(line)))
	end
	return e
end

local function idOf(name: string, e: Entry): string?
	local id = e.id
	if (id == "" or badIds[id]) and e.fallback and e.fallback ~= "" then id = e.fallback end
	if id == "" then
		warnOnce("noid:" .. name, ("sound %q has no id yet (plays silent)"):format(name))
		return nil
	end
	return "rbxassetid://" .. id
end

local function listenerPos(): Vector3
	local cam = Workspace.CurrentCamera
	return cam and cam.CFrame.Position or Vector3.zero
end

local function bedGroup(e: Entry): SoundGroup
	if e.group == "Music" then return groups.MusicBed end
	if e.group == "Ambience" and e.loop then return groups.AmbienceBed end
	return groups[e.group] or groups.SFX
end

local function make(name: string, e: Entry, id: string, pos: Vector3?): (Sound, Attachment?)
	setup()
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = e.volume
	s.Looped = e.loop == true
	local p = e.pitch
	s.PlaybackSpeed = p and (p[1] + math.random() * (p[2] - p[1])) or 1
	s.SoundGroup = bedGroup(e)
	local att: Attachment? = nil
	if pos then
		att = Instance.new("Attachment")
		att.WorldPosition = pos
		att.Parent = Workspace.Terrain
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = e.rolloff and e.rolloff[1] or 10
		s.RollOffMaxDistance = e.rolloff and e.rolloff[2] or 300
		s.Parent = att
	else
		s.Parent = root
	end
	return s, att
end

local function finish(name: string, v: Voice)
	local list = active[name]
	if list then
		local i = table.find(list, v)
		if i then table.remove(list, i) end
	end
	v.s:Destroy()
	if v.att then v.att:Destroy() end
end

-- One-shot. `pos` = nil for 2D (UI) sounds. Returns the Sound or nil if skipped.
function Sound.play(name: string, pos: Vector3?, opts: { pitch: number?, volume: number? }?): Sound?
	local e = entry(name)
	if not e then return nil end
	local id = idOf(name, e)
	if not id then return nil end
	local now = os.clock()
	if e.cooldown and lastStart[name] and now - lastStart[name] < e.cooldown then return nil end
	-- supersedes: skip if something that replaces us just played; cut what we replace
	for other, oe in CONFIG do
		if oe.supersedes and table.find(oe.supersedes, name) and lastStart[other] and now - lastStart[other] < SUPERSEDE_WINDOW then
			return nil
		end
	end
	for _, victim in e.supersedes or {} do
		if lastStart[victim] and now - lastStart[victim] < SUPERSEDE_WINDOW then
			for _, v in table.clone(active[victim] or {}) do finish(victim, v) end
		end
	end
	local dist = 0
	if pos then
		dist = (listenerPos() - pos).Magnitude
		if dist > (e.rolloff and e.rolloff[2] or 300) then return nil end
	end
	local list = active[name] or {}
	active[name] = list
	if #list >= (e.voices or 6) then
		local worst: Voice? = nil
		for _, v in list do
			if not worst or v.dist + (now - v.t) * 0.01 > worst.dist + (now - worst.t) * 0.01 then worst = v end
		end
		if not worst or worst.dist < dist then return nil end -- all voices nearer: drop this one
		finish(name, worst)
	end
	local s, att = make(name, e, id, pos)
	if opts and opts.pitch then s.PlaybackSpeed *= opts.pitch end
	if opts and opts.volume then s.Volume *= opts.volume end
	local v: Voice = { s = s, t = now, dist = dist, att = att }
	table.insert(list, v)
	lastStart[name] = now
	s.Ended:Once(function() finish(name, v) end)
	s:Play()
	if e.duck then table.insert(ducks, { e.duck[1], now + e.duck[2] }) end
	return s
end

-- Looping 3D sound on a part (engines). ALWAYS call handle.stop() when the owner DIES, not only on despawn.
function Sound.loop(name: string, parent: BasePart | Attachment)
	local e = entry(name)
	local id = e and idOf(name, e)
	local s: Sound? = nil
	if e and id then
		s = make(name, e, id, nil)
		local snd = s :: Sound
		snd.Looped = true
		snd.RollOffMode = Enum.RollOffMode.InverseTapered
		snd.RollOffMinDistance = e.rolloff and e.rolloff[1] or 10
		snd.RollOffMaxDistance = e.rolloff and e.rolloff[2] or 300
		snd.Parent = parent
		snd:Play()
	end
	local handle = {}
	function handle.stop(fade: number?) -- idempotent
		local snd = s
		s = nil
		if not snd then return end
		local tw = TweenService:Create(snd, TweenInfo.new(fade or 0.5), { Volume = 0 })
		tw.Completed:Once(function() snd:Destroy() end)
		tw:Play()
	end
	return handle
end

-- Ambience bed on a layer: starting one fades out whatever else is on that layer. on=false stops it.
function Sound.ambience(name: string, on: boolean)
	local e = entry(name)
	if not e then return end
	local layer = e.layer or name
	local cur = beds[layer]
	if cur and (cur.name ~= name or not on) then
		local old = cur.s
		beds[layer] = nil
		local tw = TweenService:Create(old, TweenInfo.new(1.5), { Volume = 0 })
		tw.Completed:Once(function() old:Destroy() end)
		tw:Play()
	end
	if not on or (beds[layer] and beds[layer].name == name) then return end
	local id = idOf(name, e)
	if not id then return end
	local s = make(name, e, id, nil)
	s.Looped = true
	local target = s.Volume
	s.Volume = 0
	s:Play()
	TweenService:Create(s, TweenInfo.new(1.5), { Volume = target }):Play()
	beds[layer] = { name = name, s = s }
end

-- Settings toggles. Music affects music beds only; stingers are in UI and stay audible.
function Sound.setVolume(group: string, v: number)
	setup()
	local g = groups[group]
	if g then g.Volume = v end
end

-- Preload every id; ids that fail ("not approved", no permission) switch to their fallback.
function Sound.preload()
	setup()
	local probes, names = {}, {}
	for name, e in CONFIG do
		if e.id ~= "" then
			local s = Instance.new("Sound")
			s.SoundId = "rbxassetid://" .. e.id
			table.insert(probes, s)
			names[s.SoundId] = name
		end
	end
	ContentProvider:PreloadAsync(probes, function(contentId, status)
		if status ~= Enum.AssetFetchStatus.Success then
			local id = string.match(contentId, "%d+")
			if id then badIds[id] = true end
			warn(("[Sound] %s failed to load (%s); using fallback if set"):format(tostring(names[contentId]), status.Name))
		end
	end)
	for _, s in probes do s:Destroy() end
end

-- ducking: fast attack, slow release, applied to the bed groups only
RunService.Heartbeat:Connect(function(dt)
	if not root then return end
	local now, target = os.clock(), 0
	for i = #ducks, 1, -1 do
		if now > ducks[i][2] then table.remove(ducks, i) else target = math.max(target, ducks[i][1]) end
	end
	local k = target > duckNow and math.min(dt / 0.08, 1) or math.min(dt / 0.7, 1)
	duckNow += (target - duckNow) * k
	groups.MusicBed.Volume = 1 - duckNow
	groups.AmbienceBed.Volume = 1 - duckNow * 0.5
end)

return Sound
