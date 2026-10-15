--!nonstrict
-- Monotonic onboarding funnel with fill-in, client validation and a Studio dry run.
-- Server ModuleScript. Store `data.onb` (highest step logged) and
-- `data.onbLegacy` in the player's save; `getData(player)` must return that table.

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Funnel = {}

-- One entry per step, in order. `client = true` = only the client can see it.
local STEPS = {
	{ id = "joined",        label = "Joined first time" },
	{ id = "intro_start",   label = "Intro started",              client = true },
	{ id = "intro_end",     label = "Intro finished or skipped",  client = true },
	{ id = "card_shown",    label = "Tutorial card shown",        client = true },
	{ id = "collected",     label = "Collected" },
	{ id = "sell_opened",   label = "Opened Sell",                client = true },
	{ id = "sold",          label = "Sold" },
	-- ... one row per sub-action ...
	{ id = "done",          label = "Tutorial completed" },
}
local INDEX = {}
for i, s in ipairs(STEPS) do INDEX[s.id] = i end

local IS_STUDIO = RunService:IsStudio()
local dryRun = {} -- bounded record of what would have been sent
local function record(kind, ...)
	if #dryRun >= 200 then table.remove(dryRun, 1) end
	table.insert(dryRun, { kind, ... })
end
function Funnel.debugSnapshot() return table.clone(dryRun) end

Funnel.getData = function(_player) return nil end -- replace with your save lookup

local function send(player, n)
	local s = STEPS[n]
	if IS_STUDIO then
		record("Onboarding", n, s.label)
	else
		pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, n, s.label)
	end
end

-- Log step `id`. Server calls fill in skipped earlier steps; client calls
-- must be exactly the next step.
function Funnel.step(player, id, fromClient)
	local data = Funnel.getData(player)
	local n = INDEX[id]
	if not data or not n or data.onbLegacy then return false end
	local last = data.onb or 0
	if n <= last then return false end           -- once per player, ever
	if fromClient and n ~= last + 1 then return false end
	for k = last + 1, n do send(player, k) end   -- fill-in keeps it monotonic
	data.onb = n
	return true
end

-- Call on load. Fresh saves start the funnel; old mid-tutorial saves freeze.
function Funnel.playerLoaded(player, isFreshSave, tutorialDone, hadOldFunnel)
	local data = Funnel.getData(player)
	if not data or tutorialDone then return end
	if not isFreshSave and (data.onb == nil) and hadOldFunnel then
		data.onbLegacy = true -- old numbering: never mix it with the new one
		return
	end
	if isFreshSave then
		data.onb = 0
		Funnel.step(player, "joined", false)
	end
end

-- Client remote: allow-list, tutorial active, next step only, rate limited.
local CLIENT_OK = {}
for _, s in ipairs(STEPS) do if s.client then CLIENT_OK[s.id] = true end end
local lastCalls = {} -- player -> {t1, t2, t3}

function Funnel.onClient(player, id, isTutorialActive)
	if typeof(id) ~= "string" or not CLIENT_OK[id] then
		if IS_STUDIO then record("Rejected", id) end
		return
	end
	if not isTutorialActive then return end
	local now, calls = os.clock(), lastCalls[player] or {}
	if #calls >= 3 and now - calls[1] < 1 then return end -- 3 calls/s
	table.insert(calls, now)
	if #calls > 3 then table.remove(calls, 1) end
	lastCalls[player] = calls
	if not Funnel.step(player, id, true) and IS_STUDIO then record("Rejected", id) end
end

function Funnel.playerRemoving(player) lastCalls[player] = nil end

-- Per-join session funnel and custom events
function Funnel.session(player, sessionId, step, label, isRejoin)
	local fields = { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = isRejoin and "Rejoin" or "New player" }
	if IS_STUDIO then
		record("Session", step, label)
		return
	end
	pcall(AnalyticsService.LogFunnelStepEvent, AnalyticsService, player, "TutorialSession", sessionId, step, label, fields)
end

function Funnel.event(player, name, value, field1)
	local fields = field1 and { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = field1 } or nil
	if IS_STUDIO then
		record("Custom", name, value, field1)
		return
	end
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value, fields)
end

return Funnel
