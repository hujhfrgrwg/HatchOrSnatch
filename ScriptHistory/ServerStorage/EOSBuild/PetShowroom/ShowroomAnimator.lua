--!nocheck
-- ShowroomAnimator: plays every clip of every pet and egg in the showroom, one after another.
-- Each family (base + variants) runs the same clip together so they can be compared.
-- The original animations belong to the Fishing with Pets! group and Roblox won't play them in this
-- (user-owned) game, so in Studio each clip is played from its KeyframeSequence copy in
-- ServerStorage.FWP_PetLibrary.Clips. In a live server that only works once the animations are
-- re-uploaded to this game's owner (see FWP_PetLibrary notes).
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local room = script.Parent
local lib = ServerStorage:WaitForChild("FWP_PetLibrary", 10)
local clips = lib and lib:FindFirstChild("Clips")
local registered = {}

local function contentId(anim: Animation): string
	local id = anim.AnimationId:match("%d+")
	if id and clips and RunService:IsStudio() then
		local kfs = clips:FindFirstChild(id)
		if kfs then
			if not registered[id] then
				local ok, cid = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, kfs)
				registered[id] = if ok then cid else anim.AnimationId
			end
			return registered[id]
		end
	end
	return anim.AnimationId
end

local ORDER = { "Idle", "Walk", "Fish", "Cheer", "Evolve", "Wobble", "Hatch", "Wait", "Sit", "HopOut", "JumpIn" }
local IDLE_HOLD = 2.5 -- seconds of idle between the other clips

local function setup(model: Model)
	local ctrl = model:FindFirstChildOfClass("AnimationController") or model:FindFirstChildOfClass("Humanoid")
	local folder = model:FindFirstChild("Animations")
	if not ctrl or not folder then
		return nil
	end
	local animator = ctrl:FindFirstChildOfClass("Animator") or Instance.new("Animator", ctrl)
	local tracks = {}
	for _, name in ORDER do
		local a = folder:FindFirstChild(name)
		if a and a:IsA("Animation") then
			local anim = Instance.new("Animation")
			anim.Name = name
			anim.AnimationId = contentId(a)
			local ok, track = pcall(animator.LoadAnimation, animator, anim)
			if ok then
				table.insert(tracks, { name = name, track = track })
			end
		end
	end
	local label
	for _, d in model:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "Anim" then
			label = d
		end
	end
	return { tracks = tracks, label = label }
end

-- group the animated models: a family's members share one schedule
local groups = {}
for _, m in room:GetDescendants() do
	if m:IsA("Model") and m:GetAttribute("ShowroomAnimate") then
		local key = m.Parent
		groups[key] = groups[key] or {}
		local s = setup(m)
		if s and #s.tracks > 0 then
			table.insert(groups[key], s)
		end
	end
end

local function play(members, i)
	local longest = 0
	for _, s in members do
		local entry = s.tracks[i]
		if entry then
			for _, other in s.tracks do
				if other ~= entry and other.track.IsPlaying then
					other.track:Stop(0.2)
				end
			end
			entry.track.Looped = false
			entry.track:Play(0.2)
			if s.label then
				s.label.Text = "▶ " .. entry.name
			end
			longest = math.max(longest, entry.track.Length)
		end
	end
	return longest
end

for _, members in groups do
	if #members > 0 then
		task.spawn(function()
			task.wait(math.random() * 2)
			local count = #members[1].tracks
			while room.Parent do
				for i = 1, count do
					local name = members[1].tracks[i].name
					local len = play(members, i)
					if len <= 0 then
						task.wait(0.3) -- still loading: Length reads 0 until the clip is in
						len = 0
						for _, s in members do
							local e = s.tracks[i]
							len = math.max(len, e and e.track.Length or 0)
						end
					end
					local hold = if name == "Idle" then math.max(IDLE_HOLD, len) else math.max(len, 0.5)
					task.wait(hold)
				end
			end
		end)
	end
end
