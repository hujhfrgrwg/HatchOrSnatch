--!strict
-- UI: the runtime module for the imported ScreenGui (skeleton; extend per game, keep the rules).
-- Lives in <luau_out>/client/UI.luau; Builder copies it into StarterGui.<Gui> (Client folder).
-- ONE source of truth: edit the file on disk, re-bundle, and run scripts/check_copies.py.
--
-- From any LocalScript:
--   local UI = require(Players.LocalPlayer.PlayerGui:WaitForChild("HeroChickenUI"):WaitForChild("UI"))
--   UI.open("Shop") / UI.close() / UI.toggle("Shop") / UI.back()   -- close returns to the previous screen
--   UI.current() -> name?   UI.anyOpen() -> bool  (world click handlers: `if UI.anyOpen() then return end`)
--   UI.setText(scope, "CashText", "1,250")                         -- also updates CashTextShadow
--   UI.countTo("cash", 1250, scope, "CashText", NumberFormat.cash)  -- count-up tween, one per key
--   UI.setGroupHidden("Goal", true)                                 -- hide a HUD group (e.g. under a modal)
--   UI.popup(function() ... end, "offer")                           -- queued, suppressed while busy
--   UI.suppress("tutorial", true)                                   -- no unsolicited popups while set
--   UI.Action:Connect(function(name, screen, button) end)           -- every button press
--   UI.PageChanged:Connect(function(name?) end)                     -- screen opened (name) / closed (nil)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local UI = {}

local actionEvent = Instance.new("BindableEvent")
UI.Action = actionEvent.Event
local pageEvent = Instance.new("BindableEvent")
UI.PageChanged = pageEvent.Event
local openedEvt = Instance.new("BindableEvent")
UI.Opened = openedEvt

local gui: ScreenGui
local root: Frame
local dim: Frame
local screens: { [string]: Frame } = {}
local current: string? = nil
local history: { string } = {}
local inited = false
local conns: { RBXScriptConnection } = {}
local function keep(c: RBXScriptConnection) table.insert(conns, c) end

local OPEN = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPRING = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- HUD groups that stay visible while a panel is open (everything else on HUD screens hides)
UI.keepWithPanel = {}

---------------------------------------------------------------- sounds
-- Fill with audio the game's owner can use (probe first: audio from another creator plays as
-- silence with no error). Engine built-ins under rbxasset://sounds/ also work for prototypes.
local SOUND_IDS: { [string]: string } = {
	hover = "", -- e.g. "rbxassetid://<your hover tick>"
	click = "",
	purchase = "",
	reward = "",
}
local SFX: { [string]: Sound } = {}
local function makeSounds()
	for name, id in SOUND_IDS do
		if id ~= "" then
			local s = Instance.new("Sound")
			s.Name = "UISfx_" .. name
			s.SoundId = id
			s.Volume = if name == "hover" then 0.35 else 0.6
			-- edit-mode harness runs must not save these into the place
			if not RunService:IsRunning() then s.Archivable = false end
			s.Parent = SoundService
			SFX[name] = s
		end
	end
end
function UI.play(name: string)
	local s = SFX[name]
	if s then SoundService:PlayLocalSound(s) end
end

---------------------------------------------------------------- text
local function fitLabel(d: TextLabel)
	-- the cap is in SCREEN px: design size x the CURRENT FitScale (else text shrinks above 1080p). Re-applied on
	-- every set: FitScale can still be tiny when the first text arrives at join, freezing the label at ~11 px.
	local c = d:FindFirstChild("UIFitCap") :: UITextSizeConstraint?
	if not c then
		d:SetAttribute("UIFit", true)
		d:SetAttribute("UIDesignSize", d.TextSize)
		c = Instance.new("UITextSizeConstraint")
		c.Name = "UIFitCap"
		c.Parent = d
		d.TextScaled = true
	end
	local fs = root and root:FindFirstChild("FitScale") :: UIScale?
	local design = d:GetAttribute("UIDesignSize") or d.TextSize
	c.MaxTextSize = math.max(8, math.floor(design * (if fs then fs.Scale else 1)))
	c.MinTextSize = math.min(14, c.MaxTextSize)
