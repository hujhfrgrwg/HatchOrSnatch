--!strict
-- TanukiPet (client): the Scroll Tanuki (Decoy Epic), HOS-PET-022. Built in tools/pet-kit/tanuki/tanuki.py.
--  * follower: GroundPet (trots behind your right side; Walk / Run / Hop / Idle from TanukiAnims)
--  * summon (every ability press, both roles; visual only, abilities fire on the press): it pops up at your
--    front-right; Runner (Fake Clone) plays Ability (slaps the leaf on its head and spins in a puff), Catcher (Snare)
--    plays Snare (rears and slams a paw down). VFX.TanukiSummon_L1-L3 flashes at FLASH_AT, then it shrinks into you.
--    The split / poof / snare trigger are the Tanuki* templates (AbilityCosmetics); the Snare seal stays default.
--  * poof: none of its own (the TanukiDecoyPoof template covers the copy leaving).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))
local GroundPet = require(script.Parent:WaitForChild("GroundPet"))

local TanukiPet = {}

TanukiPet.SPECIES = "Scroll Tanuki"
TanukiPet.INTRO = 0.9 -- how long the summon plays (visual only)
TanukiPet.FLASH_AT = 0.45 -- seconds in: the cast peaks
TanukiPet.SUMMON_SCALE = 1.3

TanukiPet.PARAMS = {
	species = "Scroll Tanuki",
	scale = 1.0,
	walkStride = 0.6,
	runStride = 1.0,
	runAt = 1.5,
	maxSpeed = 3,
	side = 2.4,
	back = 2.2,
} :: GroundPet.Params

function TanukiPet.newFollower(level: number, root: BasePart)
	return GroundPet.newFollower(TanukiPet.PARAMS, level, root)
end
TanukiPet.respawnFollower = GroundPet.respawnFollower
TanukiPet.updateFollower = GroundPet.updateFollower

function TanukiPet.summon(who: Model, level: number)
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	level = math.clamp(math.floor(level), 1, 3)
	local plr = Players:GetPlayerFromCharacter(who)
	local role = plr and plr:GetAttribute("EOS_Role")
	local catcher = type(role) == "string" and string.upper(role) == "CATCHER" -- EOS_Role is "CATCHER" / "RUNNER"
	local clip = if catcher then "Snare" else "Ability"
	local beast = PetModel.build(TanukiPet.SPECIES, TanukiPet.SUMMON_SCALE, level)
	beast.Name = "EOS_TanukiSummon"
	local rig = PetRig.new(beast, TanukiPet.SPECIES)
	local INTRO = TanukiPet.INTRO
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
		if not flashed and os.clock() - t0 >= TanukiPet.FLASH_AT then
			flashed = true
			local cf, size = beast:GetBoundingBox()
			GroundPet.playFx("TanukiSummon_L" .. level, CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.3, 0)))
		end
		place(k)
		rig:step(dt)
	end)
end

function TanukiPet.poof(_pos: Vector3, _level: number): boolean
	return false
end

return TanukiPet
