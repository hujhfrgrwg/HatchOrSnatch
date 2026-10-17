--!strict
-- PointsConfig (HOS-PTS-001, 17 Oct 2026): match points, revive, the egg ladder and the podium. Every number
-- and switch in one table; ReplicatedStorage.EOS.Shared so clients show the same numbers the server pays.
--
-- Points: survive a crossing +100 (a Hero who gets across alone +200, HeroChickenConfig.HERO_POINTS), juke +10,
-- revive +25, catch +50, snatch +25 / +50 / +100 for a Rare / Epic / Legendary egg. Points are the match XP 1:1
-- (replacing EconomyConfig.xpFor and the Hero's extra crossings of XP while Enabled). Gold: the match's pot is
-- what EconomyConfig.goldFor would have paid everyone; each eligible player keeps the PLAYED floor and the rest
-- of the pot is shared by points (no new Gold). Gems are never touched.
-- Popups never pause play.

local Shared = script.Parent
local HC = require(Shared:WaitForChild("HeroChickenConfig"))

local PointsConfig = {}

PointsConfig.Enabled = true -- the switch: false = no points, XP and Gold exactly as before

PointsConfig.Points = {
	SAFE = 100, -- reached the safe zone this crossing
	HERO_SAFE = HC.HERO_POINTS, -- the Hero of the crossing got across alone (one number: HeroChickenConfig)
	JUKE = 10,
	REVIVE = 25,
	CATCH = 50,
	SNATCH = { rare = 25, epic = 50, legendary = 100 }, -- by the egg the caught Runner carried (on top of CATCH)
}

-- a juke: a Catcher's lunge or stab misses a Runner standing this close when it was thrown
PointsConfig.Juke = {
	RADIUS = 6, -- studs, flat, Catcher root to Runner root when the attack starts
	CHECK_AFTER = 0.45, -- seconds after the attack: still a free Runner = juked (lunge strike 0.2 s, stab fall 0.17 s)
	PAIR_COOLDOWN = 4, -- seconds: one juke per Catcher and Runner pair this often
}

PointsConfig.Xp = { PER_POINT = 1 } -- match XP = points x this (VIP / 2x XP passes still add on top)

-- Gold: the pot split (see above). FLOOR = what every eligible player keeps (EconomyConfig.GOLD.ACTIVE, "PLAYED")
PointsConfig.Gold = { SPLIT = true, FLOOR_LABEL = "PLAYED", SHARE_LABEL = "POT SHARE" } -- HOS-PTS-001: "points" never sits next to a Gold amount (label audit)

-- revive (ReviveService): a downed Runner can be brought back by a teammate holding the prompt
PointsConfig.Revive = {
	Enabled = true,
	WINDOW = 6, -- seconds a caught Runner stays revivable; after that they're out as before
	HOLD = 1.5, -- seconds to hold E (tap and hold on phone, X on a controller)
	RANGE = 6, -- studs: the prompt's activation distance (= PROMPT_RADIUS)
	-- the ring billboard (client, checked at ~10 Hz): hidden for everyone; free Runners within SHOW_RADIUS see the
	-- ring pop in (0.6 -> 1 + fade, 0.2 s, ease out back; out 0.15 s), within PROMPT_RADIUS the key cap pops in too.
	-- Catchers and far players never see it.
	REVIVE_SHOW_RADIUS = 20,
	REVIVE_PROMPT_RADIUS = 6,
	CHECK_HZ = 10,
	MOVE_CANCEL = 3, -- studs the reviver may drift during the hold before it cancels
	REVIVES_PER_CROSSING = 1, -- how often one Runner may revive someone per crossing
	REVIVED_PER_CROSSING = 1, -- how often one Runner may be revived per crossing
}

-- the egg ladder (EggLadder): the carried egg is a rarity, not a level. Crossings 1, 3 and 5 may upgrade it,
-- crossings 2 and 4 add a small boost to the next roll. Rarity sets the egg's look and the piece it pays.
PointsConfig.Ladder = {
	Enabled = true,
	ORDER = { "common", "rare", "epic", "legendary" },
	-- the TierConfig level each rarity shows as (the first level of that look group), so the carried egg, the HUD
	-- and the Catcher's steal cap keep working on levels
	LEVEL = { common = 1, rare = 3, epic = 5, legendary = 7 },
	-- per crossing: rolls tried top-down, from = the egg it applies to, chance 0..1 (first hit wins)
	STEPS = {
		[1] = { { from = "common", to = "rare", chance = 1 } },
		[3] = { { from = "rare", to = "legendary", chance = 0.02 }, { from = "rare", to = "epic", chance = 0.10 } },
		[5] = { { from = "epic", to = "legendary", chance = 0.01 }, { from = "rare", to = "epic", chance = 0.10 } },
	},
	BOOST = { [2] = 0.25, [4] = 0.25 }, -- the next upgrade roll's chances x (1 + this): 2% -> 2.5%, 10% -> 12.5% (used up by it)
	-- the egg piece each rarity pays. Legendary has no piece yet (ProfileLogic refuses "crowned"): until the
	-- Legendary piece ships it pays LEGENDARY_FALLBACK
	PIECE = { common = "common", rare = "rare", epic = "epic", legendary = "crowned" },
	LEGENDARY_FALLBACK = "epic",
}

-- between crossings: the board in WAVE_END (4 s; the Hero or Chicken pick starts at about 4 s). Seconds.
-- The server sends it at SEND after the crossing ends; the client times the rest from when it arrives.
PointsConfig.Round = {
	SEND = 0.5, -- after the crossing ends
	AFTER_POP = 1.0, -- opens no sooner than this after your last points pop (max OPEN_LATEST)
	AFTER_BANNER = 0.2, -- ...and than your SAFE! / CAUGHT! / TOO SLOW! banner's 1.4-1.6 s hold ending (its exit takes about 0.2 s)
	OPEN_LATEST = 1.3, -- the latest it waits for those, from arrival (caught right at the end: opens about 1.8 s in)
	OPEN = 0.25, -- fade + scale in (Quad Out)
	COUNT = 0.5, -- the +N PTS pills count up
	SLIDE_AFTER = 0.1, -- after the open ends
	SLIDE = 0.9, -- rows to their new ranks (Cubic InOut; climbers pass over the rows they overtake)
	CLOSE_AT = 2.85, -- from arrival: starts closing at about 3.35 s into the 4 s break
	CLOSE = 0.2, -- fade + scale out (Quad In): clear screen by about 3.55 s, about 0.5 s before the pick (4.04-4.18 s measured)
	DIM = 0.82, -- background dim transparency while it's up (the line-up happens behind it)
}

-- 5 crossings (GameConfig.Match.FIXED_CROSSINGS is the live number; this is what the podium banner says)
PointsConfig.Podium = {
	Enabled = false, -- Hunter 17 Oct: "the podium cutscene is too much": off, kept for later (PodiumService, ServerStorage.HOS_Podium)
	TOP = 3,
	WIDE = 1.6, -- seconds on the wide shot
	PUSH = 2, -- seconds on each of 3rd, 2nd, 1st
	CONFETTI = 1.2,
	EGG = 3, -- the egg reveal
	DEFAULT_EMOTE = "thumbs_up", -- the top 3 with no favourite emote do this (there is no cheer emote yet)
}

function PointsConfig.rarityForLevel(level: number?): string
	local L = PointsConfig.Ladder.LEVEL
	local lv = level or 1
	if lv >= L.legendary then
		return "legendary"
	elseif lv >= L.epic then
		return "epic"
	elseif lv >= L.rare then
		return "rare"
	end
	return "common"
end

-- the piece a rarity pays today (Legendary falls back until its piece exists)
function PointsConfig.pieceFor(rarity: string): string
	local LD = PointsConfig.Ladder
	local m = LD.PIECE[rarity] or "common"
	if m == "crowned" then
		return LD.LEGENDARY_FALLBACK
	end
	return m
end

return PointsConfig
