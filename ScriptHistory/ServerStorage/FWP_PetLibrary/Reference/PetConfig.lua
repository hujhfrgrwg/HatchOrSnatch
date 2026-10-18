--!strict
-- HOOKED-PETS-CORE-001 (plan docs/HOOKED_PETS_PLAN_001.md §1.3-1.5, Revision 2).
-- Pet definitions shared by the server and the client. Data-driven: a new pet is one row in Pets
-- plus an optional prefab ReplicatedStorage.Prefabs.Pets.<Id> (without one it renders as a
-- placeholder built from Look). Bonuses are rolled and saved at hatch time; no gameplay system
-- reads them until PETS_BONUS_WIRING_001 (owner decision D6).
local RunService = game:GetService("RunService")

-- HOOKED-EGG-GUIDE-001 (owner 2026-10-01: the first egg hops out of the water and guides the player): while the
-- walking egg guide is on, the Starter Egg is fished up one level earlier (Shared.Config.EggGuideConfig.EggLevel).
-- nil = that switch is off (or the module is missing): StarterEggFind.Level stays 4, as before.
-- HOOKED-EGG-LADDER-001: the Castaway's quest egg is a Shiny while the egg ladder is on (EggLadderConfig)
local CASTAWAY_TIER = "Basic"
do
	local module = script.Parent:FindFirstChild("EggLadderConfig")
	local ok, ladder = pcall(function()
		return module and (require :: any)(module)
	end)
	if ok and type(ladder) == "table" and ladder.On() and type(ladder.CastawayTier) == "string" then
		CASTAWAY_TIER = ladder.CastawayTier
	end
end
local EGG_GUIDE_LEVEL: number? = nil
do
	local module = script.Parent:FindFirstChild("EggGuideConfig")
	local ok, guide = pcall(function()
		return module and (require :: any)(module)
	end)
	if ok and type(guide) == "table" and guide.Enabled == true then
		EGG_GUIDE_LEVEL = tonumber(guide.EggLevel)
	end
end

local PetConfig = {}

PetConfig.Version = 1

