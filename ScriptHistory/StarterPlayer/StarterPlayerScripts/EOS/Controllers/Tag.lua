-- Tag: Catcher input. Two hint paths, both validated by the server:
--  * contact: touching a vulnerable Runner (client sees it first; server re-checks distance+LOS)
--  * swing: the TAG action (click, E, gamepad R2/X, or the on-screen TAG button) plays the full-body
--    lunge stab (GameConfig.Stab), but the hit is decided ON THE CLICK from where everyone is then,
--    exactly like the old jab: it reaches a bit farther than contact (from the body's centre, never
--    from the knife) and has a short cooldown. It goes where the camera aims: the Runner nearest the
--    crosshair's direction (within GameConfig.Capture.SWING_CONE), and the aim direction goes to the
--    server so everyone sees the arm and knife strike that way (CharacterAnim). The server holds the
--    caught Runner's fall until the knife lands (Stab.STRIKE_TIME).
-- The server also runs its own contact scan, so tagging never depends on this script.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Layout = require(Shared:WaitForChild("Layout"))
local Net = require(Shared:WaitForChild("Net"))
local Sound = require(script.Parent.Sound)
local Movement = require(script.Parent.Movement)

local C = GameConfig.Capture
local LG = GameConfig.Lunge
local Tag = {}
Tag.lastSwing = -math.huge
Tag.isUIOpen = function()
	return false
