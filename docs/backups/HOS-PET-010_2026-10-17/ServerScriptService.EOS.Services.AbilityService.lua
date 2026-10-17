--!strict
-- AbilityService: the equipped pet's ability in a match (GDD v0.4 section 13). One pet = one ability.
-- HOS-PET-001: five archetypes (AbilityConfig.ORDER: Decoy, Invisibility, Guardian, Tempest, Rift). The
-- pet's family is its archetype; the player's role when they press picks the Runner or Catcher handler
-- (ServerScriptService.EOS.Abilities.<Archetype>). Every number is in AbilityConfig, per archetype and
-- role; a species only picks looks and sound (AbilityCosmetics).
-- The server owns cooldowns and effects; the family is fixed for the whole match (no mid-match swaps),
-- and the cooldown carries over when a Runner becomes a Catcher.
--  * The match's starting Catcher has no pet ability (EOS_PetAbilityOff hides the button). NPCs never use one.
--  * A handler that refuses (a stub, an invalid teleport) costs nothing: the cooldown starts only on success.
--  * Capture asks Abilities.Shared before a tag lands, so a "blocks one tag" charge can stop it.
-- Everyone sees a short pet summon + ring when an ability fires (AbilityFx); followers stay private.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedRS = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local AbilityConfig = require(SharedRS:WaitForChild("AbilityConfig"))
local EconomyConfig = require(SharedRS:WaitForChild("EconomyConfig"))
local Net = require(SharedRS:WaitForChild("Net"))
local ProfileLogic = require(ServerScriptService.EOS.Core.ProfileLogic)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)

local AbilitiesFolder = ServerScriptService.EOS:WaitForChild("Abilities")
local Shared = require(AbilitiesFolder:WaitForChild("Shared"))
local ARCH: { [string]: any } = {}
for _, name in ipairs(AbilityConfig.ORDER) do
	ARCH[name] = require(AbilitiesFolder:WaitForChild(name))
end

local AbilityService = {}
AbilityService.Shared = Shared -- later abilities and tests: validPosition, grantTagBlock

type Loadout = { family: string, species: string, rarity: string, gold: boolean, readyAt: number, level: number }
local loadouts: { [Player]: Loadout } = {}

-- a pet's mutation level (1..3); pets have no level field yet, so 1 until they do
local function petLevel(pet: any): number
	local lv = tonumber(pet and (pet.level or pet.mutation)) or 1
	return math.clamp(math.floor(lv), 1, 3)
end

-- Studio pet test, set on Workspace (live servers ignore it): EOS_TestPet = species ("Crow"),
-- EOS_TestPetLevel = 1..3 (or 0 = cycle 1 > 2 > 3, one level per use), EOS_TestCooldown = seconds.
-- Copied onto each player as they join (EOS_TestPet / EOS_TestPetLevel player attributes).
-- A player's EOS_TestPetFamily picks any archetype (stubs included) for the test pet.
local function studioTest(): (string?, number, number?)
	if not RunService:IsStudio() then
		return nil, 1, nil
	end
	local sp = workspace:GetAttribute("EOS_TestPet")
	local lv = workspace:GetAttribute("EOS_TestPetLevel")
	local cd = workspace:GetAttribute("EOS_TestCooldown")
	return (if type(sp) == "string" and sp ~= "" then sp else nil),
		(if type(lv) == "number" then math.clamp(math.floor(lv), 0, 3) else 1),
		(if type(cd) == "number" and cd > 0 then cd else nil)
end

-- the match's original Catcher (MatchLogic participant.initialHunter): never gets a pet ability
local function isStartingCatcher(plr: Player): boolean
	local c = MatchService.current()
	local p = c and c.logic:get(plr.UserId)
	return p ~= nil and p.initialHunter == true
end
AbilityService.isStartingCatcher = isStartingCatcher

