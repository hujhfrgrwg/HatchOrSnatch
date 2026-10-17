--!strict
-- MatchLogic: the pure rules engine for one Evolve or Steal match (GDD v0.2 sections 1, 2, 4).
-- No Roblox services, no yields: every mutation runs start-to-finish in one call, so each call
-- is atomic with respect to other server threads (this is the per-victim mutex of GDD 4).
-- Time is passed in by the caller (seconds, any monotonic clock).
--
-- How a match ends (developer, Oct 2026): crossings keep coming (no fixed number). The Runners win
-- when 3 crossings IN A ROW go by clean (nobody caught; a timeout breaks the run too, configurable),
-- or when the last Runner standing makes a solo crossing (one that STARTS with only them): once is
-- enough. No Runners left = the Catchers win. A high safety cap (maxWaves) only stops stuck matches.
-- Egg levels still climb +1 per crossing up to the top level (3 crossings to reach it).
--
-- LOCKED rules encoded here:
--  * every valid crossing = +1 carried tier (Runners only, once per wave)
--  * capture: victim BANKS max(earned, carried); victim becomes Catcher for the rest of the match
--  * captor's bestStolenTier = max(old, min(stolen, CATCHER_TIER_CAP)); never the survivor tier
--  * timeout: unfinished Runner becomes Catcher, keeps earned tier, nobody is credited
--  * one settlement per participant per match (idempotency is enforced again in ProfileLogic)

local MatchLogic = {}
MatchLogic.__index = MatchLogic

-- CAUGHT: tagged this wave; out (no tagging, no being tagged) until the wave ends, then a Catcher
export type Role = "RUNNER" | "CATCHER" | "CAUGHT"

export type Participant = {
	userId: number,
	role: Role,
	initialHunter: boolean,
	isNewPlayer: boolean,
	currentCarriedTier: number?, -- nil once a Catcher
	earnedRunnerTier: number,
	bestStolenTier: number,
	crossingsCompleted: number,
	isSafeThisWave: boolean,
	isConverted: boolean,
	convertedAt: number?,
	convertedWave: number?,
	conversionCause: string?, -- "CAPTURED" | "TIMEOUT"
	capturedBy: number?,
	captureCount: number,
	captureVictims: { number },
	firstCaptureAt: number?,
	finishTimes: { [number]: number }, -- wave -> time the Runner entered the safe zone
	lastCrossingFinishAt: number?,
	shells: number,
	laterCaptureShells: number,
	graceUntil: number,
	disconnected: boolean,
	disconnectedAt: number?,
	activeDistance: number,
}

export type Options = {
	matchId: string,
	tiers: any, -- TierConfig
	rewards: any, -- RewardConfig
	economy: any?, -- EconomyConfig (GDD v0.4 Gold / Gems / egg piece per match)
	maxCrossings: number?, -- crossings to reach the top egg level (the level cap does the clamping)
	cleanStreakToWin: number?, -- clean crossings in a row that win it for the Runners (default 3)
	maxWaves: number?, -- safety cap on crossings (a watchdog, not a rule; default 40)
	timeoutBreaksStreak: boolean?, -- does a Runner timing out spoil a clean crossing? (default true)
	conversionGrace: number?,
	waveStartProtection: number?,
	minActiveDistance: number?,
	isTest: boolean?,
	-- Studio solo test (one player, never rewarded): waves run their full time even with no Runners
	-- left, so the one player can try both roles (time out as a Runner -> play the next waves as Catcher)
	solo: boolean?,
}

local function sortedIds(t: { [number]: any }): { number }
	local ids = {}
	for id in pairs(t) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

