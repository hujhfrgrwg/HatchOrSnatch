--!strict
-- QuestConfig: the daily quest pool. Two quests per UTC day, chosen deterministically from the
-- date so every server agrees. Progress only comes from settled match events (never from idling).

local QuestConfig = {}

QuestConfig.DAILY_COUNT = 2

export type QuestDef = {
	id: string,
	kind: string, -- groups similar quests so one day never gets two of the same kind
	metric: string, -- "crossings" | "captures" | "matches" | "secureTier"
	target: number,
	minTier: number?, -- for metric "secureTier": counts matches settled at >= this tier
	reward: number, -- Shells
	title: string,
}

QuestConfig.Pool = {
	{ id = "cross1", kind = "cross", metric = "crossings", target = 1, reward = 15, title = "Complete 1 crossing" },
	{ id = "cross3", kind = "cross", metric = "crossings", target = 3, reward = 25, title = "Complete 3 crossings" },
	{ id = "capture1", kind = "capture", metric = "captures", target = 1, reward = 15, title = "Make 1 capture" },
	{ id = "capture3", kind = "capture", metric = "captures", target = 3, reward = 25, title = "Make 3 captures" },
	{ id = "match1", kind = "match", metric = "matches", target = 1, reward = 15, title = "Finish 1 match" },
	{ id = "match3", kind = "match", metric = "matches", target = 3, reward = 25, title = "Finish 3 matches" },
	{ id = "tier2", kind = "tier", metric = "secureTier", minTier = 2, target = 1, reward = 20, title = "Secure a Tier 2+ egg" },
	{ id = "tier3", kind = "tier", metric = "secureTier", minTier = 3, target = 1, reward = 30, title = "Secure a Tier 3+ egg" },
} :: { QuestDef }

local byId: { [string]: QuestDef } = {}
for _, q in ipairs(QuestConfig.Pool) do
	byId[q.id] = q
end

function QuestConfig.get(id: string): QuestDef?
	return byId[id]
end

-- small deterministic string hash (djb2), stable across servers and Luau versions
local function hash(s: string): number
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + string.byte(s, i)) % 2147483647
	end
	return h
end

-- The quest ids for a UTC date "YYYY-MM-DD": DAILY_COUNT quests of different kinds.
function QuestConfig.forDate(utcDate: string): { string }
	local pool = QuestConfig.Pool
	local picked: { string } = {}
	local usedKinds: { [string]: boolean } = {}
	local h = hash("eos-daily:" .. utcDate)
	local i = 0
	while #picked < QuestConfig.DAILY_COUNT and i < #pool * 4 do
		local q = pool[(h + i * 7) % #pool + 1]
		if not usedKinds[q.kind] then
			usedKinds[q.kind] = true
			table.insert(picked, q.id)
		end
		i += 1
	end
	return picked
end

return QuestConfig
