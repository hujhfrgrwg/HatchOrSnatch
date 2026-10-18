--!strict
-- DragonPet (client): the Bone Dragon (Tempest Legendary, Halloween), HOS-HWN-001. Built in tools/pet-kit/dragon/dragon.py.\n * follower: flies behind your right shoulder (the Tengu's hover follower; wing beats in Idle / Walk / Run).\n * summon (every ability press; visual only, the ability fires on the press): Runner (Knockback) plays Ability (rears, slams\n   down in a wing beat), Catcher (Storm Ball) plays Breath (spits the soul-fire ball); VFX.DragonSummon_L1-3 fires at FLASH_AT.\n   The pulse / storm ball / hits are the Dragon* templates (AbilityCosmetics).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))
local GroundPet = require(script.Parent:WaitForChild("GroundPet"))

local DragonPet = {}

DragonPet.SPECIES = "Bone Dragon"
DragonPet.INTRO = 0.9 -- how long the summon plays (visual only)
DragonPet.FLASH_AT = 0.45 -- seconds in: the cast peaks
DragonPet.SCALE = 1.0
DragonPet.SUMMON_SCALE = 1.4

-- follower placement (studs, in the owner's frame): right, up from the root, behind
DragonPet.SIDE = 2.2
DragonPet.HEIGHT = 1.4
DragonPet.BACK = 1.9

export type Follower = {
	model: Model,
	rig: any,
	pos: Vector3,
	vel: Vector3,
	yaw: number,
	roll: number,
	t: number,
	level: number,
	gait: string,
}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function approachAngle(a: number, b: number, rate: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * rate
end

local function spotFor(f: Follower?, root: BasePart): Vector3
	local cf = root.CFrame
	local look = flat(cf.LookVector)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	local right = Vector3.new(-look.Z, 0, look.X)
	local t = if f then f.t else 0
	local bob = math.sin(t * 1.5) * 0.22
	return root.Position + right * DragonPet.SIDE - look * DragonPet.BACK + Vector3.new(0, DragonPet.HEIGHT + bob, 0)
end

function DragonPet.newFollower(level: number, root: BasePart): Follower
	local m = PetModel.build(DragonPet.SPECIES, DragonPet.SCALE, level)
	m.Name = "EOS_Follower"
	local rig = PetRig.new(m, DragonPet.SPECIES)
	local f: Follower = {
		model = m,
		rig = rig,
		pos = Vector3.zero,
		vel = Vector3.zero,
		yaw = GroundPet.yawOf(root.CFrame.LookVector, 0),
		roll = 0,
		t = math.random() * 6,
		level = level,
		gait = "idle",
	}
	f.pos = spotFor(f, root)
	rig:play("Idle", 0, 1, math.random() * 60)
	m:PivotTo(CFrame.new(f.pos) * CFrame.Angles(0, f.yaw, 0))
	m.Parent = workspace.CurrentCamera -- local only
	return f
end

function DragonPet.respawnFollower(f: Follower, root: BasePart)
	f.pos = spotFor(f, root)
	f.vel = Vector3.zero
	f.roll = 0
	f.gait = "idle"
	f.rig:play("Idle", 0)
end

function DragonPet.updateFollower(f: Follower, root: BasePart, dt: number)
	if dt <= 0 then
		return
	end
	f.t += dt
	local goal = spotFor(f, root)
	local to = goal - f.pos
	if to.Magnitude > 40 then
		f.pos = goal -- lost (teleport / respawn): pop back next to the owner
		to = Vector3.zero
	end
	local prev = f.pos
	local k = 1 - math.exp(-dt * (3.2 + math.min(to.Magnitude, 12) * 0.35))
	f.pos = f.pos + to * k
	local vel = (f.pos - prev) / dt
	f.vel = f.vel:Lerp(vel, 1 - math.exp(-dt * 6))
	local speed = flat(f.vel).Magnitude

	local look = flat(root.CFrame.LookVector)
	local wantYaw = if speed > 1.2 then GroundPet.yawOf(f.vel, f.yaw) else GroundPet.yawOf(look, f.yaw)
	local oldYaw = f.yaw
	f.yaw = approachAngle(f.yaw, wantYaw, 1 - math.exp(-dt * (if speed > 1.2 then 6 else 2.5)))
	local yawRate = ((f.yaw - oldYaw + math.pi) % (2 * math.pi) - math.pi) / dt
	f.roll += (math.clamp(-yawRate * 0.2, -0.5, 0.5) - f.roll) * (1 - math.exp(-dt * 5))

	local g = if speed > 7 then "run" elseif speed > 1.6 or (f.gait ~= "idle" and speed > 0.9) then "walk" else "idle"
	if g ~= f.gait then
		f.gait = g
		f.rig:play(if g == "run" then "Run" elseif g == "walk" then "Walk" else "Idle", 0.3)
	end
	if g ~= "idle" then
		f.rig:setSpeed(math.clamp(speed / (if g == "run" then 12 else 5), 0.7, 1.6))
	end
	f.model:PivotTo(CFrame.new(f.pos) * CFrame.Angles(0, f.yaw, 0) * CFrame.Angles(0, 0, f.roll))
	f.rig:step(dt)
end

function DragonPet.summon(who: Model, level: number)
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	level = math.clamp(math.floor(level), 1, 3)
	local plr = Players:GetPlayerFromCharacter(who)
	local role = plr and plr:GetAttribute("EOS_Role")
	local catcher = type(role) == "string" and string.upper(role) == "CATCHER" -- EOS_Role is "CATCHER" / "RUNNER"
	local clip = if catcher then "Breath" else "Ability"
	local fx = (if catcher then "DragonSummon_L" else "DragonSummon_L") .. level
	local ghost = PetModel.build(DragonPet.SPECIES, DragonPet.SUMMON_SCALE, level)
	ghost.Name = "EOS_DragonSummon"
	local rig = PetRig.new(ghost, DragonPet.SPECIES)
	local INTRO = DragonPet.INTRO
	local yaw = GroundPet.yawOf(root.CFrame.LookVector, 0)
	-- seeps up out of smoke at your front-right, facing the way you face; fades away into you at the end
	local function place(k: number)
		local rcf = root.CFrame
		local rise = math.min(1, k / 0.2)
		local lp = Vector3.new(2.0, 0.6 + 0.9 * rise * (2 - rise), -1.3)
		yaw = GroundPet.yawOf(rcf.LookVector, yaw)
		ghost:PivotTo(CFrame.new(rcf * lp) * CFrame.Angles(0, yaw, 0))
		local inK = math.clamp(1 - k / 0.18, 0, 1)
		local outK = math.clamp((k - 0.75) / 0.25, 0, 1)
		GroundPet.fade(ghost, math.max(inK, outK) * 0.95)
	end
	place(0)
	ghost.Parent = workspace.CurrentCamera
	rig:play(clip, 0, rig:length(clip) / (INTRO * 0.8), 0)
	local t0 = os.clock()
	local flashed = false
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local k = (os.clock() - t0) / INTRO
		if not root.Parent or k >= 1 then
			conn:Disconnect()
			ghost:Destroy()
			return
		end
		if not flashed and os.clock() - t0 >= DragonPet.FLASH_AT then
			flashed = true
			local cf, size = ghost:GetBoundingBox()
			GroundPet.playFx(fx, CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.1, 0)))
		end
		place(k)
		rig:step(dt)
	end)
end

function DragonPet.poof(_pos: Vector3, _level: number): boolean
	return false
end

return DragonPet
