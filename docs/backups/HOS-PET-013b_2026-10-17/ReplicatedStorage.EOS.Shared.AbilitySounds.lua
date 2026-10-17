--!strict
-- AbilitySounds (HOS-SFX-001): the default sound for each ability effect key (the same keys as the VFX:
-- the template names in ReplicatedStorage.VFX.Abilities, plus InvisOn / InvisOff). Real recordings only:
-- every id is from Roblox's licensed Pro Sound Effects library (creator "ProSoundEffects", verified,
-- free on the Creator Store); the list with sources is docs/ability-vfx/SOUNDS.md.
-- A species can swap any key (AbilityCosmetics SPECIES[x].sfx = { [key] = other key or NONE }); a species
-- whose own effect covers a key (its vfx is NONE) gets no default sound there either.
-- Played by Controllers.AbilityVFX through SoundService.Abilities, 3D with rolloff (see ROLLOFF).
--   id      rbxassetid number
--   volume  0..1 (before the Abilities group's volume)
--   speed   playback speed (pitch)
--   start / length  play only this part of the recording (seconds)
--   loop    loops while a lasting effect is on (lasting keys only)

local AbilitySounds = {}

AbilitySounds.ROLLOFF = { min = 12, max = 90 } -- studs: full volume within min, silent past max

AbilitySounds.SOUNDS = {
	-- Decoy
	DecoySplit = { id = 9120711172, volume = 0.7, speed = 1.1 }, -- Whoosh Fast Swish By 7
	DecoyPoof = { id = 9117848644, volume = 0.8 }, -- Pops Mouth Popping 7
	Snare = { id = 9113760544, volume = 0.8 }, -- Chain Movement 8 (the snare drops)
	SnareTrigger = { id = 9113760085, volume = 1 }, -- Chain Movement 1 (a Runner is caught)
	-- Guardian
	ShieldUp = { id = 9114369767, volume = 0.7, start = 0, length = 1.1, speed = 1.15 }, -- Fairy Dust 2 (chimes)
	ShieldBreak = { id = 9114593452, volume = 0.9 }, -- Glass Breaks 20
	TetherYank = { id = 9114164480, volume = 1, speed = 0.85 }, -- Dowel Swishes 21 (whip-like)
	-- Tempest
	PulseCharge = { id = 9116276051, volume = 0.6, speed = 1.3 }, -- Lightning Flashes Quick Electrical Bursts 11
	PulseBlast = { id = 9116277954, volume = 0.9 }, -- Lightning Flashes Quick Electrical Bursts 32
	KnockHit = { id = 9113476527, volume = 0.7 }, -- Body Fall Master 36
	StormBall = { id = 9114237487, volume = 0.45, loop = true }, -- Electric Arcing 4 (rolls while it rolls)
	StormBounce = { id = 9116684830, volume = 0.9 }, -- Metal Impacts 3
	StormHit = { id = 9116275998, volume = 1 }, -- Lightning Flashes Quick Electrical Bursts 13
	-- Rift
	RiftPortal = { id = 9119467870, volume = 0.6, length = 1.2, speed = 1.2 }, -- Spirit Pass Bys 3
	RiftArrive = { id = 9120716870, volume = 0.7, speed = 1.15 }, -- Whoosh Fast Swish By 4
	RiftReticle = { id = 9113089565, volume = 0.45, start = 0, length = 0.6 }, -- Alarm Tone 2-Tone (Blink warning)
	RiftFizzle = { id = 9119583983, volume = 0.7 }, -- Static Many Various Length Bursts 24
	-- Invisibility (the default cloak only)
	InvisOn = { id = 9113069659, volume = 0.6, length = 1.4 }, -- Air Fingers Short Swooshing Bursts Sucking 1
	InvisOff = { id = 9114159111, volume = 0.6, length = 1.2 }, -- Doppler Whooshes Crackly Airy Bursts 1
	-- per-pet sounds (AbilityCosmetics SPECIES[x].sfx)
	BeetleShieldUp = { id = 9116524438, volume = 0.75 }, -- Metal Box Hits Bumps Second Has Clang 2 (the shell closes)
} :: { [string]: { [string]: any } }

-- lasting effects that sound when they appear (the rest of the lasting keys are silent)
AbilitySounds.ON_DRESS = { Snare = true, PulseCharge = true, StormBall = true, RiftReticle = true } :: { [string]: boolean }

return AbilitySounds
