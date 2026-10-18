--!strict
-- EggResultsRow (HOS-EGG-002 fixes, 17 Oct): the results card's shard line as "+N FILL" (a pill in the shard's colour
-- with the shard icon, and the small rarity word), and the small incubator egg's "x / 18 FILL" -> "x / 36 FILL".
-- Writes into Results v2's EggBlock (PointsUI ...ResultsV2.Panel.EggBlock, the match-points thread's layout) without
-- moving it: PieceIcon / PieceText are hidden and a clone of EggUITemplates.FillLine_<rarity> sits where they were.
-- Hooks (one line each in EggUIController): apply(lb, shard, H) in applyResults; mini(mini, view, H) wherever the mini
-- egg is refilled.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("EggConfig"))

local Row = {}

local GOLD, GREEN = Color3.fromRGB(255, 210, 58), Color3.fromRGB(124, 240, 90)
local NARROW = 320 -- EggBlock narrower than this on screen (px) = a phone: the shard word goes to one bigger word
local TEMPLATES = "EggUITemplates"

local function hideTwin(lb: Instance, name: string, on: boolean, H: any)
	H.show(H.find(lb, name), on)
	H.show(H.find(lb, name .. "Shadow"), on)
end

function Row.apply(lb: Instance, shard: string?, H: any)
	local old = lb:FindFirstChild("EggFillLine", true)
	if old then old:Destroy() end
	local pieceText = H.find(lb, "PieceText")
	local tf = ReplicatedStorage:FindFirstChild(TEMPLATES)
	local tpl = shard and tf and tf:FindFirstChild("FillLine_" .. shard)
	if not (shard and pieceText and pieceText:IsA("GuiObject") and tpl) then
		hideTwin(lb, "PieceIcon", shard ~= nil, H)
		return
	end
	local anchor = H.find(lb, "PieceIcon")
	local host = pieceText.Parent :: Instance
	local line = tpl:Clone() :: GuiObject
	line.Name = "EggFillLine"
	line.AnchorPoint = Vector2.zero
	line.Size = UDim2.fromOffset(0, 0)
	line.Position = UDim2.fromOffset(0, 0)
	line.Visible = true
	line.ZIndex = pieceText.ZIndex
	line.Parent = host
	local w = EggConfig.SHARD_WEIGHT[shard]
	if w then H.setText(line, "FillText", ("+%s FILL"):format(H.num(w))) end -- the number follows the config
	-- line the pill up with the old line: its left edge on PieceIcon's (or PieceText's), centred on PieceText's height
	local pill = line:FindFirstChild("FillPill", true) :: GuiObject?
	local hostG = if host:IsA("GuiObject") then host else nil
	if pill and hostG then
		local sc = hostG.AbsoluteSize.X / math.max(1, hostG.Size.X.Offset)
		local left = if anchor and anchor:IsA("GuiObject") then anchor.AbsolutePosition.X else pieceText.AbsolutePosition.X
		local cy = pieceText.AbsolutePosition.Y + pieceText.AbsoluteSize.Y / 2
		local d = (Vector2.new(left, cy) - Vector2.new(pill.AbsolutePosition.X, pill.AbsolutePosition.Y + pill.AbsoluteSize.Y / 2)) / math.max(sc, 1e-3)
		line.Position = UDim2.fromOffset(d.X, d.Y)
	end
	hideTwin(lb, "PieceIcon", false, H)
	hideTwin(lb, "PieceText", false, H)
	Row.unwrap(line)
	-- narrow (phones, 844 x 390): the two-line "RARE / SHARD" word turns into one bigger rarity word beside the pill
	if hostG and hostG.AbsoluteSize.X < NARROW then
		hideTwin(line, "ShardWord2", false, H)
		local w1 = line:FindFirstChild("ShardWord", true)
		local pillG = line:FindFirstChild("FillPill", true)
		if w1 and w1:IsA("TextLabel") and pillG and pillG:IsA("GuiObject") then
			local sh = w1.Parent and w1.Parent:FindFirstChild("ShardWordShadow")
			local base = w1:GetAttribute("BaseTS") or w1.TextSize
			w1:SetAttribute("BaseTS", base)
			for _, l in { w1, sh } do
				if l and l:IsA("TextLabel") then l.TextSize = math.floor((base :: number) * 1.5) end
			end
			-- centre the word on the pill's height
			local dy = (pillG.AbsolutePosition.Y + pillG.AbsoluteSize.Y / 2) - (w1.AbsolutePosition.Y + w1.AbsoluteSize.Y / 2)
			local sc = hostG.AbsoluteSize.X / math.max(1, hostG.Size.X.Offset)
			for _, l in { w1, sh } do
				if l and l:IsA("GuiObject") then l.Position += UDim2.fromOffset(0, dy / math.max(sc, 1e-3)) end
			end
		end
	end
	Row.matchAlpha(line, H.find(lb, "EggText"))
