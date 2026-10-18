--!strict
-- Abilities.Decoy (HOS-PET-001): the Decoy archetype. Numbers: AbilityConfig.ARCHETYPES.Decoy.
--  * Runner: a copy of you (same look, egg and knife) runs ahead for `duration` seconds, then poofs.
--    It can't tag or be tagged; Catchers who swing at it see "DECOY!". It leaves on the press: a
--    species' fly-in (the Crow, the Kitsune) plays over it and never delays it.
--  * Catcher: stub (the snare is not built yet).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SharedRS = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local AnimConfig = require(SharedRS:WaitForChild("AnimConfig"))
local GameConfig = require(SharedRS:WaitForChild("GameConfig"))
local Shared = require(script.Parent.Shared)

local Decoy = {}

local decoyRng = Random.new()

local function decoy(plr: Player, dir: Vector3, duration: number, spread: number, species: string?, level: number?)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local human = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hrp or not human then
		return
	end
	local was = char.Archivable
	char.Archivable = true
	local clone = char:Clone()
	char.Archivable = was
	if not clone then
		return
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("ForceField") or d:IsA("LinearVelocity") or d:IsA("AlignOrientation") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	clone.Name = plr.Name
	clone:SetAttribute("EOS_Decoy", plr.UserId)
	local h = clone:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = clone:FindFirstChild("HumanoidRootPart") :: BasePart
	if not h or not root then
		clone:Destroy()
		return
	end
	local speed = human:GetAttribute("EOS_MaxSpeed")
	h.WalkSpeed = if type(speed) == "number" then speed else GameConfig.Movement.RUNNER_SPEED
	h.AutoRotate = true
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	h:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local moving = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
	if flat.Magnitude < 0.1 and moving.Magnitude > 4 then
		flat = moving -- no stick input but still carrying speed (a slide, a lunge): go the way you're moving
	elseif flat.Magnitude < 0.1 then
		flat = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	end
	flat = flat.Unit
	-- the copy picks its own heading inside a cone around yours, so Catchers can't call which way it goes
	local half = math.rad(spread / 2)
	flat = (CFrame.Angles(0, decoyRng:NextNumber(-half, half), 0) * flat).Unit
	-- The server sees a running player a moment in the past, and the copy reaches their screen later
	-- still: start it where they'll be by then (ping + interpolation), already at full speed, so it
	-- doesn't appear behind them. A wall in the way stops the lead short of it.
	local vel = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
	-- measured in Studio: a new copy shows up on the owner's screen about 0.3 s behind the server
	local lead = vel * math.clamp(plr:GetNetworkPing() + 0.3, 0.25, 0.6)
	local start = hrp.Position
	if lead.Magnitude > 0.05 then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char, Shared.runtimeFolder("Decoys") }
		local hit = workspace:Raycast(hrp.Position, lead, params)
		start = if hit
			then hrp.Position + lead.Unit * math.max(0, (hit.Position - hrp.Position).Magnitude - 1.5)
			else hrp.Position + lead
	end
	clone:PivotTo(CFrame.lookAt(start, start + flat))
	clone.Parent = Shared.runtimeFolder("Decoys")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	root.AssemblyLinearVelocity = flat * h.WalkSpeed -- already running when it appears
	-- the same run clip the owner shows (published id; Studio-only clips can't play on the server)
	local animator = h:FindFirstChildOfClass("Animator") or Instance.new("Animator", h)
	local runId = AnimConfig.ids.Run
	if runId and runId ~= "" then
		local a = Instance.new("Animation")
		a.AnimationId = runId
		local ok, track = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok and track then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Movement
			track:Play(0.1, 1, h.WalkSpeed / (AnimConfig.naturalSpeed.Run or 21.5))
		end
	end
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not clone.Parent or os.clock() - t0 > duration then
			conn:Disconnect()
			if clone.Parent then
				Shared.fx({
					userId = plr.UserId,
					family = "Decoy",
					kind = "poof",
					pos = root.Position,
					species = species,
					level = level,
				})
				clone:Destroy()
			end
			return
		end
		h:Move(flat, false)
	end)
end

function Decoy.Runner(ctx: any): (boolean, string?)
	if not ctx.root then
		return false, "NO_CHARACTER"
	end
	-- on the press (Hunter, 17 Oct): the species' fly-in plays over the copy and never delays it
	-- a puff at your feet that you and the copy both leave, so nobody can tell which is which
	Shared.vfx("DecoySplit", Shared.groundBelow(ctx.root.Position), nil, ctx.species, ctx.level)
	decoy(ctx.player, ctx.moveDir, ctx.def.duration, ctx.def.spread or 145, ctx.species, ctx.level)
	return true, nil
end

-- ===== SNARE (Catcher, HOS-PET-008 prototype) =====
-- A ring at your feet everyone can see, `radius` studs, for `duration` seconds. The first Runner whose
-- body enters it is rooted for `root` seconds (top speed 0, so no running and no dash) and the snare is
-- used up. One snare per Catcher: a new one replaces the old.
local CharacterService = require(script.Parent.Parent.Services.CharacterService)
local AbilityConfig = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("AbilityConfig"))
local SNARE_COLOR = AbilityConfig.ARCHETYPES.Decoy.color
local snares: { [Player]: { part: BasePart, conn: RBXScriptConnection } } = {}

local function clearSnare(plr: Player)
	local s = snares[plr]
	snares[plr] = nil
	if s then
		s.conn:Disconnect()
		s.part:Destroy()
	end
end

function Decoy.Catcher(ctx: any): (boolean, string?)
	local root = ctx.root :: BasePart?
	if not root then
		return false, "NO_CHARACTER"
	end
	if Shared.inSafeZone(root.Position) then
		return false, "SAFE_ZONE"
	end
	local d = ctx.def
	local plr = ctx.player
	clearSnare(plr)
	local ground = Shared.groundBelow(root.Position)
	local center = ground + Vector3.new(0, 0.12, 0)
	local part = Shared.ring(center, d.radius, SNARE_COLOR, 0, 0.3)
	part.Name = "EOS_Snare"
	Shared.tagVfx(part, "Snare", nil, ctx.species) -- the chain seal everyone sees (HOS-VFX-001)
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if os.clock() - t0 > d.duration or not part.Parent then
			if snares[plr] and snares[plr].part == part then
				clearSnare(plr)
			end
			return
		end
		for _, r in ipairs(Shared.actorsInRole("RUNNER", true)) do
			local rr = r.Character.HumanoidRootPart :: BasePart
			local off = rr.Position - center
			if Vector3.new(off.X, 0, off.Z).Magnitude <= d.radius and math.abs(off.Y) < 6 then
				CharacterService.slowFor(r, 0, d.root)
				local feet = Shared.groundBelow(rr.Position)
				Shared.tagVfx(Shared.ring(feet + Vector3.new(0, 0.15, 0), 2.2, SNARE_COLOR, d.root, 0.1), "Rooted", nil, ctx.species)
				Shared.vfx("SnareTrigger", feet, nil, ctx.species, ctx.level)
				clearSnare(plr)
				return
			end
		end
	end)
	snares[plr] = { part = part, conn = conn }
	return true, nil
end

-- the match is over for this player: their copies go
function Decoy.cleanup(plr: Player)
	clearSnare(plr)
	local f = workspace:FindFirstChild("EOS_Runtime")
	local decoys = f and f:FindFirstChild("Decoys")
	if decoys then
		for _, d in ipairs(decoys:GetChildren()) do
			if d:GetAttribute("EOS_Decoy") == plr.UserId then
				d:Destroy()
			end
		end
	end
end

return Decoy
