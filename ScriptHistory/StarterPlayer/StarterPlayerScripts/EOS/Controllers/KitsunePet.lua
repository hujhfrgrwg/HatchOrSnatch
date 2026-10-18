--!strict
-- KitsunePet (client): the Kitsune (Clone Decoy).
--  * follower: GroundPet (walks / runs behind your right side)
--  * summon: the fox appears behind the user, runs in, hops diagonally to the left, diagonally to the
--    right (closing the gap from far behind), then leaps into the user's back; a burst marks each take-off and spirit sparks trail it.
--    The level's flash fires as it merges, the moment the server spawns the copy (AbilityService
--    waits INTRO seconds). L1 white flash + foxfire; L2 warm fox-spirit flash, ofuda, more foxfire;
--    L3 adds the shrine seal and a red torii gate blooming behind the user.
--  * poof: the copy's end (L2/L3 scatter paper charms; L1 keeps the stock poof in Pets).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))
local GroundPet = require(script.Parent:WaitForChild("GroundPet"))

local KitsunePet = {}

KitsunePet.SPECIES = "Kitsune"
KitsunePet.INTRO = 1.25 -- request -> merge; AbilityService.INTRO.Kitsune must match
KitsunePet.FLASH_AT = 0.12 -- the flash's time inside the KitsuneDecoy_L* templates
KitsunePet.SUMMON_SCALE = 1.5

KitsunePet.PARAMS = {
	species = "Kitsune",
	scale = 1.25,
	walkStride = 0.67,
	runStride = 1.41,
	runAt = 1.4,
	maxSpeed = 3,
	side = 2.2,
	back = 2.0,
} :: GroundPet.Params

function KitsunePet.newFollower(level: number, root: BasePart)
	return GroundPet.newFollower(KitsunePet.PARAMS, level, root)
end
KitsunePet.respawnFollower = GroundPet.respawnFollower
KitsunePet.updateFollower = GroundPet.updateFollower

-- path in the user's own space (x right, y up from the feet, z behind):
-- run in from behind -> diagonal hop to the LEFT -> diagonal hop to the RIGHT -> leap into the torso.
-- Each leg's end as a fraction of INTRO; a small burst (KitsuneHop_L*) fires at every take-off.
local T_RUN, T_J1, T_J2 = 0.24, 0.50, 0.74

local function arc(a: Vector3, b: Vector3, u: number, h: number): Vector3
	return a:Lerp(b, u) + Vector3.new(0, h * 4 * u * (1 - u), 0)
end

local function bez(a: Vector3, b: Vector3, c: Vector3, u: number): Vector3
	local v = 1 - u
	return a * (v * v) + b * (2 * v * u) + c * (u * u)
end

