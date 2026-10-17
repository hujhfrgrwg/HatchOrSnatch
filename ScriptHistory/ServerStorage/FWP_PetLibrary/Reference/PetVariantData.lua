--!strict
-- HOOKED-PET-VARIANTS-IMPORT-001: what each pet colour variant looks like and is called (art data only).
-- GENERATED from assets/pets/variants/variants.json by assets/pets/src/variant_export.py. Do not edit by
-- hand: change assets/pets/src/pet_variants.py, rebuild, upload, regenerate.
--
-- A variant is the pet's own prefab (ReplicatedStorage.Prefabs.Pets.<PetId>: same mesh, rig, animations)
-- with the body MeshPart's TextureID swapped for a 128 px sheet in the shared atlas's layout, and the Neon
-- <PetId>_Glow part recoloured where the pet has one. Tier 1 is the pet as it is today; tier 2 has two
-- stars, tier 3 three stars. Cosmetic only. The roll, saving, odds and effects belong to the pet system.
local PetVariantData = {}

export type Variant = {
	Name: string, -- short name, e.g. "Snow"
	DisplayName: string, -- the pet's full name in this variant, e.g. "Snow Lil' Otter"
	Texture: string, -- TextureID of the body MeshPart
	Glow: Color3?, -- Color of the Neon <PetId>_Glow part (nil: this pet has no glow part)
}
export type PetEntry = {
	BaseGlow: Color3?, -- the glow part's own colour (tier 1)
	BaseTexture: string?, -- the pet's own tier 1 texture, when its colours are not in the shared atlas image
	Tiers: { [number]: Variant },
}

PetVariantData.MaxTier = 3
PetVariantData.BaseTexture = "rbxassetid://117479335691231"

