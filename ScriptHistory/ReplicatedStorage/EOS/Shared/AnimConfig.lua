--!strict
-- AnimConfig: which clip plays for which movement, and their published animation ids.
-- Clips live as KeyframeSequences in ReplicatedStorage.EOS_Animations (slot name = clip name),
-- picked by the developer from the "35+ General Movement Animations Pack" (#n = picker number).
-- Live servers need published ids: until an id is filled in, Studio playtests register the
-- KeyframeSequence for a temporary id instead (Studio only).

local AnimConfig = {}

AnimConfig.LIBRARY = "EOS_Animations"

-- slot -> published id ("" = not published yet). Re-published 2026-10-15 to the group that owns the game,
-- Eggs with Friends (228184582), as "EOS <name>": a group game can't play animations owned by a user.
-- (The 2026-10-14 copies on the developer's own profile are no longer used.)
AnimConfig.ids = {
	WalkSlow = "rbxassetid://89947928930228", -- #2 Walk2: slow walking
	WalkFast = "rbxassetid://110481889381649", -- #1 Walk1: faster walking
	Run = "rbxassetid://87156589310850", -- #8 Run2: full speed
	StrafeLeft = "rbxassetid://98567160284454", -- #4 Walk Left: Catchers moving sideways; anyone walking back-left
	StrafeRight = "rbxassetid://90926412203967", -- #5 Walk Right
	DashBack = "rbxassetid://115077148052587", -- #25 DashBack
	DashLeft = "rbxassetid://124658835855251", -- #18 LeftDash1
	DashRight = "rbxassetid://107227095081492", -- #19 RightDash1
	-- the Catcher's two hits (made for this game: arms + knife only, so the legs keep the movement
	-- clip underneath)
	SwingJab = "rbxassetid://70668465161245",
	SwingSlash = "rbxassetid://73285276196206",
	-- the Catcher's lunge (Space): both hands overhead, blade straight down, driven into the ground while
	-- lunging forward. Authored in Studio (ServerStorage.EOS_LungeAuthor); "" = Studio uses the local clip
	LungeStab = "",
}

-- NPC-only clips (players have no forward dash; NPCs dive now and then)
AnimConfig.npcIds = {
	DiveForward = "rbxassetid://114663888468024", -- #27 Dive Forward (KeyframeSequence "DashForward")
}

-- Roblox's own R6 clips for the moments the pack doesn't cover (free to use, always available)
AnimConfig.builtin = {
	Idle = "rbxassetid://180435571",
	Fall = "rbxassetid://180436148",
}

-- ground speed each clip looks right at (studs/s, measured from the foot sweep); playback rate
-- = actual speed / natural speed, clamped so nothing looks frantic or frozen
AnimConfig.naturalSpeed = {
	WalkSlow = 4.4,
	WalkFast = 6.8,
	Run = 21.5, -- tuned by feel: one stride cycle every ~0.44 s at 28 (Huss Valley reference ~0.5 s)
	StrafeLeft = 6,
	StrafeRight = 6,
}
AnimConfig.RATE_MIN = 0.6
AnimConfig.RATE_MAX = 2.2

-- which locomotion clip by flat speed (studs/s)
AnimConfig.IDLE_BELOW = 0.8
AnimConfig.WALK_FAST_FROM = 7
AnimConfig.RUN_FROM = 14

-- Catchers (camera-facing): angle between movement and facing that counts as sideways / backwards
AnimConfig.STRAFE_FROM = math.rad(50)
AnimConfig.BACKPEDAL_FROM = math.rad(110) -- backwards plays WalkFast in reverse (no back-walk clip); = GameConfig.Movement.BACKPEDAL_ANGLE
-- walking backwards: closer than this to straight back = WalkFast reversed; between this and
-- BACKPEDAL_FROM (S+A / S+D) = the side walk #4 / #5 toward that side
AnimConfig.BACK_STRAIGHT_FROM = math.rad(158)

AnimConfig.FADE = 0.18

return AnimConfig
