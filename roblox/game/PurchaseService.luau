--!strict
-- PurchaseService (HOS-GEMS-001, 16 Oct): Robux Gem packs (EconomyConfig.GEM_PACKS, live developer products).
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

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local pack = packByProduct[info.ProductId]
	if not pack then
		warn(("[EOS] receipt for unknown product %s (purchase %s): left for a later server"):format(tostring(info.ProductId), tostring(info.PurchaseId)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local plr = Players:GetPlayerByUserId(info.PlayerId)
	if not plr or not DataService.isLoaded(plr) then
		-- not here (or the save is still loading): Roblox retries, including when they next join
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
		Net.event("Toast"):FireClient(plr, { text = ("+%d Gems! Thanks for your support"):format(pack.gems), kind = "reward" })
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
