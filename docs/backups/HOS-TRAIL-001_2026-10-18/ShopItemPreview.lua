--!nonstrict
-- ShopItemPreview (HOS-INV-001 follow-up, Hunter 18 Oct: "The items in the shop that don't have hover previews need
-- them"). Every Shop card that had only a flat icon now opens a live stage on hover (tap the picture on a phone),
-- like the pet cards (ShopPetPreview) and the Weapons tab: your own character with the item, on the card's backdrop.
--
--   ClientMain: task.spawn(require(Controllers.ShopItemPreview).init)
--
-- Cards: Shop > Cosmetics (PageItems.Row.Card_<id>, built by UIController.refreshShop) and the Featured pair
-- (FeatA = EconomyConfig.FEATURED.weekly, FeatB = .spotlight). Found by name at runtime: UIController is untouched.
-- What each kind shows (all looks only, the same as in a match):
--   case      your character turning slowly, the egg on your back inside the glass case
--   trail     your character running, the egg's trail streaming behind (2D: viewports draw no trails)
--   trailPerm same, rainbow
--   burst     confetti popping over your head
--   entrance  the lightning bolt striking down on you
--   abilityFx gold rings and sparkles bursting off you (your ability's colours turn gold)
--   abilitySkin the Rift portal in its colour swirling beside you
--   hatchFx   an egg shaking, then cracking open in a gold flash
-- The stage tweens out of the card's icon (0.25 s) and everything is destroyed when the mouse leaves, the card
-- hides, or the Shop closes; the icon always comes back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local AnimConfig = require(Shared:WaitForChild("AnimConfig"))

local ShopItemPreview = {}

local player = Players.LocalPlayer
local DWELL = 0.08
local OPEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BACKDROP = { -- ShopPetPreview's uploaded backdrops
	violet = "rbxassetid://126543247334245",
	orange = "rbxassetid://119860466123113",
	sky = "rbxassetid://98575396374871",
	lime = "rbxassetid://129629158117711",
}
local KIND = { -- backdrop + the line under the stage
	case = { "sky", "ON YOUR EGG IN EVERY MATCH" },
	trail = { "lime", "BEHIND YOUR EGG FOR ONE MATCH" },
	trailPerm = { "violet", "BEHIND YOUR EGG IN EVERY MATCH" },
	burst = { "orange", "POP IT IN THE LOBBY" },
	entrance = { "sky", "EVERY TIME YOU ARRIVE IN THE LOBBY" },
	abilityFx = { "orange", "A GOLD RING EVERY TIME YOUR ABILITY FIRES" },
	abilitySkin = { "violet", "YOUR RIFT PORTALS" },
	hatchFx = { "violet", "EVERY HATCH AT THE INCUBATOR" },
}
local TRAIL_LAYERS = { -- EconomyService.TRAIL_LAYERS: the layers a match draws (texture, width, lifetime)
	trail_spark = { { tex = "rbxassetid://18568183566", width = 1, life = 0.5 }, { tex = "rbxassetid://18568048335", width = 0.6, life = 0.35 } },
	trail_ember = { { tex = "rbxassetid://70464235210468", width = 1, life = 0.4 } },
	trailp_rainbow = { { tex = "rbxassetid://99421661918040", width = 1, life = 0.55 }, { tex = "rbxassetid://18568048335", width = 0.7, life = 0.4 } },
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 214, 72)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 236, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 255)),
})
local CONFETTI = { Color3.fromRGB(255, 90, 160), Color3.fromRGB(255, 214, 72), Color3.fromRGB(90, 200, 255), Color3.fromRGB(140, 240, 110), Color3.fromRGB(190, 120, 255) }
local GOLD = Color3.fromRGB(255, 210, 58)

local assets: any = nil
local attached: { [Instance]: boolean } = {}
local controls: { [Instance]: { open: () -> (), close: () -> () } } = {} -- for tests and other screens

local function icon(slug: string): string
	if not assets then
		local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("EOSUI")
		local m = gui and gui:FindFirstChild("AssetIds")
		local ok, a = pcall(function()
			return m and require(m)
		end)
		assets = if ok then a else nil
	end
	return (assets and assets.icons and assets.icons[slug]) or ""
end

local function reduceEffects(): boolean
	return player:GetAttribute("EOS_ReduceEffects") == true
end

-- ===== 3D: your character, cleaned for a WorldModel (same steps as the Weapons tab stage)

