--!strict
-- MatchService: the authoritative match loop (GDD 2, 3, 5, 9).
-- BOOT -> WAITING / INTERMISSION -> ROLE_REVEAL -> CROSSING -> WAVE_END -> ... -> RESULTS -> back.
-- Rules live in Core/MatchLogic; this file owns time, positions, remotes and characters.
--
-- Replicated state: ReplicatedStorage.EOS_State attributes
--   Phase, PhaseEndsAt (server time), PhaseId, Wave, MaxWaves, StartSide, FinishSide, MatchId,
--   RunnersLeft, Catchers, Ready, Needed, InMatchCount, IsTest
-- Player attributes: EOS_Role, EOS_Tier, EOS_Secured, EOS_Safe, EOS_InMatch, EOS_MatchCaptures
--
-- NPCs (NpcService): under Npc.RUNNER_TARGET players, NPC Runners top the match up to that many
-- Runners. A bot answers like a Player (UserId, DisplayName, Character, attributes), so the roster
-- holds both ("actors"); only real players get remotes, data and rewards. Matches start with
-- Match.MIN_TO_START real players; fewer than Match.MIN_PLAYERS real players = practice (not saved).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TierConfig = require(Shared:WaitForChild("TierConfig"))
local RewardConfig = require(Shared:WaitForChild("RewardConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Layout = require(Shared:WaitForChild("Layout"))
local Net = require(Shared:WaitForChild("Net"))
local MatchLogic = require(ServerScriptService.EOS.Core.MatchLogic)
local RateLimiter = require(ServerScriptService.EOS.Core.RateLimiter)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local CharacterService = require(script.Parent.CharacterService)
local NpcService = require(script.Parent.NpcService)

local T = GameConfig.Timing
local C = GameConfig.Capture
local N = GameConfig.Npc
local isBot = NpcService.isBot

local MatchService = {}

local state = Net.state()
local rng = Random.new()
local limiter = RateLimiter.new(GameConfig.RateLimits)
MatchService.limiter = limiter
-- other services hook a real player's match start / return to the lobby (cosmetics, abilities)
local startHooks: { (Player) -> () } = {}
local leaveHooks: { (Player) -> () } = {}
function MatchService.onPlayerMatchStart(fn: (Player) -> ())
	table.insert(startHooks, fn)
end
function MatchService.onPlayerMatchEnd(fn: (Player) -> ())
	table.insert(leaveHooks, fn)
end

-- the running match (nil in the lobby)
type Current = {
	matchId: string,
	logic: any,
	roster: { [number]: any }, -- Player or NPC bot
	isTest: boolean,
	abort: boolean,
	abortReason: string?,
	lastPos: { [number]: Vector3 },
	lastSwing: { [number]: number },
	startSide: string,
	finishSide: string,
}
local current: Current? = nil
local busy = false -- guards against a second concurrent match (A23)
local forceStartFlag = false
local hunterTimes: { [number]: number } = {} -- this server's "last time you started as Catcher"
local resultsHooks: { (any) -> () } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

function MatchService.current(): Current?
	return current
end

function MatchService.onResults(fn: (any) -> ())
	table.insert(resultsHooks, fn)
end

-- ===== state helpers =====

local function setPhase(phase: string, duration: number)
	state:SetAttribute("Phase", phase)
	state:SetAttribute("PhaseEndsAt", now() + duration)
	state:SetAttribute("PhaseId", (state:GetAttribute("PhaseId") or 0) + 1)
	Net.event("MatchState"):FireAllClients({
		phase = phase,
		endsAt = now() + duration,
		wave = state:GetAttribute("Wave"),
		maxWaves = state:GetAttribute("MaxWaves"),
		cleanStreak = state:GetAttribute("CleanStreak"), -- clean crossings in a row so far
		streakToWin = state:GetAttribute("StreakToWin"),
		lastClean = state:GetAttribute("LastClean"), -- was the crossing that just ended clean?
		finishSide = state:GetAttribute("FinishSide"),
		lastStanding = state:GetAttribute("LastStanding"), -- user id of a lone Runner's solo crossing
	})
end

local function updateCounts()
	local c = current
	if c then
		state:SetAttribute("RunnersLeft", c.logic:runnersRemaining())
		state:SetAttribute("Catchers", c.logic:catchersCount())
	else
		state:SetAttribute("RunnersLeft", 0)
		state:SetAttribute("Catchers", 0)
	end
end

local function minPlayers(): number
	local need = if N.ENABLED then GameConfig.Match.MIN_TO_START else GameConfig.Match.MIN_PLAYERS
	if RunService:IsStudio() and workspace:GetAttribute("EOS_Sandbox") == true then
		return math.huge -- knife test baseplate (SandboxService): no matches
	end
	if RunService:IsStudio() then
		local dev = workspace:GetAttribute(GameConfig.Match.DEV_MIN_PLAYERS_ATTRIBUTE)
		if type(dev) == "number" and dev >= 1 then
			need = math.floor(dev)
		end
	end
	return need
end

local function eligiblePlayers(): { Player }
	local out = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if DataService.isLoaded(plr) and not plr:GetAttribute("EOS_AFK") and CharacterService.rootPosition(plr) then
			table.insert(out, plr)
		end
	end
	return out
end

local function setGates(closed: boolean)
	local gates = CollectionService:GetTagged("EOS_Gate")
	if #gates == 0 then
		Analytics.warn("UnexpectedStateRecovery", "nogates", "no EOS_Gate parts found (world not built?)", { reason = "NO_GATES" })
	end
	for _, g in ipairs(gates) do
		if g:IsA("BasePart") then
			g.CanCollide = closed
			g.Transparency = 1 -- invisible either way (developer, Oct 15)
		end
	end
end

local function forwardEvents(c: Current)
	for _, e in ipairs(c.logic:drainEvents()) do
		local name = e.name
		e.name = nil
		Analytics.log(name, e)
	end
end

-- everyone still in the match (players and NPCs)
local function participantsOf(c: Current): { any }
	local out = {}
	for uid, plr in pairs(c.roster) do
		local p = c.logic:get(uid)
		if p and not p.disconnected and plr.Parent then
			table.insert(out, plr)
		end
	end
	return out
end

local function fireMatch(c: Current, remote: string, payload: any)
	local ev = Net.event(remote)
	for _, plr in ipairs(participantsOf(c)) do
		if not isBot(plr) then
			ev:FireClient(plr, payload)
		end
	end
end

local function fireTo(actor: any, remote: string, payload: any)
	if not isBot(actor) then
		Net.event(remote):FireClient(actor, payload)
	end
end

-- which friend look an NPC wears (clients swap in their own friend's name / face); nil for players
local function slotOf(actor: any): number?
	return if isBot(actor) then actor.slot else nil
end

local function toast(plr: Player, text: string, kind: string?)
	Net.event("Toast"):FireClient(plr, { text = text, kind = kind or "info" })
end

local function syncPlayer(c: Current, plr: Player)
	local p = c.logic:get(plr.UserId)
	if not p then
		return
	end
	plr:SetAttribute("EOS_Secured", c.logic:securedTier(p))
	plr:SetAttribute("EOS_Safe", p.isSafeThisWave)
	plr:SetAttribute("EOS_MatchCaptures", p.captureCount)
	plr:SetAttribute("EOS_CatcherSource", p.conversionCause or (if p.initialHunter then "START" else nil))
end

-- where a participant belongs right now (respawns, out-of-bounds recovery)
local function rolePosition(c: Current, plr: Player): (Vector3, Vector3)
	local p = c.logic:get(plr.UserId)
	local arena = Layout.Arena.CENTER
	if p and p.role == "RUNNER" then
		local zone = if p.isSafeThisWave then c.finishSide else c.startSide
		local spots = Layout.zoneSpawns(zone, 12)
		return spots[rng:NextInteger(1, #spots)], arena
	end
	local spots = Layout.catcherSpawns(10)
	return spots[rng:NextInteger(1, #spots)], arena
end

-- ===== capture =====

local function inAnyZone(pos: Vector3): boolean
	return Layout.inBox(pos, Layout.Zones.A) or Layout.inBox(pos, Layout.Zones.B)
end

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.RespectCanCollide = true

local function lineOfSight(a: Vector3, b: Vector3, exclude: { Instance }): boolean
	losParams.FilterDescendantsInstances = exclude
	local dir = b - a
	local hit = workspace:Raycast(a, dir, losParams)
	return hit == nil
end

-- Server-side validation + the atomic logic transaction. kind: "contact" | "swing" | "server"
local function tryCapture(c: Current, hunter: any, victim: any, kind: string): (boolean, string?)
	local hp, vp = CharacterService.rootPosition(hunter), CharacterService.rootPosition(victim)
	if not hp or not vp then
		return false, "NO_CHARACTER"
	end
	local reach = if kind == "swing" then C.TAG_RADIUS else C.CONTACT_RADIUS
	if kind ~= "server" then
		reach += C.LAG_TOLERANCE
	end
	local flat = Vector3.new(hp.X - vp.X, 0, hp.Z - vp.Z).Magnitude
	if flat > reach then
		return false, "TOO_FAR"
	end
	if math.abs(hp.Y - vp.Y) > C.MAX_VERTICAL_GAP then
		return false, "HEIGHT"
	end
	if inAnyZone(vp) then
		return false, "VICTIM_IN_SAFE_ZONE"
	end
	if C.LINE_OF_SIGHT and not lineOfSight(hp, vp, { hunter.Character :: Instance, victim.Character :: Instance }) then
		return false, "NO_LOS"
	end
	if kind == "swing" then
		local last = c.lastSwing[hunter.UserId] or -math.huge
		if os.clock() - last < C.TAG_COOLDOWN then
			return false, "COOLDOWN"
		end
		c.lastSwing[hunter.UserId] = os.clock()
	end
	local ok, reason, info = c.logic:capture(hunter.UserId, victim.UserId, now())
	if not ok then
		return false, reason
	end
	-- the victim is out for the rest of this crossing (a Catcher from the next one)
	CharacterService.applyRole(victim, "CAUGHT")
	-- ...and goes down, knocked away from the Catcher. A knife hit is decided on the click (above, the old
	-- jab's rule) but the fall waits for the stab's knife to land (GameConfig.Stab.STRIKE_TIME)
	local away = Vector3.new(vp.X - hp.X, 0, vp.Z - hp.Z)
	if away.Magnitude < 0.1 then
		local hroot = hunter.Character and hunter.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		away = if hroot then hroot.CFrame.LookVector else Vector3.zAxis
		away = Vector3.new(away.X, 0, away.Z)
	end
	away = if away.Magnitude > 0.01 then away.Unit else Vector3.zAxis
	local push = away * C.RAGDOLL_PUSH + Vector3.new(0, C.RAGDOLL_LIFT, 0)
	if kind == "swing" then
		local char = victim.Character
		task.delay(GameConfig.Stab.STRIKE_TIME, function()
			-- still the same body, still down this crossing (a crossing that just ended stands them up)
			if char and victim.Character == char and victim:GetAttribute("EOS_Role") == "CAUGHT" then
				CharacterService.ragdoll(victim, push)
			end
		end)
	else
		CharacterService.ragdoll(victim, push)
	end
	syncPlayer(c, victim)
	syncPlayer(c, hunter)
	CharacterService.refreshTag(hunter)
	updateCounts()
	forwardEvents(c)
	fireTo(victim, "RoleChanged", {
		role = "CAUGHT",
		cause = "CAPTURED",
		by = hunter.UserId,
		byName = hunter.DisplayName,
		bySlot = slotOf(hunter),
		bankedTier = info.victimSecured,
	})
	fireMatch(c, "CaptureFeedback", {
		hunterId = hunter.UserId,
		hunterName = hunter.DisplayName,
		hunterSlot = slotOf(hunter),
		victimId = victim.UserId,
		victimName = victim.DisplayName,
		victimSlot = slotOf(victim),
		stolenTier = info.stolenTier,
		creditedTier = info.creditedTier,
		hunterSecured = info.hunterSecured,
		shells = info.shells,
		position = vp,
		runnersLeft = info.runnersLeft,
	})
	return true, nil
end

-- ===== remote: RequestTag =====

local function onRequestTag(plr: Player, target: any, kind: any, aim: any)
	if not limiter:allow(plr.UserId, "RequestTag", os.clock()) then
		return
	end
	local badAim = aim ~= nil and (typeof(aim) ~= "Vector3" or aim ~= aim or aim.Magnitude < 0.1 or aim.Magnitude > 2)
	if (target ~= nil and type(target) ~= "number") or (kind ~= "contact" and kind ~= "swing") or badAim then
		Analytics.warn("RemoteValidationRejected", "tag" .. plr.UserId, "bad RequestTag payload from " .. plr.UserId, { userId = plr.UserId, remote = "RequestTag" })
		return
	end
	if kind == "swing" and aim and plr:GetAttribute("EOS_Role") == "CATCHER" then
		-- everyone sees the hit go where this Catcher aimed (also on the Studio knife-test baseplate)
		CharacterService.markSwing(plr, aim)
	end
	local c = current
	if not c or c.logic.phase ~= "ACTIVE" or not c.roster[plr.UserId] then
		return
	end
	local me = c.logic:get(plr.UserId)
	if not me or me.role ~= "CATCHER" then
		return
	end
	local victim: any = nil
	if target then
		local v = c.roster[target]
		if v and v.Parent then
			victim = v
		end
	else
		-- no target given: nearest vulnerable Runner (for a swing: only in front of where it was aimed)
		local hp = CharacterService.rootPosition(plr)
		local best = math.huge
		local aimFlat = if aim then Vector3.new(aim.X, 0, aim.Z) else nil
		local cosCone = math.cos(C.SWING_CONE + math.rad(15)) -- a little slack for lag
		if hp then
			for uid, other in pairs(c.roster) do
				local op = c.logic:get(uid)
				local pos = CharacterService.rootPosition(other)
				local inFront = true
				if pos and aimFlat and aimFlat.Magnitude > 0.05 then
					local off = Vector3.new(pos.X - hp.X, 0, pos.Z - hp.Z)
					inFront = off.Magnitude < 1 or off.Unit:Dot(aimFlat.Unit) >= cosCone
				end
				if op and op.role == "RUNNER" and pos and inFront then
					local d = (pos - hp).Magnitude
					if d < best then
						best, victim = d, other
					end
				end
			end
		end
	end
	if victim then
		tryCapture(c, plr, victim, kind)
	end
end

-- ===== per-tick checks =====

local function tick(c: Current)
	local t = now()
	local runners, catchers = {}, {}
	for uid, plr in pairs(c.roster) do
		local p = c.logic:get(uid)
		if p and not p.disconnected and plr.Parent then
			local pos = CharacterService.rootPosition(plr)
			if pos then
				-- activity (ignores teleports)
				local last = c.lastPos[uid]
				local tpAt = plr:GetAttribute("EOS_TeleportedAt") or 0
				if last and os.clock() - tpAt > 0.5 then
					local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(last.X, 0, last.Z)).Magnitude
					if d < 40 then
						c.logic:markActivity(uid, d)
					end
				end
				c.lastPos[uid] = pos
				-- out of bounds / fell: put them back where they belong
				if pos.Y < -25 or not Layout.inBox(pos, { center = Layout.ArenaBounds.center, size = Layout.ArenaBounds.size + Vector3.new(30, 60, 30) }) then
					local spot, look = rolePosition(c, plr)
					CharacterService.teleport(plr, spot, look)
					Analytics.log("UnexpectedStateRecovery", { userId = uid, reason = "OUT_OF_BOUNDS", matchId = c.matchId })
				elseif p.role == "RUNNER" then
					if not p.isSafeThisWave and Layout.inBox(pos, Layout.Zones[c.finishSide]) then
						local ok, _, info = c.logic:finishCrossing(uid, t)
						if ok then
							CharacterService.applyRole(plr, "RUNNER", info.newTier)
							syncPlayer(c, plr)
							fireMatch(c, "RunnerEvolved", { userId = uid, name = plr.DisplayName, slot = slotOf(plr), prevTier = info.prevTier, newTier = info.newTier, shells = info.shells, crossings = info.crossings })
							updateCounts()
						end
					elseif not p.isSafeThisWave then
						table.insert(runners, { plr = plr, pos = pos })
					else
						-- made it across: no going back into the field this crossing. Once clear of the zone
						-- wall it closes behind them; stepping back out before that puts them back in the zone
						local depth = Layout.zoneDepth(pos, c.finishSide)
						if depth >= GameConfig.Match.SAFE_LOCK_DEPTH then
							CharacterService.setZoneLock(plr, true)
						elseif depth < -GameConfig.Match.SAFE_ESCAPE_MARGIN then
							local spot, look = rolePosition(c, plr)
							CharacterService.teleport(plr, spot, look)
						end
					end
				elseif p.role == "CATCHER" and t >= p.graceUntil then
					table.insert(catchers, { plr = plr, pos = pos })
				end
			end
		end
	end
	-- server contact scan (does not depend on any client)
	if GameConfig.Features.SERVER_CONTACT_SCAN and t >= c.logic.waveStartedAt + T.WAVE_START_PROTECTION then
		for _, r in ipairs(runners) do
			if not inAnyZone(r.pos) then
				for _, k in ipairs(catchers) do
					local flat = Vector3.new(r.pos.X - k.pos.X, 0, r.pos.Z - k.pos.Z).Magnitude
					if flat <= C.CONTACT_RADIUS and math.abs(r.pos.Y - k.pos.Y) <= C.MAX_VERTICAL_GAP then
						if tryCapture(c, k.plr, r.plr, "server") then
							break
						end
					end
				end
			end
		end
	end
	forwardEvents(c)
end

-- ===== match flow =====

local function waitPhase(c: Current?, seconds: number, stop: (() -> boolean)?)
	local untilT = os.clock() + seconds
	while os.clock() < untilT do
		if c and c.abort then
			return
		end
		if stop and stop() then
			return
		end
		task.wait(0.1)
	end
end

local function cleanupPlayer(plr: any)
	if isBot(plr) then
		NpcService.despawn(plr) -- match NPCs leave with the match
		return
	end
	plr:SetAttribute("EOS_InMatch", false)
	for _, fn in ipairs(leaveHooks) do
		task.spawn(fn, plr)
	end
	plr:SetAttribute("EOS_Secured", nil)
	plr:SetAttribute("EOS_Safe", nil)
	plr:SetAttribute("EOS_MatchCaptures", nil)
	plr:SetAttribute("EOS_CatcherSource", nil)
	if plr.Parent then
		CharacterService.applyRole(plr, "LOBBY")
		local spawn = Layout.Lobby.SPAWN + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-4, 4))
		CharacterService.teleport(plr, spawn, Layout.Lobby.CENTERPIECE)
	end
end

local function buildResultsPayload(c: Current, results: any): any
	local function nameOf(uid: number?): string?
		if not uid then
			return nil
		end
		local plr = c.roster[uid]
		return plr and plr.DisplayName or ("Player " .. uid)
	end
	local runners = {}
	for _, r in ipairs(results.topRunners) do
		table.insert(runners, { userId = r.userId, name = nameOf(r.userId), npcSlot = slotOf(c.roster[r.userId]), place = r.place, crossings = r.crossings, securedTier = r.securedTier, survived = r.survived })
	end
	local thief = nil
	if results.topCatchers[1] then
		local k = results.topCatchers[1]
		thief = { userId = k.userId, name = nameOf(k.userId), npcSlot = slotOf(c.roster[k.userId]), captures = k.captures, bestStolenTier = k.bestStolenTier }
	end
	return {
		matchId = results.matchId,
		isTest = results.isTest,
		team = results.team,
		endReason = results.endReason,
		wavesPlayed = results.wavesPlayed,
		maxCrossings = results.maxCrossings,
		champion = results.champion,
		topRunners = runners,
		topThief = thief,
		nextMatchAt = now() + T.RESULTS + T.INTERMISSION,
	}
end

local function runMatch(roster: { Player }, isTest: boolean, solo: boolean)
	local matchId = HttpService:GenerateGUID(false)
	local logic = MatchLogic.new({
		matchId = matchId,
		tiers = TierConfig,
		rewards = RewardConfig,
		economy = EconomyConfig,
		cleanStreakToWin = GameConfig.Match.CLEAN_STREAK_TO_WIN,
		timeoutBreaksStreak = GameConfig.Match.TIMEOUT_BREAKS_STREAK,
		maxWaves = GameConfig.Match.MAX_CROSSINGS_SAFETY,
		conversionGrace = T.CONVERSION_GRACE,
		waveStartProtection = T.WAVE_START_PROTECTION,
		minActiveDistance = GameConfig.Match.MIN_ACTIVE_DISTANCE,
		isTest = isTest,
		solo = solo,
	})
	-- fair initial Catcher(s)
	local candidates = {}
	for _, plr in ipairs(roster) do
		local prof = DataService.get(plr)
		table.insert(candidates, {
			userId = plr.UserId,
			volunteer = plr:GetAttribute("EOS_Volunteer") == true,
			isNewPlayer = plr:GetAttribute("EOS_IsNew") == true,
			lastHunterAt = hunterTimes[plr.UserId] or (prof and prof.hunterHistory and prof.hunterHistory.lastHunterAt) or 0,
		})
	end
	local actors: { any } = table.clone(roster)
	local catcherIds: { number }
	if N.ENABLED and not solo and #roster < N.RUNNER_TARGET then
		-- NPCs: Catcher slots go to real volunteers first, then NPCs (so real players get to run);
		-- NPC Runners then top the real Runners up to RUNNER_TARGET
		local slotsK = GameConfig.initialCatchersFor(N.RUNNER_TARGET + 1)
		local volunteers = {}
		for _, cand in ipairs(candidates) do
			if cand.volunteer then
				table.insert(volunteers, cand)
			end
		end
		catcherIds = MatchLogic.pickInitialCatchers(volunteers, math.min(slotsK, #volunteers), rng)
		local npcRunners = math.max(0, N.RUNNER_TARGET - (#roster - #catcherIds))
		local npcCatchers = slotsK - #catcherIds
		for i = 1, npcRunners + npcCatchers do
			local bot = NpcService.spawn("MATCH", Layout.Zones.A.center, Layout.Arena.CENTER)
			if not bot then
				break -- out of NPC looks: play with what we have
			end
			table.insert(actors, bot)
			if i > npcRunners then
				table.insert(catcherIds, bot.UserId)
			end
		end
	else
		-- solo test: VOLUNTEER TO HUNT on = start as the Catcher, off = start as a Runner
		local catcherCount = if solo then (if roster[1]:GetAttribute("EOS_Volunteer") == true then 1 else 0) else GameConfig.initialCatchersFor(#roster)
		catcherIds = MatchLogic.pickInitialCatchers(candidates, catcherCount, rng)
	end
	local isCatcher = {}
	for _, id in ipairs(catcherIds) do
		isCatcher[id] = true
		local who = nil
		for _, a in ipairs(actors) do
			if a.UserId == id then
				who = a
			end
		end
		if who and not isBot(who) then
			hunterTimes[id] = os.time()
		end
	end
	local c: Current = {
		matchId = matchId,
		logic = logic,
		roster = {},
		isTest = isTest,
		abort = false,
		abortReason = nil,
		lastPos = {},
		lastSwing = {},
		startSide = "A",
		finishSide = "B",
	}
	for _, plr in ipairs(actors) do
		local role = if isCatcher[plr.UserId] then "CATCHER" else "RUNNER"
		logic:addParticipant(plr.UserId, role, { isNewPlayer = plr:GetAttribute("EOS_IsNew") == true })
		c.roster[plr.UserId] = plr
		if not isBot(plr) then
			Analytics.log("PlayerMatchQueued", { userId = plr.UserId, matchId = matchId, role = role })
		end
	end
	current = c
	NpcService.setMatch(c)
	state:SetAttribute("MatchId", matchId)
	state:SetAttribute("IsTest", isTest)
	state:SetAttribute("IsSolo", solo)
	state:SetAttribute("MaxWaves", if solo then logic.maxCrossings else 0) -- 0 = no fixed number of crossings
	state:SetAttribute("CleanStreak", 0)
	state:SetAttribute("StreakToWin", logic.cleanStreakToWin)
	state:SetAttribute("LastClean", nil)
	state:SetAttribute("Wave", 0)
	state:SetAttribute("LastStanding", nil)
	state:SetAttribute("InMatchCount", #actors)
	state:SetAttribute("NpcCount", #actors - #roster)
	Analytics.log("MatchStarted", { matchId = matchId, players = #roster, npcs = #actors - #roster, catchers = #catcherIds, test = isTest })

	-- watchdog (A22): the match can never run past its planned length + slack
	local deadline = os.clock() + GameConfig.plannedMatchSeconds(if solo then logic.maxCrossings else logic.maxWaves) + T.WATCHDOG_SLACK
	task.spawn(function()
		while current == c do
			if os.clock() > deadline then
				c.abort = true
				c.abortReason = "WATCHDOG"
				Analytics.warn("UnexpectedStateRecovery", "watchdog" .. matchId, "match watchdog fired for " .. matchId, { matchId = matchId, reason = "WATCHDOG" })
				return
			end
			task.wait(1)
		end
	end)

	-- ROLE_REVEAL: Runners in Side A, Catchers on the centre line, gates closed
	setGates(true)
	c.startSide, c.finishSide = MatchLogic.sidesForWave(1)
	state:SetAttribute("StartSide", c.startSide)
	state:SetAttribute("FinishSide", c.finishSide)
	local runnerSpots = Layout.zoneSpawns(c.startSide, #actors)
	local catcherSpots = Layout.catcherSpawns(#actors)
	local ri, ci = 0, 0
	local order = table.clone(actors) -- shuffled, so real players don't always get the same spots
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for _, plr in ipairs(order) do
		local p = logic:get(plr.UserId)
		plr:SetAttribute("EOS_InMatch", true)
		if not isBot(plr) then
			for _, fn in ipairs(startHooks) do
				local ok, err = pcall(fn, plr)
				if not ok then
					warn("[EOS] match start hook: " .. tostring(err))
				end
			end
		end
		CharacterService.applyRole(plr, p.role, p.currentCarriedTier)
		syncPlayer(c, plr)
		if p.role == "RUNNER" then
			ri += 1
			CharacterService.teleport(plr, runnerSpots[ri], Layout.Zones[c.finishSide].center)
		else
			ci += 1
			CharacterService.teleport(plr, catcherSpots[ci], Layout.Zones[c.startSide].center)
		end
		fireTo(plr, "RoleChanged", { role = p.role, cause = "START", bankedTier = 1 })
	end
	updateCounts()
	forwardEvents(c)
	setPhase("ROLE_REVEAL", T.ROLE_REVEAL)
	waitPhase(c, T.ROLE_REVEAL)

	-- WAVES
	while not c.abort do
		local ok = logic:startWave(now())
		if not ok then
			break
		end
		c.startSide, c.finishSide = MatchLogic.sidesForWave(logic.wave)
		state:SetAttribute("Wave", logic.wave)
		-- one Runner left: their solo crossing decides the match (make it = they win)
		state:SetAttribute("LastStanding", logic.soloCrossingBy)
		state:SetAttribute("StartSide", c.startSide)
		state:SetAttribute("FinishSide", c.finishSide)
		for _, plr in ipairs(participantsOf(c)) do
			syncPlayer(c, plr)
			CharacterService.setZoneLock(plr, false) -- last crossing's finish is this one's start: free to go
		end
		setGates(false)
		setPhase("CROSSING", T.CROSSING)
		forwardEvents(c)
		local endsAt = os.clock() + T.CROSSING
		while os.clock() < endsAt and not c.abort do
			tick(c)
			if logic:waveComplete() then
				break
			end
			task.wait(T.TICK)
		end
		-- end of wave: timeouts become Catchers and keep their tier
		local res = logic:endWave(now())
		setGates(true)
		if res.ok then
			state:SetAttribute("CleanStreak", res.cleanStreak)
			state:SetAttribute("LastClean", res.clean)
		end
		if res.ok then
			for _, uid in ipairs(res.timedOut) do
				local plr = c.roster[uid]
				if plr and plr.Parent then
					CharacterService.applyRole(plr, "CATCHER")
					syncPlayer(c, plr)
					fireTo(plr, "RoleChanged", { role = "CATCHER", cause = "TIMEOUT", bankedTier = logic:securedTier(logic:get(uid)), graceUntil = now() + T.CONVERSION_GRACE })
				end
			end
			-- caught during this crossing: Catchers from the next one
			for _, uid in ipairs(res.promoted or {}) do
				local plr = c.roster[uid]
				if plr and plr.Parent then
					CharacterService.applyRole(plr, "CATCHER")
					syncPlayer(c, plr)
					fireTo(plr, "RoleChanged", { role = "CATCHER", cause = "NEXT_ROUND", bankedTier = logic:securedTier(logic:get(uid)) })
				end
			end
		end
		updateCounts()
		forwardEvents(c)
		if not res.ok or res.nextAction == "END" then
			break
		end
		-- WAVE_END: flip sides; safe Runners are already standing in the next start zone
		setPhase("WAVE_END", T.WAVE_TRANSITION)
		waitPhase(c, 1.2)
		local nextStart = select(1, MatchLogic.sidesForWave(logic.wave + 1))
		local spots = Layout.catcherSpawns(#actors)
		local k = 0
		for _, plr in ipairs(participantsOf(c)) do
			local p = logic:get(plr.UserId)
			local pos = CharacterService.rootPosition(plr)
			if p.role == "CATCHER" then
				k += 1
				CharacterService.teleport(plr, spots[k], Layout.Zones[nextStart].center)
			elseif pos and not Layout.inBox(pos, Layout.Zones[nextStart]) then
				local zs = Layout.zoneSpawns(nextStart, 12)
				CharacterService.teleport(plr, zs[rng:NextInteger(1, #zs)], Layout.Arena.CENTER)
			end
		end
		waitPhase(c, T.WAVE_TRANSITION - 1.2)
	end

	-- RESULTS + SETTLEMENT (exactly once)
	if logic.phase == "ACTIVE" then
		logic:endWave(now()) -- abort mid-wave: resolve it the normal way
	end
	logic:forceEnd(c.abortReason or logic.endReason or "END")
	local results = logic:computeResults(now())
	forwardEvents(c)
	local payload = buildResultsPayload(c, results)
	local rewards = {}
	for uid, plr in pairs(c.roster) do
		local p = logic:get(uid)
		if p and not p.disconnected and plr.Parent and not isBot(plr) then
			local s = logic:settlementFor(uid)
			local applied = false
			if s then
				applied = DataService.settle(plr, s)
			end
			rewards[uid] = { applied = applied }
		end
	end
	setGates(true)
	for _, plr in ipairs(participantsOf(c)) do
		cleanupPlayer(plr)
	end
	setPhase("RESULTS", T.RESULTS)
	-- everyone sees the podium; participants also get their own reward block
	local ev = Net.event("Results")
	for _, plr in ipairs(Players:GetPlayers()) do
		local mine = results.perPlayer[plr.UserId]
		local out = table.clone(payload)
		if mine then
			out.you = {
				securedTier = mine.securedTier,
				eligible = mine.eligible,
				source = mine.source,
				nearMiss = mine.nearMiss,
				gold = mine.gold,
				goldParts = mine.goldParts,
				gems = mine.gems,
				material = mine.material,
				crossings = mine.crossings,
				captures = mine.captures,
				runnerPlace = mine.runnerPlace,
				win = mine.win,
				saved = rewards[plr.UserId] and rewards[plr.UserId].applied or false,
			}
		end
		ev:FireClient(plr, out)
	end
	for _, fn in ipairs(resultsHooks) do
		task.spawn(fn, payload)
	end
	state:SetAttribute("LastResults", HttpService:JSONEncode(payload))
	current = nil
	NpcService.setMatch(nil)
	state:SetAttribute("NpcCount", 0)
	updateCounts()
	state:SetAttribute("InMatchCount", 0)
	state:SetAttribute("Wave", 0)
	waitPhase(nil, T.RESULTS)
end

-- ===== lobby loop =====

local function lobbyLoop()
	while true do
		local need = minPlayers()
		local ready = eligiblePlayers()
		state:SetAttribute("Ready", #ready)
		state:SetAttribute("Needed", need)
		if #ready < need and not forceStartFlag then
			if state:GetAttribute("Phase") ~= "WAITING" then
				setPhase("WAITING", 0)
			end
			task.wait(0.5)
			continue
		end
		-- INTERMISSION countdown (aborts if players drop out)
		setPhase("INTERMISSION", T.INTERMISSION)
		local cancelled = false
		waitPhase(nil, T.INTERMISSION, function()
			if forceStartFlag then
				return true
			end
			local n = #eligiblePlayers()
			state:SetAttribute("Ready", n)
			if n < minPlayers() then
				cancelled = true
				return true
			end
			return false
		end)
		if cancelled then
			continue
		end
		forceStartFlag = false
		local roster = eligiblePlayers()
		-- Studio solo test with NPCs switched off (EOS_DevMinPlayers = 1, one player): a practice match
		-- of one, never rewarded. With NPCs on, a lone player gets a full NPC-filled match instead.
		local solo = not N.ENABLED and RunService:IsStudio() and #roster == 1 and minPlayers() <= 1
		if #roster < 2 and not solo and not N.ENABLED then
			continue -- a match needs at least one Runner and one Catcher
		end
		if #roster == 0 then
			continue
		end
		if #roster > GameConfig.Match.MAX_PLAYERS then
			local trimmed = {}
			for i = 1, GameConfig.Match.MAX_PLAYERS do
				trimmed[i] = roster[i]
			end
			roster = trimmed
		end
		local isTest = solo or #roster < GameConfig.Match.MIN_PLAYERS
		if busy then
			Analytics.warn("UnexpectedStateRecovery", "busy", "match start refused: a match is already running", { reason = "DUPLICATE_START" })
			continue
		end
		busy = true
		local ok, err = pcall(runMatch, roster, isTest, solo)
		busy = false
		if not ok then
			warn("[EOS] match crashed: " .. tostring(err))
			Analytics.log("UnexpectedStateRecovery", { reason = "MATCH_ERROR", error = string.sub(tostring(err), 1, 200) })
			local c = current
			if c then
				c.logic:forceEnd("ERROR")
				for _, plr in ipairs(participantsOf(c)) do
					pcall(cleanupPlayer, plr)
				end
			end
			for _, bot in ipairs(table.clone(NpcService.all())) do
				if bot.kind == "MATCH" then
					NpcService.despawn(bot)
				end
			end
			current = nil
			NpcService.setMatch(nil)
			setGates(true)
			updateCounts()
			task.wait(2)
		end
	end
end

-- ===== joins, leaves, respawns =====

local function onLeaving(plr: Player)
	limiter:forget(plr.UserId)
	local c = current
	if not c or not c.roster[plr.UserId] then
		return
	end
	local removed = c.logic:removeParticipant(plr.UserId, now())
	if removed then
		local s = c.logic:settlementFor(plr.UserId)
		if s and ((s.gold or 0) > 0 or (s.gems or 0) > 0) then
			DataService.settle(plr, s) -- partial: Gold/Gems already earned, never an egg piece
		end
		forwardEvents(c)
		updateCounts()
	end
end

local function onCharacter(plr: Player, char: Model)
	local c = current
	if not c or not c.roster[plr.UserId] then
		return
	end
	local p = c.logic:get(plr.UserId)
	if not p or p.disconnected then
		return
	end
	char:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.1)
	CharacterService.applyRole(plr, p.role, p.currentCarriedTier)
	local spot, look = rolePosition(c, plr)
	CharacterService.teleport(plr, spot, look)
end

-- ===== dev / test hooks (Studio) =====

function MatchService.forceStart()
	forceStartFlag = true
end

function MatchService.forceEndWave()
	local c = current
	if c then
		c.abort = true
		c.abortReason = "DEV_FORCE_END"
	end
end

function MatchService._testCapture(hunterId: number, victimId: number, kind: string?): (boolean, string?)
	local c = current
	if not c then
		return false, "NO_MATCH"
	end
	local h, v = c.roster[hunterId], c.roster[victimId]
	if not h or not v then
		return false, "NOT_IN_ROSTER"
	end
	return tryCapture(c, h, v, kind or "server")
end

function MatchService.init()
	state:SetAttribute("Phase", "BOOT")
	state:SetAttribute("PhaseEndsAt", now())
	state:SetAttribute("Wave", 0)
	state:SetAttribute("MaxWaves", 0)
	state:SetAttribute("CleanStreak", 0)
	state:SetAttribute("StreakToWin", GameConfig.Match.CLEAN_STREAK_TO_WIN)
	setGates(true)
	Net.event("RequestTag").OnServerEvent:Connect(onRequestTag)
	DataService.onLeaving(onLeaving)
	Players.PlayerAdded:Connect(function(plr)
		plr:SetAttribute("EOS_InMatch", false)
		plr.CharacterAdded:Connect(function(char)
			onCharacter(plr, char)
		end)
	end)
	for _, plr in ipairs(Players:GetPlayers()) do
		plr.CharacterAdded:Connect(function(char)
			onCharacter(plr, char)
		end)
	end
	for _, problem in ipairs(TierConfig.validate()) do
		warn("[EOS] TierConfig: " .. problem)
	end
end

function MatchService.start()
	task.spawn(lobbyLoop)
end

return MatchService
