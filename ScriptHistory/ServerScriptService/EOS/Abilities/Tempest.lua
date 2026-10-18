--!strict
-- Abilities.Tempest (HOS-PET-009 prototype). Numbers: AbilityConfig.ARCHETYPES.Tempest.
--  * Runner, PULSE: a ring shows around you for `windup` seconds, then every Catcher within `radius` is
--    pushed `push` studs straight away from you (never into a safe zone, a wall or off the map: shorter
--    pushes are tried). A Catcher who was pushed can't be pushed again for `immunity` seconds, by anyone.
--  * Catcher, STORM BALL: a ball rolls from you the way you face at `speed` studs/s for `range` studs (a
--    wall stops it). The first Runner it touches is slowed to `slow` of top speed for `slowTime` seconds.
-- Placeholder looks: neon parts in the Tempest colour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = require(script.Parent.Shared)
local CharacterService = require(script.Parent.Parent.Services.CharacterService)
local AbilityConfig = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("AbilityConfig"))

local Tempest = {}

local COLOR = AbilityConfig.ARCHETYPES.Tempest.color
local pushImmuneUntil: { [any]: number } = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- ===== PULSE =====

function Tempest.Runner(ctx: any): (boolean, string?)
	local root = ctx.root :: BasePart?
	if not root then
		return false, "NO_CHARACTER"
	end
	local d = ctx.def
	local me = ctx.player
	local role = me:GetAttribute("EOS_Role")
	local tele = Shared.ring(Shared.groundBelow(root.Position) + Vector3.new(0, 0.12, 0), d.radius, COLOR, d.windup, 0.55)
	Shared.tagVfx(tele, "PulseCharge", nil, ctx.species, ctx.level) -- the charge ring and arcs (HOS-VFX-003)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < d.windup and tele.Parent and root.Parent do
			tele.CFrame = CFrame.new(Shared.groundBelow(root.Position) + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
			task.wait()
		end
	end)
	task.delay(d.windup, function()
		if me:GetAttribute("EOS_Role") ~= role or not root.Parent then
			return
		end
		local center = root.Position
		Shared.vfx("PulseBlast", Shared.groundBelow(center), nil, ctx.species, ctx.level)
		local now = os.clock()
		for _, c in ipairs(Shared.actorsInRole("CATCHER", true)) do
			local cr = c.Character.HumanoidRootPart :: BasePart
			local off = flat(cr.Position - center)
			if off.Magnitude <= d.radius and now >= (pushImmuneUntil[c] or 0) then
				local dir = if off.Magnitude > 0.1 then off.Unit else flat(root.CFrame.LookVector).Unit
				for _, frac in ipairs({ 1, 0.66, 0.33 }) do
					local dest = cr.Position + dir * d.push * frac
					if Shared.validPosition(c, dest) then
						pushImmuneUntil[c] = now + d.immunity
						Shared.slideTo(c, dest, 0.2)
						Shared.vfx("KnockHit", cr.Position, dir, ctx.species, ctx.level)
						break
					end
				end
			end
		end
	end)
	return true, nil
end

-- ===== STORM BALL =====

function Tempest.Catcher(ctx: any): (boolean, string?)
	local root = ctx.root :: BasePart?
	if not root then
		return false, "NO_CHARACTER"
	end
	local d = ctx.def
	local dir = flat(root.CFrame.LookVector)
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.zAxis
	local start = root.Position + dir * 2.5 - Vector3.new(0, 1, 0)
	local ball = Instance.new("Part")
	ball.Name = "EOS_StormBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2.4, 2.4, 2.4)
	ball.Material = Enum.Material.SmoothPlastic -- a solid toy ball (HOS-VFX-003); clients add arcs, glow and dust
	ball.Color = Color3.fromRGB(255, 205, 30)
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow = true, false, false, false, false
	ball.CFrame = CFrame.new(start)
	ball.Parent = Shared.runtimeFolder("AbilityFx")
	Shared.tagVfx(ball, "StormBall", true, ctx.species, ctx.level)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { Shared.runtimeFolder("AbilityFx") }
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local rt = workspace:FindFirstChild("EOS_Runtime")
	if rt then
		table.insert(ignore, rt)
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	params.CollisionGroup = root.CollisionGroup
	local travelled = 0
	local bounces = 0
	local pos = start
	local conn
	local function stop()
		conn:Disconnect()
		ball:Destroy()
	end
	conn = RunService.Heartbeat:Connect(function(dt)
		if not ball.Parent then
			conn:Disconnect()
			return
		end
		local step = math.min(d.speed * dt, d.range - travelled)
		if step <= 0 then
			stop()
			return
		end
		local hit = workspace:Raycast(pos, dir * (step + 1.2), params)
		if hit then
			-- HOS-VFX-003 (Wrecking Ball reference): bounce off the first wall, same total range; stop at the next
			local n = flat(hit.Normal)
			n = if n.Magnitude > 0.01 then n.Unit else -dir
			Shared.vfx("StormBounce", hit.Position, n, ctx.species, ctx.level)
			if bounces < (d.bounces or 0) then
				bounces += 1
				local out = flat(dir - 2 * dir:Dot(n) * n)
				dir = if out.Magnitude > 0.01 then out.Unit else -dir
				return
			end
			stop()
			return
		end
		pos += dir * step
		travelled += step
		-- it rolls: spin about the axis across its path
		ball.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-travelled / 1.2, 0, 0)
		for _, r in ipairs(Shared.actorsInRole("RUNNER", true)) do
			local rr = r.Character.HumanoidRootPart :: BasePart
			local off = rr.Position - pos
			if flat(off).Magnitude <= d.hitRadius and math.abs(off.Y) < 5 then
				CharacterService.slowFor(r, d.slow, d.slowTime)
				Shared.tagVfx(Shared.ring(Shared.groundBelow(rr.Position) + Vector3.new(0, 0.15, 0), 2.2, COLOR, d.slowTime, 0.15), "Slowed", nil, ctx.species)
				Shared.vfx("StormHit", pos, nil, ctx.species, ctx.level)
				stop()
				return
			end
		end
	end)
	return true, nil
end

function Tempest.cleanup(plr: Player)
	pushImmuneUntil[plr] = nil
end

return Tempest
