--!strict
-- PetBehaviors (client): which module drives each rigged pet species (follower + ability summon).
-- Every module has: INTRO, newFollower(level, root), respawnFollower(f, root), updateFollower(f, root, dt),
-- summon(who, level), poof(pos, level) -> boolean.

local PetBehaviors = {}

PetBehaviors.MODULES = {
	Crow = "CrowPet",
	Kitsune = "KitsunePet",
	["Prism Chameleon"] = "ChameleonPet",
	["Mirage Manta"] = "MantaPet",
	["Bastion Beetle"] = "BeetlePet", -- HOS-PET-013
	["Thunder Toad"] = "ToadPet", -- HOS-PET-014
	["Ring Imp"] = "ImpPet", -- HOS-PET-017
	["Grim Ghost"] = "GhostPet", -- HOS-PET-018 Grin Ghost
	["Crystal Warden"] = "WardenPet", -- HOS-PET-019
	["Riot Hound"] = "HoundPet", -- HOS-PET-020
	["Compass Hare"] = "HarePet", -- HOS-PET-021 Compass Hare, Rift Rare (tools/pet-kit/hare/hare.py)
	["Scroll Tanuki"] = "TanukiPet", -- HOS-PET-022 Scroll Tanuki, Decoy Epic (tools/pet-kit/tanuki/tanuki.py)
	["Moonveil Moth"] = "MothPet", -- HOS-PET-023 Moonveil Moth, Invisibility Epic (tools/pet-kit/moth/moth.py)
	["Shrine Lion"] = "LionPet", -- HOS-PET-024 Shrine Lion, Guardian Epic (tools/pet-kit/lion/lion.py)
	["Drum Oni"] = "OniPet", -- HOS-PET-025 Drum Oni, Tempest Epic (tools/pet-kit/oni/oni.py)
	["Astral Djinn"] = "DjinnPet", -- HOS-PET-026 Astral Djinn, Rift Epic (tools/pet-kit/djinn/djinn.py)
	["Eclipse Tengu"] = "TenguPet", -- HOS-PET-027 Eclipse Tengu, Decoy Legendary (tools/pet-kit/tengu/tengu.py)
	["Veil Nekomata"] = "NekoPet", -- HOS-PET-028 Veil Nekomata, Invisibility Legendary (tools/pet-kit/neko/neko.py)
	["Aegis Kirin"] = "KirinPet", -- HOS-PET-029 Aegis Kirin, Guardian Legendary (tools/pet-kit/kirin/kirin.py)
	["Raiju"] = "RaijuPet", -- HOS-PET-030 Raiju, Tempest Legendary (tools/pet-kit/raiju/raiju.py)
	["Void Seraph"] = "SeraphPet", -- HOS-PET-031 Void Seraph, Rift Legendary (tools/pet-kit/seraph/seraph.py)
	["Pumpkin Wraith"] = "WraithPet", -- HOS-HWN-001 Halloween Pumpkin Wraith
	["Witch's Cat"] = "WitchCatPet", -- HOS-HWN-001 Halloween Witch's Cat
	["Mummy"] = "MummyPet", -- HOS-HWN-001 Halloween Mummy
	["Bone Dragon"] = "DragonPet", -- HOS-HWN-001 Halloween Bone Dragon
} :: { [string]: string }

local cache: { [string]: any } = {}

function PetBehaviors.get(species: any): any
	if type(species) ~= "string" then
		return nil
	end
	local b = cache[species]
	if b == nil then
		local name = PetBehaviors.MODULES[species]
		local mod = name and script.Parent:FindFirstChild(name)
		b = if mod then require(mod :: ModuleScript) else false
		cache[species] = b
	end
	return if b then b else nil
end

return PetBehaviors
