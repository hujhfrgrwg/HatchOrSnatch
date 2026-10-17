-- Plays every pack clip on its numbered dummy. Studio only (uses temporary KeyframeSequence ids).
-- Use Run (F8): the server view is what you see. Delete the whole EOS_AnimPicker model when done.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local KSP = game:GetService("KeyframeSequenceProvider")
for _, dummy in ipairs(script.Parent.Dummies:GetChildren()) do
	task.spawn(function()
		local clip = dummy:FindFirstChild("Clip")
		local seq = clip and clip.Value
		if not (seq and seq:IsDescendantOf(game)) then
			-- clip was migrated by the Animation Clip Editor: find it in ServerStorage.RBX_ANIMSAVES
			seq = nil
			local saves = game:GetService("ServerStorage"):FindFirstChild("RBX_ANIMSAVES")
			for _, ov in ipairs(saves and saves:GetChildren() or {}) do
				if ov:IsA("ObjectValue") and ov.Value == dummy then
					seq = ov:FindFirstChildWhichIsA("KeyframeSequence")
				end
			end
		end
		local hum = dummy:FindFirstChildOfClass("Humanoid")
		if not seq or not hum then return end
		local ok, id = pcall(function() return KSP:RegisterKeyframeSequence(seq) end)
		if not ok then warn("[AnimPicker] could not register " .. dummy.Name .. ": " .. tostring(id)) return end
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action
		if seq.Loop then
			track.Looped = true
			track:Play(0.1)
		else
			track.Looped = false
			while dummy.Parent do
				track:Play(0.05)
				task.wait(math.max(dummy:GetAttribute("Seconds") or 0.5, 0.3) + 0.9)
			end
		end
	end)
end
