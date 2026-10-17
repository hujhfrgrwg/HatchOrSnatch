--!strict
-- NekoPet (client): the Veil Nekomata (Invisibility Legendary), HOS-PET-028. Built in tools/pet-kit/neko/neko.py.
--  * follower: GroundPet (slinks behind your right side; Walk / Run / Hop / Idle from NekoAnims, twin tails weaving)
--  * summon (every ability press, both roles; visual only, the ability fires on the press): it springs up at your
--    front-right; Runner (Vanish) plays Ability (crouches, whips both flaming tails over its back, springs out),
--    Catcher plays Stalk (hunting crouch, lunges a forepaw). VFX.NekoVanish_L1-L3 / NekoStalk_L1-L3 (blue onibi,
--    smoke and a pair of glowing cat eyes; L3 blue-violet) fire at FLASH_AT, then it shrinks into you.
--  * poof: none.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))
local GroundPet = require(script.Parent:WaitForChild("GroundPet"))

local NekoPet = {}

NekoPet.SPECIES = "Veil Nekomata"
NekoPet.INTRO = 0.9 -- how long the summon plays (visual only)
NekoPet.FLASH_AT = 0.5 -- seconds in: the cast peaks
NekoPet.SUMMON_SCALE = 1.2

NekoPet.PARAMS = {
	species = "Veil Nekomata",
	scale = 1.0,
	walkStride = 0.6,
	runStride = 1.0,
	runAt = 1.5,
	maxSpeed = 3,
	side = 2.4,
	back = 2.2,
} :: GroundPet.Params

function NekoPet.newFollower(level: number, root: BasePart)
	return GroundPet.newFollower(NekoPet.PARAMS, level, root)
end
NekoPet.respawnFollower = GroundPet.respawnFollower
NekoPet.updateFollower = GroundPet.updateFollower

function NekoPet.summon(who: Model, level: number)
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	level = math.clamp(math.floor(level), 1, 3)
	local plr = Players:GetPlayerFromCharacter(who)
	local role = plr and plr:GetAttribute("EOS_Role")
	local catcher = type(role) == "string" and string.upper(role) == "CATCHER" -- EOS_Role is "CATCHER" / "RUNNER"
	local clip = if catcher then "Stalk" else "Ability"
	local beast = PetModel.build(NekoPet.SPECIES, NekoPet.SUMMON_SCALE, level)
	beast.Name = "EOS_NekoSummon"
	local rig = PetRig.new(beast, NekoPet.SPECIES)
	local INTRO = NekoPet.INTRO
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
		if not flashed and os.clock() - t0 >= NekoPet.FLASH_AT then
			flashed = true
			local cf, size = beast:GetBoundingBox()
			GroundPet.playFx((if catcher then "NekoStalk_L" else "NekoVanish_L") .. level, CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.3, 0)))
		end
		place(k)
		rig:step(dt)
	end)
end

function NekoPet.poof(_pos: Vector3, _level: number): boolean
	return false
end

return NekoPet
