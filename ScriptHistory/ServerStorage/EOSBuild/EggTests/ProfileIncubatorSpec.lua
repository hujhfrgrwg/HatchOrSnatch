-- ProfileIncubator.spec (HOS-EGG-002): IncubatorLogic against profile tables. jest-lua syntax; runs under Lune
-- (run_specs.luau) and in Studio (ServerStorage.EOSBuild.EggTests, which also runs the real ProfileLogic.migrate
-- on V1 / V2 / V3 shapes).
return function(JestGlobals: any, EggLogic: any, EggConfig: any, IncubatorLogic: any?)
	local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
	local Inc = IncubatorLogic
	if not Inc then
		Inc = require("./IncubatorLogic")
		Inc.setEggLogic(EggLogic)
	end

	-- the live EconomyConfig shape (17 Oct): only Decoy and Invisibility hatch; no Legendary species anywhere
	local econ = {
		LAUNCH_FAMILIES = { "Decoy", "Invisibility" },
		FAMILIES = {
			Decoy = { species = { common = "Mouse", rare = "Crow", epic = "Kitsune" } },
			Invisibility = { species = { common = "Prism Chameleon", rare = "Grim Ghost", epic = "Mirage Manta" } },
		},
	}
	local econLegend = {
		LAUNCH_FAMILIES = { "Decoy", "Invisibility" },
		FAMILIES = {
			Decoy = { species = { common = "Mouse", rare = "Crow", epic = "Kitsune", legendary = "Phoenix" } },
			Invisibility = { species = { common = "Prism Chameleon", rare = "Grim Ghost", epic = "Mirage Manta" } },
		},
	}

	local function profile(materials: any?): any
		return {
			materials = materials or { common = 0, rare = 0, epic = 0, crowned = 0 },
			pets = {},
			nextPetId = 1,
			equippedPet = "",
			firstCommonFree = true,
			stats = { petsHatched = 0 },
		}
	end

	describe("incubator: ensure / migration", function()
		it("adds an empty incubator and converts pieces once", function()
			local p = profile({ common = 4, rare = 3, epic = 2, crowned = 0 })
			expect(Inc.migrate(p)).toBe(true)
			expect(p.incubator.fill).toBe(9)
			expect(p.incubator.shards.epic).toBe(2)
			expect(p.materials.epic).toBe(0)
			expect(p.incubatorV1).toBe(true)
			expect(p.stats.secondsPlayed).toBe(0)
			-- idempotent: pieces given again later are not converted again
			p.materials.rare = 5
			expect(Inc.migrate(p)).toBe(false)
			expect(p.incubator.fill).toBe(9)
		end)
		it("leaves a migrated fill of 18+ ready to hatch; the hatch spends the whole egg", function()
			local p = profile({ common = 0, rare = 10, epic = 12, crowned = 0 })
			Inc.migrate(p)
			expect(p.incubator.fill).toBe(34)
			expect(EggLogic.isReady(p.incubator)).toBe(true)
			local ok = Inc.hatch(p, econ, { rarity = 0.99, family = 0, species = 0 })
			expect(ok).toBe(true)
			expect(p.incubator.fill).toBe(0)
		end)
		it("does nothing while the plan is switched off", function()
			local was = EggConfig.ENABLED
			EggConfig.ENABLED = false
			local p = profile({ common = 2, rare = 0, epic = 0, crowned = 0 })
			expect(Inc.migrate(p)).toBe(false)
			expect(p.incubator).toBeNil()
			EggConfig.ENABLED = was
		end)
	end)

	describe("incubator: settlement", function()
		it("never converts pieces itself (only migrate does)", function()
			local p = profile({ common = 2, rare = 0, epic = 0, crowned = 0 })
			Inc.applySettlement(p, { seconds = 10 })
			expect(p.materials.common).toBe(2)
			expect(p.incubator.fill).toBe(0)
		end)
		it("adds the match shard and the match time", function()
			local p = profile()
			expect(Inc.applySettlement(p, { shard = "epic", seconds = 245 })).toBe("epic")
			expect(p.incubator.fill).toBe(2)
			expect(p.incubator.shards.epic).toBe(1)
			expect(p.stats.secondsPlayed).toBe(245)
			expect(p.incubator.firstWon).toBe(true)
		end)
		it("ignores a bad shard and clamps the time", function()
			local p = profile()
			expect(Inc.applySettlement(p, { shard = "crowned", seconds = 1e9 })).toBeNil()
			expect(p.incubator.fill).toBe(0)
			expect(p.stats.secondsPlayed).toBe(3600)
			expect(p.incubator.firstWon).toBeNil()
		end)
	end)

	describe("incubator: focus", function()
		it("takes Any or an open family and changes the fill needed", function()
			local p = profile()
			expect(Inc.setFocus(p, "Decoy", econ)).toBe(true)
			expect(EggLogic.fillNeeded(p.incubator)).toBe(22.5)
			expect(Inc.setFocus(p, "Any", econ)).toBe(true)
			expect(EggLogic.fillNeeded(p.incubator)).toBe(18)
		end)
		it("refuses locked, unknown and same focus", function()
			local p = profile()
			local ok, why = Inc.setFocus(p, "Rift", econ)
			expect(ok).toBe(false)
			expect(why).toBe("LOCKED")
			ok, why = Inc.setFocus(p, "Scout", econ)
			expect(why).toBe("BAD_FAMILY")
			ok, why = Inc.setFocus(p, "Any", econ)
			expect(why).toBe("SAME")
		end)
	end)

	describe("incubator: hatch", function()
		it("refuses an egg that isn't full", function()
			local p = profile()
			Inc.ensure(p)
			p.incubator.fill = 17.5
			local ok, why = Inc.hatch(p, econ, { rarity = 0.5, family = 0, species = 0 })
			expect(ok).toBe(false)
			expect(why).toBe("NOT_READY")
			expect(p.incubator.fill).toBe(17.5)
		end)
		it("uses a bought boost for this hatch only and reports its tier", function()
			local p = profile()
			Inc.ensure(p)
			p.incubator.fill = 18
			expect(Inc.grantBoost(p, 1, "r1")).toBe(true)
			expect(Inc.grantBoost(p, 1, "r1")).toBe(false)
			local ok, _, _, info = Inc.hatch(p, econ, { rarity = 0.5, family = 0, species = 0 })
			expect(ok).toBe(true)
			expect(info.boostTier).toBe(1)
			expect(math.abs(info.odds.epic + info.odds.legendary - 0.40) < 1e-9).toBe(true) -- x2 at 100%: 32 + 8
			expect(p.incubator.boost).toBe(0)
		end)
		it("folds Legendary into Epic with no Legendary pet, and opens it when one exists", function()
			local p = profile()
			Inc.ensure(p)
			p.incubator.shards.legendary = 1
			expect(Inc.odds(p, econ).legendary).toBe(0)
			expect(Inc.odds(p, econLegend).legendary > 0).toBe(true)
			Inc.setFocus(p, "Invisibility", econLegend)
			expect(Inc.odds(p, econLegend).legendary).toBe(0)
		end)
		it("hatches the focus family at the rolled rarity, equips it and resets odds", function()
			local p = profile()
			Inc.ensure(p)
			Inc.setFocus(p, "Invisibility", econ)
			p.incubator.fill = 25
			p.incubator.shards.epic = 4
			local ok, why, pet, info = Inc.hatch(p, econ, { rarity = 0.05, family = 0, species = 0 })
			expect(ok).toBe(true)
			expect(why).toBeNil()
			expect(pet.family).toBe("Invisibility")
			expect(pet.rarity).toBe("epic")
			expect(pet.species).toBe("Mirage Manta")
			expect(p.equippedPet).toBe(pet.id)
			expect(info.focused).toBe(true)
			expect(info.fillUsed).toBe(25) -- the whole egg (its odds were read at 25 - 4.5)
			expect(info.fillAtHatch).toBe(25)
			expect(p.incubator.fill).toBe(0)
			expect(p.incubator.shards.epic).toBe(0)
			expect(p.stats.petsHatched).toBe(1)
		end)
		it("picks Any from families with a pet, and a duplicate raises the level", function()
			local p = profile()
			Inc.ensure(p)
			p.incubator.fill = 30
			local _, _, a = Inc.hatch(p, econ, { rarity = 0.99, family = 0, species = 0 })
			expect(a.species).toBe("Crow")
			p.incubator.fill = 30
			local _, _, b, info = Inc.hatch(p, econ, { rarity = 0.99, family = 0, species = 0 })
			expect(b.species).toBe("Crow")
			expect(info.duplicate).toBe(true)
			expect(a.level).toBe(2)
			expect(b.level).toBe(2)
			expect(p.equippedPet).toBe(a.id)
		end)
	end)

	describe("focus rules (17 Oct): hatches never fail", function()
		-- the Grin Ghost moved to Legendary: Invisibility has Common, Epic and Legendary but no Rare
		local econGhost = {
			LAUNCH_FAMILIES = { "Decoy", "Invisibility" },
			FAMILIES = {
				Decoy = { species = { common = "Mouse", rare = "Crow", epic = "Kitsune" } },
				Invisibility = { species = { common = "Prism Chameleon", epic = "Mirage Manta", legendary = "Grim Ghost" } },
			},
		}
		it("1. a focus chip needs a Rare and an Epic pet", function()
			expect(Inc.focusOpen(econ, "Decoy")).toBe(true)
			expect(Inc.focusOpen(econGhost, "Invisibility")).toBe(false)
			expect(Inc.focusOpen(econGhost, "Rift")).toBe(false)
			expect(Inc.focusOpen(econGhost, "Any")).toBe(true)
			local p = profile()
			local ok, why = Inc.setFocus(p, "Invisibility", econGhost)
			expect(ok).toBe(false)
			expect(why).toBe("LOCKED")
		end)
		it("2. a focus that lost its Rare lands on the nearest rarity below in the same family", function()
			local p = profile()
			Inc.ensure(p)
			p.incubator.focus = "Invisibility" -- set before the swap
			p.incubator.fill = 37.5
			local ok, _, pet, info = Inc.hatch(p, econGhost, { rarity = 0.99, family = 0, species = 0 })
			expect(ok).toBe(true)
			expect(info.rolled).toBe("rare")
			expect(pet.family).toBe("Invisibility")
			expect(pet.rarity).toBe("common")
			expect(info.focusRefunded).toBe(false)
			expect(p.incubator.focus).toBe("Invisibility")
		end)
		it("2. a focused Legendary roll uses the family's own Legendary when it has one", function()
			local p = profile()
			Inc.ensure(p)
			p.incubator.focus = "Invisibility"
			p.incubator.fill = 37.5
			local ok, _, pet = Inc.hatch(p, econGhost, { rarity = 0, family = 0, species = 0 })
			expect(ok).toBe(true)
			expect(pet.rarity).toBe("legendary")
			expect(pet.species).toBe("Grim Ghost")
		end)
		it("2. a focus family with no pets at all falls back to Any and refunds the +25% fill", function()
			local p = profile()
			Inc.ensure(p)
			p.incubator.focus = "Tempest"
			p.incubator.fill = 36
			local ok, why, pet, info = Inc.hatch(p, econ, { rarity = 0.99, family = 0.99, species = 0 })
			expect(ok).toBe(true)
			expect(why).toBeNil()
			expect(info.focusRefunded).toBe(true)
			expect(info.refund).toBe(4.5)
			expect(info.fillUsed).toBe(36 - 4.5)
			expect(pet.family).toBe("Invisibility")
			expect(p.incubator.fill).toBe(4.5) -- the focus cost, back in the next egg
			expect(p.incubator.focus).toBe("Any")
		end)
		it("3. Any picks only families with the rolled rarity", function()
			local p = profile()
			Inc.ensure(p)
			p.incubator.fill = 30
			local _, _, pet = Inc.hatch(p, econGhost, { rarity = 0.99, family = 0.99, species = 0 })
			expect(pet.rarity).toBe("rare")
			expect(pet.family).toBe("Decoy") -- the only family with a Rare, whatever the family roll
		end)
		it("3. Any takes the nearest rarity down when no family has the rolled one", function()
			local f, r, refunded = Inc.resolve(econ, "Any", "legendary", 0.5)
			expect(r).toBe("epic")
			expect(f).toBe("Invisibility")
			expect(refunded).toBe(false)
		end)
		it("never fails while any family has any pet", function()
			for _, e in ipairs({ econ, econGhost, econLegend }) do
				for _, focus in ipairs({ "Any", "Decoy", "Invisibility", "Guardian", "Tempest", "Rift" }) do
					for _, r in ipairs({ "common", "rare", "epic", "legendary" }) do
						local f, rr = Inc.resolve(e, focus, r, 0.5)
						expect(f ~= nil and rr ~= nil).toBe(true)
					end
				end
			end
		end)
	end)

	describe("client view", function()
		it("never changes the profile", function()
			local p = profile({ common = 2, rare = 0, epic = 0, crowned = 0 })
			local v = Inc.view(p)
			expect(v.fill).toBe(0)
			expect(v.focus).toBe("Any")
			expect(p.incubator).toBeNil()
			expect(p.materials.common).toBe(2)
			Inc.migrate(p)
			v = Inc.view(p)
			v.shards.common = 99
			expect(p.incubator.shards.common).toBe(0)
		end)
	end)

	describe("client view numbers", function()
		it("carries need, ready, odds, focus locks and first-pet families from the pet data", function()
			Inc.setEcon(econ)
			local p = profile()
			Inc.ensure(p)
			p.incubator.fill = 27
			p.incubator.shards.epic = 2
			local v = Inc.view(p)
			expect(v.need).toBe(18)
			expect(v.full).toBe(18)
			expect(v.cap).toBe(36)
			expect(v.oddsLevel).toBe(1.5)
			expect(v.ready).toBe(true)
			expect(v.legendaryOpen).toBe(false)
			expect(math.abs(v.odds.epic - 0.28) < 1e-9).toBe(true)
			expect(v.focusOpen.Decoy).toBe(true)
			expect(v.focusOpen.Rift).toBe(false)
			expect(#v.firstPetFamilies).toBe(2)
			expect(v.firstPetClaimable).toBe(false)
			-- put the real pet data back (in Studio the module is the live one: nil left the server's incubator view empty)
			Inc.setEcon(if script ~= nil then require(game:GetService("ReplicatedStorage").EOS.Shared.EconomyConfig) else nil)
		end)
	end)

	describe("first pet", function()
		it("unlocks after the first egg won, once, for a chosen family", function()
			local p = profile()
			local ok, why = Inc.claimFirstPet(p, "Decoy", econ)
			expect(why).toBe("NOT_YET")
			Inc.applySettlement(p, { shard = "rare", seconds = 200 })
			ok, why = Inc.claimFirstPet(p, "Rift", econ)
			expect(why).toBe("BAD_FAMILY")
			local good, _, pet = Inc.claimFirstPet(p, "Decoy", econ)
			expect(good).toBe(true)
			expect(pet.species).toBe("Mouse")
			expect(p.firstCommonFree).toBe(false)
			ok, why = Inc.claimFirstPet(p, "Decoy", econ)
			expect(why).toBe("CLAIMED")
			expect(p.incubator.fill).toBe(1) -- the first shard still went into the egg
		end)
	end)

	describe("unseen shards (HOS-INC-001)", function()
		it("remembers each settled shard until seen, oldest first, at most 12", function()
			local p = profile()
			Inc.applySettlement(p, { shard = "rare", seconds = 10 })
			Inc.applySettlement(p, { shard = "epic", seconds = 10 })
			local v = Inc.view(p)
			expect(#v.unseen).toBe(2)
			expect(v.unseen[1]).toBe("rare")
			expect(v.unseen[2]).toBe("epic")
			for _ = 1, 20 do
				Inc.applySettlement(p, { shard = "common", seconds = 1 })
			end
			expect(#Inc.view(p).unseen).toBe(12)
			expect(#p.incubator.unseen).toBe(12)
		end)
		it("markSeen clears them once; a hatch forgets them", function()
			local p = profile()
			local ok, why = Inc.markSeen(p)
			expect(ok).toBe(false)
			expect(why).toBe("NONE")
			Inc.applySettlement(p, { shard = "legendary", seconds = 10 })
			expect((Inc.markSeen(p))).toBe(true)
			expect(#Inc.view(p).unseen).toBe(0)
			for _ = 1, 3 do
				Inc.applySettlement(p, { shard = "legendary", seconds = 10 })
			end
			expect(#Inc.view(p).unseen).toBe(3)
			expect((Inc.hatch(p, econ, { rarity = 0.5, family = 0.5, species = 0.5 }))).toBe(true)
			expect(#Inc.view(p).unseen).toBe(0)
		end)
		it("ignores junk in a saved list and never changes the profile from the view", function()
			local p = profile()
			Inc.applySettlement(p, { shard = "rare", seconds = 10 })
			p.incubator.unseen = { "rare", "crowned", 5, "epic" }
			local v = Inc.view(p)
			expect(#v.unseen).toBe(2)
			expect(#p.incubator.unseen).toBe(4)
		end)
	end)
end
