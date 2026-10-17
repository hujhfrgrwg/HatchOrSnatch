-- Fit: rescales every "Fit" UIScale in the EOS ScreenGuis from the 1920x1080 design canvas.
-- s = min(w/1920, h/1080); phones get a boost so text stays readable (LESSONS 6), TVs a 10% bump.
-- Uses each ScreenGui's own AbsoluteSize (the safe-area canvas), refits when it changes.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Fit = {}

local guis: { ScreenGui } = {}
Fit.scale = 1

local function compute(gui: ScreenGui): number
	local size = gui.AbsoluteSize
	if size.X < 2 or size.Y < 2 then
		local cam = workspace.CurrentCamera
		size = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
	end
	local s = math.min(size.X / 1920, size.Y / 1080)
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if touchOnly and size.Y < 700 then
		s *= 1.28 -- phone: bigger targets and text
	elseif touchOnly then
		s *= 1.08 -- tablet: finger-sized targets
	elseif GuiService:IsTenFootInterface() then
		s *= 1.1
	else
		s *= 0.9 -- desktop: mouse precision, a little less bulk
	end
	return math.clamp(s, 0.36, 1.3)
end

-- A group's pixel offset from its anchor is in design pixels too, so it scales with the group
-- (otherwise a 220 px gap that is right at 1080p pushes things to mid-screen on a phone).
-- The design position lives in the "DesignPos" attribute; layout code sets that, never Position.
local function place(g: GuiObject, s: number)
	local design = g:GetAttribute("DesignPos")
	if typeof(design) ~= "UDim2" then
		design = g.Position
		g:SetAttribute("DesignPos", design)
	end
	-- "FitExtra": real (unscaled) pixels added on top, e.g. to clear Roblox's own topbar buttons
	local extra = g:GetAttribute("FitExtra")
	local ex, ey = 0, 0
	if typeof(extra) == "Vector2" then
		ex, ey = extra.X, extra.Y
	end
	g.Position = UDim2.new(design.X.Scale, math.round(design.X.Offset * s + ex), design.Y.Scale, math.round(design.Y.Offset * s + ey))
end

local scales: { [ScreenGui]: number } = {}

local function apply(gui: ScreenGui)
	local s = compute(gui)
	-- never let a group outgrow the canvas (the phone boost would push the results card off-screen)
	local canvas = gui.AbsoluteSize
	if canvas.X > 2 and canvas.Y > 2 then
		for _, g in ipairs(gui:GetChildren()) do
			if g:IsA("GuiObject") and g:FindFirstChild("Fit") then
				local h, w = g.Size.Y.Offset, g.Size.X.Offset
				if h > 0 then
					s = math.min(s, (canvas.Y - 8) / h)
				end
				if w > 0 then
					s = math.min(s, (canvas.X - 8) / w)
				end
			end
		end
	end
	scales[gui] = s
	if gui == guis[1] then
		Fit.scale = s -- the HUD's scale
	end
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("UIScale") and d.Name == "Fit" then
			d.Scale = s
			local g = d.Parent
			if g and g:IsA("GuiObject") and g.Parent == gui then
				place(g, s)
			end
		end
	end
end

-- Each ScreenGui fits its own canvas (menus/results use CoreUISafeInsets, so on phones they
-- scale to the area under Roblox's topbar while the HUD uses the whole safe screen).
function Fit.scaleFor(g: Instance): number
	local gui = g:FindFirstAncestorOfClass("ScreenGui")
	return (gui and scales[gui]) or Fit.scale
end

-- Move an anchored group (design pixels); applied at the current scale.
function Fit.setDesignPosition(g: GuiObject, anchor: Vector2, pos: UDim2, extra: Vector2?)
	g.AnchorPoint = anchor
	g:SetAttribute("DesignPos", pos)
	g:SetAttribute("FitExtra", extra or Vector2.zero)
	place(g, Fit.scaleFor(g))
end

function Fit.track(gui: ScreenGui)
	table.insert(guis, gui)
	apply(gui)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		apply(gui)
	end)
end

function Fit.refreshAll()
	for _, g in ipairs(guis) do
		apply(g)
	end
end

function Fit.init()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(Fit.refreshAll)
	end
	UserInputService.LastInputTypeChanged:Connect(Fit.refreshAll)
	-- settle after startup (canvas sizes arrive late on phones)
	task.delay(1, Fit.refreshAll)
	task.delay(3, Fit.refreshAll)
end

return Fit
