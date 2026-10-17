--!strict
-- MapVoteService (HOS-MAPVOTE-001, 17 Oct, Hunter: "map voting before the start of every round, with the lead
-- catcher button under it like the reference"). The NEXT MAP vote in the lobby INTERMISSION:
--  * two choices, picked at random from the maps not just played (MapService.available() minus the live one)
--  * one vote per real player, switchable until the countdown ends; bots don't vote; AFK players don't vote and
--    going AFK drops your vote (HOS-MAPVOTE-002, Hunter: "players who are afk dont see map vote")
--  * 1.5 s before 0:00 the vote locks and shows the winner in the lobby (most votes; a tie or no votes = random);
--    at 0:00 the winner goes live (MapService.set), before ROLE_REVEAL
--  * a vote left open by a cancelled countdown (players dropped) carries over to the next countdown
--  * no vote with a pinned map (workspace EOS_FixedMap) or fewer than 2 other maps: the old rotation runs instead
-- Replicated on ReplicatedStorage for the UI (Controllers.MapVoteController):
--   MapVoteState "open" | "result" | nil, MapVoteA / MapVoteB (map keys), MapVoteTitleA / B, MapVoteCountA / B,
--   MapVoteVotersA / B (JSON list of up to 8 voter user ids, newest first), MapVoteEndsAt (server time),
--   MapVoteWinner (1 | 2, set with "result").
-- Remote: EOS_Remotes.RequestMapVote (RemoteEvent) (choice: 1 | 2).
-- Hooks (MatchService.lobbyLoop, one line each, "-- HOS-MAPVOTE-001"): open() before the INTERMISSION countdown,
-- close() once it finishes (before runMatch). Starts itself on the first open(); no Bootstrap line.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))
local MapService = require(script.Parent.MapService)

local MapVoteService = {}

local LOCK_BEFORE = 1.5 -- seconds before 0:00 the vote locks and the winner shows (still in the lobby)
local VOTERS_SHOWN = 8

local rng = Random.new()
local started = false
local open = false
local options: { string } = {}
local votes: { [number]: number } = {} -- userId -> 1 | 2
local order: { number } = {} -- userIds, newest vote last
local endsAt = 0
local resultToken = 0
local lockedWin: number? = nil

local function titleOf(key: string): string
	local live = workspace:FindFirstChild("EOS_World") and workspace.EOS_World:FindFirstChild("Arena")
	if live and live:GetAttribute("Map") == key then
		return (live:GetAttribute("MapTitle") :: string?) or key
	end
	local store = game:GetService("ServerStorage"):FindFirstChild("EOS_Maps")
	local m = store and store:FindFirstChild("Arena_" .. key)
	return (m and m:GetAttribute("MapTitle") :: string?) or key
end

local function publish()
	local counts, voters = { 0, 0 }, { {}, {} }
	for i = #order, 1, -1 do
		local uid = order[i]
		local c = votes[uid]
		if c then
			counts[c] += 1
			if #voters[c] < VOTERS_SHOWN then
				table.insert(voters[c], uid)
			end
		end
	end
	ReplicatedStorage:SetAttribute("MapVoteCountA", counts[1])
	ReplicatedStorage:SetAttribute("MapVoteCountB", counts[2])
	ReplicatedStorage:SetAttribute("MapVoteVotersA", HttpService:JSONEncode(voters[1]))
	ReplicatedStorage:SetAttribute("MapVoteVotersB", HttpService:JSONEncode(voters[2]))
	return counts
end

local function onVote(plr: Player, choice: any)
	if not open or lockedWin or (choice ~= 1 and choice ~= 2) or plr:GetAttribute("EOS_AFK") == true then
		return
	end
	local uid = plr.UserId
	if votes[uid] == choice then
		return
	end
	votes[uid] = choice
	local at = table.find(order, uid)
	if at then
		table.remove(order, at)
	end
	table.insert(order, uid)
	publish()
end

