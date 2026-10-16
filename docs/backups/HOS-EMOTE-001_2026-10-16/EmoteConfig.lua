--!strict
-- EmoteConfig: the Emote Crate (one emote per opening) and the emotes in it. Shared by the server
-- (rolls, refunds) and the client (cards, odds, music). Odds never change with ownership.
-- Clips: ReplicatedStorage.EOS_Emotes[<id>] (KeyframeSequences from the "20+ R6 Emotes" rig).
-- animId "" = unpublished: Studio plays the local KeyframeSequence; a live server needs the clip
-- published to the group (Eggs with Friends) and its id pasted here.
-- Music: Roblox licensed library tracks (usable in any experience), picked to fit each dance.

local EmoteConfig = {}

EmoteConfig.LIBRARY = "EOS_Emotes"
EmoteConfig.CRATE_GEMS = 250
EmoteConfig.MUSIC_VOLUME = 0.55
EmoteConfig.MUSIC_RANGE = 70 -- studs: other players hear your song when they're near you

-- per-emote odds in percent (all tiers sum to 100)
EmoteConfig.RARITY = {
	common = { name = "COMMON", odds = 10, ramp = "grey", order = 1, color = Color3.fromRGB(170, 178, 190) },
	rare = { name = "RARE", odds = 5, ramp = "blue", order = 2, color = Color3.fromRGB(80, 160, 255) },
	epic = { name = "EPIC", odds = 4.5, ramp = "purple", order = 3, color = Color3.fromRGB(178, 96, 255) },
	legendary = { name = "LEGENDARY", odds = 3.25, ramp = "yellow", order = 4, color = Color3.fromRGB(255, 196, 40) },
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
	-- Common
	{ id = "snappy_skip", name = "Snappy Skipping", rarity = "common", animId = "", music = 9041926464, song = "Clap Your Hands And Smile" },
	{ id = "idle_dance", name = "Idle Dance", rarity = "common", animId = "", music = 1835566917, song = "Soul Dancefloor" },
	{ id = "shuffle", name = "Shuffle", rarity = "common", animId = "", music = 1847785490, song = "Cyber Gym" },
	{ id = "wavy_grooves", name = "Wavy Grooves", rarity = "common", animId = "", music = 1835567922, song = "Explosive Groove" },
	{ id = "moongazer", name = "Moongazer", rarity = "common", animId = "", music = 1837664271, song = "Moonwalk" },
	{ id = "cat_dance", name = "Cat Dance", rarity = "common", animId = "", music = 1837664412, song = "The Jitters" },
	-- Rare
	{ id = "skeleton", name = "Skeleton", rarity = "rare", animId = "", music = 1837467234, song = "Trick or Treat" },
	{ id = "electro_shuffle", name = "Electro Shuffle", rarity = "rare", animId = "", music = 1842601749, song = "Commodore Love" },
	{ id = "jumpstyle", name = "Jumpstyle", rarity = "rare", animId = "", music = 9044578281, song = "Free to Rave" },
	{ id = "wibbly_wobbly", name = "Wibbly Wobbly", rarity = "rare", animId = "", music = 1846912778, song = "Dubstep Orange" },
	-- Epic
	{ id = "marat", name = "Marat", rarity = "epic", animId = "", music = 1839906498, song = "Eurodance" },
	{ id = "kpop_dance", name = "K-Pop Dance", rarity = "epic", animId = "", music = 9042057040, song = "I Cannot Get Enough" },
	{ id = "flexer", name = "Flexer", rarity = "epic", animId = "", music = 1843461844, song = "Night Sweats" },
	-- Legendary
	{ id = "rap_bounce", name = "Rap Bounce", rarity = "legendary", animId = "", music = 1843462242, song = "Brass Knuckles" },
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

return EmoteConfig
