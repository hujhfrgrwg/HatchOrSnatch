--!nocheck
-- LastStanding (HOS-CINE-002, 17 Oct 2026): the "Last One Standing" moment. One Runner left: in the break
-- before their solo crossing the server sends LastStanding to every match player, and this plays a 3.4 s
-- cut-scene through Controllers/Cinematic, in the beat order of Hunter's reference clips:
--   0.0-1.2  slow push-in on the Runner (ends knees-up, left third); gold beam + ring; the name card (LS_Name)
--   1.2-2.2  low and wide on the Catcher wall, a slow pan; VS + "21 CATCHERS" (LS_Vs)
--   2.2-3.1  face-off from behind the Runner, creeping in; FACE OFF! + the line for your role (LS_FaceOff)
--   All inside Cinematic.COMFORT (gentle push-ins, no whips, no shake, a black dip on each cut).
--   3.1-3.4  bars out, your camera back, aimed at the finish (Catchers: at the Runner)
-- During that solo crossing a small pill "LAST ONE STANDING · <name>" sits at the top (it replaces the old
-- banner pop); the tension music is UIController's (RunnersLeft <= 2). Reduce effects = callout only.
-- Off switch: GameConfig.Cinematic.LAST_STANDING_ENABLED.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EOS = ReplicatedStorage:WaitForChild("EOS")
local GameConfig = require(EOS:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Net = require(EOS.Shared:WaitForChild("Net"))
local TextService = game:GetService("TextService")
local Cinematic = require(script.Parent.Cinematic)
local CameraFX = require(script.Parent.CameraFX)
local NpcSkins = require(script.Parent.NpcSkins)
local Sound = require(script.Parent.Sound)

local LastStanding = {}

local player = Players.LocalPlayer
local state = Net.state()
local UP = Vector3.yAxis

local TEX = {
	beam = "rbxassetid://93525054108814", -- av_beam_energy (AllVFX pack)
	ring = "rbxassetid://87500185897341", -- av_ring_glow
	glitter = "rbxassetid://117932483145389", -- av_glitter
}
local GOLD = Color3.fromRGB(255, 214, 64)

local COPY = {
	runner = "It's all on you. Make it across to win it for the Runners.",
	catcher = "Catch %s to win it for the Catchers.",
	other = "%s crosses alone. Can they make it?",
}

local last: any = nil -- the latest payload (the pill uses its name)

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function runnerRoot(t: any): BasePart?
	local model: Model? = nil
	if t.npcSlot then
		model = NpcSkins.modelForSlot(t.npcSlot)
	else
		local plr = Players:GetPlayerByUserId(t.userId)
		model = plr and plr.Character
	end
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function displayName(t: any): string
	return (t.npcSlot and NpcSkins.nameForSlot(t.npcSlot)) or t.name or "The last Runner"
end

-- ===== the beam, ring and sparkles on the Runner (local only, short and light) =====
local function spotlight(rootPos: () -> Vector3)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "EOS_LastStandingFX"
	local function ground(): Vector3
		return rootPos() - Vector3.new(0, 2.9, 0)
	end
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(ground())
	anchor.Parent = folder
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 70, 0)
	top.Parent = anchor
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, 70, 0) -- drops to the ground
	bottom.Parent = anchor
	local beams = {}
	for i, w in ipairs({ { 7, 5 }, { 2.4, 1.6 } }) do
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = top, bottom
		b.Texture = TEX.beam
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureSpeed = 0.8
		b.Color = ColorSequence.new(if i == 1 then GOLD else Color3.fromRGB(255, 246, 200))
		b.LightEmission = 1
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Width0, b.Width1 = w[1], w[2]
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.6, 0.25), NumberSequenceKeypoint.new(1, 0.1) })
		b.Segments = 4
		b.Parent = anchor
		table.insert(beams, b)
	end
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 14
	light.Brightness = 0
	light.Parent = bottom
	local rings = {}
	for i = 1, 2 do
		local r = Instance.new("Part")
		r.Name = "Ring" .. i
		r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch = true, false, false, false
		r.Transparency = 1
		r.Size = Vector3.new(2, 0.05, 2)
		local d = Instance.new("Decal")
		d.Face = Enum.NormalId.Top
		d.Texture = TEX.ring
		d.Color3 = GOLD
		d.Transparency = 1
		d.Parent = r
		r.Parent = folder
		rings[i] = { part = r, decal = d }
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = TEX.glitter
	sparks.Color = ColorSequence.new(GOLD)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0.6) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	sparks.Lifetime = NumberRange.new(0.6, 1)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Rate = 0
	sparks.Parent = bottom
	folder.Parent = cam -- under the camera: only this screen draws it

	-- follow the Runner while it lives
	local conn = RunService.RenderStepped:Connect(function()
		local g = ground()
		anchor.CFrame = CFrame.new(g)
		for _, r in ipairs(rings) do
			r.part.CFrame = CFrame.new(g + Vector3.new(0, 0.08, 0))
		end
	end)
	-- the drop
	TweenService:Create(bottom, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = Vector3.zero }):Play()
	task.delay(0.18, function()
		TweenService:Create(light, TweenInfo.new(0.08), { Brightness = 3 }):Play()
		sparks:Emit(16)
		for i, r in ipairs(rings) do
			task.delay((i - 1) * 0.22, function()
				r.decal.Transparency = 0
				r.part.Size = Vector3.new(2, 0.05, 2)
				TweenService:Create(r.part, TweenInfo.new(0.75, Enum.EasingStyle.Quart), { Size = Vector3.new(15, 0.05, 15) }):Play()
				TweenService:Create(r.decal, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			end)
		end
	end)
	-- fade out after the wide shot
	task.delay(1.15, function()
		for _, b in ipairs(beams) do
			local seq = b.Transparency
			local t0 = os.clock()
			task.spawn(function()
				while os.clock() - t0 < 0.35 and b.Parent do
					local k = (os.clock() - t0) / 0.35
					b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9 + 0.1 * k), NumberSequenceKeypoint.new(0.6, 0.25 + 0.75 * k), NumberSequenceKeypoint.new(1, 0.1 + 0.9 * k) })
					task.wait()
				end
			end)
			local _ = seq
		end
		TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0 }):Play()
	end)
	task.delay(1.7, function()
		conn:Disconnect()
		folder:Destroy()
	end)
