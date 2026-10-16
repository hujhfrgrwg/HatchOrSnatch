--!strict
-- EmoteService: the Emote Crate and lobby emotes. Clients only ask:
--  * RequestOpenCrate()        250 Gems -> one emote, rolled here (odds never change with ownership);
--                              a duplicate refunds Gems by rarity (Shared/EmoteConfig)
--  * RequestEmote(emoteId)     play an owned emote in the lobby ("" stops). Sets the character
--                              attribute EOS_Emote; every client plays that character's song near it.
--  * RequestEmoteWheel(slots)  save the 6 emotes on your G wheel (owned only; a new win fills an empty slot)
-- Emotes stop when a match starts. Robux openings stay hidden until they have product ids.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EmoteConfig = require(Shared:WaitForChild("EmoteConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProfileLogic = require(ServerScriptService.EOS.Core.ProfileLogic)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)

local EmoteService = {}

local rng = Random.new()

local function toast(plr: Player, text: string, kind: string?)
	Net.event("Toast"):FireClient(plr, { text = text, kind = kind or "info" })
end

local function inMatch(plr: Player): boolean
	return plr:GetAttribute("EOS_InMatch") == true
end

local function setEmote(plr: Player, id: string)
	local char = plr.Character
	if char then
		char:SetAttribute("EOS_Emote", id)
	end
end

local CRATE_WORDS = {
	NOT_ENOUGH = "Not enough Gems: a crate is %d",
	NOT_LOADED = "Your save is still loading",
	UNKNOWN = "Can't open a crate right now",
}

local function onOpenCrate(plr: Player)
	if not MatchService.limiter:allow(plr.UserId, "RequestOpenCrate", os.clock()) then
		return
	end
	if inMatch(plr) then
		return toast(plr, "Open crates between matches", "info")
	end
	local live = DataService.get(plr)
	if not live then
		Net.event("CrateResult"):FireClient(plr, { ok = false, reason = "NOT_LOADED" })
		return toast(plr, CRATE_WORDS.NOT_LOADED, "warn")
	end
	-- rolled once, here, so every replay of the change gives the same emote
	local emoteId = EmoteConfig.roll(rng:NextNumber())
	local scratch = ProfileLogic.deepCopy(live)
	local ok, info = ProfileLogic.openEmoteCrate(scratch, emoteId, EmoteConfig)
	if not ok then
		Net.event("CrateResult"):FireClient(plr, { ok = false, reason = info })
		return toast(plr, (CRATE_WORDS[info] or CRATE_WORDS.UNKNOWN):format(EmoteConfig.CRATE_GEMS), "warn")
	end
	local result = info
	DataService.update(plr, "crate:" .. emoteId, function(p)
		local won = ProfileLogic.openEmoteCrate(p, emoteId, EmoteConfig)
		if won then
			ProfileLogic.wheelAdd(p, emoteId, EmoteConfig)
		end
	end)
	Net.event("CrateResult"):FireClient(plr, { ok = true, emote = result.emote, dupe = result.dupe, refund = result.refund })
	Analytics.log("GemsSink", { userId = plr.UserId, amount = EmoteConfig.CRATE_GEMS, reason = "emote_crate" })
end

local function onEmote(plr: Player, id: any)
	if not MatchService.limiter:allow(plr.UserId, "RequestEmote", os.clock()) then
		return
	end
	if type(id) ~= "string" or #id > 32 then
		return
	end
	if id == "" then
		return setEmote(plr, "")
	end
	if inMatch(plr) then
		return setEmote(plr, "")
	end
	local p = DataService.get(plr)
	if not p or type(p.emotes) ~= "table" or p.emotes[id] ~= true or not EmoteConfig.get(id) then
		return toast(plr, "You don't have that emote yet", "warn")
	end
	setEmote(plr, id)
end

local function onWheel(plr: Player, slots: any)
	if not MatchService.limiter:allow(plr.UserId, "RequestEmoteWheel", os.clock()) then
		return
	end
	if type(slots) ~= "table" or #slots > EmoteConfig.WHEEL_SLOTS then
		return
	end
	for i = 1, EmoteConfig.WHEEL_SLOTS do
		local v = slots[i]
		if v ~= nil and (type(v) ~= "string" or #v > 32) then
			return
		end
	end
	if not DataService.get(plr) then
		return
	end
	DataService.update(plr, "emoteWheel", function(p)
		ProfileLogic.setEmoteWheel(p, slots, EmoteConfig)
	end)
end

function EmoteService.init()
	Net.event("RequestOpenCrate").OnServerEvent:Connect(onOpenCrate)
	Net.event("RequestEmote").OnServerEvent:Connect(onEmote)
	Net.event("RequestEmoteWheel").OnServerEvent:Connect(onWheel)
	MatchService.onPlayerMatchStart(function(plr)
		setEmote(plr, "")
	end)
	Players.PlayerAdded:Connect(function(plr)
		plr:GetAttributeChangedSignal("EOS_InMatch"):Connect(function()
			if inMatch(plr) then
				setEmote(plr, "")
			end
		end)
	end)
	for _, plr in ipairs(Players:GetPlayers()) do
		plr:GetAttributeChangedSignal("EOS_InMatch"):Connect(function()
			if inMatch(plr) then
				setEmote(plr, "")
			end
		end)
	end
end

return EmoteService