local function strip(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Sound") or d:IsA("BaseScript") then
			d:Destroy()
		end
	end
end

local function cloneMe(): (Model?, BasePart?, Humanoid?)
	local me = player.Character
	if not me then
		return nil
	end
	local was = me.Archivable
	me.Archivable = true
	local char = me:Clone()
	me.Archivable = was
	if not char then
		return nil
	end
	for _, d in char:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ForceField") or d:IsA("BillboardGui") or d:IsA("Highlight") then
			d:Destroy()
		elseif d:IsA("BasePart") and (d:GetAttribute("EOS_Knife") or d:GetAttribute("EOS_Holstered") or d:GetAttribute("EOS_Egg")) then
			d:Destroy()
		end
	end
	for _, c in char:GetChildren() do
		if c:IsA("Model") and c:GetAttribute("EOS_Egg") then
			c:Destroy()
		end
	end
	strip(char)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		char:Destroy()
		return nil
	end
	for _, d in char:GetDescendants() do -- accessories: re-hang on Motor6Ds so they follow the animation
		if d:IsA("Weld") or d:IsA("ManualWeld") or d:IsA("RigidConstraint") or d:IsA("WeldConstraint") then
			local p0 = if d:IsA("RigidConstraint") then (d.Attachment0 and d.Attachment0.Parent) else (d :: any).Part0
			local p1 = if d:IsA("RigidConstraint") then (d.Attachment1 and d.Attachment1.Parent) else (d :: any).Part1
			if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				local m = Instance.new("Motor6D")
				m.Name = "HangJoint"
				m.Part0, m.Part1 = p0, p1
				m.C0 = p0.CFrame:ToObjectSpace(p1.CFrame)
				m.Parent = p1
				d:Destroy()
			end
		end
	end
	char:PivotTo(CFrame.new(0, 3, 0))
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
		end
	end
	root.Anchored = true
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	return char, root, hum
end

local function play(hum: Humanoid, id: string?, looped: boolean, speed: number?): AnimationTrack?
	if not id or id == "" then
		return nil
	end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local a = Instance.new("Animation")
	a.AnimationId = id
	local ok, t = pcall(function()
		return animator:LoadAnimation(a)
	end)
	if not ok or not t then
		return nil
	end
	t.Looped = looped
	t:Play(0.1, 1, speed or 1)
	return t
end

local function newEgg(wearable: boolean): Model?
	local ok, EggModel = pcall(require, Shared:FindFirstChild("EggModel"))
	local egg: Model? = nil
	if ok and EggModel and EggModel.build then
		local ok2, m = pcall(EggModel.build, 1, wearable)
		if ok2 then
			egg = m
		end
	end
	if not egg then
		local t = ReplicatedStorage.EOS:FindFirstChild("Assets") and ReplicatedStorage.EOS.Assets:FindFirstChild("CarryEgg")
		egg = t and t:Clone()
	end
	if egg then
		strip(egg)
		for _, d in egg:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.Massless = true
			end
		end
	end
	return egg
end

-- the egg on the back (CharacterService.setEgg's spot), joined with Motor6Ds so it follows the animation
local function eggOnBack(char: Model, caseItem: any?): Model?
	local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
	local egg = newEgg(true)
	if not torso or not egg or not egg.PrimaryPart then
		return nil
	end
	local base = egg.PrimaryPart :: BasePart
	egg:PivotTo(torso.CFrame * CFrame.new(0, -0.55, torso.Size.Z / 2 + 0.7))
	for _, p in egg:GetDescendants() do
		if p:IsA("BasePart") and p ~= base then
			local m = Instance.new("Motor6D")
			m.Part0, m.Part1 = base, p
			m.C0 = base.CFrame:ToObjectSpace(p.CFrame)
			m.Parent = p
			for _, w in p:GetChildren() do
				if w:IsA("WeldConstraint") or w:IsA("Weld") then
					w:Destroy()
				end
			end
		end
	end
	if caseItem then -- EconomyService.caseOn: a glass shell round the egg in the case's colour
		local cf, size = egg:GetBoundingBox()
		local shell = Instance.new("Part")
		shell.Name = "Case"
		shell.Size = size + Vector3.new(0.35, 0.35, 0.35)
		shell.CFrame = cf
		shell.Material = Enum.Material.Glass
		shell.Color = caseItem.color
		shell.Transparency = 0.45
		shell.CanCollide = false
		shell.Massless = true
		local m = Instance.new("Motor6D")
		m.Part0, m.Part1 = base, shell
		m.C0 = base.CFrame:ToObjectSpace(cf)
		m.Parent = shell
		shell.Parent = egg
	end
	local j = Instance.new("Motor6D")
	j.Name = "EggJoint"
	j.Part0, j.Part1 = torso, base
	j.C0 = torso.CFrame:ToObjectSpace(base.CFrame)
	j.Parent = base
	egg.Parent = char
	return egg
end

local function viewport(parent: GuiObject): (ViewportFrame, WorldModel, Camera)
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Stage3D"
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.fromScale(1, 1)
	vf.Ambient = Color3.fromRGB(205, 200, 220)
	vf.LightColor = Color3.fromRGB(255, 250, 240)
	vf.LightDirection = Vector3.new(-0.6, -1, -0.7)
	vf.ZIndex = parent.ZIndex + 2
	vf.Parent = parent
	local wm = Instance.new("WorldModel")
	wm.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vf
	vf.CurrentCamera = cam
	return vf, wm, cam
end

-- ===== 2D helpers (the overlay layer above the viewport)

local function img(parent: GuiObject, image: string, z: number): ImageLabel
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = image
	i.AnchorPoint = Vector2.new(0.5, 0.5)
	i.ZIndex = z
	i.Parent = parent
	return i
end

local function ring(parent: GuiObject, color: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.SizeConstraint = Enum.SizeConstraint.RelativeYY
	f.ZIndex = z
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 4
	s.Parent = f
	f.Parent = parent
	return f
end

local function flash(parent: GuiObject, color: Color3, z: number, t: number)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0.15
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	f.Parent = parent
	TweenService:Create(f, TweenInfo.new(t, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	task.delay(t + 0.05, function()
		f:Destroy()
	end)
end

-- ===== the scenes: each builds into `stage` and returns a stop function; `alive()` is false once closed

type Scene = (stage: Frame, fx: Frame, item: any, alive: () -> boolean) -> ()

local function standCam(cam: Camera, turn: number?)
	cam.CFrame = CFrame.lookAt(Vector3.new(13.5 * math.sin(turn or 0.5), 4.2, -13.5 * math.cos(turn or 0.5)), Vector3.new(0, 2.2, 0))
end

local SCENES: { [string]: Scene } = {}

SCENES.case = function(stage, fx, item, alive)
	local _, wm, cam = viewport(stage)
	local char, root, hum = cloneMe()
	if not char then
		return
	end
	char.Parent = wm
	eggOnBack(char, item)
	play(hum :: Humanoid, AnimConfig.builtin and AnimConfig.builtin.Idle, true)
	cam.FieldOfView = 28
	local a = 2.6 -- start showing the back (the egg)
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not alive() then
			conn:Disconnect()
			return
		end
		a += dt * 0.7
		;(root :: BasePart).CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(0, a, 0)
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 3.6, -13.5), Vector3.new(0, 2.0, 0))
	end)
end

-- HOS-PREV-001 (Matthew 18 Oct: "They look bad and I hope the trail doesnt look like that in game. You could move the
-- player all the way to the left on the viewport so the trail can be seen in the center/right side"). The trail is
-- drawn the way a match draws it (EconomyService.trailOn): each of the item's layers with its own texture stretched
-- along it, 0.8 studs tall (times the layer's width) at the egg, its colour running from the egg to the tail as it
-- fades out, the shorter-lived layer shorter. A viewport draws no Trails, so the layers are flat pictures on a layer
-- just under the 3D: the egg and your back cover where it starts, as in a match. The camera is worked out every frame
-- so you stand at TRAIL_X across, TRAIL_FILL of the scene's height, whatever shape the stage is (a Featured daily
-- card's scene ends at its SceneBottom attribute, above the card's name and buttons).
local TRAIL_X, TRAIL_FILL, TRAIL_TOP = 0.26, 0.8, 0.06 -- where you stand (of the width), how tall (of the scene), its top
local TRAIL_END = 0.97 -- the longest layer reaches this far across
local TRAIL_LEAD = 0.15 -- the textures start blank: this much of a layer's length sits back under the egg
local TRAIL_GLOW = 3 -- each layer drawn this many times over itself (a match adds light with LightEmission; pictures only blend)

local function trailScene(stage, fx, item, alive)
	local _, wm, cam = viewport(stage)
	local char, root, hum = cloneMe()
	if not char then
		return
	end
	char.Parent = wm
	local egg = eggOnBack(char, nil)
	local base = egg and egg.PrimaryPart
	;(root :: BasePart).CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(-90), 0) -- running toward screen left (the egg and its trail on the right)
	local boxCf, box = char:GetBoundingBox()
	local run = AnimConfig.ids and (AnimConfig.ids.Run or AnimConfig.ids.WalkFast) -- the run clip, as a Runner moves in a match (Matthew: "it should be their running animation, not the walk")
	play(hum :: Humanoid, run, true)
	-- the layers, under the viewport (over the backdrop at the stage's z, under the viewport at +2)
	local back = Instance.new("Frame")
	back.Name = "TrailBack"
	back.BackgroundTransparency = 1
	back.Size = UDim2.fromScale(1, 1)
	back.ZIndex = stage.ZIndex + 1
	back.Parent = stage
	local layers = TRAIL_LAYERS[item.id] or { { tex = "", width = 1, life = 0.45 } }
	local longest = 0
	for _, layer in layers do
		longest = math.max(longest, layer.life)
	end
	local ribbons = {}
	for i, layer in layers do
		for k = 1, TRAIL_GLOW do
			local r = img(back, layer.tex, i)
			r.ScaleType = Enum.ScaleType.Stretch
			r.AnchorPoint = Vector2.new(0, 0.5)
			if layer.tex == "" then
				r.BackgroundTransparency = 0
				r.BorderSizePixel = 0
			end
			local g = Instance.new("UIGradient")
			g.Color = if item.id == "trailp_rainbow" then RAINBOW else ColorSequence.new(item.color)
			g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, if i == 1 then 0.1 else 0.35), NumberSequenceKeypoint.new(1, 1) })
			g.Parent = r
			table.insert(ribbons, { gui = r, layer = layer, y = nil :: number? })
		end
	end
	local from = Vector2.new(TRAIL_X + 0.05, 0.4) -- where the egg is on screen (the sparks start there)
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not alive() then
			conn:Disconnect()
			return
		end
		local abs = stage.AbsoluteSize
		if abs.X < 2 or abs.Y < 2 then
			return
		end
		local aspect = abs.X / abs.Y
		local tanV = math.tan(math.rad(cam.FieldOfView / 2))
		local bottom = (stage:GetAttribute("SceneBottom") :: number?) or (1 - TRAIL_TOP)
		local win = bottom - TRAIL_TOP
		local dist = box.Y / (2 * TRAIL_FILL * win * tanV)
		local c = boxCf.Position
		-- looking along +Z, screen right is world -X: put the middle of you at (TRAIL_X, the scene's middle)
		local at = Vector3.new(c.X + (2 * TRAIL_X - 1) * dist * tanV * aspect, c.Y - (1 - 2 * (TRAIL_TOP + win / 2)) * dist * tanV, c.Z - dist)
		cam.CFrame = CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
		if not base then
			return
		end
		local function screen(p: Vector3): Vector2
			local l = cam.CFrame:PointToObjectSpace(p)
			local z = math.max(-l.Z, 0.1)
			return Vector2.new(0.5 + l.X / (z * tanV * aspect) / 2, 0.5 - l.Y / (z * tanV) / 2)
		end
		local cf = base.CFrame
		for _, rb in ribbons do
			local lo = screen(cf * Vector3.new(0, 0.1, 0)) -- EconomyService.trailOn's attachments
			local hi = screen(cf * Vector3.new(0, 0.1 + 0.8 * rb.layer.width, 0))
			local x, y = (lo.X + hi.X) / 2, (lo.Y + hi.Y) / 2
			rb.y = if rb.y then rb.y + (y - rb.y) * math.min(1, dt * 8) else y -- (follows the egg's bob a touch behind, like the trail does)
			local len = math.max(0, (TRAIL_END - x) * rb.layer.life / longest)
			rb.gui.Position = UDim2.fromScale(x - TRAIL_LEAD * len, rb.y :: number)
			rb.gui.Size = UDim2.fromScale(len * (1 + TRAIL_LEAD), math.abs(lo.Y - hi.Y))
			from = Vector2.new(x, y)
		end
	end)
	if item.id ~= "trailp_rainbow" then -- sparks / embers like the egg's emitter
		task.spawn(function()
			while alive() do
				local sp = img(fx, icon("sparkle"), fx.ZIndex + 2)
				sp.ImageColor3 = item.color
				sp.Position = UDim2.fromScale(from.X + 0.02 + math.random() * 0.05, from.Y + (math.random() - 0.5) * 0.08)
				sp.Size = UDim2.fromScale(0.06, 0.06)
				sp.SizeConstraint = Enum.SizeConstraint.RelativeYY
				local up = if item.id == "trail_ember" then -0.15 else 0.12
				TweenService:Create(sp, TweenInfo.new(0.7), { Position = sp.Position + UDim2.fromScale(0.25 + math.random() * 0.1, up), ImageTransparency = 1, Size = UDim2.fromScale(0.02, 0.02) }):Play()
				task.delay(0.75, function()
					sp:Destroy()
				end)
				task.wait(0.08)
			end
		end)
	end
end

SCENES.trail = trailScene
SCENES.trailPerm = trailScene

SCENES.burst = function(stage, fx, item, alive)
	local _, wm, cam = viewport(stage)
	local char, _, hum = cloneMe()
	if not char then
		return
	end
	char.Parent = wm
	play(hum :: Humanoid, AnimConfig.builtin and AnimConfig.builtin.Idle, true)
	standCam(cam, 0.35)
	task.spawn(function()
		task.wait(0.4)
		while alive() do
			for _ = 1, 36 do
				local p = Instance.new("Frame")
				p.BorderSizePixel = 0
				p.BackgroundColor3 = CONFETTI[math.random(#CONFETTI)]
				p.AnchorPoint = Vector2.new(0.5, 0.5)
				p.Size = UDim2.fromScale(0.035, 0.05)
				p.SizeConstraint = Enum.SizeConstraint.RelativeYY
				p.Position = UDim2.fromScale(0.5, 0.18)
				p.Rotation = math.random(0, 180)
				p.ZIndex = fx.ZIndex + 1
				p.Parent = fx
				local dx, up = (math.random() - 0.5) * 0.9, 0.1 + math.random() * 0.2
				local peak = UDim2.fromScale(0.5 + dx * 0.6, 0.18 - up)
				TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = peak, Rotation = p.Rotation + 180 }):Play()
				task.delay(0.35, function()
					if p.Parent then
						TweenService:Create(p, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5 + dx, 1.05), Rotation = p.Rotation + 360, BackgroundTransparency = 0.4 }):Play()
					end
				end)
				task.delay(1.7, function()
					p:Destroy()
				end)
			end
			flash(fx, Color3.fromRGB(255, 240, 200), fx.ZIndex, 0.25)
			task.wait(2.4)
		end
	end)
