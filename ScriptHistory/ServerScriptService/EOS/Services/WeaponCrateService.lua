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

local function onCrate(plr: Player)
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
	-- rolled once, here, so every replay of the change gives the same skin
	local itemId = WeaponCrateService.roll(rng:NextNumber(), rng:NextNumber(), live.weaponPity)
	if not itemId then
		ev:FireClient(plr, { ok = false, reason = "UNKNOWN" })
		return toast(plr, WORDS.UNKNOWN, "warn")
	end
	local scratch = ProfileLogic.deepCopy(live)
	local ok, info = ProfileLogic.openWeaponCrate(scratch, itemId, EconomyConfig)
	if not ok then
		ev:FireClient(plr, { ok = false, reason = info })
		return toast(plr, (WORDS[info] or WORDS.UNKNOWN):format(EconomyConfig.KNIFE_CRATE.gems), "warn")
	end
	DataService.update(plr, "wcrate:" .. itemId, function(p)
		ProfileLogic.openWeaponCrate(p, itemId, EconomyConfig)
	end)
	ev:FireClient(plr, { ok = true, itemId = itemId, dupe = info.dupe, refund = info.refund, pity = scratch.weaponPity })
	Analytics.log("GemsSink", { userId = plr.UserId, amount = EconomyConfig.KNIFE_CRATE.gems, reason = "weapon_crate" })
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
