--!strict
-- LionPet (client): the Shrine Lion (Guardian Epic), HOS-PET-024. Built in tools/pet-kit/lion/lion.py.
--  * follower: GroundPet (pads behind your right side; Walk / Run / Hop / Idle from LionAnims, bells swinging)
--  * summon (every ability press, both roles; visual only, abilities fire on the press): it springs up at your
--    front-right; Runner (Shield) plays Ability (rears up roaring, stamps both forepaws), Catcher (Long Reach) plays
--    Roar (lowers its head and roars the beam out). VFX.LionSummon_L1-L3 flashes at FLASH_AT, then it shrinks into you.
--    The shield / tether are the Lion* templates (gold-red versions of the Guardian effects; the dome keeps its blue).
--  * poof: none.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))
local GroundPet = require(script.Parent:WaitForChild("GroundPet"))

local LionPet = {}

LionPet.SPECIES = "Shrine Lion"
LionPet.INTRO = 0.9 -- how long the summon plays (visual only)
LionPet.FLASH_AT = 0.42 -- seconds in: the cast peaks
LionPet.SUMMON_SCALE = 1.2

LionPet.PARAMS = {
	species = "Shrine Lion",
	scale = 1.0,
	walkStride = 0.6,
	runStride = 1.0,
	runAt = 1.5,
	maxSpeed = 3,
	side = 2.4,
	back = 2.2,
} :: GroundPet.Params

function LionPet.newFollower(level: number, root: BasePart)
	return GroundPet.newFollower(LionPet.PARAMS, level, root)
end
LionPet.respawnFollower = GroundPet.respawnFollower
LionPet.updateFollower = GroundPet.updateFollower

function LionPet.summon(who: Model, level: number)
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	level = math.clamp(math.floor(level), 1, 3)
	local plr = Players:GetPlayerFromCharacter(who)
	local role = plr and plr:GetAttribute("EOS_Role")
	local catcher = type(role) == "string" and string.upper(role) == "CATCHER" -- EOS_Role is "CATCHER" / "RUNNER"
	local clip = if catcher then "Roar" else "Ability"
	local beast = PetModel.build(LionPet.SPECIES, LionPet.SUMMON_SCALE, level)
	beast.Name = "EOS_LionSummon"
	local rig = PetRig.new(beast, LionPet.SPECIES)
	local INTRO = LionPet.INTRO
	local baseScale = beast:GetScale()
	local yaw = GroundPet.yawOf(root.CFrame.LookVector, 0)
	-- at your front-right, facing the way you face
	local function place(k: number)
		local rcf = root.CFrame
		local feet = GroundPet.feetY(who, root)
		local pop = math.min(1, k / 0.15) -- springs up out of the ground
		local lp = Vector3.new(2.1, -0.6 * (1 - pop), -1.2)
		local wp = Vector3.new(0, feet - rcf.Position.Y, 0) + rcf * lp
		yaw = GroundPet.yawOf(rcf.LookVector, yaw)
		beast:PivotTo(CFrame.new(wp) * CFrame.Angles(0, yaw, 0))
		-- shrinks into you over the last fifth
		local m = math.clamp((k - 0.8) / 0.2, 0, 1)
		if m > 0 then
			beast:ScaleTo(baseScale * (1 - 0.7 * m))
			GroundPet.fade(beast, m * 0.85)
		end
	end
	place(0)
	beast.Parent = workspace.CurrentCamera
	rig:play(clip, 0, rig:length(clip) / (INTRO * 0.8), 0)
	local t0 = os.clock()
	local flashed = false
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local k = (os.clock() - t0) / INTRO
		if not root.Parent or k >= 1 then
			conn:Disconnect()
			beast:Destroy()
			return
		end
		if not flashed and os.clock() - t0 >= LionPet.FLASH_AT then
			flashed = true
			local cf, size = beast:GetBoundingBox()
			GroundPet.playFx("LionSummon_L" .. level, CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.3, 0)))
		end
		place(k)
		rig:step(dt)
	end)
end

function LionPet.poof(_pos: Vector3, _level: number): boolean
	return false
end

return LionPet