end

-- ===== the three shots (Hunter's reference order; the review stills were captured with these exact CFrames) =====
-- rp() = the Runner's root position (live), catchersAt = the middle of the Catcher line, fwd() = the Runner's
-- forward (toward the Catchers). right = the Runner's right. All three follow the Runner every frame.
function LastStanding.shotsFor(rp: () -> Vector3, catchersAt: Vector3, fwd: () -> Vector3): { any }
	-- Comfort (Cinematic.COMFORT): FOV 50-70 at <= 12 deg/s, >= 6 studs from any character, <= 5 studs/s and 25 deg/s,
	-- eased in-out; a black dip on each cut. Every value here sits inside those limits (peak rates noted per shot).
	local ASPECT = 16 / 9
	local function basis()
		local f = fwd()
		return f, f:Cross(UP)
	end
	local function io(a: number): number
		return TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end
	-- sideways offset of the aim point that puts the subject on the left third at distance d with vertical FOV fov
	local function thirds(d: number, fov: number): number
		return d * math.tan(math.rad(fov / 2)) * ASPECT / 3
	end
	return {
		{ -- 1 (1.2 s): a slow dramatic push-in on the Runner from the front, a little low; ends knees-up, the Runner
			-- on the left third, the name beside them. 12 -> 8.5 studs (peak 4.6 studs/s), FOV 66 -> 57 (peak 11.8 deg/s)
			duration = 1.2,
			fov = { 66, 57 },
			cframe = function(a: number)
				local f, right = basis()
				local p = rp()
				local e = io(a)
				local d = 12 - 3.5 * e
				local fov = 66 - 9 * e
				local eye = p + f * d + UP * 0.1
				-- facing the Runner, their right is the camera's left: aim to their left so they sit on the left third
				return CFrame.lookAt(eye, p + UP * 0.9 - right * thirds(d, fov))
			end,
		},
		{ -- 2 (1.0 s): wide and low on the Catcher wall, a slow 2-stud pan (peak 3.1 studs/s), FOV 70
			duration = 1.0,
			fov = 70,
			cframe = function(a: number)
				local f, right = basis()
				local slide = -right * (1 - 2 * io(a))
				local eye = catchersAt - f * 13 + UP * -0.8 + slide
				return CFrame.lookAt(eye, catchersAt + UP * 0.9 + slide)
			end,
		},
		{ -- 3 (0.9 s): face-off from behind the Runner, creeping in 10 -> 9 studs (peak 1.7 studs/s), FOV 62 -> 59;
			-- the Runner on the left third, the Catcher wall ahead
			duration = 0.9,
			fov = { 62, 59 },
			cframe = function(a: number)
				local f, right = basis()
				local p = rp()
				local e = io(a)
				local d = 10 - e
				local fov = 62 - 3 * e
				local eye = p - f * d + right * thirds(d, fov) + UP * 1.6
				return CFrame.lookAt(eye, eye + f * 40 + UP * -1.0)
			end,
		},
	}
end

-- ===== the cards (roblox-ui-maker templates) =====
-- UI\build.py section "HOS-CINE-002" -> ui_laststanding/rbx.json -> ReplicatedStorage.LastStandingTemplates
-- (LS_Name, LS_Vs, LS_FaceOff, LS_Compact, LS_Pill) + StarterGui.LastStandingUI (Root + FitScale + UIKit).
-- Cards are cloned through UIKit and placed at their design spot inside Root (1920x1080 design, fitted to the
-- screen). Runtime changes to the imported templates (also in docs/HOS-CINE-002 Last One Standing.md):
--   * every card sits in a CanvasGroup wrapper so it fades as a whole (no per-child fades)
--   * names, the role plate and the pill re-fit around their real text (measured with TextService); long names
--     shrink to the column width; the role icon is swapped per role (runner / catcher / spectate)
--   * LS_Vs: VsTextBig.Rotation = -7 (the HTML tilt; the exporter drops it on an inline span)
--   * LastStandingUI: Enabled, DisplayOrder 55 (above the cut-scene bars at 50; Cinematic keeps it visible)
local DESIGN = Vector2.new(1920, 1080)
local TOP = { LS_Name = 119, LS_Vs = 105, LS_FaceOff = 143, LS_Compact = 166, LS_Pill = 0 } -- design y of each card
local NAME_COLUMN = { LS_Name = 900, LS_Compact = 1000 } -- widest the name may draw (design px)
local ROLE_ICON = { runner = "runner", catcher = "catcher", other = "spectate" }

local gui: ScreenGui? = nil
local root: Frame? = nil
local K: any = nil

local function fitRoot()
	if not gui or not root then
		return
	end
	local abs = gui.AbsoluteSize
	if abs.X < 2 or abs.Y < 2 then
		return
	end
	local s = math.min(abs.X / DESIGN.X, abs.Y / DESIGN.Y)
	local fs = root:FindFirstChild("FitScale") :: UIScale?
	if fs then
		fs.Scale = s
	end
	root:SetAttribute("TopOffset", (abs.Y - DESIGN.Y * s) / 2 / s) -- design px from the screen top to Root's top
end

local function ensureUI(): boolean
	if root and root.Parent and gui and gui.Parent then
		return true
	end
	gui = player:WaitForChild("PlayerGui"):WaitForChild("LastStandingUI", 10) :: ScreenGui?
	if not gui then
		warn("[LastStanding] PlayerGui.LastStandingUI missing (ServerStorage.LastStandingUIBuild.Builder.build())")
		return false
	end
	local g = gui :: ScreenGui
	g.DisplayOrder = 55
	g.Enabled = true
	root = g:WaitForChild("Root", 5) :: Frame?
	K = require(g:WaitForChild("UIKit") :: ModuleScript)
	K.init(g:GetAttribute("TemplatesFolder"), g:FindFirstChild("AssetIds"))
	g:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitRoot)
	fitRoot()
	return root ~= nil