function MatchLogic.new(opts: Options)
	assert(type(opts.matchId) == "string" and #opts.matchId > 0, "matchId required")
	local self = setmetatable({}, MatchLogic)
	self.matchId = opts.matchId
	self.tiers = opts.tiers
	self.rewards = opts.rewards
	self.economy = opts.economy
	self.maxCrossings = opts.maxCrossings or opts.tiers.MAX_CROSSINGS
	self.cleanStreakToWin = opts.cleanStreakToWin or 3
	self.maxWaves = opts.maxWaves or 40
	self.timeoutBreaksStreak = opts.timeoutBreaksStreak ~= false
	self.cleanStreak = 0 -- clean crossings in a row so far
	self.waveCaptures = 0 -- captures during the current crossing
	self.conversionGrace = opts.conversionGrace or 1.5
	self.waveStartProtection = opts.waveStartProtection or 0
	self.minActiveDistance = opts.minActiveDistance or 0
	self.isTest = opts.isTest == true or opts.solo == true
	self.solo = opts.solo == true
	self.phase = "SETUP" -- SETUP -> ACTIVE <-> BETWEEN -> ENDED
	self.wave = 0
	self.waveStartedAt = 0
	self.participants = {} :: { [number]: Participant }
	self.events = {} :: { any }
	self.endReason = nil :: string?
	-- the one Runner left when this crossing started (their solo run), else nil
	self.soloCrossingBy = nil :: number?
	self.results = nil :: any
	return self
end

function MatchLogic:_event(name: string, fields: { [string]: any })
	fields.name = name
	fields.matchId = self.matchId
	fields.wave = self.wave
	table.insert(self.events, fields)
end

-- Remove and return queued events (the service forwards them to analytics / clients).
function MatchLogic:drainEvents(): { any }
	local e = self.events
	self.events = {}
	return e
end

-- Wave 1 runs A -> B, wave 2 B -> A, wave 3 A -> B ... Returns (startSide, finishSide).
function MatchLogic.sidesForWave(wave: number): (string, string)
	if wave % 2 == 1 then
		return "A", "B"
	end
	return "B", "A"
end

-- A05: only the finish side of the CURRENT wave counts as a crossing.
function MatchLogic.isCorrectFinishZone(wave: number, zone: string): boolean
	local _, finish = MatchLogic.sidesForWave(wave)
	return zone == finish
end

-- ===== roster =====

-- Fair initial-Catcher pick (GDD 5). candidates: { userId, volunteer, isNewPlayer, lastHunterAt }
-- Order: volunteers first, then non-new players, then least recently hunted, then rng tiebreak.
-- New players are only picked when nobody else is available.
function MatchLogic.pickInitialCatchers(candidates: { any }, count: number, rng: Random?): { number }
	local r = rng or Random.new()
	local list = {}
	for _, c in ipairs(candidates) do
		table.insert(list, { c = c, roll = r:NextNumber() })
	end
	table.sort(list, function(a, b)
		local av, bv = a.c.volunteer and 1 or 0, b.c.volunteer and 1 or 0
		if av ~= bv then
			return av > bv
		end
		local an, bn = a.c.isNewPlayer and 1 or 0, b.c.isNewPlayer and 1 or 0
		if an ~= bn then
			return an < bn
		end
		local at, bt = a.c.lastHunterAt or 0, b.c.lastHunterAt or 0
		if at ~= bt then
			return at < bt
		end
		return a.roll < b.roll
	end)
	local out = {}
	for i = 1, math.min(count, #list) do
		table.insert(out, list[i].c.userId)
	end
	return out
end

function MatchLogic:addParticipant(userId: number, role: Role, info: { isNewPlayer: boolean? }?): (boolean, string?)
	if self.phase ~= "SETUP" then
		return false, "NOT_SETUP"
	end
	if self.participants[userId] then
		return false, "DUPLICATE"
	end
	if role ~= "RUNNER" and role ~= "CATCHER" then
		return false, "BAD_ROLE"
	end
	local base = self.tiers.BASE_TIER
	local p: Participant = {
		userId = userId,
		role = role,
		initialHunter = role == "CATCHER",
		isNewPlayer = (info and info.isNewPlayer) == true,
		currentCarriedTier = if role == "RUNNER" then base else nil,
		earnedRunnerTier = base,
		bestStolenTier = base, -- initial Catchers: insured Tier 1 eligibility
		crossingsCompleted = 0,
		isSafeThisWave = false,
		isConverted = false,
		convertedAt = nil,
		convertedWave = nil,
		conversionCause = nil,
		capturedBy = nil,
		captureCount = 0,
		captureVictims = {},
		firstCaptureAt = nil,
		finishTimes = {},
		lastCrossingFinishAt = nil,
		shells = 0,
		laterCaptureShells = 0,
		graceUntil = 0,
		disconnected = false,
		disconnectedAt = nil,
		activeDistance = 0,
	}
	self.participants[userId] = p
	if role == "CATCHER" then
		self:_event("StartingHunterAssigned", { userId = userId })
	end
	return true, nil
end

function MatchLogic:get(userId: number): Participant?
	return self.participants[userId]
end

function MatchLogic:markActivity(userId: number, distance: number)
	local p = self.participants[userId]
	if p and not p.disconnected and distance > 0 and distance < 1000 then
		p.activeDistance += distance
	end
end

function MatchLogic:runnersRemaining(): number
	local n = 0
	for _, p in pairs(self.participants) do
		if p.role == "RUNNER" and not p.disconnected then
			n += 1
		end
	end
	return n
end

function MatchLogic:unsafeRunnersRemaining(): number
	local n = 0
	for _, p in pairs(self.participants) do
		if p.role == "RUNNER" and not p.disconnected and not p.isSafeThisWave then
			n += 1
		end
	end
	return n
end

function MatchLogic:catchersCount(): number
	local n = 0
	for _, p in pairs(self.participants) do
		if p.role == "CATCHER" and not p.disconnected then
			n += 1
		end
	end
	return n
end

function MatchLogic:participantCount(): number
	local n = 0
	for _ in pairs(self.participants) do
		n += 1
	end
	return n
end

-- ===== tiers =====

function MatchLogic:securedTier(p: Participant): number
	local t = math.max(p.earnedRunnerTier, p.bestStolenTier)
	if p.role == "RUNNER" and p.currentCarriedTier then
		t = math.max(t, p.currentCarriedTier)
	end
	return self.tiers.clamp(t)
end

-- ===== waves =====

function MatchLogic:startWave(now: number): (boolean, string?)
	if self.phase ~= "SETUP" and self.phase ~= "BETWEEN" then
		return false, "BAD_PHASE"
	end
	if self.wave >= (if self.solo then self.maxCrossings else self.maxWaves) then
		return false, "NO_MORE_WAVES"
	end
	if self:runnersRemaining() == 0 and not self.solo then
		return false, "NO_RUNNERS"
	end
	self.wave += 1
	self.phase = "ACTIVE"
	self.waveStartedAt = now
	self.soloCrossingBy = nil
	self.waveCaptures = 0
	for _, p in pairs(self.participants) do
		if p.role == "RUNNER" then
			p.isSafeThisWave = false
		end
	end
	-- last one standing: a crossing that starts with a single Runner is their solo run. Make it
	-- across and the match ends right there with them as the winner (no more crossings needed).
	if not self.solo and self:runnersRemaining() == 1 then
		for id, p in pairs(self.participants) do
			if p.role == "RUNNER" and not p.disconnected then
				self.soloCrossingBy = id
			end
		end
	end
	self:_event("WaveStarted", { at = now, runners = self:runnersRemaining(), catchers = self:catchersCount(), lastStanding = self.soloCrossingBy })
	return true, nil
end

-- A Runner entered the CORRECT finish zone for this wave (the service checks direction).
function MatchLogic:finishCrossing(userId: number, now: number): (boolean, string?, any)
	if self.phase ~= "ACTIVE" then
		return false, "BAD_PHASE", nil
	end
	local p = self.participants[userId]
	if not p then
		return false, "NOT_PARTICIPANT", nil
	end
	if p.disconnected then
		return false, "DISCONNECTED", nil
	end
	if p.role ~= "RUNNER" then
		return false, "NOT_RUNNER", nil
	end
	if p.isSafeThisWave then
		return false, "ALREADY_SAFE", nil -- A04: repeated entries give nothing
	end
	local old = p.currentCarriedTier or self.tiers.BASE_TIER
	local new = math.min(old + 1, self.tiers.SURVIVOR_TIER_MAX)
	p.currentCarriedTier = new
	p.earnedRunnerTier = math.max(p.earnedRunnerTier, new)
	p.crossingsCompleted += 1
	p.isSafeThisWave = true
	p.finishTimes[self.wave] = now
	p.lastCrossingFinishAt = now
	local shells = self.rewards.SHELLS_PER_CROSSING
	p.shells += shells
	self:_event("RunnerFinishedWave", { userId = userId, elapsed = now - self.waveStartedAt, newTier = new })
	self:_event("RunnerEvolved", { userId = userId, prevTier = old, newTier = new })
	self:_event("HighestSecuredTierChanged", { userId = userId, tier = self:securedTier(p) })
	return true, nil, { prevTier = old, newTier = new, shells = shells, crossings = p.crossingsCompleted }
end

-- The normative capture transaction (GDD 4). Runs without yielding = atomic.
function MatchLogic:capture(hunterId: number, victimId: number, now: number): (boolean, string?, any)
	if self.phase ~= "ACTIVE" then
		return false, "BAD_PHASE", nil
	end
	if hunterId == victimId then
		return false, "SELF", nil
	end
	local h = self.participants[hunterId]
	local v = self.participants[victimId]
	if not h or not v then
		return false, "NOT_PARTICIPANT", nil
	end
	if h.disconnected or v.disconnected then
		return false, "DISCONNECTED", nil
	end
	if h.role ~= "CATCHER" then
		return false, "HUNTER_NOT_CATCHER", nil
	end
	if v.role ~= "RUNNER" then
		return false, "VICTIM_NOT_RUNNER", nil -- A08 / A16: already captured
	end
	if v.isSafeThisWave then
		return false, "VICTIM_SAFE", nil -- A17
	end
	if now < h.graceUntil then
		return false, "HUNTER_GRACE", nil
	end
	if now < self.waveStartedAt + self.waveStartProtection then
		return false, "WAVE_START_PROTECTION", nil
	end

	self.waveCaptures += 1 -- this crossing isn't clean any more
	local stolen = v.currentCarriedTier or self.tiers.BASE_TIER
	-- victim banks the egg tier they were carrying
	v.earnedRunnerTier = math.max(v.earnedRunnerTier, stolen)
	-- captor's steal credit is clamped to the Catcher cap (A11: never the survivor tier)
	local credited = math.min(self.tiers.clamp(stolen), self.tiers.CATCHER_TIER_CAP)
	local prevHunterSecured = self:securedTier(h)
	h.bestStolenTier = math.max(h.bestStolenTier, credited)
	-- the victim is out for the rest of this wave and becomes a Catcher when it ends (endWave)
	v.currentCarriedTier = nil
	v.role = "CAUGHT"
	v.isConverted = true
	v.convertedAt = now
	v.convertedWave = self.wave
	v.conversionCause = "CAPTURED"
	v.capturedBy = hunterId
	-- captor stats + Shells (B09 schedule)
	h.captureCount += 1
	table.insert(h.captureVictims, victimId)
	h.firstCaptureAt = h.firstCaptureAt or now
	local pay, laterTotal = self.rewards.captureShells(h.captureCount, h.laterCaptureShells)
	h.laterCaptureShells = laterTotal
	h.shells += pay

	self:_event("RunnerCaptured", { userId = victimId, hunterId = hunterId, stolenTier = stolen, credited = credited, elapsed = now - self.waveStartedAt })
	if self:securedTier(h) ~= prevHunterSecured then
		self:_event("HighestSecuredTierChanged", { userId = hunterId, tier = self:securedTier(h) })
	end
	return true, nil, {
		stolenTier = stolen,
		creditedTier = credited,
		hunterSecured = self:securedTier(h),
		victimSecured = self:securedTier(v),
		shells = pay,
		captureCount = h.captureCount,
		runnersLeft = self:runnersRemaining(),
	}
end

-- All remaining Runners are safe (or there are none): the wave can end early.
function MatchLogic:waveComplete(): boolean
	if self.solo and self:runnersRemaining() == 0 then
		return false -- solo Catcher: the wave runs its full time
	end
	return self.phase == "ACTIVE" and self:unsafeRunnersRemaining() == 0
end

-- End the current wave. Unfinished Runners time out: they become Catchers and keep their
-- earned tier; nobody gets steal credit (A13). Returns what happened and what comes next.
function MatchLogic:endWave(now: number): any
	if self.phase ~= "ACTIVE" then
		return { ok = false, reason = "BAD_PHASE" }
	end
	local timedOut = {}
	local promoted = {} -- caught this wave: Catchers from the next wave on
	for _, id in ipairs(sortedIds(self.participants)) do
		local p = self.participants[id]
		if p.role == "CAUGHT" then
			p.role = "CATCHER"
			p.graceUntil = now + self.conversionGrace
			table.insert(promoted, id)
			self:_event("RoleConverted", { userId = id, cause = "CAPTURED", bankedTier = p.earnedRunnerTier })
		elseif p.role == "RUNNER" and not p.disconnected and not p.isSafeThisWave then
			p.earnedRunnerTier = math.max(p.earnedRunnerTier, p.currentCarriedTier or self.tiers.BASE_TIER)
			p.currentCarriedTier = nil
			p.role = "CATCHER"
			p.isConverted = true
			p.convertedAt = now
			p.convertedWave = self.wave
			p.conversionCause = "TIMEOUT"
			p.graceUntil = now + self.conversionGrace
			table.insert(timedOut, id)
			self:_event("RunnerTimeout", { userId = id, bankedTier = p.earnedRunnerTier })
			self:_event("RoleConverted", { userId = id, cause = "TIMEOUT", bankedTier = p.earnedRunnerTier })
		end
	end
	local runners = self:runnersRemaining()
	-- clean crossing: nobody caught (and, by default, nobody timed out). 3 in a row wins it.
	local clean = self.waveCaptures == 0 and (#timedOut == 0 or not self.timeoutBreaksStreak)
	self.cleanStreak = if clean then self.cleanStreak + 1 else 0
	local nextAction
	local lone = self.soloCrossingBy and self.participants[self.soloCrossingBy]
	if runners == 0 and not self.solo then
		nextAction = "END"
		self.endReason = "ALL_RUNNERS_GONE"
	elseif lone and lone.role == "RUNNER" and lone.isSafeThisWave and not lone.disconnected then
		-- the last Runner made their solo crossing: once is enough, they win
		nextAction = "END"
		self.endReason = "LAST_ONE_STANDING"
	elseif self.solo and self.wave >= self.maxCrossings then
		nextAction = "END" -- Studio solo test (no NPCs): a fixed 3 crossings
		self.endReason = "FINAL_WAVE"
	elseif not self.solo and self.cleanStreak >= self.cleanStreakToWin then
		nextAction = "END"
		self.endReason = "CLEAN_STREAK"
	elseif not self.solo and self.wave >= self.maxWaves then
		nextAction = "END" -- safety cap: whoever is still running survives
		self.endReason = "SAFETY_CAP"
	else
		nextAction = "NEXT_WAVE"
	end
	self.phase = if nextAction == "END" then "ENDED" else "BETWEEN"
	self:_event("WaveEnded", { clean = clean, cleanStreak = self.cleanStreak, captures = self.waveCaptures, timeouts = #timedOut, runnersLeft = runners })
	return { ok = true, timedOut = timedOut, promoted = promoted, runnersLeft = runners, nextAction = nextAction, clean = clean, cleanStreak = self.cleanStreak, captures = self.waveCaptures }
end

-- Disconnect / leave mid-match: no conversion, no steal credit, no completion reward.
function MatchLogic:removeParticipant(userId: number, now: number): boolean
	local p = self.participants[userId]
	if not p or p.disconnected then
		return false
	end
	p.disconnected = true
	p.disconnectedAt = now
	p.isSafeThisWave = false
	self:_event("MatchQuit", { userId = userId, role = p.role })
	return true
end

-- Force the match to end (watchdog / abort). Safe to call more than once.
function MatchLogic:forceEnd(reason: string)
	if self.phase ~= "ENDED" then
		self.phase = "ENDED"
		self.endReason = reason
	end
end

-- ===== results =====

-- a winning Runner: still running when the match ended (after 3 clean crossings in a row, the last
-- one standing's solo crossing, or the safety cap). Nobody survives a Catcher win.
local function survived(self: any, p: Participant): boolean
	if p.role ~= "RUNNER" or p.disconnected then
		return false
	end
	if self.endReason == "LAST_ONE_STANDING" then
		return self.soloCrossingBy == p.userId
	end
	if self.solo then
		return p.crossingsCompleted >= self.maxCrossings
	end
	return true
end

-- GDD 2 "Winner and leaderboards" ordering for players who STARTED as Runners.
local function runnerLess(self: any, a: Participant, b: Participant): boolean
	if a.crossingsCompleted ~= b.crossingsCompleted then
		return a.crossingsCompleted > b.crossingsCompleted
	end
	local sa, sb = survived(self, a), survived(self, b)
	if sa ~= sb then
		return sa
	end
	if sa and sb then
		-- full survivors: final-wave time, then previous wave time, then user id
		for w = self.wave, 1, -1 do
			local ta, tb = a.finishTimes[w] or math.huge, b.finishTimes[w] or math.huge
			if ta ~= tb then
				return ta < tb
			end
		end
		return a.userId < b.userId
	end
	-- same crossings, both converted: later conversion ranks higher
	local ca, cb = a.convertedAt or math.huge, b.convertedAt or math.huge
	if ca ~= cb then
		return ca > cb
	end
	local la, lb = a.lastCrossingFinishAt or math.huge, b.lastCrossingFinishAt or math.huge
	if la ~= lb then
		return la < lb
	end
	return a.userId < b.userId
end

local function catcherLess(a: Participant, b: Participant): boolean
	if a.captureCount ~= b.captureCount then
		return a.captureCount > b.captureCount
	end
	if a.bestStolenTier ~= b.bestStolenTier then
		return a.bestStolenTier > b.bestStolenTier
	end
	local fa, fb = a.firstCaptureAt or math.huge, b.firstCaptureAt or math.huge
	if fa ~= fb then
		return fa < fb
	end
	return a.userId < b.userId
end

function MatchLogic:isEligible(p: Participant): boolean
	if p.disconnected then
		return false
	end
	return p.activeDistance >= self.minActiveDistance or p.crossingsCompleted > 0 or p.captureCount > 0
end

-- How the secured tier was obtained, for the results card.
function MatchLogic:rewardSource(p: Participant): string
	local secured = self:securedTier(p)
	if survived(self, p) then
		if self.endReason == "LAST_ONE_STANDING" then
			return "LAST ONE STANDING"
		end
		return "SURVIVED " .. p.crossingsCompleted .. " CROSSINGS TO THE END"
	end
	if p.bestStolenTier > p.earnedRunnerTier and p.bestStolenTier == secured then
		return "STOLE TIER " .. secured
	end
	if p.initialHunter and secured == self.tiers.BASE_TIER then
		return "INITIAL CATCHER"
	end
	if p.crossingsCompleted > 0 then
		return "SURVIVED " .. p.crossingsCompleted .. (if p.crossingsCompleted == 1 then " CROSSING" else " CROSSINGS")
	end
	return "STARTING EGG"
end

-- Informative near-miss line for converted Runners (GDD 8); nil when there is no next tier.
function MatchLogic:nearMiss(p: Participant): string?
	if p.initialHunter or not p.isConverted then
		return nil
	end
	local nextTier = p.earnedRunnerTier + 1
	if nextTier > self.tiers.SURVIVOR_TIER_MAX or self:securedTier(p) >= nextTier then
		return nil
	end
	return "ONE MORE ESCAPE WOULD REACH TIER " .. nextTier
end

-- Compute results once; later calls return the cached table.
function MatchLogic:computeResults(now: number): any
	if self.results then
		return self.results
	end
	self:forceEnd(self.endReason or "RESULTS")
	local runners, catchers = {}, {}
	local anySurvivor = false
	for _, id in ipairs(sortedIds(self.participants)) do
		local p = self.participants[id]
		if not p.disconnected then
			if not p.initialHunter then
				table.insert(runners, p)
				if survived(self, p) then
					anySurvivor = true
				end
			end
			if p.captureCount > 0 then
				table.insert(catchers, p)
			end
		end
	end
	table.sort(runners, function(a, b)
		return runnerLess(self, a, b)
	end)
	table.sort(catchers, catcherLess)

	local team = if anySurvivor then "RUNNERS" else "CATCHERS"
	local perPlayer = {}
	local runnerPlace = {}
	for i, p in ipairs(runners) do
		runnerPlace[p.userId] = i
	end
	for _, id in ipairs(sortedIds(self.participants)) do
		local p = self.participants[id]
		local eligible = self:isEligible(p)
		local secured = self:securedTier(p)
		local win = false
		if eligible then
			if team == "RUNNERS" then
				win = survived(self, p)
			else
				win = p.initialHunter
			end
		end
		-- GDD v0.4: Gold, Gems and one egg piece, from server-confirmed contributions only
		local gold, goldParts, gems, material = 0, {}, 0, nil
		if self.economy then
			local outcome = { active = eligible, crossings = p.crossingsCompleted, captures = p.captureCount, win = win }
			gold, goldParts = self.economy.goldFor(outcome)
			gems = self.economy.gemsFor(outcome)
			material = if eligible then self.economy.materialForTier(secured) else nil
		end
		perPlayer[id] = {
			userId = id,
			gold = gold,
			goldParts = goldParts,
			gems = gems,
			material = material,
			eligible = eligible,
			disconnected = p.disconnected,
			securedTier = secured,
			source = self:rewardSource(p),
			nearMiss = self:nearMiss(p),
			matchShells = p.shells,
			participationShells = if eligible then self.rewards.PARTICIPATION_SHELLS else 0,
			crossings = p.crossingsCompleted,
			captures = p.captureCount,
			bestStolenTier = p.bestStolenTier,
			earnedRunnerTier = p.earnedRunnerTier,
			survived = survived(self, p),
			initialHunter = p.initialHunter,
			conversionCause = p.conversionCause,
			runnerPlace = runnerPlace[id],
			win = win,
		}
	end

	local topRunners = {}
	for i = 1, math.min(3, #runners) do
		local p = runners[i]
		table.insert(topRunners, {
			userId = p.userId,
			place = i,
			crossings = p.crossingsCompleted,
			securedTier = self:securedTier(p),
			survived = survived(self, p),
		})
	end
	local topCatchers = {}
	for i = 1, math.min(3, #catchers) do
		local p = catchers[i]
		table.insert(topCatchers, { userId = p.userId, captures = p.captureCount, bestStolenTier = p.bestStolenTier })
	end

	self.results = {
		matchId = self.matchId,
		isTest = self.isTest,
		team = team,
		endReason = self.endReason,
		wavesPlayed = self.wave,
		maxCrossings = self.maxCrossings,
		cleanStreakToWin = self.cleanStreakToWin,
		champion = if team == "RUNNERS" and topRunners[1] then topRunners[1].userId else nil,
		topRunner = if topRunners[1] then topRunners[1].userId else nil,
		topThief = if topCatchers[1] then topCatchers[1].userId else nil,
		topRunners = topRunners,
		topCatchers = topCatchers,
		perPlayer = perPlayer,
		at = now,
	}
	self:_event("MatchEnded", { team = team, reason = self.endReason, participants = self:participantCount() })
	return self.results
end

-- What ProfileLogic.applySettlement needs for one player. Disconnected players get a
-- ":partial" settlement: legitimately earned Shells/stats only, no egg, no completion.
function MatchLogic:settlementFor(userId: number): any
	local p = self.participants[userId]
	if not p then
		return nil
	end
	local results = self.results
	if p.disconnected then
		-- left early: keep what was already earned in the match (crossings, a steal), no piece, no win
		local gold, gems = 0, 0
		if self.economy then
			local outcome = { active = false, crossings = p.crossingsCompleted, captures = p.captureCount, win = false }
			gold = (self.economy.goldFor(outcome))
			gems = self.economy.gemsFor(outcome)
		end
		return {
			key = self.matchId .. ":partial",
			matchId = self.matchId,
			isTest = self.isTest,
			eggTier = nil,
			material = nil,
			gold = gold,
			gems = gems,
			shells = p.shells,
			stats = { wins = 0, matchesCompleted = 0, captures = p.captureCount, successfulCrossings = p.crossingsCompleted },
			bestTier = nil,
			quest = { crossings = p.crossingsCompleted, captures = p.captureCount, matches = 0, securedTier = 0 },
			initialHunter = p.initialHunter,
		}
	end
	assert(results, "computeResults before settlementFor")
	local r = results.perPlayer[userId]
	local eligible = r.eligible
	return {
		key = self.matchId,
		matchId = self.matchId,
		isTest = self.isTest,
		eggTier = if eligible then r.securedTier else nil,
		material = r.material,
		gold = if self.economy then r.gold else r.matchShells + r.participationShells,
		gems = r.gems,
		shells = r.matchShells + r.participationShells,
		stats = {
			wins = if r.win then 1 else 0,
			matchesCompleted = if eligible then 1 else 0,
			captures = p.captureCount,
			successfulCrossings = p.crossingsCompleted,
		},
		bestTier = if eligible then r.securedTier else nil,
		quest = {
			crossings = p.crossingsCompleted,
			captures = p.captureCount,
			matches = if eligible then 1 else 0,
			securedTier = if eligible then r.securedTier else 0,
		},
		initialHunter = p.initialHunter,
	}
end

return MatchLogic
