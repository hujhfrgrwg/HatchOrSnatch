--!nocheck
-- DataTests: TEST_PLAN B07 + session-lock cases against DataService with the in-memory mock
-- store (never a real DataStore). Run in Studio edit mode:
--   require(game.ServerStorage.EOSBuild.DataTests)()
-- Uses fake player tables (UserId / Parent / SetAttribute / Kick) so no playtest is needed.

return function()
	local DataService = require(game.ServerScriptService.EOS.Services.DataService)
	local lines, passed, failed = {}, 0, 0
	local function case(id, name, fn)
		local ok, err = pcall(fn)
		if ok then
			passed += 1
			table.insert(lines, "PASS " .. id .. " " .. name)
		else
			failed += 1
			table.insert(lines, "FAIL " .. id .. " " .. name .. " :: " .. tostring(err))
		end
	end
	local function eq(a, b, msg)
		if a ~= b then
			error((msg or "expected equal") .. ": got " .. tostring(a) .. ", want " .. tostring(b), 2)
		end
	end
	local function fakePlayer(id)
		local attrs = {}
		return {
			UserId = id,
			Parent = game,
			DisplayName = "Fake" .. id,
			kicked = nil,
			SetAttribute = function(self, k, v)
				attrs[k] = v
			end,
			GetAttribute = function(self, k)
				return attrs[k]
			end,
			Kick = function(self, msg)
				self.kicked = msg
				self.Parent = nil
			end,
		}
	end
	local HttpService = game:GetService("HttpService")
	local function stored(store, id)
		local raw = store.data["p_" .. id]
		return raw and HttpService:JSONDecode(raw)
	end

	local store = DataService.MemoryStore.new()
	DataService._setStore(store)

	case("B14-DS", "New player loads with safe defaults and a session lock", function()
		local plr = fakePlayer(9001)
		DataService._load(plr)
		assert(DataService.isLoaded(plr), "loaded")
		local d = stored(store, 9001)
		eq(d.schemaVersion, 3)
		eq(d._session.id, DataService.SESSION)
		eq(plr:GetAttribute("EOS_Loaded"), true)
	end)

	case("B07", "Write fails twice then succeeds: one credit, no duplicate", function()
		local plr = fakePlayer(9002)
		DataService._load(plr)
		store:failNext(2)
		local s = { key = "m-b07", matchId = "m-b07", eggTier = 3, material = "epic", gold = 25, stats = { matchesCompleted = 1 } }
		local applied = DataService.settle(plr, s)
		eq(applied, true, "optimistic apply")
		local t0 = os.clock()
		while os.clock() - t0 < 8 and #DataService._session(plr).queue > 0 do
			task.wait(0.2)
		end
		eq(#DataService._session(plr).queue, 0, "queue drained after retries")
		local d = stored(store, 9002)
		eq(d.materials.epic, 1)
		eq(d.gold, 25)
		-- same settlement again (e.g. a retried settlement call): nothing changes
		local again = DataService.settle(plr, s)
		eq(again, false)
		task.wait(0.5)
		d = stored(store, 9002)
		eq(d.materials.epic, 1)
		eq(d.gold, 25)
	end)

	case("B04-DS", "A Level 4 Epic piece persists across a rejoin", function()
		local plr = fakePlayer(9003)
		DataService._load(plr)
		DataService.settle(plr, { key = "m-b04", matchId = "m-b04", eggTier = 4, material = "epic", gold = 35, stats = { matchesCompleted = 1, wins = 1 } })
		task.wait(0.5)
		DataService._release(plr)
		local again = fakePlayer(9003)
		DataService._load(again)
		local p = DataService.get(again)
		eq(p.materials.epic, 1)
		eq(p.stats.wins, 1)
		eq(stored(store, 9003)._session.id, DataService.SESSION)
	end)

	case("LOCK-STALE", "A stale lock from a dead server is taken over", function()
		store.data["p_9004"] = HttpService:JSONEncode({ schemaVersion = 2, shells = 77, _session = { id = "dead-server", t = os.time() - 10000 } })
		local plr = fakePlayer(9004)
		DataService._load(plr)
		eq(DataService.get(plr).gold, 77) -- a V2 save's Shells arrive as Gold
		eq(stored(store, 9004)._session.id, DataService.SESSION)
	end)

	case("LOCK-TAKEN", "A live foreign lock refuses our write (never overwrites)", function()
		local plr = fakePlayer(9005)
		DataService._load(plr)
		local d = stored(store, 9005)
		d._session = { id = "other-live-server", t = os.time() }
		d.gold = 500
		store.data["p_9005"] = HttpService:JSONEncode(d)
		DataService.settle(plr, { key = "m-lock", matchId = "m-lock", eggTier = 2, material = "rare", gold = 10, stats = {} })
		task.wait(1.5)
		local after = stored(store, 9005)
		eq(after.gold, 500, "foreign data untouched")
		eq(after.materials.rare, 0)
		eq(DataService._session(plr) and DataService._session(plr).noSave, true)
		assert(plr.kicked, "player told to rejoin")
	end)

	case("TEST-MATCH", "Test matches never save rewards", function()
		local plr = fakePlayer(9006)
		DataService._load(plr)
		local applied = DataService.settle(plr, { key = "m-test", matchId = "m-test", isTest = true, eggTier = 3, material = "epic", gold = 50, stats = {} })
		eq(applied, false)
		task.wait(0.3)
		eq(stored(store, 9006).gold, 0)
	end)

	-- leave the module's store as a fresh memory store
	DataService._setStore(DataService.MemoryStore.new())
	return { passed = passed, failed = failed, lines = lines }
end
