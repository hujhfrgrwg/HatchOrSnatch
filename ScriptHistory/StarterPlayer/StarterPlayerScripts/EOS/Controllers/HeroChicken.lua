-- HeroChicken (HOS-HOC-001, 17 Oct): the client side of the Hero or Chicken pick.
-- Reads ReplicatedStorage.EOS_HeroChicken (HeroChickenService) and plays the cinematic for everyone:
--   CHOOSING  a: LEAD CATCHER shot (countdown over their head) -> white flash + low rush across the field
--             to the Runner line -> slow low dolly along the Runners (everyone) / pick view (the lead
--             Catcher: tap or click a Runner, gamepad left/right + A). A spotlight + highlight follows
--             the Runner the Catcher is aiming at, on every screen. Drumroll.
--   PICKED    b: spotlight locks gold, flash, push-in to an over-the-shoulder close shot; name card +
--             HERO OR CHICKEN?; the picked Runner gets the two big buttons. Heartbeat.
--   REVEAL    c: HERO = gold flash, sting, confetti + rays; CHICKEN = dim / desaturated, feathers, flaps.
--             Then the swoop back to the gameplay camera, letterbox out, HUD back.
--   READY     "<name> is going HERO" + 3-2-1.     HERO_RUN  HERO ATTEMPT banner + HERO tag over the Hero.
--   HERO_SUCCESS  low close shot of the Hero in the safe zone, angled HERO! banner, +points, confetti, cheer,
--             quick fade to black, back to the game.    GROUP_READY  "The group goes next" + countdown.
-- Camera / letterbox / HUD fade go through Controllers.Cinematic when it is in the place; until then a
-- small built-in stand-in does the same (camera Scriptable, bars, HUD guis hidden, always restored).
-- The overlay is StarterGui.HeroChickenUI (built from UI/hero-chicken, roblox-ui-maker); numbers live in
-- Shared.HeroChickenConfig.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local HC = require(Shared:WaitForChild("HeroChickenConfig"))
local TM = HC.Timing
local LK = HC.Look

local player = Players.LocalPlayer
local Controllers = script.Parent

local HeroChicken = {}

-- real recordings only (Roblox's licensed library: Pro Sound Effects + APM / production music)
local SOUNDS = {
	drumroll = { id = 1842251033, volume = 0.45, looped = true }, -- Snare Drum Roll (KPM via APM)
	heartbeat = { id = 1842342421, volume = 0.7, looped = true }, -- Heartbeat (a) (KPM via APM)
	whoosh = { id = 9120711172, volume = 0.6 }, -- Whoosh Fast Swish By 7 (PSE)
	lock = { id = 9119882039, volume = 0.8 }, -- Synth Whomps 38: the spotlight locks (PSE)
	hero = { id = 9047100306, volume = 0.6 }, -- Hustler Sting 2 (Score Production Music)
	chicken = { id = 9113444703, volume = 0.8, length = 1.8 }, -- Bird Wing Flaps Pigeon Two Squeaks 1 (PSE)
	cheer = { id = 9112766176, volume = 0.55, start = 1.5, length = 3.6 }, -- Crowd Cheer And Applause 1 (PSE)
	tick = { id = 9113089565, volume = 0.25, length = 0.12 }, -- Alarm Tone 2-Tone, a short blip (PSE)
}

local state: Configuration
local gui: ScreenGui
local root: Frame
local K: any -- the gui's UIKit
local NpcSkins: any = nil
local GameSound: any = nil -- Controllers.Sound: the Settings sound toggle + music ducking

-- ===== small helpers =====

local function now(): number
	return workspace:GetServerTimeNow()
end

local function charOf(uid: number?): Model?
	if not uid then
		return nil
	end
	local plr = Players:GetPlayerByUserId(uid)
	if plr then
		return plr.Character
	end
	local rt = workspace:FindFirstChild("EOS_Runtime")
	local npcs = rt and rt:FindFirstChild("Npcs")
	if npcs then
		for _, m in ipairs(npcs:GetChildren()) do
			if m:GetAttribute("EOS_UserId") == uid then
				return m :: Model
			end
		end
	end
	return nil
end

local function rootOf(uid: number?): BasePart?
	local c = charOf(uid)
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function nameOf(uid: number?): string
	if not uid then
		return "?"
	end
	local plr = Players:GetPlayerByUserId(uid)
	if plr then
		return plr.DisplayName
	end
	local c = charOf(uid)
	local slot = c and c:GetAttribute("EOS_NpcSlot")
	if NpcSkins and slot and NpcSkins.nameForSlot then
		local ok, n = pcall(NpcSkins.nameForSlot, slot)
		if ok and type(n) == "string" and n ~= "" then
			return n
		end
	end
	return "Runner " .. tostring(slot or "")
end

local function find(name: string): any
	return K.find(root, name)
end

local function set(name: string, text: string)
	K.set(find(name), text)
end

local function setIn(box: string, name: string, text: string)
	K.set(K.find(find(box), name), text)
end

local function show(name: string, on: boolean)
	local g = find(name)
	if g then
		g.Visible = on
	end
end

local function lineup(): { number }
	local s = state:GetAttribute("Lineup")
	if type(s) ~= "string" then
		return {}
	end
	local ok, t = pcall(function()
		return game:GetService("HttpService"):JSONDecode(s)
	end)
	return if ok and type(t) == "table" then t else {}
end

local sounds: { [string]: Sound } = {}
local function sfx(key: string): Sound?
	local d = SOUNDS[key]
	if not d then
		return nil
	end
	if GameSound and GameSound.enabled == false then
		return nil
	end
	local s = sounds[key]
	if not s then
		s = Instance.new("Sound")
		s.Name = "HC_" .. key
		s.SoundId = "rbxassetid://" .. d.id
		s.Volume = d.volume
		s.Looped = d.looped == true
		s.SoundGroup = SoundService:FindFirstChild("EOS_SFX") :: SoundGroup?
		s.Parent = SoundService
		sounds[key] = s
	end
	s.PlaybackSpeed = 1
	s.TimePosition = d.start or 0
	s:Play()
	if d.length then
		local token = os.clock()
		s:SetAttribute("Token", token)
		task.delay(d.length, function()
			if s:GetAttribute("Token") == token then
				s:Stop()
			end
		end)
	end
	return s
end

local function stopSfx(key: string)
	local s = sounds[key]
	if s then
		s:Stop()
	end
end

-- ===== camera + letterbox (shared Cinematic module, or the stand-in) =====

type Shot = { from: any, to: any, fov0: number, fov1: number, t: number, ease: string? }

local Cine: any = nil -- Controllers.Cinematic when present
local cineHandle: any = nil

-- stand-in: bars + HUD hide + a Scriptable camera driven per frame
local standIn = { active = false, shots = {} :: { Shot }, shotAt = 0, hidden = {} :: { ScreenGui } }
local barHome: { [GuiObject]: UDim2 } = {}

local function resolve(v: any): CFrame
	if typeof(v) == "function" then
		local ok, r = pcall(v)
		if ok and typeof(r) == "CFrame" then
			return r
		end
		return workspace.CurrentCamera.CFrame
	end
	return v
end

local function easeOut(a: number): number
	return 1 - (1 - a) ^ 3
end

local function inOut(a: number): number
	return if a < 0.5 then 4 * a ^ 3 else 1 - (-2 * a + 2) ^ 3 / 2
end

local function standInLetterbox(on: boolean)
	-- the exported Letterbox group (UI/hero-chicken): bars slide in from the top and bottom edges
	local box = find("LetterboxBox") :: GuiObject?
	if box then
		if on and not standIn.active then
			box.Visible = true
		end
		for _, n in ipairs({ "BarTop", "BarBottom" }) do
			local b = find(n) :: GuiObject?
			if b then
				local home = barHome[b] or b.Position
				barHome[b] = home
				local away = home + UDim2.fromOffset(0, if n == "BarTop" then -140 else 140)
				if on and not standIn.active then
					b.Position = away
				end
				local tw = TweenService:Create(b, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Position = if on then home else away })
				tw:Play()
				if not on then
					tw.Completed:Once(function()
						if not standIn.active then
							box.Visible = false
						end
					end)
				end
			end
		end
	end
	if on and not standIn.active then
		standIn.hidden = {}
		for _, g in ipairs(player.PlayerGui:GetChildren()) do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled and (g.Name:match("^EOS") or g.Name == "EOSUI") then
				g.Enabled = false
				table.insert(standIn.hidden, g)
			end
		end
	elseif not on then
		for _, g in ipairs(standIn.hidden) do
			g.Enabled = true
		end
		standIn.hidden = {}
	end
	standIn.active = on
