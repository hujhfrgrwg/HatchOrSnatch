-- Samples editable KeyframeSequences without requiring uploaded animation IDs.
-- All observers evaluate the same pose data locally; no per-frame remotes.
local Player = {}

function Player.Read(sequence)
	local frames = {}
	for _, key in sequence:GetKeyframes() do
		local poses = {}
		for _, item in key:GetDescendants() do
			if item:IsA("Pose") then poses[item.Name] = item.CFrame end
		end
		table.insert(frames, {time = key.Time, poses = poses})
	end
	table.sort(frames, function(a, b) return a.time < b.time end)
	assert(#frames >= 2, "Animation needs at least two keyframes")
	return {frames = frames, duration = frames[#frames].time}
end

function Player.Sample(clip, time)
	local t = time % clip.duration
	local a, b = clip.frames[1], clip.frames[#clip.frames]
	for i = 2, #clip.frames do
		if clip.frames[i].time >= t then
			a, b = clip.frames[i - 1], clip.frames[i]
			break
		end
	end
	local alpha = math.clamp((t - a.time) / math.max(b.time - a.time, 0.00001), 0, 1)
	local result = {}
	for name, cf in a.poses do result[name] = cf:Lerp(b.poses[name] or cf, alpha) end
	return result
end

return Player