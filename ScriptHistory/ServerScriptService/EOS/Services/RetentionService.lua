--!strict
-- RetentionService (HOS-RET-001): the welcome back gift, favorite prompt, event RSVP and starter pack.
-- The server keeps what each player has been shown in profile.retention and owns the gift itself; the
-- client (RetentionController) only decides WHEN to show things, in the lobby, one at a time.
--
-- profile.retention = {
--   firstDay = "2026-10-17" | "legacy",  -- first day we saw this player ("legacy" = played before this shipped)
--   giftDate = "2026-10-18"?,            -- UTC day of the last claimed gift
--   favPrompted = true?,                 -- Roblox favorite prompt shown (once ever)
--   eventsSeen = { [eventId] = true },   -- RSVP prompt shown per event
--   starter = { shownAt = unix?, done = true? },
-- }
-- Remotes: ReplicatedStorage.EOS_Retention { State (server -> client), Claim (RemoteFunction), Seen (client -> server) }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local RetentionConfig = require(Shared:WaitForChild("RetentionConfig"))
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

local RetentionService = {}

local remotes: Folder
local stateEvent: RemoteEvent
local lastSent: { [Player]: string } = {}
local lastClaim: { [Player]: number } = {}

local function rec(p: any): any
	local r = p.retention
	if type(r) ~= "table" then
		r = {}
		p.retention = r
	end
	if type(r.eventsSeen) ~= "table" then r.eventsSeen = {} end
	if type(r.starter) ~= "table" then r.starter = {} end
	return r
end

local function hasPet(p: any): boolean
	local stats = p.stats or {}
	return (type(p.pets) == "table" and next(p.pets) ~= nil) or (tonumber(stats.petsHatched) or 0) > 0
end

local function giftReady(p: any, today: string): boolean
	local r = p.retention
	if type(r) ~= "table" or not r.firstDay then return false end
	return r.firstDay ~= today and r.giftDate ~= today
end

local function view(p: any): any
	local now = os.time()
	local today = RetentionConfig.day(now)
	local r = p.retention or {}
	local st = r.starter or {}
	local S = RetentionConfig.STARTER
	local starterEnds = if st.shownAt then st.shownAt + S.hours * 3600 else nil
	return {
		giftReady = giftReady(p, today),
		claimedToday = r.giftDate == today,
		nextGiftAt = RetentionConfig.nextDay(now),
		serverNow = now,
		matches = tonumber((p.stats or {}).matchesCompleted) or 0,
		hasPet = hasPet(p),
		favPrompted = r.favPrompted == true,
		eventSeen = RetentionConfig.EVENT_ID ~= "" and (r.eventsSeen or {})[RetentionConfig.EVENT_ID] == true,
		starterShown = st.shownAt ~= nil,
		starterOpen = S.enabled and starterEnds ~= nil and now < starterEnds and not st.done,
		starterEndsAt = starterEnds,
	}
end

local function send(plr: Player, force: boolean?)
	local p = DataService.get(plr)
	if not p then return end
	local v = view(p)
	-- serverNow changes every second; leave it out of the "did anything change" key
	local key = table.concat({ tostring(v.giftReady), tostring(v.claimedToday), v.matches, tostring(v.hasPet),
		tostring(v.favPrompted), tostring(v.eventSeen), tostring(v.starterShown), tostring(v.starterOpen), RetentionConfig.day() }, "|")
	if not force and lastSent[plr] == key then return end
	lastSent[plr] = key
	stateEvent:FireClient(plr, v)
end

local function onLoaded(plr: Player, p: any)
	if type(p.retention) ~= "table" or not p.retention.firstDay then
		local first = if (tonumber((p.stats or {}).matchesCompleted) or 0) > 0 then "legacy" else RetentionConfig.day()
		DataService.update(plr, "retention_init", function(prof)
			local r = rec(prof)
			if not r.firstDay then r.firstDay = first end
		end)
	end
	send(plr, true)
end

