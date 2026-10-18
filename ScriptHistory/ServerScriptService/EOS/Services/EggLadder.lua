--!strict
-- EggLadder (HOS-PTS-001, 17 Oct 2026): the carried egg climbs a rarity ladder instead of +1 level a crossing.
-- MatchService.tick calls onCrossed(c, uid, info) right after MatchLogic:finishCrossing succeeds; it may rewrite
-- info.prevTier / info.newTier (levels) before applyRole and RunnerEvolved use them. Numbers: PointsConfig.Ladder.
--   crossing 1: Common -> Rare always; 3: Rare -> Epic 10% or Legendary 2%; 5: Rare -> Epic 10%, Epic -> Legendary 1%;
--   crossings 2 and 4 add a small boost to the next roll. Levels are TierConfig look levels (Ladder.LEVEL).
-- Off (Ladder.Enabled false or PointsConfig.Enabled false): returns info untouched (the old +1 a crossing).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PointsConfig = require(Shared:WaitForChild("PointsConfig"))

local EggLadder = {}

local rng = Random.new()

function EggLadder.enabled(): boolean
	return PointsConfig.Enabled and PointsConfig.Ladder.Enabled
end

-- per match: uid -> { rarity, boost } (on the match table, so it dies with the match)
local function stateOf(c: any, uid: number): any
	c.ptsLadder = c.ptsLadder or {}
	local s = c.ptsLadder[uid]
	if not s then
		s = { rarity = "common", boost = 0 }
		c.ptsLadder[uid] = s
	end
	return s
end

-- the roll for one crossing: returns the new rarity (or the same one)
function EggLadder.roll(crossing: number, rarity: string, boost: number, r: number?): (string, number)
	local LD = PointsConfig.Ladder
	local steps = LD.STEPS[crossing]
	local nextBoost = boost + (LD.BOOST[crossing] or 0)
	if not steps then
		return rarity, nextBoost
	end
	local roll = r or rng:NextNumber()
	local acc = 0
	local applies = false
	for _, st in ipairs(steps) do
		if st.from == rarity then
			applies = true
			acc += math.min(1, st.chance * (1 + boost))
			if roll < acc then
				return st.to, 0
			end
		end
	end
	return rarity, if applies then 0 else nextBoost -- an upgrade roll uses the boost up, hit or miss
end

-- after MatchLogic:finishCrossing(uid) succeeded this tick. info = { prevTier, newTier, shells, crossings }
function EggLadder.onCrossed(c: any, uid: number, info: any): any
	if not EggLadder.enabled() or not info then
		return info
	end
	local p = c.logic:get(uid)
	if not p then
		return info
	end
	local LV = PointsConfig.Ladder.LEVEL
	local s = stateOf(c, uid)
	-- a revived or long-lived Runner: trust the egg they actually carry
	s.rarity = PointsConfig.rarityForLevel(info.prevTier)
	local before = s.rarity
	local crossing = c.logic.wave
	s.rarity, s.boost = EggLadder.roll(crossing, s.rarity, s.boost)
	local level = LV[s.rarity]
	p.currentCarriedTier = level
	p.earnedRunnerTier = math.max(p.earnedRunnerTier, level)
	info.prevTier = LV[before]
	info.newTier = level
	info.rarity = s.rarity
	info.upgraded = s.rarity ~= before
	return info
end

-- the rarity a level means (results, the leaderboard, snatch points)
function EggLadder.rarityOf(level: number?): string
	return PointsConfig.rarityForLevel(level)
end

return EggLadder