end
-- set a named label and EVERY "<name>Shadow" twin under scope (the drop shadow is a second label)
function UI.setText(scope: Instance, name: string, text: string)
	for _, d in scope:GetDescendants() do
		if d:IsA("TextLabel") and (d.Name == name or d.Name == name .. "Shadow") then
			fitLabel(d)
			d.Text = text
		end
	end
end

-- count-up: one tween per key; a new value cancels the old tween and the label always lands on
-- the exact target (overlapping tweens fought and the slower one left a stale number)
local shown: { [string]: number } = {}
local running: { [string]: Tween } = {}
function UI.countTo(key: string, target: number, scope: Instance, label: string, fmt: (number) -> string)
	local prev = running[key]
	if prev then prev:Cancel() end
	local nv = Instance.new("NumberValue")
	nv.Value = shown[key] or target
	nv.Changed:Connect(function(v) UI.setText(scope, label, fmt(v)) end)
	local t = TweenService:Create(nv, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Value = target })
	running[key] = t
	t.Completed:Once(function(state)
		if running[key] == t then running[key] = nil end
		if state ~= Enum.PlaybackState.Cancelled then UI.setText(scope, label, fmt(target)) end
		nv:Destroy()
	end)
	t:Play()
	shown[key] = target
end

---------------------------------------------------------------- screens
-- Premium open: the scrim fades in, the panel group pops from 0.86 with a Back ease, its banner slides
-- in from the left a beat later, the close X spins in last. Rest positions live in "RestPos" attributes.
-- Roblox applies only ONE UIScale per object: reuse whatever UIScale is there (Builder's BigText,
-- juicy's JuiceScale) and remember its resting value in "Base" so tweens return to it.
local function scaleOf(g: GuiObject, name: string): UIScale
	local s = g:FindFirstChild(name) :: UIScale?
	if not s then
		for _, c in g:GetChildren() do
			if c:IsA("UIScale") then
				s = c
				break
			end
		end
	end
	if s then
		if s:GetAttribute("Base") == nil then s:SetAttribute("Base", s.Scale) end
	else
		local ns = Instance.new("UIScale")
		ns.Name = name
		ns:SetAttribute("Base", 1)
		ns.Parent = g
		s = ns
	end
	return s :: UIScale
end
local function base(s: UIScale): number
	return (s:GetAttribute("Base") :: number?) or 1
end
local function rest(g: GuiObject): UDim2
	local r = g:GetAttribute("RestPos") :: UDim2?
	if not r then
		g:SetAttribute("RestPos", g.Position)
		r = g.Position
	end
	return r :: UDim2
end
local function fadeDim(frame: GuiObject, on: boolean)
	local d = frame:FindFirstChild("Dim")
	local f = d and d:FindFirstChild("F") :: Frame?
	if not f then return end
	local base = f:GetAttribute("BaseT") :: number?
	if base == nil then
		base = f.BackgroundTransparency
		f:SetAttribute("BaseT", base)
	end
	if on then
		f.BackgroundTransparency = 1
		TweenService:Create(f, FADE, { BackgroundTransparency = base }):Play()
	else
		TweenService:Create(f, CLOSE, { BackgroundTransparency = 1 }):Play()
	end
end
local function popIn(frame: GuiObject)
	fadeDim(frame, true)
	for _, g in frame:GetChildren() do
		if g:IsA("GuiObject") and g.Name ~= "Dim" then
			local ps = scaleOf(g, "PopScale")
			ps.Scale = 0.86 * base(ps)
			TweenService:Create(ps, OPEN, { Scale = base(ps) }):Play()
			local banner = g:FindFirstChild("Banner") :: GuiObject?
			if banner and banner:IsA("GuiObject") then
				local at = rest(banner)
				banner.Position = at - UDim2.fromOffset(90, 0)
				TweenService:Create(banner, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.06),
					{ Position = at }):Play()
			end
			local x = g:FindFirstChild("CloseButton") :: GuiObject?
			if x and x:IsA("GuiObject") then
				local xs = scaleOf(x, "SpinScale")
				xs.Scale = 0
				local rot = x:GetAttribute("RestRot") :: number?
				if rot == nil then
					rot = x.Rotation
					x:SetAttribute("RestRot", rot)
				end
				x.Rotation = (rot :: number) - 120
				local ti = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.14)
				TweenService:Create(xs, ti, { Scale = base(xs) }):Play()
				TweenService:Create(x, ti, { Rotation = rot }):Play()
			end
		end
	end
	openedEvt:Fire(frame.Name)
