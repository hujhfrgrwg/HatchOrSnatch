--!strict
-- FacePlayer: turns every model tagged "EOS_FacePlayer" (the lobby leaderboards) on its
-- vertical axis so its front faces this player, smoothly, like a slow turntable. Yaw only: it never tilts.
-- Client-only: each player sees the boards facing them. The model's pivot (PrimaryPart, or WorldPivot
-- for a model that streams Atomic / Persistent) is the turning point; its LookVector is the front.
-- The server only moves these models when a map lifts the lobby (workspace attribute EOS_LobbyLift);
-- entries inside Workspace.LobbyProto remember the lift they were read at and shift their pivot by the
-- change. The SurfaceGui rows LobbyService writes keep updating as normal.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FacePlayer = {}

local TAG = "EOS_FacePlayer"
local TURN_RATE = 5 -- higher = snappier (exponential smoothing per second)
local MAX_DIST = 160 -- only turn when the player is this close (studs)
local DEADZONE = math.rad(0.5)

type Entry = { model: Model, pos: Vector3, yaw: number, lift: number, lifts: boolean }
local entries: { [Model]: Entry } = {}

local player = Players.LocalPlayer

local function lobbyLift(): number
	local v = workspace:GetAttribute("EOS_LobbyLift")
	return if type(v) == "number" then v else 0
end

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function add(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local model = inst :: Model
	local whole = model.ModelStreamingMode == Enum.ModelStreamingMode.Atomic
		or model.ModelStreamingMode == Enum.ModelStreamingMode.Persistent
	if not model.PrimaryPart and not whole then
		-- streaming may deliver the PrimaryPart a moment later
		task.delay(1, function()
			if model.Parent and not entries[model] and model.PrimaryPart then
				add(model)
			end
		end)
		return
	end
	local cf = model:GetPivot()
	local lobby = workspace:FindFirstChild("LobbyProto")
	entries[model] = {
		model = model,
		pos = cf.Position,
		yaw = yawOf(cf),
		lift = lobbyLift(),
		lifts = lobby ~= nil and model:IsDescendantOf(lobby),
	}
end

local function remove(inst: Instance)
	entries[inst :: Model] = nil
end

local function shortest(a: number, b: number): number
	-- signed smallest angle from a to b
	local d = (b - a) % (2 * math.pi)
	if d > math.pi then
		d -= 2 * math.pi
	end
	return d
end

local function step(dt: number)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = if root then root.Position else workspace.CurrentCamera.CFrame.Position
	local k = 1 - math.exp(-TURN_RATE * dt)
	local lift = lobbyLift()
	for model, e in entries do
		if not model.Parent then
			entries[model] = nil
			continue
		end
		if e.lifts and e.lift ~= lift then -- the lobby was raised/lowered: follow it
			e.pos += Vector3.new(0, lift - e.lift, 0)
			e.lift = lift
			model:PivotTo(CFrame.new(e.pos) * CFrame.Angles(0, e.yaw, 0))
		end
		local flat = Vector3.new(target.X - e.pos.X, 0, target.Z - e.pos.Z)
		local dist = flat.Magnitude
		if dist < 2 or dist > MAX_DIST then
			continue
		end
		local want = math.atan2(-flat.X, -flat.Z)
		local diff = shortest(e.yaw, want)
		if math.abs(diff) < DEADZONE then
			continue
		end
		e.yaw += diff * k
		model:PivotTo(CFrame.new(e.pos) * CFrame.Angles(0, e.yaw, 0))
	end
end

function FacePlayer.init()
	for _, inst in CollectionService:GetTagged(TAG) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	RunService.RenderStepped:Connect(step)
end

return FacePlayer
