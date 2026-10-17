-- Movement: how the local character moves, faces and dashes.
--  * momentum: a held direction builds speed, turns redirect it, letting go brakes (planar
--    LinearVelocity; gravity stays native). Values: GameConfig.Movement (Huss Valley reference pass).
--  * facing: Runners (and everyone in the lobby) face the way they move; Catchers in a match face
--    where the camera looks, so they sidestep and backpedal. In a match, pushing backwards (S)
--    keeps anyone facing the camera and walks them backwards slowly.
--  * dash: Space / gamepad A / the round DASH button. Read against the CAMERA, keyboard, gamepad and
--    touch thumbstick alike: W+A / A (a stick up-left or left) slides straight left (9 o'clock), the
--    D side straight right (3 o'clock); S+A / S+D slide diagonally backwards (7:30 / 4:30) with the
--    same left / right slide clips; straight back (S) back-dashes straight back; straight ahead (or
--    no push) doesn't dash at all. Nor does a dash the way the BODY faces (developer, Oct 15): running
--    sideways to the camera with D held, D + dash would just be a forward dash, so it's refused.
--    The body faces the camera's way for the dash so the clip reads, and the dash holds its line until
--    it has eased back down. Catchers can't dash at all (GameConfig.Dash.CATCHER_DASH).
--  * no jumping (JumpHeight 0 from the server; the Jumping state is disabled here too).
-- The server owns the top speed (Humanoid attribute EOS_MaxSpeed) and validates every tag.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local M = GameConfig.Movement
local D = GameConfig.Dash

local Movement = {}
Movement.speedFraction = 0 -- read by the camera (FOV kick)
Movement.facingMode = "MOVE" -- "MOVE" | "CAMERA"
Movement.dashReadyAt = 0
Movement.dashing = false
Movement.dashSide = "Back" -- "Back" | "Left" | "Right" (there is no forward dash)
Movement.refusedAt = -math.huge -- last time a dash press found no allowed direction (the UI shows why nothing happened)
Movement.refusedWhy = "FORWARD" -- "FORWARD" (straight ahead of the camera / no push) | "FACING" (the way the body faces)
Movement.backpedaling = false -- in a match and pushing backwards: facing the camera, walking backwards slowly
Movement.dashStartedAt = -math.huge
Movement._testWish = nil :: Vector3? -- test hook: stands in for the move input (Studio checks only)

local listeners: { (side: string) -> () } = {}
function Movement.onDash(fn: (side: string) -> ())
	table.insert(listeners, fn)
end

local player = Players.LocalPlayer
type Data = {
	character: Model,
	human: Humanoid,
	root: BasePart,
	drive: LinearVelocity,
	velocity: Vector3,
	active: boolean,
	teleportMarker: any,
	dashDir: Vector3,
	heldFacing: Vector3?,
}
local current: Data? = nil
-- the anchored turn the momentum step is working through (see turnFrame)
type Turn = { wish: Vector3, keep: Vector3, flip: Vector3 }
local turn: Turn? = nil

local tuning: Instance? = nil
local function tune(name: string, default: number): number
	if not tuning or not tuning.Parent then
		tuning = ReplicatedStorage:FindFirstChild("EOS_Tuning")
	end
	local v = tuning and tuning:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function planar(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function topSpeed(human: Humanoid): number
	local cap = human:GetAttribute("EOS_MaxSpeed")
	local base = if type(cap) == "number" then math.max(0, cap) else 16
	return base * tune("SpeedMultiplier", 1) -- live tuning knob; the server's role speed is the base
end

local function suspend(data: Data)
	data.drive.Enabled = false
	if data.active then
		data.human.WalkSpeed = topSpeed(data.human)
		data.human.AutoRotate = true
		data.active = false
	end
	data.velocity = planar(data.root.AssemblyLinearVelocity)
end

local function bind(character: Model)
	current = nil
	local human = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if player.Character ~= character or not human or not root then
		return
	end
	human:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	local attachment = Instance.new("Attachment")
	attachment.Name = "EOS_MoveAttachment"
	attachment.Parent = root
	local drive = Instance.new("LinearVelocity")
	drive.Name = "EOS_MoveDrive"
	drive.Attachment0 = attachment
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.PrimaryTangentAxis = Vector3.xAxis
	drive.SecondaryTangentAxis = Vector3.zAxis
	drive.ForceLimitsEnabled = true
	drive.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	drive.Enabled = false
	drive.Parent = root
	current = {
		character = character,
		human = human,
		root = root,
		drive = drive,
		velocity = planar(root.AssemblyLinearVelocity),
		active = false,
		teleportMarker = player:GetAttribute("EOS_TeleportedAt"),
		dashDir = Vector3.zero,
		heldFacing = nil,
	}
	Movement.dashing = false
	turn = nil
end

local function approach(v: Vector3, target: Vector3, amount: number): Vector3
	local delta = target - v
	return if delta.Magnitude <= amount then target else v + delta.Unit * amount
end

local function toward(x: number, target: number, amount: number): number
	return if x < target then math.min(x + amount, target) else math.max(x - amount, target)
end

-- A turn taken at speed (A+W -> W+D, W -> W+D) is split along the line halfway between where you
-- were going and where you now push: that part (the shared W) carries on, and only the part that
-- flipped brakes and builds back. Anchored when the keys change, re-anchored if the input swings
-- further; reversals and starts from slow use the plain step below.
local TURN_RETARGET = math.cos(math.rad(8)) -- the input has swung this far since anchoring: re-anchor
local TURN_STRAIGHT = math.cos(math.rad(3)) -- closer than this to your motion is not a turn

local function turnFrame(v: Vector3, w: Vector3, top: number): Turn?
	local speed = v.Magnitude
	if speed < top * M.TURN_MIN_SPEED then
		turn = nil
		return nil
	end
	if turn and turn.wish:Dot(w) >= TURN_RETARGET then
		return turn
	end
	turn = nil
	local u = v / speed
	local c = u:Dot(w)
	if c > TURN_STRAIGHT or c < math.cos(M.TURN_MAX_ANGLE) then
		return nil
	end
	local keep = (u + w).Unit
	local flip = w - keep * w:Dot(keep)
	if flip.Magnitude < 1e-4 then
		return nil
	end
	turn = { wish = w, keep = keep, flip = flip.Unit }
	return turn
end

-- one axis: brake motion the wrong way, kick then build up to the target, ease down if above it
local function axisStep(x: number, target: number, dt: number, decel: number, build: number): number
	if x < -0.01 then
		return math.min(0, x + decel * dt)
	elseif x < target then
		local rate = if x < target * tune("KickFraction", M.KICK_FRACTION) then math.max(build, tune("KickAccel", M.KICK_ACCEL)) else build
		return math.min(target, x + rate * dt)
	end
	return math.max(target, x - decel * dt)
end

-- one momentum step toward the wished velocity (reference-measured, see GameConfig.Movement).
-- Split the velocity into the part along your input and the rest: the rest (sideways or backwards)
-- dies fast, the part along your input builds with a quick kick then a slower ramp.
local function step(v: Vector3, wish: Vector3, grounded: boolean, dt: number, top: number): Vector3
	dt = math.min(dt, 0.1)
	local decel = if grounded then tune("Decel", M.DECEL) else M.AIR_ACCELERATION
	local magnitude = math.min(wish.Magnitude, 1)
	if magnitude < 0.001 then
		turn = nil
		return approach(v, Vector3.zero, (if grounded then tune("StopDecel", M.STOP_DECEL) else M.AIR_ACCELERATION) * dt)
	end
	local w = wish.Unit
	local target = top * magnitude
	if not grounded then
		turn = nil
	end
	local t = if grounded then turnFrame(v, w, top) else nil
	if t then
		local keep = axisStep(v:Dot(t.keep), target * w:Dot(t.keep), dt, decel, tune("Acceleration", M.ACCELERATION))
		local flip = axisStep(v:Dot(t.flip), target * w:Dot(t.flip), dt, decel, tune("TurnAcceleration", M.TURN_ACCELERATION))
		return t.keep * keep + t.flip * flip
	end
	local along = v:Dot(w)
	local side = approach(v - w * along, Vector3.zero, decel * dt) -- motion you're not pushing for
	if along < -0.01 then
		along = math.min(0, along + decel * dt) -- plant: kill the backwards part first
	elseif along < target then
		local kickTo = target * tune("KickFraction", M.KICK_FRACTION)
		local rate = if not grounded then M.AIR_ACCELERATION
			elseif along < kickTo then tune("KickAccel", M.KICK_ACCEL)
			else tune("Acceleration", M.ACCELERATION)
		along = math.min(target, along + rate * dt)
	else
		along = math.max(target, along - decel * dt)
	end
	return w * along + side
end

local function updateFacingMode()
	local catcher = player:GetAttribute("EOS_InMatch") == true and player:GetAttribute("EOS_Role") == "CATCHER"
	Movement.facingMode = if catcher then "CAMERA" else "MOVE"
end

-- why a dash can't happen right now (nil = it can)
function Movement.blockedReason(): string?
	local data = current
	if not D.ENABLED then
		return "OFF"
	end
	if not D.CATCHER_DASH and player:GetAttribute("EOS_InMatch") == true and player:GetAttribute("EOS_Role") == "CATCHER" then
		return "CATCHER" -- Catchers don't dash (the dash meter / button hide)
	end
	if not data or not data.active or data.human.Health <= 0 then
		return "PAUSED"
	end
	if topSpeed(data.human) <= 0 then
		return "PAUSED"
	end
	if os.clock() < Movement.dashReadyAt then
		return "COOLDOWN"
	end
	return nil
end

-- 0 = just used, 1 = ready
function Movement.dashCharge(): number
	local left = Movement.dashReadyAt - os.clock()
	return if left <= 0 then 1 else 1 - left / math.max(tune("DashCooldown", D.COOLDOWN), 0.01)
end

-- what a dash would be right now, read against the camera: side = "Left" | "Right" | "Back", or nil
-- when there's no side / back direction (no push, or straight ahead: there is no forward dash) or the
-- dash would go the way the body faces (running sideways with D held: D + dash = a forward dash).
-- W+A / A = straight left (9 o'clock), W+D / D = straight right (3 o'clock), S+A / S+D = diagonally
-- backwards (7:30 / 4:30) with the left / right slide clip, S = straight back.
-- 4th value when refused: "FORWARD" (no push / straight ahead of the camera) or "FACING" (the body's way).
local function dashPlan(data: Data): (string?, Vector3?, Vector3, string?)
	local root = data.root
	local wish = planar(Movement._testWish or data.human.MoveDirection)
	-- the frame is the camera (the move input is camera-relative too, keys and thumbstick alike), so
	-- the body turning toward a diagonal you've been holding never turns a slide into "straight ahead"
	local cam = workspace.CurrentCamera
	local fwd = if cam then planar(cam.CFrame.LookVector) else Vector3.zero
	if fwd.Magnitude < 0.01 then
		fwd = planar(root.CFrame.LookVector)
	end
	fwd = if fwd.Magnitude > 0.01 then fwd.Unit else Vector3.new(0, 0, -1)
	local right = fwd:Cross(Vector3.yAxis)
	local angle = math.atan2(wish:Dot(right), wish:Dot(fwd)) -- 0 = straight ahead, + = to the right
	local a = math.abs(angle)
	if wish.Magnitude <= 0.1 or a <= D.FORWARD_MAX_ANGLE then
		return nil, nil, fwd, "FORWARD"
	end
	local side: string, dir: Vector3
	if a >= D.BACK_MIN_ANGLE then
		side, dir = "Back", -fwd
	else
		local toSide = if angle > 0 then right else -right
		side = if angle > 0 then "Right" else "Left"
		dir = if a >= D.DIAG_BACK_FROM then (toSide - fwd).Unit else toSide
	end
	-- never the way the body faces: that's a forward dash whatever the camera says
	local body = planar(root.CFrame.LookVector)
	if body.Magnitude > 0.01 and dir:Dot(body.Unit) >= math.cos(D.BODY_FORWARD_MAX_ANGLE) then
		return nil, nil, fwd, "FACING"
	end
	return side, dir, fwd, nil
end

local function startDash(data: Data, side: string, dir: Vector3, fwd: Vector3)
	local root = data.root
	local now = os.clock()
	Movement._lastDash = { side = side, diagonal = side ~= "Back" and dir:Dot(fwd) < -0.3 } -- test hook
	data.dashDir = dir
	data.heldFacing = if Movement.facingMode == "MOVE" then fwd else nil
	if data.heldFacing then
		-- face the camera's way at once: a left slide then moves to the body's left (the clip reads)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + fwd)
	end
	data.velocity = dir * tune("DashSpeed", D.SPEED)
	turn = nil
	Movement.dashing = true
	Movement.dashSide = side
	Movement.dashStartedAt = now
	Movement.dashReadyAt = now + tune("DashCooldown", D.COOLDOWN)
	for _, fn in ipairs(listeners) do
		task.spawn(fn, side)
	end
end

-- A dash press waits here until it can go (Movement.dash). backSince = when the push last came onto
-- straight back (S), for the W -> S -> S+A roll.
local pendingUntil = -math.huge
local backSince: number? = nil

local function tryPending(now: number): boolean
	local data = current
	if pendingUntil == -math.huge or not data then
		return false
	end
	if Movement.blockedReason() then
		pendingUntil = -math.huge
		return false
	end
	local side, dir, fwd, why = dashPlan(data)
	if side == "Back" then
		-- S only just came on (W -> S -> S+A): give A / D a split second, from the S key, to join and
		-- make it a diagonal slide; S held a while back-dashes at once
		if now - (backSince or now) < tune("DiagWait", D.DIAG_WAIT) then
			return false
		end
	end
	if side and dir then
		pendingUntil = -math.huge
		startDash(data, side, dir, fwd)
		return true
	end
	if now > pendingUntil then
		pendingUntil = -math.huge
		Movement.refusedAt = now -- never got an allowed direction: say why nothing happened
		Movement.refusedWhy = why or "FORWARD"
	end
	return false
end

-- Space / gamepad A / the DASH button. The dash key is handled before this frame's movement keys
-- reach the Humanoid, so W -> S+A + Space pressed together still reads as W (or as nothing) for a
-- moment: a press that can't go yet waits up to BUFFER_TIME and fires the moment a side / back
-- direction shows up ("SIDE OR BACK ONLY" only if none does). A straight-back press right after S
-- came on waits up to DIAG_WAIT (from the S key) for A / D, for the diagonal back slides.
function Movement.dash(): boolean
	if not current or Movement.blockedReason() then
		return false
	end
	pendingUntil = os.clock() + tune("DashBuffer", D.BUFFER_TIME)
	return tryPending(os.clock())
end

-- ===== the Catcher's lunge (GameConfig.Lunge) =====
-- Space as a Catcher: a straight burst the camera's way (the body already faces it). It holds its
-- line through the burst, then eases down to top speed (the server slows the Catcher right after).
local LG = GameConfig.Lunge
Movement.lunging = false
Movement.lungeStartedAt = -math.huge
Movement.onCatcherSpace = nil :: (() -> ())? -- Tag sets this: Space as a Catcher = lunge

-- start the lunge's movement; false if the body can't move right now (held on the line, dead, seated)
function Movement.startLunge(): (boolean, Vector3?)
	local data = current
	if not data or not data.active or data.human.Health <= 0 or topSpeed(data.human) <= 0 then
		return false, nil
	end
	local cam = workspace.CurrentCamera
	local fwd = if cam then planar(cam.CFrame.LookVector) else Vector3.zero
	if fwd.Magnitude < 0.01 then
		fwd = planar(data.root.CFrame.LookVector)
	end
	fwd = fwd.Unit
	data.dashDir = fwd
	data.velocity = fwd * LG.SPEED
	turn = nil
	Movement.dashing = false
	Movement.lunging = true
	Movement.lungeStartedAt = os.clock()
	data.root.CFrame = CFrame.lookAt(data.root.Position, data.root.Position + fwd)
	return true, fwd
end

-- true while a dash press is waiting for its direction (test hook)
function Movement.dashPending(): boolean
	return pendingUntil > -math.huge
end

-- the way the player is pushing right now (flat, may be zero)
function Movement.wishDir(): Vector3
	local data = current
	if not data then
		return Vector3.zero
	end
	return planar(Movement._testWish or data.human.MoveDirection)
end

function Movement.init()
	player.CharacterAdded:Connect(function(character)
		task.spawn(bind, character)
	end)
	if player.Character then
		task.spawn(bind, player.Character)
	end
	player:GetAttributeChangedSignal("EOS_Role"):Connect(updateFacingMode)
	player:GetAttributeChangedSignal("EOS_InMatch"):Connect(updateFacingMode)
	updateFacingMode()

	-- Space / gamepad A dash (sinks the default jump). A falls through to the UI while a panel
	-- has gamepad selection, so menus stay usable.
	ContextActionService:BindActionAtPriority("EOS_Dash", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if GuiService.SelectedObject ~= nil then
			return Enum.ContextActionResult.Pass
		end
		local catcher = player:GetAttribute("EOS_InMatch") == true and player:GetAttribute("EOS_Role") == "CATCHER"
		if catcher and Movement.onCatcherSpace then
			Movement.onCatcherSpace() -- Catchers don't dash: Space lunges
		else
			Movement.dash()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

	RunService.PreSimulation:Connect(function(dt)
		local data = current
		if not data or not data.character:IsDescendantOf(workspace) then
			return
		end
		local human, root = data.human, data.root
		local state = human:GetState()
		local allowed = state == Enum.HumanoidStateType.Running
			or state == Enum.HumanoidStateType.RunningNoPhysics
			or state == Enum.HumanoidStateType.Landed
			or state == Enum.HumanoidStateType.Freefall
		if not allowed or human.Health <= 0 or human.Sit or human.PlatformStand or root.Anchored then
			suspend(data)
			Movement.dashing = false
			Movement.backpedaling = false
			return
		end
		data.active = true
		local now = os.clock()
		-- when the push came onto straight back (for the W -> S -> S+A diagonal), then any waiting dash
		if dashPlan(data) == "Back" then
			backSince = backSince or now
		else
			backSince = nil
		end
		tryPending(now)
		local top = topSpeed(human)
		local wish = planar(Movement._testWish or human.MoveDirection)
		local actual = planar(root.AssemblyLinearVelocity)
		local marker = player:GetAttribute("EOS_TeleportedAt")
		if marker ~= data.teleportMarker then
			-- the server moved us (spawn, wave reset, practice tag): no stored momentum carries over
			data.teleportMarker = marker
			data.velocity = actual
			Movement.dashing = false
			turn = nil
		end
		if data.velocity.Magnitude > 4 and actual.Magnitude < data.velocity.Magnitude * 0.4 then
			data.velocity = actual -- a wall can't bank a full-speed launch (or a dash) for later
		end
		local grounded = human.FloorMaterial ~= Enum.Material.Air

		-- in a match, pushing backwards (S, S+A, S+D) = face the camera and walk backwards slowly
		local cam = workspace.CurrentCamera
		local camFlat = if cam then planar(cam.CFrame.LookVector) else Vector3.zero
		local backpedal = player:GetAttribute("EOS_InMatch") == true
			and wish.Magnitude > 0.1
			and camFlat.Magnitude > 0.01
			and wish.Unit:Dot(camFlat.Unit) <= math.cos(M.BACKPEDAL_ANGLE)
		Movement.backpedaling = backpedal
		local moveTop = if backpedal then math.min(top, tune("BackpedalSpeed", M.BACKPEDAL_SPEED)) else top

		local sinceDash = now - Movement.dashStartedAt
		local dashSpeed, burst, recover = tune("DashSpeed", D.SPEED), tune("DashBurst", D.BURST_TIME), tune("DashRecover", D.RECOVER_TIME)
		local sinceLunge = now - Movement.lungeStartedAt
		if Movement.lunging and sinceLunge >= LG.BURST_TIME + LG.RECOVER_TIME then
			Movement.lunging = false
		end
		if Movement.lunging then
			-- the lunge holds its line: full lunge speed, then ease down to (the slowed) top speed
			local t = math.clamp((sinceLunge - LG.BURST_TIME) / math.max(LG.RECOVER_TIME, 0.01), 0, 1)
			data.velocity = data.dashDir * (LG.SPEED + (math.min(top, LG.SPEED) - LG.SPEED) * t)
		elseif Movement.dashing and sinceDash < burst + recover then
			-- the dash holds its line (straight left / right / back) while it eases back down to top
			-- speed, whatever is held; your keys take over again when it's done
			local t = math.clamp((sinceDash - burst) / math.max(recover, 0.01), 0, 1)
			data.velocity = data.dashDir * (dashSpeed + (top - dashSpeed) * t)
		else
			if Movement.dashing then
				Movement.dashing = false
				data.heldFacing = nil
			end
			data.velocity = step(data.velocity, wish, grounded, dt, moveTop) -- slows to the backpedal pace on its own
			if top <= 0 then
				data.velocity = Vector3.zero
			elseif data.velocity.Magnitude > top then
				data.velocity = data.velocity.Unit * top
			end
		end

		human.WalkSpeed = 0 -- the planar drive supplies horizontal motion
		human.AutoRotate = false
		data.drive.MaxForce = root.AssemblyMass * 1500
		data.drive.PlaneVelocity = Vector2.new(data.velocity.X, data.velocity.Z)
		data.drive.Enabled = true

		-- facing
		local heading: Vector3
		if Movement.facingMode == "CAMERA" then
			heading = if camFlat.Magnitude > 0.01 then camFlat else planar(root.CFrame.LookVector)
		elseif Movement.dashing and data.heldFacing then
			heading = data.heldFacing -- body holds still so side/back dash clips read correctly
		elseif backpedal then
			heading = camFlat -- Runners walking backwards keep facing the camera
		else
			heading = if data.velocity.Magnitude > 0.8 then data.velocity else wish
		end
		if heading.Magnitude > 0.01 then
			local facing = CFrame.lookAt(root.Position, root.Position + heading)
			root.CFrame = root.CFrame:Lerp(facing, 1 - math.exp(-dt * M.TURN_RATE))
		end
		Movement.speedFraction = if top > 0 then math.clamp(data.velocity.Magnitude / top, 0, 1.5) else 0
	end)
end

-- read by the animation controller
function Movement.state(): (Vector3, boolean)
	local data = current
	if not data then
		return Vector3.zero, false
	end
	return data.velocity, data.active
end

return Movement
