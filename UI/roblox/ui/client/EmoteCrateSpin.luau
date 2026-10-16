-- EmoteCrateSpin: plays the emote crate opening on screen.
--   crate wobbles -> bursts -> reel whips past and eases onto the prize -> landing juice -> reveal card
--
-- Purely cosmetic. The SERVER has already charged, rolled and granted the emote before play() is
-- called; this module only shows the result. The reel strip is built AROUND the known prize, and
-- the flavour tiles follow the crate's real rarity weights (no rigged near-misses).
--
-- Look: UI/web (roblox-ui-maker). The screen "EmoteCrate" (groups CrateTitle, CrateStage, Reel,
-- SkipHint, Reveal) and the templates Tile_common / Tile_rare / Tile_epic / Tile_legendary are
-- built from those pages. Timings and pitch match UI/web/emote_crate_spin.html: change both together.
--
-- Use (client):
--   local Spin = require(path.to.EmoteCrateSpin)
--   Spin.init({ gui = playerGui:WaitForChild("EmoteCrateUI"), templates = ReplicatedStorage:WaitForChild("EmoteCrateTemplates"),
--               sounds = { tick = ..., burst = ..., land = { Legendary = ... } },   -- optional, real recordings only
--               onOpenAgain = function() BuyEmoteCrate:FireServer(crateId) end })
--   CrateOpened.OnClientEvent:Connect(function(result) Spin.play(result) end)     -- see type Result

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local EmoteCrateSpin = {}

-- seconds. First open of a session gets the long spin; "Open again" spins are shorter.
EmoteCrateSpin.TIMING = {
	shake = 1.25, shakeRepeat = 0.6, burst = 0.35,
	spinFirst = 5.0, spinRepeat = 3.6, settle = 0.45,
	landHold = 0.7, reveal = 0.35, againTimeout = 8,
}
local TILE, PITCH = 190, 206 -- design px, same as build.py TILE / PITCH
local STRIP_LEN, FROM_END = 48, 6 -- tiles in the strip; the prize sits 6 from the end
local JITTER = 0.32 -- the reel stops anywhere within +-0.32 tile of the prize centre, then settles
local TICK_GAP = 0.03 -- at most one tick sound per 30 ms

EmoteCrateSpin.ORDER = { "Common", "Rare", "Epic", "Legendary" }
-- glow colour per rarity (build.py RARITY[...][4]); landShake = reel shake in design px
EmoteCrateSpin.RARITY = {
	Common = { key = "common", glow = Color3.fromRGB(217, 224, 230), landShake = 0, landScale = 1.08 },
	Rare = { key = "rare", glow = Color3.fromRGB(69, 207, 255), landShake = 0, landScale = 1.12 },
	Epic = { key = "epic", glow = Color3.fromRGB(217, 85, 255), landShake = 7, landScale = 1.12 },
	Legendary = { key = "legendary", glow = Color3.fromRGB(255, 210, 58), landShake = 14, landScale = 1.16 },
}

export type Emote = { id: string, name: string, rarity: string, image: string? }
export type Result = {
	prize: Emote, -- what the server granted
	pool: { Emote }, -- every emote this crate can give (fills the reel)
	weights: { [string]: number }?, -- the rarity weights the server rolled with
	crateName: string?, -- title, default "Emote Crate"
	crateImage: string?, -- the crate's picture (the one the shop shows)
	isNew: boolean?, -- false shows the "already have it" line
	dupeText: string?, -- what a duplicate gives, e.g. "Already owned: +50 coins"
	againPrice: string?, -- formatted price for "Open again"; nil hides the button
	canAffordAgain: boolean?, -- false: grey button + shortText
	shortText: string?, -- e.g. "Need 120 more"
}
export type Options = {
	gui: ScreenGui,
	templates: Instance,
	sounds: { tick: Sound?, burst: Sound?, reveal: Sound?, land: { [string]: Sound }? }?,
	onOpenAgain: (() -> ())?, -- ask the server for another open; its result comes back through play()
	onOpened: (() -> ())?, -- e.g. hide the HUD
	onClosed: (() -> ())?,
	juicy: ((GuiButton) -> ())?, -- the game's button hover/press helper, if it has one
}

local opts: Options = nil :: any
local screen: GuiObject = nil :: any
local queue: { Result } = {}
local busy = false
local skipping = false
local opens = 0
local blur: BlurEffect? = nil
local raysConn: RBXScriptConnection? = nil
local choice: string? = nil
local design: { [string]: any } = {}

-- ---------------------------------------------------------------- helpers
local function find(scope: Instance, name: string): any
	return scope:FindFirstChild(name, true)
end

