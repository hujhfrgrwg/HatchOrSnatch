-- NpcSkinService: dresses the NPCs. HOS-BOT-001 (Npc.REAL_POOL): everyone sees the same made-up
-- looks from RealPlayerPool. With Npc.FRIEND_FALLBACK (the old way, below): every player sees the
-- NPCs as their own friends.
-- For each player the server picks friends (then friends of friends when the list is short),
-- builds their avatars as R6 models and puts them in that player's PlayerGui (EOS_FriendSkins),
-- which only that player receives. The player's client (Controllers/NpcSkins) then dresses each
-- NPC body locally: NPC slot n wears Skin<n>. Bodies, positions and animations stay server-side
-- and shared, so this costs one set of avatar models per player and nothing per frame.
-- Built on demand: only as many looks as the server can need (fewer players = more NPCs).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local NpcService = require(script.Parent.NpcService)

local N = GameConfig.Npc
local NpcSkinService = {}

type Entry = { id: number, name: string, desc: HumanoidDescription? }
local descCache: { [number]: HumanoidDescription } = {}
local states: { [Player]: { list: { Entry }?, built: number, busy: boolean } } = {}
local rng = Random.new()

local function shuffle(t: { any })
	for i = #t, 2, -1 do
		local j = rng:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end

-- up to `want` friends of userId not already in `seen`
local function friendsOf(userId: number, out: { Entry }, seen: { [number]: boolean }, want: number)
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(userId)
	end)
	if not ok or not pages then
		return
	end
	while #out < want do
		for _, f in ipairs(pages:GetCurrentPage()) do
			local uname = tostring(f.Username or "")
			local dname = tostring(f.DisplayName or uname)
			local deleted = string.find(uname, "Account Deleted", 1, true) ~= nil or string.find(dname, "Account Deleted", 1, true) ~= nil
			if f.Id and not seen[f.Id] and not deleted then
				seen[f.Id] = true
				table.insert(out, { id = f.Id, name = if dname ~= "" then dname else "Friend" })
				if #out >= want then
					break
				end
			end
		end
		if pages.IsFinished or #out >= want then
			break
		end
		local advanced = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not advanced then
			break
		end
	end
end

local function buildList(plr: Player): { Entry }
	if N.REAL_POOL and not N.FRIEND_FALLBACK then
		-- HOS-BOT-001: everyone sees the same made-up people (RealPlayerPool), slot for slot.
		-- FriendUserId gets the identity's opaque negative key (no headshot; no real UserId)
		local Pool = require(script.Parent.RealPlayerPool)
		local list: { Entry } = {}
		for i, id in ipairs(Pool.list(N.MAX_SLOTS)) do
			list[i] = { id = id.key, name = id.name, desc = Pool.description(id) }
		end
		return list
	end
	local seen: { [number]: boolean } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		seen[p.UserId] = true -- people in this server are here for real; they're never NPC looks
	end
	local friends: { Entry } = {}
	if plr.UserId > 0 then
		friendsOf(plr.UserId, friends, seen, N.MAX_SLOTS)
	end
	shuffle(friends)
	local list = table.clone(friends)
	if #list < N.MAX_SLOTS then
		-- too few friends: borrow from friends' friend lists
		local sources = table.clone(friends)
		shuffle(sources)
		for i = 1, math.min(#sources, N.FRIEND_OF_FRIEND_LOOKUPS) do
			local extra: { Entry } = {}
			friendsOf(sources[i].id, extra, seen, N.MAX_SLOTS - #list)
			shuffle(extra)
			for _, e in ipairs(extra) do
				table.insert(list, e)
			end
			if #list >= N.MAX_SLOTS then
				break
			end
		end
	end
	return list
end

local function container(plr: Player): ScreenGui?
	local pg = plr:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	local g = pg:FindFirstChild("EOS_FriendSkins") :: ScreenGui?
	if not g then
		local ng = Instance.new("ScreenGui")
		ng.Name = "EOS_FriendSkins"
		ng.ResetOnSpawn = false
		ng.Enabled = false
		ng.Parent = pg
		g = ng
	end
	return g
end

local function buildSkin(entry: Entry, slot: number): Model?
	local desc = entry.desc or descCache[entry.id]
	if not desc then
		local ok, d = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(entry.id)
		end)
		if not ok or not d then
			return nil
		end
		descCache[entry.id] = d
		desc = d
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		return nil
	end
	model.Name = "Skin" .. slot
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	model:SetAttribute("FriendUserId", entry.id)
	model:SetAttribute("FriendName", entry.name)
	return model
end

-- how many looks this server can need right now: lobby fill + a full NPC match
local function expectedSlots(): number
	local n = #Players:GetPlayers()
	if not N.ENABLED then
		return 0
	end
	local lobby = math.max(0, N.LOBBY_TARGET - n)
	local match = if n < N.RUNNER_TARGET then (N.RUNNER_TARGET - n + 1) + 2 else 0
	return math.min(N.MAX_SLOTS, math.max(lobby + match, NpcService.highestSlot()))
end

local function pump(plr: Player)
	local st = states[plr]
	if not st or st.busy then
		return
	end
	st.busy = true
	task.spawn(function()
		while plr.Parent and states[plr] == st do
			local need = expectedSlots()
			if need <= st.built then
				break
			end
			if not st.list then
				st.list = buildList(plr)
			end
			local list = st.list :: { Entry }
			local slot = st.built + 1
			local entry = list[slot]
			if not entry then
				break -- no more friends to show: the rest keep the plain NPC look
			end
			local skin = buildSkin(entry, slot)
			if skin then
				local g = container(plr)
				if g then
					local old = g:FindFirstChild(skin.Name)
					if old then
						old:Destroy()
					end
					skin.Parent = g
				end
				st.built = slot
			elseif entry.desc then
				st.built = slot -- (made-up look won't build: that slot keeps the plain look and the same name)
			else
				table.remove(list, slot) -- that avatar won't load: next friend takes this slot
			end
			task.wait(0.15)
		end
		st.busy = false
	end)
end

function NpcSkinService.init()
	local function add(plr: Player)
		states[plr] = { list = nil, built = 0, busy = false }
		task.delay(1, pump, plr)
	end
	Players.PlayerAdded:Connect(add)
	for _, plr in ipairs(Players:GetPlayers()) do
		add(plr)
	end
	Players.PlayerRemoving:Connect(function(plr)
		states[plr] = nil
	end)
	NpcService.onSlotsChanged(function()
		for plr in pairs(states) do
			pump(plr)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(3)
			for plr in pairs(states) do
				pump(plr)
			end
		end
	end)
end

return NpcSkinService
