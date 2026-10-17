--!strict
-- PointsController (HOS-PTS-001, 17 Oct 2026): the client half of match points, revive and the podium. Booted by
-- StarterGui.PointsUI's Controller (no ClientMain line). It only clones the approved templates
-- (ReplicatedStorage.PointsUITemplates, built from ui/build.py section HOS-PTS-001) and fills them.
--   Pop        "+100 Reached Safety!" beside your Runner (screen right of centre), stacks upward, never pauses play
--   Juke       the short JUKE! slam in the upper middle (you only)
--   Revive     the ring billboard over a downed teammate: Runners within REVIVE_SHOW_RADIUS see it pop in,
--              within REVIVE_PROMPT_RADIUS the key cap pops in; holding fills the ring green (10 Hz checks)
--   Results    the old Results panel is closed (UIC.closeResults) while Points is on; instead: the podium
--              cutscene (Controllers/Cinematic: wide, 3rd, 2nd, 1st, confetti), then the Points screen
--              (leaderboard + your rewards with the egg)
--   HUD        CLEAN STREAK pips hidden while GameConfig.Match.FIXED_CROSSINGS is set
-- Server halves: PointsService (Pop, Juke, Board remotes in ReplicatedStorage.EOS_Points), ReviveService
-- (ProximityPrompts tagged EOS_RevivePrompt), PodiumService (workspace.HOS_Podium during RESULTS).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PointsConfig = require(Shared:WaitForChild("PointsConfig"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local EmoteConfig = require(Shared:WaitForChild("EmoteConfig"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local PointsController = {}

local gui: ScreenGui
local UI: any
local K: any
local screen: Frame? = nil
local eosAssets: any = nil
local board: any = nil
local myEgg = { rarity = "common", from = nil :: string?, at = nil :: number? }

local RV = PointsConfig.Revive
local OUT = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local IN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- ===== small helpers =====
local KINDS = { -- kind -> words, icon, colour (the approved mock's fills)
	safe = { "Reached Safety!", "safe", Color3.fromRGB(184, 255, 74) },
	hero = { "Hero crossing!", "crown", Color3.fromRGB(255, 210, 58) },
	juke = { "Juke!", "runner", Color3.fromRGB(255, 255, 255) },
	revive = { "Revive!", "plus", Color3.fromRGB(106, 216, 255) },
	catch = { "Catch!", "catcher", Color3.fromRGB(255, 90, 90) },
	snatch_rare = { "Rare egg snatched!", "egg_shiny", Color3.fromRGB(80, 160, 255) },
	snatch_epic = { "Epic egg snatched!", "egg_cosmic", Color3.fromRGB(178, 96, 255) },
	snatch_legendary = { "Legendary egg snatched!", "egg_golden", Color3.fromRGB(255, 196, 40) },
}
local RARITY = {
	common = { "COMMON", "egg_basic", "piece_common", Color3.fromRGB(184, 255, 74) },
	rare = { "RARE", "egg_shiny", "piece_rare", Color3.fromRGB(80, 160, 255) },
	epic = { "EPIC", "egg_cosmic", "piece_epic", Color3.fromRGB(178, 96, 255) },
	legendary = { "LEGENDARY", "egg_golden", "piece_crowned", Color3.fromRGB(255, 196, 40) },
}

local function iconId(slug: string): string?
	local mine = gui:FindFirstChild("AssetIds")
	local ok, a = pcall(function()
		return if mine then require(mine :: ModuleScript) else nil
	end)
	local id = ok and a and a.icons and a.icons[slug]
	if id then
		return id
	end
	if not eosAssets then
		local eos = player.PlayerGui:FindFirstChild("EOSUI")
		local m = eos and eos:FindFirstChild("AssetIds")
		local ok2, b = pcall(function()
			return if m then require(m :: ModuleScript) else nil
		end)
		eosAssets = if ok2 and b then b else {}
	end
	return eosAssets.icons and eosAssets.icons[slug] or nil
end

local function setIcon(scope: Instance, name: string, slug: string)
	local id = iconId(slug)
	if not id then
		return
	end
	for _, d in ipairs(scope:GetDescendants()) do
		if d:IsA("ImageLabel") and (d.Name == name or d.Name == name .. "Shadow") then
			d.Image = id
		end
	end
end

local function find(scope: Instance?, name: string): Instance?
	return scope and scope:FindFirstChild(name, true)
end

local function setText(scope: Instance, name: string, text: string)
	UI.setText(scope, name, text)
end

-- the label's fill colour lives on its UIGradient (exported from the mock's fill class)
local function setFill(scope: Instance, name: string, c: Color3)
	local l = find(scope, name)
	if not l then
		return
	end
	local g = l:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(c)
	elseif l:IsA("TextLabel") then
		l.TextColor3 = c
	end
end

local function fade(g: Instance, t: number, info: TweenInfo)
	for _, d in ipairs(g:GetDescendants()) do
		if d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = t }):Play()
			local s = d:FindFirstChildOfClass("UIStroke")
			if s then
				TweenService:Create(s, info, { Transparency = t }):Play()
			end
		elseif d:IsA("ImageLabel") then
			TweenService:Create(d, info, { ImageTransparency = t }):Play()
		end
	end
end

-- the panel's own transparencies, so it fades as one piece (Leaderboard is a Frame, not a CanvasGroup)
type Fader = { list: { { inst: Instance, prop: string, base: number } }, alpha: number }
local function makeFader(root: Instance): Fader
	local list = {}
	local function add(inst: Instance, prop: string, base: number)
		if base < 1 then
			table.insert(list, { inst = inst, prop = prop, base = base })
		end
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then
			add(d, "BackgroundTransparency", d.BackgroundTransparency)
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				add(d, "TextTransparency", (d :: TextLabel).TextTransparency)
			elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
				add(d, "ImageTransparency", (d :: ImageLabel).ImageTransparency)
			end
		elseif d:IsA("UIStroke") then
			add(d, "Transparency", d.Transparency)
		end
	end
	return { list = list, alpha = 1 }
end
local function setAlpha(f: Fader, a: number) -- 1 = as built, 0 = gone
	f.alpha = a
	for _, e in ipairs(f.list) do
		(e.inst :: any)[e.prop] = 1 - (1 - e.base) * a
	end
end
local function fadeTo(f: Fader, a: number, info: TweenInfo) -- tween a Fader's alpha (restores the built look at 1)
	local nv = Instance.new("NumberValue")
	nv.Value = f.alpha
	nv.Changed:Connect(function(v)
		setAlpha(f, v)
	end)
	local tw = TweenService:Create(nv, info, { Value = a })
	tw.Completed:Once(function()
		setAlpha(f, a)
		nv:Destroy()
	end)
	tw:Play()
end

local function rarityOf(level: number?): string
	return PointsConfig.rarityForLevel(level)
end

-- ===== points pops =====
local stack: { GuiObject } = {}
local popHolder: Frame? = nil
local lastPopAt = -math.huge -- the round board waits for the pop (and the SAFE! banner fired with it)
local bannerUntil = -math.huge -- and for UIController's own SAFE! / CAUGHT! / TOO SLOW! banner (1.4 / 1.6 s)
local function holder(): Frame
	if popHolder and popHolder.Parent then
		return popHolder
	end
	local f = Instance.new("Frame") -- an invisible anchor, not a look: the pops are the approved template
	f.Name = "PtsPops"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0, 1)
	f.Position = UDim2.fromScale(0.545, 0.64) -- right of your Runner, under the crosshair line
	f.Size = UDim2.fromOffset(1, 1)
	f.Parent = K.overlay()
	popHolder = f
	return f
end

local function onPop(t: any)
	if type(t) ~= "table" or type(t.kind) ~= "string" then
		return
	end
	local k = KINDS[t.kind]
	lastPopAt = os.clock()
	local p = K.template("PointsPop") :: GuiObject?
	if not k or not p then
		return
	end
	setText(p, "PointsText", ("+%d PTS"):format(tonumber(t.amount) or 0)) -- the one points look: teal pill
	setText(p, "WordsText", k[1])
	setIcon(p, "Icon", k[2])
	local sc = K.scaled(p)
	p.AnchorPoint = Vector2.new(0, 1)
	p.Position = UDim2.fromOffset(0, 0)
	p.Parent = holder()
	-- older pops move up and fade a step
	for i, old in ipairs(stack) do
		if old.Parent then
			local lift = (#stack - i + 1) * 118 * sc.Scale
			TweenService:Create(old, OUT, { Position = UDim2.fromOffset(0, -lift) }):Play()
		end
	end
	table.insert(stack, p)
	while #stack > 4 do
		local o = table.remove(stack, 1)
		if o then
			o:Destroy()
		end
	end
	local base = sc.Scale
	sc.Scale = base * 0.6
	TweenService:Create(sc, OUT, { Scale = base }):Play()
	task.delay(1.6, function()
		if p.Parent then
			fade(p, 1, IN)
			task.delay(0.2, function()
				local i = table.find(stack, p)
				if i then
					table.remove(stack, i)
				end
				p:Destroy()
			end)
		end
	end)
end

-- ===== JUKE! =====
local jukeShown: GuiObject? = nil
local function onJuke(t: any)
	if type(t) ~= "table" or t.userId ~= player.UserId then
		return
	end
	if jukeShown then
		jukeShown:Destroy()
	end
	local w = K.template("JukeWord") :: GuiObject?
	if not w then
		return
	end
	jukeShown = w
	local sc = K.scaled(w)
	w.AnchorPoint = Vector2.new(0.5, 0.5)
	w.Position = UDim2.fromScale(0.5, 0.25) -- upper middle, clear of the crosshair
	w.Rotation = -6
	w.Parent = K.overlay()
	local base = sc.Scale
	sc.Scale = base * 0.6
	TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = base }):Play()
	task.delay(0.42, function()
		if w.Parent then
			fade(w, 1, IN)
			TweenService:Create(sc, IN, { Scale = base * 1.15 }):Play()
			task.delay(0.16, function()
				w:Destroy()
			end)
		end
	end)
end

-- ===== the revive ring =====
type Ring = { prompt: ProximityPrompt, bb: BillboardGui, ring: GuiObject, scale: UIScale, keyOn: boolean, shown: boolean, holdAt: number?, tap: TextButton?, fader: any }
local rings: { [ProximityPrompt]: Ring } = {}

local function cooldown(frame: Instance?, frac: number, c: Color3)
	-- the exported conic wedge: halves R / L, each a clipped round disc masked by a rotating UIGradient
	-- (Builder.cooldown's layout: the edge is always the circle, never a square corner)
	if not frame then
		return
	end
	local a = math.clamp(frac, 0, 1) * 360
	for _, n in ipairs({ "R", "L" }) do
		local half = frame:FindFirstChild(n) :: Frame?
		local arc = half and half:FindFirstChild("Arc") :: Frame?
		local g = arc and arc:FindFirstChildOfClass("UIGradient")
		if half and arc and g then
			arc.BackgroundColor3 = c
			if n == "R" then
				half.Visible = a > 0
				g.Rotation = math.min(a, 180)
			else
				half.Visible = a > 180
				g.Rotation = a
			end
		end
	end
end

local function keyMode(r: Ring)
	local key = find(r.ring, "Key")
	if not key then
		return
	end
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local pad = UserInputService.GamepadEnabled and UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
	for _, d in ipairs(key:GetDescendants()) do
		if d.Name == "KeyIcon" or d.Name == "KeyIconShadow" then
			(d :: GuiObject).Visible = pad
			if pad and d:IsA("ImageLabel") then
				d.Image = UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonX)
			end
		elseif d.Name == "KeyText" or d.Name == "KeyTextShadow" then
			(d :: GuiObject).Visible = not pad
			if d:IsA("TextLabel") then
				d.Text = if touch then "HOLD" else "E"
				d.TextScaled = touch
			end
		end
	end
end

local function dropRing(prompt: ProximityPrompt)
	local r = rings[prompt]
	if not r then
		return
	end
	rings[prompt] = nil
	if r.tap then
		r.tap:Destroy()
	end
	TweenService:Create(r.scale, IN, { Scale = r.scale.Scale * 0.6 }):Play()
	if r.fader then
		fadeTo(r.fader, 0, IN)
	else
		fade(r.ring, 1, IN)
	end
	task.delay(0.16, function()
		r.bb:Destroy()
	end)
end

local function makeRing(prompt: ProximityPrompt, root: BasePart): Ring?
	local ring = K.template("ReviveRing") :: GuiObject?
	if not ring then
		return nil
	end
	local bb = Instance.new("BillboardGui") -- the world anchor for the approved template
	bb.Name = "PtsReviveRing"
	bb.Adornee = root
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(132 * 1.5, 188 * 1.5) -- pixels with headroom (billboards clip to Size)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	bb.MaxDistance = RV.REVIVE_SHOW_RADIUS + 10
	bb.ResetOnSpawn = false
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Parent = bb
	local sc = Instance.new("UIScale")
	sc.Scale = 0.6
	sc.Parent = ring
	bb.Parent = player.PlayerGui
	local key = find(ring, "Key") :: GuiObject?
	if key then
		key.Visible = false
	end
	for _, n in ipairs({ "DropShadow" }) do
		local ds = ring:FindFirstChild(n, true)
		if ds and ds.Parent and ds.Parent:FindFirstChild("Key") and (ds :: GuiObject).Position.Y.Offset > 100 then
			(ds :: GuiObject).Visible = false -- the key's shadow follows the key
		end
	end
	local fader = makeFader(ring) -- HOS-PTS-001: fade to the built look (shadows stay soft), not to fully opaque
	setAlpha(fader, 0)
	fadeTo(fader, 1, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	TweenService:Create(sc, OUT, { Scale = 1 }):Play()
	local r: Ring = { prompt = prompt, bb = bb, ring = ring, scale = sc, keyOn = false, shown = true, holdAt = nil, tap = nil, fader = fader }
	keyMode(r)
	return r
end

local function setKey(r: Ring, on: boolean)
	if r.keyOn == on then
		return
	end
	r.keyOn = on
	local key = find(r.ring, "Key") :: GuiObject?
	if key then
		key.Visible = on
		local ks = key:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		ks.Parent = key
		if on then
			ks.Scale = 0.6
			TweenService:Create(ks, OUT, { Scale = 1 }):Play()
		end
	end
	-- touch: the whole ring is the tap-and-hold target (billboard buttons get no input under a full-screen HUD)
	if UserInputService.TouchEnabled and on and not r.tap then
		local b = Instance.new("TextButton")
		b.Name = "PtsReviveTap"
		b.Text = ""
		b.BackgroundTransparency = 1
		b.Size = UDim2.fromOffset(150, 150)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Parent = K.overlay()
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				r.prompt:InputHoldBegin()
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				r.prompt:InputHoldEnd()
			end
		end)
		r.tap = b
	elseif not on and r.tap then
		r.tap:Destroy()
		r.tap = nil
	end
end