end

local function textWidth(l: TextLabel, text: string?, size: number?): number
	local p = Instance.new("GetTextBoundsParams")
	p.Text = text or l.Text
	p.Font = l.FontFace
	p.Size = size or l.TextSize
	p.Width = 100000
	local ok, v = pcall(function()
		return TextService:GetTextBoundsAsync(p)
	end)
	return if ok then v.X else #(text or l.Text) * (size or l.TextSize) * 0.6
end

-- a label and its Shadow twin
local function setText(scope: Instance, name: string, text: string)
	for _, n in ipairs({ name, name .. "Shadow" }) do
		local l = scope:FindFirstChild(n, true)
		if l and l:IsA("TextLabel") then
			l.Text = text
		end
	end
end

-- the big name / title: re-centre its "<Name>Big" frame on the designed centre, wide enough for the text,
-- shrinking the text if it would pass maxW (design px)
local function fitBig(card: Instance, name: string, maxW: number)
	local big = card:FindFirstChild(name .. "Big", true) :: Frame?
	local label = big and big:FindFirstChild(name) :: TextLabel?
	if not big or not label then
		return
	end
	local scale = (big:FindFirstChildOfClass("UIScale") :: UIScale?)
	local s = if scale then scale.Scale else 1
	local cx = big.Position.X.Offset + big.Size.X.Offset * s / 2
	local w = textWidth(label)
	if w * s > maxW then
		local ts = math.max(8, math.floor(label.TextSize * maxW / (w * s)))
		for _, l in ipairs({ label, big:FindFirstChild(name .. "Shadow") }) do
			if l and l:IsA("TextLabel") then
				l.TextSize = ts
			end
		end
		w = textWidth(label)
	end
	local lw = math.ceil(w + 8)
	big.Size = UDim2.fromOffset(lw, big.Size.Y.Offset)
	big.Position = UDim2.fromOffset(math.floor(cx - lw * s / 2), big.Position.Y.Offset)
	for _, l in ipairs({ label, big:FindFirstChild(name .. "Shadow") }) do
		if l and l:IsA("GuiObject") then
			l.Size = UDim2.fromOffset(lw, l.Size.Y.Offset)
		end
	end
