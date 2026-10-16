--!strict
-- PassService (HOS-PASS-001, 16 Oct): the VIP and 2x Gold game passes (EconomyConfig.PASSES).
-- Ownership is checked on join and when a purchase finishes, then mirrored to a player attribute
-- (EOS_VIP, EOS_Gold2x) that the client and other services read. Only the server sets these, and
-- client-set attributes never replicate up, so the attribute is the source of truth here.
-- Passes never touch eggs, pets or Gems (GDD v0.4):
--  * VIP: a gold VIP on the nameplate (CharacterService), a [VIP] chat tag (client) and one emote
--  * 2x Gold: match Gold doubled when it is settled (MatchService calls PassService.doubleGold)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local EmoteConfig = require(Shared:WaitForChild("EmoteConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProfileLogic = require(ServerScriptService.EOS.Core.ProfileLogic)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local CharacterService = require(script.Parent.CharacterService)

local PassService = {}

function PassService.has(plr: Player, key: string): boolean
	local pass = EconomyConfig.pass(key)
	return pass ~= nil and plr:GetAttribute(pass.attr) == true
end

-- 2x Gold: doubles a settlement's Gold in place. Returns the Gold added (0 when the player has no pass).
function PassService.doubleGold(plr: Player, s: any): number
	if type(s) ~= "table" or not PassService.has(plr, "gold2x") then return 0 end
	local g = math.max(0, math.floor(tonumber(s.gold) or 0))
	if g <= 0 then return 0 end
	s.gold = g * 2
	return g
end

-- VIP's emote: added to the collection (and the G wheel) once the profile has loaded
local function grantVipEmote(plr: Player)
	local pass = EconomyConfig.pass("vip")
	local id = pass and pass.emote
	if not id or not EmoteConfig.get(id) then return end
	local t0 = os.clock()
	while plr.Parent and not DataService.isLoaded(plr) and os.clock() - t0 < 60 do
		task.wait(1)
	end
	local p = DataService.get(plr)
	if not p or (type(p.emotes) == "table" and p.emotes[id] == true) then return end
	DataService.update(plr, "vip_emote", function(prof)
		if type(prof.emotes) ~= "table" then prof.emotes = {} end
		if prof.emotes[id] ~= true then
			prof.emotes[id] = true
			ProfileLogic.wheelAdd(prof, id, EmoteConfig)
		end
	end)
end

local function setOwned(plr: Player, pass: any, on: boolean)
	plr:SetAttribute(pass.attr, if on then true else nil)
	if pass.key == "vip" then
		CharacterService.refreshTag(plr)
		if on then task.spawn(grantVipEmote, plr) end
	end
end

local function check(plr: Player)
	for _, pass in ipairs(EconomyConfig.PASSES) do
		local ok, has = false, false
		for attempt = 1, 3 do
			ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, pass.passId)
			end)
			if ok then break end
			task.wait(2 ^ attempt)
		end
		if ok and plr.Parent then
			setOwned(plr, pass, has == true)
		elseif not ok then
			Analytics.warn("PersistenceError", "pass" .. plr.UserId, "Game pass check failed: " .. tostring(has), { userId = plr.UserId, reason = "PASS_CHECK" })
		end
	end
end

function PassService.init()
	Players.PlayerAdded:Connect(check)
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(check, plr)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr: Player, passId: number, purchased: boolean)
		if not purchased then return end
		for _, pass in ipairs(EconomyConfig.PASSES) do
			if pass.passId == passId then
				setOwned(plr, pass, true)
				Net.event("ShopResult"):FireClient(plr, { ok = true, pass = pass.key }) -- the client's Reward reveal
				Analytics.log("CosmeticUsed", { userId = plr.UserId, reason = "game_pass", itemId = pass.key })
			end
		end
	end)
end

return PassService