end

SCENES.entrance = function(stage, fx, item, alive)
	local _, wm, cam = viewport(stage)
	local char, _, hum = cloneMe()
	if not char then
		return
	end
	char.Parent = wm
	play(hum :: Humanoid, AnimConfig.builtin and AnimConfig.builtin.Idle, true)
	standCam(cam, 0.35)
	cam.CFrame = CFrame.lookAt(cam.CFrame.Position + Vector3.new(0, 1.5, -2), Vector3.new(0, 3.6, 0))
	local bolt = Instance.new("Folder")
	bolt.Parent = wm
	task.spawn(function()
		task.wait(0.5)
		while alive() do
			bolt:ClearAllChildren()
			-- EconomyService.bolt: jagged neon from the sky to your feet
			local top, bottom = Vector3.new(0, 26, 0), Vector3.new(0, 0.5, 0)
			local pts = { top }
			for i = 1, 5 do
				table.insert(pts, top:Lerp(bottom, i / 6) + Vector3.new(math.random(-12, 12) / 10, 0, math.random(-12, 12) / 10))
			end
			table.insert(pts, bottom)
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				local seg = Instance.new("Part")
				seg.Anchored = true
				seg.Material = Enum.Material.Neon
				seg.Color = Color3.fromRGB(170, 215, 255)
				seg.Size = Vector3.new(0.35, 0.35, (b - a).Magnitude)
				seg.CFrame = CFrame.lookAt((a + b) / 2, b)
				seg.Parent = bolt
			end
			flash(fx, Color3.fromRGB(200, 230, 255), fx.ZIndex, 0.35)
			task.wait(0.3)
			bolt:ClearAllChildren()
			task.wait(1.9)
		end
	end)
