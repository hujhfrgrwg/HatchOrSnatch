--!strict
-- AbilityCosmetics (HOS-PET-001): the one place a pet species changes how its ability LOOKS and SOUNDS.
-- Species can never change a number (cooldown, duration, windup, size, reach): those live in AbilityConfig
-- per archetype and are the same for every species. Anything else put in a species entry is dropped.
--
--  * color: the summon ring / telegraph tint (default: the archetype's colour)
--  * sound: a Sound controller key played with the summon (default "ability")
--  * vfx: per-effect overrides { [key] = template name } (see AbilityCosmetics.vfx below)
--  * sfx: per-effect sound overrides { [key] = a key in Shared.AbilitySounds, or NONE } (HOS-SFX-001)
--  (which rigged model plays the summon is PetBehaviors.MODULES on the client: looks only too)
--
-- Per-pet VFX (HOS-VFX-OVR, Hunter 17 Oct: every pet gets its own ability VFX one day; the archetype's
-- effects are the defaults). Every effect has a key: the default template's name in
-- ReplicatedStorage.VFX.Abilities (PulseBlast, StormBall, RiftPortal, ...), plus "Summon" (the pet's
-- entrance over the user) and "DecoyPoof" (the copy leaving). A species overrides any single key, one-shot
-- or lasting, and keeps the default for the rest:
--   Mouse = { vfx = { DecoySplit = "DecoySplit_Mouse" } }  -- a template next to the default one
--   Crow  = { vfx = { DecoySplit = AbilityCosmetics.NONE } } -- its own effect covers it: draw nothing
-- A missing override template falls back to the default. Overrides are looks only, and the readability
-- rule above still holds: an override of an effect opponents must read keeps its size, colour and timing.
-- Pets with their own rigged effects (PetBehaviors: Crow, Kitsune, Prism Chameleon) keep their summon and
-- poof exactly as built (Hunter, 17 Oct); the archetype defaults never play on top of them.
--
-- Gold Ability Colors recolours the summon ring only. Effects opponents must read (the Decoy copy, the
-- Invisibility shimmer, snares, warning rings) always keep their archetype look, so no cosmetic can make
-- them harder to see.

local AbilityConfig = require(script.Parent:WaitForChild("AbilityConfig"))

local AbilityCosmetics = {}

AbilityCosmetics.ALLOWED = { color = true, sound = true, vfx = true, sfx = true } :: { [string]: boolean }
AbilityCosmetics.GOLD = Color3.fromRGB(255, 210, 58)
AbilityCosmetics.NONE = "None" -- a vfx value: draw nothing for this effect (the species' own effect covers it)

-- per species: looks and sound only
AbilityCosmetics.SPECIES = {
	Crow = { sound = "poof", vfx = { DecoySplit = "None" } }, -- its swoop-in summon is the split
	Kitsune = { sound = "poof", vfx = { DecoySplit = "None" } }, -- its run-in summon is the split
	["Grim Ghost"] = { vfx = { InvisShimmer = "None" } }, -- keeps its own glints (Controllers.Invisibility)
	["Prism Chameleon"] = { vfx = { InvisShimmer = "None" } }, -- keeps its own prism glints
	["Mirage Manta"] = { vfx = { InvisShimmer = "None" } }, -- keeps its own blue star glints
	-- HOS-PET-013c, Hunter's model sheet: Shell Shield (Runner) = cyan hex crystal dome, Horn Tether (Catcher) =
	-- jagged cyan crystal spear from the horn
	["Bastion Beetle"] = {
		vfx = {
			ShieldUp = "BeetleShieldUp",
			ShieldBubble = "BeetleShieldBubble",
			ShieldBreak = "BeetleShieldBreak",
			TetherBeam = "BeetleTetherBeam",
			TetherYank = "BeetleTetherYank",
		},
		sfx = { ShieldUp = "BeetleShieldUp" },
	},
	-- HOS-PET-014, the concept card: Shockwave (Runner) = yellow burst with blue-white lightning and croak
	-- ripples; Electric Ball (Catcher) = blue-white crackling shell round a yellow glowing core, lightning trail.
	-- The ball keeps its size, speed and yellow floor scorch so opponents still read it; Slowed stays default.
	["Thunder Toad"] = {
		vfx = {
			PulseCharge = "ToadPulseCharge",
			PulseBlast = "ToadPulseBlast",
			KnockHit = "ToadKnockHit",
			StormBall = "ToadStormBall",
			StormBounce = "ToadStormBounce",
			StormHit = "ToadStormHit",
		},
		sfx = { PulseCharge = "ToadCroak" }, -- the croak as the throat sac swells
	},
	-- HOS-PET-017 Ring Imp: magenta-gold rune portals (Runner) and a violet flash + ring burst (Blink in / out).
	-- Same size and timing as the defaults; the Blink warning reticle stays default so opponents still read it.
	["Ring Imp"] = {
		vfx = { RiftPortal = "ImpRiftPortal", RiftArrive = "ImpRiftArrive" },
	},
	-- HOS-PET-019 Crystal Warden: sapphire / violet crystal versions of the Guardian effects with prism facet
	-- shards (gold at L2, rainbow at L3). The dome keeps its size and blue so opponents still read it.
	["Crystal Warden"] = {
		vfx = {
			ShieldUp = "WardenShieldUp",
			ShieldBubble = "WardenShieldBubble",
			ShieldBreak = "WardenShieldBreak",
			TetherBeam = "WardenTetherBeam",
			TetherYank = "WardenTetherYank",
		},
	},
	-- HOS-PET-020 Riot Hound: gold shockwave with navy shadows (Runner) and a blue electric Storm Ball wrapped in
	-- gold lightning (Catcher), from the card. Same size, speed and gold floor scorch as the Toad so opponents read
	-- them; L2 adds blue lightning, L3 cyan arcs.
	["Riot Hound"] = {
		vfx = {
			PulseCharge = "HoundPulseCharge",
			PulseBlast = "HoundPulseBlast",
			KnockHit = "HoundKnockHit",
			StormBall = "HoundStormBall",
			StormBounce = "HoundStormBounce",
			StormHit = "HoundStormHit",
		},
	},
	-- HOS-PET-021 Compass Hare, Rift Rare (tools/pet-kit/hare/hare.py)
	["Compass Hare"] = {
		vfx = {
			RiftArrive = "HareRiftArrive",
			RiftPortal = "HareRiftPortal",
		},
	},
	-- HOS-PET-022 Scroll Tanuki, Decoy Epic (tools/pet-kit/tanuki/tanuki.py)
	["Scroll Tanuki"] = {
		vfx = {
			DecoyPoof = "TanukiDecoyPoof",
			DecoySplit = "TanukiDecoySplit",
			SnareTrigger = "TanukiSnareTrigger",
		},
	},
	-- HOS-PET-023 Moonveil Moth, Invisibility Epic (tools/pet-kit/moth/moth.py)
	["Moonveil Moth"] = {
		vfx = {
			InvisShimmer = "None",
		},
	},
	-- HOS-PET-024 Shrine Lion, Guardian Epic (tools/pet-kit/lion/lion.py)
	["Shrine Lion"] = {
		vfx = {
			ShieldBreak = "LionShieldBreak",
			ShieldBubble = "LionShieldBubble",
			ShieldUp = "LionShieldUp",
			TetherBeam = "LionTetherBeam",
			TetherYank = "LionTetherYank",
		},
	},
	-- HOS-PET-025 Drum Oni, Tempest Epic (tools/pet-kit/oni/oni.py)
	["Drum Oni"] = {
		vfx = {
			KnockHit = "OniKnockHit",
			PulseBlast = "OniPulseBlast",
			PulseCharge = "OniPulseCharge",
			StormBall = "OniStormBall",
			StormBounce = "OniStormBounce",
			StormHit = "OniStormHit",
		},
	},
	-- HOS-PET-026 Astral Djinn, Rift Epic (tools/pet-kit/djinn/djinn.py)
	["Astral Djinn"] = {
		vfx = {
			RiftArrive = "DjinnRiftArrive",
			RiftPortal = "DjinnRiftPortal",
		},
	},
	-- HOS-PET-027 Eclipse Tengu, Decoy Legendary (tools/pet-kit/tengu/tengu.py)
	["Eclipse Tengu"] = {
		vfx = {
			DecoyPoof = "TenguDecoyPoof",
			DecoySplit = "TenguDecoySplit",
			SnareTrigger = "TenguSnareTrigger",
		},
	},
	-- HOS-PET-028 Veil Nekomata, Invisibility Legendary (tools/pet-kit/neko/neko.py)
	["Veil Nekomata"] = {
		vfx = {
			InvisShimmer = "None",
		},
	},
	-- HOS-PET-029 Aegis Kirin, Guardian Legendary (tools/pet-kit/kirin/kirin.py)
	["Aegis Kirin"] = {
		vfx = {
			ShieldBreak = "KirinShieldBreak",
			ShieldBubble = "KirinShieldBubble",
			ShieldUp = "KirinShieldUp",
			TetherBeam = "KirinTetherBeam",
			TetherYank = "KirinTetherYank",
		},
	},
	-- HOS-PET-030 Raiju, Tempest Legendary (tools/pet-kit/raiju/raiju.py)
	["Raiju"] = {
		vfx = {
			KnockHit = "RaijuKnockHit",
			PulseBlast = "RaijuPulseBlast",
			PulseCharge = "RaijuPulseCharge",
			StormBall = "RaijuStormBall",
			StormBounce = "RaijuStormBounce",
			StormHit = "RaijuStormHit",
		},
	},
	-- HOS-PET-031 Void Seraph, Rift Legendary (tools/pet-kit/seraph/seraph.py)
	["Void Seraph"] = {
		vfx = {
			RiftArrive = "SeraphRiftArrive",
			RiftPortal = "SeraphRiftPortal",
		},
	},
	-- HOS-HWN-001 Halloween Pumpkin Wraith
	["Pumpkin Wraith"] = {
		vfx = {
			InvisShimmer = "None",
		},
	},
	-- HOS-HWN-001 Halloween Witch's Cat
	["Witch's Cat"] = {
		vfx = {
			DecoyPoof = "CatDecoyPoof",
			DecoySplit = "CatDecoySplit",
			SnareTrigger = "CatSnareTrigger",
		},
	},
	-- HOS-HWN-001 Halloween Mummy
	["Mummy"] = {
		vfx = {
			ShieldBreak = "MummyShieldBreak",
			ShieldBubble = "MummyShieldBubble",
			ShieldUp = "MummyShieldUp",
			TetherBeam = "MummyTetherBeam",
			TetherYank = "MummyTetherYank",
		},
	},
	-- HOS-HWN-001 Halloween Bone Dragon
	["Bone Dragon"] = {
		vfx = {
			KnockHit = "DragonKnockHit",
			PulseBlast = "DragonPulseBlast",
			PulseCharge = "DragonPulseCharge",
			StormBall = "DragonStormBall",
			StormBounce = "DragonStormBounce",
			StormHit = "DragonStormHit",
		},
	},
} :: { [string]: { [string]: any } }

-- Bought ability skins (HOS-VFX-RES-001), keyed by shop item id. The server passes "skin:<id>" in place of
-- the species for the effects a skin covers; the same size, timing and readability rules apply.
AbilityCosmetics.SKINS = {
	fx_rift_void = { vfx = { RiftPortal = "SkinVoidRiftPortal" } },
	fx_rift_inferno = { vfx = { RiftPortal = "SkinInfernoRiftPortal" } },
	fx_rift_frost = { vfx = { RiftPortal = "SkinFrostRiftPortal" } },
} :: { [string]: { [string]: any } }

-- the effect to draw for `key` when `species` uses its ability: the species' override, else the default
-- (`key` itself). Effects with no species (or an unknown one) always get the default.
function AbilityCosmetics.vfx(species: any, key: string): string
	local entry = if type(species) == "string" then (if species:sub(1, 5) == "skin:" then AbilityCosmetics.SKINS[species:sub(6)] else AbilityCosmetics.SPECIES[species]) else nil
	local o = entry and entry.vfx
	local v = if type(o) == "table" then o[key] else nil
	return if type(v) == "string" and v ~= "" then v else key
end

-- the sound to play for effect `key` (HOS-SFX-001): the species' sfx override (a key in AbilitySounds, or
-- NONE), else the default (`key`). A species whose own effect covers `key` (its vfx override is NONE) gets
-- no default sound for it either, so defaults never play on top of a pet's own look.
function AbilityCosmetics.sfx(species: any, key: string, vfxKey: string?): string
	local entry = if type(species) == "string" then AbilityCosmetics.SPECIES[species] else nil
	local o = entry and entry.sfx
	local v = if type(o) == "table" then o[key] else nil
	if type(v) == "string" and v ~= "" then
		return v
	end
	if AbilityCosmetics.vfx(species, vfxKey or key) == AbilityCosmetics.NONE then
		return AbilityCosmetics.NONE
	end
	return key
end

-- per archetype, when the species has no sound of its own
AbilityCosmetics.ARCHETYPE_SOUND = { Decoy = "poof" } :: { [string]: string }

export type Look = { color: Color3, ringColor: Color3, sound: string }

function AbilityCosmetics.resolve(species: any, archetype: any, gold: boolean?): Look
	local a = AbilityConfig.get(archetype)
	local base = if a then a.color else AbilityCosmetics.GOLD
	local out: { [string]: any } = {}
	local entry = if type(species) == "string" then AbilityCosmetics.SPECIES[species] else nil
	for k, v in pairs(entry or {}) do
		if AbilityCosmetics.ALLOWED[k] then
			out[k] = v
		end
	end
	local color = if typeof(out.color) == "Color3" then out.color else base
	return {
		color = color, -- effects opponents must read: never gold
		ringColor = if gold then AbilityCosmetics.GOLD else color,
		sound = if type(out.sound) == "string" then out.sound else (AbilityCosmetics.ARCHETYPE_SOUND[archetype] or "ability"),
	}
end

return AbilityCosmetics
