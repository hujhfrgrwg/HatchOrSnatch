--!nocheck
-- HOS_IncubatorTestBenchCamera (HOS-INC-001, 17 Oct 2026, Matthew): Studio only. When the incubator test bench
-- (ServerScriptService.HOS_IncubatorTestBench) puts you in front of the incubator, it sets the player attribute
-- HOS_TestBenchAt; this turns you and the camera to face the egg.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then return end
local player = Players.LocalPlayer

local function face()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local inc = workspace:FindFirstChild("Incubator")
	local centre = inc and inc:FindFirstChild("Incubator") and inc.Incubator:FindFirstChild("A09_EggCentre")
	if not (hrp and centre) then return end
	local E = centre.Position
	local flat = Vector3.new(E.X - hrp.Position.X, 0, E.Z - hrp.Position.Z)
	if flat.Magnitude < 0.1 then return end
	local look = flat.Unit
	hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + look) -- the client owns the character, so turn it here too
	local cam = workspace.CurrentCamera
	cam.CFrame = CFrame.lookAt(hrp.Position - look * 9 + Vector3.new(0, 4, 0), E)
end

player:GetAttributeChangedSignal("HOS_TestBenchAt"):Connect(function()
	task.wait() -- the character has moved
	face()
end)