end

SCENES.abilityFx = function(stage, fx, item, alive)
	local _, wm, cam = viewport(stage)
	local char, _, hum = cloneMe()
	if not char then
		return
	end
	char.Parent = wm
	play(hum :: Humanoid, AnimConfig.builtin and AnimConfig.builtin.Idle, true)
	standCam(cam, 0.35)
	task.spawn(function()
		task.wait(0.3)
		while alive() do
			for k = 0, 2 do
				local r = ring(fx, GOLD, fx.ZIndex + 1)
				r.Position = UDim2.fromScale(0.5, 0.55)
				r.Size = UDim2.fromScale(0.15, 0.15)
				local st = r:FindFirstChildOfClass("UIStroke") :: UIStroke
				task.delay(k * 0.12, function()
					TweenService:Create(r, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1.1, 1.1) }):Play()
					TweenService:Create(st, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Transparency = 1, Thickness = 1 }):Play()
				end)
				task.delay(1, function()
					r:Destroy()
				end)
			end
			for _ = 1, 8 do
				local sp = img(fx, icon("sparkle"), fx.ZIndex + 2)
				sp.ImageColor3 = GOLD
				sp.SizeConstraint = Enum.SizeConstraint.RelativeYY
				sp.Size = UDim2.fromScale(0.09, 0.09)
				sp.Position = UDim2.fromScale(0.5, 0.55)
				local a = math.random() * math.pi * 2
				TweenService:Create(sp, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5 + math.cos(a) * 0.35, 0.55 + math.sin(a) * 0.35), ImageTransparency = 1, Rotation = 180 }):Play()
				task.delay(0.75, function()
					sp:Destroy()
				end)
			end
			task.wait(1.6)
		end
	end)
end

SCENES.abilitySkin = function(stage, fx, item, alive)
	local _, wm, cam = viewport(stage)
	local char, _, hum = cloneMe()
	if not char then
		return
	end
	char.Parent = wm
	play(hum :: Humanoid, AnimConfig.builtin and AnimConfig.builtin.Idle, true)
	cam.CFrame = CFrame.lookAt(Vector3.new(-3.5, 4.2, -14.5), Vector3.new(-2.6, 2.7, 0))
	-- the portal in the skin's colour: the Rift icon tinted, swirling and breathing behind / beside you
	local col = item.color or Color3.fromRGB(141, 75, 255)
	local p = img(fx, icon("ab_rift"), stage.ZIndex + 1) -- behind the character
	p.Parent = stage
	p.ImageColor3 = col:Lerp(Color3.new(1, 1, 1), 0.25)
	p.SizeConstraint = Enum.SizeConstraint.RelativeYY
	p.Position = UDim2.fromScale(0.68, 0.5)
	local glow = img(stage, icon("sparkle"), stage.ZIndex + 1)
	glow.ImageColor3 = col
	glow.SizeConstraint = Enum.SizeConstraint.RelativeYY
	glow.Position = p.Position
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not alive() then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		local open = math.clamp(t / 0.5, 0, 1)
		p.Rotation = -t * 120
		p.Size = UDim2.fromScale(0.78 * open * (1 + 0.05 * math.sin(t * 4)), 0.78 * open * (1 + 0.05 * math.sin(t * 4)))
		glow.Rotation = t * 60
		glow.Size = UDim2.fromScale(0.95 * open, 0.95 * open)
		glow.ImageTransparency = 0.55 + 0.2 * math.sin(t * 3)
	end)
end