end
local function popOut(frame: GuiObject, done: () -> ())
	fadeDim(frame, false)
	local last: Tween? = nil
	for _, g in frame:GetChildren() do
		local s = if g:IsA("GuiObject") and g.Name ~= "Dim" then scaleOf(g, "PopScale") else nil
		if s then
			local t = TweenService:Create(s, CLOSE, { Scale = 0.82 * base(s) })
			t:Play()
			last = t
		end
	end
	if last then last.Completed:Once(done) else done() end
end

---------------------------------------------------------------- motion helpers (used by game code)
-- quick scale punch on any GuiObject (badge, wallet, ability card)
function UI.pulse(g: GuiObject, amount: number?)
	local s = scaleOf(g, "PulseScale")
	s.Scale = base(s) * (1 + (amount or 0.12))
	TweenService:Create(s, TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = base(s) }):Play()
end
-- pop a thing in from nothing (reveals, toasts, podium)
function UI.popFrom(g: GuiObject, from: number?, delay: number?)
	local s = scaleOf(g, "PulseScale")
	s.Scale = base(s) * (from or 0)
	TweenService:Create(s, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay or 0), { Scale = base(s) }):Play()
end
-- slide a thing in from an offset to its rest position
function UI.slideIn(g: GuiObject, dx: number, dy: number, delay: number?, time: number?)
	local at = rest(g)
	g.Position = at + UDim2.fromOffset(dx, dy)
	TweenService:Create(g, TweenInfo.new(time or 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, delay or 0), { Position = at }):Play()
end
-- left/right shake (refused action, egg about to hatch)
function UI.shake(g: GuiObject, mag: number?, dur: number?)
	local at = rest(g)
	local m, t0 = mag or 8, os.clock()
	local c: RBXScriptConnection
	c = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > (dur or 0.35) or not g.Parent then
			g.Position = at
			c:Disconnect()
			return
		end
		local k = 1 - t / (dur or 0.35)
		g.Position = at + UDim2.fromOffset(math.sin(t * 60) * m * k, 0)
	end)
end
-- slow continuous spin (light rays) while the object is on screen; one loop per object
local spinning: { [GuiObject]: number } = {}
function UI.spin(g: GuiObject, degPerSec: number)
	if spinning[g] then spinning[g] = degPerSec return end
	spinning[g] = degPerSec
	local c: RBXScriptConnection
	c = RunService.RenderStepped:Connect(function(dt)
		if not g.Parent then
			spinning[g] = nil
			c:Disconnect()
			return
		end
		if g.Visible and g:FindFirstAncestorWhichIsA("ScreenGui") and (g:FindFirstAncestorWhichIsA("ScreenGui") :: ScreenGui).Enabled then
			g.Rotation = (g.Rotation + (spinning[g] or 0) * dt) % 360
		end
	end)
end
-- gentle breathing scale loop (ready badges, claimable buttons); stop with UI.breathe(g, false)
local breathing: { [GuiObject]: Tween } = {}
function UI.breathe(g: GuiObject, on: boolean)
	local cur = breathing[g]
	if on and cur then return end
	if cur then
		cur:Cancel()
		breathing[g] = nil
		local bs = scaleOf(g, "BreatheScale")
		bs.Scale = base(bs)
	end
	if on then
		local s = scaleOf(g, "BreatheScale")
		s.Scale = base(s)
		local t = TweenService:Create(s, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = base(s) * 1.08 })
		breathing[g] = t
		t:Play()
	end
end
-- re-capture a moved element's rest position (call after code positions something)
function UI.setRest(g: GuiObject)
	g:SetAttribute("RestPos", g.Position)
end

