--!strict
-- CrowRig: plays the crow pet's baked keyframes (CrowAnims) on its Bones from code.
-- No Animation assets: works in any place whoever owns it, in Studio and live, on client-only
-- models. Keys are rotations about each bone's rest head in model axes; they are turned into
-- Bone.Transform with the bone's rest orientation: T = R^-1 * Q * R (translation R^-1 * t).
-- Between keys: Catmull-Rom (smooth through the keys, like Blender's auto curves).

local Anims = require(script:WaitForChild("CrowAnims"))

local CrowRig = {}
CrowRig.__index = CrowRig
CrowRig.FPS = 24
CrowRig.Anims = Anims

type Anim = { frames: number, loop: boolean, bones: { string }, keys: { { f: number, v: { number } } } }
type Track = { name: string, anim: Anim, frame: number, speed: number }
export type Rig = typeof(setmetatable(
	{} :: {
		model: Model,
		bones: { [string]: Bone },
		cur: Track?,
		prev: Track?,
		fade: number,
		fadeTime: number,
		names: { string },
	},
	CrowRig
))

-- rest orientation of each bone relative to the model pivot (same for every crow clone)
local REST: { [string]: CFrame } = {}
local REST_INV: { [string]: CFrame } = {}

local function rotOnly(cf: CFrame): CFrame
	return cf - cf.Position
end

local function learnRest(model: Model, bones: { [string]: Bone })
	if next(REST) then
		return
	end
	local pivot = model:GetPivot()
	for name, b in pairs(bones) do
		local r = rotOnly(pivot:ToObjectSpace(b.WorldCFrame))
		REST[name] = r
		REST_INV[name] = r:Inverse()
	end
end

-- Call once with the untouched template so later clones never learn from a posed rig.
function CrowRig.prime(template: Model)
	local bones = {}
	for _, d in ipairs(template:GetDescendants()) do
		if d:IsA("Bone") then
			bones[d.Name] = d
		end
	end
	learnRest(template, bones)
end

function CrowRig.new(model: Model): Rig
	local bones: { [string]: Bone } = {}
	local names = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Bone") then
			bones[d.Name] = d
			table.insert(names, d.Name)
		end
	end
	learnRest(model, bones)
	local self = setmetatable({
		model = model,
		bones = bones,
		cur = nil :: Track?,
		prev = nil :: Track?,
		fade = 1,
		fadeTime = 0.2,
		names = names,
	}, CrowRig)
	return self
end

-- sample one animation at a (fractional) frame: bone name -> { qx, qy, qz, qw, tx, ty, tz }
local function sample(anim: Anim, frame: number): { [string]: { number } }
	local keys = anim.keys
	local n = #keys
	local f = frame
	if anim.loop then
		f = f % anim.frames
	else
		f = math.clamp(f, keys[1].f, keys[n].f)
	end
	-- segment i: keys[i].f <= f <= keys[i+1].f
	local i = 1
	while i < n - 1 and keys[i + 1].f < f do
		i += 1
	end
	local k1, k2 = keys[i], keys[math.min(i + 1, n)]
	local f1, f2 = k1.f, k2.f
	local k0, k3, f0, f3
	if anim.loop then
		-- keys[1] and keys[n] are the same pose (f = 0 and f = frames)
		if i > 1 then
			k0, f0 = keys[i - 1], keys[i - 1].f
		else
			k0, f0 = keys[n - 1], keys[n - 1].f - anim.frames
		end
		if i + 2 <= n then
			k3, f3 = keys[i + 2], keys[i + 2].f
		else
			k3, f3 = keys[2], keys[2].f + anim.frames
		end
	else
		if i > 1 then
			k0, f0 = keys[i - 1], keys[i - 1].f
		else
			k0, f0 = k1, f1 - 1
		end
		if i + 2 <= n then
			k3, f3 = keys[i + 2], keys[i + 2].f
		else
			k3, f3 = k2, f2 + 1
		end
	end
	local span = math.max(f2 - f1, 1e-6)
	local s = math.clamp((f - f1) / span, 0, 1)
	local s2, s3 = s * s, s * s * s
	local h00, h10, h01, h11 = 2 * s3 - 3 * s2 + 1, s3 - 2 * s2 + s, -2 * s3 + 3 * s2, s3 - s2
	local m1s = span / math.max(f2 - f0, 1e-6)
	local m2s = span / math.max(f3 - f1, 1e-6)
	local out = {}
	local v0, v1, v2, v3 = k0.v, k1.v, k2.v, k3.v
	for b, name in ipairs(anim.bones) do
		local o = (b - 1) * 7
		local r = table.create(7, 0)
		-- keep the quaternions on one hemisphere
		local d0 = v0[o + 1] * v1[o + 1] + v0[o + 2] * v1[o + 2] + v0[o + 3] * v1[o + 3] + v0[o + 4] * v1[o + 4]
		local d2 = v2[o + 1] * v1[o + 1] + v2[o + 2] * v1[o + 2] + v2[o + 3] * v1[o + 3] + v2[o + 4] * v1[o + 4]
		local d3 = v3[o + 1] * v1[o + 1] + v3[o + 2] * v1[o + 2] + v3[o + 3] * v1[o + 3] + v3[o + 4] * v1[o + 4]
		local s0 = if d0 < 0 then -1 else 1
		local sg2 = if d2 < 0 then -1 else 1
		local sg3 = if d3 < 0 then -1 else 1
		for c = 1, 7 do
			local a0, a1, a2, a3 = v0[o + c], v1[o + c], v2[o + c], v3[o + c]
			if c <= 4 then
				a0 *= s0
				a2 *= sg2
				a3 *= sg3
			end
			local m1 = (a2 - a0) * m1s
			local m2 = (a3 - a1) * m2s
			r[c] = h00 * a1 + h10 * m1 + h01 * a2 + h11 * m2
		end
		local len = math.sqrt(r[1] * r[1] + r[2] * r[2] + r[3] * r[3] + r[4] * r[4])
		if len > 1e-6 then
			r[1] /= len
			r[2] /= len
			r[3] /= len
			r[4] /= len
		else
			r[4] = 1
		end
		out[name] = r
	end
	return out
end
CrowRig.sample = sample

local IDENT = { 0, 0, 0, 1, 0, 0, 0 }

function CrowRig.play(self: Rig, name: string, fadeTime: number?, speed: number?, startFrame: number?)
	local anim = (Anims :: any)[name] :: Anim?
	if not anim then
		return
	end
	local cur = self.cur
	if cur and cur.name == name then
		cur.speed = speed or cur.speed
		return
	end
	self.prev = cur
	self.cur = { name = name, anim = anim, frame = startFrame or 0, speed = speed or 1 }
	self.fadeTime = fadeTime or 0.2
	self.fade = if self.prev and self.fadeTime > 0 then 0 else 1
end

function CrowRig.setSpeed(self: Rig, speed: number)
	if self.cur then
		self.cur.speed = speed
	end
end

-- current animation name and frame
function CrowRig.state(self: Rig): (string?, number)
	local cur = self.cur
	if not cur then
		return nil, 0
	end
	return cur.name, cur.frame
end

function CrowRig.finished(self: Rig): boolean
	local cur = self.cur
	return cur == nil or (not cur.anim.loop and cur.frame >= cur.anim.frames)
end

local function apply(self: Rig, poseA: { [string]: { number } }?, poseB: { [string]: { number } }, w: number)
	local scale = self.model:GetScale()
	for name, bone in pairs(self.bones) do
		local b = poseB[name] or IDENT
		local q = b
		if poseA and w < 1 then
			local a = poseA[name] or IDENT
			local dot = a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4]
			local sg = if dot < 0 then -1 else 1
			local r = table.create(7, 0)
			for c = 1, 7 do
				local av = a[c]
				if c <= 4 then
					av *= sg
				end
				r[c] = av + (b[c] - av) * w
			end
			local len = math.sqrt(r[1] * r[1] + r[2] * r[2] + r[3] * r[3] + r[4] * r[4])
			r[1] /= len
			r[2] /= len
			r[3] /= len
			r[4] /= len
			q = r
		end
		local R, Ri = REST[name], REST_INV[name]
		if R then
			local Q = CFrame.new(0, 0, 0, q[1], q[2], q[3], q[4])
			local t = Vector3.new(q[5], q[6], q[7]) * scale
			bone.Transform = CFrame.new(Ri * t) * (Ri * Q * R)
		end
	end
