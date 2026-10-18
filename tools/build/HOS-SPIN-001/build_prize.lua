-- HOS-SPIN-001 (18 Oct 2026, Matthew: "Have the reward kinda be its own GUI that pops up in the middle of the screen with
-- the rest of the background kinda shaded black"): adds the prize popup to StarterGui.SpinWheelUI. Run after build_ui.lua.
--   Root.Prize   a copy of EOSUI's Reward reveal (rays, sparkles, big icon, name, kind, sub line) over a black shade,
--                with one COLLECT! button; SpinWheelController fills it and opens it on top of the spin screen
--                (no description lines: Matthew 18 Oct "Remove the Description here")
--   Root.Multi   x5 / x10: that many wheels spinning at once over the same shade, each landing on its own prize
--                (SpinWheelController clones the screen's wheel into Wheels), then COLLECT!
--   Fly          a full-screen layer above everything: the Gold / Gems / egg shards fly from the popup to the HUD
-- The old in-wheel Result tile is removed (the popup replaces it).
local gui = game.StarterGui.SpinWheelUI
local root = gui.Root

local oldResult = root.Spin.SpinCard.Panel:FindFirstChild("Result")
if oldResult then oldResult:Destroy() end
local old = root:FindFirstChild("Prize")
if old then old:Destroy() end

local p = game.StarterGui.EOSUI.Root.Reward:Clone()
p.Name = "Prize"
p.Visible = false
p:SetAttribute("Dim", 0) -- its own shade (black) instead of the purple scrim
p:SetAttribute("Hud", false)
local shade = p.Dim -- keeps the name Dim: the UI module fades a screen's own Dim in and out
shade.F.BackgroundColor3 = Color3.new(0, 0, 0)
shade.F.BackgroundTransparency = 0.15
shade.F.Size = UDim2.new(1, 4000, 1, 4000)
shade.F.Position = UDim2.fromOffset(-2000, -2000)
shade.Active = true

local rev = p.Reveal
local ps = Instance.new("UIScale") -- the reveal is 1064 tall: at 0.8 the shade shows round it
ps.Name = "PopScale"
ps.Scale = 0.8
ps:SetAttribute("Base", 0.8)
ps.Parent = rev
for _, n in { "Title", "TitleShadow" } do rev.TitleBig[n].Text = "YOU WON!" end
for _, n in { "ItemName", "ItemNameShadow" } do rev[n].Text = "+250 Gold" end
for _, n in { "KindText", "KindTextShadow", "SubText", "SubTextShadow" } do rev[n]:Destroy() end
for _, n in { "Icon", "IconShadow" } do rev[n].Image = "rbxassetid://97477413390638" end
rev.BtnClose:Destroy()
local b = rev.BtnUse
b.Name = "BtnCollect"
b.Position = UDim2.fromOffset((1004 - 250) / 2, 885)
for _, n in { "Label", "LabelShadow" } do b[n].Text = "COLLECT!" end
p.Parent = root

local oldMulti = root:FindFirstChild("Multi")
if oldMulti then oldMulti:Destroy() end
local m = Instance.new("Frame")
m.Name = "Multi"
m.BackgroundTransparency = 1
m.Size = UDim2.fromScale(1, 1)
m.Visible = false
m.ZIndex = p.ZIndex
m:SetAttribute("Dim", 0)
m:SetAttribute("Hud", false)
p.Dim:Clone().Parent = m
local t = rev.TitleBig:Clone()
t.AnchorPoint = Vector2.new(0.5, 0)
t.Position = UDim2.new(0.5, 0, 0.05, 0) -- a scale Y keeps it out of the UI module's top-bar shuffle
t.ZIndex = 3
for _, n in { "Title", "TitleShadow" } do t[n].Text = "SPIN x10!" end
t.Parent = m
local w = Instance.new("Frame")
w.Name = "Wheels"
w.BackgroundTransparency = 1
w.AnchorPoint = Vector2.new(0.5, 0.5)
w.Position = UDim2.new(0.5, 0, 0.5, 10)
w.Size = UDim2.fromOffset(1760, 720)
w.ZIndex = 2
w.Parent = m
local mb = b:Clone()
mb.AnchorPoint = Vector2.new(0.5, 1)
mb.Position = UDim2.new(0.5, 0, 0.96, 0)
mb.ZIndex = 4
mb.Parent = m
m.Parent = root

local fly = gui:FindFirstChild("Fly") or Instance.new("Frame")
fly.Name = "Fly"
fly.BackgroundTransparency = 1
fly.Size = UDim2.fromScale(1, 1)
fly.ZIndex = 50
fly.Parent = gui
return "prize built"
