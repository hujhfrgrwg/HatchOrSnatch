--!strict
-- AbilityConfig (HOS-PET-001): the five pet ability archetypes and every number they use, per role.
-- Shared so the UI shows the same numbers the server uses; the server is the authority
-- (ServerScriptService.EOS.Abilities.<Archetype> runs the handlers and reads these values).
--
--  * An equipped pet's family is its archetype. The player's role when they press the button picks
--    the handler: Runner or Catcher. The cooldown is shared and carries over a role change.
--  * Species never change numbers: AbilityCosmetics picks looks and sound only.
--  * The match's starting Catcher has no pet ability (Hunter's rule: one starting Catcher, never made
--    stronger). NPCs never use pet abilities.
--  * built = false: the handler is a stub that only logs; pressing the button is refused and costs
--    nothing. Flip it once the handler is written.

local AbilityConfig = {}

export type RoleDef = {
	built: boolean,
	name: string, -- the ability card's title in this role
	icon: string, -- HOS-PET-003: the icon slug in this role (UI falls back to the Runner icon until it is uploaded)
	text: string, -- one line for this role (incubator / pets panel)
	cooldown: number,
	duration: number,
	windup: number, -- seconds from the press to the effect (the same for every species)
	[string]: any, -- the archetype's own tuning values
}
export type Archetype = {
	title: string,
	color: Color3, -- the default effect colour (summon ring etc.), equally visible to everyone; one colour for both roles
	Runner: RoleDef,
	Catcher: RoleDef,
}

AbilityConfig.ORDER = { "Decoy", "Invisibility", "Guardian", "Tempest", "Rift" }

AbilityConfig.ARCHETYPES = {
	Decoy = {
		title = "Decoy",
		color = Color3.fromRGB(255, 196, 92),
		Runner = {
			built = true,
			name = "DECOY",
			icon = "ab_decoy",
			text = "a running copy of you fools chasers",
			cooldown = 20,
			duration = 3,
			windup = 0, -- the copy leaves on the press; a species' fly-in plays over it
			spread = 145, -- degrees: the copy runs off at a random angle inside this cone around your heading
		},
		Catcher = {
			built = false,
			name = "SNARE",
			icon = "ab_snare",
			text = "drop a snare that roots the first Runner in",
			cooldown = 20,
			duration = 8,
			windup = 0,
		},
	},
	Invisibility = {
		title = "Invisibility",
		color = Color3.fromRGB(190, 150, 255),
		Runner = {
			built = true,
			name = "INVISIBLE",
			icon = "ab_invis",
			text = "fade to a shimmer; you can still be tagged",
			cooldown = 20,
			duration = 3,
			windup = 0,
		},
		-- 17 Oct (Hunter): the Catcher side is invisibility too, with tighter limits
		Catcher = {
			built = true, -- HOS-PET-006 prototype
			name = "INVISIBLE",
			icon = "ab_invis",
			text = "fade out to sneak up; any stab or lunge shows you",
			cooldown = 20,
			duration = 2,
			windup = 0,
			revealRadius = 15, -- Runners this close see a faint shimmer
			endsOnAttack = true, -- a stab or lunge ends it at once
		},
	},
	Guardian = {
		title = "Guardian",
		color = Color3.fromRGB(120, 220, 255),
		Runner = {
			built = true, -- HOS-PET-007 prototype
			name = "SHIELD",
			icon = "ab_shield",
			text = "a shield that blocks one tag",
			cooldown = 20,
			duration = 3,
			windup = 0,
			charges = 1, -- tags it blocks
			immunity = 0.5, -- seconds after the block when no tag lands (a touching Catcher retries every tick)
		},
		-- 17 Oct (Hunter): tether moved here from Invisibility; Long Reach was dropped
		Catcher = {
			built = true, -- HOS-PET-007 prototype
			cone = 60, -- degrees either side of where you face that count as "in front"
			name = "TETHER",
			icon = "ab_tether",
			text = "pull the nearest Runner in front towards you",
			cooldown = 20,
			duration = 0,
			windup = 0.4, -- visible windup before the pull
			range = 25, -- studs: the nearest Runner in front within this
			pull = 6, -- studs pulled towards you
		},
	},
	Tempest = {
		title = "Tempest",
		color = Color3.fromRGB(255, 232, 90),
		Runner = {
			built = false,
			name = "PULSE",
			icon = "ab_tempest",
			text = "push nearby Catchers away",
			cooldown = 22,
			duration = 0,
			windup = 0.3,
		},
		Catcher = {
			built = false,
			name = "STORM BALL",
			icon = "ab_stormball",
			text = "roll a storm ball that slows a Runner",
			cooldown = 18,
			duration = 0,
			windup = 0,
		},
	},
	Rift = {
		title = "Rift",
		color = Color3.fromRGB(255, 110, 220),
		Runner = {
			built = false,
			name = "PORTAL HOP",
			icon = "ab_rift",
			text = "hop a short way through a portal",
			cooldown = 20,
			duration = 0,
			windup = 0.35,
		},
		Catcher = {
			built = false,
			name = "RIFT BLINK",
			icon = "ab_blink",
			text = "blink forward after a visible warning ring",
			cooldown = 20,
			duration = 0,
			windup = 0.5,
		},
	},
} :: { [string]: Archetype }

-- "RUNNER" -> "Runner", "CATCHER" -> "Catcher"; nil for any other role
function AbilityConfig.roleKey(role: any): string?
	if role == "RUNNER" then
		return "Runner"
	elseif role == "CATCHER" then
		return "Catcher"
	end
	return nil
end

function AbilityConfig.get(archetype: any): Archetype?
	return if type(archetype) == "string" then AbilityConfig.ARCHETYPES[archetype] else nil
end

-- the definition for an archetype in a role ("RUNNER" / "CATCHER" or "Runner" / "Catcher")
function AbilityConfig.forRole(archetype: any, role: any): RoleDef?
	local a = AbilityConfig.get(archetype)
	if not a then
		return nil
	end
	local key = AbilityConfig.roleKey(role) or role
	return if key == "Runner" or key == "Catcher" then (a :: any)[key] else nil
end

return AbilityConfig
