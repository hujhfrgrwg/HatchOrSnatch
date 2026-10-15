--!nocheck
-- SessionStore: one-key-per-player DataStore saves with a session lock, retry/backoff, a kick on failed
-- load, idempotent receipts and a BindToClose that waits for in-flight saves. Game-agnostic.
-- See ../data-and-saves.md for the reasons behind every rule. Plain-Luau test: test_sessionstore.luau.
--
--   local S = SessionStore.new({
--       store    = DataStoreService:GetDataStore("Saves_v1"),
--       defaults = function() return { version = 1, cash = 0 } end,
--       migrate  = function(data) return data end,        -- optional: fill/rename fields
--       isStudio = RunService:IsStudio(),
--       sessionId = HttpService:GenerateGUID(false),       -- game.JobId is "" in Studio
--   })
--   local data = S:load(player)            -- nil = player was kicked (never a silent fresh game)
--   S:save(player, data)                   -- autosave; refreshes the lock; ok, why
--   S:saveFinal(player, data)              -- leave save; clears the lock
--   S:grantReceipt(player, data, purchaseId, grantFn) -- "granted" | "duplicate" | "failed"
--   S:bind(Players, getData, setData)      -- PlayerAdded/Removing, autosave loop, BindToClose
-- Injected for tests (default to the real globals): opts.clock, opts.time, opts.wait, opts.spawn, opts.warn.
local SessionStore = {}
SessionStore.__index = SessionStore

SessionStore.LEASE = 180 -- a lock refreshed less than this many seconds ago belongs to a live server
SessionStore.LOCK_WAIT = 30 -- how long a join waits for another server's lock before taking it over
SessionStore.LOAD_TRIES = 5
SessionStore.WRITE_TRIES = 3
SessionStore.AUTOSAVE = 60
SessionStore.CLOSE_BUDGET = 28 -- BindToClose has 30 s in total

local RUNTIME_KEYS = { lock = true, noSave = true }

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in pairs(t) do o[k] = deepCopy(v) end
	return o
end

-- replace NaN / inf with 0 (one NaN soft-locks every comparison) and report where it was
local function sanitise(t, path, warnFn)
	for k, v in pairs(t) do
		if type(v) == "number" and (v ~= v or v == math.huge or v == -math.huge) then
			t[k] = 0
			warnFn("[SessionStore] non-finite number at " .. path .. "." .. tostring(k))
		elseif type(v) == "table" then
			sanitise(v, path .. "." .. tostring(k), warnFn)
		end
	end
end

function SessionStore.new(opts)
	local self = setmetatable({}, SessionStore)
	self.store = opts.store
	self.defaults = opts.defaults
	self.migrate = opts.migrate or function(d) return d end
	self.isStudio = opts.isStudio
	self.session = opts.sessionId or tostring(math.random(1, 2 ^ 30))
	self.keyFor = opts.keyFor or function(p) return "p_" .. tostring(p.UserId) end
	self.clock = opts.clock or os.clock
	self.time = opts.time or os.time
	self.wait = opts.wait or task.wait
	self.spawn = opts.spawn or task.spawn
	self.warn = opts.warn or warn
	self.memoryOnly = opts.memoryOnly or false
	self.memory = {}
	self.saving = {} -- [player] = true while a write runs
	self.nextSave = {} -- [player] = clock time of the next autosave
	self.fails = {} -- [player] = consecutive failed saves
	return self
end

-- Only Studio with API access off is "memory-only". A live "502: API Services rejected request" is transient.
function SessionStore:isAccessOff(msg)
	msg = tostring(msg)
	return self.isStudio and (string.find(msg, "403") ~= nil or string.find(msg, "StudioAccessToApisNotAllowed") ~= nil)
end

function SessionStore:lockedByOther(old)
	local l = type(old) == "table" and old.lock
	return type(l) == "table" and l.id ~= self.session and self.time() - (tonumber(l.t) or 0) < SessionStore.LEASE
end

function SessionStore:serialise(data)
	local copy = deepCopy(data)
	for k in pairs(RUNTIME_KEYS) do copy[k] = nil end
	sanitise(copy, "save", self.warn)
	return copy
end