end

-- labels size to their text and never wrap (a wrapped "0 / 18 FILL" lost its "FILL" on phones: the font rounds up at
-- small scales, so text measured to fit at 1920 can spill by a pixel). Shadow twins follow.
function Row.unwrap(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") then
			d.TextWrapped = false
			d.TextTruncate = Enum.TextTruncate.None
			d.AutomaticSize = Enum.AutomaticSize.X
		end
	end
end

-- Results v2 fades each part in with RV2.setAlpha, which caches every descendant's resting transparency in an
-- attribute "RVb<prop>" and sets prop = 1 - (1 - base) * alpha on each tween step. Pieces we add after its alpha pass
-- (EggFillLine, EggMini) would show at full opacity until its delayed fade starts: give them the same attributes and
-- the box's current alpha, read off a label it already faded (ref), so its own tween carries them from here.
local PROPS = { "BackgroundTransparency", "TextTransparency", "ImageTransparency", "Transparency" }
local function alphaOf(ref: Instance?): number?
	if not (ref and ref:IsA("TextLabel")) then return nil end
	local base = ref:GetAttribute("RVbTextTransparency")
	if type(base) ~= "number" or base >= 1 then return nil end
	return math.clamp((1 - ref.TextTransparency) / (1 - base), 0, 1)
end
function Row.matchAlpha(root: Instance, ref: Instance?)
	local a = alphaOf(ref)
	if a == nil then return end -- not inside a Results v2 fade
	local function one(d: Instance)
		local isGui, isStroke = d:IsA("GuiObject"), d:IsA("UIStroke")
		if not (isGui or isStroke) then return end
		for _, p in PROPS do
			local ok = (p == "BackgroundTransparency" and isGui) or (p == "Transparency" and isStroke)
				or (p == "TextTransparency" and (d:IsA("TextLabel") or d:IsA("TextButton")))
				or (p == "ImageTransparency" and (d:IsA("ImageLabel") or d:IsA("ImageButton")))
			if ok then
				local key = "RVb" .. p
				local base = d:GetAttribute(key)
				if base == nil then
					base = (d :: any)[p]
					d:SetAttribute(key, base)
				end
				if (base :: number) < 1 then (d :: any)[p] = 1 - (1 - base :: number) * a end
			end
		end
	end
	one(root)
	for _, d in root:GetDescendants() do one(d) end
end

-- Results v2 is opening (its last beat, the NEXT button, not yet faded in): run fn once it has settled. Returns true
-- when fn may run now (no results on screen, or they have settled). The upgrade banner never draws over the open.
local function resultsGroup(): GuiObject?
	local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	local pts = pg and pg:FindFirstChild("PointsUI")
	local g = pts and pts:FindFirstChild("ResultsV2", true)
	return if g and g:IsA("GuiObject") then g else nil
end
local function opening(): boolean
	local g = resultsGroup()
	if not g then return false end
	local x: Instance? = g
	while x and x:IsA("GuiObject") do -- the group and every screen above it must be showing
		if not x.Visible then return false end
		x = x.Parent
	end
	if x and x:IsA("ScreenGui") and not x.Enabled then return false end
	local nextBtn = g:FindFirstChild("Continue", true)
	local ref = nextBtn and nextBtn:FindFirstChildWhichIsA("TextLabel", true)
	local a = alphaOf(ref)
	return a ~= nil and a < 0.999
end
function Row.whenSettled(fn: () -> ()): boolean
	if not opening() then return true end
	task.spawn(function()
		local t0 = os.clock()
		while opening() and os.clock() - t0 < 4 do task.wait(0.05) end
		task.wait(0.15)
		fn()
	end)
	return false
end

-- the upgrade banner's no-roll wording (17 Oct ~18:47): "SHARD UPGRADED: EPIC", shrunk to fit its line
function Row.bannerText(b: Instance, to: string, H: any)
	local word = string.upper(to)
	H.setText(b, "Title", "SHARD UPGRADED: " .. word)
	H.setText(b, "Sub", "Keep it safe to the end")
	local t = H.find(b, "Title")
	if t and t:IsA("TextLabel") and t.TextBounds.X > 0 and t.AbsoluteSize.X > 0 and t.TextBounds.X > t.AbsoluteSize.X then
		local ts = math.floor(t.TextSize * t.AbsoluteSize.X / t.TextBounds.X)
		t.TextSize = ts
		local sh = t.Parent and t.Parent:FindFirstChild(t.Name .. "Shadow")
		if sh and sh:IsA("TextLabel") then sh.TextSize = ts end
	end
end

-- the small incubator egg: toward the hatch (green, "x / 18 FILL") until it can hatch, then toward the cap (gold,
-- "x / 36 FILL"). need is 22.5 with a focus.
function Row.mini(mini: Instance?, view: any, H: any)
	if not (mini and view and view.need) then return end
	local cap = view.cap or view.need * 2
	local f = view.fill or 0
	local ready = f >= view.need
	local toward = if ready then cap else view.need
	H.ring(H.find(mini, "MiniRing"), math.min(1, f / toward), if ready then GOLD else GREEN)
	H.setText(mini, "MiniFill", ("%s / %s FILL"):format(H.num(f), H.num(toward)))
	H.tint(H.find(mini, "MiniFill"), if ready then GOLD else Color3.fromRGB(210, 210, 216))
	local egg = H.find(mini, "MiniEgg")
	if egg and H.K then H.K.icon(egg, if ready then "egg_golden" else "egg_starter") end
	Row.layout(mini, H)
	local block = mini.Parent
	Row.matchAlpha(mini, block and H.find(block, "EggText")) -- fades with the egg box (Results v2's open)
end

-- the mini egg's label goes above its ring (the ShardRow template has it below, which sat on the card's bottom border:
-- Hunter's screenshot, 17 Oct), and the ring + label stay inside the card with PAD design px on every side. Measured
-- in screen space, so it holds at any FitScale (1920 and phones); safe to run again.
local PAD = 10
function Row.layout(mini: Instance, H: any)
	local ring, lab = H.find(mini, "MiniRing"), H.find(mini, "MiniFill")
	local host = mini.Parent
	Row.unwrap(mini)
	if not (ring and lab and host and mini:IsA("GuiObject") and ring:IsA("GuiObject") and lab:IsA("GuiObject") and host:IsA("GuiObject")) then return end
	local sc = host.AbsoluteSize.X / math.max(1, host.Size.X.Offset)
	if sc <= 0 then return end
	local function shift(g: Instance?, d: Vector2)
		if g and g:IsA("GuiObject") then g.Position += UDim2.fromOffset(d.X / sc, d.Y / sc) end
	end
	local rc = ring.AbsolutePosition + ring.AbsoluteSize / 2
	local want = Vector2.new(rc.X - lab.AbsoluteSize.X / 2, ring.AbsolutePosition.Y - 4 * sc - lab.AbsoluteSize.Y)
	local d = want - lab.AbsolutePosition
	shift(lab, d)
	shift(lab.Parent and lab.Parent:FindFirstChild(lab.Name .. "Shadow"), d)
	local top = math.min(lab.AbsolutePosition.Y, ring.AbsolutePosition.Y)
	local bottom = math.max(lab.AbsolutePosition.Y + lab.AbsoluteSize.Y, ring.AbsolutePosition.Y + ring.AbsoluteSize.Y)
	local right = math.max(lab.AbsolutePosition.X + lab.AbsoluteSize.X, ring.AbsolutePosition.X + ring.AbsoluteSize.X)
	local hp, hs, pad = host.AbsolutePosition, host.AbsoluteSize, PAD * sc
	local dx = math.min(0, hp.X + hs.X - pad - right)
	local dy = 0
	if bottom > hp.Y + hs.Y - pad then dy = hp.Y + hs.Y - pad - bottom end
	if top + dy < hp.Y + pad then dy = hp.Y + pad - top end
	shift(mini, Vector2.new(dx, dy))
end

return Row
