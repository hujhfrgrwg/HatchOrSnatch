--!strict
-- Toasts: a small toast queue. Clone an approved template (designed in HTML first), never build
-- the look here. Dedupes identical text (restart + pulse instead of stacking), picks a duration
-- from length, caps the stack, and closes up the gap when one leaves.

local TweenService = game:GetService("TweenService")

local Toasts = {}

local MAX_STACK = 4
local GAP = 8
local SHORT, LONG, LONG_CHARS = 3.5, 6, 50

type Entry = { frame: Frame, text: string, token: number }
local stack: { Entry } = {}
local container: Frame
local template: Frame

function Toasts.init(parent: Frame, toastTemplate: Frame)
	container, template = parent, toastTemplate
end

local function relayout()
	local y = 0
	for _, e in stack do
		TweenService:Create(e.frame, TweenInfo.new(0.2), { Position = UDim2.new(0.5, 0, 0, y) }):Play()
		y += e.frame.Size.Y.Offset + GAP -- template height is in offset (design px under a UIScale)
	end
end

local function remove(e: Entry)
	local i = table.find(stack, e)
	if not i then return end
	table.remove(stack, i)
	local t = TweenService:Create(e.frame, TweenInfo.new(0.15), { Size = UDim2.new(e.frame.Size.X, UDim.new(0, 0)) })
	t.Completed:Once(function() e.frame:Destroy() end)
	t:Play()
	relayout()
end

local function arm(e: Entry, duration: number)
	e.token += 1
	local my = e.token
	-- restart the countdown strip too, or it shows empty while the toast stays up
	local strip = e.frame:FindFirstChild("Time") :: Frame?
	if strip then
		strip.Size = UDim2.fromScale(1, strip.Size.Y.Scale)
		TweenService:Create(strip, TweenInfo.new(duration, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(0, strip.Size.Y.Scale) }):Play()
	end
	task.delay(duration, function()
		if e.token == my then remove(e) end
	end)
end

export type Opts = { kind: string?, icon: string?, duration: number? }

function Toasts.show(text: string, opts: Opts?)
	local o = opts or {}
	local duration = o.duration or (if #text > LONG_CHARS then LONG else SHORT)

	-- dedupe: same text already up -> pulse and restart its timer
	for _, e in stack do
		if e.text == text then
			local s = e.frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", e.frame)
			s.Scale = 1.12
			TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			arm(e, duration)
			return
		end
	end

	if #stack >= MAX_STACK then
		remove(stack[1]) -- oldest drops
	end

	local f = template:Clone()
	f.AnchorPoint = Vector2.new(0.5, 0)
	local label = f:FindFirstChild("Text", true) :: TextLabel?
	if label then label.Text = text end
	f:SetAttribute("Kind", o.kind or "info") -- the template's own script colours the strip by kind
	f.Parent = container
	local e: Entry = { frame = f, text = text, token = 0 }
	table.insert(stack, e)
	relayout()

	local s = Instance.new("UIScale")
	s.Scale = 0.6
	s.Parent = f
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	arm(e, duration)
end

-- Burst merging: call this instead of show() for events that fire many times a second.
-- At most one toast per `window` seconds, carrying the running total.
local merged: { [string]: { total: number, last: number } } = {}
function Toasts.merged(key: string, amount: number, fmt: (number) -> string, window: number)
	local m = merged[key] or { total = 0, last = 0 }
	merged[key] = m
	m.total += amount
	if os.clock() - m.last >= window then
		m.last = os.clock()
		Toasts.show(fmt(m.total), { duration = LONG })
		m.total = 0
	end
end

return Toasts
