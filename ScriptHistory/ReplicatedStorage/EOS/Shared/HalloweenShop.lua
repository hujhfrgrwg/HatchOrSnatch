--!strict
-- HalloweenShop (shared): the limited Halloween pets (Jack-o'-Lantern, Witch's Cat, Mummy; Bone Dragon from Oct 24) sold outright on the Shop's Featured page, HOS-HWN-001.
-- Hunter, 17 Oct: "Do the mummy and the cat and the wrath, with the wrath being legendary and the other two being
-- epic. Put them into archetypes. Buying these pets grants the ability." So a bought pet goes into p.pets exactly like
-- a hatched one (IncubatorLogic.addPet's record) and gives its family's ability; this is Hunter's exception to the
-- "Gems / Robux buy looks only" rule, for these three pets only.
--
-- Hooked in with one line each (originals in docs/backups/HOS-HWN-001_20261017/ORIGINAL_LINES.md):
--   EconomyConfig (end):              require(script.Parent.HalloweenShop).inject(EconomyConfig)
--   ProfileLogic.buy:                 if item.kind == "pet" and econ.buyPet then return econ.buyPet(p, item) end
--   ProfileLogic.grantItemPurchase:   if item.kind == "pet" and econ.grantPetPurchase then return econ.grantPetPurchase(p, item) end
-- inject() adds the pets to EconomyConfig.SHOP (kind "pet"), so PurchaseService maps the Wraith's developer product,
-- EconomyConfig.item finds them, and the shop's itemState sees cosmetics.owned[id] once bought.
-- Prices and the end date live here (change them here). The sale ends at ENDS_AT (UTC); a Robux receipt that arrives
-- later (Roblox retries) still grants the pet. Buyers keep their pets after the event.

local HalloweenShop = {}

HalloweenShop.ENDS_AT = 1793491200    -- 2026-11-01 00:00 UTC: the sale ends
HalloweenShop.ROTATE_AT = 1792800000  -- 2026-10-24 00:00 UTC: the Bone Dragon joins, the Witch's Cat leaves Featured
-- Featured order before / after ROTATE_AT (Hunter 17 Oct: "show mummy instead of witches cat in the shop")
HalloweenShop.FEATURED_BEFORE = { "hwn_wraith", "hwn_cat", "hwn_mummy" }
HalloweenShop.FEATURED_AFTER = { "hwn_dragon", "hwn_wraith", "hwn_mummy" }

-- pass 3 (17 Oct 15:40, Hunter): the Pumpkin Wraith became the Jack-o'-Lantern (same id, species id and product);
-- the Bone Dragon was added (Tempest, Legendary, Robux), on sale from ROTATE_AT. `from` / `to` = when it can be bought.
HalloweenShop.PETS = {
	{ id = "hwn_wraith", name = "Jack-o'-Lantern", species = "Pumpkin Wraith", family = "Invisibility", rarity = "legendary",
		wallet = "robux", price = 0, robux = 399, productId = 3719178740 :: number?, icon = "pet_jack_o_lantern_t1",
		desc = "Vanishes in a burst of embers.", color = Color3.fromRGB(255, 122, 26) },
	{ id = "hwn_cat", name = "Witch's Cat", species = "Witch's Cat", family = "Decoy", rarity = "epic",
		wallet = "gems", price = 250, robux = nil :: number?, productId = nil :: number?, icon = "pet_witch_cat_t1",
		desc = "Fake clones pop in cauldron smoke.", color = Color3.fromRGB(90, 255, 74), to = 1792800000 },
	{ id = "hwn_mummy", name = "Mummy", species = "Mummy", family = "Guardian", rarity = "epic",
		wallet = "gems", price = 250, robux = nil :: number?, productId = nil :: number?, icon = "pet_mummy_t1",
		desc = "A bandage shield whips round you.", color = Color3.fromRGB(80, 200, 255) },
	{ id = "hwn_dragon", name = "Bone Dragon", species = "Bone Dragon", family = "Tempest", rarity = "legendary",
		wallet = "robux", price = 0, robux = 399, productId = 3719243734 :: number?, icon = "pet_bone_dragon_t1",
		desc = "Bone shards blast, soul fire storms.", color = Color3.fromRGB(110, 255, 150), from = 1792800000 },
}

local byId: { [string]: any } = {}
for _, it in ipairs(HalloweenShop.PETS) do
	it.kind = "pet"
	byId[it.id] = it
end

function HalloweenShop.item(id: string): any?
	return byId[id]
end

-- the shop clock: os.time(), or in Studio only the workspace attribute HWN_TestTime (UTC epoch) to test the rotation
function HalloweenShop.now(): number
	local RunService = game:GetService("RunService")
	if RunService:IsStudio() then
		local t = workspace:GetAttribute("HWN_TestTime")
		if type(t) == "number" then
			return t
		end
	end
	return os.time()
end

function HalloweenShop.onSale(now: number?): boolean
	return (now or HalloweenShop.now()) < HalloweenShop.ENDS_AT
end

-- this pet can be bought now (sale running and inside its own from / to window)
function HalloweenShop.available(it: any, now: number?): boolean
	local t = now or HalloweenShop.now()
	return t < HalloweenShop.ENDS_AT and (it.from == nil or t >= it.from) and (it.to == nil or t < it.to)
end

-- the Featured cards to show right now, in order (item ids)
function HalloweenShop.featured(now: number?): { string }
	local t = now or HalloweenShop.now()
	if t >= HalloweenShop.ENDS_AT then
		return {}
	end
	return if t >= HalloweenShop.ROTATE_AT then HalloweenShop.FEATURED_AFTER else HalloweenShop.FEATURED_BEFORE
end

function HalloweenShop.secondsLeft(now: number?): number
	return math.max(0, HalloweenShop.ENDS_AT - (now or HalloweenShop.now()))
end

-- already has this pet (bought, or the same species some other way)
function HalloweenShop.owns(p: any, it: any): boolean
	if p.cosmetics and p.cosmetics.owned and p.cosmetics.owned[it.id] then
		return true
	end
	for _, q in ipairs(p.pets or {}) do
		if q.species == it.species then
			return true
		end
	end
	return false
end

-- the same record IncubatorLogic.addPet writes; copies of the same species level the pet up (1..3)
local function addPet(p: any, it: any): any
	local pet = { id = "p" .. tostring(p.nextPetId), family = it.family, rarity = it.rarity, species = it.species, n = p.nextPetId }
	p.nextPetId += 1
	table.insert(p.pets, pet)
	local copies = {}
	for _, q in ipairs(p.pets) do
		if q.species == it.species and q.rarity == it.rarity then
			table.insert(copies, q)
		end
	end
	for _, q in ipairs(copies) do
		q.level = math.min(#copies, 3)
	end
	if p.equippedPet == "" then
		p.equippedPet = pet.id
	end
	p.cosmetics.owned[it.id] = true -- the shop card shows OWNED (UIController.itemState)
	return pet
end

-- Gems purchase (ProfileLogic.buy). Returns (ok, reason, item) like buy.
function HalloweenShop.buy(p: any, it: any): (boolean, string?, any?)
	if not HalloweenShop.available(it) then
		return false, "ENDED", it
	end
	if HalloweenShop.owns(p, it) then
		return false, "OWNED", it
	end
	if it.wallet ~= "gems" then
		return false, "BAD_WALLET", it
	end
	if (p.gems or 0) < it.price then
		return false, "NOT_ENOUGH", it
	end
	p.gems -= it.price
	addPet(p, it)
	return true, nil, it
end

-- Robux receipt (ProfileLogic.grantItemPurchase, after its exact-once receipt ledger). Granted even after the end
-- date (Roblox retries receipts). Already owned = nothing to give, the receipt is still consumed.
function HalloweenShop.grantPurchase(p: any, it: any): (boolean, string?)
	if HalloweenShop.owns(p, it) then
		return true, "OWNED"
	end
	addPet(p, it)
	return true, nil
end

-- One line at the end of EconomyConfig. Adds the pets to SHOP (PurchaseService builds its product map from SHOP),
-- makes EconomyConfig.item find them, gives the new species their family / rarity / display name, adds the Featured
-- slots and the buy hooks ProfileLogic calls. No require of EconomyConfig here (it requires this module).
function HalloweenShop.inject(econ: any)
	for _, it in ipairs(HalloweenShop.PETS) do
		local entry = { id = it.id, name = it.name, wallet = it.wallet, price = it.price, kind = "pet", desc = it.desc,
			color = it.color, robux = it.robux, productId = it.productId, species = it.species, family = it.family,
			rarity = it.rarity, icon = it.icon, from = it.from, to = it.to }
		table.insert(econ.SHOP, entry)
		byId[it.id] = entry
		econ.EXTRA_SPECIES[it.species] = it.family
		econ.SPECIES_RARITY[it.species] = it.rarity
		econ.DISPLAY_NAMES[it.species] = it.name -- "Pumpkin Wraith" (species id kept, no save migration) shows as Jack-o'-Lantern
		econ.FEATURED[it.id] = it.id -- Featured slot key = item id (UIController's Featured loop, HalloweenShopUI.slots)
	end
	local baseItem = econ.item
	econ.item = function(id: string)
		return baseItem(id) or byId[id]
	end
	econ.HALLOWEEN = HalloweenShop
	econ.buyPet = function(p: any, item: any)
		return HalloweenShop.buy(p, byId[item.id] or item)
	end
	econ.grantPetPurchase = function(p: any, item: any)
		return HalloweenShop.grantPurchase(p, byId[item.id] or item)
	end
	-- families a bought pet can have that eggs don't hatch yet (the UI reads FAMILIES[f] for the ability card)
	local AR = require(script.Parent:WaitForChild("AbilityConfig")).ARCHETYPES
	if not econ.FAMILIES.Tempest and AR.Tempest then
		econ.FAMILIES.Tempest = {
			ability = "PULSE",
			short = "A blast that pushes Catchers away",
			desc = "A shockwave round you that pushes nearby Catchers away.",
			species = {},
			color = AR.Tempest.color,
			cooldown = AR.Tempest.Runner.cooldown,
			duration = AR.Tempest.Runner.duration,
		}
	end
	if not econ.FAMILIES.Guardian and AR.Guardian then
		econ.FAMILIES.Guardian = {
			ability = "SHIELD",
			short = "A shield that blocks one tag",
			desc = "A shield round you for about a second that blocks the next tag.",
			species = {},
			color = AR.Guardian.color,
			cooldown = AR.Guardian.Runner.cooldown,
			duration = AR.Guardian.Runner.duration,
		}
	end
end

return HalloweenShop
