--!nocheck
-- LogicTests: TEST_PLAN A01-A24 / B01-B14 cases that are pure server logic.
-- Runs both in the Luau CLI (tests/run_local.luau) and in Studio edit mode:
--   require(game.ServerStorage.EOSBuild.LogicTests)(deps)
-- deps = { MatchLogic, ProfileLogic, TierConfig, RewardConfig, QuestConfig, RateLimiter, newRandom }
-- Returns { passed = n, failed = n, lines = { "PASS A01 ...", ... } }.

return function(deps)
	local MatchLogic = deps.MatchLogic
	local ProfileLogic = deps.ProfileLogic
	local Tiers = deps.TierConfig
	local Rewards = deps.RewardConfig
	local Quests = deps.QuestConfig
	local RateLimiter = deps.RateLimiter
	local Econ = deps.EconomyConfig
	local newRandom = deps.newRandom

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
	local function truthy(v, msg)
		if not v then
			error(msg or "expected truthy", 2)
		end
	end

	local seq = 0
	local function newMatch(extra)
		seq += 1
		local o = {
			matchId = "test-" .. seq,
			tiers = Tiers,
			rewards = Rewards,
			conversionGrace = 1.5,
			waveStartProtection = 0,
			minActiveDistance = 30,
		}
		for k, v in pairs(extra or {}) do
			o[k] = v
		end
		return MatchLogic.new(o)
	end
	-- runners 1..nr, catchers 100..(99+nc); everyone marked active
	local function setup(nr, nc, extra)
		local m = newMatch(extra)
		for i = 1, nr do
			m:addParticipant(i, "RUNNER")
			m:markActivity(i, 50)
		end
		for i = 1, nc do
			m:addParticipant(99 + i, "CATCHER")
			m:markActivity(99 + i, 50)
		end
		return m
	end
	local function ctx()
		return { utcDate = "2026-10-14", questConfig = Quests, ledgerSize = 60 }
	end

	-- ===== A: pure server logic =====
	case("A01", "Runner starts with Tier 1 egg", function()
		local m = setup(1, 1)
		local p = m:get(1)
		eq(p.role, "RUNNER")
		eq(p.currentCarriedTier, 1)
		eq(p.earnedRunnerTier, 1)
		eq(p.bestStolenTier, 1)
	end)

	case("A02", "Initial Catcher has insured Tier 1, no carried egg", function()
		local m = setup(2, 1)
		local c = m:get(100)
		eq(c.role, "CATCHER")
		eq(c.currentCarriedTier, nil)
		eq(c.initialHunter, true)
		eq(m:securedTier(c), 1)
		eq(m:catchersCount(), 1)
	end)

	case("A03", "Correct finish: +1 tier, SAFE, reward tier 2", function()
		local m = setup(1, 1)
		m:startWave(0)
		local ok, _, info = m:finishCrossing(1, 5)
		truthy(ok, "finish should succeed")
		eq(info.newTier, 2)
		eq(m:get(1).isSafeThisWave, true)
		eq(m:securedTier(m:get(1)), 2)
	end)

	case("A04", "Repeated finish in same wave gives nothing", function()
		local m = setup(1, 1)
		m:startWave(0)
		m:finishCrossing(1, 5)
		local shells = m:get(1).shells
		m:drainEvents()
		local ok, reason = m:finishCrossing(1, 6)
		eq(ok, false)
		eq(reason, "ALREADY_SAFE")
		eq(m:get(1).currentCarriedTier, 2)
		eq(m:get(1).shells, shells)
		for _, e in ipairs(m:drainEvents()) do
			truthy(e.name ~= "RunnerEvolved", "no second RunnerEvolved")
		end
	end)

	case("A05", "Wrong-direction finish zone does not count", function()
		eq(MatchLogic.isCorrectFinishZone(1, "A"), false)
		eq(MatchLogic.isCorrectFinishZone(1, "B"), true)
		eq(MatchLogic.isCorrectFinishZone(2, "A"), true)
		eq(MatchLogic.isCorrectFinishZone(2, "B"), false)
		eq(MatchLogic.isCorrectFinishZone(3, "B"), true)
	end)

	case("A06", "Clear waves 1 and 2 -> Tier 3", function()
		local m = setup(2, 1)
		m:startWave(0); m:finishCrossing(1, 5); m:finishCrossing(2, 5); m:endWave(10)
		m:startWave(14); m:finishCrossing(1, 20); m:finishCrossing(2, 20); m:endWave(25)
		eq(m:get(1).earnedRunnerTier, 3)
		eq(m:get(1).currentCarriedTier, 3)
	end)

	case("A07", "Tagged at Tier 3 in wave 3: converts, secures Tier 3", function()
		local m = setup(2, 1)
		m:startWave(0); m:finishCrossing(1, 5); m:finishCrossing(2, 6); m:endWave(10)
		m:startWave(14); m:finishCrossing(1, 20); m:finishCrossing(2, 21); m:endWave(25)
		m:startWave(29)
		local ok, _, info = m:capture(100, 1, 32)
		truthy(ok, "capture should succeed")
		local v = m:get(1)
		eq(v.role, "CAUGHT") -- out for the rest of the wave
		eq(v.currentCarriedTier, nil)
		eq(m:securedTier(v), 3)
		eq(info.stolenTier, 3)
	end)

	case("A07b", "Caught Runner sits out the rest of the wave, then is a Catcher", function()
		local m = setup(3, 1)
		m:startWave(0)
		truthy(m:capture(100, 1, 3))
		eq(m:get(1).role, "CAUGHT")
		eq(m:catchersCount(), 1) -- not hunting yet
		eq(m:runnersRemaining(), 2)
		local ok, reason = m:capture(1, 2, 5)
		eq(ok, false)
		eq(reason, "HUNTER_NOT_CATCHER")
		local ok2, reason2 = m:capture(100, 1, 6)
		eq(ok2, false)
		eq(reason2, "VICTIM_NOT_RUNNER")
		m:finishCrossing(2, 10); m:finishCrossing(3, 11)
		local res = m:endWave(30)
		eq(res.promoted[1], 1)
		eq(m:get(1).role, "CATCHER")
		eq(m:catchersCount(), 2)
		m:startWave(34)
		truthy(m:capture(1, 2, 40), "promoted Catcher tags in the next wave")
	end)

	case("A08", "Captured Runner tagged again is rejected", function()
		local m = setup(2, 2)
		m:startWave(0)
		truthy(m:capture(100, 1, 1))
		m:drainEvents()
		local ok, reason = m:capture(101, 1, 3)
		eq(ok, false)
		eq(reason, "VICTIM_NOT_RUNNER")
		eq(#m:drainEvents(), 0)
		eq(m:get(101).captureCount, 0)
	end)

	case("A09", "Catcher captures Tier 3: captor Tier 3, victim keeps Tier 3", function()
		local m = setup(2, 1)
		m:startWave(0); m:finishCrossing(1, 5); m:finishCrossing(2, 5); m:endWave(10)
		m:startWave(14); m:finishCrossing(1, 20); m:finishCrossing(2, 20); m:endWave(25)
		m:startWave(29)
		m:capture(100, 1, 33)
		eq(m:get(100).bestStolenTier, 3)
		eq(m:securedTier(m:get(1)), 3)
	end)

	case("A10", "No downgrade after stealing Tier 3 then Tier 1", function()
		local m = setup(2, 1)
		m:startWave(0)
		m:get(1).currentCarriedTier = 3 -- runner 1 carries Tier 3 (state injected for the case)
		m:capture(100, 1, 2)
		eq(m:get(100).bestStolenTier, 3)
		m:capture(100, 2, 3) -- runner 2 carries Tier 1
		eq(m:get(100).bestStolenTier, 3)
		eq(m:get(100).captureCount, 2)
		-- capture Shells follow the schedule: 10 then 8
		eq(m:get(100).shells, 18)
	end)

	case("A11", "Capturing a (contrived) Tier 4 Runner never credits Tier 4", function()
		local m = setup(1, 1)
		m:startWave(0)
		m:get(1).currentCarriedTier = 4 -- injected state
		m:capture(100, 1, 2)
		eq(m:get(100).bestStolenTier, 3)
		truthy(m:securedTier(m:get(100)) <= Tiers.CATCHER_TIER_CAP, "captor <= cap")
		eq(m:securedTier(m:get(1)), 4)
	end)

	case("A12", "3 clean crossings in a row: Level 4, still Runners, RUNNERS WIN", function()
		local m = setup(2, 1)
		for w = 1, 3 do
			m:startWave(w * 40)
			m:finishCrossing(1, w * 40 + 8)
			m:finishCrossing(2, w * 40 + 9)
			local res = m:endWave(w * 40 + 30)
			eq(res.nextAction, if w < 3 then "NEXT_WAVE" else "END")
		end
		eq(m.endReason, "CLEAN_STREAK")
		local r = m:computeResults(200)
		eq(m:get(1).role, "RUNNER")
		eq(r.perPlayer[1].securedTier, 4)
		eq(r.team, "RUNNERS")
		local s = m:settlementFor(1)
		eq(s.eggTier, 4)
	end)

	case("A13", "Timeout at Tier 3: becomes Catcher, keeps Tier 3, no thief credit", function()
		local m = setup(2, 1)
		m:startWave(0); m:finishCrossing(1, 5); m:finishCrossing(2, 5); m:endWave(10)
		m:startWave(14); m:finishCrossing(1, 18); m:finishCrossing(2, 18); m:endWave(25)
		m:startWave(29); m:finishCrossing(2, 33)
		local res = m:endWave(59)
		eq(res.timedOut[1], 1)
		local p = m:get(1)
		eq(p.role, "CATCHER")
		eq(p.conversionCause, "TIMEOUT")
		eq(m:securedTier(p), 3)
		eq(m:get(100).bestStolenTier, 1)
		eq(m:get(100).captureCount, 0)
	end)

	case("A14", "Initial Catcher with zero tags: insured Tier 1 only", function()
		local m = setup(2, 1)
		m:startWave(0); m:finishCrossing(1, 5); m:finishCrossing(2, 5); m:endWave(10)
		m:startWave(14); m:finishCrossing(1, 18); m:finishCrossing(2, 18); m:endWave(25)
		m:startWave(29); m:finishCrossing(1, 33); m:finishCrossing(2, 33); m:endWave(40)
		m:computeResults(50)
		local s = m:settlementFor(100)
		eq(s.eggTier, 1)
		eq(s.shells, Rewards.PARTICIPATION_SHELLS)
		eq(s.stats.captures, 0)
	end)

	case("A15", "Tier 1 converted Catcher steals Tier 3 later: one Tier 3 token", function()
		local m = setup(3, 1)
		m:startWave(0)
		m:capture(100, 2, 2) -- runner 2 caught at Tier 1
		m:finishCrossing(1, 5); m:finishCrossing(3, 5)
		m:endWave(10)
		m:startWave(14); m:finishCrossing(1, 18); m:finishCrossing(3, 18); m:endWave(25)
		m:startWave(29)
		local ok = m:capture(2, 1, 35) -- converted runner 2 steals Tier 3
		truthy(ok, "converted catcher capture")
		m:finishCrossing(3, 36)
		m:endWave(40)
		local r = m:computeResults(41)
		eq(r.perPlayer[2].securedTier, 3)
		eq(m:settlementFor(2).eggTier, 3)
		eq(r.perPlayer[2].source, "STOLE TIER 3")
	end)

	case("A16", "Two Catchers tag one Runner: exactly one capture", function()
		local m = setup(1, 2)
		m:startWave(0)
		local ok1 = m:capture(100, 1, 3)
		local ok2, reason2 = m:capture(101, 1, 3)
		eq(ok1, true)
		eq(ok2, false)
		eq(reason2, "VICTIM_NOT_RUNNER")
		eq(m:get(100).captureCount + m:get(101).captureCount, 1)
	end)

	case("A17", "Tag after SAFE committed is rejected", function()
		local m = setup(1, 1)
		m:startWave(0)
		m:finishCrossing(1, 4)
		local ok, reason = m:capture(100, 1, 4)
		eq(ok, false)
		eq(reason, "VICTIM_SAFE")
		eq(m:get(1).role, "RUNNER")
	end)

	case("A18", "Tier is never taken from callers (no tier parameter exists)", function()
		local m = setup(1, 1)
		m:startWave(0)
		-- extra junk arguments (as a hostile remote might send) are ignored
		local ok = m:capture(100, 1, 2, 4, "FinishWave=3")
		truthy(ok)
		eq(m:get(100).bestStolenTier, 1)
		local ok2, reason = m:finishCrossing(100, 3)
		eq(ok2, false)
		eq(reason, "NOT_RUNNER")
	end)

	case("A19", "All Runners caught mid-wave: ends early exactly once", function()
		local m = setup(2, 1)
		m:startWave(0)
		m:capture(100, 1, 2)
		m:capture(100, 2, 3)
		truthy(m:waveComplete(), "wave complete")
		local r1 = m:endWave(3)
		eq(r1.nextAction, "END")
		local r2 = m:endWave(4)
		eq(r2.ok, false)
		local ok = m:startWave(5)
		eq(ok, false)
	end)

	case("A20", "Several survivors: RUNNERS WIN, champion by final-wave time", function()
		local m = setup(3, 1)
		for w = 1, 3 do
			m:startWave(w * 40)
			m:finishCrossing(3, w * 40 + 9)
			m:finishCrossing(1, w * 40 + 7)
			m:finishCrossing(2, w * 40 + (w == 3 and 6 or 10))
			m:endWave(w * 40 + 30)
		end
		local r = m:computeResults(200)
		eq(r.team, "RUNNERS")
		eq(r.champion, 2)
		eq(r.topRunners[1].userId, 2)
		eq(r.topRunners[2].userId, 1)
		eq(r.topRunners[3].userId, 3)
	end)

	case("A21", "No survivors: CATCHERS WIN, Top Runner by longevity", function()
		local m = setup(3, 1)
		m:startWave(0)
		m:capture(100, 3, 2)
		m:finishCrossing(1, 5); m:finishCrossing(2, 6)
		m:endWave(10)
		m:startWave(14)
		m:capture(100, 1, 16)
		m:capture(100, 2, 20) -- caught later than runner 1
		m:endWave(20)
		local r = m:computeResults(25)
		eq(r.team, "CATCHERS")
		eq(r.topRunner, 2)
		eq(r.topRunners[2].userId, 1)
		eq(r.topRunners[3].userId, 3)
		eq(r.topThief, 100)
		eq(r.perPlayer[100].win, true)
	end)

	case("A22", "Nobody moves for a wave: timeout resolves the phase", function()
		local m = setup(2, 1)
		m:startWave(0)
		local res = m:endWave(30)
		eq(#res.timedOut, 2)
		eq(res.nextAction, "END")
		eq(m.phase, "ENDED")
	end)

	case("A23", "Duplicate participant / double init rejected", function()
		local m = setup(1, 1)
		local ok, reason = m:addParticipant(1, "RUNNER")
		eq(ok, false)
		eq(reason, "DUPLICATE")
		m:startWave(0)
		local ok2, reason2 = m:addParticipant(5, "RUNNER")
		eq(ok2, false)
		eq(reason2, "NOT_SETUP")
		local ok3 = m:startWave(1)
		eq(ok3, false)
	end)

	case("A24", "Disconnect during a wave: no stranded membership", function()
		local m = setup(2, 1)
		m:startWave(0)
		m:finishCrossing(1, 5)
		m:removeParticipant(2, 6)
		truthy(m:waveComplete(), "remaining runner is safe -> wave can end")
		local res = m:endWave(7)
		eq(res.nextAction, "NEXT_WAVE")
		eq(m:runnersRemaining(), 1)
		local r = m:computeResults(8)
		eq(r.perPlayer[2].eligible, false)
		local s = m:settlementFor(2)
		eq(s.eggTier, nil)
		eq(s.key, m.matchId .. ":partial")
	end)

	case("A-RANK", "Early-caught Tier 1 never ranks above late-caught Tier 3", function()
		local m = setup(2, 1)
		m:startWave(0)
		m:capture(100, 2, 1) -- Tier 1, early
		m:finishCrossing(1, 5)
		m:endWave(8)
		m:startWave(12); m:finishCrossing(1, 15); m:endWave(20)
		m:startWave(24); m:capture(100, 1, 30); m:endWave(30)
		local r = m:computeResults(31)
		eq(r.topRunners[1].userId, 1)
		eq(r.topRunners[2].userId, 2)
	end)

	case("A-ROLE", "Initial Catcher pick: volunteers first, new players shielded", function()
		local rng = newRandom(7)
		local c = MatchLogic.pickInitialCatchers({
			{ userId = 1, volunteer = false, isNewPlayer = true },
			{ userId = 2, volunteer = false, isNewPlayer = false, lastHunterAt = 50 },
			{ userId = 3, volunteer = false, isNewPlayer = false, lastHunterAt = 10 },
		}, 1, rng)
		eq(c[1], 3)
		local v = MatchLogic.pickInitialCatchers({
			{ userId = 1, volunteer = false, isNewPlayer = false },
			{ userId = 2, volunteer = true, isNewPlayer = false, lastHunterAt = 999 },
		}, 1, rng)
		eq(v[1], 2)
		local onlyNew = MatchLogic.pickInitialCatchers({ { userId = 9, volunteer = false, isNewPlayer = true } }, 1, rng)
		eq(onlyNew[1], 9)
	end)

	case("A-AFK", "Idle participant gets no egg and no participation Shells", function()
		local m = newMatch()
		m:addParticipant(1, "RUNNER"); m:addParticipant(100, "CATCHER")
		m:markActivity(100, 50)
		m:startWave(0)
		m:endWave(30)
		m:computeResults(31)
		local s = m:settlementFor(1)
		eq(s.eggTier, nil)
		eq(s.shells, 0)
	end)

	-- ===== B: persistence / economy (pure transforms) =====
	case("B01", "Settled Tier 3 adds exactly one Epic piece", function()
		local p = ProfileLogic.default()
		local ok = ProfileLogic.applySettlement(p, { key = "m1", matchId = "m1", eggTier = 3, material = "epic", gold = 20, stats = { matchesCompleted = 1 } }, ctx())
		truthy(ok)
		eq(p.materials.epic, 1)
		eq(p.gold, 20)
	end)

	case("B02", "Same matchId reprocessed: no extra reward", function()
		local p = ProfileLogic.default()
		local s = { key = "m1", matchId = "m1", eggTier = 3, material = "epic", gold = 20, stats = { matchesCompleted = 1, captures = 2 } }
		ProfileLogic.applySettlement(p, s, ctx())
		local ok, info = ProfileLogic.applySettlement(p, s, ctx())
		eq(ok, false)
		eq(info.reason, "DUPLICATE")
		eq(p.materials.epic, 1)
		eq(p.gold, 20)
		eq(p.stats.captures, 2)
	end)

	case("B03", "Tier 3 Runner converted then match ends: an Epic piece", function()
		local m = setup(2, 1, { economy = Econ })
		m:startWave(0); m:finishCrossing(1, 3); m:finishCrossing(2, 3); m:endWave(5)
		m:startWave(9); m:finishCrossing(1, 12); m:finishCrossing(2, 12); m:endWave(15)
		m:startWave(19); m:capture(100, 1, 22); m:finishCrossing(2, 25); m:endWave(30)
		m:computeResults(31)
		local p = ProfileLogic.default()
		ProfileLogic.applySettlement(p, m:settlementFor(1), ctx())
		eq(p.materials.epic, 1)
		eq(p.materials.common, 0)
	end)

	case("B04", "Level 4 survivor gets exactly one Epic piece (Crowned deferred)", function()
		local m = setup(2, 1, { economy = Econ })
		for w = 1, 3 do
			m:startWave(w * 40); m:finishCrossing(1, w * 40 + 5); m:finishCrossing(2, w * 40 + 6); m:endWave(w * 40 + 30)
		end
		m:computeResults(200)
		local p = ProfileLogic.default()
		ProfileLogic.applySettlement(p, m:settlementFor(1), ctx())
		ProfileLogic.applySettlement(p, m:settlementFor(1), ctx())
		eq(p.materials.epic, 1)
		eq(p.materials.crowned, 0)
		eq(p.stats.lifetimeBestTier, 4)
		eq(p.stats.wins, 1)
	end)

	case("B05", "Many captures: one piece at the capped tier", function()
		local m = setup(3, 1, { economy = Econ })
		m:startWave(0); m:finishCrossing(1, 2); m:finishCrossing(2, 2); m:finishCrossing(3, 2); m:endWave(4)
		m:startWave(8); m:finishCrossing(1, 9); m:finishCrossing(2, 9); m:finishCrossing(3, 9); m:endWave(12)
		m:startWave(16)
		m:capture(100, 1, 17); m:capture(100, 2, 18); m:capture(100, 3, 19)
		m:endWave(20)
		m:computeResults(21)
		local s = m:settlementFor(100)
		eq(s.eggTier, 3)
		local p = ProfileLogic.default()
		ProfileLogic.applySettlement(p, s, ctx())
		local total = 0
		for _, v in pairs(p.materials) do
			total += v
		end
		eq(total, 1)
		eq(p.materials.epic, 1)
	end)

	case("B06", "Disconnect mid-match: no piece, earned Gold only", function()
		local m = setup(2, 1, { economy = Econ })
		m:startWave(0); m:finishCrossing(1, 3)
		m:removeParticipant(1, 4)
		local s = m:settlementFor(1)
		eq(s.eggTier, nil)
		eq(s.gold, Econ.GOLD.PER_CROSSING)
		eq(s.stats.matchesCompleted, 0)
		local p = ProfileLogic.default()
		ProfileLogic.applySettlement(p, s, ctx())
		local total = 0
		for _, v in pairs(p.materials) do
			total += v
		end
		eq(total, 0)
		eq(p.gold, Econ.GOLD.PER_CROSSING)
	end)

	case("B08", "Old V1 profile migrates without wiping balances", function()
		local old = { coins = 340, eggs = { basic = 2, rare = 1 }, stats = { wins = 5 } }
		local p, changed = ProfileLogic.migrate(old)
		truthy(changed)
		eq(p.schemaVersion, 3)
		eq(p.gold, 340) -- V1 coins -> V2 shells -> V3 gold
		eq(p.materials.common, 2) -- V1 basic = Tier 1 = Common
		eq(p.materials.epic, 1) -- V1 rare = Tier 3 = Epic
		eq(p.stats.wins, 5)
		eq(p.stats.captures, 0)
		local q, changed2 = ProfileLogic.migrate(p)
		eq(changed2, false)
		eq(q.gold, 340)
		local weird = ProfileLogic.migrate({ schemaVersion = 3, gold = 0 / 0, futureField = "keep" })
		eq(weird.gold, 0)
		eq(weird.futureField, "keep")
	end)

	case("B09", "Capture Shells: +10, +8, then +4 capped at +10 total", function()
		local got = {}
		local later = 0
		for i = 1, 6 do
			local pay
			pay, later = Rewards.captureShells(i, later)
			table.insert(got, pay)
		end
		eq(table.concat(got, ","), "10,8,4,4,2,0")
	end)

	case("B11", "Daily quest claimed twice: second rejected", function()
		local p = ProfileLogic.default()
		ProfileLogic.ensureDaily(p, "2026-10-14", Quests)
		local id = p.dailyQuests.active[1]
		local q = Quests.get(id)
		p.dailyQuests.progress[id] = q.target
		local ok1, _, reward = ProfileLogic.claimQuest(p, id, ctx())
		local ok2, reason2 = ProfileLogic.claimQuest(p, id, ctx())
		eq(ok1, true)
		eq(reward, q.reward)
		eq(ok2, false)
		eq(reason2, "ALREADY_CLAIMED")
		eq(p.gold, q.reward)
	end)

	case("B12", "UTC day rollover resets quests once", function()
		local p = ProfileLogic.default()
		eq(ProfileLogic.ensureDaily(p, "2026-10-14", Quests), true)
		eq(ProfileLogic.ensureDaily(p, "2026-10-14", Quests), false)
		local id = p.dailyQuests.active[1]
		p.dailyQuests.progress[id] = 1
		eq(ProfileLogic.ensureDaily(p, "2026-10-15", Quests), true)
		eq(p.dailyQuests.utcDate, "2026-10-15")
		for _, qid in ipairs(p.dailyQuests.active) do
			eq(p.dailyQuests.progress[qid], 0)
		end
		eq(#p.dailyQuests.active, 2)
		eq(ProfileLogic.utcDate(1792022400), "2026-10-15") -- 2026-10-15 00:00 UTC
		eq(ProfileLogic.utcDate(1792022400 - 1), "2026-10-14")
	end)

	case("B13", "RequestQuestClaim spam is rate limited", function()
		local rl = RateLimiter.new({ RequestQuestClaim = { max = 4, window = 2 } })
		local allowed = 0
		for i = 1, 20 do
			if rl:allow(1, "RequestQuestClaim", 100 + i * 0.01) then
				allowed += 1
			end
		end
		eq(allowed, 4)
		truthy(rl:allow(1, "RequestQuestClaim", 103), "allowed again after the window")
	end)

	case("B14", "New player defaults", function()
		local p = ProfileLogic.migrate(nil)
		eq(p.schemaVersion, 3)
		eq(p.gold, 0)
		eq(p.gems, 0)
		eq(p.materials.common, 0)
		eq(#p.pets, 0) -- no starter pet
		eq(p.equippedPet, "")
		eq(p.stats.lifetimeBestTier, 1)
		eq(p.afkPreference, false)
		eq(next(p.petInventory), nil)
		eq(next(p.cosmeticInventory), nil)
	end)

	case("Q-PROG", "Quest progress comes from settlements and caps at target", function()
		local p = ProfileLogic.default()
		ProfileLogic.ensureDaily(p, "2026-10-14", Quests)
		ProfileLogic.applySettlement(p, { key = "a", matchId = "a", eggTier = 2, shells = 0, stats = {}, quest = { crossings = 5, captures = 5, matches = 5, securedTier = 3 } }, ctx())
		for _, id in ipairs(p.dailyQuests.active) do
			eq(p.dailyQuests.progress[id], Quests.get(id).target)
		end
	end)

	case("S01", "Studio solo test: lone Catcher plays every wave, lone Runner can time out and keep going", function()
		-- lone Catcher: no Runners, yet waves start, never auto-complete, and the match runs to the last wave
		local m = newMatch({ solo = true })
		m:addParticipant(1, "CATCHER")
		truthy(m.isTest, "solo is always a test match")
		for w = 1, m.maxCrossings do
			truthy(m:startWave(w * 40), "wave " .. w .. " starts")
			eq(m:waveComplete(), false)
			local res = m:endWave(w * 40 + 30)
			eq(res.nextAction, if w < m.maxCrossings then "NEXT_WAVE" else "END")
		end
		eq(m.endReason, "FINAL_WAVE")
		-- lone Runner: crossing completes the wave; timing out converts and the match carries on
		local r = newMatch({ solo = true })
		r:addParticipant(1, "RUNNER")
		truthy(r:startWave(0))
		truthy(r:finishCrossing(1, 5))
		eq(r:waveComplete(), true)
		eq(r:endWave(6).nextAction, "NEXT_WAVE")
		truthy(r:startWave(10))
		local res = r:endWave(40)
		eq(res.nextAction, "NEXT_WAVE")
		eq(r:get(1).role, "CATCHER")
		truthy(r:startWave(50), "wave 3 starts with no Runners")
		r:endWave(80)
		local results = r:computeResults(90)
		truthy(results ~= nil)
		-- normal matches are unchanged: no Runners left ends the match
		local n = setup(1, 1)
		n:startWave(0)
		eq(n:endWave(30).nextAction, "END")
	end)

	case("E01", "Last one standing: a crossing that starts with one Runner ends the match when they make it", function()
		local m = setup(3, 1)
		m:startWave(0)
		truthy(m:capture(100, 2, 2)); truthy(m:capture(100, 3, 3))
		m:finishCrossing(1, 6)
		-- runner 1 became the last one DURING this crossing: that's not the solo run yet
		eq(m.soloCrossingBy, nil)
		eq(m:endWave(10).nextAction, "NEXT_WAVE")
		truthy(m:startWave(14))
		eq(m.soloCrossingBy, 1)
		truthy(m:finishCrossing(1, 20))
		eq(m:waveComplete(), true)
		local res = m:endWave(21)
		eq(res.nextAction, "END")
		eq(m.endReason, "LAST_ONE_STANDING")
		local r = m:computeResults(22)
		eq(r.team, "RUNNERS")
		eq(r.champion, 1)
		eq(r.perPlayer[1].win, true)
		eq(r.perPlayer[1].survived, true)
		eq(r.perPlayer[1].source, "LAST ONE STANDING")
		eq(r.perPlayer[1].securedTier, 3)
		eq(m:settlementFor(1).stats.wins, 1)
	end)

	case("E02", "Last Runner caught on their solo crossing: the Catchers win", function()
		local m = setup(2, 1)
		m:startWave(0); m:capture(100, 2, 2); m:finishCrossing(1, 6); m:endWave(10)
		m:startWave(14)
		eq(m.soloCrossingBy, 1)
		truthy(m:capture(2, 1, 18), "the promoted Catcher gets the last Runner")
		local res = m:endWave(19)
		eq(res.nextAction, "END")
		eq(m.endReason, "ALL_RUNNERS_GONE")
		local r = m:computeResults(20)
		eq(r.team, "CATCHERS")
		eq(r.perPlayer[1].win, false)
		-- and timing out on the solo run is the same: no Runners left
		local t = setup(2, 1)
		t:startWave(0); t:capture(100, 2, 2); t:finishCrossing(1, 6); t:endWave(10)
		t:startWave(14)
		local tr = t:endWave(44)
		eq(tr.timedOut[1], 1)
		eq(tr.nextAction, "END")
		eq(t:computeResults(45).team, "CATCHERS")
	end)

	-- ===== GDD v0.4 economy =====
	local function econCtx()
		return { utcDate = "2026-10-15", questConfig = Quests, ledgerSize = 60 }
	end

	case("G01", "Gold and Gems per match follow the GDD formulas and caps", function()
		local g, parts = Econ.goldFor({ active = true, crossings = 3, captures = 0, win = true })
		eq(g, 25 + 36 + 15)
		eq(#parts, 3)
		eq(Econ.gemsFor({ active = true, crossings = 3, captures = 0, win = true }), 4)
		-- a winning Catcher with steals: played + first steal + victory
		eq((Econ.goldFor({ active = true, crossings = 0, captures = 4, win = true })), 25 + 10 + 15)
		eq(Econ.gemsFor({ active = true, crossings = 0, captures = 4, win = true }), 3)
		-- everything at once still caps (90 Gold / 5 Gems)
		eq((Econ.goldFor({ active = true, crossings = 3, captures = 2, win = true })), 86)
		eq((Econ.goldFor({ active = true, crossings = 9, captures = 2, win = true })), 90)
		eq(Econ.gemsFor({ active = true, crossings = 3, captures = 2, win = true }), 5)
		-- AFK presence earns nothing
		eq((Econ.goldFor({ active = false, crossings = 0, captures = 0, win = false })), 0)
		eq(Econ.gemsFor({ active = false, crossings = 0, captures = 0, win = false }), 0)
	end)

	case("G02", "One egg piece per match from the best result; none when idle or gone", function()
		local m = setup(3, 1, { economy = Econ })
		m:addParticipant(50, "RUNNER") -- never moves: not eligible
		m:startWave(0); m:finishCrossing(1, 5); m:finishCrossing(2, 5); m:finishCrossing(3, 5); m:endWave(10)
		m:startWave(14)
		truthy(m:capture(100, 1, 16)) -- runner 1 caught at Tier 2: Rare
		m:finishCrossing(2, 20); m:finishCrossing(3, 20)
		m:removeParticipant(3, 21) -- left mid-match
		m:endWave(30)
		m:startWave(34); m:finishCrossing(2, 40); m:endWave(41)
		local r = m:computeResults(42)
		eq(r.perPlayer[1].material, "rare")
		eq(r.perPlayer[2].material, "epic") -- survived all 3 (Level 4): Epic at launch
		eq(r.perPlayer[100].material, "rare") -- the Catcher stole a Tier 2
		eq(r.perPlayer[50].material, nil)
		eq(r.perPlayer[50].gold, 0)
		local s2 = m:settlementFor(2)
		eq(s2.gold, 25 + 36 + 15)
		eq(s2.gems, 4)
		eq(s2.material, "epic")
		local s3 = m:settlementFor(3)
		eq(s3.material, nil)
		eq(s3.gold, 24) -- two crossings were already earned
		eq(s3.key, m.matchId .. ":partial")
	end)

	case("G03", "V2 saves move Shells to Gold and egg tokens to pieces, once", function()
		local raw = ProfileLogic.default()
		raw.schemaVersion = 2
		raw.materials = nil
		raw.gold = nil
		raw.shells = 120
		raw.unhatchedEggsByTier = { ["1"] = 2, ["2"] = 1, ["3"] = 0, ["4"] = 1 }
		local p = ProfileLogic.migrate(raw)
		eq(p.gold, 120)
		eq(p.shells, 0)
		eq(p.materials.common, 2)
		eq(p.materials.rare, 1)
		eq(p.materials.epic, 1)
		eq(p.equippedPet, "")
		eq(p.firstCommonFree, true)
		local again = ProfileLogic.migrate(p)
		eq(again.gold, 120)
		eq(again.materials.common, 2)
	end)

	case("G04", "First Common pet: 2 pieces with a free family pick, then random 2 / chosen 3", function()
		local p = ProfileLogic.default()
		p.materials.common = 7
		local ctx = { econ = Econ, pickFamily = function() return "Scout" end }
		local ok, reason = ProfileLogic.hatch(p, "common", nil, ctx)
		eq(ok, false)
		eq(reason, "CHOOSE_FAMILY")
		eq(p.materials.common, 7)
		local ok2, _, pet = ProfileLogic.hatch(p, "common", "Brake", ctx)
		truthy(ok2)
		eq(p.materials.common, 5)
		eq(pet.family, "Brake")
		eq(pet.species, "Turtle")
		eq(p.equippedPet, pet.id) -- first pet equips itself
		local ok3, _, pet2 = ProfileLogic.hatch(p, "common", nil, ctx)
		truthy(ok3)
		eq(p.materials.common, 3)
		eq(pet2.family, "Scout")
		eq(p.equippedPet, pet.id) -- later pets don't steal the slot
		truthy(ProfileLogic.hatch(p, "common", "Decoy", ctx))
		eq(p.materials.common, 0) -- chosen family = one extra piece
		eq(#p.pets, 3)
		eq(p.stats.petsHatched, 3)
		local bad = ProfileLogic.hatch(p, "common", "Dash", ctx)
		eq(bad, false)
	end)

	case("G05", "Higher pieces fill lower recipes only when allowed; never upward", function()
		local p = ProfileLogic.default()
		p.firstCommonFree = false
		p.materials.common = 1
		p.materials.rare = 2
		local ctx = { econ = Econ, pickFamily = function() return "Decoy" end }
		local ok, reason, _, plan = ProfileLogic.hatch(p, "common", nil, ctx)
		eq(ok, false)
		eq(reason, "NEEDS_HIGHER")
		eq(plan.take.common, 1)
		eq(plan.take.rare, 1)
		ctx.allowHigher = true
		truthy(ProfileLogic.hatch(p, "common", nil, ctx))
		eq(p.materials.common, 0)
		eq(p.materials.rare, 1)
		-- Rare needs 3 Rare-or-better: Commons never count upward
		p.materials.common = 9
		local ok2, reason2 = ProfileLogic.hatch(p, "rare", nil, ctx)
		eq(ok2, false)
		eq(reason2, "NOT_ENOUGH")
		eq(p.materials.common, 9)
	end)

	case("G06", "Shop: prices, owned items, consumables and the egg case", function()
		local p = ProfileLogic.default()
		p.gold = 1000
		local ok, reason = ProfileLogic.buy(p, "case_frost", Econ)
		truthy(ok, reason)
		eq(p.gold, 100)
		eq(p.cosmetics.case, "case_frost")
		local again, why = ProfileLogic.buy(p, "case_frost", Econ)
		eq(again, false)
		eq(why, "OWNED")
		eq(p.gold, 100)
		truthy(ProfileLogic.buy(p, "trail_spark", Econ))
		truthy(ProfileLogic.buy(p, "trail_spark", Econ))
		eq(p.cosmetics.consumables.trail_spark, 2)
		eq(p.cosmetics.trailNext, "trail_spark")
		eq(p.gold, 20)
		local poor, why2 = ProfileLogic.buy(p, "trail_ember", Econ)
		eq(poor, false)
		eq(why2, "NOT_ENOUGH")
		truthy(ProfileLogic.consume(p, "trail_spark"))
		truthy(ProfileLogic.consume(p, "trail_spark"))
		eq(ProfileLogic.consume(p, "trail_spark"), false)
		eq(p.cosmetics.trailNext, "")
		-- Gem items spend Gems, never Gold
		p.gems = 149
		eq((ProfileLogic.buy(p, "trailp_rainbow", Econ)), false)
		p.gems = 150
		truthy(ProfileLogic.buy(p, "trailp_rainbow", Econ))
		eq(p.gems, 0)
		eq(p.gold, 20)
		eq((ProfileLogic.setCosmetic(p, "case", "case_sunset", Econ)), false)
	end)

	case("G07", "Purchased Gems are granted once per receipt", function()
		local p = ProfileLogic.default()
		truthy(ProfileLogic.grantPurchasedGems(p, "r1", 100, 50))
		eq((ProfileLogic.grantPurchasedGems(p, "r1", 100, 50)), false)
		eq(p.gems, 100)
		eq(p.stats.gemsPurchased, 100)
		eq(p.stats.gemsEarned, 0)
	end)

	case("G08", "Settlements add Gold, Gems and the piece exactly once", function()
		local p = ProfileLogic.default()
		local s = { key = "m1", matchId = "m1", gold = 76, gems = 4, material = "epic", eggTier = 4, stats = { wins = 1 }, quest = {} }
		truthy(ProfileLogic.applySettlement(p, s, econCtx()))
		eq((ProfileLogic.applySettlement(p, s, econCtx())), false)
		eq(p.gold, 76)
		eq(p.gems, 4)
		eq(p.materials.epic, 1)
		eq(p.stats.goldEarned, 76)
		eq(p.stats.gemsEarned, 4)
		local view = ProfileLogic.clientView(p, Quests)
		eq(view.gold, 76)
		eq(view.materials.epic, 1)
	end)

	case("E03", "Crossings keep coming: a capture resets the clean run; 3 clean in a row wins", function()
		local m = setup(4, 1, { economy = Econ })
		local t = 0
		local function wave(catch: number?)
			t += 40
			truthy(m:startWave(t), "wave starts")
			if catch then
				truthy(m:capture(100, catch, t + 2))
			end
			for id = 1, 4 do
				if m:get(id).role == "RUNNER" then
					m:finishCrossing(id, t + 8)
				end
			end
			return m:endWave(t + 30)
		end
		eq(wave().cleanStreak, 1)
		local w2 = wave(1)
		eq(w2.clean, false)
		eq(w2.cleanStreak, 0)
		eq(w2.nextAction, "NEXT_WAVE")
		eq(wave().cleanStreak, 1)
		local w4 = wave()
		eq(w4.cleanStreak, 2)
		eq(w4.nextAction, "NEXT_WAVE") -- 4 crossings in, the match goes on
		local w5 = wave()
		eq(w5.nextAction, "END")
		eq(m.endReason, "CLEAN_STREAK")
		eq(m.wave, 5)
		local r = m:computeResults(400)
		eq(r.team, "RUNNERS")
		eq(r.perPlayer[2].survived, true)
		eq(r.perPlayer[2].win, true)
		eq(r.perPlayer[2].securedTier, 4) -- levels top out at 4 however many crossings
		eq(r.perPlayer[2].crossings, 5)
		eq(r.perPlayer[1].survived, false)
	end)

	case("E04", "A Runner timing out spoils a clean crossing too", function()
		local m = setup(3, 1)
		m:startWave(0); m:finishCrossing(1, 5); m:finishCrossing(2, 5); m:finishCrossing(3, 5)
		eq(m:endWave(10).cleanStreak, 1)
		m:startWave(14); m:finishCrossing(1, 18); m:finishCrossing(2, 18) -- runner 3 never makes it
		local res = m:endWave(44)
		eq(res.timedOut[1], 3)
		eq(res.clean, false)
		eq(res.cleanStreak, 0)
		-- the rule can be switched to "only captures count"
		local n = setup(3, 1, { timeoutBreaksStreak = false })
		n:startWave(0); n:finishCrossing(1, 5); n:finishCrossing(2, 5)
		eq(n:endWave(30).clean, true)
	end)

	case("E05", "Safety cap: a stuck match still ends, survivors win", function()
		local m = setup(6, 1, { maxWaves = 3 })
		for w = 1, 3 do
			m:startWave(w * 40)
			truthy(m:capture(100, w, w * 40 + 2))
			for id = 1, 6 do
				if m:get(id).role == "RUNNER" then
					m:finishCrossing(id, w * 40 + 8)
				end
			end
			local res = m:endWave(w * 40 + 30)
			eq(res.nextAction, if w < 3 then "NEXT_WAVE" else "END")
		end
		eq(m.endReason, "SAFETY_CAP")
		eq(m:computeResults(200).team, "RUNNERS")
	end)

	case("CFG", "Tier policy validates (Catcher cap below survivor tier)", function()
		eq(#Tiers.validate(), 0)
		truthy(Tiers.CATCHER_TIER_CAP < Tiers.SURVIVOR_TIER_MAX)
		local days = {}
		for d = 1, 28 do
			local ids = Quests.forDate(string.format("2026-11-%02d", d))
			eq(#ids, 2)
			truthy(Quests.get(ids[1]).kind ~= Quests.get(ids[2]).kind, "two different quest kinds")
			days[ids[1] .. ids[2]] = true
		end
	end)

	return { passed = passed, failed = failed, lines = lines }
end
