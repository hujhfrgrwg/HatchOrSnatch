--!strict
-- MapVoteController (HOS-MAPVOTE-001, 17 Oct): the NEXT MAP vote panel under the round header in the lobby countdown.
-- The panel is a roblox-ui-maker template (ReplicatedStorage.MapVoteUITemplates.MapVotePanel, from UI/build.py
-- vote_panel / s_mapvote_templates, export workspace ui_mapvote/). Driven by MapVoteService's attributes on
-- ReplicatedStorage (MapVoteState / A / B / TitleA / TitleB / CountA / CountB / VotersA / VotersB / EndsAt / Winner)
-- and EOS_State.Phase. Click a map or press 1 / 2 (EOS_Remotes.RequestMapVote); you can switch until 0:00.
-- Started by Controllers.LeadCatcherController (whose card docks centred under this panel while it shows).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Fit = require(script.Parent.Fit)
local UIKit: any = nil -- the roblox-ui-maker kit shipped in the built MapVoteUI gui (set: fit-to-box text); loaded in init

local MapVoteController = {}

local player = Players.LocalPlayer
local TAGS = { SunnyCove = "SAND + PALMS", FrostyPass = "ICE + SNOW", Farm = "THE CLASSIC", Stadium = "BIG CROWD" }
local PANEL_Y = 200 -- design px from the top: under the round header
local PANEL_W = 960 -- Hunter's reference 03: 50% x 44% of 1080p
MapVoteController.PANEL_H = 473

local holder: Frame? = nil
local panel: GuiObject? = nil
local myVote: number? = nil
local shownChanged = Instance.new("BindableEvent")
MapVoteController.ShownChanged = shownChanged.Event
local wasShown = false
local dismissed = false -- the X hides the panel for this vote

local function templates(): Instance?
	return ReplicatedStorage:FindFirstChild("MapVoteUITemplates") or script:FindFirstChild("Templates")
end

local function setText(root: Instance, name: string, text: string)
	for _, n in ipairs({ name, name .. "Shadow" }) do
		local l = root:FindFirstChild(n, true)
		if l and l:IsA("TextLabel") then
			l.Text = text
		end
	end
end

