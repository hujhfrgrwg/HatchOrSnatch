--!strict
-- AbilityCosmetics (HOS-PET-001): the one place a pet species changes how its ability LOOKS and SOUNDS.
-- Species can never change a number (cooldown, duration, windup, size, reach): those live in AbilityConfig
-- per archetype and are the same for every species. Anything else put in a species entry is dropped.
--
--  * color: the summon ring / telegraph tint (default: the archetype's colour)
--  * sound: a Sound controller key played with the summon (default "ability")
--  (which rigged model plays the summon is PetBehaviors.MODULES on the client: looks only too)
--
-- Gold Ability Colors recolours the summon ring only. Effects opponents must read (the Decoy copy, the
-- Invisibility shimmer, snares, warning rings) always keep their archetype look, so no cosmetic can make
-- them harder to see.

local AbilityConfig = require(script.Parent:WaitForChild("AbilityConfig"))

local AbilityCosmetics = {}

AbilityCosmetics.ALLOWED = { color = true, sound = true } :: { [string]: boolean }
AbilityCosmetics.GOLD = Color3.fromRGB(255, 210, 58)

-- per species: looks and sound only
AbilityCosmetics.SPECIES = {
	Crow = { sound = "poof" },
	Kitsune = { sound = "poof" },
} :: { [string]: { [string]: any } }

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
