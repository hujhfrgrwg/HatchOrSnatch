--!strict
-- AbilityVFX (client, HOS-VFX-001): how the pet abilities look. Effects are presentation only and run
-- on each client; the server decides everything and never waits on them.
--  * One-shots: the server fires AbilityFx { kind = "vfx", name, pos, look? } and every client plays
--    ReplicatedStorage.VFX.Abilities[name] there (Emit.play).
--  * Lasting effects: the server tags its invisible gameplay part (snare, rings, ball, beam) with
--    CollectionService tag EOS_AbilityVFX and attribute VFX = name; each client dresses it with that
--    template for as long as the part exists (DRESS below, or "follow the part" by default).
-- Effects use the archetype's colour only: Gold Ability Colors never touches these, so nothing an
-- opponent must read (snare, warning rings, beams) gets harder to see.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VFXFolder = ReplicatedStorage:WaitForChild("VFX")
local Emit = require(VFXFolder:WaitForChild("Emit"))
local Templates = VFXFolder:WaitForChild("Abilities")

local AbilityVFX = {}

local TAG = "EOS_AbilityVFX"
local active: { [Instance]: () -> () } = {}

local function holder(): Instance
	return workspace.CurrentCamera or workspace
end

-- plays a one-shot template at a CFrame
function AbilityVFX.play(name: string, cf: CFrame)
	local t = Templates:FindFirstChild(name)
	if not t then
		return
	end
	local ok, err = pcall(Emit.play, t, cf, { parent = holder() })
	if not ok then
		warn("[EOS] AbilityVFX " .. name .. ": " .. tostring(err))
	end
end

-- scale every particle size in a clone (templates are authored at a reference size)
local function scaleSizes(root: Instance, k: number)
	if math.abs(k - 1) < 0.01 then
		return
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			local kps = {}
			for _, kp in ipairs(d.Size.Keypoints) do
				table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
			end
			d.Size = NumberSequence.new(kps)
		end
	end
end

-- default dressing: the template's model follows the tagged part every frame
local function follow(part: BasePart, name: string, offset: CFrame?): () -> ()
	local t = Templates:FindFirstChild(name)
	if not t or not t:IsA("Model") then
		return function() end
	end
	local m = t:Clone()
	m:PivotTo(CFrame.new(part.Position) * (offset or CFrame.identity))
	m.Parent = holder()
	local conn = RunService.RenderStepped:Connect(function()
		if part.Parent then
			m:PivotTo(CFrame.new(part.Position) * (offset or CFrame.identity))
		end
	end)
	return function()
		conn:Disconnect()
		m:Destroy()
	end
end

local DRESS: { [string]: (BasePart) -> () -> () } = {}

-- Decoy Catcher's snare: the chain seal lies on the ground and turns slowly; the pulse and sparks
-- come from the template. The server part is a flat cylinder whose height axis is X (its Y / Z are
-- the diameter).
DRESS.Snare = function(part: BasePart): () -> ()
	local t = Templates:FindFirstChild("Snare")
	local pad = t and t:FindFirstChild("Pad")
	if not pad then
		return function() end
	end
	local p = (pad :: BasePart):Clone()
	local dia = math.max(part.Size.Y, part.Size.Z)
	p.Size = Vector3.new(dia, 0.05, dia)
	scaleSizes(p, dia / 8)
	local base = part.Position + Vector3.new(0, 0.05, 0)
	p.CFrame = CFrame.new(base)
	p.Parent = holder()
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		p.CFrame = CFrame.new(base) * CFrame.Angles(0, (os.clock() - t0) * math.rad(25), 0)
	end)
	return function()
		conn:Disconnect()
		p:Destroy()
	end
end

-- Guardian Catcher's tether (HOS-VFX-002): real Beams strung between the two bodies on this client (smooth,
-- not a stretched part), and a hook glow on the Runner. The server part carries ObjectValues A and B.
DRESS.TetherBeam = function(part: BasePart): () -> ()
	local t = Templates:FindFirstChild("TetherBeam")
	local a = part:WaitForChild("A", 1) :: ObjectValue?
	local b = part:WaitForChild("B", 1) :: ObjectValue?
	local ra = a and a.Value :: BasePart?
	local rb = b and b.Value :: BasePart?
	if not t or not ra or not rb then
		return function() end
	end
	local made: { Instance } = {}
	local a0 = Instance.new("Attachment")
	a0.Name = "EOS_TetherFrom"
	a0.Parent = ra
	local a1 = Instance.new("Attachment")
	a1.Name = "EOS_TetherTo"
	a1.Parent = rb
	table.insert(made, a0)
	table.insert(made, a1)
	for _, src in ipairs(t:GetDescendants()) do
		if src:IsA("Beam") then
			local bm = src:Clone()
			bm.Attachment0 = a0
			bm.Attachment1 = a1
			bm.Parent = holder()
			table.insert(made, bm)
		elseif src:IsA("ParticleEmitter") then
			local e = src:Clone()
			e.Parent = a1
			table.insert(made, e)
		end
	end
	return function()
		for _, x in ipairs(made) do
			x:Destroy()
		end
	end
end

local function dress(part: Instance)
	if not part:IsA("BasePart") or active[part] then
		return
	end
	local name = part:GetAttribute("VFX")
	if type(name) ~= "string" then
		return
	end
	local fn = DRESS[name]
	local ok, cleanup = pcall(function()
		return if fn then fn(part) else follow(part, name)
	end)
	if ok and cleanup then
		active[part] = cleanup
	elseif not ok then
		warn("[EOS] AbilityVFX dress " .. name .. ": " .. tostring(cleanup))
	end
end

local function undress(part: Instance)
	local c = active[part]
	active[part] = nil
	if c then
		c()
	end
end

function AbilityVFX.init()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(dress)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(undress)
	for _, p in ipairs(CollectionService:GetTagged(TAG)) do
		dress(p)
	end
end

return AbilityVFX
