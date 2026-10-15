--!strict
-- FXPool.luau: one client FX controller that plays particle templates from ReplicatedStorage,
-- pooled, budgeted per quality, with a GENERATION COUNTER so stale timers and handles can't kill
-- a reused effect.
--
-- Templates: ReplicatedStorage.GameVFX.<Name> = an anchored, invisible, non-colliding Part holding
-- ParticleEmitters / Beams / Trails / Lights.  Attributes:
--   Kind      = "burst" | "loop"
--   EmitCount = number   (on each burst emitter: particles per :Emit())
--
--   FX.burst("explosion_large", pos, { scale = 1, cull = true })
--   local h = FX.loop("fire", pos, { group = "battle" });  h:stop()
--   FX.clear("battle")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FX = {}
FX.quality = 2 -- 1 Low, 2 Medium, 3 High. Default Low on touch / small screens (set by the settings code).
FX.stats = { played = 0, dropped = 0, culled = 0, missing = 0 }

local Q_COUNT = { 0.5, 1, 1.25 } -- burst particle count multiplier per quality
local Q_RATE = { 0.5, 1, 1.15 }  -- loop emission rate multiplier
local BUDGET = { small = 70, medium = 22, big = 9 } -- plays per second at Medium
local LIVE_CAP = { small = 24, medium = 10, big = 8 } -- per template
local CULL_DIST = { small = 220, medium = 420 }      -- big effects are never distance-culled
local CLASS: { [string]: string } = { muzzle = "small", impact = "small", sparkle = "small", explosion_large = "big" }
local PARK = CFrame.new(0, -2000, 0)
local MAX_PARKED = 8

type Rec = {
	name: string, key: string, root: BasePart, gen: number, alive: boolean, group: string?,
	bursts: { { e: ParticleEmitter, n: number } }, loops: { ParticleEmitter }, other: { Instance },
	life: number, q: number,
}

local folder: Folder? = nil
local pools: { [string]: { Rec } } = {}
local live: { [Rec]: boolean } = {}
local liveCount: { [string]: number } = {}
local buckets: { [string]: { tokens: number, t: number } } = {}

local function holder(): Folder
	if folder and folder.Parent then return folder end
	local old = Workspace:FindFirstChild("RuntimeFX")
	if old then old:Destroy() end -- left over from an edit-mode run that got saved
	local f = Instance.new("Folder")
	f.Name = "RuntimeFX"
	if not RunService:IsRunning() then f.Archivable = false end
	f.Parent = Workspace
	folder = f
	return f
end

local function template(name: string): BasePart?
	local lib = ReplicatedStorage:FindFirstChild("GameVFX")
	local t = lib and lib:FindFirstChild(name)
	if not t then
		FX.stats.missing += 1
		warn("[FX] missing template " .. name)
		return nil
	end
	return t :: BasePart
end

local function prepare(name: string, key: string, tpl: BasePart, scale: number): Rec
	local q = FX.quality
	local root = tpl:Clone()
	root.Anchored, root.CanCollide, root.CanQuery, root.Transparency = true, false, false, 1
	local rec: Rec = { name = name, key = key, root = root, gen = 0, alive = false, bursts = {}, loops = {}, other = {}, life = 0, q = q }
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			if scale ~= 1 then
				local ks = {}
				for _, kp in d.Size.Keypoints do
					table.insert(ks, NumberSequenceKeypoint.new(kp.Time, kp.Value * scale, kp.Envelope * scale))
				end
				d.Size = NumberSequence.new(ks)
			end
			rec.life = math.max(rec.life, d.Lifetime.Max)
			local n = d:GetAttribute("EmitCount")
			if typeof(n) == "number" then
				d.Enabled = false
				table.insert(rec.bursts, { e = d, n = math.max(1, math.round(n * Q_COUNT[q])) })
			else
				d.Rate *= Q_RATE[q]
				d.Enabled = false
				table.insert(rec.loops, d)
			end
		elseif d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") then
			(d :: any).Enabled = false
			table.insert(rec.other, d)
		end
	end
	root.CFrame = PARK
	root.Parent = holder()
	return rec
end

