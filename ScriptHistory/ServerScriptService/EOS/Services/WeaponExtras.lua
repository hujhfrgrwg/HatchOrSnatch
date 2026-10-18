--!strict
-- WeaponExtras (server, HOS-INV-001, Hunter 18 Oct "Do all of it"): what the Weapon Crate leads to.
--  * RequestForgeSkin(itemId): a knife skin you don't own, for Weapon Shards (duplicates from the crate give shards,
--    EconomyConfig.KNIFE_CRATE.shards / .forge). Worn straight away; the client gets the usual ShopResult reveal.
--  * Weapon sets (EconomyConfig.WEAPON_SETS): every skin of a rarity owned = that set's Gems, once. The Legendary set
--    makes you a Weapon Master: a gold line on your name tag and a gold glow on your weapon (CharacterService).
--  * Inspect (Controllers.InspectController): what you wear goes on your Player as attributes so anyone can click
--    you in the lobby: EOS_InspKnife (item id), EOS_InspPet (species), EOS_InspEmotes ("id,id"), EOS_WeaponMaster.
--   WeaponCrateService.init calls WeaponExtras.init(); its crate paths call WeaponExtras.checkSets(plr).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProfileLogic = require(ServerScriptService.EOS.Core.ProfileLogic)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)
local CharacterService = require(script.Parent.CharacterService)

local WeaponExtras = {}

local WORDS = {
	NOT_ENOUGH = "Not enough Weapon Shards: duplicates from Weapon Crates give shards",
	OWNED = "You already have that weapon",
	UNKNOWN = "Can't forge that right now",
}
local SET_NAME = { common = "Common", rare = "Rare", epic = "Epic", legendary = "Legendary" }

local function toast(plr: Player, text: string, kind: string?)
	Net.event("Toast"):FireClient(plr, { text = text, kind = kind or "info" })
end

-- what others see when they inspect you
local function publish(plr: Player, p: any)
	local c = p.cosmetics or {}
	local knife = c.knifeSkin
	plr:SetAttribute("EOS_InspKnife", if type(knife) == "string" and (c.owned or {})[knife] then knife else "")
	local species = ""
	if type(p.equippedPet) == "string" and p.equippedPet ~= "" then
		for _, pet in p.pets or {} do
			if type(pet) == "table" and pet.id == p.equippedPet then
				species = tostring(pet.species or "")
			end
		end
	end
	plr:SetAttribute("EOS_InspPet", species)
	local wheel = {}
	for _, id in p.emoteWheel or {} do
		if type(id) == "string" and id ~= "" and #wheel < 6 then
			table.insert(wheel, id)
		end
	end
	plr:SetAttribute("EOS_InspEmotes", table.concat(wheel, ","))
	local master = type(p.weaponSets) == "table" and p.weaponSets.legendary == true
	if (plr:GetAttribute("EOS_WeaponMaster") == true) ~= master then
		plr:SetAttribute("EOS_WeaponMaster", master)
		CharacterService.refreshTag(plr)
		CharacterService.refreshKnife(plr)
	end
end

-- any skin just arrived: finish the sets it completes (Gems + toast; the Legendary set = Weapon Master)
function WeaponExtras.checkSets(plr: Player)
	local live = DataService.get(plr)
	if not live then
		return
	end
	local done = ProfileLogic.weaponSets(ProfileLogic.deepCopy(live), EconomyConfig)
	if #done == 0 then
		return
	end
	DataService.update(plr, "wsets:" .. table.concat(done, ","), function(p)
		ProfileLogic.weaponSets(p, EconomyConfig)
	end)
	for _, r in done do
		for _, set in EconomyConfig.WEAPON_SETS do
			if set.rarity == r then
				local extra = if set.title then "  You're a Weapon Master!" else ""
				toast(plr, ("%s weapon set complete: +%d Gems!%s"):format(SET_NAME[r] or r, set.gems or 0, extra), "reward")
				Analytics.log("GemsSource", { userId = plr.UserId, amount = set.gems or 0, reason = "weapon_set_" .. r })
			end
		end
	end
	local now = DataService.get(plr)
	if now then
		publish(plr, now)
	end
end

local function onForge(plr: Player, itemId: any)
	if type(itemId) ~= "string" or #itemId > 80 then
		return
	end
	if not MatchService.limiter:allow(plr.UserId, "RequestForgeSkin", os.clock()) then
		return
	end
	if plr:GetAttribute("EOS_InMatch") == true then
		return toast(plr, "Forge weapons between matches")
	end
	local live = DataService.get(plr)
	if not live then
		return toast(plr, "Your save is still loading", "warn")
	end
	local ok, info = ProfileLogic.forgeSkin(ProfileLogic.deepCopy(live), itemId, EconomyConfig)
	if not ok then
		return toast(plr, WORDS[info] or WORDS.UNKNOWN, "warn")
	end
	DataService.update(plr, "forge:" .. itemId, function(p)
		ProfileLogic.forgeSkin(p, itemId, EconomyConfig)
	end)
	CharacterService.refreshKnife(plr)
	Net.event("ShopResult"):FireClient(plr, { ok = true, itemId = itemId, forged = true })
	Analytics.log("CosmeticUsed", { userId = plr.UserId, reason = "forge", itemId = itemId, shards = info.cost })
	WeaponExtras.checkSets(plr)
end

function WeaponExtras.init()
	Net.event("RequestForgeSkin").OnServerEvent:Connect(onForge)
	DataService.Loaded:Connect(function(plr: Player, p: any)
		publish(plr, p)
		task.defer(WeaponExtras.checkSets, plr) -- a set finished before sets existed
	end)
	DataService.Changed:Connect(function(plr: Player)
		local p = DataService.get(plr)
		if p then
			publish(plr, p)
		end
	end)
	for _, plr in Players:GetPlayers() do
		local p = DataService.get(plr)
		if p then
			publish(plr, p)
		end
	end
end

return WeaponExtras