PetVariantData.Pets = {
	MiniFisherman = {
		Tiers = {
			[2] = { Name = "Red Coat", DisplayName = "Red Coat Mini Fisherman", Texture = "rbxassetid://88473232899439" },
			[3] = { Name = "Captain", DisplayName = "Mini Captain", Texture = "rbxassetid://138333208681396" },
		},
	},
	SandCrab = {
		Tiers = {
			[2] = { Name = "Blue", DisplayName = "Blue Sand Crab", Texture = "rbxassetid://130997533299631" },
			[3] = { Name = "Amethyst", DisplayName = "Amethyst Sand Crab", Texture = "rbxassetid://127045136396143" },
		},
	},
	PebbleFrog = {
		Tiers = {
			[2] = { Name = "Strawberry", DisplayName = "Strawberry Pebble Frog", Texture = "rbxassetid://92673739120946" },
			[3] = { Name = "Sapphire", DisplayName = "Sapphire Pebble Frog", Texture = "rbxassetid://132658696170797" },
		},
	},
	PufferPup = {
		Tiers = {
			[2] = { Name = "Bubblegum", DisplayName = "Bubblegum Puffer Pup", Texture = "rbxassetid://95102472674582" },
			[3] = { Name = "Midnight", DisplayName = "Midnight Puffer Pup", Texture = "rbxassetid://109493330615926" },
		},
	},
	SeagullScout = {
		Tiers = {
			[2] = { Name = "Puffin", DisplayName = "Puffin Scout", Texture = "rbxassetid://101183666156681" },
			[3] = { Name = "Flamingo", DisplayName = "Flamingo Scout", Texture = "rbxassetid://72233157953926" },
		},
	},
	LilOtter = {
		Tiers = {
			[2] = { Name = "Snow", DisplayName = "Snow Lil' Otter", Texture = "rbxassetid://110384113929847" },
			[3] = { Name = "Shadow", DisplayName = "Shadow Lil' Otter", Texture = "rbxassetid://86617817886551" },
		},
	},
	KoiSpirit = {
		Tiers = {
			[2] = { Name = "Midnight", DisplayName = "Midnight Koi Spirit", Texture = "rbxassetid://122697024120028" },
			[3] = { Name = "Golden", DisplayName = "Golden Koi Spirit", Texture = "rbxassetid://93532729130343" },
		},
	},
	HermitKnight = {
		Tiers = {
			[2] = { Name = "Black", DisplayName = "Black Hermit Knight", Texture = "rbxassetid://109633949163460" },
			[3] = { Name = "Golden", DisplayName = "Golden Hermit Knight", Texture = "rbxassetid://96294465275885" },
		},
	},
	ParrotPirate = {
		Tiers = {
			[2] = { Name = "Blue", DisplayName = "Blue Parrot Pirate", Texture = "rbxassetid://112504666156784" },
			[3] = { Name = "Ghost", DisplayName = "Ghost Parrot Pirate", Texture = "rbxassetid://74564716774793" },
		},
	},
	NarwhalCalf = {
		BaseGlow = Color3.fromRGB(70, 210, 255),
		Tiers = {
			[2] = { Name = "Coral", DisplayName = "Coral Narwhal Calf", Texture = "rbxassetid://94951358469615", Glow = Color3.fromRGB(255, 216, 96) },
			[3] = { Name = "Aurora", DisplayName = "Aurora Narwhal Calf", Texture = "rbxassetid://96497273175261", Glow = Color3.fromRGB(110, 255, 186) },
		},
	},
	JellyWisp = {
		BaseGlow = Color3.fromRGB(255, 100, 235),
		Tiers = {
			[2] = { Name = "Aqua", DisplayName = "Aqua Jelly Wisp", Texture = "rbxassetid://110109505863338", Glow = Color3.fromRGB(120, 250, 255) },
			[3] = { Name = "Ember", DisplayName = "Ember Jelly Wisp", Texture = "rbxassetid://75133015166993", Glow = Color3.fromRGB(255, 232, 110) },
		},
	},
	GoldenOtter = {
		BaseGlow = Color3.fromRGB(255, 200, 40),
		Tiers = {
			[2] = { Name = "Rose Gold", DisplayName = "Rose Gold Otter", Texture = "rbxassetid://100898801649944", Glow = Color3.fromRGB(255, 184, 160) },
			[3] = { Name = "Diamond", DisplayName = "Diamond Otter", Texture = "rbxassetid://82529706319288", Glow = Color3.fromRGB(150, 248, 255) },
		},
	},
	KrakenHatchling = {
		BaseGlow = Color3.fromRGB(255, 226, 120),
		Tiers = {
			[2] = { Name = "Abyss", DisplayName = "Abyss Kraken Hatchling", Texture = "rbxassetid://127201316808810", Glow = Color3.fromRGB(110, 255, 236) },
			[3] = { Name = "Void", DisplayName = "Void Kraken Hatchling", Texture = "rbxassetid://90944437994077", Glow = Color3.fromRGB(255, 110, 236) },
		},
	},
	PhoenixGull = {
		BaseGlow = Color3.fromRGB(255, 220, 70),
		Tiers = {
			[2] = { Name = "Blue Flame", DisplayName = "Blue Flame Phoenix Gull", Texture = "rbxassetid://80865253452617", Glow = Color3.fromRGB(160, 242, 255) },
			[3] = { Name = "Shadow", DisplayName = "Shadow Phoenix Gull", Texture = "rbxassetid://92202413822405", Glow = Color3.fromRGB(255, 150, 248) },
		},
	},
	LeviathanPup = {
		BaseGlow = Color3.fromRGB(120, 224, 255),
		Tiers = {
			[2] = { Name = "Magma", DisplayName = "Magma Leviathan Pup", Texture = "rbxassetid://135357185676757", Glow = Color3.fromRGB(255, 190, 60) },
			[3] = { Name = "Glacier", DisplayName = "Glacier Leviathan Pup", Texture = "rbxassetid://107526419035280", Glow = Color3.fromRGB(110, 255, 186) },
		},
	},
	LilAlien = {
		BaseGlow = Color3.fromRGB(255, 70, 230),
		BaseTexture = "rbxassetid://133653275788650",
		Tiers = {
			[2] = { Name = "Martian", DisplayName = "Lil' Martian", Texture = "rbxassetid://118950330939812", Glow = Color3.fromRGB(90, 240, 255) },
			[3] = { Name = "Galaxy", DisplayName = "Galaxy Lil' Alien", Texture = "rbxassetid://116838306000032", Glow = Color3.fromRGB(255, 222, 90) },
		},
	},
	SaucerPilot = {
		BaseGlow = Color3.fromRGB(140, 255, 50),
		BaseTexture = "rbxassetid://133653275788650",
		Tiers = {
			[2] = { Name = "Stealth", DisplayName = "Stealth Saucer Pilot", Texture = "rbxassetid://82308497246556", Glow = Color3.fromRGB(255, 70, 70) },
			[3] = { Name = "Golden", DisplayName = "Golden Saucer Pilot", Texture = "rbxassetid://103164207889876", Glow = Color3.fromRGB(110, 240, 255) },
		},
	},
	MiniMothership = {
		BaseGlow = Color3.fromRGB(140, 255, 50),
		BaseTexture = "rbxassetid://90203538007548",
		Tiers = {
			[2] = { Name = "Magma", DisplayName = "Magma Mini Mothership", Texture = "rbxassetid://74189997006497", Glow = Color3.fromRGB(255, 180, 50) },
			[3] = { Name = "Phantom", DisplayName = "Phantom Mini Mothership", Texture = "rbxassetid://102893958993245", Glow = Color3.fromRGB(120, 225, 255) },
		},
	},
	MechaInvader = {
		BaseGlow = Color3.fromRGB(150, 255, 50),
		BaseTexture = "rbxassetid://90203538007548",
		Tiers = {
			[2] = { Name = "Inferno", DisplayName = "Inferno Mecha Invader", Texture = "rbxassetid://123239766641465", Glow = Color3.fromRGB(255, 120, 40) },
			[3] = { Name = "Celestial", DisplayName = "Celestial Mecha Invader", Texture = "rbxassetid://77654973901758", Glow = Color3.fromRGB(110, 240, 255) },
		},
	},
	VoidOverlord = {
		BaseGlow = Color3.fromRGB(120, 255, 44),
		BaseTexture = "rbxassetid://90203538007548",
		Tiers = {
			[2] = { Name = "Crimson", DisplayName = "Crimson Void Overlord", Texture = "rbxassetid://95466174920938", Glow = Color3.fromRGB(255, 60, 60) },
			[3] = { Name = "Radiant", DisplayName = "Radiant Void Overlord", Texture = "rbxassetid://80002575202861", Glow = Color3.fromRGB(120, 235, 255) },
		},
	},
	SushiCat = {
		BaseTexture = "rbxassetid://105275260323414",
		Tiers = {
			[2] = { Name = "Smoky", DisplayName = "Smoky Sushi Cat", Texture = "rbxassetid://87250685761764" },
			[3] = { Name = "Golden", DisplayName = "Golden Sushi Cat", Texture = "rbxassetid://87602842170267" },
		},
	},
	SurferDog = {
		BaseGlow = Color3.fromRGB(255, 244, 170),
		BaseTexture = "rbxassetid://105275260323414",
		Tiers = {
			[2] = { Name = "Husky", DisplayName = "Surfer Husky", Texture = "rbxassetid://90378662891040", Glow = Color3.fromRGB(255, 244, 170) },
			[3] = { Name = "Neon", DisplayName = "Neon Surfer Dog", Texture = "rbxassetid://120143379934426", Glow = Color3.fromRGB(255, 90, 230) },
		},
	},
	CozyLion = {
		BaseGlow = Color3.fromRGB(255, 238, 204),
		BaseTexture = "rbxassetid://105275260323414",
		Tiers = {
			[2] = { Name = "Snow", DisplayName = "Snow Lion", Texture = "rbxassetid://130767290547231", Glow = Color3.fromRGB(255, 250, 240) },
			[3] = { Name = "Cotton Candy", DisplayName = "Cotton Candy Lion", Texture = "rbxassetid://91711093621389", Glow = Color3.fromRGB(255, 214, 90) },
		},
	},
	FloatieGiraffe = {
		BaseTexture = "rbxassetid://105275260323414",
		Tiers = {
			[2] = { Name = "Flamingo", DisplayName = "Flamingo Giraffe", Texture = "rbxassetid://138407759595512" },
			[3] = { Name = "Galaxy", DisplayName = "Galaxy Giraffe", Texture = "rbxassetid://70776914872611" },
		},
	},
	FireDragon = {
		BaseGlow = Color3.fromRGB(255, 150, 40),
		BaseTexture = "rbxassetid://105275260323414",
		Tiers = {
			[2] = { Name = "Frost", DisplayName = "Frost Dragon", Texture = "rbxassetid://79074186876132", Glow = Color3.fromRGB(130, 240, 255) },
			[3] = { Name = "Bone", DisplayName = "Bone Dragon", Texture = "rbxassetid://138271435355602", Glow = Color3.fromRGB(190, 90, 255) },
		},
	},
	ShadesShark = {
		BaseTexture = "rbxassetid://99184087157244",
		Tiers = {
			[2] = { Name = "Great White", DisplayName = "Great White Shades Shark", Texture = "rbxassetid://131797255260407" },
			[3] = { Name = "Golden", DisplayName = "Golden Shades Shark", Texture = "rbxassetid://83575231984896" },
		},
	},
	GamerAxolotl = {
		BaseTexture = "rbxassetid://99184087157244",
		Tiers = {
			[2] = { Name = "Wild", DisplayName = "Wild Gamer Axolotl", Texture = "rbxassetid://117896963799315" },
			[3] = { Name = "Cyber", DisplayName = "Cyber Gamer Axolotl", Texture = "rbxassetid://76246232582674" },
		},
	},
	BanditRaccoon = {
		BaseTexture = "rbxassetid://99184087157244",
		Tiers = {
			[2] = { Name = "Arctic", DisplayName = "Arctic Bandit Raccoon", Texture = "rbxassetid://99152137472402" },
			[3] = { Name = "Shadow", DisplayName = "Shadow Bandit Raccoon", Texture = "rbxassetid://91764565928168" },
		},
	},
	NinjaPenguin = {
		BaseTexture = "rbxassetid://99184087157244",
		Tiers = {
			[2] = { Name = "Emperor", DisplayName = "Emperor Ninja Penguin", Texture = "rbxassetid://113148332781940" },
			[3] = { Name = "Golden", DisplayName = "Golden Ninja", Texture = "rbxassetid://92525810465658" },
		},
	},
	RoboCrab = {
		BaseTexture = "rbxassetid://99184087157244",
		Tiers = {
			[2] = { Name = "Steel Blue", DisplayName = "Steel Blue Robo Crab", Texture = "rbxassetid://83398078015166" },
			[3] = { Name = "Gold Mech", DisplayName = "Gold Mech Robo Crab", Texture = "rbxassetid://109370048596115" },
		},
	},
	VikingWalrus = {
		BaseTexture = "rbxassetid://99184087157244",
		Tiers = {
			[2] = { Name = "Arctic", DisplayName = "Arctic Viking Walrus", Texture = "rbxassetid://130240865083959" },
			[3] = { Name = "Jarl", DisplayName = "Jarl Walrus", Texture = "rbxassetid://87810304274095" },
		},
	},
	ArmoredRex = {
		BaseTexture = "rbxassetid://99184087157244",
		Tiers = {
			[2] = { Name = "Blue", DisplayName = "Blue Armored Rex", Texture = "rbxassetid://80292714018615" },
			[3] = { Name = "Gold Armor", DisplayName = "Gold Armor Rex", Texture = "rbxassetid://87163481858395" },
		},
	},
	FrostYeti = {
		BaseTexture = "rbxassetid://99184087157244",
		Tiers = {
			[2] = { Name = "Storm", DisplayName = "Storm Frost Yeti", Texture = "rbxassetid://132836494959031" },
			[3] = { Name = "Aurora", DisplayName = "Aurora Frost Yeti", Texture = "rbxassetid://113297404084118" },
		},
	},
	ThunderWolf = {
		BaseGlow = Color3.fromRGB(255, 228, 40),
		BaseTexture = "rbxassetid://99184087157244",
		Tiers = {
			[2] = { Name = "Frost", DisplayName = "Frost Wolf", Texture = "rbxassetid://128104050861008", Glow = Color3.fromRGB(90, 220, 255) },
			[3] = { Name = "Shadow Storm", DisplayName = "Shadow Storm Wolf", Texture = "rbxassetid://126637943170219", Glow = Color3.fromRGB(192, 90, 255) },
		},
	},
	LavaScorpion = {
		BaseGlow = Color3.fromRGB(255, 136, 30),
		BaseTexture = "rbxassetid://99184087157244",
		Tiers = {
			[2] = { Name = "Toxic", DisplayName = "Toxic Lava Scorpion", Texture = "rbxassetid://86039238332672", Glow = Color3.fromRGB(124, 255, 60) },
			[3] = { Name = "Void", DisplayName = "Void Scorpion", Texture = "rbxassetid://120889835591385", Glow = Color3.fromRGB(200, 80, 255) },
		},
	},
} :: { [string]: PetEntry }