local function acquire(name: string, scale: number, group: string?): Rec?
	local tpl = template(name)
	if not tpl then return nil end
	local key = name .. "|" .. scale .. "|" .. FX.quality -- sizes and rates are baked per scale + quality
	local pool = pools[key]
	local rec = pool and table.remove(pool) or prepare(name, key, tpl, scale)
	rec.gen += 1 -- NEW USE: every timer/handle from the previous use stops matching
	rec.alive = true
	rec.group = group
	live[rec] = true
	liveCount[name] = (liveCount[name] or 0) + 1
	return rec
end

local function release(rec: Rec)
	if not rec.alive then return end
	rec.alive = false
	live[rec] = nil
	liveCount[rec.name] = math.max(0, (liveCount[rec.name] or 1) - 1)
	for _, e in rec.loops do e.Enabled = false end
	for _, o in rec.other do (o :: any).Enabled = false end
	local pool = pools[rec.key] or {}
	pools[rec.key] = pool
	if #pool < MAX_PARKED and rec.root.Parent and rec.q == FX.quality then
		rec.root.CFrame = PARK
		table.insert(pool, rec)
	else
		rec.root:Destroy()
	end
end

-- the only way to schedule a release: it checks the generation it was scheduled for
local function releaseLater(rec: Rec, t: number)
	local g = rec.gen
	task.delay(t, function()
		if rec.gen == g then release(rec) end
	end)
end

local function admit(name: string, pos: Vector3, cull: boolean): boolean
	local cls = CLASS[name] or "medium"
	if (liveCount[name] or 0) >= LIVE_CAP[cls] then FX.stats.dropped += 1 return false end
	local cam = Workspace.CurrentCamera
	if cull and cam and CULL_DIST[cls] then
		local _, onScreen = cam:WorldToViewportPoint(pos)
		if not onScreen or (cam.CFrame.Position - pos).Magnitude > CULL_DIST[cls] then FX.stats.culled += 1 return false end
	end
	local rate = BUDGET[cls] * Q_COUNT[FX.quality]
	local now = os.clock()
	local b = buckets[cls] or { tokens = rate, t = now }
	buckets[cls] = b
	b.tokens = math.min(rate, b.tokens + (now - b.t) * rate)
	b.t = now
	if b.tokens < 1 then FX.stats.dropped += 1 return false end -- drop, never queue
	b.tokens -= 1
	return true
end

function FX.burst(name: string, pos: Vector3, opts: { scale: number?, cull: boolean?, group: string? }?)
	local o = opts or {}
	if not admit(name, pos, o.cull ~= false) then return end
	local rec = acquire(name, o.scale or 1, o.group)
	if not rec then return end
	rec.root.CFrame = CFrame.new(pos)
	for _, b in rec.bursts do b.e:Emit(b.n) end
	FX.stats.played += 1
	releaseLater(rec, rec.life + 0.25)
end

export type Handle = { rec: Rec, gen: number, stop: (self: Handle, immediate: boolean?) -> () }

function FX.loop(name: string, pos: Vector3, opts: { scale: number?, group: string? }?): Handle?
	local o = opts or {}
	local rec = acquire(name, o.scale or 1, o.group)
	if not rec then return nil end
	rec.root.CFrame = CFrame.new(pos)
	for _, e in rec.loops do e.Enabled = true end
	for _, x in rec.other do (x :: any).Enabled = true end
	local h = { rec = rec, gen = rec.gen } :: any
	function h.stop(self: Handle, immediate: boolean?)
		if self.rec.gen ~= self.gen then return end -- stale handle: the rec belongs to someone else now
		for _, e in self.rec.loops do e.Enabled = false end
		if immediate then release(self.rec) else releaseLater(self.rec, self.rec.life + 0.25) end
	end
	return h :: Handle
end

function FX.clear(group: string?)
	for rec in table.clone(live) do
		if group == nil or rec.group == group then release(rec) end
	end
end

-- Quality change: drop the pools; new plays prepare at the new quality.
function FX.setQuality(q: number)
	FX.quality = math.clamp(math.floor(q), 1, 3)
	for _, pool in pools do for _, rec in pool do rec.root:Destroy() end end
	table.clear(pools)
end

return FX
