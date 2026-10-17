-- Run (F8): the server plays every dagger clip on its numbered dummy (Studio only).
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
if not RunService:IsRunMode() then return end -- Play (F5) uses PreviewPlayerClient
local KSP = game:GetService("KeyframeSequenceProvider")

local function animatorOf(dummy)
	local hum = dummy:FindFirstChildOfClass("Humanoid")
	return hum and (hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum))
end

local function load(animator, id, priority)
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local track = animator:LoadAnimation(anim)
	track.Priority = priority
	return track
end

local function playClip(dummy, track, looped)
	if looped then
		track.Looped = true
		track:Play(0.1)
	else
		track.Looped = false
		while dummy.Parent do
			track:Play(0.05)
			task.wait(math.max(dummy:GetAttribute("Seconds") or 0.5, 0.3) + 0.9)
		end
	end
end

local function start(dummy)
	task.spawn(function()
		local clip = dummy:WaitForChild("Clip", 10)
		local seq = clip and clip.Value
		local animator = animatorOf(dummy)
		if not seq or not animator then return end
		local ok, id = pcall(function() return KSP:RegisterKeyframeSequence(seq) end)
		if not ok then warn("[DaggerPicker] could not register " .. dummy.Name .. ": " .. tostring(id)) return end
		-- mixed dummies: the movement clip runs the legs underneath (lower priority)
		local legs = dummy:GetAttribute("Legs")
		if type(legs) == "string" and legs ~= "" then
			local legTrack = load(animator, legs, Enum.AnimationPriority.Movement)
			legTrack.Looped = true
			legTrack:Play(0.1)
		end
		playClip(dummy, load(animator, id, Enum.AnimationPriority.Action), seq.Loop)
	end)
end

for _, folderName in ipairs({ "Dummies", "Mixed" }) do
	local folder = script.Parent:WaitForChild(folderName, 10)
	for _, dummy in ipairs(folder and folder:GetChildren() or {}) do
		start(dummy)
	end
end
