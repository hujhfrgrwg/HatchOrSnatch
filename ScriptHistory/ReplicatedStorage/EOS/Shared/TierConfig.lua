--!strict
-- TierConfig: egg levels, the Catcher cap and the level -> look mapping. The ONLY place level
-- numbers and egg colours live.
--
-- Oct 15 2026 (developer): crossings are open-ended, so the egg keeps levelling (no Level 4 top).
-- Looks come in five checkpoint groups (Common -> Rare -> Epic -> Legendary -> Cosmic). Inside a
-- group each level leans a little further toward the next group's colours, so every crossing
-- visibly changes the egg; the first level of a group snaps to that group's look. The carried egg
-- pops and swaps colour on every level-up (client Controllers/EggFX).
-- Rewards are NOT driven by these groups: EconomyConfig.materialForTier still decides the piece.

local TierConfig = {}

TierConfig.BASE_TIER = 1
TierConfig.MAX_CROSSINGS = 3 -- Studio solo test only: a fixed 3-crossing run
TierConfig.SURVIVOR_TIER_MAX = 99 -- level cap (in practice none: the 40-crossing safety cap ends a match first)
TierConfig.CATCHER_TIER_CAP = 3 -- steals clamp here (unchanged; the full-snatch rule is not built yet)

-- how far the LAST level of a group leans toward the next group's colours (0 = none, 1 = all the way)
TierConfig.BLEND_TOWARD_NEXT = 0.5

export type Group = {
	id: string,
	name: string,
	from: number, -- first level of the group
	shell: Color3,
	spot: Color3,
	text: Color3, -- UI accent
	spotNeon: boolean, -- spots glow
	light: number, -- PointLight brightness on the carried egg (0 = none)
	sparkle: number, -- sparkle particles per second on the carried egg (0 = none)
}

TierConfig.Groups = {
	{ id = "common", name = "Common", from = 1, shell = Color3.fromRGB(246, 246, 240), spot = Color3.fromRGB(84, 196, 104), text = Color3.fromRGB(236, 240, 226), spotNeon = false, light = 0, sparkle = 0 },
	{ id = "rare", name = "Rare", from = 3, shell = Color3.fromRGB(116, 194, 255), spot = Color3.fromRGB(26, 94, 214), text = Color3.fromRGB(130, 204, 255), spotNeon = false, light = 0, sparkle = 0 },
	{ id = "epic", name = "Epic", from = 5, shell = Color3.fromRGB(170, 104, 255), spot = Color3.fromRGB(255, 122, 216), text = Color3.fromRGB(206, 150, 255), spotNeon = true, light = 0, sparkle = 0 },
	{ id = "legendary", name = "Legendary", from = 7, shell = Color3.fromRGB(255, 196, 52), spot = Color3.fromRGB(255, 246, 200), text = Color3.fromRGB(255, 214, 90), spotNeon = true, light = 0.6, sparkle = 6 },
	{ id = "cosmic", name = "Cosmic", from = 10, shell = Color3.fromRGB(58, 34, 168), spot = Color3.fromRGB(120, 255, 240), text = Color3.fromRGB(140, 255, 240), spotNeon = true, light = 1.2, sparkle = 10 },
} :: { Group }

export type TierDef = {
	level: number,
	name: string, -- the group's name ("Common" ...)
	group: string, -- the group's id
	groupIndex: number,
	shell: Color3, -- main egg colour
	spot: Color3, -- spot colour
	text: Color3, -- UI accent text colour
	scale: number, -- size multiplier for the voxel showcase eggs (Shared/EggModel)
	glow: boolean, -- voxel showcase eggs: gold crown + glowing band
	spotNeon: boolean,
	light: number,
	sparkle: number,
}

function TierConfig.isValid(tier: any): boolean
	return type(tier) == "number" and tier == math.floor(tier) and tier >= TierConfig.BASE_TIER
		and tier <= TierConfig.SURVIVOR_TIER_MAX
end

function TierConfig.clamp(tier: number): number
	return math.clamp(math.floor(tier), TierConfig.BASE_TIER, TierConfig.SURVIVOR_TIER_MAX)
end

-- the tier a Catcher may secure from a stolen egg of `tier`
function TierConfig.clampStolen(tier: number): number
	return math.min(TierConfig.clamp(tier), TierConfig.CATCHER_TIER_CAP)
end

function TierConfig.groupIndexFor(level: number): number
	local gi = 1
	for i, g in ipairs(TierConfig.Groups) do
		if level >= g.from then
			gi = i
		end
	end
	return gi
end

local cache: { [number]: TierDef } = {}

function TierConfig.get(tier: number): TierDef
	local level = TierConfig.clamp(tier)
	local hit = cache[level]
	if hit then
		return hit
	end
	local gi = TierConfig.groupIndexFor(level)
	local g = TierConfig.Groups[gi]
	local n = TierConfig.Groups[gi + 1]
	local shell, spot, text = g.shell, g.spot, g.text
	local light, sparkle = g.light, g.sparkle
	if n then
		-- lean toward the next group; the last level of the group gets BLEND_TOWARD_NEXT
		local span = n.from - g.from
		local k = if span > 1 then (level - g.from) / (span - 1) * TierConfig.BLEND_TOWARD_NEXT else 0
		shell = g.shell:Lerp(n.shell, k)
		spot = g.spot:Lerp(n.spot, k)
		text = g.text:Lerp(n.text, k)
	else
		-- top group: every level past its first glows a little brighter (up to +5 levels)
		local extra = math.min(level - g.from, 5)
		light += extra * 0.2
		sparkle += extra * 3
	end
	local def: TierDef = {
		level = level,
		name = g.name,
		group = g.id,
		groupIndex = gi,
		shell = shell,
		spot = spot,
		text = text,
		scale = 1 + math.min(gi - 1, 4) * 0.08,
		glow = gi >= 4,
		spotNeon = g.spotNeon,
		light = light,
		sparkle = sparkle,
	}
	cache[level] = def
	return def
end

-- TierConfig.Tiers[level] still works (old call sites); any level is computed on demand
TierConfig.Tiers = setmetatable({}, {
	__index = function(_, k)
		if type(k) == "number" and k >= TierConfig.BASE_TIER and k <= TierConfig.SURVIVOR_TIER_MAX then
			return TierConfig.get(k)
		end
		return nil
	end,
}) :: any

function TierConfig.label(tier: number): string
	return "Level " .. tostring(TierConfig.clamp(tier))
end

function TierConfig.longLabel(tier: number): string
	local t = TierConfig.clamp(tier)
	return "Level " .. t .. " " .. TierConfig.get(t).name
end

-- Startup policy check
function TierConfig.validate(): { string }
	local problems = {}
	if TierConfig.CATCHER_TIER_CAP >= TierConfig.SURVIVOR_TIER_MAX then
		table.insert(problems, "CATCHER_TIER_CAP >= SURVIVOR_TIER_MAX")
	end
	if TierConfig.CATCHER_TIER_CAP < TierConfig.BASE_TIER then
		table.insert(problems, "CATCHER_TIER_CAP below BASE_TIER")
	end
	if TierConfig.Groups[1].from ~= TierConfig.BASE_TIER then
		table.insert(problems, "the first egg group must start at BASE_TIER")
	end
	for i = 2, #TierConfig.Groups do
		if TierConfig.Groups[i].from <= TierConfig.Groups[i - 1].from then
			table.insert(problems, "egg groups must start at increasing levels (" .. TierConfig.Groups[i].id .. ")")
		end
	end
	return problems
end

return TierConfig
