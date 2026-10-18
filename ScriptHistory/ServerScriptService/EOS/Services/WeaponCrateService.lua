--!strict
-- WeaponCrateService (server): the Weapon Crate and the knife-skin previews, HOS-WEP-001.
--  * RequestWeaponCrate()  250 Gems -> one knife skin. The rarity is rolled by EconomyConfig.KNIFE_CRATE.odds
--                          (shown on the crate card), then one skin of that rarity, evenly. Odds never change with
--                          what you own; a duplicate refunds Gems by rarity. A new skin is equipped straight away
--                          (like buying one). Answer: WeaponCrateResult { ok, reason?, itemId, dupe, refund }.
--  * The skin templates live in ServerStorage.EOS_Assets.KnifeSkins (the server builds the knife from them); a
--    copy without scripts goes to ReplicatedStorage.EOS_KnifeSkinPreviews so the shop can draw each one in 3D.
-- Paid-random-item rules: where PolicyService restricts them, the crate stays shut (as the Emote Crate).
-- Looks only: every skin tags with the same reach and timing.
-- Lobby weapon pedestals (v2, Hunter 18 Oct "Ok"): a pedestal's copy of you swings when you walk up; the client asks
-- PedestalHit(slot) and this knocks you down (CharacterService.ragdoll, the caught-Runner fall) for 2 s if you are
-- really next to that pedestal, in the lobby, not already down, and not hit in the last 8 s. Pushed toward the middle
-- of the lobby so nobody goes off an edge. Looks only.

local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProfileLogic = require(ServerScriptService.EOS.Core.ProfileLogic)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)
local CharacterService = require(script.Parent.CharacterService)
local Layout = require(Shared:WaitForChild("Layout"))

local WeaponCrateService = {}

local rng = Random.new()
local toast: (Player, string, string?) -> () = function() end

local WORDS = {
	NOT_ENOUGH = "Not enough Gems: a crate is %d",
	NOT_LOADED = "Your save is still loading",
	UNKNOWN = "Can't open a crate right now",
}

local restricted: { [Player]: boolean } = {}
local function crateRestricted(plr: Player): boolean
	if restricted[plr] == nil then
		local ok, info = false, nil
		for attempt = 1, 3 do
			ok, info = pcall(function()
				return PolicyService:GetPolicyInfoForPlayerAsync(plr)
			end)
			if ok then
				break
			end
			task.wait(attempt)
		end
		restricted[plr] = not ok or (type(info) == "table" and info.ArePaidRandomItemsRestricted == true)
	end
	return restricted[plr]
end

