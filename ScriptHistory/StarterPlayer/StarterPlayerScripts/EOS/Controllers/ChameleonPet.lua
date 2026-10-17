--!strict
-- ChameleonPet (client): the Prism Chameleon (Invisibility).
--  * follower: GroundPet with `ride` (walks beside you, rides your right shoulder while you sprint)
--  * summon: the chameleon pops up beside the user, hops onto their right shoulder, clings, then
--    melts into their body; the level's flash fires as it melts in, the moment the server makes the
--    user invisible (AbilityService waits INTRO seconds).
--    L1 white flash; L2 chromatic accents + spectrum shimmer; L3 a stronger spectrum flash and a
--    spectrum wash wrapping the user's body just before they vanish.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))
local GroundPet = require(script.Parent:WaitForChild("GroundPet"))

local ChameleonPet = {}

ChameleonPet.SPECIES = "Prism Chameleon"
ChameleonPet.INTRO = 0.7 -- request -> invisible; AbilityService.INTRO["Prism Chameleon"] must match
ChameleonPet.FLASH_AT = 0.12 -- the flash's time inside the PrismInvis_L* templates
ChameleonPet.SUMMON_SCALE = 1.25

ChameleonPet.PARAMS = {
	species = "Prism Chameleon",
	scale = 1.2,
	walkStride = 0.22,
	runStride = nil,
	runAt = 99,
	maxSpeed = 2.4,
	side = 2.0,
	back = 1.6,
	ride = true,
} :: GroundPet.Params

function ChameleonPet.newFollower(level: number, root: BasePart)
	return GroundPet.newFollower(ChameleonPet.PARAMS, level, root)
end
ChameleonPet.respawnFollower = GroundPet.respawnFollower
ChameleonPet.updateFollower = GroundPet.updateFollower

local T_APPEAR, T_HOP = 0.14, 0.52 -- fractions of INTRO: appear, hop ends on the shoulder; then melt

-- a quick spectrum wash over the user (L3): hue-cycling highlight that fades as they vanish
local function spectrumWrap(who: Model, dur: number)
	local h = Instance.new("Highlight")
	h.Name = "EOS_PrismWrap"
	h.Adornee = who
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.FillTransparency = 0.45
	h.OutlineTransparency = 0.2
	h.Parent = workspace.CurrentCamera
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / dur
		if k >= 1 or not who.Parent then
			conn:Disconnect()
			h:Destroy()
			return
		end
		local hue = (os.clock() * 1.6) % 1
		h.FillColor = Color3.fromHSV(hue, 0.55, 1)
		h.OutlineColor = Color3.fromHSV((hue + 0.33) % 1, 0.35, 1)
		h.FillTransparency = 0.45 + 0.55 * k * k
		h.OutlineTransparency = 0.2 + 0.8 * k
	end)
end

function ChameleonPet.summon(who: Model, level: number)
	local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	level = math.clamp(math.floor(level), 1, 3)
	local cham = PetModel.build(ChameleonPet.SPECIES, ChameleonPet.SUMMON_SCALE, level)
	cham.Name = "EOS_ChameleonSummon"
	local rig = PetRig.new(cham, ChameleonPet.SPECIES)
	local INTRO = ChameleonPet.INTRO
	local baseScale = cham:GetScale()
	local start = Vector3.new(1.9, 0, 0.9) -- beside the right foot (user space, y from the feet)
	local leg = ""
	local hopFrom: Vector3? = nil

	local function place(k: number)
		local rcf = root.CFrame
		local feet = GroundPet.feetY(who, root)
		local yaw = GroundPet.yawOf(rcf.LookVector, 0)
		local ground = Vector3.new(0, feet - rcf.Position.Y, 0) + rcf * start
		local sh = GroundPet.shoulder(who, root).Position
		local pos: Vector3
		if k < T_APPEAR then
			if leg ~= "appear" then
				leg = "appear"
				rig:play("Idle", 0, 1.5)
			end
			pos = ground
			GroundPet.fade(cham, 1 - k / T_APPEAR) -- shimmers into view
			yaw = GroundPet.yawOf(sh - ground, yaw)
		elseif k < T_HOP then
			if leg ~= "hop" then
				leg = "hop"
				hopFrom = ground
				GroundPet.fade(cham, 0)
				rig:play("Hop", 0.05, rig:length("Hop") / ((T_HOP - T_APPEAR) * INTRO), 0)
			end
			local u = (k - T_APPEAR) / (T_HOP - T_APPEAR)
			pos = (hopFrom :: Vector3):Lerp(sh, u) + Vector3.new(0, 1.4 * 4 * u * (1 - u), 0)
			yaw = GroundPet.yawOf(sh - (hopFrom :: Vector3), yaw)
		else
			if leg ~= "cling" then
				leg = "cling"
				rig:play("Cling", 0.06, 1.4)
			end
			-- melt: shrinks into the shoulder and sinks into the chest while it fades
			local m = (k - T_HOP) / (1 - T_HOP)
			local chest = (GroundPet.chestOf(who) :: CFrame).Position
			pos = sh:Lerp(chest, m * m * 0.7)
			cham:ScaleTo(baseScale * (1 - 0.7 * m))
			GroundPet.fade(cham, math.clamp(m * 1.1, 0, 0.95))
		end
		cham:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw, 0))
	end
	place(0)
	cham.Parent = workspace.CurrentCamera
	local t0 = os.clock()
	local fxStarted, wrapped = false, false
	local fxHandle: any = nil
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local k = (os.clock() - t0) / INTRO
		if not root.Parent then
			conn:Disconnect()
			cham:Destroy()
			return
		end
		if level >= 3 and not wrapped and k >= T_HOP then
			wrapped = true
			spectrumWrap(who, (1 - T_HOP) * INTRO + 0.35)
		end
		if not fxStarted and k >= 1 - ChameleonPet.FLASH_AT / INTRO then
			fxStarted = true
			local chest = GroundPet.chestOf(who)
			if chest then
				fxHandle = GroundPet.playFx("PrismInvis_L" .. level, CFrame.new(chest.Position))
			end
		end
		if fxHandle and not fxHandle.finished and fxHandle.time < 0.45 then
			local chest = GroundPet.chestOf(who)
			if chest then
				fxHandle.root:PivotTo(CFrame.new(chest.Position))
			end
		end
		if k >= 1 then
			if cham.Parent then
				cham:Destroy() -- melted in
			end
			if not fxHandle or fxHandle.finished or fxHandle.time >= 0.45 then
				conn:Disconnect()
			end
			return
		end
		place(k)
		rig:step(dt)
	end)
end

function ChameleonPet.poof(_pos: Vector3, _level: number): boolean
	return false
end

return ChameleonPet