SCENES.hatchFx = function(stage, fx, item, alive)
	local _, wm, cam = viewport(stage)
	cam.FieldOfView = 32
	task.spawn(function()
		while alive() do
			wm:ClearAllChildren()
			local egg = newEgg(false)
			if not egg then
				return
			end
			for _, d in egg:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			egg:PivotTo(CFrame.new(0, 1, 0))
			egg.Parent = wm
			local cf, size = egg:GetBoundingBox()
			cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, size.Y * 0.25, -size.Y * 3.2), cf.Position)
			-- shake, harder and harder
			local t0 = os.clock()
			while alive() and os.clock() - t0 < 1.4 do
				local k = (os.clock() - t0) / 1.4
				egg:PivotTo(CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.sin(os.clock() * 40) * 0.25 * k))
				RunService.RenderStepped:Wait()
			end
			if not alive() then
				return
			end
			-- the royal crack: gold flash, rays, sparkles
			egg:Destroy()
			flash(fx, GOLD, fx.ZIndex, 0.5)
			local rays = img(fx, icon("sparkle"), fx.ZIndex + 1)
			rays.ImageColor3 = GOLD
			rays.SizeConstraint = Enum.SizeConstraint.RelativeYY
			rays.Position = UDim2.fromScale(0.5, 0.5)
			rays.Size = UDim2.fromScale(0.2, 0.2)
			TweenService:Create(rays, TweenInfo.new(1, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1.3, 1.3), Rotation = 90, ImageTransparency = 1 }):Play()
			local crown = img(fx, icon("crown"), fx.ZIndex + 2)
			crown.SizeConstraint = Enum.SizeConstraint.RelativeYY
			crown.Position = UDim2.fromScale(0.5, 0.5)
			crown.Size = UDim2.fromScale(0.1, 0.1)
			TweenService:Create(crown, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.5, 0.5) }):Play()
			task.wait(1.4)
			if crown.Parent then
				TweenService:Create(crown, TweenInfo.new(0.25), { ImageTransparency = 1 }):Play()
			end
			task.wait(0.3)
			rays:Destroy()
			crown:Destroy()
		end
	end)
end

-- ===== one card

local function artRect(card: GuiObject): (Vector2?, Vector2?)
	local box = card:FindFirstChild("ArtBox") :: GuiObject? -- Featured cards
	if box then
		return Vector2.new(box.Position.X.Offset, box.Position.Y.Offset), Vector2.new(box.Size.X.Offset, box.Size.Y.Offset)
	end
	local ic = card:FindFirstChild("Icon") :: GuiObject? -- Cosmetics cards: the icon's row, full card width
	if ic then
		local w = card.Size.X.Offset
		return Vector2.new(14, ic.Position.Y.Offset - 8), Vector2.new(w - 28, ic.Size.Y.Offset + 14)
	end
	return nil
end

local function attach(card: GuiObject, getItem: () -> any)
	if attached[card] then
		return
	end
	attached[card] = true
	local stage: Frame? = nil
	local token = 0
	local hovering = false
	local hidden: { [GuiObject]: boolean } = {}

	local function close()
		token += 1
		if stage then
			local s = stage
			stage = nil
			s:Destroy()
		end
		for g in hidden do
			g.Visible = true
		end
		table.clear(hidden)
	end

	local function open()
		local item = getItem()
		local scene = item and SCENES[item.kind]
		if not scene or stage or not card.Visible then
			return
		end
		local pos, size = artRect(card)
		if not pos then
			return
		end
		token += 1
		local my = token
		local function alive(): boolean
			return my == token and stage ~= nil and card.Visible and card.Parent ~= nil
		end
		local kind = KIND[item.kind] or { "violet", "" }
		local s = Instance.new("Frame")
		s.Name = "ItemPreview"
		s.BackgroundColor3 = Color3.fromRGB(18, 14, 36)
		s.ClipsDescendants = true
		s.ZIndex = 40
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = s
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(225, 225, 232)
		stroke.Thickness = 2
		stroke.Transparency = 0.25
		stroke.Parent = s
		local bd = Instance.new("ImageLabel")
		bd.Name = "Backdrop"
		bd.BackgroundTransparency = 1
		bd.Image = BACKDROP[kind[1]] or ""
		bd.ScaleType = Enum.ScaleType.Crop
		bd.Size = UDim2.fromScale(1, 1)
		bd.ZIndex = s.ZIndex
		bd.Parent = s
		local fx = Instance.new("Frame")
		fx.Name = "FX"
		fx.BackgroundTransparency = 1
		fx.Size = UDim2.fromScale(1, 1)
		fx.ZIndex = s.ZIndex + 4
		fx.Parent = s
		local cap = Instance.new("TextLabel")
		cap.Name = "Caption"
		cap.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
		cap.BackgroundTransparency = 0.25
		cap.AnchorPoint = Vector2.new(0.5, 1)
		cap.Position = UDim2.new(0.5, 0, 1, -8)
		cap.Size = UDim2.new(0.92, 0, 0, 22)
		cap.Font = Enum.Font.FredokaOne
		cap.TextColor3 = Color3.new(1, 1, 1)
		cap.TextSize = 14
		cap.Text = kind[2]
		cap.ZIndex = s.ZIndex + 8
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 8)
		cc.Parent = cap
		cap.Parent = s
		-- grow out of the icon
		local ic = card:FindFirstChild("Icon") :: GuiObject?
		local from = if ic then ic else nil
		s.Position = if from then UDim2.fromOffset(from.Position.X.Offset - from.AnchorPoint.X * from.Size.X.Offset, from.Position.Y.Offset - from.AnchorPoint.Y * from.Size.Y.Offset) else UDim2.fromOffset(pos.X, pos.Y)
		s.Size = if from then from.Size else UDim2.fromOffset(size.X, size.Y)
		s.Parent = card
		stage = s
		for _, n in { "Icon", "IconShadow" } do
			local g = card:FindFirstChild(n)
			if g and g:IsA("GuiObject") and g.Visible then
				hidden[g] = true
				g.Visible = false
			end
		end
		TweenService:Create(s, OPEN, { Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(size.X, size.Y) }):Play()
		if reduceEffects() then
			return -- the backdrop and caption only
		end
		local ok, err = pcall(scene, s, fx, item, alive)
		if not ok then
			warn("[ShopItemPreview] " .. tostring(item.id) .. ": " .. tostring(err))
		end
	end

	controls[card] = { open = open, close = close }
	card.MouseEnter:Connect(function()
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			return
		end
		hovering = true
		task.delay(DWELL, function()
			if hovering then
				open()
			end
		end)
	end)
	card.MouseLeave:Connect(function()
		hovering = false
		close()
	end)
	-- touch: tap the picture to open, tap again to flip back
	local ic = card:FindFirstChild("Icon") or card:FindFirstChild("ArtBox")
	if ic and ic:IsA("GuiObject") then
		ic.Active = true
		ic.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				if stage then
					close()
				else
					open()
				end
			end
		end)
	end
	card:GetPropertyChangedSignal("Visible"):Connect(function()
		if not card.Visible then
			close()
		end
	end)
	card.AncestryChanged:Connect(function()
		if not card:IsDescendantOf(game) then
			close()
			attached[card] = nil
			controls[card] = nil
		end
	end)
	-- the Shop closing hides its screen, not the card
	local screen = card:FindFirstAncestor("Shop")
	if screen and screen:IsA("GuiObject") then
		screen:GetPropertyChangedSignal("Visible"):Connect(function()
			if not screen.Visible then
				close()
			end
		end)
	end
	-- when touched while open, a tap elsewhere on the card (stage) closes it
	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and stage then
			local p = input.Position
			local a, sz = stage.AbsolutePosition, stage.AbsoluteSize
			local inside = p.X >= a.X and p.X <= a.X + sz.X and p.Y >= a.Y and p.Y <= a.Y + sz.Y
			if inside then
				close()
			end
		end
	end)
