--!strict
-- GameConfig: every tunable for Evolve or Steal in one place.
-- All numbers are PLAYTEST STARTING VALUES (GDD v0.2), not balance commitments.
-- Tier / reward / quest numbers live in TierConfig, RewardConfig and QuestConfig.

local GameConfig = {}

GameConfig.VERSION = "0.4.0"

-- Match phase lengths in seconds (GDD section 2 table).
GameConfig.Timing = {
	INTERMISSION = 15, -- lobby countdown once enough players are ready
	ROLE_REVEAL = 5, -- roles shown, gates closed
	CROSSING = 30, -- one wave
	WAVE_TRANSITION = 4, -- SAFE / level-up / flip sides
	RESULTS = 11, -- results screen before the next intermission (HOS-PTS-001: back to 11, the podium is off)
	WATCHDOG_SLACK = 25, -- extra seconds beyond the planned match length before a forced end
	CONVERSION_GRACE = 1.5, -- a converted Catcher cannot tag for this long
	WAVE_START_PROTECTION = 0.75, -- Runners can't be tagged in the first moments of a wave
	-- Catchers (players and NPCs) are held still through the role reveal / side flip and for this long
	-- after a crossing opens, so they can never move before the Runners (developer, Oct 15)
	CATCHER_RELEASE_DELAY = 0.75,
	TICK = 0.1, -- server match tick (zones, contact scan)
}

GameConfig.Match = {
	MIN_PLAYERS = 4, -- real players needed for a match to save rewards (fewer = practice match, never saved)
	MIN_TO_START = 1, -- real players needed to start a match at all (NPCs fill the rest)
	MAX_PLAYERS = 16,
	-- initial Catchers by roster size: first row whose maxPlayers >= roster size
	INITIAL_CATCHERS = {
		{ maxPlayers = 9, catchers = 1 },
		{ maxPlayers = 16, catchers = 2 },
	},
	-- Studio only: workspace attribute EOS_DevMinPlayers lowers MIN_PLAYERS for automation.
	-- Matches started below MIN_PLAYERS this way are TEST matches and never save rewards.
	DEV_MIN_PLAYERS_ATTRIBUTE = "EOS_DevMinPlayers",
	-- minimum distance moved during a match to count as an active participant (anti-AFK farm)
	MIN_ACTIVE_DISTANCE = 30,
	-- How a match ends (developer, Oct 2026): crossings keep coming until the Runners string together
	-- CLEAN_STREAK_TO_WIN clean crossings in a row (nobody caught), the last Runner makes a solo
	-- crossing, or no Runners are left. MAX_CROSSINGS_SAFETY only stops a match that somehow never ends.
	CLEAN_STREAK_TO_WIN = 3,
	TIMEOUT_BREAKS_STREAK = true, -- a Runner who doesn't make it in time also spoils the crossing
	MAX_CROSSINGS_SAFETY = 40,
	-- HOS-PTS-001: a match is FIXED_CROSSINGS crossings (nil = the open-ended clean-streak rule above). It ends early
	-- only when no Runners are left; SOLO_WIN_ENDS_MATCH = true brings back "the last Runner's solo crossing wins it".
	FIXED_CROSSINGS = 5 :: number?,
	SOLO_WIN_ENDS_MATCH = false,
	-- made it across = stays across (developer, Oct 15): once a safe Runner is this far inside the finish
	-- zone, the zone's invisible wall closes behind them (for them only) until the next crossing; one who
	-- steps back out before that (more than SAFE_ESCAPE_MARGIN into the field) is put back in the zone
	SAFE_LOCK_DEPTH = 3, -- studs: clear of the wall (1.5 thick, on the zone's edge) so it never pushes them out
	SAFE_ESCAPE_MARGIN = 1,
}

-- Field Gems (HOS-GEMS-002, 17 Oct; after the reference game Hunter showed): a few Gems lie on the field each
-- crossing, more in later crossings. Runners who aren't safe yet pick one up by walking into it. Each is worth
-- 1 Gem, paid with the match's Gems at settlement (EconomyConfig.GEMS.FIELD_CAP per match, inside CAP).
GameConfig.FieldGems = {
	ENABLED = true, -- kill switch
	PER_CROSSING = { 1, 2, 2, 3 }, -- Gems on the field in crossing 1, 2, 3, 4+ (the last entry repeats)
	FULL_AT_PLAYERS = 20, -- real players for the full count; fewer scale it down (never below 1)
	RUNNERS_ONLY = true, -- Catchers can't take them (they'd camp the Gems instead of chasing)
	PICKUP_RADIUS = 4, -- studs, flat, from the root
	ZONE_INSET = 14, -- studs: never this close to a safe zone (no free Gems on the doorstep)
	CENTER_GAP = 10, -- studs: never on the Catchers' start line
	EDGE_INSET = 10, -- studs from the side walls
	MIN_SPACING = 18, -- studs between two Gems
	HOVER = 2, -- studs above the ground
	TICK = 0.1,
}

