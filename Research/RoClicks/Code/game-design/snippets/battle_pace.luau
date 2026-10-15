--!strict
-- Battle endings that don't drag: pace scale, surrender, one overtime.
-- Pure functions; call them from your battle step on the server.

local Pace = {}

-- Clock speeds up as either side collapses: {lossFraction, multiplier}
Pace.STEPS = { { 0.85, 2.0 }, { 0.60, 1.6 }, { 0.35, 1.3 } }
Pace.MARCH = 1.25

-- lossA / lossB: fraction of each side's peak strength already lost (0..1)
function Pace.scale(lossA: number, lossB: number, marching: boolean): number
	if marching then return Pace.MARCH end
	local worst = math.max(lossA, lossB)
	for _, s in ipairs(Pace.STEPS) do
		if worst >= s[1] then return s[2] end
	end
	return 1
end

-- Effective dt = real dt * player speed (1x/2x/5x) * pace scale
function Pace.step(dt: number, playerSpeed: number, lossA: number, lossB: number, marching: boolean): number
	return dt * playerSpeed * Pace.scale(lossA, lossB, marching)
end

-- Mop-up: switch every squad to "hunt nearest to me" when the enemy is low.
function Pace.mopUp(enemyAlive: number, enemyPeak: number): boolean
	return enemyAlive <= math.max(3, math.floor(enemyPeak * 0.20))
end

-- Surrender once the outcome is certain.
Pace.SURRENDER_AFTER = 15 -- seconds the condition must hold
export type SurrenderState = { since: number? }

function Pace.checkSurrender(st: SurrenderState, now: number, defAlive: number,
	defPeak: number, atkAlive: number): boolean
	local beaten = defAlive <= math.max(2, math.floor(defPeak * 0.10))
		and atkAlive >= defAlive * 4
	if not beaten then
		st.since = nil
		return false
	end
	local since = st.since or now
	st.since = since
	return now - since >= Pace.SURRENDER_AFTER
end

-- At time-out: a near-empty defence counts as surrender, not a loss.
function Pace.timeoutResult(defAlive: number, defPeak: number): "surrender" | "timeout"
	if defAlive <= math.max(2, math.floor(defPeak * 0.05)) then return "surrender" end
	return "timeout"
end

-- One overtime: clock nearly out, reinforcements still coming, defence halved.
Pace.OVERTIME = 90
function Pace.overtime(timeLeft: number, usedOvertime: boolean, reinforcementsLeft: number,
	defAlive: number, defPeak: number): number
	if usedOvertime or timeLeft > 5 then return 0 end
	if reinforcementsLeft > 0 and defAlive <= defPeak * 0.5 then return Pace.OVERTIME end
	return 0
end

return Pace
