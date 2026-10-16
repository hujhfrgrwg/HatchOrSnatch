-- SpectateController (HOS-SPECTATE-001, 16 Oct): watch the match from the lobby (Huss Valley's spectate).
-- The SPECTATE pill (HUD.Watch) shows while a match runs and you're not in it. The Spectate bar:
--   < >      the previous / next player in the match (real players first, then NPC Runners)
--   FOLLOW   the camera follows that player (Roblox's camera: right-drag orbits, scroll zooms)
--   FREE CAM fly around the field: WASD, Q / E down / up, right-drag to look, Shift for speed
--   EXIT     back to your character (also when the match ends or you're put into one)
-- Your character stands still while you watch (anchored in the lobby, Space doesn't dash).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("Net"))
local UI = require(script.Parent.UIController)

local SpectateController = {}

local player = Players.LocalPlayer
local state = Net.state()
local screen: Frame? = nil
local active = false
local mode = "follow"
local targetModel: Model? = nil
local freeCF = CFrame.new()
local yaw, pitch = 0, 0
local LIVE = { ROLE_REVEAL = true, CROSSING = true, WAVE_END = true }
local ROLE_WORD = { RUNNER = "Runner", CATCHER = "Catcher", CAUGHT = "Caught", SAFE = "Safe" }

local function find(scope: Instance?, name: string): Instance?
	return scope and scope:FindFirstChild(name, true)
end
local function setText(scope: Instance?, name: string, text: string)
	local t = find(scope, name)
	if t and (t:IsA("TextLabel") or t:IsA("TextButton")) then t.Text = text end
end
local function show(g: Instance?, on: boolean)
	if g and g:IsA("GuiObject") then g.Visible = on end
end

function SpectateController.matchLive(): boolean
	return LIVE[state:GetAttribute("Phase") or ""] == true
end

-- everyone in the match you can watch: real players first, then NPC Runners
function SpectateController.targets(): { Model }
	local out = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and plr:GetAttribute("EOS_InMatch") == true and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
			table.insert(out, plr.Character)
		end
	end
	local rt = workspace:FindFirstChild("EOS_Runtime")
	local npcs = rt and rt:FindFirstChild("Npcs")
	if npcs then
		local list = {}
		for _, m in ipairs(npcs:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("EOS_InMatch") == true and m:FindFirstChildOfClass("Humanoid") then
				table.insert(list, m)
			end
		end
		table.sort(list, function(a, b) return (a:GetAttribute("EOS_NpcSlot") or 0) < (b:GetAttribute("EOS_NpcSlot") or 0) end)
		for _, m in ipairs(list) do table.insert(out, m) end
	end
	return out
end

local function nameOf(m: Model): string
	local plr = Players:GetPlayerFromCharacter(m)
	if plr then return plr.DisplayName end
	-- NPCs: the name their overhead tag shows on this client (a friend's name live, "Runner 4" in Studio)
	local head = m:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("EOS_Tag")
	local label = tag and tag:FindFirstChild("NameLabel", true)
	if label and label:IsA("TextLabel") and label.Text ~= "" then return label.Text end
	local hum = m:FindFirstChildOfClass("Humanoid")
	return if hum and hum.DisplayName ~= "" then hum.DisplayName else "Runner"
end

local function infoOf(m: Model): string
	local plr = Players:GetPlayerFromCharacter(m)
	local src: any = plr or m
	local role = ROLE_WORD[src:GetAttribute("EOS_Role") or ""] or "In the match"
	local tier = src:GetAttribute("EOS_Tier")
	if type(tier) == "number" and (src:GetAttribute("EOS_Role") == "RUNNER" or src:GetAttribute("EOS_Role") == "SAFE") then
		return ("%s  ·  Level %d egg"):format(role, tier)
	end
	return role
end

-- your character waits in the lobby: its root is anchored while you watch (the game has no PlayerModule
-- to switch off; Movement drives the humanoid), and Space / jump are sunk so nothing dashes
local anchored: BasePart? = nil
local function controls(on: boolean)
	if on then
		if anchored and anchored.Parent then anchored.Anchored = false end
		anchored = nil
		ContextActionService:UnbindAction("EOS_SpectateSink")
	else
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and not root.Anchored then
			root.Anchored = true
			anchored = root
		end
		ContextActionService:BindActionAtPriority("EOS_SpectateSink", function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	end
end

local function refreshBar()
	if not screen then return end
	local bar = screen:FindFirstChild("Bar")
	for _, pair in ipairs({ { "TabFollow", "follow" }, { "TabFree", "free" } }) do
		local b = find(bar, pair[1])
		show(b and b:FindFirstChild("On"), mode == pair[2])
		show(b and b:FindFirstChild("Off"), mode ~= pair[2])
	end
	local list = SpectateController.targets()
	show(find(bar, "BtnPrev"), mode == "follow" and #list > 1)
	show(find(bar, "BtnNext"), mode == "follow" and #list > 1)
	if mode == "follow" and targetModel then
		setText(bar, "TargetName", nameOf(targetModel))
		setText(bar, "TargetInfo", infoOf(targetModel))
	elseif mode == "free" then
		setText(bar, "TargetName", "Explore the field")
		setText(bar, "TargetInfo", "Free cam  ·  WASD to fly")
	else
		setText(bar, "TargetName", "Waiting for players")
		setText(bar, "TargetInfo", "Nobody in the match yet")
	end
	setText(screen, "HintText", if mode == "follow"
		then "Right-drag: orbit  ·  Scroll: zoom  ·  < >: next player"
		else "WASD: fly  ·  Q / E: down / up  ·  Right-drag: look  ·  Shift: fast")
end

local function follow(m: Model?)
	targetModel = m
	local cam = workspace.CurrentCamera
	local hum = m and m:FindFirstChildOfClass("Humanoid")
	if cam and hum then
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = hum
	end
	refreshBar()
end

local function step(dir: number)
	local list = SpectateController.targets()
	if #list == 0 then return follow(nil) end
	local i = table.find(list, targetModel :: any) or 0
	i = ((i - 1 + dir) % #list) + 1
	follow(list[i])
end

local function setMode(m: string)
	mode = m
	local cam = workspace.CurrentCamera
	if m == "free" and cam then
		freeCF = cam.CFrame
		local look = freeCF.LookVector
		yaw = math.atan2(-look.X, -look.Z)
		pitch = math.asin(math.clamp(look.Y, -1, 1))
		cam.CameraType = Enum.CameraType.Scriptable
	else
		if not targetModel or not targetModel.Parent then
			targetModel = SpectateController.targets()[1]
		end
		follow(targetModel)
	end
	refreshBar()
end

function SpectateController.start()
	if active then return end
	if player:GetAttribute("EOS_InMatch") == true then return end
	local list = SpectateController.targets()
	if #list == 0 then
		return UI.toast("Nobody to watch yet: wait for the match to start", "info")
	end
	active = true
	UI.close()
	controls(false)
	local hud = screen and screen.Parent and screen.Parent:FindFirstChild("HUD")
	show(hud, false)
	show(screen, true)
	mode = "follow"
	follow(list[1])
	SpectateController.onChanged(true)
end

function SpectateController.stop()
	if not active then return end
	active = false
	mode = "follow"
	targetModel = nil
	local cam = workspace.CurrentCamera
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		if hum then cam.CameraSubject = hum end
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	controls(true)
	show(screen, false)
	local hud = screen and screen.Parent and screen.Parent:FindFirstChild("HUD")
	if hud and player:GetAttribute("EOS_InMatch") ~= true then show(hud, true) end
	SpectateController.onChanged(false)
end

function SpectateController.isActive(): boolean
	return active
end

-- UIController hides / shows its HUD around this
SpectateController.onChanged = function(_on: boolean) end

local function freeStep(dt: number)
	local cam = workspace.CurrentCamera
	if not cam then return end
	if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
	local rmb = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	UserInputService.MouseBehavior = if rmb then Enum.MouseBehavior.LockCurrentPosition else Enum.MouseBehavior.Default
	if rmb then
		local d = UserInputService:GetMouseDelta()
		yaw -= d.X * 0.004
		pitch = math.clamp(pitch - d.Y * 0.004, -1.4, 1.4)
	end
	local k = UserInputService
	local move = Vector3.zero
	if not k:GetFocusedTextBox() then
		if k:IsKeyDown(Enum.KeyCode.W) then move += Vector3.new(0, 0, -1) end
		if k:IsKeyDown(Enum.KeyCode.S) then move += Vector3.new(0, 0, 1) end
		if k:IsKeyDown(Enum.KeyCode.A) then move += Vector3.new(-1, 0, 0) end
		if k:IsKeyDown(Enum.KeyCode.D) then move += Vector3.new(1, 0, 0) end
		if k:IsKeyDown(Enum.KeyCode.E) then move += Vector3.new(0, 1, 0) end
		if k:IsKeyDown(Enum.KeyCode.Q) then move += Vector3.new(0, -1, 0) end
	end
	-- gamepad: left stick flies, right stick looks
	for _, inp in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
		if inp.KeyCode == Enum.KeyCode.Thumbstick1 and inp.Position.Magnitude > 0.15 then
			move += Vector3.new(inp.Position.X, 0, -inp.Position.Y)
		elseif inp.KeyCode == Enum.KeyCode.Thumbstick2 and inp.Position.Magnitude > 0.15 then
			yaw -= inp.Position.X * dt * 2.5
			pitch = math.clamp(pitch + inp.Position.Y * dt * 2.5, -1.4, 1.4)
		end
	end
	local speed = if k:IsKeyDown(Enum.KeyCode.LeftShift) then 90 else 35
	local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local pos = freeCF.Position + rot:VectorToWorldSpace(move) * speed * dt
	freeCF = CFrame.new(pos) * rot
	cam.CFrame = freeCF
end

function SpectateController.init()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("EOSUI", 30)
	local root = gui and gui:WaitForChild("Root", 10)
	screen = root and root:FindFirstChild("Spectate") :: Frame?
	show(screen, false)
	local bar = screen and screen:FindFirstChild("Bar")
	local function btn(name: string, fn: () -> ())
		local b = find(bar, name)
		if b and b:IsA("GuiButton") then UI.juicy(b, fn) end
	end
	btn("BtnPrev", function() step(-1) end)
	btn("BtnNext", function() step(1) end)
	btn("TabFollow", function() setMode("follow") end)
	btn("TabFree", function() setMode("free") end)
	btn("BtnExit", SpectateController.stop)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not active or processed then return end
		if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.ButtonL1 then step(-1)
		elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.ButtonR1 then step(1)
		elseif input.KeyCode == Enum.KeyCode.F then setMode(if mode == "free" then "follow" else "free")
		elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then SpectateController.stop() end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		if not active then return end
		if mode == "free" then
			freeStep(dt)
		end
		acc += dt
		if acc < 0.25 then return end
		acc = 0
		-- the match ended, or you were put into it
		if player:GetAttribute("EOS_InMatch") == true or not SpectateController.matchLive() then
			SpectateController.stop()
			return
		end
		if mode == "follow" then
			local still = targetModel and targetModel.Parent and targetModel:GetAttribute("EOS_InMatch") ~= false
			local plr = targetModel and Players:GetPlayerFromCharacter(targetModel)
			if plr and plr:GetAttribute("EOS_InMatch") ~= true then still = false end
			if not still then step(1) else refreshBar() end
		end
	end)
	player.CharacterAdded:Connect(function()
		if active then SpectateController.stop() end
	end)
end

return SpectateController