-- Capture (tag) rules. Server validates everything; the client only sends hints.
GameConfig.Capture = {
	CONTACT_RADIUS = 3.4, -- body contact: server scan + client hint
	TAG_RADIUS = 6.5, -- manual TAG action reach (click / tap / R2 / E)
	LAG_TOLERANCE = 3.2, -- extra studs the server allows for latency on client-sent tags (raised with the faster 28 speed)
	TAG_COOLDOWN = 1.0, -- manual tag (stab) cooldown per Catcher (developer, Oct 15: was 0.6, too quick; the stab
	-- clip takes ~0.8 s, so a new stab never cuts the last one off)
	LINE_OF_SIGHT = true, -- reject tags through arena structures
	MAX_VERTICAL_GAP = 7, -- reject tags across big height differences
	-- hits go where the camera aims: a swing takes the Runner nearest the crosshair's direction
	-- within this half-angle (flat), and the arm + knife swing toward the crosshair point
	SWING_CONE = math.rad(75),
	AIM_RANGE = 80, -- studs: how far the crosshair ray looks for what you're aiming at
	ARM_MAX_YAW = math.rad(55), -- how far the hit can bend left/right of the chest
	ARM_MAX_UP = math.rad(60),
	ARM_MAX_DOWN = math.rad(70),
	-- caught = ragdoll: the Runner falls the way they were hit and STAYS on the floor for the rest of
	-- the crossing (developer, Oct 15); they get up when it ends, as Catchers
	RAGDOLL_SETTLE = 1.2, -- seconds of real fall, then the body locks in the pose it landed in (no physics while it lies there)
	RAGDOLL_STAY_DOWN = true,
	RAGDOLL_SECONDS = 2.5, -- only used if RAGDOLL_STAY_DOWN is false: time down before getting back up
	RAGDOLL_PUSH = 30, -- studs/s away from the Catcher
	RAGDOLL_LIFT = 14, -- studs/s up, so the fall reads
}

