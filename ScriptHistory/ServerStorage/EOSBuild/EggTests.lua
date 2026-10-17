--!nocheck
-- EggTests (HOS-EGG-002): the egg plan's tests in Studio edit mode (no playtest):
--   require(game.ServerStorage.EOSBuild.EggTests)()  -> { passed, failed, lines }
-- Runs the jest-lua-syntax specs (children EggLogicSpec, ProfileIncubatorSpec; the same files run under Lune on
-- the PC with docs/HOS-EGG-002/src/run_specs.luau) through a small describe/it/expect shim, then the real
-- ProfileLogic on V1 / V2 / V3 profile shapes with the plan on, then LogicTests with the plan OFF (the old
-- pieces path must keep working as the rollback).

return function()
	local RS = game:GetService("ReplicatedStorage")
	local SSS = game:GetService("ServerScriptService")
	local Shared = RS.EOS.Shared
	local EggConfig = require(Shared.EggConfig)
	local EggLogic = require(Shared.EggLogic)
	local IncubatorLogic = require(SSS.EOS.Core.IncubatorLogic)
	local ProfileLogic = require(SSS.EOS.Core.ProfileLogic)
	local EconomyConfig = require(Shared.EconomyConfig)

	local lines, passed, failed = {}, 0, 0
	local path = {}
	local function fmt(v)
		return if type(v) == "string" then string.format("%q", v) else tostring(v)
	end
	local function expect(received)
		local function check(ok, msg)
			if not ok then
				error(msg, 3)
			end
		end
		local m = {}
		function m.toBe(expected)
			check(received == expected, ("expected %s, got %s"):format(fmt(expected), fmt(received)))
		end
		m.toEqual = m.toBe
		function m.toBeNil()
			check(received == nil, ("expected nil, got %s"):format(fmt(received)))
		end
		m.never = {
			toBe = function(expected)
				check(received ~= expected, ("expected not %s"):format(fmt(expected)))
			end,
			toBeNil = function()
				check(received ~= nil, "expected a value, got nil")
			end,
		}
		return m
	end
	local function describe(name, fn)
		table.insert(path, name)
		fn()
		table.remove(path)
	end
	local function it(name, fn)
		local ok, err = pcall(fn)
		local full = table.concat(path, " > ") .. " > " .. name
		if ok then
			passed += 1
			table.insert(lines, "PASS " .. full)
		else
			failed += 1
			table.insert(lines, "FAIL " .. full .. " :: " .. tostring(err))
		end
	end
	local J = { describe = describe, it = it, test = it, expect = expect }

	local wasEnabled = EggConfig.ENABLED
	EggConfig.ENABLED = true
	require(script.EggLogicSpec)(J, EggLogic, EggConfig)
	require(script.ProfileIncubatorSpec)(J, EggLogic, EggConfig, IncubatorLogic)

	-- the real ProfileLogic with the plan on
	local ctx = { utcDate = "2026-10-17", questConfig = require(Shared.QuestConfig), ledgerSize = 50, economy = EconomyConfig }
	describe("ProfileLogic with the egg plan on", function()
		it("migrates a V1 profile (coins, eggs by name) into incubator fill once", function()
			local p = ProfileLogic.migrate({ schemaVersion = 1, coins = 40, eggs = { basic = 2, rare = 1 } })
			-- V1 basic = Tier 1 = Common piece, V1 rare = Tier 3 = Epic piece -> 2 x 0.5 + 1 x 2
			expect(p.incubator.fill).toBe(3)
			expect(p.incubator.shards.epic).toBe(1)
			expect(p.materials.common).toBe(0)
			expect(p.gold).toBe(40)
			expect(p.incubatorV1).toBe(true)
			local again = ProfileLogic.migrate(p)
			expect(again.incubator.fill).toBe(3)
		end)
		it("migrates a V2 profile (egg tokens) through pieces into fill", function()
			local p = ProfileLogic.migrate({ schemaVersion = 2, shells = 10, unhatchedEggsByTier = { ["1"] = 2, ["2"] = 1, ["3"] = 0, ["4"] = 1 } })
			expect(p.incubator.fill).toBe(2 * 0.5 + 1 + 2)
			expect(p.incubator.shards.epic).toBe(1)
			expect(p.unhatchedEggsByTier["4"]).toBe(0)
		end)
		it("migrates a V3 profile with pieces; 30+ is ready with the overflow kept", function()
			local raw = ProfileLogic.default()
			raw.materials = { common = 6, rare = 12, epic = 9, crowned = 0 }
			local p = ProfileLogic.migrate(raw)
			expect(p.incubator.fill).toBe(33)
			expect(EggLogic.isReady(p.incubator)).toBe(true)
			expect(p.incubator.shards.epic).toBe(9)
			expect(p.stats.secondsPlayed).toBe(0)
		end)
		it("leaves pets, mutation levels and firstCommonFree alone", function()
			local raw = ProfileLogic.default()
			raw.pets = { { id = "p1", family = "Decoy", rarity = "rare", species = "Crow", n = 1, level = 2 } }
			raw.nextPetId = 2
			raw.equippedPet = "p1"
			raw.firstCommonFree = false
			raw.materials.rare = 3
			local p = ProfileLogic.migrate(raw)
			expect(#p.pets).toBe(1)
			expect(p.pets[1].level).toBe(2)
			expect(p.equippedPet).toBe("p1")
			expect(p.firstCommonFree).toBe(false)
			expect(p.incubator.fill).toBe(3)
		end)
		it("settles a shard and match time exactly once", function()
			local p = ProfileLogic.migrate(ProfileLogic.default())
			local s = { key = "m1", matchId = "m1", shard = "epic", seconds = 240, gold = 30, stats = {}, quest = { crossings = 0, captures = 0, matches = 1, securedTier = 0 } }
			local ok, out = ProfileLogic.applySettlement(p, s, ctx)
			expect(ok).toBe(true)
			expect(out.shard).toBe("epic")
			expect(p.incubator.fill).toBe(2)
			expect(p.stats.secondsPlayed).toBe(240)
			local ok2 = ProfileLogic.applySettlement(p, s, ctx)
			expect(ok2).toBe(false)
			expect(p.incubator.fill).toBe(2)
			expect(ProfileLogic.clientView(p, ctx.questConfig).incubator.fill).toBe(2)
		end)
		it("command-bar check: migrate, add shards, focus, hatch with the live EconomyConfig", function()
			local p = ProfileLogic.migrate(ProfileLogic.default())
			for i = 1, 8 do
				ProfileLogic.applySettlement(p, { key = "k" .. i, matchId = "k" .. i, shard = "epic", seconds = 200, stats = {}, quest = {} }, ctx)
			end
			for i = 9, 9 do
				ProfileLogic.applySettlement(p, { key = "k" .. i, matchId = "k" .. i, shard = "rare", seconds = 200, stats = {}, quest = {} }, ctx)
			end
			expect(p.incubator.fill).toBe(17)
			expect(EggLogic.isReady(p.incubator)).toBe(false)
			ProfileLogic.applySettlement(p, { key = "k10", matchId = "k10", shard = "epic", seconds = 200, stats = {}, quest = {} }, ctx)
			expect(EggLogic.isReady(p.incubator)).toBe(true)
			local odds = IncubatorLogic.odds(p, EconomyConfig)
			-- overfill: 19 / 18 = 105.6% -> Epic 16.67% + Legendary 4.22% (folded into Epic while no Legendary pet for Any)
			expect(math.abs(odds.epic + odds.legendary - (0.20 + 0.08 / 9)) < 1e-9).toBe(true)
			expect(odds.legendary == 0 or math.abs(odds.legendary - (0.04 + 0.02 / 9)) < 1e-9).toBe(true)
			-- a family's chip is open only with a Rare and an Epic pet in the live data (it changes as pets land)
			for _, fam in { "Guardian", "Tempest", "Rift" } do
				local open = IncubatorLogic.focusOpen(EconomyConfig, fam)
				expect(IncubatorLogic.setFocus(p, fam, EconomyConfig)).toBe(open)
				IncubatorLogic.setFocus(p, "Any", EconomyConfig)
			end
			expect(IncubatorLogic.setFocus(p, "Decoy", EconomyConfig)).toBe(true)
			expect(EggLogic.isReady(p.incubator)).toBe(false) -- 19 < 22.5 once focused
			IncubatorLogic.setFocus(p, "Any", EconomyConfig)
			local ok, why, pet, info = IncubatorLogic.hatch(p, EconomyConfig, { rarity = 0.1, family = 0.9, species = 0 })
			expect(ok).toBe(true)
			expect(why).toBeNil()
			expect(pet.rarity).toBe("epic")
			-- which family Any picks depends on the live pet data (it changes as pets land): any family with an Epic pet
			expect(table.find(EggConfig.FAMILIES, pet.family) ~= nil).toBe(true)
			expect(type(pet.species) == "string" and pet.species ~= "").toBe(true)
			expect(info.fillUsed).toBe(19) -- the whole egg
			expect(info.fillAtHatch).toBe(19)
			expect(p.incubator.fill).toBe(0)
			expect(p.incubator.shards.epic).toBe(0)
		end)
	end)
	EggConfig.ENABLED = wasEnabled

	-- the rollback path: LogicTests with the plan off (E03 is a known failure from the round-cap work, not this ticket)
	local okL, res = pcall(function()
		EggConfig.ENABLED = false
		local deps = {
			MatchLogic = require(SSS.EOS.Core.MatchLogic), ProfileLogic = ProfileLogic, TierConfig = require(Shared.TierConfig),
			RewardConfig = require(Shared.RewardConfig), QuestConfig = require(Shared.QuestConfig), RateLimiter = require(SSS.EOS.Core.RateLimiter),
			EconomyConfig = EconomyConfig, newRandom = function(seed) return Random.new(seed) end,
		}
		return require(game.ServerStorage.EOSBuild.LogicTests)(deps)
	end)
	EggConfig.ENABLED = wasEnabled
	if okL then
		table.insert(lines, ("LogicTests (plan off): %d passed, %d failed"):format(res.passed, res.failed))
		for _, l in ipairs(res.lines) do
			if l:find("^FAIL") then
				table.insert(lines, "  " .. l)
			end
		end
	else
		table.insert(lines, "LogicTests ERROR " .. tostring(res))
	end
	return { passed = passed, failed = failed, lines = lines }
end