end

local camActive = false
local function cameraOff()
	camActive = false
	standIn.shots = {}
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
	end
end

local function easeAlpha(name: string?, a: number): number
	if name == "linear" then
		return a
	elseif name == "out" then
		return easeOut(a)
	elseif name == "Sine" then
		return 0.5 - 0.5 * math.cos(math.pi * a)
	end
	return inOut(a)
end

-- play one camera move (replaces whatever runs; the letterbox stays up) and hold its last frame for `hold`
-- seconds. Move + hold are ONE Cinematic shot (a second shot would be a cut, and Cinematic dips on cuts).
-- The FOV squeeze runs linearly over the whole shot, so it stays far under COMFORT's 12 deg/s.
local function shot(s: Shot, maxSeconds: number?, hold: number?, afterLook: Vector3?)
	local h = hold or 1
	local total = s.t + h
	-- the path is framed ONCE (on the shot's first frame, after the bodies have settled from the lineup
	-- teleport) and never tracks a body afterwards: a body that jumps can never drag the camera with it
	local fromCf: CFrame?, toCf: CFrame?
	local function cframeAt(t: number): CFrame
		if not fromCf then
			fromCf, toCf = resolve(s.from), resolve(s.to)
		end
		local a = math.clamp(t / math.max(s.t, 0.01), 0, 1)
		return (fromCf :: CFrame):Lerp(toCf :: CFrame, easeAlpha(s.ease, a))
	end
	local one = { duration = total, cframe = function(_alpha: number, t: number)
		return cframeAt(t)
	end, fov = { s.fov0, s.fov1 }, ease = "linear" }
	local cap = maxSeconds or (total + 0.5)
	if Cine and Cine.play then
		local ok, handle = pcall(Cine.play, { shots = { one }, keepGuis = { gui }, maxSeconds = cap, afterLook = afterLook })
		if ok and handle then
			cineHandle = handle
			return
		end
		warn("[HeroChicken] Cinematic.play failed, using the stand-in: " .. tostring(handle))
	end
	standInLetterbox(true)
	standIn.shots = { { from = s.from, to = s.to, fov0 = s.fov0, fov1 = s.fov1, t = s.t, ease = s.ease, total = total } }
	standIn.shotAt = os.clock()
	camActive = true
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
end

local function endCinematic()
	local had = cineHandle ~= nil or standIn.active or camActive
	if cineHandle then
		local h = cineHandle
		cineHandle = nil
		pcall(function()
			if h.stop then
				h:stop()
			elseif Cine.stop then
				Cine.stop()
			end
		end)
	end
	if standIn.active or camActive then
		standInLetterbox(false)
		cameraOff()
	end
	-- held Runners were turned by the lineup: put the follow camera behind them, facing the field
	if not had then
		return
	end
	task.defer(function()
		local cam = workspace.CurrentCamera
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if cam and r and cam.CameraType == Enum.CameraType.Custom then
			cam.CFrame = CFrame.lookAt(r.Position - r.CFrame.LookVector * 13 + Vector3.new(0, 5.5, 0), r.Position + Vector3.new(0, 2, 0))
		end
	end)
end

RunService:BindToRenderStep("HC_Camera", Enum.RenderPriority.Camera.Value + 1, function()
	if not camActive then
		return
	end
	local s = standIn.shots[1]
	if not s then
		return
	end
	local t = os.clock() - standIn.shotAt
	local a = math.clamp(t / math.max(s.t, 0.01), 0, 1)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = resolve(s.from):Lerp(resolve(s.to), easeAlpha(s.ease, a))
	cam.FieldOfView = s.fov0 + (s.fov1 - s.fov0) * math.clamp(t / math.max(s.total or s.t, 0.01), 0, 1)
end)

-- ===== shot builders (all functions: they follow the bodies every frame) =====

local function headOf(uid: number?): Vector3
	local r = rootOf(uid)
	return if r then r.Position + Vector3.new(0, 1.6, 0) else Vector3.zero
end

local function lineInfo(): (Vector3, Vector3, number, Vector3)
	-- centre of the Runner row, the row's direction, its length, and "toward the field"
	local ids = lineup()
	local a, b = rootOf(ids[1]), rootOf(ids[#ids])
	if not a or not b then
		local r = rootOf(ids[1]) or rootOf(state:GetAttribute("Catcher"))
		local p = if r then r.Position else Vector3.zero
		return p, Vector3.new(0, 0, 1), 10, Vector3.new(1, 0, 0)
	end
	local dir = b.Position - a.Position
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local along = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, 1)
	local look = a.CFrame.LookVector
	local field = Vector3.new(look.X, 0, look.Z)
	field = if field.Magnitude > 0.1 then field.Unit else Vector3.new(1, 0, 0)
	return (a.Position + b.Position) / 2, along, flat.Magnitude, field
end

-- Comfort (Hunter 17 Oct, GameConfig.Cinematic.COMFORT): FOV 70 fixed, people at least 12 studs away
-- (full body / knees-up), eased moves under 4 studs/s and 20 deg/s, 0.2 s black dips between shots.
-- line of sight: a shot's camera never sits behind a wall or a building (maps differ: the snow map's cabins
-- blocked the lead Catcher). From the subject, the wanted direction is tried first, then other angles around
-- them; if nothing is clear at `dist`, the camera pulls in to just before the first hit. Characters and
-- invisible parts (gates, catcher walls) don't block.
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
local function blockedAt(from: Vector3, to: Vector3): number?
	local ex: { Instance } = { workspace.CurrentCamera }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	local rt = workspace:FindFirstChild("EOS_Runtime")
	if rt then
		table.insert(ex, rt)
	end
	for _ = 1, 8 do
		losParams.FilterDescendantsInstances = ex
		local hit = workspace:Raycast(from, to - from, losParams)
		if not hit then
			return nil
		end
		if hit.Instance.Transparency < 0.95 then
			return (hit.Position - from).Magnitude
		end
		table.insert(ex, hit.Instance)
	end
	return nil
