--!nocheck
-- SpinWheelController (HOS-SPIN-001, 18 Oct 2026, Matthew): the lobby spin wheel on the client.
--  * walk up to the wheel (Workspace.SpinWheel) and the spin screen opens (SpinWheelUI, built by
--    tools/build/HOS-SPIN-001/build_ui.lua); walk away and it closes. Closed with X, it waits until you've left.
--  * SPIN! / SPIN x5 / SPIN x10 ask the server (EOS_SpinWheel.Spin), which rolls and pays; the screen's wheel then
--    turns to the result and the prize pops up in the middle over a black shade (Root.Prize). SPIN x5 / x10 open that
--    many wheels at once instead (Root.Multi), all spinning together, each landing on its own prize, which shows under
--    it. What a wheel lands on is exactly what that spin paid. COLLECT! sends it home: Gold and Gems fly as single
--    coins / gems to the HUD wallet (bottom left), egg shards to the HUD's incubator button (top left), each from the
--    wheel or popup it was won on. The wallet waits for them: its count-up (EOSUI's UI.countTo) is held from the spin
--    until the first coin lands.
--  * the big wheel in the lobby turns for everyone near it when anyone spins (Spun); far away it just jumps
--  * the sign over the crystal shows the free spin timer
--  * spin packs prompt their developer product (SpinWheelConfig.PACKS; not on sale until they have a productId)
-- Wheel angles are radians, counter-clockwise as you face the wheel; slot k is at the top when the angle is
-- (k - 1) * 45 degrees (mod a full turn). The wheel spins clockwise.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local C = require(Shared:WaitForChild("SpinWheelConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local LobbyGate = require(script.Parent:WaitForChild("LobbyGate"))
local Sound = require(script.Parent:WaitForChild("Sound"))

local player = Players.LocalPlayer
local SpinWheelController = {}

local UIC, UI
local gui, screen, panel, vf, slotsFrame, prize, multi, flyLayer
local miniTemplate = nil -- the screen's wheel at rest, copied for the x5 / x10 wheels
local remotes
local state = nil
local clockOffset = 0
local spinning = false
local oddsMode = false

local OPEN_AT, CLOSE_AT = 8, 12 -- studs from the spot in front of the steps
local TURNS = 4 -- full turns before it settles
local SLOT_R = 4.05 -- studs from the hub to a slot's icon
local STEP = math.rad(45)
local TAU = math.pi * 2
local GREY = Color3.fromRGB(110, 110, 110)

---------------------------------------------------------------- helpers
local function serverNow(): number
	return os.time() + clockOffset
end

local function freeReady(): boolean
	return state ~= nil and (state.freeAt or 0) <= serverNow()
end

local function have(): number
	if not state then return 0 end
	return (state.spins or 0) + (if freeReady() then 1 else 0)
end

local function clock(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function setText(scope, name, text)
	UI.setText(scope, name, text)
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then return s end
	end
end

-- a wheel model turned to angle a about its hub (rest = its pivot at angle 0)
local function turn(model, rest, centre, axis, a)
	model:PivotTo(CFrame.new(centre) * CFrame.fromAxisAngle(axis, a) * CFrame.new(-centre) * rest)
end

-- from angle a0, clockwise, to slot k (a little off its middle so it doesn't look canned)
local function targetFor(a0: number, k: number): number
	local want = (k - 1) * STEP + (math.random() - 0.5) * STEP * 0.6
	return a0 - TURNS * TAU - ((a0 - want) % TAU)
end

local function ease(u: number): number
	return 1 - (1 - u) ^ 4
end

---------------------------------------------------------------- the screen's wheel
local ui = { model = nil, rest = nil, centre = nil, axis = nil, angle = 0 }

local function placeSlotsIn(view: ViewportFrame, slots: Frame, a: number)
	local size = view.Size.X.Offset
	local pps = (size / 2) / view:GetAttribute("HalfStuds")
	local cx, cy = size / 2, size / 2 + view:GetAttribute("LiftStuds") * pps
	for _, f in slots:GetChildren() do
		local k = f:GetAttribute("Slot")
		if k then
			local phi = (k - 1) * STEP - a -- clockwise from the top, on screen
			f.Position = UDim2.fromOffset(cx + SLOT_R * pps * math.sin(phi), cy - SLOT_R * pps * math.cos(phi))
			f.Rotation = math.deg(phi)
		end
	end
end

local function setUiAngle(a: number)
	ui.angle = a
	turn(ui.model, ui.rest, ui.centre, ui.axis, a)
	placeSlotsIn(vf, slotsFrame, a)
end

---------------------------------------------------------------- the lobby's wheel
local world = { model = nil, rest = nil, centre = nil, axis = nil, angle = 0, token = 0 }

local function bindWorld()
	local sw = workspace:FindFirstChild("SpinWheel")
	local w = sw and sw:FindFirstChild("Wheel")
	if not w or w == world.model then return end
	local pivot = sw:GetPivot()
	world.model = w
	world.rest = w:GetPivot() -- streamed in fresh, so at angle 0
	world.centre = pivot:PointToWorldSpace(Vector3.new(0, 10.72, 0))
	world.axis = pivot.ZVector
	if world.angle % TAU ~= 0 then turn(w, world.rest, world.centre, world.axis, world.angle) end
end

local function spinWorld(slot: number)
	bindWorld()
	world.token += 1
	local token = world.token
	local a0 = world.angle
	local a1 = targetFor(a0, slot)
	local w = world.model
	if not w or not w.Parent or not LobbyGate.active() or not LobbyGate.near(world.centre, 150) then
		world.angle = a1 % TAU
		if w and w.Parent then turn(w, world.rest, world.centre, world.axis, world.angle) end
		return
	end
	local t0 = os.clock()
	while token == world.token and w.Parent do
		local u = math.min(1, (os.clock() - t0) / C.SPIN_TIME)
		world.angle = a0 + (a1 - a0) * ease(u)
		turn(w, world.rest, world.centre, world.axis, world.angle)
		if u >= 1 then break end
		RunService.RenderStepped:Wait()
	end
	world.angle %= TAU
end

---------------------------------------------------------------- screen state
-- greyed, but still clickable: a press says why it can't spin
local function grey(b: Instance, off: boolean)
	for _, d in b:GetDescendants() do
		if d:IsA("ImageLabel") and d.Name == "Art" then d.ImageColor3 = if off then GREY else Color3.new(1, 1, 1) end
	end
end

local function refresh()
	if not panel then return end
	local free = freeReady()
	setText(panel, "TimerText", if free then "Free spin ready!" elseif state then "Free spin in " .. clock((state.freeAt or 0) - serverNow()) else "...")
	setText(panel, "SpinsText", "Spins: " .. (if state then commas(state.spins or 0) else "0"))
	local n = have()
	setText(panel.BtnSpin, "Label", if free then "FREE SPIN!" else "SPIN!")
	grey(panel.BtnSpin, spinning or n < 1)
	grey(panel.BtnSpin5, spinning or n < 5)
	grey(panel.BtnSpin10, spinning or n < 10)
	-- the sign over the crystal
	local sw = workspace:FindFirstChild("SpinWheel")
	local anchor = sw and sw:FindFirstChild("SpinSign")
	local sign = anchor and anchor:FindFirstChild("Sign")
	if sign and state then
		local sub = sign:FindFirstChild("Sub")
		if sub then
			sub.Text = if free then "Free spin ready!"
				elseif (state.spins or 0) > 0 then "You have " .. state.spins .. " spin" .. (if state.spins == 1 then "" else "s")
				else "Free spin in " .. clock((state.freeAt or 0) - serverNow())
		end
	end
end

local function setOdds(on: boolean)
	oddsMode = on
	for _, f in slotsFrame:GetChildren() do
		local k = f:GetAttribute("Slot")
		if k then
			setText(f, "Amount", if on then string.format("%g%%", math.floor(C.chance(k) * 1000 + 0.5) / 10) else C.short(C.SLOTS[k]))
		end
	end
	setText(panel.BtnOdds, "OddsText", if on then "PRIZES" else "ODDS")
end

---------------------------------------------------------------- the HUD wallet waits for the coins
-- EOSUI's wallet counts up through its UI module's countTo (keys "gold" / "gems"). While a spin is held, the newest
-- call is kept and run on release, so the number climbs as the coins land instead of before the wheel stops.
local held = { gold = 0, gems = 0 }
local heldCall = {}
local heldSince = 0
local origCountTo = nil

local function hookWallet()
	local eos = player.PlayerGui:WaitForChild("EOSUI", 30)
	local mod = eos and eos:WaitForChild("UI", 30)
	if not mod then return end
	local EUI = require(mod)
	if origCountTo or type(EUI.countTo) ~= "function" then return end
	origCountTo = EUI.countTo
	EUI.countTo = function(key, ...)
		if held[key] and held[key] > 0 then
			heldCall[key] = table.pack(key, ...)
			return
		end
		return origCountTo(key, ...)
	end
end

local function hold(kind: string, on: boolean)
	held[kind] = math.max(0, held[kind] + (if on then 1 else -1))
	if on then heldSince = os.clock() end
	if held[kind] == 0 and heldCall[kind] and origCountTo then
		local a = heldCall[kind]
		heldCall[kind] = nil
		origCountTo(table.unpack(a, 1, a.n))
	end
end

local function releaseAll()
	for kind in held do
		held[kind] = 1
		hold(kind, false)
	end
end

---------------------------------------------------------------- results
local function describe(g): (string, string)
	if g.kind == "gold" then return "+" .. commas(g.amount) .. " Gold", C.ICONS.gold end
	if g.kind == "gems" then return "+" .. commas(g.amount) .. " Gems", C.ICONS.gems end
	if g.kind == "shard" then return (g.rarity:gsub("^%l", string.upper)) .. " egg shard", C.ICONS[g.rarity] or C.ICONS.common end
	if g.kind == "weapon" then
		local item = EconomyConfig.item(g.itemId)
		local name = if item then item.name else "Weapon"
		return if g.dupe then name .. " (+" .. (g.shards or 0) .. " Weapon Shards)" else name, C.ICONS.weapon
	end
	return "", ""
end

---------------------------------------------------------------- flying home
-- a gui object's centre in the Fly layer's pixels (every lobby gui ignores the top bar inset the same way)
local function centreOf(g: GuiObject): Vector2
	return g.AbsolutePosition + g.AbsoluteSize / 2 - flyLayer.AbsolutePosition
end

local function visible(g: GuiObject?): boolean
	if not g or g.AbsoluteSize.X < 2 then return false end
	local x: Instance? = g
	while x and x:IsA("GuiObject") do
		if not x.Visible then return false end
		x = x.Parent
	end
	local lc = g:FindFirstAncestorWhichIsA("LayerCollector")
	return lc ~= nil and lc.Enabled
end

local function hudTarget(kind: string): GuiObject?
	local eos = player.PlayerGui:FindFirstChild("EOSUI")
	local hud = eos and eos:FindFirstChild("Root") and eos.Root:FindFirstChild("HUD")
	if not hud then return nil end
	local g = if kind == "shard" then hud:FindFirstChild("IncubatorButton", true)
		elseif kind == "gems" then hud:FindFirstChild("GemsIcon", true)
		else hud:FindFirstChild("GoldIcon", true)
	return if visible(g) then g else nil
end

local function fallbackTarget(kind: string): Vector2
	local s = flyLayer.AbsoluteSize
	return if kind == "shard" then Vector2.new(90, 60) else Vector2.new(90, s.Y - 90)
end

local function fitScale(): number
	local fs = gui.Root:FindFirstChild("FitScale")
	return if fs then fs.Scale else 1
end

local function bezier(a: Vector2, b: Vector2, c: Vector2, t: number): Vector2
	local u = 1 - t
	return a * (u * u) + b * (2 * u * t) + c * (t * t)
end

-- a quick sparkle and a "+n" where things land
local function landFx(at: Vector2, text: string?)
	local k = fitScale()
	local sp = Instance.new("ImageLabel")
	sp.BackgroundTransparency = 1
	sp.Image = "rbxassetid://125948263137023"
	sp.AnchorPoint = Vector2.new(0.5, 0.5)
	sp.Position = UDim2.fromOffset(at.X, at.Y)
	sp.Size = UDim2.fromOffset(20 * k, 20 * k)
	sp.ZIndex = 3
	sp.Parent = flyLayer
	TweenService:Create(sp, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(110 * k, 110 * k), ImageTransparency = 1, Rotation = 90 }):Play()
	Debris:AddItem(sp, 0.4)
	if text then
		local src = prize.Reveal:FindFirstChild("ItemName")
		if src then
			local t = src:Clone()
			t.Text = text
			t.TextSize = math.max(14, math.floor(34 * k))
			t.TextColor3 = Color3.new(1, 1, 1)
			for _, d in t:GetChildren() do
				if d:IsA("UIStroke") then d.Thickness = math.max(1.5, 3 * k) end
			end
			t.AnchorPoint = Vector2.new(0.5, 0.5)
			t.Size = UDim2.fromOffset(300 * k, 50 * k)
			t.Position = UDim2.fromOffset(at.X + 70 * k, at.Y - 20 * k)
			t.ZIndex = 4
			t.Parent = flyLayer
			TweenService:Create(t, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(at.X + 70 * k, at.Y - 90 * k), TextTransparency = 1 }):Play()
			for _, d in t:GetChildren() do
				if d:IsA("UIStroke") then TweenService:Create(d, TweenInfo.new(0.9), { Transparency = 1 }):Play() end
			end
			Debris:AddItem(t, 1)
		end
	end
end

-- one icon: bursts out of the prize, then curves home and shrinks into the target
local function flyOne(image: string, from: Vector2, kind: string, delay: number, onLand: () -> ())
	task.delay(delay, function()
		local k = fitScale()
		local size = (if kind == "shard" then 92 else 76) * k
		local im = Instance.new("ImageLabel")
		im.BackgroundTransparency = 1
		im.Image = image
		im.ScaleType = Enum.ScaleType.Fit
		im.AnchorPoint = Vector2.new(0.5, 0.5)
		im.Size = UDim2.fromOffset(size, size)
		im.Position = UDim2.fromOffset(from.X, from.Y)
		im.ZIndex = 2
		im.Parent = flyLayer
		local a = math.random() * TAU
		local burst = from + Vector2.new(math.cos(a), math.sin(a)) * (math.random(70, 170) * k)
		local t0 = os.clock()
		while os.clock() - t0 < 0.28 do
			local u = ease((os.clock() - t0) / 0.28)
			local p = from:Lerp(burst, u)
			im.Position = UDim2.fromOffset(p.X, p.Y)
			im.Rotation = 25 * u
			RunService.RenderStepped:Wait()
		end
		local target = hudTarget(kind)
		local to = if target then centreOf(target) else fallbackTarget(kind)
		local mid = (burst + to) / 2 + Vector2.new(math.random(-160, 160), -math.random(80, 220)) * k
		local dur = 0.55 + math.random() * 0.25
		t0 = os.clock()
		while true do
			local u = math.min(1, (os.clock() - t0) / dur)
			local e = u * u -- speeds up into the target
			local p = bezier(burst, mid, to, e)
			im.Position = UDim2.fromOffset(p.X, p.Y)
			local s = size * (1 - 0.45 * e)
			im.Size = UDim2.fromOffset(s, s)
			im.Rotation = 25 + 200 * e
			if u >= 1 then break end
			RunService.RenderStepped:Wait()
		end
		im:Destroy()
		onLand()
	end)
end

-- everything won goes home. items = { { g = what one spin gave, from = where it was shown } }: each prize bursts
-- from its own wheel (or the popup) as single coins / gems / shards; the first of a kind to land starts the wallet
local function sendHome(items)
	local single = #items == 1
	local totals = { gold = 0, gems = 0, shard = 0 }
	local flights = {}
	for _, it in items do
		local g = it.g
		if g.kind == "gold" or g.kind == "gems" then
			totals[g.kind] += g.amount
			local n = if single
				then (if g.kind == "gold" then math.clamp(math.floor(g.amount / 60), 6, 14) else math.clamp(g.amount, 4, 10))
				else (if g.kind == "gold" then math.clamp(math.floor(g.amount / 100) + 1, 2, 5) else math.clamp(g.amount, 2, 5))
			for _ = 1, n do table.insert(flights, { kind = g.kind, image = C.ICONS[g.kind], from = it.from }) end
		elseif g.kind == "shard" then
			totals.shard += 1
			table.insert(flights, { kind = "shard", image = C.ICONS[g.rarity] or C.ICONS.common, from = it.from })
		end
	end
	if totals.gold == 0 then hold("gold", false) end
	if totals.gems == 0 then hold("gems", false) end
	local first = {}
	for i, f in flights do
		flyOne(f.image, f.from, f.kind, (i - 1) * (if single then 0.06 else 0.035), function()
			if first[f.kind] then
				Sound.play(if f.kind == "gold" then "click" else "gem", 1.05)
				return
			end
			first[f.kind] = true
			if f.kind ~= "shard" then hold(f.kind, false) end -- the wallet starts counting as the first one lands
			local target = hudTarget(f.kind)
			local n = totals[f.kind]
			landFx(if target then centreOf(target) else fallbackTarget(f.kind),
				if f.kind == "shard" then "+" .. n .. " shard" .. (if n == 1 then "" else "s") else "+" .. commas(n))
			Sound.play(if f.kind == "gold" then "reward" else "gem", if f.kind == "shard" then 0.8 else nil)
		end)
	end
end

---------------------------------------------------------------- the prize popup
local pendingPrize = nil

-- one spin: the prize in the middle of the screen
local function openPrize(res)
	local g = res.gave and res.gave[1]
	if not g then
		releaseAll()
		return
	end
	pendingPrize = res
	local text, img = describe(g)
	local rev = prize.Reveal
	for _, n in { "Icon", "IconShadow" } do rev[n].Image = img end
	setText(rev, "ItemName", text)
	UI.open("Prize", { keepHistory = UI.isOpen("Spin") })
	local rays = rev:FindFirstChild("Rays")
	if rays then UI.spin(rays, 18) end
	UI.popFrom(rev.Icon, 0.4, 0.1)
	UI.popFrom(rev.IconShadow, 0.4, 0.1)
	Sound.play(if g.kind == "weapon" or C.SLOTS[res.slots[1]].weight <= 6 then "reveal" else "reward")
end

-- x5 / x10: that many wheels, all spinning at once, each landing on its own roll (res.slots[i] paid res.gave[i])
local minis = {}
local multiRes = nil

local function openMulti(res)
	for _, m in minis do m.frame:Destroy() end
	table.clear(minis)
	multiRes = res
	local n = #res.slots
	local cols = math.min(n, 5)
	local rows = math.ceil(n / cols)
	local k = if rows > 1 then 0.5 else 0.6 -- each wheel is 540 x 620 before this
	local W, H, GAP = 540 * k, 620 * k, 22
	local box = multi.Wheels
	local x0 = (box.Size.X.Offset - (cols * W + (cols - 1) * GAP)) / 2
	local y0 = (box.Size.Y.Offset - (rows * H + (rows - 1) * GAP)) / 2
	local nameSrc, nameSh = prize.Reveal.ItemName, prize.Reveal.ItemNameShadow
	for i, slot in res.slots do
		local col, row = (i - 1) % cols, (i - 1) // cols
		local f = Instance.new("Frame")
		f.Name = "Wheel" .. i
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromOffset(540, 620)
		f.Position = UDim2.fromOffset(x0 + col * (W + GAP), y0 + row * (H + GAP))
		f.ZIndex = 2
		local sc = Instance.new("UIScale")
		sc.Scale = k
		sc.Parent = f
		local v = miniTemplate.vf:Clone()
		v.Position = UDim2.fromOffset(0, 0)
		v.CurrentCamera = v:FindFirstChildOfClass("Camera")
		v.Parent = f
		local sl = miniTemplate.slots:Clone()
		sl.Position = UDim2.fromOffset(0, 0)
		sl.Parent = f
		-- the prize under the wheel, shown when it lands
		local labels = {}
		for j, src in { nameSh, nameSrc } do
			local t = src:Clone()
			t.Text = ""
			t.AnchorPoint = Vector2.new(0.5, 0)
			t.Position = UDim2.fromOffset(270, 548 + (if j == 1 then 5 else 0))
			t.Size = UDim2.fromOffset(600, 72)
			t.TextSize = 60
			t.ZIndex = 5 + j
			t.Parent = f
			labels[j] = t
		end
		f.Parent = box
		local model = v:FindFirstChild("Wheel")
		placeSlotsIn(v, sl, 0)
		table.insert(minis, {
			frame = f, vf = v, slots = sl, model = model, rest = model:GetPivot(), labels = labels,
			target = targetFor(0, slot), dur = C.SPIN_TIME * (0.8 + 0.4 * math.random()), landed = false,
		})
	end
	setText(multi, "Title", "SPIN x" .. n .. "!")
	multi.BtnCollect.Visible = false
	UI.open("Multi", { keepHistory = UI.isOpen("Spin") })
	-- all together; each settles in its own time
	local t0 = os.clock()
	local lastSector = 0
	while multiRes == res do
		local left = 0
		local now = os.clock()
		for i, m in minis do
			if not m.landed then
				local u = math.min(1, (now - t0) / m.dur)
				local a = m.target * ease(u)
				turn(m.model, m.rest, ui.centre, ui.axis, a)
				placeSlotsIn(m.vf, m.slots, a)
				if i == 1 then
					local sector = math.floor(a / STEP + 0.5)
					if sector ~= lastSector then
						lastSector = sector
						Sound.play("click", 0.9 + 0.3 * (1 - u))
					end
				end
				if u >= 1 then
					m.landed = true
					local text = describe(res.gave[i])
					for _, t in m.labels do t.Text = text end
					UI.popFrom(m.labels[2], 0.3)
					UI.popFrom(m.labels[1], 0.3)
					Sound.play("pop", 1 + i * 0.03)
				else
					left += 1
				end
			end
		end
		if left == 0 then break end
		RunService.RenderStepped:Wait()
	end
	if multiRes == res then
		multi.BtnCollect.Visible = true
		UI.popFrom(multi.BtnCollect, 0.4)
		Sound.play("reward")
	end
end

-- COLLECT! (or Escape / a tap on the shade): close the popup and send the prizes home
local function collect(closeIt: boolean)
	local items = {}
	local scr = nil
	if pendingPrize then
		local icon = prize.Reveal.Icon
		local from = if icon.AbsoluteSize.X > 2 then centreOf(icon) else flyLayer.AbsoluteSize / 2
		table.insert(items, { g = pendingPrize.gave[1], from = from })
		pendingPrize, scr = nil, "Prize"
	elseif multiRes then
		for i, m in minis do
			table.insert(items, { g = multiRes.gave[i], from = if m.vf.AbsoluteSize.X > 2 then centreOf(m.vf) else flyLayer.AbsoluteSize / 2 })
		end
		multiRes, scr = nil, "Multi"
	else
		return
	end
	if closeIt and UI.isOpen(scr) then UI.close() end
	sendHome(items)
end

---------------------------------------------------------------- spinning
local function spin(count: number)
	if spinning or not state then return end
	if have() < count then
		if have() < 1 then
			UIC.toast("No spins left. Next free spin in " .. clock((state.freeAt or 0) - serverNow()) .. ", or get more below.", "info", true)
		else
			UIC.toast("You need " .. count .. " spins for that. You have " .. have() .. ".", "info", true)
		end
		for _, n in { "BtnBuy1", "BtnBuy10", "BtnBuy100" } do
			local b = panel:FindFirstChild(n)
			if b then UI.pulse(b, 0.1) end
		end
		return
	end
	spinning = true
	refresh()
	-- the wallet holds from now: the server pays before the wheel has even started
	hold("gold", true)
	hold("gems", true)
	local ok, res = pcall(function()
		return remotes:WaitForChild("Spin"):InvokeServer(count)
	end)
	if not ok or type(res) ~= "table" or not res.ok then
		hold("gold", false)
		hold("gems", false)
		spinning = false
		if type(res) == "table" and res.state then state = res.state end
		refresh()
		local why = type(res) == "table" and res.reason
		UIC.toast(if why == "busy" then "The wheel is still turning!" elseif why == "match" then "Spin in the lobby between matches." elseif why == "no_spins" then "No spins left." else "Couldn't spin right now. Try again in a moment.", "info", true)
		return
	end
	if res.state then
		state = res.state
		clockOffset = (tonumber(res.state.serverNow) or os.time()) - os.time()
	end
	refresh()
	if player:GetAttribute("EOS_InMatch") == true then -- no wheels in a match: the prizes just go home
		spinning = false
		local items = {}
		for _, g in res.gave do table.insert(items, { g = g, from = flyLayer.AbsoluteSize / 2 }) end
		sendHome(items)
		return
	end
	if count > 1 then
		openMulti(res)
		spinning = false
		refresh()
		return
	end
	-- one spin: the screen's wheel turns to it (the lobby's turns from Spun)
	local a0 = ui.angle
	local a1 = targetFor(a0, res.slots[1])
	local t0 = os.clock()
	local lastSector = math.floor(a0 / STEP + 0.5)
	while true do
		local u = math.min(1, (os.clock() - t0) / C.SPIN_TIME)
		local a = a0 + (a1 - a0) * ease(u)
		setUiAngle(a)
		local sector = math.floor(a / STEP + 0.5)
		if sector ~= lastSector and gui.Enabled and UI.isOpen("Spin") then
			lastSector = sector
			Sound.play("click", 0.9 + 0.3 * (1 - u))
		end
		if u >= 1 then break end
		RunService.RenderStepped:Wait()
	end
	ui.angle %= TAU
	spinning = false
	refresh()
	task.wait(0.35) -- a beat on the winning slot
	openPrize(res)
end

local function buy(spins: number)
	for _, pack in C.PACKS do
		if pack.spins == spins then
			if pack.productId then
				MarketplaceService:PromptProductPurchase(player, pack.productId)
			else
				UIC.toast("Spin packs aren't on sale yet.", "info", true)
			end
			return
		end
	end
end

---------------------------------------------------------------- walk-up
local PHONE_H, PHONE_SCALE = 500, 1.3
local function sizeCard()
	local card = screen:FindFirstChild("SpinCard")
	if not card then return end
	local cam = workspace.CurrentCamera
	local k = if cam and cam.ViewportSize.Y < PHONE_H then PHONE_SCALE else 1
	local sc = card:FindFirstChild("PopScale")
	if not sc then
		sc = Instance.new("UIScale")
		sc.Name = "PopScale"
		sc.Parent = card
	end
	sc:SetAttribute("Base", k)
	sc.Scale = k
end

local openedByWalk, armed = false, true

local function spot(): Vector3?
	local sw = workspace:FindFirstChild("SpinWheel")
	if not sw then return nil end
	return sw:GetPivot():PointToWorldSpace(Vector3.new(0, 0, 8))
end

local function canOpen(): boolean
	if player:GetAttribute("EOS_InMatch") == true or player:GetAttribute("EOS_Loaded") ~= true then return false end
	if not LobbyGate.active() then return false end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	if UIC.isOpen() or UI.current() ~= nil then return false end
	if UIC.spectating and UIC.spectating() then return false end
	return true
end

local function tickWalk()
	local p = spot()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local d = math.huge
	if p and root then d = Vector3.new(root.Position.X - p.X, 0, root.Position.Z - p.Z).Magnitude end
	local open = UI.isOpen("Spin")
	if open and (player:GetAttribute("EOS_InMatch") == true or (openedByWalk and d > CLOSE_AT)) then
		UI.close()
		openedByWalk = false
		return
	end
	if d > CLOSE_AT then armed = true end
	if not open and armed and d < OPEN_AT and canOpen() then
		armed = false
		openedByWalk = true
		sizeCard()
		refresh()
		UI.open("Spin")
		Sound.play("open")
	end
end

---------------------------------------------------------------- init
function SpinWheelController.init(uiController)
	UIC = uiController
	remotes = ReplicatedStorage:WaitForChild("EOS_SpinWheel")
	gui = player:WaitForChild("PlayerGui"):WaitForChild("SpinWheelUI")
	gui.DisplayOrder = 8 -- above EOSUI, like the other lobby cards
	gui.Enabled = true
	UI = require(gui:WaitForChild("UI"))
	UI.init(gui)
	local root = gui:WaitForChild("Root")
	screen = root:WaitForChild("Spin")
	panel = screen:WaitForChild("SpinCard"):WaitForChild("Panel")
	vf = panel:WaitForChild("WheelView")
	slotsFrame = panel:WaitForChild("Slots")
	prize = root:WaitForChild("Prize")
	multi = root:WaitForChild("Multi")
	miniTemplate = { vf = vf:Clone(), slots = slotsFrame:Clone() } -- before anything turns it
	flyLayer = gui:WaitForChild("Fly")
	task.spawn(hookWallet)
	ui.model = vf:WaitForChild("Wheel")
	ui.rest = ui.model:GetPivot()
	ui.centre = vf:GetAttribute("Centre")
	ui.axis = vf:GetAttribute("Axis")
	setUiAngle(0)
	setOdds(false)

	UI.Action:Connect(function(name: string, scr: string, b: Instance?)
		if scr ~= "Spin" then return end
		if name == "BtnSpin" then task.spawn(spin, 1)
		elseif name == "BtnSpin5" then task.spawn(spin, 5)
		elseif name == "BtnSpin10" then task.spawn(spin, 10)
		elseif name == "BtnOdds" then setOdds(not oddsMode)
		elseif name:match("^BtnBuy") and b then buy(b:GetAttribute("Spins"))
		elseif name == "CloseButton" then openedByWalk = false end
	end)
	UI.Action:Connect(function(name: string, scr: string)
		if scr ~= "Prize" and scr ~= "Multi" then return end
		if name == "BtnCollect" then collect(true)
		elseif name == "CloseButton" then collect(false) end -- Escape / the scrim: the UI module closes it
	end)
	for _, scr in { prize, multi } do
		scr:WaitForChild("Dim").InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			-- the x5 / x10 wheels finish before a tap on the shade collects
			if scr == multi and not multi.BtnCollect.Visible then return end
			collect(true)
		end)
	end

	remotes:WaitForChild("State").OnClientEvent:Connect(function(v)
		if type(v) ~= "table" then return end
		state = v
		clockOffset = (tonumber(v.serverNow) or os.time()) - os.time()
		if not spinning then refresh() end
	end)
	remotes:WaitForChild("Spun").OnClientEvent:Connect(function(_userId, slot)
		if type(slot) == "number" and C.SLOTS[slot] then task.spawn(spinWorld, slot) end
	end)
	remotes:WaitForChild("Ask"):FireServer()

	workspace.ChildAdded:Connect(function(c)
		if c.Name == "SpinWheel" then task.defer(bindWorld) end
	end)
	bindWorld()

	task.spawn(function()
		while gui.Parent do
			local ok, err = pcall(tickWalk)
			if not ok then warn("[SpinWheel] walk-up: " .. tostring(err)) end
			if not spinning then pcall(refresh) end
			-- never leave the wallet held (a lost reply, a popup left open for minutes)
			if (held.gold > 0 or held.gems > 0) and not spinning and os.clock() - heldSince > (if pendingPrize or multiRes then 120 else 15) then
				releaseAll()
			end
			task.wait(0.25)
		end
	end)
end

return SpinWheelController