local function key(rarity: string): string
	local r = EmoteCrateSpin.RARITY[rarity]
	return if r then r.key else string.lower(rarity)
end

local function rarityInfo(rarity: string)
	return EmoteCrateSpin.RARITY[rarity] or EmoteCrateSpin.RARITY.Common
end

-- every label named `name` under scope, its Shadow twin included (LESSONS: replace every twin)
local function setText(scope: Instance, name: string, text: string, skip: { Instance }?)
	for _, d in scope:GetDescendants() do
		if (d.Name == name or d.Name == name .. "Shadow") and (d:IsA("TextLabel") or d:IsA("TextButton")) then
			local inSkipped = false
			for _, s in skip or {} do
				if d:IsDescendantOf(s) then inSkipped = true end
			end
			if not inSkipped then (d :: TextLabel).Text = text end
		end
	end
end

local function show(obj: Instance?, on: boolean)
	if obj and obj:IsA("GuiObject") then (obj :: GuiObject).Visible = on end
end

local function scaleOf(obj: GuiObject): UIScale
	local s = obj:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Parent = obj
	end
	return s :: UIScale
end

local function tween(obj: Instance, t: number, style: Enum.EasingStyle, dir: Enum.EasingDirection, props: { [string]: any }): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style, dir), props)
	tw:Play()
	return tw
end

-- fade an image or a plain frame (exported glows are images; a radial div may come out either way)
local function fade(obj: GuiObject, from: number, to: number, t: number)
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		(obj :: ImageLabel).ImageTransparency = from
		tween(obj, t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { ImageTransparency = to })
	else
		obj.BackgroundTransparency = from
		tween(obj, t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = to })
	end
end

local function tint(obj: GuiObject?, c: Color3)
	if not obj then return end
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		(obj :: ImageLabel).ImageColor3 = c
	else
		obj.BackgroundColor3 = c
	end
end

local function play(s: Sound?)
	if s then SoundService:PlayLocalSound(s) end
end

-- waits for a tween unless the player taps to skip; returns false when skipped
local function await(tw: Tween): boolean
	while tw.PlaybackState == Enum.PlaybackState.Playing or tw.PlaybackState == Enum.PlaybackState.Begin do
		if skipping then
			tw:Cancel()
			return false
		end
		RunService.RenderStepped:Wait()
	end
	return true
end

local function sleep(t: number, skippable: boolean)
	local t0 = os.clock()
	while os.clock() - t0 < t do
		if skippable and skipping then return end
		RunService.RenderStepped:Wait()
	end
end

-- a template tile for this rarity (templates may wrap each tile in a same-named group)
local function tileTemplate(rarity: string): GuiObject?
	local n = "Tile_" .. key(rarity)
	local t = opts.templates:FindFirstChild(n, true)
	if t and t:FindFirstChild(n) then t = t:FindFirstChild(n) end
	if not t then
		t = opts.templates:FindFirstChild("Tile_common", true)
		warn("[EmoteCrateSpin] no template " .. n .. ", using Tile_common")
	end
	return t :: any
end

local function makeTile(e: Emote): GuiObject?
	local tpl = tileTemplate(e.rarity)
	if not tpl then return nil end
	local t = tpl:Clone()
	t.Visible = true
	t.AnchorPoint = Vector2.zero
	setText(t, "EmoteName", e.name)
	local icon = find(t, "Icon")
	if icon and e.image then (icon :: ImageLabel).Image = e.image end
	show(find(t, "Shade"), false)
	return t
end

-- ---------------------------------------------------------------- reel plan (cosmetic only)
local function weightedRarity(rng: Random, weights: { [string]: number }, available: { [string]: { Emote } }): string
	local total = 0
	for r, w in weights do
		if available[r] then total += w end
	end
	local x = rng:NextNumber() * total
	for _, r in EmoteCrateSpin.ORDER do
		local w = weights[r]
		if w and available[r] then
			x -= w
			if x <= 0 then return r end
		end
	end
	for r in available do return r end
	return "Common"
end

