--!nocheck
-- LobbyAmbience (HOS-LOBBY-004, 18 Oct 2026, Matthew): the lobby's small life, client side only.
--   lanterns  every hanging lantern (a model with an A03_Chain child: the trees' lanterns and the altar lamp posts')
--             swings gently from the top of its chain, but only while you're within LobbyGate.ANIM_RANGE of it and it's
--             on screen. (The incubator's two lanterns swing in IncubatorWorld.)
--   wind      a few white wind trails drift and curl through the air in front of you: a pool of WIND_COUNT invisible
--             movers with a Trail each, recycled, never more. Off with reduce effects.
-- Nothing runs in a match or while the camera is away from the lobby (LobbyGate.active()); the lanterns are put back at
-- rest and the trails switched off when that happens. Lantern visibility is re-checked a few times a second and lantern
-- motion is capped at 30 Hz. Lanterns that stream in later join; ones that stream out are dropped.
local RunService = game:GetService("RunService")

local LobbyGate = require(script.Parent:WaitForChild("LobbyGate"))

local LobbyAmbience = {}

local SWING = { math.rad(3.5), math.rad(2.5) } -- swing on the two flat axes (radians)
local LANTERN_HZ = 30
local VIS_EVERY = 0.2 -- seconds between visibility checks
local WIND_COUNT = 4
local WIND_DIR = Vector3.new(1, 0, 0.35).Unit -- the lobby's breeze
local WIND_LIFE = 1.0 -- trail lifetime (seconds)

local rng = Random.new()

---------------------------------------------------------------- lanterns
type Unit = { model: Model, parts: { BasePart }, rest: { CFrame }, pivot: Vector3, phase: number, amp: number, speed: number, dirty: boolean, swinging: boolean, visible: boolean }
local units: { [Model]: Unit } = {}

local function restore(u: Unit)
	local parts, cfs = {}, {}
	for i, p in u.parts do
		if p.Parent then
			table.insert(parts, p)
			table.insert(cfs, u.rest[i])
		end
	end
	if #parts > 0 then workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
	u.swinging = false
end

-- (re)read a lantern's parts and rest positions (back at rest first) and the top of its chain
local function rebuild(u: Unit)
	if u.swinging then restore(u) end
	u.parts, u.rest = {}, {}
	for _, d in u.model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(u.parts, d)
			table.insert(u.rest, d.CFrame)
		end
	end
	local chain = u.model:FindFirstChild("A03_Chain")
	if chain and chain:IsA("Model") and #chain:GetChildren() > 0 then
		local cf, sz = chain:GetBoundingBox()
		u.pivot = cf.Position + Vector3.new(0, sz.Y / 2, 0)
	elseif chain and chain:IsA("BasePart") then
		u.pivot = chain.Position + Vector3.new(0, chain.Size.Y / 2, 0)
	end
	u.dirty = false
end

local function register(model: Instance?)
	if not (model and model:IsA("Model")) or units[model] or not model:FindFirstChild("A03_Chain") then return end
	local u: Unit = {
		model = model, parts = {}, rest = {}, pivot = model:GetPivot().Position, phase = rng:NextNumber(0, 2 * math.pi),
		amp = rng:NextNumber(0.75, 1.2), speed = rng:NextNumber(0.85, 1.15), dirty = true, swinging = false, visible = false,
	}
	units[model] = u
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then u.dirty = true end
	end)
	model.DescendantRemoving:Connect(function(d)
		if d:IsA("BasePart") then u.dirty = true end
	end)
	rebuild(u)
end

local function restoreAll()
	for _, u in units do
		if u.swinging then restore(u) end
	end
end

---------------------------------------------------------------- wind
type Gust = { part: BasePart, trail: Trail, live: boolean, nextAt: number, t0: number, dur: number, origin: Vector3, dir: Vector3, speed: number, side: Vector3, phase: number, loopAt: number?, armed: boolean }
local gusts: { Gust } = {}
local windOn = false

local function reduceEffects(): boolean
	local ok, CameraFX = pcall(function()
		return require(script.Parent:FindFirstChild("CameraFX"))
	end)
	return ok and type(CameraFX) == "table" and CameraFX.reduceEffects == true
end

local function makeGust(): Gust
	local p = Instance.new("Part")
	p.Name = "WindGust"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.17, 0), Vector3.new(0, -0.17, 0) -- a 0.34-stud ribbon
	a0.Parent, a1.Parent = p, p
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(Color3.new(1, 1, 1))
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.12, 0.2), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 1) })
	tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.15, 1), NumberSequenceKeypoint.new(1, 0.1) }) -- pointed at the head, tapering off behind
	tr.Lifetime = WIND_LIFE
	tr.LightEmission = 0.6
	tr.FaceCamera = true
	tr.MinLength = 0.05
	tr.Enabled = false
	tr.Parent = p
	p.Parent = workspace.CurrentCamera
	return { part = p, trail = tr, live = false, nextAt = os.clock() + rng:NextNumber(0, 2), t0 = 0, dur = 0, origin = Vector3.zero, dir = WIND_DIR, speed = 0, side = Vector3.zero, phase = 0, loopAt = nil, armed = false }
