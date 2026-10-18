--!strict
-- WardenPet (client): the Crystal Warden (Guardian Rare), HOS-PET-019. Built in tools/pet-kit/warden/warden.py.
--  * follower: GroundPet (prowls behind your right side; Walk / Run / Hop / Idle from WardenAnims)
--  * summon (every ability press, both roles; visual only, abilities fire on the press, Hunter 17 Oct): the
--    Warden springs up at your front-right in a burst of crystal and casts:
--      Runner (Shell Shield): the Ability clip, rears up on its hind legs and slams both forepaws down;
--      Catcher (Horn Tether / Long Reach): the Reach clip, crouches and lunges with its jaw thrown open.
--    The level's flash (VFX.WardenSummon_L1-L3, sapphire crystal + prism facets) fires at FLASH_AT, then it
--    shrinks into you. The shield / tether themselves are the Warden* templates (AbilityCosmetics).
--  * poof: none (Guardian has no decoy).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))
local GroundPet = require(script.Parent:WaitForChild("GroundPet"))

local WardenPet = {}

WardenPet.SPECIES = "Crystal Warden"
WardenPet.INTRO = 0.9 -- how long the summon plays (visual only)
WardenPet.FLASH_AT = 0.4 -- seconds in: the paws slam (Shield) / the jaw opens (Reach)
WardenPet.SUMMON_SCALE = 1.3

WardenPet.PARAMS = {
	species = "Crystal Warden",
	scale = 1.0,
	walkStride = 0.6,
	runStride = 1.0,
	runAt = 1.5,
	maxSpeed = 3,
	side = 2.4,
	back = 2.2,
} :: GroundPet.Params

function WardenPet.newFollower(level: number, root: BasePart)
	return GroundPet.newFollower(WardenPet.PARAMS, level, root)
end
WardenPet.respawnFollower = GroundPet.respawnFollower
WardenPet.updateFollower = GroundPet.updateFollower

function WardenPet.summon(who: Model, level: number)
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	level = math.clamp(math.floor(level), 1, 3)
	local plr = Players:GetPlayerFromCharacter(who)
	local role = plr and plr:GetAttribute("EOS_Role")
	local catcher = type(role) == "string" and string.upper(role) == "CATCHER" -- EOS_Role is "CATCHER" / "RUNNER"
	local clip = if catcher then "Reach" else "Ability"
	local beast = PetModel.build(WardenPet.SPECIES, WardenPet.SUMMON_SCALE, level)
	beast.Name = "EOS_WardenSummon"
	local rig = PetRig.new(beast, WardenPet.SPECIES)
	local INTRO = WardenPet.INTRO
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
		if not flashed and os.clock() - t0 >= WardenPet.FLASH_AT then
			flashed = true
			local cf, size = beast:GetBoundingBox()
			GroundPet.playFx("WardenSummon_L" .. level, CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.3, 0)))
		end
		place(k)
		rig:step(dt)
	end)
end

function WardenPet.poof(_pos: Vector3, _level: number): boolean
	return false
end

return WardenPet
