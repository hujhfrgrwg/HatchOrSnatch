--!strict
-- SpinWheelConfig (HOS-SPIN-001, 18 Oct 2026, Matthew): the lobby spin wheel's 8 slots, odds, free spin and spin packs.
-- Slot 1 is the top sector under the crystal; the rest go clockwise as you face the wheel (Workspace.SpinWheel.Wheel.
-- Sectors.Sector_<n>). Only the weapon slot is orange. Weights are relative (they add to 100 here, so weight = % chance).
--
-- kinds:
--   weapon  weaponId = a knife skin item id (EconomyConfig.item): won = owned and equipped; a duplicate gives Weapon
--           Shards like a crate. mystery = the wheel shows a dark knife with a "?" instead of saying which.
--           (nil weaponId would pay fallbackGold, but then the slot lands on a weapon and pays Gold: keep one set.)
--   gold / gems   amount
--   shard   rarity ("common" | "rare" | "epic" | "legendary"): one egg shard into the incubator, flies in at the lobby
--           incubator like a match shard
local C = {}

C.FREE_SECONDS = 15 * 60 -- one free spin, then the next one after this long
C.SPIN_TIME = 4.2 -- seconds the wheel turns (UI and world); the server won't take another spin from you before then
C.MULTI = { 1, 5, 10 } -- the spin buttons

local ORANGE = Color3.fromRGB(255, 150, 30)
local PURPLE = Color3.fromRGB(150, 70, 230)
local DEEP = Color3.fromRGB(80, 40, 130)
local DARK = Color3.fromRGB(40, 32, 58)

C.SLOTS = {
	-- placeholder weapon until Matthew picks it (18 Oct): the All Hallow's Sword, so what it lands on is what you get
	{ kind = "weapon", weaponId = "knife_rb_all_hallow_s_sword", mystery = true, fallbackGold = 1000, weight = 1, color = ORANGE },
	{ kind = "gold", amount = 250, weight = 20, color = PURPLE },
	{ kind = "shard", rarity = "common", weight = 17, color = DEEP },
	{ kind = "gems", amount = 3, weight = 15, color = DARK },
	{ kind = "gold", amount = 500, weight = 12, color = PURPLE },
	{ kind = "shard", rarity = "rare", weight = 9, color = DEEP },
	{ kind = "gems", amount = 10, weight = 6, color = DARK },
	{ kind = "gold", amount = 100, weight = 20, color = PURPLE },
}

-- Robux spin packs. productId nil = not on sale yet (the buttons say so). Matthew/Hunter create the developer products.
C.PACKS = {
	{ spins = 1, robux = 49, productId = nil :: number? },
	{ spins = 10, robux = 349, productId = nil :: number? },
	{ spins = 100, robux = 2900, productId = nil :: number? },
}

C.ICONS = {
	weapon = "rbxassetid://114397729012864", -- placeholder knife until the weapon is picked
	gold = "rbxassetid://97477413390638",
	gems = "rbxassetid://111102563440206",
	common = "rbxassetid://76372701778308",
	rare = "rbxassetid://82457245446958",
	epic = "rbxassetid://78444144417389",
	legendary = "rbxassetid://78444144417389",
}

function C.totalWeight(): number
	local t = 0
	for _, s in C.SLOTS do t += s.weight end
	return t
end

-- r in [0, 1) -> slot index
function C.roll(r: number): number
	local x = r * C.totalWeight()
	for i, s in C.SLOTS do
		x -= s.weight
		if x < 0 then return i end
	end
	return #C.SLOTS
end

function C.chance(i: number): number
	return C.SLOTS[i].weight / C.totalWeight()
end

function C.icon(s: any): string
	if s.kind == "shard" then return C.ICONS[s.rarity] or C.ICONS.common end
	return C.ICONS[s.kind] or ""
end

-- the short text on the wheel ("250", "WEAPON", "Rare")
function C.short(s: any): string
	if s.kind == "weapon" then return "WEAPON" end
	if s.kind == "shard" then return (s.rarity:gsub("^%l", string.upper)) end
	return tostring(s.amount)
end

-- the full name ("250 Gold", "Rare egg shard", "Mystery weapon")
function C.name(s: any, econ: any?): string
	if s.kind == "weapon" then
		local item = s.weaponId and econ and econ.item(s.weaponId)
		return if item then item.name else "Mystery weapon"
	end
	if s.kind == "shard" then return (s.rarity:gsub("^%l", string.upper)) .. " egg shard" end
	return s.amount .. (if s.kind == "gold" then " Gold" else " Gems")
end

-- rarest first (the wheel lands on the best of a multi-spin)
function C.best(list: { number }): number
	local best = list[1]
	for _, i in list do
		if C.SLOTS[i].weight < C.SLOTS[best].weight then best = i end
	end
	return best
end

return C
