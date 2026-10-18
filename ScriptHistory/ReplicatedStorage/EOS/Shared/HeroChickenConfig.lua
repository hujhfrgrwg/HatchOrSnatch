--!strict
-- HeroChickenConfig (HOS-HOC-001, 17 Oct): every number for the Hero or Chicken pick in one table.
-- At the start of every crossing the lead Catcher picks one Runner, who chooses HERO (crosses alone
-- first, the group waits on the start line, then goes) or CHICKEN (crosses with everyone).
-- No extra protection; a caught Hero joins the Catchers like anyone caught; a Hero who gets across
-- earns double crossing value (Gold + XP, never Gems) and one bonus egg-piece roll.
-- Skipped when only one Runner is left (their Last Runner Standing moment plays instead).

local HeroChickenConfig = {}

HeroChickenConfig.Enabled = true -- the switch: false = crossings start straight away, as before
HeroChickenConfig.MIN_RUNNERS = 2 -- fewer Runners than this at a crossing's start = no pick
HeroChickenConfig.OTHERS = "WAIT_THEN_GO" -- the group waits on the start line during a Hero run

-- server timings (seconds)
HeroChickenConfig.Timing = {
	-- beat a: the lead Catcher intro, the rush to the Runner line, then the pick itself. The whole
	-- window is the Catcher's countdown; picks are taken from PICK_OPENS_AT on.
	INTRO = 3.2, -- the lead Catcher: a slow push toward them (comfort: under 4 studs/s)
	RUSH = 0.4, -- the 0.2 s dip through black from the Catcher to the Runner line (+ settle)
	PICK_WINDOW = 9.2, -- whole beat a; no pick by then = the hovered Runner, else a random one
	-- beat b: the picked Runner chooses
	PUSH_IN = 0.7, -- spotlight locks, flash, camera push-in before the buttons show
	CHOICE_WINDOW = 5, -- whole beat b; no choice by then = CHICKEN
	-- beat c: the reveal, then the swoop back to the gameplay camera
	REVEAL = 2.0,
	SWOOP = 1.3,
	READY = 1.5, -- HUD back, "<name> is going HERO" + 3-2-1 before the crossing opens
	-- the Hero run
	HERO_MAX = 12, -- the group goes after this even if the Hero is still out there
	SUCCESS = 3.4, -- the Hero made it: HERO! cutscene on them in the safe zone (~3 s hold + fade)
	SUCCESS_FADE = 0.35, -- the quick fade to black at the end of it
	GROUP_READY = 2.5, -- "HERO ATTEMPT COMPLETE - the group goes next" + GET READY countdown
}
HeroChickenConfig.PICK_OPENS_AT = HeroChickenConfig.Timing.INTRO + HeroChickenConfig.Timing.RUSH

-- forced lineup at the start of every crossing (Hunter, 17 Oct): Services.CrossingLineup
HeroChickenConfig.Lineup = {
	RUNNER_SPACING = 4, -- studs between Runners in a row (shoulder to shoulder)
	ROW_GAP = 4.5, -- extra rows go this far behind the front row
	FRONT_INSET = 4, -- the front row stands this far inside the start zone's field-side edge
	EDGE_MARGIN = 6, -- keep this far from the zone's side walls
	LEAD_STEP = 4, -- the lead Catcher stands this far in front of the Catchers' row
	HERO_STEP = 5, -- a Runner who goes HERO steps this far out of the row toward the field
}

-- NPCs
HeroChickenConfig.Npc = {
	HOVER_EVERY = { 0.45, 0.9 }, -- an NPC Catcher's spotlight hops between Runners this often
	PICK_AT = { 4.8, 7.4 }, -- seconds into beat a when an NPC Catcher picks (after PICK_OPENS_AT)
	CHOOSE_AT = { 2.8, 4.2 }, -- seconds into beat b when an NPC Runner chooses
	HERO_CHANCE = 0.4,
}

-- the lead Catcher's gesture (Hunter 17 Oct: "the lead catcher should probably do an animation"): Services.CatcherGesture
HeroChickenConfig.Gesture = {
	CONSIDER_ID = 131022066837723, -- published 17 Oct (group 228184582, Open Cloud); 0 = consider plays in Studio only
	POINT_ID = 0, -- 0 = procedural point on every server (shoulder C0 aimed at the picked Runner)
	CHIN_RAISE = 115, -- degrees the right arm comes up toward the chin while choosing
	HEAD_SCAN = 25, -- degrees the head turns either way, scanning the line
	SCAN_SECONDS = 2.4, -- one scan left-right-left
	TURN_SECONDS = 0.3, -- the turn to face the picked Runner
	ARM_SECONDS = 0.3, -- the procedural arm raise (with the turn)
	POINT_SHOT = 1.2, -- the over-the-shoulder shot of the point before the picked Runner's push-in
	OTS = { BACK = 3, SIDE = 7.5, UP = 0.2, AHEAD = 7 }, -- that shot: studs behind / right of / above the Catcher's head (~8.1 away). Mostly side-on, so the arm reads in profile: Catcher left of frame, arm across it, Runners right
}

-- reward for a Hero who gets across (placeholder until Hunter confirms point values)
HeroChickenConfig.HERO_POINTS = 200 -- the HERO! banner's "+200 PTS" chip (a normal crossing = 100)
HeroChickenConfig.HERO_CROSSING_MULT = 2 -- the Hero crossing pays this many crossings of Gold + XP
-- one bonus egg-piece roll (weights); granted with the match settlement
HeroChickenConfig.BONUS_ROLL = { { "common", 70 }, { "rare", 25 }, { "epic", 5 } }

-- client look
HeroChickenConfig.Look = {
	SPOT_COLOR = Color3.fromRGB(255, 236, 170),
	HERO_GOLD = Color3.fromRGB(255, 196, 46),
	CHICKEN_WHITE = Color3.fromRGB(245, 245, 240),
	CATCHER_RED = Color3.fromRGB(235, 64, 64),
	DOLLY_HEIGHT = 1.0, -- the choosing dolly, studs above the Runners' root (about chest height)
	DOLLY_DISTANCE = 12, -- comfort: never closer than 12 studs to a person
	CLOSE_DISTANCE = 12, -- the picked Runner's shot: knees-up at the closest
	FOV = 70, -- comfort (GameConfig.Cinematic.COMFORT): the gameplay FOV, no FOV animation
	CLOSE_FOV = 70,
	PUSH = { from = 20, to = 11, seconds = 3.2, fovSqueeze = 8 }, -- gentle push-ins: sine in-out dolly, peak ~4.4 studs/s, FOV 70 -> 62 (peak ~3.9 deg/s); COMFORT: <= 5 studs/s, <= 12 deg/s FOV
	PULL = { from = 10, to = 14, seconds = 2.0 }, -- CHICKEN: a slow comedic pull-back
	MOVE_SPEED = 3.5, -- comfort: eased camera moves stay under 4 studs/s (and 20 deg/s)
	DIP = 0.2, -- comfort: shots change with a 0.2 s dip through black (no fast moves, no flashes)
	TAG_RANGE = 60, -- during the Hero run other overhead tags fade past this many studs (no far clump)
	NAME_TAGS = "SPOTLIT", -- during the pick only the spotlit Runner's overhead tag shows; held Runners' tags hide
}

return HeroChickenConfig