end

-- Royal Hatching in the real ceremony (UIController.showReveal calls this as the pet pops when t.royal):
-- the same gold flash, rays and crown the Shop preview shows, over the Hatch screen's pet picture
function ShopItemPreview.royalBurst(sc: Instance)
	local petImg = sc:FindFirstChild("Pet", true) :: GuiObject?
	if not petImg then
		return
	end
	local holder = petImg.Parent :: GuiObject
	local z = petImg.ZIndex
	local cx = petImg.Position.X.Offset + petImg.Size.X.Offset * (0.5 - petImg.AnchorPoint.X)
	local cy = petImg.Position.Y.Offset + petImg.Size.Y.Offset * (0.5 - petImg.AnchorPoint.Y)
	local d = math.max(petImg.Size.X.Offset, petImg.Size.Y.Offset)
	local function at(img: ImageLabel, size: number)
		img.Position = UDim2.fromOffset(cx, cy)
		img.Size = UDim2.fromOffset(size, size)
		img.Parent = holder
	end
	local glow = Instance.new("Frame")
	glow.BackgroundColor3 = GOLD
	glow.BackgroundTransparency = 0.2
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromOffset(cx, cy)
	glow.Size = UDim2.fromOffset(d * 0.4, d * 0.4)
	glow.ZIndex = z - 1
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(0.5, 0)
	gc.Parent = glow
	glow.Parent = holder
	TweenService:Create(glow, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(d * 2.2, d * 2.2), BackgroundTransparency = 1 }):Play()
	local rays = Instance.new("ImageLabel")
	rays.BackgroundTransparency = 1
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Image = icon("sparkle")
	rays.ImageColor3 = GOLD
	rays.ZIndex = z - 1
	at(rays, d * 0.5)
	TweenService:Create(rays, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(d * 2.4, d * 2.4), Rotation = 90, ImageTransparency = 1 }):Play()
	local crown = Instance.new("ImageLabel")
	crown.BackgroundTransparency = 1
	crown.AnchorPoint = Vector2.new(0.5, 0.5)
	crown.Image = icon("crown")
	crown.ZIndex = z + 2
	crown.Rotation = 18 -- tipped on the pet's top-right corner, clear of the title above
	crown.Position = UDim2.fromOffset(cx + d * 0.34, cy - d * 0.3)
	crown.Size = UDim2.fromOffset(d * 0.08, d * 0.08)
	crown.Parent = holder
	TweenService:Create(crown, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(d * 0.3, d * 0.3) }):Play()
	task.delay(3.5, function()
		TweenService:Create(crown, TweenInfo.new(0.4), { ImageTransparency = 1 }):Play()
	end)
	task.delay(4, function()
		glow:Destroy()
		rays:Destroy()
		crown:Destroy()
	end)
end