-- one roll: a rarity by the shown odds, then a skin of that rarity, evenly. `pity` = the player's weaponPity
-- (openings since the last Epic+ / Legendary): when the next opening is the KNIFE_CRATE.pity one, the rarity is
-- forced (a Legendary; or Epic / Legendary by their own odds).
function WeaponCrateService.roll(u1: number, u2: number, pity: any?): string?
	local C = EconomyConfig.KNIFE_CRATE
	local order = C.order
	if type(pity) == "table" and C.pity then
		if (tonumber(pity.legendary) or 0) + 1 >= C.pity.legendary then
			order = { "legendary" }
		elseif (tonumber(pity.epic) or 0) + 1 >= C.pity.epic then
			order = { "epic", "legendary" }
		end
	end
	local total = 0
	for _, r in ipairs(order) do
		total += C.odds[r]
	end
	local pick, acc = order[#order], 0
	for _, r in ipairs(order) do
		acc += C.odds[r]
		if u1 * total < acc then
			pick = r
			break
		end
	end
	local pool = {}
	for _, it in ipairs(EconomyConfig.SHOP) do
		if it.kind == "knifeSkin" and (it :: any).rarity == pick then
			table.insert(pool, it.id)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[math.clamp(math.floor(u2 * #pool) + 1, 1, #pool)]
end

-- HOS-INV-001: everyone nearby sees an opening (Controllers.CrateShowcase): kind|rarity|name|stamp
local function showcase(plr: Player, itemId: string)
	local it = EconomyConfig.item(itemId)
	plr:SetAttribute("EOS_CrateOpen", ("weapon|%s|%s|%d"):format(it and (it :: any).rarity or "common", it and it.name or "a weapon", math.floor(os.clock() * 1000)))
end

-- the pull the reel shows: the rarest (the first of equals)
local RANK = { common = 1, rare = 2, epic = 3, legendary = 4 }
local function bestOf(results: { any }): any
	local best = results[1]
	for _, r in results do
		local a, b = EconomyConfig.item(r.itemId), EconomyConfig.item(best.itemId)
		if a and b and (RANK[(a :: any).rarity] or 0) > (RANK[(b :: any).rarity] or 0) then
			best = r
		end
	end
	return best
end

local function onCrate(plr: Player, count: any)
	if not MatchService.limiter:allow(plr.UserId, "RequestWeaponCrate", os.clock()) then
		return
	end
	local ev = Net.event("WeaponCrateResult")
	if crateRestricted(plr) then
		ev:FireClient(plr, { ok = false, reason = "RESTRICTED" })
		return toast(plr, "Weapon Crates aren't available where you play", "info")
	end
	if plr:GetAttribute("EOS_InMatch") == true then
		return toast(plr, "Open crates between matches", "info")
	end
	local live = DataService.get(plr)
	if not live then
		ev:FireClient(plr, { ok = false, reason = "NOT_LOADED" })
		return toast(plr, WORDS.NOT_LOADED, "warn")
	end
	-- rolled once, here, so every replay of the change gives the same skins. HOS-INV-001: count 10 = open x10
	-- (KNIFE_CRATE.multi: one price, one Epic or better guaranteed); every roll honours the guarantee
	local C = EconomyConfig.KNIFE_CRATE
	local multi = count == C.multi.count
	local n = if multi then C.multi.count else 1
	local price = if multi then C.multi.gems else C.gems
	local scratch = ProfileLogic.deepCopy(live)
	local ids, results = {}, {}
	local gotEpic = false
	for i = 1, n do
		local pity = scratch.weaponPity
		if multi and i == n and not gotEpic then -- the x10 guarantee: the last roll is Epic or better
			pity = { epic = C.pity.epic, legendary = (type(pity) == "table" and tonumber(pity.legendary)) or 0 }
		end
		local itemId = WeaponCrateService.roll(rng:NextNumber(), rng:NextNumber(), pity)
		if not itemId then
			ev:FireClient(plr, { ok = false, reason = "UNKNOWN" })
			return toast(plr, WORDS.UNKNOWN, "warn")
		end
		local ok, info = ProfileLogic.openWeaponCrate(scratch, itemId, EconomyConfig, if i == 1 then price else 0)
		if not ok then
			ev:FireClient(plr, { ok = false, reason = info })
			return toast(plr, (WORDS[info] or WORDS.UNKNOWN):format(price), "warn")
		end
		local it = EconomyConfig.item(itemId)
		if it and (it.rarity == "epic" or it.rarity == "legendary") then
			gotEpic = true
		end
		table.insert(ids, itemId)
		table.insert(results, info)
	end
	local best = bestOf(results)
	DataService.update(plr, "wcrate:" .. (if multi then "x10" else ids[1]), function(p)
		for i, id in ids do
			ProfileLogic.openWeaponCrate(p, id, EconomyConfig, if i == 1 then price else 0)
		end
		if multi and not best.dupe then
			p.cosmetics.knifeSkin = best.itemId -- x10 wears the best new skin, not the last one
		end
	end)
	ev:FireClient(plr, { ok = true, itemId = best.itemId, dupe = best.dupe, refund = best.refund, pity = scratch.weaponPity, multi = if multi then results else nil })
	showcase(plr, best.itemId)
	Analytics.log("GemsSink", { userId = plr.UserId, amount = price, reason = if multi then "weapon_crate_x10" else "weapon_crate" })
end

-- HOS-INV-001: one Weapon Crate opened with Robux (KNIFE_CRATE.productId). PurchaseService hands receipts here first;
-- nil = not this product. Granted only after the save (DataService.commit), exact-once by the receipt ledger.
function WeaponCrateService.processReceipt(info: any, plr: Player, ledgerSize: number): Enum.ProductPurchaseDecision?
	local C = EconomyConfig.KNIFE_CRATE
	if not C.productId or info.ProductId ~= C.productId then
		return nil
	end
	local live = DataService.get(plr)
	local itemId = WeaponCrateService.roll(rng:NextNumber(), rng:NextNumber(), live and live.weaponPity)
	if not itemId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipt = tostring(info.PurchaseId)
	local result = nil
	if not DataService.commit(plr, "receipt:" .. receipt, function(p)
		local ok, res = ProfileLogic.grantWeaponCratePurchase(p, receipt, itemId, EconomyConfig, ledgerSize)
		if ok then
			result = res
		end
	end) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if result then
		local now = DataService.get(plr)
		Net.event("WeaponCrateResult"):FireClient(plr, { ok = true, itemId = result.itemId, dupe = result.dupe, refund = result.refund, pity = now and now.weaponPity, robux = true })
		showcase(plr, result.itemId)
		Analytics.log("CosmeticUsed", { userId = plr.UserId, reason = "robux_weapon_crate", itemId = result.itemId, robux = info.CurrencySpent, purchaseId = receipt })
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- the shop's 3D previews: the templates without anything that runs or makes sound
local function publishPreviews()
	local src = ServerStorage:FindFirstChild("EOS_Assets") and ServerStorage.EOS_Assets:FindFirstChild("KnifeSkins")
	if not src then
		return
	end
	local old = ReplicatedStorage:FindFirstChild("EOS_KnifeSkinPreviews")
	if old then
		old:Destroy()
	end
	local f = src:Clone()
	f.Name = "EOS_KnifeSkinPreviews"
	for _, d in ipairs(f:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	f.Parent = ReplicatedStorage
end

local PEDESTAL_RANGE = 9 -- studs, flat (the client asks at 6; a little slack for lag)
local PEDESTAL_COOLDOWN = 8
local lastPedestalHit: { [Player]: number } = {}

local function onPedestalHit(plr: Player, slot: any)
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 0 or slot > 4 then
		return
	end
	local now = os.clock()
	if now - (lastPedestalHit[plr] or -math.huge) < PEDESTAL_COOLDOWN then
		return
	end
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root or plr:GetAttribute("EOS_InMatch") == true or char:GetAttribute("EOS_Ragdoll") == true then
		return
	end
	local lobby = workspace:FindFirstChild("LobbyProto")
	local folder = lobby and lobby:FindFirstChild("WeaponPedestals")
	local ped: Model? = nil
	if folder then
		for _, m in folder:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("Slot") == slot then
				ped = m
			end
		end
	end
	local top = ped and ped:FindFirstChild("Top") :: BasePart?
	if not top then
		return
	end
	local d = Vector3.new(root.Position.X - top.Position.X, 0, root.Position.Z - top.Position.Z)
	if d.Magnitude > PEDESTAL_RANGE or math.abs(root.Position.Y - top.Position.Y) > 10 then
		return
	end
	lastPedestalHit[plr] = now
	-- knocked toward the middle of the lobby (never toward an edge), a little up
	local mid = Layout.Lobby.CENTER
	local toMid = Vector3.new(mid.X - root.Position.X, 0, mid.Z - root.Position.Z)
	local dir = if toMid.Magnitude > 0.1 then toMid.Unit else (if d.Magnitude > 0.1 then d.Unit else Vector3.new(1, 0, 0))
	CharacterService.ragdoll(plr, dir * 16 + Vector3.new(0, 9, 0), 2)
end

function WeaponCrateService.init(deps: { toast: (Player, string, string?) -> () })
	toast = deps.toast
	publishPreviews()
	Net.event("RequestWeaponCrate").OnServerEvent:Connect(onCrate)
	Net.event("PedestalHit").OnServerEvent:Connect(onPedestalHit)
	game:GetService("Players").PlayerRemoving:Connect(function(plr)
		restricted[plr] = nil
		lastPedestalHit[plr] = nil
	end)
end

return WeaponCrateService
