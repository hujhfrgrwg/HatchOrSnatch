-- HOS-EMOTE-003 (18 Oct, Matthew: "The reward UI needs to look like this"): the reveal is the game's reward popup
-- (YOU WON!, rays, the emote's picture, name, rarity line, New / duplicate line, COLLECT! and AGAIN) over a black
-- shade, built by tools/build/HOS-EMOTE-003/build_reveal.lua. The crate title goes while it shows.
local placeholderIcon: string? = nil
local function reveal(r: Result)
	local rev = find(screen, "Reveal") :: GuiObject
	if not rev then return end
	local info = rarityInfo(r.prize.rarity)
	local card = (rev:FindFirstChild("Card") or rev) :: GuiObject
	-- the big picture: a RevealTile over the card's Icon; decorateTile puts the emote's still in it
	local old = find(rev, "RevealTile")
	if old then old:Destroy() end
	local icon = card:FindFirstChild("Icon") :: GuiObject?
	if icon and icon:IsA("ImageLabel") then
		if not placeholderIcon then placeholderIcon = icon.Image end
		local holder = Instance.new("Frame")
		holder.Name = "RevealTile"
		holder.BackgroundTransparency = 1
		holder.Position = icon.Position
		holder.Size = icon.Size
		holder.ZIndex = icon.ZIndex
		local ph = icon:Clone()
		ph.Position = UDim2.new()
		ph.Size = UDim2.fromScale(1, 1)
		ph.Image = r.prize.image or placeholderIcon or ""
		ph.Visible = true
		ph.Parent = holder
		holder.Parent = card
		show(icon, false)
		show(card:FindFirstChild("IconShadow"), false)
		if opts.decorateTile then pcall(opts.decorateTile, holder, r.prize) end
	end
	setText(card, "ItemName", r.prize.name)
	setText(card, "KindText", string.upper(r.prize.rarity) .. " EMOTE")
	local kind = card:FindFirstChild("KindText")
	if kind and kind:IsA("TextLabel") then
		kind.TextColor3 = info.glow
		local g = kind:FindFirstChildOfClass("UIGradient") -- (the export baked a design colour into it)
		if g then g.Color = ColorSequence.new(Color3.new(1, 1, 1)) end
	end
	local isNew = r.isNew ~= false
	setText(card, "SubText", if isNew then "New emote!" else (r.dupeText or "You already have this one"))
	local sub = card:FindFirstChild("SubText")
	if sub and sub:IsA("TextLabel") then
		sub.TextColor3 = if isNew then Color3.fromRGB(110, 235, 90) else Color3.fromRGB(255, 214, 92)
		local g = sub:FindFirstChildOfClass("UIGradient")
		if g then g.Color = ColorSequence.new(Color3.new(1, 1, 1)) end
	end
	-- COLLECT! alone in the middle, or COLLECT! | AGAIN
	local claim = card:FindFirstChild("BtnClaim") :: GuiObject?
	local again = card:FindFirstChild("BtnAgain") :: GuiObject?
	local hasAgain = r.againPrice ~= nil and opts.onOpenAgain ~= nil
	show(again, hasAgain)
	if claim then
		local left = if hasAgain then 240 else (card.Size.X.Offset - claim.Size.X.Offset) / 2
		claim.Position = UDim2.fromOffset(left + claim.Size.X.Offset * claim.AnchorPoint.X, claim.Position.Y.Offset) -- (juiced: centre-anchored)
		if claim:GetAttribute("JuiceRest") ~= nil then claim:SetAttribute("JuiceRest", claim.Position) end
	end
	if r.againPrice then setText(card, "Price", r.againPrice) end
	local poor = r.canAffordAgain == false
	local art = again and again:FindFirstChild("Art")
	if art and art:IsA("ImageLabel") then
		art.ImageColor3 = if poor then Color3.fromRGB(120, 120, 130) else Color3.new(1, 1, 1)
	end
	show(find(card, "ShortRow"), poor and hasAgain)
	if r.shortText then setText(card, "Short", r.shortText) end
	-- rays in the rarity colour, turning
	local rays = find(card, "Rays") :: GuiObject
	if rays then
		tint(rays, info.glow)
		for _, d in rays:GetDescendants() do
			if d:IsA("ImageLabel") then (d :: ImageLabel).ImageColor3 = info.glow end
		end
	end
	if raysConn then raysConn:Disconnect() end
	if rays then
		raysConn = RunService.RenderStepped:Connect(function(dt)
			rays.Rotation = (rays.Rotation + dt * 15) % 360
		end)
	end
	show(find(screen, "CrateTitle"), false) -- YOU WON! takes its place
	show(find(screen, "Reel"), false) -- and the reel goes: the shade shows the world, like the spin wheel's popup
	show(rev, true)
	local shade = rev:FindFirstChild("Shade") :: GuiObject?
	if shade then fade(shade, 1, 0.15, 0.25) end
	if card ~= rev then
		local s = card:FindFirstChildOfClass("UIScale") or scaleOf(card)
		local base = s:GetAttribute("Base") or 1
		s.Scale = base * 0.6
		tween(s, EmoteCrateSpin.TIMING.reveal, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = base })
	end
	cue("reveal")
end