-- A strip of STRIP_LEN emotes with the prize at `landing`. Flavour tiles are drawn with the same
-- weights the server rolls with, so the reel looks like the real odds; neighbours are not rigged.
function EmoteCrateSpin.plan(pool: { Emote }, weights: { [string]: number }?, prize: Emote): ({ Emote }, number)
	local byRarity: { [string]: { Emote } } = {}
	for _, e in pool do
		byRarity[e.rarity] = byRarity[e.rarity] or {}
		table.insert(byRarity[e.rarity], e)
	end
	local w = weights
	if not w then -- no weights given: one share per emote
		w = {}
		for r, list in byRarity do (w :: any)[r] = #list end
	end
	local rng = Random.new()
	local strip: { Emote } = {}
	for i = 1, STRIP_LEN do
		local r = weightedRarity(rng, w :: any, byRarity)
		local list = byRarity[r]
		strip[i] = if list then list[rng:NextInteger(1, #list)] else prize
	end
	local landing = STRIP_LEN - FROM_END
	strip[landing] = prize
	return strip, landing
end

-- ---------------------------------------------------------------- the opening
local function hideAll()
	for _, g in { "CrateStage", "Reel", "SkipHint", "Reveal" } do show(find(screen, g), false) end
end

local function stripCentre(strip: GuiObject): number
	-- design px: the markers point at the strip's centre
	if strip.Size.X.Offset > 0 and strip.Size.X.Scale == 0 then return strip.Size.X.Offset / 2 end
	local track = find(strip, "Track") :: GuiObject
	local k = if track and track.Size.X.Offset > 0 then track.AbsoluteSize.X / track.Size.X.Offset else 1
	return strip.AbsoluteSize.X / 2 / math.max(k, 1e-3)
end

local function wiggle()
	for _, n in { "MarkerTop", "MarkerBottom" } do
		local m = find(screen, n) :: GuiObject
		if m then
			m.Rotation = if n == "MarkerTop" then -10 else 10
			tween(m, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Rotation = 0 })
		end
	end
end

local function shakeGroup(g: GuiObject, amp: number, t: number)
	local p0 = g.Position
	local t0 = os.clock()
	while os.clock() - t0 < t do
		local k = amp * (1 - (os.clock() - t0) / t)
		g.Position = p0 + UDim2.fromOffset((math.random() * 2 - 1) * k, (math.random() * 2 - 1) * k)
		RunService.RenderStepped:Wait()
	end
	g.Position = p0
end

local function crateStage(r: Result)
	local stage = find(screen, "CrateStage") :: GuiObject
	if not stage then return end
	show(stage, true)
	local icon = find(stage, "CrateIcon") :: GuiObject
	local burst = find(stage, "Burst") :: GuiObject
	show(burst, false)
	setText(stage, "Status", "Opening...")
	if icon and r.crateImage and icon:IsA("ImageLabel") then (icon :: ImageLabel).Image = r.crateImage end
	-- 1. wobble harder and harder
	local dur = if opens == 1 then EmoteCrateSpin.TIMING.shake else EmoteCrateSpin.TIMING.shakeRepeat
	if icon then
		local sc = scaleOf(icon)
		local t0 = os.clock()
		while os.clock() - t0 < dur and not skipping do
			local t = (os.clock() - t0) / dur
			icon.Rotation = (4 + 14 * t) * math.sin(t * dur * 2 * math.pi * (3 + 5 * t))
			sc.Scale = 1 + 0.12 * t
			RunService.RenderStepped:Wait()
		end
		icon.Rotation = 0
		sc.Scale = 1
	end
	skipping = false
	-- 2. burst
	play(opts.sounds and opts.sounds.burst)
	if burst then
		show(burst, true)
		local bs = scaleOf(burst)
		bs.Scale = 0.6
		tween(bs, EmoteCrateSpin.TIMING.burst, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Scale = 2 })
		fade(burst, 0, 1, EmoteCrateSpin.TIMING.burst)
	end
	if icon then show(icon, false) end
	sleep(EmoteCrateSpin.TIMING.burst * 0.5, false)
	show(stage, false)
	if icon then show(icon, true) end
end

