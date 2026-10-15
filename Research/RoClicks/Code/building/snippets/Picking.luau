--!strict
-- Picking (client): correct pointer rays, a forgiving pick, one reused hover Highlight, and tap-vs-drag.
--
-- THE 58 PX BUG: InputObject.Position is in GUI space (top-bar inset already removed) and must go to
-- Camera:ScreenPointToRay. UserInputService:GetMouseLocation() is in viewport space (inset included) and
-- must go to Camera:ViewportPointToRay. Mixing them aims one inset (58 px in a Studio playtest) above the
-- cursor: clicks pick the building above, or nothing. Never add/subtract GetGuiInset by hand.
--
--   Picking.ownerAt = function(cell) return myGrid:owner(cell) end   -- your cell -> id lookup
--   Picking.modelOf = function(id) return buildingsById[id] end
--   Picking.groundFolder = workspace.Map.Ground
--   Picking.onTap = function(id, model) openBubble(id) end
--   Picking.start()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Picking = {}
Picking.CELL = 4 -- studs per grid cell
Picking.ownerAt = function(_cell: Vector2): string? return nil end
Picking.modelOf = function(_id: string): Model? return nil end
Picking.groundFolder = nil :: Instance?
Picking.onTap = function(_id: string?, _model: Model?) end
Picking.blocked = function(): boolean return false end -- placing, a screen open, cutscene...

-- tap thresholds: movement in px, max duration in s
Picking.TAP = {
	mouse = { move = 7, time = 0.5 },
	touch = { move = 14, frac = 0.025, time = 0.65 }, -- 14 px or 2.5% of the short screen side
}

---------------------------------------------------------------- rays
function Picking.rayFromInput(pos: Vector3 | Vector2): Ray -- InputObject.Position (GUI space)
	return workspace.CurrentCamera:ScreenPointToRay(pos.X, pos.Y)
end

function Picking.rayFromMouse(): Ray -- GetMouseLocation (viewport space)
	local m = UserInputService:GetMouseLocation()
	return workspace.CurrentCamera:ViewportPointToRay(m.X, m.Y)
end

function Picking.overGui(guiPos: Vector2): boolean -- GetGuiObjectsAtPosition takes GUI space too
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return false end
	for _, g in pg:GetGuiObjectsAtPosition(guiPos.X, guiPos.Y) do
		if g.Visible and (g:IsA("GuiButton") or (g:IsA("Frame") and g.BackgroundTransparency < 1)) then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- forgiving pick
-- Cast against the GROUND only, turn the hit into a cell, ask who owns the cell. Works whatever CanQuery
-- says on decorative parts, and the hit area is the whole footprint, not the thin parts of a model.
function Picking.pick(ray: Ray): (string?, Model?)
	local params = RaycastParams.new()
	if Picking.groundFolder then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { Picking.groundFolder }
	end
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
	if not hit then return nil, nil end
	local cell = Vector2.new(math.floor(hit.Position.X / Picking.CELL), math.floor(hit.Position.Z / Picking.CELL))
	local id = Picking.ownerAt(cell)
	return id, if id then Picking.modelOf(id) else nil
end

---------------------------------------------------------------- hover (ONE Highlight, reused)
-- Roblox draws at most 31 Highlights at once; one per building silently stops drawing past that.
local hover = Instance.new("Highlight")
hover.Name = "HoverHighlight"
hover.FillColor = Color3.new(1, 1, 1)
hover.OutlineColor = Color3.new(1, 1, 1)
hover.FillTransparency = 1
hover.OutlineTransparency = 1
hover.DepthMode = Enum.HighlightDepthMode.Occluded
hover.Enabled = false

local hoverId: string? = nil
local lastMouse, lastCam = Vector2.zero, CFrame.identity
local lastPick = 0

local function setHover(id: string?, model: Model?)
	if id == hoverId then return end
	hoverId = id
	if model then
		hover.Adornee = model
		hover.Enabled = true
		hover.FillTransparency, hover.OutlineTransparency = 0.86, 0.3 -- tween these in ~0.1 s in a real game
	else
		hover.Enabled = false
		hover.Adornee = nil
	end
end

local function updateHover()
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	if touchOnly or Picking.blocked() or UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
		setHover(nil, nil)
		return
	end
	local m, cam = UserInputService:GetMouseLocation(), workspace.CurrentCamera.CFrame
	-- re-pick only when the mouse or camera moved, at most 15 times a second
	if (m == lastMouse and cam == lastCam) or os.clock() - lastPick < 1 / 15 then return end
	lastMouse, lastCam, lastPick = m, cam, os.clock()
	local inset = (game:GetService("GuiService"):GetGuiInset())
	if Picking.overGui(m - inset) then -- convert viewport -> GUI space for the GUI query only
		setHover(nil, nil)
		return
	end
	setHover(Picking.pick(Picking.rayFromMouse())) -- the SAME pick a click uses
end

---------------------------------------------------------------- tap vs drag
-- Note: UserInputService:GetTouchesInProgress does not exist. Count touches yourself.
type Press = { pos: Vector2, t: number, kind: string, multi: boolean }
local touches = 0
local press: Press? = nil

local function isTap(p: Press, input: InputObject): boolean
	local kind = p.kind
	local rule = Picking.TAP[kind]
	local cam = workspace.CurrentCamera.ViewportSize
	local limit = if kind == "touch"
		then math.max(rule.move, (rule.frac or 0) * math.min(cam.X, cam.Y))
		else rule.move
	local moved = (Vector2.new(input.Position.X, input.Position.Y) - p.pos).Magnitude
	return moved <= limit and os.clock() - p.t <= rule.time and not p.multi
end

function Picking.start()
	hover.Parent = workspace
	RunService.RenderStepped:Connect(updateHover)

	UserInputService.InputBegan:Connect(function(input, processed)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch then
			touches += 1
			if press then press.multi = true end -- a second finger = pinch/pan, never a tap
		end
		if processed or Picking.blocked() then return end
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			if not press then
				press = { pos = Vector2.new(input.Position.X, input.Position.Y), t = os.clock(),
					kind = if t == Enum.UserInputType.Touch then "touch" else "mouse", multi = touches > 1 }
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch then touches = math.max(0, touches - 1) end
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		local p = press
		if touches > 0 and t == Enum.UserInputType.Touch then return end -- wait for the last finger
		press = nil
		if p and isTap(p, input) then
			Picking.onTap(Picking.pick(Picking.rayFromInput(input.Position))) -- GUI space -> ScreenPointToRay
		end
	end)
end

return Picking