local function freeRunner(): boolean
	return player:GetAttribute("EOS_Role") == "RUNNER" and player:GetAttribute("EOS_Safe") ~= true
end

local function reviveStep()
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local seen = {}
	for _, inst in ipairs(CollectionService:GetTagged("EOS_RevivePrompt")) do
		local prompt = inst :: ProximityPrompt
		local root = prompt.Parent :: BasePart?
		local char = root and root.Parent
		if root and char and char ~= player.Character then
			local d = if me then (root.Position - me.Position).Magnitude else math.huge
			local inShow = freeRunner() and d <= RV.REVIVE_SHOW_RADIUS
			if inShow then
				seen[prompt] = true
				local r = rings[prompt] or makeRing(prompt, root)
				if r then
					rings[prompt] = r
					setKey(r, d <= RV.REVIVE_PROMPT_RADIUS)
				end
			end
		end
	end
	for prompt in pairs(rings) do
		if not seen[prompt] or not prompt.Parent then
			dropRing(prompt)
		end
	end
end

local function ringFrame()
	local now = workspace:GetServerTimeNow()
	local cam = workspace.CurrentCamera
	for prompt, r in pairs(rings) do
		local root = prompt.Parent :: BasePart?
		local char = root and root.Parent
		local untilT = char and char:GetAttribute("EOS_DownedUntil") :: number?
		local cd = find(r.ring, "Cooldown")
		if r.holdAt then
			cooldown(cd, (os.clock() - r.holdAt) / math.max(0.1, prompt.HoldDuration), Color3.fromRGB(123, 232, 74))
		elseif untilT then
			cooldown(cd, (untilT - now) / RV.WINDOW, Color3.fromRGB(255, 77, 85))
		end
		if r.tap and cam and root then
			local p, on = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 3.2, 0))
			r.tap.Visible = on
			r.tap.Position = UDim2.fromOffset(p.X, p.Y)
		end
	end
end

-- ===== podium + results =====
local function nameOf(row: any): string
	if row.npcSlot then
		local ok, NpcSkins = pcall(function()
			return require(script.Parent:WaitForChild("NpcSkins", 2))
		end)
		if ok and NpcSkins and NpcSkins.nameForSlot then
			local n = NpcSkins.nameForSlot(row.npcSlot)
			if n then
				return n
			end
		end
	end
	return row.name or "Player"
end

local function stats(row: any): string
	return table.concat(row.stats or {}, "  ·  ")
end

local TWINS = { ShadowRing = true, DropShadow = true, InnerRing = true, InnerShade = true }
local function twinsOf(g: GuiObject): { GuiObject }
	local out = {}
	local parent = g.Parent
	if not parent then
		return out
	end
	for _, s in ipairs(parent:GetChildren()) do
		if s ~= g and s:IsA("GuiObject") and TWINS[s.Name] and math.abs(s.Position.X.Offset - g.Position.X.Offset) < 8
			and math.abs(s.Position.Y.Offset - g.Position.Y.Offset) < 8 and math.abs(s.Size.X.Offset - g.Size.X.Offset) < 12 then
			table.insert(out, s)
		end
	end
	return out
end
local function showTw(g: Instance?, on: boolean)
	if g and g:IsA("GuiObject") then
		g.Visible = on
		for _, t in ipairs(twinsOf(g)) do
			t.Visible = on
		end
	end
end
local function shiftTw(g: Instance?, x: number)
	if g and g:IsA("GuiObject") then
		local dx = x - g.Position.X.Offset
		for _, t in ipairs(twinsOf(g)) do
			t.Position += UDim2.fromOffset(dx, 0)
		end
		g.Position += UDim2.fromOffset(dx, 0)
	end
end

local function showGroup(name: string, on: boolean)
	local g = screen and screen:FindFirstChild(name) :: GuiObject?
	if g then
		g.Visible = on
	end
end

-- the row's points pill is a fixed column (build.py PTS_PILL_W): centre the trophy + number as one group, like the
-- HTML, whatever the number's width (PostFit gave the text box the full column, so it never shrinks)
local function rowPill(row: Instance, text: string)
	setText(row, "PointsText", text)
	local pill = find(row, "PtsPill") :: GuiObject?
	local l = pill and pill:FindFirstChild("PointsText") :: TextLabel?
	local icon = pill and pill:FindFirstChild("PtsIcon") :: GuiObject?
	if not (pill and l and icon) or pill.AbsoluteSize.X <= 0 then
		return
	end
	local sc = pill.AbsoluteSize.X / pill.Size.X.Offset
	local pw, iw, gap = pill.Size.X.Offset, icon.Size.X.Offset, 4
	local tw = math.min(l.TextBounds.X / sc, pw - iw - gap - 16)
	local x = math.floor((pw - (iw + gap + tw)) / 2)
	local dx = x - icon.Position.X.Offset
	for _, c in ipairs(pill:GetChildren()) do
		if c:IsA("GuiObject") and (c.Name == "PtsIcon" or c.Name == "PtsIconShadow") then
			c.Position += UDim2.fromOffset(dx, 0)
		elseif c:IsA("TextLabel") and (c.Name == "PointsText" or c.Name == "PointsTextShadow") then
			c.TextXAlignment = Enum.TextXAlignment.Left
			c.Position = UDim2.new(0, x + iw + gap, c.Position.Y.Scale, c.Position.Y.Offset)
			c.Size = UDim2.new(0, pw - (x + iw + gap) - 6, c.Size.Y.Scale, c.Size.Y.Offset)
		end
	end
end

-- role / outcome tag tints (Hunter 17 Oct): the round header's Runners blue and Catchers red, Hero or Chicken's
-- HERO_GOLD. The tag's border and word take the tint; the kit's dark plate and outline stay; CAUGHT stays neutral.
local TAG_TINT: { [string]: Color3 } = {
	RUNNER = Color3.fromRGB(106, 216, 255),
	ESCAPED = Color3.fromRGB(106, 216, 255),
	CATCHER = Color3.fromRGB(255, 90, 90),
	HERO = Color3.fromRGB(255, 196, 46),
	["TOP THIEF"] = Color3.fromRGB(255, 90, 90),
}
local TAG_EDGE = Color3.fromRGB(225, 225, 232)
-- the tag box follows its word at every screen size (HOS-PTS-001: "ESCAP" at phone size): plain text at the design
-- size (the root UIScale scales it), the box = the word + 14 px each side; its shadow twin keeps the same size
local function fitTag(tag: GuiObject)
	local label: TextLabel? = nil
	for _, l in ipairs(tag:GetChildren()) do
		if l:IsA("TextLabel") then
			local design = l:GetAttribute("UIDesignSize") :: number?
			local cap = l:FindFirstChild("UIFitCap")
			if cap then
				cap:Destroy()
			end
			l.TextScaled = false
			l.TextWrapped = false
			if design then
				l.TextSize = design
			end
			if not string.find(l.Name, "Shadow$") then
				label = l
			end
		end
	end
	if not label or tag.AbsoluteSize.X <= 0 then
		return
	end
	local sc = tag.AbsoluteSize.X / tag.Size.X.Offset
	local w = math.ceil(label.TextBounds.X / sc) + 28
	local twins = twinsOf(tag)
	local dw = w - tag.Size.X.Offset
	tag.Size += UDim2.fromOffset(dw, 0)
	for _, t in ipairs(twins) do
		t.Size += UDim2.fromOffset(dw, 0)
	end
	for _, l in ipairs(tag:GetChildren()) do
		if l:IsA("TextLabel") then
			l.Size = UDim2.new(0, w - 28, l.Size.Y.Scale, l.Size.Y.Offset)
			l.Position = UDim2.new(0, 14, l.Position.Y.Scale, l.Position.Y.Offset)
			l.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
end

local function tintTag(tag: Instance?, word: string)
	if not tag then
		return
	end
	if tag:IsA("GuiObject") then
		fitTag(tag)
	end
	local c = TAG_TINT[word]
	local edge = tag:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = c or TAG_EDGE
	end
	for _, l in ipairs(tag:GetChildren()) do
		if l:IsA("TextLabel") and not string.find(l.Name, "Shadow$") then
			local g = l:FindFirstChildOfClass("UIGradient")
			if g then
				g.Color = ColorSequence.new(c or Color3.new(1, 1, 1))
			else
				l.TextColor3 = c or Color3.new(1, 1, 1)
			end
		end
	end
end

local function fillRow(row: Instance, rank: number, r: any, thiefId: number?)
	setText(row, "RankText", tostring(rank))
	setText(row, "NameText", nameOf(r))
	setText(row, "OutcomeText", r.outcome)
	tintTag(find(row, "Outcome"), r.outcome)
	tintTag(find(row, "Thief"), "TOP THIEF")
	setText(row, "StatsText", stats(r))
	rowPill(row, ("%d PTS"):format(r.points))
	local isThief = thiefId ~= nil and r.userId == thiefId
	showTw(find(row, "Thief"), isThief)
	-- the outcome tag (and Top thief) sit right after the name, however long it is
	local nameL = find(row, "NameText") :: TextLabel?
	local outc = find(row, "Outcome") :: GuiObject?
	if nameL and outc then
		local x = nameL.Position.X.Offset + nameL.TextBounds.X / math.max(0.01, (nameL.AbsoluteSize.X / math.max(1, nameL.Size.X.Offset))) + 12
		shiftTw(outc, x)
		local th = find(row, "Thief") :: GuiObject?
		if th and isThief then
			shiftTw(th, x + outc.Size.X.Offset + 10)
		end
	end
	local head = find(row, "Head") :: GuiObject?
	require(script.Parent:WaitForChild("BotHeadshot")).fill(head, if r.userId > 0 then nil else r.npcSlot) -- HOS-BOT-001: NPC rows show the NPC's look
	if head and r.userId > 0 then
		local img = head:FindFirstChild("Shot") :: ImageLabel?
		if not img then
			local i = Instance.new("ImageLabel") -- the headshot is data inside the approved slot
			i.Name = "Shot"
			i.BackgroundTransparency = 1
			i.Size = UDim2.fromScale(1, 1)
			i.Parent = head
			img = i
		end
		(img :: ImageLabel).Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(r.userId)
	end
end

-- one pool of rows for both boards: built once and reused (nothing is created while rows move)
local function rowPool(tpl: GuiObject, n: number): { GuiObject }
	local rows = { tpl }
	for _, d in ipairs(tpl.Parent and tpl.Parent:GetChildren() or {}) do
		if d.Name == "RowClone" then
			table.insert(rows, d :: GuiObject)
		end
	end
	while #rows < n do
		local c = tpl:Clone()
		c.Name = "RowClone"
		c.Parent = tpl.Parent
		table.insert(rows, c)
	end
	for i = n + 1, #rows do
		rows[i].Visible = false
	end
	return rows
end

-- the subtitle's fill: Runner blue for an early win, else back to the exported dim fill
local function subTint(lb: Instance, c: Color3?)
	local l = find(lb, "SubText") :: TextLabel?
	local g = l and l:FindFirstChildOfClass("UIGradient")
	if not g then
		return
	end
	if g:GetAttribute("BaseColor") == nil then
		g:SetAttribute("BaseColor", g.Color)
	end
	g.Color = if c then ColorSequence.new(c) else g:GetAttribute("BaseColor") :: ColorSequence
end