end

local ANGLES = { 0, 35, -35, 70, -70, 110, -110, 180 }
-- a clear direction from `subject` (flat), checked at `dist` studs and `lift` studs up
local function clearDir(subject: Vector3, baseDir: Vector3, dist: number, lift: number): (Vector3, number)
	local flat = Vector3.new(baseDir.X, 0, baseDir.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, 1)
	local best, bestDist = flat, 0
	for _, a in ipairs(ANGLES) do
		local d = CFrame.Angles(0, math.rad(a), 0):VectorToWorldSpace(flat)
		local hitAt = blockedAt(subject, subject + d * dist + Vector3.new(0, lift, 0))
		if not hitAt then
			return d, dist
		end
		if hitAt > bestDist then
			best, bestDist = d, hitAt
		end
	end
	return best, math.max(4, bestDist - 1.5)
end

local function leadShot(uid: number, dist: number): () -> CFrame
	return function()
		local r = rootOf(uid)
		if not r then
			return workspace.CurrentCamera.CFrame
		end
		-- the direction is chosen at the push's far end, so both ends of the push share it
		local dir, maxD = clearDir(r.Position + Vector3.new(0, LK.DOLLY_HEIGHT, 0), r.CFrame.LookVector, LK.PUSH.from, 0)
		local camPos = r.Position + dir * math.min(dist, maxD) + dir:Cross(Vector3.yAxis) * -2 + Vector3.new(0, LK.DOLLY_HEIGHT, 0)
		return CFrame.lookAt(camPos, r.Position + Vector3.new(0, LK.DOLLY_HEIGHT, 0))
	end
end

local function lineFront(): () -> CFrame
	return function()
		local c, _, len, field = lineInfo()
		local fovR = math.rad(LK.FOV / 2)
		local dist = math.clamp((len / 2 + 6) / math.tan(fovR) * 0.62, 16, 70)
		return CFrame.lookAt(c + field * dist + Vector3.new(0, 7, 0), c + Vector3.new(0, 2, 0))
	end
end

local function dollyAt(u: number): CFrame
	local c, along, len, field = lineInfo()
	local p = c + along * ((u - 0.5) * (len + 6))
	-- chest height, 12 studs in front of the row, looking straight at it (no turning while it slides)
	return CFrame.lookAt(p + field * LK.DOLLY_DISTANCE + Vector3.new(0, LK.DOLLY_HEIGHT, 0), p - along * 2 + Vector3.new(0, LK.DOLLY_HEIGHT, 0))
end

-- the slice of the row the dolly covers in `seconds` at MOVE_SPEED (centred on the row)
local function dollyRange(seconds: number): (number, number)
	local _, _, len = lineInfo()
	local span = math.clamp(LK.MOVE_SPEED * seconds * 0.6 / math.max(len + 6, 1), 0, 1) -- sine in-out peaks at ~1.57x the average
	return 0.5 - span / 2, 0.5 + span / 2
end

local function closeShot(uid: number, dist: number, side: number?): () -> CFrame
	return function()
		local r = rootOf(uid)
		if not r then
			return workspace.CurrentCamera.CFrame
		end
		local dir, maxD = clearDir(r.Position + Vector3.new(0, LK.DOLLY_HEIGHT, 0), r.CFrame.LookVector, math.max(dist, LK.PUSH.from), 0)
		local camPos = r.Position + dir * math.min(dist, maxD) + dir:Cross(Vector3.yAxis) * -(side or 2) + Vector3.new(0, LK.DOLLY_HEIGHT, 0)
		return CFrame.lookAt(camPos, r.Position + Vector3.new(0, 0.8, 0))
	end
end