local function spinReel(r: Result): (GuiObject?, { GuiObject }, number)
	local reel = find(screen, "Reel") :: GuiObject
	local strip = find(reel, "Strip") :: GuiObject
	local track = find(strip, "Track") :: GuiObject
	local glow = find(track, "PrizeGlow") :: GuiObject
	-- clear the previous strip (and the exported sample tiles); keep layout objects and the glow
	for _, c in track:GetChildren() do
		if c:IsA("GuiObject") and c ~= glow then c:Destroy() end
	end
	show(glow, false)
	local strip_, landing = EmoteCrateSpin.plan(r.pool, r.weights, r.prize)
	local tiles: { GuiObject } = {}
	local z = (if glow then glow.ZIndex else 1) + 1
	for i, e in strip_ do
		local t = makeTile(e)
		if t then
			t.Name = if i == landing then "Prize" else "Tile" .. i
			t.Position = UDim2.fromOffset((i - 1) * PITCH, design.tileY)
			t.ZIndex = z
			t.Parent = track
			tiles[i] = t
		end
	end
	local cx = stripCentre(strip)
	local function tx(i: number): number
		return cx - ((i - 1) * PITCH + TILE / 2)
	end
	local p0 = design.trackPos :: UDim2
	local value = Instance.new("NumberValue")
	local last = 3
	local lastTick = 0
	local function place(x: number)
		track.Position = UDim2.new(p0.X.Scale, x, p0.Y.Scale, p0.Y.Offset)
		local idx = math.floor((cx - x - TILE / 2) / PITCH + 0.5) + 1
		if idx ~= last then
			last = idx
			wiggle()
			if os.clock() - lastTick >= TICK_GAP then
				lastTick = os.clock()
				play(opts.sounds and opts.sounds.tick)
			end
		end
	end
	value.Changed:Connect(place)
	local start, final = tx(3), tx(landing)
	local over = final - (math.random() * 2 - 1) * JITTER * PITCH -- stop somewhere on the prize tile
	value.Value = start
	place(start)
	show(reel, true)
	show(find(screen, "SkipHint"), true)
	-- 3. whip, long Quint ease onto the prize tile, then a Back settle to its centre
	local dur = if opens == 1 then EmoteCrateSpin.TIMING.spinFirst else EmoteCrateSpin.TIMING.spinRepeat
	if await(tween(value, dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Value = over })) then
		await(tween(value, EmoteCrateSpin.TIMING.settle, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Value = final }))
	end
	skipping = false
	value.Value = final
	place(final)
	value:Destroy()
	show(find(screen, "SkipHint"), false)
	return glow, tiles, landing
end

local function land(r: Result, glow: GuiObject?, tiles: { GuiObject }, landing: number)
	local info = rarityInfo(r.prize.rarity)
	for i, t in tiles do
		if i ~= landing then
			local shade = find(t, "Shade") :: GuiObject
			if shade then
				show(shade, true)
				fade(shade, 1, design.shadeT, 0.3)
			end
		end
	end
	local prize = tiles[landing]
	if prize then
		prize.ZIndex += 1
		local s = scaleOf(prize)
		s.Scale = 1
		tween(s, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = info.landScale })
	end
	if glow and prize then
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromOffset(prize.Position.X.Offset + TILE / 2, design.tileY + TILE / 2)
		tint(glow, info.glow)
		show(glow, true)
		fade(glow, 1, 0, 0.3)
	end
	local landSounds = opts.sounds and opts.sounds.land
	play(landSounds and landSounds[r.prize.rarity])
	if info.landShake > 0 then shakeGroup(find(screen, "Reel"), info.landShake, 0.4) end
	sleep(EmoteCrateSpin.TIMING.landHold, false)
end

local function reveal(r: Result)
	local rev = find(screen, "Reveal") :: GuiObject
	if not rev then return end
	local info = rarityInfo(r.prize.rarity)
	local card = find(rev, "Card") :: GuiObject
	for _, rr in EmoteCrateSpin.ORDER do show(find(rev, "Head_" .. EmoteCrateSpin.RARITY[rr].key), rr == r.prize.rarity) end
	-- the big tile: a clone of the rarity template in the sample's spot
	local sample = find(rev, "TileSample") :: GuiObject
	local old = find(rev, "RevealTile")
	if old then old:Destroy() end
	local big: GuiObject? = nil
	if sample then
		show(sample, false)
		big = makeTile(r.prize)
		if big then
			big.Name = "RevealTile"
			big.AnchorPoint = sample.AnchorPoint
			big.Position = sample.Position
			big.ZIndex = sample.ZIndex
			scaleOf(big).Scale = sample.Size.X.Offset / TILE
			big.Parent = sample.Parent
		end
	end
	local skip: { Instance } = { sample }
	if big then table.insert(skip, big) end
	setText(card or rev, "EmoteName", r.prize.name, skip)
	local isNew = r.isNew ~= false
	show(find(rev, "NewTagRow"), isNew)
	show(find(rev, "DupeTagRow"), not isNew)
	if not isNew and r.dupeText then setText(rev, "DupeTag", r.dupeText) end
	local again = find(rev, "BtnAgain") :: GuiObject
	show(again, r.againPrice ~= nil and opts.onOpenAgain ~= nil)
	if r.againPrice then setText(rev, "Price", r.againPrice) end
	local poor = r.canAffordAgain == false
	show(find(rev, "AgainPlate"), not poor)
	show(find(rev, "AgainPlatePoor"), poor)
	show(find(rev, "ShortRow"), poor and r.againPrice ~= nil)
	if r.shortText then setText(rev, "Short", r.shortText) end
	tint(find(rev, "Glow"), info.glow)
	local rays = find(rev, "Rays") :: GuiObject
	tint(rays, info.glow)
	if raysConn then raysConn:Disconnect() end
	if rays then
		raysConn = RunService.RenderStepped:Connect(function(dt)
			rays.Rotation = (rays.Rotation + dt * 15) % 360
		end)
	end
	show(rev, true)
	if card then
		local s = scaleOf(card)
		s.Scale = 0.6
		tween(s, EmoteCrateSpin.TIMING.reveal, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
	end
	play(opts.sounds and opts.sounds.reveal)
end

local function openScreen()
	opts.gui.Enabled = true
	show(screen, true)
	hideAll()
	local cam = Workspace.CurrentCamera
	if cam and not blur then -- blur on the CAMERA, not Lighting (PATTERNS: crate opening)
		local b = Instance.new("BlurEffect")
		b.Size = 0
		b.Parent = cam
		blur = b
		tween(b, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = 16 })
	end
	if opts.onOpened then opts.onOpened() end