local function fillBoard(results: any)
	if not screen or not board then
		return
	end
	local lb = screen:FindFirstChild("Leaderboard")
	local tpl = find(lb, "Row") :: GuiObject?
	local you = find(lb, "YouRow") :: GuiObject?
	if not lb or not tpl then
		return
	end
	-- the round board moves the template row: put it back in slot 1, and the rewards card back
	if tpl:GetAttribute("BaseY") then
		tpl.Position = UDim2.new(tpl.Position.X, UDim.new(0, tpl:GetAttribute("BaseY") :: number))
	end
	showTw(find(lb, "You"), true)
	-- rows come from the pool the round board uses (row 1 is the template)
	local pool = rowPool(tpl, math.min(7, #board.rows))
	local thiefId = results and results.topThief and results.topThief.userId or nil
	local myRank = nil
	for i, r in ipairs(board.rows) do
		if r.userId == player.UserId then
			myRank = i
		end
	end
	local gap = 76
	for i = 1, math.min(7, #board.rows) do
		local row = pool[i]
		if i > 1 then
			row.Position = tpl.Position + UDim2.fromOffset(0, (i - 1) * gap)
		end
		fillRow(row, i, board.rows[i], thiefId)
		row.Visible = i ~= myRank -- your own row is the gold YouRow, moved into this slot below
	end
	if you and myRank then
		you.Visible = true
		if myRank <= 7 then
			you:SetAttribute("PinnedY", you:GetAttribute("PinnedY") or you.Position.Y.Offset)
			you.Position = UDim2.new(you.Position.X, UDim.new(0, tpl.Position.Y.Offset + (myRank - 1) * gap))
		elseif you:GetAttribute("PinnedY") then
			you.Position = UDim2.new(you.Position.X, UDim.new(0, you:GetAttribute("PinnedY") :: number))
		end
		local ring = you.Parent and you.Parent:FindFirstChild("YouRing", true) :: GuiObject?
		if ring then
			ring.Visible = true
			ring.Position = UDim2.new(ring.Position.X, UDim.new(0, you.Position.Y.Offset - 4))
		end
		fillRow(you, myRank, board.rows[myRank], thiefId)
	elseif you then
		you.Visible = false
		local ring = you.Parent and you.Parent:FindFirstChild("YouRing", true) :: GuiObject?
		if ring then
			ring.Visible = false
		end
	end
	local escaped = if board.escaped == 0 then "nobody escaped" else ("%d of %d escaped"):format(board.escaped, board.total)
	-- HOS-PTS-001: an early Runners win (3 clean crossings in a row) says so, in Runner blue, on the same line
	local early = board.endReason == "CLEAN_STREAK"
	local n = board.crossings or 0
	local crossings = ("%d crossing%s"):format(n, if n == 1 then "" else "s") -- HOS-PTS-001: "1 crossing"
	setText(lb, "SubText", (if early then "RUNNERS WON EARLY!  ·  %s  ·  %s" else "%s  ·  %s"):format(crossings, escaped))
	subTint(lb, if early then Color3.fromRGB(106, 216, 255) else nil)
	-- your rewards (Results remote: you = { xp, gold, goldParts, gems, material, securedTier })
	local mine = myRank and board.rows[myRank]
	local y = results and results.you
	setText(lb, "PointsTotal", ("%d PTS"):format(mine and mine.points or 0))
	if y then
		UI.countTo("ptsXp", tonumber(y.xp) or 0, lb, "XpText", function(n) return ("+%d XP"):format(n) end)
		local parts = y.goldParts or {}
		for i = 1, 2 do
			local line = find(lb, "Line" .. i) :: GuiObject?
			if line then
				line.Visible = parts[i] ~= nil
				if parts[i] then
					setText(line, "LineLabel", tostring(parts[i].label))
					setText(line, "LineAmount", ("+%d GOLD"):format(tonumber(parts[i].amount) or 0))
				end
			end
		end
		UI.countTo("ptsGold", tonumber(y.gold) or 0, lb, "GoldTotal", function(n) return ("+%d GOLD"):format(n) end)
		local gems = find(lb, "GemsSlot")
		if gems then
			(gems :: GuiObject).Visible = (tonumber(y.gems) or 0) > 0
			setText(gems, "CountText", "x" .. tostring(y.gems or 0))
		end
		local r = rarityOf(y.securedTier)
		local R = RARITY[r]
		local eggSlot = find(lb, "EggSlot")
		if eggSlot then
			setIcon(eggSlot, "Icon", R[2])
		end
		setText(lb, "EggText", R[1] .. " EGG")
		setFill(lb, "EggText", R[4])
		setText(lb, "EggHow", if myEgg.from and myEgg.at then ("%s to %s on crossing %d"):format(myEgg.from:sub(1, 1):upper() .. myEgg.from:sub(2), r:sub(1, 1):upper() .. r:sub(2), myEgg.at) else "Kept it all match")
		local piece = y.material or PointsConfig.pieceFor(r)
		setText(lb, "PieceText", ("+1 %s piece"):format(piece:sub(1, 1):upper() .. piece:sub(2)))
		setIcon(lb, "PieceIcon", (RARITY[piece] or RARITY.common)[3])
		setFill(lb, "PieceText", (RARITY[piece] or R)[4])
	end
end

-- ===== between crossings: the same board, rows tweening from the last order to the new one (Hunter 17 Oct) =====
local roundToken = 0
local function reduceEffects(): boolean
	local ok, CameraFX = pcall(function()
		return require(script.Parent:WaitForChild("CameraFX", 2))
	end)
	return ok and CameraFX and CameraFX.reduceEffects == true
end

-- Between crossings the panel is just the leaderboard column, fitted to the rows it shows: the crossing label sits
-- in the header strip beside the banner, the list starts under the banner, even 29 px margins, no X (it closes
-- itself). Runtime layout of the imported screen (logged in the HOS-PTS-001 Hook Map); the panel and glow art
-- 9-slice while compact so corners and borders keep their size. setCompact(lb, false) puts every value back.
local SLICE = { Panel = { 24, 1556 / 1024, 576 }, Glow = { 30, 1552 / 1024, 573 } } -- tex margin, design px per tex px, tex height
local function keep(g: Instance?): GuiObject?
	if g and g:IsA("GuiObject") then
		if g:GetAttribute("WideSize") == nil then
			g:SetAttribute("WideSize", g.Size)
			g:SetAttribute("WidePos", g.Position)
		end
		return g
	end
	return nil
end
local function restore(g: Instance?)
	if g and g:IsA("GuiObject") and g:GetAttribute("WideSize") ~= nil then
		g.Size = g:GetAttribute("WideSize") :: UDim2
		g.Position = g:GetAttribute("WidePos") :: UDim2
	end
end
local function setCompact(lb: Instance, on: boolean, slots: number?, top: number?)
	local panel = lb:FindFirstChild("Panel")
	local glow = lb:FindFirstChild("Glow")
	local lists = {}
	for _, c in ipairs(panel and panel:GetChildren() or {}) do
		local wide = c:GetAttribute("WidePos") :: UDim2?
		if c.Name == "List" or (c.Name == "ShadowRing" and c:IsA("GuiObject") and ((wide and wide.X.Offset) or c.Position.X.Offset) < 100) then
			table.insert(lists, c) -- the list well and its shadow twin
		end
	end
	local subs = { panel and panel:FindFirstChild("SubText"), panel and panel:FindFirstChild("SubTextShadow") }
	local all = { lb, panel, glow, glow and glow:FindFirstChild("Art"), panel and panel:FindFirstChild("Art"), subs[1], subs[2] }
	for _, l in ipairs(lists) do
		table.insert(all, l)
	end
	for _, g in ipairs(all) do
		keep(g)
	end
	local x = lb:FindFirstChild("CloseButton") :: GuiObject?
	if x then
		x.Visible = not on
	end
	if not on then
		for _, g in ipairs(all) do
			restore(g)
		end
		for _, t in ipairs(subs) do
			if t and t:IsA("TextLabel") then
				t.TextXAlignment = Enum.TextXAlignment.Left
			end
		end
		for name in pairs(SLICE) do
			local art = lb:FindFirstChild(name) and lb[name]:FindFirstChild("Art") :: ImageLabel?
			if art then
				art.ScaleType = Enum.ScaleType.Stretch
			end
		end
		return
	end
	-- design px, from the exported panel: Leaderboard = Panel + 42 wide, 50 above it and 16 below; Glow 16 / 12 / 16 out
	local n = slots or 7
	local rowTop = top or 16
	local listW, margin = 1000, 29
	local listY = 98 -- the banner ends 82 px into the panel
	local listH = rowTop + n * 76 - 6 + rowTop + (if n > 7 then 8 else 0)
	local pw, ph = listW + 2 * margin, listY + listH + margin
	local function set(g: Instance?, x0: number?, y0: number?, w: number?, h: number?)
		if g and g:IsA("GuiObject") then
			local bs, bp = g:GetAttribute("WideSize") :: UDim2, g:GetAttribute("WidePos") :: UDim2
			g.Size = UDim2.new(bs.X.Scale, w or bs.X.Offset, bs.Y.Scale, h or bs.Y.Offset)
			g.Position = UDim2.new(bp.X.Scale, x0 or bp.X.Offset, bp.Y.Scale, y0 or bp.Y.Offset)
		end
	end
	set(lb, nil, nil, pw + 42, 50 + ph + 16)
	set(panel, nil, nil, pw, ph)
	set(panel and panel:FindFirstChild("Art"), nil, nil, pw + 36, ph + 36)
	set(glow, nil, nil, pw + 32, ph + 28)
	set(glow and glow:FindFirstChild("Art"), nil, nil, pw + 32, ph + 28)
	for _, l in ipairs(lists) do
		set(l, margin, listY, listW, listH)
	end
	-- the crossing label, right-aligned in the header strip beside the banner
	for i, t in ipairs(subs) do
		if t and t:IsA("TextLabel") then
			set(t, 742, 26 + (i - 1) * 2, pw - 742 - margin, nil)
			t.TextXAlignment = Enum.TextXAlignment.Right
		end
	end
	for name, sl in pairs(SLICE) do
		local art = lb:FindFirstChild(name) and lb[name]:FindFirstChild("Art") :: ImageLabel?
		if art then
			local m = sl[1]
			art.ScaleType = Enum.ScaleType.Slice
			art.SliceCenter = Rect.new(m, m, 1024 - m, sl[3] - m)
			art.SliceScale = sl[2]
		end
	end
end

local roundFader: Fader? = nil
local roundConn: RBXScriptConnection? = nil
local function roundRestore() -- the results screen gets the panel back exactly as built
	roundToken += 1
	if roundConn then
		roundConn:Disconnect()
		roundConn = nil
	end
	if roundFader then
		setAlpha(roundFader, 1)
		roundFader = nil
	end
	local lb = screen and screen:FindFirstChild("Leaderboard")
	local ps = lb and lb:FindFirstChild("PopScale") :: UIScale?
	if ps then
		ps.Scale = 1
	end
	local dim = screen and screen:FindFirstChild("Dim")
	local f = dim and dim:FindFirstChild("F") :: Frame?
	if f and f:GetAttribute("BaseBT") then
		f.BackgroundTransparency = f:GetAttribute("BaseBT") :: number
	end
	if lb then
		setCompact(lb, false)
		for _, d in ipairs(lb:GetDescendants()) do
			if (d.Name == "RowClone" or d.Name == "Row") and d:IsA("GuiObject") and d:GetAttribute("BaseZ") then
				d.ZIndex = d:GetAttribute("BaseZ") :: number
			end
		end
	end
end

local function onRound(t: any)
	if type(t) ~= "table" or type(t.rows) ~= "table" or not screen then
		return
	end
	if UI.current() == screen.Name then
		return -- the results screen is up
	end
	local arrived = os.clock()
	local RC = PointsConfig.Round
	local lb = screen:FindFirstChild("Leaderboard") :: GuiObject?
	local tpl = find(lb, "Row") :: GuiObject?
	if not lb or not tpl then
		return
	end
	roundRestore()
	local token = roundToken
	if not tpl:GetAttribute("BaseY") then
		tpl:SetAttribute("BaseY", tpl.Position.Y.Offset)
	end
	local gap, top = 76, tpl:GetAttribute("BaseY") :: number
	local function slotY(rank: number): number
		return top + (math.min(rank, 8) - 1) * gap + (if rank > 7 then 8 else 0) -- 8th slot = your own row under the top 7
	end
	-- 1. build everything while hidden: the board without the rewards card, rows from the pool
	screen.Visible = false
	showTw(find(lb, "You"), false)
	local you = find(lb, "YouRow") :: GuiObject?
	if you then
		you.Visible = false
	end
	setText(lb, "SubText", ("Crossing %d of %d"):format(t.crossing or 0, t.of or 0))
	subTint(lb, nil)
	local ring = tpl.Parent and tpl.Parent:FindFirstChild("YouRing", true) :: GuiObject?
	if ring then
		ring.Visible = false
	end
	local list = {}
	for _, r in ipairs(t.rows) do
		if r.prevRank <= 7 or r.rank <= 7 or r.userId == player.UserId then
			table.insert(list, r)
		end
	end
	local rows = rowPool(tpl, #list)
	local shown: { { row: GuiObject, r: any } } = {}
	for i, r in ipairs(list) do
		local row = rows[i]
		local mine = r.userId == player.UserId
		if not row:GetAttribute("BaseZ") then
			row:SetAttribute("BaseZ", row.ZIndex)
		end
		-- a Runner who made a Hero run this match wears HERO (gold), like the results screen
		local tag = if r.hero and r.role == "RUNNER" then "HERO" else r.role
		fillRow(row, r.prevRank, { userId = r.userId, name = r.name, npcSlot = r.npcSlot, outcome = tag, stats = {}, points = r.total }, nil)
		-- the pill is this crossing's gain (counts up); the total sits on the row's second line
		setText(row, "StatsText", ("%s  ·  %d PTS total"):format(if r.role == "CATCHER" then "Catcher" else "Runner", r.total))
		rowPill(row, "+0 PTS")
		row.Position = UDim2.new(tpl.Position.X, UDim.new(0, slotY(r.prevRank)))
		row.Visible = r.prevRank <= 7 or mine
		table.insert(shown, { row = row, r = r })
	end
	-- fit the panel to the slots it shows: the top 7 (fewer in a small match) + your row under them if you're lower
	local slots = math.min(7, #t.rows)
	for _, r in ipairs(list) do
		if r.userId == player.UserId and (r.rank > 7 or r.prevRank > 7) then
			slots = 8
		end
	end
	setCompact(lb, true, slots, top)
	showGroup("PodiumBanner", false)
	showGroup("ResultsV2", false) -- HOS-PTS-001: the end screen never shows between crossings
	showGroup("ResultsSkinRed", false)
	showGroup("Leaderboard", true)
	local dim = screen:FindFirstChild("Dim") :: GuiObject?
	local dimF = dim and dim:FindFirstChild("F") :: Frame?
	if dimF and not dimF:GetAttribute("BaseBT") then
		dimF:SetAttribute("BaseBT", dimF.BackgroundTransparency)
	end
	showGroup("Dim", dimF ~= nil)
	local ps = lb:FindFirstChild("PopScale") :: UIScale?
	if not ps then
		local u = Instance.new("UIScale") -- the same scale UI.open pops the panel with
		u.Name = "PopScale"
		u.Parent = lb
		ps = u
	end
	local fader = makeFader(lb)
	roundFader = fader
	setAlpha(fader, 0)
	if dimF then
		dimF.BackgroundTransparency = 1
	end
	local reduce = reduceEffects()
	-- 2. the timeline (seconds from arrival; the crossing ended Round.SEND before that)
	local openAt = math.clamp(math.max(lastPopAt + RC.AFTER_POP, bannerUntil + RC.AFTER_BANNER) - arrived, 0, RC.OPEN_LATEST)
	local countAt = openAt + RC.OPEN
	local slideAt = countAt + RC.SLIDE_AFTER
	local closeAt = RC.CLOSE_AT
	local function ease(style: Enum.EasingStyle, dir: Enum.EasingDirection, x: number): number
		return TweenService:GetValue(math.clamp(x, 0, 1), style, dir)
	end
	local slid, closed, counted = false, false, false
	screen.Visible = true
	_G.PTS_ROUND_T = { arrived = arrived, openAt = openAt, slideAt = slideAt, closeAt = closeAt } -- for the timing check
	roundConn = RunService.RenderStepped:Connect(function()
		if roundToken ~= token then
			return
		end
		local e = os.clock() - arrived
		if e >= openAt and lastPopAt > arrived - 2 then
			for _, p in ipairs(stack) do -- pops still up hand over to the board
				if p.Parent and p:GetAttribute("PtsGone") == nil then
					p:SetAttribute("PtsGone", true)
					fade(p, 1, IN)
				end
			end
		end
		-- open / close: one alpha and one scale for the whole panel
		local a, sc
		if e < closeAt then
			local x = if reduce then (if e >= openAt then 1 else 0) else ease(Enum.EasingStyle.Quad, Enum.EasingDirection.Out, (e - openAt) / RC.OPEN)
			a, sc = x, 0.94 + 0.06 * x
		else
			local x = if reduce then 1 else ease(Enum.EasingStyle.Quad, Enum.EasingDirection.In, (e - closeAt) / RC.CLOSE)
			a, sc = 1 - x, 1 - 0.03 * x
		end
		if a ~= fader.alpha then
			setAlpha(fader, a)
		end
		(ps :: UIScale).Scale = sc
		if dimF then
			dimF.BackgroundTransparency = 1 - (1 - RC.DIM) * a
		end
		-- the pills count up
		if e >= countAt and not counted then
			local c = math.clamp((e - countAt) / RC.COUNT, 0, 1)
			for _, s in ipairs(shown) do
				rowPill(s.row, ("+%d PTS"):format(math.floor(s.r.gained * ease(Enum.EasingStyle.Quad, Enum.EasingDirection.Out, c) + 0.5)))
			end
			counted = c >= 1
		end
		-- the rows slide to their new ranks
		if e >= slideAt and not slid then
			local x = if reduce then 1 else ease(Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut, (e - slideAt) / RC.SLIDE)
			for _, s in ipairs(shown) do
				local y0, y1 = slotY(s.r.prevRank), slotY(s.r.rank)
				-- rows leaving / entering the top 7 show only on the top-7 half of their slide (never across your row)
				local y = y0 + (y1 - y0) * x
				s.row.Visible = s.r.userId == player.UserId
					or ((s.r.prevRank <= 7 or x >= 0.5) and (s.r.rank <= 7 or x < 0.5) and y <= slotY(slots)) -- never below the fitted list
				-- layers while moving: climbers on top, rows going down next, rows that stay put underneath
				-- (a row that isn't moving never covers one that is)
				s.row.ZIndex = (s.row:GetAttribute("BaseZ") :: number) + (if s.r.rank < s.r.prevRank then 3 elseif s.r.rank > s.r.prevRank then 2 else 0)
				s.row.Position = UDim2.new(tpl.Position.X, UDim.new(0, y))
			end
			if x >= 1 then
				slid = true
				for _, s in ipairs(shown) do
					local mine = s.r.userId == player.UserId
					s.row.Visible = s.r.rank <= 7 or mine
					setText(s.row, "RankText", tostring(s.r.rank))
					if mine and ring then
						ring.Visible = true
						ring.Position = UDim2.new(ring.Position.X, UDim.new(0, s.row.Position.Y.Offset - 4))
					end
				end
			end
		end
		if e >= closeAt + RC.CLOSE and not closed then
			closed = true
			if screen and UI.current() ~= screen.Name then
				screen.Visible = false
			end
			showTw(find(lb, "You"), true)
			roundRestore()
		end
	end)
end

local Cinematic: any = nil
local function cinematic(): any
	if not Cinematic then
		local ok, m = pcall(function()
			return require(script.Parent:WaitForChild("Cinematic", 2))
		end)
		Cinematic = if ok then m else false
	end
	return Cinematic or nil
end

local VFXEmit: any = nil
local function confetti(pos: Vector3)
	local folder = ReplicatedStorage:FindFirstChild("VFX")
	local set = folder and folder:FindFirstChild("HeroChicken")
	local tpl = set and set:FindFirstChild("HC_SuccessBurst") -- the Hero or Chicken confetti (shared VFX)
	if not tpl then
		return
	end
	if not VFXEmit then
		local ok, m = pcall(function()
			return require(folder:WaitForChild("Emit"))
		end)
		VFXEmit = if ok then m else false
	end
	if VFXEmit then
		pcall(VFXEmit.play, tpl, CFrame.new(pos))
	end
end

-- the winners' emotes (server sets EOS_Emote on each copy; empty = they left, a still pose)
local function playWinners(model: Model)
	for _, w in ipairs(model:GetChildren()) do
		if w:IsA("Model") and w.Name == "Winner" then
			local id = w:GetAttribute("EOS_Emote") :: string?
			local e = id and EmoteConfig.get(id)
			local hum = w:FindFirstChildOfClass("Humanoid")
			local animator = hum and (hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum))
			if e and animator and e.animId ~= "" then
				local a = Instance.new("Animation")
				a.AnimationId = "rbxassetid://" .. e.animId
				local ok, track = pcall(function()
					return (animator :: Animator):LoadAnimation(a)
				end)
				if ok and track then
					track.Looped = true
					track:Play(0.2)
				end
			end
			-- the emote's prop effect, if it has one
			pcall(function()
				local EmoteFX = require(script.Parent:WaitForChild("EmoteFX", 2))
				w:SetAttribute("EOS_Emote", id)
				EmoteFX.update(w)
			end)
		end
	end
end

local function podiumCards(model: Model)
	for place = 1, 3 do
		local row = board and board.rows[place]
		local step = model:FindFirstChild("Step" .. place)
		local spot = step and step:FindFirstChild("Spot") :: BasePart?
		local card = row and spot and K.template("PodiumCard") :: GuiObject?
		if card and spot and row then
			local bb = Instance.new("BillboardGui")
			bb.Name = "PtsPodiumCard"
			bb.Adornee = spot
			bb.Size = UDim2.fromOffset(460, 230)
			bb.StudsOffsetWorldSpace = Vector3.new(0, 8.4, 0)
			bb.LightInfluence = 0
			bb.ResetOnSpawn = false
			setText(card, "NameText", nameOf(row))
			setText(card, "PointsText", ("%d Points"):format(row.points))
			card.Parent = bb
			K.scaled(card)
			bb.Parent = spot -- in the world: Cinematic hides player GUIs during the cut-scene
			task.delay(GameConfig.Timing.RESULTS, function()
				bb:Destroy()
			end)
		end
	end
end

local function bigCard(place: number): GuiObject?
	local row = board and board.rows[place]
	local c = row and K.template("PodiumCardBig") :: GuiObject?
	if not c or not row then
		return nil
	end
	local p = ({ "1st", "2nd", "3rd" })[place]
	setText(c, "PlaceText", p)
	setFill(c, "PlaceText", ({ Color3.fromRGB(255, 210, 58), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 160, 64) })[place])
	setText(c, "NameText", nameOf(row))
	setText(c, "PointsText", ("%d Points"):format(row.points))
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Position = UDim2.fromScale(0.5, 0.42)
	K.scaled(c)
	c.Parent = gui -- PointsUI is in the cut-scene's keepGuis (the overlay gets hidden)
	return c
end

-- ===== results v2 (Hunter 17 Oct: "looks phenomenal. build it"): the end-of-match screen in the reference layout =====
-- ResultsV2 (exported from UI/build.py rv_*): winner title, subtitle, "Next match" countdown, tabs POINTS / SURVIVED /
-- CATCHES (auto-cycle every 4 s with a bar, tap to pick and stop the cycle), the top 3 with headshots, the YOU strip,
-- rewards (XP / GOLD / GEMS + level bar), the egg block (EggUIController fills it after us) and NEXT. Runtime layout
-- changes to the imported screen are logged in the HOS-PTS-001 Hook Map.
local RV2 = {
	tab = "Points",
	token = 0,
	auto = true,
	tabs = {} :: { string },
	lists = {} :: { [string]: { any } },
	view = nil :: any, -- latest ProfileState (xp)
	CYCLE = 4,
	ORDER = { "Points", "Survived", "Catches" },
	KEY = { Points = "points", Survived = "safe", Catches = "catches" },
	STAT = { Points = "StatPts", Survived = "StatSafe", Catches = "StatCatch" },
	ROLE = { HERO = "HERO", ESCAPED = "RUNNER", CATCHER = "CATCHER", CAUGHT = "CAUGHT" },
	phone = false,
	you = nil :: any, -- this match's Results payload (XP and GOLD count up from it)
}

function RV2.group(): Frame?
	return screen and screen:FindFirstChild("ResultsV2") :: Frame?
end

function RV2.both(scope: Instance?, name: string, fn: (GuiObject) -> ())
	if not scope then
		return
	end
	for _, d in ipairs(scope:GetDescendants()) do
		if d:IsA("GuiObject") and (d.Name == name or d.Name == name .. "Shadow") then
			fn(d)
		end
	end
end

-- the headshot: a real player's Roblox headshot, or the NPC's own look (BotHeadshot, HOS-BOT-001)
function RV2.head(slot: Instance?, r: any)
	if not slot or not slot:IsA("GuiObject") then
		return
	end
	local img = slot:FindFirstChild("Shot") :: ImageLabel?
	if not img then
		local i = Instance.new("ImageLabel")
		i.Name = "Shot"
		i.BackgroundTransparency = 1
		i.Size = UDim2.fromScale(1, 1)
		i.ZIndex = slot.ZIndex + 1
		local c = slot:FindFirstChildOfClass("UICorner")
		if c then
			c:Clone().Parent = i
		end
		i.Parent = slot
		img = i
	end
	local bot = r.npcSlot ~= nil or (tonumber(r.userId) or 0) <= 0
	;(img :: ImageLabel).Image = if bot then "" else ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(r.userId)
	pcall(function()
		require(script.Parent:WaitForChild("BotHeadshot", 2)).fill(slot, if bot then r.npcSlot else nil)
	end)
end

-- standings for one tab: competition ranking (equal values share a place; "JOINT #n" when they do)
function RV2.ranked(key: string): { any }
	local list = {}
	for _, r in ipairs(board and board.rows or {}) do
		local v = tonumber(r[key]) or 0
		if key == "points" or v > 0 then
			table.insert(list, { r = r, v = v })
		end
	end
	table.sort(list, function(a, b)
		if a.v ~= b.v then
			return a.v > b.v
		end
		return (tonumber(a.r.userId) or 0) < (tonumber(b.r.userId) or 0)
	end)
	for i, e in ipairs(list) do
		e.place = if i > 1 and e.v == list[i - 1].v then list[i - 1].place else i
	end
	local count = {}
	for _, e in ipairs(list) do
		count[e.place] = (count[e.place] or 0) + 1
	end
	for _, e in ipairs(list) do
		e.joint = count[e.place] > 1
	end
	return list
end

-- a role tag: word, tint, sized to the word, centred on x (design px in its parent)
function RV2.tag(tag: Instance?, word: string, cx: number?)
	if not tag then
		return
	end
	RV2.unbig(tag) -- back to the exported tag before sizing it for this screen
	setText(tag, "RoleText", word)
	setText(tag, "YouRoleText", word)
	tintTag(tag, word)
	if tag:IsA("GuiObject") then -- a little slack: at phone sizes the word's pixels round wider than its bounds
		for _, t in ipairs(twinsOf(tag)) do
			t.Size += UDim2.fromOffset(8, 0)
		end
		tag.Size += UDim2.fromOffset(8, 0)
		for _, l in ipairs(tag:GetChildren()) do
			if l:IsA("TextLabel") then
				l.Size += UDim2.fromOffset(8, 0)
			end
		end
	end
	RV2.bigTag(tag)
	if cx and tag:IsA("GuiObject") then
		shiftTw(tag, math.floor(cx - tag.Size.X.Offset / 2))
	end
end

-- phones (Hunter: small text bigger): a tag's word at PHONE_TEXT x its design size, the box regrown round it (centre kept)
RV2.PHONE_TEXT = 1.35
-- the phone enlargement is undone when the same screen later opens at a PC size (a resized window): every property
-- it changes is snapshotted first (RV0<prop>) and put back by RV2.unbig / RV2.unbigLabels
RV2.TAGPROPS = { "Size", "Position", "TextSize", "TextScaled", "TextWrapped", "TextXAlignment" }
function RV2.snap(o: Instance)
	for _, p in ipairs(RV2.TAGPROPS) do
		local ok, v = pcall(function()
			return (o :: any)[p]
		end)
		if ok and o:GetAttribute("RV0" .. p) == nil then
			o:SetAttribute("RV0" .. p, if typeof(v) == "EnumItem" then v.Name else v)
		end
	end
end
function RV2.unsnap(o: Instance)
	for _, p in ipairs(RV2.TAGPROPS) do
		local v = o:GetAttribute("RV0" .. p)
		if v ~= nil then
			pcall(function()
				(o :: any)[p] = if p == "TextXAlignment" then (Enum.TextXAlignment :: any)[v] else v
			end)
			o:SetAttribute("RV0" .. p, nil)
		end
	end
end
function RV2.unbig(tag: Instance?)
	if not (tag and tag:IsA("GuiObject")) then
		return
	end
	for _, t in ipairs(twinsOf(tag)) do
		RV2.unsnap(t)
	end
	RV2.unsnap(tag)
	for _, l in ipairs(tag:GetChildren()) do
		RV2.unsnap(l)
	end
end

function RV2.bigTag(tag: Instance?)
	if not (RV2.phone and tag and tag:IsA("GuiObject")) or tag.AbsoluteSize.X <= 0 then
		return
	end
	for _, t in ipairs(twinsOf(tag)) do
		RV2.snap(t)
	end
	RV2.snap(tag)
	for _, l in ipairs(tag:GetChildren()) do
		if l:IsA("TextLabel") then
			RV2.snap(l)
		end
	end
	local main: TextLabel? = nil
	local labels = {}
	for _, l in ipairs(tag:GetChildren()) do
		if l:IsA("TextLabel") then
			local design = (l:GetAttribute("UIDesignSize") :: number?) or l.TextSize
			l.TextScaled = false
			l.TextWrapped = false
			l.TextSize = math.floor(design * RV2.PHONE_TEXT + 0.5)
			table.insert(labels, l)
			if not string.find(l.Name, "Shadow$") then
				main = l
			end
		end
	end
	if not main then
		return
	end
	local sc = tag.AbsoluteSize.X / math.max(1, tag.Size.X.Offset)
	local w = math.ceil(main.TextBounds.X / sc) + 28
	local th = math.ceil(main.TextBounds.Y / sc)
	local h = th + 12
	local dw, dh = w - tag.Size.X.Offset, h - tag.Size.Y.Offset
	for _, t in ipairs(twinsOf(tag)) do
		t.Size += UDim2.fromOffset(dw, dh)
		t.Position -= UDim2.fromOffset(0, math.floor(dh / 2))
	end
	tag.Size += UDim2.fromOffset(dw, dh)
	tag.Position -= UDim2.fromOffset(0, math.floor(dh / 2))
	local mainY = main.Position.Y.Offset
	for _, l in ipairs(labels) do
		local off = l.Position.Y.Offset - mainY -- the shadow's drop
		l.Size = UDim2.new(0, w - 28, 0, th)
		l.Position = UDim2.new(0, 14, 0, math.floor((h - th) / 2) + off)
		l.TextXAlignment = Enum.TextXAlignment.Center
	end
end

RV2.caps = {} :: { [Instance]: Instance }
function RV2.unbigLabels(g: Instance)
	for _, d in ipairs(g:GetDescendants()) do
		if d:IsA("TextLabel") and d:GetAttribute("PhoneBig") then
			RV2.unsnap(d)
			local cap = RV2.caps[d]
			if cap then
				cap.Parent = d
				RV2.caps[d] = nil
			end
			d:SetAttribute("PhoneBig", nil)
		end
	end
end

-- phones: plain labels nobody re-sets (column headers, JOINT) at PHONE_TEXT x design, centred where they were
function RV2.bigLabels(g: Instance)
	if not RV2.phone then
		return
	end
	for _, d in ipairs(g:GetDescendants()) do
		if d:IsA("TextLabel") and not d:GetAttribute("PhoneBig") then
			local base = string.gsub(d.Name, "Shadow$", "")
			if base == "T_Xp" or base == "T_Gold" or base == "T_Gems" or base == "T_YourRewards" or base == "T_Egg" or base == "JointText" then
				local design = (d:GetAttribute("UIDesignSize") :: number?) or d.TextSize
				RV2.snap(d)
				local cap = d:FindFirstChild("UIFitCap")
				if cap then
					RV2.caps[d] = cap
					cap.Parent = nil
				end
				d.TextScaled = false
				d.TextWrapped = false
				d.TextSize = math.floor(design * RV2.PHONE_TEXT + 0.5)
				d:SetAttribute("PhoneBig", true)
			end
		end
	end
end

function RV2.card(card: GuiObject, e: any?, tab: string)
	showTw(card, e ~= nil)
	if card.Name == "Place1" then
		RV2.both(card.Parent, "Crown", function(c)
			c.Visible = e ~= nil
		end)
	end
	if not e then
		RV2.clearView(card)
		return
	end
	local r = e.r
	setText(card, "NameText", nameOf(r))
	setText(card, "RankText", "#" .. e.place)
	RV2.both(card, "JointText", function(l)
		l.Visible = e.joint
	end)
	RV2.both(card, "RankText", function(l)
		local base = l:GetAttribute("BaseY") :: number?
		if base == nil then
			base = l.Position.Y.Offset
			l:SetAttribute("BaseY", base)
		end
		l.Position = UDim2.new(l.Position.X, UDim.new(l.Position.Y.Scale, (base :: number) + (if e.joint then 20 else 0)))
	end)
	RV2.tag(find(card, "Role"), RV2.ROLE[r.outcome] or "RUNNER", card.Size.X.Offset / 2)
	for t, nm in pairs(RV2.STAT) do
		local g = card:FindFirstChild(nm, true) :: GuiObject?
		if g then
			g.Visible = t == tab
		end
	end
	local v = e.v
	if tab == "Points" then
		setText(card, "StatText", ("+%s PTS"):format(K.format and K.format(v) or tostring(v)))
	elseif tab == "Survived" then
		setText(card, "SafeText", ("%d crossing%s"):format(v, if v == 1 then "" else "s"))
	else
		setText(card, "CatchText", ("%d catch%s"):format(v, if v == 1 then "" else "es"))
	end
	RV2.head(find(card, "Head"), r)
	RV2.stage(card, e, tonumber(string.match(card.Name, "%d+")) or 1) -- the emote podium (the headshot is its fallback)
end

-- the YOU strip follows the tab on show, so it always agrees with the cards: your place on that tab (JOINT #N when
-- tied, the cards' rule) and that tab's stat. POINTS keeps the teal "+N PTS" pill (teal is only ever points); on
-- SURVIVED / CATCHES the stat sits after the place in white ("#1 · 2 crossings", "0 catches" when you have none)
function RV2.youStrip(tab: string)
	local g = RV2.group()
	local you = g and find(g, "You") :: GuiObject?
	if not you or not you.Visible then
		return
	end
	local me: any = nil
	for _, e in ipairs(RV2.lists[tab] or {}) do
		if e.r.userId == player.UserId then
			me = e
		end
	end
	local mine: any = nil
	for _, e in ipairs(RV2.lists.Points or {}) do
		if e.r.userId == player.UserId then
			mine = e
		end
	end
	local function place(e: any): string
		return (if e.joint then "JOINT #" else "#") .. e.place
	end
	local function stat(v: number): string
		if tab == "Survived" then
			return ("%d crossing%s"):format(v, if v == 1 then "" else "s")
		end
		return ("%d catch%s"):format(v, if v == 1 then "" else "es")
	end
	local rank = find(you, "YouRank") :: TextLabel?
	if rank and not rank:GetAttribute("RVwide") then -- room for "JOINT #2 · 2 crossings" (the pill sits further right)
		rank:SetAttribute("RVwide", true)
		RV2.both(you, "YouRank", function(l)
			l.Size = UDim2.new(0, 560, l.Size.Y.Scale, l.Size.Y.Offset)
			;(l :: TextLabel).TextXAlignment = Enum.TextXAlignment.Left
		end)
	end
	local pill = find(you, "PtsPill")
	if tab == "Points" then
		setText(you, "YouRank", if me then place(me) else "")
		setText(you, "YouPts", ("+%s PTS"):format(K.format and K.format(mine and mine.v or 0) or tostring(mine and mine.v or 0)))
		showTw(pill, true)
	else
		setText(you, "YouRank", if me then place(me) .. "  ·  " .. stat(me.v) else stat(0))
		showTw(pill, false)
	end
	local tag = find(you, "YouRole")
	if mine then
		RV2.tag(tag, RV2.ROLE[mine.r.outcome] or "RUNNER", nil)
	end
	if rank and tag and rank.AbsoluteSize.X > 0 then
		local sc = rank.AbsoluteSize.X / math.max(1, rank.Size.X.Offset)
		shiftTw(tag, math.floor(rank.Position.X.Offset + rank.TextBounds.X / sc + 14))
	end
end

function RV2.showTab(tab: string)
	local g = RV2.group()
	if not g then
		return
	end
	RV2.tab = tab
	pcall(RV2.youStrip, tab)
	for _, name in ipairs(RV2.ORDER) do
		local t = find(g, "Tab" .. name)
		if t then
			local on, off = t:FindFirstChild("On") :: GuiObject?, t:FindFirstChild("Off") :: GuiObject?
			if on then
				showTw(on, name == tab)
				RV2.alphas[on] = nil
			end
			if off then
				showTw(off, name ~= tab)
				RV2.alphas[off] = nil
			end
		end
	end
	local list = RV2.lists[tab] or {}
	for i = 1, 3 do
		local card = find(g, "Place" .. i) :: GuiObject?
		if card then
			RV2.card(card, list[i], tab)
		end
	end
end

-- tabs: hide a tab nobody scored in (no catches -> no CATCHES), centre the rest and the cycle bar under them.
-- The export makes each tab a button (TabPoints...) centred on its spot, its On / Off states inside it.
function RV2.layoutTabs(g: Frame)
	local base: { [string]: number } = {}
	local frames: { [string]: GuiObject } = {}
	local W = 0
	for _, name in ipairs(RV2.ORDER) do
		local t = find(g, "Tab" .. name) :: GuiObject?
		if t then
			if t:GetAttribute("BaseX") == nil then
				t:SetAttribute("BaseX", t.Position.X.Offset)
			end
			base[name] = t:GetAttribute("BaseX") :: number
			frames[name] = t
			W = t.Size.X.Offset
		end
	end
	if not (base.Points and base.Survived) then
		return
	end
	local step = base.Survived - base.Points
	local n = #RV2.tabs
	local first = base.Survived - (n - 1) * step / 2 -- the three are centred on the middle one
	local k = 0
	for _, name in ipairs(RV2.ORDER) do
		local t = frames[name]
		local shown = table.find(RV2.tabs, name) ~= nil
		if t then
			t.Visible = shown
			if shown then
				t.Position = UDim2.new(t.Position.X.Scale, math.floor(first + k * step), t.Position.Y.Scale, t.Position.Y.Offset)
				t:SetAttribute("RVBasePos", t.Position)
				k += 1
			end
		end
	end
	local bar = find(g, "CycleBar") :: GuiObject?
	if bar then
		if bar:GetAttribute("BaseX") == nil then
			bar:SetAttribute("BaseX", bar.Position.X.Offset)
		end
		bar.Position = UDim2.new(bar.Position.X.Scale, math.floor((bar:GetAttribute("BaseX") :: number) + first - base.Points), bar.Position.Y.Scale, bar.Position.Y.Offset)
		bar.Size = UDim2.new(0, n * W + (n - 1) * (step - W), bar.Size.Y.Scale, bar.Size.Y.Offset)
		bar:SetAttribute("RVBasePos", bar.Position)
		bar.Visible = n > 1
	end
end

-- a bar's fill: F is the exported fill frame, its raster Art a fixed-size child: stretch the art over F
function RV2.setFill(b: Instance?, frac: number)
	local f = b and b:FindFirstChild("F") :: GuiObject?
	if not f then
		return
	end
	f.Size = UDim2.new(math.clamp(frac, 0, 1), 0, f.Size.Y.Scale, f.Size.Y.Offset)
	local art = f:FindFirstChild("Art") :: GuiObject?
	if art then
		art.Position = UDim2.new()
		art.Size = UDim2.fromScale(1, 1)
	end
	f.Visible = frac > 0.001
end

function RV2.bar(frac: number)
	local g = RV2.group()
	RV2.setFill(g and find(g, "CycleBar"), frac)
end

-- the level bar from the latest ProfileState (it refreshes when the settlement's profile lands)
function RV2.level()
	local g = RV2.group()
	local v = RV2.view
	if g then -- no profile yet: "LEVEL N" (the player's EOS_Level) over an empty bar, never the export's sample numbers;
		-- the row is always there (no gap in the box), the bar and numbers fill when the profile lands
		local has = v ~= nil and v.xp ~= nil
		RV2.both(g, "XpLine", function(o)
			o.Visible = has
		end)
		if not has then
			setText(g, "LevelText", "LEVEL " .. tostring(player:GetAttribute("EOS_Level") or 1))
			RV2.setFill(find(g, "XpBar"), 0)
		end
	end
	if not g or not v or v.xp == nil then
		return
	end
	local ok, EconomyConfig = pcall(function()
		return require(Shared:WaitForChild("EconomyConfig"))
	end)
	if not ok then
		return
	end
	local level, into, need = EconomyConfig.levelFor(tonumber(v.xp) or 0)
	setText(g, "LevelText", "LEVEL " .. level)
	setText(g, "XpLine", ("%s / %s XP"):format(K.format and K.format(into) or tostring(into), K.format and K.format(need) or tostring(need)))
	RV2.setFill(find(g, "XpBar"), into / math.max(1, need))
end

-- Catchers win: the red panel (ResultsSkinRed's art) on the same frames; anything else: the blue it was built with
function RV2.skin(g: Frame, red: boolean)
	local src = screen and screen:FindFirstChild("ResultsSkinRed")
	for _, path in ipairs({ { "Glow", "Art" }, { "Panel", "Art" }, { "Banner", "Edge", "Art" }, { "Banner", "Fill", "Art" } }) do
		local a: Instance? = g
		local b: Instance? = src
		for _, p in ipairs(path) do
			a = a and a:FindFirstChild(p)
			b = b and b:FindFirstChild(p)
		end
		if a and a:IsA("ImageLabel") then
			if a:GetAttribute("BaseImage") == nil then
				a:SetAttribute("BaseImage", a.Image)
			end
			a.Image = if red and b and b:IsA("ImageLabel") then b.Image else a:GetAttribute("BaseImage") :: string
		end
	end
end

function RV2.fill(results: any)
	local g = RV2.group()
	if not g or not board then
		return
	end
	RV2.clearViews() -- a new screen: last match's podium models go
	-- phones (first, so the tags below are measured at the size they show): the panel fills the screen height
	-- (1.1 of the design; banner top to panel bottom is 966 px)
	local cam = workspace.CurrentCamera
	local old = g:FindFirstChild("PhoneScale")
	if old then
		old:Destroy()
	end
	RV2.phone = cam ~= nil and cam.ViewportSize.Y < 600
	for _, n in ipairs({ "Panel", "Banner", "Glow" }) do -- a tap on the card is not a tap on the backdrop (which closes)
		local f = g:FindFirstChild(n) :: GuiObject?
		if f then
			f.Active = true
		end
	end
	RV2.scale(g).Scale = if RV2.phone then 1.1 else 1 -- measured at the size it shows (enter animates from here)
	if RV2.phone then
		RV2.bigLabels(g)
	else
		RV2.unbigLabels(g)
	end
	-- title, subtitle, colour
	local early = board.endReason == "CLEAN_STREAK"
	-- the game's own rule (MatchLogic): RUNNERS when anyone is still running at the end, else CATCHERS
	local team = board.team or (results and results.team)
	local catchers = if team then team == "CATCHERS" else (not early and (board.escaped or 0) == 0)
	setText(g, "Title", if early then "RUNNERS WON EARLY!" elseif catchers then "CATCHERS WIN" else "RUNNERS WIN")
	RV2.skin(g, catchers)
	local n = board.crossings or 0
	local escaped = if (board.escaped or 0) == 0 then "nobody escaped" else ("%d of %d escaped"):format(board.escaped, board.total)
	setText(g, "SubText", ("%d crossing%s  ·  %s"):format(n, if n == 1 then "" else "s", escaped))
	-- tabs and their top 3
	RV2.lists, RV2.tabs = {}, {}
	for _, name in ipairs(RV2.ORDER) do
		RV2.lists[name] = RV2.ranked(RV2.KEY[name])
		if #RV2.lists[name] > 0 then
			table.insert(RV2.tabs, name)
		end
	end
	RV2.layoutTabs(g)
	RV2.auto = true
	RV2.showTab(RV2.tabs[1] or "Points")
	-- you
	local me: any = nil
	for _, e in ipairs(RV2.lists.Points or {}) do
		if e.r.userId == player.UserId then
			me = e
		end
	end
	local you = find(g, "You") :: GuiObject?
	if you then
		you.Visible = me ~= nil
	end
	if me and you then
		RV2.head(find(you, "YouHead"), me.r)
		RV2.youStrip(RV2.tab)
	end
	-- rewards: XP, GOLD, GEMS (the column only when there are some; XP and GOLD spread over the box without it)
	local y = results and results.you
	local gems = y and tonumber(y.gems) or 0
	local cols = { ColXp = 1, ColGold = 3, ColGems = 5 }
	local rw = 540 -- build.py RV_REW_W
	for name, slot in pairs(cols) do
		local c = find(g, name) :: GuiObject?
		if c then
			if c:GetAttribute("BaseX") == nil then
				c:SetAttribute("BaseX", c.Position.X.Offset)
			end
			local base = c:GetAttribute("BaseX") :: number
			local want = if gems > 0 then rw * slot / 6 else rw * (if name == "ColXp" then 1 else 3) / 4
			c.Position = UDim2.new(c.Position.X.Scale, base + want - rw * slot / 6, c.Position.Y.Scale, c.Position.Y.Offset)
			if name == "ColGems" then
				c.Visible = gems > 0
			end
		end
	end
	if y then
		RV2.you = y
		setText(g, "GemsText", ("+%d GEMS"):format(gems))
		-- the egg block: what PointsController always wrote; EggUIController lands its shard line on top at 0.3 / 1 / 2 s
		local r = rarityOf(y.securedTier)
		local R = RARITY[r]
		local eggSlot = find(g, "EggSlot")
		if eggSlot then
			setIcon(eggSlot, "Icon", R[2])
		end
		setText(g, "EggText", R[1] .. " EGG")
		setFill(g, "EggText", R[4])
		setText(g, "EggHow", "Kept it all match")
		local piece = y.material or PointsConfig.pieceFor(r)
		setText(g, "PieceText", ("+1 %s piece"):format(piece:sub(1, 1):upper() .. piece:sub(2)))
		setIcon(g, "PieceIcon", (RARITY[piece] or RARITY.common)[3])
		setFill(g, "PieceText", (RARITY[piece] or R)[4])
	end
	RV2.level()
	-- the cycle and the countdown
	RV2.token += 1
	local my = RV2.token
	task.spawn(function()
		local state = Net.state()
		local t0 = os.clock()
		while my == RV2.token and g.Parent and screen and screen.Visible do
			local rem = (tonumber(state:GetAttribute("PhaseEndsAt")) or 0) - workspace:GetServerTimeNow()
			setText(g, "NextText", ("Next match  ·  %ds"):format(math.max(0, math.ceil(rem))))
			if rem <= 0.6 and UI.current() == screen.Name and not RV2.closing then
				UI.close() -- the exit finishes before the lobby (or map vote) comes up
				break
			end
			if RV2.auto and #RV2.tabs > 1 then
				local since = os.clock() - t0
				if since >= RV2.CYCLE then
					local i = (table.find(RV2.tabs, RV2.tab) or 0) % #RV2.tabs + 1
					RV2.switchTo(RV2.tabs[i])
					t0, since = os.clock(), 0
				end
				-- reduce effects: the tabs still swap, the bar doesn't sweep; else it empties over 0.2 s, then fills
				RV2.bar(if reduceEffects() then 1 elseif since < 0.2 and RV2.switch > 0 then 1 - since / 0.2 else since / RV2.CYCLE)
			else
				RV2.bar(1)
			end
			task.wait(1 / 20)
		end
	end)
end

-- ===== results v2 motion (Hunter 18:26: "better tweens and animations for pill header switching, appearing on
-- screen, and off screen"). Gentle: eased, no shake, no flashes; Reduce effects = plain short fades.
-- One tween helper (RV2.play: one tween per object + key, a new one cancels the old) and one fade helper (RV2.fade:
-- an alpha per root over every descendant, re-read each frame so headshots and bot views added later follow).
RV2.tws = {} :: { [Instance]: { [string]: Tween } }
RV2.alphas = {} :: { [Instance]: number }
RV2.fades = {} :: { [Instance]: { nv: NumberValue, tw: Tween } }
RV2.counts = {} :: { [Instance]: NumberValue }
RV2.switch = 0
RV2.closing = false

function RV2.TI(t: number, style: Enum.EasingStyle?, dir: Enum.EasingDirection?, delay: number?): TweenInfo
	return TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0)
end

function RV2.play(inst: Instance, key: string, info: TweenInfo, props: { [string]: any }): Tween
	local slot = RV2.tws[inst]
	if not slot then
		slot = {}
		RV2.tws[inst] = slot
	end
	local old = slot[key]
	if old then
		old:Cancel()
	end
	local t = TweenService:Create(inst, info, props)
	slot[key] = t
	t:Play()
	return t
end

function RV2.stop(inst: Instance, key: string)
	local slot = RV2.tws[inst]
	local t = slot and slot[key]
	if t then
		t:Cancel()
		slot[key] = nil
	end
end

function RV2.setAlpha(root: Instance, a: number)
	RV2.alphas[root] = a
	local function prop(d: Instance, p: string)
		local key = "RVb" .. p
		local base = d:GetAttribute(key) :: number?
		if base == nil then
			base = (d :: any)[p]
			d:SetAttribute(key, base)
		end
		if (base :: number) < 1 then
			(d :: any)[p] = 1 - (1 - (base :: number)) * a
		end
	end
	local function one(d: Instance)
		if d:IsA("GuiObject") then
			prop(d, "BackgroundTransparency")
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				prop(d, "TextTransparency")
			elseif d:IsA("ImageLabel") or d:IsA("ImageButton") or d:IsA("ViewportFrame") then
				prop(d, "ImageTransparency")
			end
		elseif d:IsA("UIStroke") then
			prop(d, "Transparency")
		end
	end
	one(root)
	for _, d in ipairs(root:GetDescendants()) do
		one(d)
	end
end

function RV2.fade(root: Instance, a: number, info: TweenInfo): Tween
	local f = RV2.fades[root]
	if f then
		f.tw:Cancel()
		f.nv:Destroy()
	end
	local nv = Instance.new("NumberValue")
	nv.Value = RV2.alphas[root] or 1
	nv.Changed:Connect(function(v)
		RV2.setAlpha(root, v)
	end)
	local tw = TweenService:Create(nv, info, { Value = a })
	RV2.fades[root] = { nv = nv, tw = tw }
	tw.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			RV2.setAlpha(root, a)
			if RV2.fades[root] and RV2.fades[root].nv == nv then
				RV2.fades[root] = nil
			end
			nv:Destroy()
		end
	end)
	tw:Play()
	return tw
end

-- an object's resting place (set once; layoutTabs refreshes the tabs' own)
function RV2.base(inst: GuiObject): UDim2
	local b = inst:GetAttribute("RVBasePos") :: UDim2?
	if b == nil then
		b = inst.Position
		inst:SetAttribute("RVBasePos", b)
	end
	return b :: UDim2
end

function RV2.slide(inst: GuiObject, dx: number, dy: number, info: TweenInfo)
	local b = RV2.base(inst)
	inst.Position = b + UDim2.fromOffset(dx, dy)
	RV2.play(inst, "pos", info, { Position = b })
end

-- every piece of the screen sorted into the beats it moves with
function RV2.roots(g: Frame): { { inst: GuiObject, kind: string } }
	local out = {}
	local function add(i: Instance, kind: string)
		if i:IsA("GuiObject") then
			table.insert(out, { inst = i, kind = kind })
		end
	end
	for _, c in ipairs(g:GetChildren()) do
		if c.Name == "Banner" then
			add(c, "banner")
		elseif c.Name ~= "Panel" then
			add(c, "shell")
		end
	end
	local P = g:FindFirstChild("Panel")
	for _, c in ipairs(P and P:GetChildren() or {}) do
		if c:IsA("GuiObject") then
			local n = c.Name
			if n == "Podium" then
				for _, k in ipairs(c:GetChildren()) do
					add(k, if string.match(k.Name, "^Crown") then "crown" else k.Name)
				end
			elseif n == "TabPoints" or n == "TabSurvived" or n == "TabCatches" or n == "CycleBar" then
				add(c, "tabs")
			elseif n == "You" then
				add(c, "you")
			elseif n == "Continue" then
				add(c, "next")
			elseif (RV2.base(c) :: UDim2).Y.Offset >= 700 then
				add(c, "low")
			else
				add(c, "shell")
			end
		end
	end
	return out
end

function RV2.scale(g: Frame): UIScale
	local s = g:FindFirstChild("PopScale") :: UIScale?
	if not s then
		local n = Instance.new("UIScale")
		n.Name = "PopScale"
		n.Parent = g
		s = n
	end
	return s :: UIScale
end

-- XP and GOLD count up when the rewards box arrives
function RV2.countRewards(delay: number)
	local g, y = RV2.group(), RV2.you
	if not g then
		return
	end
	UI.countTo("rvXp", 0, g, "XpText", function(v) return ("+%d XP"):format(v) end)
	UI.countTo("rvGold", 0, g, "GoldTotal", function(v) return ("+%d GOLD"):format(v) end)
	local my = RV2.token
	task.delay(delay, function()
		if my ~= RV2.token or not y then
			return
		end
		UI.countTo("rvXp", tonumber(y.xp) or 0, g, "XpText", function(v) return ("+%d XP"):format(v) end)
		UI.countTo("rvGold", tonumber(y.gold) or 0, g, "GoldTotal", function(v) return ("+%d GOLD"):format(v) end)
	end)
end

-- hidden, ready to come in (UI.open's hook: before the fill, so nothing flashes)
function RV2.prep()
	local g = RV2.group()
	if not g then
		return
	end
	RV2.closing = false
	for _, r in ipairs(RV2.roots(g)) do
		RV2.setAlpha(r.inst, 0)
	end
	local dim = screen and screen:FindFirstChild("Dim")
	if dim then
		RV2.setAlpha(dim, 0)
	end
end

function RV2.enter()
	local g = RV2.group()
	if not g or not screen then
		return
	end
	local roots = RV2.roots(g)
	local pop = RV2.scale(g)
	local target = if RV2.phone then 1.1 else 1 -- phones: the panel fills the screen height (966 design px tall)
	for _, r in ipairs(roots) do -- the fill added headshots and bot views after prep: everything starts hidden
		RV2.setAlpha(r.inst, 0)
	end
	local dim = screen:FindFirstChild("Dim")
	local TI = RV2.TI
	if dim then
		RV2.fade(dim, 1, TI(0.25))
	end
	if reduceEffects() then
		RV2.stop(pop, "s")
		pop.Scale = target
		for _, r in ipairs(roots) do
			RV2.base(r.inst)
			RV2.fade(r.inst, 1, TI(0.2))
		end
		RV2.countRewards(0.1)
		return
	end
	pop.Scale = target * 0.92
	RV2.play(pop, "s", TI(0.35, Enum.EasingStyle.Back), { Scale = target })
	local Q, OUT = Enum.EasingStyle.Quad, Enum.EasingDirection.Out
	local beat = { -- kind -> delay, fade time, dx, dy, slide time, style
		shell = { 0, 0.25 },
		banner = { 0.05, 0.2, -160, 0, 0.3, Enum.EasingStyle.Quart },
		tabs = { 0.15, 0.25, 0, 14, 0.25, Q },
		Place2 = { 0.22, 0.25, 0, 28, 0.3, Q },
		Place3 = { 0.29, 0.25, 0, 28, 0.3, Q },
		Place1 = { 0.36, 0.25, 0, 40, 0.4, Enum.EasingStyle.Back },
		crown = { 0.5, 0.2, 0, -40, 0.3, Enum.EasingStyle.Back },
		you = { 0.45, 0.25, 0, 20, 0.25, Q },
		low = { 0.55, 0.25 },
		next = { 0.7, 0.2, 0, 10, 0.2, Q },
	}
	for _, r in ipairs(roots) do
		local b = beat[r.kind] or beat.shell
		RV2.fade(r.inst, 1, TI(b[2], Q, OUT, b[1]))
		if b[5] then
			RV2.slide(r.inst, b[3], b[4], TI(b[5], b[6], OUT, b[1]))
		end
	end
	RV2.countRewards(0.55)
end

-- exit (NEXT, X, the scrim, Escape, or the countdown's last half second): content fades and sinks, then the
-- panel shrinks a touch and fades, then the dim; done() hides the screen (about 0.42 s, 0.17 with Reduce effects)
function RV2.exit(done: () -> ())
	local g = RV2.group()
	if not g or not screen then
		done()
		return
	end
	RV2.closing = true
	RV2.token += 1 -- the cycle and countdown stop
	RV2.switch += 1
	local roots = RV2.roots(g)
	local pop = RV2.scale(g)
	local dim = screen:FindFirstChild("Dim")
	local TI = RV2.TI
	local function finish()
		for _, r in ipairs(roots) do
			RV2.stop(r.inst, "pos")
			r.inst.Position = RV2.base(r.inst)
		end
		RV2.stop(pop, "s")
		pop.Scale = if RV2.phone then 1.1 else 1
		RV2.clearViews() -- the emote podium's models and views go with the screen
		done()
	end
	if reduceEffects() then
		for _, r in ipairs(roots) do
			RV2.fade(r.inst, 0, TI(0.15))
		end
		if dim then
			RV2.fade(dim, 0, TI(0.15))
		end
		task.delay(0.17, finish)
		return
	end
	local IN = Enum.EasingDirection.In
	for _, r in ipairs(roots) do
		if r.kind == "shell" or r.kind == "banner" then
			RV2.fade(r.inst, 0, TI(0.2, Enum.EasingStyle.Quad, IN, 0.12))
		else
			RV2.fade(r.inst, 0, TI(0.16, Enum.EasingStyle.Quad, IN))
			RV2.play(r.inst, "pos", TI(0.18, Enum.EasingStyle.Quad, IN), { Position = RV2.base(r.inst) + UDim2.fromOffset(0, 12) })
		end
	end
	RV2.play(pop, "s", TI(0.2, Enum.EasingStyle.Quad, IN, 0.12), { Scale = (if RV2.phone then 1.1 else 1) * 0.95 })
	if dim then
		RV2.fade(dim, 0, TI(0.18, Enum.EasingStyle.Quad, IN, 0.22))
	end
	task.delay(0.42, finish)
end

-- a stat counting to its value as the card comes back in
function RV2.countStat(card: GuiObject, tab: string, e: any?)
	local old = RV2.counts[card]
	if old then
		old:Destroy()
		RV2.counts[card] = nil
	end
	if not e then
		return
	end
	local v = tonumber(e.v) or 0
	local function show(n: number)
		n = math.floor(n + 0.5)
		if tab == "Points" then
			setText(card, "StatText", ("+%s PTS"):format(K.format and K.format(n) or tostring(n)))
		elseif tab == "Survived" then
			setText(card, "SafeText", ("%d crossing%s"):format(n, if n == 1 then "" else "s"))
		else
			setText(card, "CatchText", ("%d catch%s"):format(n, if n == 1 then "" else "es"))
		end
	end
	if reduceEffects() or v <= 1 then
		show(v)
		return
	end
	local nv = Instance.new("NumberValue")
	RV2.counts[card] = nv
	nv.Value = 0
	show(0)
	nv.Changed:Connect(show)
	local tw = TweenService:Create(nv, RV2.TI(0.3), { Value = v })
	tw.Completed:Once(function()
		if RV2.counts[card] == nv then
			show(v)
			RV2.counts[card] = nil
		end
		nv:Destroy()
	end)
	tw:Play()
end

-- the tab switch: the highlight slides across, the cards cross-fade with a small slide in the switch direction
-- (staggered 0.04 s), names and headshots swap while they are hidden, the stat counts up. Rapid taps: every
-- step checks it is still the latest switch, and the fades / slides cancel what was running.
function RV2.switchTo(tab: string)
	local g = RV2.group()
	if not g or tab == RV2.tab then
		return
	end
	local from = table.find(RV2.tabs, RV2.tab) or 1
	local to = table.find(RV2.tabs, tab) or 1
	local dir = if to > from or (from == #RV2.tabs and to == 1) then 1 else -1
	local old = RV2.tab
	RV2.tab = tab
	RV2.switch += 1
	local my = RV2.switch
	task.delay(0.15, function() -- the YOU strip changes with the cards (as the first card swaps)
		if my == RV2.switch then
			pcall(RV2.youStrip, tab)
		end
	end)
	local reduce = reduceEffects()
	local TI = RV2.TI
	-- the highlight
	for _, name in ipairs(RV2.ORDER) do
		local t = find(g, "Tab" .. name)
		local on = t and t:FindFirstChild("On") :: GuiObject?
		local off = t and t:FindFirstChild("Off") :: GuiObject?
		if on and off then
			if name == tab then
				showTw(on, true)
				RV2.setAlpha(on, RV2.alphas[on] or 0)
				RV2.fade(on, 1, TI(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut))
				if not reduce then
					RV2.slide(on, -dir * 40, 0, TI(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut))
				end
				RV2.fade(off, 0, TI(0.2))
			elseif name == old or on.Visible then -- the old tab, or one a rapid tap passed over
				RV2.fade(on, 0, TI(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut))
				if not reduce then
					RV2.play(on, "pos", TI(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Position = RV2.base(on) + UDim2.fromOffset(dir * 40, 0) })
				end
				showTw(off, true)
				RV2.setAlpha(off, RV2.alphas[off] or 0)
				RV2.fade(off, 1, TI(0.2))
				task.delay(0.26, function()
					if RV2.tab ~= name then
						showTw(on, false)
						RV2.stop(on, "pos")
						on.Position = RV2.base(on)
					end
				end)
			end
		end
	end
	-- the cards (left to right in the switch direction)
	local list = RV2.lists[tab] or {}
	local order = if dir > 0 then { 2, 1, 3 } else { 3, 1, 2 }
	local slideX = if reduce then 0 else 24
	for k, i in ipairs(order) do
		local card = find(g, "Place" .. i) :: GuiObject?
		if card then
			local wait = (k - 1) * 0.04
			local base = RV2.base(card)
			local crown = if i == 1 then { find(g, "Crown"), find(g, "CrownShadow") } else {}
			RV2.fade(card, 0, TI(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In, wait))
			for _, c in ipairs(crown) do
				RV2.fade(c :: Instance, 0, TI(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In, wait))
			end
			if slideX > 0 then
				RV2.play(card, "pos", TI(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In, wait), { Position = base + UDim2.fromOffset(-dir * slideX, 0) })
			end
			task.delay(wait + 0.15, function()
				if my ~= RV2.switch then
					return
				end
				RV2.card(card, list[i], tab)
				RV2.countStat(card, tab, list[i])
				if slideX > 0 then
					card.Position = base + UDim2.fromOffset(dir * slideX, 0)
					RV2.play(card, "pos", TI(0.2), { Position = base })
				end
				RV2.fade(card, 1, TI(0.2))
				for _, c in ipairs(crown) do
					RV2.fade(c :: Instance, 1, TI(0.2))
				end
			end)
		end
	end
end

-- ===== the emote podium (Hunter OK 17 Oct, mock v2): each top-3 card shows the player, full body, doing their starred
-- emote on loop (no favourite, or a bot: a free emote picked for them). Players are built from their
-- HumanoidDescription (a copy of their character if that fails), bots wear their NpcSkins outfit. No scripts, the
-- root anchored, the emote on the Humanoid's Animator. The view fades in over the headshot (1.2 s) once it is ready;
-- Reduce effects, a load or animation failure, more than 2 s to load or low graphics keep the headshot.
-- One view per card (3 at most), models cached per player for this screen, everything destroyed on exit.
RV2.views = {} :: { [Instance]: any }
RV2.models = {} :: { [string]: Model }
RV2.FREE = { "loser_dance", "snappy_skip", "shuffle", "kpop_dance", "jumpstyle", "cossack_kick", "boogie_down", "candy_dance", "electro_shuffle", "rap_bounce" }

function RV2.lowGraphics(): boolean
	local ok, q = pcall(function()
		return UserSettings().GameSettings.SavedQualityLevel
	end)
	return ok and q ~= nil and q ~= Enum.SavedQualitySetting.Automatic and q.Value <= 3
end

function RV2.noStage(): boolean
	return reduceEffects() or RV2.lowGraphics()
end

function RV2.emoteFor(r: any): any?
	local function get(id: string?): any?
		if not id then
			return nil
		end
		for _, e in ipairs(EmoteConfig.LIST) do
			if e.id == id and e.animId ~= "" then
				return e
			end
		end
		return nil
	end
	if not r.npcSlot and (tonumber(r.userId) or 0) > 0 then
		local p = Players:GetPlayerByUserId(r.userId)
		local fav = get(p and p:GetAttribute("EOS_FavEmote") :: string?)
		if fav then
			return fav
		end
	end
	-- a free emote, the same one for this player all screen
	local seed = (tonumber(r.npcSlot) or 0) * 3 + math.abs(tonumber(r.userId) or 0) % 997 -- neighbours get different ones
	for k = 0, #RV2.FREE - 1 do
		local e = get(RV2.FREE[(seed + k) % #RV2.FREE + 1])
		if e then
			return e
		end
	end
	return nil
end

local function cleanModel(m: Model): Model?
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Tool") or d:IsA("BillboardGui") or d:IsA("ForceField") or d:IsA("Sound")
			or d:IsA("ParticleEmitter") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	local root = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	m.PrimaryPart = root
	m:PivotTo(CFrame.new(0, 3, 0))
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = p == root
			p.CanCollide = false
			p.CastShadow = false
		end
	end
	-- no physics in a viewport: each hat and hair handle goes on its body attachment by hand, then is welded
	for _, acc in ipairs(m:GetChildren()) do
		local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
		local a0 = handle and handle:FindFirstChildOfClass("Attachment")
		if handle and handle:IsA("BasePart") and a0 then
			for _, part in ipairs(m:GetChildren()) do
				local a1 = part:IsA("BasePart") and part ~= handle and part:FindFirstChild(a0.Name)
				if a1 and a1:IsA("Attachment") then
					for _, w in ipairs(handle:GetChildren()) do
						if w:IsA("JointInstance") or w:IsA("WeldConstraint") then
							w:Destroy()
						end
					end
					handle.CFrame = a1.WorldCFrame * a0.CFrame:Inverse()
					local w = Instance.new("WeldConstraint")
					w.Part0, w.Part1 = handle, part :: BasePart
					w.Parent = handle
					break
				end
			end
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		if not hum:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = hum
		end
	end
	return m
end

-- the player's model (yields; nil = keep the headshot)
function RV2.buildModel(r: any): (Model?, string)
	local key = if r.npcSlot then "npc" .. tostring(r.npcSlot) else "u" .. tostring(r.userId)
	local m: Model? = nil
	if r.npcSlot or (tonumber(r.userId) or 0) <= 0 then
		local ok, NpcSkins = pcall(function()
			return require(script.Parent:WaitForChild("NpcSkins", 2))
		end)
		local skin = ok and NpcSkins and NpcSkins.skinFor(r.npcSlot)
		if skin then
			m = skin:Clone()
		end
	else
		local p = Players:GetPlayerByUserId(r.userId)
		local hum = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local ok, built = pcall(function()
			local desc = if hum then hum:GetAppliedDescription() else Players:GetHumanoidDescriptionFromUserIdAsync(r.userId)
			return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R6)
		end)
		if ok and built then
			m = built
		elseif p and p.Character then -- a copy of what they look like in the game
			local c = p.Character
			local was = c.Archivable
			c.Archivable = true
			local ok2, copy = pcall(function()
				return c:Clone()
			end)
			c.Archivable = was
			m = if ok2 then copy else nil
		end
	end
	return if m then cleanModel(m) else nil, key
end

-- the alpha system's resting value for a piece of the card, so card fades and this reveal agree:
-- reveal(x, 1) = as built, reveal(x, 0) = hidden; the card's own alpha still applies on top
function RV2.reveal(inst: Instance, t: number, card: Instance)
	local a = RV2.alphas[card] or 1
	local function prop(d: Instance, p: string)
		local ok = d:GetAttribute("RVo" .. p) :: number?
		if ok == nil then
			ok = (d:GetAttribute("RVb" .. p) :: number?) or (d :: any)[p]
			d:SetAttribute("RVo" .. p, ok)
		end
		local base = 1 - (1 - (ok :: number)) * t
		d:SetAttribute("RVb" .. p, base);
		(d :: any)[p] = 1 - (1 - base) * a
	end
	local function one(d: Instance)
		if d:IsA("GuiObject") then
			prop(d, "BackgroundTransparency")
			if d:IsA("TextLabel") then
				prop(d, "TextTransparency")
			elseif d:IsA("ImageLabel") or d:IsA("ViewportFrame") then
				prop(d, "ImageTransparency")
			end
		elseif d:IsA("UIStroke") then
			prop(d, "Transparency")
		end
	end
	one(inst)
	for _, d in ipairs(inst:GetDescendants()) do
		one(d)
	end
end

function RV2.viewFor(card: GuiObject): any
	local v = RV2.views[card]
	if v and v.vf.Parent then
		return v
	end
	-- draw order once: the card art at the back, the character over it and the headshot, the words on top
	if not card:GetAttribute("RVz") then
		card:SetAttribute("RVz", true)
		for _, c in ipairs(card:GetChildren()) do
			if c:IsA("GuiObject") and c.Name ~= "Art" and c.Name ~= "Head" then
				c.ZIndex += 3
				for _, d in ipairs(c:GetDescendants()) do
					if d:IsA("GuiObject") then
						d.ZIndex += 3
					end
				end
			end
		end
	end
	local name = card:FindFirstChild("NameText") :: GuiObject?
	local W = card.Size.X.Offset
	local bottom = if name then name.Position.Y.Offset - 2 else card.Size.Y.Offset - 150
	local vf = Instance.new("ViewportFrame")
	vf.Name = "EmoteView"
	vf.BackgroundTransparency = 1
	vf.ImageTransparency = 1
	vf:SetAttribute("RVoImageTransparency", 0)
	vf:SetAttribute("RVbImageTransparency", 1)
	vf:SetAttribute("RVoBackgroundTransparency", 1)
	vf.ZIndex = 2
	vf.Position = UDim2.fromOffset(6, 8)
	vf.Size = UDim2.fromOffset(W - 12, bottom - 8)
	vf.Ambient = Color3.fromRGB(170, 170, 180)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-0.5, -1, -0.6)
	local wm = Instance.new("WorldModel")
	wm.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = card
	v = { vf = vf, wm = wm, cam = cam, key = nil, track = nil, token = 0 }
	RV2.views[card] = v
	return v
end

-- full body with room for raised arms and kicks, a slight 3/4 from the front (the right card turns the other way);
-- phones: the same, the card is just smaller
function RV2.frame(v: any, place: number)
	local vf, cam = v.vf, v.cam
	local aspect = vf.Size.X.Offset / math.max(1, vf.Size.Y.Offset)
	local needH = 7.2
	local dist = (needH / 2) / math.tan(math.rad(cam.FieldOfView / 2))
	if aspect < 0.75 then
		dist *= 0.75 / aspect
	end
	local focus = Vector3.new(0, 2.5, 0)
	local look = CFrame.Angles(0, math.rad(if place == 3 then -25 else 25), 0)
	cam.CFrame = CFrame.lookAt(focus + look.LookVector * dist, focus)
end

function RV2.clearView(card: Instance)
	local v = RV2.views[card]
	if not v then
		return
	end
	v.token += 1
	if v.track then
		pcall(function()
			v.track:Stop(0)
		end)
		v.track = nil
	end
	for _, c in ipairs(v.wm:GetChildren()) do
		c.Parent = nil -- back to the cache (RV2.models)
	end
	v.key = nil
	RV2.reveal(v.vf, 0, card)
	local head = card:FindFirstChild("Head")
	if head then
		RV2.reveal(head, 1, card)
	end
	local chip = card:FindFirstChild("EmoteChip")
	if chip then
		showTw(chip, false)
	end
end

function RV2.clearViews()
	for card, v in pairs(RV2.views) do
		if v.track then
			pcall(function()
				v.track:Stop(0)
			end)
		end
		v.vf:Destroy()
		local head = card:FindFirstChild("Head")
		if head then
			RV2.reveal(head, 1, card)
		end
		local chip = card:FindFirstChild("EmoteChip")
		if chip then
			showTw(chip, false)
		end
	end
	table.clear(RV2.views)
	for _, m in pairs(RV2.models) do
		m:Destroy()
	end
	table.clear(RV2.models)
end

-- the emote chip hugs its name and stays in the card's top-right corner at every size: the pill is the name's width
-- plus padding, right-aligned in the exported chip box, never wider than the card minus the rank corner; a name too
-- long for that shrinks on one line
function RV2.fitChip(chip: Instance, card: GuiObject, name: string)
	local box = chip :: GuiObject
	local pill = chip:FindFirstChild("F") :: GuiObject?
	local ring = chip:FindFirstChild("ShadowRing") :: GuiObject?
	local label = chip:FindFirstChild("EmoteText", true) :: TextLabel?
	if not (pill and label) then
		return
	end
	local design = (label:GetAttribute("UIDesignSize") :: number?) or 17
	local params = Instance.new("GetTextBoundsParams")
	params.Text = name
	params.Font = label.FontFace
	params.Size = design
	params.Width = 10000
	local bounds = game:GetService("TextService"):GetTextBoundsAsync(params)
	local pad = 12
	local maxPill = math.min(box.Size.X.Offset, card.Size.X.Offset - 110) -- clear of the "#2" / "JOINT #2" corner
	local textW = math.min(math.ceil(bounds.X) + 2, maxPill - 2 * pad)
	local pillW = textW + 2 * pad
	local x = box.Size.X.Offset - pillW
	for _, f in ipairs({ pill, ring }) do
		if f then
			f.Size = UDim2.new(0, pillW, f.Size.Y.Scale, f.Size.Y.Offset)
			f.Position = UDim2.new(0, x, f.Position.Y.Scale, f.Position.Y.Offset)
		end
	end
	for _, l in ipairs(chip:GetDescendants()) do
		if l:IsA("TextLabel") then
			local cap = l:FindFirstChildOfClass("UITextSizeConstraint")
			if cap then
				cap.MaxTextSize = design
			end
			l.TextWrapped = false
			l.TextScaled = bounds.X + 2 > textW -- shrink only when it doesn't fit
			if not l.TextScaled then
				l.TextSize = design
			end
			l.TextXAlignment = Enum.TextXAlignment.Center
			l.Size = UDim2.new(0, textW, l.Size.Y.Scale, l.Size.Y.Offset)
			l.Position = UDim2.new(0, (if l.Parent == pill then 0 else x) + pad, l.Position.Y.Scale, l.Position.Y.Offset)
		end
	end
end

-- the stage for one card (called whenever the card shows someone; the same player stays put across tabs)
function RV2.stage(card: GuiObject, e: any, place: number)
	if RV2.noStage() then
		RV2.clearView(card)
		return
	end
	local r = e.r
	local key = if r.npcSlot then "npc" .. tostring(r.npcSlot) else "u" .. tostring(r.userId)
	local v = RV2.viewFor(card)
	local head = card:FindFirstChild("Head")
	if v.key == key then
		if head then
			RV2.reveal(head, 0, card) -- a fresh headshot image under the character stays hidden
		end
		return
	end
	RV2.clearView(card)
	v.key = key
	v.token += 1
	local my = v.token
	local emote = RV2.emoteFor(r)
	local chip = card:FindFirstChild("EmoteChip")
	local cached = RV2.models[key] ~= nil -- seen on another tab: swap straight in while the card is hidden
	task.spawn(function()
		local done, model = false, nil
		task.spawn(function()
			local m = RV2.models[key]
			if not m then
				m = RV2.buildModel(r)
				if m then
					RV2.models[key] = m
				end
			end
			model = m
			done = true
		end)
		local t0 = os.clock()
		while not done and os.clock() - t0 < 2 do
			task.wait()
		end
		if my ~= v.token or not model or not emote or not v.vf.Parent then
			return -- too slow, failed, or the card moved on: the headshot stays
		end
		local m = model :: Model
		m.Parent = v.wm
		local hum = m:FindFirstChildOfClass("Humanoid")
		local an = hum and hum:FindFirstChildOfClass("Animator")
		local ok, track = pcall(function()
			local a = Instance.new("Animation")
			a.AnimationId = "rbxassetid://" .. emote.animId
			local t = (an :: Animator):LoadAnimation(a)
			t.Looped = true
			t:Play(0)
			return t
		end)
		if not ok or not track then
			m.Parent = nil
			return
		end
		v.track = track
		RV2.frame(v, place)
		if chip then
			setText(chip, "EmoteText", emote.name)
			pcall(RV2.fitChip, chip, card, emote.name)
			showTw(chip, true)
			RV2.reveal(chip, 0, card)
		end
		if cached then
			RV2.reveal(v.vf, 1, card)
			if head then
				RV2.reveal(head, 0, card)
			end
			if chip then
				RV2.reveal(chip, 1, card)
			end
			return
		end
		-- fade in over the headshot
		local nv = Instance.new("NumberValue")
		nv.Changed:Connect(function(x)
			if my ~= v.token then
				return
			end
			RV2.reveal(v.vf, x, card)
			if head then
				RV2.reveal(head, 1 - x, card)
			end
			if chip then
				RV2.reveal(chip, x, card)
			end
		end)
		local tw = TweenService:Create(nv, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = 1 })
		tw.Completed:Once(function()
			nv:Destroy()
		end)
		tw:Play()
	end)
end

-- a tap on a tab picks it and stops the cycle for this screen
function RV2.tap(button: Instance?)
	local t = button
	while t and t ~= screen do
		local name = string.match(t.Name, "^Tab(%a+)$")
		if name and RV2.lists[name] then
			RV2.auto = false
			RV2.switchTo(name)
			return true
		end
		t = t.Parent
	end
	return false
end

local function openBoard(results: any)
	if not screen then
		return
	end
	roundRestore() -- HOS-PTS-001: a round board still fading hands the panel back as built
	showGroup("PodiumBanner", false)
	showGroup("ResultsSkinRed", false)
	if RV2.group() then -- HOS-PTS-001: results v2 replaces the leaderboard card at the end of the match
		showGroup("Leaderboard", false)
		showGroup("ResultsV2", true)
		showGroup("Dim", true)
		if popHolder then -- the last crossing's pops never sit on the results
			for _, c in ipairs(popHolder:GetChildren()) do
				c:Destroy()
			end
		end
		UI.open(screen.Name) -- the hook (init) hides it first; RV2.enter brings it in once it is filled
		RV2.fill(results)
		RV2.enter()
		return
	end
	fillBoard(results)
	showGroup("Leaderboard", true)
	showGroup("Dim", true)
	UI.open(screen.Name)
end

local function runPodium(results: any)
	local model = workspace:WaitForChild("HOS_Podium", 3) :: Model?
	local banner = screen and screen:FindFirstChild("PodiumBanner")
	if banner and board then
		local title = if board.escaped == 0 then "CATCHERS WIN!" elseif board.escaped >= board.total then ("ALL %d ESCAPED!"):format(board.total) else ("%d OF %d ESCAPED!"):format(board.escaped, board.total)
		setText(banner, "Title", title)
		setFill(banner, "Title", if board.escaped == 0 then Color3.fromRGB(255, 90, 90) elseif board.escaped >= board.total then Color3.fromRGB(255, 210, 58) else Color3.fromRGB(184, 255, 74))
		showGroup("Leaderboard", false)
		showGroup("Dim", false)
		showGroup("PodiumBanner", true)
		if screen then
			screen.Visible = true
		end
	end
	local C = cinematic()
	if not model or not C or not PointsConfig.Podium.Enabled then
		openBoard(results)
		return
	end
	podiumCards(model)
	playWinners(model)
	local P = PointsConfig.Podium
	local function cam(name: string, place: number?): CFrame?
		local part = if place then (model:FindFirstChild("Step" .. place) and model["Step" .. place]:FindFirstChild("Cam")) else model:FindFirstChild(name)
		return part and (part :: BasePart).CFrame or nil
	end
	local wide = cam("CamWide")
	local shots = {}
	if wide then
		table.insert(shots, { duration = P.WIDE, from = wide * CFrame.new(0, 0, 4), to = wide, ease = "Sine" })
	end
	local cards: { GuiObject } = {}
	for _, place in ipairs({ 3, 2, 1 }) do
		local cf = cam("", place)
		if cf and board and board.rows[place] then
			table.insert(shots, { duration = P.PUSH, from = cf * CFrame.new(0, 0, 3), to = cf, ease = "Sine", place = place })
		end
	end
	local spec = {
		shots = shots,
		maxSeconds = P.WIDE + P.PUSH * 3 + P.CONFETTI + 1,
		keepGuis = { gui },
		hideHud = true,
		letterbox = true,
		onShot = function(_i: number, shot: any)
			for _, c in ipairs(cards) do
				c:Destroy()
			end
			table.clear(cards)
			if shot.place then
				local c = bigCard(shot.place)
				if c then
					table.insert(cards, c)
				end
			end
		end,
		onEnd = function()
			for _, c in ipairs(cards) do
				c:Destroy()
			end
			table.clear(cards)
			local s1 = model:FindFirstChild("Step1")
			local spot = s1 and s1:FindFirstChild("Spot") :: BasePart?
			if spot then
				confetti(spot.Position + Vector3.new(0, 6, 0))
			end
			task.delay(P.CONFETTI, function()
				openBoard(results)
			end)
		end,
	}
	local ok, err = pcall(C.play, spec)
	if not ok then
		warn("[Points] podium cinematic: " .. tostring(err))
		openBoard(results)
	end
end

local function onResults(results: any)
	if type(results) ~= "table" or not PointsConfig.Enabled then
		return
	end
	-- the old Results panel stays shut while Points is on (one results screen: ours)
	task.defer(function()
		local ok, UIC = pcall(function()
			return require(script.Parent:WaitForChild("UIController", 2))
		end)
		if ok and UIC and UIC.closeResults then
			UIC.closeResults()
		end
	end)
	if not board or (results.matchId and board.matchId and results.matchId ~= board.matchId) then
		return -- not in this match (the lobby still sees the podium in the world)
	end
	if PointsConfig.Podium.Enabled then
		task.spawn(runPodium, results)
	else
		task.spawn(openBoard, results) -- HOS-PTS-001: the podium is off (Hunter 17 Oct): straight to the results screen
	end
end

-- ===== my egg's story (for "Rare to Epic on crossing 3") =====
local function onEvolved(t: any)
	if type(t) ~= "table" or t.userId ~= player.UserId then
		return
	end
	local before, after = rarityOf(t.prevTier), rarityOf(t.newTier)
	if before ~= after then
		myEgg.from, myEgg.at = before, Net.state():GetAttribute("Wave") :: number?
	end
	myEgg.rarity = after
end

-- ===== favourite emote star on My Emotes (EmoteController names the cards Mine_<emoteId>) =====
local setFavRemote: RemoteEvent? = nil
local function favStars()
	local eos = player.PlayerGui:FindFirstChild("EOSUI")
	if not eos or not PointsConfig.Podium.Enabled then
		return
	end
	local fav = player:GetAttribute("EOS_FavEmote") :: string?
	for _, card in ipairs(eos:GetDescendants()) do
		if card:IsA("GuiObject") and card.Name:sub(1, 5) == "Mine_" and card.Visible then
			local id = card.Name:sub(6)
			local star = card:FindFirstChild("PtsFavStar") :: GuiObject?
			if not star then
				local s = K.template("FavStar") :: GuiObject?
				if not s then
					return
				end
				s.Name = "PtsFavStar"
				s.Position = UDim2.fromOffset(186, 20) -- top right of the 250-wide card (the approved mock)
				s.ZIndex = 20
				s.Parent = card
				local btn = s:FindFirstChild("BtnFav", true)
				if btn and btn:IsA("GuiButton") then
					btn.Activated:Connect(function()
						if setFavRemote then
							setFavRemote:FireServer(if player:GetAttribute("EOS_FavEmote") == id then "" else id)
						end
					end)
				end
				local tag = K.template("FavTag") :: GuiObject?
				if tag then
					tag.Name = "PtsFavTag"
					tag.Position = UDim2.fromOffset(45, 108)
					tag.ZIndex = 20
					tag.Parent = card
				end
				star = s
			end
			local on = fav == id
			local onB, offB = find(star, "On") :: GuiObject?, find(star, "Off") :: GuiObject?
			if onB then onB.Visible = on end
			if offB then offB.Visible = not on end
			local tag = card:FindFirstChild("PtsFavTag") :: GuiObject?
			if tag then tag.Visible = on end
		end
	end
end

-- ===== HUD: no clean streak with fixed crossings =====
-- the CLEAN STREAK row follows the server: shown while a streak can win the match (3 clean crossings in a row,
-- Hunter 17 Oct), hidden only when the streak win is off (StreakToWin 999)
local function hideStreak()
	local toWin = Net.state():GetAttribute("StreakToWin")
	local hide = type(toWin) == "number" and toWin >= 999
	local eos = player.PlayerGui:FindFirstChild("EOSUI")
	if not eos then
		return
	end
	local green: UIGradient? = nil
	for _, d in ipairs(eos:GetDescendants()) do
		if d:IsA("GuiObject") and (d.Name:match("^StreakPip%d$") or (d:IsA("TextLabel") and d.Text == "CLEAN STREAK")) then
			d.Visible = not hide
		end
		if d.Name == "StreakPip1" then
			green = d:FindFirstChildOfClass("UIGradient")
		end
	end
	-- every lit diamond the same green (only pip 1 was exported lit; UIController toggles the gradient per pip)
	if green then
		for _, d in ipairs(eos:GetDescendants()) do
			if d:IsA("GuiObject") and d.Name:match("^StreakPip[23]$") and not d:FindFirstChildOfClass("UIGradient") then
				local g = green:Clone()
				g.Enabled = d:GetAttribute("On") == true
				g.Parent = d
			end
		end
	end
end

function PointsController.init(g: ScreenGui, ui: any, kit: any)
	gui, UI, K = g, ui, kit
	-- HOS-PTS-001: results v2 level bar. First thing, before anything here can yield: the first ProfileState comes early
	Net.event("ProfileState").OnClientEvent:Connect(function(v)
		if type(v) == "table" then
			RV2.view = v
			if RV2.group() and RV2.group().Visible then
				pcall(RV2.level)
			end
		end
	end)
	if game:GetService("RunService"):IsStudio() then
		_G.HOS_RV2 = RV2 -- Studio only: playtest drivers poke the results screen
	end
	local root = gui:FindFirstChild("Root")
	screen = root and root:FindFirstChild("Points") :: Frame?
	-- HOS-PTS-001: build the row pool (and each row's headshot slot) now, so the first board open makes nothing
	task.defer(function()
		local lb = screen and screen:FindFirstChild("Leaderboard")
		local tpl = find(lb, "Row") :: GuiObject?
		if not tpl then
			return
		end
		for _, row in ipairs(rowPool(tpl, 8)) do
			local head = find(row, "Head")
			if head and not head:FindFirstChild("Shot") then
				local i = Instance.new("ImageLabel")
				i.Name = "Shot"
				i.BackgroundTransparency = 1
				i.Size = UDim2.fromScale(1, 1)
				i.Parent = head
			end
		end
	end)
	local folder = ReplicatedStorage:WaitForChild("EOS_Points", 30)
	if not folder then
		warn("[Points] EOS_Points remotes missing")
		return
	end
	(folder:WaitForChild("Pop") :: RemoteEvent).OnClientEvent:Connect(onPop);
	(folder:WaitForChild("Juke") :: RemoteEvent).OnClientEvent:Connect(onJuke);
	(folder:WaitForChild("Board") :: RemoteEvent).OnClientEvent:Connect(function(b)
		board = b
	end)
	local roundRemote = folder:WaitForChild("Round", 10) :: RemoteEvent?
	if roundRemote then
		roundRemote.OnClientEvent:Connect(onRound)
	end
	Net.event("Results").OnClientEvent:Connect(onResults)
	showGroup("ResultsV2", false)
	showGroup("ResultsSkinRed", false)
	if UI.hooks and screen then -- HOS-PTS-001: results v2 runs its own enter / exit
		UI.hooks[screen.Name] = {
			open = function(_s: Frame): boolean
				local g = RV2.group()
				if g and g.Visible then
					RV2.prep()
					return true
				end
				return false
			end,
			close = function(_s: Frame, done: () -> ()): boolean
				local g = RV2.group()
				if g and g.Visible and not RV2.closing then
					RV2.exit(done)
					return true
				end
				return false
			end,
		}
	end
	local state = Net.state()
	state:GetAttributeChangedSignal("Phase"):Connect(function()
		local ph = state:GetAttribute("Phase")
		if ph ~= "RESULTS" and screen then
			showGroup("PodiumBanner", false)
			if UI.current() == screen.Name then
				UI.close()
			end
			screen.Visible = false
		end
	end)
	Net.event("RunnerEvolved").OnClientEvent:Connect(onEvolved)
	Net.event("RunnerEvolved").OnClientEvent:Connect(function(t)
		if type(t) == "table" and t.userId == player.UserId then
			bannerUntil = math.max(bannerUntil, os.clock() + 1.4)
		end
	end)
	Net.event("RoleChanged").OnClientEvent:Connect(function(t)
		if type(t) == "table" and (t.cause == "CAPTURED" or t.cause == "TIMEOUT") then
			bannerUntil = math.max(bannerUntil, os.clock() + 1.6)
		end
		if type(t) == "table" and t.cause == "START" then
			myEgg.from, myEgg.at, myEgg.rarity = nil, nil, "common"
		end
	end)
	-- the screen's buttons: NEXT and the X close it
	if UI.Action then
		UI.Action:Connect(function(name: string)
			if name == "Continue" and screen and UI.current() == screen.Name then
				UI.close()
			end
		end)
		UI.Action:Connect(function(_name: string, _scr: any, button: Instance?) -- HOS-PTS-001: results v2 tabs
			pcall(RV2.tap, button)
		end)
	end
	-- revive: hold state from the prompt service (the server validates everything)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		local r = rings[prompt]
		if r then
			r.holdAt = os.clock()
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		local r = rings[prompt]
		if r then
			r.holdAt = nil
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 / RV.CHECK_HZ then
			acc = 0
			local ok, err = pcall(reviveStep)
			if not ok then
				warn("[Points] revive ring: " .. tostring(err))
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		if next(rings) then
			pcall(ringFrame)
		end
	end)
	task.spawn(function() -- SetFav comes from PodiumService (off): never hold the loop below on it
		setFavRemote = folder:WaitForChild("SetFav", 30) :: RemoteEvent?
	end)
	task.spawn(function()
		pcall(hideStreak) -- HOS-PTS-001: CLEAN STREAK row matches the server from the first frame
		local n = 0
		while true do
			pcall(favStars) -- HOS-PTS-001: the starred emote plays on the results screen's podium cards
			n += 1
			if n % 4 == 0 then
				pcall(hideStreak)
			end
			task.wait(0.5)
		end
	end)
end

return PointsController
