--!strict
-- Abilities.Invisibility (HOS-PET-001): the Invisibility archetype. Numbers: AbilityConfig.ARCHETYPES.Invisibility.
--  * Runner: the existing invisibility (below), the same for every species.
--  * Catcher: stub (the tether is not built yet).

local Shared = require(script.Parent.Shared)

local Invisibility = {}

local invisToken: { [Player]: any } = {}

-- Shared by every invisibility pet: the pet's summon is only a look. For `duration` seconds the body
-- carries EOS_Invisible; each client draws it (Controllers.Invisibility: ghosted for you, a faint
-- shimmer for everyone else, no tag/outline/egg sparkle) and NPC Catchers stop targeting it
-- (NpcService). Tags and collisions are unchanged: an opponent who finds you can still catch you.

local function endInvisible(plr: Player, species: string?, level: number?, token: any?)
	if token ~= nil and invisToken[plr] ~= token then
		return
	end
	invisToken[plr] = nil
	local char = plr.Character
	if char and char:GetAttribute("EOS_Invisible") then
		char:SetAttribute("EOS_Invisible", nil)
		char:SetAttribute("EOS_InvisibleSpecies", nil)
		char:SetAttribute("EOS_InvisibleLevel", nil)
		local r = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		Shared.fx({
			userId = plr.UserId,
			family = "Invisibility",
			kind = "reveal",
			pos = r and r.Position or nil,
			species = species,
			level = level,
		})
	end
end

local function invisible(plr: Player, duration: number, species: string?, level: number?)
	local char = plr.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return
	end
	local token = {}
	invisToken[plr] = token
	char:SetAttribute("EOS_InvisibleSpecies", species)
	char:SetAttribute("EOS_InvisibleLevel", level or 1)
	char:SetAttribute("EOS_Invisible", true)
	-- caught / role change / new body: it ends at once
	local conns: { RBXScriptConnection } = {}
	local function finish()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		endInvisible(plr, species, level, token)
	end
	table.insert(conns, plr:GetAttributeChangedSignal("EOS_Role"):Connect(finish))
	table.insert(conns, plr.CharacterRemoving:Connect(finish))
	task.delay(duration, finish)
end

function Invisibility.Runner(ctx: any): (boolean, string?)
	if not ctx.root then
		return false, "NO_CHARACTER"
	end
	invisible(ctx.player, ctx.def.duration, ctx.species, ctx.level)
	return true, nil
end

Invisibility.Catcher = Shared.stub("Invisibility", "Catcher")

function Invisibility.cleanup(plr: Player)
	if invisToken[plr] then
		local char = plr.Character
		endInvisible(plr, char and char:GetAttribute("EOS_InvisibleSpecies"), char and char:GetAttribute("EOS_InvisibleLevel"))
	end
end

return Invisibility
