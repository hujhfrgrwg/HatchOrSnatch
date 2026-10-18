--!nocheck
-- SpinWheelController (HOS-SPIN-001, 18 Oct 2026, Matthew): the lobby spin wheel on the client.
--  * walk up to the wheel (Workspace.SpinWheel) and the spin screen opens (SpinWheelUI, built by
--    tools/build/HOS-SPIN-001/build_ui.lua); walk away and it closes. Closed with X, it waits until you've left.
--  * SPIN! / SPIN x5 / SPIN x10 ask the server (EOS_SpinWheel.Spin), which rolls and pays; the screen's wheel then
--    turns to the result (the best one of a multi-spin) and the prize pops over the hub
--  * the big wheel in the lobby turns for everyone near it when anyone spins (Spun); far away it just jumps
--  * the sign over the crystal shows the free spin timer
--  * spin packs prompt their developer product (SpinWheelConfig.PACKS; not on sale until they have a productId)
-- Wheel angles are radians, counter-clockwise as you face the wheel; slot k is at the top when the angle is
-- (k - 1) * 45 degrees (mod a full turn). The wheel spins clockwise.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local C = require(Shared:WaitForChild("SpinWheelConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local LobbyGate = require(script.Parent:WaitForChild("LobbyGate"))
local Sound = require(script.Parent:WaitForChild("Sound"))

local player = Players.LocalPlayer
local SpinWheelController = {}

local UIC, UI
local gui, screen, panel, vf, slotsFrame, result
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

local function placeSlots(a: number)
	local size = vf.Size.X.Offset
	local pps = (size / 2) / vf:GetAttribute("HalfStuds")
	local cx, cy = size / 2, size / 2 + vf:GetAttribute("LiftStuds") * pps
	for _, f in slotsFrame:GetChildren() do
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
	placeSlots(a)
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

local function summary(gave): string
	local gold, gems, shards, weapons = 0, 0, 0, 0
	for _, g in gave do
		if g.kind == "gold" then gold += g.amount
		elseif g.kind == "gems" then gems += g.amount
		elseif g.kind == "shard" then shards += 1
		elseif g.kind == "weapon" then weapons += 1 end
	end
	local parts = {}
	if weapons > 0 then table.insert(parts, weapons .. " weapon" .. (if weapons == 1 then "" else "s")) end
	if gold > 0 then table.insert(parts, "+" .. commas(gold) .. " Gold") end
	if gems > 0 then table.insert(parts, "+" .. commas(gems) .. " Gems") end
	if shards > 0 then table.insert(parts, shards .. " egg shard" .. (if shards == 1 then "" else "s")) end
	return table.concat(parts, ", ")
end

local function showResult(res)
	-- the tile shows the prize the wheel stopped on (the first roll of that slot)
	local g = res.gave and res.gave[table.find(res.slots, res.best) or 1]
	if not g then return end
	local text, img = describe(g)
	for _, d in result:GetDescendants() do
		if d:IsA("ImageLabel") and (d.Name == "Icon" or d.Name == "IconShadow") then d.Image = img end
	end
	setText(result, "LabelText", text)
	setText(result, "ResultSub", if #res.slots > 1 then "x" .. #res.slots .. ": " .. summary(res.gave) else "")
	result.Visible = true
	UI.popFrom(result, 0.3)
	Sound.play(if g.kind == "weapon" or C.SLOTS[res.best].weight <= 6 then "reveal" else "reward")
	UIC.toast(if #res.slots > 1 then "Spin x" .. #res.slots .. ": " .. summary(res.gave) else "You won " .. text:gsub("^%+", "") .. "!", "reward", true)
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
	result.Visible = false
	refresh()
	local ok, res = pcall(function()
		return remotes:WaitForChild("Spin"):InvokeServer(count)
	end)
	if not ok or type(res) ~= "table" or not res.ok then
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
	-- the screen's wheel turns to the result (the lobby's turns from Spun)
	local a0 = ui.angle
	local a1 = targetFor(a0, res.best)
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
	showResult(res)
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
		result.Visible = false
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
	result = panel:WaitForChild("Result")
	result.Visible = false
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
			task.wait(0.25)
		end
	end)
end

return SpinWheelController
