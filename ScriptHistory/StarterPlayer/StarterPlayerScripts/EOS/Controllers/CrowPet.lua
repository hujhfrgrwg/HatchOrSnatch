--!strict
-- CrowPet (client): the crow pet's behaviour, used by Pets for species "Crow".
--  * follower: walks behind your right side; takes off and flies at your shoulder when you run,
--    jump or get far ahead; lands and walks again when you stop.
--  * summon (Clone Decoy): the crow swoops in from behind/above the user and flares at their
--    chest; the level's flash plays as it arrives, the same moment the server spawns the copy
--    (AbilityService waits INTRO seconds). L1 white flash; L2 black smoke + crow burst;
--    L3 that plus the red eye mark. Mutations are looks only.
--  * poof: the decoy's end (L2/L3 scatter a few crows; L1 keeps the stock poof in Pets).
-- Bones are driven by CrowRig (no Animation assets). Everything here is local and never physical.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local CrowRig = require(Shared:WaitForChild("CrowRig"))

local CrowPet = {}

CrowPet.INTRO = 0.5 -- seconds from the request to the flash; AbilityService.INTRO.Crow must match
CrowPet.FLASH_AT = 0.12 -- the flash's time inside the CrowDecoy_L* templates
CrowPet.FOLLOW_SCALE = 1.25 -- PetModel scale (1 = about 1 stud tall)
CrowPet.SUMMON_SCALE = 1.6

local WALK_MAX = 2.4 -- studs/s on foot
local STRIDE = 0.95 -- studs per walk cycle at model scale 1 (CrowAnims.Walk)
local TAKEOFF_DIST = 7
local TAKEOFF_SPEED = 9 -- owner's horizontal speed that makes the crow fly
local LAND_SPEED = 2.5

-- ===== helpers =====

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function yawOf(dir: Vector3, fallback: number): number
	local d = flat(dir)
	if d.Magnitude < 1e-3 then
		return fallback
	end
	return math.atan2(-d.X, -d.Z) -- model faces -Z
end

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

local function groundAt(p: Vector3): number?
	refreshRayList()
	local hit = workspace:Raycast(p + Vector3.new(0, 5, 0), Vector3.new(0, -16, 0), rayParams)
	return hit and hit.Position.Y or nil
end

-- ===== follower =====

export type Follower = {
	model: Model,
	rig: any,
	pos: Vector3,
	yaw: number,
	mode: string, -- "ground" | "air" | "land"
	ground: number?,
	groundAt: number,
	slowFor: number,
	t: number,
	level: number,
}

function CrowPet.newFollower(level: number, root: BasePart): Follower
	local m = PetModel.build("Crow", CrowPet.FOLLOW_SCALE, level)
	m.Name = "EOS_Follower"
	local rig = CrowRig.new(m)
	local start = (root.CFrame * CFrame.new(2.3, 3, 2.5)).Position
	local f: Follower = {
		model = m,
		rig = rig,
		pos = start,
		yaw = yawOf(root.CFrame.LookVector, 0),
		mode = "air",
		ground = nil,
		groundAt = 0,
		slowFor = 0,
		t = math.random() * 6,
		level = level,
	}
	rig:play("Fly", 0, 1.1, math.random() * 16)
	m:PivotTo(CFrame.new(start) * CFrame.Angles(0, f.yaw, 0))
	m.Parent = workspace.CurrentCamera -- local only
	return f
end

-- put a returning follower somewhere sensible (after the ability hid it)
function CrowPet.respawnFollower(f: Follower, root: BasePart)
	f.pos = (root.CFrame * CFrame.new(3, 6, 5)).Position
	f.mode = "air"
	f.rig:play("Fly", 0.1, 1.2)
end

