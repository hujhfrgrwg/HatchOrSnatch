--!strict
-- ChunkStreamer: client-side streaming of a large or endless map in square chunks, with LODs, a per-frame
-- time budget and pools. A skeleton: plug in your own chunk content via `Streamer.content`.
--
-- The four rules this encodes, each from a real bug:
--   1. PUBLISH THEN RELEASE. Build the new LOD copy fully, record it as the loaded copy, and only then queue
--      the old copy's release. Releasing inside the build job orphaned whole chunks when the job was cancelled
--      between the two steps (duplicate ground z-fighting, stale buildings, leaked parts).
--   2. NEVER CANCEL A RELEASE. Releases yield piece by piece; a "cancel" just drops the coroutine at its last
--      yield and leaves a half-destroyed chunk. Release jobs have their own tag and are never cancelled.
--   3. FILTER BEFORE CLONE. Decide whether a template child is wanted from the SOURCE child; cloning a 2.8k
--      part template and hiding most of it cost ~50 ms per chunk and kept hidden parts alive in pools.
--   4. POOLS RESET AND STAY SMALL. Reset Transparency (and anything else you change) on acquire, cap each
--      template's pool, and clear pools on quality change. A reused chunk kept its ground hidden from an
--      old LOD swap and showed the void through the map.

local RunService = game:GetService("RunService")

local Streamer = {}
Streamer.BUDGET = 0.004 -- seconds of work per frame
Streamer.CHUNK = 96 -- studs per chunk side
Streamer.RADII = { full = 1, lite = 2, flat = 4 } -- in chunks, Chebyshev distance from the focus chunk
Streamer.POOL_MAX = { default = 6 } -- per-template caps; set 1 for whole-chunk templates

-- content provider: return the template for a chunk at an LOD, and whether a template child is wanted
Streamer.content = {
	template = function(_cx: number, _cz: number, _lod: string): Model? return nil end,
	-- `at` = where the piece would land; return false to skip it (never cloned, never pooled)
	keep = function(_src: PVInstance, _at: CFrame): boolean return true end,
}

---------------------------------------------------------------- scheduler (time-budgeted coroutines)
type Job = { co: thread, tag: string, prio: number, dead: boolean }
local jobs: { Job } = {}
local frameStart = 0

-- call inside a job between units of work: yields if this frame's budget is spent
function Streamer.step()
	if os.clock() - frameStart > Streamer.BUDGET then
		coroutine.yield()
	end
end

local function add(fn: () -> (), prio: number, tag: string): Job
	local job = { co = coroutine.create(fn), tag = tag, prio = prio, dead = false }
	table.insert(jobs, job)
	table.sort(jobs, function(a, b) return a.prio > b.prio end)
	return job
end

-- cancel BUILD jobs only. Anything tagged "release" always runs to the end.
local function cancel(job: Job)
	if job.tag ~= "release" then
		job.dead = true
	end
end

RunService.Heartbeat:Connect(function()
	frameStart = os.clock()
	local i = 1
	while i <= #jobs and os.clock() - frameStart < Streamer.BUDGET do
		local job = jobs[i]
		if job.dead or coroutine.status(job.co) == "dead" then
			table.remove(jobs, i)
		else
			local ok, err = coroutine.resume(job.co)
			if not ok then
				warn("[Streamer] job error: " .. tostring(err))
				job.dead = true
			end
			i += 1
		end
	end
end)

---------------------------------------------------------------- pools
-- Pooled per SOURCE piece (a direct child of a chunk template), so a filtered-out piece is never cloned.
local pools: { [Instance]: { PVInstance } } = {}

local function acquire(src: PVInstance): PVInstance
	local pool = pools[src]
	local m = pool and table.remove(pool)
	if not m then
		return src:Clone()
	end
	-- reset everything a previous user may have changed (rule 4). Clones keep descendant order.
	local a, b = src:GetDescendants(), m:GetDescendants()
	table.insert(a, 1, src)
	table.insert(b, 1, m)
	for i, d in b do
		local s = a[i]
		if d:IsA("BasePart") and s and s:IsA("BasePart") then
			d.Transparency = s.Transparency
			d.Color = s.Color
		end
	end
	return m
end

