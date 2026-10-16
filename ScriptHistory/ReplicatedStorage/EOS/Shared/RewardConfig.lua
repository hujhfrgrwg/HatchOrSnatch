--!strict
-- RewardConfig: Shell (soft currency) payouts. TEST VALUES from GDD 8, not an economy commitment.

local RewardConfig = {}

RewardConfig.SHELLS_PER_CROSSING = 10
-- Shells for a Catcher's 1st, 2nd ... distinct captures in one match
RewardConfig.CAPTURE_SHELLS = { 10, 8 }
-- 3rd and later captures pay this each, but at most LATER_CAPTURE_CAP in total per match
RewardConfig.LATER_CAPTURE_SHELLS = 4
RewardConfig.LATER_CAPTURE_CAP = 10
-- qualified active participation in a completed match
RewardConfig.PARTICIPATION_SHELLS = 5

-- Shells for the n-th capture given what 3rd+ captures already paid this match.
-- Returns (shells, newLaterTotal).
function RewardConfig.captureShells(captureIndex: number, laterPaidSoFar: number): (number, number)
	local fixed = RewardConfig.CAPTURE_SHELLS[captureIndex]
	if fixed then
		return fixed, laterPaidSoFar
	end
	local room = math.max(0, RewardConfig.LATER_CAPTURE_CAP - laterPaidSoFar)
	local pay = math.min(RewardConfig.LATER_CAPTURE_SHELLS, room)
	return pay, laterPaidSoFar + pay
end

return RewardConfig
