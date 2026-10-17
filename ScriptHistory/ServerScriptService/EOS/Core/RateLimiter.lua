--!strict
-- RateLimiter: sliding-window counter per (player, remote). Pure; time is passed in.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(limits: { [string]: { max: number, window: number } })
	local self = setmetatable({}, RateLimiter)
	self.limits = limits
	self.buckets = {} :: { [string]: { number } }
	return self
end

-- Returns true when the call is allowed (and records it).
function RateLimiter:allow(userId: number, remote: string, now: number): boolean
	local lim = self.limits[remote]
	if not lim then
		return true
	end
	local key = tostring(userId) .. "|" .. remote
	local b = self.buckets[key]
	if not b then
		b = {}
		self.buckets[key] = b
	end
	-- drop timestamps outside the window
	local cutoff = now - lim.window
	local keep = {}
	for _, t in ipairs(b) do
		if t > cutoff then
			table.insert(keep, t)
		end
	end
	if #keep >= lim.max then
		self.buckets[key] = keep
		return false
	end
	table.insert(keep, now)
	self.buckets[key] = keep
	return true
end

function RateLimiter:forget(userId: number)
	local prefix = tostring(userId) .. "|"
	for k in pairs(self.buckets) do
		if string.sub(k, 1, #prefix) == prefix then
			self.buckets[k] = nil
		end
	end
end

return RateLimiter