-- ===== storefront polish (Hunter 18 Oct: "Ensure it all looks premium ... a storefront where people would actually
-- want to buy"). All runtime, on the PlayerGui copy; UIController and WeaponShopUI are untouched.

-- the three Rift skins had one magenta icon between them: each card gets its own colour (Assets/Images/ShopRift)
ShopItemPreview.ICON_OVERRIDE = {
	fx_rift_void = "rbxassetid://126284765452940",
	fx_rift_inferno = "rbxassetid://98255317976812",
	fx_rift_frost = "rbxassetid://70566103479726",
}

local function recolourCard(card: Instance, id: string)
	local img = ShopItemPreview.ICON_OVERRIDE[id]
	if not img then
		return
	end
	for _, n in { "Icon", "IconShadow" } do
		local i = card:FindFirstChild(n)
		if i and i:IsA("ImageLabel") then
			i.Image = img
		end
	end
end

-- a small chip on each previewable card: HOVER TO PREVIEW (TAP TO PREVIEW on touch), like the pet cards' PREVIEW
local function previewChip(card: GuiObject)
	if card:FindFirstChild("PreviewChip") then
		return
	end
	local pos, size = artRect(card)
	if not pos or not size then
		return
	end
	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local chip = Instance.new("TextLabel")
	chip.Name = "PreviewChip"
	chip.BackgroundColor3 = Color3.fromRGB(14, 12, 24)
	chip.BackgroundTransparency = 0.15
	chip.AnchorPoint = Vector2.new(1, 1)
	chip.Position = UDim2.fromOffset(pos.X + size.X - 6, pos.Y + size.Y - 4)
	chip.Size = UDim2.fromOffset(if touch then 128 else 138, 26)
	chip.Font = Enum.Font.FredokaOne
	chip.Text = if touch then "TAP TO PREVIEW" else "HOVER TO PREVIEW"
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.TextSize = 14
	chip.ZIndex = 30
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = chip
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = Color3.fromRGB(225, 225, 232)
	st.Thickness = 1.5
	st.Transparency = 0.3
	st.Parent = chip
	chip.Parent = card
end

-- the Shop's six tabs: WeaponShopUI re-spaced them to 244 px, but the old tabs' On / Off halves stayed centred
-- for 290 px (23 px off) and their hover springs still pointed at the old spots (they jumped on hover)
local function tidyTabs(shop: Instance)
	local panel = shop:FindFirstChild("Panel", true)
	if not panel then
		return
	end
	for _, t in panel:GetChildren() do
		if t:IsA("GuiButton") and t.Name:sub(1, 3) == "Tab" then
			local w, h = t.Size.X.Offset, t.Size.Y.Offset
			for _, half in t:GetChildren() do
				if half:IsA("GuiObject") and (half.Name == "On" or half.Name == "Off") then
					half.AnchorPoint = Vector2.new(0.5, 0.5)
					half.Position = UDim2.fromOffset(w / 2, h / 2)
					if half:GetAttribute("JuiceRest") ~= nil then
						half:SetAttribute("JuiceRest", half.Position)
					end
				end
			end
			if t:GetAttribute("JuiceRest") ~= nil then
				t:SetAttribute("JuiceRest", t.Position)
			end
		end
	end
end

-- names that ran past their boxes ("Mythic Sword of the Earth", "LEGENDARY 3%"): shrink to fit, a frame after
-- the text is set (TextBounds updates a frame late). Phones cap text with Fit's UIFitCap; that wins.
local fitQueued = false
local function fitTexts(shop: Instance)
	if fitQueued then
		return
	end
	fitQueued = true
	task.defer(function()
		RunService.Heartbeat:Wait()
		fitQueued = false
		for _, d in shop:GetDescendants() do
			if d:IsA("TextLabel") and not d.TextScaled and d.AbsoluteSize.X > 4 and d.Text ~= "" and d.Name ~= "PreviewChip" then
				local w = d.TextBounds.X
				if w > d.AbsoluteSize.X + 1 then
					d.TextWrapped = false
					d.TextSize = math.max(8, math.floor(d.TextSize * d.AbsoluteSize.X / w))
				end
				-- text poking out of its card (the crate's "LEGENDARY 3%"): slide it back inside
				local card = d:FindFirstAncestor("CrateCard") :: GuiObject?
				if card and d:IsDescendantOf(card) and d.Parent == card and d:GetAttribute("Nudged") == nil then
					local over = (d.AbsolutePosition.X + d.AbsoluteSize.X / 2 + d.TextBounds.X / 2) - (card.AbsolutePosition.X + card.AbsoluteSize.X - 10)
					if d.TextXAlignment == Enum.TextXAlignment.Left then
						over = (d.AbsolutePosition.X + d.TextBounds.X) - (card.AbsolutePosition.X + card.AbsoluteSize.X - 10)
					end
					if over > 0 then
						local k = d.AbsoluteSize.X / math.max(d.Size.X.Offset, 1) -- screen px per design px
						d:SetAttribute("Nudged", true)
						d.Position = d.Position - UDim2.fromOffset(math.ceil(over / math.max(k, 0.01)), 0)
					end
				end
			end
		end
	end)
end

-- the Emotes tab's empty right half: your character doing the Legendary emotes, one after another, live
local SHOWCASE = { "e_dance", "honored_one", "floating_meditation", "shadow_step" }
local SHOW_EACH = 4.5 -- seconds per emote
local function emoteShowcase(shop: Instance)
	local card = shop:FindFirstChild("CrateCard", true) :: GuiObject?
	if not card or card:FindFirstChild("Showcase") or not card:FindFirstAncestor("PageEmotes") then
		return
	end
	local okE, EmoteConfig = pcall(require, Shared:FindFirstChild("EmoteConfig"))
	if not okE or not EmoteConfig then
		return
	end
	local w, h = card.Size.X.Offset, card.Size.Y.Offset
	-- the crate's text and buttons end ~1140 px in: the stage fills the rest
	local left = 1160
	local t = Instance.new("Frame")
	t.Name = "Showcase"
	t.BackgroundColor3 = Color3.fromRGB(18, 14, 36)
	t.ClipsDescendants = true
	t.Position = UDim2.fromOffset(left, 24)
	t.Size = UDim2.fromOffset(math.max(240, w - left - 24), h - 48)
	t.ZIndex = 6
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = t
	local st = Instance.new("UIStroke")
	st.Color = GOLD
	st.Thickness = 2.5
	st.Parent = t
	local bd = Instance.new("ImageLabel")
	bd.BackgroundTransparency = 1
	bd.Image = BACKDROP.violet
	bd.ScaleType = Enum.ScaleType.Crop
	bd.Size = UDim2.fromScale(1, 1)
	bd.ZIndex = 6
	bd.Parent = t
	local function label(name: string, y: number, size: number, color: Color3, anchorY: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, anchorY)
		l.Position = UDim2.new(0.5, 0, anchorY, y)
		l.Size = UDim2.new(1, -16, 0, size + 6)
		l.Font = Enum.Font.FredokaOne
		l.TextColor3 = color
		l.TextSize = size
		l.ZIndex = 9
		local s2 = Instance.new("UIStroke")
		s2.Thickness = 2.5
		s2.Parent = l
		l.Parent = t
		return l
	end
	label("Head", 10, 22, GOLD, 0).Text = "LEGENDARY PULLS"
	local nameL = label("EmoteName", -14, 26, Color3.new(1, 1, 1), 1)
	t.Parent = card
	local token = 0
	local function clear()
		token += 1
		local vf = t:FindFirstChild("Stage3D")
		if vf then
			vf:Destroy()
		end
	end
	local function fill()
		if t:FindFirstChild("Stage3D") then
			return
		end
		token += 1
		local my = token
		local _, wm, cam = viewport(t)
		local char, _, hum = cloneMe()
		if not char or not hum then
			return
		end
		char.Parent = wm
		cam.FieldOfView = 30
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 3.6, -17), Vector3.new(0, 2.9, 0)) -- room for arms out and floating poses
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		task.spawn(function()
			local k = 0
			local track: AnimationTrack? = nil
			while my == token do
				k = k % #SHOWCASE + 1
				local e = EmoteConfig.get(SHOWCASE[k])
				if e then
					nameL.Text = string.upper(e.name)
					local id = e.animId
					local anim = if type(id) == "string" and id ~= "" then (if id:find("rbxassetid") then id else "rbxassetid://" .. id) else nil
					if not anim then -- Studio: the clip only exists as a KeyframeSequence
						local lib = ReplicatedStorage:FindFirstChild("EOS_Emotes")
						local ks = lib and lib:FindFirstChild(e.id)
						if ks and ks:IsA("KeyframeSequence") then
							local okK, url = pcall(function()
								return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(ks)
							end)
							anim = if okK then url else nil
						end
					end
					if track then
						track:Stop(0.2)
					end
					if anim then
						local a = Instance.new("Animation")
						a.AnimationId = anim
						local okT, tr = pcall(function()
							return animator:LoadAnimation(a)
						end)
						if okT and tr then
							track = tr
							tr.Looped = true
							tr:Play(0.2)
						end
					end
				end
				task.wait(SHOW_EACH)
			end
		end)
	end
	local page = card:FindFirstAncestor("PageEmotes") :: GuiObject?
	local function check()
		local on = page ~= nil and page.Visible and (not shop:IsA("GuiObject") or (shop :: GuiObject).Visible)
		if on and not reduceEffects() then
			fill()
		else
			clear()
		end
	end
	if page then
		page:GetPropertyChangedSignal("Visible"):Connect(check)
	end
	if shop:IsA("GuiObject") then
		(shop :: GuiObject):GetPropertyChangedSignal("Visible"):Connect(check)
	end
	check()