function CrowPet.updateFollower(f: Follower, root: BasePart, dt: number)
	f.t += dt
	local cf = root.CFrame
	local look = flat(cf.LookVector)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	local right = Vector3.new(-look.Z, 0, look.X)
	local vel = flat(root.AssemblyLinearVelocity)
	local ownerSpeed = vel.Magnitude
	local scale = f.model:GetScale()

	-- ground under the walking spot, ten times a second
	local spot = root.Position + right * 2.4 - look * 1.8
	if os.clock() - f.groundAt > 0.1 then
		f.groundAt = os.clock()
		f.ground = groundAt(Vector3.new(spot.X, root.Position.Y, spot.Z))
	end
	local gy = f.ground

	if f.mode == "ground" then
		local goal = Vector3.new(spot.X, gy or f.pos.Y, spot.Z)
		local to = flat(goal - f.pos)
		local far = to.Magnitude > TAKEOFF_DIST
		local step = gy == nil or math.abs(goal.Y - f.pos.Y) > 2.5
		if far or step or (ownerSpeed > TAKEOFF_SPEED and to.Magnitude > 2.5) then
			f.mode = "air"
			f.rig:play("Fly", 0.12, 1.25)
		else
			local speed = 0
			if to.Magnitude > 0.45 then
				speed = math.min(WALK_MAX, to.Magnitude * 1.6)
				local move = to.Unit * math.min(speed * dt, to.Magnitude)
				f.pos += move
				f.yaw = approachAngle(f.yaw, yawOf(to, f.yaw), 1 - math.exp(-dt * 10))
			else
				f.yaw = approachAngle(f.yaw, yawOf(look, f.yaw), 1 - math.exp(-dt * 3))
			end
			f.pos = Vector3.new(f.pos.X, f.pos.Y + (goal.Y - f.pos.Y) * (1 - math.exp(-dt * 14)), f.pos.Z)
			if speed > 0.05 then
				f.rig:play("Walk", 0.18)
				f.rig:setSpeed(math.clamp(speed / (STRIDE * scale), 0.6, 3.2))
			else
				f.rig:play("Idle", 0.25)
			end
		end
	end

	if f.mode == "air" or f.mode == "land" then
		if ownerSpeed < LAND_SPEED then
			f.slowFor += dt
		else
			f.slowFor = 0
			if f.mode == "land" then
				f.mode = "air"
			end
		end
		local goal
		if f.mode == "air" then
			goal = root.Position + right * 2.1 - look * 1.7 + Vector3.new(0, 1.5 + math.sin(f.t * 3) * 0.18, 0)
			if f.slowFor > 0.45 and gy ~= nil then
				f.mode = "land"
			end
		else
			goal = Vector3.new(spot.X, gy :: number, spot.Z)
		end
		local before = f.pos
		local rate = if f.mode == "land" then 4.5 else 7
		f.pos = f.pos:Lerp(goal, 1 - math.exp(-dt * rate))
		local moved = f.pos - before
		local face = if flat(moved).Magnitude > 0.02 then moved else look
		f.yaw = approachAngle(f.yaw, yawOf(face, f.yaw), 1 - math.exp(-dt * 8))
		if f.mode == "land" and gy and (f.pos - goal).Magnitude < 0.25 then
			f.mode = "ground"
			f.pos = goal
			f.rig:play("Idle", 0.3)
		elseif f.mode == "land" then
			f.rig:play("Fly", 0.15, 0.9)
		else
			f.rig:play("Fly", 0.15, if ownerSpeed > 12 then 1.4 else 1.1)
		end
	end

	-- far followers animate at a lower rate
	local cam = workspace.CurrentCamera
	local dist = (cam.CFrame.Position - f.pos).Magnitude
	f.model:PivotTo(CFrame.new(f.pos) * CFrame.Angles(0, f.yaw, 0))
	if dist < 80 or (math.floor(f.t * 15) ~= math.floor((f.t - dt) * 15)) then
		f.rig:step(if dist < 80 then dt else math.max(dt, 1 / 15))
	end
end

-- ===== the summon =====

local function vfxFolder(): Instance?
	return ReplicatedStorage:FindFirstChild("VFX")
end

local function playFx(name: string, cf: CFrame): any
	local folder = vfxFolder()
	local emitModule = folder and folder:FindFirstChild("Emit")
	local template = folder and folder:FindFirstChild(name)
	if not emitModule or not template then
		return nil
	end
	local VFX = require(emitModule :: ModuleScript) :: any
	return VFX.play(template, cf, { parent = workspace.CurrentCamera })
