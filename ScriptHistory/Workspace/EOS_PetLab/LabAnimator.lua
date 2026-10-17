-- LabAnimator (client, Studio only): bay displays play their Anim attribute in Play mode
-- (looping ones loop; one-shots hold their Frame). Rigged pets only (CrowRig).
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CrowRig = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("CrowRig"))
local lab = script.Parent
task.wait(1)
local rigs = {}
for _, m in ipairs(lab:GetDescendants()) do
	if m:IsA("Model") and m:FindFirstChild("RootPart") then
		local a = m:GetAttribute("Anim")
		if type(a) == "string" and a ~= "" and CrowRig.Anims[a] then
			local rig = CrowRig.new(m)
			local frame = m:GetAttribute("Frame") or 0
			if CrowRig.Anims[a].loop then
				rig:play(a, 0, 1, frame)
				table.insert(rigs, rig)
			else
				rig:pose(a, frame)
			end
		end
	end
end
RunService.RenderStepped:Connect(function(dt)
	for _, r in ipairs(rigs) do
		r:step(dt)
	end
end)
