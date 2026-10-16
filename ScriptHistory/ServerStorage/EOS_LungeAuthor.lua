-- EOS_LungeAuthor: authoring tools for the Catcher's lunge stab clip (Studio only, not used by the game).
-- A pose is { [jointName] = { r = Vector3 degrees (rotation about the joint's pivot, in the PARENT
-- part's frame: X right, Y up, -Z forward), p = Vector3 studs (offset in the parent's frame) } },
-- plus optional knife = CFrame (the knife in the Right Arm's frame). Pose CFrames = Motor6D.Transform.
local A = {}

A.JOINTS = { -- jointName = { parentPart, motorName }
	Torso = { "HumanoidRootPart", "RootJoint" },
	Head = { "Torso", "Neck" },
	RightArm = { "Torso", "Right Shoulder" },
	LeftArm = { "Torso", "Left Shoulder" },
	RightLeg = { "Torso", "Right Hip" },
	LeftLeg = { "Torso", "Left Hip" },
}
A.ORDER = { "Torso", "Head", "RightArm", "LeftArm", "RightLeg", "LeftLeg" }

local function motorOf(rig, j)
	local spec = A.JOINTS[j]
	return rig[spec[1]]:FindFirstChild(spec[2])
end

local function rot(v)
	return CFrame.fromEulerAnglesYXZ(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
end

-- the Motor6D.Transform for a joint spec
function A.transform(motor, js)
	if not js then
		return CFrame.new()
	end
	local c0r = motor.C0.Rotation
	local R = rot(js.r or Vector3.zero)
	local p = js.p or Vector3.zero
	return CFrame.new(c0r:Inverse() * p) * (c0r:Inverse() * R * c0r)
end

function A.knifeMotor(rig)
	return rig["Right Arm"]:FindFirstChild("Minute Sword")
end

-- knife Transform from a desired knife CFrame in the arm's frame
function A.knifeTransform(motor, want)
	return motor.C0:Inverse() * want * motor.C1
end

-- show a pose on an anchored rig by forward kinematics (exactly what the Animator would do)
function A.show(rig, pose)
	for _, p in ipairs(rig:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end
	local root = rig.HumanoidRootPart
	local function place(motor, T)
		motor.Part1.CFrame = motor.Part0.CFrame * motor.C0 * T * motor.C1:Inverse()
	end
	for _, j in ipairs(A.ORDER) do
		local m = motorOf(rig, j)
		place(m, A.transform(m, pose[j]))
	end
	local km = A.knifeMotor(rig)
	if km then
		place(km, if pose.knife then A.knifeTransform(km, pose.knife) else CFrame.new())
	end
end

-- build a KeyframeSequence from { {t = seconds, pose = pose, ease = Enum.PoseEasingStyle?}, ... }
function A.build(rig, frames, name)
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = name
	kfs.Loop = false
	kfs.Priority = Enum.AnimationPriority.Action2
	for _, f in ipairs(frames) do
		local kf = Instance.new("Keyframe")
		kf.Time = f.t
		local rootPose = Instance.new("Pose")
		rootPose.Name = "HumanoidRootPart"
		rootPose.Weight = 0
		rootPose.Parent = kf
		local torsoPose
		local function mk(partName, T, parent, weight)
			local p = Instance.new("Pose")
			p.Name = partName
			p.CFrame = T
			p.Weight = weight or 1
			p.EasingStyle = f.ease or Enum.PoseEasingStyle.Cubic
			p.EasingDirection = f.dir or Enum.PoseEasingDirection.InOut
			p.Parent = parent
			return p
		end
		local tm = motorOf(rig, "Torso")
		torsoPose = mk("Torso", A.transform(tm, f.pose.Torso), rootPose)
		for j, partName in pairs({ Head = "Head", RightArm = "Right Arm", LeftArm = "Left Arm", RightLeg = "Right Leg", LeftLeg = "Left Leg" }) do
			local mo = motorOf(rig, j)
			local p = mk(partName, A.transform(mo, f.pose[j]), torsoPose)
			if j == "RightArm" then
				local km = A.knifeMotor(rig)
				mk("Minute Dagger", if f.pose.knife then A.knifeTransform(km, f.pose.knife) else CFrame.new(), p)
			end
		end
		for _, mk2 in ipairs(f.markers or {}) do
			local marker = Instance.new("KeyframeMarker")
			marker.Name = mk2
			kf:AddMarker(marker)
		end
		kf.Parent = kfs
	end
	return kfs
end

-- forward kinematics of the right arm relative to the root, for a pose
function A.armInRoot(rig, pose)
	local rj = rig.HumanoidRootPart.RootJoint
	local rs = rig.Torso["Right Shoulder"]
	local torso = rj.C0 * A.transform(rj, pose.Torso) * rj.C1:Inverse()
	return torso * rs.C0 * A.transform(rs, pose.RightArm) * rs.C1:Inverse()
end

-- knife in the arm's frame: blade tip along `blade` (a direction in the root frame: X right, Y up,
-- -Z forward), the edge facing `edge` (default forward), the handle in the right fist
A.BLADE_AXIS_SIGN = 1 -- the blade tip is the knife's +X end
A.HAND = Vector3.new(0, -1.15, 0) -- the fist, in the arm's frame
A.CENTER_ALONG = 0.75 -- studs from the fist to the knife's centre, along the blade
function A.knifeFor(rig, pose, blade, edge)
	local arm = A.armInRoot(rig, pose)
	local hand = arm * A.HAND
	local x = blade.Unit * A.BLADE_AXIS_SIGN
	local e = (edge or Vector3.new(0, 0, -1))
	local z = x:Cross(e)
	if z.Magnitude < 1e-3 then z = x:Cross(Vector3.new(1, 0, 0)) end
	z = z.Unit
	local y = z:Cross(x).Unit
	local knifeRoot = CFrame.fromMatrix(hand + blade.Unit * A.CENTER_ALONG, x, y, z)
	return arm:Inverse() * knifeRoot
end

return A