end

-- the role line: text + icon, the glass plate hugging the text, centred
local function fitRole(card: Instance, role: string, text: string)
	local holder = card:FindFirstChild("Role", true)
	local plate = holder and holder:FindFirstChild("Plate") :: Frame?
	local label = plate and plate:FindFirstChild("RoleText") :: TextLabel?
	if not holder or not plate or not label then
		return
	end
	setText(plate, "RoleText", text)
	for _, n in ipairs({ "Icon", "IconShadow" }) do
		local ic = plate:FindFirstChild(n)
		if ic then
			K.icon(ic, ROLE_ICON[role] or "runner")
		end
	end
	local padR = plate.Size.X.Offset - (label.Position.X.Offset + label.Size.X.Offset)
	local tw = math.ceil(textWidth(label) + 4)
	local w = label.Position.X.Offset + tw + math.max(padR, 20)
	for _, l in ipairs({ label, plate:FindFirstChild("RoleTextShadow") }) do
		if l and l:IsA("GuiObject") then
			l.Size = UDim2.fromOffset(tw, l.Size.Y.Offset)
		end
	end
	local x = math.floor((DESIGN.X - w) / 2)
	local dx = x - plate.Position.X.Offset
	plate.Size = UDim2.fromOffset(w, plate.Size.Y.Offset)
	plate.Position = UDim2.fromOffset(x, plate.Position.Y.Offset)
	local ring = plate:FindFirstChild("InnerRing") :: Frame?
	if ring then
		ring.Size = UDim2.fromOffset(w - 2 * ring.Position.X.Offset, ring.Size.Y.Offset)
	end
	local drop = holder:FindFirstChild("DropShadow") :: Frame?
	if drop then
		drop.Size = UDim2.fromOffset(w, drop.Size.Y.Offset)
		drop.Position = UDim2.fromOffset(drop.Position.X.Offset + dx, drop.Position.Y.Offset)
		local shape = drop:FindFirstChild("Shape") :: Frame?
		if shape then
			shape.Size = UDim2.fromOffset(w, shape.Size.Y.Offset)
		end
	end
end