-- Movement feel (Section 3). Momentum values come from the teammate's Huss Valley reference pass
-- (R6ReferenceAnimations "Huss Valley reference v2"); role top speeds are the server's.
GameConfig.Movement = {
	LOBBY_SPEED = 26,
	RUNNER_SPEED = 31, -- (developer, Oct 15: 28 -> 31, "slightly faster")
	CATCHER_SPEED = 31,
	JUMP_HEIGHT = 0, -- no jumping: Space dashes instead (the touch jump button hides itself at 0)
	-- momentum, measured from the developer's Huss Valley reference clip (A/D reversals at 60 fps):
	-- speed you're no longer pushing for dies almost at once, then you set off the new way with a
	-- quick kick to about a third of top speed and build the rest more slowly. No swivelling at speed.
	-- Live overrides: ReplicatedStorage.EOS_Tuning attributes (same names in CamelCase).
	DECEL = 160, -- studs/s^2: killing sideways / backwards motion on a direction change (~0.14 s)
	STOP_DECEL = 120, -- studs/s^2: letting go of the keys (22 -> 0 in ~0.18 s)
	KICK_FRACTION = 0.35, -- the first part of a start happens almost instantly...
	KICK_ACCEL = 160, -- ...at this rate (studs/s^2)
	ACCELERATION = 30, -- studs/s^2 for the rest of the way to top speed (0 -> 28 in ~0.65 s)
	-- turns taken at speed (A+W -> W+D, W -> W+D): the part of your motion both directions share (the
	-- held W) carries on; only the part that flipped brakes and builds back, at this faster rate.
	-- A+W -> W+D at 28 dips to ~20 and is back to full in ~0.35 s. Full reversals (A -> D) are unchanged.
	TURN_ACCELERATION = 60,
	TURN_MIN_SPEED = 0.25, -- fraction of top speed: slower than this, a key change is a fresh start
	TURN_MAX_ANGLE = math.rad(170), -- sharper than this is a reversal (brake, then build from a stop)
	AIR_ACCELERATION = 30, -- falling off a ledge: everything at this gentler rate
	-- in a match, pushing backwards (S, S+A, S+D) keeps you facing the camera and walks you backwards slowly
	BACKPEDAL_SPEED = 19, -- studs/s, ~61% of running speed (developer, Oct 15: 10, 14, 18, 24, 27 with the 31 run, then 70% of that = 19) (live: EOS_Tuning.BackpedalSpeed)
	BACKPEDAL_ANGLE = math.rad(110), -- input at least this far from the camera's forward counts as backwards
	TURN_RATE = 18, -- how fast the body turns to face its heading (1/s, exponential)
}

-- Dash (Space / gamepad A / round DASH button on touch). Direction = the way you're pushing,
-- relative to the camera; standing still dashes the way you face.
GameConfig.Dash = {
	ENABLED = true,
	SPEED = 58, -- studs/s during the burst
	BURST_TIME = 0.16, -- seconds at full dash speed
	RECOVER_TIME = 0.24, -- seconds to ease back down to top speed
	COOLDOWN = 2.0,
	ANIM_SPEED = 1.15, -- playback rate of the slide / back dash clips
	-- read against the camera (keys and thumbstick alike): the angle between where you push and where
	-- the camera looks picks the dash, and the dash goes STRAIGHT that way (W+A = 9 o'clock)
	FORWARD_MAX_ANGLE = math.rad(22), -- straight on (incl. no push): no dash at all, there is no forward dash
	BACK_MIN_ANGLE = math.rad(150), -- only straight back: back dash
	BUFFER_TIME = 0.2, -- a dash pressed before the new direction keys register waits this long for them
	DIAG_WAIT = 0.15, -- S just pressed (W -> S -> S+A): a straight-back dash waits up to this long, from the S key, for A / D
	DIAG_BACK_FROM = math.rad(112.5), -- from here to BACK_MIN_ANGLE (S+A / S+D): slide diagonally backwards
	-- (7:30 / 4:30) with the left / right slide clip; between FORWARD_MAX_ANGLE and here: straight left / right
	-- Never the way your BODY faces either (developer, Oct 15): running sideways to the camera (A or D held,
	-- body turned that way), a slide that way would just be a forward dash, so it's refused. W+A held (body
	-- on the 45° diagonal) still slides straight left; the body cone is narrower than that.
	BODY_FORWARD_MAX_ANGLE = math.rad(40),
	CATCHER_DASH = false, -- Catchers can't dash at all in a match (developer, Oct 15), NPC Catchers included
}