end

function CrowRig.step(self: Rig, dt: number)
	local cur = self.cur
	if not cur then
		return
	end
	local fps = CrowRig.FPS
	cur.frame += dt * fps * cur.speed
	if not cur.anim.loop and cur.frame > cur.anim.frames then
		cur.frame = cur.anim.frames
	end
	local prev = self.prev
	local poseA = nil
	if prev and self.fade < 1 then
		prev.frame += dt * fps * prev.speed
		if not prev.anim.loop and prev.frame > prev.anim.frames then
			prev.frame = prev.anim.frames
		end
		self.fade = math.min(1, self.fade + dt / math.max(self.fadeTime, 1e-3))
		poseA = sample(prev.anim, prev.frame)
	else
		self.prev = nil
	end
	local w = self.fade
	w = w * w * (3 - 2 * w)
	apply(self, poseA, sample(cur.anim, cur.frame), w)
end

-- show one frame of one animation right now (viewports, thumbnails)
function CrowRig.pose(self: Rig, name: string, frame: number)
	local anim = (Anims :: any)[name] :: Anim?
	if anim then
		apply(self, nil, sample(anim, frame), 1)
	end
end

-- back to the bind pose
function CrowRig.reset(self: Rig)
	for _, b in pairs(self.bones) do
		b.Transform = CFrame.identity
	end
end

return CrowRig
