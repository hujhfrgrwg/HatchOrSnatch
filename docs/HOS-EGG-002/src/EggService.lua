--!strict
-- EggService (HOS-EGG-002, 17 Oct 2026): the egg plan in the match and at the incubator. Rules: Shared.EggLogic,
-- numbers: Shared.EggConfig (ENABLED false = EggLadder and the old pieces exactly as before).
-- Hooks other code calls (one line each):
--   MatchService.tick (finish zone)  info = EggService.onSafe(c, uid, info)   charge, then the step at safety
--   MatchService settlement          EggService.settle(c, uid, s)             the shard + match time; no pieces
--   MatchService results payload     you.shard = EggService.shardOf(c, uid)
--   PointsService.award              EggService.onAward(c, actor, kind)      jukes (max 2 a crossing), revives
--   EconomyService.init              EggService.init(econHelpers)            remotes, watch, crossing hooks
-- No random chance in the match (17 Oct ~18:47): the meter lasts the match; each mark it passes (EggConfig.CHARGE.MARKS)
-- steps the egg up once at the next safety (attribute EOS_EggMarks = marks spent). A Hero who gets across alone adds
-- HERO_SUCCESS just before their step (read from
-- HeroChickenService's c.hc, no edit there). Snatches (Q4, 17 Oct): a catch is pending while the Runner is down; a revive cancels it, the Runner's
-- conversion makes it final. A Catcher keeps their best final snatch, capped one rarity above the egg they held
-- when caught (the starting Catcher: Epic). Remotes: ReplicatedStorage.EOS_Egg (Charged, Rolled, Stash to clients;
-- HatchIncubator, SetFocus, ClaimFirstPet from clients). Telemetry: EggCharged, ShardStep, ShardGranted,
-- IncubatorHatched, FocusChanged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EggConfig = require(Shared:WaitForChild("EggConfig"))
local EggLogic = require(Shared:WaitForChild("EggLogic"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Net = require(Shared:WaitForChild("Net"))
local IncubatorLogic = require(ServerScriptService.EOS.Core.IncubatorLogic)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local NpcService = require(script.Parent.NpcService)

local isBot = NpcService.isBot

local EggService = {}

local rng = Random.new()
local remotes: { [string]: RemoteEvent } = {}
local helpers: any = {} -- from EconomyService.init: { tryUpdate, toast, inMatch }
local started = false

function EggService.on(): boolean
	return EggConfig.ENABLED == true
end

-- ===== per-match state (on the match table c, so it dies with the match) =====
-- charge[uid] = EggLogic.Charge; held[uid] = the egg a Catcher held when caught / timed out (nil = starting Catcher);
-- pending[victim] = { hunter, rarity } while the victim is down; stash[uid] = best final snatch; snap[uid] = last
-- seen { role, carried }; shards[uid] = the end shard (after settle)
local function stateOf(c: any): any
	local st = c.egg
	if not st then
		st = { charge = {}, held = {}, pending = {}, stash = {}, snap = {}, shards = {}, capSent = {}, startedAt = os.clock() }
		c.egg = st
	end
	return st
end

local function chargeOf(st: any, uid: number): any
	local ch = st.charge[uid]
	if not ch then
		ch = EggLogic.newCharge()
		st.charge[uid] = ch
	end
	return ch
end

local function fire(name: string, plr: any, payload: any)
	local r = remotes[name]
	if r and plr and not isBot(plr) and plr.Parent then
		r:FireClient(plr, payload)
	end
end

local function fireMatch(c: any, name: string, payload: any)
	for _, actor in pairs(c.roster) do
		fire(name, actor, payload)
	end
end

local function setAttr(actor: any, key: string, value: any)
	if actor and not isBot(actor) and actor.Parent then
		actor:SetAttribute(key, value)
	end
end

local function userIdOrNil(c: any, uid: number): number?
	return if isBot(c.roster[uid]) then nil else uid
end

local function secondsPlayed(actor: any): number
	if not actor or isBot(actor) then
		return math.huge -- bots never get the new-player boost
	end
	local p = DataService.get(actor)
	return (p and p.stats and tonumber(p.stats.secondsPlayed)) or 0
end

-- ===== charge =====

local function charge(c: any, actor: any, source: string)
	local st = stateOf(c)
	local uid = actor.UserId
	local ch = chargeOf(st, uid)
	local added = EggLogic.addCharge(ch, source, EggLogic.isNewbie(secondsPlayed(actor)))
	if added <= 0 then
		return
	end
	setAttr(actor, "EOS_EggCharge", ch.charge)
	local p = c.logic:get(uid)
	fire("Charged", actor, { charge = ch.charge, added = added, source = source, rarity = p and EggLogic.rarityForLevel(p.currentCarriedTier) })
	Analytics.log("EggCharged", { matchId = c.matchId, wave = c.logic.wave, userId = userIdOrNil(c, uid), source = source, charge = ch.charge })
end

-- PointsService.award: a juke or a revive by a Runner still out in the field charges their egg
function EggService.onAward(c: any, actor: any, kind: string)
	if not EggService.on() or not c or not actor or (kind ~= "juke" and kind ~= "revive") then
		return
	end
	local p = c.logic:get(actor.UserId)
	if not p or p.role ~= "RUNNER" or p.isSafeThisWave then
		return
	end
	charge(c, actor, kind)
end

-- ===== the step at safety (no random chance) =====

-- MatchService.tick, right after MatchLogic:finishCrossing succeeded. info = { prevTier, newTier, shells, crossings }
-- (levels). Rewrites the carried egg like EggLadder did, so applyRole / RunnerEvolved / the HUD keep working.
function EggService.onSafe(c: any, uid: number, info: any): any
	if not EggService.on() then
		return require(script.Parent.EggLadder).onCrossed(c, uid, info)
	end
	if not info then
		return info
	end
	local p = c.logic:get(uid)
	if not p then
		return info
	end
	local st = stateOf(c)
	local actor = c.roster[uid]
	local hc = c.hc
	if hc and hc.heroId == uid and hc.phase == "HERO_RUN" and actor then
		charge(c, actor, "hero") -- the Hero got across alone: the meter fills before this roll
	end
	local ch = chargeOf(st, uid)
	local before = EggLogic.rarityForLevel(info.prevTier)
	local crossing = c.logic.wave
	local chargeAtRoll = ch.charge
	local after, guaranteed = EggLogic.safetyStep(before, ch) -- no random chance: a passed meter mark steps it once
	local level = EggLogic.levelFor(after)
	p.currentCarriedTier = level
	p.earnedRunnerTier = math.max(p.earnedRunnerTier, level)
	info.prevTier = EggLogic.levelFor(before)
	info.newTier = level
	info.rarity = after
	info.upgraded = after ~= before
	info.charge = chargeAtRoll
	info.guaranteed = guaranteed
	fireMatch(c, "Rolled", {
		userId = uid,
		slot = if isBot(actor) then actor.slot else nil,
		from = before,
		to = after,
		crossing = crossing,
		charge = chargeAtRoll,
		marks = ch.used,
		guaranteed = guaranteed, -- a meter mark gave this step ("Rolled" is the remote's old name)
		seconds = 0, -- no flicker: the step is shown as it is
	})
	if after ~= before then
		Analytics.log("ShardStep", { matchId = c.matchId, userId = userIdOrNil(c, uid), crossing = crossing, from = before, to = after, meter = chargeAtRoll, marked = guaranteed })
	end
	if guaranteed then -- the meter keeps filling toward the next mark
		setAttr(actor, "EOS_EggMarks", ch.used)
	end
	return info
end

-- ===== snatches (10 Hz watch of the roster) =====

local function finalize(c: any, victim: number)
	local st = stateOf(c)
	local pend = st.pending[victim]
	if not pend then
		return
	end
	st.pending[victim] = nil
	local best = EggLogic.bestOf(st.stash[pend.hunter], pend.rarity)
	if best ~= st.stash[pend.hunter] then
		st.stash[pend.hunter] = best
		local hunter = c.roster[pend.hunter]
		setAttr(hunter, "EOS_EggStash", best)
		fire("Stash", hunter, { rarity = best })
	end
end

local function watch(c: any)
	local st = stateOf(c)
	for uid, actor in pairs(c.roster) do
		local p = c.logic:get(uid)
		if p then
			local was = st.snap[uid]
			if was then
				if p.role == "CAUGHT" and was.role == "RUNNER" then
					-- caught: the egg they carried is pending for the Catcher, capped by what the Catcher held
					local carried = EggLogic.rarityForLevel(was.carried)
					st.held[uid] = carried
					if p.capturedBy and c.roster[p.capturedBy] then
						local cap = EggLogic.snatchCap(st.held[p.capturedBy])
						st.pending[uid] = { hunter = p.capturedBy, rarity = EggLogic.creditSnatch(carried, cap) }
					end
				elseif p.role == "RUNNER" and was.role == "CAUGHT" then
					-- revived (Q4): the snatch is cancelled and the Runner keeps their egg
					st.pending[uid] = nil
					st.held[uid] = nil
				elseif p.role == "CATCHER" and was.role == "CAUGHT" then
					finalize(c, uid)
				elseif p.role == "CATCHER" and was.role == "RUNNER" then
					st.held[uid] = EggLogic.rarityForLevel(was.carried) -- timed out: that egg is lost (Q2)
				end
			end
			st.snap[uid] = { role = p.role, carried = p.currentCarriedTier or (was and was.carried) or EggConfig.LEVEL.common }
			if p.role ~= "RUNNER" then -- the HUD card's "snatch up to" line
				local cap = EggLogic.snatchCap(st.held[uid])
				if st.capSent[uid] ~= cap then
					st.capSent[uid] = cap
					setAttr(actor, "EOS_EggCap", cap)
				end
			end
		end
	end
end

EggService._watch = watch -- EggTests drives the watch without a playtest
EggService._finalize = finalize

local function onCrossing(c: any, event: string, _wave: number)
	if not EggService.on() then
		return
	end
	local st = stateOf(c)
	if event == "start" then
		if c.logic.wave <= 1 then -- a new match: the HUD card's attributes start clean
			for _, actor in pairs(c.roster) do
				setAttr(actor, "EOS_EggCharge", 0)
				setAttr(actor, "EOS_EggMarks", 0)
				setAttr(actor, "EOS_EggStash", nil)
				setAttr(actor, "EOS_EggCap", nil)
			end
		end
		-- a new crossing: the juke count restarts; the meter keeps its charge for the whole match
		for _, ch in pairs(st.charge) do
			EggLogic.newCrossing(ch)
		end
	elseif event == "match" then
		watch(c)
		for victim in pairs(st.pending) do
			finalize(c, victim) -- still down when the match ended: the snatch stands
		end
	end
end

EggService._onCrossing = onCrossing

-- ===== settlement =====

-- the end shard for one player (computeResults must have run; cached per match)
function EggService.shardOf(c: any, uid: number): string?
	if not EggService.on() or not c or not c.logic.results then
		return nil
	end
	local st = stateOf(c)
	if st.shards[uid] ~= nil then
		return st.shards[uid] or nil
	end
	local r = c.logic.results.perPlayer[uid]
	local p = c.logic:get(uid)
	local shard = nil
	if r and p and not p.disconnected then
		shard = EggLogic.shardFor({
			eligible = r.eligible,
			survived = r.survived and p.role == "RUNNER",
			held = EggLogic.rarityForLevel(p.currentCarriedTier),
			snatched = st.stash[uid],
		})
	end
	st.shards[uid] = shard or false
	return shard
end

-- MatchService settlement, before DataService.settle: the shard and the match time replace the piece
function EggService.settle(c: any, uid: number, s: any)
	if not EggService.on() or not s then
		return
	end
	local st = stateOf(c)
	s.material = nil
	s.bonusMaterials = nil -- the Hero bonus piece roll is removed (the Hero charges the egg instead)
	s.shard = EggService.shardOf(c, uid)
	s.seconds = math.floor(os.clock() - st.startedAt)
	if s.shard then
		local p = c.logic:get(uid)
		Analytics.log("ShardGranted", { matchId = c.matchId, userId = uid, rarity = s.shard, role = if p and p.role == "RUNNER" then "RUNNER" else "CATCHER", matchCrossings = c.logic.wave })
	end
end

-- ===== the incubator (lobby) =====

local WORDS = {
	NOT_READY = "Your egg isn't full yet",
	NO_PET = "No pet of that kind yet: try Any",
	LOCKED = "That family's pets are coming soon",
	BAD_FAMILY = "That family isn't available yet",
	NOT_YET = "Win your first egg in a match first",
	CLAIMED = "You already picked your first pet",
	NOT_LOADED = "Your save is still loading",
}

local function allow(plr: Player): boolean
	local MatchService = require(script.Parent.MatchService)
	return MatchService.limiter:allow(plr.UserId, "RequestHatch", os.clock())
end

local function lobbyOnly(plr: Player): boolean
	if plr:GetAttribute("EOS_InMatch") == true then
		helpers.toast(plr, "Hatch at the incubator between matches", "info")
		return false
	end
	return true
end

-- the Lucky Egg pass (EggConfig.LUCKY_PASS; gamePassId 0 = off): ownership checked once on join and on a finished
-- purchase, cached; every MarketplaceService call in a pcall. The attribute EOS_LuckyEgg lets the screen show the
-- same odds the hatch rolls.
local MarketplaceService = game:GetService("MarketplaceService")
local lucky: { [number]: boolean } = {}

local function setLucky(plr: Player, on: boolean)
	lucky[plr.UserId] = on
	if plr.Parent then
		plr:SetAttribute("EOS_LuckyEgg", on or nil)
	end
end

local function checkLucky(plr: Player)
	local id = EggConfig.LUCKY_PASS.gamePassId
	if not id or id == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, id)
	end)
	if ok then
		setLucky(plr, owns == true)
	end
end

function EggService.isLucky(plr: Player): boolean
	return lucky[plr.UserId] == true
end
EggService._setLucky = setLucky -- test hook (EggTests / playtests force the pass without a purchase)

-- the hatch boost ladder (EggConfig.HATCH_BOOST; product ids 0 = off). Roblox allows one ProcessReceipt per game:
-- PurchaseService calls this first for every receipt (a one-line hook) and uses our answer when it isn't nil.
-- Granted only after the save (DataService.commit), once per purchase id (the incubator's receipt ledger).
local function boostTierOf(productId: number): number?
	local P = EggConfig.HATCH_BOOST.products
	for tier, key in ipairs({ "x2", "x3", "x4" }) do
		if P[key] and P[key] ~= 0 and P[key] == productId then
			return tier
		end
	end
	return nil
end

function EggService.processReceipt(info: any, plr: Player): Enum.ProductPurchaseDecision?
	local tier = info and boostTierOf(info.ProductId)
	if not tier then
		return nil -- not ours
	end
	local receipt = tostring(info.PurchaseId)
	local isNew = false
	local saved = DataService.commit(plr, "receipt:" .. receipt, function(p)
		if IncubatorLogic.grantBoost(p, tier, receipt) then
			isNew = true
		end
	end)
	if not saved then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries; the ledger stops a second grant
	end
	if isNew then
		Analytics.log("HatchBoostBought", { userId = plr.UserId, tier = tier, mult = EggConfig.HATCH_BOOST.mults[tier], robux = info.CurrencySpent, purchaseId = receipt })
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function royal(plr: Player): boolean
	local p = DataService.get(plr)
	return p ~= nil and p.cosmetics.owned.hatch_royal == true
end

local function onHatch(plr: Player)
	if not EggService.on() or not allow(plr) or not lobbyOnly(plr) then
		return
	end
	-- rolled once, here, so every replay of the change hatches the same pet
	local rolls = { rarity = rng:NextNumber(), family = rng:NextNumber(), species = rng:NextNumber(), lucky = EggService.isLucky(plr) }
	local infoOut: any = nil
	local ok, res = helpers.tryUpdate(plr, "eggHatch", function(p)
		local good, reason, pet, info = IncubatorLogic.hatch(p, EconomyConfig, rolls)
		if not good then
			return false, reason
		end
		infoOut = info
		return true, pet
	end)
	if not ok then
		Net.event("HatchResult"):FireClient(plr, { ok = false, reason = res, incubator = true })
		helpers.toast(plr, WORDS[res] or "Can't hatch right now", "warn")
		return
	end
	Net.event("HatchResult"):FireClient(plr, { ok = true, pet = res, royal = royal(plr), incubator = true, egg = infoOut })
	if infoOut and infoOut.focusRefunded then
		helpers.toast(plr, ("Focus refunded: +%g FILL in your next egg"):format(infoOut.refund), "info")
	end
	Analytics.log("IncubatorHatched", { userId = plr.UserId, rarity = res.rarity, family = res.family, focused = infoOut and infoOut.focused, fillUsed = infoOut and infoOut.fillUsed, fillAtHatch = infoOut and infoOut.fillAtHatch, lucky = rolls.lucky, boostTier = infoOut and infoOut.boostTier, duplicate = infoOut and infoOut.duplicate })
	Analytics.log("PetCrafted", { userId = plr.UserId, speciesId = res.species, abilityFamily = res.family, rarity = res.rarity, randomFlag = not (infoOut and infoOut.focused) })
end

local function onSetFocus(plr: Player, focus: any)
	if not EggService.on() or not allow(plr) then
		return
	end
	if type(focus) ~= "string" or #focus > 24 then
		return
	end
	local ok, why = helpers.tryUpdate(plr, "eggFocus", function(p)
		return IncubatorLogic.setFocus(p, focus, EconomyConfig)
	end)
	if not ok then
		if why ~= "SAME" then
			helpers.toast(plr, WORDS[why] or "Can't change the focus right now", "warn")
		end
		return
	end
	Analytics.log("FocusChanged", { userId = plr.UserId, focus = focus })
end

local function onClaimFirst(plr: Player, family: any)
	if not EggService.on() or not allow(plr) or not lobbyOnly(plr) then
		return
	end
	if type(family) ~= "string" or #family > 24 then
		return
	end
	local ok, res = helpers.tryUpdate(plr, "eggFirstPet", function(p)
		local good, reason, pet = IncubatorLogic.claimFirstPet(p, family, EconomyConfig)
		if not good then
			return false, reason
		end
		return true, pet
	end)
	if not ok then
		helpers.toast(plr, WORDS[res] or "Can't do that right now", "warn")
		return
	end
	Net.event("HatchResult"):FireClient(plr, { ok = true, pet = res, royal = royal(plr), firstPet = true })
	Analytics.log("PetCrafted", { userId = plr.UserId, speciesId = res.species, abilityFamily = res.family, rarity = res.rarity, randomFlag = false })
end

-- ===== init (EconomyService.init) =====
-- h = { tryUpdate = (plr, label, fn) -> (ok, info), toast = (plr, text, kind) -> () }
function EggService.init(h: any)
	if started then
		return
	end
	started = true
	helpers = h or {}
	for _, name in ipairs({ "EggCharged", "ShardStep", "ShardGranted", "IncubatorHatched", "FocusChanged", "HatchBoostBought" }) do
		Analytics.KNOWN[name] = true
	end
	local f = Instance.new("Folder")
	f.Name = "EOS_Egg"
	for _, name in ipairs({ "Charged", "Rolled", "Stash", "HatchIncubator", "SetFocus", "ClaimFirstPet" }) do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = f
		remotes[name] = r
	end
	f.Parent = ReplicatedStorage
	remotes.HatchIncubator.OnServerEvent:Connect(onHatch)
	remotes.SetFocus.OnServerEvent:Connect(onSetFocus)
	require(script.Parent.CharacterService).onEggBuilt(require(script.Parent.EggShardBack).dress) -- the carried egg shows as a back shard (approved 17 Oct)
	remotes.ClaimFirstPet.OnServerEvent:Connect(onClaimFirst)
	local Players = game:GetService("Players")
	for _, plr in Players:GetPlayers() do
		task.spawn(checkLucky, plr)
	end
	Players.PlayerAdded:Connect(function(plr)
		task.spawn(checkLucky, plr)
	end)
	Players.PlayerRemoving:Connect(function(plr)
		lucky[plr.UserId] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, id, purchased)
		if purchased and id == EggConfig.LUCKY_PASS.gamePassId and id ~= 0 then
			setLucky(plr, true)
		end
	end)
	local MatchService = require(script.Parent.MatchService)
	MatchService.onCrossing(onCrossing)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local c = MatchService.current()
		if c and EggService.on() then
			watch(c)
		end
	end)
end

return EggService