-- the pill: crown, LEAD · VALUE laid out left to right, the glass hugging them, centred
local function fitPill(card: Instance, value: string)
	local p = card:FindFirstChild("Pill")
	local glass = p and p:FindFirstChild("Glass") :: Frame?
	if not p or not glass then
		return
	end
	setText(p, "NameText", value)
	local crown = p:FindFirstChild("Crown") :: GuiObject?
	local padL = (crown and crown.Position.X.Offset - glass.Position.X.Offset) or 8
	local gap = 12
	local parts = { "LeadText", "DotText", "NameText" }
	local widths, total = {}, 0
	for i, n in ipairs(parts) do
		local l = p:FindFirstChild(n) :: TextLabel?
		widths[i] = if l then math.ceil(textWidth(l) + 2) else 0
		total += widths[i] + (if i < #parts then gap else 0)
	end
	local crownW = if crown then crown.Size.X.Offset + 6 else 0
	local w = padL + crownW + total + 24
	local x0 = math.floor((DESIGN.X - w) / 2)
	local function move(o: Instance?, x: number, width: number?)
		if o and o:IsA("GuiObject") then
			o.Position = UDim2.fromOffset(x, o.Position.Y.Offset)
			if width then
				o.Size = UDim2.fromOffset(width, o.Size.Y.Offset)
			end
		end
	end
	move(glass, x0, w)
	local ring = glass:FindFirstChild("InnerRing") :: Frame?
	if ring then
		ring.Size = UDim2.fromOffset(w - 2 * ring.Position.X.Offset, ring.Size.Y.Offset)
	end
	local drop = p:FindFirstChild("DropShadow") :: Frame?
	if drop then
		move(drop, x0, w)
		local shape = drop:FindFirstChild("Shape") :: Frame?
		if shape then
			shape.Size = UDim2.fromOffset(w, shape.Size.Y.Offset)
		end
	end
	move(crown, x0 + padL)
	move(p:FindFirstChild("CrownShadow"), x0 + padL)
	local x = x0 + padL + crownW
	for i, n in ipairs(parts) do
		local l = p:FindFirstChild(n) :: TextLabel?
		if l then
			l.TextXAlignment = Enum.TextXAlignment.Left
			move(l, x, widths[i])
			local sh = p:FindFirstChild(n .. "Shadow") :: TextLabel?
			if sh then
				sh.TextXAlignment = Enum.TextXAlignment.Left
				move(sh, x, widths[i])
			end
		end
		x += widths[i] + gap
	end
end

-- a card: clone the template, wrap it for whole-card fades, put it at its design spot
local function card(name: string): (CanvasGroup?, Frame?)
	if not ensureUI() then
		return nil, nil
	end
	local t = K.template(name) :: Frame?
	if not t then
		return nil, nil
	end
	local wrap = Instance.new("CanvasGroup") -- runtime wrapper (no look of its own): fades the card as a whole
	wrap.Name = name
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y)
	wrap.GroupTransparency = 1
	wrap.Parent = root
	t.Position = UDim2.fromOffset(0, TOP[name] or 0)
	t.Parent = wrap
	return wrap, t
end

