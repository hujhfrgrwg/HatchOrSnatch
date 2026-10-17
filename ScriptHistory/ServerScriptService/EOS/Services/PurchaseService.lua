--!strict
-- PurchaseService (HOS-GEMS-001, 16 Oct): Robux purchases. Gem packs (EconomyConfig.GEM_PACKS), shop items
-- bought outright (EconomyConfig.SHOP productId) and the one-crate Robux opening (EmoteConfig.ROBUX x1).
--  * MarketplaceService.ProcessReceipt is the ONLY path that grants purchased Gems
--  * each receipt credits once (ProfileLogic.grantPurchasedGems keeps a bounded receipt ledger), and Roblox
--    only hears PurchaseGranted after the Gems are saved (DataService.commit); otherwise NotProcessedYet,
--    and Roblox retries the receipt later (next join included)
--  * the client prompts purchases itself (MarketplaceService:PromptProductPurchase); nothing it sends can
--    grant anything
-- Gems buy looks and Emote Crates, never pets or abilities (GDD 18).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local EmoteConfig = require(Shared:WaitForChild("EmoteConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProfileLogic = require(ServerScriptService.EOS.Core.ProfileLogic)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)

local PurchaseService = {}

local RECEIPT_LEDGER = 200 -- receipt ids kept per player (Roblox retries recent receipts only)

local packByProduct: { [number]: any } = {}
for _, pack in ipairs(EconomyConfig.GEM_PACKS) do
	if pack.productId then
		packByProduct[pack.productId] = pack
	end
end
-- shop items bought outright with Robux, and the one-crate Robux opening
local itemByProduct: { [number]: any } = {}
for _, item in ipairs(EconomyConfig.SHOP) do
	if item.productId then
		itemByProduct[item.productId] = item
	end
end
local crateProduct: number? = nil
for _, r in ipairs(EmoteConfig.ROBUX) do
	if r.count == 1 and r.productId then
		crateProduct = r.productId
	end
end
local rng = Random.new()

local function settle(plr: Player, receipt: string, fn: (any) -> ()): boolean
	return DataService.commit(plr, "receipt:" .. receipt, fn)
end

-- items and crates: same exact-once ledger, same "granted only after the save" rule
local function processOther(info: any, plr: Player): Enum.ProductPurchaseDecision?
	local egg = require(script.Parent.EggService).processReceipt(info, plr) if egg then return egg end -- HOS-EGG-002: hatch boost products (nil = not ours)
	local receipt = tostring(info.PurchaseId)
	local item = itemByProduct[info.ProductId]
	if item then
		local granted, why = false, nil
		if not settle(plr, receipt, function(p)
			local ok, reason = ProfileLogic.grantItemPurchase(p, receipt, item.id, EconomyConfig, RECEIPT_LEDGER)
			if ok then granted, why = true, reason end
		end) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if granted then
			-- a new item gets the client's Reward reveal; an item already owned refunds its Gems with a toast
			Net.event("ShopResult"):FireClient(plr, { ok = true, itemId = item.id, robux = true, refunded = why == "OWNED_REFUNDED" })
			if why == "OWNED_REFUNDED" then
				Net.event("Toast"):FireClient(plr, { text = ("You already had %s: +%d Gems"):format(item.name, item.price), kind = "reward" })
			end
			Analytics.log("CosmeticUsed", { userId = plr.UserId, reason = "robux_item", itemId = item.id, robux = info.CurrencySpent, purchaseId = receipt })
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if crateProduct and info.ProductId == crateProduct then
		-- rolled once per receipt attempt; the ledger stops a second grant if Roblox retries
		local emoteId = EmoteConfig.roll(rng:NextNumber())
		local result = nil
		if not settle(plr, receipt, function(p)
			local ok, res = ProfileLogic.grantCratePurchase(p, receipt, emoteId, EmoteConfig, RECEIPT_LEDGER)
			if ok then
				result = res
				ProfileLogic.wheelAdd(p, emoteId, EmoteConfig)
			end
		end) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if result then
			Net.event("CrateResult"):FireClient(plr, { ok = true, emote = result.emote, dupe = result.dupe, refund = result.refund, robux = true })
			Analytics.log("CosmeticUsed", { userId = plr.UserId, reason = "robux_crate", emote = result.emote, robux = info.CurrencySpent, purchaseId = receipt })
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return nil
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local plr = Players:GetPlayerByUserId(info.PlayerId)
	if not plr or not DataService.isLoaded(plr) then
		-- not here (or the save is still loading): Roblox retries, including when they next join
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if require(script.Parent.LeadCatcherService).owns(info.ProductId) then return require(script.Parent.LeadCatcherService).processReceipt(info, plr) end -- HOS-LEAD-001
	local pack = packByProduct[info.ProductId]
	if not pack then
		local other = processOther(info, plr)
		if other then
			return other
		end
		warn(("[EOS] receipt for unknown product %s (purchase %s): left for a later server"):format(tostring(info.ProductId), tostring(info.PurchaseId)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipt = tostring(info.PurchaseId)
	local granted = false
	local saved = DataService.commit(plr, "receipt:" .. receipt, function(p)
		local ok = ProfileLogic.grantPurchasedGems(p, receipt, pack.gems, RECEIPT_LEDGER)
		if ok then granted = true end
	end)
	if not saved then
		Analytics.warn("PersistenceError", "receipt" .. receipt, "Gem pack receipt not saved yet; Roblox will retry", { userId = plr.UserId, reason = "RECEIPT_NOT_SAVED" })
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if granted then
		Net.event("ShopResult"):FireClient(plr, { ok = true, gems = pack.gems }) -- the client's Reward reveal
		Analytics.log("GemsSource", { userId = plr.UserId, amount = pack.gems, reason = "robux_pack", robux = info.CurrencySpent, productId = info.ProductId, purchaseId = receipt })
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- exposed for tests (Roblox won't hand ProcessReceipt back once it's set)
PurchaseService.processReceipt = processReceipt

function PurchaseService.init()
	MarketplaceService.ProcessReceipt = processReceipt
end

return PurchaseService
