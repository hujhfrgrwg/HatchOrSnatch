--!strict
-- EconomyConfig: GDD v0.4 economy, in one place (shared so the UI shows the same numbers the
-- server uses). PLAYTEST STARTING VALUES from the GDD tables; tune from telemetry, not by feel.
--
--  * Gold: earn-only soft currency for low-stakes and recurring expression (never buys power)
--  * Gems: earnable now; purchasable with Robux later (GEM_PACKS stay hidden until the developer
--    approves real developer products); buys durable premium cosmetics only
--  * Egg pieces: one primary piece per eligible match (Common / Rare / Epic; Crowned deferred),
--    crafted into pets at the incubator. A pet grants one ability family in matches.

local EconomyConfig = {}

-- ===== per-match earnings (GDD 08) =====
-- Gold = min(90, 25 active + 12 x successful crossings + 10 x credited first theft + 15 x final victory)
EconomyConfig.GOLD = { CAP = 90, ACTIVE = 25, PER_CROSSING = 12, FIRST_THEFT = 10, VICTORY = 15 }
-- Gems = min(5, 1 active + 1 first crossing + 1 second crossing + 1 final victory + 1 credited first theft)
-- + 1 per Gem picked up on the field (HOS-GEMS-002), at most FIELD_CAP a match, still inside CAP
EconomyConfig.GEMS = { CAP = 5, ACTIVE = 1, FIRST_CROSSING = 1, SECOND_CROSSING = 1, VICTORY = 1, FIRST_THEFT = 1, FIELD_CAP = 2 }

export type MatchOutcome = {
	active: boolean, -- eligible (moved / crossed / tagged): no AFK presence rewards
	crossings: number,
	captures: number, -- credited captures (the first one counts once)
	win: boolean,
	fieldGems: number?, -- Gems picked up on the field
}

-- Returns gold, plus a breakdown for the results card
function EconomyConfig.goldFor(o: MatchOutcome): (number, { { label: string, amount: number } })
	local G = EconomyConfig.GOLD
	local parts = {}
	local total = 0
	local function add(label: string, amount: number)
		if amount > 0 then
			table.insert(parts, { label = label, amount = amount })
			total += amount
		end
	end
	if o.active then
		add("PLAYED", G.ACTIVE)
	end
	add("CROSSINGS", G.PER_CROSSING * math.max(0, o.crossings))
	add("FIRST STEAL", if o.captures > 0 then G.FIRST_THEFT else 0)
	add("VICTORY", if o.win then G.VICTORY else 0)
	return math.min(G.CAP, total), parts
end

-- Account XP and level (16 Oct, Hunter). Every match pays XP; XP builds the account level on your nameplate
-- ("Lv. 12"). Each level-up pays a little Gold, every 5th a few Gems. VIP (+25%) and 2x XP (+100%) add to match
-- XP only. A level changes nothing in a match.
EconomyConfig.XP = { ACTIVE = 40, PER_CROSSING = 20, FIRST_THEFT = 25, EXTRA_THEFT = 10, MAX_EXTRA_THEFTS = 3, VICTORY = 40 }
EconomyConfig.LEVEL_REWARD = { gold = 50, gemsEvery = 5, gems = 10 }

function EconomyConfig.xpFor(o: MatchOutcome): number
	local X = EconomyConfig.XP
	local n = 0
	if o.active then
		n += X.ACTIVE
	end
	n += X.PER_CROSSING * math.max(0, o.crossings)
	if o.captures > 0 then
		n += X.FIRST_THEFT + X.EXTRA_THEFT * math.min(X.MAX_EXTRA_THEFTS, o.captures - 1)
	end
	if o.win then
		n += X.VICTORY
	end
	return n
end

-- XP to go from `level` to the next (100, 125, 150 ...: level 10 is about 15 matches)
function EconomyConfig.xpToNext(level: number): number
	return 100 + 25 * (math.max(1, level) - 1)
end