-- The Catcher's hit is a full-body lunge stab (developer, Oct 15: the "knife attack" clip, every part of
-- the body moves). Balanced exactly like the old jab (developer, Oct 15): the hit is decided ON THE CLICK
-- from where everyone is then (Capture.TAG_RADIUS, SWING_CONE unchanged; TAG_COOLDOWN later 1.0), and the Catcher
-- keeps full speed. The clip's lunge is looks only: the reach is measured from the body's centre, never
-- from the knife. Only the caught Runner's fall waits for the knife to land (STRIKE_TIME).
-- (Checking the hit on the strike frame instead let the body carry ~4 studs forward first: +29% to +56%
-- reach on juking / standing Runners. Planting the Catcher for the lunge made misses cost ~9 studs.)
GameConfig.Stab = {
	STRIKE_TIME = 0.17, -- the knife at full reach: a Runner the click caught falls now
	MOVING_FADE_AT = 0.2, -- moving: right after the thrust the run takes the legs back...
	MOVING_FADE = 0.15, -- ...over this long (keeps the lunge stance from sliding along the ground)
	END_FADE_AT = 0.78, -- standing still, the clip plays out: fade it here instead of snapping at its end
	-- (developer, Oct 15) the jab costs nothing: no stop, no slow. The price is on the lunge (Lunge.SLOW_*).
}

