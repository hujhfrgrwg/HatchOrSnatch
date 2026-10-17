--!strict
-- LobbyService: the living parts of the lobby.
--  * gate status board (next match / waiting for players / match in progress)
--  * left leaderboards: live THIS-SERVER boards (clearly labelled; not global)
--  * centre podium: last match's Top 3 Runners as avatar statues + Top Thief sign
--  * walk-up prompts that open the Incubator / Pets / Shop / Quests screens
-- World parts are found by CollectionService tags set by the world builder; missing tags warn.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local TierConfig = require(Shared:WaitForChild("TierConfig"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local MatchService = require(script.Parent.MatchService)

local LobbyService = {}
local state = Net.state()

local function tagged(tag: string): { Instance }
	local list = CollectionService:GetTagged(tag)
	if #list == 0 then
		warn("[EOS] LobbyService: nothing tagged " .. tag .. " (build the world with EOSBuild.WorldBuilder)")
	end
	return list
end

local function find(inst: Instance, name: string): any
	return inst:FindFirstChild(name, true)
end

-- ===== status board =====

local function statusText(): (string, string)
	local phase = state:GetAttribute("Phase") or "BOOT"
	local left = math.max(0, (state:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow())
	if phase == "WAITING" or phase == "BOOT" then
		return "WAITING FOR PLAYERS", ("%d / %d READY  ·  TRY THE PRACTICE FIELD"):format(state:GetAttribute("Ready") or 0, state:GetAttribute("Needed") or 4)
	elseif phase == "INTERMISSION" then
		return "NEXT MATCH IN " .. Format.time(left), Format.plural(state:GetAttribute("Ready") or 0, "PLAYER") .. " READY"
	elseif phase == "RESULTS" then
		return "MATCH OVER", "NEXT MATCH SOON"
	else
		local wave = state:GetAttribute("Wave") or 0
		return "MATCH IN PROGRESS", ("CROSSING %d  ·  YOU'RE IN THE NEXT ONE"):format(math.max(wave, 1))
	end
end

local function updateBoards()
	local title, sub = statusText()
	for _, board in ipairs(CollectionService:GetTagged("EOS_StatusBoard")) do
		local t = find(board, "Title")
		local s = find(board, "Sub")
		if t then
			t.Text = title
		end
		if s then
			s.Text = sub
		end
	end
end

-- ===== leaderboards (this server) =====

local BOARD_STATS = {
	wins = { attr = "EOS_Wins", fmt = function(v: number)
		return Format.short(v)
	end },
	bestTier = { attr = "EOS_BestTier", fmt = function(v: number)
		return "LEVEL " .. v
	end },
	captures = { attr = "EOS_Captures", fmt = function(v: number)
		return Format.short(v)
	end },
	petsHatched = { attr = "EOS_PetsHatched", fmt = function(v: number)
		return Format.short(v)
	end },
}

local function updateLeaderboards()
	for _, board in ipairs(CollectionService:GetTagged("EOS_Board")) do
		local stat = BOARD_STATS[board:GetAttribute("Stat") or ""]
		if stat then
			local rows = {}
			for _, plr in ipairs(Players:GetPlayers()) do
				local v = plr:GetAttribute(stat.attr)
				if type(v) == "number" then
					table.insert(rows, { name = plr.DisplayName, v = v, id = plr.UserId })
				end
			end
			table.sort(rows, function(a, b)
				if a.v ~= b.v then
					return a.v > b.v
				end
				return a.id < b.id
			end)
			for i = 1, 8 do
				local row = find(board, "Row" .. i)
				if row then
					local r = rows[i]
					local nameL = row:FindFirstChild("PlayerName")
					local valL = row:FindFirstChild("Value")
					if nameL then
						nameL.Text = if r then (i .. ". " .. r.name) else ""
					end
					if valL then
						valL.Text = if r then stat.fmt(r.v) else ""
					end
				end
			end
		end
	end
end

-- ===== podium =====

local function clearPodium()
	for _, spot in ipairs(CollectionService:GetTagged("EOS_PodiumSpot")) do
		local old = spot:FindFirstChild("EOS_Statue")
		if old then
			old:Destroy()
		end
		local label = find(spot, "PodiumName")
		if label then
			label.Text = "—"
		end
		local sub = find(spot, "PodiumSub")
		if sub then
			sub.Text = ""
		end
	end
end

local function placeStatue(spot: BasePart, userId: number)
	task.spawn(function()
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromUserId(userId)
		end)
		if not ok or not model or not spot.Parent then
			return
		end
		model.Name = "EOS_Statue"
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			end
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		local _, size = model:GetBoundingBox()
		local top = spot.Position + Vector3.new(0, spot.Size.Y / 2 + size.Y / 2 + 0.05, 0)
		-- face the way the podium faces (the builder sets it; the lobby's middle)
		local facing = spot:GetAttribute("Facing")
		local dir = if typeof(facing) == "Vector3" and facing.Magnitude > 0.1 then facing.Unit else Vector3.new(0, 0, 1)
		model:PivotTo(CFrame.lookAt(top, top + dir))
		model.Parent = spot
	end)
end

function LobbyService.showResults(payload: any)
	clearPodium()
	for _, spot in ipairs(CollectionService:GetTagged("EOS_PodiumSpot")) do
		local place = spot:GetAttribute("Place")
		local entry = nil
		for _, r in ipairs(payload.topRunners or {}) do
			if r.place == place and not r.npcSlot then -- NPCs look different to every player: real players only here
				entry = r
			end
		end
		if entry and spot:IsA("BasePart") then
			local label = find(spot, "PodiumName")
			local sub = find(spot, "PodiumSub")
			if label then
				label.Text = entry.name or "?"
			end
			if sub then
				sub.Text = (if entry.survived then "SURVIVED  ·  " else (entry.crossings .. " CROSSINGS  ·  ")) .. "LEVEL " .. entry.securedTier
				sub.TextColor3 = TierConfig.get(entry.securedTier).text
			end
			placeStatue(spot, entry.userId)
		end
	end
	for _, sign in ipairs(CollectionService:GetTagged("EOS_ThiefSign")) do
		local t = find(sign, "ThiefName")
		local s = find(sign, "ThiefSub")
		local thief = payload.topThief
		if thief and thief.npcSlot then
			thief = nil
		end
		if t then
			t.Text = if thief then thief.name else "NO CAPTURES"
		end
		if s then
			s.Text = if thief then (Format.plural(thief.captures, "CAPTURE") .. "  ·  STOLE LEVEL " .. thief.bestStolenTier) else ""
		end
	end
	for _, b in ipairs(CollectionService:GetTagged("EOS_PodiumTitle")) do
		local t = find(b, "Title")
		if t then
			t.Text = if payload.team == "RUNNERS" then "LAST MATCH: RUNNERS WON" else "LAST MATCH: CATCHERS WON"
		end
	end
end

-- ===== prompts =====

local function setupPrompts()
	for _, part in ipairs(tagged("EOS_Prompt")) do
		if part:IsA("BasePart") and not part:FindFirstChildOfClass("ProximityPrompt") then
			local screen = part:GetAttribute("Screen") or "Quests"
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = part:GetAttribute("Action") or "Open"
			pp.ObjectText = part:GetAttribute("Label") or screen
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 12
			pp.RequiresLineOfSight = false
			pp.Parent = part
			pp.Triggered:Connect(function(plr)
				Net.event("OpenScreen"):FireClient(plr, { name = screen, tab = part:GetAttribute("Tab") })
			end)
		end
	end
end

function LobbyService.init()
	setupPrompts()
	tagged("EOS_StatusBoard")
	tagged("EOS_Board")
	tagged("EOS_PodiumSpot")
	MatchService.onResults(LobbyService.showResults)
	task.spawn(function()
		local n = 0
		while true do
			pcall(updateBoards)
			n += 1
			if n % 12 == 0 then
				pcall(updateLeaderboards)
			end
			task.wait(0.25)
		end
	end)
end

return LobbyService
