-- EggLogic.spec (HOS-EGG-002): jest-lua syntax. Runs under Lune with tools/run_specs.luau (a describe/it/expect
-- shim, no Jest download: Hunter 17 Oct) and, if Jest is ever added, unchanged with JestGlobals.
return function(JestGlobals: any, EggLogic: any, EggConfig: any)
	local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

	local function near(a: number, b: number, eps: number?)
		expect(math.abs(a - b) <= (eps or 1e-9)).toBe(true)
	end

	describe("shard meter (lasts the match, no random chance)", function()
		it("adds 0.25 per juke and counts at most 2 jukes a crossing", function()
			local st = EggLogic.newCharge()
			expect(EggLogic.addCharge(st, "juke")).toBe(0.25)
			expect(EggLogic.addCharge(st, "juke")).toBe(0.25)
			expect(EggLogic.addCharge(st, "juke")).toBe(0)
			expect(st.charge).toBe(0.5)
		end)
		it("keeps its charge across crossings (only the juke count restarts)", function()
			local st = EggLogic.newCharge()
			EggLogic.addCharge(st, "juke")
			EggLogic.addCharge(st, "juke")
			EggLogic.newCrossing(st)
			expect(st.charge).toBe(0.5)
			expect(EggLogic.addCharge(st, "juke")).toBe(0.25)
			expect(st.charge).toBe(0.75)
		end)
		it("adds 0.5 for a revive and 2.0 for a Hero success, capped at 5.0", function()
			local st = EggLogic.newCharge()
			expect(EggLogic.addCharge(st, "revive")).toBe(0.5)
			expect(EggLogic.addCharge(st, "hero")).toBe(2)
			expect(st.charge).toBe(2.5)
			EggLogic.addCharge(st, "hero")
			expect(EggLogic.addCharge(st, "hero")).toBe(0.5)
			expect(st.charge).toBe(5)
			expect(EggLogic.addCharge(st, "revive")).toBe(0)
		end)
		it("fills x1.5 for new players (every source)", function()
			local st = EggLogic.newCharge()
			expect(EggLogic.addCharge(st, "juke", true)).toBe(0.375)
			expect(EggLogic.addCharge(st, "revive", true)).toBe(0.75)
			expect(EggLogic.addCharge(st, "hero", true)).toBe(3)
			expect(EggLogic.addCharge(EggLogic.newCharge(), "juke", false)).toBe(0.25)
		end)
		it("counts the first 10 h of match time as new", function()
			expect(EggLogic.isNewbie(0)).toBe(true)
			expect(EggLogic.isNewbie(nil)).toBe(true)
			expect(EggLogic.isNewbie(10 * 3600 - 1)).toBe(true)
			expect(EggLogic.isNewbie(10 * 3600)).toBe(false)
		end)
		it("ignores unknown sources", function()
			local st = EggLogic.newCharge()
			expect(EggLogic.addCharge(st, "catch")).toBe(0)
		end)
		it("has its marks at 2.0 (EPIC) and 5.0 (LEGENDARY)", function()
			expect(EggConfig.CHARGE.MARKS[1]).toBe(2)
			expect(EggConfig.CHARGE.MARKS[2]).toBe(5)
			expect(EggConfig.MARK_RARITY[1]).toBe("epic")
			expect(EggConfig.MARK_RARITY[2]).toBe("legendary")
			local st = EggLogic.newCharge()
			st.charge = 1.75
			expect(EggLogic.marksPassed(st)).toBe(0)
			expect(EggLogic.markReady(st)).toBe(false)
			st.charge = 2
			expect(EggLogic.marksPassed(st)).toBe(1)
			expect(EggLogic.markReady(st)).toBe(true)
			st.charge = 4.75
			expect(EggLogic.marksPassed(st)).toBe(1)
			st.charge = 5
			expect(EggLogic.marksPassed(st)).toBe(2)
		end)
	end)

	describe("the step at safety (marks, no roll)", function()
		local function at(charge: number)
			local st = EggLogic.newCharge()
			st.charge = charge
			return st
		end
		it("always turns Common into Rare, without spending a mark", function()
			local st = at(2)
			local to, m = EggLogic.safetyStep("common", st)
			expect(to).toBe("rare")
			expect(m).toBe(false)
			expect(st.used).toBe(0)
			expect(EggLogic.markReady(st)).toBe(true) -- kept for the next safety
		end)
		it("never steps without a passed mark (the same result every time)", function()
			for _ = 1, 50 do
				local to, m = EggLogic.safetyStep("rare", at(1.75))
				expect(to).toBe("rare")
				expect(m).toBe(false)
			end
		end)
		it("steps Rare to Epic at the first mark, once", function()
			local st = at(2)
			local to, m = EggLogic.safetyStep("rare", st)
			expect(to).toBe("epic")
			expect(m).toBe(true)
			expect(st.used).toBe(1)
			expect(st.charge).toBe(2) -- the meter never empties
			local to2, m2 = EggLogic.safetyStep("epic", st)
			expect(to2).toBe("epic")
			expect(m2).toBe(false)
		end)
		it("steps Epic to Legendary at the second mark, once", function()
			local st = at(2)
			EggLogic.safetyStep("rare", st)
			st.charge = 5
			local to, m = EggLogic.safetyStep("epic", st)
			expect(to).toBe("legendary")
			expect(m).toBe(true)
			expect(st.used).toBe(2)
			expect(EggLogic.nextMark(st)).toBe(nil)
			expect((EggLogic.safetyStep("legendary", st))).toBe("legendary")
		end)
		it("takes one step per safety when both marks are passed at once", function()
			local st = at(5)
			expect((EggLogic.safetyStep("rare", st))).toBe("epic")
			expect((EggLogic.safetyStep("epic", st))).toBe("legendary")
			expect(st.used).toBe(2)
		end)
		it("names the next mark for the HUD", function()
			local st = at(0)
			expect(EggLogic.nextMark(st)).toBe(1)
			st.charge = 2
			EggLogic.safetyStep("rare", st)
			expect(EggLogic.nextMark(st)).toBe(2)
			expect(EggLogic.markReady(st)).toBe(false)
		end)
		it("a new player's meter reaches the marks sooner (x1.5)", function()
			local slow, fast = EggLogic.newCharge(), EggLogic.newCharge()
			for _ = 1, 3 do
				EggLogic.addCharge(slow, "revive")
				EggLogic.addCharge(fast, "revive", true)
			end
			expect(EggLogic.markReady(slow)).toBe(false) -- 1.5
			expect(EggLogic.markReady(fast)).toBe(true) -- 2.25
		end)
	end)

	describe("snatch cap (+1)", function()
		it("caps the starting Catcher at Epic", function()
			expect(EggLogic.snatchCap(nil)).toBe("epic")
			expect(EggLogic.creditSnatch("legendary", EggLogic.snatchCap(nil))).toBe("epic")
		end)
		it("allows one rarity above the egg held when caught", function()
			expect(EggLogic.snatchCap("common")).toBe("rare")
			expect(EggLogic.snatchCap("rare")).toBe("epic")
			expect(EggLogic.snatchCap("epic")).toBe("legendary")
			expect(EggLogic.snatchCap("legendary")).toBe("legendary")
			expect(EggLogic.creditSnatch("epic", "rare")).toBe("rare")
			expect(EggLogic.creditSnatch("rare", "epic")).toBe("rare")
		end)
		it("keeps only the best snatch", function()
			expect(EggLogic.bestOf(nil, "rare")).toBe("rare")
			expect(EggLogic.bestOf("epic", "rare")).toBe("epic")
			expect(EggLogic.bestOf("rare", "legendary")).toBe("legendary")
		end)
	end)

	describe("end shard", function()
		it("pays a survivor the egg they hold", function()
			expect(EggLogic.shardFor({ eligible = true, survived = true, held = "epic", snatched = "rare" })).toBe("epic")
		end)
		it("pays a Catcher (caught or timed out) only their best snatch", function()
			expect(EggLogic.shardFor({ eligible = true, survived = false, held = "epic", snatched = "rare" })).toBe("rare")
			expect(EggLogic.shardFor({ eligible = true, survived = false, held = "epic" })).toBeNil()
		end)
		it("pays nothing to an ineligible player", function()
			expect(EggLogic.shardFor({ eligible = false, survived = true, held = "rare" })).toBeNil()
		end)
	end)

	describe("incubator", function()
		it("weights shards 0.5 / 1 / 2 / 8", function()
			local inc = EggLogic.newIncubator()
			expect(EggLogic.addShard(inc, "common")).toBe(0.5)
			expect(EggLogic.addShard(inc, "rare")).toBe(1)
			expect(EggLogic.addShard(inc, "epic")).toBe(2)
			expect(EggLogic.addShard(inc, "legendary")).toBe(8)
			expect(inc.fill).toBe(11.5)
			expect(inc.shards.epic).toBe(1)
			expect(EggLogic.addShard(inc, "crowned")).toBe(0)
		end)
		it("needs 18, or 22.5 when focused (and the requirement follows the focus)", function()
			local inc = EggLogic.newIncubator()
			expect(EggLogic.fillNeeded(inc)).toBe(18)
			inc.fill = 18
			expect(EggLogic.isReady(inc)).toBe(true)
			inc.focus = "Decoy"
			expect(EggLogic.fillNeeded(inc)).toBe(22.5)
			expect(EggLogic.isReady(inc)).toBe(false)
		end)
		it("shows the 100% odds 80 / 16 / 4 until the egg is past full", function()
			local inc = EggLogic.newIncubator()
			for _, f in ipairs({ 0, 9, 18 }) do
				inc.fill = f
				local o = EggLogic.incubatorOdds(inc, true)
				near(o.rare, 0.80)
				near(o.epic, 0.16)
				near(o.legendary, 0.04)
			end
		end)
		it("raises the odds with overfill: 150% 72 / 22 / 6, 200% 64 / 28 / 8, linear between", function()
			local inc = EggLogic.newIncubator()
			inc.fill = 27
			local o = EggLogic.incubatorOdds(inc, true)
			near(o.rare, 0.72)
			near(o.epic, 0.22)
			near(o.legendary, 0.06)
			inc.fill = 36
			o = EggLogic.incubatorOdds(inc, true)
			near(o.rare, 0.64)
			near(o.epic, 0.28)
			near(o.legendary, 0.08)
			inc.fill = 22.5 -- 125%: halfway from 100% to 150%
			o = EggLogic.incubatorOdds(inc, true)
			near(o.rare, 0.76)
			near(o.epic, 0.19)
			near(o.legendary, 0.05)
		end)
		it("applies the Lucky Egg pass (Epic and Legendary x1.5, Rare the rest) at 100 / 150 / 200%", function()
			local want = { -- fill -> without, with the pass
				[18] = { { 0.80, 0.16, 0.04 }, { 0.70, 0.24, 0.06 } },
				[27] = { { 0.72, 0.22, 0.06 }, { 0.58, 0.33, 0.09 } },
				[36] = { { 0.64, 0.28, 0.08 }, { 0.46, 0.42, 0.12 } },
			}
			local inc = EggLogic.newIncubator()
			for fill, w in pairs(want) do
				inc.fill = fill
				for i, lucky in ipairs({ false, true }) do
					local o = EggLogic.applyLuck(EggLogic.incubatorOdds(inc, true), lucky)
					near(o.rare, w[i][1], 1e-9)
					near(o.epic, w[i][2], 1e-9)
					near(o.legendary, w[i][3], 1e-9)
				end
			end
		end)
		it("keeps the pass's odds summing to 1 with Legendary folded into Epic", function()
			local inc = EggLogic.newIncubator()
			inc.fill = 36
			local o = EggLogic.applyLuck(EggLogic.incubatorOdds(inc, false), true)
			expect(o.legendary).toBe(0)
			near(o.epic, (0.28 + 0.08) * 1.5)
			near(o.rare + o.epic, 1)
		end)
		it("multiplies Epic and Legendary by the boost tier (x2 / x3 / x4), Legendary capped at 20%, at 100% and 200%", function()
			local want = { -- [fill][lucky][tier] = { rare, epic, legendary }
				[18] = {
					[false] = { [0] = { 0.80, 0.16, 0.04 }, { 0.60, 0.32, 0.08 }, { 0.40, 0.48, 0.12 }, { 0.20, 0.64, 0.16 } },
					[true] = { [0] = { 0.70, 0.24, 0.06 }, { 0.40, 0.48, 0.12 }, { 0.10, 0.72, 0.18 }, { 0.00, 0.80, 0.20 } },
				},
				[36] = {
					[false] = { [0] = { 0.64, 0.28, 0.08 }, { 0.28, 0.56, 0.16 }, { 0.00, 0.80, 0.20 }, { 0.00, 0.80, 0.20 } },
					[true] = { [0] = { 0.46, 0.42, 0.12 }, { 0.00, 0.80, 0.20 }, { 0.00, 0.80, 0.20 }, { 0.00, 0.80, 0.20 } },
				},
			}
			for fill, byLuck in pairs(want) do
				for lucky, byTier in pairs(byLuck) do
					for tier = 0, 3 do
						local inc = EggLogic.newIncubator()
						inc.fill = fill
						inc.boost = tier
						local o = EggLogic.hatchOdds(inc, true, lucky)
						local w = byTier[tier]
						near(o.rare, w[1], 1e-9)
						near(o.epic, w[2], 1e-9)
						near(o.legendary, w[3], 1e-9)
						near(o.rare + o.epic + o.legendary, 1, 1e-9)
					end
				end
			end
		end)
		it("grants a bought boost once per purchase id, never lowers it, and spends it at hatch", function()
			local inc = EggLogic.newIncubator()
			expect(EggLogic.grantBoost(inc, 1, "p1")).toBe(true)
			expect(inc.boost).toBe(1)
			expect(EggLogic.grantBoost(inc, 1, "p1")).toBe(false) -- Roblox retried the same receipt
			expect(EggLogic.grantBoost(inc, 2, "p2")).toBe(true)
			expect(inc.boost).toBe(2)
			EggLogic.grantBoost(inc, 1, "p3") -- an old x2 receipt landing late
			expect(inc.boost).toBe(2)
			inc.fill = 18
			EggLogic.consumeHatch(inc)
			expect(inc.boost).toBe(0)
			expect(#inc.boostReceipts).toBe(3) -- kept: a late retry still can't grant twice
		end)
		it("lets shard rarity set only the fill, never the odds", function()
			local inc = EggLogic.newIncubator()
			inc.fill = 18
			local before = EggLogic.incubatorOdds(inc, true)
			inc.shards.epic = 20
			inc.shards.legendary = 5
			local after = EggLogic.incubatorOdds(inc, true)
			near(after.epic, before.epic)
			near(after.legendary, before.legendary)
		end)
		it("holds up to 200% (36); fill past that waits for the next egg", function()
			local inc = EggLogic.newIncubator()
			inc.fill = 30
			expect(EggLogic.addShard(inc, "legendary")).toBe(8)
			expect(inc.fill).toBe(36)
			expect(inc.carry).toBe(2)
			EggLogic.addShard(inc, "rare")
			expect(inc.fill).toBe(36)
			expect(inc.carry).toBe(3)
		end)
		it("reads a focused egg's odds after the 4.5 focus cost", function()
			local inc = EggLogic.newIncubator()
			inc.focus = "Decoy"
			inc.fill = 22.5 -- just ready: 100% odds after the cost
			expect(EggLogic.isReady(inc)).toBe(true)
			near(EggLogic.incubatorOdds(inc, true).epic, 0.16)
			inc.fill = 27 -- 125% after the cost
			near(EggLogic.incubatorOdds(inc, true).epic, 0.19)
			inc.fill = 36 -- 175% after the cost
			near(EggLogic.incubatorOdds(inc, true).epic, 0.25)
		end)
		it("folds Legendary into Epic while no Legendary pet exists (Q1)", function()
			local inc = EggLogic.newIncubator()
			inc.fill = 18
			local o = EggLogic.incubatorOdds(inc, false)
			expect(o.legendary).toBe(0)
			near(o.epic, 0.16 + 0.04)
			near(o.rare + o.epic, 1)
			expect(EggLogic.hatchRoll(o, 0)).toBe("epic")
		end)
		it("rolls the hatch from the shown odds", function()
			local o = { rare = 0.8, epic = 0.16, legendary = 0.04 }
			expect(EggLogic.hatchRoll(o, 0.01)).toBe("legendary")
			expect(EggLogic.hatchRoll(o, 0.1)).toBe("epic")
			expect(EggLogic.hatchRoll(o, 0.5)).toBe("rare")
		end)
		it("spends the whole egg at hatch; the next egg starts from what waited past the cap", function()
			local inc = EggLogic.newIncubator()
			inc.fill = 36
			inc.carry = 3
			inc.shards.epic = 3
			inc.shards.legendary = 1
			inc.focus = "Invisibility"
			expect(EggLogic.consumeHatch(inc)).toBe(36)
			expect(inc.fill).toBe(3)
			expect(inc.carry).toBe(0)
			expect(inc.shards.epic).toBe(0)
			expect(inc.shards.legendary).toBe(0)
			expect(inc.hatched).toBe(1)
			expect(inc.focus).toBe("Invisibility")
		end)
		it("sanitizes a damaged save", function()
			local inc = EggLogic.sanitize({ fill = 0 / 0, carry = -1, shards = { epic = -2, rare = "x" }, focus = "Scout", hatched = 2.7 })
			expect(inc.fill).toBe(0)
			expect(inc.carry).toBe(0)
			expect(inc.shards.epic).toBe(0)
			expect(inc.shards.rare).toBe(0)
			expect(inc.focus).toBe("Any")
			expect(inc.hatched).toBe(2)
			expect(EggLogic.sanitize(nil).focus).toBe("Any")
		end)
	end)

	describe("family and species", function()
		it("uses the focus when it has a pet of that rarity, else nothing", function()
			expect(EggLogic.pickFamily("Decoy", { "Decoy", "Invisibility" }, 0.9)).toBe("Decoy")
			expect(EggLogic.pickFamily("Rift", { "Decoy", "Invisibility" }, 0.9)).toBeNil()
		end)
		it("picks Any from the open families only", function()
			expect(EggLogic.pickFamily("Any", { "Decoy", "Invisibility" }, 0)).toBe("Decoy")
			expect(EggLogic.pickFamily("Any", { "Decoy", "Invisibility" }, 0.99)).toBe("Invisibility")
			expect(EggLogic.pickFamily("Any", {}, 0.5)).toBeNil()
		end)
		it("gives an unowned species first", function()
			local sp, dup = EggLogic.pickSpecies({ "Crow", "Raven" }, { Crow = true }, 0.99)
			expect(sp).toBe("Raven")
			expect(dup).toBe(false)
		end)
		it("gives a duplicate when every species is owned", function()
			local sp, dup = EggLogic.pickSpecies({ "Crow" }, { Crow = true }, 0.5)
			expect(sp).toBe("Crow")
			expect(dup).toBe(true)
			expect((EggLogic.pickSpecies({}, {}, 0.5))).toBeNil()
		end)
	end)

	describe("migration of old pieces", function()
		it("converts V3 pieces at the shard weights and counts Epic as shards", function()
			local inc = EggLogic.newIncubator()
			local add = EggLogic.migratePieces(inc, { common = 4, rare = 3, epic = 2, crowned = 0 })
			expect(add).toBe(4 * 0.5 + 3 + 2 * 2)
			expect(inc.fill).toBe(9)
			expect(inc.shards.epic).toBe(2)
			expect(inc.shards.legendary).toBe(0)
		end)
		it("treats crowned / legendary pieces as Legendary", function()
			local inc = EggLogic.newIncubator()
			EggLogic.migratePieces(inc, { crowned = 1, legendary = 1 })
			expect(inc.fill).toBe(16)
			expect(inc.shards.legendary).toBe(2)
		end)
		it("ignores junk", function()
			local inc = EggLogic.newIncubator()
			expect(EggLogic.migratePieces(inc, { common = -3, rare = 0 / 0, epic = "2" })).toBe(0)
			expect(EggLogic.migratePieces(inc, nil)).toBe(0)
		end)
	end)

	describe("levels", function()
		it("maps rarities to the TierConfig look levels and back", function()
			expect(EggLogic.levelFor("legendary")).toBe(7)
			expect(EggLogic.rarityForLevel(1)).toBe("common")
			expect(EggLogic.rarityForLevel(4)).toBe("rare")
			expect(EggLogic.rarityForLevel(5)).toBe("epic")
			expect(EggLogic.rarityForLevel(12)).toBe("legendary")
			expect(EggLogic.rarityForLevel(nil)).toBe("common")
		end)
	end)
end
