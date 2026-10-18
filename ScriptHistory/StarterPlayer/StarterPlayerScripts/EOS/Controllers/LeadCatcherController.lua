--!strict
-- LeadCatcherController (HOS-LEAD-001, 17 Oct): the paid Lead Catcher card, bottom right in the lobby wait.
-- The cards are roblox-ui-maker templates (ReplicatedStorage.LeadCatcherUITemplates, from UI/build.py lead_card /
-- s_lead_templates, export workspace ui_lead/), one per viewer state:
--   LeadCardBuy      slot free: BE LEAD CATCHER + Robux price (BtnBuy asks the server; the SERVER opens the prompt)
--   LeadCardPending  you hold the 30 s reservation while your Roblox prompt is open (TimerText counts down)
--   LeadCardTaken    someone else has it (HolderText = their name), greyed, no button
--   LeadCardYours    you hold a pass: you're Lead Catcher next match
-- Driven only by LeadCatcherService's replicated attributes (ReplicatedStorage LeadCatcherState / Owner /
-- OwnerName / Price / Until). Hidden while the slot is closed (a match is on) or off (no product yet).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Fit = require(script.Parent.Fit)

local LeadCatcherController = {}

local player = Players.LocalPlayer
local TEMPLATE = { buy = "LeadCardBuy", pending = "LeadCardPending", taken = "LeadCardTaken", yours = "LeadCardYours" }
-- HOS-MAPVOTE-001 (Hunter: the card was way too big on the vote): while the NEXT MAP vote shows, a small
-- 210 x 62 button from MapVoteUITemplates sits centred under the panel instead (key hint R, like his reference)
local DOCKED = { buy = "LeadBtnBuy", pending = "LeadBtnBuying", taken = "LeadBtnTaken", yours = "LeadBtnYours" }
local DOCK_KEY = Enum.KeyCode.R

local gui: ScreenGui? = nil
local holder: Frame? = nil
local shown: string? = nil
local shownKey: string? = nil
local card: GuiObject? = nil
local asking = false

local function voteController(): any
	local v = script.Parent:FindFirstChild("MapVoteController")
	return v and require(v) :: any
end

local function docked(): boolean
	local v = voteController()
	return v ~= nil and v.isShown()
end

local function templates(): Instance?
	if docked() then
		local v = script.Parent:FindFirstChild("MapVoteController")
		return ReplicatedStorage:FindFirstChild("MapVoteUITemplates") or (v and v:FindFirstChild("Templates"))
	end
	return ReplicatedStorage:FindFirstChild("LeadCatcherUITemplates") or script:FindFirstChild("Templates")
end

