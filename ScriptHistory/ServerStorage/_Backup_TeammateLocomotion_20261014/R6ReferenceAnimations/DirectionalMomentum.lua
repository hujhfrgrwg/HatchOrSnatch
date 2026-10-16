-- World-space momentum. A held direction gains speed; turns redirect existing velocity.
local Momentum = {}
local function approach(current, target, amount)
	local delta = target - current
	return delta.Magnitude <= amount and target or current + delta.Unit * amount
end

function Momentum.Step(velocity, wish, grounded, dt, config)
	local magnitude = math.min(wish.Magnitude, 1)
	local target = magnitude > 0.001 and wish.Unit * config.TopSpeed * magnitude or Vector3.zero
	local acceleration = grounded and config.Acceleration or config.AirAcceleration
	if grounded and magnitude > 0.001 and velocity.Magnitude > 0.5
		and velocity.Unit:Dot(wish.Unit) < 0.7 then
		acceleration *= 2.5 -- Redirect promptly while retaining a visible arc/reversal slowdown.
	end
	if magnitude < 0.001 then acceleration = grounded and config.Braking or config.AirBraking end
	return approach(velocity, target, acceleration * math.min(dt, 0.1))
end

return Momentum