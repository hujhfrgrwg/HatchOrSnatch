--!strict
-- EggShardMeter (HOS-EGG-002, 17 Oct ~19:40, no roll): the HUD card's meter. One meter a match, marks at
-- EggConfig.CHARGE.MARKS (2.0 EPIC, 5.0 LEGENDARY). Seg1 fills 0 -> MARKS[1], Seg2 MARKS[1] -> MARKS[2] (the export's
-- two-mark meter); a card still built with Seg1..Seg4 fills them evenly across 0 -> CAP. Once the meter has passed a mark
-- that isn't spent yet (EOS_EggMarks = marks spent), the card's tag reads "NEXT SAFE: EPIC".
-- Hook (one line in EggUIController.refreshCard): card(cur, tag, charge, bonusShowing, H)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EggConfig = require(Shared:WaitForChild("EggConfig"))
local EggLogic = require(Shared:WaitForChild("EggLogic"))

local Meter = {}

local function fillSeg(seg: Instance?, part: number)
	local fill = seg and seg:FindFirstChild("Fill")
	if not (fill and fill:IsA("GuiObject")) then return end
	local full = fill:GetAttribute("FullW") or fill.Size.X.Offset
	fill:SetAttribute("FullW", full)
	fill.ClipsDescendants = true
	fill.Visible = part > 0.01
	fill.Size = UDim2.new(0, math.max(2, (full :: number) * part), fill.Size.Y.Scale, fill.Size.Y.Offset)
end

-- a passed, unspent mark: the step the next safe gives (EggLogic.safetyStep). nil when none waits, and while the egg
-- is still Common (crossing 1 makes it Rare anyway and the mark waits for the safe after)
function Meter.pending(charge: number): string?
	local plr = Players.LocalPlayer
	local used = tonumber(plr:GetAttribute("EOS_EggMarks")) or 0
	local passed = 0
	for _, at in EggConfig.CHARGE.MARKS do
		if charge >= at - 1e-9 then passed += 1 end
	end
	if passed <= used then return nil end
	local rarity = EggLogic.rarityForLevel(plr:GetAttribute("EOS_Tier") or 1)
	return EggLogic.guaranteedStep(rarity)
end

function Meter.card(cur: Instance?, tag: Instance?, charge: number, bonusShowing: boolean, H: any)
	local meter = cur and H.find(cur, "Charge")
	if not meter then return end
	H.show(meter, true)
	local C = EggConfig.CHARGE
	local twoMark = meter:FindFirstChild("Seg2") ~= nil and meter:FindFirstChild("Seg3") == nil
	if twoMark then
		local prev = 0
		for i, at in C.MARKS do
			fillSeg(meter:FindFirstChild("Seg" .. i), math.clamp((charge - prev) / (at - prev), 0, 1))
			prev = at
		end
	else
		for i = 1, 4 do
			fillSeg(meter:FindFirstChild("Seg" .. i), math.clamp(charge / C.CAP * 4 - (i - 1), 0, 1))
		end
	end
	local glow = cur and H.find(cur, "ChargeGlow")
	if glow and glow:IsA("ImageLabel") then
		glow.Visible = charge > 0 -- Reduce effects keeps the glow (the one charge cue it allows)
		glow.ImageTransparency = if charge >= C.MARKS[1] - 1e-9 then 0.05 else 0.5
	end
	local nxt = Meter.pending(charge)
	if tag and not bonusShowing then
		if nxt then H.setText(tag, "BonusText", "NEXT SAFE: " .. string.upper(nxt)) end
		H.show(tag, nxt ~= nil)
	end
end