local function release(src: PVInstance, m: PVInstance)
	m.Parent = nil
	local pool = pools[src] or {}
	pools[src] = pool
	local tpl = src.Parent
	local cap = Streamer.POOL_MAX[tpl and tpl.Name or ""] or Streamer.POOL_MAX.default
	if #pool < cap then
		table.insert(pool, m)
	else
		m:Destroy()
	end
end

function Streamer.clearPools()
	for _, pool in pools do
		for _, m in pool do m:Destroy() end
	end
	table.clear(pools)
end

---------------------------------------------------------------- chunks
type Piece = { src: PVInstance, inst: PVInstance }
type Rec = { lod: string, folder: Folder, pieces: { Piece } }
local loaded: { [string]: Rec } = {}
local inflight: { [string]: Job } = {}
local root = Instance.new("Folder")
root.Name = "StreamedWorld"
root.Parent = workspace

local function key(cx: number, cz: number): string return `{cx},{cz}` end

-- uncancellable: tagged "release" (rule 2)
local function queueRelease(rec: Rec)
	add(function()
		for _, piece in rec.pieces do
			release(piece.src, piece.inst)
			Streamer.step()
		end
		rec.folder:Destroy()
	end, -10, "release")
end

local function build(cx: number, cz: number, lod: string)
	local k = key(cx, cz)
	local tpl = Streamer.content.template(cx, cz, lod)
	local folder = Instance.new("Folder")
	folder.Name = `C{k}_{lod}`
	local rec: Rec = { lod = lod, folder = folder, pieces = {} }
	-- If this job is cancelled at a step(), nothing was published: the unparented folder is simply
	-- dropped. (Put a one-part "backstop" ground under every chunk elsewhere, so an LOD swap in flight
	-- shows plain ground, never the void.)
	if tpl then
		local origin = CFrame.new(cx * Streamer.CHUNK, 0, cz * Streamer.CHUNK)
		local toLocal = tpl:GetPivot():Inverse()
		for _, src in tpl:GetChildren() do
			if src:IsA("PVInstance") then
				local at = origin * (toLocal * src:GetPivot())
				if Streamer.content.keep(src, at) then -- rule 3: decide on the SOURCE, before cloning
					local inst = acquire(src)
					inst:PivotTo(at)
					inst.Parent = folder
					table.insert(rec.pieces, { src = src, inst = inst })
					Streamer.step()
				end
			end
		end
	end
	folder.Parent = root
	local old = loaded[k]
	loaded[k] = rec -- rule 1: publish first...
	inflight[k] = nil
	if old then queueRelease(old) end -- ...then release
end

local function lodFor(dist: number): string
	if dist <= Streamer.RADII.full then return "full" end
	if dist <= Streamer.RADII.lite then return "lite" end
	if dist <= Streamer.RADII.flat then return "flat" end
	return "none"
end

-- call a few times per second with the camera focus
function Streamer.update(focus: Vector3)
	local fx, fz = math.floor(focus.X / Streamer.CHUNK + 0.5), math.floor(focus.Z / Streamer.CHUNK + 0.5)
	local r = Streamer.RADII.flat
	local want: { [string]: boolean } = {}
	for cx = fx - r, fx + r do
		for cz = fz - r, fz + r do
			local k = key(cx, cz)
			local lod = lodFor(math.max(math.abs(cx - fx), math.abs(cz - fz)))
			want[k] = true
			local rec, job = loaded[k], inflight[k]
			if (not rec or rec.lod ~= lod) and not job then
				local prio = -math.max(math.abs(cx - fx), math.abs(cz - fz)) -- near first
				inflight[k] = add(function() build(cx, cz, lod) end, prio, "build")
			end
		end
	end
	for k, rec in loaded do
		if not want[k] then
			loaded[k] = nil
			local job = inflight[k]
			if job then cancel(job); inflight[k] = nil end -- a build: safe, nothing published yet
			queueRelease(rec)
		end
	end
end

-- quality change / map reset: cancel builds, let releases finish, then drop pools
function Streamer.clear()
	for _, job in jobs do cancel(job) end
	table.clear(inflight)
	for k, rec in loaded do
		loaded[k] = nil
		queueRelease(rec)
	end
	task.delay(2, Streamer.clearPools)
end

return Streamer
