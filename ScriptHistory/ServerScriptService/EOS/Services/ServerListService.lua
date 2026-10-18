--!strict
-- ServerListService (HOS-SERVERS-001): the Servers panel ("find your people", like Huss Valley).
--  * every server writes itself to a MemoryStore sorted map every 15 s (expires after 45 s, so dead
--    servers drop off): players / max, country + city of the server (ip-api.com, once), match phase,
--    and the average ping of its players
--  * RequestServers()          -> ServerList { servers, here, t } (read at most every 8 s, shared)
--  * RequestJoinServer(jobId)  teleports you to that server (lobby only; never to a full one)
-- Studio: the map works (Studio's own store) but teleports don't, so joining just explains that.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local MatchService = require(script.Parent.MatchService)

local ServerListService = {}

local MAP_NAME = "EOS_Servers_v1"
local WRITE_EVERY = 15
local EXPIRY = 45
local READ_CACHE = 8

local state = Net.state()
local map = MemoryStoreService:GetSortedMap(MAP_NAME)
local jobId = if game.JobId ~= "" then game.JobId else ("studio-" .. HttpService:GenerateGUID(false))
local where = { country = "Unknown", code = "", city = "" }
local cache: { any } = {}
local cacheAt = -math.huge
local reading = false

local function toast(plr: Player, text: string, kind: string?)
	Net.event("Toast"):FireClient(plr, { text = text, kind = kind or "info" })
end

local function phaseWord(): string
	local ph = state:GetAttribute("Phase")
	if ph == "CROSSING" or ph == "WAVE_END" or ph == "ROLE_REVEAL" then
		return "Match in progress"
	elseif ph == "RESULTS" then
		return "Match ending"
	elseif ph == "INTERMISSION" then
		return "Starting soon"
	end
	return "In lobby"
end

local function avgPing(): number
	local sum, n = 0, 0
	for _, plr in ipairs(Players:GetPlayers()) do
		local ok, p = pcall(function()
			return plr:GetNetworkPing()
		end)
		if ok and type(p) == "number" and p == p then
			sum += p
			n += 1
		end
	end
	return if n > 0 then math.floor(sum / n * 1000 + 0.5) else 0
end

local function entry(): any
	return {
		id = jobId,
		players = #Players:GetPlayers(),
		max = Players.MaxPlayers,
		country = where.country,
		code = where.code,
		city = where.city,
		phase = phaseWord(),
		ping = avgPing(),
	}
end

local function write()
	pcall(function()
		map:SetAsync(jobId, entry(), EXPIRY)
	end)
end

local function locate()
	local ok, body = pcall(function()
		return HttpService:GetAsync("http://ip-api.com/json/?fields=status,country,countryCode,city")
	end)
	if not ok then
		return
	end
	local ok2, t = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if ok2 and type(t) == "table" and t.status == "success" then
		where.country = tostring(t.country or "Unknown"):sub(1, 40)
		where.code = tostring(t.countryCode or ""):sub(1, 4)
		where.city = tostring(t.city or ""):sub(1, 40)
	end
end

-- the whole list, cached for READ_CACHE seconds; this server always comes from its live numbers
local function list(): { any }
	if os.clock() - cacheAt >= READ_CACHE and not reading then
		reading = true
		local ok, items = pcall(function()
			return map:GetRangeAsync(Enum.SortDirection.Ascending, 100)
		end)
		reading = false
		if ok and type(items) == "table" then
			local out = {}
			for _, it in ipairs(items) do
				local v = it.value
				if type(v) == "table" and type(v.id) == "string" and v.id ~= jobId then
					table.insert(out, v)
				end
			end
			cache = out
			cacheAt = os.clock()
		end
	end
	local all = { entry() }
	for _, v in ipairs(cache) do
		table.insert(all, v)
	end
	return all
end

local function onRequest(plr: Player)
	if not MatchService.limiter:allow(plr.UserId, "RequestServers", os.clock()) then
		return
	end
	Net.event("ServerList"):FireClient(plr, { servers = list(), here = jobId, t = os.time() })
end

local function onJoin(plr: Player, id: any)
	if not MatchService.limiter:allow(plr.UserId, "RequestJoinServer", os.clock()) then
		return
	end
	if type(id) ~= "string" or #id > 64 then
		return
	end
	if id == jobId then
		return toast(plr, "You're already in that server")
	end
	if plr:GetAttribute("EOS_InMatch") == true then
		return toast(plr, "Switch servers between matches")
	end
	local target = nil
	for _, v in ipairs(list()) do
		if v.id == id then
			target = v
		end
	end
	if not target then
		return toast(plr, "That server closed: refresh the list", "warn")
	end
	if (target.players or 0) >= (target.max or 0) then
		return toast(plr, "That server is full", "warn")
	end
	if RunService:IsStudio() then
		return toast(plr, "Joining another server works in the live game, not in Studio")
	end
	toast(plr, "Joining server...", "good")
	local opts = Instance.new("TeleportOptions")
	opts.ServerInstanceId = id
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { plr }, opts)
	end)
	if not ok then
		warn("[EOS] teleport to " .. id .. " failed: " .. tostring(err))
		toast(plr, "Couldn't join that server: try another", "warn")
	end
end

function ServerListService.init()
	Net.event("RequestServers").OnServerEvent:Connect(onRequest)
	Net.event("RequestJoinServer").OnServerEvent:Connect(onJoin)
	TeleportService.TeleportInitFailed:Connect(function(plr, result, msg)
		if plr and plr.Parent then
			toast(plr, "Couldn't join that server: try another", "warn")
		end
	end)
	task.spawn(function()
		locate()
		while true do
			write()
			task.wait(WRITE_EVERY)
		end
	end)
	Players.PlayerAdded:Connect(function()
		task.defer(write)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(write)
	end)
	game:BindToClose(function()
		pcall(function()
			map:RemoveAsync(jobId)
		end)
	end)
end

return ServerListService
