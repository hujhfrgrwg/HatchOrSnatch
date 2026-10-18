--!strict
-- BeetlePet (client): the Bastion Beetle (Guardian Common), HOS-PET-013. Built in tools/pets/bastion_beetle.py.
--  * follower: GroundPet (trundles behind your right side; Walk / Run / Hop / Idle from BeetleAnims)
--  * summon (every ability press, both roles): the beetle pops up beside you, rears up with its shell plates
--    flared and its horn thrust out (the Ability clip), a gold flash at the peak (VFX.BeetleSummon_L1-L3),
--    then shrinks into you. Visual only: abilities fire on the press and never wait on this (Hunter, 17 Oct).
--  * poof: none (Guardian has no decoy).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))
local GroundPet = require(script.Parent:WaitForChild("GroundPet"))

local BeetlePet = {}

BeetlePet.SPECIES = "Bastion Beetle"
BeetlePet.INTRO = 0.85 -- how long the summon plays (visual only)
BeetlePet.FLASH_AT = 0.36 -- seconds in: the shell is fully open
BeetlePet.SUMMON_SCALE = 1.35

BeetlePet.PARAMS = {
	species = "Bastion Beetle",
	scale = 1.1,
	walkStride = 0.55,
	runStride = 0.95,
	runAt = 1.5,
	maxSpeed = 3,
	side = 2.3,
	back = 2.0,
} :: GroundPet.Params

function BeetlePet.newFollower(level: number, root: BasePart)
	return GroundPet.newFollower(BeetlePet.PARAMS, level, root)
end
BeetlePet.respawnFollower = GroundPet.respawnFollower
BeetlePet.updateFollower = GroundPet.updateFollower

function BeetlePet.summon(who: Model, level: number)
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	level = math.clamp(math.floor(level), 1, 3)
	local bug = PetModel.build(BeetlePet.SPECIES, BeetlePet.SUMMON_SCALE, level)
	bug.Name = "EOS_BeetleSummon"
	local rig = PetRig.new(bug, BeetlePet.SPECIES)
	local INTRO = BeetlePet.INTRO
	local baseScale = bug:GetScale()
	local yaw = GroundPet.yawOf(root.CFrame.LookVector, 0)
	-- at your front-right, facing the way you face
	local function place(k: number)
		local rcf = root.CFrame
		local feet = GroundPet.feetY(who, root)
		local pop = math.min(1, k / 0.15) -- springs up out of the ground
		local lp = Vector3.new(2.1, -0.6 * (1 - pop), -1.2)
		local wp = Vector3.new(0, feet - rcf.Position.Y, 0) + rcf * lp
		yaw = GroundPet.yawOf(rcf.LookVector, yaw)
		bug:PivotTo(CFrame.new(wp) * CFrame.Angles(0, yaw, 0))
		-- shrinks into you over the last fifth
		local m = math.clamp((k - 0.8) / 0.2, 0, 1)
		if m > 0 then
			bug:ScaleTo(baseScale * (1 - 0.7 * m))
			GroundPet.fade(bug, m * 0.85)
		end
	end
	place(0)
	bug.Parent = workspace.CurrentCamera
	rig:play("Ability", 0, rig:length("Ability") / (INTRO * 0.8), 0)
	local t0 = os.clock()
	local flashed = false
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local k = (os.clock() - t0) / INTRO
		if not root.Parent or k >= 1 then
			conn:Disconnect()
			bug:Destroy()
			return
		end
		if not flashed and os.clock() - t0 >= BeetlePet.FLASH_AT then
			flashed = true
			local cf, size = bug:GetBoundingBox()
			GroundPet.playFx("BeetleSummon_L" .. level, CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.3, 0)))
		end
		place(k)
		rig:step(dt)
	end)
end

function BeetlePet.poof(_pos: Vector3, _level: number): boolean
	return false
end

return BeetlePet
