-- HOS-EMOTE-003 round 2 (18 Oct, Matthew, with a screenshot of the spin wheel's prize popup: "The reward UI needs to look
-- like this for the emote thing"): EmoteCrateUI's Reveal becomes the game's reward reveal (EOSUI.Root.Reward.Reveal,
-- the same one the spin wheel's popup copies) over a black shade.
--   Reveal         full-screen holder; Span = the card's height on screen (EmoteCrateSpin's phone fit)
--     Shade        black, 0.15
--     Card         the Reward reveal at 0.8 (CardScale, Base 0.8): rays, YOU WON!, the big picture (EmoteCrateSpin puts
--                  the emote's still over Icon), ItemName = emote, KindText = "COMMON EMOTE" in the rarity colour,
--                  SubText = New emote! / the duplicate's refund, BtnClaim = COLLECT! (the green USE NOW art),
--                  BtnAgain = AGAIN [gem] price (the NICE! art), ShortRow = "Need N more" under it
-- The old card Reveal goes to ServerStorage._Backups.HOS-EMOTE-003_2026-10-18.Reveal_before.
-- Run in edit mode. EmoteCrateSpin.reveal() fills it (same file's ticket).
local ec = game.StarterGui.EmoteCrateUI
local screen = ec:FindFirstChild("EmoteCrate", true)
local bk = game.ServerStorage._Backups:FindFirstChild("HOS-EMOTE-003_2026-10-18") or Instance.new("Folder")
bk.Name = "HOS-EMOTE-003_2026-10-18"
bk.Parent = game.ServerStorage._Backups

local old = screen:FindFirstChild("Reveal")
if old and not old:GetAttribute("HOS_PrizeLook") then
	if not bk:FindFirstChild("Reveal_before") then
		old.Name = "Reveal_before"
		old.Parent = bk
	else
		old:Destroy()
	end
elseif old then
	old:Destroy() -- an earlier run of this script
end

local GEM = "rbxassetid://111102563440206"
local SCALE = 0.8
local src = game.StarterGui.EOSUI.Root.Reward.Reveal

local rev = Instance.new("Frame")
rev.Name = "Reveal"
rev.BackgroundTransparency = 1
rev.AnchorPoint = Vector2.new(0.5, 0.5)
rev.Position = UDim2.fromScale(0.5, 0.5)
rev.Size = UDim2.fromOffset(math.floor(1004 * SCALE), math.floor(1104 * SCALE))
rev.ZIndex = 5
rev.Visible = false
rev:SetAttribute("HOS_PrizeLook", true)
rev:SetAttribute("Span", math.floor(1104 * SCALE))

local shade = Instance.new("Frame")
shade.Name = "Shade"
shade.BorderSizePixel = 0
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BackgroundTransparency = 0.15
shade.AnchorPoint = Vector2.new(0.5, 0.5)
shade.Position = UDim2.fromScale(0.5, 0.5)
shade.Size = UDim2.fromOffset(8000, 8000)
shade.ZIndex = 1
shade.Active = true -- clicks on the shade don't reach the game
shade.Parent = rev

local card = src:Clone()
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(1004, 1104)
card.ZIndex = 2
card.Visible = true
for _, d in card:GetChildren() do
	if d:IsA("UIScale") then d:Destroy() end
end
local cs = Instance.new("UIScale")
cs.Name = "CardScale"
cs.Scale = SCALE
cs:SetAttribute("Base", SCALE)
cs.Parent = card

for _, n in { "Title", "TitleShadow" } do card.TitleBig[n].Text = "YOU WON!" end
for _, n in { "ItemName", "ItemNameShadow" } do card[n].Text = "Emote Name" end
for _, n in { "KindText", "KindTextShadow" } do card[n].Text = "COMMON EMOTE" end
for _, n in { "SubText", "SubTextShadow" } do card[n].Text = "New emote!" end
card.SubText.TextColor3 = Color3.fromRGB(110, 235, 90)
card.SubText.TextSize = 34
card.SubTextShadow.TextSize = 34
card.SubText.Size = UDim2.fromOffset(983, 38)
card.SubTextShadow.Size = UDim2.fromOffset(983, 38)
for _, n in { "Icon", "IconShadow" } do card[n].Image = "rbxassetid://136024113568543" end -- the reel's placeholder

-- COLLECT! (left) and AGAIN (right): the reward's own two buttons
local claim = card.BtnUse
claim.Name = "BtnClaim"
for _, n in { "Label", "LabelShadow" } do claim[n].Text = "COLLECT!" end
local again = card.BtnClose
again.Name = "BtnAgain"
for _, n in { "Label", "LabelShadow" } do
	local l = again[n]
	l.Text = "AGAIN"
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Position = UDim2.fromOffset(18, l.Position.Y.Offset)
	l.Size = UDim2.fromOffset(112, l.Size.Y.Offset)
	l.TextScaled = false
	l.TextSize = 36
	local p = l:Clone()
	p.Name = if n == "Label" then "Price" else "PriceShadow"
	p.Text = "250"
	p.Position = UDim2.fromOffset(178, l.Position.Y.Offset)
	p.Size = UDim2.fromOffset(64, l.Size.Y.Offset)
	p.Parent = again
end
for _, n in { "GemShadow", "Gem" } do
	local g = Instance.new("ImageLabel")
	g.Name = n
	g.BackgroundTransparency = 1
	g.Image = GEM
	g.ScaleType = Enum.ScaleType.Fit
	g.Position = UDim2.fromOffset(132, if n == "Gem" then 20 else 23)
	g.Size = UDim2.fromOffset(42, 42)
	g.ImageColor3 = if n == "Gem" then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
	g.ImageTransparency = if n == "Gem" then 0 else 0.6
	g.ZIndex = 2
	g.Parent = again
end

local row = Instance.new("Frame")
row.Name = "ShortRow"
row.BackgroundTransparency = 1
row.Position = UDim2.fromOffset(again.Position.X.Offset, 1070)
row.Size = UDim2.fromOffset(250, 34)
row.ZIndex = again.ZIndex
row.Visible = false
for _, n in { "ShortShadow", "Short" } do
	local t = card.SubText:Clone()
	t.Name = n
	t.Text = "Need 250 more"
	t.TextSize = 30
	t.TextColor3 = if n == "Short" then Color3.fromRGB(255, 96, 96) else Color3.fromRGB(5, 5, 6)
	t.Position = UDim2.fromOffset(0, if n == "Short" then 0 else 2)
	t.Size = UDim2.fromOffset(250, 34)
	t.ZIndex = if n == "Short" then 2 else 1
	t.Parent = row
end
row.Parent = card

card.Parent = rev
rev.Parent = screen
return "reveal built"
