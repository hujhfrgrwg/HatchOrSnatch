-- HOS-SPIN-001 (18 Oct 2026, Matthew: "Have the reward kinda be its own GUI that pops up in the middle of the screen with
-- the rest of the background kinda shaded black"): adds the prize popup to StarterGui.SpinWheelUI. Run after build_ui.lua.
--   Root.Prize   a copy of EOSUI's Reward reveal (rays, sparkles, big icon, name, kind, sub line) over a black shade,
--                with one COLLECT! button; SpinWheelController fills it and opens it on top of the spin screen
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
shade.F.BackgroundTransparency = 0.3
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
for _, n in { "KindText", "KindTextShadow" } do rev[n].Text = "SPIN WHEEL PRIZE" end
for _, n in { "SubText", "SubTextShadow" } do rev[n].Text = "" end
for _, n in { "Icon", "IconShadow" } do rev[n].Image = "rbxassetid://97477413390638" end
rev.BtnClose:Destroy()
local b = rev.BtnUse
b.Name = "BtnCollect"
b.Position = UDim2.fromOffset((1004 - 250) / 2, b.Position.Y.Offset)
for _, n in { "Label", "LabelShadow" } do b[n].Text = "COLLECT!" end
p.Parent = root

local fly = gui:FindFirstChild("Fly") or Instance.new("Frame")
fly.Name = "Fly"
fly.BackgroundTransparency = 1
fly.Size = UDim2.fromScale(1, 1)
fly.ZIndex = 50
fly.Parent = gui
return "prize built"