-- the exporter puts a "DropShadow" frame right before each element that has one: pair them once per clone
local shadowOf: { [Instance]: GuiObject } = {}
local function pairShadows(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") and d.Name ~= "DropShadow" then
			local kids = d:GetChildren()
			for i, c in ipairs(kids) do
				if c.Name == "DropShadow" and c:IsA("GuiObject") then
					local nxt = kids[i + 1]
					if nxt and nxt:IsA("GuiObject") and nxt.Name ~= "DropShadow" then
						shadowOf[nxt] = c
					end
				end
			end
		end
	end
end

local function show(root: Instance?, name: string, on: boolean)
	if not root then
		return
	end
	for _, n in ipairs({ name, name .. "Shadow" }) do
		local g = root:FindFirstChild(n)
		if g and g:IsA("GuiObject") then
			g.Visible = on
			local sh = shadowOf[g]
			if sh then
				sh.Visible = on
			end
		end
	end
end

function MapVoteController.isShown(): boolean
	local st = ReplicatedStorage:GetAttribute("MapVoteState")
	local phase = ReplicatedStorage:FindFirstChild("EOS_State") and ReplicatedStorage.EOS_State:GetAttribute("Phase")
	-- gone the moment the countdown ends; never for AFK players (HOS-MAPVOTE-002)
	return not dismissed and player:GetAttribute("EOS_AFK") ~= true and phase == "INTERMISSION" and (st == "open" or st == "result")
end

local function vote(choice: number)
	if ReplicatedStorage:GetAttribute("MapVoteState") ~= "open" then
		return
	end
	myVote = choice
	local ev = ReplicatedStorage:WaitForChild("EOS_Remotes"):FindFirstChild("RequestMapVote") :: RemoteEvent?
	if ev then
		ev:FireServer(choice)
	end
end

local function fillTile(p: GuiObject, idx: number, side: string)
	local tile = p:FindFirstChild("Tile" .. idx, true)
	if not tile then
		return
	end
	local key = ReplicatedStorage:GetAttribute("MapVote" .. side) :: string?
	local title = (ReplicatedStorage:GetAttribute("MapVoteTitle" .. side) :: string?) or key or ""
	local count = (ReplicatedStorage:GetAttribute("MapVoteCount" .. side) :: number?) or 0
	-- the name fills its NameBox on the plate and shrinks to fit (UIKit.set: TextScaled under a size cap)
	local nameBox = tile:FindFirstChild("NameBox")
	local nameLabel = nameBox and nameBox:FindFirstChild("MapName")
	if nameLabel and nameLabel:IsA("TextLabel") then
		if not nameLabel:GetAttribute("MVSized") then
			nameLabel:SetAttribute("MVSized", true)
			for _, l in ipairs({ nameLabel, nameBox:FindFirstChild("MapNameShadow") }) do
				if l and l:IsA("TextLabel") then
					l.Size = UDim2.new(1, -28, l.Size.Y.Scale, l.Size.Y.Offset) -- 14 px padding each side (the strip's padding)
					l.Position = UDim2.new(0, 14, l.Position.Y.Scale, l.Position.Y.Offset)
					l.TextXAlignment = Enum.TextXAlignment.Left
				end
			end
		end
		if UIKit then
			UIKit.set(nameLabel, string.upper(title))
		else
			setText(nameBox, "MapName", string.upper(title))
		end
	end
	local tag = tile:FindFirstChild("Tag")
	if tag then -- the exporter names a tag's label after its text (T_SandPalms + its Shadow twin)
		for _, l in ipairs(tag:GetChildren()) do
			if l:IsA("TextLabel") then
				l.Text = if key then TAGS[key] or "" else ""
			end
		end
	end
	setText(tile, "VotesText", tostring(count))
	local art = tile:FindFirstChild("Art", true) -- inside the Photo frame
	local folder = templates()
	local ids = folder and folder:FindFirstChild("AssetIds")
	if art and art:IsA("ImageLabel") and not art:FindFirstChildOfClass("UICorner") then
		-- the photo fills its slot (photos are cropped to its 429:226 aspect); Crop keeps it full if a photo is ever
		-- off-aspect, and the corner matches the plate's inner radius (4 px plate radius - 3 px border)
		art.ScaleType = Enum.ScaleType.Crop
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 1)
		corner.Parent = art
	end
	if key and art and art:IsA("ImageLabel") and ids and ids:IsA("ModuleScript") then
		local icons = (require(ids) :: any).icons
		local img = icons and icons["map_" .. string.lower(key)]
		if img then
			art.Image = img
		end
	end
	-- voter heads, newest first (the server sends up to 8 ids)
	local ok, voters = pcall(HttpService.JSONDecode, HttpService, (ReplicatedStorage:GetAttribute("MapVoteVoters" .. side) :: string?) or "[]")
	voters = if ok and type(voters) == "table" then voters else {}
	for k = 1, 8 do
		local head = tile:FindFirstChild("Head" .. k)
		local uid = voters[k]
		show(tile, "Head" .. k, uid ~= nil) -- with its drop-shadow twin
		if head and head:IsA("GuiObject") then
			local img = head:FindFirstChild("Img")
			if uid and img and img:IsA("ImageLabel") then
				img.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(uid)
			end
		end
	end
	local more = count - math.min(count, 8)
	show(tile, "More", more > 0)
	setText(tile, "MoreText", "+" .. more)
	-- your vote / the winner / the loser
	local st = ReplicatedStorage:GetAttribute("MapVoteState")
	local winner = ReplicatedStorage:GetAttribute("MapVoteWinner")
	local result = st == "result" and winner ~= nil
	show(tile, "PlateMine", not result and myVote == idx) -- your vote: the lime plate
	show(tile, "PlateWin", result and winner == idx) -- the winner: the gold plate + WINNER
	show(tile, "WinTag", result and winner == idx)
	show(tile, "Dim", result and winner ~= idx)
end

local function refresh()
	local h = holder
	if not h then
		return
	end
	local on = MapVoteController.isShown()
	if on and not panel then
		local folder = templates()
		local t = folder and folder:FindFirstChild("MapVotePanel")
		if t and t:IsA("GuiObject") then
			local p = t:Clone()
			p.Position = UDim2.fromOffset(0, 0)
			p.Visible = true
			p.Parent = h
			panel = p
			pairShadows(p)
			for idx = 1, 2 do
				local tile = p:FindFirstChild("Tile" .. idx, true)
				if tile and tile:IsA("GuiObject") then
					local hit = Instance.new("TextButton") -- invisible hit area over the whole tile
					hit.Name = "Hit"
					hit.BackgroundTransparency = 1
					hit.Text = ""
					hit.Size = UDim2.fromScale(1, 1)
					hit.ZIndex = 50
					hit.Parent = tile
					hit.Activated:Connect(function()
						vote(idx)
					end)
				end
			end
			local x = p:FindFirstChild("CloseButton", true)
			if x and x:IsA("GuiObject") then
				local hit = Instance.new("TextButton") -- the red X: hide the panel for this vote
				hit.Name = "Hit"
				hit.BackgroundTransparency = 1
				hit.Text = ""
				hit.Size = UDim2.fromScale(1, 1)
				hit.ZIndex = 50
				hit.Parent = x
				hit.Activated:Connect(function()
					dismissed = true
					refresh()
				end)
			end
		end
	end
	h.Visible = on and panel ~= nil
	local p = panel
	if p then
		fillTile(p, 1, "A")
		fillTile(p, 2, "B")
		local st = ReplicatedStorage:GetAttribute("MapVoteState")
		local winner = ReplicatedStorage:GetAttribute("MapVoteWinner")
		if st == "result" and winner then
			local title = ReplicatedStorage:GetAttribute(if winner == 1 then "MapVoteTitleA" else "MapVoteTitleB")
			setText(p, "Footer", ("%s wins!"):format(tostring(title)))
		else
			setText(p, "Footer", "Click or Press 1/2")
		end
	end
	if on ~= wasShown then
		wasShown = on
		if not on then
			myVote = nil
		end
		shownChanged:Fire(on)
	end
end

function MapVoteController.init()
	local g = Instance.new("ScreenGui")
	g.Name = "MapVoteHUD"
	g.ResetOnSpawn = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = 4
	local h = Instance.new("Frame")
	h.Name = "MapVote"
	h.BackgroundTransparency = 1
	h.Size = UDim2.fromOffset(PANEL_W, MapVoteController.PANEL_H)
	h.Visible = false
	local s = Instance.new("UIScale")
	s.Name = "Fit"
	s.Parent = h
	h.Parent = g
	g.Parent = player:WaitForChild("PlayerGui")
	holder = h
	local built = player:WaitForChild("PlayerGui"):WaitForChild("MapVoteUI", 10)
	local kit = built and built:FindFirstChild("UIKit")
	if kit and kit:IsA("ModuleScript") then
		UIKit = require(kit) :: any
	end
	Fit.setDesignPosition(h, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, PANEL_Y))
	Fit.track(g)
	for _, a in ipairs({ "MapVoteState", "MapVoteA", "MapVoteB", "MapVoteCountA", "MapVoteCountB", "MapVoteVotersA", "MapVoteVotersB", "MapVoteWinner" }) do
		ReplicatedStorage:GetAttributeChangedSignal(a):Connect(refresh)
	end
	ReplicatedStorage:GetAttributeChangedSignal("MapVoteA"):Connect(function()
		myVote = nil -- a new vote: the X only hid the last one
		dismissed = false
	end)
	player:GetAttributeChangedSignal("EOS_AFK"):Connect(refresh) -- AFK on hides the panel (the server drops the vote), off shows it again
	local stateObj = ReplicatedStorage:WaitForChild("EOS_State", 30)
	if stateObj then
		stateObj:GetAttributeChangedSignal("Phase"):Connect(refresh)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not MapVoteController.isShown() then
			return
		end
		if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.KeypadOne then
			vote(1)
			refresh()
		elseif input.KeyCode == Enum.KeyCode.Two or input.KeyCode == Enum.KeyCode.KeypadTwo then
			vote(2)
			refresh()
		end
	end)
	refresh()
	-- timer + bar
	RunService.Heartbeat:Connect(function()
		local p = panel
		if not p or not wasShown then
			return
		end
		local ends = ReplicatedStorage:GetAttribute("MapVoteEndsAt")
		local left = if type(ends) == "number" then math.max(0, ends - workspace:GetServerTimeNow()) else 0
		if ReplicatedStorage:GetAttribute("MapVoteState") == "result" then
			left = 0
		end
		local secs = math.ceil(left)
		setText(p, "TimerText", ("%d:%02d"):format(secs // 60, secs % 60))
		local bar = p:FindFirstChild("TimeBar", true)
		local fill = bar and bar:FindFirstChild("F")
		if fill and fill:IsA("GuiObject") then
			fill.Size = UDim2.new(math.clamp(left / 15, 0, 1), 0, fill.Size.Y.Scale, fill.Size.Y.Offset)
		end
	end)
end

-- the Lead Catcher card docks here (design px, under the panel's centre)
function MapVoteController.dockPosition(): UDim2
	return UDim2.new(0.5, 0, 0, PANEL_Y + MapVoteController.PANEL_H + 20)
end

return MapVoteController