local function setDim(alpha: number)
	if alpha > 0 then
		dim.Visible = true
		TweenService:Create(dim, FADE, { BackgroundTransparency = 1 - alpha }):Play()
	else
		local t = TweenService:Create(dim, FADE, { BackgroundTransparency = 1 })
		t.Completed:Once(function()
			if dim.BackgroundTransparency >= 0.99 then dim.Visible = false end
		end)
		t:Play()
	end
end

local hiddenGroups: { [string]: boolean } = {}
function UI.setGroupHidden(name: string, on: boolean)
	hiddenGroups[name] = on or nil
	UI.refreshHud()
end
function UI.refreshHud()
	for _, s in screens do
		if s:GetAttribute("Hud") then
			for _, g in s:GetChildren() do
				if g:IsA("GuiObject") then
					g.Visible = not hiddenGroups[g.Name] and (current == nil or UI.keepWithPanel[g.Name] == true)
				end
			end
		end
	end
end

function UI.current(): string?
	return current
end
function UI.isOpen(name: string): boolean
	return current == name
end
function UI.anyOpen(): boolean
	return current ~= nil
end

function UI.open(name: string, opts: { keepHistory: boolean? }?)
	local s = screens[name]
	assert(s, "no screen " .. name)
	if current == name then return end
	if current then
		if opts and opts.keepHistory then table.insert(history, current) end
		screens[current].Visible = false
	end
	current = name
	s.Visible = true
	popIn(s)
	setDim((s:GetAttribute("Dim") :: number?) or 0)
	UI.refreshHud()
	pageEvent:Fire(name)
end

-- every close path (X button, Escape, gamepad B, scrim, code) goes through here
function UI.close()
	local name = current
	if not name then return end
	current = nil
	local s = screens[name]
	popOut(s, function()
		if current ~= name then s.Visible = false end
	end)
	local back = table.remove(history)
	if back then
		UI.open(back) -- return to the screen the player came from
		return
	end
	setDim(0)
	UI.refreshHud()
	pageEvent:Fire(nil)
end
function UI.toggle(name: string)
	if current == name then UI.close() else UI.open(name) end
end
function UI.back()
	UI.close()
end

---------------------------------------------------------------- buttons
local function centreAnchor(b: GuiObject)
	if b.AnchorPoint == Vector2.new(0.5, 0.5) then return end
	local p, s = b.Position, b.Size
	b.Position = p + UDim2.new(s.X.Scale * (0.5 - b.AnchorPoint.X), s.X.Offset * (0.5 - b.AnchorPoint.X),
		s.Y.Scale * (0.5 - b.AnchorPoint.Y), s.Y.Offset * (0.5 - b.AnchorPoint.Y))
	b.AnchorPoint = Vector2.new(0.5, 0.5)
end
local function screenOf(b: Instance): string
	local p: Instance? = b
	while p and p.Parent ~= root do p = p.Parent end
	return if p then p.Name else "?"
end