-- total XP -> level, XP into this level, XP this level needs
function EconomyConfig.levelFor(xp: number): (number, number, number)
	local level, rest = 1, math.max(0, math.floor(xp))
	while level < 999 and rest >= EconomyConfig.xpToNext(level) do
		rest -= EconomyConfig.xpToNext(level)
		level += 1
	end
	return level, rest, EconomyConfig.xpToNext(level)
end

function EconomyConfig.gemsFor(o: MatchOutcome): number
	local M = EconomyConfig.GEMS
	local n = 0
	if o.active then
		n += M.ACTIVE
	end
	if o.crossings >= 1 then
		n += M.FIRST_CROSSING
	end
	if o.crossings >= 2 then
		n += M.SECOND_CROSSING
	end
	if o.win then
		n += M.VICTORY
	end
	if o.captures > 0 then
		n += M.FIRST_THEFT
	end
	n += math.min(M.FIELD_CAP or 0, o.fieldGems or 0)
	return math.min(M.CAP, n)
end

-- ===== egg pieces (GDD 03) =====
EconomyConfig.MATERIALS = { "common", "rare", "epic" } -- low -> high; "crowned" is deferred
EconomyConfig.MATERIAL_INFO = {
	common = { name = "Common", color = Color3.fromRGB(226, 220, 204), text = Color3.fromRGB(240, 234, 218) },
	rare = { name = "Rare", color = Color3.fromRGB(92, 176, 255), text = Color3.fromRGB(122, 196, 255) },
	epic = { name = "Epic", color = Color3.fromRGB(184, 112, 255), text = Color3.fromRGB(206, 150, 255) },
}
-- highest egg level secured this match -> the one piece earned (Level 4 = Epic at launch)
EconomyConfig.MATERIAL_FOR_TIER = { [1] = "common", [2] = "rare", [3] = "epic", [4] = "epic" }
-- pieces per hatch: random family / chosen family ("focus" = one extra piece of the same tier)
EconomyConfig.RECIPES = {
	common = { base = 2, focus = 3 },
	rare = { base = 3, focus = 4 },
	epic = { base = 5, focus = 6 },
}
-- the first Common pet: base recipe (2 pieces) AND a free family choice

function EconomyConfig.materialForTier(tier: number): string
	return EconomyConfig.MATERIAL_FOR_TIER[math.clamp(math.floor(tier), 1, 4)]
end

function EconomyConfig.materialIndex(m: string): number?
	return table.find(EconomyConfig.MATERIALS, m)
end

