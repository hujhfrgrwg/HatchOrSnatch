-- HOS-SPIN-001 (18 Oct 2026, Matthew): builds StarterGui.SpinWheelUI, the spin wheel screen, in the game's current UI
-- theme. It is a copy of RetentionUI (same runtime UI module, scrim, fit and button juice) whose gift card is re-laid:
--   left   the banner, the free spin timer, "Spins: n", SPIN! / SPIN x5 / SPIN x10, the three spin packs, ODDS
--   right  WheelView: a ViewportFrame with a copy of the lobby wheel (Workspace.SpinWheel.Wheel + the crystal) that the
--          client turns; Slots: one icon + amount per sector, kept on their sectors by the client; Result: the prize tile
-- Art is only what the gift card already uses (panel, banner, green button, gold tile, grey plate); icons are the
-- game's own. SpinWheelController drives it. Re-runnable: it replaces the old SpinWheelUI.
local SG = game:GetService("StarterGui")
local C = require(game.ReplicatedStorage.EOS.Shared.SpinWheelConfig)

local old = SG:FindFirstChild("SpinWheelUI")
if old then old:Destroy() end
local gui = SG.RetentionUI:Clone()
gui.Name = "SpinWheelUI"
gui.Enabled = false
local root = gui.Root
root.Starter:Destroy()
root.WaitOffer:Destroy()
local screen = root.Gift
screen.Name = "Spin"
screen.Visible = false
local card = screen.GiftCard
card.Name = "SpinCard"
local panel = card.Panel

-- templates (removed at the end)
local T = {
	head = panel.Head, headSh = panel.HeadShadow,
	sub = panel.Sub, subSh = panel.SubShadow,
	btn = panel.BtnClaim, slot = panel.GoldSlot, tile = panel.GiftTile,
	count = panel.GoldSlot.Count.CountText, countSh = panel.GoldSlot.Count.CountTextShadow,
	plate = panel.HeaderInfo.Art,
}

local function scaleTree(g: GuiObject, kx: number, ky: number)
	local k = math.min(kx, ky)
	for _, d in g:GetDescendants() do
		if d:IsA("GuiObject") then
			d.Position = UDim2.new(d.Position.X.Scale, d.Position.X.Offset * kx, d.Position.Y.Scale, d.Position.Y.Offset * ky)
			d.Size = UDim2.new(d.Size.X.Scale, d.Size.X.Offset * kx, d.Size.Y.Scale, d.Size.Y.Offset * ky)
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				d.TextSize = math.max(8, math.floor(d.TextSize * k + 0.5))
			end
		elseif d:IsA("UIStroke") then
			d.Thickness *= k
			if d:GetAttribute("BaseThickness") then d:SetAttribute("BaseThickness", d.Thickness) end
		end
	end
	g.Size = UDim2.fromOffset(g.Size.X.Offset * kx, g.Size.Y.Offset * ky)
end

-- a shadowed label pair (main + "<name>Shadow" a few px lower), from a template pair
local function pair(parent: Instance, name: string, text: string, x: number, y: number, w: number, h: number, ts: number,
	src: TextLabel, srcSh: TextLabel, align: Enum.TextXAlignment?, z: number?)
	local k = ts / src.TextSize
	local dy = math.max(2, math.floor(3 * k + 0.5))
	local out = {}
	for i, t in { srcSh, src } do
		local c = t:Clone()
		c.Name = if i == 1 then name .. "Shadow" else name
		c.Text = text
		c.TextSize = ts
		c.Position = UDim2.fromOffset(x, y + (if i == 1 then dy else 0))
		c.Size = UDim2.fromOffset(w, h)
		c.TextXAlignment = align or Enum.TextXAlignment.Left
		c.ZIndex = (z or 4) + i - 1
		c:SetAttribute("FitW", nil)
		c:SetAttribute("FitRatio", nil)
		for _, st in c:GetChildren() do
			if st:IsA("UIStroke") then
				st.Thickness *= k
				st:SetAttribute("BaseThickness", st.Thickness)
			end
		end
		c.Parent = parent
		out[i] = c
	end
	return out[2], out[1]
end