end

function EmoteCrateSpin.close()
	if raysConn then raysConn:Disconnect(); raysConn = nil end
	local b = blur
	blur = nil
	if b then
		tween(b, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = 0 }).Completed:Connect(function()
			b:Destroy()
		end)
	end
	hideAll()
	show(screen, false)
	if opts.onClosed then opts.onClosed() end
end

local function runQueue()
	busy = true
	openScreen()
	while true do
		local r = table.remove(queue, 1)
		if not r then break end
		opens += 1
		skipping = false
		choice = nil
		hideAll()
		setText(find(screen, "CrateTitle") or screen, "Title", r.crateName or "Emote Crate")
		crateStage(r)
		local glow, tiles, landing = spinReel(r)
		land(r, glow, tiles, landing)
		reveal(r)
		-- the player claims it themselves (never auto-claim); Open again asks the server for another
		choice = nil
		while not choice do RunService.RenderStepped:Wait() end
		if choice == "again" and #queue == 0 and opts.onOpenAgain then
			show(find(screen, "Reveal"), false)
			opts.onOpenAgain()
			local t0 = os.clock() -- the server's result arrives through play(); give up quietly if it doesn't
			while #queue == 0 and os.clock() - t0 < EmoteCrateSpin.TIMING.againTimeout do RunService.RenderStepped:Wait() end
		end
	end
	EmoteCrateSpin.close()
	busy = false
end

-- Show one opening. Results that arrive while one is playing wait their turn.
function EmoteCrateSpin.play(r: Result)
	assert(opts, "EmoteCrateSpin.init first")
	table.insert(queue, r)
	if not busy then task.spawn(runQueue) end
end

function EmoteCrateSpin.isBusy(): boolean
	return busy
end

function EmoteCrateSpin.init(o: Options)
	opts = o
	screen = (o.gui:FindFirstChild("EmoteCrate", true) or o.gui) :: any
	-- remember the exported layout the runtime moves around
	local track = find(screen, "Track") :: GuiObject
	local sampleTile = track and (track:FindFirstChild("Prize") or track:FindFirstChildWhichIsA("Frame")) :: GuiObject
	design.trackPos = if track then track.Position else UDim2.new()
	design.tileY = if sampleTile then sampleTile.Position.Y.Offset else 30
	local tpl = tileTemplate("Common")
	local shade = tpl and find(tpl, "Shade") :: GuiObject
	design.shadeT = if shade then shade.BackgroundTransparency else 0.38
	if track then track.ClipsDescendants = false end -- the Strip clips; the landed prize may grow past its row
	hideAll()
	show(screen, false)
	-- buttons
	local claim = find(screen, "BtnClaim") :: GuiButton
	local again = find(screen, "BtnAgain") :: GuiButton
	for _, b in { claim, again } do
		if b and o.juicy then o.juicy(b) end
	end
	if claim then claim.Activated:Connect(function() choice = "claim" end) end
	if again then again.Activated:Connect(function() choice = "again" end) end
	-- tap anywhere to skip the wobble / spin (never the reveal: that needs a button)
	UserInputService.InputBegan:Connect(function(input)
		if not busy then return end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Space then
			local rev = find(screen, "Reveal") :: GuiObject
			if not (rev and rev.Visible) then skipping = true end
		end
		-- Escape / B on the reveal = Claim (Escape may arrive processed, so check before anything else)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			local rev = find(screen, "Reveal") :: GuiObject
			if rev and rev.Visible then choice = "claim" end
		end
	end)
	GuiService.MenuOpened:Connect(function()
		local rev = find(screen, "Reveal") :: GuiObject
		if busy and rev and rev.Visible then choice = "claim" end
	end)
end

return EmoteCrateSpin
