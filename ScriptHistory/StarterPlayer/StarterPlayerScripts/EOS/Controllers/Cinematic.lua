--!nocheck
-- Cinematic (HOS-CINE-002, 17 Oct 2026): shared cut-scene helper. Letterbox bars, HUD hide, camera dim,
-- a title slam with a name plate and a line under it, and a Scriptable camera driven by a shot list.
-- Used by Last One Standing (Controllers/LastStanding) and Hero or Chicken.
--
--   local h = Cinematic.play(spec)     start (or, while one runs, replace its shots in place: no bar flicker)
--   h:chain(spec)                      queue a spec to start when the current shots end
--   h:setTitle(text, sub?, accent?)    change the callout mid-play;  h:setSub(sub)
--   h:stop()                           end it now (camera back at once, bars slide out)
--   Cinematic.letterbox(on)            bars only
--   Cinematic.title(text, sub?, accent?, plate?)   callout only (returns a handle with :hide())
--   Cinematic.restore()                hard reset: camera Custom on your Humanoid, bars/dim/HUD back
--   Cinematic.isPlaying()
--
-- spec = {
--   shots = { shot, ... },   each shot = { duration = s, cframe = CFrame | fn(alpha, t) -> CFrame }
--                            or { duration, from = CFrame | fn(), to = CFrame | fn(), ease = "Sine" }
--                            from/to/cframe functions run every frame (a moving subject stays framed).
--                            fov = number | { from, to } (clamped to COMFORT: 50-70, 12 deg/s); blendIn is ignored (cuts)
--   title = { text, sub?, accent?, plate? = { name, tail?, icon? }, at = s, plateDelay = s, onShow = fn },   (optional)
--   outro = s (0.3)          bars out / callout fade after the last shot (camera is already back)
--   maxSeconds = s (GameConfig.Cinematic.MAX_SECONDS) hard cap: the camera is always given back by then
--   letterbox = true, dim = true, hideHud = true
--   keepGuis = { ScreenGui }  stay visible, lifted above the bars (DisplayOrder 60+)
--   callOnly = bool          callout only (no camera, bars, dim or HUD hide). Reduce effects forces it.
--   onShot = fn(index, shot) / onEnd = fn(reason)   reason: "done" | "stopped" | "cut" | "timeout" | "error" | "respawn"
--   afterLook = Vector3      CameraFX.lookToward this once the camera is back
-- }
-- The camera ALWAYS goes back to Custom + your Humanoid: at the end, after maxSeconds, on respawn, on any
-- error, and the moment the match Phase becomes CROSSING (no cut-scene ever eats crossing time).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EOS = ReplicatedStorage:WaitForChild("EOS")
local GameConfig = require(EOS:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Theme = require(EOS:WaitForChild("UI"):WaitForChild("Theme"))
local Net = require(EOS.Shared:WaitForChild("Net"))
local CameraFX = require(script.Parent.CameraFX)

local CFG = GameConfig.Cinematic or {}
local BAR = CFG.BAR_HEIGHT or 0.11 -- of the viewport height
local BAR_TIME = CFG.BAR_TIME or 0.28
local MAX_SECONDS = CFG.MAX_SECONDS or 4
local BAR_ORDER = 50 -- the bars' ScreenGui; kept GUIs go to 60+
-- COMFORT (Hunter, 17 Oct: "too zoomed in... a bit of motion sickness", then "you can do zoom ins, and make them
-- dramatic and cinematic, but be gentler"). Every shot of every cut-scene (Last One Standing, Hero or Chicken) is
-- clamped to these; a spec that asks for more is clamped and warned about once. GameConfig.Cinematic.COMFORT can
-- override any field.
local COMFORT = {
	FOV_MAX = 70, -- the gameplay FOV; shots start here or narrower
	FOV_MIN = 50, -- slow push-ins may narrow to this
	FOV_RATE = 12, -- degrees per second, eased (no punch-ins, never widening fast)
	MIN_SUBJECT_DISTANCE = 6, -- studs from the camera to the nearest character in view (chest-up at the closest)
	MAX_SPEED = 5, -- studs per second of camera travel within a shot
	MAX_TURN = 25, -- degrees per second of camera turn within a shot
	DIP = 0.2, -- seconds of letterbox-black dip on a cut between shots (0 = hard cut)
}
for k, v in pairs(CFG.COMFORT or {}) do
	COMFORT[k] = v
end
local NEVER_HIDE = { TouchGui = true, EOS_Cinematic = true, Freecam = true }

-- the look, in one place (the callout isn't approved yet: restyle here)
local LOOK = {
	barColor = Color3.fromRGB(5, 7, 10),
	titleColor = Theme.white,
	accentColor = Theme.gold,
	outline = Theme.ink,
	plate = Theme.panel,
	plateT = 0.14,
	plateLip = Color3.fromRGB(184, 116, 0), -- the gold lip under the plate
	tailColor = Color3.fromRGB(255, 90, 95),
	edge = Theme.edge,
	edgeT = Theme.edgeT,
	dim = { Saturation = -0.5, Brightness = -0.08, Contrast = 0.06 },
	vignetteT = 0.45,
}

local Cinematic = {}
local player = Players.LocalPlayer
local state = Net.state()

local gui: ScreenGui? = nil
local ui: any = {} -- bars, vignette, callout pieces
local dimFx: ColorCorrectionEffect? = nil
local hidden: { [Instance]: boolean } = {} -- ScreenGuis and BillboardGuis this cut-scene switched off
local humNames: { [Humanoid]: Enum.HumanoidDisplayDistanceType } = {}
local lifted: { [ScreenGui]: number } = {}
local active: any = nil -- the running handle
local stepName = "EOS_Cinematic"
local stepBound = false
local barsOn = false

local function tween(obj: Instance, t: number, props: any, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function viewport(): Vector2
	local cam = workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1280, 720)
end

-- one unit = 1 px on a 1600x900 screen; phones scale down by whichever side is tighter
local function unit(): number
	local v = viewport()
	return math.clamp(math.min(v.X / 1600, v.Y / 900), 0.45, 1.6)
end

local function stroke(parent: Instance, thick: number, color: Color3?, t: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thick
	s.Color = color or LOOK.outline
	s.Transparency = t or 0
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function label(name: string, parent: Instance, font: Font): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextColor3 = LOOK.titleColor
	l.RichText = true
	l.Text = ""
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.new()
	l.Parent = parent
	return l
end

local function ensureGui(): ScreenGui
	if gui and gui.Parent then
		return gui
	end
	local pg = player:WaitForChild("PlayerGui")
	local g = Instance.new("ScreenGui")
	g.Name = "EOS_Cinematic"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.ScreenInsets = Enum.ScreenInsets.None -- bars/dip/vignette edge to edge, under a notch too (cards keep DeviceSafeInsets)
	g.DisplayOrder = BAR_ORDER
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Enabled = true

	-- vignette: four soft edges (screen space, under the bars)
	local vig = Instance.new("Frame")
	vig.Name = "Vignette"
	vig.BackgroundTransparency = 1
	vig.Size = UDim2.fromScale(1, 1)
	vig.Visible = false
	vig.Parent = g
	for i, d in ipairs({ { 0, 0, 1, 0.32, 90 }, { 0, 0.68, 1, 0.32, -90 }, { 0, 0, 0.22, 1, 0 }, { 0.78, 0, 0.22, 1, 180 } }) do
		local f = Instance.new("Frame")
		f.Name = "Edge" .. i
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BackgroundTransparency = 1
		f.Position = UDim2.fromScale(d[1], d[2])
		f.Size = UDim2.fromScale(d[3], d[4])
		local gr = Instance.new("UIGradient")
		gr.Rotation = d[5]
		gr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		gr.Parent = f
		f.Parent = vig
	end

	local dipFrame = Instance.new("Frame") -- the letterbox-black dip between shots (COMFORT.DIP)
	dipFrame.Name = "Dip"
	dipFrame.BorderSizePixel = 0
	dipFrame.BackgroundColor3 = LOOK.barColor
	dipFrame.BackgroundTransparency = 1
	dipFrame.Size = UDim2.fromScale(1, 1)
	dipFrame.ZIndex = 1
	dipFrame.Parent = g

	local function bar(name: string, top: boolean): Frame
		local b = Instance.new("Frame")
		b.Name = name
		b.BorderSizePixel = 0
		b.BackgroundColor3 = LOOK.barColor
		b.AnchorPoint = Vector2.new(0, if top then 1 else 0)
		b.Size = UDim2.fromScale(1, BAR)
		b.Position = UDim2.fromScale(0, if top then 0 else 1) -- parked off screen
		b.ZIndex = 2
		b.Parent = g
		return b
	end

	-- callout: title, plate, line
	local call = Instance.new("Frame")
	call.Name = "Callout"
	call.BackgroundTransparency = 1
	call.AnchorPoint = Vector2.new(0.5, 0.5)
	call.Position = UDim2.fromScale(0.5, 0.47)
	call.Size = UDim2.fromScale(1, 0.5)
	call.ZIndex = 3
	call.Visible = false
	call.Parent = g
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 10)
	list.Parent = call

	local titleWrap = Instance.new("Frame") -- holds the title + its drop shadow; the UIScale slams it
	titleWrap.Name = "TitleWrap"
	titleWrap.BackgroundTransparency = 1
	titleWrap.AutomaticSize = Enum.AutomaticSize.XY
	titleWrap.LayoutOrder = 1
	titleWrap.Parent = call
	local slam = Instance.new("UIScale")
	slam.Parent = titleWrap
	local shadow = label("Shadow", titleWrap, Theme.font)
	shadow.TextColor3 = LOOK.outline
	shadow.Position = UDim2.fromOffset(0, 6)
	local shadowStroke = stroke(shadow, 5)
	local title = label("Title", titleWrap, Theme.font)
	local titleStroke = stroke(title, 5)

	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.LayoutOrder = 2
	plate.AutomaticSize = Enum.AutomaticSize.XY
	plate.BackgroundColor3 = Color3.new(1, 1, 1) -- colour comes from the Lip gradient
	plate.BackgroundTransparency = 1
	plate.Size = UDim2.new()
	plate.Parent = call
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 14)
	pc.Parent = plate
	stroke(plate, 1, LOOK.edge, LOOK.edgeT)
	local pad = Instance.new("UIPadding")
	pad.Parent = plate
	local prow = Instance.new("UIListLayout")
	prow.FillDirection = Enum.FillDirection.Horizontal
	prow.VerticalAlignment = Enum.VerticalAlignment.Center
	prow.SortOrder = Enum.SortOrder.LayoutOrder
	prow.Parent = plate
	-- gold lip along the bottom edge: a hard band in the plate's own gradient (no extra frame to lay out)
	local lip = Instance.new("UIGradient")
	lip.Name = "Lip"
	lip.Rotation = 90
	lip.Parent = plate
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.LayoutOrder = 1
	icon.Parent = plate
	local pname = label("Name", plate, Theme.font)
	pname.LayoutOrder = 2
	local tail = label("Tail", plate, Theme.font)
	tail.LayoutOrder = 3
	tail.TextColor3 = LOOK.tailColor

	local sub = label("Sub", call, Theme.font)
	sub.LayoutOrder = 3
	local subStroke = stroke(sub, 2.5)

	ui = {
		dip = dipFrame,
		top = bar("BarTop", true),
		bot = bar("BarBottom", false),
		vig = vig,
		call = call,
		list = list,
		titleWrap = titleWrap,
		slam = slam,
		title = title,
		shadow = shadow,
		titleStroke = titleStroke,
		shadowStroke = shadowStroke,
		plate = plate,
		pad = pad,
		prow = prow,
		lip = lip,
		icon = icon,
		pname = pname,
		tail = tail,
		sub = sub,
		subStroke = subStroke,
	}
	g.Parent = pg
	gui = g
	return g
end

-- size every piece for this screen (called on each show)
local function layout()
	ensureGui()
	local u = unit()
	ui.title.TextSize = math.floor(92 * u)
	ui.shadow.TextSize = ui.title.TextSize
	ui.titleStroke.Thickness = math.max(2, 6 * u)
	ui.shadowStroke.Thickness = ui.titleStroke.Thickness
	ui.shadow.Position = UDim2.fromOffset(0, math.floor(7 * u))
	ui.pname.TextSize = math.floor(36 * u)
	ui.tail.TextSize = ui.pname.TextSize
	ui.prow.Padding = UDim.new(0, math.floor(14 * u))
	ui.pad.PaddingLeft = UDim.new(0, math.floor(26 * u))
	ui.pad.PaddingRight = ui.pad.PaddingLeft
	ui.pad.PaddingTop = UDim.new(0, math.floor(10 * u))
	ui.pad.PaddingBottom = UDim.new(0, math.floor(16 * u))
	ui.icon.Size = UDim2.fromOffset(math.floor(40 * u), math.floor(40 * u))
	ui.sub.TextSize = math.floor(30 * u)
	ui.subStroke.Thickness = math.max(1.5, 3 * u)
	ui.list.Padding = UDim.new(0, math.floor(12 * u))
	-- lip band: ~6 px of the plate's height (plate ~ text + padding)
	local h = ui.pname.TextSize + 26 * u
	local k = math.clamp(1 - math.max(3, 6 * u) / h, 0.75, 0.97)
	ui.lip.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, LOOK.plate),
		ColorSequenceKeypoint.new(k, LOOK.plate),
		ColorSequenceKeypoint.new(math.min(k + 0.002, 0.999), LOOK.plateLip),
		ColorSequenceKeypoint.new(1, LOOK.plateLip),
	})
	ui.lip.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, LOOK.plateT),
		NumberSequenceKeypoint.new(k, LOOK.plateT),
		NumberSequenceKeypoint.new(math.min(k + 0.002, 0.999), 0),
		NumberSequenceKeypoint.new(1, 0),
	})
