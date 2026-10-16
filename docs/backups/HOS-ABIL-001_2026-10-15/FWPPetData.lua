--!nocheck
-- FWPPetData: labels for the pets and eggs ported from Fishing with Pets! (Oct 15 2026).
-- Copied from that game's PetConfig / EggConfig / PetVariantData at port time (display only).
local D = {}

D.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
D.Rarities = {
	Common = Color3.fromRGB(196, 206, 220),
	Uncommon = Color3.fromRGB(70, 214, 88),
	Rare = Color3.fromRGB(60, 170, 255),
	Epic = Color3.fromRGB(190, 84, 255),
	Legendary = Color3.fromRGB(255, 190, 60),
	Mythic = Color3.fromRGB(200, 70, 245),
}
D.Archetypes = { Merchant = "Fish sell for more", Scout = "Find new fish", Scholar = "More XP", Alchemist = "More mutations", Treasure = "Finds coin treasure", Lucky = "Rarer fish", Skipper = "Extra bounces", Fetcher = "Brings extra fish", BossLure = "Bosses bite more", Aim = "Bigger Perfect zone", Packer = "More bag space" }
D.Pets = {
	MiniFisherman = { Name = "Mini Fisherman", Rarity = "Common", Archetype = "Scholar", Note = "Starter pet", Eggs = { "Starter" } },
	SandCrab = { Name = "Sand Crab", Rarity = "Common", Archetype = "Merchant", Note = "", Eggs = { "Basic", "Shiny" } },
	PebbleFrog = { Name = "Pebble Frog", Rarity = "Common", Archetype = "Skipper", Note = "", Eggs = { "Basic", "Shiny" } },
	ShadesShark = { Name = "Shades Shark", Rarity = "Common", Archetype = "Lucky", Note = "", Eggs = { "Basic" } },
	GamerAxolotl = { Name = "Gamer Axolotl", Rarity = "Common", Archetype = "Scholar", Note = "", Eggs = { "Basic" } },
	PufferPup = { Name = "Puffer Pup", Rarity = "Uncommon", Archetype = "Lucky", Note = "", Eggs = { "Basic", "Shiny", "Golden" } },
	SeagullScout = { Name = "Seagull Scout", Rarity = "Uncommon", Archetype = "Aim", Note = "", Eggs = { "Basic", "Shiny", "Golden" } },
	LilOtter = { Name = "Lil' Otter", Rarity = "Uncommon", Archetype = "Merchant", Note = "", Eggs = { "Basic", "Shiny", "Golden" } },
	RoboCrab = { Name = "Robo Crab", Rarity = "Uncommon", Archetype = "Skipper", Note = "", Eggs = { "Shiny" } },
	BanditRaccoon = { Name = "Bandit Raccoon", Rarity = "Uncommon", Archetype = "Treasure", Note = "", Eggs = { "Basic" } },
	NinjaPenguin = { Name = "Ninja Penguin", Rarity = "Uncommon", Archetype = "Aim", Note = "", Eggs = { "Shiny" } },
	KoiSpirit = { Name = "Koi Spirit", Rarity = "Rare", Archetype = "Alchemist", Note = "", Eggs = { "Basic", "Shiny", "Golden", "Cosmic", "Royal" } },
	HermitKnight = { Name = "Hermit Knight", Rarity = "Rare", Archetype = "Skipper", Note = "", Eggs = { "Basic", "Shiny", "Golden", "Cosmic", "Royal" } },
	ParrotPirate = { Name = "Parrot Pirate", Rarity = "Rare", Archetype = "Treasure", Note = "", Eggs = { "Basic", "Shiny", "Golden", "Cosmic", "Royal" } },
	SushiCat = { Name = "Sushi Cat", Rarity = "Rare", Archetype = "Fetcher", Note = "", Eggs = { "Basic", "Shiny", "Golden", "Cosmic", "Royal" } },
	FloatieGiraffe = { Name = "Floatie Giraffe", Rarity = "Rare", Archetype = "Lucky", Note = "", Eggs = { "Basic", "Shiny", "Golden", "Cosmic", "Royal" } },
	VikingWalrus = { Name = "Viking Walrus", Rarity = "Rare", Archetype = "BossLure", Note = "", Eggs = { "Shiny", "Cosmic", "Royal" } },
	ArmoredRex = { Name = "Armored Rex", Rarity = "Rare", Archetype = "Merchant", Note = "", Eggs = { "Golden", "Cosmic", "Royal" } },
	FrostYeti = { Name = "Frost Yeti", Rarity = "Rare", Archetype = "Packer", Note = "", Eggs = { "Golden", "Cosmic", "Royal" } },
	NarwhalCalf = { Name = "Narwhal Calf", Rarity = "Epic", Archetype = "Lucky", Note = "", Eggs = { "Shiny", "Golden", "Cosmic", "Royal" } },
	JellyWisp = { Name = "Jelly Wisp", Rarity = "Epic", Archetype = "Alchemist", Note = "", Eggs = { "Shiny", "Golden", "Cosmic", "Royal" } },
	SurferDog = { Name = "Surfer Dog", Rarity = "Epic", Archetype = "Skipper", Note = "", Eggs = { "Shiny", "Golden", "Cosmic", "Royal" } },
	CozyLion = { Name = "Cozy Lion", Rarity = "Epic", Archetype = "Scholar", Note = "", Eggs = { "Shiny", "Golden", "Cosmic", "Royal" } },
	ThunderWolf = { Name = "Thunder Wolf", Rarity = "Epic", Archetype = "Fetcher", Note = "", Eggs = { "Golden", "Cosmic", "Royal" } },
	LavaScorpion = { Name = "Lava Scorpion", Rarity = "Epic", Archetype = "Alchemist", Note = "", Eggs = { "Golden", "Cosmic", "Royal" } },
	KrakenHatchling = { Name = "Kraken Hatchling", Rarity = "Legendary", Archetype = "Lucky", Note = "Deep sea only", Eggs = { "Cosmic" } },
	PhoenixGull = { Name = "Phoenix Gull", Rarity = "Legendary", Archetype = "Scholar", Note = "", Eggs = { "Golden", "Cosmic", "Royal" } },
	FireDragon = { Name = "Fire Dragon", Rarity = "Legendary", Archetype = "Merchant", Note = "", Eggs = { "Golden", "Cosmic", "Royal" } },
	LeviathanPup = { Name = "Leviathan Pup", Rarity = "Mythic", Archetype = "Lucky", Note = "Deep sea only", Eggs = { "Cosmic" } },
	LilAlien = { Name = "Lil' Alien", Rarity = "Epic", Archetype = "Packer", Note = "Alien Egg exclusive", Eggs = { "Alien" } },
	MiniMothership = { Name = "Mini Mothership", Rarity = "Epic", Archetype = "Merchant", Note = "Alien Egg exclusive", Eggs = { "Alien" } },
	SaucerPilot = { Name = "Saucer Pilot", Rarity = "Legendary", Archetype = "Alchemist", Note = "Alien Egg exclusive", Eggs = { "Alien" } },
	MechaInvader = { Name = "Mecha Invader", Rarity = "Legendary", Archetype = "BossLure", Note = "Alien Egg exclusive", Eggs = { "Alien" } },
	VoidOverlord = { Name = "Void Overlord", Rarity = "Mythic", Archetype = "Scholar", Note = "Alien Egg exclusive", Eggs = { "Alien" } },
	CloudWhale = { Name = "Cloud Whale", Rarity = "Mythic", Archetype = "Merchant", Note = "Huge exclusive", Eggs = {  } },
	TreasureGolem = { Name = "Treasure Golem", Rarity = "Mythic", Archetype = "Treasure", Note = "Huge exclusive", Eggs = {  } },
	GoldenOtter = { Name = "Golden Otter", Rarity = "Epic", Archetype = "Merchant", Note = "Archived (no longer drops)", Eggs = {  } },
}
-- Oct 15 2026: pets grouped by the EOS Runner ability they'd be a skin for (each ability has its own
-- pool, ordered common -> rarest). "Left out" = not used for now, with the reason.
D.Pools = {
	{ Id = "DoubleDash", Title = "Double Dash", Blurb = "two quick dashes, Jett-style", Color = Color3.fromRGB(255, 140, 60), Pets = { "ShadesShark", "SurferDog", "ThunderWolf", "PhoenixGull", "FireDragon" } },
	{ Id = "Invisibility", Title = "Invisibility", Blurb = "fade out for a few seconds", Color = Color3.fromRGB(150, 200, 255), Pets = { "KoiSpirit", "JellyWisp", "SaucerPilot", "VoidOverlord" } },
	{ Id = "Decoy", Title = "Decoy", Blurb = "a running copy of you", Color = Color3.fromRGB(255, 196, 92), Pets = { "GamerAxolotl", "BanditRaccoon", "NinjaPenguin", "LilAlien", "MiniMothership" } },
	{ Id = "Shield", Title = "Shield", Blurb = "a bubble that blocks one tag", Color = Color3.fromRGB(120, 236, 220), Pets = { "PebbleFrog", "PufferPup", "HermitKnight", "TreasureGolem" } },
	{ Id = "Wall", Title = "Wall", Blurb = "drop an obstruction in front of you", Color = Color3.fromRGB(176, 150, 255), Pets = { "SandCrab", "RoboCrab", "ArmoredRex", "FrostYeti", "LavaScorpion", "MechaInvader" } },
	{ Id = "PetTackle", Title = "Pet Tackle", Blurb = "your pet bowls a Catcher over", Color = Color3.fromRGB(255, 96, 96), Pets = { "VikingWalrus", "CozyLion", "NarwhalCalf", "KrakenHatchling", "LeviathanPup" } },
}
D.LeftOut = {
	MiniFisherman = "fishing character with a rod",
	LilOtter = "plain; Golden Otter is the same model",
	GoldenOtter = "recolour of Lil' Otter (archived)",
	SeagullScout = "a scout bird; no scouting ability now",
	ParrotPirate = "pirate/fishing theme, busy silhouette",
	SushiCat = "food/fishing theme",
	FloatieGiraffe = "pool-floatie theme",
	CloudWhale = "Huge pet: lobby showpiece or trophy",
}
D.LeftOutOrder = { "MiniFisherman", "LilOtter", "GoldenOtter", "SeagullScout", "ParrotPirate", "SushiCat", "FloatieGiraffe", "CloudWhale" }
D.Rows = {}
for _, pool in D.Pools do
	table.insert(D.Rows, { Title = pool.Title, Sub = pool.Blurb, Color = pool.Color, Pets = pool.Pets, Ability = pool.Title })
