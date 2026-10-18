--!strict
-- HoundPet (client): the Riot Hound (Tempest Rare), HOS-PET-020. Built in tools/pet-kit/hound/hound.py.
--  * follower: GroundPet (lopes behind your right side; Walk / Run gallop / Hop / Idle from HoundAnims)
--  * summon (every ability press, both roles; visual only, abilities fire on the press, Hunter 17 Oct): the
--    Hound springs up at your front-right crackling with lightning and casts:
--      Runner (Shockwave knockback): the Ability clip, rears its head and slams its forepaws down;
--      Catcher (Storm Ball): the Howl clip, crouches and howls the ball out.
--    The level's flash (VFX.HoundSummon_L1-L3, gold + blue lightning) fires at FLASH_AT, then it shrinks into you.
--    The shockwave / ball themselves are the Hound* templates (AbilityCosmetics).
--  * poof: none (Tempest has no decoy).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))
local GroundPet = require(script.Parent:WaitForChild("GroundPet"))

local HoundPet = {}

HoundPet.SPECIES = "Riot Hound"
HoundPet.INTRO = 0.9 -- how long the summon plays (visual only)
HoundPet.FLASH_AT = 0.42 -- seconds in: the paws slam (Knockback) / the howl peaks (Storm Ball)
HoundPet.SUMMON_SCALE = 1.25

HoundPet.PARAMS = {
	species = "Riot Hound",
	scale = 1.0,
	walkStride = 0.7,
	runStride = 1.3,
	runAt = 1.5,
	maxSpeed = 3,
	side = 2.4,
	back = 2.2,
} :: GroundPet.Params

function HoundPet.newFollower(level: number, root: BasePart)
	return GroundPet.newFollower(HoundPet.PARAMS, level, root)
end
HoundPet.respawnFollower = GroundPet.respawnFollower
HoundPet.updateFollower = GroundPet.updateFollower

function HoundPet.summon(who: Model, level: number)
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	level = math.clamp(math.floor(level), 1, 3)
	local plr = Players:GetPlayerFromCharacter(who)
	local role = plr and plr:GetAttribute("EOS_Role")
	local catcher = type(role) == "string" and string.upper(role) == "CATCHER" -- EOS_Role is "CATCHER" / "RUNNER"
	local clip = if catcher then "Howl" else "Ability"
	local beast = PetModel.build(HoundPet.SPECIES, HoundPet.SUMMON_SCALE, level)
	beast.Name = "EOS_HoundSummon"
	local rig = PetRig.new(beast, HoundPet.SPECIES)
	local INTRO = HoundPet.INTRO
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
		if not flashed and os.clock() - t0 >= HoundPet.FLASH_AT then
			flashed = true
			local cf, size = beast:GetBoundingBox()
			GroundPet.playFx("HoundSummon_L" .. level, CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.3, 0)))
		end
		place(k)
		rig:step(dt)
	end)
end

function HoundPet.poof(_pos: Vector3, _level: number): boolean
	return false
end

return HoundPet
