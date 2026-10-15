--!nocheck
-- Plain-luau test of SessionStore against the mock DataStore. Run from this folder:
--   luau test_sessionstore.luau
local M = require("./mock_datastore")
local SessionStore = require("./SessionStore")
local c = M.checker()

local function fresh(isStudio)
	local env, store = M.env(), M.store()
	local S = SessionStore.new({
		store = store, isStudio = isStudio or false, sessionId = "SERVER-A",
		defaults = function() return { version = 1, cash = 0, fresh = true } end,
		clock = env.clock, time = env.time, wait = env.wait, spawn = env.spawn, warn = env.warn,
	})
	return S, store, env
end

-- 1 new player: no lock-only table written on load; first save writes the lock; leave save clears it
do
	local S, store = fresh()
	local p = M.player(1)
	local d = S:load(p)
	c.check("new player gets defaults", d and d.fresh == true and store.data.p_1 == nil)
	c.check("first save writes our lock", S:save(p, d) == true and store.data.p_1.lock.id == "SERVER-A")
	c.check("state never carries the lock", d.lock == nil)
	c.check("leave save clears the lock", S:saveFinal(p, d) == true and store.data.p_1.lock == nil)
end

-- 2 another live server holds the lock, then releases it (its leave save): we wait and load the newer save
do
	local S, store, env = fresh()
	store.data.p_2 = { cash = 100, lock = { id = "SERVER-B", t = env.time() } }
	local waits = 0
	env.onWait = function()
		waits += 1
		if waits == 3 then store.data.p_2 = { cash = 999 } end
	end
	local d = S:load(M.player(2))
	c.check("waits for the other server, loads its final save", d and d.cash == 999 and waits == 3)
	c.check("we now own the lock", store.data.p_2.lock.id == "SERVER-A")
end

-- 3 the other server died holding the lock: taken over after LOCK_WAIT
do
	local S, store, env = fresh()
	store.data.p_3 = { cash = 5, lock = { id = "SERVER-B", t = env.time() } }
	local d = S:load(M.player(3))
	c.check("stale lock taken over after ~30 s", d and env.t >= 30 and env.t < 40 and store.data.p_3.lock.id == "SERVER-A")
end

-- 4 a transient 502 is retried, and never flips the server to memory-only
do
	local S, store = fresh()
	store.data.p_4 = { cash = 44 }
	store.fail("502: API Services rejected request with error. HTTP 500", 2)
	local p = M.player(4)
	local d = S:load(p)
	c.check("502 retried, load ok", d and d.cash == 44 and p.kicked == nil and S.memoryOnly == false)
end

-- 5 load keeps failing: kick with a message, no silent fresh game
do
	local S, store = fresh()
	store.fail("502: API Services rejected request", SessionStore.LOAD_TRIES)
	local p = M.player(5)
	local d = S:load(p)
	c.check("persistent failure kicks, returns nil", d == nil and p.kicked ~= nil and S.memoryOnly == false)
end

-- 6 another server took the profile over: our save is refused, the session stops saving and kicks
do
	local S, store, env = fresh()
	local p = M.player(6)
	local d = S:load(p)
	S:save(p, d)
	store.data.p_6.lock = { id = "SERVER-C", t = env.time() }
	store.data.p_6.cash = 123
	local ok, why = S:save(p, d)
	c.check("save refused when another server owns the lock", ok == false and why == "locked" and store.data.p_6.cash == 123)
	c.check("session marked noSave and player kicked", d.noSave == true and p.kicked ~= nil)
end

-- 7 failed saves back off instead of retrying every tick
do
	local S, store, env = fresh()
	local p = M.player(7)
	local d = S:load(p)
	store.fail("502: API Services rejected request", SessionStore.WRITE_TRIES)
	local t0 = env.t
	c.check("3 failing attempts -> save false", S:save(p, d) == false)
	c.check("next autosave pushed out by the backoff", S.nextSave[p] - env.t >= 14 and S.nextSave[p] > t0)
	c.check("next save succeeds", S:save(p, d) == true and S.fails[p] == 0)
end

-- 8 Studio with API access off goes memory-only (and only Studio)
do
	local S, store = fresh(true)
	store.fail("StudioAccessToApisNotAllowed: 403: Cannot write to DataStore from studio", 1)
	local p = M.player(8)
	local d = S:load(p)
	c.check("Studio 403 -> memory-only fresh game", d and S.memoryOnly == true and p.kicked == nil)
	d.cash = 50
	S:save(p, d)
	c.check("memory-only save round-trips", S:load(p).cash == 50)
end

-- 9 receipts: granted once per PurchaseId, rolled back if the save fails
do
	local S, store = fresh()
	local p = M.player(9)
	local d = S:load(p)
	local grant = function(data) data.cash += 100 return function(x) x.cash -= 100 end end
	c.check("first receipt granted", S:grantReceipt(p, d, "PID-1", grant) == "granted" and d.cash == 100)
	c.check("retried receipt is a duplicate", S:grantReceipt(p, d, "PID-1", grant) == "duplicate" and d.cash == 100)
	store.fail("502: API Services rejected request", SessionStore.WRITE_TRIES)
	c.check("save failure -> failed, grant undone", S:grantReceipt(p, d, "PID-2", grant) == "failed" and d.cash == 100 and d.receipts["PID-2"] == nil)
end

-- 10 NaN never reaches the store
do
	local S, store, env = fresh()
	local p = M.player(10)
	local d = S:load(p)
	d.cash = 0 / 0
	S:save(p, d)
	c.check("NaN saved as 0 with a warning", store.data.p_10.cash == 0 and #env.warns > 0)
end

c.done()