end
table.insert(D.Rows, { Title = "Left out for now", Sub = "not in any ability pool yet", Color = Color3.fromRGB(150, 150, 160), Pets = D.LeftOutOrder })
D.AbilityOf = {}
for _, pool in D.Pools do
	for _, id in pool.Pets do
		D.AbilityOf[id] = pool.Title
	end
end
D.Float = { PhoenixGull = 2.2, PufferPup = 1.2, SeagullScout = 2, KoiSpirit = 1.6, ParrotPirate = 2, NarwhalCalf = 1.4, JellyWisp = 2, LeviathanPup = 1.8, KrakenHatchling = 1.6, VoidOverlord = 1.2, SaucerPilot = 1.6, MiniMothership = 1.6 } -- hover height (studs at 1x)
D.Huge = { CloudWhale = 2.3 } -- Treasure Golem shows at normal size in the Shield pool
D.Eggs = {
	{ Id = "Starter", Name = "Starter Egg", Source = "Starter", Odds = "Always hatches Mini Fisherman", Hatch = "30 s" },
	{ Id = "Basic", Name = "Basic Egg", Source = "Fishing", Odds = "Common 50 · Uncommon 38 · Rare 12", Hatch = "3 min" },
	{ Id = "Shiny", Name = "Shiny Egg", Source = "Fishing", Odds = "Common 15 · Uncommon 45 · Rare 28 · Epic 12", Hatch = "10 min" },
	{ Id = "Golden", Name = "Golden Egg", Source = "Fishing", Odds = "Uncommon 20 · Rare 45 · Epic 27 · Legendary 8", Hatch = "30 min" },
	{ Id = "Cosmic", Name = "Cosmic Egg", Source = "Fishing (deep sea)", Odds = "Rare 40 · Epic 42 · Legendary 17.5 · Mythic 0.5", Hatch = "2 h" },
	{ Id = "Royal", Name = "Royal Egg", Source = "Robux", Odds = "Rare 60 · Epic 35 · Legendary 5", Hatch = "instant" },
	{ Id = "Alien", Name = "Alien Egg", Source = "Robux (limited)", Odds = "Lil' Alien 62 · Mothership 25 · Saucer 9 · Mecha 3.5 · Void 0.5", Hatch = "instant" },
}
return D
