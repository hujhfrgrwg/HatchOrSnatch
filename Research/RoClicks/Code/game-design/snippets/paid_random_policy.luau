--!nonstrict
-- Server: PolicyService gate for paid random items (crates, eggs, spins).
-- A failed lookup counts as restricted and is retried after RETRY seconds.

local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")

local Policy = {}
local RETRY = 60
local cache = {} -- player -> {restricted = bool, failed = bool, at = number}

function Policy.lookup(player)
	local c = cache[player]
	if c and (not c.failed or os.clock() - c.at < RETRY) then return c end
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if ok and type(info) == "table" then
		c = { restricted = info.ArePaidRandomItemsRestricted == true, failed = false, at = os.clock() }
	else
		c = { restricted = true, failed = true, at = os.clock() }
	end
	cache[player] = c
	return c
end

function Policy.restricted(player): boolean
	return Policy.lookup(player).restricted
end

-- Use this in EVERY path that can start a paid random item:
-- the crate-open remote, the generic "use product" remote, gift paths.
function Policy.guard(player, productDef)
	if productDef.paidRandom and Policy.restricted(player) then
		return false, "This isn't available for your account"
	end
	return true
end

-- Client asks this; keep asking every RETRY s while `failed` is true.
function Policy.forClient(player)
	local c = Policy.lookup(player)
	return { restricted = c.restricted, failed = c.failed }
end

Players.PlayerRemoving:Connect(function(p) cache[p] = nil end)

-- Weighted roll with pity, on the server. Odds text must come from `items`.
-- items = { {id="a", weight=60, rare=false}, {id="b", weight=5, rare=true}, ... }
function Policy.roll(items, pityCount, pityAt, rng)
	rng = rng or Random.new()
	if pityAt and pityCount + 1 >= pityAt then
		local rares, w = {}, 0
		for _, it in ipairs(items) do if it.rare then table.insert(rares, it); w += it.weight end end
		local r = rng:NextNumber() * w
		for _, it in ipairs(rares) do r -= it.weight; if r <= 0 then return it, 0 end end
	end
	local total = 0
	for _, it in ipairs(items) do total += it.weight end
	local r = rng:NextNumber() * total
	for _, it in ipairs(items) do
		r -= it.weight
		if r <= 0 then return it, (it.rare and 0 or pityCount + 1) end
	end
	return items[#items], pityCount + 1
end

-- Odds for display, computed from the same table the roll uses.
function Policy.oddsText(items)
	local total = 0
	for _, it in ipairs(items) do total += it.weight end
	local out = {}
	for _, it in ipairs(items) do
		table.insert(out, { id = it.id, percent = math.floor(it.weight / total * 1000 + 0.5) / 10 })
	end
	return out
end

return Policy
