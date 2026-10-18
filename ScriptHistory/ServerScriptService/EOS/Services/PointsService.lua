--!strict
-- PointsService (HOS-PTS-001, 17 Oct 2026): match points, the end leaderboard, points -> XP and the Gold split.
-- Numbers and switches: Shared.PointsConfig. It never edits MatchLogic; it reads the match (MatchService.current())
-- and hooks MatchService's own extension points:
--   onCrossing "start" / "end" / "match"   per-crossing reset, the leaderboard + Gold split before settlement
--   onCatcherAttack(plr, kind)             jukes (NPC Catchers call PointsService.catcherAttacked the same way)
-- plus a 10 Hz watch of the participants for safety (+100 / Hero +200) and catches (+50, snatch by egg).
-- Hooks other code calls (one line each):
--   MatchService.settleXp      PointsService.xpFor(plr) -> match XP = points (nil = Points off: the old XP)
--   ReviveService               PointsService.award(c, actor, "revive")
-- Remotes (ReplicatedStorage.EOS_Points): Pop (owner: { kind, amount, rarity? }), Juke (everyone near: { userId }),
-- Board (match players at the end: { rows, podium, crossings, escaped, total, team }).
-- Points also live on the player as the attribute EOS_MatchPoints (0 outside a match).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PointsConfig = require(Shared:WaitForChild("PointsConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Analytics = require(script.Parent.Analytics)
local CharacterService = require(script.Parent.CharacterService)
local NpcService = require(script.Parent.NpcService)

local P = PointsConfig.Points
local J = PointsConfig.Juke
local isBot = NpcService.isBot

local PointsService = {}

local MatchService: any = nil -- bound in init (MatchService requires this module inline, so no top-level require)
local folder: Folder
local popRemote: RemoteEvent
local jukeRemote: RemoteEvent
local boardRemote: RemoteEvent
local roundRemote: RemoteEvent

-- the last match's points, kept after it ends until settlement has read them: uid -> totals
local lastMatchId: string? = nil
local lastTotals: { [number]: number } = {}
local lastBoard: any = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

function PointsService.enabled(): boolean
	return PointsConfig.Enabled == true
end

-- ===== per-match state (on the match table c, so it dies with the match) =====
type Stat = { total: number, safe: number, hero: number, jukes: number, revives: number, catches: number, snatch: { [string]: number } }

local function statsOf(c: any, uid: number): Stat
	c.pts = c.pts or {}
	local s = c.pts[uid]
	if not s then
		s = { total = 0, safe = 0, hero = 0, jukes = 0, revives = 0, catches = 0, snatch = {} }
		c.pts[uid] = s
	end
	return s
end

local function fireOwner(actor: any, payload: any)
	if not isBot(actor) and actor.Parent then
		popRemote:FireClient(actor, payload)
	end
end

-- kind: "safe" | "hero" | "juke" | "revive" | "catch" | "snatch"; rarity for snatch
function PointsService.award(c: any, actor: any, kind: string, rarity: string?)
	if not PointsService.enabled() or not c or not actor then
		return
	end
	local amount = 0
	if kind == "safe" then
		amount = P.SAFE
	elseif kind == "hero" then
		amount = P.HERO_SAFE
	elseif kind == "juke" then
		amount = P.JUKE
	elseif kind == "revive" then
		amount = P.REVIVE
	elseif kind == "catch" then
		amount = P.CATCH
	elseif kind == "snatch" then
		amount = rarity and P.SNATCH[rarity] or 0
	end
	if amount <= 0 then
		return
	end
	require(script.Parent.EggService).onAward(c, actor, kind) -- HOS-EGG-002: jukes and revives charge the carried egg
	local s = statsOf(c, actor.UserId)
	s.total += amount
	if kind == "safe" then
		s.safe += 1
	elseif kind == "hero" then
		s.hero += 1
		s.safe += 1
	elseif kind == "juke" then
		s.jukes += 1
	elseif kind == "revive" then
		s.revives += 1
	elseif kind == "catch" then
		s.catches += 1
	elseif kind == "snatch" and rarity then
		s.snatch[rarity] = (s.snatch[rarity] or 0) + 1
	end
	if not isBot(actor) then
		actor:SetAttribute("EOS_MatchPoints", s.total)
	end
	fireOwner(actor, { kind = if kind == "snatch" then "snatch_" .. tostring(rarity) else kind, amount = amount, rarity = rarity, total = s.total })
end

-- ===== the 10 Hz watch: safety and catches =====
-- snapshot per uid: { role, safe, carried }; c.ptsHeroAt[uid] = heroBonusCrossings when the crossing started
local function watch(c: any, settle: boolean?)
	c.ptsSnap = c.ptsSnap or {}
	local snap = c.ptsSnap
	-- HOS-PTS-001: a safety award waits 0.3 s for the Hero flag; at the end of a crossing ("settle") anything still
	-- waiting pays now, so the Runner who ends the crossing (or a whole group arriving at once) is never skipped
	c.ptsPending = c.ptsPending or {}
	local function paySafe(uid: number, actor: any, p: any)
		local heroBefore = c.ptsPending[uid]
		if heroBefore == nil then
			return
		end
		c.ptsPending[uid] = nil
		local hero = ((p :: any).heroBonusCrossings or 0) > heroBefore
		PointsService.award(c, actor, if hero then "hero" else "safe")
	end
	if settle then
		for uid in pairs(c.ptsPending) do
			local actor, p = c.roster[uid], c.logic:get(uid)
			if actor and p then
				paySafe(uid, actor, p)
			end
		end
	end
	for uid, actor in pairs(c.roster) do
		local p = c.logic:get(uid)
		if p and not p.disconnected and actor.Parent then
			-- HOS-PTS-001: a Runner first seen this crossing counts as not yet safe (safe before the first tick still pays)
			local was = snap[uid] or (if p.role == "RUNNER" then { role = "RUNNER", safe = false, carried = p.currentCarriedTier or 1 } else nil)
			if was then
				-- reached safety this crossing (+200 instead when they were the Hero who got across alone)
				if p.role == "RUNNER" and p.isSafeThisWave and not was.safe then
					c.ptsPending[uid] = (c.ptsHeroAt and c.ptsHeroAt[uid]) or 0
					if settle then
						paySafe(uid, actor, p)
					else
						task.delay(0.3, function() -- HeroChickenService marks a Hero's success a tick later
							if MatchService.current() == c then
								paySafe(uid, actor, p)
							end
						end)
					end
				end
				-- caught: +50 to the Catcher, + the egg the Runner carried (Rare / Epic / Legendary)
				if p.role == "CAUGHT" and was.role == "RUNNER" and p.capturedBy then
					local hunter = c.roster[p.capturedBy]
					if hunter then
						PointsService.award(c, hunter, "catch")
						local rarity = PointsConfig.rarityForLevel(was.carried)
						if rarity ~= "common" then
							PointsService.award(c, hunter, "snatch", rarity)
						end
					end
				end
			end
			snap[uid] = { role = p.role, safe = p.isSafeThisWave, carried = p.currentCarriedTier or (was and was.carried) or 1 }
		end
	end
end

-- ===== jukes =====
-- a Catcher's lunge or stab started: Runners this close who are still free a moment later juked it
function PointsService.catcherAttacked(catcher: any, kind: string)
	if not PointsService.enabled() or not MatchService then
		return
	end
	local c = MatchService.current()
	if not c or c.logic.phase ~= "ACTIVE" then
		return
	end
	local cp = CharacterService.rootPosition(catcher)
	if not cp then
		return
	end
	local near = {}
	for uid, actor in pairs(c.roster) do
		local p = c.logic:get(uid)
		if p and p.role == "RUNNER" and not p.isSafeThisWave and not p.disconnected and actor.Parent then
			local rp = CharacterService.rootPosition(actor)
			if rp and Vector3.new(rp.X - cp.X, 0, rp.Z - cp.Z).Magnitude <= J.RADIUS then
				table.insert(near, actor)
			end
		end
	end
	if #near == 0 then
		return
	end
	local wave = c.logic.wave
	task.delay(J.CHECK_AFTER, function()
		if MatchService.current() ~= c or c.logic.wave ~= wave then
			return
		end
		c.ptsJuke = c.ptsJuke or {}
		for _, actor in ipairs(near) do
			local p = c.logic:get(actor.UserId)
			if p and p.role == "RUNNER" and not p.disconnected then
				local key = tostring(catcher.UserId) .. ":" .. tostring(actor.UserId)
				local last = c.ptsJuke[key]
				if not last or os.clock() - last >= J.PAIR_COOLDOWN then
					c.ptsJuke[key] = os.clock()
					PointsService.award(c, actor, "juke")
					-- "+10" over their head for everyone in the match
					for _, other in pairs(c.roster) do
						if not isBot(other) and other.Parent then
							jukeRemote:FireClient(other, { userId = actor.UserId, slot = if isBot(actor) then actor.slot else nil })
						end
					end
				end
			end
		end
	end)
end

-- ===== the end: leaderboard, Gold split =====
local function outcomeOf(c: any, p: any, results: any): string
	local r = results and results.perPlayer[p.userId]
	if r and r.survived then
		local s = c.pts and c.pts[p.userId]
		return if s and s.hero > 0 then "HERO" else "ESCAPED"
	end
	if p.initialHunter then
		return "CATCHER"
	end
	return if p.conversionCause == "TIMEOUT" then "CATCHER" else "CAUGHT"
end

local function statsLine(s: Stat?): { string }
	local out = {}
	if not s then
		return out
	end
	local function add(n: number, one: string, many: string)
		if n > 0 then
			table.insert(out, n .. " " .. (if n == 1 then one else many))
		end
	end
	add(s.safe, "safe", "safe")
	if s.hero > 0 then
		table.insert(out, "Hero")
	end
	add(s.catches, "catch", "catches")
	for _, r in ipairs({ "legendary", "epic", "rare" }) do
		if (s.snatch[r] or 0) > 0 then
			table.insert(out, r:sub(1, 1):upper() .. r:sub(2) .. " snatch")
		end
	end
	add(s.jukes, "juke", "jukes")
	add(s.revives, "revive", "revives")
	return out
end

-- Gold: today's pot (what goldFor paid every eligible real player) re-shared: PLAYED floor each, the rest by points
local function splitGold(c: any, results: any)
	if not PointsConfig.Gold.SPLIT then
		return
	end
	local G = EconomyConfig.GOLD
	local elig, pot, sumPts = {}, 0, 0
	for uid, r in pairs(results.perPlayer) do
		local actor = c.roster[uid]
		if r.eligible and not r.disconnected and actor and not isBot(actor) then
			table.insert(elig, uid)
			local hero = 0 -- the Hero's extra crossings of Gold are replaced by their double points (HOS-HOC-001 line)
			for _, part in ipairs(r.goldParts or {}) do
				if part.label == "HERO" then
					hero += part.amount
				end
			end
			pot += (r.gold or 0) - hero
			sumPts += (c.pts and c.pts[uid] and c.pts[uid].total) or 0
		end
	end
	if #elig == 0 then
		return
	end
	local floorEach = math.min(G.ACTIVE, math.floor(pot / #elig))
	local rest = pot - floorEach * #elig
	local paid = 0
	table.sort(elig, function(a, b)
		local pa = (c.pts and c.pts[a] and c.pts[a].total) or 0
		local pb = (c.pts and c.pts[b] and c.pts[b].total) or 0
		if pa ~= pb then
			return pa > pb
		end
		return a < b
	end)
	local shares = {}
	for _, uid in ipairs(elig) do
		local pts = (c.pts and c.pts[uid] and c.pts[uid].total) or 0
		local share = if sumPts > 0 then math.floor(rest * pts / sumPts) else math.floor(rest / #elig)
		shares[uid] = share
		paid += share
	end
	shares[elig[1]] += rest - paid -- rounding goes to the top scorer, so the pot is paid out exactly
	for _, uid in ipairs(elig) do
		local r = results.perPlayer[uid]
		r.gold = floorEach + shares[uid]
		r.goldParts = { { label = PointsConfig.Gold.FLOOR_LABEL, amount = floorEach } }
		if shares[uid] > 0 then
			table.insert(r.goldParts, { label = PointsConfig.Gold.SHARE_LABEL, amount = shares[uid] })
		end
	end
end

-- the egg piece from the carried rarity (the ladder's levels mean rarities)
local function ladderPieces(results: any)
	if not PointsConfig.Ladder.Enabled then
		return
	end
	for _, r in pairs(results.perPlayer) do
		if r.material then
			r.material = PointsConfig.pieceFor(PointsConfig.rarityForLevel(r.securedTier))
		end
	end
end

local function onMatchEnd(c: any)
	-- computeResults caches: settlement right after this reads the same table we adjust here
	local results = c.logic:computeResults(now())
	splitGold(c, results)
	ladderPieces(results)
	local rows = {}
	local escaped, total = 0, 0
	for uid, actor in pairs(c.roster) do
		local p = c.logic:get(uid)
		if p and not p.disconnected then
			total += 1
			local s = c.pts and c.pts[uid]
			local outcome = outcomeOf(c, p, results)
			if outcome == "ESCAPED" or outcome == "HERO" then
				escaped += 1
			end
			table.insert(rows, {
				userId = uid,
				name = actor.DisplayName,
				npcSlot = if isBot(actor) then actor.slot else nil,
				outcome = outcome,
				stats = statsLine(s),
				points = s and s.total or 0,
				left = actor.Parent == nil,
				safe = s and s.safe or 0, catches = s and s.catches or 0, -- HOS-PTS-001: results v2 SURVIVED / CATCHES tabs
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.points ~= b.points then
			return a.points > b.points
		end
		return a.userId < b.userId
	end)
	local podium = {}
	for i = 1, math.min(PointsConfig.Podium.TOP, #rows) do
		podium[i] = rows[i].userId
	end
	lastMatchId = c.matchId
	lastTotals = {}
	for uid, s in pairs(c.pts or {}) do
		lastTotals[uid] = s.total
	end
	c.ptsBoard = { rows = rows, podium = podium, crossings = c.logic.wave, escaped = escaped, total = total, team = results.team, matchId = c.matchId,
		endReason = c.logic.endReason } -- HOS-PTS-001: CLEAN_STREAK = the Runners won early (results subtitle)
	lastBoard = c.ptsBoard
	for _, actor in pairs(c.roster) do
		if not isBot(actor) and actor.Parent then
			boardRemote:FireClient(actor, c.ptsBoard)
		end
	end
	Analytics.log("MatchPoints", { matchId = c.matchId, players = total, escaped = escaped, top = rows[1] and rows[1].points or 0 })
end

-- Between crossings (Hunter 17 Oct): the standings after this crossing, with each row's rank before it and its gain.
-- Sent at crossing "end" (+0.5 s so the last safety awards are in); never after the final crossing (results instead).
local function rankOf(list: { any }, key: string): { [number]: number }
	table.sort(list, function(a, b)
		if a[key] ~= b[key] then
			return a[key] > b[key]
		end
		return a.userId < b.userId
	end)
	local r = {}
	for i, row in ipairs(list) do
		r[row.userId] = i
	end
	return r
end

local function roundBoard(c: any)
	if c.logic.phase == "ENDED" or MatchService.current() ~= c then
		return
	end
	local rows = {}
	for uid, actor in pairs(c.roster) do
		local p = c.logic:get(uid)
		if p and not p.disconnected and actor.Parent then
			local total = (c.pts and c.pts[uid] and c.pts[uid].total) or 0
			local before = (c.ptsAtStart and c.ptsAtStart[uid]) or 0
			table.insert(rows, { userId = uid, name = actor.DisplayName, npcSlot = if isBot(actor) then actor.slot else nil,
				role = p.role, total = total, before = before, gained = total - before,
				hero = (c.pts and c.pts[uid] and c.pts[uid].hero or 0) > 0 }) -- HOS-PTS-001: HERO tag between crossings
		end
	end
	local prevRank = rankOf(table.clone(rows), "before")
	local newRank = rankOf(rows, "total") -- rows end up sorted by the new order
	for _, row in ipairs(rows) do
		row.prevRank = prevRank[row.userId]
		row.rank = newRank[row.userId]
	end
	local payload = { crossing = c.logic.wave, of = c.logic.maxWaves, rows = rows }
	for _, actor in pairs(c.roster) do
		if not isBot(actor) and actor.Parent then
			roundRemote:FireClient(actor, payload)
		end
	end
end

-- MatchService.settleXp: match XP = points x Xp.PER_POINT (nil = Points off, or no points for this match)
function PointsService.xpFor(plr: Player): number?
	if not PointsService.enabled() or not MatchService then
		return nil
	end
	local c = MatchService.current()
	if not c then
		return nil
	end
	local k = PointsConfig.Xp.PER_POINT
	if c.matchId == lastMatchId then
		return math.floor((lastTotals[plr.UserId] or 0) * k) -- settlement at the end
	end
	local s = c.pts and c.pts[plr.UserId]
	return math.floor((s and s.total or 0) * k) -- left mid-match: what they had
end

-- the last board (PodiumService / late joiners)
function PointsService.lastBoard(): any
	return lastBoard
end

function PointsService.init(matchService: any): any
	MatchService = matchService
	folder = ReplicatedStorage:FindFirstChild("EOS_Points") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "EOS_Points"
		folder.Parent = ReplicatedStorage
	end
	local function remote(name: string): RemoteEvent
		local r = folder:FindFirstChild(name) :: RemoteEvent
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
		return r
	end
	popRemote, jukeRemote, boardRemote, roundRemote = remote("Pop"), remote("Juke"), remote("Board"), remote("Round")
	if not PointsService.enabled() then
		return PointsService
	end
	MatchService.onCrossing(function(c: any, event: string, _wave: number)
		if event == "start" then
			c.ptsSnap = {} -- fresh snapshot: last crossing's safety doesn't carry over
			c.ptsAtStart = {}
			for uid, st in pairs(c.pts or {}) do
				c.ptsAtStart[uid] = st.total
			end
			c.ptsHeroAt = {}
			for uid in pairs(c.roster) do
				local p = c.logic:get(uid)
				c.ptsHeroAt[uid] = p and (p :: any).heroBonusCrossings or 0
			end
		elseif event == "end" then
			pcall(watch, c, true) -- HOS-PTS-001: settle the crossing's last arrivals and catches before the board
			task.delay(PointsConfig.Round.SEND, roundBoard, c)
		elseif event == "match" then
			pcall(watch, c, true) -- HOS-PTS-001: and before the results, XP and the Gold split
			onMatchEnd(c)
		end
	end)
	MatchService.onCatcherAttack(function(plr: Player, kind: string)
		PointsService.catcherAttacked(plr, kind)
	end)
	MatchService.onPlayerMatchEnd(function(plr: Player)
		plr:SetAttribute("EOS_MatchPoints", nil)
	end)
	MatchService.onPlayerMatchStart(function(plr: Player)
		plr:SetAttribute("EOS_MatchPoints", 0)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local c = MatchService.current()
		if c and c.logic.phase == "ACTIVE" then
			local ok, err = pcall(watch, c)
			if not ok then
				warn("[EOS] points watch: " .. tostring(err))
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(plr)
		lastTotals[plr.UserId] = nil
	end)
	-- require(script.Parent.PodiumService).init(MatchService, PointsService) -- HOS-PTS-001: podium off (Hunter 17 Oct); kept for later
	return PointsService
end

return PointsService
