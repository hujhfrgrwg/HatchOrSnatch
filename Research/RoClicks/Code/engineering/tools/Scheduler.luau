--!nocheck
-- Scheduler: time-budgeted coroutine jobs, so heavy work (streaming chunks, cloning big models, building a
-- world, baking meshes) spreads over frames instead of one long hitch. Client or server.
--
--   local S = require(Scheduler)
--   S.budgetMs = 4                                   -- per frame, for ALL jobs together
--   local job = S.add(function()
--       for i, piece in pieces do
--           piece:Clone().Parent = folder
--           S.step()                                 -- yields if this frame's budget is used up
--       end
--   end, 10, "chunk")                                -- priority (lower runs first), tag
--   S.cancel(job) / S.cancelTag("chunk")             -- drops the coroutine at its last step()
--   S.drain(5)                                       -- run everything now (edit-mode harnesses, tests)
--
-- RULE: never cancel a job in the middle of a RELEASE (destroy / return-to-pool). Cancel drops the coroutine
-- where it yielded, so a half-released model is orphaned forever: duplicate ground, stale props, leaked parts.
-- Publish the new thing first, then release the old one in its own job under a tag nobody cancels.
local S = {}
S.budgetMs = 4
S.worstSliceMs = 0 -- longest uninterrupted slice seen (find the loop that forgot to call step())

local jobs = {}
local frameStart = os.clock()
local inJob, draining = false, false

function S.add(fn, priority, tag)
	local job = { co = coroutine.create(fn), pri = priority or 0, tag = tag }
	table.insert(jobs, job)
	return job
end

function S.cancel(job) if job then job.dead = true end end

function S.cancelTag(tag)
	for _, j in jobs do if j.tag == tag then j.dead = true end end
end

function S.pending()
	local n = 0
	for _, j in jobs do if not j.dead then n += 1 end end
	return n
end

local function over()
	if draining then return false end
	return (os.clock() - frameStart) * 1000 > S.budgetMs
end

-- cooperative yield point: call it inside every loop iteration of a job
function S.step()
	if inJob and over() then coroutine.yield() end
end

local function runFrame()
	frameStart = os.clock()
	if #jobs == 0 then return end
	table.sort(jobs, function(a, b) return a.pri < b.pri end)
	local i = 1
	while i <= #jobs and not over() do
		local j = jobs[i]
		if j.dead then
			table.remove(jobs, i)
		else
			inJob = true
			local t0 = os.clock()
			local ok, err = coroutine.resume(j.co)
			S.worstSliceMs = math.max(S.worstSliceMs, (os.clock() - t0) * 1000)
			inJob = false
			if not ok then
				warn("[Scheduler] job error: " .. tostring(err) .. "\n" .. debug.traceback(j.co))
				table.remove(jobs, i)
			elseif coroutine.status(j.co) == "dead" then
				table.remove(jobs, i)
			else
				i += 1
			end
		end
	end
end

function S.drain(maxSeconds)
	local t0 = os.clock()
	draining = true
	while #jobs > 0 and os.clock() - t0 < (maxSeconds or 20) do runFrame() end
	draining = false
	return #jobs
end

-- one Heartbeat hook drives everything (pass a fake signal in plain-luau tests)
function S.start(heartbeat)
	heartbeat = heartbeat or game:GetService("RunService").Heartbeat
	return heartbeat:Connect(runFrame)
end

return S
