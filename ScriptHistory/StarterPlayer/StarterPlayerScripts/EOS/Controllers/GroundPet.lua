--!strict
-- GroundPet (client): the walking follower shared by the rigged ground pets (Kitsune, Prism Chameleon).
--  * walks to a spot behind your right side; trots / runs to keep up (the run clip scales with speed)
--  * far behind or lost (a big drop or a teleport): it pops back next to you
--  * a pet with `ride` (the chameleon) hops onto your right shoulder while you sprint and hops back
--    down when you stop; it clings there with its Cling clip
-- Bones are driven by Shared/PetRig. Everything here is local and never physical.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))

local GroundPet = {}

export type Params = {
	species: string,
	scale: number, -- PetModel scale for the follower
	walkStride: number, -- studs per Walk cycle at rig scale 1
	runStride: number?, -- studs per Run cycle at rig scale 1 (nil: no Run clip)
	runAt: number, -- speed (studs/s) where it switches to Run
	maxSpeed: number, -- its own top speed when it is not catching up
	side: number, -- studs to your right
	back: number, -- studs behind you
	ride: boolean?, -- hops onto your shoulder when you sprint
}

export type Follower = {
	p: Params,
	model: Model,
	rig: any,
	pos: Vector3,
	yaw: number,
	mode: string, -- "ground" | "hop" | "ride" | "hopdown"
	hopT: number,
	hopFrom: Vector3,
	ground: number?,
	groundAt: number,
	fastFor: number,
	slowFor: number,
	speed: number, -- smoothed ground speed (drives the clip and its rate)
	gait: string, -- "idle" | "walk" | "run" (with hysteresis so it never flickers between clips)
	t: number,
	level: number,
}

-- ===== helpers =====

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function GroundPet.yawOf(dir: Vector3, fallback: number): number
	local d = flat(dir)
	if d.Magnitude < 1e-3 then
		return fallback
	end
	return math.atan2(-d.X, -d.Z) -- models face -Z
end
local yawOf = GroundPet.yawOf