local function icon(parent: Instance, name: string, image: string, x: number, y: number, s: number, z: number)
	local sh = Instance.new("ImageLabel")
	sh.Name = name .. "Shadow"
	sh.BackgroundTransparency = 1
	sh.Image = image
	sh.ImageColor3 = Color3.new(0, 0, 0)
	sh.ScaleType = Enum.ScaleType.Fit
	sh.Position = UDim2.fromOffset(x, y + math.max(2, s * 0.04))
	sh.Size = UDim2.fromOffset(s, s)
	sh.ZIndex = z
	sh.Parent = parent
	local ic = sh:Clone()
	ic.Name = name
	ic.ImageColor3 = Color3.new(1, 1, 1)
	ic.Position = UDim2.fromOffset(x, y)
	ic.ZIndex = z + 1
	ic.Parent = parent
	return ic, sh
end

-- a green button like CLAIM, scaled to w x h
local function button(name: string, text: string, x: number, y: number, w: number, h: number)
	local b = T.btn:Clone()
	b.Name = name
	scaleTree(b, w / 320, h / 100)
	b.Position = UDim2.fromOffset(x, y)
	b.Visible = true
	for _, d in b:GetDescendants() do
		if d:IsA("TextLabel") then d.Text = text end
	end
	b.Parent = panel
	return b
end

---------------------------------------------------------------- banner
local banner = card.Banner
for _, n in { "I_gift_daily", "I_gift_dailyShadow" } do
	local im = banner:FindFirstChild(n)
	if im then
		im.Image = "rbxassetid://87833590533916"
		im.Name = n:gsub("gift_daily", "spin")
	end
end
for _, n in { "Title", "TitleShadow" } do banner[n].Text = "SPIN TO WIN!" end

---------------------------------------------------------------- left column
local hdr = panel.HeaderInfo
hdr.Name = "Timer"
hdr.Position = UDim2.fromOffset(40, 100)
for _, n in { "TimerText", "TimerTextShadow" } do hdr[n].Text = "Free spin ready!" end

pair(panel, "SpinsText", "Spins: 0", 42, 172, 500, 53, 44, T.head, T.headSh)

local spin1 = button("BtnSpin", "SPIN!", 40, 236, 320, 100)
spin1.ZIndex = 9
local spin5 = button("BtnSpin5", "SPIN x5", 376, 236, 164, 48)
local spin10 = button("BtnSpin10", "SPIN x10", 376, 288, 164, 48)
spin5.ZIndex, spin10.ZIndex = 9, 9

pair(panel, "BuyHead", "Get more spins", 42, 352, 380, 34, 28, T.sub, T.subSh)

local TILE = 112
for i, pack in C.PACKS do
	local b = Instance.new("TextButton")
	b.Name = "BtnBuy" .. pack.spins
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Position = UDim2.fromOffset(40 + (i - 1) * (TILE + 14), 394)
	b.Size = UDim2.fromOffset(TILE, TILE)
	b.ZIndex = 9
	b:SetAttribute("Button", true)
	b:SetAttribute("Spins", pack.spins)
	local t = T.slot:Clone()
	t.Name = "Tile"
	scaleTree(t, TILE / 136, TILE / 136)
	t.Position = UDim2.fromOffset(0, 0)
	t.Icon.Image = "rbxassetid://87833590533916"
	t.IconShadow.Image = t.Icon.Image
	t.Icon.Position += UDim2.fromOffset(0, -4)
	t.IconShadow.Position += UDim2.fromOffset(0, -4)
	for _, d in t:GetDescendants() do
		if d:IsA("TextLabel") and d.Name:match("^CountText") then d.Text = "+" .. pack.spins end
		if d:IsA("TextLabel") and d.Name:match("^LabelText") then
			d.Text = tostring(pack.robux)
			d.TextXAlignment = Enum.TextXAlignment.Left
			d.Position += UDim2.fromOffset(40, 0)
		end
	end
	local rb = icon(t.Label, "Robux", "rbxassetid://131610750805605", 22, -1, 21, 3)
	t.Parent = b
	b.Parent = panel
end

local odds = Instance.new("TextButton")
odds.Name = "BtnOdds"
odds.Text = ""
odds.AutoButtonColor = false
odds.BackgroundTransparency = 1
odds.Position = UDim2.fromOffset(418, 448)
odds.Size = UDim2.fromOffset(122, 52)
odds.ZIndex = 9
odds:SetAttribute("Button", true)
local oa = T.plate:Clone()
oa.Size = UDim2.fromOffset(122, 52)
oa.Parent = odds
pair(odds, "OddsText", "ODDS", 0, 9, 122, 34, 30, T.sub, T.subSh, Enum.TextXAlignment.Center, 2)
odds.Parent = panel