-- ===== pets and ability families (GDD 13, appendix B) =====
-- One equipped pet = one ability. Rarity is visual at launch (casual rarity stats are a TEST: 0%).
-- HOS-PET-001 (16 Oct): Scout and Brake are gone. A family is one of the five ability archetypes
-- (AbilityConfig: Decoy, Invisibility, Guardian, Tempest, Rift); the cooldown / duration shown here are
-- the Runner side's, read from AbilityConfig (the one place the numbers live). Only families with
-- species are listed; LAUNCH_FAMILIES is what eggs hatch.
local AbilityConfig = require(script.Parent:WaitForChild("AbilityConfig"))
local AR = AbilityConfig.ARCHETYPES
-- HOS-PET-REDO (Hunter 17 Oct, "implement"): every roster pet hatches from its family at its SPECIES_RARITY rarity;
-- the four Halloween shop pets stay shop-only (HalloweenShop.inject, never in these tables)
EconomyConfig.LAUNCH_FAMILIES = { "Decoy", "Invisibility", "Guardian", "Tempest", "Rift" }
EconomyConfig.FAMILIES = {
	Decoy = {
		ability = "DECOY",
		short = "A running copy of you",
		desc = "Sends a copy of you running ahead for 3 seconds. Catchers chasing it lose you.",
		species = { common = "Crow", rare = "Kitsune", epic = "Scroll Tanuki", legendary = "Eclipse Tengu" }, -- (Mouse retired: no model)
		color = AR.Decoy.color,
		cooldown = AR.Decoy.Runner.cooldown,
		duration = AR.Decoy.Runner.duration,
	},
	-- the invisibility pets (Abilities.Invisibility / client Controllers.Invisibility). Only the Prism
	-- Chameleon has a model so far, so it is every rarity until the Grim Ghost ships.
	Invisibility = {
		ability = "INVISIBLE",
		short = "Fade from sight",
		desc = "Turns you nearly invisible for 3 seconds: opponents only see a faint shimmer.",
		species = { common = "Prism Chameleon", rare = "Grim Ghost", epic = { "Mirage Manta", "Moonveil Moth" }, legendary = "Veil Nekomata" }, -- HOS-PET-018: the Grin Ghost is the Rare
		color = AR.Invisibility.color,
		cooldown = AR.Invisibility.Runner.cooldown,
		duration = AR.Invisibility.Runner.duration,
	},
	Guardian = {
		ability = "SHIELD",
		short = "A shield that blocks one tag",
		desc = "A shield round you for about a second that blocks the next tag.",
		species = { common = "Bastion Beetle", rare = "Crystal Warden", epic = "Shrine Lion", legendary = "Aegis Kirin" },
		color = AR.Guardian.color,
		cooldown = AR.Guardian.Runner.cooldown,
		duration = AR.Guardian.Runner.duration,
	},
	Tempest = {
		ability = "PULSE",
		short = "A blast that pushes Catchers away",
		desc = "A shockwave round you that pushes nearby Catchers away.",
		species = { common = "Thunder Toad", rare = "Riot Hound", epic = "Drum Oni", legendary = "Raiju" },
		color = AR.Tempest.color,
		cooldown = AR.Tempest.Runner.cooldown,
		duration = AR.Tempest.Runner.duration,
	},
	Rift = {
		ability = "PORTAL HOP",
		short = "Hop through a portal",
		desc = "Opens a portal and hops you through it to a spot ahead.",
		species = { common = "Ring Imp", rare = "Compass Hare", epic = "Astral Djinn", legendary = "Void Seraph" },
		color = AR.Rift.color,
		cooldown = AR.Rift.Runner.cooldown,
		duration = AR.Rift.Runner.duration,
	},
}

-- the family a species belongs to (hatch tables above, plus the new rigged pets not in a table yet)
EconomyConfig.EXTRA_SPECIES = { Mouse = "Decoy", Crow = "Decoy", Kitsune = "Decoy", ["Bastion Beetle"] = "Guardian", ["Thunder Toad"] = "Tempest", ["Ring Imp"] = "Rift", ["Crystal Warden"] = "Guardian", ["Riot Hound"] = "Tempest", ["Compass Hare"] = "Rift", ["Scroll Tanuki"] = "Decoy", ["Moonveil Moth"] = "Invisibility", ["Shrine Lion"] = "Guardian", ["Drum Oni"] = "Tempest", ["Astral Djinn"] = "Rift", ["Eclipse Tengu"] = "Decoy", ["Veil Nekomata"] = "Invisibility", ["Aegis Kirin"] = "Guardian", ["Raiju"] = "Tempest", ["Void Seraph"] = "Rift" } :: { [string]: string }