local function approachAngle(a: number, b: number, rate: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * rate
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false
local rayListAt = 0

local function refreshRayList()
	if os.clock() - rayListAt < 1 then
		return
	end
	rayListAt = os.clock()
	local list: { Instance } = { workspace.CurrentCamera }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local rt = workspace:FindFirstChild("EOS_Runtime")
	if rt then
		table.insert(list, rt)
	end
	rayParams.FilterDescendantsInstances = list
end

function GroundPet.groundAt(p: Vector3): number?
	refreshRayList()
	local hit = workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
	return hit and hit.Position.Y or nil
end
local groundAt = GroundPet.groundAt

-- the feet height under a character (works for R6 / R15 / NPC rigs)
function GroundPet.feetY(who: Model, root: BasePart): number
	local hum = who:FindFirstChildOfClass("Humanoid")
	local hip = if hum then hum.HipHeight else 2
	if hum and hum.RigType == Enum.HumanoidRigType.R6 then
		hip = 2
	end
	return root.Position.Y - root.Size.Y / 2 - hip
end

-- top of the right shoulder, in world space (for the chameleon's perch)
function GroundPet.shoulder(who: Model, root: BasePart): CFrame
	local ut = who:FindFirstChild("UpperTorso") :: BasePart?
	if ut then
		return ut.CFrame * CFrame.new(ut.Size.X * 0.36, ut.Size.Y * 0.5, 0.05)
	end
	local torso = who:FindFirstChild("Torso") :: BasePart?
	if torso then
		return torso.CFrame * CFrame.new(torso.Size.X * 0.36, torso.Size.Y * 0.5, 0.05)
	end
	return root.CFrame * CFrame.new(0.75, 1.5, 0.05)
end

-- ===== follower =====

function GroundPet.newFollower(p: Params, level: number, root: BasePart): Follower
	local m = PetModel.build(p.species, p.scale, level)
	m.Name = "EOS_Follower"
	local rig = PetRig.new(m, p.species)
	local cf = root.CFrame
	local start = (cf * CFrame.new(p.side, 0, p.back)).Position
	local gy = groundAt(start)
	start = Vector3.new(start.X, gy or (start.Y - 3), start.Z)
	local f: Follower = {
		p = p,
		model = m,
		rig = rig,
		pos = start,
		yaw = yawOf(cf.LookVector, 0),
		mode = "ground",
		hopT = 0,
		hopFrom = start,
		ground = gy,
		groundAt = 0,
		fastFor = 0,
		slowFor = 0,
		speed = 0,
		gait = "idle",
		t = math.random() * 6,
		level = level,
	}
	rig:play("Idle", 0, 1, math.random() * 40)
	m:PivotTo(CFrame.new(start) * CFrame.Angles(0, f.yaw, 0))
	m.Parent = workspace.CurrentCamera -- local only
	return f
end

-- put a returning follower next to its owner (after the ability hid it)
function GroundPet.respawnFollower(f: Follower, root: BasePart)
	local p = (root.CFrame * CFrame.new(f.p.side, 0, f.p.back)).Position
	local gy = groundAt(p)
	f.pos = Vector3.new(p.X, gy or (p.Y - 3), p.Z)
	f.mode = "ground"
	f.gait = "idle"
	f.speed = 0
	f.rig:play("Idle", 0)
end

local function arc(a: Vector3, b: Vector3, u: number, h: number): Vector3
	return a:Lerp(b, u) + Vector3.new(0, h * 4 * u * (1 - u), 0)
end

function GroundPet.updateFollower(f: Follower, root: BasePart, dt: number)
	f.t += dt
	local p = f.p
	local who = root.Parent :: Model
	local cf = root.CFrame
	local look = flat(cf.LookVector)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	local right = Vector3.new(-look.Z, 0, look.X)
	local ownerSpeed = flat(root.AssemblyLinearVelocity).Magnitude
	local scale = f.model:GetScale() / ((f.model:GetAttribute("RigScale") :: number?) or 1)
	if ownerSpeed > 13 then
		f.fastFor += dt
		f.slowFor = 0
	elseif ownerSpeed < 2 then
		f.slowFor += dt
		f.fastFor = 0
	else
		f.fastFor = 0
		f.slowFor = 0
	end

	local spot = root.Position + right * p.side - look * p.back
	if os.clock() - f.groundAt > 0.1 then
		f.groundAt = os.clock()
		f.ground = groundAt(Vector3.new(spot.X, root.Position.Y, spot.Z))
	end
	local gy = f.ground or GroundPet.feetY(who, root)
	local goal = Vector3.new(spot.X, gy, spot.Z)
	local final: CFrame

	if f.mode == "ground" then
		local to = flat(goal - f.pos)
		if to.Magnitude > 32 or math.abs(goal.Y - f.pos.Y) > 7 then
			f.pos = goal -- lost: pop back next to the owner
			to = Vector3.zero
		end
		if p.ride and (f.fastFor > 0.35 or (to.Magnitude > 12 and ownerSpeed > 8)) then
			f.mode = "hop"
			f.hopT = 0
			f.hopFrom = f.pos
			f.rig:play("Hop", 0.08, 1)
		end
		local speed = 0
		if to.Magnitude > 0.5 then
			-- keep up: never slower than the owner once it is behind
			-- keep up: a little faster than the owner, and faster still the further behind it is
			local behind = math.max(0, to.Magnitude - 2)
			local want = math.max(p.maxSpeed, ownerSpeed * 1.12 + behind * 5)
			speed = math.min(want, to.Magnitude * 14)
			f.pos += to.Unit * math.min(speed * dt, to.Magnitude)
			f.yaw = approachAngle(f.yaw, yawOf(to, f.yaw), 1 - math.exp(-dt * 10))
		else
			f.yaw = approachAngle(f.yaw, yawOf(look, f.yaw), 1 - math.exp(-dt * 3))
		end
		f.pos = Vector3.new(f.pos.X, f.pos.Y + (gy - f.pos.Y) * (1 - math.exp(-dt * 14)), f.pos.Z)
		if f.mode == "ground" then
			-- smooth the speed, then pick the clip with hysteresis (no flicker between Walk and Run)
			f.speed += (speed - f.speed) * (1 - math.exp(-dt * 8))
			local sp = f.speed
			local g = f.gait
			if p.runStride and (sp > p.runAt * 1.15 or (g == "run" and sp > p.runAt * 0.8)) then
				g = "run"
			elseif sp > 0.25 or (g ~= "idle" and sp > 0.12) then
				g = "walk"
			else
				g = "idle"
			end
			if g ~= f.gait then
				f.gait = g
				f.rig:play(if g == "run" then "Run" elseif g == "walk" then "Walk" else "Idle", if g == "idle" then 0.25 else 0.2)
			end
			if g == "run" then
				f.rig:setSpeed(math.clamp(sp / ((p.runStride :: number) * scale), 0.75, 1.5))
			elseif g == "walk" then
				f.rig:setSpeed(math.clamp(sp / (p.walkStride * scale), 0.6, 1.8))
			end
		end
		final = CFrame.new(f.pos) * CFrame.Angles(0, f.yaw, 0)
	end

	if f.mode == "hop" or f.mode == "hopdown" then
		f.hopT += dt / 0.42
		local u = math.min(f.hopT, 1)
		local target: Vector3
		if f.mode == "hop" then
			target = GroundPet.shoulder(who, root).Position
		else
			target = goal
		end
		f.pos = arc(f.hopFrom, target, u, 1.6)
		f.yaw = approachAngle(f.yaw, yawOf(look, f.yaw), 1 - math.exp(-dt * 10))
		if u >= 1 then
			if f.mode == "hop" then
				f.mode = "ride"
				f.rig:play("Cling", 0.12)
			else
				f.mode = "ground"
				f.gait = "idle"
				f.rig:play("Idle", 0.2)
			end
		end
		final = CFrame.new(f.pos) * CFrame.Angles(0, f.yaw, 0)
	end

	if f.mode == "ride" then
		local sh = GroundPet.shoulder(who, root)
		f.pos = sh.Position
		f.yaw = yawOf(look, f.yaw)
		-- perched along the shoulder, facing forward
		final = CFrame.new(f.pos) * CFrame.Angles(0, f.yaw, 0)
		if f.slowFor > 1.1 then
			f.mode = "hopdown"
			f.hopT = 0
			f.hopFrom = f.pos
			f.rig:play("Hop", 0.08, 1)
		end
	end

	local cam = workspace.CurrentCamera
	local dist = (cam.CFrame.Position - f.pos).Magnitude
	f.model:PivotTo(final :: CFrame)
	if dist < 80 or (math.floor(f.t * 15) ~= math.floor((f.t - dt) * 15)) then
		f.rig:step(if dist < 80 then dt else math.max(dt, 1 / 15))
	end
end

-- ===== effects helpers (shared by the summons) =====

function GroundPet.playFx(name: string, cf: CFrame): any
	local folder = ReplicatedStorage:FindFirstChild("VFX")
	local emitModule = folder and folder:FindFirstChild("Emit")
	local template = folder and folder:FindFirstChild(name)
	if not emitModule or not template then
		return nil
	end
	local VFX = require(emitModule :: ModuleScript) :: any
	return VFX.play(template, cf, { parent = workspace.CurrentCamera })
end

function GroundPet.chestOf(who: Model): CFrame?
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	return root.CFrame * CFrame.new(0, 0.75, 0)
end

-- fade a model in or out locally (0 = solid, 1 = gone)
function GroundPet.fade(model: Model, a: number)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "RootPart" then
			d.LocalTransparencyModifier = a
		end
	end
end

return GroundPet