end
Tag.onSwing = nil :: (() -> ())? -- a stab started (the click)
Tag.onDecoy = nil :: (() -> ())? -- a swing went through a Decoy pet's copy
Tag.lastStrike = nil :: { at: number, target: number? }? -- test hook: the last hit (decided on the click)
local swingListeners: { () -> () } = {}
-- extra listeners for every stab, called on the click (the character's lunge animation)
function Tag.addSwingListener(fn: () -> ())
	table.insert(swingListeners, fn)
end

local player = Players.LocalPlayer
local requestTag = Net.event("RequestTag")

local function myRoot(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isCatcher(): boolean
	return player:GetAttribute("EOS_InMatch") == true and player:GetAttribute("EOS_Role") == "CATCHER"
end

local function inZone(pos: Vector3): boolean
	return Layout.inBox(pos, Layout.Zones.A) or Layout.inBox(pos, Layout.Zones.B)
end

-- every Runner in the match, players and NPCs: { uid, root }
local function runners(): { { uid: number, root: BasePart } }
	local out = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other:GetAttribute("EOS_InMatch") and other:GetAttribute("EOS_Role") == "RUNNER" and not other:GetAttribute("EOS_Safe") then
			local c = other.Character
			local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				table.insert(out, { uid = other.UserId, root = hrp })
			end
		end
	end
	local runtime = workspace:FindFirstChild("EOS_Runtime")
	local npcs = runtime and runtime:FindFirstChild("Npcs")
	if npcs then
		for _, m in ipairs(npcs:GetChildren()) do
			if m:GetAttribute("EOS_InMatch") and m:GetAttribute("EOS_Role") == "RUNNER" and not m:GetAttribute("EOS_Safe") then
				local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart?
				local uid = m:GetAttribute("EOS_UserId")
				if hrp and type(uid) == "number" then
					table.insert(out, { uid = uid, root = hrp })
				end
			end
		end
	end
	return out
end

-- nearest vulnerable Runner within `reach` (flat distance): its user id (NPCs have negative ids)
local function nearestRunner(reach: number): (number?, number)
	local root = myRoot()
	if not root then
		return nil, math.huge
	end
	local best, bestD = nil, math.huge
	for _, r in ipairs(runners()) do
		local pos = r.root.Position
		if not inZone(pos) then
			local d = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z).Magnitude
			if d < bestD and math.abs(pos.Y - root.Position.Y) <= C.MAX_VERTICAL_GAP then
				best, bestD = r.uid, d
			end
		end
	end
	if bestD <= reach then
		return best, bestD
	end
	return nil, bestD
end

-- ===== aim: hits go where the camera looks =====

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude
aimParams.IgnoreWater = true

-- the world point under the crosshair (the screen centre, where the mouse is locked)
function Tag.aimPoint(): Vector3?
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local origin, look = cam.CFrame.Position, cam.CFrame.LookVector
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	for _ = 1, 4 do
		aimParams.FilterDescendantsInstances = exclude
		local hit = workspace:Raycast(origin, look * C.AIM_RANGE, aimParams)
		if not hit then
			break
		end
		-- see-through walls and zone volumes don't stop the aim
		if hit.Instance.Transparency < 0.9 then
			return hit.Position
		end
		table.insert(exclude, hit.Instance)
	end
	return origin + look * C.AIM_RANGE
end

-- direction from `from` (a shoulder, say) to the crosshair point
function Tag.aimFrom(from: Vector3): Vector3?
	local p = Tag.aimPoint()
	local cam = workspace.CurrentCamera
	if not p or not cam then
		return nil
	end
	local d = p - from
	if d.Magnitude < 2 then
		return cam.CFrame.LookVector -- aiming right at yourself: just use the camera's direction
	end
	return d.Unit
end

-- the Runner in reach that best matches where the camera points: smallest angle first, distance
-- second. Runners behind you (outside the cone) can't be hit by a swing; body contact still works.
local function aimedRunner(reach: number): number?
	local root = myRoot()
	local cam = workspace.CurrentCamera
	if not root or not cam then
		return nil
	end
	local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	if look.Magnitude < 0.05 then
		look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	look = look.Unit
	local best, bestScore = nil, math.huge
	for _, r in ipairs(runners()) do
		local pos = r.root.Position
		local off = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
		local d = off.Magnitude
		if d <= reach and not inZone(pos) and math.abs(pos.Y - root.Position.Y) <= C.MAX_VERTICAL_GAP then
			local angle = if d < 0.5 then 0 else math.acos(math.clamp(off.Unit:Dot(look), -1, 1))
			if angle <= C.SWING_CONE then
				local score = angle / C.SWING_CONE + 0.5 * d / reach
				if score < bestScore then
					best, bestScore = r.uid, score
				end
			end
		end
	end
	return best
end

-- ===== the lunge (Space as a Catcher, GameConfig.Lunge) =====
-- Movement does the burst; the hit is decided when the knife lands (STRIKE_TIME), from where everyone
-- is then: the Runner in reach nearest the crosshair's direction. The server slows us after the burst.
Tag.lastLunge = -math.huge
local lungeListeners: { () -> () } = {}
function Tag.addLungeListener(fn: () -> ())
	table.insert(lungeListeners, fn)
end

-- 0 = just used, 1 = ready
function Tag.lungeCharge(): number
	local left = Tag.lastLunge + LG.COOLDOWN - os.clock()
	return if left <= 0 then 1 else 1 - left / LG.COOLDOWN
end

function Tag.lunge()
	if not LG.ENABLED or not isCatcher() or Tag.isUIOpen() then
		return
	end
	local now = os.clock()
	if now - Tag.lastLunge < LG.COOLDOWN then
		return
	end
	local ok, dir = Movement.startLunge()
	if not ok then
		return -- held on the line (or can't move): no lunge, no cooldown spent
	end
	Tag.lastLunge = now
	Net.event("RequestLunge"):FireServer(dir)
	for _, fn in ipairs(lungeListeners) do
		task.spawn(fn)
	end
	Sound.play("swing", 0.8)
	task.delay(LG.STRIKE_TIME, function()
		if Tag.lastLunge ~= now or not isCatcher() then
			return
		end
		local target = aimedRunner(LG.REACH + 0.5)
		local root = myRoot()
		Tag.lastStrike = { at = os.clock(), target = target }
		if not target and root and Tag.onDecoy then
			local rt = workspace:FindFirstChild("EOS_Runtime")
			local decoys = rt and rt:FindFirstChild("Decoys")
			for _, d in ipairs(if decoys then decoys:GetChildren() else {}) do
				local dr = d:FindFirstChild("HumanoidRootPart") :: BasePart?
				if dr and (dr.Position - root.Position).Magnitude <= LG.REACH + 1 then
					Tag.onDecoy()
					break
				end
			end
		end
		local aim = root and Tag.aimFrom(root.Position + Vector3.new(0, 1, 0))
		requestTag:FireServer(target, "lunge", aim)
		Sound.play("swing", 0.9 + math.random() * 0.1)
	end)
end

function Tag.swing()
	if not isCatcher() then
		return
	end
	local now = os.clock()
	if now - Tag.lastSwing < C.TAG_COOLDOWN then
		return
	end
	if now - Tag.lastLunge < LG.BURST_TIME + LG.RECOVER_TIME + 0.25 then
		return -- mid-lunge: the jab would cut the lunge's stab off
	end
	Tag.lastSwing = now
	-- the hit is decided now, from where everyone is on the click (the old jab's rule): the lunge in
	-- the clip is looks only, so it never reaches any farther
	local target = aimedRunner(C.TAG_RADIUS + 0.5)
	local root = myRoot()
	Tag.lastStrike = { at = now, target = target }
	if not target and root and Tag.onDecoy then
		-- swung at a Decoy copy: say so (it can't be tagged)
		local rt = workspace:FindFirstChild("EOS_Runtime")
		local decoys = rt and rt:FindFirstChild("Decoys")
		for _, d in ipairs(if decoys then decoys:GetChildren() else {}) do
			local dr = d:FindFirstChild("HumanoidRootPart") :: BasePart?
			if dr and (dr.Position - root.Position).Magnitude <= C.TAG_RADIUS + 1 then
				Tag.onDecoy()
				break
			end
		end
	end
	local aim = root and Tag.aimFrom(root.Position + Vector3.new(0, 1, 0))
	requestTag:FireServer(target, "swing", aim)
	if Tag.onSwing then
		Tag.onSwing()
	end
	for _, fn in ipairs(swingListeners) do
		task.spawn(fn)
	end
	-- the whoosh goes with the thrust
	task.delay(0.07, function()
		if Tag.lastSwing == now then
			Sound.play("swing", 0.95 + math.random() * 0.1)
		end
	end)
end

function Tag.init()
	Movement.onCatcherSpace = Tag.lunge
	ContextActionService:BindAction("EOS_Tag", function(_, state)
		if state == Enum.UserInputState.Begin then
			Tag.swing()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonX)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or Tag.isUIOpen() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Tag.swing()
		end
	end)
	-- contact hints, throttled
	local acc = 0
	local lastSent: { [number]: number } = {}
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		if not isCatcher() then
			return
		end
		local target = nearestRunner(C.CONTACT_RADIUS)
		if target then
			local t = os.clock()
			if not lastSent[target] or t - lastSent[target] > 0.25 then
				lastSent[target] = t
				requestTag:FireServer(target, "contact")
			end
		end
	end)
end

return Tag