---------------------------------------------------------------- the wheel
local VP = 540
local vf = Instance.new("ViewportFrame")
vf.Name = "WheelView"
vf.BackgroundTransparency = 1
vf.Position = UDim2.fromOffset(552, -22)
vf.Size = UDim2.fromOffset(VP, VP)
vf.ZIndex = 2
vf.Ambient = Color3.fromRGB(150, 140, 170)
vf.LightColor = Color3.fromRGB(255, 240, 225)
vf.LightDirection = Vector3.new(0.35, -0.5, -1)
local sw = workspace.SpinWheel
local pivot = sw:GetPivot()
local w = sw.Wheel:Clone()
local lbl = w:FindFirstChild("Labels")
if lbl then lbl:Destroy() end -- SurfaceGuis don't draw in a ViewportFrame: Slots does it here
w.Parent = vf
sw.Frame.Crystal:Clone().Parent = vf
-- camera: straight on, a little above the hub so the crystal fits; the client reads these to place Slots
local HALF, LIFT, FOV = 9.4, 1.0, 20
local centre = pivot:PointToWorldSpace(Vector3.new(0, 10.72, 0))
local target = centre + pivot.YVector * LIFT
local cam = Instance.new("Camera")
cam.FieldOfView = FOV
cam.CFrame = CFrame.lookAt(target + pivot.ZVector * (HALF / math.tan(math.rad(FOV / 2))), target, pivot.YVector)
cam.Parent = vf
vf.CurrentCamera = cam
vf:SetAttribute("HalfStuds", HALF)
vf:SetAttribute("LiftStuds", LIFT)
vf:SetAttribute("Centre", centre)
vf:SetAttribute("Axis", pivot.ZVector)
vf.Parent = panel

local slots = Instance.new("Frame")
slots.Name = "Slots"
slots.BackgroundTransparency = 1
slots.Position = vf.Position
slots.Size = vf.Size
slots.ZIndex = 3
slots.Parent = panel
for i, s in C.SLOTS do
	local f = Instance.new("Frame")
	f.Name = "Slot" .. i
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(100, 112)
	f.ZIndex = 3
	f:SetAttribute("Slot", i)
	local isz = if s.kind == "weapon" then 66 else 56
	local ic = icon(f, "Icon", C.icon(s), (100 - isz) / 2, 6, isz, 4)
	if s.kind == "weapon" and s.mystery then
		ic.ImageColor3 = Color3.fromRGB(40, 22, 8)
		pair(f, "Mystery", "?", 0, 4, 100, 60, 52, T.head, T.headSh, Enum.TextXAlignment.Center, 6)
	end
	pair(f, "Amount", C.short(s), 0, 70, 100, 28, if s.kind == "weapon" then 19 else 25, T.count, T.countSh, Enum.TextXAlignment.Center, 8)
	f.Parent = slots
end

-- the prize, over the hub when the wheel stops
local res = Instance.new("Frame")
res.Name = "Result"
res.BackgroundTransparency = 1
res.AnchorPoint = Vector2.new(0.5, 0.5)
res.Position = UDim2.fromOffset(552 + VP / 2, -22 + VP / 2 + 29)
res.Size = UDim2.fromOffset(200, 200)
res.ZIndex = 20
res.Visible = false
local tile = T.tile:Clone()
tile.Name = "Tile"
scaleTree(tile, 200 / 300, 200 / 300)
tile.Position = UDim2.fromOffset(0, 0)
for _, d in tile:GetDescendants() do
	if d:IsA("GuiObject") then d.ZIndex += 20 end
end
tile.Parent = res
pair(res, "ResultSub", "", -130, 206, 460, 34, 27, T.sub, T.subSh, Enum.TextXAlignment.Center, 30)
res.Parent = panel

---------------------------------------------------------------- tidy
for _, n in { "Head", "HeadShadow", "Sub", "SubShadow", "GoldSlot", "GemsSlot", "GiftTile", "BtnClaim", "BtnLater", "Note", "NoteShadow" } do
	local g = panel:FindFirstChild(n)
	if g then g:Destroy() end
end
gui.Parent = SG
return "SpinWheelUI built"
