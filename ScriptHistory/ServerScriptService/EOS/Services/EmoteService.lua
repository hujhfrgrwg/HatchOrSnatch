--!strict
-- EmoteService: the Emote Crate and lobby emotes. Clients only ask:
--  * RequestOpenCrate()        250 Gems -> one emote, rolled here (odds never change with ownership);
--                              a duplicate refunds Gems by rarity (Shared/EmoteConfig)
--  * RequestEmote(emoteId)     play an owned emote in the lobby ("" stops). Sets the character
--                              attribute EOS_Emote; every client plays that character's song near it.
--  * RequestEmoteWheel(slots)  save the 6 emotes on your G wheel (owned only; a new win fills an empty slot)
-- Emotes stop when a match starts. Robux openings stay hidden until they have product ids.
-- Paid-random-item rules: where PolicyService restricts them, crates can't be opened (HOS-GEMS-001).

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
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

-- Gems are buyable with Robux, so the crate is a paid random item: where Roblox's policy restricts those
-- (some countries), the crate stays shut. Cached per player; a failed lookup counts as restricted.
local restricted: { [Player]: boolean } = {}
local function crateRestricted(plr: Player): boolean
	if restricted[plr] == nil then
		local ok, info = false, nil
		for attempt = 1, 3 do
			ok, info = pcall(function()
				return PolicyService:GetPolicyInfoForPlayerAsync(plr)
			end)
			if ok then break end
			task.wait(attempt)
		end
		restricted[plr] = not ok or (type(info) == "table" and info.ArePaidRandomItemsRestricted == true)
	end
	return restricted[plr]
end

local function onOpenCrate(plr: Player, count: any)
	if not MatchService.limiter:allow(plr.UserId, "RequestOpenCrate", os.clock()) then
		return
	end
	if crateRestricted(plr) then
		Net.event("CrateResult"):FireClient(plr, { ok = false, reason = "RESTRICTED" })
		return toast(plr, "Emote Crates aren't available where you play", "info")
	end
	if inMatch(plr) then
		return toast(plr, "Open crates between matches", "info")
	end
	local live = DataService.get(plr)
	if not live then
		Net.event("CrateResult"):FireClient(plr, { ok = false, reason = "NOT_LOADED" })
		return toast(plr, CRATE_WORDS.NOT_LOADED, "warn")
	end
	-- rolled once, here, so every replay of the change gives the same emotes. HOS-INV-001: count 10 = open x10
	-- (EmoteConfig.MULTI: one price, one Epic or better guaranteed); every roll honours the guarantee (rollPity)
	local multi = count == EmoteConfig.MULTI.count
	local n = if multi then EmoteConfig.MULTI.count else 1
	local price = if multi then EmoteConfig.MULTI.gems else EmoteConfig.CRATE_GEMS
	local scratch = ProfileLogic.deepCopy(live)
	local ids, results = {}, {}
	local gotEpic = false
	for i = 1, n do
		local id = EmoteConfig.rollPity(rng:NextNumber(), scratch.emotePity, multi and i == n and not gotEpic)
		local ok, info = ProfileLogic.openEmoteCrate(scratch, id, EmoteConfig, if i == 1 then price else 0)
		if not ok then
			Net.event("CrateResult"):FireClient(plr, { ok = false, reason = info })
			return toast(plr, (CRATE_WORDS[info] or CRATE_WORDS.UNKNOWN):format(price), "warn")
		end
		local e = EmoteConfig.get(id)
		if e and (e.rarity == "epic" or e.rarity == "legendary") then
			gotEpic = true
		end
		table.insert(ids, id)
		table.insert(results, info)
	end
	DataService.update(plr, "crate:" .. (if multi then "x10" else ids[1]), function(p)
		for i, id in ids do
			if ProfileLogic.openEmoteCrate(p, id, EmoteConfig, if i == 1 then price else 0) then
				ProfileLogic.wheelAdd(p, id, EmoteConfig)
			end
		end
	end)
	-- the reel plays the best pull; x10 also sends every result (Controllers.CrateExtras shows them all)
	local RANK = { common = 1, rare = 2, epic = 3, legendary = 4 }
	local best = results[1]
	for _, r in results do
		local a, b = EmoteConfig.get(r.emote), EmoteConfig.get(best.emote)
		if a and b and (RANK[a.rarity] or 0) > (RANK[b.rarity] or 0) then
			best = r
		end
	end
	Net.event("CrateResult"):FireClient(plr, { ok = true, emote = best.emote, dupe = best.dupe, refund = best.refund, multi = if multi then results else nil })
	do -- HOS-INV-001: everyone nearby sees the opening (Controllers.CrateShowcase): kind|rarity|name|stamp
		local e = EmoteConfig.get(best.emote)
		plr:SetAttribute("EOS_CrateOpen", ("emote|%s|%s|%d"):format(e and e.rarity or "common", e and e.name or "an emote", math.floor(os.clock() * 1000)))
	end
	Analytics.log("GemsSink", { userId = plr.UserId, amount = price, reason = if multi then "emote_crate_x10" else "emote_crate" })
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
	Players.PlayerRemoving:Connect(function(plr)
		restricted[plr] = nil
	end)
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
