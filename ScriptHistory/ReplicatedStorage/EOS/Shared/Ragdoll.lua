--!strict
-- Ragdoll: a caught Runner falls over the way they were hit, then gets back up.
-- The server (CharacterService.ragdoll) swaps the R6 joints for ball sockets so every screen sees
-- the same fall; after Capture.RAGDOLL_SETTLE seconds it locks the body in the pose it landed in
-- (limbs welded, body anchored) so nothing keeps simulating while it lies there (Oct 16: lag fix).
-- Character attributes:
--   EOS_Ragdoll        true while down (cleared when the joints come back)
--   EOS_RagdollPush    the knock (world velocity, studs/s) to add as they go down
--   EOS_RagdollFrozen  true once the landed pose is locked
-- Whoever simulates the fall flips its Humanoid into Physics and back: the player's own client for
-- players (Ragdoll.bindLocal, started from ClientMain), the server for NPCs. Both use fling / standUp.

local Players = game:GetService("Players")

local Ragdoll = {}

-- R6 ball-socket frames per joint: c0 = attachment on the Torso, c1 = on the limb, cone and twist
-- limits in degrees. The cone axis is the attachment's X axis: up for the head, out sideways for
-- the arms, down for the legs. Positions match the R6 rest pose (arm centre (±1.5, 0), leg (±0.5, -2)).
export type Joint = { c0: CFrame, c1: CFrame, cone: number, twist: number }
Ragdoll.JOINTS = {
	Neck = { c0 = CFrame.new(0, 1, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1), c1 = CFrame.new(0, -0.5, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1), cone = 40, twist = 30 },
	["Left Shoulder"] = { c0 = CFrame.new(-1.3, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1), c1 = CFrame.new(0.2, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1), cone = 100, twist = 45 },
	["Right Shoulder"] = { c0 = CFrame.new(1.3, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), c1 = CFrame.new(-0.2, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), cone = 100, twist = 45 },
	["Left Hip"] = { c0 = CFrame.new(-0.5, -1, 0, 0, 1, 0, -1, 0, 0, 0, 0, 1), c1 = CFrame.new(0, 1, 0, 0, 1, 0, -1, 0, 0, 0, 0, 1), cone = 60, twist = 20 },
	["Right Hip"] = { c0 = CFrame.new(0.5, -1, 0, 0, 1, 0, -1, 0, 0, 0, 0, 1), c1 = CFrame.new(0, 1, 0, 0, 1, 0, -1, 0, 0, 0, 0, 1), cone = 60, twist = 20 },
} :: { [string]: Joint }

-- send the loose body flying: half the run's momentum plus the knock, tipping over the way it was hit
function Ragdoll.fling(char: Model, push: Vector3)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = char:FindFirstChild("Torso") :: BasePart?
	if not root then
		return
	end
	local v = root.AssemblyLinearVelocity
	local vel = Vector3.new(v.X, 0, v.Z) * 0.5 + push
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") then
			p.AssemblyLinearVelocity = vel
		end
	end
	local flat = Vector3.new(push.X, 0, push.Z)
	if torso and flat.Magnitude > 0.1 then
		torso.AssemblyAngularVelocity = Vector3.yAxis:Cross(flat.Unit) * 7 -- top of the body moves with the hit
	end
end

local standParams = RaycastParams.new()
standParams.FilterType = Enum.RaycastFilterType.Exclude
standParams.RespectCanCollide = true

-- back on your feet where you landed: upright, facing roughly where the body pointed, on the floor
function Ragdoll.standUp(char: Model)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.2 then
		-- lying flat on the back or front: the body's up axis points along the ground instead
		local up = root.CFrame.UpVector
		look = Vector3.new(up.X, 0, up.Z)
	end
	look = if look.Magnitude > 0.05 then look.Unit else Vector3.zAxis
	standParams.FilterDescendantsInstances = { char }
	local from = root.Position + Vector3.new(0, 3, 0)
	local hit = workspace:Raycast(from, Vector3.new(0, -14, 0), standParams)
	local y = if hit then hit.Position.Y + 3 else root.Position.Y + 2 -- R6: hips 2 above the floor, root 1 above the hips
	local pos = Vector3.new(root.Position.X, y, root.Position.Z)
	char:PivotTo(CFrame.lookAt(pos, pos + look))
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") then
			p.AssemblyLinearVelocity = Vector3.zero
			p.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

-- client: drive the local player's own body (their client owns its physics)
function Ragdoll.bindLocal()
	local player = Players.LocalPlayer
	local function bind(char: Model)
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hum then
			return
		end
		local down = false
		local function apply()
			local on = char:GetAttribute("EOS_Ragdoll") == true
			if on and not down then
				down = true
				hum:ChangeState(Enum.HumanoidStateType.Physics)
				local push = char:GetAttribute("EOS_RagdollPush")
				Ragdoll.fling(char, if typeof(push) == "Vector3" then push else Vector3.zero)
			elseif not on and down then
				down = false
				-- a teleport (next crossing, back to the lobby) may already have stood the body up
				-- somewhere else: only pick it up off the floor if it's still lying there
				local torso = char:FindFirstChild("Torso") :: BasePart?
				if torso and torso.CFrame.UpVector.Y < 0.7 then
					Ragdoll.standUp(char)
				end
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end
		char:GetAttributeChangedSignal("EOS_Ragdoll"):Connect(apply)
		apply()
	end
	player.CharacterAdded:Connect(function(char)
		task.spawn(bind, char)
	end)
	if player.Character then
		task.spawn(bind, player.Character)
	end
end

return Ragdoll
