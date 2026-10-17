--!strict
-- MapService: rotates the arena map between matches (Oct 2026).
-- The live map is workspace.EOS_World.Arena; the others wait in ServerStorage.EOS_Maps as
-- Arena_<Name> (built by BuildAll). Each map model carries attributes Map, MapTitle and FIELD_HALF_X.
-- Swapping moves models (nothing is rebuilt), then points Layout at the new field length:
-- workspace attribute EOS_FieldHalfX, which every Layout copy (server + clients) follows.
-- Every map shares the arena centre, width, zone depth and gate layout, so the match code is unchanged.
--
-- Studio / testing:
--   workspace attribute EOS_FixedMap = "SunnyCove"  -> always play that map (no rotation)
--   require(ServerScriptService.EOS.Services.MapService).set("FrostyPass")  -> swap now (between matches)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("Layout"))
local Net = require(Shared:WaitForChild("Net"))

local MapService = {}

local ORDER = { "Farm", "SunnyCove", "FrostyPass", "Stadium" } -- rotation order
local TITLES = { Farm = "Hatchery Farm", SunnyCove = "Sunny Cove", FrostyPass = "Frosty Pass", Stadium = "Egg Bowl Stadium" }

local state = Net.state()
local current = "Farm"

local function store(): Instance
	local f = ServerStorage:FindFirstChild("EOS_Maps")
	if not f then
		f = Instance.new("Folder")
		f.Name = "EOS_Maps"
		f.Parent = ServerStorage
	end
	return f
end

local function liveArena(): Model?
	local world = workspace:FindFirstChild("EOS_World")
	local a = world and world:FindFirstChild("Arena")
	return if a and a:IsA("Model") then a else nil
end

local function stored(name: string): Model?
	local m = store():FindFirstChild("Arena_" .. name)
	return if m and m:IsA("Model") then m else nil
end

-- 16 Oct 2026: the lobby (workspace.LobbyProto) never moves, but it takes each map's colours:
-- Top = the field colour, Base = the earth just under it. Each map model carries them as
-- attributes LobbyTop / LobbyBase (Color3); a map without them leaves the lobby as it is.
-- Lift: a map can raise the lobby (attribute LobbyLift, studs; the stadium uses it so the lobby sits
-- in its stands). LobbyProto's resting pivot is remembered in its attribute EOS_RestPivot; anyone
-- standing on the lobby rides up/down with it.
local function liftLobby(lobby: Model, lift: number)
	local rest = lobby:GetAttribute("EOS_RestPivot")
	if typeof(rest) ~= "CFrame" then
		rest = lobby:GetPivot()
		lobby:SetAttribute("EOS_RestPivot", rest)
	end
	local was = lobby:GetPivot()
	local want = (rest :: CFrame) + Vector3.new(0, lift, 0)
	local dy = want.Y - was.Y
	if math.abs(dy) > 0.01 then
		local cf, size = lobby:GetBoundingBox()
		lobby:PivotTo(want)
		for _, h in workspace:GetDescendants() do
			if h:IsA("Humanoid") then
				local root = h.Parent and h.Parent:FindFirstChild("HumanoidRootPart")
				local d = if root and root:IsA("BasePart") then root.Position - cf.Position else nil
				if d and math.abs(d.X) < size.X / 2 + 2 and math.abs(d.Z) < size.Z / 2 + 2 and d.Y > -size.Y / 2 and d.Y < size.Y / 2 + 30 then
					(h.Parent :: Model):PivotTo((h.Parent :: Model):GetPivot() + Vector3.new(0, dy, 0))
				end
			end
		end
	end
	workspace:SetAttribute("EOS_LobbyLift", lift)
end

local function paintLobby(arena: Model)
	local lobby = workspace:FindFirstChild("LobbyProto")
	if not lobby or not lobby:IsA("Model") then
		return
	end
	local lift = arena:GetAttribute("LobbyLift")
	liftLobby(lobby, if type(lift) == "number" then lift else 0)
	local top = arena:GetAttribute("LobbyTop")
	local base = arena:GetAttribute("LobbyBase")
	local topModel = lobby:FindFirstChild("Top")
	if typeof(top) == "Color3" and topModel then
		for _, d in topModel:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = top
			end
		end
	end
	if typeof(base) == "Color3" then
		for _, d in lobby:GetChildren() do
			if d:IsA("BasePart") and d.Name == "Base" then
				d.Color = base
			end
		end
	end
end

local function publish(arena: Model)
	local name = arena:GetAttribute("Map") :: string? or "Farm"
	local fx = arena:GetAttribute("FIELD_HALF_X") :: number? or Layout.DEFAULT_FIELD_HALF_X
	local c = arena:GetAttribute("CENTER")
	local center: Vector3 = if typeof(c) == "Vector3" then c else Layout.DEFAULT_CENTER
	current = name
	Layout.setArenaCenter(center) -- this server, right now
	Layout.setFieldHalfX(fx)
	workspace:SetAttribute("EOS_ArenaCenter", center) -- every client's Layout
	workspace:SetAttribute("EOS_FieldHalfX", fx)
	paintLobby(arena)
	workspace:SetAttribute("EOS_Map", name)
	local title = arena:GetAttribute("MapTitle") :: string? or TITLES[name] or name
	state:SetAttribute("Map", name)
	state:SetAttribute("MapTitle", title)
end

function MapService.current(): string
	return current
end

-- maps that exist right now (live or stored), in rotation order
function MapService.available(): { string }
	local out = {}
	for _, name in ORDER do
		if name == current or stored(name) then
			table.insert(out, name)
		end
	end
	return out
end

-- Swap the live arena for `name`. Only call between matches (nobody on the field).
function MapService.set(name: string): boolean
	if name == current and liveArena() then
		return true
	end
	local world = workspace:FindFirstChild("EOS_World")
	local nextArena = stored(name)
	if not world or not nextArena then
		warn(("[EOS] MapService: map %q not found in ServerStorage.EOS_Maps"):format(name))
		return false
	end
	local live = liveArena()
	if live then
		live.Name = "Arena_" .. ((live:GetAttribute("Map") :: string?) or current)
		live.Parent = store()
	end
	nextArena.Name = "Arena"
	nextArena.Parent = world
	publish(nextArena)
	return true
end

-- Next map in the rotation (or the pinned EOS_FixedMap). Returns the map now live.
function MapService.rotate(): string
	local fixed = workspace:GetAttribute("EOS_FixedMap")
	if type(fixed) == "string" and fixed ~= "" then
		MapService.set(fixed)
		return current
	end
	local list = MapService.available()
	if #list > 1 then
		local i = table.find(list, current) or 0
		MapService.set(list[i % #list + 1])
	end
	return current
end

function MapService.title(): string
	return (state:GetAttribute("MapTitle") :: string?) or TITLES[current] or current
end

function MapService.init()
	local live = liveArena()
	if not live then
		warn("[EOS] MapService: no EOS_World.Arena (world not built?)")
		return
	end
	-- the farm arena from BuildArena: label it like the other maps
	if live:GetAttribute("Map") == nil then
		live:SetAttribute("Map", "Farm")
		live:SetAttribute("MapTitle", TITLES.Farm)
		live:SetAttribute("FIELD_HALF_X", Layout.DEFAULT_FIELD_HALF_X)
	end
	publish(live)
	local fixed = workspace:GetAttribute("EOS_FixedMap")
	if type(fixed) == "string" and fixed ~= "" then
		MapService.set(fixed)
	end
end

return MapService