-- phones (Hunter, 17 Oct ~20:03: "this pill looks unnecessarily large on mobile"): EggUIController's applyCompact hides
-- the card's small lines (title, marks, "pays") but the glass kept its desktop height, leaving a dark empty half. In
-- compact the glass hugs the slot, the rarity word and the meter, and the card is scaled to phone-chip size.
-- Hook (one line in refreshCard, after applyCompact): compact(card)
local COMPACT_H = 134 -- design px: the slot (20 .. 120) + the meter (~100 .. 122) + 12 padding
local COMPACT_SCALE = 1 -- 0.82 made RARE ~12 px and the meter ~5 px on an iPhone 14: the hug alone removes the dead space
-- the card as a shard (Hunter approved 17 Oct ~20:18): the Runner looks read "YOUR SHARD" with the shard icon of their
-- rarity (exported with the egg icons); done once per look
local SHARD_ICON = { common = "piece_common", rare = "piece_rare", epic = "piece_epic", legendary = "piece_crowned" }
local function reskin(card: Instance)
	local ui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local kitMod = ui and ui:FindFirstChild("EggUI") and ui.EggUI:FindFirstChild("UIKit")
	local okK, K = pcall(function() return kitMod and require(kitMod) end)
	for _, v in card:GetChildren() do
		local r = v.Name:match("^Runner_(%a+)$")
		if r and SHARD_ICON[r] and not v:GetAttribute("ShardSkin") then
			v:SetAttribute("ShardSkin", true)
			for _, n in { "EggTitle", "EggTitleShadow" } do
				local l = v:FindFirstChild(n, true)
				if l and l:IsA("TextLabel") then l.Text = "YOUR SHARD" end
			end
			local slot = v:FindFirstChild("EggSlot", true)
			for _, n in { "Icon", "IconShadow" } do
				local img = slot and slot:FindFirstChild(n, true)
				if img and okK and K and K.icon then pcall(K.icon, img, SHARD_ICON[r]) end
			end
		end
	end
end

function Meter.compact(card: Instance?)
	if not card then return end
	reskin(card)
	local on = card:GetAttribute("Compact") == true
	for _, v in card:GetChildren() do
		local glass = v:FindFirstChild("Glass")
		if glass and glass:IsA("GuiObject") then
			local baseH = glass:GetAttribute("BaseH") or glass.Size.Y.Offset
			glass:SetAttribute("BaseH", baseH)
			local h = if on then COMPACT_H else baseH :: number
			glass.Size = UDim2.new(glass.Size.X, UDim.new(0, h))
			local shadow = v:FindFirstChild("DropShadow")
			if shadow and shadow:IsA("GuiObject") then
				shadow.Position = UDim2.new(shadow.Position.X, UDim.new(0, glass.Position.Y.Offset + h))
			end
		end
	end
	local s = card:FindFirstChild("CompactScale")
	if on and not s then
		s = Instance.new("UIScale")
		s.Name = "CompactScale"
		s.Parent = card
	end
	if s and s:IsA("UIScale") then s.Scale = if on then COMPACT_SCALE else 1 end
end

-- keep the card's plate below Roblox's top-left buttons (the top-bar inset); run after the card is placed each frame.
-- Hook (one line at the end of EggUIController.hideOldCard): clearTopbar(card, root)
function Meter.clearTopbar(card: Instance?, root: Instance?)
	if not (card and card:IsA("GuiObject") and card.Visible and root) then return end
	local shown
	for _, v in card:GetChildren() do
		if v:IsA("GuiObject") and v.Visible and v.Name ~= "BonusTag" then shown = v break end
	end
	local glass = shown and shown:FindFirstChild("Glass")
	if not (glass and glass:IsA("GuiObject")) then return end
	local inset = game:GetService("GuiService"):GetGuiInset().Y
	local gui = card:FindFirstAncestorWhichIsA("ScreenGui")
	local top = glass.AbsolutePosition.Y + (if gui and gui.IgnoreGuiInset then 0 else inset)
	local want = inset + 6
	if top < want then
		local fit = root:FindFirstChildOfClass("UIScale")
		local k = (fit and fit.Scale) or 1
		card.Position += UDim2.fromOffset(0, (want - top) / math.max(k, 1e-3))
	end
end

return Meter