-- a little spirit trail on the fox while it is in the air (level-tinted sparks)
local function addTrail(fox: Model, level: number): ParticleEmitter?
	local body = fox:FindFirstChild("Kitsune_Body") :: BasePart?
	if not body then
		return nil
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "SpiritTrail"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Brightness = 3
	e.Color = if level >= 2
		then ColorSequence.new(Color3.fromRGB(255, 244, 225), Color3.fromRGB(255, 140, 60))
		else ColorSequence.new(Color3.fromRGB(255, 255, 255))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 + 0.08 * level), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.1)
	e.Lifetime = NumberRange.new(0.25, 0.45)
	e.Speed = NumberRange.new(0.3, 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 0
	e.LockedToPart = false
	e.Parent = body
	return e
end

function KitsunePet.summon(who: Model, level: number)
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	level = math.clamp(math.floor(level), 1, 3)
	local fox = PetModel.build(KitsunePet.SPECIES, KitsunePet.SUMMON_SCALE, level)
	fox.Name = "EOS_KitsuneSummon"
	local rig = PetRig.new(fox, KitsunePet.SPECIES)
	local INTRO = KitsunePet.INTRO
	local baseScale = fox:GetScale()
	local chestH = root.Position.Y + 0.6 - GroundPet.feetY(who, root) -- torso height above the feet
	local T = chestH - 1.15 -- fox feet here puts its body at your torso (feet = 0)
	-- starts well behind you and closes the gap with every hop, leaping into your back at the end
	local P0 = Vector3.new(0.4, 0, 15) -- far behind
	local P1 = Vector3.new(-0.6, 0, 9) -- still behind: springs up from here
	local L = Vector3.new(-2.6, T, 5.2) -- diagonal hop 1: up to torso height, behind-left
	local R = Vector3.new(2.4, T, 2.3) -- diagonal hop 2: across, behind-right (catching up)
	local C = Vector3.new(0, chestH - 0.95, 0.3) -- into the torso (from behind)

	local function local3(k: number): (Vector3, string)
		if k < T_RUN then
			return P0:Lerp(P1, k / T_RUN), "run"
		elseif k < T_J1 then
			local u = (k - T_RUN) / (T_J1 - T_RUN)
			-- springs up: rises fast, levels out at torso height (with a small crest)
			local e = 1 - (1 - u) * (1 - u)
			local p = P1:Lerp(L, u)
			return Vector3.new(p.X, P1.Y + (L.Y - P1.Y) * e + 0.6 * 4 * u * (1 - u), p.Z), "j1"
		elseif k < T_J2 then
			return arc(L, R, (k - T_J1) / (T_J2 - T_J1), 0.7), "j2"
		end
		local u = math.min((k - T_J2) / (1 - T_J2), 1)
		return bez(R, Vector3.new(1.3, T + 0.8, 1.2), C, u), "j3"
	end

	local trail = addTrail(fox, level)
	local leg = ""
	local lastP: Vector3? = nil
	local yaw = GroundPet.yawOf(root.CFrame.LookVector, 0)
	local dtNow = 1 / 60
	local function hopFx(at: Vector3)
		GroundPet.playFx("KitsuneHop_L" .. level, CFrame.new(at))
	end
	local function place(k: number)
		local rcf = root.CFrame
		local feet = GroundPet.feetY(who, root)
		local lp, which = local3(k)
		local wp = Vector3.new(0, feet - rcf.Position.Y, 0) + rcf * lp
		if which ~= leg then
			leg = which
			if which == "run" then
				rig:play("Run", 0, 1.7)
			else
				-- one Jump clip per hop, squeezed into the hop's time; a burst where it takes off
				local span = (if which == "j1" then T_J1 - T_RUN elseif which == "j2" then T_J2 - T_J1 else 1 - T_J2) * INTRO
				rig:play("Jump", 0.04, rig:length("Jump") / math.max(span, 0.05), 0)
				hopFx(wp)
				if trail then
					trail.Rate = 35 + 15 * level
				end
			end
		end
		local ahead = if lastP then wp - lastP else rcf.LookVector
		if (ahead :: Vector3).Magnitude < 1e-3 then
			ahead = rcf.LookVector
		end
		lastP = wp
		-- face mostly forward (it is chasing you from behind), angled about 30-35 degrees toward each
		-- side hop so the left / right reads without turning fully side-on
		local d = rcf:VectorToObjectSpace(ahead)
		if which == "j1" then
			d = Vector3.new(-0.6, 0, -1) -- hop to your left: angled left
		elseif which == "j2" then
			d = Vector3.new(0.7, 0, -1) -- hop to your right: angled right
		elseif which == "j3" then
			d = Vector3.new(-0.4, 0, -1) -- leaps forward into your back
		end
		local want = GroundPet.yawOf(rcf:VectorToWorldSpace(d), yaw)
		local turn = if which == "run" then 1 else 1 - math.exp(-dtNow * 22)
		yaw = yaw + (((want - yaw + math.pi) % (2 * math.pi)) - math.pi) * turn
		fox:PivotTo(CFrame.new(wp) * CFrame.Angles(0, yaw, 0))
		-- merge: shrinks into the user over the last stretch of the final leap
		local m = math.clamp((k - 0.88) / 0.12, 0, 1)
		if m > 0 then
			fox:ScaleTo(baseScale * (1 - 0.65 * m))
			GroundPet.fade(fox, m * 0.8)
		end
	end
	place(0)
	fox.Parent = workspace.CurrentCamera
	local t0 = os.clock()
	local fxStarted = false
	local fxHandle: any = nil
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local k = (os.clock() - t0) / INTRO
		if not root.Parent then
			conn:Disconnect()
			fox:Destroy()
			return
		end
		if not fxStarted and k >= 1 - KitsunePet.FLASH_AT / INTRO then
			fxStarted = true
			local chest = GroundPet.chestOf(who)
			if chest then
				fxHandle = GroundPet.playFx("KitsuneDecoy_L" .. level, (root.CFrame - root.Position) + chest.Position)
			end
		end
		if fxHandle and not fxHandle.finished and fxHandle.time < 0.45 then
			local chest = GroundPet.chestOf(who)
			if chest then
				fxHandle.root:PivotTo((root.CFrame - root.Position) + chest.Position)
			end
		end
		if k >= 1 then
			if fox.Parent then
				fox:Destroy() -- merged
			end
			if not fxHandle or fxHandle.finished or fxHandle.time >= 0.45 then
				conn:Disconnect()
			end
			return
		end
		dtNow = dt
		place(k)
		rig:step(dt)
	end)
end

function KitsunePet.poof(pos: Vector3, level: number): boolean
	if level < 2 then
		return false
	end
	return GroundPet.playFx("KitsuneDecoy_Poof", CFrame.new(pos)) ~= nil
end

return KitsunePet