-- The Catcher's lunge (developer, Oct 15): Space as a Catcher. A two-handed overhead stab driven down
-- at the ground while the body lunges forward (the camera's way), like a dash with a hit at the end.
-- The hit is decided when the knife lands (STRIKE_TIME, the clip's "Strike" marker), from where
-- everyone is then; afterwards the Catcher is slowed for a moment. Players and NPC Catchers alike.
GameConfig.Lunge = {
	ENABLED = true,
	SPEED = 46, -- studs/s while lunging (~9 studs of travel)
	BURST_TIME = 0.2, -- seconds at lunge speed (the knife lands at the end of it)
	RECOVER_TIME = 0.1, -- seconds easing from lunge speed down to the (slowed) top speed
	STRIKE_TIME = 0.2, -- seconds after the press: the hit is checked (= the clip's Strike marker)
	REACH = 6.5, -- studs from the body's centre at the strike (same as the jab's TAG_RADIUS)
	COOLDOWN = 2.5,
	SLOW_FACTOR = 0.5, -- after the lunge: this share of top speed...
	SLOW_TIME = 0.7, -- ...for this long (starts when the burst ends)
	ANIM_SPEED = 1,
	-- NPC Catchers lunge at a Runner this far away (and close the rest on foot)
	NPC_MIN_RANGE = 6,
	NPC_MAX_RANGE = 10,
}

GameConfig.Camera = {
	BASE_FOV = 70,
	SPEED_FOV_BONUS = 6, -- added at full speed (off with Reduce Effects)
	MIN_ZOOM = 8,
	MAX_ZOOM = 40,
	DEFAULT_ZOOM = 11,
	SHOULDER_OFFSET = Vector3.new(1.4, 0.35, 0), -- over-the-shoulder in a match (camera space, studs)
	SHOULDER_BLEND_TIME = 0.35, -- seconds to ease the offset in/out when a match starts/ends
	LOCK_MOUSE_IN_MATCH = true, -- PC: mouse turns the camera without right-click during a match
	-- the lobby uses Roblox's free camera: no shoulder offset, free mouse, heads don't follow the camera
}

-- Head look: the head turns toward where the player's camera looks, side to side and up and down
-- (body keeps its own facing).
GameConfig.HeadLook = {
	MAX_YAW = math.rad(90), -- side to side (running sideways to the camera = looking straight at it)
	MAX_PITCH_UP = math.rad(60), -- up and down follows the camera's tilt
	MAX_PITCH_DOWN = math.rad(55),
	SEND_RATE = 8, -- per second, only when it changed
	MIN_CHANGE = math.rad(4),
}

-- NPCs (server bodies + brains; each player sees them dressed as their own friends, client-side).
GameConfig.Npc = {
	ENABLED = true,
	RUNNER_TARGET = 20, -- under this many players, NPC Runners top the match up to this many Runners
	LOBBY_TARGET = 5, -- under this many people in the server, NPCs hang around the lobby up to this many
	MAX_SLOTS = 26, -- distinct NPC looks at once (= friend avatars built per player, on demand)
	THINK_RATE = 10, -- brain decisions per second
	-- speeds (studs/s): exactly the players' speeds (developer, Oct 15: "they need to be same speed";
	-- was 24 vs the players' 31). NPC Catchers = NPC Runners; a lunge slows them briefly (Lunge.SLOW_*)
	RUNNER_SPEED = GameConfig.Movement.RUNNER_SPEED,
	CATCHER_SPEED = GameConfig.Movement.CATCHER_SPEED,
	-- a Runner's dash fakes NPC Catchers out (developer, Oct 15: "my dashes don't really help against
	-- mobs"): for this long after a Runner starts a dash, Catchers on them keep heading for where the
	-- Runner WAS, read no lead off the dash, and can't lunge or stab
	DASH_FAKE_TIME = 0.5,
	DASH_SEEN_SPEED = 1.3, -- x run speed: a Runner moving faster than this is mid-dash
	BACKPEDAL_FRACTION = 19 / 31, -- walking backwards while facing a Runner: same share as players (Movement.BACKPEDAL_SPEED)
	LOBBY_WALK_SPEED = 9, -- lobby NPCs only ever walk
	-- lobby NPCs mostly stand around (idle) and take short strolls in between (~80% of the time standing)
	LOBBY_STAND_CHANCE = 0.8, -- after each stroll: chance to stand a while (else stroll on)
	LOBBY_STAND_MIN = 5, -- seconds standing
	LOBBY_STAND_MAX = 14,
	LOBBY_STROLL_MIN = 8, -- studs per stroll
	LOBBY_STROLL_MAX = 24,
	-- spacing (developer, Oct 15: no mobbing, no 20-in-one stacks; bodies don't collide, so brains keep apart)
	SEPARATION_RADIUS = 8, -- NPCs of the same role push apart inside this distance
	SEPARATION_WEIGHT = 1.8,
	LANE_JITTER = 10, -- studs: a Runner's lane stays near where it lined up (+/- this)
	-- Runners
	-- (developer's reference video, Oct 16: the whole line sprints off together on RUN, each Runner
	-- holds its own lane mostly straight, dodging Catchers as they come; safe Runners stand in a row on
	-- the line facing the field; only one or two get caught a crossing)
	START_DELAY_MAX = 0.3, -- seconds: everyone leaves the line together (was 1.2)
	CAUTIOUS_SHARE = 0, -- nobody waits for an opening (was 0.3)
	WEAVE_MIN = 0.03, -- side-to-side weave while running (fraction of a step sideways; was 0.1-0.45)
	WEAVE_MAX = 0.15,
	EVADE_RADIUS = 30, -- start steering away from Catchers this close (was 22)
	EVADE_WEIGHT = 3.2, -- how hard (was 2.4)
	JUKE_RADIUS = 10, -- a Catcher this close may get a side-slide juke (was 9)
	JUKE_CHANCE = 0.9, -- per chance (a Catcher closing in) (was 0.5)
	LUNGE_DODGE_CHANCE = 0.85, -- an NPC Runner a Catcher lunges at side-slides out of it this often (dash ready)
	SAFE_ROW_SPACING = 3.6, -- studs between safe Runners standing in their row on the line
	SAFE_ROW_INSET = 5, -- studs inside the safe zone's field edge
	-- Catchers
	CHASE_PREDICT = 0.25, -- seconds of lead on the target's velocity
	HUMAN_PREFERENCE = 0.85, -- real Runners count as this much closer when choosing a target
	MAX_PER_TARGET = 2, -- Catchers that may go after the same Runner while others are free
	CLAIM_PENALTY = 30, -- studs added to a Runner's distance per Catcher already on them
	FLANK_SPACING = 8, -- studs: Catchers sharing a target come at them from different sides
	-- Catchers square up: facing the Runner, they shuffle sideways (and back) to stay between the Runner
	-- and the finish; they only turn and run straight at them once that Runner is past them
	PAST_MARGIN = 3, -- studs along the field: a Runner this far beyond a Catcher (toward the finish) is past
	CLOSE_IN_RADIUS = 9, -- this close: step in for the stab
	GUARD_AHEAD_MIN = 6, -- studs ahead of the Runner (toward the finish) a Catcher holds while squared up
	GUARD_AHEAD_MAX = 16,
	FACE_RATE = 12, -- how fast an NPC turns to face (1/s, exponential)
	-- dashes (NPC Runners, in matches only): same burst and same rules as players: never as a Catcher,
	-- never the way the body faces (so no forward dives since Oct 15)
	DASH_COOLDOWN = 2.5,
	RANDOM_DASH_PER_SEC = 0.05, -- unprovoked side slides now and then
	-- friends as NPC looks
	FRIEND_OF_FRIEND_LOOKUPS = 6, -- friend lists to borrow from when a player has too few friends
	-- HOS-BOT-001: NPCs are made-up people (generated names, free catalog outfits) carrying real
	-- players' stats (RealPlayerPool), the same for everyone in the server
	REAL_POOL = true,
	FRIEND_FALLBACK = false, -- true: each player sees the NPCs as their own friends again (the old looks)
	LOBBY_CHAT = false, -- (not built yet)
	LOBBY_EMOTES = true, -- HOS-BOT-002: lobby NPCs emote now and then (Services/NpcEmotes); false = never
	-- (developer, Oct 17: uncommon, never in sync, quiet unless you're close)
	EMOTE_INTERVAL_MIN = 150, -- seconds between one NPC's emotes (each NPC rolls its own)
	EMOTE_INTERVAL_MAX = 360,
	EMOTE_FIRST_MIN = 30, -- a new NPC's first emote
	EMOTE_FIRST_MAX = 300,
	EMOTE_MAX_AT_ONCE = 1, -- NPCs emoting at once, whole lobby
	EMOTE_GAP = 20, -- seconds after any NPC's emote ends before another may start
	EMOTE_CHEER_CHANCE = 0.15, -- when results end: chance an NPC cheers
	EMOTE_CHEER_MAX = 1,
	EMOTE_COPY_CHANCE = 0.08, -- a real player emotes: chance a standing NPC nearby joins in
	EMOTE_COPY_RANGE = 20, -- studs
	EMOTE_COPY_COOLDOWN = 180, -- seconds: each NPC copies at most once in this long
	EMOTE_SOUND_VOLUME_SCALE = 0.35, -- x the player's emote song volume
	EMOTE_SOUND_ROLLOFF_MIN = 8, -- studs (InverseTapered)
	EMOTE_SOUND_ROLLOFF_MAX = 40,
	POOL_CAP = 300, -- recorded players kept (newest first)
	POOL_WRITE_INTERVAL = 60, -- seconds between this server's pool writes (batched)
	POOL_STUDIO_SEED = true, -- Studio, memory-only data: make up a few stat lines so previews work
}

-- Feature flags: what's live. Nothing in the UI may pretend an OFF system works.
-- GDD v0.4 (Oct 2026): pets, hatching, the three launch abilities and Gold/Gem cosmetics are live;
-- Robux purchases stay OFF until the developer approves real developer products.
GameConfig.Features = {
	ABILITIES = true,
	PETS = true,
	HATCHING = true,
	COSMETICS = true,
	SHOP_PURCHASES = true, -- Robux Gem packs: live developer products since 16 Oct (HOS-GEMS-001, EconomyConfig.GEM_PACKS)
	PRACTICE_BOT = true,
	SERVER_CONTACT_SCAN = true,
}

GameConfig.Data = {
	STORE_NAME = "EOS_Profiles_v2",
	-- Studio never touches the live store: it uses this name, and only when the
	-- workspace attribute UseDataStore = true. Otherwise Studio runs memory-only.
	STUDIO_STORE_NAME = "EOS_Profiles_v2_STUDIO_TEST",
	STUDIO_USE_DATASTORE_ATTRIBUTE = "UseDataStore",
	KEY_PREFIX = "p_",
	LEDGER_SIZE = 60, -- awardedMatchIds kept (bounded exact-once ledger)
	LOCK_LEASE = 180, -- session lock lease seconds
	LOCK_WAIT = 30, -- wait for another server's lock before stealing it
	AUTOSAVE_INTERVAL = 60,
	LOAD_RETRY_DELAYS = { 1, 2, 4, 8 },
	WRITE_RETRIES = 3,
	FAILED_SAVE_BACKOFF_MIN = 15,
	FAILED_SAVE_BACKOFF_MAX = 300,
}

-- Remote rate limits: max requests per window (seconds) per player.
GameConfig.RateLimits = {
	RequestTag = { max = 8, window = 1 },
	RequestLunge = { max = 2, window = 2 },
	RequestQuestClaim = { max = 4, window = 2 },
	RequestAFK = { max = 3, window = 2 },
	RequestVolunteer = { max = 3, window = 2 },
	RequestSettings = { max = 4, window = 2 },
	RequestProfile = { max = 3, window = 2 },
	RequestLook = { max = 14, window = 1 },
	RequestHatch = { max = 3, window = 2 },
	RequestOpenCrate = { max = 1, window = 1.5 },
	RequestEmote = { max = 6, window = 2 },
	RequestEquipPet = { max = 4, window = 2 },
	RequestBuy = { max = 4, window = 2 },
	RequestUseItem = { max = 2, window = 2 },
	RequestSetCosmetic = { max = 4, window = 2 },
	RequestAbility = { max = 4, window = 1 },
	RequestEmoteWheel = { max = 6, window = 2 },
	RequestServers = { max = 2, window = 3 },
	RequestJoinServer = { max = 2, window = 5 },
}

-- HOS-CINE-002: cut-scenes (Controllers/Cinematic). Last One Standing plays in the break before a crossing
-- that starts with a single Runner; that break gets LAST_STANDING_EXTRA seconds longer only then.
GameConfig.Cinematic = {
	LAST_STANDING_ENABLED = true, -- the switch: false = no cut-scene, the old "LAST ONE STANDING!" banner
	LAST_STANDING_EXTRA = 1.6, -- seconds added to that WAVE_END
	LAST_STANDING_SECONDS = 3.4, -- the moment's length on screen (shots 3.1 + bars out 0.3)
	MAX_SECONDS = 4, -- hard cap: any cut-scene gives the camera back by then
	BAR_HEIGHT = 0.11, -- letterbox bars, fraction of the screen height
	BAR_TIME = 0.28, -- bars slide in / out
}

-- Practice area (low-population fallback, never rewards).
GameConfig.Practice = {
	BOT_SPEED = 21, -- kept about 80% of the lobby speed (26)
	BOT_TAG_RADIUS = 3.6,
	BOT_RETARGET = 0.25,
	BOT_COUNT = 1,
}

function GameConfig.initialCatchersFor(rosterSize: number): number
	for _, row in ipairs(GameConfig.Match.INITIAL_CATCHERS) do
		if rosterSize <= row.maxPlayers then
			return row.catchers
		end
	end
	return GameConfig.Match.INITIAL_CATCHERS[#GameConfig.Match.INITIAL_CATCHERS].catchers
end

function GameConfig.plannedMatchSeconds(waves: number): number
	local t = GameConfig.Timing
	return t.ROLE_REVEAL + waves * t.CROSSING + waves * t.WAVE_TRANSITION + t.RESULTS
end

return GameConfig