local function tween(o: Instance, secs: number, props: any, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(o, TweenInfo.new(secs, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- a "<Name>Big" frame's UIScale, multiplied by k (slam / punch-in)
local function bigScale(t: Instance, name: string): (UIScale?, number)
	local big = t:FindFirstChild(name .. "Big", true)
	local sc = big and big:FindFirstChildOfClass("UIScale")
	return sc, if sc then sc.Scale else 1
end

local function punch(sc: UIScale?, base: number, from: number, secs: number, overshoot: boolean?)
	if not sc then
		return
	end
	local v = Instance.new("NumberValue")
	v.Value = from
	sc.Scale = base * from
	v.Changed:Connect(function(x)
		sc.Scale = base * x
	end)
	local tw = tween(v, secs, { Value = 1 }, if overshoot then Enum.EasingStyle.Back else Enum.EasingStyle.Quad)
	tw.Completed:Connect(function()
		v:Destroy()
	end)
end

-- a banner wipes in from the left (a clipping holder grows over it)
local function wipe(banner: Frame?, secs: number)
	if not banner then
		return
	end
	local clip = Instance.new("Frame") -- runtime holder (no look): clips the banner while it wipes in
	clip.Name = banner.Name .. "Wipe"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Position = UDim2.fromOffset(banner.Position.X.Offset - 20, banner.Position.Y.Offset - 30)
	clip.Size = UDim2.fromOffset(0, banner.Size.Y.Offset + 60)
	clip.Parent = banner.Parent
	banner.Position = UDim2.fromOffset(20, 30)
	banner.Parent = clip
	tween(clip, secs, { Size = UDim2.fromOffset(banner.Size.X.Offset + 60, clip.Size.Y.Offset) }, Enum.EasingStyle.Quart)
end

local function spinRays(t: Instance, dir: number)
	local rays = t:FindFirstChild("Rays", true)
	local art = rays and rays:FindFirstChild("Art") :: ImageLabel?
	if not rays or not art then
		return
	end
	art.ImageTransparency = 1
	tween(art, 0.35, { ImageTransparency = 0 })
	tween(rays, 4, { Rotation = 50 * dir }, Enum.EasingStyle.Linear)
end

local shown: CanvasGroup? = nil
local function hideShown(instant: boolean?)
	local s = shown
	shown = nil
	if not s then
		return
	end
	if instant then
		s:Destroy()
		return
	end
	tween(s, 0.2, { GroupTransparency = 1 }).Completed:Connect(function()
		s:Destroy()
	end)
end

local function show(wrap: CanvasGroup?)
	hideShown(true)
	if wrap then
		shown = wrap
		wrap.GroupTransparency = 0
	end
end

-- the three cards, timed with the shots
local function nameCard(name: string)
	local wrap, t = card("LS_Name")
	if not wrap or not t then
		return
	end
	setText(t, "NameText", name)
	fitBig(t, "NameText", NAME_COLUMN.LS_Name)
	show(wrap)
	spinRays(t, 1)
	local sc, base = bigScale(t, "NameText")
	punch(sc, base, 2.4, 0.32, true) -- slam 2.4 -> 1 with overshoot
	wipe(t:FindFirstChild("Tag", true) :: Frame?, 0.22)
	Sound.play("impact")
	Sound.duck(0.35, 1.4)
end

local function vsCard(n: number)
	local wrap, t = card("LS_Vs")
	if not wrap or not t then
		return
	end
	setText(t, "CountText", ("%d CATCHER%s"):format(n, if n == 1 then "" else "S"))
	local big = t:FindFirstChild("VsTextBig", true) :: Frame?
	if big then
		big.Rotation = -7
	end
	show(wrap)
	spinRays(t, -1)
	local sc, base = bigScale(t, "VsText")
	punch(sc, base, 1.8, 0.16, true) -- a scale bounce only (no flash, no shake)
	task.delay(0.17, function()
		wipe(t:FindFirstChild("Count", true) :: Frame?, 0.2)
	end)
end

local function faceOffCard(role: string, line: string)
	local wrap, t = card("LS_FaceOff")
	if not wrap or not t then
		return
	end
	fitRole(t, role, line)
	show(wrap)
	local title = t:FindFirstChild("Title") :: Frame?
	if title then
		local y = title.Position.Y.Offset
		title.Position = UDim2.fromOffset(title.Position.X.Offset, y - 90)
		tween(title, 0.3, { Position = UDim2.fromOffset(title.Position.X.Offset, y) }, Enum.EasingStyle.Back)
	end
	local roleRow = t:FindFirstChild("Role") :: Frame?
	if roleRow then
		local y = roleRow.Position.Y.Offset
		roleRow.Position = UDim2.fromOffset(0, y + 30)
		task.delay(0.2, function()
			tween(roleRow, 0.22, { Position = UDim2.fromOffset(0, y) }, Enum.EasingStyle.Quart)
		end)
	end
end

-- Reduce effects: no camera, bars or dim; one compact card under the match Status that fades after ~2.5 s
local function compactCard(name: string, role: string, line: string)
	local wrap, t = card("LS_Compact")
	if not wrap or not t then
		return
	end
	setText(t, "NameText", name)
	fitBig(t, "NameText", NAME_COLUMN.LS_Compact)
	fitRole(t, role, line)
	if root then
		t.Position = UDim2.fromOffset(0, TOP.LS_Compact - (root:GetAttribute("TopOffset") or 0))
	end
	wrap.GroupTransparency = 1
	tween(wrap, 0.25, { GroupTransparency = 0 })
	Sound.play("impact")
	task.delay(2.5, function()
		if wrap.Parent then
			tween(wrap, 0.4, { GroupTransparency = 1 }).Completed:Connect(function()
				wrap:Destroy()
			end)
		end
	end)
end

-- ===== the cut-scene =====
local function play(t: any)
	if not GameConfig.Cinematic or not GameConfig.Cinematic.LAST_STANDING_ENABLED then
		return
	end
	if type(t) ~= "table" or typeof(t.pos) ~= "Vector3" or typeof(t.from) ~= "Vector3" then
		return
	end
	last = t
	local name = displayName(t)
	local rootPart = runnerRoot(t)
	local function rp(): Vector3
		if rootPart and rootPart.Parent then
			return rootPart.Position
		end
		return t.pos
	end
	local catchersAt: Vector3 = t.from
	-- the Runner faces the Catchers (and the finish beyond them)
	local function fwd(): Vector3
		local f = flat(catchersAt - rp())
		if f.Magnitude < 2 then
			f = flat((t.finish or catchersAt) - rp())
		end
		return if f.Magnitude > 0.01 then f.Unit else Vector3.xAxis
	end

	local you = t.userId == player.UserId
	local myRole = player:GetAttribute("EOS_Role")
	local role = if you then "runner" elseif myRole == "CATCHER" then "catcher" else "other"
	local line = if you then COPY.runner elseif role == "catcher" then COPY.catcher:format(name) else COPY.other:format(name)
	local n = tonumber(t.catchers) or 0

	if CameraFX.reduceEffects then
		compactCard(name, role, line)
		return
	end
	if not ensureUI() then
		return
	end
	local shots = LastStanding.shotsFor(rp, catchersAt, fwd)
	local after = if role == "catcher" then rp() else t.finish
	Cinematic.play({
		shots = shots,
		maxSeconds = GameConfig.Cinematic.MAX_SECONDS or 4,
		outro = 0.3,
		afterLook = after,
		keepGuis = if gui then { gui } else nil,
		onShot = function(i: number)
			if i == 1 then
				pcall(spotlight, rp)
				task.delay(0.25, function() -- once the bars are in
					if Cinematic.isPlaying() then
						nameCard(name)
					end
				end)
			elseif i == 2 then
				vsCard(n)
			elseif i == 3 then
				faceOffCard(role, line)
			end
		end,
		onEnd = function(reason: string)
			hideShown(reason ~= "done" and reason ~= "stopped")
		end,
	})
end

-- ===== the pill during a solo crossing =====
local pill: CanvasGroup? = nil

local function refreshPill()
	local lone = state:GetAttribute("LastStanding")
	local on = GameConfig.Cinematic and GameConfig.Cinematic.LAST_STANDING_ENABLED
		and state:GetAttribute("Phase") == "CROSSING" and lone ~= nil and player:GetAttribute("EOS_InMatch") == true
	if not on then
		if pill then
			local p = pill
			pill = nil
			tween(p, 0.2, { GroupTransparency = 1 }).Completed:Connect(function()
				p:Destroy()
			end)
		end
		return
	end
	if pill and pill.Parent then
		return
	end
	local name = nil
	if last and last.userId == lone then
		name = displayName(last)
	else
		local plr = Players:GetPlayerByUserId(lone)
		name = plr and plr.DisplayName
	end
	-- the first solo crossing names the Runner (after the cut-scene); later ones of the same match count crossings
	local first, wave = state:GetAttribute("LastStandingFirstWave"), state:GetAttribute("Wave")
	if type(first) == "number" and type(wave) == "number" and wave > first then
		name = "CROSSING " .. wave
	end
	local wrap, t = card("LS_Pill")
	if not wrap or not t then
		return
	end
	fitPill(t, name or "the last Runner")
	-- under the match Status at the top of the screen (Root is centred; this lifts the card to the screen top)
	if root then
		t.Position = UDim2.fromOffset(0, -(root:GetAttribute("TopOffset") or 0))
	end
	pill = wrap
	tween(wrap, 0.3, { GroupTransparency = 0 })
end

function LastStanding.init()
	Net.event("LastStanding").OnClientEvent:Connect(function(t)
		local ok, err = pcall(play, t)
		if not ok then
			warn("[LastStanding] " .. tostring(err))
			Cinematic.restore()
			hideShown(true)
		end
	end)
	state:GetAttributeChangedSignal("Phase"):Connect(refreshPill)
	state:GetAttributeChangedSignal("LastStanding"):Connect(refreshPill)
	player:GetAttributeChangedSignal("EOS_InMatch"):Connect(refreshPill)
	task.spawn(function()
		ensureUI()
		refreshPill()
	end)
end

-- Studio check: play it on yourself without a match (MCP eval on a client)
LastStanding._test = play
LastStanding._pill = refreshPill

return LastStanding
