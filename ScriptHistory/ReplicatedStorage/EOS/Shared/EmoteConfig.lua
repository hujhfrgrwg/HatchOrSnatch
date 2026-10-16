--!strict
-- EmoteConfig: the Emote Crate (one emote per opening) and the emotes in it. Shared by the server
-- (rolls, refunds, wheel) and the client (cards, odds, wheel, music). Odds never change with ownership.
-- Clips: ReplicatedStorage.EOS_Emotes[<id>] (R6 KeyframeSequences from Workspace["52+ Emotes (R15/R6)"],
-- which includes the "20+ R6 Emotes" pack; HOS-EMOTE-001, 16 Oct). The game is R6 only.
-- animId "" = unpublished: Studio plays the local KeyframeSequence; a live server needs the clip
-- published to the group that owns the place and its id pasted here.
-- once = true: plays one time, then the emote ends (the rest loop until you move).
-- Music: Roblox licensed library tracks (usable in any experience); emotes without one play silently.
-- Names: Fortnite / TF2 / real-artist names are swapped for our own (Take the L -> Loser Dance, etc.).

local EmoteConfig = {}

EmoteConfig.LIBRARY = "EOS_Emotes"
EmoteConfig.CRATE_GEMS = 250
EmoteConfig.MUSIC_VOLUME = 0.55
EmoteConfig.MUSIC_RANGE = 70 -- studs: other players hear your song when they're near you
EmoteConfig.WHEEL_SLOTS = 6

-- per-emote odds in percent: 16 x 2.875 + 16 x 2 + 12 x 1.25 + 7 x 1 = 100
EmoteConfig.RARITY = {
	common = { name = "COMMON", odds = 2.875, ramp = "grey", order = 1, color = Color3.fromRGB(170, 178, 190) },
	rare = { name = "RARE", odds = 2, ramp = "blue", order = 2, color = Color3.fromRGB(80, 160, 255) },
	epic = { name = "EPIC", odds = 1.25, ramp = "purple", order = 3, color = Color3.fromRGB(178, 96, 255) },
	legendary = { name = "LEGENDARY", odds = 1, ramp = "yellow", order = 4, color = Color3.fromRGB(255, 196, 40) },
}

-- a duplicate refunds Gems by rarity
EmoteConfig.DUPE_REFUND = { common = 10, rare = 20, epic = 40, legendary = 75 }

-- Robux openings: hidden until each has a developer product id (nothing pretends an OFF system works)
EmoteConfig.ROBUX = {
	{ key = "x1", count = 1, robux = 149, productId = nil :: number? },
	{ key = "x3", count = 3, robux = 499, productId = nil :: number? },
	{ key = "x10", count = 10, robux = 1399, productId = nil :: number? },
}

