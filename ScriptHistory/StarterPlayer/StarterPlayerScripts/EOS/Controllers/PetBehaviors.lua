--!strict
-- PetBehaviors (client): which module drives each rigged pet species (follower + ability summon).
-- Every module has: INTRO, newFollower(level, root), respawnFollower(f, root), updateFollower(f, root, dt),
-- summon(who, level), poof(pos, level) -> boolean.

local PetBehaviors = {}

PetBehaviors.MODULES = {
	Crow = "CrowPet",
	Kitsune = "KitsunePet",
	["Prism Chameleon"] = "ChameleonPet",
	["Bastion Beetle"] = "BeetlePet", -- HOS-PET-013
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
