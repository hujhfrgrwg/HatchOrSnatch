--!nocheck
-- EvolutionKits (Oct 15 2026): mock-up "evolved form" add-ons built on top of the ported pet meshes,
-- so the Level 2 / Level 3 looks can be judged in Studio before real art is made.
-- Every add-on is a plain part fixed to one of the pet's bones (RigidConstraint), so it follows the
-- pet's animations. Positions come from the pet's measured shape (head bone, top, front face), with
-- the pet built at the origin facing -Z (the way these pets are authored).
local Kits = {}

local NEON = Enum.Material.Neon
local PLASTIC = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal

-- ===== measuring a pet =====

local function bone(m: Model, names: { string }): Bone?
	for _, n in names do
		for _, d in m:GetDescendants() do
			if d:IsA("Bone") and d.Name == n then
				return d
			end
		end
	end
	return nil
end

local function meshParts(m: Model)
	local out = {}
	for _, d in m:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(out, d)
		end
	end
	return out
end

-- first surface hit along a ray, only against this pet's meshes
local function surface(m: Model, from: Vector3, dir: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = meshParts(m)
	local r = workspace:Raycast(from, dir, params)
	return r and r.Position
end

-- The pet must sit at the origin, facing -Z, parented to workspace (for raycasts).
function Kits.measure(m: Model)
	local cf, size = m:GetBoundingBox()
	local lo, hi = cf.Position - size / 2, cf.Position + size / 2
	local head = bone(m, { "Head", "Face" })
	local body = bone(m, { "Body", "Torso", "Chest", "Hips" }) or bone(m, { "Root" })
	local root = bone(m, { "Root" })
	local tail = bone(m, { "TailFin", "Tail2", "Tail", "Tail1", "Sting", "Fluke" })
	local H = hi.Y
	local headY = if head then head.WorldPosition.Y else H * 0.55
	local headCY = (headY + H) / 2
	local headR = math.max((H - headY) / 2, H * 0.18)
	local cz = if head then head.WorldPosition.Z else (lo.Z + hi.Z) / 2
	local eyeY = headCY + headR * 0.05
	-- eye bones, where the rig has them (lids / eyes): exact eye spots for glowing eyes and brows
	local eyePos = nil
	local lr, ll = bone(m, { "Lid_R", "Eye_R" }), bone(m, { "Lid_L", "Eye_L" })
	if lr and ll then
		eyePos = { lr.WorldPosition, ll.WorldPosition }
		eyeY = (lr.WorldPosition.Y + ll.WorldPosition.Y) / 2
	else
		local eb = bone(m, { "Eyes" })
		if eb then
			eyeY = eb.WorldPosition.Y
		end
	end
	local front = surface(m, Vector3.new(0, eyeY, lo.Z - 4), Vector3.new(0, 0, 12))
	local frontZ = if front then front.Z else lo.Z
	if eyePos then
		for i, e in eyePos do
			local hit = surface(m, Vector3.new(e.X, e.Y, lo.Z - 4), Vector3.new(0, 0, 12))
			eyePos[i] = Vector3.new(e.X, e.Y, if hit then hit.Z else math.min(e.Z, frontZ))
		end
	end
	local top = surface(m, Vector3.new(0, H + 4, cz), Vector3.new(0, -12, 0))
	local topY = if top then top.Y else H
	local backHit = surface(m, Vector3.new(0, H * 0.45, hi.Z + 4), Vector3.new(0, 0, -12))
	local backZ = if backHit then backHit.Z else hi.Z
	return {
		lo = lo, hi = hi, W = size.X, H = H, D = size.Z,
		head = head or body, body = body or root, root = root, tail = tail,
		headCY = headCY, headR = headR, headZ = cz, eyeY = eyeY, frontZ = frontZ, topY = topY, backZ = backZ,
		hasHeadBone = head ~= nil, eyePos = eyePos,
	}
end

-- ===== making add-on parts =====

local function fix(p: BasePart, anchor: Instance?)
	if anchor and anchor:IsA("Bone") then
		local a = Instance.new("Attachment")
		a.Name = "KitAttach"
		a.CFrame = p.CFrame:Inverse() * anchor.WorldCFrame
		a.Parent = p
		local rc = Instance.new("RigidConstraint")
		rc.Attachment0 = anchor
		rc.Attachment1 = a
		rc.Parent = p
	end
end

local function part(kit: Folder, anchor, name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or PLASTIC
	if shape then
		p.Shape = shape
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = mat ~= NEON
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = kit
	fix(p, anchor)
	return p
end

local function wedge(kit, anchor, name, size, cf, color, mat)
	local p = part(kit, anchor, name, size, cf, color, mat)
	local w = Instance.new("SpecialMesh")
	w.MeshType = Enum.MeshType.Wedge
	w.Parent = p
	return p
end

-- ===== the kits (S = measure(), c = main colour, c2 = accent) =====
local K = {}

-- crown of spikes on top of the head
function K.crown(kit, S, c, c2)
	local y, r = S.topY, S.headR * 0.75
	part(kit, S.head, "CrownBand", Vector3.new(0.22, r * 2.1, r * 2.1), CFrame.new(0, y + 0.05, S.headZ) * CFrame.Angles(0, 0, math.rad(90)), c, METAL, Enum.PartType.Cylinder)
	for i = 0, 4 do
		local a = math.rad(i * 72)
		local p = Vector3.new(math.sin(a) * r, y + 0.35, S.headZ + math.cos(a) * r)
		wedge(kit, S.head, "CrownSpike", Vector3.new(0.16, 0.55, 0.3), CFrame.lookAt(p, Vector3.new(0, p.Y, S.headZ)), c, METAL)
	end
	part(kit, S.head, "CrownGem", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, y + 0.3, S.headZ - r), c2, NEON)
end

-- two horns sweeping back from the top of the head
function K.horns(kit, S, c, c2, big)
	local s = if big then 1.3 else 1
	for _, side in { -1, 1 } do
		local base = Vector3.new(side * S.headR * 0.6, S.topY - 0.08, S.headZ + 0.1)
		local root = CFrame.new(base) * CFrame.Angles(math.rad(55), 0, math.rad(-side * 22))
		local h1 = part(kit, S.head, "Horn", Vector3.new(0.24, 0.42, 0.24) * s, root * CFrame.new(0, 0.18 * s, 0), c)
		wedge(kit, S.head, "HornTip", Vector3.new(0.18, 0.38, 0.2) * s, h1.CFrame * CFrame.new(0, 0.36 * s, 0.04 * s) * CFrame.Angles(math.rad(28), 0, 0), c2 or c)
	end
end

-- neon visor across the eyes
function K.visor(kit, S, c)
	local w = S.headR * 2
	if S.eyePos then
		w = math.abs(S.eyePos[1].X - S.eyePos[2].X) + 0.5
	end
	local z = S.frontZ
	if S.eyePos then
		z = math.min(S.eyePos[1].Z, S.eyePos[2].Z)
	end
	part(kit, S.head, "Visor", Vector3.new(w, 0.24, 0.12), CFrame.new(0, S.eyeY, z - 0.09), c, NEON).Transparency = 0.15
end

-- glowing eyes (two small neon blocks on the face)
local function eyeSpots(S)
	if S.eyePos then
		return S.eyePos
	end
	return { Vector3.new(S.headR * 0.42, S.eyeY, S.frontZ), Vector3.new(-S.headR * 0.42, S.eyeY, S.frontZ) }
end

function K.eyes(kit, S, c)
	for _, e in eyeSpots(S) do
		part(kit, S.head, "GlowEye", Vector3.new(0.24, 0.24, 0.1), CFrame.new(e.X, e.Y, e.Z - 0.06), c, NEON)
	end
end

-- angry brows: two short dark bars tilted down to the middle
function K.brows(kit, S, c)
	for _, e in eyeSpots(S) do
		local side = if e.X >= 0 then 1 else -1
		local up = math.max(S.headR * 0.32, 0.22)
		local hit = surface(kit.Parent, Vector3.new(e.X, e.Y + up, S.lo.Z - 4), Vector3.new(0, 0, 12))
		local z = if hit then hit.Z else e.Z
		part(kit, S.head, "Brow", Vector3.new(math.max(S.headR * 0.5, 0.32), 0.12, 0.1), CFrame.new(e.X, e.Y + up, z - 0.06) * CFrame.Angles(0, 0, math.rad(side * 20)), c or Color3.fromRGB(28, 26, 34))
	end
end

-- spiky mane ring round the head
function K.mane(kit, S, c, c2)
	local r = S.headR * 1.05
	for i = 0, 9 do
		local a = math.rad(i * 36)
		local dir = Vector3.new(math.sin(a), math.cos(a), 0)
		local p = Vector3.new(0, S.headCY, S.headZ + 0.15) + dir * r
		wedge(kit, S.head, "ManeSpike", Vector3.new(0.18, 0.7, 0.45), CFrame.lookAt(p, p + Vector3.new(0, 0, 1), dir) * CFrame.Angles(math.rad(-90), 0, 0), if i % 2 == 0 then c else (c2 or c))
	end
end

-- helmet cap with a fin on top
function K.helmet(kit, S, c, c2)
	part(kit, S.head, "Helmet", Vector3.new(S.headR * 2.2, S.headR * 0.55, S.headR * 2.2), CFrame.new(0, S.topY - S.headR * 0.1, S.headZ), c, METAL)
	wedge(kit, S.head, "HelmetFin", Vector3.new(0.14, 0.45, S.headR * 1.6), CFrame.new(0, S.topY + S.headR * 0.35, S.headZ + 0.1), c2 or c, METAL)
end

-- gamer headset
function K.headset(kit, S, c, c2)
	part(kit, S.head, "Band", Vector3.new(S.headR * 2.3, 0.16, 0.25), CFrame.new(0, S.topY + 0.04, S.headZ), c)
	for _, side in { -1, 1 } do
		part(kit, S.head, "EarCup", Vector3.new(0.3, 0.5, 0.5), CFrame.new(side * S.headR * 1.12, S.headCY, S.headZ), c)
		part(kit, S.head, "EarGlow", Vector3.new(0.06, 0.32, 0.32), CFrame.new(side * (S.headR * 1.12 + 0.17), S.headCY, S.headZ), c2, NEON)
	end
	part(kit, S.head, "Mic", Vector3.new(0.08, 0.08, S.headR * 1.1), CFrame.new(S.headR * 0.95, S.headCY - S.headR * 0.4, S.headZ - S.headR * 0.55), c)
end

-- ninja / bandit mask band over the eyes with trailing ribbons
function K.mask(kit, S, c)
	part(kit, S.head, "MaskBand", Vector3.new(S.headR * 2.15, 0.3, S.headR * 2.1), CFrame.new(0, S.eyeY + 0.02, S.headZ), c)
	for _, side in { -1, 1 } do
		part(kit, S.head, "MaskTail", Vector3.new(0.12, 0.2, 0.9), CFrame.new(side * 0.18, S.eyeY - 0.1, S.headZ + S.headR + 0.4) * CFrame.Angles(math.rad(-20), math.rad(side * 12), 0), c)
	end
end

-- cape hanging behind the body
function K.cape(kit, S, c, c2)
	local w = math.min(S.W * 0.7, 2.2)
	local cape = part(kit, S.body, "Cape", Vector3.new(w, S.H * 0.55, 0.1), CFrame.new(0, S.H * 0.42, S.backZ + 0.12) * CFrame.Angles(math.rad(-12), 0, 0), c)
	part(kit, S.body, "CapeTrim", Vector3.new(w + 0.05, 0.12, 0.14), cape.CFrame * CFrame.new(0, -S.H * 0.275, 0), c2 or c, NEON)
end

-- wings on the back (flame / energy)
function K.wings(kit, S, c, c2)
	for _, side in { -1, 1 } do
		local base = Vector3.new(side * S.W * 0.22, S.H * 0.6, S.backZ - 0.1)
		local w = wedge(kit, S.body, "Wing", Vector3.new(0.12, 1.3, 1.4), CFrame.new(base + Vector3.new(side * 0.55, 0.35, 0.3)) * CFrame.Angles(0, math.rad(side * 70), math.rad(side * 35)), c, NEON)
		w.Transparency = 0.15
		wedge(kit, S.body, "WingTip", Vector3.new(0.1, 0.8, 0.9), w.CFrame * CFrame.new(0, 0.7, 0.25), c2 or c, NEON).Transparency = 0.25
	end
end

-- armour: chest plate + shoulder pads
function K.armor(kit, S, c, c2)
	local y = S.H * 0.38
	local fz = surface(kit.Parent, Vector3.new(0, y, S.lo.Z - 4), Vector3.new(0, 0, 12))
	local z = if fz then fz.Z else S.lo.Z
	part(kit, S.body, "ChestPlate", Vector3.new(S.W * 0.45, S.H * 0.22, 0.14), CFrame.new(0, y, z - 0.06), c, METAL)
	part(kit, S.body, "ChestGem", Vector3.new(0.22, 0.22, 0.1), CFrame.new(0, y, z - 0.15), c2, NEON)
	for _, side in { -1, 1 } do
		part(kit, S.body, "Pauldron", Vector3.new(0.6, 0.3, 0.7), CFrame.new(side * S.W * 0.38, S.H * 0.52, (z + S.backZ) / 2) * CFrame.Angles(0, 0, math.rad(-side * 25)), c, METAL)
	end
end

-- spikes down the back
function K.spikes(kit, S, c)
	for i = 0, 3 do
		local y = S.H * (0.62 - i * 0.12)
		local hit = surface(kit.Parent, Vector3.new(0, y, S.hi.Z + 4), Vector3.new(0, 0, -12))
		local z = if hit then hit.Z else S.backZ
		wedge(kit, S.body, "BackSpike", Vector3.new(0.14, 0.5 - i * 0.07, 0.45), CFrame.new(0, y + 0.1, z + 0.12) * CFrame.Angles(math.rad(-60), 0, 0), c)
	end
end

-- shell plates for crabs / puffer (raised scutes over the body)
function K.scutes(kit, S, c)
	for i = -1, 1 do
		part(kit, S.body, "Scute", Vector3.new(0.5, 0.18, 0.5), CFrame.new(i * S.W * 0.22, S.topY + 0.02, S.headZ + 0.1) * CFrame.Angles(0, math.rad(45), 0), c, METAL)
	end
end

-- floating halo ring over the head
function K.halo(kit, S, c)
	part(kit, S.head, "Halo", Vector3.new(0.12, S.headR * 2, S.headR * 2), CFrame.new(0, S.topY + 0.55, S.headZ) * CFrame.Angles(0, 0, math.rad(90)), c, NEON, Enum.PartType.Cylinder).Transparency = 0.1
end

-- big glowing horn on the nose (narwhal lance)
function K.lance(kit, S, c)
	local p = Vector3.new(0, S.eyeY + 0.1, S.frontZ - 0.2)
	wedge(kit, S.head, "Lance", Vector3.new(0.25, 0.25, 1.6), CFrame.lookAt(p + Vector3.new(0, 0.25, -0.8), p + Vector3.new(0, 0.6, -2)), c, NEON)
end

-- tusks (walrus)
function K.tusks(kit, S, c)
	for _, side in { -1, 1 } do
		wedge(kit, S.head, "Tusk", Vector3.new(0.16, 0.8, 0.22), CFrame.new(side * 0.32, S.eyeY - S.headR * 0.85, S.frontZ - 0.08) * CFrame.Angles(math.rad(180), 0, 0), c)
	end
end

-- see-through bubble shield round the whole pet (Shield pets, Level 3)
function K.bubble(kit, S, c)
	local d = math.max(S.W, S.H, S.D) * 1.25
	local b = part(kit, S.body, "Bubble", Vector3.new(d, d, d), CFrame.new(0, S.H / 2, (S.lo.Z + S.hi.Z) / 2), c, Enum.Material.ForceField, Enum.PartType.Ball)
	b.Transparency = 0.2
	b.CastShadow = false
end

-- KITS_THAT_EMIT: effects added after the final scale (sizes in studs at 1x, multiplied by the scale)
local TEX = {
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}
local FX = {
	fire = { tex = "fire", rate = 18, life = { 0.4, 0.7 }, size = { 0.7, 0.1 }, speed = { 1.5, 3 }, light = 0.15, accel = Vector3.new(0, 4, 0) },
	sparks = { tex = "spark", rate = 14, life = { 0.3, 0.6 }, size = { 0.35, 0 }, speed = { 2, 4 }, light = 1, accel = Vector3.zero },
	frost = { tex = "spark", rate = 10, life = { 0.8, 1.4 }, size = { 0.25, 0.05 }, speed = { 0.5, 1.2 }, light = 0.6, accel = Vector3.new(0, -1, 0) },
	void = { tex = "smoke", rate = 10, life = { 0.8, 1.3 }, size = { 0.8, 1.6 }, speed = { 0.3, 0.8 }, light = 0, accel = Vector3.new(0, 0.8, 0), trans = 0.45 },
	water = { tex = "smoke", rate = 12, life = { 0.5, 0.9 }, size = { 0.5, 0.9 }, speed = { 1, 2 }, light = 0.3, accel = Vector3.new(0, -3, 0), trans = 0.35 },
	gold = { tex = "spark", rate = 10, life = { 0.6, 1 }, size = { 0.3, 0 }, speed = { 0.6, 1.4 }, light = 1, accel = Vector3.new(0, 1, 0) },
	glitch = { tex = "spark", rate = 16, life = { 0.15, 0.3 }, size = { 0.3, 0.3 }, speed = { 1, 3 }, light = 1, accel = Vector3.zero },
}

function Kits.emit(m: Model, S, kind: string, color: Color3, scale: number, where: string?)
	local f = FX[kind]
	local anchor = if where == "tail" and S.tail then S.tail elseif where == "head" then S.head else S.body
	local a = anchor -- emitters sit on the bone itself (a Bone is an Attachment), so they follow it
	local e = Instance.new("ParticleEmitter")
	e.Name = "FX_" .. kind
	e.Texture = TEX[f.tex]
	e.Color = ColorSequence.new(color)
	e.LightEmission = f.light
	e.Rate = f.rate
	e.Lifetime = NumberRange.new(f.life[1], f.life[2])
	e.Size = NumberSequence.new(f.size[1] * scale, f.size[2] * scale)
	e.Speed = NumberRange.new(f.speed[1] * scale, f.speed[2] * scale)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = f.accel * scale
	e.Transparency = NumberSequence.new(f.trans or 0.1, 1)
	e.Parent = a
end

-- ground aura ring + light (Level 3)
function Kits.aura(m: Model, color: Color3, size: number)
	local cf, s = m:GetBoundingBox()
	local ring = Instance.new("Part")
	ring.Name = "AuraRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = NEON
	ring.Color = color
	ring.Transparency = 0.35
	ring.Size = Vector3.new(0.08, size, size)
	ring.CFrame = CFrame.new(cf.Position.X, cf.Position.Y - s.Y / 2 + 0.06, cf.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = m
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = 2
	l.Range = size * 1.6
	l.Parent = ring
end

-- apply a list of kit calls: { {"crown", c, c2}, ... }
function Kits.apply(m: Model, S, list)
	local kit = m:FindFirstChild("Kit") or Instance.new("Folder")
	kit.Name = "Kit"
	kit.Parent = m
	for _, k in list do
		local fn = K[k[1]]
		if fn then
			fn(kit, S, k[2], k[3], k[4])
		else
			warn("EvolutionKits: no kit " .. tostring(k[1]))
		end
	end
end

return Kits