-- snapshot the equipped pet as the match starts
local function onMatchStart(plr: Player)
	loadouts[plr] = nil
	plr:SetAttribute("EOS_PetAbilityOff", if isStartingCatcher(plr) then true else nil)
	-- Studio pet test (EOS_PetLab): player attributes EOS_TestPet = species, EOS_TestPetLevel = 1..3
	local test = if RunService:IsStudio() then plr:GetAttribute("EOS_TestPet") else nil
	if type(test) == "string" and test ~= "" then
		local fam = plr:GetAttribute("EOS_TestPetFamily")
		local family = if AbilityConfig.get(fam) then fam else (EconomyConfig.familyOfSpecies(test) or "Decoy")
		if not AbilityConfig.get(family) then
			family = "Decoy"
		end
		loadouts[plr] = {
			family = family,
			species = test,
			rarity = "common",
			gold = false,
			readyAt = 0,
			level = petLevel({ level = plr:GetAttribute("EOS_TestPetLevel") }),
		}
		return
	end
	local p = DataService.get(plr)
	if not p or p.equippedPet == "" then
		return
	end
	local pet = ProfileLogic.petById(p, p.equippedPet)
	if not pet or not AbilityConfig.get(pet.family) then
		return -- (a pet of a removed family has no ability)
	end
	loadouts[plr] = {
		family = pet.family,
		species = pet.species,
		rarity = pet.rarity,
		gold = p.cosmetics.owned.fx_gold == true,
		readyAt = 0,
		level = petLevel(pet),
	}
end

local function onMatchEnd(plr: Player)
	loadouts[plr] = nil
	plr:SetAttribute("EOS_PetAbilityOff", nil)
	Shared.clearTagBlock(plr)
	for name, mod in pairs(ARCH) do
		if mod.cleanup then
			local ok, err = pcall(mod.cleanup, plr)
			if not ok then
				warn(("[EOS] %s cleanup: %s"):format(name, tostring(err)))
			end
		end
	end
end

-- ===== the request =====

local WORDS = {
	NO_PET = "No pet equipped: hatch one at the incubator",
	COOLDOWN = nil, -- the card shows the timer
	WAIT = "Wait for the crossing to start",
	OUT = "You're out this crossing",
	LOBBY = "Abilities work in matches",
	STARTER = "The starting Catcher has no pet ability",
	NOT_BUILT = "This ability isn't ready yet",
	NO_TARGET = "No Runner in range in front of you",
	-- Shared.validPosition refusals
	OFF_MAP = "Can't go there", SAFE_ZONE = "Can't go there", ZONE_LOCKED = "Can't go there",
	BLOCKED = "Can't go there", NO_ROOM = "Can't go there", NO_GROUND = "Can't go there",
} :: { [string]: string? }