-- hover grow + lift + sound, press sink, release spring. Rest position lives in the JuiceRest
-- attribute: code that moves a button must update it (UIKit.rest) or hover snaps it back.
local wired: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any
function UI.juicy(b: GuiButton)
	-- tracked per INSTANCE (not an attribute): a clone of a juiced prototype copies attributes and the
	-- JuiceScale child but none of the connections, and must be wired again
	if wired[b] then return end
	wired[b] = true
	local stale = b:FindFirstChild("JuiceScale")
	if stale then stale:Destroy() end
	centreAnchor(b)
	b:SetAttribute("JuiceRest", b.Position)
	local sc = Instance.new("UIScale")
	sc.Name = "JuiceScale"
	sc:SetAttribute("Base", 1)
	sc.Parent = b
	local hovered, held = false, false
	local lift = if b.Name == "CloseButton" then 1.12 else 1.06
	local function to(info: TweenInfo, s: number, dy: number)
		TweenService:Create(sc, info, { Scale = s }):Play()
		local at = (b:GetAttribute("JuiceRest") :: UDim2?) or b.Position
		TweenService:Create(b, info, { Position = at + UDim2.fromOffset(0, dy) }):Play()
	end
	b.MouseEnter:Connect(function()
		hovered = true
		if not held then
			UI.play("hover")
			to(HOVER, lift, -3)
		end
	end)
	b.MouseLeave:Connect(function()
		hovered, held = false, false
		to(HOVER, 1, 0)
	end)
	b.MouseButton1Down:Connect(function()
		held = true
		to(PRESS, 0.92, 4)
	end)
	b.MouseButton1Up:Connect(function()
		if not held then return end
		held = false
		to(SPRING, if hovered then lift else 1, if hovered then -3 else 0)
	end)
	-- tabs and filter chips (a dual's On/Off halves, or the button itself) swipe instead of click
	local function isTab(x: Instance?): boolean
		return x ~= nil and (x.Name:match("^Tab") ~= nil or x.Name:match("^Filter") ~= nil)
	end
	local tabby = isTab(b) or ((b.Name == "On" or b.Name == "Off") and isTab(b.Parent))
	b.Activated:Connect(function()
		UI.play(if tabby then "tab" else "click")
		local opens = b:GetAttribute("Opens") :: string?
		if b.Name == "CloseButton" then
			actionEvent:Fire("CloseButton", screenOf(b), b) -- listeners run first (e.g. "collect on close")
			UI.close()
			return
		elseif opens and screens[opens] then
			UI.toggle(opens)
		end
		actionEvent:Fire(b.Name, screenOf(b), b)
	end)
end

---------------------------------------------------------------- popups (unsolicited offers, celebrations)
-- Queue so two never overlap. Earned celebrations ("reward") always queue and show after the current
-- one (they are not held back by suppress(); call them when the moment is right). Unsolicited offers
-- ("offer") are DROPPED while suppressed / a panel is open / too soon after join or the last offer.
local suppressed: { [string]: boolean } = {}
local queue: { () -> () } = {}
local busy = false
local lastOffer, joinedAt = -math.huge, os.clock()
UI.offerCooldown, UI.offerGraceAfterJoin = 180, 90
function UI.suppress(reason: string, on: boolean)
	suppressed[reason] = on or nil
end
local function blocked(): boolean
	return next(suppressed) ~= nil or current ~= nil
end
function UI.popupDone()
	busy = false
	local nxt = table.remove(queue, 1)
	if nxt then
		busy = true
		task.defer(nxt)
	end
end
-- kind "reward": always shown eventually (queued). kind "offer": dropped if blocked/too soon.
-- fn must call UI.popupDone() when its popup closes (also on failure paths).
function UI.popup(fn: () -> (), kind: string?)
	if kind == "offer" then
		if blocked() or busy or os.clock() - joinedAt < UI.offerGraceAfterJoin or os.clock() - lastOffer < UI.offerCooldown then return end
		lastOffer = os.clock()
	end
	if busy then
		table.insert(queue, fn)
		return
	end
	busy = true
	task.defer(fn)
end

---------------------------------------------------------------- fit to screen
local function fit()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	if vp.X < 2 or vp.Y < 2 then return end
	local W, H = root:GetAttribute("DesignW") :: number, root:GetAttribute("DesignH") :: number
	local s = math.min(vp.X / W, vp.Y / H)
	root.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
	local fs = root:FindFirstChild("FitScale") :: UIScale
	fs.Scale = s
	-- Roblox's top bar keeps its point size while the HUD scales down, so its buttons cover more of the design
	-- width on smaller windows. A top-corner group slides sideways to clear them and stays in the top row
	-- (Hunter, 16 Oct: Quests / Incubator belong beside the Roblox buttons, not under them), shrinking to
	-- no less than 75% so it stops short of the top-centre status. Only when even that won't fit does it
	-- drop below the bar. Design offsets are remembered in BaseX / BaseY.
	local inset = GuiService.TopbarInset
	local barH = if inset.Max.Y > 0 then inset.Max.Y / s + 8 else 0
	local rw = vp.X / s
	local leftEnd, rightStart = inset.Min.X / s, (if inset.Max.X > 0 then inset.Max.X else vp.X) / s
	local CENTRE_HALF = 228 -- the top-centre status keeps this much either side of the middle (a gap on a 1366 laptop)
	for _, sc in screens do
		for _, g in sc:GetChildren() do
			-- full-screen layers (each panel's Dim, sized by scale) are never top-corner groups: they stay put
			if g:IsA("GuiObject") and g.Position.Y.Scale == 0 and g.Size.X.Scale == 0 then
				local base = g:GetAttribute("BaseY") :: number?
				if base == nil then
					base = g.Position.Y.Offset
					g:SetAttribute("BaseY", base)
				end
				local baseX = g:GetAttribute("BaseX") :: number?
				if baseX == nil then
					baseX = g.Position.X.Offset
					g:SetAttribute("BaseX", baseX)
				end
				local w = g.Size.X.Offset
				local x0 = g.Position.X.Scale * rw + (baseX :: number) - g.AnchorPoint.X * w
				local x1 = x0 + w
				local y, dx, k = base :: number, 0, 1
				if y < barH and (x0 < leftEnd or x1 > rightStart) then
					local room, need
					if x0 < leftEnd then
						room = (rw / 2 - CENTRE_HALF) - (leftEnd + 10) -- from the Roblox buttons to the centre
						need = leftEnd + 10 - x0
					else
						room = (rightStart - 10) - (rw / 2 + CENTRE_HALF)
						need = -(x1 - (rightStart - 10))
					end
					local sc0 = g:FindFirstChildOfClass("UIScale")
					local canScale = sc0 == nil or sc0.Name == "InsetScale"
					if w <= room then
						dx = need
					elseif canScale and room >= w * 0.75 then
						k = room / w -- UIScale shrinks toward the AnchorPoint, so the cleared edge stays put
						dx = need
					else
						y = barH
					end
				end
				local is = g:FindFirstChild("InsetScale") :: UIScale?
				if k < 1 and not is then
					is = Instance.new("UIScale")
					is.Name = "InsetScale"
					is.Parent = g
				end
				if is then is.Scale = k end
				g.Position = UDim2.new(g.Position.X.Scale, (baseX :: number) + dx, 0, y)
			end
		end
	end
end

---------------------------------------------------------------- init
function UI.init(g: ScreenGui?): typeof(UI)
	if inited then return UI end
	inited = true
	gui = g or Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("HeroChickenUI") :: ScreenGui
	root = gui:WaitForChild("Root") :: Frame
	dim = root:WaitForChild("Dim") :: Frame
	if not root:GetAttribute("DesignW") then
		root:SetAttribute("DesignW", root.Size.X.Offset)
		root:SetAttribute("DesignH", root.Size.Y.Offset)
	end
	for _, s in root:GetChildren() do
		if s:IsA("Frame") and s.Name ~= "Dim" then screens[s.Name] = s end
	end
	makeSounds()
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d:GetAttribute("Button") then UI.juicy(d) end
	end
	keep(dim.InputBegan:Connect(function(input)
		-- tapping the scrim closes the panel (and never reaches the world)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if current then actionEvent:Fire("CloseButton", current, nil); UI.close() end
		end
	end))
	UI.refreshHud()
	fit()
	local function hook()
		local cam = workspace.CurrentCamera
		if cam then keep(cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)) end
		fit()
	end
	keep(GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fit))
	keep(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook))
	hook()
	keep(UserInputService.InputBegan:Connect(function(input, processed)
		-- Escape is bound to the Roblox menu: it can arrive with processed = true, so check it BEFORE
		-- the processed early-return (but never while the player is typing in a TextBox)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if current and not UserInputService:GetFocusedTextBox() then
				actionEvent:Fire("CloseButton", current, nil)
				UI.close()
			end
			return
		end
		if processed then return end
		-- game hotkeys go here; respect modes (no hotbar keys while a panel/battle owns the screen)
	end))
	keep(GuiService.MenuOpened:Connect(function()
		if current then UI.close() end
	end))
	return UI
end

-- disconnect everything init() hooked (used by the edit-mode harness before destroying its clone)
function UI.destroy()
	for _, c in conns do c:Disconnect() end
	table.clear(conns)
	for _, s in SFX do s:Destroy() end
	table.clear(SFX)
	inited = false
end

return UI
