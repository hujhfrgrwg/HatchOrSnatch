--!strict
-- EggConfig (HOS-EGG-002, 17 Oct 2026): the egg plan's numbers in one table. The server (EggService, ProfileLogic)
-- and the UI (EggUIController) all read this, so the screen shows the odds the server rolls.
-- Spec: docs/HOS-EGG-002/Egg Plan Build Spec.md. Starting values: tune from playtests and telemetry, not by feel.
--
-- In the match: brave plays fill a charge meter that lasts the match; the egg rolls once at safety (crossing 1
-- Common -> Rare always, crossings 2..5 small base upgrade chances, or one guaranteed step when the meter is full). End of match: one shard per player (the egg a
-- surviving Runner holds, or a Catcher's best snatch). Between matches every shard fills one incubator egg;
-- a full egg hatches a pet at the shown odds. Eggs, shards, fill, odds, focus and hatches are never sold.
-- Pure data: no Instances (EggLogic and its tests also run under Lune).

local EggConfig = {}

EggConfig.ENABLED = true -- false = the old ladder (EggLadder) and pieces/recipes (rollback switch)

-- rarities, low -> high, and the TierConfig look level each one shows as (= PointsConfig.Ladder.LEVEL)
EggConfig.RARITIES = { "common", "rare", "epic", "legendary" }
EggConfig.LEVEL = { common = 1, rare = 3, epic = 5, legendary = 7 }
-- names and UI colours (RGB; the UI kit's rarity fills, as on the approved mockups)
EggConfig.RARITY_INFO = {
	common = { name = "Common", rgb = { 142, 240, 122 } },
	rare = { name = "Rare", rgb = { 92, 200, 255 } },
	epic = { name = "Epic", rgb = { 200, 138, 255 } },
	legendary = { name = "Legendary", rgb = { 255, 210, 58 } },
}

-- the charge meter (guaranteed upgrade, Hunter 17 Oct 17:19): it fills across the whole match (the juke count
-- resets each crossing). A FULL meter at a safety on crossings 2..LAST_ROLL_CROSSING (or an early-end bonus roll)
-- guarantees one rarity step (Rare -> Epic, Epic -> Legendary) and empties; GUARANTEE_PER_MATCH guarantees a match,
-- then the meter stays empty. A Hero success fills it.
EggConfig.CHARGE = { JUKE = 0.25, JUKE_MAX_PER_CROSSING = 2, REVIVE = 0.5, HERO_SUCCESS = 2.0, FULL = 2.0, CAP = 2.0, GUARANTEE_PER_MATCH = 1 }

-- the roll at safety. Crossing 1 (and any Common egg's first safety) = Common -> Rare always.
-- Crossings 2..LAST_ROLL_CROSSING without a full meter: chance = base (newbies: base x NEWBIE_BASE_MULT);
-- perCharge is kept for tuning but 0 (the meter guarantees instead of raising the odds).
EggConfig.ROLL = {
	RARE_TO_EPIC = { base = 0.036, perCharge = 0 },
	RARE_TO_LEGENDARY = { base = 0.0036, perCharge = 0 },
	EPIC_TO_LEGENDARY = { base = 0.024, perCharge = 0 },
	LAST_ROLL_CROSSING = 5,
	NEWBIE_BASE_MULT = 1.5,
	NEWBIE_HOURS = 10,
	ROLL_SECONDS = 1, -- the flicker on the egg before the result shows (play never pauses)
	-- section 10 (17 Oct): a match that ends early (3 clean crossings) rolls each surviving Runner's egg once per
	-- skipped roll slot (crossings 2..5 = TOTAL_ROLLS slots) at the base chances, so the end spread doesn't depend on
	-- match length; an unspent full meter is used once by the first of them
	BONUS_ROLLS_ON_EARLY_END = true,
	TOTAL_ROLLS = 4,
}

-- snatching: a Catcher's snatch is credited at most this many rarities above the egg they held when caught;
-- the starting Catcher (never held one this match) is capped at STARTING_CATCHER_CAP
EggConfig.SNATCH = { STEP = 1, STARTING_CATCHER_CAP = "epic" }

-- one shard per player per match goes into the incubator egg at these weights (a shard's rarity only sets its fill)
EggConfig.SHARD_WEIGHT = { common = 0.5, rare = 1, epic = 2, legendary = 8 }

-- the incubator egg (overfill, 17 Oct ~18:04): it can hatch at FILL (100%) and keeps filling to FILL x MAX_MULT (200%);
-- fill past that waits for the next egg. A hatch spends the whole egg and reads the odds from its fill at that moment
-- (minus the focus cost), along ODDS (linear between the points, clamped to the ends). A focus costs FOCUS_COST x FILL
-- at hatch, so a focused egg needs FILL x (1 + FOCUS_COST) to hatch.
EggConfig.INCUBATOR = {
	FILL = 18, -- 100%. 30 -> 12 -> 18 (17 Oct pace; Hunter picks 12 / 18 / 24)
	MAX_MULT = 2, -- the egg holds up to 200% (36)
	FOCUS_COST = 0.25, -- of FILL (4.5), spent at hatch
	ODDS = { -- fill / FILL -> hatch odds (Rare is the rest)
		{ at = 1.0, rare = 0.80, epic = 0.16, legendary = 0.04 },
		{ at = 1.5, rare = 0.72, epic = 0.22, legendary = 0.06 },
		{ at = 2.0, rare = 0.64, epic = 0.28, legendary = 0.08 },
	},
	-- Q1 (17 Oct): while the focus (or, for Any, every family) has no Legendary pet in EconomyConfig, Legendary
	-- shows "coming soon" and its chance goes to Epic (IncubatorLogic.legendaryOpen); it switches on by itself
}

-- the Lucky Egg game pass (Hunter 17 Oct ~18:10): an owner's Epic and Legendary hatch odds x1.5 after the overfill odds
-- are read (Rare is the rest: at 200% fill 46 / 42 / 12). gamePassId 0 = off until Hunter creates the pass in Creator Hub.
EggConfig.LUCKY_PASS = { gamePassId = 0, epicMult = 1.5, legendaryMult = 1.5 }

-- the hatch boost ladder (Hunter 17 Oct ~18:15): Robux dev products on the incubator, for the current egg's hatch only:
-- x2, then upgrade to x3, then x4 (Epic and Legendary odds; Rare the rest). Bought tiers stay on the egg until it
-- hatches. Legendary is capped at legendaryCap after every multiplier (overfill and the Lucky Egg pass included).
-- Product ids 0 = off until Hunter creates the 3 products in Creator Hub (prices ~49 / +50 / +50 Robux, his to set).
EggConfig.HATCH_BOOST = { products = { x2 = 0, x3 = 0, x4 = 0 }, mults = { 2, 3, 4 }, legendaryCap = 0.20 }

-- focus picker order; "Any" = a random family that has a pet of the rolled rarity
EggConfig.FAMILIES = { "Decoy", "Invisibility", "Guardian", "Tempest", "Rift" }
EggConfig.ANY = "Any"

return EggConfig
