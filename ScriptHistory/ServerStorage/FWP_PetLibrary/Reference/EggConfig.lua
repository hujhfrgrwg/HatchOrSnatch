--!strict
-- HOOKED-PETS-CORE-001 (plan docs/HOOKED_PETS_PLAN_001.md §1.6, owner revisions 2026-09-30).
-- Egg tiers, hatch pools, hatch timers and the fishing drop table. No coin eggs: eggs come from
-- the Starter gift, bought Royal Eggs (hatch at once) and very rare fishing drops.
--
-- Owner 2026-09-30: eggs hatch on timers (a short one for the first egg), players can pay to speed a
-- hatch up, bought eggs hatch immediately. Fishing eggs ("Put fishing eggs in, but make sure they
-- meet the rarity parameters"): very rare, the rarest pets extremely rare, never influenced by luck
-- stats "or anything", and certain pets only found very deep (endgame).
--
-- Odds are exact and shared: every pool is converted once, at load, into integer weights out of
-- 10,000 (hundredths of a percent). The server rolls those integers and the UI shows the same
-- integers as percentages, so the displayed odds always equal the rolled odds and add up to 100.00%.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local EggLadderConfig = require(ReplicatedStorage.Shared.Config.EggLadderConfig) -- HOOKED-EGG-LADDER-001

local EggConfig = {}

EggConfig.TotalWeight = 10000
EggConfig.BagCap = 20 -- eggs waiting in the bag (the incubating egg is not counted; bought eggs are never refused)

EggConfig.Order = { "Starter", "Basic", "Shiny", "Golden", "Cosmic", "Royal", "Alien" }

-- HOOKED-PET-ECON-PASS-002: false = the Starter pet hatches from the Starter Egg only (see the pool builder
-- below for the numbers); true = it is also in the Common part of the Basic and Shiny eggs, as before.
EggConfig.StarterInEggs = false

-- Odds = percent per rarity (each tier adds up to 100). Inside a rarity every pet the egg can hold is
-- equally likely. HatchSeconds = real time in the incubator (it keeps counting while the player is
-- offline); 0 = hatches straight from the bag. Deep = may hold the deep-only pets (PetConfig DeepOnly).
EggConfig.Tiers = {
	Starter = {
		Name = "Starter Egg", Short = "Starter", Rank = 0, Source = "Starter", HatchSeconds = 30,
		FixedPet = "MiniFisherman",
		Color = Color3.fromRGB(250, 236, 200), Spots = Color3.fromRGB(120, 200, 255),
	},
	-- HOOKED-EGG-ACQUISITION-001: Odds boosted towards better pets (Common 50%, Uncommon 38%, Rare 12%)
	Basic = {
		Name = "Basic Egg", Short = "Basic", Rank = 1, Source = "Fishing", HatchSeconds = 3 * 60,
		Odds = { Common = 50, Uncommon = 38, Rare = 12 },
		Color = Color3.fromRGB(236, 240, 246), Spots = Color3.fromRGB(110, 200, 110),
	},
	-- HOOKED-EGG-ACQUISITION-001: Common 15%, Uncommon 45%, Rare 28%, Epic 12%
	Shiny = {
		Name = "Shiny Egg", Short = "Shiny", Rank = 2, Source = "Fishing", HatchSeconds = 10 * 60,
		Odds = { Common = 15, Uncommon = 45, Rare = 28, Epic = 12 },
		Color = Color3.fromRGB(150, 226, 255), Spots = Color3.fromRGB(255, 255, 255),
	},
	-- HOOKED-EGG-ACQUISITION-001: Uncommon 20%, Rare 45%, Epic 27%, Legendary 8%
	Golden = {
		Name = "Golden Egg", Short = "Golden", Rank = 3, Source = "Fishing", HatchSeconds = 30 * 60,
		Odds = { Uncommon = 20, Rare = 45, Epic = 27, Legendary = 8 },
		Color = Color3.fromRGB(255, 206, 60), Spots = Color3.fromRGB(255, 250, 200),
	},
	Cosmic = {
		Name = "Cosmic Egg", Short = "Cosmic", Rank = 4, Source = "Fishing", HatchSeconds = 2 * 60 * 60, Deep = true,
		Odds = { Rare = 40, Epic = 42, Legendary = 17.5, Mythic = 0.5 },
		Color = Color3.fromRGB(70, 40, 150), Spots = Color3.fromRGB(120, 255, 240),
	},
	Royal = {
		Name = "Royal Egg", Short = "Royal", Rank = 5, Source = "Robux", HatchSeconds = 0,
		Odds = { Rare = 60, Epic = 35, Legendary = 5 },
		Color = Color3.fromRGB(150, 40, 60), Spots = Color3.fromRGB(255, 210, 70),
	},
	-- HOOKED-ALIEN-EGG-001 (owner 2026-10-01 23:20Z: "a new egg for tomorrow's update ... some sort of
	-- alien pet egg, with 2 new pets and 3 variants per pet ... slightly more expensive than the other
	-- eggs as a limited time egg", 23:21Z: "the alien egg should go live when the ufo event does").
	-- 23:55Z: "add the alien egg as a limited option this weekend for a GUARANTEED ALIEN PET".
	-- A bought, instant egg like the Royal Egg. Pool = its own pets with their exact percent (they add
	-- up to 100); those pets carry Exclusive = "Alien" in PetConfig. It is only on sale inside its
	-- window (EggConfig.Limited below); an Alien Egg already paid for always hatches.
	Alien = {
		Name = "Alien Egg", Short = "Alien", Rank = 6, Source = "Robux", HatchSeconds = 0,
		-- HOOKED-ALIEN-EGG-002: five alien pets, the Void Overlord (Mythic) 1 in 200
		Pool = { { "LilAlien", 62 }, { "MiniMothership", 25 }, { "SaucerPilot", 9 }, { "MechaInvader", 3.5 }, { "VoidOverlord", 0.5 } },
		Color = Color3.fromRGB(96, 104, 120), Spots = Color3.fromRGB(150, 255, 60),
	},
}

-- HOOKED-ALIEN-EGG-001: limited-time eggs. ONE SWITCH per egg: Enabled = false and that egg is never
-- shown or sold (pets already hatched from it stay). The window is checked against the server clock
-- (os.time() on the server, workspace:GetServerTimeNow() on clients, both UTC seconds).
--   StartUtc         when the sale opens. FollowUfoEvent = true takes the UFO event's own go-live
--                    moment instead (Config.UfoEventConfig.GoLiveUnix), so moving the event moves the egg.
--   EndUtc           when it closes. nil = no end.
--   ForceOnInStudio  true = on sale right away, but only inside Roblox Studio (a live server ignores it).
EggConfig.Limited = {
	Alien = {
		Enabled = true,
		-- ALIEN_EGG_DATES_001 (owner 2026-10-04 21:32Z "keep it in!"): the UFO event moved to Oct 11, but the egg
		-- keeps its own Oct 2 start so it never leaves the egg window. true = start with the event instead.
		FollowUfoEvent = false,
		StartUtc = { Year = 2026, Month = 10, Day = 2, Hour = 19, Minute = 40 }, -- Fri Oct 2, 3:40 PM Eastern
		-- Owner 2026-10-02 01:53Z: "Make the alien egg last until next friday at midnight" = the end of
		-- Friday Oct 9 Eastern = Sat Oct 10, 04:00 UTC. (Before: "this weekend", owner 10-01 23:55Z, until
		-- Sunday midnight Eastern = { Year = 2026, Month = 10, Day = 5, Hour = 4, Minute = 0 }.)
		-- ALIEN_EGG_DATES_001 (owner 2026-10-04: "We want the alien egg to stay in the game but the event to
		-- start on this day. It will last 5 days."): the UFO event moved to Sun Oct 11 3:40 PM Eastern, and the
		-- start follows it (FollowUfoEvent), so the old end (Sat Oct 10, 04:00 UTC) came before the start and the
		-- egg would never have gone on sale. Owner 2026-10-04 20:56Z "yes keep selling" (after the event ends):
		-- no end, so it stays on sale from the event's start on, with no countdown and no "Limited Time!" line.
		-- To end it with the event instead: { Year = 2026, Month = 10, Day = 16, Hour = 19, Minute = 40 }.
		-- Old value: { Year = 2026, Month = 10, Day = 10, Hour = 4, Minute = 0 }.
		EndUtc = nil :: any,
		ForceOnInStudio = false,
		-- HOOKED-ALIEN-EGG-003 (owner 2026-10-02 00:31Z: "while the alien egg is available, it should probably be
		-- the centerpiece until you interact with the menu with some vfx"): the hatchery's incubator shows this
		-- egg, sparkling, until the player opens the egg menu. false = the incubator only ever shows their own egg.
		Centerpiece = true,
	},
}

-- HOOKED-ALIEN-EGG-001 (owner 2026-10-01 23:51Z: "The alien pet egg should be INSANELY rare as well
-- during the alien event. That way we can preserve the rarity.", 23:55Z: "keep the alien pets in the
-- game attainable through the expensive eggs"): very rare extra pets inside regular eggs, from the UFO
-- event's go-live on (the event is permanent, so this has no end).
-- ONE SWITCH: Enabled = false and every regular egg holds exactly what it held before.
--   Tiers[<egg>] = { { petId, percent }, ... }  The extras' percent comes off that egg's MOST COMMON
--   rarity (its biggest share), so every rarer pet in the egg keeps its exact chance. Before the start
--   moment the eggs roll and show their old pools (EggConfig.Pools); from it on, EggConfig.EventPools.
--   Which pool is in use depends on the date alone, never on anything about the player.
EggConfig.Extras = {
	Enabled = true,
	-- ALIEN_EGG_DATES_001 (owner 2026-10-04 "keep it in!"): the alien pets stay in Golden / Royal from Oct 2 on,
	-- like the Alien Egg, although the UFO event moved to Oct 11. true = start with the event instead.
	FollowUfoEvent = false,
	StartUtc = { Year = 2026, Month = 10, Day = 2, Hour = 19, Minute = 40 },
	ForceOnInStudio = false,
	Tiers = {
		-- HOOKED-ALIEN-EGG-002: 0.5% for any alien pet in all; the Void Overlord 1 in 10,000
		-- The Golden Egg holds the two Epic alien pets only (with all five it would show 15 pets, too many tiles
		-- to read on a phone); the three rarer ones are in the Royal Egg and the Alien Egg.
		Golden = { { "LilAlien", 0.4 }, { "MiniMothership", 0.1 } },
		Royal = { { "LilAlien", 0.3 }, { "MiniMothership", 0.1 }, { "SaucerPilot", 0.07 }, { "MechaInvader", 0.02 }, { "VoidOverlord", 0.01 } },
	},
}

local function unixOf(utc: any): number?
	if type(utc) ~= "table" then
		return nil
	end
	return DateTime.fromUniversalTime(utc.Year, utc.Month, utc.Day, utc.Hour or 0, utc.Minute or 0, 0).UnixTimestamp
end
local ufoGoLive: number? = nil
do
	local module = script.Parent:FindFirstChild("UfoEventConfig")
	local ok, ufo = pcall(function()
		return module and (require :: any)(module)
	end)
	if ok and type(ufo) == "table" and type(ufo.GoLiveUnix) == "number" then
		ufoGoLive = ufo.GoLiveUnix
	end
end
for _, limited in pairs(EggConfig.Limited) do
	limited.StartUnix = (if limited.FollowUfoEvent == true then ufoGoLive else nil) or unixOf(limited.StartUtc)
	limited.EndUnix = unixOf(limited.EndUtc)
end
EggConfig.Extras.StartUnix = (if EggConfig.Extras.FollowUfoEvent == true then ufoGoLive else nil) or unixOf(EggConfig.Extras.StartUtc)

-- Fishing drops (HOOKED-PETS-EGG-DROPS-001; rolled by Controllers.PetEggProgression from the ThrowRod
-- settlement). One roll per cast that landed at least one fish, highest tier first, at most one egg
-- per cast. Every tier has ONE fixed chance wherever it can drop. The only inputs are where the cast
-- was made: the island (RegionConfig Order, 1 Driftwood .. 5 Volcano) and, for the deep-only egg, the
-- cast's logical depth (ThrowRod; about 26 at the shore). Luck, level, passes, potions, Server Luck,
-- events and pets are never read, and nothing multiplies a chance.
--
-- Cosmic MinDepth 262 is Volcano-gear depth, measured with the game's own cast maths
-- (PetsCoreVerifier 4b). It was 230 until 2026-10-01: the Cast Power / Sinker levels were then
-- extended, which put 230 within reach of Coral Shores gear and of 92% of max-gear AutoFish casts,
-- so the owner picked "Raise to 262" (docs/HOOKED_CAST_DEPTH_AUDIT_001.md): again out of reach for
-- Coral Shores gear, and reached by max Volcano gear with the best lure on roughly a third of
-- AutoFish casts and most Perfect casts. If cast depth is retuned again, re-run the verifier and
-- move this line with it. The deep-only pets (PetConfig DeepOnly) live in that egg alone.
--
-- Pity = bad-luck floor: after that many casts without an egg of that tier, the next cast that
-- finds nothing else gives one. Only the two common tiers have it; Golden and Cosmic are never
-- guaranteed.
--
-- HOOKED-PET-ECON-FIXES-001 (owner 2026-10-02 04:21Z "is the cosmic egg too rare?", on 1 in 1,000: "i think
-- thats still too much and too rare. the odds that they get an amazing drop are low anyways", on 1 in 250: "i
-- dont know if thats too common and ruin it" -> 1 in 400). The Cosmic chance is per DEEP cast, and deep casts
-- are rare by themselves: they need Volcano's best rod, maxed Cast Power and Sinker and a Deep Lure, which the
-- lure shop stocks on 1 restock in 10, so a maxed player makes about 9 of them an hour (tools/econ-sim/
-- egg_odds.py). At 1 in 15,000 that was about 1,600 hours of maxed play for a first egg; at 1 in 400 it is
-- about 43 (a Golden Egg takes about 29). The depth line, the island rule and the pets inside are unchanged.
-- That was the 05:00Z state (EggConfig.CosmicRule.Lure below).
--
-- 05:23Z, same ticket. Owner on "one every 16 days for a 3-hour AutoFisher who buys every Deep Lure": "this
-- feels too extreme and too difficult", then "we shouldnt have it be deep lures then, meaning we should raise the
-- ratio back to like 1/1000", "make sure that all of the eggs scale in rarity well", and on the three options
-- "make the best decision for me". So:
--   MinDepth 245 (was 262). 262 forced the Deep Lure on Volcano (its best gear reaches 257 with no lure). 245 is
--     reached by Volcano's best gear with NO lure on about 24% of AutoFish casts and 80% of Perfect casts, and is
--     still out of reach for Coral Shores' own best gear with any lure (deepest 239).
--   Chance 1 in 1,000 deep casts. For a maxed player that is about 1 in 4,100 of all casts, the Golden Egg's
--     rate, and it needs maxed Volcano gear on top, so it stays the rarest fished egg (1 in 500 would be twice
--     as common as a Golden Egg).
--   DailyCasts 100: only the first 100 deep casts of a UTC day can find the egg. Without the lure nothing else
--     stops an all-day AutoFisher (about 7 eggs a week); with it they find what a 3-hour player finds (about one
--     every 10 days). An active 2-hour player makes about 66 deep casts a day and is not touched. The count
--     lives beside the bad-luck counters (pity.CosmicCasts; Controllers.PetEggProgression starts it again each
--     day), so EvaluateDrop still reads nothing but its arguments.
-- Sim: tools/econ-sim/egg_odds.py, docs/HOOKED_EGG_RARITY_LADDER_001.md. The egg menu shows the chance from
-- here and says the daily limit. ONE LINE to go back: Use = "Lure" (05:00Z) or "Before" (as first built).
EggConfig.CosmicRule = {
	Use = "After",
	Before = { Chance = 1 / 15000, MinDepth = 262 },
	Lure = { Chance = 1 / 400, MinDepth = 262 },
	-- HOOKED-EGG-ACQUISITION-001: 30% more acquirable fishing drop rate ((1/1000)*1.3 = 1 in 769.2)
	After = { Chance = (1 / 1000) * 1.3, MinDepth = 245, DailyCasts = 100 },
}
local cosmicRule = EggConfig.CosmicRule[EggConfig.CosmicRule.Use] or EggConfig.CosmicRule.Before
EggConfig.Drops = {
	Enabled = true,
	RollOrder = { "Cosmic", "Golden", "Shiny", "Basic" },
	Tiers = {
		-- HOOKED-EGG-ACQUISITION-001: 30% more acquirable fishing drop rates & scaled pity floors
		Basic = { Chance = (1 / 250) * 1.3, MinIsland = 2, Pity = 384 },
		Shiny = { Chance = (1 / 1000) * 1.3, MinIsland = 2, Pity = 1923 },
		Golden = { Chance = (1 / 4000) * 1.3, MinIsland = 3 },
		-- HOOKED-PET-ECON-FIXES-001 (EggConfig.CosmicRule above): 1.3 in 1,000 casts past depth 245, the first 100 a day
		Cosmic = { Chance = cosmicRule.Chance, MinIsland = 4, MinDepth = cosmicRule.MinDepth, DailyCasts = cosmicRule.DailyCasts },
	},
	PityOrder = { "Shiny", "Basic" }, -- when nothing rolled, the rarer guarantee is paid first
	-- HOOKED-PET-ECON-PASS-002: the two rarest finds were the only ones a full egg bag threw away (a Basic or Shiny
	-- find keeps its guarantee; the menu still showed 1 in 4,000 and 1 in 1,000). An egg of these kinds that a cast
	-- finds while the bag is full is kept (one of each at most) and handed over by the first later cast with room.
	-- No chance changes and no egg is added: it is an egg the cast already found. Absent or false = lost, as before.
	KeepWhenBagFull = { Golden = true, Cosmic = true },
}

-- HOOKED-EGG-METER-001 (owner 2026-10-02 08:27Z "Does it now feel like pets are the focus of our gameplay, and the
-- greatest reward of our gameplay loop", 08:33Z "we are renaming the game to fishing with pets! so we need pets to
-- almost be as important as the fishing, but obviously not as important"). The sim said they were not: a phone
-- kid found about 2 fishing eggs a month, because eggs only came from very rare rolls. THE EGG METER makes every
-- cast count toward a pet: each cast that lands a fish on island 2 or later fills it by one, and a full meter
-- pays one egg of Tier. The random drops above are unchanged and come on top.
--   Casts    casts for the day's 1st, 2nd, 3rd ... meter egg. The list's length is the most meter eggs a player
--            can earn in one UTC day, so all-day AutoFish earns what a long session earns (owner: "we dont want
--            the eggs too common, because players will be autofishing for them"). { 20, 40, 60 }: a phone kid
--            (about 20 casts a play day) earns about one a play day, a 45-minute player two, a grinder or an
--            AutoFisher three. Before: 2 eggs a month for the kid.
--   Tier     Basic only (Common 70%, Uncommon 25%, Rare 5%): good pets stay as rare as they were.
-- Luck, passes, potions, pets and the Rebirth perk are not read. The count lives beside the bad-luck counters
-- (Pity.Meter, Pity.MeterEggs, Pity.MeterDay; additive) and is kept by Controllers.PetEggProgression; a full bag
-- keeps the meter full until there is room.
-- HOOKED-EGG-METER-002 (owner 2026-10-02 08:37Z "the egg meter should function similarly to the streak system. it
-- should be the same ui type, and fill only if you continue to consistently fish. it decays if not"):
--   Show     "Pill" = its own pill beside the fishing streak pill, built the same way
--            (Client.Controllers.EggMeterHUD). "Tile" = the first version: the PETS tile's caption "EGG 12/20".
--   Decay    Use picks the rule. Grace = seconds without a counted cast before the meter starts to drain,
--            Step = seconds per cast lost after that (0 = the whole count is lost at once, as the streak does).
--            "Gentle" 120 / 10: a walk to the sell booth costs nothing, four minutes away costs about 12 casts.
--            "Hard" 60 / 0 = the streak's own rule. "Off" = never drains (the first version).
--            Time away from the game never drains it (the clock starts again on joining) and a full meter that
--            waits for bag room does not drain. AutoFish never drains it either, which is why the day's list of
--            Casts stays the limit. The time of the last counted cast is Pity.MeterAt (additive).
-- HOOKED-EGG-METER-003 (owner 2026-10-02 08:55Z: "the meter egg should probably only award 1 per day. it should
-- also only unlock after doing the hatchery stuff"):
--   Plan     names the day's list in Plans; Casts is that list. "OneADay" { 20 }: one egg a play day for everyone,
--            so a bought Basic Egg keeps its worth. "ThreeADay" { 20, 40, 60 } was the first version.
--   After    "FirstHatch" = the meter counts only once the player has hatched a pet (the Starter Egg at the
--            hatchery), so it never appears before the hatchery has been learned. "None" = from the first cast
--            on island 2.
-- ONE SWITCH: Enabled = false and nothing counts, nothing is paid and nothing is shown.
EggConfig.Meter = {
	Enabled = true,
	Tier = "Basic",
	Plan = "OneADay",
	Plans = { OneADay = { 20 }, ThreeADay = { 20, 40, 60 } },
	Casts = { 20 }, -- set from Plan just below
	After = "FirstHatch",
	Show = "Pill",
	Decay = {
		Use = "Gentle",
		Gentle = { Grace = 120, Step = 10 },
		Hard = { Grace = 60, Step = 0 },
		Off = false,
	},
	-- HOOKED-PET-ECON-PASS-002: casts made after the day's egg were thrown away, so a phone kid (about 18 counted
	-- casts a play day in the sim) got the daily egg on only 64% of play days. true = those casts keep filling
	-- the meter, up to one short of full: tomorrow opens at the carried count. Still 20 casts an egg and one egg
	-- a day for everyone (all-day Auto Fishing stays at exactly 1). Server only: the pill behaves as before.
	-- false = casts after the day's egg are not counted, as before.
	CarryOver = true,
	-- HOOKED-WEEKLY-GOLDEN-001 (owner 2026-10-02 20:48Z: "shouldn't players progressively get access to better eggs
	-- earning wise so the common-rare pets are accessible to f2p, with epic+ being rare for them"; 20:59Z "Do we think
	-- that epics are too rare and that we are gatekeeping some things behind paywalls"; 21:06Z "Make the recommended
	-- changes", on: "every 7th daily egg is Golden instead of Basic"). A phone kid's eggs were almost all Basic, which
	-- can never be Epic: about one Epic in 5 to 6 months (sim estimate). Every Every-th meter egg of a player's life
	-- is Bonus.Tier instead of Tier: with one meter egg a day that is one Golden Egg per 7 play days (22% Epic, 3%
	-- Legendary), whatever the cast count, so Auto Fishing cannot speed it up. The count is Pity.MeterTotal
	-- (additive, kept by Controllers.PetEggProgression). The pill shows the Golden Egg while it is the next one.
	-- Enabled = false: every meter egg is Tier, as before (the count keeps running).
	Bonus = { Enabled = true, Every = 7, Tier = "Golden" },
}

EggConfig.Meter.Casts = EggConfig.Meter.Plans[EggConfig.Meter.Plan] or EggConfig.Meter.Plans.OneADay

-- The tier of the player's NEXT meter egg. `total` = meter eggs earned so far in the player's life (Pity.MeterTotal).
-- Reads only its argument and the rule above, so the server and the client's pill always agree.
function EggConfig.MeterTier(total: any): string
	local meter = EggConfig.Meter
	local bonus = meter.Bonus
	-- HOOKED-EGG-LADDER-001: the ladder's every-20th Golden replaces this one (EggLadderConfig.MeterBonus)
	local ladderOff = EggLadderConfig.On() and EggLadderConfig.MeterBonus == false
	if not ladderOff and type(bonus) == "table" and bonus.Enabled == true and type(bonus.Tier) == "string" then
		local every = math.floor(tonumber(bonus.Every) or 0)
		if every >= 2 and (math.max(math.floor(tonumber(total) or 0), 0) + 1) % every == 0 then
			return bonus.Tier
		end
	end
	return meter.Tier
end

-- Whether the meter counts for this player yet (Meter.After). `hatched` = pets the player has hatched so far.
function EggConfig.MeterOpen(hatched: any): boolean
	local meter = EggConfig.Meter
	if type(meter) ~= "table" or meter.Enabled ~= true then
		return false
	end
	return meter.After ~= "FirstHatch" or (tonumber(hatched) or 0) >= 1
end

-- HOOKED-BRIDGE-EGGS-001 (owner 2026-10-02, on "a pet goal per island, for example an egg for repairing each bridge":
-- "great idea"): repairing a bridge (coins or the Robux skip) gives one egg of that bridge's tier, once per bridge
-- per run (a Rebirth resets the bridges, so each run earns them again). Tiers[n] = the egg for Bridge n.
-- HOOKED-BRIDGE-EGGS-002 (owner 2026-10-02: "starter island to i2 will not give an egg"; then "Do Basic Shiny Gold,
-- start egg only for first time players"): Bridge 1 gives no bridge egg (the Starter Egg stays the once-per-player
-- egg it always was), Bridge 2 (island 2 -> 3) Basic, Bridge 3 (-> Coral Shores) Shiny, Bridge 4 (-> Volcano) Golden.
-- A bridge egg is never refused for a full egg bag.
-- ONE SWITCH: Enabled = false and bridges give no egg (the Starter Egg is unchanged either way).
-- HOOKED-BRIDGE-EGGS-003 (owner 2026-10-02 21:06Z "Make the recommended changes", on decision 2 of the pet economy
-- report: "Each bridge keeps its Basic / Shiny / Golden egg the first time, then gives a Basic Egg, one bridge egg a
-- day"). A Rebirth resets the bridges and each one paid its egg again: a daily Rebirth player got 40 to 45 Golden and
-- 45 to 50 Shiny Eggs a month for free (sim estimate), about 13 Epic pets a month, against one fished Golden Egg.
--   Repeat.Use = "After": the FIRST time in a player's life each bridge gives its egg, the tier is Tiers[n] as the
--     owner set it, in whichever run that happens. Every later repair of that bridge gives Repeat.Tier, at most
--     Repeat.PerDay repeat bridge eggs a UTC day; Bridge Repeat.ShinyBridge gives a Shiny instead when the player's
--     last Shiny bridge egg was Repeat.ShinyEveryDays or more days ago. A repair over the day's limit gives no egg.
--     The day's limit is tested first, so the Shiny only comes when Bridge 3's repair is the day's first repeat
--     bridge egg (a run that repairs Bridge 2 and Bridge 3 on one day gets the Basic Egg from Bridge 2 and nothing
--     from Bridge 3). Put to the owner 2026-10-02 as an open choice; swapping the two tests in BridgeEggFor makes
--     the weekly Shiny dependable at the cost of two bridge eggs on that one day.
--   Repeat.Use = "Before": every run pays Tiers[n] again, with no limit (the first version).
-- Save fields (additive, Controllers.Pets): BridgeEggsEver[n], BridgeEggDay / BridgeEggToday, BridgeShinyAt.
EggConfig.BridgeEggs = {
	Enabled = true,
	Tiers = { [2] = "Basic", [3] = "Shiny", [4] = "Golden" },
	Repeat = { Use = "After", Tier = "Basic", PerDay = 1, ShinyBridge = 3, ShinyEveryDays = 7 },
}

-- Which egg a repaired bridge gives. first = the player never had this bridge's egg; repeatsToday = repeat bridge
-- eggs already given this UTC day; shinyAgo = seconds since the player's last Shiny bridge egg (nil = never).
-- Returns the tier (nil = no egg) and "First" / "Repeat" / "Weekly" / "DayLimit". Reads only its arguments.
function EggConfig.BridgeEggFor(bridgeIndex: any, first: boolean, repeatsToday: any, shinyAgo: any): (string?, string)
	local rule = EggConfig.BridgeEggs
	local tier = type(rule) == "table" and rule.Enabled == true and type(rule.Tiers) == "table" and rule.Tiers[bridgeIndex] or nil
	if type(tier) ~= "string" then
		return nil, "None"
	end
	local again = rule.Repeat
	if first or type(again) ~= "table" or again.Use ~= "After" then
		return tier, "First"
	end
	if (tonumber(repeatsToday) or 0) >= (tonumber(again.PerDay) or math.huge) then
		return nil, "DayLimit"
	end
	if bridgeIndex == again.ShinyBridge and (shinyAgo == nil or (tonumber(shinyAgo) or 0) >= (tonumber(again.ShinyEveryDays) or 7) * 86400) then
		return "Shiny", "Weekly"
	end
	return again.Tier, "Repeat"
end

-- The meter's count after draining. `count` casts stood on the meter when the clock read `since` (the last counted
-- cast, or the moment of joining), `need` = casts the egg needs, `now` = the same clock. It reads only its
-- arguments and the rule above, so the server and the client's pill always agree. `exact` keeps the fraction
-- (the pill's bar drains smoothly; the number is the whole count).
function EggConfig.MeterCount(count: any, need: any, since: any, now: any, exact: boolean?): number
	local have = math.max(math.floor(tonumber(count) or 0), 0)
	local meter = EggConfig.Meter
	local rules = if type(meter) == "table" then meter.Decay else nil
	local rule = if type(rules) == "table" then rules[rules.Use] else nil
	if type(rule) ~= "table" or have <= 0 or have >= (tonumber(need) or 0) or type(since) ~= "number" or type(now) ~= "number" then
		return have
	end
	local late = now - since - (tonumber(rule.Grace) or 0)
	if late <= 0 then
		return have
	end
	local step = tonumber(rule.Step) or 0
	if step <= 0 then
		return 0
	end
	local lost = late / step
	return math.max(have - (if exact then lost else math.floor(lost)), 0)
end

-- The meter as the client shows it, from the saved counters: N = casts on the meter when the clock read At,
-- Of = casts that egg needs, Left = meter eggs still to earn today (0 = done for today), At = when the count was
-- last true (the last counted cast, or `joined` when that is later; absent = never counted). `today` = UTC day
-- number. The client drains N itself with EggConfig.MeterCount.
function EggConfig.MeterView(pity: any, today: number, joined: number?)
	local meter = EggConfig.Meter
	if type(meter) ~= "table" or meter.Enabled ~= true or type(pity) ~= "table" then
		return nil
	end
	local earned = if tonumber(pity.MeterDay) == today then math.max(math.floor(tonumber(pity.MeterEggs) or 0), 0) else 0
	local need = tonumber(meter.Casts[earned + 1])
	if not need then
		return { N = 0, Of = 0, Left = 0 }
	end
	return {
		N = math.clamp(math.floor(tonumber(pity.Meter) or 0), 0, need),
		Of = need,
		Left = #meter.Casts - earned,
		At = EggConfig.MeterSince(pity, joined),
		Tier = EggConfig.MeterTier(pity.MeterTotal), -- HOOKED-WEEKLY-GOLDEN-001: the egg this meter is filling
	}
end

-- When the saved count was last true: the last counted cast, or the moment of joining when that is later.
function EggConfig.MeterSince(pity: any, joined: number?): number?
	local at = if type(pity) == "table" then tonumber(pity.MeterAt) else nil
	if at and type(joined) == "number" and joined > at then
		return joined
	end
	return at
end

-- HOOKED-REBIRTH-EGG-FIND-001 (owner 2026-10-02: a fifth Rebirth perk for egg luck; then "We only want the luck
-- chance of getting an egg, not any luck changes to what you get inside the eggs"; "dont have it scale way too much
-- even when stat is maxxed out ... only slightly noticeable with catching basic and shiny eggs and thats barely
-- noticing it on those tiers"). The Rebirth perk "Hatching" (EGGS / EGG LUCK, VoyageConfig.Perks) raises the
-- chance that a cast FINDS an egg. It is the one player input to the drop roll; what hatches from an egg is never
-- touched (Roll / OddsTable / pity read no player stat).
--   boost = the perk's bonus (0.02 per rank, 0.10 at max rank 5). A tier's chance x (1 + boost x TierShare[tier]).
--   At max rank: Basic 1 in 250 -> 1 in 227, Shiny 1 in 1,000 -> 1 in 943, Golden 1 in 4,000 -> 1 in 3,902,
--   Cosmic 1 in 400 unchanged (its deep-only pets are the game's last chase). Pity counts are unchanged.
-- The egg menu shows each player their own chance (EggConfig.BoostedChance with the same boost).
-- ONE SWITCH: Enabled = false and every cast rolls the plain chances again.
EggConfig.FindBoost = {
	Enabled = true,
	Perk = "Hatching", -- VoyageConfig.Perks key (the save's NewVoyage.Perks rank)
	Attribute = "VoyageEggFind", -- set by Server.Controllers.VoyageService for the client's egg menu
	Max = 0.25, -- safety cap on any boost handed in
	TierShare = { Basic = 1, Shiny = 0.6, Golden = 0.25, Cosmic = 0 },
}

-- The boost a saved profile has (server: Controllers.PetEggProgression). 0 when off or unknown.
function EggConfig.FindBoostOf(data: any): number
	local cfg = EggConfig.FindBoost
	if cfg.Enabled ~= true or type(data) ~= "table" then
		return 0
	end
	local voyage = data.NewVoyage
	local perks = type(voyage) == "table" and voyage.Perks or nil
	local rank = math.max(math.floor(tonumber(type(perks) == "table" and perks[cfg.Perk] or 0) or 0), 0)
	local ok, perk = pcall(function()
		return (require(script.Parent.VoyageConfig) :: any).Perks[cfg.Perk]
	end)
	if not ok or type(perk) ~= "table" then
		return 0
	end
	rank = math.min(rank, tonumber(perk.MaxRank) or 0)
	return math.clamp(rank * (tonumber(perk.BonusPerRank) or 0), 0, cfg.Max)
end

-- The boost a player has on this client (the attribute the server sets). 0 when off or unknown.
function EggConfig.PlayerFindBoost(player: any): number
	local cfg = EggConfig.FindBoost
	if cfg.Enabled ~= true or typeof(player) ~= "Instance" then
		return 0
	end
	return math.clamp(tonumber(player:GetAttribute(cfg.Attribute)) or 0, 0, cfg.Max)
end

-- A tier's per-cast chance with a boost (the egg menu's "1 in N"): its fixed chance x (1 + boost x share).
function EggConfig.BoostedChance(tier: string, boost: number?): number
	local drop = EggConfig.Drops.Tiers[tier]
	if not drop then
		return 0
	end
	local cfg = EggConfig.FindBoost
	local b = if cfg.Enabled == true then math.clamp(tonumber(boost) or 0, 0, cfg.Max) else 0
	return drop.Chance * (1 + b * math.max(tonumber(cfg.TierShare[tier]) or 0, 0))
end

-- Splits a tier's rarity odds into integer pet weights out of TotalWeight.
-- `extras` (optional) = { { petId, percent }, ... } from EggConfig.Extras: their share is taken off the
-- tier's biggest rarity share and they are added as rows of their own.
-- HOOKED-EGG-SIGNATURE-001 (Hunter 2026-10-05 15:08Z "Build it" on "Give Basic, Shiny and Golden eggs their own
-- signature pets?"): every egg keeps its rarity percentages exactly, but each of the ten new pets hatches from only
-- one of the eggs named in `Eggs`, so the three eggs feel different. Eggs not named (Cosmic, Royal) keep every pet of
-- their rarities, as before. Every signature egg can be fished, so each pet set stays completable without Robux.
-- ONE SWITCH: Use = "Before" and every egg holds what it held before this ticket.
EggConfig.Signature = {
	Use = "After",
	Eggs = { Basic = true, Shiny = true, Golden = true },
	Pets = {
		ShadesShark = "Basic", GamerAxolotl = "Basic", BanditRaccoon = "Basic",
		NinjaPenguin = "Shiny", RoboCrab = "Shiny", VikingWalrus = "Shiny",
		ArmoredRex = "Golden", FrostYeti = "Golden", ThunderWolf = "Golden", LavaScorpion = "Golden",
	},
}
-- The egg a signature pet belongs to, or nil (not a signature pet, or the switch is off).
function EggConfig.SignatureEggOf(petId: string): string?
	if EggConfig.Signature.Use ~= "After" then
		return nil
	end
	return EggConfig.Signature.Pets[petId]
end

local function buildPool(tierName: string, tier: any, extras: any?)
	if tier.FixedPet then
		assert(PetConfig.Pets[tier.FixedPet], "EggConfig: unknown FixedPet in " .. tierName)
		return { { PetId = tier.FixedPet, Weight = EggConfig.TotalWeight } }
	end
	if tier.Pool then
		-- HOOKED-ALIEN-EGG-001: an egg with its own pets, each with an exact percent
		local pool = {}
		for _, entry in ipairs(tier.Pool) do
			local pet = PetConfig.Pets[entry[1]]
			assert(pet and pet.Exclusive == tierName, ("EggConfig: %s Pool pet %s must be Exclusive = \"%s\""):format(tierName, tostring(entry[1]), tierName))
			local share = entry[2] * EggConfig.TotalWeight / 100
			assert(math.abs(share - math.floor(share + 0.5)) < 1e-6, ("EggConfig: %s Pool odds must be in hundredths of a percent"):format(tierName))
			table.insert(pool, { PetId = entry[1], Weight = math.floor(share + 0.5) })
		end
		return pool
	end
	local rows = {}
	local total = 0
	for _, rarity in ipairs(PetConfig.RarityOrder) do
		total += tier.Odds[rarity] or 0
	end
	assert(math.abs(total - 100) < 1e-9, ("EggConfig: %s odds add up to %s, not 100"):format(tierName, tostring(total)))
	for rarity in pairs(tier.Odds) do
		assert(PetConfig.Rarities[rarity], ("EggConfig: %s has unknown rarity %s"):format(tierName, tostring(rarity)))
	end
	-- Each rarity keeps its exact share (e.g. 25% = 2,500 weight); inside a rarity the share is split
	-- as evenly as integers allow, the first pets in PetConfig.Order taking the leftover points, so the
	-- split is identical on every server and client.
	-- extras (HOOKED-ALIEN-EGG-001): their weight comes off the biggest rarity share
	local extraRows, extraWeight, extraFrom = {}, 0, nil
	if extras then
		local biggest = 0
		for _, rarity in ipairs(PetConfig.RarityOrder) do
			if (tier.Odds[rarity] or 0) > biggest then
				biggest, extraFrom = tier.Odds[rarity], rarity
			end
		end
		for _, entry in ipairs(extras) do
			local pet = PetConfig.Pets[entry[1]]
			assert(pet and pet.Exclusive ~= nil and pet.DeepOnly ~= true, ("EggConfig: %s extra %s must be an Exclusive pet"):format(tierName, tostring(entry[1])))
			local share = entry[2] * EggConfig.TotalWeight / 100
			assert(math.abs(share - math.floor(share + 0.5)) < 1e-6, ("EggConfig: %s extra odds must be in hundredths of a percent"):format(tierName))
			table.insert(extraRows, { PetId = entry[1], Weight = math.floor(share + 0.5) })
			extraWeight += math.floor(share + 0.5)
		end
	end
	for _, rarity in ipairs(PetConfig.RarityOrder) do
		local percent = tier.Odds[rarity] or 0
		if percent > 0 then
			local ids = {}
			for _, id in ipairs(PetConfig.Order) do
				local pet = PetConfig.Pets[id]
				-- Exclusive pets (HOOKED-ALIEN-EGG-001) are never in a rarity pool
				-- HOOKED-PET-ECON-PASS-002 (owner 2026-10-02 17:17Z "Ensure rarity %, prices, economy etc. all make sense"):
				-- every player owns the Starter pet (the Mini Fisherman, one fixed bonus), yet it was the most likely
				-- hatch of a Basic Egg (23.34%) and 10% of a Shiny Egg: one in five Basic eggs, bought ones too, was a
				-- plain copy of it. It now comes from the Starter Egg only (FixedPet), and the other pets of its rarity
				-- share its part: Basic Sand Crab / Pebble Frog 35% each (were 23.33%), Shiny 15% each (were 10%).
				-- Every rarity percent of every egg stays as it was. ONE LINE to go back: StarterInEggs = true.
				local starterOut = pet.Starter == true and EggConfig.StarterInEggs ~= true
				-- HOOKED-EGG-SIGNATURE-001: a signature pet hatches only from its own egg among the eggs Signature names
				local sigEgg = EggConfig.SignatureEggOf(id)
				local sigOut = sigEgg ~= nil and EggConfig.Signature.Eggs[tierName] == true and sigEgg ~= tierName
				if pet.Rarity == rarity and (tier.Deep == true or pet.DeepOnly ~= true) and pet.Exclusive == nil and not starterOut and pet.Archived ~= true and not sigOut then -- HOOKED-OTTER-ARCHIVE-001
					table.insert(ids, id)
				end
			end
			assert(#ids > 0, ("EggConfig: %s gives %s%% %s but no pet has that rarity"):format(tierName, tostring(percent), rarity))
			local share = percent * EggConfig.TotalWeight / 100
			assert(math.abs(share - math.floor(share + 0.5)) < 1e-6, ("EggConfig: %s %s odds must be in hundredths of a percent"):format(tierName, rarity))
			share = math.floor(share + 0.5)
			if rarity == extraFrom then
				share -= extraWeight
				assert(share > 0, ("EggConfig: %s extras leave nothing of %s"):format(tierName, rarity))
			end
			local base = share // #ids
			local extra = share - base * #ids
			for i, id in ipairs(ids) do
				table.insert(rows, { PetId = id, Weight = base + (if i <= extra then 1 else 0) })
			end
		end
	end
	for _, row in ipairs(extraRows) do
		table.insert(rows, row)
	end
	local pool = {}
	for _, row in ipairs(rows) do
		if row.Weight > 0 then
			table.insert(pool, { PetId = row.PetId, Weight = row.Weight })
		end
	end
	return pool
end

EggConfig.Pools = {}
for _, tierName in ipairs(EggConfig.Order) do
	local tier = EggConfig.Tiers[tierName]
	assert(tier, "EggConfig.Order names a missing tier: " .. tierName)
	tier.Id = tierName
	local pool = buildPool(tierName, tier)
	local sum = 0
	for _, row in ipairs(pool) do
		sum += row.Weight
		table.freeze(row)
	end
	assert(sum == EggConfig.TotalWeight, "EggConfig: pool weights do not add up for " .. tierName)
	EggConfig.Pools[tierName] = table.freeze(pool)
end

-- HOOKED-ALIEN-EGG-001: the same eggs with their extras (only the tiers EggConfig.Extras names)
EggConfig.EventPools = {}
for tierName, extras in pairs(EggConfig.Extras.Tiers) do
	local tier = EggConfig.Tiers[tierName]
	assert(tier and tier.Odds and not tier.Deep, "EggConfig.Extras names an egg that cannot take extras: " .. tostring(tierName))
	local pool = buildPool(tierName, tier, extras)
	local sum = 0
	for _, row in ipairs(pool) do
		sum += row.Weight
		table.freeze(row)
	end
	assert(sum == EggConfig.TotalWeight, "EggConfig: event pool weights do not add up for " .. tierName)
	EggConfig.EventPools[tierName] = table.freeze(pool)
end

-- True from the extras' start moment on (EggConfig.Extras). `now` = UTC seconds; left out, the
-- server-synced clock is used.
function EggConfig.ExtrasLive(now: number?): boolean
	local extras = EggConfig.Extras
	if extras.Enabled ~= true then
		return false
	end
	if extras.ForceOnInStudio == true and game:GetService("RunService"):IsStudio() then
		return true
	end
	return (now or workspace:GetServerTimeNow()) >= extras.StartUnix
end

-- The pool an egg rolls from and shows at `now`: its event pool once the extras are live, else its own.
function EggConfig.PoolFor(tier: any, now: number?)
	local event = if type(tier) == "string" then EggConfig.EventPools[tier] else nil
	if event and EggConfig.ExtrasLive(now) then
		return event
	end
	return if type(tier) == "string" then EggConfig.Pools[tier] else nil
end

-- True when a pet can be hatched from some egg at `now` (an Exclusive pet: its egg is on sale, or it
-- is a live extra somewhere). The Index lists such pets.
function EggConfig.PetAvailable(petId: any, now: number?): boolean
	local pet = PetConfig.Pets[petId]
	if not pet then
		return false
	end
	if pet.Archived == true then
		return false -- HOOKED-OTTER-ARCHIVE-001: in no egg for now
	end
	if pet.Exclusive == nil then
		return true
	end
	if EggConfig.OnSale(pet.Exclusive, now) then
		return true
	end
	if EggConfig.ExtrasLive(now) then
		for _, pool in pairs(EggConfig.EventPools) do
			for _, row in ipairs(pool) do
				if row.PetId == petId then
					return true
				end
			end
		end
	end
	return false
end

function EggConfig.Get(tier: any)
	return if type(tier) == "string" then EggConfig.Tiers[tier] else nil
end

-- HOOKED-ALIEN-EGG-001: the sale window of a limited egg: opens at, closes at (nil = no end). nil, nil
-- for an egg that is not limited.
function EggConfig.SaleWindow(tier: any): (number?, number?)
	local limited = if type(tier) == "string" then EggConfig.Limited[tier] else nil
	if not limited then
		return nil, nil
	end
	return limited.StartUnix, limited.EndUnix
end

-- True while an egg may be shown and sold. Eggs that are not limited are always on sale (whether a
-- product exists for them is PetProductConfig's business). `now` = UTC seconds; left out, the
-- server-synced clock is used.
function EggConfig.OnSale(tier: any, now: number?): boolean
	local limited = if type(tier) == "string" then EggConfig.Limited[tier] else nil
	if not limited then
		return EggConfig.Tiers[tier] ~= nil
	end
	if limited.Enabled ~= true then
		return false
	end
	if limited.ForceOnInStudio == true and game:GetService("RunService"):IsStudio() then
		return true
	end
	local t = now or workspace:GetServerTimeNow()
	local from, to = EggConfig.SaleWindow(tier)
	return from ~= nil and t >= from and (to == nil or t < to)
end

-- Hatches straight from the bag (no incubator time).
function EggConfig.IsInstant(tier: string): boolean
	local info = EggConfig.Tiers[tier]
	return info ~= nil and (tonumber(info.HatchSeconds) or 0) <= 0
end

-- UI odds list: { { PetId, Weight, Percent } } in pet order. Percent = Weight / 100 (two decimals),
-- identical to what Roll uses. `now` (optional, UTC seconds) = the moment to show; left out, now.
function EggConfig.OddsTable(tier: string, now: number?)
	local pool = EggConfig.PoolFor(tier, now)
	if not pool then
		return {}
	end
	local out = table.create(#pool)
	for _, row in ipairs(pool) do
		table.insert(out, { PetId = row.PetId, Weight = row.Weight, Percent = row.Weight / 100 })
	end
	return out
end

-- HOOKED-EGG-LADDER-001: the new-pet promise (EggLadderConfig.NewPet). `has(petId)` = the player has had that pet.
-- The egg rolls as always; an Epic+ or never-had pet is kept, a repeat of rarity MaxRarity or lower is swapped for a
-- never-had pet of rarity MaxRarity or lower, picked by the egg's own weights. Epic+ chances never change.
local function promiseRank(): number
	for i, r in ipairs(PetConfig.RarityOrder) do
		if r == EggLadderConfig.NewPet.MaxRarity then
			return i
		end
	end
	return 0
end
local function rankOf(petId: string): number
	local pet = PetConfig.Pets[petId]
	for i, r in ipairs(PetConfig.RarityOrder) do
		if pet and r == pet.Rarity then
			return i
		end
	end
	return math.huge
end
-- The pool rows the promise may hand out (never-had, MaxRarity or lower), or nil when none is left.
function EggConfig.PromisePool(tier: string, has: (string) -> boolean)
	local pool = EggConfig.PoolFor(tier)
	if not pool or EggConfig.Tiers[tier] == nil or EggConfig.Tiers[tier].FixedPet then
		return nil
	end
	local top = promiseRank()
	local rows, total = {}, 0
	for _, row in ipairs(pool) do
		if rankOf(row.PetId) <= top and not has(row.PetId) then
			table.insert(rows, row)
			total += row.Weight
		end
	end
	return if total > 0 then rows else nil, total
end
-- The promised hatch: `petId` (from Roll) or a never-had pet in its place.
function EggConfig.KeepPromise(tier: string, petId: string, has: (string) -> boolean, rng: Random): string
	if rankOf(petId) > promiseRank() or not has(petId) then
		return petId
	end
	local rows, total = EggConfig.PromisePool(tier, has)
	if not rows then
		return petId
	end
	local ticket = rng:NextNumber() * total
	for _, row in ipairs(rows) do
		ticket -= row.Weight
		if ticket <= 0 then
			return row.PetId
		end
	end
	return rows[#rows].PetId
end
-- The promised hatch's true odds for the egg window: { { PetId, Weight, Percent } } like OddsTable, or nil when the
-- promise would change nothing. A never-had pet's chance grows by the share the repeats gave up; repeats go to 0.
function EggConfig.PromiseOdds(tier: string, has: (string) -> boolean)
	local rows, newTotal = EggConfig.PromisePool(tier, has)
	if not rows then
		return nil
	end
	local top = promiseRank()
	local lowTotal = 0
	for _, row in ipairs(EggConfig.PoolFor(tier) or {}) do
		if rankOf(row.PetId) <= top then
			lowTotal += row.Weight
		end
	end
	local out = {}
	for _, row in ipairs(EggConfig.PoolFor(tier) or {}) do
		local w = row.Weight
		if rankOf(row.PetId) <= top then
			w = if has(row.PetId) then 0 else row.Weight * lowTotal / newTotal
		end
		if w > 0 then
			table.insert(out, { PetId = row.PetId, Weight = w, Percent = w / 100 })
		end
	end
	return out
end

function EggConfig.Roll(tier: string, rng: Random): string?
	-- the egg's own pool, or its event pool once EggConfig.Extras is live (decided by the date alone)
	local pool = EggConfig.PoolFor(tier)
	if not pool then
		return nil
	end
	local ticket = rng:NextInteger(1, EggConfig.TotalWeight)
	for _, row in ipairs(pool) do
		ticket -= row.Weight
		if ticket <= 0 then
			return row.PetId
		end
	end
	return pool[#pool].PetId
end

-- HOOKED-PET-PITY-001 (owner 2026-10-02 00:28Z: "we definitely want to implement a pity system! that way after a
-- certain amount of eggs, they will eventually be guaranteed the top egg drop"; 01:08Z: "we have pity implement
-- as well"). A VISIBLE bad-luck floor for bought eggs: the egg menu shows "Legendary guaranteed in N eggs!" and
-- counts down (never a hidden guarantee). ONE SWITCH: Enabled = false and every egg rolls exactly as before
-- (saved counters are kept, only ignored).
--   Tiers[<egg>] = { After = N, Min = "<rarity>" }: the N-th egg in a row without a pet of rarity Min or better
--   gives a pet of exactly rarity Min, picked from that egg's own pool by its own weights. Any Min-or-better
--   pet, lucky or guaranteed, starts the count again. The guarantee never hands out a pet rarer than Min, so
--   the rarest pets keep their shown chance (the Void Overlord stays 1 in 200: owner "INSANELY rare").
-- The player's own count is the only new input to a hatch: no stat, pass, potion or pet is read.
--
-- HOOKED-PET-ECON-FIXES-001 (owner 2026-10-02 04:30Z "just optimize it all to be the fairest. just remember that
-- eggs have odds"): KeepBetter. With "exactly Min" the guaranteed egg could never be a pet rarer than Min, so over
-- many eggs the Void Overlord came 0.475% of the time against the 0.5% the Alien Egg shows (1 in 210, not 1 in
-- 200). A paid egg must never show more than it gives. KeepBetter = true: the guaranteed egg first rolls like any
-- other egg and a Min-or-better pet from that roll is kept; only otherwise is it replaced by a pet of exactly
-- Min. Every egg, guaranteed or not, now has the full shown chance of every Min-or-better pet (the Void Overlord
-- is exactly 1 in 200) and the guarantee itself is unchanged. KeepBetter = false: exactly Min, as before.
EggConfig.HatchPity = {
	Enabled = true,
	KeepBetter = true,
	Tiers = {
		Royal = { After = 30, Min = "Legendary" }, -- 5% Legendary: every 20th egg on average, the 30th at the latest
		Alien = { After = 10, Min = "Legendary" }, -- 12.5% Legendary: every 8th egg on average, the 10th at the latest
	},
}

-- The pity rule of an egg, or nil (no rule, switched off, or a bad row).
function EggConfig.PityFor(tier: any)
	local pity = EggConfig.HatchPity
	local rule = if pity.Enabled == true and type(tier) == "string" then pity.Tiers[tier] else nil
	if type(rule) ~= "table" or not PetConfig.Rarities[rule.Min] or (tonumber(rule.After) or 0) < 2 then
		return nil
	end
	return rule
end

-- The rows of the egg's pool at `now` that the guarantee picks from: its pets of exactly rarity Min.
function EggConfig.PityPool(tier: any, now: number?)
	local rule = EggConfig.PityFor(tier)
	local pool = if rule then EggConfig.PoolFor(tier, now) else nil
	local out = {}
	for _, row in ipairs(pool or {}) do
		local pet = PetConfig.Pets[row.PetId]
		if pet and pet.Rarity == rule.Min then
			table.insert(out, row)
		end
	end
	return out
end

-- The guaranteed pet: one of PityPool by the pool's own weights. nil when the egg has no such pet.
function EggConfig.RollPity(tier: string, rng: Random): string?
	local rows = EggConfig.PityPool(tier)
	local total = 0
	for _, row in ipairs(rows) do
		total += row.Weight
	end
	if total <= 0 then
		return nil
	end
	-- HOOKED-PET-ECON-FIXES-001 (KeepBetter above): the egg's ordinary roll comes first, and a Min-or-better pet
	-- from it is the guaranteed pet, so no pet loses any of its shown chance on a guaranteed egg
	if EggConfig.HatchPity.KeepBetter == true then
		local natural = EggConfig.Roll(tier, rng)
		if natural ~= nil and EggConfig.IsPityHit(tier, natural) then
			return natural
		end
	end
	local ticket = rng:NextInteger(1, total)
	for _, row in ipairs(rows) do
		ticket -= row.Weight
		if ticket <= 0 then
			return row.PetId
		end
	end
	return rows[#rows].PetId
end

-- True when hatching `petId` from that egg starts the count again (its rarity is Min or better).
function EggConfig.IsPityHit(tier: any, petId: any): boolean
	local rule = EggConfig.PityFor(tier)
	local pet = PetConfig.Pets[petId]
	if not rule or not pet then
		return false
	end
	return PetConfig.Rarities[pet.Rarity].Order >= PetConfig.Rarities[rule.Min].Order
end

-- Eggs until the guaranteed one for a saved count (1 = the next egg is guaranteed); nil without a rule.
function EggConfig.PityLeft(tier: any, count: any): number?
	local rule = EggConfig.PityFor(tier)
	if not rule then
		return nil
	end
	local n = math.max(math.floor(tonumber(count) or 0), 0)
	return math.max(rule.After - n, 1)
end

-- load-time checks: a pity row must name a real egg that holds a pet of its rarity
for pityTier, rule in pairs(EggConfig.HatchPity.Tiers) do
	assert(EggConfig.Tiers[pityTier] and not EggConfig.Tiers[pityTier].FixedPet, "EggConfig.HatchPity names an egg that cannot have pity: " .. tostring(pityTier))
	assert(PetConfig.Rarities[rule.Min], "EggConfig.HatchPity: bad rarity for " .. tostring(pityTier))
	local has = false
	for _, row in ipairs(EggConfig.Pools[pityTier]) do
		if PetConfig.Pets[row.PetId].Rarity == rule.Min then
			has = true
		end
	end
	assert(has, ("EggConfig.HatchPity: the %s egg holds no %s pet"):format(tostring(pityTier), tostring(rule.Min)))
end

-- Drop chance for one cast on an island at a cast depth: the tier's fixed chance, or 0 where the
-- tier can't drop. `depth` nil means "unknown": tiers with a MinDepth then never drop.
-- `boost` (optional, HOOKED-REBIRTH-EGG-FIND-001) = the player's Rebirth egg-find boost (EggConfig.FindBoost).
-- `mult` (optional, HOOKED-EGG-PLAYER-BOOST-001) = { [tier] = x } from EggPlayerBoostConfig.MultFor; nil = x1.
function EggConfig.DropChance(tier: string, island: number, depth: number?, boost: number?, mult: { [string]: number }?): number
	local drop = EggConfig.Drops.Tiers[tier]
	if not drop or island < drop.MinIsland then
		return 0
	end
	if drop.MinDepth and (depth == nil or depth < drop.MinDepth) then
		return 0
	end
	local x = if type(mult) == "table" then math.max(tonumber(mult[tier]) or 1, 1) else 1
	-- HOOKED-EGG-LADDER-001: Shiny and Golden eggs drop more often on later islands (x1 when the ladder is off)
	return math.min(EggConfig.BoostedChance(tier, boost) * EggLadderConfig.IslandMultiplier(tier, island) * x, 1)
end

-- Pure drop evaluation for one cast. Its arguments are everything that can matter: the island, the
-- cast depth, the player's own pity counters ({ Basic, Shiny }, mutated), the RNG and the player's Rebirth
-- egg-find boost (HOOKED-REBIRTH-EGG-FIND-001). Returns the dropped tier (or nil) and how ("Roll" | "Pity").
function EggConfig.EvaluateDrop(island: number, pity: { [string]: number }, rng: Random, depth: number?, boost: number?, mult: { [string]: number }?): (string?, string?)
	if not EggConfig.Drops.Enabled or type(island) ~= "number" or island < 2 then
		return nil, nil
	end
	for name, drop in pairs(EggConfig.Drops.Tiers) do
		if drop.Pity and island >= drop.MinIsland then
			pity[name] = math.max(math.floor(tonumber(pity[name]) or 0), 0) + 1
		end
	end
	local dropped, how = nil, nil
	for _, name in ipairs(EggConfig.Drops.RollOrder) do
		local chance = EggConfig.DropChance(name, island, depth, boost, mult)
		-- HOOKED-PET-ECON-FIXES-001 (DailyCasts): a tier with a daily limit counts every cast that could find it
		-- (pity["<tier>Casts"]) and stops rolling past the limit. The caller starts the count again each day.
		local daily = if chance > 0 then tonumber(EggConfig.Drops.Tiers[name].DailyCasts) else nil
		if daily then
			local key = name .. "Casts"
			local used = math.max(math.floor(tonumber(pity[key]) or 0), 0) + 1
			pity[key] = used
			if used > daily then
				chance = 0
			end
		end
		if chance > 0 and rng:NextNumber() < chance then
			dropped, how = name, "Roll"
			break
		end
	end
	if not dropped then
		for _, name in ipairs(EggConfig.Drops.PityOrder) do
			local drop = EggConfig.Drops.Tiers[name]
			if drop.Pity and island >= drop.MinIsland and (pity[name] or 0) >= drop.Pity then
				dropped, how = name, "Pity"
				break
			end
		end
	end
	if dropped and EggConfig.Drops.Tiers[dropped].Pity then
		pity[dropped] = 0
	end
	return dropped, how
end

-- HOOKED-HATCH-NOW-GUARD-001 (owner 2026-10-02 19:13Z, picked from the pet economy report: "Hatch Now in a
-- timer's last seconds: a child can pay 9 to 119 R$ to skip one minute. I would hide the button then"). The Robux
-- Hatch Now was offered as long as any time was left: full price for the last seconds, and on the 3-minute quest
-- egg from its first second. It is now NOT offered (no button, no prompt) when
--   * less than MinSeconds or less than MinShare of the egg's own timer is left
--     (Basic 10 min: the last 60 s; Shiny 30 min: 3 min; Golden 2 h: 12 min; Cosmic 8 h: 48 min; an egg that
--     was swapped out and put back is still measured against its tier's full timer), or
--   * the timer it runs on is MinTimer seconds or shorter (the 3 minute quest egg).
-- A purchase that was offered in time but whose receipt arrives with less than MinSeconds left is kept as a
-- stored Hatch Now instead of being spent on those seconds (HatchNowTooLate); any other receipt finishes the
-- timer, as before. Stored (free) Hatch Nows work at any time, as before. Enabled = false: the old behaviour.
EggConfig.HatchNowGuard = { Enabled = true, MinSeconds = 60, MinShare = 0.10, MinTimer = 300 }

-- Is the Robux Hatch Now offered for this hatching egg ({ StartedAt, ReadyAt }) with `left` seconds to go?
-- The same rule on the server (which decides) and the client (which draws the button).
function EggConfig.HatchNowOpen(inc: any, left: any): boolean
	local remaining = tonumber(left) or 0
	if type(inc) ~= "table" or remaining <= 0 then
		return false
	end
	local guard = EggConfig.HatchNowGuard
	if type(guard) ~= "table" or guard.Enabled ~= true then
		return true
	end
	local total = (tonumber(inc.ReadyAt) or 0) - (tonumber(inc.StartedAt) or 0)
	if total <= (tonumber(guard.MinTimer) or 0) then
		return false
	end
	-- the share is of the tier's full timer: an egg put back after a swap restarts with only its time left
	local tier = type(inc.Tier) == "string" and EggConfig.Tiers[inc.Tier] or nil
	local whole = math.max(total, tonumber(tier and tier.HatchSeconds) or 0)
	return remaining >= math.max(tonumber(guard.MinSeconds) or 0, whole * (tonumber(guard.MinShare) or 0))
end

-- A Hatch Now receipt that lands with only the last seconds of the timer left (the dialog was opened in time):
-- true = keep it as a stored Hatch Now instead of spending it on those seconds.
function EggConfig.HatchNowTooLate(left: any): boolean
	local guard = EggConfig.HatchNowGuard
	if type(guard) ~= "table" or guard.Enabled ~= true then
		return false
	end
	return (tonumber(left) or 0) < (tonumber(guard.MinSeconds) or 0)
end

-- "4:32", "1:05:09", "9h 59m" style countdown text for the UI.
function EggConfig.FormatTime(seconds: number): string
	local s = math.max(math.ceil(seconds), 0)
	local hours = s // 3600
	local minutes = (s % 3600) // 60
	if hours >= 1 then
		return string.format("%dh %02dm", hours, minutes)
	end
	return string.format("%d:%02d", minutes, s % 60)
end

table.freeze(EggConfig.Order)

-- HOOKED-EGG-QUEUE-001 (owner 2026-10-02 07:02Z "can we confirm that multiple eggs can be queue hatched", 07:24Z
-- "do the best thing you recommend"): the egg queue runs by itself. When the egg in the incubator is done and
-- another egg waits in the bag, the finished egg moves to a "ready" pile (save field Pets.Ready[tier]) and the
-- next egg's timer starts from the moment the first one finished, also while the player is away. Ready eggs
-- still count toward BagCap, are hatched with a tap (HATCH, or HATCH ALL for all of them in a row), and are
-- never lost. Every timer is as long as before; nothing hatches without a tap.
-- THE SWITCH: Enabled = false and the queue waits for a tap after every egg, as before. Eggs already in the
-- ready pile stay hatchable.
--   HatchAllMax  eggs one HATCH ALL request may hatch (the reveals play in a row, like a pack)
EggConfig.Queue = table.freeze({
	Enabled = true,
	HatchAllMax = 50,
})

function EggConfig.QueueOn(): boolean
	local queue = (EggConfig :: any).Queue
	return type(queue) == "table" and queue.Enabled == true
end

return EggConfig
