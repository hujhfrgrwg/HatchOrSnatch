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

local AbilityCosmetics = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("AbilityCosmetics"))
local VFXFolder = ReplicatedStorage:WaitForChild("VFX")
local Emit = require(VFXFolder:WaitForChild("Emit"))
local Templates = VFXFolder:WaitForChild("Abilities")

local AbilityVFX = {}

local TAG = "EOS_AbilityVFX"
local active: { [Instance]: () -> () } = {}

local function holder(): Instance
	return workspace.CurrentCamera or workspace
end

-- the template for effect `key` used by `species` (HOS-VFX-OVR): the species' override from
-- AbilityCosmetics if it has one and the template exists, else the archetype default (`key`)
function AbilityVFX.template(key: string, species: any): Instance?
	local name = AbilityCosmetics.vfx(species, key)
	if name == AbilityCosmetics.NONE then
		return nil -- the species' own effect covers this one
	end
	return (if name ~= key then Templates:FindFirstChild(name) else nil) or Templates:FindFirstChild(key)
end

-- plays a one-shot effect at a CFrame (`species`: whose ability it is, for its override)
function AbilityVFX.play(name: string, cf: CFrame, species: any?)
	local t = AbilityVFX.template(name, species)
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
local function follow(part: BasePart, t: Instance?, offset: CFrame?): () -> ()
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

-- custom dressings, by default key; each gets the template to use (the default or a species' override)
local DRESS: { [string]: (BasePart, Instance?) -> () -> () } = {}

-- Decoy Catcher's snare: the chain seal lies on the ground and turns slowly; the pulse and sparks
-- come from the template. The server part is a flat cylinder whose height axis is X (its Y / Z are
-- the diameter).
DRESS.Snare = function(part: BasePart, t: Instance?): () -> ()
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
DRESS.TetherBeam = function(part: BasePart, t: Instance?): () -> ()
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

-- Tempest Catcher's storm ball (HOS-VFX-003b, Wrecking Ball reference): the server's ball is the gameplay
-- part; this client hides it and draws an energy orb in its place (dark core with glowing seams, a crackling
-- shell with a dark outline) that spins as the server rolls it, a lightning cage, arcs jumping to the floor,
-- and a scorch + electric trail on the ground that fades in about 0.5 s. The template's Root faces the way
-- the ball travels (the trail attachments sit either side of it).
local function reaim(a: Attachment, r: number)
	local v = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	a.Position = (if v.Magnitude > 0.01 then v.Unit else Vector3.yAxis) * r
end
DRESS.StormBall = function(part: BasePart, t: Instance?): () -> ()
	if not t then
		return function() end
	end
	local m = t:Clone()
	local root = m:FindFirstChild("Root") :: BasePart
	local orb = m:FindFirstChild("Orb") :: Model
	part.LocalTransparencyModifier = 1
	root.CFrame = CFrame.new(part.Position)
	orb:PivotTo(part.CFrame)
	m.Parent = holder()
	local cage, floor = {}, {}
	for i = 1, 3 do
		local b = root:FindFirstChild("Cage" .. i) :: Beam?
		if b then
			table.insert(cage, b)
		end
	end
	for i = 1, 2 do
		local a, c = root:FindFirstChild("FloorA" .. i) :: Attachment?, root:FindFirstChild("FloorB" .. i) :: Attachment?
		if a and c then
			table.insert(floor, { a = a, b = c })
		end
	end
	local last, dir = part.Position, Vector3.xAxis
	local acc = 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		if not part.Parent then
			return
		end
		local p = part.Position
		local d = Vector3.new(p.X - last.X, 0, p.Z - last.Z)
		if d.Magnitude > 0.01 then
			dir = d.Unit
		end
		last = p
		root.CFrame = CFrame.lookAt(p, p + dir)
		orb:PivotTo(part.CFrame)
		acc += dt
		if acc >= 0.05 then -- the bolts jump about 20 times a second
			acc = 0
			for _, b in ipairs(cage) do
				reaim(b.Attachment0 :: Attachment, 1.4)
				reaim(b.Attachment1 :: Attachment, 1.4)
				b.CurveSize0 = (math.random() - 0.5) * 3
				b.CurveSize1 = (math.random() - 0.5) * 3
			end
			for _, f in ipairs(floor) do
				local ang = math.random() * math.pi * 2
				local r = 1.3 + math.random() * 1.6
				f.a.Position = Vector3.new(math.cos(ang) * 0.6, -0.9, math.sin(ang) * 0.6)
				f.b.Position = Vector3.new(math.cos(ang) * r, -1.15, math.sin(ang) * r)
			end
		end
	end)
	return function()
		conn:Disconnect()
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
		-- the trail and dust finish fading where they are
		for _, x in ipairs(m:GetDescendants()) do
			if x:IsA("ParticleEmitter") then
				x.Enabled = false
			elseif x:IsA("Beam") then
				x.Enabled = false
			end
		end
		orb:Destroy()
		task.delay(0.6, function()
			m:Destroy()
		end)
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
	local t = AbilityVFX.template(name, part:GetAttribute("VFXSpecies")) -- HOS-VFX-OVR
	local ok, cleanup = pcall(function()
		return if fn then fn(part, t) else follow(part, t)
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