end

local function chestOf(who: Model): CFrame?
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	return root.CFrame * CFrame.new(0, 0.75, 0)
end

-- who: the user's character (or NPC model); level 1..3
function CrowPet.summon(who: Model, level: number)
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	level = math.clamp(math.floor(level), 1, 3)
	local crow = PetModel.build("Crow", CrowPet.SUMMON_SCALE, level)
	crow.Name = "EOS_CrowSummon"
	local rig = CrowRig.new(crow)
	local INTRO = CrowPet.INTRO
	-- Swoop frames 4 -> 26 (the flare) over INTRO seconds
	rig:play("Swoop", 0, (26 - 4) / CrowRig.FPS / INTRO, 4)
	-- path in the user's own space: behind (+Z) and above, down to the chest
	local P0 = Vector3.new(2.4, 7.5, 9)
	local P1 = Vector3.new(1.4, 4.8, 3)
	local P2 = Vector3.new(0, 0.35, -0.55)
	local function at(u: number): Vector3
		local a = 1 - u
		return P0 * (a * a) + P1 * (2 * a * u) + P2 * (u * u)
	end
	local function place(u: number)
		local rcf = root.CFrame
		local p = rcf * at(u)
		local ahead = rcf * at(math.min(u + 0.04, 1)) - p
		if ahead.Magnitude < 1e-3 then
			ahead = rcf.LookVector
		end
		local h = flat(ahead)
		local yaw = yawOf(h, 0)
		local pitch = math.atan2(ahead.Y, math.max(h.Magnitude, 1e-3)) * 0.35
		crow:PivotTo(CFrame.new(p) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0))
	end
	place(0)
	crow.Parent = workspace.CurrentCamera
	local t0 = os.clock()
	local fxStarted = false
	local fxHandle: any = nil
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local k = (os.clock() - t0) / INTRO
		if not root.Parent then
			conn:Disconnect()
			crow:Destroy()
			return
		end
		if not fxStarted and k >= 1 - CrowPet.FLASH_AT / INTRO then
			fxStarted = true
			local chest = chestOf(who)
			if chest then
				fxHandle = playFx("CrowDecoy_L" .. level, CFrame.new(chest.Position))
			end
		end
		-- the flash's locked layers ride along with the user for a moment
		if fxHandle and not fxHandle.finished and fxHandle.time < 0.45 then
			local chest = chestOf(who)
			if chest then
				fxHandle.root:PivotTo(CFrame.new(chest.Position))
			end
		end
		if k >= 1 then
			if crow.Parent then
				crow:Destroy() -- vanishes inside the flash
			end
			if not fxHandle or fxHandle.finished or fxHandle.time >= 0.45 then
				conn:Disconnect()
			end
			return
		end
		-- ease: quick dive that settles into the flare
		local u = 1 - (1 - k) * (1 - k) * (1 - 0.35 * k)
		place(u)
		rig:step(dt)
	end)
end

function CrowPet.poof(pos: Vector3, level: number): boolean
	if level < 2 then
		return false
	end
	return playFx("CrowDecoy_Poof", CFrame.new(pos)) ~= nil
end

-- Studio pet tests: player attributes EOS_TestPet / EOS_TestPetLevel override the equipped pet
function CrowPet.speciesOf(plr: Player): (string?, number)
	local sp = plr:GetAttribute("EOS_PetSpecies")
	local lv = plr:GetAttribute("EOS_PetLevel")
	if RunService:IsStudio() then
		local t = plr:GetAttribute("EOS_TestPet")
		if type(t) == "string" and t ~= "" then
			sp = t
			lv = plr:GetAttribute("EOS_TestPetLevel") or lv
		end
	end
	return (if type(sp) == "string" and sp ~= "" then sp else nil), (if type(lv) == "number" then math.clamp(math.floor(lv), 1, 3) else 1)
end

return CrowPet
