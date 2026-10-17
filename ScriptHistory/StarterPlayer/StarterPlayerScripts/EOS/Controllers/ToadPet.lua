--!strict
-- ToadPet (client): the Thunder Toad (Tempest Common), HOS-PET-014. Built in tools/pets/thunder_toad.py.
--  * follower: GroundPet (hops along behind your right side; Walk / Run / Hop / Idle from ToadAnims)
--  * summon (every ability press, both roles): the toad pops up beside you, rears back and balloons its throat
--    sac in a big croak (the Ability clip), a yellow lightning flash at the peak (VFX.ToadSummon_L1-L3), then
--    shrinks into you. Visual only: abilities fire on the press and never wait on this (Hunter, 17 Oct).
--  * poof: none (Tempest has no decoy).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))
local GroundPet = require(script.Parent:WaitForChild("GroundPet"))

local ToadPet = {}

ToadPet.SPECIES = "Thunder Toad"
ToadPet.INTRO = 0.85 -- how long the summon plays (visual only)
ToadPet.FLASH_AT = 0.42 -- seconds in: the throat sac is fully puffed
ToadPet.SUMMON_SCALE = 1.35

ToadPet.PARAMS = {
	species = "Thunder Toad",
	scale = 1.0,
	walkStride = 0.55,
	runStride = 0.95,
	runAt = 1.5,
	maxSpeed = 3,
	side = 2.3,
	back = 2.0,
} :: GroundPet.Params

function ToadPet.newFollower(level: number, root: BasePart)
	return GroundPet.newFollower(ToadPet.PARAMS, level, root)
end
ToadPet.respawnFollower = GroundPet.respawnFollower
ToadPet.updateFollower = GroundPet.updateFollower

function ToadPet.summon(who: Model, level: number)
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	level = math.clamp(math.floor(level), 1, 3)
	local toad = PetModel.build(ToadPet.SPECIES, ToadPet.SUMMON_SCALE, level)
	toad.Name = "EOS_ToadSummon"
	local rig = PetRig.new(toad, ToadPet.SPECIES)
	local INTRO = ToadPet.INTRO
	local baseScale = toad:GetScale()
	local yaw = GroundPet.yawOf(root.CFrame.LookVector, 0)
	-- at your front-right, facing the way you face
	local function place(k: number)
		local rcf = root.CFrame
		local feet = GroundPet.feetY(who, root)
		local pop = math.min(1, k / 0.15) -- springs up out of the ground
		local lp = Vector3.new(2.1, -0.6 * (1 - pop), -1.2)
		local wp = Vector3.new(0, feet - rcf.Position.Y, 0) + rcf * lp
		yaw = GroundPet.yawOf(rcf.LookVector, yaw)
		toad:PivotTo(CFrame.new(wp) * CFrame.Angles(0, yaw, 0))
		-- shrinks into you over the last fifth
		local m = math.clamp((k - 0.8) / 0.2, 0, 1)
		if m > 0 then
			toad:ScaleTo(baseScale * (1 - 0.7 * m))
			GroundPet.fade(toad, m * 0.85)
		end
	end
	place(0)
	toad.Parent = workspace.CurrentCamera
	rig:play("Ability", 0, rig:length("Ability") / (INTRO * 0.8), 0)
	local t0 = os.clock()
	local flashed = false
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local k = (os.clock() - t0) / INTRO
		if not root.Parent or k >= 1 then
			conn:Disconnect()
			toad:Destroy()
			return
		end
		if not flashed and os.clock() - t0 >= ToadPet.FLASH_AT then
			flashed = true
			local cf, size = toad:GetBoundingBox()
			GroundPet.playFx("ToadSummon_L" .. level, CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.3, 0)))
		end
		place(k)
		rig:step(dt)
	end)
end

function ToadPet.poof(_pos: Vector3, _level: number): boolean
	return false
end

return ToadPet