-- a label and its Shadow twin (the exporter's drop shadow) always carry the same text
local function setText(root: Instance, name: string, text: string)
	for _, n in ipairs({ name, name .. "Shadow" }) do
		local l = root:FindFirstChild(n, true)
		if l and l:IsA("TextLabel") then
			l.Text = text
		end
	end
end

local function viewState(): string?
	local state = ReplicatedStorage:GetAttribute("LeadCatcherState")
	local mine = ReplicatedStorage:GetAttribute("LeadCatcherOwner") == player.UserId
	if state == "free" then
		return "buy"
	elseif state == "reserved" then
		return if mine then "pending" else "taken"
	elseif state == "taken" then
		return if mine then "yours" else "taken"
	end
	return nil -- closed / off / not set
end

local function ask()
	if asking then
		return
	end
	asking = true
	local fn = ReplicatedStorage:WaitForChild("EOS_Remotes"):FindFirstChild("RequestLeadCatcher") :: RemoteFunction?
	if fn then
		pcall(fn.InvokeServer, fn) -- the server answers through the attributes (and opens the prompt itself)
	end
	task.delay(1, function()
		asking = false
	end)
end

local function fill()
	local c = card
	if not c then
		return
	end
	setText(c, "PriceText", tostring(ReplicatedStorage:GetAttribute("LeadCatcherPrice") or ""))
	setText(c, "HolderText", tostring(ReplicatedStorage:GetAttribute("LeadCatcherOwnerName") or "Someone"))
	if shown == "taken" and docked() then
		setText(c, "Line2", tostring(ReplicatedStorage:GetAttribute("LeadCatcherOwnerName") or "Someone"))
	end
end

local function refresh()
	local h = holder
	if not h then
		return
	end
	-- HOS-MAPVOTE-002 (Hunter: no card bottom right unless it's the map vote): Lead Catcher only shows as the small
	-- button under the open NEXT MAP vote; the vote already hides itself for AFK players
	local dock = docked()
	local state = if dock then viewState() else nil
	local want = state and (state .. (if dock then ":dock" else ""))
	if want ~= shownKey then
		shownKey = want
		if card then
			card:Destroy()
			card = nil
		end
		shown = state
		local folder = templates()
		local t = state and folder and folder:FindFirstChild((if dock then DOCKED else TEMPLATE)[state])
		if t and t:IsA("GuiObject") then
			local c = t:Clone()
			c.Position = UDim2.fromOffset(0, 0)
			c.Visible = true
			c.Parent = h
			card = c
			h.Size = UDim2.fromOffset(t.Size.X.Offset, t.Size.Y.Offset)
			local b = c:FindFirstChild("BtnBuy", true) or c:FindFirstChild("Btn", true)
			if state == "buy" and b and b:IsA("GuiButton") then
				b.Activated:Connect(ask)
			end
		end
	end
	h.Visible = card ~= nil
	fill()
end

local function place()
	local h = holder
	if not h then
		return
	end
	-- HOS-MAPVOTE-001: while the NEXT MAP vote shows, the card docks centred under it (Hunter's reference)
	local vote = script.Parent:FindFirstChild("MapVoteController")
	if vote and (require(vote) :: any).isShown() then
		Fit.setDesignPosition(h, Vector2.new(0.5, 0), (require(vote) :: any).dockPosition())
		return
	end
	-- phones: above Roblox's jump button (bottom right); elsewhere in the corner, clear of ability + dash
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	Fit.setDesignPosition(h, Vector2.new(1, 1), UDim2.new(1, -40, 1, if touch then -330 else -104))
end

function LeadCatcherController.init()
	local g = Instance.new("ScreenGui")
	g.Name = "LeadCatcherHUD"
	g.ResetOnSpawn = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = 4
	local h = Instance.new("Frame")
	h.Name = "LeadCatcher"
	h.BackgroundTransparency = 1
	h.Size = UDim2.fromOffset(580, 176)
	h.Visible = false
	local s = Instance.new("UIScale")
	s.Name = "Fit"
	s.Parent = h
	h.Parent = g
	g.Parent = player:WaitForChild("PlayerGui")
	gui, holder = g, h
	place()
	Fit.track(g)
	UserInputService.LastInputTypeChanged:Connect(place)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == DOCK_KEY and shown == "buy" and docked() then
			ask() -- R, like the reference's "Become Lead Catcher" key hint
		end
	end)
	-- HOS-MAPVOTE-001: the NEXT MAP vote panel (started here, so ClientMain keeps one line for both)
	local vote = script.Parent:FindFirstChild("MapVoteController")
	if vote then
		local MapVote = require(vote) :: any
		task.spawn(MapVote.init)
		MapVote.ShownChanged:Connect(function()
			place()
			refresh()
		end)
	end
	for _, a in ipairs({ "LeadCatcherState", "LeadCatcherOwner", "LeadCatcherOwnerName", "LeadCatcherPrice" }) do
		ReplicatedStorage:GetAttributeChangedSignal(a):Connect(refresh)
	end
	refresh()
	-- the 30 s hold counts down on the buyer's card
	RunService.Heartbeat:Connect(function()
		local c = card
		if shown ~= "pending" or not c then
			return
		end
		local untilT = ReplicatedStorage:GetAttribute("LeadCatcherUntil")
		local left = if type(untilT) == "number" then math.max(0, math.ceil(untilT - workspace:GetServerTimeNow())) else 0
		setText(c, "TimerText", ("%d:%02d"):format(left // 60, left % 60))
	end)
end

return LeadCatcherController
