-- CameraFX: readable chase camera on top of Roblox's default camera.
--  * in a match, over-the-shoulder: the camera sits a little right of and above the character
--    (camera-space offset, so it doesn't swing when a Runner turns). The lobby keeps Roblox's free camera.
--  * PC in a match: the mouse is locked to the centre and turns the camera (shift-lock style,
--    without forcing the body to face the camera; Movement decides facing). The arrow is hidden and
--    a tiny square marks the centre instead. Free in the lobby, and whenever a menu or the results
--    screen is open.
--  * zoom range clamped so opponents stay readable on phones; starts close (DEFAULT_ZOOM)
--  * gentle FOV kick with speed (off with "Reduce effects")
--  * a tiny decaying shake on big moments (off with "Reduce effects"); never drifts (offset resets)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local Movement = require(script.Parent.Movement)

local CameraFX = {}
CameraFX.reduceEffects = false
-- set by the UI: true while a menu / results screen needs the mouse
CameraFX.lockBlocked = function(): boolean
	return false
end
local mouseLocked = false
local shoulder = 0 -- 0 = lobby free camera, 1 = full over-the-shoulder (in a match)
local LOCK_PHASES = { ROLE_REVEAL = true, CROSSING = true, WAVE_END = true }

local shakeT, shakeMag = 0, 0
local fov = GameConfig.Camera.BASE_FOV

function CameraFX.shake(magnitude: number, duration: number?)
	if CameraFX.reduceEffects then
		return
	end
	shakeMag = math.max(shakeMag, magnitude)
	shakeT = math.max(shakeT, duration or 0.25)
end

-- Point the camera behind the character toward a world position (role reveal, wave start).
function CameraFX.lookToward(target: Vector3)
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = workspace.CurrentCamera
	if not hrp or not cam then
		return
	end
	local flat = Vector3.new(target.X - hrp.Position.X, 0, target.Z - hrp.Position.Z)
	if flat.Magnitude < 1 then
		return
	end
	local dir = flat.Unit
	local eye = hrp.Position - dir * 14 + Vector3.new(0, 6, 0)
	cam.CFrame = CFrame.lookAt(eye, hrp.Position + dir * 10 + Vector3.new(0, 2, 0))
end

local function wantsMouseLock(player: Player): boolean
	if not GameConfig.Camera.LOCK_MOUSE_IN_MATCH or not UserInputService.MouseEnabled then
		return false
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return false
	end
	if player:GetAttribute("EOS_InMatch") ~= true then
		return false
	end
	if player:GetAttribute("EOS_Sandbox") == true then
		return not CameraFX.lockBlocked() -- Studio knife test baseplate: always the match camera
	end
	local state = ReplicatedStorage:FindFirstChild("EOS_State")
	if not state or not LOCK_PHASES[state:GetAttribute("Phase") or ""] then
		return false
	end
	return not CameraFX.lockBlocked()
end

-- start each life zoomed in close (players can still zoom out to MAX_ZOOM)
-- the tiny centre square shown instead of the mouse arrow while the mouse is locked
local DOT_SIZE = 3
local dotGui: ScreenGui? = nil
local function ensureDot(player: Player): ScreenGui?
	if dotGui and dotGui.Parent then
		return dotGui
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "EOS_Crosshair"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- (0.5, 0.5) = the exact point LockCenter holds the mouse at
	gui.DisplayOrder = 6 -- above the HUD, below menus (menus free the mouse anyway)
	gui.Enabled = false
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.4
	stroke.Thickness = 1
	stroke.Parent = dot
	dot.Parent = gui
	gui.Parent = playerGui
	dotGui = gui
	return gui
end

local function setLocked(player: Player, locked: boolean)
	UserInputService.MouseBehavior = if locked then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = not locked
	local gui = ensureDot(player)
	if gui then
		gui.Enabled = locked
	end
	mouseLocked = locked
end

local function snapZoom(player: Player)
	local C = GameConfig.Camera
	player.CameraMaxZoomDistance = C.DEFAULT_ZOOM
	task.delay(0.25, function()
		player.CameraMaxZoomDistance = C.MAX_ZOOM
	end)
end

function CameraFX.init()
	local player = Players.LocalPlayer
	player.CameraMinZoomDistance = GameConfig.Camera.MIN_ZOOM
	player.CameraMaxZoomDistance = GameConfig.Camera.MAX_ZOOM
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		snapZoom(player)
	end)
	if player.Character then
		snapZoom(player)
	end
	RunService:BindToRenderStep("EOS_CameraFX", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local C = GameConfig.Camera
		-- mouse lock (PC, in a match)
		local lock = wantsMouseLock(player)
		if lock then
			setLocked(player, true) -- every frame: Roblox's camera scripts can reset the behaviour
		elseif mouseLocked then
			setLocked(player, false)
		end
		-- over the shoulder in a match; Roblox's free camera in the lobby (eased in/out)
		local want = if player:GetAttribute("EOS_InMatch") == true then 1 else 0
		shoulder += (want - shoulder) * (1 - math.exp(-dt * 3 / math.max(C.SHOULDER_BLEND_TIME, 0.05)))
		if cam.CameraType == Enum.CameraType.Custom and shoulder > 0.001 then
			cam.CFrame *= CFrame.new(C.SHOULDER_OFFSET * shoulder)
		end
		local target = C.BASE_FOV + (if CameraFX.reduceEffects then 0 else C.SPEED_FOV_BONUS * Movement.speedFraction)
		fov += (target - fov) * math.clamp(dt * 6, 0, 1)
		cam.FieldOfView = fov
		if shakeT > 0 then
			shakeT -= dt
			local k = shakeMag * math.max(shakeT, 0) * 4
			cam.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * k), math.rad((math.random() - 0.5) * k), 0)
			if shakeT <= 0 then
				shakeMag = 0
			end
		end
	end)
end

return CameraFX