-- Master switch. Pets release on their own (plan §3, Revision 2), so live servers stay off until
-- the owner sets LiveRelease = true. Studio and Local Server tests always run pets.
-- HOOKED-PETS-LIVE-RELEASE-001 (owner 2026-10-01: the hatchery did nothing on live -> "Release live
-- if all is working"): released after PetsCore 645/645, PetHatchery 91/91, PetsVariants 342/342 and a
-- Studio walk-up -> hatch -> equip run. false switches every pet system off on live servers again.
PetConfig.LiveRelease = true
PetConfig.Enabled = PetConfig.LiveRelease or RunService:IsStudio()

PetConfig.StorageCap = 200 -- owned pets per player (plan §1.3); bounds the save size

-- HOOKED-PETS-LESSON-EGG-001 (owner 2026-10-01: players hatch and equip the Starter pet "but they dont
-- understand how to get more" -> "a 2nd egg ... in their first 2-3 casts in island 2", "a golden circle
-- around the egg just like the rare fish in the tutorial. If they miss it, it pops up on the next cast";
-- hatch timer 3 min, between the Starter's 30 s and the Basic egg's 10 min). Once per player, from island 2,
-- after the Starter pet has hatched: the egg swims in the cast's school (a FishingObject, PetEggProgression)
-- from the FromCast-th cast on that island until it is hooked. Not a drop: EggConfig's odds are untouched.
-- HOOKED-PETS-QUEST-EGG-001 (owner 2026-10-01 18:01Z: "there shouldnt be a second free egg reward. it
-- should be a reward for the end of the castaway questline"): switched OFF. The egg no longer swims in
-- the school; it is PetConfig.QuestEgg below. Enabled = true brings the swimming egg back.
PetConfig.LessonEgg = table.freeze({
	Enabled = false,
	Object = "Pet Egg", -- Content.Item.FishingObject entry (Kind "PetEgg")
	Tier = "Basic",
	FromCast = 2, -- the egg first swims on this cast on island 2+ (counted after the Starter pet hatched)
	MinIsland = 2,
	HatchSeconds = 180,
})

-- HOOKED-PETS-QUEST-EGG-001: the second egg is the reward for finishing a story questline. Given once per
-- player by Controllers.Pets when Controllers.Storyline turns in the arc's last quest (and on join for a
-- player who finished it before owning a Starter Egg). A replay of the arc after a Rebirth gives it again, as
-- a Shiny Egg (HOOKED-PETS-QUEST-EGG-REBIRTH-001, RebirthTier below).
-- Enabled = false: no quest egg.
PetConfig.QuestEgg = table.freeze({
	Enabled = true,
	-- HOOKED-PETS-QUEST-EGG-003 (owner 2026-10-01 18:35Z: "multiple quest vendors should reward eggs!"): one
	-- egg per story questline, rising with the story. Key = StorylineConfig.Arcs key; LastQuest = that arc's
	-- number of jobs; HatchSeconds (optional) = a shorter timer than the tier's own when the egg starts
	-- hatching at once. Never Cosmic (deep-water pets) and never Royal (the paid egg). Remove a row and that
	-- questline gives no egg.
	-- HOOKED-PETS-QUEST-EGG-REBIRTH-001 (owner 2026-10-02: "First run through no rebirth: [Basic] eggs. Second run
	-- through and beyond: only shiny eggs"): every NPC quest egg is Basic on the first run (Diver was Shiny,
	-- FireKeeper Golden); after a Rebirth all of them are RebirthTier (Shiny).
	Arcs = table.freeze({
		-- (HOOKED-STORY-LONGER-001: every questline is 7 jobs now; the egg comes with the last one)
		-- HOOKED-ISLAND2-CASTAWAY-EGG-001 (owner 2026-10-12, Island 2 churn): the Castaway's egg comes with his 3rd job
		-- (about 4 minutes in) instead of his 7th. LastQuest may now be a mid-questline job: Controllers.Pets hands the
		-- egg over on that job (OnStoryArcComplete) and the later jobs carry on with no egg line. 7 = the old timing.
		Castaway = table.freeze({ Tier = CASTAWAY_TIER, LastQuest = 3, HatchSeconds = 180 }), -- island 2 (Shiny with the egg ladder)
		-- HOOKED-CASTAWAY-EGG2-001 (owner 2026-10-12: "put a second egg at the end of the castaway. So 2 eggs total"):
		-- a second row for the same questline (Arc = the StorylineConfig.Arcs key it belongs to), handed over with his
		-- last job. Saved under its own key (QuestEggs.CastawayFinal), so the first egg's save and timing are untouched.
		CastawayFinal = table.freeze({ Arc = "Castaway", Tier = "Basic", LastQuest = 7 }), -- island 2, end of his questline
		Diver = table.freeze({ Tier = "Basic", LastQuest = 7 }), -- Volcano Island
		FireKeeper = table.freeze({ Tier = "Basic", LastQuest = 7 }), -- Volcano Island, the story's last arc
		-- STORY_TRAIL_001 (owner 2026-10-03, "each new NPC gives one Basic egg"): the trail's new questlines.
		-- Dock Gran Nell moved to Waterfall Cove after the Castaway (owner 01:00Z), so her egg comes long after the
		-- Starter Egg and the Castaway's (it had no row while she stood on island 1).
		Nell = table.freeze({ Tier = "Basic", LastQuest = 3 }), -- Waterfall Cove, after the Castaway
		Pip = table.freeze({ Tier = "Basic", LastQuest = 5 }), -- Lily Pond
		Lou = table.freeze({ Tier = "Basic", LastQuest = 5 }), -- Coral Shores
	}),
	Line = "Here, take this Pet Egg!", -- the NPC's extra line when the egg is handed over
	-- HOOKED-QUEST-EGG-DAY-LIMIT-001 (owner 2026-10-02 19:13Z, picked from the pet economy report: "Quest eggs after
	-- a Rebirth: the same leak as the bridge eggs ... I would allow one a day"). Every Rebirth resets the questlines
	-- and each one pays its Shiny Egg again, with no limit: a player who Rebirths many times a day got 160 to 384
	-- free Shiny Eggs a month in the sim. After the first Rebirth, at most this many quest eggs a UTC day in total
	-- (the first run's eggs and Rick's reef egg are never limited). A questline finished over the limit stays owed
	-- and pays on a later UTC day while it is still finished: when the player joins, or within seconds of the day
	-- turning if they are online. 0 = no limit, as before.
	PerDayAfterRebirth = 1,
	-- the NPC's line when the day's quest egg was already given. It counts the hours to the next UTC day, because
	-- "tomorrow" is wrong for an evening player in the Americas (UTC midnight is 8 pm US Eastern).
	WaitFormat = "Next quest egg in %d hours!",
	WaitOne = "Next quest egg in 1 hour!",
	-- Found while testing the day limit (2026-10-02): "this questline's last job was ever handed in" survives a
	-- Rebirth (Storyline's Heard_ number), and it counted as finished. So after every Rebirth the next join paid
	-- each such questline's Shiny Egg again without the questline being replayed. true = after a Rebirth the
	-- questline has to be finished again in that run (what "the story questlines replay after each rebirth and
	-- give their egg again" below describes). false = as before. The first run is not affected.
	ReplayAfterRebirth = true,
	-- HOOKED-PETS-QUEST-EGG-002 (owner 2026-10-01 18:11Z: "it should hint at it yes. we also may want to change
	-- the ! over his head to be an egg with a ! in it? not sure."), until the player has received the egg:
	Hint = true, -- the first job's offer ends with HintLine, and the last job's reward line names the egg
	HintLine = "Finish all my jobs and I'll give you a Pet Egg!",
	RewardFormat = "%s! Reward: $%s, %s XP and a Pet Egg",
	-- (owner 18:18Z: "only the final quest awards the egg, and that is clear so kids dont think its broken?")
	-- after each earlier job he counts down to it:
	LeftFormat = "%d more jobs and the Pet Egg is yours!",
	LeftOne = "1 more job and the Pet Egg is yours!",
	Marker = true, -- his "!" / "?" floats in front of an egg; false = the plain gold marker
	-- HOOKED-PETS-RICK-EGG-001 (owner 2026-10-01: "Need to be able to get a low tier egg from the rick quest",
	-- then "change rick's quests to align with the egg ... same style for Rick"): Rick the Scientist's quest is
	-- the reef (Server.Controllers.ReefRestoration). Reaching ReefTier counts as finishing it; the egg is saved
	-- like a questline's (QuestEggs.Rick). Same egg marker, hint, countdown and handover line as the Castaway.
	Reef = table.freeze({
		-- HOOKED-PETS-RICK-EGG-LAST-TIER-001 (owner 2026-10-01: "egg at the last reef tier. eggs are supposed to be
		-- rare"): Coral Shores, "Pristine Reef" (all 895 Reef Points). Was ReefTier 2 ("Growing Reef", 70 points).
		Rick = table.freeze({ Tier = "Basic", ReefTier = 5 }),
	}),
	ReefHintLine = "Help me heal the reef and I'll give you a Pet Egg!",
	ReefLeftFormat = "%d more reef levels and the Pet Egg is yours!",
	ReefLeftOne = "1 more reef level and the Pet Egg is yours!",
	-- HOOKED-PETS-QUEST-EGG-REBIRTH-001 (owner 2026-10-02: "All eggs should be shiny for npc quests after rebirth.
	-- And stay at shiny"): once a player has rebirthed (NewVoyage.VoyageCount >= 1) every NPC quest egg is this
	-- tier, whatever its row says, on every rebirth after. The story questlines replay after each rebirth and give
	-- their egg again each time (Controllers.Pets keeps QuestEggRebirth[arcId] = the rebirth it was given in).
	-- Rick's reef is never reset, so his egg stays once per player (Shiny if first earned after a rebirth).
	RebirthTier = "Shiny",
})

-- HOOKED-CASTAWAY-EGG2-001: every egg row of one questline (its own row, plus rows whose Arc names it), as
-- { Key = save key, Row = row }, earliest job first.
function PetConfig.QuestEggRows(arcId: any): { { Key: string, Row: any } }
	local quest = PetConfig.QuestEgg :: any
	local rows = {}
	if type(quest) ~= "table" or type(quest.Arcs) ~= "table" or type(arcId) ~= "string" then
		return rows
	end
	for key, row in pairs(quest.Arcs) do
		if type(row) == "table" and (key == arcId and row.Arc == nil or row.Arc == arcId) then
			table.insert(rows, { Key = key, Row = row })
		end
	end
	table.sort(rows, function(a, b)
		return (tonumber(a.Row.LastQuest) or 0) < (tonumber(b.Row.LastQuest) or 0)
	end)
	return rows
end

-- HOOKED-CASTAWAY-EGG2-001: the questline's next egg still owed (received = the QuestEggs table the server sends),
-- as (save key, row); nil when every egg of it was received.
function PetConfig.QuestEggNext(arcId: any, received: any): (string?, any)
	for _, entry in ipairs(PetConfig.QuestEggRows(arcId)) do
		if not (type(received) == "table" and received[entry.Key] == true) then
			return entry.Key, entry.Row
		end
	end
	return nil, nil
end

-- How many times the player has rebirthed (New Voyage).
function PetConfig.RebirthCount(data: any): number
	local voyage = type(data) == "table" and data.NewVoyage
	return math.max(math.floor(tonumber(type(voyage) == "table" and voyage.VoyageCount or 0) or 0), 0)
end

-- HOOKED-QUEST-EGG-DAY-LIMIT-001: the NPC's line when the day's quest egg is used up, at `now` (os.time).
function PetConfig.QuestEggWaitLine(now: number): string
	local quest = PetConfig.QuestEgg :: any
	local hours = math.clamp(math.ceil((86400 - (math.floor(now) % 86400)) / 3600), 1, 24)
	return if hours == 1 then quest.WaitOne else string.format(quest.WaitFormat, hours)
end

-- HOOKED-PETS-QUEST-EGG-REBIRTH-001: the egg tier a quest actually gives this player (its row's tier, or
-- QuestEgg.RebirthTier once they have rebirthed). Used by the server grant and every client egg picture.
function PetConfig.QuestEggTier(baseTier: string, data: any): string
	local quest = PetConfig.QuestEgg
	if type(quest) == "table" and type(quest.RebirthTier) == "string" and PetConfig.RebirthCount(data) >= 1 then
		return quest.RebirthTier
	end
	return baseTier
end

-- HOOKED-PETS-STARTER-FIND-001 (owner 2026-10-01: "place the starter egg somewhere in the 1st island
-- progression where they're not being spammed by other onboarding stuff", "moved forward onto island 1 where
-- you actually find it while fishing ... 'unlock island 2 to hatch the egg'", "the bridge 1 reward is that they
-- get to hatch the egg literally once they cross"). From Level (core tutorial done) the Starter Egg swims in the
-- school on island 1 with the gold ring, every cast until hooked. Level 4 sits after the tutorial's Starter Gift
-- and the first playtime gift (~90 s) and before Level 5 (Bridge 1 card + Auto Fishing). The egg waits in the
-- bag and becomes ready to hatch the moment the player stands on island 2 (Controllers.Pets:_readyStarter).
PetConfig.StarterEggFind = table.freeze({
	Enabled = true,
	Object = "Starter Egg", -- Content.Item.FishingObject entry (Kind "PetEgg", EggTier "Starter")
	Level = EGG_GUIDE_LEVEL or 4, -- HOOKED-EGG-GUIDE-001: 3 while the walking egg guide is on (see the top of this file)
	-- HOOKED-STARTER-EGG-FORCE-001 (owner 2026-10-02: "Make the egg on starter island force catch on level 3.5"): the
	-- egg comes once the player is this far through Level (0.5 = halfway to the next level, so "3.5"), and the cast
	-- it comes in catches it for sure (the hook grabs it as it passes the egg's depth). nil = from the start of Level,
	-- caught like any fish (as before).
	-- HOOKED-FIRST-SESSION-001 (owner 2026-10-10 "another reward"): 0 (was 0.5) = from the start of the level, so with
	-- EggGuideConfig.EggLevel 2 the egg is hooked on the first cast after the tutorial.
	LevelFraction = 0,
	Force = true,
	Island = 1,
})

-- HOOKED-FIRST-SESSION-002 (owner 2026-10-10: "as someone who doesnt read (also every kid ever) [they're] not gonna know
-- to reach level 5 for it and leave out of confusion since the egg doesnt hatch"; picked "Hatch it on Island 1"). The
-- Starter Egg no longer waits for Bridge 1: after it is fished up, every catch cracks it a little (a pip meter over the
-- walking egg, Client.Controllers.StarterEggMeter) and on the Catches-th catch it hatches right where the player
-- stands (Controllers.Pets:StarterProgress). Bridge 1 / island 2 stay the way to the hatchery and more eggs.
-- Enabled = false = the old flow (the egg waits in the bag until the player stands on island 2).
PetConfig.StarterHatchHere = table.freeze({
	Enabled = true,
	Catches = 2, -- catches after the egg's own cast; with Level 5 ~2 casts after the egg, it hatches no later than the bridge opens
	HatchDelay = 2.2, -- seconds after the catch settles, so the catch shows first and the hatch reveal follows
})

-- HOOKED-PETS-HATCHERY-001: the Pet Hatchery booth on island 2. The model and its anchors come from
-- HOOKED-PET-HATCHERY-PLACE-001; Client.Controllers.PetHatchery draws each player's own eggs and
-- pets on it (nothing it shows is shared between players).
PetConfig.Hatchery = table.freeze({
	Path = table.freeze({ "WorldZones", "Zone2", "PetHatchery" }), -- under Workspace
	OpenTab = "Eggs", -- PETS panel tab (kept for the panel's own HATCH button)
	OpenMenu = true, -- stepping on the green pad opens the egg menu (Controllers.PetEggMenu)
	PadMargin = 3, -- studs past the pad before the panel closes again (the booths' leash)
	PadLeaveSeconds = 0.35,
	ShowDistance = 140, -- the booth only updates for players this close
	VisitRadius = 24, -- "reached the hatchery" for analytics: this close to the pad
	VisitSlack = 14, -- extra studs the server allows for lag when it checks that report
	-- One-line switch (owner 2026-10-01: a visible swap must be easy to revert). false = the booth's
	-- four static shelf eggs stay exactly as they were placed; no animated eggs are put over them.
	AnimatedShelf = true,
})

-- One-line switch for the pet voices (HOOKED-PETS-VOICES-001). false = every pet is silent again:
-- Shared.Modules.PetVoices plays nothing and the egg shop's pet tiles go back to their click.
PetConfig.Voices = table.freeze({ Enabled = true })

-- HOOKED-PETS-BONUS-WIRING-001 (owner 2026-10-01: "wire the bonuses"): which pet bonuses act on the
-- game. One line each: false = that bonus is still shown on the pet but does nothing (how every
-- bonus was before this ticket). Enabled = false switches all six off at once.
--   Lucky      x luck in the fish roll            (Events.ThrowRod, with the other luck multipliers)
--   Skipper    chance of one extra Skip Bounce    (Events.ThrowRod, open-water Good / Perfect casts)
--   Scout      undiscovered fish weigh more       (Events.ThrowRod, the roll's discovery input)
--   Scholar    x XP on live catches               (Events.ThrowRod, the haul's XP)
--   Alchemist  x mutation chance                  (Events.ThrowRod, the mutation roll's input)
--   Merchant   x sell value                       (Services.Item.GetSellValue; not Reef donations)
-- Only the EQUIPPED pet counts, with its own rolled value (capped at today's range, EffectiveBonus).
PetConfig.BonusWiring = table.freeze({
	Enabled = true,
	Lucky = true,
	Skipper = true,
	Scout = true,
	Scholar = true,
	Alchemist = true,
	Merchant = true,
	-- HOOKED-PET-EXTRA-FISH-001 (owner 2026-10-02: "a chance to award 1+ fish extra per cast"):
	--   Fetcher    chance of one more fish          (Events.ThrowRod settlement, Controllers.PetBonus:ExtraFish)
	Fetcher = true,
	-- HOOKED-PET-NEW-BENEFITS-001 (owner 2026-10-02 04:55Z / 04:57Z: Treasure Finder, Boss Lure, Perfect Cast
	-- Helper, Backpack Space; 05:01Z "make all of the changes we discussed"). One line each, as above:
	--   Treasure   chance of a coin pop on a catch    (Controllers.PetBonus:Treasure, the pets' own settlement call)
	--   BossLure   the boss bites more often          (Controllers.BossEvents:_encounterOdds; never summons one)
	--   Aim        a wider Perfect zone, hand casts   (Events.ThrowRod cast quality + the client's meter)
	--   Packer     extra bag slots                    (Services.Backpack.GetCap, player attribute PetBagSlots)
	Treasure = true,
	BossLure = true,
	Aim = true,
	Packer = true,
})

-- How a working bonus is shown (owner 2026-10-01: "then add the tag and a boost chip"). One line
-- each: false = that piece is not drawn (the bonus itself keeps working).
PetConfig.BonusDisplay = table.freeze({
	Chip = true, -- your own pet's bonus as a chip in the HUD boosts row (hover or tap it for the pet's name)
	Tag = true, -- a small "+12% Luck" over OTHER players' pets, close up (never over your own)
	TagDistance = 45, -- studs the tag can be read from
})

-- The colour each bonus is written in on the chip's card (the boosts row's own colours where it has one).
PetConfig.BonusTints = table.freeze({
	Lucky = Color3.fromRGB(94, 234, 74),
	Skipper = Color3.fromRGB(124, 199, 255),
	Scout = Color3.fromRGB(255, 165, 61),
	Scholar = Color3.fromRGB(82, 249, 249),
	Alchemist = Color3.fromRGB(255, 74, 74),
	Merchant = Color3.fromRGB(255, 215, 0),
	Fetcher = Color3.fromRGB(255, 150, 110), -- HOOKED-PET-EXTRA-FISH-001
	-- HOOKED-PET-NEW-BENEFITS-001
	Treasure = Color3.fromRGB(255, 217, 74),
	BossLure = Color3.fromRGB(255, 120, 190),
	Aim = Color3.fromRGB(200, 255, 140),
	Packer = Color3.fromRGB(160, 232, 255),
})

-- HOOKED-PETS-HUD-RULES-001 (owner 2026-10-01: "pets button and ui should be hidden while you are
-- fishing"). false = the PETS button and windows stay on screen during a cast, as before.
-- HOOKED-PETS-TILE-BIG-EGG-001 (owner 2026-10-01: "i wonder if the egg icon should be larger on this ui so
-- it is easily identifieable. it should be structured like the join group gift icon"): BigEgg = true builds
-- the tile like the free gift tile (the egg or pet fills the tile, the label sits across its bottom edge,
-- no progress bar); false = the small egg above a label inside the tile, as before.
PetConfig.Hud = table.freeze({ HideWhileFishing = true, BigEgg = true })

PetConfig.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
-- Colours match the fish rarity gradients in Shared.Utils.Visuals.
PetConfig.Rarities = {
	Common = { Order = 1, Light = Color3.fromRGB(245, 248, 255), Color = Color3.fromRGB(196, 206, 220), Dark = Color3.fromRGB(120, 132, 150) },
	Uncommon = { Order = 2, Light = Color3.fromRGB(145, 255, 114), Color = Color3.fromRGB(70, 214, 88), Dark = Color3.fromRGB(24, 140, 56) },
	Rare = { Order = 3, Light = Color3.fromRGB(102, 246, 255), Color = Color3.fromRGB(60, 170, 255), Dark = Color3.fromRGB(30, 84, 210) },
	Epic = { Order = 4, Light = Color3.fromRGB(246, 113, 255), Color = Color3.fromRGB(190, 84, 255), Dark = Color3.fromRGB(104, 40, 200) },
	Legendary = { Order = 5, Light = Color3.fromRGB(255, 246, 111), Color = Color3.fromRGB(255, 190, 60), Dark = Color3.fromRGB(214, 110, 10) },
	Mythic = { Order = 6, Light = Color3.fromRGB(255, 72, 220), Color = Color3.fromRGB(200, 70, 245), Dark = Color3.fromRGB(110, 40, 200) },
}

-- Bonus ranges in percent, per rarity (plan §1.4). Merchant runs at about half the others because
-- sell value already multiplies through VIP, Rebirth and potions.
local STANDARD = {
	Common = { 6, 8 }, Uncommon = { 10, 13 }, Rare = { 15, 19 },
	Epic = { 21, 26 }, Legendary = { 30, 33 }, Mythic = { 40, 45 },
}
local MERCHANT = {
	Common = { 3, 4 }, Uncommon = { 5, 6 }, Rare = { 7, 9 },
	Epic = { 10, 12 }, Legendary = { 14, 15 }, Mythic = { 18, 20 },
}
-- HOOKED-PET-ECON-FIXES-001 (econ sim 006, docs/HOOKED_PET_ECONOMY_FIXES_HANDOFF_001.md section 1; owner
-- 2026-10-02 "begin fixing the issues", "just optimize it all to be the fairest"): XP is the one bonus that
-- shortens the whole game, and the pet's XP multiplies with the x2 XP pass. On the standard ranges a finished
-- Phoenix Gull (+42.5%) reached Volcano in 86 minutes and a finished Void Overlord (+57.9%) in 78 (floor 90),
-- and with x2 XP they skipped 58% / 60% of the run to Level 100 (approved limit 55%). XP pets therefore have
-- lower ranges: a finished Mythic is +28.3% (Volcano about 89 minutes, 55% with x2 XP). Only Cozy Lion, Phoenix
-- Gull and Void Overlord roll from this table (the Mini Fisherman is fixed at 8). No migration: EffectiveBonus
-- caps a saved roll at today's range. ONE LINE to go back: SCHOLAR_USE = "Before".
local SCHOLAR_USE = "After"
local SCHOLAR = if SCHOLAR_USE == "Before" then STANDARD else {
	Common = { 6, 8 }, Uncommon = { 8, 10 }, Rare = { 10, 13 },
	Epic = { 13, 16 }, Legendary = { 16, 19 }, Mythic = { 19, 22 },
}

-- HOOKED-PET-NEW-BENEFITS-001: ranges of the four new bonuses (see the Archetypes rows for what the number means).
-- HOOKED-PET-ECON-PASS-002 (owner 2026-10-02 17:17Z "Ensure rarity %, prices, economy etc. all make sense"): on the
-- first table the Rare Parrot Pirate (4-5% chance of a coin pop) was worth about +1.5 to 1.9% of a free player's
-- fishing coins, half of the Common Sand Crab's +3 to 4% Sell: a Rare beaten by a Common. The ranges are doubled
-- inside the same cap of 15: a fresh Parrot Pirate is about +3.0 to 3.6% (level with the Sand Crab), a finished
-- one 15% = the cap (9.5 x 1.575), which the 10-02 sim check already ran (31 pass, 3 warn, 0 fail). Only the
-- Rare row is in use today. Rolls made on the first table are read at the same place of the new range
-- (PetConfig.EffectiveBonus), so no pet is left behind. ONE LINE to go back: TREASURE_USE = "Before".
local TREASURE_BEFORE = {
	Common = { 2, 3 }, Uncommon = { 3, 4 }, Rare = { 4, 5 },
	Epic = { 5, 6 }, Legendary = { 6, 8 }, Mythic = { 8, 10 },
}
local TREASURE_USE = "After"
local TREASURE_AFTER = {
	Common = { 4, 5 }, Uncommon = { 6, 7 }, Rare = { 8, 9.5 },
	Epic = { 10, 11.5 }, Legendary = { 12, 13.5 }, Mythic = { 14, 15 },
}
local TREASURE = if TREASURE_USE == "Before" then TREASURE_BEFORE else TREASURE_AFTER

-- HOOKED-PET-ECON-PASS-002 (pacing audit 2026-10-02, sim estimates): the two-to-three-star EVOLVE of the three
-- early rarities was priced for a later island than their owners fish on, and a Rebirth wipes the savings. A
-- phone kid's pet sat at level 10 "Ready to evolve!" for 36% of all casts (66% in week 4), and no level-up can
-- happen while it waits: the Starter pet's last EVOLVE cost him 19.8 minutes of his income (6.7 at 25M).
-- Common 100M -> 25M, Uncommon 250M -> 60M, Rare 750M -> 200M. Epic 3B, Legendary 12B and Mythic 40B stay (rare
-- pets, a Volcano goal). Nobody pays more. ONE LINE to go back: EVOLVE_COST_USE = "Before".
local EVOLVE_COST_USE = "After"
-- (owner 2026-10-02 05:51Z: "we are changing the way bosses work. so it should be 25% boss efficiency"): the boss
-- bonus is "Boss Efficiency" and a Legendary pet's is 25%. ONE LINE to go back to the first build ("Boss Bites",
-- +20% to +130%, cap 200): BOSS_LURE_USE = "Before".
local BOSS_LURE_USE = "After"
local BOSS_LURE = if BOSS_LURE_USE == "Before" then {
	Common = { 20, 30 }, Uncommon = { 30, 45 }, Rare = { 45, 60 },
	Epic = { 60, 80 }, Legendary = { 80, 100 }, Mythic = { 110, 130 },
} else {
	Common = { 6, 8 }, Uncommon = { 9, 12 }, Rare = { 13, 16 },
	Epic = { 17, 20 }, Legendary = { 21, 25 }, Mythic = { 26, 30 },
}
local BOSS_LURE_LABEL = if BOSS_LURE_USE == "Before" then "Boss Bites" else "Boss Efficiency"
local BOSS_LURE_CAP = if BOSS_LURE_USE == "Before" then 200 else 40
local AIM = {
	Common = { 20, 25 }, Uncommon = { 30, 38 }, Rare = { 40, 50 },
	Epic = { 50, 60 }, Legendary = { 60, 70 }, Mythic = { 75, 85 },
}
local PACKER = {
	Common = { 5, 8 }, Uncommon = { 10, 14 }, Rare = { 15, 20 },
	Epic = { 22, 28 }, Legendary = { 30, 36 }, Mythic = { 40, 45 },
}

-- Protected = changes fish rolls inside ThrowRod / fish odds (owner decision D6 before wiring).
PetConfig.Archetypes = {
	Lucky = { Label = "Luck", Blurb = "Rarer fish", Ranges = STANDARD, Protected = true },
	Skipper = { Label = "Bounce", Blurb = "Extra bounces", Ranges = STANDARD, Protected = true }, -- HOOKED-PET-BOUNCE-LABEL-001 (owner 2026-10-03: "pets say +x% skip stat but should say bounce"; was "Skips" / "Extra water skips")
	Scout = { Label = "New Fish", Blurb = "Find new fish", Ranges = STANDARD, Protected = true },
	Scholar = { Label = "XP", Blurb = "More XP", Ranges = SCHOLAR, Protected = false }, -- HOOKED-PET-ECON-FIXES-001: lower ranges (see SCHOLAR above)
	Alchemist = { Label = "Mutation", Blurb = "More mutations", Ranges = STANDARD, Protected = true },
	Merchant = { Label = "Sell", Blurb = "Fish sell for more", Ranges = MERCHANT, Protected = false },
	-- HOOKED-PET-EXTRA-FISH-001: the percent is the chance, per cast that lands a fish, that the pet brings one
	-- more of the fish that cast hooked. A rarer pet picks from more of the catch and keeps the best (ExtraFish
	-- below), so it brings better fish.
	Fetcher = { Label = "Extra Fish", Blurb = "Brings extra fish", Ranges = STANDARD, Protected = true },
	-- HOOKED-PET-NEW-BENEFITS-001 (docs/HOOKED_PET_NEW_BENEFITS_001_DESIGN.md). Cap = the most the bonus can ever
	-- be, grown or not (GrownBonus clamps to it, so the card shows what the game uses). Unit = what follows the
	-- number ("%" when absent). Whole = shown and used as a whole number.
	--   Treasure  percent = chance, per cast that lands a fish, of a coin pop (PetConfig.Treasure)
	--   BossLure  percent = how much more often a boss bites while one is up (PetConfig.BossLure)
	--   Aim       percent = how much wider the cast meter's Perfect zone is (PetConfig.Aim)
	--   Packer    number  = extra bag slots
	Treasure = { Label = "Treasure", Blurb = "Finds coin treasure", Ranges = TREASURE, Protected = false, Cap = 15 },
	BossLure = { Label = BOSS_LURE_LABEL, Blurb = "Bosses bite more", Ranges = BOSS_LURE, Protected = true, Cap = BOSS_LURE_CAP },
	Aim = { Label = "Perfect Zone", Blurb = "Bigger Perfect zone", Ranges = AIM, Protected = true, Cap = 100 },
	Packer = { Label = "Bag Slots", Blurb = "More bag space", Ranges = PACKER, Protected = true, Cap = 60, Unit = "", Whole = true },
}

-- HOOKED-PET-NEW-BENEFITS-001: how the four new bonuses act. Sized in the design note above.
--   Treasure   PopCasts / ChestCasts = the coins of that many average casts for the player's island and gear
--              (MonetizationConfig.ExpectedCoinsPerCast: never multiplied by potions, boss boosts or passes);
--              one pop in ChestEvery is a chest. ToastEvery = seconds between its toasts (Auto Fishing).
--   BossLure   OddsFloor = the pet never makes a boss bite more often than 1 in this (the forged Sovereign Rod's
--              1 in 50 stays the best boss tool; the Ember Wyrm's 1 in 40 is unchanged).
--   Aim        the Perfect zone on the cast meter (0..1 along the bar, the same numbers Events.ThrowRod and the
--              client's meter have always used). Hand casts only: Auto Fishing keeps the unwidened zone.
PetConfig.Treasure = table.freeze({ PopCasts = 1, ChestCasts = 3, ChestEvery = 10, ToastEvery = 20 })
--              ReferenceOdds = the most common boss's odds (the Kraken), used only to SHOW what the pet adds
--              for a player holding the forged Sovereign Rod (PetConfig.ShownBonus below).
PetConfig.BossLure = table.freeze({ OddsFloor = 40, ReferenceOdds = 400 })
PetConfig.Aim = table.freeze({ Low = 0.4, High = 0.55, GoodLow = 0.1, GoodHigh = 0.9 })

-- The Perfect zone for a pet that widens it by `widen` (a fraction: 0.3 = 30% wider; nil or 0 = today's zone).
-- Returns low, high: a release at t is Perfect when low <= t < high. Widened evenly on both sides, at most doubled.
function PetConfig.PerfectZone(widen: any): (number, number)
	local aim = PetConfig.Aim
	local more = math.clamp(tonumber(widen) or 0, 0, 1)
	if more ~= more or more <= 0 or not PetConfig.BonusOn("Aim") then
		return aim.Low, aim.High
	end
	local half = (aim.High - aim.Low) / 2
	local mid = (aim.High + aim.Low) / 2
	return math.max(mid - half * (1 + more), aim.GoodLow), math.min(mid + half * (1 + more), aim.GoodHigh)
end

-- HOOKED-PET-EXTRA-FISH-001: how a Fetcher pet picks the fish it brings. Picks[pet rarity] = how many of the
-- cast's hooked fish it looks at before keeping the rarest (1 = any hooked fish). NeverCopy = fish rarities it
-- never brings a second one of (boss fish are left out as well). ToastEvery = seconds between its toasts.
-- PerHooked: when the chance hits, it brings one fish for every PerHooked fish the cast hooked, rounded up, at
-- most Max (a 6-fish cast: 1, a 17-fish cast: 3). Sized with tools/econ-sim/extra_fish.py so a Rare pet is
-- worth about +3% fish per cast on every island, like the other bonuses; a single fish was worth under 1% on
-- the late islands. Each extra fish takes the size of a fish of its kind from the same cast, never a mutation.
PetConfig.ExtraFish = table.freeze({
	PerHooked = 8,
	Max = 4,
	Picks = table.freeze({ Common = 1, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }),
	NeverCopy = table.freeze({ Mythic = true, Secret = true }),
	ToastEvery = 45,
})

-- Look drives the placeholder model until the Blender prefab exists (Shared.Modules.PetModels).
-- Float = hover height in studs above the ground (fliers and spirits float higher).
-- DeepOnly (owner 2026-09-30: "certain pets should only be found very deep so endgame") = only in
-- eggs marked Deep in EggConfig (the Cosmic egg, a deep-cast drop on the last islands); never in a
-- bought egg.
PetConfig.Order = {
	"MiniFisherman", "SandCrab", "PebbleFrog",
	"PufferPup", "SeagullScout", "LilOtter",
	"KoiSpirit", "HermitKnight", "ParrotPirate",
	"NarwhalCalf", "JellyWisp", "GoldenOtter",
	"KrakenHatchling", "PhoenixGull",
	"LeviathanPup",
	-- HOOKED-ALIEN-EGG-001: the two alien pets (Exclusive, see PetConfig.Pets)
	"LilAlien", "SaucerPilot",
	-- HOOKED-ALIEN-EGG-002 (owner 2026-10-02 00:19Z: "make all 3 and have them be different rarity tiers")
	"MiniMothership", "MechaInvader", "VoidOverlord",
	-- HOOKED-FIVE-PETS-001 (owner 2026-10-02 01:28Z: Cat, Dog, Lion, Giraffe, Dragon): regular pets, in the eggs'
	-- rarity pools. Kept after the first fifteen so the hatchery board's fifteen tiles still read in this order.
	"SushiCat", "FloatieGiraffe", "SurferDog", "CozyLion", "FireDragon",
	-- HOOKED-NEW-PETS-12 (Hunter 2026-10-05 02:41Z: "Add the 12 ... edgy, cool looking pets that boys ... will really
	-- desire"): regular pets in the eggs' rarity pools (the Cloud Whale and Treasure Golem are the other two of the 12)
	"ShadesShark", "GamerAxolotl", "BanditRaccoon", "NinjaPenguin", "RoboCrab",
	"VikingWalrus", "ArmoredRex", "FrostYeti", "ThunderWolf", "LavaScorpion",
	-- HUGE_PETS_001 (Hunter 2026-10-05): the two huge limited pets, sold only at the Huge Pet stands (Config.HugePetConfig)
	"CloudWhale", "TreasureGolem",
}

PetConfig.Pets = {
	MiniFisherman = {
		Name = "Mini Fisherman", Rarity = "Common", Archetype = "Scholar", FixedBonus = 8, Starter = true,
		Look = { Kind = "Fisherman", Body = Color3.fromRGB(58, 132, 222), Accent = Color3.fromRGB(255, 206, 60), Float = 0 },
	},
	SandCrab = {
		Name = "Sand Crab", Rarity = "Common", Archetype = "Merchant",
		Look = { Kind = "Crab", Body = Color3.fromRGB(240, 110, 70), Accent = Color3.fromRGB(255, 214, 150), Float = 0 },
	},
	PebbleFrog = {
		Name = "Pebble Frog", Rarity = "Common", Archetype = "Skipper",
		Look = { Kind = "Frog", Body = Color3.fromRGB(110, 196, 80), Accent = Color3.fromRGB(226, 240, 140), Float = 0 },
	},
	PufferPup = {
		Name = "Puffer Pup", Rarity = "Uncommon", Archetype = "Lucky",
		Look = { Kind = "Puffer", Body = Color3.fromRGB(255, 196, 70), Accent = Color3.fromRGB(255, 244, 200), Float = 1.2 },
	},
	SeagullScout = {
		Name = "Seagull Scout", Rarity = "Uncommon", Archetype = "Scout",
		Look = { Kind = "Bird", Body = Color3.fromRGB(240, 244, 250), Accent = Color3.fromRGB(255, 176, 40), Float = 2 },
	},
	LilOtter = {
		Name = "Lil' Otter", Rarity = "Uncommon", Archetype = "Merchant",
		Look = { Kind = "Otter", Body = Color3.fromRGB(150, 98, 60), Accent = Color3.fromRGB(232, 200, 160), Float = 0 },
	},
	KoiSpirit = {
		Name = "Koi Spirit", Rarity = "Rare", Archetype = "Alchemist",
		Look = { Kind = "Koi", Body = Color3.fromRGB(255, 250, 245), Accent = Color3.fromRGB(255, 96, 40), Float = 1.6 },
	},
	HermitKnight = {
		Name = "Hermit Knight", Rarity = "Rare", Archetype = "Skipper",
		Look = { Kind = "Hermit", Body = Color3.fromRGB(230, 120, 80), Accent = Color3.fromRGB(176, 186, 204), Float = 0 },
	},
	ParrotPirate = {
		Name = "Parrot Pirate", Rarity = "Rare", Archetype = "Scout",
		Look = { Kind = "Bird", Body = Color3.fromRGB(230, 50, 50), Accent = Color3.fromRGB(40, 120, 230), Hat = true, Float = 2 },
	},
	NarwhalCalf = {
		Name = "Narwhal Calf", Rarity = "Epic", Archetype = "Lucky",
		Look = { Kind = "Narwhal", Body = Color3.fromRGB(120, 160, 220), Accent = Color3.fromRGB(245, 240, 220), Float = 1.4 },
	},
	JellyWisp = {
		Name = "Jelly Wisp", Rarity = "Epic", Archetype = "Alchemist",
		Look = { Kind = "Jelly", Body = Color3.fromRGB(236, 120, 255), Accent = Color3.fromRGB(160, 240, 255), Float = 2 },
	},
	-- HOOKED-OTTER-ARCHIVE-001 (owner 2026-10-03: "make one of the 2 otter groups physically different besides color or
	-- remove. adds confusion" / "temporarily archive the worser/rarer ones"): the Golden Otter shares the Lil' Otter's
	-- model. Archived = no egg holds it, the Index hides it from players who never hatched one and it counts toward no
	-- pet set; owned Golden Otters keep working. ONE LINE to bring it back: delete Archived = true.
	GoldenOtter = {
		Name = "Golden Otter", Rarity = "Epic", Archetype = "Merchant", Archived = true,
		Look = { Kind = "Otter", Body = Color3.fromRGB(255, 196, 40), Accent = Color3.fromRGB(255, 244, 170), Float = 0 },
	},
	KrakenHatchling = {
		Name = "Kraken Hatchling", Rarity = "Legendary", Archetype = "Lucky", DeepOnly = true,
		Look = { Kind = "Kraken", Body = Color3.fromRGB(150, 60, 190), Accent = Color3.fromRGB(255, 150, 220), Float = 1.6 },
	},
	PhoenixGull = {
		Name = "Phoenix Gull", Rarity = "Legendary", Archetype = "Scholar",
		Look = { Kind = "Bird", Body = Color3.fromRGB(255, 120, 30), Accent = Color3.fromRGB(255, 226, 60), Fire = true, Float = 2.2 },
	},
	LeviathanPup = {
		Name = "Leviathan Pup", Rarity = "Mythic", Archetype = "Lucky", DeepOnly = true,
		Look = { Kind = "Leviathan", Body = Color3.fromRGB(40, 70, 170), Accent = Color3.fromRGB(90, 255, 230), Float = 1.8 },
	},
	-- HOOKED-ALIEN-EGG-001 (owner 2026-10-01 23:20Z: "some sort of alien pet egg, with 2 new pets and 3
	-- variants per pet", "a limited time egg"): the UFO event's alien species as pets.
	-- Exclusive = "<tier>": the pet is left out of the eggs' rarity pools. It hatches from that egg (an
	-- EggConfig tier with a Pool: the Alien Egg guarantees one of the two) and, from the UFO event's
	-- go-live on, as a very rare extra in the eggs that name it (EggConfig.Extras; owner 2026-10-01
	-- 23:51Z "INSANELY rare", 23:55Z "keep the alien pets in the game attainable through the expensive
	-- eggs, but add the alien egg as a limited option this weekend for a GUARANTEED ALIEN PET").
	-- The Index lists it once it can be hatched somewhere, or for players who own one.
	-- Neither is Lucky: a bought Legendary luck pet would undercut the deep-only Kraken Hatchling.
	LilAlien = {
		Name = "Lil' Alien", Rarity = "Epic", Archetype = "Scout", Exclusive = "Alien",
		Look = { Kind = "Fisherman", Body = Color3.fromRGB(140, 230, 50), Accent = Color3.fromRGB(176, 186, 204), Float = 0 },
	},
	SaucerPilot = {
		Name = "Saucer Pilot", Rarity = "Legendary", Archetype = "Alchemist", Exclusive = "Alien",
		Look = { Kind = "Jelly", Body = Color3.fromRGB(150, 158, 172), Accent = Color3.fromRGB(150, 255, 60), Float = 1.6 },
	},
	-- HOOKED-ALIEN-EGG-002 (owner 2026-10-02 00:02Z: "this needs 1 more, rarer pet for the alien egg and alien theme
	-- ... something more edgy maybe, that looks crazy? or a robot of some sort", 00:19Z: "Can we make all 3 and have
	-- them be different rarity tiers, with 1 being the highest possible rarity?"): Epic, Legendary and Mythic.
	-- None is Lucky (the deep-only pets keep the top luck bonuses).
	MiniMothership = {
		Name = "Mini Mothership", Rarity = "Epic", Archetype = "Merchant", Exclusive = "Alien",
		Look = { Kind = "Jelly", Body = Color3.fromRGB(92, 96, 112), Accent = Color3.fromRGB(150, 255, 60), Float = 1.6 },
	},
	MechaInvader = {
		Name = "Mecha Invader", Rarity = "Legendary", Archetype = "Skipper", Exclusive = "Alien",
		Look = { Kind = "Fisherman", Body = Color3.fromRGB(42, 40, 56), Accent = Color3.fromRGB(255, 84, 236), Float = 0 },
	},
	VoidOverlord = {
		Name = "Void Overlord", Rarity = "Mythic", Archetype = "Scholar", Exclusive = "Alien",
		Look = { Kind = "Jelly", Body = Color3.fromRGB(58, 42, 88), Accent = Color3.fromRGB(150, 255, 60), Float = 1.2 },
	},
	-- HOOKED-FIVE-PETS-001 (owner 2026-10-02 01:28Z: "Cat, Dog, Lion, Giraffe, Dragon ... unique themes ... The
	-- dragon and Dog need to be more for the boys, rest geared towards cuteness"; 02:40Z "Get it all done" on the
	-- roles below; 02:54Z "it should be mixed into existing eggs. We have too many eggs already"). Regular pets:
	-- they hatch from every egg that holds their rarity, sharing that rarity's percent with the pets already in
	-- it (each egg's rarity odds are unchanged; a Rare or Epic pet is now 1 of 5 instead of 1 of 3, and the
	-- Phoenix Gull shares Legendary with the Fire Dragon). Each fills a gap in the bonus ladder
	-- (docs/HOOKED_PET_BONUS_AUDIT_001.md): Rare Luck, Epic Skips, an XP pet between Common and Legendary, the
	-- first Sell pet above Epic, and the new Extra Fish type.
	SushiCat = {
		Name = "Sushi Cat", Rarity = "Rare", Archetype = "Fetcher",
		Look = { Kind = "Otter", Body = Color3.fromRGB(252, 250, 246), Accent = Color3.fromRGB(244, 128, 36), Float = 0 },
	},
	FloatieGiraffe = {
		Name = "Floatie Giraffe", Rarity = "Rare", Archetype = "Lucky",
		Look = { Kind = "Otter", Body = Color3.fromRGB(255, 204, 54), Accent = Color3.fromRGB(182, 106, 40), Float = 0 },
	},
	SurferDog = {
		Name = "Surfer Dog", Rarity = "Epic", Archetype = "Skipper",
		Look = { Kind = "Otter", Body = Color3.fromRGB(224, 148, 62), Accent = Color3.fromRGB(232, 52, 44), Float = 0 },
	},
	CozyLion = {
		Name = "Cozy Lion", Rarity = "Epic", Archetype = "Scholar",
		Look = { Kind = "Otter", Body = Color3.fromRGB(250, 196, 60), Accent = Color3.fromRGB(38, 188, 182), Float = 0 },
	},
	FireDragon = {
		Name = "Fire Dragon", Rarity = "Legendary", Archetype = "Merchant",
		Look = { Kind = "Leviathan", Body = Color3.fromRGB(214, 40, 36), Accent = Color3.fromRGB(255, 160, 40), Float = 0 },
	},
	-- HOOKED-NEW-PETS-12 (Hunter 2026-10-05 02:41Z: "Add the 12 like you mentioned ... Implement them into the game";
	-- 07:51Z "Auto approve the concepts"). Regular pets: they hatch from every egg that holds their rarity, sharing that
	-- rarity's percent with the pets already in it (each egg's rarity odds are unchanged). Blender models with their own
	-- palette sheet (PetAtlas2); concepts docs/pets/concepts/batch9_*.png.
	ShadesShark = {
		Name = "Shades Shark", Rarity = "Common", Archetype = "Lucky",
		Look = { Kind = "Otter", Body = Color3.fromRGB(60, 116, 204), Accent = Color3.fromRGB(228, 46, 40), Float = 0 },
	},
	GamerAxolotl = {
		Name = "Gamer Axolotl", Rarity = "Common", Archetype = "Scholar",
		Look = { Kind = "Otter", Body = Color3.fromRGB(255, 150, 192), Accent = Color3.fromRGB(130, 255, 80), Float = 0 },
	},
	BanditRaccoon = {
		Name = "Bandit Raccoon", Rarity = "Uncommon", Archetype = "Treasure",
		Look = { Kind = "Otter", Body = Color3.fromRGB(158, 154, 152), Accent = Color3.fromRGB(36, 36, 42), Float = 0 },
	},
	NinjaPenguin = {
		Name = "Ninja Penguin", Rarity = "Uncommon", Archetype = "Aim",
		Look = { Kind = "Otter", Body = Color3.fromRGB(34, 40, 74), Accent = Color3.fromRGB(222, 40, 40), Float = 0 },
	},
	RoboCrab = {
		Name = "Robo Crab", Rarity = "Uncommon", Archetype = "Skipper",
		Look = { Kind = "Hermit", Body = Color3.fromRGB(255, 120, 30), Accent = Color3.fromRGB(90, 230, 255), Float = 0 },
	},
	VikingWalrus = {
		Name = "Viking Walrus", Rarity = "Rare", Archetype = "BossLure",
		Look = { Kind = "Otter", Body = Color3.fromRGB(150, 86, 50), Accent = Color3.fromRGB(40, 50, 92), Float = 0 },
	},
	ArmoredRex = {
		Name = "Armored Rex", Rarity = "Rare", Archetype = "Merchant",
		Look = { Kind = "Otter", Body = Color3.fromRGB(128, 200, 40), Accent = Color3.fromRGB(152, 158, 172), Float = 0 },
	},
	FrostYeti = {
		Name = "Frost Yeti", Rarity = "Rare", Archetype = "Packer",
		Look = { Kind = "Otter", Body = Color3.fromRGB(244, 246, 250), Accent = Color3.fromRGB(96, 176, 255), Float = 0 },
	},
	ThunderWolf = {
		Name = "Thunder Wolf", Rarity = "Epic", Archetype = "Fetcher",
		Look = { Kind = "Otter", Body = Color3.fromRGB(74, 78, 98), Accent = Color3.fromRGB(255, 228, 40), Float = 0 },
	},
	LavaScorpion = {
		Name = "Lava Scorpion", Rarity = "Epic", Archetype = "Alchemist",
		Look = { Kind = "Hermit", Body = Color3.fromRGB(52, 46, 50), Accent = Color3.fromRGB(255, 136, 30), Float = 0 },
	},
	-- HUGE_PETS_001 (Hunter 2026-10-05 01:08Z: "Make 1 and 2 ... we need a stand to advertise it with only 1000 being
	-- sold. sell it for 799"; "needs to be the best pets in the game"). Bought for Robux at a Huge Pet stand, 1,000 of
	-- each across all servers (Config.HugePetConfig, Config.PetProductConfig Kind "HugePet"). Exclusive = "Huge": in no
	-- egg, no pet set, listed in the Index once owned. Huge = drawn this many times bigger in the world (SizeOf).
	-- The bonus is one fixed number at the Legendary level of its type, so a bought pet never beats the top egg pets.
	CloudWhale = {
		Name = "Cloud Whale", Rarity = "Mythic", Archetype = "Merchant", Exclusive = "Huge", FixedBonus = 15, Huge = 2.3,
		Look = { Kind = "Leviathan", Body = Color3.fromRGB(244, 146, 192), Accent = Color3.fromRGB(246, 244, 252), Float = 0 },
	},
	TreasureGolem = {
		Name = "Treasure Golem", Rarity = "Mythic", Archetype = "Treasure", Exclusive = "Huge", FixedBonus = 13, Huge = 2.1,
		Look = { Kind = "Hermit", Body = Color3.fromRGB(156, 92, 52), Accent = Color3.fromRGB(255, 200, 40), Float = 0 },
	},
}

-- HOOKED-PET-NEW-BENEFITS-001: which pets carry the four new bonuses. No rarity and no egg odds change: only
-- the pet's bonus type. Parrot Pirate and Seagull Scout are live pets and both gave New Fish, the one bonus
-- that stops working once the Index is full (docs/HOOKED_PET_BONUS_AUDIT_001.md); the two alien pets are not
-- on sale before the UFO event's go-live. A pet a player already owns keeps its place in the range
-- (EffectiveBonus reads RolledAs). ONE LINE to put all four back: Use = "Before".
PetConfig.NewBenefits = table.freeze({
	Use = "After",
	Carriers = table.freeze({
		ParrotPirate = "Treasure", -- Rare, was Scout (New Fish)
		SeagullScout = "Aim", -- Uncommon, was Scout (New Fish)
		MechaInvader = "BossLure", -- Legendary, Alien Egg, was Skipper (Skips)
		LilAlien = "Packer", -- Epic, Alien Egg, was Scout (New Fish)
	}),
	-- (owner 05:51Z "it should be 25% boss efficiency") a carrier whose bonus is one fixed number instead of a
	-- roll: every Mecha Invader is +25% Boss Efficiency (stars and levels still grow it, up to the type's cap).
	Fixed = if BOSS_LURE_USE == "Before" then table.freeze({}) else table.freeze({ MechaInvader = 25 }),
})
if PetConfig.NewBenefits.Use == "After" then
	for petId, archetype in pairs(PetConfig.NewBenefits.Carriers) do
		local pet = (PetConfig.Pets :: any)[petId]
		if pet and PetConfig.Archetypes[archetype] and pet.Archetype ~= archetype then
			pet.RolledAs = pet.Archetype -- the type its saved rolls were made in
			pet.Archetype = archetype
			local fixed = (PetConfig.NewBenefits :: any).Fixed[petId]
			if type(fixed) == "number" then
				pet.FixedBonus = fixed
			end
		end
	end
end

-- True while that archetype's bonus acts on the game (BonusWiring).
function PetConfig.BonusOn(archetype: any): boolean
	local wiring = PetConfig.BonusWiring
	return type(archetype) == "string" and wiring.Enabled == true and (wiring :: any)[archetype] == true
end

function PetConfig.Get(petId: any)
	return if type(petId) == "string" then PetConfig.Pets[petId] else nil
end

function PetConfig.Range(petId: string): (number, number)
	local pet = PetConfig.Pets[petId]
	if not pet then
		return 0, 0
	end
	local archetype = PetConfig.Archetypes[pet.Archetype]
	local range = archetype and archetype.Ranges[pet.Rarity]
	if not range then
		return 0, 0
	end
	return range[1], range[2]
end

-- Bonus rolled once at hatch: uniform inside the rarity range, rounded to 1 decimal.
function PetConfig.RollBonus(petId: string, rng: Random): number
	local pet = PetConfig.Pets[petId]
	if not pet then
		return 0
	end
	if pet.FixedBonus then
		return pet.FixedBonus
	end
	local lo, hi = PetConfig.Range(petId)
	return math.floor((lo + rng:NextNumber() * (hi - lo)) * 10 + 0.5) / 10
end

-- What a saved bonus is worth now. Economy tuning may lower a range later; the saved roll is kept,
-- but its effect is capped at today's maximum so a retune never needs a data migration.
function PetConfig.EffectiveBonus(petId: string, stored: number): number
	local pet = PetConfig.Pets[petId]
	if not pet then
		return 0
	end
	local cap = pet.FixedBonus or select(2, PetConfig.Range(petId))
	local value = tonumber(stored) or 0
	-- HOOKED-PET-NEW-BENEFITS-001: a pet that was moved to another bonus type (RolledAs) keeps its place in the
	-- range: a roll made in the old type's range is read at the same spot of the new one (a top roll stays a top
	-- roll). Rolls made since the move are already inside the new range and are left alone. No migration.
	local was = (pet :: any).RolledAs
	local old = was and not pet.FixedBonus and PetConfig.Archetypes[was]
	local oldRange = old and old.Ranges[pet.Rarity]
	if oldRange and oldRange[2] > oldRange[1] then
		local lo, hi = PetConfig.Range(petId)
		if (value < lo or value > hi) and value >= oldRange[1] - 0.05 and value <= oldRange[2] + 0.05 then
			local at = math.clamp((value - oldRange[1]) / (oldRange[2] - oldRange[1]), 0, 1)
			value = math.floor((lo + at * (hi - lo)) * 10 + 0.5) / 10
		end
	end
	-- HOOKED-PET-ECON-PASS-002: a Treasure roll made on the first table (4-5 for a Rare) is read at the same place
	-- of today's range (the two tables never overlap inside a rarity). No migration.
	-- (And the other way round after a switch back to "Before": a roll made on the new table keeps its place.)
	if (pet :: any).Archetype == "Treasure" and not pet.FixedBonus then
		local other = (if TREASURE_USE == "Before" then TREASURE_AFTER else TREASURE_BEFORE :: any)[pet.Rarity]
		local lo, hi = PetConfig.Range(petId)
		if other and other[2] > other[1] and (value < lo - 0.05 or value > hi + 0.05) and value >= other[1] - 0.05 and value <= other[2] + 0.05 then
			local at = math.clamp((value - other[1]) / (other[2] - other[1]), 0, 1)
			value = math.floor((lo + at * (hi - lo)) * 10 + 0.5) / 10
		end
	end
	return math.clamp(value, 0, cap)
end

function PetConfig.FormatBonus(value: number): string
	local rounded = math.floor((tonumber(value) or 0) * 10 + 0.5) / 10
	if rounded % 1 == 0 then
		return string.format("%d", rounded)
	end
	return string.format("%.1f", rounded)
end

-- "+8% XP"
function PetConfig.BonusText(petId: string, value: number): string
	local pet = PetConfig.Pets[petId]
	local archetype = pet and PetConfig.Archetypes[pet.Archetype]
	if not archetype then
		return ""
	end
	return PetConfig.BonusShort(petId, value) .. " " .. archetype.Label
end

-- HOOKED-PET-NEW-BENEFITS-001 (econ sim check 2026-10-02: "make the card honest"): the number to SHOW for a pet
-- while the player holds `rodName`. Only a Boss Bites pet differs, and only with the forged Sovereign Rod: that
-- rod already makes bosses bite 1 in 50, and the pet never passes 1 in OddsFloor, so the pet really adds about
-- +25% there, whatever its own number. Every other pet and rod: `value` unchanged.
function PetConfig.ShownBonus(petId: string, value: number, rodName: any): number
	local pet = PetConfig.Pets[petId]
	if not pet or pet.Archetype ~= "BossLure" or type(rodName) ~= "string" then
		return value
	end
	local ok, shown = pcall(function()
		local forge = (require :: any)(script.Parent:FindFirstChild("VolcanoConfig")).Forge
		if rodName ~= forge.SovereignRod then
			return value
		end
		local rule = PetConfig.BossLure
		local base = math.max(math.floor(rule.ReferenceOdds / forge.SovereignBossOddsMultiplier + 0.5), 1)
		if base <= rule.OddsFloor then
			return 0
		end
		local with = math.max(math.floor(base / (1 + math.max(value, 0) / 100) + 0.5), rule.OddsFloor)
		return math.min(math.floor((base / with - 1) * 100 + 0.5), value)
	end)
	return if ok and type(shown) == "number" then shown else value
end

-- "+8%" / "+24" (HOOKED-PET-NEW-BENEFITS-001: a bonus counted in things, like bag slots, has no percent sign).
function PetConfig.BonusShort(petId: string, value: number): string
	local pet = PetConfig.Pets[petId]
	local archetype = pet and (PetConfig.Archetypes :: any)[pet.Archetype]
	local unit = if archetype and type(archetype.Unit) == "string" then archetype.Unit else "%"
	return "+" .. PetConfig.FormatBonus(value) .. unit
end

-- HOOKED-PETS-VARIANTS-001 (owner 2026-10-01: "2 additional variations of every pet", "Implement the
-- variants you made"): rarer colour variants. Cosmetic only: a variant never changes a pet's bonus,
-- rarity or which egg holds it. The variant is rolled AFTER the pet is chosen, so every egg's pet
-- odds stay exactly as shown. One integer ticket out of Total decides the tier; the UI shows the
-- same integers, so the odds on screen are the odds rolled. Nothing else is an input (no luck,
-- level, passes or pets). Looks and names live in Config.PetVariantData (art data).
--   tier 1 = the pet as drawn, tier 2 = two stars, tier 3 = three stars (and a sparkle).
PetConfig.Variants = table.freeze({
	Total = 100,
	Weights = table.freeze({ [2] = 10, [3] = 2 }), -- 1 in 10 and 1 in 50
	MaxTier = 3,
	Star = "★",
	Colors = table.freeze({
		[2] = Color3.fromRGB(120, 226, 255),
		[3] = Color3.fromRGB(255, 214, 70),
	}),
})

-- Tier for a pet that was just chosen. `has(tier)` says whether that pet has art for the tier
-- (PetVariantData); a tier without art falls back to 1.
function PetConfig.RollVariant(rng: Random, has: ((tier: number) -> boolean)?): number
	local variants = PetConfig.Variants
	local ticket = rng:NextInteger(1, variants.Total)
	for tier = variants.MaxTier, 2, -1 do
		local weight = variants.Weights[tier] or 0
		if ticket <= weight then
			return if has == nil or has(tier) then tier else 1
		end
		ticket -= weight
	end
	return 1
end

-- Percent chance of a variant tier (tier 1 = what is left).
function PetConfig.VariantPercent(tier: number): number
	local variants = PetConfig.Variants
	if tier == 1 then
		local rest = variants.Total
		for _, weight in pairs(variants.Weights) do
			rest -= weight
		end
		return rest * 100 / variants.Total
	end
	return (variants.Weights[tier] or 0) * 100 / variants.Total
end

-- "★★" for tier 2, "★★★" for tier 3, "" for the normal pet.
function PetConfig.Stars(tier: any): string
	local n = math.floor(tonumber(tier) or 1)
	if n < 2 then
		return ""
	end
	return string.rep(PetConfig.Variants.Star, math.min(n, PetConfig.Variants.MaxTier))
end

function PetConfig.RarityColor(rarity: string?): Color3
	local info = rarity and PetConfig.Rarities[rarity]
	return if info then info.Color else PetConfig.Rarities.Common.Color
end

-- HOOKED-PET-LEVELS-001 (owner 2026-10-01 23:53Z: "When you level your pet up to level 10, you can pay gold to
-- evolve it? ... a cutscene plays when you upgrade it a star to the next variant ... so maybe its just levels
-- 1-10"): the EQUIPPED pet earns XP from catches and levels 1..MaxLevel inside its colour variant. At MaxLevel
-- the player pays coins to train it: it becomes its next colour variant (one more star) and starts again at
-- level 1. Three stars at MaxLevel is a finished pet. A pet hatched as a rarer colour has fewer steps left.
-- Enabled = false: no pet XP, no TRAIN, no level badges, and every bonus is exactly the saved roll, as before
-- (saved levels are kept, only ignored).
--   bonus = saved roll x (1 + PerStar x (stars - 1) + PerLevel x (level - 1))
-- PerStar is more than the nine level steps of one star, so a freshly evolved pet at level 1 is clearly
-- stronger than it was at level 10 (the cutscene shows old bonus -> new bonus; with equal steps the first
-- test showed "+8.7% > +8.8%").
-- (ArchetypeGrowth scales both steps alike, so that still holds for every pet.)
-- The whole growth is capped at MaxMultiplier, whatever the tables say (econ sim: tools/econ-sim, --pet).
PetConfig.Levels = table.freeze({
	Enabled = true,
	MaxLevel = 10,
	XpPerCatch = 1, -- per cast that lands at least one fish (Auto Fishing included); nothing else gives pet XP
	-- XP from level N to N + 1 for a one-star pet (9 steps: 40 catches from level 1 to 10)
	Steps = table.freeze({ 2, 2, 3, 3, 4, 5, 6, 7, 8 }),
	-- later stars need more XP (owner: "later evolves cost more coins and XP"): x the steps above
	StarXp = table.freeze({ [1] = 1, [2] = 3, [3] = 7.5 }),
	PerLevel = 0.015,
	PerStar = 0.22,
	MaxMultiplier = 1.58,
	-- Share of that growth an archetype gets (absent = all of it). XP is the one bonus that shortens the
	-- whole game (econ sim 2026-10-01: a +52% XP pet reaches Level 100 29% sooner, +43% 25% sooner; every
	-- other bonus at full growth moves it 5% or less), so XP pets grow half as much.
	-- HOOKED-PET-NEW-BENEFITS-001: the Perfect zone grows half as fast too (a finished Mythic just reaches its
	-- cap, a zone twice today's; at full growth every Legendary would sit on the cap as well).
	ArchetypeGrowth = table.freeze({ Scholar = 0.5, Aim = 0.5 }),
	-- Coins to train a level-10 pet into its next star, by the pet's rarity. [1] = one star -> two stars,
	-- [2] = two stars -> three stars. Rarer pets are found later, so their costs sit at that island's income;
	-- the last steps are a late Volcano coin sink.
	EvolveCost = table.freeze({
		[1] = table.freeze({ Common = 250e3, Uncommon = 1e6, Rare = 5e6, Epic = 50e6, Legendary = 500e6, Mythic = 2e9 }),
		[2] = table.freeze(if EVOLVE_COST_USE == "Before"
			then { Common = 100e6, Uncommon = 250e6, Rare = 750e6, Epic = 3e9, Legendary = 12e9, Mythic = 40e9 }
			else { Common = 25e6, Uncommon = 60e6, Rare = 200e6, Epic = 3e9, Legendary = 12e9, Mythic = 40e9 }),
	}),
	-- One-line switches for the visible pieces (false = that piece is not drawn; levels keep working).
	Overhead = true, -- the small star badge + level over every pet
	Cutscene = true, -- the training cutscene (false = the pet just changes, with a toast)
	-- Blender-rendered star badges (1 / 2 / 3 stars, and the gold-framed finished pet). "" = plain text stars.
	Badge = table.freeze({ [1] = "rbxassetid://110509271341195", [2] = "rbxassetid://86151389871813", [3] = "rbxassetid://109299786460942", Max = "rbxassetid://134763857803467" }),
	-- width / height of each badge picture, so the overhead row draws it at its own width beside the level
	BadgeAspect = table.freeze({ [1] = 1.079, [2] = 1.975, [3] = 2.567, Max = 2.113 }),
	-- (owner 2026-10-02 00:16Z: "Should each better variant of a pet be SLIGHTLY larger than the last to show
	-- hierarchy?" -> "yes") the pet that follows a player is this much bigger per star, and it grows in the
	-- training cutscene. All three at 1 = every star the same size, as before. Pictures in menus are framed to
	-- the pet, so they do not change.
	StarScale = table.freeze({ [1] = 1, [2] = 1.1, [3] = 1.2 }),
	-- HOOKED-PET-ECON-FIXES-001 (econ sim 006: a level-10 pet threw its XP away until the EVOLVE was paid; a phone
	-- kid lost 16% of a month's pet XP that way, and a Snack Box fed to a waiting pet did nothing). The XP a
	-- top-level pet earns while it waits is kept (save field Bank, additive) up to the whole bar of its next star
	-- and starts that star when it evolves. A finished pet (three stars) keeps nothing. false = the XP is dropped,
	-- as before (a saved Bank is kept, only ignored).
	BankXp = true,
})

-- HOOKED-PET-ECON-FIXES-001: the most XP a top-level pet with `stars` can keep for its next star: that star's
-- whole bar. 0 = nothing is kept (levels or the bank switched off, or there is no next star).
function PetConfig.BankCap(stars: any): number
	local levels = PetConfig.Levels
	local at = math.clamp(math.floor(tonumber(stars) or 1), 1, PetConfig.Variants.MaxTier)
	if levels.Enabled ~= true or levels.BankXp ~= true or at >= PetConfig.Variants.MaxTier then
		return 0
	end
	local factor = levels.StarXp[at + 1] or 1
	local total = 0
	for _, step in ipairs(levels.Steps) do
		total += math.max(math.floor(step * factor + 0.5), 1)
	end
	return total
end

-- Stars of a saved colour variant: 1 (the pet as drawn), 2 or 3.
function PetConfig.StarsOf(variant: any): number
	local n = math.floor(tonumber(variant) or 1)
	return math.clamp(if n ~= n then 1 else n, 1, PetConfig.Variants.MaxTier)
end

-- Level of a saved pet field (absent = 1).
function PetConfig.LevelOf(level: any): number
	local n = math.floor(tonumber(level) or 1)
	return math.clamp(if n ~= n then 1 else n, 1, PetConfig.Levels.MaxLevel)
end

-- XP from `level` to the next one for a pet with `stars`; nil at MaxLevel.
function PetConfig.XpToNext(stars: any, level: any): number?
	local levels = PetConfig.Levels
	local at = PetConfig.LevelOf(level)
	local step = levels.Steps[at]
	if at >= levels.MaxLevel or not step then
		return nil
	end
	local factor = levels.StarXp[PetConfig.StarsOf(stars)] or 1
	return math.max(math.floor(step * factor + 0.5), 1)
end

-- What stars and levels multiply the saved roll by (1 while Levels is off). `archetype` = the pet's, for
-- ArchetypeGrowth.
function PetConfig.GrowthMultiplier(stars: any, level: any, archetype: any?): number
	local levels = PetConfig.Levels
	if levels.Enabled ~= true then
		return 1
	end
	local growth = levels.PerStar * (PetConfig.StarsOf(stars) - 1) + levels.PerLevel * (PetConfig.LevelOf(level) - 1)
	local share = if type(archetype) == "string" then tonumber((levels.ArchetypeGrowth :: any)[archetype]) else nil
	return math.clamp(1 + growth * math.clamp(share or 1, 0, 1), 1, levels.MaxMultiplier)
end

-- The bonus a pet gives now, in percent: its saved roll (capped at today's range, EffectiveBonus) grown by
-- its stars and level, to one decimal. Server and client both show and use this one number.
function PetConfig.GrownBonus(petId: string, stored: any, stars: any, level: any): number
	local pet = PetConfig.Pets[petId]
	local base = PetConfig.EffectiveBonus(petId, tonumber(stored) or 0)
	local grown = math.floor(base * PetConfig.GrowthMultiplier(stars, level, pet and pet.Archetype) * 10 + 0.5) / 10
	-- HOOKED-PET-NEW-BENEFITS-001: an archetype's Cap holds whatever stars and levels add; Whole = whole numbers
	local archetype = pet and (PetConfig.Archetypes :: any)[pet.Archetype]
	if archetype then
		if type(archetype.Cap) == "number" then
			grown = math.min(grown, archetype.Cap)
		end
		if archetype.Whole == true then
			grown = math.floor(grown + 1e-6)
		end
	end
	return grown
end

-- Coins to train a pet with `stars` into the next star; nil when it already has the most stars.
function PetConfig.EvolveCost(petId: string, stars: any): number?
	local pet = PetConfig.Pets[petId]
	local at = PetConfig.StarsOf(stars)
	local row = PetConfig.Levels.EvolveCost[at]
	if not pet or at >= PetConfig.Variants.MaxTier or not row then
		return nil
	end
	return row[pet.Rarity]
end

-- How much bigger a pet with `stars` is drawn in the world (1 while Levels is off).
function PetConfig.StarScale(stars: any): number
	local levels = PetConfig.Levels
	if levels.Enabled ~= true then
		return 1
	end
	return math.clamp(tonumber((levels.StarScale :: any)[PetConfig.StarsOf(stars)]) or 1, 0.5, 2)
end

-- HUGE_PETS_001: how many times bigger this pet is drawn in the world (the huge pets' `Huge`; 1 for every other pet).
-- Multiplies StarScale where a pet is placed in the world (Client.Controllers.PetFollow).
function PetConfig.SizeOf(petId: any): number
	local pet = if type(petId) == "string" then (PetConfig.Pets :: any)[petId] else nil
	return if pet and type(pet.Huge) == "number" then math.clamp(pet.Huge, 1, 4) else 1
end

-- A finished pet: the most stars at the top level.
function PetConfig.IsMaxed(stars: any, level: any): boolean
	return PetConfig.StarsOf(stars) >= PetConfig.Variants.MaxTier and PetConfig.LevelOf(level) >= PetConfig.Levels.MaxLevel
end

-- HOOKED-PET-ENDLESS-001 (owner 2026-10-02 05:02Z: "maxed level pets should probably level up infinitely then,
-- but the actual stats shouldnt change past a certain point"). A finished pet (three stars at MaxLevel) keeps
-- earning XP and keeps levelling: 11, 12, ... up to TopLevel. Its bonus never moves again: the saved level
-- (Lv) stays at MaxLevel and every stat still reads PetConfig.LevelOf, so nothing in the economy changes. The
-- levels past MaxLevel are their own save field (Over, additive) and only change the number that is shown
-- (the pet row, the badge over the pet, the Top Pets board).
-- ONE SWITCH: Enabled = false and a finished pet reads MAX and earns nothing, as before (saved levels are
-- kept, only ignored).
--   XP for the next level past MaxLevel = FirstXp + MoreXp x levels already gained, never more than MostXp.
--   60 is the last step of a three-star pet (level 9 to 10); it reaches 600 at level 100 and stays there.
PetConfig.Endless = table.freeze({
	Enabled = true,
	TopLevel = 9999, -- the highest level that can be shown (the Top Pets board holds 9,999 per star)
	FirstXp = 60,
	MoreXp = 6,
	MostXp = 600,
})

-- Do pets with `stars` keep levelling past MaxLevel? (finished pets only: fewer stars evolve instead)
function PetConfig.EndlessOn(stars: any): boolean
	local rule = (PetConfig :: any).Endless
	return type(rule) == "table" and rule.Enabled == true and PetConfig.Levels.Enabled == true
		and PetConfig.StarsOf(stars) >= PetConfig.Variants.MaxTier
end

-- Levels gained past MaxLevel, from the saved field (absent = 0).
function PetConfig.OverOf(over: any): number
	local n = math.floor(tonumber(over) or 0)
	local most = math.max(math.floor(tonumber(PetConfig.Endless.TopLevel) or 0) - PetConfig.Levels.MaxLevel, 0)
	return math.clamp(if n ~= n then 0 else n, 0, most)
end

-- XP from level MaxLevel + `over` to the next one; nil at TopLevel.
function PetConfig.EndlessXp(over: any): number?
	local rule = PetConfig.Endless
	local at = PetConfig.OverOf(over)
	if PetConfig.Levels.MaxLevel + at >= rule.TopLevel then
		return nil
	end
	return math.max(math.floor(math.min(rule.FirstXp + rule.MoreXp * at, rule.MostXp) + 0.5), 1)
end

-- The level to SHOW for a saved pet: its level, plus the levels past MaxLevel of a finished pet. Stats never
-- read this (they read LevelOf).
function PetConfig.ShownLevel(stars: any, level: any, over: any): number
	local at = PetConfig.LevelOf(level)
	if at >= PetConfig.Levels.MaxLevel and PetConfig.EndlessOn(stars) then
		return at + PetConfig.OverOf(over)
	end
	return at
end

-- "250K", "1.5M", "12B" (coin costs on buttons)
function PetConfig.FormatCoins(amount: any): string
	local n = math.max(tonumber(amount) or 0, 0)
	for _, unit in ipairs({ { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
		if n >= unit[1] then
			local value = math.floor(n / unit[1] * 10 + 0.5) / 10
			return (if value % 1 == 0 then string.format("%d", value) else string.format("%.1f", value)) .. unit[2]
		end
	end
	return string.format("%d", n)
end

-- HOOKED-PET-RELEASE-001 (owner 2026-10-02 00:28Z: "should we give people some sort of currency if they get a
-- duplicate, so they can use it to purchase another egg"; 00:41Z: "So basically you can dismantle your pets for
-- currency?"; 02:06Z: "Yes do whats recommended"). A player may release a pet they do not want for Egg Tokens
-- and spend the tokens on fishing eggs. Always the player's own choice: nothing is converted by itself.
-- ONE SWITCH: Enabled = false and the RELEASE button and the token egg rows are gone and the server refuses
-- both; saved tokens are kept.
--   Tokens[rarity]   tokens for a one-star pet of that rarity
--   StarMult[stars]  times that for a pet HATCHED with more stars. Stars added by evolving never count: coins
--                    must not turn into eggs (eggs come from fishing or Robux only).
--   EggPrice[tier]   token price of an egg. Fishing eggs only: never Royal or Alien (they are sold) and never
--                    the deep-only Cosmic Egg. A token egg goes in the bag and hatches on its timer, like a
--                    fished one.
--   Sized so an egg gives back about a fifth of its price when every pet from it is released (Basic 1.9 of
--   10, Shiny 4.0 of 25, Golden 10.7 of 75): no loop. Server.Verifiers.PetsReleaseVerifier re-checks it
--   against the egg pools.
--   KeepOne   the last pet can never be released.      ShowFrom   pets owned before the RELEASE strip shows.
--   LogSize   the last released pets stay in the save (Data.Pets.ReleaseLog), so support can see them.
PetConfig.Release = table.freeze({
	Enabled = true,
	Tokens = table.freeze({ Common = 1, Uncommon = 2, Rare = 5, Epic = 15, Legendary = 60, Mythic = 300 }),
	StarMult = table.freeze({ [1] = 1, [2] = 3, [3] = 8 }),
	EggPrice = table.freeze({ Basic = 10, Shiny = 25, Golden = 75 }),
	EggOrder = table.freeze({ "Basic", "Shiny", "Golden" }),
	KeepOne = true,
	ShowFrom = 2,
	LogSize = 10,
})

function PetConfig.ReleaseOn(): boolean
	local rule = (PetConfig :: any).Release
	return type(rule) == "table" and rule.Enabled == true
end

-- The stars a pet was hatched with: its stars now, less the times it was evolved.
function PetConfig.HatchStars(variant: any, trained: any): number
	local evolved = math.max(math.floor(tonumber(trained) or 0), 0)
	return math.clamp(PetConfig.StarsOf(variant) - evolved, 1, PetConfig.Variants.MaxTier)
end

-- Egg Tokens for releasing a pet, or nil (switched off, or a pet this config does not know).
function PetConfig.ReleaseTokens(petId: any, variant: any, trained: any): number?
	local pet = PetConfig.Pets[petId]
	if not PetConfig.ReleaseOn() or not pet then
		return nil
	end
	local rule = PetConfig.Release
	local base = tonumber((rule.Tokens :: any)[pet.Rarity])
	local mult = tonumber((rule.StarMult :: any)[PetConfig.HatchStars(variant, trained)]) or 1
	if not base or base <= 0 or mult <= 0 then
		return nil
	end
	return math.max(math.floor(base * mult + 0.5), 1)
end

-- The token price of an egg, or nil when tokens cannot buy it.
function PetConfig.TokenEggPrice(tier: any): number?
	if not PetConfig.ReleaseOn() or type(tier) ~= "string" then
		return nil
	end
	local price = tonumber((PetConfig.Release.EggPrice :: any)[tier])
	return if price and price >= 1 then math.floor(price) else nil
end

-- Load-time checks: a bad row fails loudly in Studio instead of shipping.
do
	local seen = {}
	for _, id in ipairs(PetConfig.Order) do
		local pet = PetConfig.Pets[id]
		assert(pet, "PetConfig.Order names a missing pet: " .. id)
		assert(PetConfig.Rarities[pet.Rarity], "PetConfig: bad rarity for " .. id)
		assert(PetConfig.Archetypes[pet.Archetype], "PetConfig: bad archetype for " .. id)
		assert(pet.Look and pet.Look.Kind, "PetConfig: missing Look for " .. id)
		assert(not seen[id], "PetConfig: duplicate id " .. id)
		seen[id] = true
		pet.Id = id
	end
	for id in pairs(PetConfig.Pets) do
		assert(seen[id], "PetConfig.Pets has a pet missing from Order: " .. id)
	end
	table.freeze(PetConfig.Order)
end

-- HOOKED-PET-REBIRTH-MARK-001 (owner 2026-10-02 17:17Z "Make all of your recommended changes"; idea 30, "Pets
-- get a mark when you Rebirth"). The lead pet that is out at a Rebirth gets +1 on a saved count (Owned[uid].Marks).
-- Show only: a mark gives no coins, XP, odds, eggs or tokens and no roll or payout ever reads it.
--   Enabled      false = no mark is given or drawn; saved marks stay in the save untouched.
--   Cap          the most marks a pet SHOWS (the save keeps counting, so nothing earned is thrown away). 10 is
--                the Rebirth count of the last aura and of the coin bonus cap (VoyageConfig).
--   MinCatches   catches the pet must be out for since the last Rebirth (0 = no rule): the pet you fished with
--                gets the mark, not one swapped in a second before.
--   MomentDelay  seconds after the Rebirth before the line and the pop (after the landing message has cleared).
--   Tiers        colour steps at the same Rebirth counts as the player's own auras (VoyageConfig.TrailMilestones).
--   Row / Card   the numbered chip on the pet's picture in the PETS list; the line on the tap card.
--   Overhead     a soft glow in the step's colour behind the level badge over the pet (off until the owner has
--                seen it).
PetConfig.RebirthMark = table.freeze({
	Enabled = true,
	Cap = 10,
	MinCatches = 5,
	MomentDelay = 16,
	Tiers = table.freeze({
		table.freeze({ At = 1, Name = "Ocean", Colors = table.freeze({ Color3.fromRGB(60, 200, 255) }) }),
		table.freeze({ At = 3, Name = "Royal", Colors = table.freeze({ Color3.fromRGB(200, 110, 255) }) }),
		table.freeze({ At = 5, Name = "Gold", Colors = table.freeze({ Color3.fromRGB(255, 235, 110) }) }),
		table.freeze({ At = 10, Name = "Rainbow", Colors = table.freeze({
			Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 200, 60), Color3.fromRGB(90, 230, 90),
			Color3.fromRGB(60, 180, 255), Color3.fromRGB(190, 90, 255),
		}) }),
	}),
	Row = true,
	Card = true,
	Overhead = false,
	-- player lines: 8 words or fewer, one idea each (rows in assets/localization/rebirth_mark_rows.py)
	Lines = table.freeze({
		First = "Your pet earned a Rebirth Mark!",
		Next = "Rebirth Mark %d!",
		CardOne = "1 Rebirth together",
		Card = "%d Rebirths together",
		CardCap = "%d+ Rebirths together",
	}),
})

function PetConfig.MarkOn(): boolean
	local rule = (PetConfig :: any).RebirthMark
	return PetConfig.Enabled == true and type(rule) == "table" and rule.Enabled == true
end

-- The number a pet shows for its saved marks: 0 while the switch is off, never above Cap.
function PetConfig.MarksShown(saved: any): number
	if not PetConfig.MarkOn() then
		return 0
	end
	local n = math.floor(tonumber(saved) or 0)
	if n ~= n or n < 0 then
		n = 0
	end
	return math.min(n, math.max(math.floor(tonumber(PetConfig.RebirthMark.Cap) or 0), 0))
end

-- The colour step a shown number has reached (nil for 0), and whether the saved count is past what is shown.
function PetConfig.MarkTier(shown: any): any
	local n = math.floor(tonumber(shown) or 0)
	local best = nil
	for _, tier in ipairs(PetConfig.RebirthMark.Tiers) do
		if n >= tier.At then
			best = tier
		end
	end
	return best
end

-- The tap card's line for a pet: "1 Rebirth together", "4 Rebirths together", "10+ Rebirths together" (the
-- number shown stops at Cap, so the "+" keeps the sentence true for a pet that has more). nil for no marks.
function PetConfig.MarkCardLine(shown: any): string?
	local n = math.floor(tonumber(shown) or 0)
	if n <= 0 or not PetConfig.MarkOn() then
		return nil
	end
	local lines = PetConfig.RebirthMark.Lines
	if n == 1 then
		return lines.CardOne
	end
	return string.format(if n >= PetConfig.RebirthMark.Cap then lines.CardCap else lines.Card, n)
end

return PetConfig
