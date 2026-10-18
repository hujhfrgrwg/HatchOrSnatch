--!strict
-- ProximityFade (HOS-LOBBY-003): every model tagged "EOS_ProximityFade" (the pro altar's tall beam wall
-- and its PRO LOBBY / LOCKED signs) fades in as this player walks up to it and out as they walk away.
-- Client-only, nothing replicates. Distance is measured flat from the model's pivot; the model's
-- FadeNear / FadeFar attributes (studs) are where it is fully shown / fully hidden.
-- Beams and parts fade through LocalTransparencyModifier, CanvasGroups through GroupTransparency,
-- text through TextTransparency, UIStrokes through Transparency, Frames through BackgroundTransparency,
-- lights through Brightness (text and
-- strokes are faded directly because CanvasGroups don't draw in AlwaysOnTop SurfaceGuis). Streamed-in
-- pieces join the fade as they arrive. Beams with a true "Twinkle" attribute also pulse in and out on
-- their own random rhythm (sparkling), on top of the distance fade.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ProximityFade = {}

local TAG = "EOS_ProximityFade"
local RATE = 4 -- higher = snappier fade (exponential smoothing per second)
local DEFAULT_NEAR, DEFAULT_FAR = 24, 36
local TWINKLE_SPEED = { 0.9, 2.4 } -- radians per second, picked per beam

type Entry = {
	model: Model,
	hidden: number, -- 0 = fully shown, 1 = fully hidden; -1 until the first frame snaps it
	base: { [Instance]: number }, -- each piece's own resting value
	twinkle: { [Beam]: { phase: number, speed: number } },
	conns: { RBXScriptConnection },
}
local entries: { [Model]: Entry } = {}

local player = Players.LocalPlayer
local rng = Random.new()

local function setPiece(inst: Instance, base: number, h: number)
	if inst:IsA("Beam") then
		(inst :: any).LocalTransparencyModifier = h -- hidden but scriptable on Beam
	elseif inst:IsA("BasePart") then
		inst.LocalTransparencyModifier = h
	elseif inst:IsA("CanvasGroup") then
		inst.GroupTransparency = base + (1 - base) * h
	elseif inst:IsA("TextLabel") then
		inst.TextTransparency = base + (1 - base) * h
	elseif inst:IsA("Frame") then
		inst.BackgroundTransparency = base + (1 - base) * h
	elseif inst:IsA("UIStroke") then
		inst.Transparency = base + (1 - base) * h
	elseif inst:IsA("Light") then
		inst.Brightness = base * (1 - h)
	end
end

local function remember(e: Entry, inst: Instance)
	if inst:IsA("CanvasGroup") then
		e.base[inst] = inst.GroupTransparency
	elseif inst:IsA("TextLabel") then
		e.base[inst] = inst.TextTransparency
	elseif inst:IsA("Frame") then
		e.base[inst] = inst.BackgroundTransparency
	elseif inst:IsA("UIStroke") then
		e.base[inst] = inst.Transparency
	elseif inst:IsA("Light") then
		e.base[inst] = inst.Brightness
	elseif inst:IsA("Beam") or inst:IsA("BasePart") then
		e.base[inst] = 0
		if inst:IsA("Beam") and inst:GetAttribute("Twinkle") == true then
			e.twinkle[inst] = { phase = rng:NextNumber() * 2 * math.pi, speed = rng:NextNumber(TWINKLE_SPEED[1], TWINKLE_SPEED[2]) }
		end
	else
		return
	end
	if e.hidden >= 0 then
		setPiece(inst, e.base[inst], e.hidden)
	end
end

local function apply(e: Entry)
	for inst, base in e.base do
		setPiece(inst, base, e.hidden)
	end
end

local function add(inst: Instance)
	if not inst:IsA("Model") or entries[inst :: Model] then
		return
	end
	local model = inst :: Model
	local e: Entry = { model = model, hidden = -1, base = {}, twinkle = {}, conns = {} }
	for _, d in model:GetDescendants() do
		remember(e, d)
	end
	table.insert(e.conns, model.DescendantAdded:Connect(function(d)
		remember(e, d)
	end))
	table.insert(e.conns, model.DescendantRemoving:Connect(function(d)
		e.base[d] = nil
		e.twinkle[d :: any] = nil
	end))
	entries[model] = e
end

local function remove(inst: Instance)
	local e = entries[inst :: Model]
	if e then
		for _, c in e.conns do
			c:Disconnect()
		end
		entries[inst :: Model] = nil
	end
end

-- sparkle: each twinkling beam fades in and out on its own sine, sharpened so it spends longer dim
local function twinkle(e: Entry, now: number)
	for beam, tw in e.twinkle do
		local pulse = (0.5 + 0.5 * math.sin(now * tw.speed + tw.phase)) ^ 2
		(beam :: any).LocalTransparencyModifier = 1 - (1 - e.hidden) * pulse
	end
end

local function step(dt: number)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = if root then root.Position else workspace.CurrentCamera.CFrame.Position
	local k = 1 - math.exp(-RATE * dt)
	local now = os.clock()
	for model, e in entries do
		if not model.Parent then
			remove(model)
			continue
		end
		local near = model:GetAttribute("FadeNear")
		local far = model:GetAttribute("FadeFar")
		near = if type(near) == "number" then near else DEFAULT_NEAR
		far = if type(far) == "number" and far > near then far else near + 1
		local p = model:GetPivot().Position
		local d = Vector3.new(target.X - p.X, 0, target.Z - p.Z).Magnitude
		local want = math.clamp((d - near) / (far - near), 0, 1)
		local h = if e.hidden < 0 then want else e.hidden + (want - e.hidden) * k
		if math.abs(h - want) < 0.002 then
			h = want
		end
		if h ~= e.hidden then
			e.hidden = h
			apply(e)
		end
		if e.hidden < 1 and next(e.twinkle) then
			twinkle(e, now)
		end
	end
end

function ProximityFade.init()
	for _, inst in CollectionService:GetTagged(TAG) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	RunService.RenderStepped:Connect(step)
end

return ProximityFade