end

local function richTitle(text: string, accent: string?): string
	local esc = function(s: string)
		return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
	end
	if accent and accent ~= "" then
		local a, b = string.find(text, accent, 1, true)
		if a then
			local hex = LOOK.accentColor:ToHex()
			return esc(text:sub(1, a - 1)) .. ('<font color="#%s">'):format(hex) .. esc(text:sub(a, b)) .. "</font>" .. esc(text:sub(b + 1))
		end
	end
	return esc(text)
end

-- ===== bars, dim, HUD =====

function Cinematic.letterbox(on: boolean, instant: boolean?)
	ensureGui()
	barsOn = on
	local t = if instant then 0 else BAR_TIME
	local style, dir = Enum.EasingStyle.Quart, if on then Enum.EasingDirection.Out else Enum.EasingDirection.In
	tween(ui.top, t, { Position = UDim2.fromScale(0, if on then BAR else 0) }, style, dir)
	tween(ui.bot, t, { Position = UDim2.fromScale(0, if on then 1 - BAR else 1) }, style, dir)
end

-- a cut between shots goes through black: full black at once, then clear over `seconds`
local function dip(seconds: number)
	ensureGui()
	ui.dip.BackgroundTransparency = 0
	tween(ui.dip, seconds, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

local function setDim(on: boolean, instant: boolean?)
	local cam = workspace.CurrentCamera
	if on and cam then
		if not dimFx or dimFx.Parent ~= cam then
			if dimFx then
				dimFx:Destroy()
			end
			dimFx = Instance.new("ColorCorrectionEffect")
			dimFx.Name = "EOS_CinematicDim"
			dimFx.Parent = cam -- on the camera, not Lighting: only this screen, nothing left behind
		end
		tween(dimFx, if instant then 0 else 0.3, LOOK.dim)
	elseif dimFx then
		local fx = dimFx
		dimFx = nil
		if instant then
			fx:Destroy()
		else
			tween(fx, 0.25, { Saturation = 0, Brightness = 0, Contrast = 0 }).Completed:Connect(function()
				fx:Destroy()
			end)
		end
	end
	ensureGui()
	ui.vig.Visible = true
	for _, e in ipairs(ui.vig:GetChildren()) do
		if e:IsA("Frame") then
			tween(e, if instant then 0 else 0.3, { BackgroundTransparency = if on then LOOK.vignetteT else 1 })
		end
	end
end

local function hideHud(keep: { ScreenGui }?)
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local keepSet = {}
	for _, g in ipairs(keep or {}) do
		keepSet[g] = true
		if not lifted[g] then
			lifted[g] = g.DisplayOrder
			g.DisplayOrder = math.max(g.DisplayOrder, BAR_ORDER + 10)
		end
	end
	for _, g in ipairs(pg:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled and not NEVER_HIDE[g.Name] and not keepSet[g] and not hidden[g] then
			hidden[g] = true
			g.Enabled = false
		end
	end
	-- overhead name tags: every BillboardGui in PlayerGui (client-made tags), on player characters and on NPC
	-- bodies (workspace.EOS_Runtime), plus Roblox's own Humanoid name display. Not the whole workspace (a hitch).
	local roots: { Instance } = { pg }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(roots, p.Character)
		end
	end
	local runtime = workspace:FindFirstChild("EOS_Runtime") -- NPC bodies (NpcService)
	if runtime then
		table.insert(roots, runtime)
	end
	for _, root in ipairs(roots) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BillboardGui") and d.Enabled and not hidden[d] then
				hidden[d] = true
				d.Enabled = false
			elseif d:IsA("Humanoid") and d.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None and not humNames[d] then
				humNames[d] = d.DisplayDistanceType
				d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
	end
end

-- things that switch themselves back on every frame while a cut-scene runs (CameraFX re-enables the mouse-lock
-- centre dot each frame at Camera + 1; this runs after it at Camera + 2)
local function keepHidden()
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local dot = pg and pg:FindFirstChild("EOS_Crosshair")
	if dot and dot:IsA("ScreenGui") and dot.Enabled then
		dot.Enabled = false
	end
end

local function showHud()
	for g in pairs(hidden) do
		if g.Parent then
			g.Enabled = true
		end
	end
	table.clear(hidden)
	for h, kind in pairs(humNames) do
		if h.Parent then
			h.DisplayDistanceType = kind
		end
	end
	table.clear(humNames)
	for g, order in pairs(lifted) do
		if g.Parent then
			g.DisplayOrder = order
		end
	end
	table.clear(lifted)
end

-- ===== callout =====

local calloutToken = 0
local function showTitle(text: string, sub: string?, accent: string?, plate: any?, instant: boolean?, plateDelay: number?)
	ensureGui()
	layout()
	calloutToken += 1
	ui.title.Text = richTitle(text, accent)
	ui.shadow.Text = text
	ui.sub.Text = sub or ""
	ui.sub.Visible = sub ~= nil and sub ~= ""
	local hasPlate = type(plate) == "table" and plate.name ~= nil
	ui.plate.Visible = hasPlate
	if hasPlate then
		ui.pname.Text = plate.name
		ui.tail.Text = plate.tail or ""
		ui.tail.Visible = plate.tail ~= nil
		ui.icon.Image = plate.icon or ""
		ui.icon.Visible = plate.icon ~= nil
	end
	ui.call.Visible = true
	ui.call.Position = UDim2.fromScale(0.5, 0.47)
	-- slam: 2.4 -> 1 with a bounce (0.32 s)
	ui.slam.Scale = if instant then 1 else 2.4
	ui.title.TextTransparency = if instant then 0 else 1
	ui.shadow.TextTransparency = ui.title.TextTransparency
	ui.titleStroke.Transparency = ui.title.TextTransparency
	ui.shadowStroke.Transparency = ui.title.TextTransparency
	if not instant then
		tween(ui.slam, 0.32, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		for _, o in ipairs({ ui.title, ui.shadow }) do
			tween(o, 0.12, { TextTransparency = 0 })
		end
		tween(ui.titleStroke, 0.12, { Transparency = 0 })
		tween(ui.shadowStroke, 0.12, { Transparency = 0 })
	end
	-- plate + line come in under it
	for _, o in ipairs({ ui.pname, ui.tail, ui.sub }) do
		o.TextTransparency = 1
	end
	ui.subStroke.Transparency = 1
	ui.plate.BackgroundTransparency = 1
	ui.icon.ImageTransparency = 1
	local my = calloutToken
	task.delay(if instant then 0 else (plateDelay or 0.3), function()
		if my ~= calloutToken then
			return
		end
		tween(ui.plate, 0.2, { BackgroundTransparency = 0 }) -- the gradient carries the glass see-through
		tween(ui.icon, 0.2, { ImageTransparency = 0 })
		for _, o in ipairs({ ui.pname, ui.tail, ui.sub }) do
			tween(o, 0.25, { TextTransparency = 0 })
		end
		tween(ui.subStroke, 0.25, { Transparency = 0 })
	end)
end

local function hideTitle(instant: boolean?)
	if not gui then
		return
	end
	calloutToken += 1
	local my = calloutToken
	if instant then
		ui.call.Visible = false
		return
	end
	local t = 0.22
	for _, o in ipairs({ ui.title, ui.shadow, ui.pname, ui.tail, ui.sub }) do
		tween(o, t, { TextTransparency = 1 })
	end
	for _, s in ipairs({ ui.titleStroke, ui.shadowStroke, ui.subStroke }) do
		tween(s, t, { Transparency = 1 })
	end
	tween(ui.plate, t, { BackgroundTransparency = 1 })
	tween(ui.icon, t, { ImageTransparency = 1 })
	tween(ui.call, t, { Position = UDim2.fromScale(0.5, 0.42) })
	task.delay(t, function()
		if my == calloutToken and ui.call then
			ui.call.Visible = false
		end
	end)
end

function Cinematic.title(text: string, sub: string?, accent: string?, plate: any?)
	showTitle(text, sub, accent, plate)
	return {
		hide = function()
			hideTitle()
		end,
		setSub = function(_, s: string)
			ui.sub.Text = s
			ui.sub.Visible = s ~= ""
		end,
	}
end

-- ===== camera =====

local function eval(v: any, alpha: number, t: number): CFrame?
	if type(v) == "function" then
		return v(alpha, t)
	end
	return v
end

-- ease: an EasingStyle name ("Sine", "Quad"...; InOut) or the short forms "linear" | "in" | "out" | "inout"
local SHORT = { ["in"] = { "Quad", "In" }, out = { "Quad", "Out" }, inout = { "Sine", "InOut" } }
local function ease(name: string?, a: number): number
	a = math.clamp(a, 0, 1)
	local n = string.lower(name or "inout")
	if n == "linear" then
		return a
	end
	local short = SHORT[n]
	local ok, style = pcall(function()
		return Enum.EasingStyle[if short then short[1] else name]
	end)
	if not ok or not style then
		return a
	end
	return TweenService:GetValue(a, style, Enum.EasingDirection[if short then short[2] else "InOut"])
end

-- a shot's length / FOV in either shape: { duration, fov = n | {a, b} } or { t, fov0, fov1 } (Hero or Chicken)
local function shotLength(s: any): number
	return s.duration or s.t or 1
end

local function giveCameraBack()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	cam.CameraType = Enum.CameraType.Custom
	if hum then
		cam.CameraSubject = hum
	end
	cam.FieldOfView = GameConfig.Camera.BASE_FOV
end

local function unbind()
	if stepBound then
		stepBound = false
		RunService:UnbindFromRenderStep(stepName)
	end
end

-- ===== handles =====

local Handle = {}
Handle.__index = Handle

-- end it. reason: "done" | "stopped" | "cut" | "timeout" | "error" | "respawn"
function Handle:_finish(reason: string)
	if self.ended then
		return
	end
	self.ended = true
	if active == self then
		active = nil
	end
	unbind()
	if self.usedCamera then
		local ok = pcall(giveCameraBack)
		if not ok then
			task.defer(giveCameraBack)
		end
		if self.spec.afterLook and reason ~= "cut" and reason ~= "respawn" then
			pcall(CameraFX.lookToward, self.spec.afterLook)
		end
	end
	for _, c in ipairs(self.conns) do
		c:Disconnect()
	end
	local hard = reason ~= "done" and reason ~= "stopped"
	-- bars out, HUD back, callout fades (instant on a hard cut)
	if barsOn then
		Cinematic.letterbox(false, hard)
	end
	setDim(false, hard)
	hideTitle(hard)
	local outro = if hard then 0 else (self.spec.outro or 0.3)
	task.delay(outro, function()
		if active == nil then
			showHud()
		end
	end)
	if self.spec.onEnd then
		task.spawn(pcall, self.spec.onEnd, reason)
	end
end

function Handle:stop()
	self:_finish("stopped")
end

function Handle:setTitle(text: string, sub: string?, accent: string?, plate: any?)
	showTitle(text, sub, accent or (self.spec.title and self.spec.title.accent), plate or (self.spec.title and self.spec.title.plate))
end

function Handle:setSub(sub: string)
	if gui then
		ui.sub.Text = sub
		ui.sub.Visible = sub ~= ""
		ui.sub.TextTransparency = 0
		ui.subStroke.Transparency = 0
	end
end

function Handle:chain(spec: any)
	table.insert(self.queue, spec)
	self.deadline += (spec.maxSeconds or MAX_SECONDS)
	return self
end

-- (re)load a spec's shots into this handle: the clock restarts, bars/dim stay as they are
function Handle:_load(spec: any)
	self.spec = spec
	self.shots = spec.shots or {}
	self.shotIndex = 0
	self.t0 = os.clock()
	self.titleShown = false
	self.lastCf = nil
	self.lastShotDrawn = nil
	self.lastStepAt = nil
	self.lastFov = nil
	local total = 0
	for _, s in ipairs(self.shots) do
		total += shotLength(s)
	end
	self.total = total
	self.deadline = os.clock() + (spec.maxSeconds or MAX_SECONDS)
	local call = spec.callOnly or CameraFX.reduceEffects
	self.callOnly = call
	if not call then
		if spec.letterbox ~= false and not barsOn then
			Cinematic.letterbox(true)
		end
		if spec.dim ~= false then
			setDim(true)
		end
		if spec.hideHud ~= false then
			hideHud(spec.keepGuis)
		end
	end
	if spec.title and (spec.title.at or 0) <= 0 then
		self.titleShown = true
		showTitle(spec.title.text, spec.title.sub, spec.title.accent, spec.title.plate, false, spec.title.plateDelay)
	end
end

function Handle:_step()
	local now = os.clock()
	if now > self.deadline then
		self:_finish("timeout")
		return
	end
	local t = now - self.t0
	local spec = self.spec
	if spec.title and not self.titleShown and t >= (spec.title.at or 0) then
		self.titleShown = true
		showTitle(spec.title.text, spec.title.sub, spec.title.accent, spec.title.plate, false, spec.title.plateDelay)
		if spec.title.onShow then
			task.spawn(pcall, spec.title.onShow)
		end
	end
	-- which shot
	local acc, shot, idx, localT = 0, nil, 0, 0
	for i, s in ipairs(self.shots) do
		local d = shotLength(s)
		if t < acc + d then
			shot, idx, localT = s, i, t - acc
			break
		end
		acc += d
	end
	if not shot then
		-- shots done: the next queued spec, else the end
		local nxt = table.remove(self.queue, 1)
		if nxt then
			self:_load(nxt)
			return
		end
		self:_finish("done")
		return
	end
	if idx ~= self.shotIndex then
		self.shotIndex = idx
		self.shotFrom = self.lastCf -- for blendIn
		if spec.onShot then
			task.spawn(pcall, spec.onShot, idx, shot)
		end
	end
	if self.callOnly then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local d = shotLength(shot)
	local a = math.clamp(localT / d, 0, 1)
	local cf: CFrame?
	if shot.cframe then
		cf = eval(shot.cframe, a, localT)
	else
		local from, to = eval(shot.from, a, localT), eval(shot.to, a, localT)
		if from and to then
			cf = from:Lerp(to, ease(shot.ease, a))
		else
			cf = from or to
		end
	end
	if not cf then
		return
	end
	local cut = self.lastShotDrawn ~= idx -- a new shot: a hard cut (or a dip), never a pan between shots
	if shot.blendIn and not self.warnedBlend then
		self.warnedBlend = true
		warn("[Cinematic] comfort: blendIn swings between shots are off (a cut / dip instead)")
	end
	cf = self:_comfort(cam, cf, cut)
	self.lastShotDrawn = idx
	self.lastCf = cf
	if cut and idx > 1 and (COMFORT.DIP or 0) > 0 then
		dip(COMFORT.DIP)
	end
	if cam.CameraType ~= Enum.CameraType.Scriptable then
		cam.CameraType = Enum.CameraType.Scriptable
	end
	self.usedCamera = true
	cam.CFrame = cf
	-- FOV: the shot's own (number, {from, to} or fov0/fov1, eased), clamped to the comfort range and rate
	local fov = shot.fov
	if fov == nil and shot.fov0 then
		fov = { shot.fov0, shot.fov1 or shot.fov0 }
	end
	local want = COMFORT.FOV_MAX
	if type(fov) == "table" then
		want = fov[1] + (fov[2] - fov[1]) * ease(shot.ease, a)
	elseif type(fov) == "number" then
		want = fov
	end
	local clamped = math.clamp(want, COMFORT.FOV_MIN, COMFORT.FOV_MAX)
	if not cut and self.lastFov then
		local step = COMFORT.FOV_RATE * math.max(self.fovDt or 0, 0)
		clamped = math.clamp(clamped, self.lastFov - step, self.lastFov + step)
	end
	if math.abs(clamped - want) > 0.5 and not self.warnedFov then
		self.warnedFov = true
		warn(("[Cinematic] comfort: FOV %.0f clamped (range %d-%d, %d deg/s)"):format(want, COMFORT.FOV_MIN, COMFORT.FOV_MAX, COMFORT.FOV_RATE))
	end
	self.lastFov = clamped
	cam.FieldOfView = clamped
end

-- keep a shot's camera comfortable: never closer than MIN_SUBJECT_DISTANCE to a character in front of it, and
-- within a shot never faster than MAX_SPEED studs/s or MAX_TURN degrees/s (a cut starts fresh)
local subjectParams = RaycastParams.new()
subjectParams.FilterType = Enum.RaycastFilterType.Include
function Handle:_comfort(cam: Camera, cf: CFrame, cut: boolean): CFrame
	-- subject distance: the first character part straight ahead (and a little around) within the minimum
	local chars: { Instance } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(chars, p.Character)
		end
	end
	local runtime = workspace:FindFirstChild("EOS_Runtime")
	if runtime then
		table.insert(chars, runtime)
	end
	subjectParams.FilterDescendantsInstances = chars
	local near = math.huge
	for _, off in ipairs({ Vector3.zero, Vector3.new(0.18, 0, 0), Vector3.new(-0.18, 0, 0), Vector3.new(0, -0.12, 0) }) do
		local dir = cf:VectorToWorldSpace(Vector3.new(off.X, off.Y, -1)).Unit
		local hit = workspace:Raycast(cf.Position, dir * COMFORT.MIN_SUBJECT_DISTANCE, subjectParams)
		if hit then
			near = math.min(near, hit.Distance)
		end
	end
	if near < COMFORT.MIN_SUBJECT_DISTANCE then
		cf = cf - cf.LookVector * (COMFORT.MIN_SUBJECT_DISTANCE - near)
		if not self.warnedNear then
			self.warnedNear = true
			warn(("[Cinematic] comfort: camera %.1f studs from a character, pulled back to %d"):format(near, COMFORT.MIN_SUBJECT_DISTANCE))
		end
	end
	-- speed limits within a shot
	local now = os.clock()
	local dt = math.clamp(now - (self.lastStepAt or now), 0, 0.1)
	self.lastStepAt = now
	self.fovDt = dt
	local prev = self.lastCf
	if cut or not prev or dt <= 0 then
		return cf
	end
	local maxMove = COMFORT.MAX_SPEED * dt
	local move = cf.Position - prev.Position
	local pos = cf.Position
	if move.Magnitude > maxMove then
		pos = prev.Position + move.Unit * maxMove
		self.clampedMove = true
	end
	local dot = math.clamp(prev.LookVector:Dot(cf.LookVector), -1, 1)
	local turn = math.deg(math.acos(dot))
	local maxTurn = COMFORT.MAX_TURN * dt
	local look = cf.LookVector
	if turn > maxTurn and turn > 1e-3 then
		local k = maxTurn / turn
		look = prev.LookVector:Lerp(cf.LookVector, k).Unit
		self.clampedTurn = true
	end
	if (self.clampedMove or self.clampedTurn) and not self.warnedSpeed then
		self.warnedSpeed = true
		warn(("[Cinematic] comfort: camera moves clamped to %d studs/s and %d deg/s"):format(COMFORT.MAX_SPEED, COMFORT.MAX_TURN))
	end
	return CFrame.lookAt(pos, pos + look)
end

function Cinematic.isPlaying(): boolean
	return active ~= nil
end

function Cinematic.current()
	return active
end

function Cinematic.play(spec: any)
	-- already running: swap the shots in place (bars stay, no flicker)
	if active and not active.ended then
		active:_load(spec)
		return active
	end
	local h = setmetatable({ spec = spec, queue = {}, conns = {}, ended = false, usedCamera = false }, Handle)
	active = h
	h:_load(spec)
	-- hard cuts: the crossing starts, you respawn
	table.insert(h.conns, state:GetAttributeChangedSignal("Phase"):Connect(function()
		if state:GetAttribute("Phase") == "CROSSING" then
			h:_finish("cut")
		end
	end))
	table.insert(h.conns, player.CharacterAdded:Connect(function()
		h:_finish("respawn")
	end))
	-- belt and braces: a timer that doesn't depend on the render step
	task.delay((spec.maxSeconds or MAX_SECONDS) + 0.05, function()
		while not h.ended and os.clock() <= h.deadline do
			task.wait(0.1)
		end
		if not h.ended then
			h:_finish("timeout")
		end
	end)
	unbind()
	stepBound = true
	-- after CameraFX (Camera + 1), so its FOV / shoulder offset never fight the shot
	RunService:BindToRenderStep(stepName, Enum.RenderPriority.Camera.Value + 2, function()
		local ok, err = pcall(h._step, h)
		if ok and not h.callOnly then
			keepHidden()
		end
		if not ok then
			warn("[Cinematic] " .. tostring(err))
			h:_finish("error")
		end
	end)
	return h
end

-- hard reset (anyone can call it; safe when nothing runs)
function Cinematic.restore()
	if active then
		active:_finish("stopped")
	end
	unbind()
	pcall(giveCameraBack)
	if gui then
		Cinematic.letterbox(false, true)
		hideTitle(true)
	end
	setDim(false, true)
	showHud()
end

Cinematic.LOOK = LOOK -- restyle hook
return Cinematic