-- HOS-PET-012: roster pets go by the names on Hunter's concept library sheet (docs/pets/concepts). Internal
-- ids (a saved pet's `species`, attributes, asset folders) stay as they are, so no save migration is needed.
EconomyConfig.DISPLAY_NAMES = {
	Crow = "Shadow Crow",
	Kitsune = "Spirit Kitsune",
	["Prism Chameleon"] = "Prism Chameleon",
	["Mirage Manta"] = "Mirage Manta",
	["Grim Ghost"] = "Grin Ghost",
} :: { [string]: string }
-- the roster rarity of each roster pet (cofounder handoff). The hatch tables above are not changed by this
-- (HOS-PET-012: no hatch changes yet); a later ticket swaps roster pets into them.
EconomyConfig.SPECIES_RARITY = { Crow = "common", ["Bastion Beetle"] = "common", ["Thunder Toad"] = "common", ["Ring Imp"] = "common", Kitsune = "rare", ["Prism Chameleon"] = "common", ["Mirage Manta"] = "epic", ["Grim Ghost"] = "rare", ["Crystal Warden"] = "rare", ["Riot Hound"] = "rare", ["Compass Hare"] = "rare", ["Scroll Tanuki"] = "epic", ["Moonveil Moth"] = "epic", ["Shrine Lion"] = "epic", ["Drum Oni"] = "epic", ["Astral Djinn"] = "epic", ["Eclipse Tengu"] = "legendary", ["Veil Nekomata"] = "legendary", ["Aegis Kirin"] = "legendary", ["Raiju"] = "legendary", ["Void Seraph"] = "legendary" } :: { [string]: string }

function EconomyConfig.displayName(species: string?): string
	if type(species) ~= "string" or species == "" then
		return "Pet"
	end
	return EconomyConfig.DISPLAY_NAMES[species] or species
end
function EconomyConfig.familyOfSpecies(species: string): string?
	local extra = EconomyConfig.EXTRA_SPECIES[species]
	if extra then
		return extra
	end
	for fam, def in pairs(EconomyConfig.FAMILIES) do
		for _, sp in pairs(def.species) do
			if sp == species or (type(sp) == "table" and table.find(sp, species)) then -- a rarity can list several pets
				return fam
			end
		end
	end
	return nil
end

function EconomyConfig.speciesFor(family: string, rarity: string): string
	local f = EconomyConfig.FAMILIES[family]
	local sp = f and f.species[rarity]
	if type(sp) == "table" then
		sp = sp[1]
	end
	return sp or "Pet"
end

-- ===== shops (GDD 04 / 05, appendix C) =====
-- Only things that work today are listed (no fake prices). kind:
--   "trail" = consumable, worn by your egg for your next match
--   "burst" = consumable, used from the shop in the lobby
--   "case"  = permanent egg case look (pick one in the shop)
--   "entrance" = permanent lobby spawn effect
--   "trailPerm" = permanent egg trail (premium)
--   "abilityFx" = permanent ability colour pack (same hitboxes and timings)
--   "abilitySkin" = permanent look for one ability's effect, worn from cosmetics[slot] (HOS-VFX-RES-001)
--   "hatchFx" = permanent hatching ceremony
--   "knifeSkin" = permanent look for the Catcher's knife, worn from cosmetics.knifeSkin (HOS-WEP-001)
export type ShopItem = {
	id: string,
	name: string,
	wallet: string, -- "gold" | "gems"
	price: number,
	kind: string,
	desc: string,
	color: Color3,
	robux: number?, -- Gem items: the Robux price when bought outright
	productId: number?, -- its developer product (nil = Gems only)
	slot: string?, -- abilitySkin: the cosmetics slot it is worn from (Wear / Take off, like cases)
	skin: string?, -- knifeSkin: the template in ServerStorage.EOS_Assets.KnifeSkins
	rarity: string?, -- knifeSkin: common / rare / epic / legendary
	crateOnly: boolean?, -- knifeSkin: never in the daily store (crate only)
}
EconomyConfig.SHOP = {
	{ id = "trail_spark", name = "Sparkle Trail", wallet = "gold", price = 40, kind = "trail", desc = "Your egg leaves sparkles. One match.", color = Color3.fromRGB(255, 236, 140) },
	{ id = "trail_ember", name = "Ember Trail", wallet = "gold", price = 60, kind = "trail", desc = "Your egg leaves embers. One match.", color = Color3.fromRGB(255, 132, 64) },
	{ id = "burst_confetti", name = "Confetti Burst", wallet = "gold", price = 75, kind = "burst", desc = "Pop confetti over your head in the lobby.", color = Color3.fromRGB(255, 120, 200) },
	{ id = "case_frost", name = "Frost Egg Case", wallet = "gold", price = 900, kind = "case", desc = "An icy shell around the egg you carry. Yours to keep.", color = Color3.fromRGB(170, 230, 255) },
	{ id = "entrance_bolt", name = "Bolt Entrance", wallet = "gold", price = 1400, kind = "entrance", desc = "Arrive in the lobby with a lightning strike. Yours to keep.", color = Color3.fromRGB(150, 200, 255) },
	{ id = "case_sunset", name = "Sunset Egg Case", wallet = "gold", price = 2400, kind = "case", desc = "This week's Gold colorway. Yours to keep.", color = Color3.fromRGB(255, 160, 96) },
	{ id = "trailp_rainbow", name = "Rainbow Trail", wallet = "gems", price = 150, kind = "trailPerm", desc = "A rainbow trail on your egg in every match.", color = Color3.fromRGB(255, 120, 220), robux = 79, productId = 3718903405 },
	{ id = "fx_gold", name = "Gold Ability Colors", wallet = "gems", price = 250, kind = "abilityFx", desc = "A gold ring bursts under you every time your pet's ability fires.", color = Color3.fromRGB(255, 210, 58), robux = 119, productId = 3718903406 },
	-- HOS-VFX-RES-001 Rift portal skins (from Hunter's resource place). Gems only until Hunter sets Robux prices.
	{ id = "fx_rift_void", name = "Void Rift", wallet = "gems", price = 200, kind = "abilitySkin", slot = "riftSkin", desc = "Your Rift portals swirl violet. Same size and timing.", color = Color3.fromRGB(141, 75, 255) },
	{ id = "fx_rift_inferno", name = "Inferno Rift", wallet = "gems", price = 200, kind = "abilitySkin", slot = "riftSkin", desc = "Your Rift portals burn orange. Same size and timing.", color = Color3.fromRGB(255, 92, 36) },
	{ id = "fx_rift_frost", name = "Frost Rift", wallet = "gems", price = 200, kind = "abilitySkin", slot = "riftSkin", desc = "Your Rift portals glow icy blue. Same size and timing.", color = Color3.fromRGB(96, 206, 255) },
	{ id = "hatch_royal", name = "Royal Hatching", wallet = "gems", price = 350, kind = "hatchFx", desc = "A bigger hatching ceremony at the incubator.", color = Color3.fromRGB(200, 150, 255), robux = 159, productId = 3718903407 },
} :: { ShopItem }

-- HOS-WEP-001 dagger skins (Hunter, 17 Oct): the Catcher's knife looks like one of these, shrunk to knife
-- size (templates in ServerStorage.EOS_Assets.KnifeSkins). Looks only: same hits, reach and timing. Worn from
-- cosmetics.knifeSkin (Wear / Take off, like the Rift skins). rb_* = Roblox-made catalog gear (InsertService),
-- the rest from Hunter's LargerWepModels folder and our own Spirit Blast. The franchise models (Genshin,
-- Yamato, Korblox copy) were removed on Hunter's word (17 Oct 21:13Z); backup in docs/backups/HOS-WEP-001_*.
EconomyConfig.KNIFE_SKINS_IP_RISK = false
EconomyConfig.KNIFE_RARITY = {
	common = { price = 150, color = Color3.fromRGB(190, 198, 206) },
	rare = { price = 300, color = Color3.fromRGB(47, 168, 255) },
	epic = { price = 500, color = Color3.fromRGB(180, 77, 255) },
	legendary = { price = 900, color = Color3.fromRGB(255, 194, 28) },
}
-- the Weapon Crate (Shop > Weapons): a rarity by these odds (shown on the card), then one skin of it evenly;
-- a duplicate refunds Gems by rarity. Robux openings stay hidden until a developer product exists.
EconomyConfig.KNIFE_CRATE = {
	gems = 250,
	order = { "common", "rare", "epic", "legendary" },
	odds = { common = 60, rare = 27, epic = 10, legendary = 3 },
	refund = { common = 40, rare = 80, epic = 150, legendary = 300 },
	-- bad-luck protection (Hunter 17 Oct: "you shouldnt be able to just buy whatever you want", so the crate is the
	-- main way in): an Epic or better at the latest on the 10th opening since the last one, a Legendary on the 30th
	pity = { epic = 10, legendary = 30 },
}
-- Tiers re-cut 17 Oct (Hunter: "pick the ones that are top dog to be higher rarities"): a pyramid, 8 / 11 / 15 / 16.
EconomyConfig.KNIFE_SKINS = { -- skin (template name), name, rarity
	{ "spirit_blast", "Spirit Blast", "legendary" }, -- an energy ball in the hand (our own effect)
	{ "dual_spirit_blast", "Twin Spirit Blast", "legendary" },
	{ "midnight_scythe", "Midnight Scythe", "legendary" },
	{ "dark_greatsword", "Dark Greatsword", "legendary" },
	{ "rb_double_bladed_scythe", "Double-Bladed Scythe", "legendary" },
	{ "rb_bat_scythe", "Bat Scythe", "legendary" },
	{ "rb_dragon_s_flame_sword", "Dragon's Flame Sword", "legendary" },
	{ "dual_shattered_dimensions", "Twin Shattered Daggers", "legendary" },
	{ "rb_ice_dragon_slayer", "Ice Dragon Slayer", "epic" },
	{ "rb_darkheart", "Darkheart", "epic" },
	{ "rb_illumina", "Illumina", "epic" },
	{ "rb_crystal_blade_amethyst_attack", "Crystal Blade: Amethyst Attack", "epic" },
	{ "rb_midnight_sword", "Midnight Sword", "epic" },
	{ "rb_dagger_of_shattered_dimensions", "Dagger of Shattered Dimensions", "epic" },
	{ "rb_all_hallow_s_sword", "All Hallow's Sword", "epic" },
	{ "rb_red_laser_scythe", "Red Laser Scythe", "epic" },
	{ "rb_blue_laser_scythe", "Blue Laser Scythe", "epic" },
	{ "rb_green_laser_scythe", "Green Laser Scythe", "epic" },
	{ "rb_darkest_arts_sword", "Darkest Arts Sword", "epic" },
	{ "holy_sword", "Holy Sword", "rare" },
	{ "blood_blade", "Blood Blade", "rare" },
	{ "red_blade", "Crimson Fang", "rare" },
	{ "rb_ghostwalker", "Ghostwalker", "rare" },
	{ "rb_firebrand", "Firebrand", "rare" },
	{ "rb_venomshank", "Venomshank", "rare" },
	{ "dual_venomshank", "Twin Venomshanks", "rare" },
	{ "dual_black_iron_katana", "Twin Black Iron Katanas", "rare" },
	{ "dual_ghostfire_dagger", "Twin Ghostfire Daggers", "rare" },
	{ "rb_sword_of_starlight", "Sword of Starlight", "rare" },
	{ "rb_mythic_sword_of_the_earth", "Mythic Sword of the Earth", "rare" },
	{ "shadow_katana", "Shadow Katana", "rare" },
	{ "holiday_axe", "Frost Axe", "rare" },
	{ "rb_sword_of_swords", "Sword of Swords", "rare" },
	{ "rb_ghostfire_dagger", "Ghostfire Dagger", "rare" },
	{ "dual_danger_dagger", "Twin Danger Daggers", "common" },
	{ "rb_crimson_periastron_mu", "Crimson Periastron Mu", "common" },
	{ "rb_azure_periastron_alpha", "Azure Periastron Alpha", "common" },
	{ "rb_sword_of_the_epicblueness", "Sword of the Epicblueness", "common" },
	{ "rb_sword_of_the_epicredness", "Sword of the Epicredness", "common" },
	{ "rb_overseer_short_sword", "Overseer Short Sword", "common" },
	{ "rb_colossal_blade", "Colossal Blade", "common" },
	{ "rb_black_iron_katana", "Black Iron Katana", "common" },
	{ "rb_diamond_blade_sword", "Diamond Blade Sword", "common" },
	{ "rb_orc_blade", "Orc Blade", "common" },
	{ "rb_scythe", "Scythe", "common" },
	{ "rb_danger_dagger", "Danger Dagger", "common" },
	{ "rb_elegant_blade", "Elegant Blade", "common" },
	{ "rb_trusty_blade", "Trusty Blade", "common" },
	{ "rb_knight_s_elder_blade", "Knight's Elder Blade", "common" },
	{ "rb_spartan_sword", "Spartan Sword", "common" },
}
-- The daily weapon store (Hunter 17 Oct: "most of them should only be acquirable from the crate"): the only place a
-- skin can be bought outright. 4 slots a day, the same for everyone, new at 00:00 UTC. Only these skins can show up
-- there; every other one (all Legendaries, every twin, most Epics and Rares) is crate-only.
EconomyConfig.KNIFE_DAILY = {
	slots = { "epic", "rare", "common", "common" },
	price = { epic = 600, rare = 300, common = 150 },
	pool = {
		rb_illumina = true, rb_ice_dragon_slayer = true, rb_midnight_sword = true,
		holy_sword = true, rb_firebrand = true, rb_venomshank = true, rb_sword_of_starlight = true,
		rb_mythic_sword_of_the_earth = true, shadow_katana = true, rb_sword_of_swords = true,
		rb_crimson_periastron_mu = true, rb_azure_periastron_alpha = true, rb_sword_of_the_epicblueness = true,
		rb_sword_of_the_epicredness = true, rb_overseer_short_sword = true, rb_colossal_blade = true,
		rb_black_iron_katana = true, rb_diamond_blade_sword = true, rb_orc_blade = true, rb_scythe = true,
		rb_danger_dagger = true, rb_elegant_blade = true, rb_trusty_blade = true, rb_knight_s_elder_blade = true,
		rb_spartan_sword = true,
	},
}
for _, k in ipairs(EconomyConfig.KNIFE_SKINS) do
	if k[4] and not EconomyConfig.KNIFE_SKINS_IP_RISK then
		continue
	end
	local r = EconomyConfig.KNIFE_RARITY[k[3]]
	local daily = EconomyConfig.KNIFE_DAILY.pool[k[1]] == true
	table.insert(EconomyConfig.SHOP, {
		id = "knife_" .. k[1], name = k[2], wallet = "gems",
		price = if daily then EconomyConfig.KNIFE_DAILY.price[k[3]] or r.price else r.price,
		kind = "knifeSkin", slot = "knifeSkin",
		desc = "Your Catcher knife becomes the " .. k[2] .. ". Same reach and timing.", color = r.color,
		skin = k[1], rarity = k[3], crateOnly = not daily,
	} :: any)
end

-- today's daily weapons: { itemId, ... } in slot order, for UTC day `day` (= floor(os.time() / 86400)). The same on
-- every server: a seeded draw per slot, no repeats within a day, and nothing from yesterday's draw when the pool
-- has something else.
local function drawDaily(day: number, avoid: { [string]: boolean }?): { string }
	local D = EconomyConfig.KNIFE_DAILY
	-- (Random seeds next to each other start alike: scramble the day first and skip the first draws)
	local rng = Random.new((day * 2654435761 + 97) % 2147483647)
	for _ = 1, 4 do
		rng:NextNumber()
	end
	local picked, out = {}, {}
	for _, rarity in ipairs(D.slots) do
		local pool, fresh = {}, {}
		for _, k in ipairs(EconomyConfig.KNIFE_SKINS) do
			local id = "knife_" .. k[1]
			if k[3] == rarity and D.pool[k[1]] and not picked[id] then
				table.insert(pool, id)
				if not (avoid and avoid[id]) then
					table.insert(fresh, id)
				end
			end
		end
		local from = if #fresh > 0 then fresh else pool
		if #from > 0 then
			local id = from[rng:NextInteger(1, #from)]
			picked[id] = true
			table.insert(out, id)
		end
	end
	return out
end
function EconomyConfig.knifeDaily(day: number): { string }
	local avoid = {}
	for _, id in ipairs(drawDaily(day - 1, nil)) do
		avoid[id] = true
	end
	return drawDaily(day, avoid)
end
function EconomyConfig.knifeOnSale(itemId: string, epochSeconds: number): boolean
	return table.find(EconomyConfig.knifeDaily(math.floor(epochSeconds / 86400)), itemId) ~= nil
end

local byId: { [string]: ShopItem } = {}
for _, it in ipairs(EconomyConfig.SHOP) do
	byId[it.id] = it
end

function EconomyConfig.item(id: string): ShopItem?
	return byId[id]
end

function EconomyConfig.isConsumable(item: ShopItem): boolean
	return item.kind == "trail" or item.kind == "burst"
end

-- Shop tabs (16 Oct, by what you buy): which tab each kind of item sits on, and the Featured pair.
-- Gem items may also have robux + productId: bought outright with Robux (PurchaseService); no productId = Gems only.
EconomyConfig.TAB_OF_KIND = {
	trail = "trails", trailPerm = "trails", case = "cases",
	burst = "effects", entrance = "effects", abilityFx = "effects", hatchFx = "effects", abilitySkin = "effects",
	knifeSkin = "weapons", -- HOS-WEP-001: their own Weapons tab (Controllers/WeaponShopUI), not Cosmetics
}
EconomyConfig.FEATURED = {
	weekly = "case_sunset", -- this week's colourway (the card counts down to Monday 00:00 UTC)
	spotlight = "hatch_royal",
}

-- Game passes (GDD v0.4 Robux catalogue, 16 Oct). PassService mirrors ownership to the player attribute.
-- xpBonus is extra match XP (added, so VIP + 2x XP pays 2.25x). Never Gold, Gems, egg pieces or anything in a chase.
-- VIP also gives the nameplate + chat tag + one emote (Hunter, 16 Oct: VIP +25% XP, stacking with the 2x XP pass).
EconomyConfig.PASSES = {
	{ key = "vip", passId = 2038202784, name = "VIP", robux = 499, attr = "EOS_VIP", icon = "pass_vip", emote = "honored_one", xpBonus = 0.25,
		label = "VIP", desc = "+25% XP from every match (stacks with 2x XP), a gold VIP tag over your head and in chat, and the Honored One emote." },
	{ key = "xp2x", passId = 2040494361, name = "2x XP", robux = 199, attr = "EOS_XP2x", icon = "pass_xp2x", xpBonus = 1,
		label = "2X XP", desc = "Double the XP from every match, forever. Level up twice as fast." },
}
function EconomyConfig.pass(key: string): any?
	for _, p in ipairs(EconomyConfig.PASSES) do
		if p.key == key then return p end
	end
	return nil
end

-- Robux Gem packs (GDD 06): live developer products since 16 Oct (HOS-GEMS-001). A pack without a
-- productId is hidden. Purchased Gems are granted only by PurchaseService's ProcessReceipt, once per receipt.
EconomyConfig.GEM_PACKS = {
	{ gems = 100, robux = 49, productId = 3718899934 },
	{ gems = 225, robux = 99, productId = 3718899939 },
	{ gems = 500, robux = 199, productId = 3718899945, tag = "POPULAR" },
	{ gems = 1100, robux = 399, productId = 3718899949 },
	{ gems = 2400, robux = 799, productId = 3718899954 },
	{ gems = 5000, robux = 1499, productId = 3718899961, tag = "BEST VALUE" },
}

require(script.Parent:WaitForChild("HalloweenShop")).inject(EconomyConfig) -- HOS-HWN-001 Halloween pets on the Featured page until Nov 1
return EconomyConfig