end

-- start a gust somewhere ahead of the camera, inside the lobby
local function launch(g: Gust, now: number): boolean
	local cam = workspace.CurrentCamera
	local cf = cam.CFrame
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	look = if look.Magnitude > 0.05 then look.Unit else Vector3.zAxis
	local right = Vector3.yAxis:Cross(look) * -1
	local at = cf.Position + look * rng:NextNumber(14, 38) + right * rng:NextNumber(-18, 18)
	local c = LobbyGate.centre()
	if Vector3.new(at.X - c.X, 0, at.Z - c.Z).Magnitude > LobbyGate.radius() - 4 then return false end
	g.dir = (WIND_DIR + Vector3.new(rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.05, 0.12), rng:NextNumber(-0.25, 0.25))).Unit
	g.origin = Vector3.new(at.X, LobbyGate.floorY() + rng:NextNumber(1.5, 6.5), at.Z) - g.dir * 6 -- starts a little upwind
	g.speed = rng:NextNumber(11, 17)
	g.dur = rng:NextNumber(1.5, 2.5)
	g.side = Vector3.yAxis:Cross(g.dir).Unit
	g.phase = rng:NextNumber(0, 2 * math.pi)
	g.loopAt = if rng:NextNumber() < 0.5 then rng:NextNumber(0.3, 0.6) * g.dur else nil -- half of them curl round once
	g.t0 = now
	g.live = true
	g.armed = false -- the trail switches on next frame, once the mover is at its start (no streak from its old spot)
	g.part.CFrame = CFrame.new(g.origin)
	return true
end

local function gustPos(g: Gust, tau: number): Vector3
	local p = g.origin + g.dir * g.speed * tau
		+ Vector3.yAxis * math.sin(tau * 3 + g.phase) * 0.45
		+ g.side * math.sin(tau * 2.1 + g.phase * 1.7) * 0.8
	local L = g.loopAt
	if L and tau > L then
		local a = math.min(1, (tau - L) / 0.55) * 2 * math.pi -- one loop over 0.55 s
		p += (g.dir * math.sin(a) + Vector3.yAxis * (1 - math.cos(a))) * 1.1
	end
	return p
end

local function windStop()
	if not windOn then return end
	windOn = false
	for _, g in gusts do
		g.trail.Enabled = false
		g.live = false
	end
end

local function windStep(now: number)
	if reduceEffects() then
		windStop()
		return
	end
	windOn = true
	if #gusts == 0 then
		for _ = 1, WIND_COUNT do table.insert(gusts, makeGust()) end
	end
	local parts, cfs = {}, {}
	for _, g in gusts do
		if not g.live then
			if now >= g.nextAt and not launch(g, now) then
				g.nextAt = now + 0.5 -- that spot was off the island: try again soon
			end
		else
			local tau = now - g.t0
			if tau >= g.dur then
				g.live = false
				g.trail.Enabled = false
				g.nextAt = now + WIND_LIFE + rng:NextNumber(1.5, 4.5)
			else
				if not g.armed then
					g.armed = true
					g.trail.Enabled = true
				end
				table.insert(parts, g.part)
				table.insert(cfs, CFrame.new(gustPos(g, tau)))
			end
		end
	end
	if #parts > 0 then workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
end

---------------------------------------------------------------- the frame
local lanternAcc, visAcc = 0, 0
local function step(dt: number)
	if not LobbyGate.active() then
		restoreAll()
		windStop()
		return
	end
	local now = os.clock()
	visAcc += dt
	if visAcc >= VIS_EVERY then
		visAcc = 0
		for model, u in units do
			if not model:IsDescendantOf(workspace) then
				units[model] = nil
			else
				u.visible = LobbyGate.near(u.pivot, LobbyGate.ANIM_RANGE) and LobbyGate.onScreen(u.pivot - Vector3.new(0, 1.3, 0), 2.5)
			end
		end
	end
	lanternAcc += dt
	if lanternAcc >= 1 / LANTERN_HZ then
		lanternAcc = 0
		local parts, cfs = {}, {}
		for _, u in units do
			if u.visible then
				if u.dirty then rebuild(u) end
				local P = u.pivot
				local s = now * u.speed
				local T = CFrame.new(P) * CFrame.Angles(math.sin(s * 1.9 + u.phase) * SWING[1] * u.amp, 0, math.sin(s * 1.3 + u.phase) * SWING[2] * u.amp) * CFrame.new(-P)
				for i, p in u.parts do
					table.insert(parts, p)
					table.insert(cfs, T * u.rest[i])
				end
				u.swinging = true
			end
		end
		if #parts > 0 then workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
	end
	windStep(now)
end

function LobbyAmbience.init()
	-- the lanterns there now, and any that stream in later
	task.spawn(function()
		for _, d in workspace:GetDescendants() do
			if d.Name == "A03_Chain" then register(d.Parent) end
		end
	end)
	workspace.DescendantAdded:Connect(function(d)
		if d.Name == "A03_Chain" then task.defer(register, d.Parent) end
	end)
	RunService.RenderStepped:Connect(step)
end

return LobbyAmbience
