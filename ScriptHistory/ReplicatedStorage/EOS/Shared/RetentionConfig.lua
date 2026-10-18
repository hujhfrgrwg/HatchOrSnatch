--!strict
-- RetentionConfig (HOS-RET-001): the welcome back gift, favorite prompt, event RSVP, starter pack and
-- waiting-round offer card. Lives in ReplicatedStorage.EOS.Shared (server and client both read it).
-- Notes: UI/Retention Prompts.md.

local RetentionConfig = {}

-- Daily gift for a RETURNING player (not on the first day): claimed with a button, once per UTC day.
RetentionConfig.GIFT = { gold = 250, gems = 2 }

-- Lobby prompts: one at a time, at least this many seconds apart, never mid-match.
RetentionConfig.GAP = 180
RetentionConfig.FIRST_DELAY = 6 -- seconds after spawning in the lobby before the first prompt
RetentionConfig.MIN_PHASE_LEFT = 12 -- skip an intermission that ends sooner than this

-- Roblox event to ask players to join ("Notify me"). Empty = no event prompt. Set the event id from the
-- Creator Hub event page. Each id is asked once per player, after their first finished match.
RetentionConfig.EVENT_ID = ""

-- Starter pack: shown once after the first pet (economy decision 33), then a real 48 h window.
-- OFF until Hunter sets contents and a Robux price (looks only, decision 32). productId = a developer
-- product; PurchaseService's ProcessReceipt must grant it before this is enabled.
RetentionConfig.STARTER = {
	enabled = false,
	productId = nil :: number?,
	robux = nil :: number?,
	hours = 48,
	items = { -- placeholders, shown in the card only
		{ icon = "gem", count = "x??", label = "Gems" },
		{ icon = "trail_rainbow", count = "", label = "Trail" },
		{ icon = "emote", count = "", label = "Emote" },
		{ icon = "case", count = "", label = "Egg Case" },
	},
}

-- Waiting-round card (bottom right, only while you wait out a crossing you aren't in). Game passes come
-- from EconomyConfig.PASSES by key; owned ones are skipped. The starter pack joins when it's enabled
-- and its window is open.
RetentionConfig.WAIT_OFFERS = {
	{ pass = "vip", icon = "crown", lines = { "+25% match XP", "VIP tag over your head", "Honored One emote" } },
	{ pass = "xp2x", icon = "star", lines = { "Double XP from", "every match,", "forever" } },
	{ starter = true, icon = "shop", title = "Starter pack", lines = { "One time only", "Trail, emote and", "an egg case" } },
}
RetentionConfig.WAIT_CYCLE = 8 -- seconds per offer
RetentionConfig.WAIT_PHASES = { ROLE_REVEAL = true, CROSSING = true, WAVE_END = true }

-- UTC day key, e.g. "2026-10-17"
function RetentionConfig.day(t: number?): string
	return os.date("!%Y-%m-%d", t or os.time()) :: string
end

-- unix time of the next UTC midnight
function RetentionConfig.nextDay(t: number?): number
	local now = t or os.time()
	return now - now % 86400 + 86400
end

return RetentionConfig
