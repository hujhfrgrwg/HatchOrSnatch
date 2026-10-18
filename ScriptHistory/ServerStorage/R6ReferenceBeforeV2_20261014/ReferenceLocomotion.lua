-- Grounded R6 reference locomotion. Default Roblox Animate handles other states.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local library = game:GetService("ReplicatedStorage"):WaitForChild("R6ReferenceAnimations")
local sampler = require(library:WaitForChild("SequencePlayer"))
local walk = sampler.Read(library:WaitForChild("ReferenceWalk"))
local idle = sampler.Read(library:WaitForChild("ReferenceIdle"))
local bindings = {}
local pending = {}

local function bind(character)
	if bindings[character] or pending[character] then return end
	pending[character] = true
	local human = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local torso = character:WaitForChild("Torso", 10)
	pending[character] = nil
	if not human or not root or not torso or human.RigType ~= Enum.HumanoidRigType.R6 then return end
	local joints = {}
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part1 then joints[joint.Part1.Name] = joint end
	end
	bindings[character] = {human = human, root = root, joints = joints,
		phase = 0, weight = 0, turn = 0, previousLook = root.CFrame.LookVector, controlled = {}}
end

local function watch(player)
	player.CharacterAdded:Connect(function(character) task.spawn(bind, character) end)
	if player.Character then task.spawn(bind, player.Character) end
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do watch(player) end

RunService.PreSimulation:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	for character, data in bindings do
		if not character:IsDescendantOf(workspace) then bindings[character] = nil; continue end
		local human, root = data.human, data.root
		local state = human:GetState()
		local supported = human.Health > 0 and not human.Sit and not human.PlatformStand
			and human.FloorMaterial ~= Enum.Material.Air
			and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics
				or state == Enum.HumanoidStateType.Landed)
		local animator = human:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				if track.Priority ~= Enum.AnimationPriority.Core
					and track.Priority.Value >= Enum.AnimationPriority.Action.Value and track.WeightCurrent > 0.01 then
					supported = false; break
				end
			end
		end
		if library:GetAttribute("Enabled") == false or character:GetAttribute("ReferenceLocomotionEnabled") == false then
			supported = false
		end
		if not supported then
			-- Clear only our previous output; leave a fresh Animator pose untouched.
			for name, previous in data.controlled do
				local joint = data.joints[name]
				if joint and joint.Transform == previous then joint.Transform = CFrame.identity end
			end
			table.clear(data.controlled)
			data.weight = 0
			data.previousLook = root.CFrame.LookVector
			continue
		end
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local targetWeight = math.clamp((speed - 0.35) / 2.5, 0, 1)
		data.weight += (targetWeight - data.weight) * (1 - math.exp(-dt * 14))
		local rate = math.clamp(speed / (library:GetAttribute("ReferenceSpeed") or 16), 0.15, 2)
		if speed > 0.35 then data.phase += dt * rate end
		local walkPose = sampler.Sample(walk, data.phase)
		local idlePose = sampler.Sample(idle, now)
		local look = root.CFrame.LookVector
		local turnRate = math.atan2(data.previousLook:Cross(look).Y, data.previousLook:Dot(look)) / math.max(dt, 1 / 240)
		data.previousLook = look
		local targetTurn = math.clamp(turnRate * 0.018, -0.07, 0.07) * data.weight
		data.turn += (targetTurn - data.turn) * (1 - math.exp(-dt * 10))
		local tool = character:FindFirstChildOfClass("Tool")
		for name, joint in data.joints do
			local posed = walkPose[name]
			if not posed then continue end
			if tool and name == "Right Arm" then
				local previous = data.controlled[name]
				if previous and joint.Transform == previous then joint.Transform = CFrame.identity end
				data.controlled[name] = nil
				continue
			end
			local result = (idlePose[name] or CFrame.identity):Lerp(posed, data.weight)
			if name == "Torso" then
				-- Convert a torso-space bank into the R6 RootJoint coordinate basis.
				local basis = joint.C0.Rotation
				result *= basis:Inverse() * CFrame.Angles(0, 0, -data.turn) * basis
			end
			joint.Transform = result
			data.controlled[name] = result
		end
	end
end)