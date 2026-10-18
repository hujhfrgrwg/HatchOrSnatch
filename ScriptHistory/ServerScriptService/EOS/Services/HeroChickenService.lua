--!strict
-- HeroChickenService (HOS-HOC-001, 17 Oct): the Hero or Chicken pick at the start of every crossing.
-- Server-authoritative. MatchService calls four hooks; everything else lives here.
--   runPick(c)          before a crossing starts (Runners lined up, gates shut). Blocks for the pick,
--                       the choice and the reveal; returns the Hero's user id or nil (CHICKEN / skipped).
--   crossingStarted(c)  just after Phase -> CROSSING: holds the group on the line during a Hero run.
--   step(c) -> number   every crossing tick: Hero resolved -> GROUP_READY -> the group goes. Returns the
--                       seconds to add to the crossing clock (once, when the group is released).
--   crossingEnded(c)    the crossing is over: release everyone, clear the stage.
-- Plus bonusFor(c, uid) at settlement (extra crossing value + bonus egg pieces for a successful Hero).
--
-- Replicated state: ReplicatedStorage.EOS_HeroChicken (Configuration) attributes
--   Stage ("" | CHOOSING | PICKED | REVEAL | READY | HERO_RUN | HERO_SUCCESS | GROUP_READY | GROUP_RUN),
--   StageAt, StageEndsAt, StageId, HeroResult ("CROSSED" | "CAUGHT" | "RUNNING"),
--   Wave, Catcher, Hover, Picked, Choice ("HERO" | "CHICKEN"), Hero, Lineup (JSON list of user ids along the line)
-- Remotes (children): Request (client -> server: "hover" | "pick" uid, "choose" "HERO"|"CHICKEN"),
--   Fx (server -> clients: { kind = "heroCrossed" | "heroCaught", userId, points, piece })

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local HC = require(Shared:WaitForChild("HeroChickenConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Analytics = require(script.Parent.Analytics)
local NpcService = require(script.Parent.NpcService)
local CrossingLineup = require(script.Parent.CrossingLineup)
local CatcherGesture = require(script.Parent.CatcherGesture)
local MatchLogic = require(script.Parent.Parent.Core.MatchLogic)

local RunService = game:GetService("RunService")

local TM = HC.Timing

-- Studio only (recordings / tests): workspace attributes HC_ForcePick = a Runner's user id (an NPC
-- Catcher picks them; "LOCAL" = the first real player) and HC_ForceChoice = "HERO" | "CHICKEN" (an NPC
-- Runner's choice). Live servers ignore both.
local function forced(name: string): any
	if not RunService:IsStudio() then
		return nil
	end
	return workspace:GetAttribute(name)
end
local isBot = NpcService.isBot
local rng = Random.new()

local HeroChickenService = {}

local state: Configuration
local requestRemote: RemoteEvent
local fxRemote: RemoteEvent

-- hooks = { lineUpCatchers, releaseCatchers, catcherLine } from MatchService (bind)
local hooks: any = {}

-- EOS_State.HeroRunActive: true only while a Hero runs alone (on go -> the group is released); other
-- systems (field Gems) pause on it. Every way out of a crossing clears it, so it can never stick.
local function setHeroRunActive(on: boolean)
	Net.state():SetAttribute("HeroRunActive", on)
end

-- the pick in progress (nil outside runPick)
local pick: { c: any, catcherId: number, lineup: { number }, hover: number?, picked: number?, choice: string?, stage: string }? = nil
local lastRequest: { [number]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setStage(stage: string, duration: number)
	state:SetAttribute("Stage", stage)
	state:SetAttribute("StageAt", now())
	state:SetAttribute("StageEndsAt", now() + duration)
	state:SetAttribute("StageId", (state:GetAttribute("StageId") or 0) + 1)
end

local function clearAll()
	setStage("", 0)
	for _, k in ipairs({ "Catcher", "Hover", "Picked", "Choice", "Hero", "Lineup" }) do
		state:SetAttribute(k, nil)
	end
end

local function waitUntil(c: any, t: number, stop: (() -> boolean)?)
	while now() < t do
		if c.abort then
			return
		end
		if stop and stop() then
			return
		end
		task.wait(0.05)
	end
end

local function rand(r: { number }): number
	return rng:NextNumber(r[1], r[2])
end

-- the lead Catcher: the same one all match while they're still a Catcher; real players first,
-- then the starting Catchers, then the lowest id (stable)
local function leadCatcher(c: any): any?
	local keep = c.hcLead and c.roster[c.hcLead]
	local kp = keep and c.logic:get(c.hcLead)
	if keep and kp and kp.role == "CATCHER" and not kp.disconnected and keep.Parent then
		return keep
	end
	local best, bestScore = nil, -math.huge
	for uid, actor in pairs(c.roster) do
		local p = c.logic:get(uid)
		if p and p.role == "CATCHER" and not p.disconnected and actor.Parent then
			local score = (if isBot(actor) then 0 else 1000) + (if p.initialHunter then 100 else 0) - math.abs(uid) * 1e-12
			if score > bestScore then
				best, bestScore = actor, score
			end
		end
	end
	c.hcLead = best and best.UserId or nil
	return best
end

local function stillRunner(c: any, uid: number?): boolean
	if not uid then
		return false
	end
	local p = c.logic:get(uid)
	local actor = c.roster[uid]
	return p ~= nil and p.role == "RUNNER" and not p.disconnected and actor ~= nil and actor.Parent ~= nil
end

local function onRequest(plr: Player, kind: any, arg: any)
	local t = os.clock()
	if t - (lastRequest[plr.UserId] or 0) < 0.05 then
		return -- hover spam: at most 20 a second
	end
	lastRequest[plr.UserId] = t
	local pk = pick
	if not pk or type(kind) ~= "string" then
		return
	end
	if kind == "hover" or kind == "pick" then
		if pk.stage ~= "CHOOSING" or plr.UserId ~= pk.catcherId or type(arg) ~= "number" then
			return
		end
		if not table.find(pk.lineup, arg) or not stillRunner(pk.c, arg) then
			return
		end
		if now() < (state:GetAttribute("StageAt") or 0) + HC.PICK_OPENS_AT then
			return -- still on the intro / rush
		end
		pk.hover = arg
		state:SetAttribute("Hover", arg)
		if kind == "pick" then
			pk.picked = arg
		end
	elseif kind == "choose" then
		if pk.stage ~= "PICKED" or plr.UserId ~= pk.picked or (arg ~= "HERO" and arg ~= "CHICKEN") then
			return
		end
		if now() < (state:GetAttribute("StageAt") or 0) + TM.PUSH_IN then
			return
		end
		pk.choice = arg
	end
end

-- ===== beat a + b + c: the pick =====

function HeroChickenService.runPick(c: any): number?
	c.hc = nil
	if not HC.Enabled or c.logic.solo or c.abort then
		return nil
	end
	-- everyone forcibly lined up and frozen until the crossing (or the group's turn) starts
	local catcher = leadCatcher(c)
	local startSide = MatchLogic.sidesForWave(c.logic.wave + 1)
	local lineup = CrossingLineup.arrange(c, startSide, catcher, hooks)
	if #lineup < HC.MIN_RUNNERS or not catcher then
		return nil -- one Runner left: their Last Runner Standing moment plays instead
	end
	local pk = { c = c, catcherId = catcher.UserId, lineup = lineup, hover = nil, picked = nil, choice = nil, stage = "CHOOSING" }
	pick = pk
	state:SetAttribute("Wave", c.logic.wave + 1)
	state:SetAttribute("Catcher", catcher.UserId)
	state:SetAttribute("Lineup", HttpService:JSONEncode(lineup))
	state:SetAttribute("Hover", nil)
	state:SetAttribute("Picked", nil)
	state:SetAttribute("Choice", nil)
	state:SetAttribute("Hero", nil)

	-- a: CHOOSING (intro on the lead Catcher, rush to the line, then the spotlight hops)
	local t0 = now()
	setStage("CHOOSING", TM.PICK_WINDOW)
	CatcherGesture.consider(catcher) -- hand to the chin, head scanning the line
	local endsAt = t0 + TM.PICK_WINDOW
	if isBot(catcher) then
		local pickAt = t0 + rand(HC.Npc.PICK_AT)
		local nextHop = t0 + HC.PICK_OPENS_AT
		while now() < math.min(pickAt, endsAt) and not c.abort do
			if now() >= nextHop then
				local alive = {}
				for _, uid in ipairs(lineup) do
					if stillRunner(c, uid) and uid ~= pk.hover then
						table.insert(alive, uid)
					end
				end
				if #alive > 0 then
					pk.hover = alive[rng:NextInteger(1, #alive)]
					state:SetAttribute("Hover", pk.hover)
				end
				nextHop = now() + rand(HC.Npc.HOVER_EVERY)
			end
			task.wait(0.05)
		end
		pk.picked = pk.hover
		local fp = forced("HC_ForcePick")
		if fp == "LOCAL" then
			for _, uid in ipairs(lineup) do
				if not isBot(c.roster[uid]) then
					fp = uid
				end
			end
		end
		if type(fp) == "number" and table.find(lineup, fp) then
			pk.picked = fp
			state:SetAttribute("Hover", fp)
		end
	else
		waitUntil(c, endsAt, function()
			return pk.picked ~= nil or not catcher.Parent
		end)
	end
	if c.abort then
		pick = nil
		CatcherGesture.stopAll()
		CrossingLineup.releaseAll()
		clearAll()
		return nil
	end
	if not stillRunner(c, pk.picked) then
		pk.picked = if stillRunner(c, pk.hover) then pk.hover else nil
	end
	if not pk.picked then
		local alive = {}
		for _, uid in ipairs(lineup) do
			if stillRunner(c, uid) then
				table.insert(alive, uid)
			end
		end
		if #alive == 0 then
			pick = nil
			clearAll()
			return nil
		end
		pk.picked = alive[rng:NextInteger(1, #alive)]
	end
	local pickedId = pk.picked :: number
	local picker = c.roster[pk.catcherId]
	local timedOut = picker ~= nil and not isBot(picker) and now() >= endsAt - 0.05

	-- b: PICKED (push-in, name card, the picked Runner's two buttons)
	pk.stage = "PICKED"
	do
		local target = c.roster[pickedId]
		local troot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		CatcherGesture.point(catcher, troot and troot.Position) -- turn to them and point, held through the choice
	end
	state:SetAttribute("Hover", pickedId)
	state:SetAttribute("Picked", pickedId)
	local t1 = now()
	setStage("PICKED", TM.CHOICE_WINDOW)
	local runner = c.roster[pickedId]
	if runner and isBot(runner) then
		local chooseAt = t1 + TM.PUSH_IN + rand(HC.Npc.CHOOSE_AT)
		waitUntil(c, math.min(chooseAt, t1 + TM.CHOICE_WINDOW))
		pk.choice = if rng:NextNumber() < HC.Npc.HERO_CHANCE then "HERO" else "CHICKEN"
		local fc = forced("HC_ForceChoice")
		if fc == "HERO" or fc == "CHICKEN" then
			pk.choice = fc
		end
	else
		waitUntil(c, t1 + TM.CHOICE_WINDOW, function()
			return pk.choice ~= nil or not stillRunner(c, pickedId)
		end)
	end
	if c.abort then
		pick = nil
		CatcherGesture.stopAll()
		CrossingLineup.releaseAll()
		clearAll()
		return nil
	end
	local choice = if pk.choice == "HERO" and stillRunner(c, pickedId) then "HERO" else "CHICKEN"
	local choiceTimedOut = pk.choice == nil

	-- c: REVEAL + SWOOP + READY
	pk.stage = "REVEAL"
	CatcherGesture.stop(catcher) -- the choice is made: the lead Catcher lowers the point
	state:SetAttribute("Choice", choice)
	if choice == "HERO" then
		-- the Hero steps out of the row toward the field, so it reads that they go alone
		local actor = c.roster[pickedId]
		local root = actor and actor.Character and actor.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local look = root.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(1, 0, 0)
			CrossingLineup.freeze(actor, root.CFrame + flat * HC.Lineup.HERO_STEP)
		end
	end
	setStage("REVEAL", TM.REVEAL + TM.SWOOP)
	waitUntil(c, now() + TM.REVEAL + TM.SWOOP)
	setStage("READY", TM.READY)
	waitUntil(c, now() + TM.READY)
	pick = nil
	if not isBot(runner) or not isBot(picker) then
		Analytics.log("HeroChickenPick", {
			matchId = c.matchId,
			wave = c.logic.wave + 1,
			userId = if runner and not isBot(runner) then pickedId else nil,
			catcherId = if picker and not isBot(picker) then pk.catcherId else nil,
			catcherNpc = picker ~= nil and isBot(picker),
			runnerNpc = runner ~= nil and isBot(runner),
			choice = choice,
			pickTimedOut = timedOut,
			choiceTimedOut = choiceTimedOut,
			runners = #lineup,
		})
	end
	if c.abort then
		clearAll()
		return nil
	end
	if choice == "HERO" then
		state:SetAttribute("Hero", pickedId)
		c.hc = { heroId = pickedId, phase = "PENDING", rewarded = false, caught = false }
		return pickedId
	end
	clearAll()
	return nil
end

-- ===== the Hero run =====

function HeroChickenService.bind(h: any)
	hooks = h
	-- a match that ends (or aborts) while people are frozen on the line never leaves them anchored
	if h.onPlayerMatchEnd then
		h.onPlayerMatchEnd(function(plr: Player)
			CrossingLineup.unfreeze(plr)
		end)
	end
end

-- the match is over (MatchService results): nobody stays frozen, nothing stays on screen
function HeroChickenService.matchEnded(_c: any)
	pick = nil
	CatcherGesture.stopAll()
	CrossingLineup.releaseAll()
	setHeroRunActive(false)
	state:SetAttribute("HeroResult", nil)
	clearAll()
end

-- Phase -> CROSSING: let people go. A Hero run lets the Hero and the Catchers go (the Catchers after
-- MatchService's usual short delay) and keeps the group frozen on the line.
function HeroChickenService.crossingStarted(c: any)
	CatcherGesture.stopAll() -- the crossing is on: the lead Catcher drops the point
	local h = c.hc
	local heroRun = h ~= nil and h.phase == "PENDING"
	local held = {}
	for uid, actor in pairs(c.roster) do
		local p = c.logic:get(uid)
		if p and actor.Parent then
			if p.role == "CATCHER" then
				CrossingLineup.unfreeze(actor, true) -- still held until MatchService releases the Catchers
			elseif heroRun and uid ~= h.heroId and p.role == "RUNNER" and not p.disconnected then
				table.insert(held, actor) -- stays frozen
			else
				CrossingLineup.unfreeze(actor)
			end
		end
	end
	if not heroRun then
		return
	end
	h.phase = "HERO_RUN"
	h.startedAt = now()
	setHeroRunActive(true)
	h.held = held
	setStage("HERO_RUN", TM.HERO_MAX)
end

local function rollPiece(): string
	local total = 0
	for _, e in ipairs(HC.BONUS_ROLL) do
		total += e[2]
	end
	local r = rng:NextNumber() * total
	for _, e in ipairs(HC.BONUS_ROLL) do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return HC.BONUS_ROLL[1][1]
end

local function fxAll(c: any, payload: any)
	for _, actor in pairs(c.roster) do
		if not isBot(actor) and actor.Parent then
			fxRemote:FireClient(actor, payload)
		end
	end
end

-- watch the Hero (success or caught) in every phase until it's known
local function watchHero(c: any)
	local h = c.hc
	if h.rewarded or h.caught then
		return
	end
	local p = c.logic:get(h.heroId)
	if not p or p.disconnected then
		h.caught = true -- gone: nothing to pay
		return
	end
	if p.role == "RUNNER" and p.isSafeThisWave then
		h.rewarded = true
		c.hcRewards = c.hcRewards or {}
		local r = c.hcRewards[h.heroId] or { crossings = 0, pieces = {} }
		r.crossings += HC.HERO_CROSSING_MULT - 1
		local piece = rollPiece()
		table.insert(r.pieces, piece)
		c.hcRewards[h.heroId] = r
		p.heroBonusCrossings = (p.heroBonusCrossings or 0) + HC.HERO_CROSSING_MULT - 1 -- read by MatchLogic results
		fxAll(c, { kind = "heroCrossed", userId = h.heroId, points = HC.HERO_POINTS, piece = piece })
		Analytics.log("HeroChickenResult", { matchId = c.matchId, wave = c.logic.wave, userId = if isBot(c.roster[h.heroId]) then nil else h.heroId, result = "CROSSED", piece = piece, seconds = now() - (h.startedAt or now()) })
	elseif p.role ~= "RUNNER" then
		h.caught = true
		fxAll(c, { kind = "heroCaught", userId = h.heroId })
		Analytics.log("HeroChickenResult", { matchId = c.matchId, wave = c.logic.wave, userId = if isBot(c.roster[h.heroId]) then nil else h.heroId, result = "CAUGHT", seconds = now() - (h.startedAt or now()) })
	end
end

function HeroChickenService.step(c: any): number
	local h = c.hc
	if not h or h.phase == "PENDING" or h.phase == "DONE" then
		return 0
	end
	watchHero(c)
	local t = now()
	if h.phase == "HERO_RUN" then
		if h.rewarded or h.caught or t - h.startedAt >= TM.HERO_MAX then
			state:SetAttribute("HeroResult", if h.rewarded then "CROSSED" elseif h.caught then "CAUGHT" else "RUNNING")
			if hooks.lineUpCatchers then
				hooks.lineUpCatchers(c) -- back to the centre line, held, facing the group
			end
			for uid, actor in pairs(c.roster) do
				local p = c.logic:get(uid)
				if p and p.role == "CATCHER" and actor.Parent then
					CrossingLineup.freeze(actor)
				end
			end
			if h.rewarded then
				-- the Hero made it: everyone gets the HERO! cutscene first, then GET READY
				h.phase = "HERO_SUCCESS"
				h.successUntil = t + TM.SUCCESS
				setStage("HERO_SUCCESS", TM.SUCCESS)
			else
				h.phase = "GROUP_READY"
				h.readyUntil = t + TM.GROUP_READY
				setStage("GROUP_READY", TM.GROUP_READY)
			end
		end
	elseif h.phase == "HERO_SUCCESS" and t >= h.successUntil then
		h.phase = "GROUP_READY"
		h.readyUntil = t + TM.GROUP_READY
		setStage("GROUP_READY", TM.GROUP_READY)
	elseif h.phase == "GROUP_READY" and t >= h.readyUntil then
		h.phase = "GROUP_RUN"
		setHeroRunActive(false)
		for _, actor in ipairs(h.held) do
			if actor.Parent then
				CrossingLineup.unfreeze(actor)
			end
		end
		for uid, actor in pairs(c.roster) do
			local p = c.logic:get(uid)
			if p and p.role == "CATCHER" and actor.Parent then
				CrossingLineup.unfreeze(actor, true) -- released just below, after the usual delay
			end
		end
		c.logic.waveStartedAt = t -- the group gets the same start protection a crossing gives
		setStage("GROUP_RUN", 0)
		local waveNo = c.logic.wave
		task.delay(GameConfig.Timing.CATCHER_RELEASE_DELAY, function()
			if c.hc == h and c.logic.wave == waveNo and hooks.releaseCatchers then
				hooks.releaseCatchers(c)
			end
		end)
		return t - h.startedAt -- the group's clock starts now
	end
	return 0
end

function HeroChickenService.crossingEnded(c: any)
	local h = c.hc
	if h then
		h.phase = "DONE"
	end
	CrossingLineup.releaseAll()
	setHeroRunActive(false)
	c.hc = nil
	state:SetAttribute("HeroResult", nil)
	clearAll()
end

-- settlement: { crossings = extra crossings of Gold + XP, pieces = { "rare", ... } } or nil
function HeroChickenService.bonusFor(c: any, uid: number): any?
	return c.hcRewards and c.hcRewards[uid] or nil
end

-- is someone the Hero of the crossing running now (tag over their head, NPC brains)
function HeroChickenService.heroId(): number?
	return state:GetAttribute("Hero")
end

function HeroChickenService.init()
	state = ReplicatedStorage:FindFirstChild("EOS_HeroChicken") :: Configuration
	if not state then
		state = Instance.new("Configuration")
		state.Name = "EOS_HeroChicken"
		state.Parent = ReplicatedStorage
	end
	requestRemote = state:FindFirstChild("Request") :: RemoteEvent
	if not requestRemote then
		requestRemote = Instance.new("RemoteEvent")
		requestRemote.Name = "Request"
		requestRemote.Parent = state
	end
	fxRemote = state:FindFirstChild("Fx") :: RemoteEvent
	if not fxRemote then
		fxRemote = Instance.new("RemoteEvent")
		fxRemote.Name = "Fx"
		fxRemote.Parent = state
	end
	clearAll()
	setHeroRunActive(false)
	CrossingLineup.init()
	Analytics.KNOWN.HeroChickenPick = true
	Analytics.KNOWN.HeroChickenResult = true
	requestRemote.OnServerEvent:Connect(onRequest)
	fxRemote.OnServerEvent:Connect(function() end)
	Players.PlayerRemoving:Connect(function(plr)
		lastRequest[plr.UserId] = nil
	end)
end

return HeroChickenService
