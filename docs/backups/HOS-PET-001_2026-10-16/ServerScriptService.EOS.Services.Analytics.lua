--!strict
-- Analytics: TEST_PLAN section E event log. Keeps the last N events in memory, prints them in
-- Studio, and forwards to an optional sink (plug a real analytics platform in via setSink).
-- Never logs secrets or chat; fields are ids, roles, waves and timings only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Analytics = {}

local MAX = 400
local buffer: { any } = {}
local counts: { [string]: number } = {}
local sink: ((any) -> ())? = nil
local warnedAt: { [string]: number } = {}

Analytics.KNOWN = {
	PlayerMatchQueued = true, MatchStarted = true, StartingHunterAssigned = true,
	WaveStarted = true, RunnerFinishedWave = true, RunnerTimeout = true, RunnerCaptured = true,
	RoleConverted = true, HighestSecuredTierChanged = true, MatchEnded = true, RewardGranted = true,
	DuplicateGrantPrevented = true, QuestProgressed = true, QuestClaimed = true, AFKToggled = true,
	MatchQuit = true, SessionEnd = true, PersistenceError = true, RemoteValidationRejected = true,
	UnexpectedStateRecovery = true, RunnerEvolved = true, SessionStart = true,
	-- GDD v0.4 appendix E
	GoldSource = true, GoldSink = true, GemsSource = true, GemsSink = true, PieceAwarded = true,
	PetCrafted = true, FocusUsed = true, AbilityUsed = true, CosmeticUsed = true, WaveEnded = true,
}

function Analytics.setSink(fn: ((any) -> ())?)
	sink = fn
end

local function deviceOf(userId: number?): string?
	if not userId then
		return nil
	end
	local plr = Players:GetPlayerByUserId(userId)
	return plr and plr:GetAttribute("EOS_Device") or nil
end

function Analytics.log(name: string, fields: { [string]: any }?)
	local e: { [string]: any } = {}
	for k, v in pairs(fields or {}) do
		e[k] = v
	end
	e.name = name
	e.t = os.time()
	if e.userId and not e.device then
		e.device = deviceOf(e.userId)
	end
	if not Analytics.KNOWN[name] then
		e.unknownEvent = true
	end
	table.insert(buffer, e)
	if #buffer > MAX then
		table.remove(buffer, 1)
	end
	counts[name] = (counts[name] or 0) + 1
	if RunService:IsStudio() and workspace:GetAttribute("EOS_VerboseAnalytics") then
		print("[EOS-A]", name, game:GetService("HttpService"):JSONEncode(e))
	end
	if sink then
		task.spawn(pcall, sink, e)
	end
end

-- Rate-limited warning (one per key per 10 s) + an analytics event.
function Analytics.warn(name: string, key: string, msg: string, fields: { [string]: any }?)
	local now = os.clock()
	if not warnedAt[key] or now - warnedAt[key] > 10 then
		warnedAt[key] = now
		warn("[EOS] " .. msg)
	end
	Analytics.log(name, fields)
end

function Analytics.recent(n: number?, filter: string?): { any }
	local out = {}
	for i = #buffer, 1, -1 do
		local e = buffer[i]
		if not filter or e.name == filter then
			table.insert(out, e)
			if #out >= (n or 50) then
				break
			end
		end
	end
	return out
end

function Analytics.counts(): { [string]: number }
	return table.clone(counts)
end

return Analytics
