-- Sound: one small set of UI/game sounds (built-in client sounds, probed in Studio).
-- Respects the "Sound effects" setting.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Theme = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("UI"):WaitForChild("Theme"))

local Sound = {}
Sound.enabled = true

local cache: { [string]: Sound } = {}
local last: { [string]: number } = {}

local VOLUME = { click = 0.45, open = 0.4, reward = 0.5, capture = 0, --[[ muted for now (developer, Oct 15); was 0.6 ]] swing = 0.4, evolve = 0.6, tick = 0.35, caught = 0.6 }

-- where the sound actually starts in its file (seconds): the built-in swordslash.wav is silent for its
-- first ~0.42 s (measured with an AudioAnalyzer), which put the dash whoosh at the END of a 0.4 s dash
-- and the stab whoosh well after the thrust. Played from here it's heard within ~0.02 s.
local START = { swing = 0.4 }

local function get(name: string): Sound?
	local s = cache[name]
	local id = Theme.sounds[name]
	if not s and id then
		s = Instance.new("Sound")
		s.Name = "EOS_" .. name
		s.SoundId = id
		s.Volume = VOLUME[name] or 0.5
		s.Parent = SoundService
		cache[name] = s
	end
	return s
end

function Sound.play(name: string, pitch: number?)
	if not Sound.enabled then
		return
	end
	-- no machine-gun repeats of the same sound inside 60 ms
	local now = os.clock()
	if last[name] and now - last[name] < 0.06 then
		return
	end
	local s = get(name)
	if not s then
		return
	end
	last[name] = now
	s.PlaybackSpeed = pitch or 1
	local from = START[name]
	if from then
		s.TimePosition = from -- skip the silent lead-in
		s:Play()
	else
		SoundService:PlayLocalSound(s)
	end
end

-- load every sound up front, so the first dash / stab / click isn't late while its file loads
task.spawn(function()
	local list = {}
	for name in pairs(Theme.sounds) do
		local snd = get(name)
		if snd then
			table.insert(list, snd)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
end)

return Sound
