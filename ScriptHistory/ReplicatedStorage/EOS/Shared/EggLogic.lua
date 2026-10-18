--!strict
-- EggLogic (HOS-EGG-002, 17 Oct 2026): the egg plan's pure rules. No Instances, no services, no yields; every
-- random draw is passed in (r in [0, 1)) so tests are deterministic. Numbers: Shared.EggConfig.
-- Used by EggService (match: meter, step at safety, snatch cap, shard), ProfileLogic (incubator: shards, odds, hatch,
-- focus, migration) and EggUIController (shown odds / fill). Tests: EggLogic.spec (jest-lua syntax, run under Lune).

local EggLogic = {}

local Config: any = nil
if script ~= nil then -- in Roblox; under Lune the test runner calls EggLogic.setConfig
	Config = require((script :: any).Parent:WaitForChild("EggConfig"))
end

function EggLogic.setConfig(cfg: any)
	Config = cfg
end

function EggLogic.config(): any
	return Config
end

-- ===== rarities =====

function EggLogic.rarityIndex(rarity: string?): number
	return (rarity and table.find(Config.RARITIES, rarity)) or 1
end

function EggLogic.rarityAt(index: number): string
	return Config.RARITIES[math.clamp(math.floor(index), 1, #Config.RARITIES)]
end

function EggLogic.isRarity(rarity: any): boolean
	return type(rarity) == "string" and table.find(Config.RARITIES, rarity) ~= nil
end

-- TierConfig look level <-> rarity (levels between groups round down, like PointsConfig.rarityForLevel)
function EggLogic.rarityForLevel(level: number?): string
	local lv = level or 1
	local best = "common"
	for _, r in ipairs(Config.RARITIES) do
		if lv >= Config.LEVEL[r] then
			best = r
		end
	end
	return best
end

function EggLogic.levelFor(rarity: string): number
	return Config.LEVEL[rarity] or Config.LEVEL.common
end

-- ===== the shard meter (one per player per match; no random chance) =====
-- charge fills toward CHARGE.CAP and lasts the match; jukes = jukes counted this crossing; used = marks spent

export type Charge = { charge: number, jukes: number, used: number }

function EggLogic.newCharge(): Charge
	return { charge = 0, jukes = 0, used = 0 }
end

-- newbie = the player is inside their first NEWBIE_HOURS of match time (their meter fills x NEWBIE_MULT)
function EggLogic.isNewbie(secondsPlayed: number?): boolean
	return (secondsPlayed or 0) < Config.CHARGE.NEWBIE_HOURS * 3600
end

-- source: "juke" | "revive" | "hero". Returns the charge actually added (0 = nothing changed).
function EggLogic.addCharge(st: Charge, source: string, newbie: boolean?): number
	local C = Config.CHARGE
	local before = st.charge
	local amount
	if source == "juke" then
		if st.jukes >= C.JUKE_MAX_PER_CROSSING then
			return 0
		end
		st.jukes += 1
		amount = C.JUKE
	elseif source == "revive" then
		amount = C.REVIVE
	elseif source == "hero" then
		amount = C.HERO_SUCCESS
	else
		return 0
	end
	st.charge = math.min(C.CAP, st.charge + amount * (if newbie then C.NEWBIE_MULT else 1))
	return st.charge - before
end

-- a new crossing: the juke count restarts; the meter keeps its charge
function EggLogic.newCrossing(st: Charge)
	st.jukes = 0
end

-- how many marks the meter has passed (0 .. #MARKS)
function EggLogic.marksPassed(st: Charge): number
	local n = 0
	for _, at in ipairs(Config.CHARGE.MARKS) do
		if st.charge >= at - 1e-9 then
			n += 1
		end
	end
	return n
end

-- the next mark to reach (index into MARKS / MARK_RARITY), or nil when every mark is spent
function EggLogic.nextMark(st: Charge): number?
	local i = (st.used or 0) + 1
	return if Config.CHARGE.MARKS[i] then i else nil
end

-- a passed mark is waiting for the next safety (the HUD's "Next safe: EPIC")
function EggLogic.markReady(st: Charge): boolean
	return EggLogic.marksPassed(st) > (st.used or 0)
end

-- the one-rarity step a mark gives (nil: Common, which crossing 1 already upgrades, or Legendary)
function EggLogic.guaranteedStep(rarity: string): string?
	if rarity == "rare" then
		return "epic"
	elseif rarity == "epic" then
		return "legendary"
	end
	return nil
end

-- the step at a safety: a Common egg becomes Rare (crossing 1); otherwise a passed, unspent mark steps the egg up once
-- and is spent. One step per safety, so two marks passed in one crossing step over two safeties. Returns
-- (new rarity, marked) where marked = a meter mark gave this step.
function EggLogic.safetyStep(rarity: string, st: Charge): (string, boolean)
	if rarity == "common" then
		return "rare", false
	end
	local step = EggLogic.guaranteedStep(rarity)
	if step and EggLogic.markReady(st) then
		st.used = (st.used or 0) + 1
		return step, true
	end
	return rarity, false
end

-- ===== snatching =====

-- the best rarity a Catcher may snatch: one step above the egg they held when caught (or timed out);
-- heldRarity nil = the starting Catcher (never held one this match)
function EggLogic.snatchCap(heldRarity: string?): string
	if heldRarity == nil then
		return Config.SNATCH.STARTING_CATCHER_CAP
	end
	return EggLogic.rarityAt(EggLogic.rarityIndex(heldRarity) + Config.SNATCH.STEP)
end

-- what a snatch of `stolen` is credited as for a Catcher capped at `cap`
function EggLogic.creditSnatch(stolen: string, cap: string): string
	return EggLogic.rarityAt(math.min(EggLogic.rarityIndex(stolen), EggLogic.rarityIndex(cap)))
end

-- keep only the best snatched egg
function EggLogic.bestOf(a: string?, b: string?): string?
	if a == nil then
		return b
	elseif b == nil then
		return a
	end
	return if EggLogic.rarityIndex(b) > EggLogic.rarityIndex(a) then b else a
end

-- ===== the end-of-match shard =====
-- o = { eligible, survived (still a Runner at the end), held = rarity carried, snatched = best snatch or nil }
function EggLogic.shardFor(o: any): string?
	if not o or not o.eligible then
		return nil
	end
	if o.survived and EggLogic.isRarity(o.held) then
		return o.held
	end
	if EggLogic.isRarity(o.snatched) then
		return o.snatched
	end
	return nil
end

-- ===== the incubator egg =====

-- fill = this egg (0 .. FILL x MAX_MULT); carry = fill past the cap, waiting for the next egg; shards = counts (display);
-- boost = the hatch boost tier bought for this egg (0 = none, 1..#HATCH_BOOST.mults); boostReceipts = recent purchase ids
export type Incubator = { fill: number, carry: number, shards: { [string]: number }, focus: string, hatched: number, boost: number, boostReceipts: { string } }

function EggLogic.newIncubator(): Incubator
	return { fill = 0, carry = 0, shards = { common = 0, rare = 0, epic = 0, legendary = 0 }, focus = Config.ANY, hatched = 0, boost = 0, boostReceipts = {} }
end

-- repairs a saved incubator in place (bad types, NaN, unknown focus); returns it
function EggLogic.sanitize(inc: any): Incubator
	if type(inc) ~= "table" then
		return EggLogic.newIncubator()
	end
	local function num(v: any): number
		return if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then math.max(0, v) else 0
	end
	inc.fill = num(inc.fill)
	inc.carry = num(inc.carry)
	if type(inc.shards) ~= "table" then
		inc.shards = {}
	end
	for _, r in ipairs(Config.RARITIES) do
		inc.shards[r] = math.floor(num(inc.shards[r]))
	end
	if not (inc.focus == Config.ANY or table.find(Config.FAMILIES, inc.focus)) then
		inc.focus = Config.ANY
	end
	inc.hatched = math.floor(num(inc.hatched))
	inc.boost = math.clamp(math.floor(num(inc.boost)), 0, #Config.HATCH_BOOST.mults)
	local receipts = {}
	if type(inc.boostReceipts) == "table" then
		for _, r in ipairs(inc.boostReceipts) do
			if type(r) == "string" then
				table.insert(receipts, r)
			end
		end
	end
	inc.boostReceipts = receipts
	return inc
end

function EggLogic.isFocused(inc: Incubator): boolean
	return inc.focus ~= Config.ANY
end

-- the most the egg holds (200%)
function EggLogic.fillCap(): number
	local I = Config.INCUBATOR
	return I.FILL * I.MAX_MULT
end

-- what a focus spends at hatch (0 for Any)
function EggLogic.focusCost(inc: Incubator): number
	local I = Config.INCUBATOR
	return if EggLogic.isFocused(inc) then I.FILL * I.FOCUS_COST else 0
end

-- the fill the egg can hatch at: 100% plus the focus cost
function EggLogic.fillNeeded(inc: Incubator): number
	return Config.INCUBATOR.FILL + EggLogic.focusCost(inc)
end

function EggLogic.isReady(inc: Incubator): boolean
	return inc.fill >= EggLogic.fillNeeded(inc) - 1e-9
end

-- the fill the odds are read from (after the focus cost), as a share of FILL (1 = 100%)
function EggLogic.oddsLevel(inc: Incubator): number
	return math.max(0, inc.fill - EggLogic.focusCost(inc)) / Config.INCUBATOR.FILL
end

-- fill into the egg up to the cap; the rest waits in carry for the next egg. Returns the fill added to this egg
function EggLogic.addFill(inc: Incubator, amount: number): number
	local room = math.max(0, EggLogic.fillCap() - inc.fill)
	local add = math.min(room, amount)
	inc.fill += add
	inc.carry = (inc.carry or 0) + (amount - add)
	return add
end

-- one shard into the egg. Returns its fill (SHARD_WEIGHT; some may wait in carry when the egg is at its cap)
function EggLogic.addShard(inc: Incubator, rarity: string): number
	if not EggLogic.isRarity(rarity) then
		return 0
	end
	local w = Config.SHARD_WEIGHT[rarity]
	EggLogic.addFill(inc, w)
	inc.shards[rarity] = (inc.shards[rarity] or 0) + 1
	return w
end

-- the odds at a fill level (1 = 100%): linear between the ODDS points, clamped to the first and last
function EggLogic.oddsAt(level: number): { rare: number, epic: number, legendary: number }
	local pts = Config.INCUBATOR.ODDS
	local a, b = pts[1], pts[#pts]
	if level <= a.at then
		b = a
	elseif level >= b.at then
		a = b
	else
		for i = 1, #pts - 1 do
			if level >= pts[i].at and level <= pts[i + 1].at then
				a, b = pts[i], pts[i + 1]
				break
			end
		end
	end
	local t = if b.at > a.at then (level - a.at) / (b.at - a.at) else 0
	local epic = a.epic + (b.epic - a.epic) * t
	local legendary = a.legendary + (b.legendary - a.legendary) * t
	return { rare = math.max(0, 1 - epic - legendary), epic = epic, legendary = legendary }
end

-- the hatch odds shown on the egg (and rolled): read from the egg's fill now (below 100%: the 100% odds, what the
-- first hatch would give). legendaryOpen = a Legendary pet exists for this focus (Q1): when false, Legendary's
-- chance goes to Epic. Returns { rare, epic, legendary } summing to 1.
function EggLogic.incubatorOdds(inc: Incubator, legendaryOpen: boolean): { rare: number, epic: number, legendary: number }
	local o = EggLogic.oddsAt(EggLogic.oddsLevel(inc))
	local epic, legendary = o.epic, o.legendary
	if not legendaryOpen then
		epic += legendary
		legendary = 0
	end
	return { rare = math.max(0, 1 - epic - legendary), epic = epic, legendary = legendary }
end

-- the Lucky Egg pass: Epic and Legendary x their multipliers, Rare takes the rest (never below 0). The server applies
-- it at hatch and the screen to what it shows, so the shown odds are the rolled odds.
function EggLogic.applyLuck(odds: { rare: number, epic: number, legendary: number }, lucky: boolean?): { rare: number, epic: number, legendary: number }
	if not lucky then
		return odds
	end
	local L = Config.LUCKY_PASS
	local epic, legendary = odds.epic * L.epicMult, odds.legendary * L.legendaryMult
	local over = math.max(0, epic + legendary - 1)
	epic -= over -- never more than 100% in total (only reachable with extreme multipliers)
	return { rare = math.max(0, 1 - epic - legendary), epic = epic, legendary = legendary }
end

-- a hatch boost tier (1..#mults): Epic and Legendary x the tier's multiplier
function EggLogic.applyBoost(odds: { rare: number, epic: number, legendary: number }, tier: number?): { rare: number, epic: number, legendary: number }
	local m = Config.HATCH_BOOST.mults[tier or 0]
	if not m then
		return odds
	end
	return { rare = odds.rare, epic = odds.epic * m, legendary = odds.legendary * m }
end

-- after every multiplier: Legendary at most HATCH_BOOST.legendaryCap, Epic at most what's left, Rare the rest
function EggLogic.capOdds(odds: { rare: number, epic: number, legendary: number }): { rare: number, epic: number, legendary: number }
	local legendary = math.min(odds.legendary, Config.HATCH_BOOST.legendaryCap)
	local epic = math.min(odds.epic, 1 - legendary)
	return { rare = math.max(0, 1 - epic - legendary), epic = epic, legendary = legendary }
end

-- the odds a hatch rolls (and the screen shows): overfill odds -> Lucky Egg pass -> the egg's boost tier -> the cap
function EggLogic.hatchOdds(inc: any, legendaryOpen: boolean, lucky: boolean?): { rare: number, epic: number, legendary: number }
	return EggLogic.capOdds(EggLogic.applyBoost(EggLogic.applyLuck(EggLogic.incubatorOdds(inc, legendaryOpen), lucky), inc.boost))
end

-- a bought boost tier (receipt handler only): once per purchase id (Roblox retries receipts); never lowers the tier.
-- Returns true when this purchase is new
function EggLogic.grantBoost(inc: Incubator, tier: number, receipt: string, ledgerSize: number?): boolean
	if table.find(inc.boostReceipts, receipt) then
		return false
	end
	table.insert(inc.boostReceipts, receipt)
	while #inc.boostReceipts > (ledgerSize or 50) do
		table.remove(inc.boostReceipts, 1)
	end
	inc.boost = math.max(inc.boost or 0, math.clamp(math.floor(tier), 0, #Config.HATCH_BOOST.mults))
	return true
end

-- the hatched rarity from the odds: r in [0, 1)
function EggLogic.hatchRoll(odds: { rare: number, epic: number, legendary: number }, r: number): string
	if r < odds.legendary then
		return "legendary"
	elseif r < odds.legendary + odds.epic then
		return "epic"
	end
	return "rare"
end

-- after a hatch: the whole egg is spent (its overfill bought the odds); the next egg starts from carry (up to the
-- cap); shard counts reset; focus stays. Returns the fill the hatch spent
function EggLogic.consumeHatch(inc: Incubator): number
	local spent = inc.fill
	local carry = inc.carry or 0
	inc.fill = 0
	inc.carry = 0
	EggLogic.addFill(inc, carry)
	for _, r in ipairs(Config.RARITIES) do
		inc.shards[r] = 0
	end
	inc.boost = 0 -- a boost is for one hatch
	inc.hatched += 1
	return spent
end

-- the family: the focus, or (Any) one of `open` (families with a pet of the rolled rarity), picked by r
function EggLogic.pickFamily(focus: string, open: { string }, r: number): string?
	if focus ~= Config.ANY then
		return if table.find(open, focus) then focus else nil
	end
	if #open == 0 then
		return nil
	end
	return open[math.clamp(math.floor(r * #open) + 1, 1, #open)]
end

-- the species: one the player doesn't own in this family and rarity first; otherwise a duplicate (raises its
-- level). speciesList = the family's species of that rarity; owned = { [species] = true }. Returns (species, dup).
function EggLogic.pickSpecies(speciesList: { string }, owned: { [string]: boolean }, r: number): (string?, boolean)
	if #speciesList == 0 then
		return nil, false
	end
	local fresh = {}
	for _, s in ipairs(speciesList) do
		if not owned[s] then
			table.insert(fresh, s)
		end
	end
	local pool = if #fresh > 0 then fresh else speciesList
	local pick = pool[math.clamp(math.floor(r * #pool) + 1, 1, #pool)]
	return pick, #fresh == 0
end

-- ===== migration (ProfileLogic, flag incubatorV1) =====
-- old pieces -> fill at the shard weights; Epic and Legendary (crowned) pieces also count as shards for odds
function EggLogic.migratePieces(inc: Incubator, materials: any): number
	if type(materials) ~= "table" then
		return 0
	end
	local function n(k: string): number
		local v = materials[k]
		return if type(v) == "number" and v == v and v > 0 then math.floor(v) else 0
	end
	local W = Config.SHARD_WEIGHT
	local legendary = n("legendary") + n("crowned")
	local add = n("common") * W.common + n("rare") * W.rare + n("epic") * W.epic + legendary * W.legendary
	EggLogic.addFill(inc, add)
	inc.shards.epic += n("epic")
	inc.shards.legendary += legendary
	return add
end

return EggLogic