-- Returns data, or nil after kicking the player. Never returns a fresh game for a failed load.
function SessionStore:load(player)
	local key = self.keyFor(player)
	if self.memoryOnly then
		return self.migrate(deepCopy(self.memory[key]) or self.defaults())
	end
	local t0, tries = self.clock(), 0
	while true do
		local state, result
		local ok, err = pcall(function()
			self.store:UpdateAsync(key, function(old)
				if old == nil then state = "new" return nil end -- no lock-only table for a new player
				if self:lockedByOther(old) and self.clock() - t0 < SessionStore.LOCK_WAIT then
					state = "locked" return nil
				end
				if self:lockedByOther(old) then self.warn("[SessionStore] taking over a stale lock for " .. key) end
				old.lock = { id = self.session, t = self.time() }
				state, result = "ok", old
				return old
			end)
		end)
		if ok and state == "new" then return self.migrate(self.defaults()) end
		if ok and state == "ok" then
			result.lock = nil
			return self.migrate(result)
		end
		if ok and state == "locked" then
			self.wait(3) -- the other server is finishing its leave save
		elseif not ok then
			if self:isAccessOff(err) then
				self.warn("[SessionStore] Studio API access is off: saves are memory-only this session")
				self.memoryOnly = true
				return self:load(player)
			end
			tries += 1
			self.warn("[SessionStore] load failed (" .. tries .. "): " .. tostring(err))
			if tries >= SessionStore.LOAD_TRIES then
				player:Kick("We couldn't load your save. Your progress is safe - please rejoin in a minute!")
				return nil
			end
			self.wait(2 ^ (tries - 1))
		end
	end
end

-- One guarded write. release = true clears the lock (leave save). Returns ok, why ("locked" | "error").
function SessionStore:write(player, data, release)
	local key = self.keyFor(player)
	if data.noSave then return false, "noSave" end
	if self.memoryOnly then self.memory[key] = self:serialise(data) return true end
	local payload = self:serialise(data)
	local why = "error"
	for attempt = 1, SessionStore.WRITE_TRIES do
		local refused = false
		local ok, err = pcall(function()
			self.store:UpdateAsync(key, function(old)
				if self:lockedByOther(old) then refused = true return nil end
				payload.lock = (not release) and { id = self.session, t = self.time() } or nil
				return payload
			end)
		end)
		if ok and not refused then return true end
		if refused then why = "locked" break end
		if self:isAccessOff(err) then self.memoryOnly = true return self:write(player, data, release) end
		self.warn("[SessionStore] save attempt " .. attempt .. " failed: " .. tostring(err))
		if attempt < SessionStore.WRITE_TRIES then self.wait(attempt) end
	end
	if why == "locked" then
		-- another server owns this profile now: stop saving this session and send the player back
		data.noSave = true
		player:Kick("Your progress was updated on another server. Please rejoin to keep playing!")
	end
	return false, why
end

-- Autosave entry point: serialised per player, next time set BEFORE the attempt, backoff on failure.
function SessionStore:save(player, data, release)
	while self.saving[player] do self.wait(0.1) end
	self.saving[player] = true
	self.nextSave[player] = self.clock() + SessionStore.AUTOSAVE
	local ok, why = self:write(player, data, release)
	self.saving[player] = nil
	if ok then
		self.fails[player] = 0
	else
		local n = (self.fails[player] or 0) + 1
		self.fails[player] = n
		self.nextSave[player] = self.clock() + math.min(15 * 2 ^ (n - 1), 300)
	end
	return ok, why
end

function SessionStore:saveFinal(player, data)
	return self:save(player, data, true)
end

-- Idempotent receipt: grant once per PurchaseId, and report granted only after the save landed.
function SessionStore:grantReceipt(player, data, purchaseId, grantFn)
	data.receipts = data.receipts or {}
	if data.receipts[purchaseId] then return "duplicate" end
	local undo = grantFn(data) -- returns an undo function (or nil)
	data.receipts[purchaseId] = self.time()
	if self:save(player, data) then return "granted" end
	data.receipts[purchaseId] = nil
	if type(undo) == "function" then undo(data) end
	return "failed"
end

-- Wire it up. getData(player) / setData(player, data|nil) connect it to your game state.
function SessionStore:bind(Players, getData, setData)
	local leaving = 0
	Players.PlayerAdded:Connect(function(p)
		local d = self:load(p)
		if d and p.Parent then setData(p, d) end
	end)
	Players.PlayerRemoving:Connect(function(p)
		leaving += 1
		local d = getData(p)
		if d then pcall(self.saveFinal, self, p, d) end
		setData(p, nil)
		leaving -= 1
	end)
	game:BindToClose(function()
		for _, p in Players:GetPlayers() do
			local d = getData(p)
			if d then self.spawn(pcall, self.saveFinal, self, p, d) end
		end
		local t0 = self.clock()
		while (leaving > 0 or next(self.saving)) and self.clock() - t0 < SessionStore.CLOSE_BUDGET do self.wait(0.1) end
	end)
	self.spawn(function()
		while true do
			self.wait(5)
			for _, p in Players:GetPlayers() do
				local d = getData(p)
				if d and not d.noSave and not self.saving[p] and self.clock() >= (self.nextSave[p] or 0) then
					self.spawn(self.save, self, p, d)
				end
			end
		end
	end)
end

return SessionStore