EmoteConfig.LIST = {
	-- Common: poses, gestures, simple dances
	{ id = "idle_sit", name = "Chill Sit", rarity = "common", animId = "" },
	{ id = "anime_pose", name = "Anime Pose", rarity = "common", animId = "" },
	{ id = "t_pose", name = "T-Pose", rarity = "common", animId = "" },
	{ id = "thumbs_up", name = "Thumbs Up", rarity = "common", animId = "" },
	{ id = "loser_dance", name = "Loser Dance", rarity = "common", animId = "" },
	{ id = "snappy_skip", name = "Snappy Skipping", rarity = "common", animId = "", music = 9041926464, song = "Clap Your Hands And Smile" },
	{ id = "idle_dance", name = "Idle Dance", rarity = "common", animId = "", music = 1835566917, song = "Soul Dancefloor" },
	{ id = "shuffle", name = "Shuffle", rarity = "common", animId = "", music = 1847785490, song = "Cyber Gym" },
	{ id = "trick_or_treat", name = "Trick or Treat", rarity = "common", animId = "", once = true },
	{ id = "sunbath", name = "Sunbath", rarity = "common", animId = "" },
	{ id = "couch_nap", name = "Couch Nap", rarity = "common", animId = "" },
	{ id = "toilet_sit", name = "Toilet Sit", rarity = "common", animId = "" },
	{ id = "dramatic_bow", name = "Dramatic Bow", rarity = "common", animId = "", once = true },
	{ id = "candy_dance", name = "Candy Dance", rarity = "common", animId = "" },
	{ id = "neko_dance", name = "Neko Dance", rarity = "common", animId = "" },
	{ id = "beatbox", name = "Beatbox", rarity = "common", animId = "" },
	-- Rare
	{ id = "cossack_kick", name = "Cossack Kick", rarity = "rare", animId = "" },
	{ id = "boogie_down", name = "Boogie Down", rarity = "rare", animId = "" },
	{ id = "orange_sway", name = "Orange Sway", rarity = "rare", animId = "" },
	{ id = "company_dance", name = "Company Dance", rarity = "rare", animId = "" },
	{ id = "surfer", name = "Surfer", rarity = "rare", animId = "" },
	{ id = "ice_cream_cart", name = "Ice Cream Cart", rarity = "rare", animId = "" },
	{ id = "parrot_wiggle", name = "Parrot Wiggle", rarity = "rare", animId = "" },
	{ id = "head_juggle", name = "Head Juggle", rarity = "rare", animId = "" },
	{ id = "zombie_dance", name = "Zombie Dance", rarity = "rare", animId = "" },
	{ id = "wavy_grooves", name = "Wavy Grooves", rarity = "rare", animId = "", music = 1835567922, song = "Explosive Groove" },
	{ id = "moongazer", name = "Moongazer", rarity = "rare", animId = "", music = 1837664271, song = "Moonwalk" },
	{ id = "cat_dance", name = "Cat Dance", rarity = "rare", animId = "", music = 1837664412, song = "The Jitters" },
	{ id = "wibbly_wobbly", name = "Wibbly Wobbly", rarity = "rare", animId = "", music = 1846912778, song = "Dubstep Orange" },
	{ id = "skeleton", name = "Skeleton", rarity = "rare", animId = "", music = 1837467234, song = "Trick or Treat" },
	{ id = "jumpstyle", name = "Jumpstyle", rarity = "rare", animId = "", music = 9044578281, song = "Free to Rave" },
	{ id = "electro_shuffle", name = "Electro Shuffle", rarity = "rare", animId = "", music = 1842601749, song = "Commodore Love" },
	-- Epic
	{ id = "gambler_dance", name = "Gambler Dance", rarity = "epic", animId = "" },
	{ id = "breakdance", name = "Breakdance", rarity = "epic", animId = "" },
	{ id = "star_emote", name = "Star Power", rarity = "epic", animId = "" },
	{ id = "coconut_launch", name = "Coconut Launch", rarity = "epic", animId = "" },
	{ id = "dap_up", name = "Dap Up", rarity = "epic", animId = "" },
	{ id = "threaten", name = "Threaten", rarity = "epic", animId = "", once = true },
	{ id = "lose_it", name = "Lose It", rarity = "epic", animId = "", once = true },
	{ id = "skeleton_grooves", name = "Skeleton Grooves", rarity = "epic", animId = "" },
	{ id = "marat", name = "Marat", rarity = "epic", animId = "", music = 1839906498, song = "Eurodance" },
	{ id = "kpop_dance", name = "K-Pop Dance", rarity = "epic", animId = "", music = 9042057040, song = "I Cannot Get Enough" },
	{ id = "flexer", name = "Flexer", rarity = "epic", animId = "", music = 1843461844, song = "Night Sweats" },
	{ id = "rap_bounce", name = "Rap Bounce", rarity = "epic", animId = "", music = 1843462242, song = "Brass Knuckles" },
	-- Legendary
	{ id = "honored_one", name = "Honored One", rarity = "legendary", animId = "" },
	{ id = "shadow_emerge", name = "Shadow Emerge", rarity = "legendary", animId = "", once = true },
	{ id = "shadow_step", name = "Shadow Step", rarity = "legendary", animId = "" },
	{ id = "reapers_ride", name = "Reaper's Ride", rarity = "legendary", animId = "" },
	{ id = "floating_meditation", name = "Floating Meditation", rarity = "legendary", animId = "" },
	{ id = "blossom_break", name = "Blossom Break", rarity = "legendary", animId = "" },
	{ id = "e_dance", name = "E Dance Supreme", rarity = "legendary", animId = "", music = 9042017853, song = "Accelerator" },
}

local byId = {}
for i, e in ipairs(EmoteConfig.LIST) do
	e.order = i
	byId[e.id] = e
end

function EmoteConfig.get(id: any): any
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function EmoteConfig.odds(e: any): number
	return EmoteConfig.RARITY[e.rarity].odds
end

-- weighted roll; r = a number in [0, 1)
function EmoteConfig.roll(r: number): string
	local total = 0
	for _, e in ipairs(EmoteConfig.LIST) do
		total += EmoteConfig.odds(e)
	end
	local x = r * total
	for _, e in ipairs(EmoteConfig.LIST) do
		x -= EmoteConfig.odds(e)
		if x < 0 then
			return e.id
		end
	end
	return EmoteConfig.LIST[#EmoteConfig.LIST].id
end

-- a saved wheel, cleaned: WHEEL_SLOTS entries, each an owned emote id or "" (no duplicates)
function EmoteConfig.cleanWheel(wheel: any, owned: any): { string }
	local out, seen = {}, {}
	for i = 1, EmoteConfig.WHEEL_SLOTS do
		local id = type(wheel) == "table" and wheel[i] or nil
		if type(id) == "string" and byId[id] and type(owned) == "table" and owned[id] == true and not seen[id] then
			out[i] = id
			seen[id] = true
		else
			out[i] = ""
		end
	end
	return out
end

return EmoteConfig