local function claim(plr: Player): any
	local now = os.clock()
	if lastClaim[plr] and now - lastClaim[plr] < 2 then return { ok = false, reason = "busy" } end
	lastClaim[plr] = now
	local p = DataService.get(plr)
	if not p then return { ok = false, reason = "loading" } end
	local today = RetentionConfig.day()
	if not giftReady(p, today) then return { ok = false, reason = "not_ready" } end
	local G = RetentionConfig.GIFT
	-- guarded by giftDate: a retried transform never pays twice
	local saved = DataService.commit(plr, "daily_gift", function(prof)
		local r = rec(prof)
		if r.giftDate == today then return end
		r.giftDate = today
		prof.gold = (tonumber(prof.gold) or 0) + G.gold
		prof.gems = (tonumber(prof.gems) or 0) + G.gems
		prof.stats = prof.stats or {}
		prof.stats.goldEarned = (tonumber(prof.stats.goldEarned) or 0) + G.gold
		prof.stats.gemsEarned = (tonumber(prof.stats.gemsEarned) or 0) + G.gems
	end, 10)
	-- the change is already applied to the cached profile (and retries in the background) even when the
	-- save is slow, so the player keeps the gift either way
	Analytics.log("DailyGiftClaimed", { userId = plr.UserId, gold = G.gold, gems = G.gems, saved = saved })
	send(plr, true)
	return { ok = true, gold = G.gold, gems = G.gems, nextGiftAt = RetentionConfig.nextDay() }
end

local SEEN_KINDS = { fav = true, event = true, starter = true, gift = true, offer = true, offer_click = true, starter_no = true }

local function seen(plr: Player, kind: any, id: any)
	if type(kind) ~= "string" or not SEEN_KINDS[kind] then return end
	if id ~= nil and (type(id) ~= "string" or #id > 40) then return end
	Analytics.log("RetentionPrompt", { userId = plr.UserId, kind = kind, id = id })
	if kind == "fav" then
		DataService.update(plr, "retention_fav", function(prof) rec(prof).favPrompted = true end)
	elseif kind == "event" and id and id == RetentionConfig.EVENT_ID then
		DataService.update(plr, "retention_event", function(prof) rec(prof).eventsSeen[id] = true end)
	elseif kind == "starter" and RetentionConfig.STARTER.enabled then
		local t = os.time()
		DataService.update(plr, "retention_starter", function(prof)
			local st = rec(prof).starter
			if not st.shownAt then st.shownAt = t end
		end)
	end
end

function RetentionService.init()
	local old = ReplicatedStorage:FindFirstChild("EOS_Retention")
	if old then old:Destroy() end
	remotes = Instance.new("Folder")
	remotes.Name = "EOS_Retention"
	stateEvent = Instance.new("RemoteEvent")
	stateEvent.Name = "State"
	stateEvent.Parent = remotes
	local claimFn = Instance.new("RemoteFunction")
	claimFn.Name = "Claim"
	claimFn.Parent = remotes
	local seenEvent = Instance.new("RemoteEvent")
	seenEvent.Name = "Seen"
	seenEvent.Parent = remotes
	local ask = Instance.new("RemoteEvent") -- client asks for a fresh state (after it starts listening)
	ask.Name = "Ask"
	ask.Parent = remotes
	remotes.Parent = ReplicatedStorage

	claimFn.OnServerInvoke = claim
	seenEvent.OnServerEvent:Connect(seen)
	ask.OnServerEvent:Connect(function(plr) send(plr, true) end)
	stateEvent.OnServerEvent:Connect(function() end)

	DataService.Loaded:Connect(onLoaded)
	DataService.Changed:Connect(function(plr) send(plr) end)
	for _, plr in Players:GetPlayers() do
		local p = DataService.get(plr)
		if p then task.spawn(onLoaded, plr, p) end
	end
	Players.PlayerRemoving:Connect(function(plr)
		lastSent[plr] = nil
		lastClaim[plr] = nil
	end)
	-- the gift turns ready at UTC midnight for players who stay on
	task.spawn(function()
		while true do
			task.wait(60)
			for _, plr in Players:GetPlayers() do send(plr) end
		end
	end)
end

return RetentionService
