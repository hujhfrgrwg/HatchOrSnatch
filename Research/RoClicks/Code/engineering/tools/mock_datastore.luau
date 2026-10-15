--!nocheck
-- Mock DataStore + fake clock for plain-luau tests of save code (no Roblox needed).
--   local M = require("./mock_datastore")
--   local env = M.env()                 -- env.clock / env.time / env.wait / env.spawn / env.warn
--   local store = M.store()             -- store.data[key], store.fail(msg, n), store.calls
--   local p = M.player(1)               -- p.kicked holds the Kick message
-- task.wait advances the fake clock instantly and calls env.onWait(), so "another server releases the lock
-- after 3 waits" is one line and a 30 s wait costs no real time.
local M = {}

local function deep(t)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in pairs(t) do o[k] = deep(v) end
	return o
end
M.deep = deep

function M.store()
	local s = { data = {}, calls = 0, queue = {} }
	-- throw `msg` on the next n calls (e.g. "502: API Services rejected request with error. HTTP 500")
	function s.fail(msg, n)
		for _ = 1, n or 1 do table.insert(s.queue, msg) end
	end
	function s:UpdateAsync(key, fn)
		self.calls += 1
		if #self.queue > 0 then error(table.remove(self.queue, 1), 0) end
		-- real DataStores never share tables with the caller: copy in and out
		local v = fn(deep(self.data[key]))
		if v ~= nil then self.data[key] = deep(v) end
		return deep(v)
	end
	function s:GetAsync(key)
		self.calls += 1
		if #self.queue > 0 then error(table.remove(self.queue, 1), 0) end
		return deep(self.data[key])
	end
	function s:SetAsync(key, v)
		self.calls += 1
		if #self.queue > 0 then error(table.remove(self.queue, 1), 0) end
		self.data[key] = deep(v)
	end
	return s
end

function M.env()
	local e = { t = 0, epoch = 1000000, warns = {}, onWait = nil }
	e.clock = function() return e.t end
	e.time = function() return e.epoch + math.floor(e.t) end
	e.wait = function(n)
		e.t += (n or 0.03)
		if e.onWait then e.onWait() end
		return n
	end
	e.spawn = function(f, ...) return f(...) end -- run inline: deterministic order
	e.warn = function(...) table.insert(e.warns, table.concat({ ... }, " ")) end
	return e
end

function M.player(id)
	local p = { UserId = id, Name = "Player" .. id, Parent = true, kicked = nil }
	function p:Kick(msg) self.kicked = msg; self.Parent = nil end
	return p
end

-- tiny assertion helper: collects failures, prints PASS/FAIL lines
function M.checker()
	local c = { failed = 0 }
	function c.check(name, cond)
		print((cond and "PASS " or "FAIL ") .. name)
		if not cond then c.failed += 1 end
	end
	function c.done()
		if c.failed > 0 then error(c.failed .. " check(s) failed") end
		print("all checks passed")
	end
	return c
end

return M
