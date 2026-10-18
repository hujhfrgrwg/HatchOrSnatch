--!strict
-- MantaPet (client): the Mirage Manta (Invisibility), a floating translucent manta spirit with galaxy
-- stars inside its body.
--  * follower: floats behind your right shoulder, bobbing; glides (Glide clip) and banks into turns when
--    it has to keep up, settles into its slow Idle undulation when you stop. Never touches the ground.
--  * summon (INTRO seconds, AbilityService.INTRO["Mirage Manta"] must match): it flies in behind the user,
--    loops round their right side to the front, turns 90 degrees onto its side with its belly toward them
--    and grows into a curtain covering them head to feet; the level's shimmer (MantaVeil_L*) fires and the
--    curtain fades away in place as the server makes the user invisible (they fade out behind it).
--    L1 subtle white-blue shimmer; L2 a watery cyan wash + ripples; L3 a strong spectral veil
--    (blue -> violet highlight wrapping the body) and pink-violet star glints.
-- Visual only: the ability itself is the shared Invisibility backend.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))
local GroundPet = require(script.Parent:WaitForChild("GroundPet"))

local MantaPet = {}

MantaPet.SPECIES = "Mirage Manta"
MantaPet.INTRO = 1.2 -- request -> invisible; AbilityService (Abilities.Shared.INTRO) must match
MantaPet.FLASH_AT = 0.12 -- the flash's time inside the MantaVeil_L* templates
MantaPet.SCALE = 1.0 -- follower
MantaPet.SUMMON_SCALE = 2.1 -- big enough to wrap a body
MantaPet.CENTER = 0.42 -- body centre above the model pivot, in model units (rig scale 1)
MantaPet.CURTAIN_COVER = 1.25 -- the curtain spans this much of the user's height
MantaPet.FOLD_SPAN = 1.0 -- curtain span / rest wingspan (flat curtain)
MantaPet.PASS_FADE = 0.5 -- seconds the curtain keeps flying past while it fades out
MantaPet.DEBUG_K = nil :: number?