end

local function polish(shop: Instance)
	tidyTabs(shop)
	pcall(emoteShowcase, shop)
	fitTexts(shop)
end

-- open / close a card's stage by hand (the hover does the same)
function ShopItemPreview.preview(card: Instance, on: boolean)
	local c = controls[card]
	if c then
		if on then
			c.open()
		else
			c.close()
		end
	end
end

-- HOS-INV-001: until your first Gem pack, every pack card wears a "FIRST BUY 2x" ribbon (the server doubles it)
local function gemBadges(shop: Instance, first: boolean)
	local packs = shop:FindFirstChild("Packs", true)
	if not packs then
		return
	end
	for i, pack in packs:GetChildren() do
		if pack:IsA("GuiObject") and pack.Name:match("^Pack%d") then
			local b = pack:FindFirstChild("FirstBuy") :: TextLabel?
			if first and not b then
				local idx = tonumber(pack.Name:match("%d+"))
				local def = idx and EconomyConfig.GEM_PACKS[idx]
				-- the HTML template PullsUITemplates.FirstBuy (UI/build_pulls.py first_buy)
				local T = ReplicatedStorage:FindFirstChild("PullsUITemplates")
				local tpl = T and T:FindFirstChild("FirstBuy")
				if tpl then
					local l = tpl:Clone() :: GuiObject
					l.Name = "FirstBuy"
					l.Position = UDim2.fromOffset(10, 4)
					l.ZIndex = 12
					local text = if def then ("FIRST BUY 2x  ·  %s GEMS"):format((tostring(def.gems * 2):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))) else "FIRST BUY 2x"
					for _, d in l:GetDescendants() do
						if d:IsA("TextLabel") and (d.Name == "RibbonText" or d.Name == "RibbonTextShadow") then
							d.Text = text
						end
					end
					l.Parent = pack
				end
			elseif b and not first then
				b:Destroy()
			end
		end
	end
end

function ShopItemPreview.init()
	task.spawn(function() local B = script.Parent:WaitForChild("PreviewBlend", 10) if B then require(B).watch() end end) -- HOS-FEAT-001: every preview fades into its frame
	task.spawn(function() -- the FIRST BUY 2x ribbons follow your save
		local Net = require(Shared:WaitForChild("Net"))
		Net.event("ProfileState").OnClientEvent:Connect(function(view)
			local sh = player.PlayerGui:FindFirstChild("EOSUI") and player.PlayerGui.EOSUI:FindFirstChild("Root")
			sh = sh and sh:FindFirstChild("Shop")
			if sh and type(view) == "table" and type(view.stats) == "table" then
				gemBadges(sh, (tonumber(view.stats.gemsPurchased) or 0) == 0)
			end
		end)
	end)
	local pg = player:WaitForChild("PlayerGui")
	local gui = pg:WaitForChild("EOSUI", 30)
	local root = gui and gui:WaitForChild("Root", 10)
	local shop = root and root:WaitForChild("Shop", 10)
	if not shop then
		return
	end
	local ok, a = pcall(require, gui:FindFirstChild("AssetIds"))
	assets = if ok then a else nil
	-- Featured: FeatA (this week's colourway) and FeatB (spotlight)
	for slot, key in { FeatA = "weekly", FeatB = "spotlight" } do
		local card = shop:FindFirstChild(slot, true)
		if card and card:IsA("GuiObject") then
			attach(card, function()
				return EconomyConfig.item(EconomyConfig.FEATURED[key])
			end)
			previewChip(card)
		end
	end
	-- Cosmetics: the runtime cards in PageItems.Row (Card_<item id>)
	local function watchRow(row: Instance)
		local function add(c: Instance)
			if c:IsA("GuiObject") and c.Name:sub(1, 5) == "Card_" then
				local id = c.Name:sub(6)
				attach(c, function()
					return EconomyConfig.item(id)
				end)
				previewChip(c)
				recolourCard(c, id)
				-- refreshShop sets the icon on every refresh: keep the skin's own colour
				local ic = c:FindFirstChild("Icon")
				if ic and ic:IsA("ImageLabel") and ShopItemPreview.ICON_OVERRIDE[id] then
					ic:GetPropertyChangedSignal("Image"):Connect(function()
						if ic.Image ~= ShopItemPreview.ICON_OVERRIDE[id] then
							recolourCard(c, id)
						end
					end)
				end
			end
		end
		for _, c in row:GetChildren() do
			add(c)
		end
		row.ChildAdded:Connect(add)
	end
	-- storefront polish: on every open and tab switch, after WeaponShopUI has mounted
	if shop:IsA("GuiObject") then
		shop:GetPropertyChangedSignal("Visible"):Connect(function()
			if shop.Visible then
				task.delay(0.05, polish, shop)
			end
		end)
	end
	for _, d in shop:GetDescendants() do
		if d:IsA("GuiObject") and d.Name:sub(1, 4) == "Page" then
			d:GetPropertyChangedSignal("Visible"):Connect(function()
				if d.Visible then
					fitTexts(shop)
				end
			end)
		end
	end
	task.delay(1, polish, shop)
	local page = shop:FindFirstChild("PageItems", true)
	if page then
		local row = page:FindFirstChild("Row")
		if row then
			watchRow(row)
		else
			page.ChildAdded:Connect(function(c)
				if c.Name == "Row" then
					watchRow(c)
				end
			end)
		end
	end
end

-- HOS-FEAT-001: a Featured v3 card (Controllers.FeaturedShopUI) gets the same stage, inside its own ArtBox
function ShopItemPreview.attachCard(card: GuiObject, id: string)
	attach(card, function()
		return EconomyConfig.item(id)
	end)
end
return ShopItemPreview
