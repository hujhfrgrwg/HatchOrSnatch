local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local library = game:GetService("ReplicatedStorage"):WaitForChild("R6ReferenceAnimations")
local momentum = require(library:WaitForChild("DirectionalMomentum"))
local player = Players.LocalPlayer
local current
local function planar(v) return Vector3.new(v.X, 0, v.Z) end
local function suspend(data)
	data.drive.Enabled = false
	if data.active then
		data.human.WalkSpeed = data.originalSpeed
		data.human.AutoRotate = data.originalRotate
		data.active = false
	end
	data.velocity = planar(data.root.AssemblyLinearVelocity)
end

local function bind(character)
	current = nil
	local human = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if player.Character ~= character or not human or not root or human.RigType ~= Enum.HumanoidRigType.R6 then return end
	local attachment = Instance.new("Attachment")
	attachment.Name = "DirectionalMovementAttachment"
	attachment.Parent = root
	local drive = Instance.new("LinearVelocity")
	drive.Name = "DirectionalMovementVelocity"
	drive.Attachment0 = attachment
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.PrimaryTangentAxis = Vector3.xAxis
	drive.SecondaryTangentAxis = Vector3.zAxis
	drive.ForceLimitsEnabled = true
	drive.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	drive.Enabled = false
	drive.Parent = root
	current = {character = character, human = human, root = root, drive = drive,
		velocity = planar(root.AssemblyLinearVelocity), active = false,
		originalSpeed = human.WalkSpeed, originalRotate = human.AutoRotate,
		teleportMarker = player:GetAttribute("EOS_TeleportedAt")}
end
player.CharacterAdded:Connect(function(character) task.spawn(bind, character) end)
if player.Character then task.spawn(bind, player.Character) end

RunService.PreSimulation:Connect(function(dt)
	local data = current
	if not data or not data.character:IsDescendantOf(workspace) then return end
	local human, root = data.human, data.root
	local state = human:GetState()
	local allowed = state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics
		or state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
	if not allowed or human.Health <= 0 or human.Sit or human.PlatformStand or root.Anchored
		or library:GetAttribute("MomentumEnabled") == false
		or data.character:GetAttribute("DirectionalMovementEnabled") == false then
		suspend(data)
		return
	end
	if not data.active then
		data.originalSpeed, data.originalRotate = human.WalkSpeed, human.AutoRotate
		data.velocity = planar(root.AssemblyLinearVelocity)
		data.active = true
	end
	-- Read device-independent input from the default Roblox controls. Never write MoveDirection.
	local wish = planar(human.MoveDirection)
	local actual = planar(root.AssemblyLinearVelocity)
	local teleportMarker = player:GetAttribute("EOS_TeleportedAt")
	if teleportMarker ~= data.teleportMarker then
		data.teleportMarker = teleportMarker
		data.velocity = actual
	end
	if data.velocity.Magnitude > 4 and actual.Magnitude < data.velocity.Magnitude * 0.4 then
		data.velocity = actual -- A wall cannot store a full-speed launch for the next turn.
	end
	-- EOS owns role speed caps; retain them when a match changes the player's role.
	local roleCap = human:GetAttribute("EOS_MaxSpeed")
	local topSpeed = typeof(roleCap) == "number" and math.max(0, roleCap) or (library:GetAttribute("TopSpeed") or 30)
	if typeof(roleCap) == "number" then data.originalSpeed = math.max(0, roleCap) end
	if topSpeed <= 0 then data.velocity = Vector3.zero end
	if data.velocity.Magnitude > topSpeed then data.velocity = data.velocity.Unit * topSpeed end
	local config = {
		TopSpeed = topSpeed,
		Acceleration = (library:GetAttribute("Acceleration") or 26) * topSpeed / 30,
		Braking = library:GetAttribute("Braking") or 38,
		AirAcceleration = library:GetAttribute("AirAcceleration") or 8,
		AirBraking = 1,
	}
	local grounded = human.FloorMaterial ~= Enum.Material.Air
	data.velocity = momentum.Step(data.velocity, wish, grounded, dt, config)
	human.WalkSpeed = 0 -- The planar constraint supplies horizontal motion; jumping/gravity remain native.
	human.AutoRotate = false
	data.drive.MaxForce = root.AssemblyMass * 1500
	data.drive.PlaneVelocity = Vector2.new(data.velocity.X, data.velocity.Z)
	data.drive.Enabled = true
	local heading = data.velocity.Magnitude > 0.8 and data.velocity or wish
	if heading.Magnitude > 0.01 then
		local facing = CFrame.lookAt(root.Position, root.Position + heading)
		root.CFrame = root.CFrame:Lerp(facing, 1 - math.exp(-dt * 15))
	end
end)