-- follower placement (studs, in the owner's frame): right, up from the root, behind
MantaPet.SIDE = 2.3
MantaPet.HEIGHT = 1.9
MantaPet.BACK = 2.0

export type Follower = {
	model: Model,
	rig: any,
	pos: Vector3,
	vel: Vector3,
	yaw: number,
	roll: number,
	pitch: number,
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

local function studsScale(model: Model): number
	local rs = model:GetAttribute("RigScale")
	return model:GetScale() / (if type(rs) == "number" and rs > 0 then rs else 1)
end

-- place the model so its BODY CENTRE sits on cf (rotations happen about the body, not the pivot)
local function placeCentre(model: Model, cf: CFrame)
	model:PivotTo(cf * CFrame.new(0, -MantaPet.CENTER * studsScale(model), 0))
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
	local bob = math.sin(t * 1.9) * 0.22
	return root.Position + right * MantaPet.SIDE - look * MantaPet.BACK + Vector3.new(0, MantaPet.HEIGHT + bob, 0)
end

function MantaPet.newFollower(level: number, root: BasePart): Follower
	local m = PetModel.build(MantaPet.SPECIES, MantaPet.SCALE, level)
	m.Name = "EOS_Follower"
	local rig = PetRig.new(m, MantaPet.SPECIES)
	local f: Follower = {
		model = m,
		rig = rig,
		pos = Vector3.zero,
		vel = Vector3.zero,
		yaw = GroundPet.yawOf(root.CFrame.LookVector, 0),
		roll = 0,
		pitch = 0,
		t = math.random() * 6,
		level = level,
		gait = "idle",
	}
	f.pos = spotFor(f, root)
	rig:play("Idle", 0, 1, math.random() * 60)
	placeCentre(m, CFrame.new(f.pos) * CFrame.Angles(0, f.yaw, 0))
	m.Parent = workspace.CurrentCamera -- local only
	return f
end

function MantaPet.respawnFollower(f: Follower, root: BasePart)
	f.pos = spotFor(f, root)
	f.vel = Vector3.zero
	f.roll, f.pitch = 0, 0
	f.gait = "idle"
	f.rig:play("Idle", 0)
end

function MantaPet.updateFollower(f: Follower, root: BasePart, dt: number)
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
	-- critically damped follow: soft, floaty, but never left behind
	local prev = f.pos
	local k = 1 - math.exp(-dt * (3.2 + math.min(to.Magnitude, 12) * 0.35))
	f.pos = f.pos + to * k
	local vel = (f.pos - prev) / dt
	f.vel = f.vel:Lerp(vel, 1 - math.exp(-dt * 6))
	local speed = flat(f.vel).Magnitude

	local look = flat(root.CFrame.LookVector)
	local wantYaw = if speed > 1.2 then GroundPet.yawOf(f.vel, f.yaw) else GroundPet.yawOf(look, f.yaw)
	local oldYaw = f.yaw
	f.yaw = approachAngle(f.yaw, wantYaw, 1 - math.exp(-dt * (if speed > 1.2 then 5 else 2.2)))
	local yawRate = ((f.yaw - oldYaw + math.pi) % (2 * math.pi) - math.pi) / dt
	-- bank into turns, nose follows climbs and dives
	f.roll += (math.clamp(-yawRate * 0.22, -0.55, 0.55) - f.roll) * (1 - math.exp(-dt * 5))
	f.pitch += (math.clamp(f.vel.Y * 0.06, -0.35, 0.35) - f.pitch) * (1 - math.exp(-dt * 4))

	local g = f.gait
	if speed > 3.5 or (g == "glide" and speed > 1.8) then
		g = "glide"
	else
		g = "idle"
	end
	if g ~= f.gait then
		f.gait = g
		f.rig:play(if g == "glide" then "Glide" else "Idle", 0.35)
	end
	if g == "glide" then
		f.rig:setSpeed(math.clamp(speed / 9, 0.8, 1.7))
	end

	local cf = CFrame.new(f.pos) * CFrame.Angles(0, f.yaw, 0) * CFrame.Angles(f.pitch, 0, f.roll)
	placeCentre(f.model, cf)
	local cam = workspace.CurrentCamera
	local dist = (cam.CFrame.Position - f.pos).Magnitude
	if dist < 90 or (math.floor(f.t * 15) ~= math.floor((f.t - dt) * 15)) then
		f.rig:step(if dist < 90 then dt else math.max(dt, 1 / 15))
	end
end

-- ===== summon =====

local T_IN, T_ORBIT = 0.36, 0.62 -- fractions of INTRO: glide in behind, loop round the right; then sweep past
local SWEEP_ANG = -58 -- where the loop hands over to the sweep (degrees from the user's front, - = right)

local function bezier(a: Vector3, c: Vector3, b: Vector3, u: number): Vector3
	return a:Lerp(c, u):Lerp(c:Lerp(b, u), u)
end

-- a soft veil wash over the user while the fins close (L2 watery cyan, L3 blue -> violet spectral)
local function veilWash(who: Model, level: number, dur: number)
	if level < 2 then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "EOS_MantaVeil"
	h.Adornee = who
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.FillTransparency = 1
	h.OutlineTransparency = 1
	h.Parent = workspace.CurrentCamera
	local t0 = os.clock()
	local peakFill = if level >= 3 then 0.35 else 0.6
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / dur
		if k >= 1 or not who.Parent then
			conn:Disconnect()
			h:Destroy()
			return
		end
		local inK = math.min(k / 0.35, 1)
		local outK = math.max(0, (k - 0.55) / 0.45)
		local a = inK * (1 - outK)
		if level >= 3 then
			local w = 0.5 + 0.5 * math.sin(os.clock() * 7)
			h.FillColor = Color3.fromRGB(70, 120, 255):Lerp(Color3.fromRGB(170, 110, 255), w)
			h.OutlineColor = Color3.fromRGB(200, 230, 255):Lerp(Color3.fromRGB(255, 170, 240), w)
		else
			h.FillColor = Color3.fromRGB(80, 190, 255)
			h.OutlineColor = Color3.fromRGB(200, 245, 255)
		end
		h.FillTransparency = 1 - (1 - peakFill) * a
		h.OutlineTransparency = 1 - 0.75 * a
	end)
end

function MantaPet.summon(who: Model, level: number)
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	level = math.clamp(math.floor(level), 1, 3)
	local manta = PetModel.build(MantaPet.SPECIES, MantaPet.SUMMON_SCALE, level)
	manta.Name = "EOS_MantaSummon"
	local rig = PetRig.new(manta, MantaPet.SPECIES)
	local INTRO = MantaPet.INTRO
	local leg = ""
	local lastPos: Vector3? = nil
	local lastCF: CFrame? = nil
	local wrapFrom: CFrame? = nil
	local s = studsScale(manta)
	local charH = 5
	local charOffset = Vector3.zero
	local stepDt = 1 / 60
	local dissolving = false
	local trail: ParticleEmitter? = nil

	-- user frame: x right, y up from the root, z behind
	-- it flies in behind the user, loops round their right side to the front, then turns 90 degrees onto
	-- its side (wings vertical, belly toward the user) and hangs there like a curtain while the fins close
	local P0 = Vector3.new(-1.6, 4.2, 7.5) -- high behind
	local PC = Vector3.new(0.8, 3.4, 4.2)
	local P1 = Vector3.new(2.4, 2.4, 2.6) -- behind-right: the loop starts here
	local R_ORBIT = 3.4

	local function glideFrame(pos: Vector3, dir: Vector3, bank: number): CFrame
		local d = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.new(0, 0, -1)
		local cf = CFrame.lookAt(pos, pos + d)
		return cf * CFrame.Angles(0, 0, bank)
	end

	local function place(k: number)
		local rcf = root.CFrame
		local yawCF = CFrame.new(rcf.Position) * CFrame.Angles(0, GroundPet.yawOf(rcf.LookVector, 0), 0)
		local cf: CFrame
		if k < T_IN then
			if leg ~= "in" then
				leg = "in"
				rig:play("Glide", 0, 1.6)
			end
			local u = k / T_IN
			local e = u * u * (3 - 2 * u)
			local pos = yawCF * bezier(P0, PC, P1, e)
			local dir = if lastPos then pos - lastPos else (yawCF * PC) - (yawCF * P0)
			lastPos = pos
			cf = glideFrame(pos, dir, -0.25 * math.sin(u * math.pi))
			GroundPet.fade(manta, math.clamp(1 - u * 3.5, 0, 1)) -- shimmers into view
		elseif k < T_ORBIT then
			if leg ~= "orbit" then
				leg = "orbit"
				GroundPet.fade(manta, 0)
				rig:play("Glide", 0.15, 1.3)
			end
			local u = (k - T_IN) / (T_ORBIT - T_IN)
			-- loop round the right side to the front-right: angle from the user's front (0 = front, -90 = right)
			local a0, a1 = math.rad(-135), math.rad(SWEEP_ANG)
			local ang = a0 + (a1 - a0) * u
			local lp = Vector3.new(-math.sin(ang) * R_ORBIT, 2.4 - 1.9 * u, -math.cos(ang) * R_ORBIT)
			local pos = yawCF * lp
			local dir = if lastPos then pos - lastPos else rcf.RightVector
			lastPos = pos
			cf = glideFrame(pos, dir, -0.55) -- banked toward the user
		else
			if leg ~= "sweep" then
				leg = "sweep"
				wrapFrom = lastCF
				-- the user's full height and middle (accessories included), measured once
				local ccf, csz = who:GetBoundingBox()
				charH = math.clamp(csz.Y, 3, 9)
				charOffset = Vector3.new(0, ccf.Position.Y - root.Position.Y, 0)
				rig:play("Glide", 0.2, 0.9)
				if trail then
					trail.Enabled = true
				end
			end
			-- the curtain flies PAST the user: it rolls 90 degrees onto its side (wings vertical, belly toward
			-- them) and keeps gliding head-first across their front, right to left. It is centred on them at
			-- k = 1 (the moment they turn invisible) and carries on past while it fades.
			local u = (k - T_ORBIT) / (1 - T_ORBIT) -- 0 at the loop's end, 1 centred, > 1 past
			local roll = math.clamp(u / 0.45, 0, 1)
			roll = roll * roll * (3 - 2 * roll)
			local look = flat(rcf.LookVector)
			look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
			local right = Vector3.new(-look.Z, 0, look.X)
			local startX = -math.sin(math.rad(SWEEP_ANG)) * R_ORBIT
			local x = startX * (1 - u)
			local dist = 1.6 + 0.6 * math.max(0, 1 - u)
			local centre = rcf.Position + charOffset + right * x + look * dist
			local curtain = CFrame.fromMatrix(centre, -Vector3.yAxis, look)
			local from = (wrapFrom or curtain) - (wrapFrom or curtain).Position
			cf = CFrame.new(centre) * from:Lerp(curtain - curtain.Position, roll)
			lastCF = cf
			placeCentre(manta, cf)
			if dissolving then
				return
			end
			-- grow so the vertical wingspan covers the user head to feet by the time it is centred
			local _, sz = manta:GetBoundingBox()
			local want = charH * MantaPet.CURTAIN_COVER / MantaPet.FOLD_SPAN
			local sNow = manta:GetScale()
			local targetScale = sNow * want / math.max(sz.X, 0.05)
			local f = math.clamp(stepDt * 9, 0, 1) * math.max(roll, 0.25)
			manta:ScaleTo(sNow + (targetScale - sNow) * f)
			placeCentre(manta, cf)
			return
		end
		lastCF = cf
		placeCentre(manta, cf)
	end
	-- stars shed off the manta as it sweeps past: small twinkles drifting gently outward (not a burst)
	local body = manta:FindFirstChild("Manta_Body") :: BasePart?
	if body then
		local tr = Instance.new("ParticleEmitter")
		tr.Name = "StarTrail"
		tr.Enabled = false
		tr.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		tr.Rate = ({ 45, 60, 80 })[level]
		tr.Lifetime = NumberRange.new(0.8, 1.5)
		tr.Speed = NumberRange.new(0.8, 2.6)
		tr.SpreadAngle = Vector2.new(180, 180)
		tr.Drag = 1.6
		tr.LockedToPart = false
		tr.LightEmission = 1
		tr.Brightness = 3
		tr.ZOffset = 0.6
		tr.Rotation = NumberRange.new(0, 360)
		tr.RotSpeed = NumberRange.new(-90, 90)
		tr.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.32),
			NumberSequenceKeypoint.new(0.6, 0.22),
			NumberSequenceKeypoint.new(1, 0),
		})
		tr.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		local white = Color3.fromRGB(240, 248, 255)
		tr.Color = if level >= 3
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, white),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 160, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 235)),
			})
			elseif level == 2 then ColorSequence.new(white, Color3.fromRGB(130, 230, 255))
			else ColorSequence.new(white, Color3.fromRGB(150, 195, 255))
		tr.Parent = body
		trail = tr
	end
	place(0)
	manta.Parent = workspace.CurrentCamera
	local t0 = os.clock()
	local fxStarted, washed = false, false
	local fxHandle: any = nil
	local dissolveT = MantaPet.PASS_FADE
	local doneAt: number? = nil
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		stepDt = dt
		-- MantaPet.DEBUG_K (Studio checks only): hold the summon at this fraction of INTRO
		if MantaPet.DEBUG_K then
			t0 = os.clock() - MantaPet.DEBUG_K * INTRO
		end
		local k = (os.clock() - t0) / INTRO
		if not root.Parent then
			conn:Disconnect()
			manta:Destroy()
			return
		end
		if not washed and k >= T_ORBIT then
			washed = true
			veilWash(who, level, (1 - T_ORBIT) * INTRO + 0.5)
		end
		if not fxStarted and k >= 1 - MantaPet.FLASH_AT / INTRO then
			fxStarted = true
			local chest = GroundPet.chestOf(who)
			if chest then
				fxHandle = GroundPet.playFx("MantaVeil_L" .. level, CFrame.new(chest.Position))
			end
		end
		if fxHandle and not fxHandle.finished and fxHandle.time < 0.5 then
			local chest = GroundPet.chestOf(who)
			if chest then
				fxHandle.root:PivotTo(CFrame.new(chest.Position))
			end
		end
		if doneAt then
			-- the manta is gone; wait for its last trailing stars to fade, then clean up
			if os.clock() >= doneAt and (not fxHandle or fxHandle.finished or fxHandle.time >= 0.5) then
				conn:Disconnect()
				manta:Destroy()
			end
			return
		end
		if k >= 1 then
			-- it flies on past while the curtain fades; the user fades out behind it (Controllers.Invisibility)
			dissolving = true
			local d = ((os.clock() - t0) - INTRO) / dissolveT
			if d >= 1 then
				GroundPet.fade(manta, 1)
				if trail then
					trail.Enabled = false
				end
				doneAt = os.clock() + 1.6
				return
			end
			GroundPet.fade(manta, math.clamp(d * d, 0, 1))
			place(k)
			rig:step(dt)
			return
		end
		place(k)
		rig:step(dt)
	end)
	local _ = s
end

function MantaPet.poof(_pos: Vector3, _level: number): boolean
	return false
end

return MantaPet