local function init()
	if started then
		return
	end
	started = true
	local remotes = ReplicatedStorage:WaitForChild("EOS_Remotes")
	local ev = remotes:FindFirstChild("RequestMapVote") :: RemoteEvent?
	if not ev then
		local e = Instance.new("RemoteEvent")
		e.Name = "RequestMapVote"
		e.Parent = remotes
		ev = e
	end
	(ev :: RemoteEvent).OnServerEvent:Connect(onVote)
	-- going AFK drops your vote (the panel hides for you too)
	local function watchAfk(plr: Player)
		plr:GetAttributeChangedSignal("EOS_AFK"):Connect(function()
			if plr:GetAttribute("EOS_AFK") == true and votes[plr.UserId] and not lockedWin then
				votes[plr.UserId] = nil
				local at = table.find(order, plr.UserId)
				if at then
					table.remove(order, at)
				end
				if open then
					publish()
				end
			end
		end)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		watchAfk(plr)
	end
	Players.PlayerAdded:Connect(watchAfk)
	Players.PlayerRemoving:Connect(function(plr)
		if votes[plr.UserId] then
			votes[plr.UserId] = nil
			local at = table.find(order, plr.UserId)
			if at then
				table.remove(order, at)
			end
			if open then
				publish()
			end
		end
	end)
end

local function pickWinner(): number
	local counts = publish()
	return if counts[1] > counts[2] then 1 elseif counts[2] > counts[1] then 2 else rng:NextInteger(1, 2)
end

-- 1.5 s before 0:00: no more votes, the winner shows in the lobby (the map swaps at 0:00 in close())
local function lock()
	if not open or lockedWin then
		return
	end
	lockedWin = pickWinner()
	ReplicatedStorage:SetAttribute("MapVoteWinner", lockedWin)
	ReplicatedStorage:SetAttribute("MapVoteState", "result")
end

local function scheduleLock(token: number)
	task.delay(math.max(0, endsAt - LOCK_BEFORE - workspace:GetServerTimeNow()), function()
		if token ~= resultToken or not open then
			return
		end
		if workspace:GetServerTimeNow() < endsAt - LOCK_BEFORE - 0.05 then
			scheduleLock(token) -- the countdown restarted (carried-over vote): wait for the new end
			return
		end
		lock()
	end)
end

-- MatchService hook, right before the INTERMISSION countdown. Opens a vote (or keeps the one already open).
-- Returns true while a vote decides the next map, so the caller skips MapService.rotate().
function MapVoteService.open(): boolean
	init()
	local fixed = workspace:GetAttribute("EOS_FixedMap")
	if type(fixed) == "string" and fixed ~= "" then
		return false
	end
	local intermission = GameConfig.Timing and GameConfig.Timing.INTERMISSION or 15
	endsAt = workspace:GetServerTimeNow() + intermission
	ReplicatedStorage:SetAttribute("MapVoteEndsAt", endsAt)
	if open then
		-- a cancelled countdown: same choices, votes kept, voting opens again if it had locked
		if lockedWin then
			lockedWin = nil
			ReplicatedStorage:SetAttribute("MapVoteWinner", nil)
			ReplicatedStorage:SetAttribute("MapVoteState", "open")
		end
		resultToken += 1
		scheduleLock(resultToken)
		return true
	end
	local pool = {}
	for _, key in ipairs(MapService.available()) do
		if key ~= MapService.current() then
			table.insert(pool, key)
		end
	end
	if #pool < 2 then
		return false
	end
	local a = table.remove(pool, rng:NextInteger(1, #pool)) :: string
	local b = table.remove(pool, rng:NextInteger(1, #pool)) :: string
	options = { a, b }
	votes, order = {}, {}
	open = true
	lockedWin = nil
	resultToken += 1
	scheduleLock(resultToken)
	ReplicatedStorage:SetAttribute("MapVoteA", a)
	ReplicatedStorage:SetAttribute("MapVoteB", b)
	ReplicatedStorage:SetAttribute("MapVoteTitleA", titleOf(a))
	ReplicatedStorage:SetAttribute("MapVoteTitleB", titleOf(b))
	ReplicatedStorage:SetAttribute("MapVoteWinner", nil)
	publish()
	ReplicatedStorage:SetAttribute("MapVoteState", "open")
	return true
end

-- MatchService hook, once the countdown has finished and before the match starts: the winner goes live.
function MapVoteService.close(): string?
	if not open then
		return nil
	end
	local win = lockedWin or pickWinner() -- forceStart can end the countdown before the lock
	open = false
	lockedWin = nil
	local key = options[win]
	local before = MapService.current()
	MapService.set(key)
	ReplicatedStorage:SetAttribute("MapVoteWinner", win)
	ReplicatedStorage:SetAttribute("MapVoteState", "result")
	if MapService.current() ~= before then
		Net.event("Toast"):FireAllClients({ text = "Next map: " .. MapService.title(), kind = "info" })
	end
	return key
end

function MapVoteService.isOpen(): boolean
	return open
end

-- tests
MapVoteService._vote = onVote
function MapVoteService._state(): any
	return { open = open, options = options, votes = votes, endsAt = endsAt }
end

return MapVoteService