local function lowHero(uid: number, dist: number): () -> CFrame
	-- the Hero in the safe zone, seen from the field side (never from the zone's back wall), a little
	-- below eye level looking up at them
	return function()
		local r = rootOf(uid)
		if not r then
			return workspace.CurrentCamera.CFrame
		end
		local ok, Layout = pcall(require, Shared:WaitForChild("Layout"))
		local centre = if ok and Layout.Arena then Layout.Arena.CENTER else r.Position + r.CFrame.LookVector * 20
		local toField = Vector3.new(centre.X - r.Position.X, 0, centre.Z - r.Position.Z)
		toField = if toField.Magnitude > 0.1 then toField.Unit else r.CFrame.LookVector
		local dir, maxD = clearDir(r.Position + Vector3.new(0, 0.2, 0), toField, math.max(dist, LK.PUSH.from), 0)
		local side = dir:Cross(Vector3.yAxis)
		local camPos = r.Position + dir * math.min(dist, maxD) + side * 2 + Vector3.new(0, 0.2, 0)
		return CFrame.lookAt(camPos, r.Position + Vector3.new(0, 1.6, 0)) -- a little below, looking up
	end
end

-- a point ahead of your own character (toward the field): the camera turns to it once it is given back
lookAhead = function(): Vector3?
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if r then r.Position + r.CFrame.LookVector * 30 else nil
end

local function gameplayCam(): CFrame
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not r then
		return workspace.CurrentCamera.CFrame
	end
	local look = r.CFrame.LookVector
	return CFrame.lookAt(r.Position - look * 13 + Vector3.new(0, 5.5, 0), r.Position + Vector3.new(0, 2, 0))
end

-- ===== screen flash / grade =====

local flash: Frame -- the exported Flash group's FlashFill

-- a 0.2 s dip through black between shots (comfort: no fast moves, no white / gold flashes)
local function dip(during: () -> ())
	local half = LK.DIP / 2
	flash.BackgroundColor3 = Color3.new(0, 0, 0)
	flash.BackgroundTransparency = 1
	flash.Visible = true
	local t = TweenService:Create(flash, TweenInfo.new(half, Enum.EasingStyle.Sine), { BackgroundTransparency = 0 })
	t:Play()
	t.Completed:Wait()
	pcall(during)
	TweenService:Create(flash, TweenInfo.new(half, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
end

local grade: ColorCorrectionEffect
local function setGrade(sat: number, bright: number, t: number)
	TweenService:Create(grade, TweenInfo.new(t), { Saturation = sat, Brightness = bright }):Play()
end

-- ===== spotlight (everyone sees it hop) =====

local spot: any = { target = nil, pos = nil, locked = false }

local function buildSpot()
	-- the spotlight is the VFX template ReplicatedStorage.VFX.HeroChicken.HC_Spotlight (roblox-vfx skill),
	-- cloned once per client; it follows the aimed Runner and is recoloured when the pick locks
	local tpl = ReplicatedStorage:WaitForChild("VFX"):WaitForChild("HeroChicken"):WaitForChild("HC_Spotlight", 10)
	if not tpl then
		warn("[HeroChicken] no HC_Spotlight template")
		return
	end
	local m = tpl:Clone()
	m.Parent = workspace.CurrentCamera
	local top = m:WaitForChild("Top") :: BasePart
	spot.model = m
	spot.part = top
	spot.floor = m:WaitForChild("Floor")
	spot.shade = m:WaitForChild("FloorShade")
	spot.beam = top:WaitForChild("Cone")
	spot.light = top:WaitForChild("Light")
	spot.ring = spot.floor:WaitForChild("Ring")
	spot.ringShade = spot.shade:WaitForChild("RingShade")
	local hl = Instance.new("Highlight") -- a Highlight has no template form; it only adorns the aimed body
	hl.FillTransparency = 0.78
	hl.OutlineTransparency = 0.1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Enabled = false
	hl.Parent = m
	spot.hl = hl
	spot.beam.Enabled = false
	spot.light.Enabled = false
	spot.ring.Transparency = 1
	spot.ringShade.Transparency = 1
end

local function spotOn(uid: number?, locked: boolean?)
	if not spot.beam then
		return
	end
	spot.target = uid
	spot.locked = locked == true
	local on = uid ~= nil
	spot.beam.Enabled = on
	spot.light.Enabled = on
	spot.ring.Transparency = if on then 0.15 else 1
	spot.ringShade.Transparency = if on then 0.45 else 1
	local col = if locked then LK.HERO_GOLD else LK.SPOT_COLOR
	spot.beam.Color = ColorSequence.new(col)
	spot.light.Color = col
	spot.light.Brightness = if locked then 8 else 5
	spot.ring.Color3 = col
	spot.hl.FillColor, spot.hl.OutlineColor = col, col
	spot.hl.Enabled = on
	spot.hl.Adornee = charOf(uid)
	if not on then
		spot.pos = nil
	end
end

RunService.RenderStepped:Connect(function(dt)
	if not spot.part or not spot.target or not spot.beam then
		return
	end
	local r = rootOf(spot.target)
	if not r then
		return
	end
	local feet = r.Position - Vector3.new(0, 2.9, 0)
	-- the light hops fast between Runners, then settles
	spot.pos = if spot.pos then spot.pos:Lerp(feet, math.clamp(dt * 14, 0, 1)) else feet
	local p = spot.pos :: Vector3
	spot.part.CFrame = CFrame.new(p + Vector3.new(0, 26, 0))
	spot.floor.CFrame = CFrame.new(p + Vector3.new(0, 0.06, 0))
	spot.shade.CFrame = CFrame.new(p + Vector3.new(0, 0.03, 0))
	if spot.hl.Adornee ~= r.Parent then
		spot.hl.Adornee = r.Parent
	end
end)

-- ===== particles =====

-- effects are templates in ReplicatedStorage.VFX.HeroChicken (roblox-vfx skill), played with the game's
-- Emit module: HC_HeroBurst (gold rays + ring with dark twins, glitter, confetti), HC_SuccessBurst (the same
-- with a second confetti wave), HC_ChickenFeathers (feathers + a puff)
local VFXEmit: any = nil
local function playFx(name: string, pos: Vector3)
	local folder = ReplicatedStorage:FindFirstChild("VFX")
	local set = folder and folder:FindFirstChild("HeroChicken")
	local tpl = set and set:FindFirstChild(name)
	if not (tpl and VFXEmit) then
		return
	end
	local ok, err = pcall(VFXEmit.play, tpl, CFrame.new(pos))
	if not ok then
		warn("[HeroChicken] " .. name .. ": " .. tostring(err))
	end
end

local function goldBurst(pos: Vector3, success: boolean?)
	playFx(if success then "HC_SuccessBurst" else "HC_HeroBurst", pos)
end

local function feathers(pos: Vector3)
	playFx("HC_ChickenFeathers", pos)
end

-- ===== overlay =====

local GROUP_BOXES = { "TitleBox", "ChoiceBox", "RevealHero", "RevealChicken", "SuccessBox" } -- HCHeaderBox: setHeader owns it
local function hideAll()
	for _, n in ipairs(GROUP_BOXES) do
		show(n, false)
	end
end

local function pop(g: GuiObject?)
	if not g then
		return
	end
	local sc = g:FindFirstChild("HC_Pop") :: UIScale?
	if not sc then
		sc = Instance.new("UIScale")
		sc.Name = "HC_Pop"
		sc.Parent = g
	end
	sc.Scale = 0.6
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- the HERO tag over the Hero during their run (billboard from the HeroTag template)
-- The HERO line lives INSIDE the game's own overhead tag (EOS_Tag, built by CharacterService: name on the
-- top half, the CATCHER status line on the bottom half, which a Runner never shows). While someone is the
-- Hero: the HeroTag template takes the top row and the name moves down one row, so the two can never overlap.
-- Everything is put back when the run ends. Your own tag is hidden in matches (see updateTags).
local heroTag: { line: GuiObject, name: GuiObject, namePos: UDim2 }? = nil
local function setHeroTag(uid: number?)
	if heroTag then
		local h = heroTag
		heroTag = nil
		if h.line.Parent then
			h.line:Destroy()
		end
		if h.name.Parent then
			h.name.Position = h.namePos
		end
	end
	local c = charOf(uid)
	local head = c and c:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("EOS_Tag")
	local name = tag and tag:FindFirstChild("NameLabel") :: GuiObject?
	if not (tag and name) then
		return
	end
	local t = K.template("HeroTag")
	if not t then
		return
	end
	local text = K.find(t, "TagText") :: TextLabel?
	t.Name = "HC_HeroLine"
	t.AnchorPoint = Vector2.new(0, 0)
	t.Position = UDim2.fromScale(0, 0)
	t.Size = UDim2.fromScale(1, 0.42)
	t.BackgroundTransparency = 1
	if text then
		-- the billboard is sized in studs: the template label fills its row (runtime fit, logged in RUNTIME_UI.md)
		text.AnchorPoint = Vector2.new(0, 0)
		text.Position = UDim2.fromScale(0, 0)
		text.Size = UDim2.fromScale(1, 1)
		text.TextScaled = true
		local twin = K.twin(text)
		if twin then
			twin:Destroy()
		end
	end
	heroTag = { line = t, name = name, namePos = name.Position }
	name.Position = UDim2.new(name.Position.X.Scale, name.Position.X.Offset, 0.44, 0)
	t.Parent = tag
end


-- ===== overhead name tags =====
-- The lined-up Runners' tags run together into one unreadable strip: during the pick only the spotlit
-- Runner's tag shows; while people are frozen on the line (a Hero run) their tags hide. Only tags this
-- module hid are turned back on (attribute HC_TagHidden), so other scripts' own hiding is kept.
local CINE_STAGES = { CHOOSING = true, PICKED = true, REVEAL = true, HERO_SUCCESS = true }
local NEAR_STAGES = { HERO_RUN = true, HERO_SUCCESS = true, GROUP_READY = true } -- tags fade past HC.Look.TAG_RANGE
local function eachTag(fn: (BillboardGui, Model) -> ())
	local function visit(char: Model?)
		local head = char and char:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("EOS_Tag")
		if tag and tag:IsA("BillboardGui") then
			fn(tag, char :: Model)
		end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		visit(plr.Character)
	end
	local rt = workspace:FindFirstChild("EOS_Runtime")
	local npcs = rt and rt:FindFirstChild("Npcs")
	if npcs then
		for _, m in ipairs(npcs:GetChildren()) do
			if m:IsA("Model") then
				visit(m)
			end
		end
	end
end

local matchState: Configuration? = nil
local function updateTags()
	local stage = state:GetAttribute("Stage") or ""
	local inMatch = player:GetAttribute("EOS_InMatch") == true
	matchState = matchState or ReplicatedStorage:FindFirstChild("EOS_State") :: Configuration?
	local phase = matchState and matchState:GetAttribute("Phase")
	-- the break before a crossing: everyone stands lined up, so their names would run into one strip
	local lineupBreak = phase == "ROLE_REVEAL" or phase == "WAVE_END"
	local leadChar = charOf(state:GetAttribute("Catcher"))
	eachTag(function(tag, char)
		if CINE_STAGES[stage] then
			return -- cut-scenes: Controllers.Cinematic hides every overhead tag itself; don't fight it
		end
		local hide = false
		local plr = Players:GetPlayerFromCharacter(char)
		local inThisMatch = (if plr then plr:GetAttribute("EOS_InMatch") else char:GetAttribute("EOS_InMatch")) == true
		if inMatch and char == player.Character then
			hide = true -- your own name never floats over your own head in a match
		elseif HC.Look.NAME_TAGS == "SPOTLIT" and char ~= leadChar then
			-- lined up (the break before a crossing) or frozen on the line (a Hero run): no row of names
			hide = char:GetAttribute("EOS_LineFrozen") == true or (lineupBreak and inThisMatch)
		end
		if hide and tag.Enabled then
			tag.Enabled = false
			tag:SetAttribute("HC_TagHidden", true)
		elseif not hide and tag:GetAttribute("HC_TagHidden") then
			tag.Enabled = true
			tag:SetAttribute("HC_TagHidden", nil)
		end
		-- during the Hero run distant tags fade out, so far Catchers don't clump into one strip
		local near = NEAR_STAGES[stage] == true
		if near and tag:GetAttribute("HC_MaxD") == nil then
			tag:SetAttribute("HC_MaxD", tag.MaxDistance)
			tag.MaxDistance = HC.Look.TAG_RANGE
		elseif not near and tag:GetAttribute("HC_MaxD") ~= nil then
			tag.MaxDistance = tag:GetAttribute("HC_MaxD")
			tag:SetAttribute("HC_MaxD", nil)
		end
	end)
end

-- ===== pick input (lead Catcher only) =====

local picking = false
local pickIndex = 1
local lastHoverSent = nil
local request: RemoteEvent

local function sendHover(uid: number)
	if uid ~= lastHoverSent then
		lastHoverSent = uid
		request:FireServer("hover", uid)
	end
end

local function runnerUnder(x: number, y: number): number?
	local cam = workspace.CurrentCamera
	local best, bestD = nil, math.huge
	for _, uid in ipairs(lineup()) do
		local r = rootOf(uid)
		if r then
			local sp, on = cam:WorldToViewportPoint(r.Position + Vector3.new(0, 0.5, 0))
			if on then
				local d = (Vector2.new(sp.X, sp.Y) - Vector2.new(x, y)).Magnitude
				if d < bestD then
					best, bestD = uid, d
				end
			end
		end
	end
	local limit = math.max(70, workspace.CurrentCamera.ViewportSize.X * 0.06)
	return if bestD <= limit then best else nil
end

local function stopPicking()
	picking = false
	ContextActionService:UnbindAction("HC_Pick")
end

local function startPicking()
	if picking then
		return
	end
	picking = true
	lastHoverSent = nil
	local ids = lineup()
	pickIndex = math.max(1, math.ceil(#ids / 2))
	ContextActionService:BindActionAtPriority("HC_Pick", function(_, st, input)
		if st ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		local list = lineup()
		if #list == 0 then
			return Enum.ContextActionResult.Sink
		end
		local kc = input.KeyCode
		if kc == Enum.KeyCode.DPadLeft or kc == Enum.KeyCode.Left or kc == Enum.KeyCode.A then
			pickIndex = (pickIndex - 2) % #list + 1
			sendHover(list[pickIndex])
		elseif kc == Enum.KeyCode.DPadRight or kc == Enum.KeyCode.Right or kc == Enum.KeyCode.D then
			pickIndex = pickIndex % #list + 1
			sendHover(list[pickIndex])
		elseif kc == Enum.KeyCode.ButtonA or kc == Enum.KeyCode.Return or kc == Enum.KeyCode.Space then
			local uid = state:GetAttribute("Hover") or list[pickIndex]
			request:FireServer("pick", uid)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.ButtonA,
		Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.A, Enum.KeyCode.D, Enum.KeyCode.Return, Enum.KeyCode.Space)
end

UserInputService.InputChanged:Connect(function(input)
	if picking and input.UserInputType == Enum.UserInputType.MouseMovement then
		local uid = runnerUnder(input.Position.X, input.Position.Y)
		if uid then
			sendHover(uid)
		end
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not picking or processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local uid = runnerUnder(input.Position.X, input.Position.Y)
		if uid then
			sendHover(uid)
			request:FireServer("pick", uid)
		end
	end
end)

-- ===== choice input (picked Runner only) =====

local choosing = false
local function choose(which: string)
	if not choosing then
		return
	end
	choosing = false
	ContextActionService:UnbindAction("HC_Choose")
	request:FireServer("choose", which)
	local b = find(if which == "HERO" then "HeroButton" else "ChickenButton")
	pop(b)
end

local function startChoosing()
	choosing = true
	ContextActionService:BindActionAtPriority("HC_Choose", function(_, st, input)
		if st == Enum.UserInputState.Begin then
			local kc = input.KeyCode
			if kc == Enum.KeyCode.ButtonX or kc == Enum.KeyCode.DPadLeft or kc == Enum.KeyCode.One or kc == Enum.KeyCode.H then
				choose("HERO")
			elseif kc == Enum.KeyCode.ButtonB or kc == Enum.KeyCode.DPadRight or kc == Enum.KeyCode.Two or kc == Enum.KeyCode.C then
				choose("CHICKEN")
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonB, Enum.KeyCode.DPadLeft,
		Enum.KeyCode.DPadRight, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.H, Enum.KeyCode.C)
end

local function stopChoosing()
	choosing = false
	ContextActionService:UnbindAction("HC_Choose")
end

-- ===== the beats =====

local stageToken = 0
local function timerLoop(token: number, box: string, labelName: string, endsAt: number, tickSound: boolean?, fmt: ((number) -> string)?)
	task.spawn(function()
		local last = -1
		while stageToken == token do
			local left = math.max(0, math.ceil(endsAt - now()))
			if left ~= last then
				last = left
				setIn(box, labelName, if fmt then fmt(left) else tostring(left))
				if tickSound and left > 0 and left <= 3 then
					sfx("tick")
				end
			end
			task.wait(0.05)
		end
	end)
end

local function isMe(uid: number?): boolean
	return uid ~= nil and uid == player.UserId
end

local function crossingNo(): number
	return state:GetAttribute("Wave") or 1
end

local DOT = "  \u{B7}  " -- the round header's separator ("Runner . 0:21")

local function clock(left: number): string
	return "0:" .. string.format("%02d", math.max(0, left))
end

-- two lines: small label (timer folded in) + big title, under the top letterbox bar
local function titleLoop(token: number, endsAt: number, label: string, tick: boolean?)
	timerLoop(token, "TitleBox", "TitleLabel", endsAt, tick, function(left: number): string
		return label .. DOT .. clock(left)
	end)
end

-- the round header takeover (HUD back): EOSUI's Status hides while HCHeader shows in its spot
local headerOn = false
local function eosStatus(): GuiObject?
	local eos = player.PlayerGui:FindFirstChild("EOSUI")
	local root = eos and eos:FindFirstChild("Root")
	local mhud = root and root:FindFirstChild("MatchHUD")
	return mhud and mhud:FindFirstChild("Status") :: GuiObject?
end
local function setHeader(on: boolean, phase: string?, phaseTint: string?, head: string?, headTint: string?)
	headerOn = on
	show("HCHeaderBox", on)
	if not on then
		local st = eosStatus()
		if st and st:GetAttribute("HC_Hidden") then
			st.Visible = true
			st:SetAttribute("HC_Hidden", nil)
		end
		return
	end
	for nm, tint in pairs({ HPhase = "", HPhaseGold = "gold", HPhaseRed = "red" }) do
		show(nm, (phaseTint or "") == tint)
		setIn("HCHeaderBox", nm, phase or "")
	end
	for nm, tint in pairs({ HHeadline = "", HHeadlineGold = "gold" }) do
		show(nm, (headTint or "") == tint)
		setIn("HCHeaderBox", nm, head or "")
	end
end
RunService.Heartbeat:Connect(function()
	if headerOn then
		local st = eosStatus()
		if st and st.Visible then
			st.Visible = false
			st:SetAttribute("HC_Hidden", true)
		end
	end
end)

local function onChoosing(token: number)
	local at = state:GetAttribute("StageAt") or now()
	local ends = state:GetAttribute("StageEndsAt") or (at + TM.PICK_WINDOW)
	local lead = state:GetAttribute("Catcher")
	local iAmLead = isMe(lead)
	hideAll()
	setHeader(false)
	setGrade(0, 0, 0.2)
	-- a1: the lead Catcher
	show("TitleBox", true)
	set("TitleText", if iAmLead then "YOU" else nameOf(lead))
	titleLoop(token, ends, "LEAD CATCHER")
	pop(find("TitleBox"))
	local drum = sfx("drumroll")
	if GameSound and GameSound.duck then
		pcall(GameSound.duck, 0.25, TM.PICK_WINDOW + TM.CHOICE_WINDOW)
	end
	local P = LK.PUSH
	dip(function()
		task.wait(0.25) -- under black: the lineup teleport replicates before the shot is framed
		shot({ from = leadShot(lead, P.from - 1), to = leadShot(lead, P.to), fov0 = LK.FOV, fov1 = LK.FOV - P.fovSqueeze, t = math.min(TM.INTRO, P.seconds) - 0.35, ease = "Sine" }, TM.PICK_WINDOW + 1)
	end)
	task.wait(math.max(0, at + TM.INTRO - now()))
	if stageToken ~= token then
		return
	end
	-- a2: a short dip through black from the Catcher to the Runner line (comfort: no rush)
	sfx("whoosh")
	local u0, u1 = dollyRange(math.max(1, ends - now()))
	dip(function()
		if iAmLead then
			local cf = lineFront()
			shot({ from = cf, to = cf, fov0 = LK.FOV, fov1 = LK.FOV, t = TM.PICK_WINDOW, ease = "linear" }, TM.PICK_WINDOW + 1)
		else
			shot({ from = function()
				return dollyAt(u0)
			end, to = function()
				return dollyAt(u1)
			end, fov0 = LK.FOV, fov1 = LK.FOV, t = math.max(1, ends - now()), ease = "inout" }, TM.PICK_WINDOW + 1)
		end
	end)
	task.wait(math.max(0, at + HC.PICK_OPENS_AT - now()))
	if stageToken ~= token then
		return
	end
	-- a3: choosing
	if iAmLead then
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local pad = UserInputService.GamepadEnabled and UserInputService:GetLastInputType().Name:match("Gamepad") ~= nil
		set("TitleText", "PICK A RUNNER")
		titleLoop(token, ends, if pad then "LEFT / RIGHT, THEN A" elseif touch then "TAP A RUNNER" else "CLICK A RUNNER")
		startPicking()
	else
		set("TitleText", "THE CATCHER IS CHOOSING...")
		titleLoop(token, ends, "CROSSING " .. crossingNo())
	end
	pop(find("TitleText"))
	-- the drumroll rises toward the end of the window
	while stageToken == token and drum do
		local a = math.clamp((now() - at) / TM.PICK_WINDOW, 0, 1)
		drum.PlaybackSpeed = 1 + a * 0.18
		drum.Volume = SOUNDS.drumroll.volume * (0.7 + a * 0.6)
		task.wait(0.1)
	end
end

local function onPicked(token: number)
	stopPicking()
	stopSfx("drumroll")
	local picked = state:GetAttribute("Picked")
	local at = state:GetAttribute("StageAt") or now()
	local ends = state:GetAttribute("StageEndsAt") or (at + TM.CHOICE_WINDOW)
	hideAll()
	spotOn(picked, true)
	sfx("lock")
	local hb = sfx("heartbeat")
	-- first the lead Catcher turning and pointing (side-on, 11 studs), then a dip to the picked Runner's push-in
	local lead = state:GetAttribute("Catcher")
	task.spawn(function()
		dip(function()
			-- over the Catcher's pointing (right) shoulder: the arm and the picked Runner both in frame (Hunter
			-- 17 Oct: "he should point at who he picked"). Framed once from where the Catcher will face, so the
			-- Catcher turns inside a still frame and the camera never swings with them. >= 8 studs from the Catcher.
			local cf = workspace.CurrentCamera.CFrame
			local r, tr = rootOf(lead), rootOf(picked)
			if r then
				local face = if tr then Vector3.new(tr.Position.X - r.Position.X, 0, tr.Position.Z - r.Position.Z) else r.CFrame.LookVector
				face = if face.Magnitude > 0.1 then face.Unit else r.CFrame.LookVector
				local right = face:Cross(Vector3.yAxis)
				local head = r.Position + Vector3.new(0, 1.6, 0)
				local O = HC.Gesture.OTS
				local camPos = head - face * O.BACK + right * O.SIDE + Vector3.new(0, O.UP, 0)
				if blockedAt(head, camPos) then
					local other = head - face * O.BACK - right * O.SIDE + Vector3.new(0, O.UP, 0)
					if not blockedAt(head, other) then
						camPos = other
					else
						local hitAt = blockedAt(head, camPos) or 8
						camPos = head + (camPos - head).Unit * math.max(6.5, hitAt - 1.5)
					end
				end
				local aim = head + face * O.AHEAD - Vector3.new(0, 1, 0) -- the Catcher sits off-centre, the Runners down the same line
				cf = CFrame.lookAt(camPos, aim)
			end
			shot({ from = cf, to = cf, fov0 = LK.FOV, fov1 = LK.FOV, t = HC.Gesture.POINT_SHOT, ease = "linear" }, TM.CHOICE_WINDOW + TM.REVEAL + 1, 0)
		end)
		task.wait(HC.Gesture.POINT_SHOT)
		if stageToken ~= token then
			return
		end
		dip(function()
			local P = LK.PUSH
			shot({ from = closeShot(picked, P.from, 2), to = closeShot(picked, P.to, 2), fov0 = LK.FOV, fov1 = LK.FOV - P.fovSqueeze, t = P.seconds, ease = "Sine" },
				TM.CHOICE_WINDOW + TM.REVEAL + 1, TM.CHOICE_WINDOW - P.seconds + TM.REVEAL)
		end)
	end)
	show("TitleBox", true)
	set("TitleText", if isMe(picked) then "YOU WERE PICKED" else nameOf(picked))
	titleLoop(token, ends, "HERO OR CHICKEN?", true)
	pop(find("TitleText"))
	task.wait(math.max(0, at + TM.PUSH_IN - now()))
	if stageToken ~= token then
		return
	end
	if isMe(picked) then
		show("ChoiceBox", true)
		-- phones: the approved phone page grows the cards 1.3x so both stay thumb-sized (>= 44 px)
		local choiceGroup = find("Choice") :: GuiObject?
		if choiceGroup then
			local sc = choiceGroup:FindFirstChild("HC_PhoneScale") :: UIScale?
			if not sc then
				sc = Instance.new("UIScale")
				sc.Name = "HC_PhoneScale"
				sc.Parent = choiceGroup
			end
			sc.Scale = if gui.AbsoluteSize.Y < 600 then 1.3 else 1
		end
		setIn("HeroButton", "Label", "CROSS ALONE" .. DOT .. HC.HERO_CROSSING_MULT .. "x POINTS")
		pop(find("ChoiceBox"))
		startChoosing()
	end
	while stageToken == token and hb do
		local a = math.clamp((now() - at) / TM.CHOICE_WINDOW, 0, 1)
		hb.PlaybackSpeed = 1 + a * 0.35
		task.wait(0.1)
	end
end

local function onReveal(token: number)
	stopChoosing()
	stopSfx("heartbeat")
	local picked = state:GetAttribute("Picked")
	local choice = state:GetAttribute("Choice")
	hideAll()
	local r = rootOf(picked)
	local pos = if r then r.Position else Vector3.zero
	if choice == "HERO" then
		sfx("hero")
		goldBurst(pos)
		show("RevealHero", true)
		K.set(K.find(find("RevealHero"), "Sub"), if isMe(picked) then "You go it alone!" else nameOf(picked) .. " is crossing alone")
		pop(find("RevealHero"))
		local cf = closeShot(picked, LK.PUSH.to, 2)
		local f = LK.FOV - LK.PUSH.fovSqueeze
		shot({ from = cf, to = cf, fov0 = f, fov1 = f, t = TM.REVEAL, ease = "linear" }, TM.REVEAL + TM.SWOOP + 1, 0.6)
	else
		spotOn(nil)
		sfx("chicken")
		setGrade(-0.65, -0.08, 0.25)
		feathers(pos)
		show("RevealChicken", true)
		K.set(K.find(find("RevealChicken"), "Sub"), (if isMe(picked) then "You run" else nameOf(picked) .. " runs") .. " with the group")
		pop(find("RevealChicken"))
		local f = LK.FOV - LK.PUSH.fovSqueeze
		shot({ from = closeShot(picked, LK.PULL.from, 2), to = closeShot(picked, LK.PULL.to, 2), fov0 = f, fov1 = f, t = LK.PULL.seconds, ease = "Sine" }, TM.REVEAL + TM.SWOOP + 1, 0.6)
	end
	task.wait(TM.REVEAL)
	if stageToken ~= token then
		return
	end
	-- back to the gameplay camera: a dip cut (comfort: no swoop)
	hideAll()
	spotOn(nil)
	setGrade(0, 0, 0.3)
	if stageToken == token then
		dip(function()
			endCinematic()
		end)
	end
end

local function onReady(token: number)
	endCinematic()
	hideAll()
	setGrade(0, 0, 0.3)
	local picked = state:GetAttribute("Picked")
	local choice = state:GetAttribute("Choice") or "CHICKEN"
	setHeader(true, "CROSSING " .. crossingNo(), nil, (if isMe(picked) then "You are going " else nameOf(picked) .. " is going ") .. choice, nil)
	timerLoop(token, "HCHeaderBox", "HSubline", state:GetAttribute("StageEndsAt") or (now() + TM.READY), true, function(left: number): string
		return "get ready" .. DOT .. tostring(left)
	end)
end

local function onHeroRun(token: number)
	endCinematic()
	hideAll()
	local hero = state:GetAttribute("Hero")
	setHeader(true, "CROSSING " .. crossingNo(), nil, "HERO ATTEMPT", "gold")
	local who = if isMe(hero) then "get across alone" else nameOf(hero) .. " crosses alone"
	timerLoop(token, "HCHeaderBox", "HSubline", state:GetAttribute("StageEndsAt") or (now() + TM.HERO_MAX), false, function(left: number): string
		return who .. DOT .. clock(left)
	end)
	setHeroTag(hero)
end

local function onSuccess(token: number)
	hideAll()
	setHeader(false)
	local hero = state:GetAttribute("Hero")
	local r = rootOf(hero)
	local pos = if r then r.Position else Vector3.zero
	sfx("hero")
	sfx("cheer")
	goldBurst(pos, true)
	if heroTag then
		heroTag.line.Visible = false -- the title carries the name
	end
	task.spawn(dip, function()
		local P = LK.PUSH
		shot({ from = lowHero(hero, P.from), to = lowHero(hero, P.to), fov0 = LK.FOV, fov1 = LK.FOV - P.fovSqueeze, t = math.min(TM.SUCCESS, P.seconds), ease = "Sine" }, TM.SUCCESS + 0.5, TM.SUCCESS - P.seconds)
	end)
	show("SuccessBox", true)
	K.set(K.find(find("SuccessBox"), "Sub"), (if isMe(hero) then "You" else nameOf(hero)) .. " made it alone")
	set("PointsText", "+" .. HC.HERO_POINTS .. " PTS") -- always with its unit (a bare number reads as Gold / XP)
	local box = find("SuccessBox") :: GuiObject
	pop(box)
	task.delay(0.35, function()
		pop(find("PointsChip"))
	end)
	task.wait(math.max(0, TM.SUCCESS - TM.SUCCESS_FADE))
	if stageToken ~= token then
		return
	end
	-- a dip back to the game
	dip(function()
		show("SuccessBox", false)
		if heroTag then
			heroTag.line.Visible = true
		end
		endCinematic()
	end)
end

local function onGroupReady(token: number)
	endCinematic()
	hideAll()
	local res = state:GetAttribute("HeroResult")
	if res == "CAUGHT" then
		setHeader(true, "THE HERO WAS CAUGHT", "red", "THE GROUP GOES NEXT", nil)
	elseif res == "CROSSED" then
		setHeader(true, "HERO ATTEMPT COMPLETE", "gold", "THE GROUP GOES NEXT", nil)
	else
		setHeader(true, "TIME'S UP FOR THE HERO", nil, "THE GROUP GOES NEXT", nil)
	end
	timerLoop(token, "HCHeaderBox", "HSubline", state:GetAttribute("StageEndsAt") or (now() + TM.GROUP_READY), true, function(left: number): string
		return "get ready" .. DOT .. tostring(left)
	end)
end

local function onStage()
	stageToken += 1
	local token = stageToken
	local stage = state:GetAttribute("Stage") or ""
	if stage ~= "CHOOSING" then
		stopPicking()
	end
	if stage ~= "PICKED" then
		stopChoosing()
	end
	if stage ~= "CHOOSING" and stage ~= "PICKED" and stage ~= "REVEAL" then
		spotOn(nil)
		stopSfx("drumroll")
		stopSfx("heartbeat")
	end
	if stage == "" or stage == "GROUP_RUN" then
		hideAll()
		setHeader(false)
		endCinematic()
		setGrade(0, 0, 0.3)
		if stage == "" then
			setHeroTag(nil)
		end
		return
	end
	local fn = ({
		CHOOSING = onChoosing,
		PICKED = onPicked,
		REVEAL = onReveal,
		READY = onReady,
		HERO_RUN = onHeroRun,
		HERO_SUCCESS = onSuccess,
		GROUP_READY = onGroupReady,
	})[stage]
	if fn then
		task.spawn(function()
			local ok, err = pcall(fn, token)
			if not ok then
				warn("[HeroChicken] " .. stage .. ": " .. tostring(err))
				endCinematic()
			end
		end)
	end
end

local function onFx(payload: any)
	if type(payload) ~= "table" then
		return
	end
	-- the points pop for a Hero crossing belongs to the points system (it shows "+N Hero crossing"); the
	-- HERO! banner's "+N PTS" chip says the rest, so no second pop here (two pops read as double pay)
	if payload.kind == "heroCrossed" then
		return
	end
end

function HeroChicken.init()
	state = ReplicatedStorage:WaitForChild("EOS_HeroChicken", 60) :: Configuration
	if not state then
		warn("[HeroChicken] no EOS_HeroChicken state")
		return
	end
	request = state:WaitForChild("Request") :: RemoteEvent
	local fx = state:WaitForChild("Fx") :: RemoteEvent
	fx.OnClientEvent:Connect(onFx)
	local okN, mod = pcall(function()
		return require(Controllers:WaitForChild("NpcSkins", 5))
	end)
	NpcSkins = if okN then mod else nil
	local okS, snd = pcall(function()
		return require(Controllers:WaitForChild("Sound", 5))
	end)
	GameSound = if okS then snd else nil
	local cineMod = Controllers:FindFirstChild("Cinematic")
	if cineMod then
		local okC, c = pcall(require, cineMod)
		Cine = if okC then c else nil
	end
	gui = player:WaitForChild("PlayerGui"):WaitForChild("HeroChickenUI", 30) :: ScreenGui
	if not gui then
		warn("[HeroChicken] no HeroChickenUI")
		return
	end
	gui.DisplayOrder = 60 -- above the Cinematic letterbox (50)
	gui.ResetOnSpawn = false
	gui.Enabled = true
	root = gui:WaitForChild("Root") :: Frame
	K = require(gui:WaitForChild("UIKit"))
	pcall(K.init, "HeroChickenTemplates", gui:FindFirstChild("AssetIds"))
	-- the skill's runtime (a copy of EOSUI's client/UI.luau): fit to the safe canvas, anchors, juicy buttons
	local uiMod = gui:FindFirstChild("UI")
	if uiMod then
		local okU, UI = pcall(require, uiMod)
		if okU and UI and UI.init then
			UI.init(gui)
		end
	end
	hideAll()
	flash = find("DipFill") :: Frame -- the exported Dip group: a black 0.2 s dip between beats (no white / gold flashes)
	flash.BackgroundTransparency = 1
	flash.Visible = false
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "HC_Grade"
	grade.Parent = Lighting
	local okV, emit = pcall(function()
		return require(ReplicatedStorage:WaitForChild("VFX"):WaitForChild("Emit"))
	end)
	VFXEmit = if okV then emit else nil
	buildSpot()
	for _, n in ipairs({ "HeroButton", "ChickenButton" }) do
		local b = find(n)
		if b and b:IsA("GuiButton") then
			b.Activated:Connect(function()
				choose(if n == "HeroButton" then "HERO" else "CHICKEN")
			end)
		end
	end
	-- load the sounds and effect textures up front: a first-use stall at the first shot of a match made the
	-- camera look like it jumped (Cinematic measures speed per frame)
	task.spawn(function()
		local list: { Instance } = {}
		for key in pairs(SOUNDS) do
			local snd = sounds[key]
			if not snd then
				snd = Instance.new("Sound")
				snd.Name = "HC_" .. key
				snd.SoundId = "rbxassetid://" .. SOUNDS[key].id
				snd.Volume = SOUNDS[key].volume
				snd.Looped = SOUNDS[key].looped == true
				snd.SoundGroup = SoundService:FindFirstChild("EOS_SFX") :: SoundGroup?
				snd.Parent = SoundService
				sounds[key] = snd
			end
			table.insert(list, snd)
		end
		local set = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("HeroChicken")
		if set then
			table.insert(list, set)
		end
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(list)
		end)
	end)
	state:GetAttributeChangedSignal("StageId"):Connect(onStage)
	task.spawn(function()
		-- every 0.1 s (about 25 tags): cheap, quick enough that no strip of names flashes up between beats,
		-- and a tag is always put back once nothing needs it hidden
		while true do
			pcall(updateTags)
			task.wait(0.1)
		end
	end)
	state:GetAttributeChangedSignal("Hover"):Connect(function()
		if state:GetAttribute("Stage") == "CHOOSING" then
			local h = state:GetAttribute("Hover")
			spotOn(h, false)
			local ids = lineup()
			local i = table.find(ids, h)
			if i then
				pickIndex = i
			end
		end
	end)
	-- dying or respawning mid-cinematic never leaves the camera stuck
	player.CharacterAdded:Connect(function()
		if (state:GetAttribute("Stage") or "") == "" then
			endCinematic()
		end
	end)
	if (state:GetAttribute("Stage") or "") ~= "" then
		onStage()
	end
end

return HeroChicken