local function onRequest(plr: Player, moveDir: any)
	if not MatchService.limiter:allow(plr.UserId, "RequestAbility", os.clock()) then
		return
	end
	if moveDir ~= nil and (typeof(moveDir) ~= "Vector3" or moveDir ~= moveDir or moveDir.Magnitude > 2) then
		return
	end
	local function refuse(reason: string, readyIn: number?)
		Net.event("AbilityState"):FireClient(plr, { ok = false, reason = reason, readyIn = readyIn })
		local w = WORDS[reason]
		if w then
			Net.event("Toast"):FireClient(plr, { text = w, kind = "info" })
		end
	end
	if plr:GetAttribute("EOS_InMatch") ~= true then
		return refuse("LOBBY")
	end
	local role = plr:GetAttribute("EOS_Role")
	-- Studio only: the knife sandbox (EOS_Sandbox) makes everyone a Catcher. A user id listed in the
	-- workspace attribute EOS_TestRunnerIds ("id,id") tries pet abilities as a Runner there instead;
	-- everyone else's sandbox is unchanged. Live servers ignore it.
	if RunService:IsStudio() and role == "CATCHER" and plr:GetAttribute("EOS_Sandbox") == true then
		local ids = workspace:GetAttribute("EOS_TestRunnerIds")
		if type(ids) == "string" and table.find(string.split((ids:gsub("%s", "")), ","), tostring(plr.UserId)) then
			role = "RUNNER"
		end
	end
	local roleKey = AbilityConfig.roleKey(role)
	if not roleKey then
		return refuse("OUT")
	end
	local sandbox = plr:GetAttribute("EOS_Sandbox") == true -- Studio knife-test baseplate
	if Net.state():GetAttribute("Phase") ~= "CROSSING" and not sandbox then
		return refuse("WAIT")
	end
	if isStartingCatcher(plr) then
		return refuse("STARTER")
	end
	if sandbox and not loadouts[plr] then
		onMatchStart(plr)
	end
	local lo = loadouts[plr]
	if not lo then
		return refuse("NO_PET")
	end
	local now = os.clock()
	if now < lo.readyAt then
		return refuse("COOLDOWN", lo.readyAt - now)
	end
	local def = AbilityConfig.forRole(lo.family, roleKey)
	local mod = ARCH[lo.family]
	local handler = mod and mod[roleKey]
	if not def or not handler then
		return refuse("NO_PET")
	end
	local testPet, testLevel, testCooldown = studioTest()
	if testPet and plr:GetAttribute("EOS_TestPet") == lo.species then
		-- Studio pet test: this use plays the level the player's pet shows
		lo.level = petLevel({ level = plr:GetAttribute("EOS_TestPetLevel") })
	end
	local c = plr.Character
	local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	local dir = if typeof(moveDir) == "Vector3" then Vector3.new(moveDir.X, 0, moveDir.Z) else Vector3.zero
	local ctx = {
		player = plr,
		role = role,
		roleKey = roleKey,
		archetype = lo.family,
		def = def,
		species = lo.species,
		level = lo.level,
		gold = lo.gold,
		moveDir = dir,
		root = r,
	}
	local okCall, ok, why = pcall(handler, ctx)
	if not okCall then
		warn(("[EOS] %s %s ability errored: %s"):format(lo.family, roleKey, tostring(ok)))
		return refuse("NOT_BUILT")
	end
	if not ok then
		Analytics.log("AbilityRefused", { userId = plr.UserId, family = lo.family, role = role, reason = why })
		return refuse(why or "NOT_BUILT")
	end
	local cooldown = testCooldown or def.cooldown
	lo.readyAt = now + cooldown
	if testPet and plr:GetAttribute("EOS_TestPet") == lo.species and testLevel == 0 then
		local nextLevel = lo.level % 3 + 1 -- cycle mode moves the test level on after this use
		task.delay(def.windup + def.duration + 0.2, function()
			if plr.Parent then
				plr:SetAttribute("EOS_TestPetLevel", nextLevel)
			end
		end)
	end
	Net.event("AbilityState"):FireClient(plr, { ok = true, family = lo.family, role = roleKey, readyIn = cooldown })
	Shared.fx({
		userId = plr.UserId,
		family = lo.family,
		role = roleKey,
		species = lo.species,
		kind = "summon",
		pos = r and r.Position or nil,
		gold = lo.gold,
		level = lo.level,
		duration = def.duration + def.windup,
	})
	Analytics.log("AbilityUsed", { userId = plr.UserId, family = lo.family, role = role })
end

function AbilityService.init()
	Net.event("RequestAbility").OnServerEvent:Connect(onRequest)
	MatchService.onPlayerMatchStart(onMatchStart)
	MatchService.onPlayerMatchEnd(onMatchEnd)
	-- "blocks one tag": a charge on the Runner stops the next tag that would land
	MatchService.addCaptureGuard(function(hunter: any, victim: any, _kind: string): string?
		if Shared.consumeTagBlock(victim, hunter) then
			return "TAG_BLOCKED"
		end
		return nil
	end)
	-- a Catcher's stab or lunge: abilities that end on an attack hear it (Invisibility.onAttack)
	MatchService.onCatcherAttack(function(plr: Player, kind: string)
		for _, mod in pairs(ARCH) do
			if mod.onAttack then
				mod.onAttack(plr, kind)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(plr)
		onMatchEnd(plr)
	end)
	if RunService:IsStudio() then
		local function tag(plr: Player)
			local sp, lv = studioTest()
			if sp then
				plr:SetAttribute("EOS_TestPet", sp)
				plr:SetAttribute("EOS_TestPetLevel", math.max(lv, 1))
			end
		end
		Players.PlayerAdded:Connect(tag)
		for _, plr in ipairs(Players:GetPlayers()) do
			tag(plr)
		end
	end
end

return AbilityService
