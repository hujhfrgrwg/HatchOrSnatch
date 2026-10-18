--!nocheck
-- EggShardIntro (HOS-EGG-002, 17 Oct ~20:30, Hunter approved the storyboard): ~3 s at the start of a match, inside the
-- existing 5 s ROLE_REVEAL (the match flow is untouched; the camera is back before CROSSING):
--   0.0 - 0.8  FLOAT    a Common egg rises over the Runners; the comfort Cinematic camera eases up to it (slow, no shake)
--   0.8 - 1.4  CRACK    it shakes and bursts softly (VFX.EggBurst: AllVFX glitter + ring; no flash), a crack sound
--   1.4 - 2.4  SCATTER  copies of the back shard arc out, one to each Runner
--   2.4 - 3.0  LAND     each Runner's own back shard (EggShardBack, server-built) appears as its copy lands
-- Reduce effects: no camera move, no flying copies (the shards are simply there). Another cut-scene playing: no camera.
-- Off with EggConfig.SHARD_INTRO_ENABLED = false. Client only; started by one line in EggUIController.init.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EggConfig = require(Shared:WaitForChild("EggConfig"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local Intro = {}

local T_FLOAT, T_CRACK, T_SCATTER, T_LAND = 0.8, 1.4, 2.4, 3.0

local function soft(name: string)
	local ok, m = pcall(function() return require(script.Parent:WaitForChild(name, 2)) end)
	return if ok then m else nil
end

local function reduceEffects(): boolean
	local CameraFX = soft("CameraFX")
	return CameraFX ~= nil and CameraFX.reduceEffects == true
end

-- every Runner in the match: players (attributes on the Player) and NPC bodies (attributes on the model)
local function runners(): { Model }
	local out = {}
	for _, plr in Players:GetPlayers() do
		if plr:GetAttribute("EOS_InMatch") and plr:GetAttribute("EOS_Role") == "RUNNER" and plr.Character then
			table.insert(out, plr.Character)
		end
	end
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("EOS_InMatch") and m:GetAttribute("EOS_Role") == "RUNNER" and m:FindFirstChildOfClass("Humanoid") then
			table.insert(out, m)
		end
	end
	return out
end

local function torsoOf(m: Model): BasePart?
	local t = m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
	return if t and t:IsA("BasePart") then t else nil
end

local function shardOf(m: Model): BasePart?
	local egg = m:FindFirstChild("EOS_Egg")
	local s = egg and egg:FindFirstChild("EOS_Shard")
	return if s and s:IsA("BasePart") then s else nil
end

local function setHidden(part: BasePart?, hidden: boolean)
	if part then part.LocalTransparencyModifier = if hidden then 1 else 0 end
end

local function burst(at: Vector3)
	local VFXm = ReplicatedStorage:FindFirstChild("VFX")
	local tpl = VFXm and VFXm:FindFirstChild("EggBurst")
	local att = tpl and tpl:FindFirstChild("EggBurst", true)
	local ok, Emit = pcall(function() return require(VFXm:WaitForChild("Emit")) end)
	if not (att and ok) then return end
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.new(at)
	p.Parent = workspace
	local a = att:Clone()
	a.Parent = p
	pcall(Emit.emit, a)
	task.delay(3, function() p:Destroy() end)
end

local function eggModel(at: Vector3): Model?
	local ok, EggModel = pcall(function() return require(Shared:WaitForChild("EggModel")) end)
	if not ok then return nil end
	local m = EggModel.build(1, false, 2.2) -- the Common egg (showcase build: anchored)
	m:PivotTo(CFrame.new(at))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false end
	end
	m.Parent = workspace
	return m
end

local function shardCopy(): BasePart?
	local kit = ReplicatedStorage:FindFirstChild("EggShardKit")
	local tpl = kit and kit:FindFirstChild("Shard")
	if not tpl then return nil end
	local s = tpl:Clone()
	local sa = kit:FindFirstChild("SA_common")
	if sa then sa:Clone().Parent = s end
	s.Anchored, s.CanCollide, s.CanQuery, s.CanTouch = true, false, false, false
	s.Parent = workspace
	return s
end

local playing = false

function Intro.play()
	if playing or not EggConfig.SHARD_INTRO_ENABLED or not EggConfig.ENABLED then return end
	if not player:GetAttribute("EOS_InMatch") then return end
	playing = true
	task.wait(0.35) -- the server builds every Runner's egg + shard as roles land
	local list = runners()
	if #list == 0 then playing = false return end
	local reduce = reduceEffects()
	-- the shards are simply there with Reduce effects
	if reduce then playing = false return end
	local centre, n = Vector3.zero, 0
	for _, m in list do
		local t = torsoOf(m)
		if t then centre += t.Position n += 1 end
	end
	if n == 0 then playing = false return end
	centre /= n
	local cam = workspace.CurrentCamera
	local fwd = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	fwd = if fwd.Magnitude > 0.01 then fwd.Unit else Vector3.new(0, 0, -1)
	local eggAt = centre + fwd * 8 + Vector3.new(0, 7, 0)
	-- hide every Runner's back shard until its copy lands
	local hidden = {}
	for _, m in list do
		local s = shardOf(m)
		if s then setHidden(s, true) table.insert(hidden, s) end
	end
	-- the camera: one slow eased shot through the shared comfort module, unless a cut-scene is already playing
	local Cinematic = soft("Cinematic")
	if Cinematic and not Cinematic.isPlaying() then
		local from = cam.CFrame
		local pos = from.Position - fwd * 1.5 + Vector3.new(0, 1, 0)
		pcall(Cinematic.play, {
			shots = { {
				duration = T_LAND,
				cframe = function(alpha)
					local look = if alpha < 0.45 then eggAt else eggAt:Lerp(centre, math.clamp((alpha - 0.45) / 0.55, 0, 1))
					return CFrame.lookAt(from.Position:Lerp(pos, math.min(1, alpha * 2)), look)
				end,
			} },
			letterbox = true, dim = false, hideHud = false, outro = 0.3, maxSeconds = 3.4,
		})
	end
	local egg = eggModel(eggAt - Vector3.new(0, 2, 0))
	local Sound = soft("Sound")
	local copies = {}
	local t0 = os.clock()
	local cracked, scattered = false, false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if egg and egg.Parent and t < T_CRACK then
			local rise = math.min(1, t / T_FLOAT)
			local shake = if t > T_FLOAT then math.sin(t * 60) * math.rad(8) * ((t - T_FLOAT) / (T_CRACK - T_FLOAT)) else 0
			egg:PivotTo(CFrame.new(eggAt - Vector3.new(0, 2 * (1 - rise * rise * (3 - 2 * rise)), 0)) * CFrame.Angles(0, t * 1.5, shake))
		end
		if t >= T_CRACK - 0.05 and not cracked then
			cracked = true
			if Sound then pcall(Sound.play, "crack") end
			burst(eggAt)
			if egg then egg:Destroy() egg = nil end
		end
		if t >= T_CRACK and not scattered then
			scattered = true
			for i, m in list do
				local s = shardCopy()
				if s then copies[i] = { part = s, target = m } end
			end
		end
		if scattered then
			local a = math.clamp((t - T_CRACK) / (T_SCATTER - T_CRACK), 0, 1)
			local e = a * a * (3 - 2 * a)
			for i, c in copies do
				local tgt = torsoOf(c.target)
				local back = shardOf(c.target)
				if c.part.Parent and tgt then
					local to = (back or tgt).Position
					local mid = (eggAt + to) / 2 + Vector3.new(0, 4, 0)
					local p = eggAt:Lerp(mid, e):Lerp(mid:Lerp(to, e), e) -- a quadratic arc
					c.part.CFrame = CFrame.new(p) * CFrame.Angles(t * 3, t * 2 + i, 0)
					if a >= 1 and not c.landed then
						c.landed = true
						c.part:Destroy()
						setHidden(back, false)
					end
				end
			end
		end
		if t >= T_LAND then
			conn:Disconnect()
			for _, c in copies do if c.part.Parent then c.part:Destroy() end end
			for _, s in hidden do setHidden(s, false) end
			if egg then egg:Destroy() end
			playing = false
		end
	end)
	task.delay(T_LAND + 1, function() -- failsafe: never leave a back shard hidden
		if conn.Connected then conn:Disconnect() end
		for _, c in copies do if c.part.Parent then c.part:Destroy() end end
		for _, s in hidden do setHidden(s, false) end
		if egg then egg:Destroy() end
		playing = false
	end)
end

function Intro.init()
	local state = Net.state()
	local function check()
		if state:GetAttribute("Phase") == "ROLE_REVEAL" then task.spawn(Intro.play) end
	end
	state:GetAttributeChangedSignal("Phase"):Connect(check)
end

return Intro