-- The variant's data, or nil for tier 1, an unknown pet or an unknown tier.
function PetVariantData.Get(petId: string, tier: number?): Variant?
	local pet = PetVariantData.Pets[petId]
	return if pet and tier then pet.Tiers[tier] else nil
end

-- A saved or received tier made safe: 1 unless this pet really has that tier.
function PetVariantData.Normalize(petId: string, tier: any): number
	local n = tonumber(tier)
	if n and n == math.floor(n) and PetVariantData.Get(petId, n) then
		return n
	end
	return 1
end

-- The pet's full name in this tier (`baseName` is the pet's own name, returned for tier 1).
function PetVariantData.DisplayName(petId: string, tier: number?, baseName: string): string
	local variant = PetVariantData.Get(petId, tier)
	return if variant then variant.DisplayName else baseName
end

-- Recolours a pet model made by PetModels.Pet (or any clone of the prefab). Tier 1 or an unknown tier puts
-- the pet's own colours back, so one model can be re-used. Sets the attribute VariantTier and returns it.
function PetVariantData.Apply(model: Model, petId: string, tier: number?): number
	local applied = PetVariantData.Normalize(petId, tier)
	local variant = PetVariantData.Get(petId, applied)
	local pet = PetVariantData.Pets[petId]
	local body = model:FindFirstChild(petId)
	if body and body:IsA("MeshPart") then
		body.TextureID = if variant then variant.Texture else ((pet and pet.BaseTexture) or PetVariantData.BaseTexture)
	end
	local glow = model:FindFirstChild(petId .. "_Glow")
	if glow and glow:IsA("BasePart") then
		local color = if variant then variant.Glow else (pet and pet.BaseGlow)
		if color then
			glow.Color = color
		end
	end
	model:SetAttribute("VariantTier", applied)
	return applied
end

-- Every variant texture (for ContentProvider:PreloadAsync).
function PetVariantData.Textures(): { string }
	local list = {}
	for _, pet in pairs(PetVariantData.Pets) do
		for _, variant in pairs(pet.Tiers) do
			table.insert(list, variant.Texture)
		end
	end
	table.sort(list)
	return list
end

return PetVariantData
