-- TopbarHover (HOS-TOPBAR-001, 17 Oct): the five lobby top-bar buttons (Quests, Incubator; Servers, Stats,
-- Settings) rest as icon squares and grow out to the full pill while the mouse is over them (or a gamepad
-- selects them). TopLeft grows rightward, TopRight leftward; neighbours slide to make room. Touch screens
-- stay square. Design: ui/build.py s_topbar_states (docs/topbar/topbar_states.jpg).
-- Which panel opens and when the groups hide are untouched (UIController). The pill art is a stretched
-- raster, so it is switched to 9-slice here to keep its ends crisp at any width. The buttons are juiced
-- (UI.juicy): their rest spot lives in the JuiceRest attribute, which this keeps current.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local TopbarHover = {}

local player = Players.LocalPlayer
local SQ = 66 -- collapsed plate width: a square behind the 72 px icon
local INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SETTLE = 0.4 -- keep laying out this long after a change (outlasts juicy's 0.14 s hover tween)
local LIFT = -3 -- juicy's hover lift
local CAP = 16 -- 9-slice end caps in image px (the art is exported at 2x)
local GROUPS = {
	{ group = "TopLeft", grow = "right", names = { "QuestsButton", "IncubatorButton" } },
	{ group = "TopRight", grow = "left", names = { "ServersButton", "StatsButton", "SettingsButton" } },
}

type Btn = {
	b: GuiButton, plate: GuiObject, art: ImageLabel?, badge: GuiObject?,
	labels: { { o: Instance, prop: string, rest: number, x: UDim? } },
	full: number, extra: number, gap: number, top: number, h: number,
	t: NumberValue, hovered: boolean, tw: Tween?,
}

local function touchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		or UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

local function build(holder: Instance, names: { string }): { Btn }?
	local list: { Btn } = {}
	for _, n in names do
		local b = holder:FindFirstChild(n)
		if not (b and b:IsA("GuiButton")) then return nil end
		local plate: GuiObject? = nil
		for _, c in b:GetChildren() do
			if c:IsA("GuiObject") and c.Name:sub(1, 3) == "Btn" then plate = c end
		end
		if not plate then return nil end
		local art = plate:FindFirstChild("Art") :: ImageLabel?
		local labels = {}
		for _, ln in { "Label", "LabelShadow" } do
			local l = plate:FindFirstChild(ln)
			if l and l:IsA("TextLabel") then
				table.insert(labels, { o = l, prop = "TextTransparency", rest = l.TextTransparency, x = l.Position.X })
				for _, s in l:GetChildren() do
					if s:IsA("UIStroke") then table.insert(labels, { o = s, prop = "Transparency", rest = s.Transparency }) end
				end
			end
		end
		local w, h = b.Size.X.Offset, b.Size.Y.Offset
		local left = b.Position.X.Offset - b.AnchorPoint.X * w
		local top = b.Position.Y.Offset - b.AnchorPoint.Y * h
		local full = plate.Size.X.Offset
		local t = Instance.new("NumberValue")
		t.Value = 0
		table.insert(list, {
			b = b, plate = plate, art = art, badge = b:FindFirstChild("Badge") :: GuiObject?, labels = labels,
			full = full, extra = w - (plate.Position.X.Offset + full), gap = 0, top = top, h = h, t = t, hovered = false,
			left = left, w = w,
		} :: any)
	end
	for i = 1, #list - 1 do -- the export's spacing between neighbours (Quests' badge overhangs Incubator)
		local a, c = list[i] :: any, list[i + 1] :: any
		list[i].gap = c.left - (a.left + a.w)
	end
	return list
end

local function prepare(x: Btn, grow: string)
	local plate, art = x.plate, x.art
	plate.ClipsDescendants = true -- the label is revealed by the growing plate
	if art then
		plate.Size = UDim2.fromOffset(plate.Size.X.Offset, math.max(plate.Size.Y.Offset, art.Size.Y.Offset)) -- keep the art's drop edge inside the clip
		art.ScaleType = Enum.ScaleType.Slice
		art.SliceCenter = Rect.new(CAP, CAP, art.Size.X.Offset * 2 - CAP, art.Size.Y.Offset * 2 - CAP)
		art.SliceScale = 0.5
	end
	x.b.AnchorPoint = Vector2.new(if grow == "right" then 0 else 1, 0.5) -- juicy scales about this edge too
end

local function apply(list: { Btn }, grow: string, origin: number)
	local pos = origin
	local n = #list
	for k = 1, n do
		local i = if grow == "right" then k else n + 1 - k
		local x = list[i]
		local t = x.t.Value
		local pw = math.floor(SQ + (x.full - SQ) * t + 0.5)
		local bw = x.plate.Position.X.Offset + pw + x.extra
		x.plate.Size = UDim2.fromOffset(pw, x.plate.Size.Y.Offset)
		if x.art then x.art.Size = UDim2.fromOffset(pw, x.art.Size.Y.Offset) end
		if x.badge then x.badge.Position = UDim2.fromOffset(x.plate.Position.X.Offset + pw - 16, x.badge.Position.Y.Offset) end
		local a = math.clamp((t - 0.35) / 0.65, 0, 1) -- the label comes in after the width
		for _, l in x.labels do
			(l.o :: any)[l.prop] = 1 - (1 - l.rest) * a
			if l.x then
				local o = l.o :: GuiObject
				o.Position = UDim2.new(l.x.Scale, l.x.Offset - 8 * (1 - a), o.Position.Y.Scale, o.Position.Y.Offset)
			end
		end
		x.b.Size = UDim2.fromOffset(bw, x.h)
		local edge = pos
		local rest = UDim2.fromOffset(edge, x.top + x.h / 2)
		x.b:SetAttribute("JuiceRest", rest)
		x.b.Position = rest + UDim2.fromOffset(0, if x.hovered then LIFT else 0)
		if grow == "right" then
			pos = edge + bw + x.gap
		else
			local prev = list[i - 1]
			pos = edge - bw - (if prev then prev.gap else 0)
		end
	end
end

function TopbarHover.init()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("EOSUI", 30)
	local root = gui and gui:WaitForChild("Root", 10)
	local hud = root and root:WaitForChild("HUD", 10)
	if not hud then
		warn("[TopbarHover] PlayerGui.EOSUI.Root.HUD missing: top bar stays as exported")
		return
	end
	-- UI.juicy re-centres each button once; wait for it so our anchor isn't overwritten after
	local t0 = os.clock()
	while os.clock() - t0 < 5 do
		local q = hud:FindFirstChild("TopLeft") and hud.TopLeft:FindFirstChild("QuestsButton")
		if q and q:FindFirstChild("JuiceScale") then break end
		task.wait(0.1)
	end

	local settleUntil = 0
	local sets = {}
	for _, g in GROUPS do
		local holder = hud:FindFirstChild(g.group)
		local list = holder and build(holder, g.names)
		if not list then
			warn("[TopbarHover] " .. g.group .. " buttons not as exported: left as they are")
			continue
		end
		local first, last = (list[1] :: any), (list[#list] :: any)
		local origin = if g.grow == "right" then first.left else last.left + last.w
		for _, x in list do
			prepare(x, g.grow)
			local function open(on: boolean)
				if on and touchOnly() then return end
				x.hovered = on
				if x.tw then x.tw:Cancel() end
				x.tw = TweenService:Create(x.t, INFO, { Value = if on then 1 else 0 })
				x.tw:Play()
				settleUntil = os.clock() + INFO.Time + SETTLE
			end
			x.b.MouseEnter:Connect(function() open(true) end)
			x.b.MouseLeave:Connect(function() open(false) end)
			x.b.SelectionGained:Connect(function() open(true) end)
			x.b.SelectionLost:Connect(function() open(false) end)
		end
		table.insert(sets, { list = list, grow = g.grow, origin = origin })
		apply(list, g.grow, origin)
	end
	if #sets == 0 then return end
	-- the HUD hides mid-hover (a match starts): MouseLeave never comes, so fold everything now
	hud:GetPropertyChangedSignal("Visible"):Connect(function()
		for _, s in sets do
			for _, x in s.list do
				x.hovered = false
				if x.tw then x.tw:Cancel() end
				x.t.Value = 0
			end
		end
		settleUntil = os.clock() + SETTLE
	end)
	settleUntil = os.clock() + SETTLE
	RunService.RenderStepped:Connect(function()
		if os.clock() > settleUntil then return end
		for _, s in sets do apply(s.list, s.grow, s.origin) end
	end)
end

return TopbarHover
