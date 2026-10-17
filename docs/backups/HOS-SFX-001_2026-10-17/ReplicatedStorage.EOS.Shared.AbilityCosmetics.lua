--!strict
-- AbilityCosmetics (HOS-PET-001): the one place a pet species changes how its ability LOOKS and SOUNDS.
-- Species can never change a number (cooldown, duration, windup, size, reach): those live in AbilityConfig
-- per archetype and are the same for every species. Anything else put in a species entry is dropped.
--
--  * color: the summon ring / telegraph tint (default: the archetype's colour)
--  * sound: a Sound controller key played with the summon (default "ability")
--  * vfx: per-effect overrides { [key] = template name } (see AbilityCosmetics.vfx below)
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

AbilityCosmetics.ALLOWED = { color = true, sound = true, vfx = true } :: { [string]: boolean }
AbilityCosmetics.GOLD = Color3.fromRGB(255, 210, 58)
AbilityCosmetics.NONE = "None" -- a vfx value: draw nothing for this effect (the species' own effect covers it)

-- per species: looks and sound only
AbilityCosmetics.SPECIES = {
	Crow = { sound = "poof", vfx = { DecoySplit = "None" } }, -- its swoop-in summon is the split
	Kitsune = { sound = "poof", vfx = { DecoySplit = "None" } }, -- its run-in summon is the split
	["Grim Ghost"] = { vfx = { InvisShimmer = "None" } }, -- keeps its own glints (Controllers.Invisibility)
	["Prism Chameleon"] = { vfx = { InvisShimmer = "None" } }, -- keeps its own prism glints
} :: { [string]: { [string]: any } }

-- the effect to draw for `key` when `species` uses its ability: the species' override, else the default
-- (`key` itself). Effects with no species (or an unknown one) always get the default.
function AbilityCosmetics.vfx(species: any, key: string): string
	local entry = if type(species) == "string" then AbilityCosmetics.SPECIES[species] else nil
	local o = entry and entry.vfx
	local v = if type(o) == "table" then o[key] else nil
	return if type(v) == "string" and v ~= "" then v else key
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
