--!nonstrict
-- Double-purchase guard: client "Delivering..." state + server intent window.
-- PromptProductPurchaseFinished fires BEFORE ProcessReceipt has granted
-- anything, so the Buy button must stay locked until the server says so.

----------------------------------------------------------------------------
-- CLIENT (LocalScript / controller)
----------------------------------------------------------------------------
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ClientGuard = {}
local busy = false
local busyUntil = 0
local MAX_WAIT = 30 -- seconds; give up and unlock if the grant never arrives

-- `setCards(state)` is your UI hook: "idle" | "prompting" | "delivering"
ClientGuard.setCards = function(_state) end

function ClientGuard.canBuy()
	return not busy or os.clock() > busyUntil
end

function ClientGuard.buy(productId)
	if not ClientGuard.canBuy() then return end
	busy, busyUntil = true, os.clock() + MAX_WAIT
	ClientGuard.setCards("prompting")
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
end

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _productId, isPurchased)
	if userId ~= Players.LocalPlayer.UserId then return end
	if isPurchased then
		ClientGuard.setCards("delivering") -- spinner, every Buy button locked
		busyUntil = os.clock() + MAX_WAIT
	else
		busy = false
		ClientGuard.setCards("idle")
	end
end)

-- Fire this from the server's "granted" RemoteEvent.
function ClientGuard.onGranted()
	busy = false
	ClientGuard.setCards("idle")
end

----------------------------------------------------------------------------
-- SERVER (inside your monetization service)
----------------------------------------------------------------------------
local ServerGuard = {}
local INTENT_WINDOW = 60  -- s: no second prompt for the same permanent item
local RATE = 1            -- s between "buy" remote calls per player
local intents = {}        -- player -> {[key] = os.clock()}
local lastCall = {}       -- player -> os.clock()

-- Call from the "I want to buy <key>" remote before returning a productId.
-- `owns(player, key)` and `def.permanent` come from your own code.
function ServerGuard.mayPrompt(player, key, def, owns)
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < RATE then
		return false, "Slow down"
	end
	lastCall[player] = now
	if def.permanent then
		if owns(player, key) then return false, "Already owned" end
		local t = intents[player] and intents[player][key]
		if t and now - t < INTENT_WINDOW then return false, "Delivering..." end
		intents[player] = intents[player] or {}
		intents[player][key] = now
	end
	return true
end

-- Inside ProcessReceipt, after the idempotency check on PurchaseId:
-- if a permanent entitlement is already owned, compensate instead of no-op.
function ServerGuard.applyPermanent(player, key, def, owns, grant, compensate, notify)
	if owns(player, key) then
		compensate(player, def.priceRobux) -- e.g. premium currency of equal value
		notify(player, "You already owned this, so we gave you gems instead.")
	else
		grant(player, key)
	end
	if intents[player] then intents[player][key] = nil end
end

-- Saved credits (a free "skip"): take first, refund on failure.
function ServerGuard.useCredit(credits, key, apply)
	if (credits[key] or 0) <= 0 then return false end
	credits[key] -= 1
	local ok, result = pcall(apply)
	if not ok or result == false then
		credits[key] += 1
		return false
	end
	return true
end

function ServerGuard.playerRemoving(player)
	intents[player], lastCall[player] = nil, nil
end

return { Client = ClientGuard, Server = ServerGuard }
