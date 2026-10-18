--!strict
-- EggIncubatorView (HOS-EGG-002 fixes, 17 Oct): the incubator's overfill / Lucky Egg / hatch boost parts, on top of what
-- EggUIController.refreshIncubator already writes (shards, odds bars, focus chips). Fill only, never percent:
-- "27 / 36 FILL", ring marks HATCH (18) and MAX (36, static in the export), "Odds at 27 fill".
-- Hooks (one line each in EggUIController): init(EUI, getView) in init; refresh(scr, view, hatching, H) at the end of
-- refreshIncubator. Purchases: BtnBoost prompts the next tier's dev product, BtnLucky the Lucky Egg pass. The server
-- grants (EggService.processReceipt / the pass check) and pushes ProfileState / EOS_LuckyEgg; nothing changes here.
-- Off while the ids are 0: the boost button and the Lucky strip stay hidden.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("EggConfig"))

local player = Players.LocalPlayer
local View = {}

local TIER_KEYS = { "x2", "x3", "x4" }
local GOLD, WHITE = Color3.fromRGB(255, 210, 58), Color3.new(1, 1, 1)
local prices: { [number]: number } = {} -- product id -> Robux (asked once each)
local asking: { [number]: boolean } = {}
local lastScr: Instance? = nil
local lastArgs: any = nil

local function productFor(tier: number): number
	local key = TIER_KEYS[tier]
	return (key and EggConfig.HATCH_BOOST.products[key]) or 0
end

-- the boost ladder is on only when every tier has a product id
function View.boostOn(): boolean
	for t = 1, #TIER_KEYS do
		if productFor(t) == 0 then return false end
	end
	return true
end

local function luckyOn(): boolean
	local id = EggConfig.LUCKY_PASS.gamePassId
	return id ~= nil and id ~= 0
end

local function priceOf(id: number): number?
	if prices[id] or asking[id] or id == 0 then return prices[id] end
	asking[id] = true
	task.spawn(function()
		local ok, info = pcall(function() return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product) end)
		if ok and type(info) == "table" and tonumber(info.PriceInRobux) then
			prices[id] = tonumber(info.PriceInRobux) :: number
			if lastScr and lastArgs then View.refresh(lastScr, lastArgs[1], lastArgs[2], lastArgs[3]) end
		end
	end)
	return nil
end

function View.refresh(scr: Instance, view: any, hatching: boolean, H: any)
	if not (scr and view and view.need) then return end
	lastScr, lastArgs = scr, { view, hatching, H }
	local full = view.full or EggConfig.INCUBATOR.FILL
	local cap = view.cap or full * EggConfig.INCUBATOR.MAX_MULT
	local cost = view.focusCost or 0
	local ready = view.ready == true
	local fill = view.fill or 0
	-- the ring runs 0 -> cap (HATCH mark at half-way): green to FILL, gold past it
	H.ring(H.find(scr, "FillRing"), math.min(1, fill / cap), if fill > full then GOLD else Color3.fromRGB(124, 240, 90))
	H.setText(scr, "FillText", ("%s / %s FILL"):format(H.num(fill), H.num(cap)))
	H.tint(H.find(scr, "FillText"), if ready then GOLD else WHITE)
	H.setText(scr, "FillSub", if not ready then ("%s more fill to hatch"):format(H.num(view.need - fill))
		elseif fill >= cap then "MAX FILL: the best odds this egg can give"
		else ("Hatch now, or fill to %s for bigger odds"):format(H.num(cap)))
	H.tint(H.find(scr, "FillSub"), if ready then GOLD else Color3.fromRGB(210, 210, 216))
	-- the odds caption: the fill the odds read from (after the focus cost; below FILL the first hatch's odds)
	H.setText(scr, "OddsNote", ("Odds at %s fill"):format(H.num(math.max(fill - cost, full))))
	H.setText(scr, "OddsNote2", if cost > 0 then ("after the %s focus cost"):format(H.num(cost))
		elseif not view.legendaryOpen then "Legendary's chance goes to Epic for now"
		elseif ready then "what your hatch rolls" else ("they grow as you fill past %s"):format(H.num(full)))
	-- the Lucky Egg pass: tag + line when owned, the buy strip when not (hidden while the pass id is 0)
	local lucky = player:GetAttribute("EOS_LuckyEgg") == true
	H.show(H.find(scr, "LuckyTag"), lucky)
	H.show(H.find(scr, "LuckyOn"), lucky)
	H.show(H.find(scr, "BtnLucky"), not lucky and luckyOn())
	-- the boost ladder: x2 ODDS -> UPGRADE TO x3 -> UPGRADE TO x4 -> x4 MAXED (hidden while any product id is 0)
	local mults = EggConfig.HATCH_BOOST.mults
	local tier = math.clamp(tonumber(view.boost) or 0, 0, #mults)
	local on = View.boostOn()
	H.show(H.find(scr, "BoostTag"), tier > 0)
	if tier > 0 then H.setText(scr, "BoostTagText", ("x%d BOOST"):format(mults[tier])) end
	local buy, maxed = H.find(scr, "BtnBoost"), H.find(scr, "BtnBoostMax")
	H.show(buy, on and tier < #mults and not hatching)
	H.show(maxed, on and tier >= #mults)
	if buy and tier < #mults then
		H.setText(buy, "BoostLabel", if tier == 0 then ("x%d ODDS"):format(mults[1]) else ("UPGRADE TO x%d"):format(mults[tier + 1]))
		local p = priceOf(productFor(tier + 1))
		H.setText(buy, "BoostPrice", if p then tostring(p) else "...")
	end
	if maxed then H.setText(maxed, "BoostLabel", ("x%d MAXED"):format(mults[#mults])) end
	-- HATCH NOW at FILL, HATCH (BIGGER ODDS) past it
	local hb = H.find(scr, "BtnHatch")
	local lbl = hb and H.find(hb, "Label")
	if lbl then H.K.set(lbl, if fill - cost > full + 1e-6 then "HATCH (BIGGER ODDS)" else "HATCH NOW") end
end

function View.init(EUI: any, getView: () -> any)
	EUI.Action:Connect(function(name: string)
		local view = getView()
		if name == "BtnBoost" and view and View.boostOn() then
			local tier = math.clamp(tonumber(view.boost) or 0, 0, #TIER_KEYS)
			local id = productFor(tier + 1)
			if id ~= 0 then
				pcall(function() MarketplaceService:PromptProductPurchase(player, id) end)
			end
		elseif name == "BtnLucky" and luckyOn() and player:GetAttribute("EOS_LuckyEgg") ~= true then
			pcall(function() MarketplaceService:PromptGamePassPurchase(player, EggConfig.LUCKY_PASS.gamePassId) end)
		end
	end)
end

return View
