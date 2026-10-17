-- Classic R6 pose curves, paced by actual velocity, with momentum-dependent banking.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local library = game:GetService("ReplicatedStorage"):WaitForChild("R6ReferenceAnimations")
local sampler = require(library:WaitForChild("SequencePlayer"))
local walk = sampler.Read(library:WaitForChild("ReferenceWalk"))
local bindings, pending = {}, {}
local function release(data)
	for name, output in data.controlled do
		local joint = data.joints[name]
		if joint and joint.Transform == output then joint.Transform = CFrame.identity end
	end
	table.clear(data.controlled)
	data.weight = 0
end
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
	bindings[character] = {human = human, root = root, joints = joints, phase = 0,
		weight = 0, bank = 0, pitch = 0, previousVelocity = Vector3.zero,
		previousLook = root.CFrame.LookVector, controlled = {}}
end
local function watch(player)
	player.CharacterAdded:Connect(function(character) task.spawn(bind, character) end)
	if player.Character then task.spawn(bind, player.Character) end
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do watch(player) end

RunService.PreSimulation:Connect(function(dt)
	for character, data in bindings do
		if not character:IsDescendantOf(workspace) then bindings[character] = nil; continue end
		local human, root = data.human, data.root
		local state = human:GetState()
		local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local speed = velocity.Magnitude
		local supported = human.Health > 0 and not human.Sit and not human.PlatformStand
			and human.FloorMaterial ~= Enum.Material.Air
			and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics
				or state == Enum.HumanoidStateType.Landed)
		local animator = human:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				if track.Priority ~= Enum.AnimationPriority.Core and track.Priority.Value >= Enum.AnimationPriority.Action.Value
					and track.WeightCurrent > 0.01 then supported = false; break end
			end
		end
		if library:GetAttribute("Enabled") == false or character:GetAttribute("ReferenceLocomotionEnabled") == false then supported = false end
		if not supported or speed < 0.35 then
			release(data)
			data.previousLook, data.previousVelocity = root.CFrame.LookVector, velocity
			data.bank, data.pitch = 0, 0
			continue
		end
		data.weight += (math.clamp(speed / 5, 0, 1) - data.weight) * (1 - math.exp(-dt * 18))
		data.phase += dt * math.clamp(speed / (library:GetAttribute("ReferenceSpeed") or 14.5), 0, 3.5)
		local pose = sampler.Sample(walk, data.phase)
		local look = root.CFrame.LookVector
		local turnRate = math.atan2(data.previousLook:Cross(look).Y, data.previousLook:Dot(look)) / math.max(dt, 1 / 240)
		local acceleration = (velocity - data.previousVelocity) / math.max(dt, 1 / 240)
		local forwardAcceleration = acceleration:Dot(look)
		local targetPitch = math.rad(-3 * math.clamp(speed / 30, 0, 1) - math.clamp(forwardAcceleration * 0.12, -3, 4))
		data.bank += (math.clamp(-turnRate * 0.035, -0.14, 0.14) - data.bank) * (1 - math.exp(-dt * 12))
		data.pitch += (targetPitch - data.pitch) * (1 - math.exp(-dt * 12))
		data.previousLook, data.previousVelocity = look, velocity
		local tool = character:FindFirstChildOfClass("Tool")
		for name, joint in data.joints do
			if not pose[name] then continue end
			if tool and name == "Right Arm" then
				local old = data.controlled[name]
				if old and joint.Transform == old then joint.Transform = CFrame.identity end
				data.controlled[name] = nil
				continue
			end
			local result = CFrame.identity:Lerp(pose[name], data.weight)
			if name == "Torso" or name == "Head" then
				local basis = joint.C0.Rotation
				local scale = name == "Head" and -0.5 or 1
				result *= basis:Inverse() * CFrame.Angles(data.pitch * scale, 0, data.bank * scale) * basis
			end
			joint.Transform = result
			data.controlled[name] = result
		end
	end
end)