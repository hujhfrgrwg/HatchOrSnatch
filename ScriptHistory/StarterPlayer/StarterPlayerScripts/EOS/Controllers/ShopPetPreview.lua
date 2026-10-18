--!strict
-- ShopPetPreview (client): hover a pet card on the Shop's Featured page (or tap its art on a touch screen) and the art box
-- tweens into a stage: the pet's own rig at its level in a ViewportFrame on a themed backdrop, cycling Idle -> move -> cast,
-- and on the cast beat the pet's own ability effect, HOS-SHOP-PREVIEW-001 (Hunter 17 Oct: "in our shop, if you hover over
-- the item, such as the bone dragon pet, it should tween in that frame to a viewport preview of the pet doing animations
-- or something on a backdrop"; 16:43 "shouldnt we try to find a way to showcase the ability vfx and effect").
--
--   ShopPetPreview.attach(card, itemId, level?)   -- Controllers.HalloweenShopUI.slots (one line), every refresh; idempotent
--
-- * ViewportFrames draw parts and skinned meshes but no ParticleEmitters, Beams or lights. The cast effect is the pet's
--   real summon template (ReplicatedStorage.VFX.<name>L<level>, the one its behaviour module fires at FLASH_AT): its parts
--   play inside the viewport through VFX.Emit, and every ParticleEmitter is re-drawn as ImageLabels over / under the
--   viewport from the emitter's own Texture, Color, Size, Transparency, Lifetime, Speed, SpreadAngle, Acceleration, Drag,
--   Rotation, flipbook, EmitDelay and EmitCount / EmitDuration. So each pet shows its own effect with nothing per pet to draw.
-- * The card keeps its size; title, ability and buy button never move. The tagline swaps for IDLE / MOVE / CAST chips.
-- * Reduce effects (Settings): the pet holds a still idle pose and there is no effect layer.
-- * Everything (viewport, rig, effect labels, connections) is destroyed when the card closes, hides or leaves the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContentProvider = game:GetService("ContentProvider")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))
local HalloweenShop = require(Shared:WaitForChild("HalloweenShop"))

local ShopPetPreview = {}

ShopPetPreview.TWEEN = 0.25 -- seconds, in and out (Quad Out)
ShopPetPreview.DWELL = 0.08 -- hover this long before it opens (sweeping the mouse across the row opens nothing)
ShopPetPreview.IDLE_SECONDS = 2.2
ShopPetPreview.MOVE_SECONDS = 2.2
ShopPetPreview.CAST_HOLD = 0.7 -- after the cast clip and its effect finish
ShopPetPreview.MAX_PER_EMITTER = 14
ShopPetPreview.MAX_LABELS = 60
ShopPetPreview.FLIPBOOK_PX = 1024 -- our flipbook sheets are 1024 px (an emitter can override with a FlipbookPx attribute)
ShopPetPreview.FX_SCALE = 0.5 -- effect sprites at this share of their in-match size: the card camera is close, the pet must stay readable
ShopPetPreview.FX_ALPHA = 0.9 -- and this much of their opacity
ShopPetPreview.timeScale = 1 -- the preview's clock (pet, effect and loop); lower it for slow-motion checks

-- backdrop images (HOS_ShopBackdrop_*.png; decal ids in docs/VFX-LEDGER.md) and the card colour they go with
ShopPetPreview.BACKDROP = {
	violet = "rbxassetid://126543247334245",
	orange = "rbxassetid://119860466123113",
	sky = "rbxassetid://98575396374871",
	lime = "rbxassetid://129629158117711",
}
ShopPetPreview.ACCENT = {
	violet = Color3.fromRGB(138, 90, 255),
	orange = Color3.fromRGB(255, 122, 26),
	sky = Color3.fromRGB(47, 180, 255),
	lime = Color3.fromRGB(120, 210, 50),
}
ShopPetPreview.THEME = { hwn_dragon = "violet", hwn_wraith = "orange", hwn_mummy = "sky", hwn_cat = "lime" }

-- per species: the move clip's chip name, and the two casts (Runner, Catcher): clip, effect template prefix (+ level), chip.
-- Mirrors each pet behaviour module's summon(); `fade` = the pet turns see-through after the flash (Invisibility).
-- A species not listed plays "Ability" with <template Prefix>Summon_L<level>.
type Cast = { clip: string, fx: string, label: string, fade: boolean? }
ShopPetPreview.CASTS = {
	["Bone Dragon"] = { move = "FLY", { clip = "Breath", fx = "DragonSummon_L", label = "BREATH" }, { clip = "Ability", fx = "DragonSummon_L", label = "SLAM" } },
	["Pumpkin Wraith"] = { move = "FLOAT", { clip = "Ability", fx = "WraithVanish_L", label = "VANISH", fade = true }, { clip = "Stalk", fx = "WraithStalk_L", label = "STALK" } },
	["Mummy"] = { move = "FLOAT", { clip = "Ability", fx = "MummySummon_L", label = "SHIELD" }, { clip = "Lash", fx = "MummySummon_L", label = "LASH" } },
	["Witch's Cat"] = { move = "FLY", { clip = "Ability", fx = "CatSummon_L", label = "CLONE" }, { clip = "Snare", fx = "CatSummon_L", label = "SNARE" } },
} :: { [string]: any }

type Card = {
	root: GuiObject, -- the template clone HalloweenShopUI positions
	inner: GuiObject, -- the frame holding ArtBox / Icon / Title ...
	id: string,
	level: number,
	hint: GuiObject?,
	orig: { { any } }?,
}
type View = {
	card: Card,
	stage: Frame,
	vp: ViewportFrame,
	back: Frame,
	front: Frame,
	chips: Frame?,
	conns: { RBXScriptConnection },
	tweens: { Tween },
	restore: { { any } },
	labels: { any },
	closing: boolean,
}

local cards: { [GuiObject]: Card } = {}
local view: View? = nil
local hoverCard: Card? = nil
local hoverSince = 0
local started = false
local preloaded: { [string]: boolean } = {}

local function reduceEffects(): boolean
	local ok, CameraFX = pcall(function()
		return require(script.Parent:FindFirstChild("CameraFX") :: ModuleScript) :: any
	end)
	return ok and CameraFX and CameraFX.reduceEffects == true
end

local function touchFirst(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function onScreen(g: GuiObject): boolean
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg or not g:IsDescendantOf(pg) then
		return false
	end
	local p: Instance? = g
	while p and p ~= pg do
		if p:IsA("GuiObject") and not p.Visible then
			return false
		elseif p:IsA("ScreenGui") and not p.Enabled then
			return false
		end
		p = p.Parent
	end
	return g.AbsoluteSize.X > 4
end

-- ============================================================ small pieces cloned from the card's own tags
-- (game code clones the card's template pieces rather than building a new look)
local function setTagText(tag: GuiObject, text: string)
	for _, d in tag:GetDescendants() do
		if d:IsA("TextLabel") then
			d.Text = text
			d.Size = UDim2.fromOffset(0, d.Size.Y.Offset)
			d.AutomaticSize = Enum.AutomaticSize.X
		end
	end
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Size = UDim2.fromOffset(0, tag.Size.Y.Offset)
	local pad = tag:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = tag
end

local function cloneTag(inner: GuiObject, text: string): GuiObject?
	local src = inner:FindFirstChild("RarityTag") :: GuiObject?
	if not src then
		return nil
	end
	local t = src:Clone()
	t.Visible = true
	setTagText(t, text)
	return t
end

local function ensureHint(c: Card)
	if c.hint and c.hint.Parent then
		return
	end
	local art = c.inner:FindFirstChild("ArtBox") :: GuiObject?
	local t = art and cloneTag(c.inner, if touchFirst() then "TAP TO PREVIEW" else "PREVIEW")
	if not art or not t then
		return
	end
	t.Name = "PreviewHint"
	t.AnchorPoint = Vector2.new(1, 1)
	t.Position = UDim2.fromOffset(art.Position.X.Offset + art.Size.X.Offset - 8, art.Position.Y.Offset + art.Size.Y.Offset - 8)
	t.ZIndex = 13
	t.Parent = c.inner
	c.hint = t
end

-- ============================================================ sequences
local function ns(seq: NumberSequence, t: number): number
	local k = seq.Keypoints
	for i = 1, #k - 1 do
		local a, b = k[i], k[i + 1]
		if t <= b.Time then
			local u = if b.Time > a.Time then (t - a.Time) / (b.Time - a.Time) else 0
			return a.Value + (b.Value - a.Value) * u
		end
	end
	return k[#k].Value
end

local function cs(seq: ColorSequence, t: number): Color3
	local k = seq.Keypoints
	for i = 1, #k - 1 do
		local a, b = k[i], k[i + 1]
		if t <= b.Time then
			local u = if b.Time > a.Time then (t - a.Time) / (b.Time - a.Time) else 0
			return a.Value:Lerp(b.Value, u)
		end
	end
	return k[#k].Value
end

local function rnd(r: NumberRange): number
	return r.Min + (r.Max - r.Min) * math.random()
end

local GRID = { [Enum.ParticleFlipbookLayout.Grid2x2] = 2, [Enum.ParticleFlipbookLayout.Grid4x4] = 4, [Enum.ParticleFlipbookLayout.Grid8x8] = 8 }

local function dirOf(e: ParticleEmitter, cf: CFrame): Vector3
	local d = e.EmissionDirection
	local axis = if d == Enum.NormalId.Top then Vector3.yAxis elseif d == Enum.NormalId.Bottom then -Vector3.yAxis
		elseif d == Enum.NormalId.Front then -Vector3.zAxis elseif d == Enum.NormalId.Back then Vector3.zAxis
		elseif d == Enum.NormalId.Right then Vector3.xAxis else -Vector3.xAxis
	local sx, sy = math.rad(e.SpreadAngle.X), math.rad(e.SpreadAngle.Y)
	local spread = CFrame.Angles((math.random() * 2 - 1) * sx, 0, (math.random() * 2 - 1) * sy)
	if math.abs(axis.Y) < 0.5 then
		spread = CFrame.Angles(0, (math.random() * 2 - 1) * sx, (math.random() * 2 - 1) * sy)
	end
	return cf:VectorToWorldSpace(spread:VectorToWorldSpace(axis))
end

-- ============================================================ the stage
local function tween(v: View, inst: Instance, props: { [string]: any }, t: number?)
	local tw = TweenService:Create(inst, TweenInfo.new(t or ShopPetPreview.TWEEN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	table.insert(v.tweens, tw)
	tw:Play()
	return tw
end

-- the card pieces the stage covers or replaces: fade them, remember them, put them back on close
local FADE_IMAGES = { "ArtBox", "Icon", "IconShadow" }
local FADE_TEXT = { "Tagline", "TaglineShadow" }
local RAISE = { RarityTag = true, EndsTag = true, NewTag = true, SwapTag = true, DropShadow = true }

-- the card's at-rest values, read once (on its first open, when it is surely at rest) and always restored to, so a
-- quick close / reopen in the middle of a tween can never leave the portrait or tagline faded
local function originals(c: Card): { { any } }
	if c.orig then
		return c.orig
	end
	local o = {}
	local inner = c.inner
	for _, n in FADE_IMAGES do
		local g = inner:FindFirstChild(n)
		if g and g:IsA("ImageLabel") then
			table.insert(o, { g, "ImageTransparency", g.ImageTransparency, 1 })
		end
	end
	for _, n in FADE_TEXT do
		local g = inner:FindFirstChild(n)
		if g and g:IsA("TextLabel") then
			table.insert(o, { g, "TextTransparency", g.TextTransparency, 1 })
			local st = g:FindFirstChildOfClass("UIStroke")
			if st then
				table.insert(o, { st, "Transparency", st.Transparency, 1 })
			end
		end
	end
	for _, g in inner:GetChildren() do
		if RAISE[g.Name] and g:IsA("GuiObject") then
			table.insert(o, { g, "ZIndex", g.ZIndex, g.ZIndex + 20 })
		end
	end
	c.orig = o
	return o
end

local function swapCard(v: View, open: boolean)
	for _, r in originals(v.card) do
		local inst, prop, rest, opened = r[1], r[2], r[3], r[4]
		if (inst :: Instance).Parent then
			local value = if open then opened else rest
			if prop == "ZIndex" then
				(inst :: any)[prop] = value
			else
				tween(v, inst, { [prop] = value }, if prop == "ImageTransparency" then nil else ShopPetPreview.TWEEN * 0.5)
			end
		end
	end
	if v.card.hint then
		v.card.hint.Visible = not open
	end
end

local function swapSurfaceAppearance(pet: Model)
	-- ViewportFrames don't draw SurfaceAppearance: move each look's colour map onto the mesh (PetPreview does the same)
	for _, d in pet:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			local mp = d.Parent
			if mp and mp:IsA("MeshPart") then
				local map = d:GetAttribute("ColorMap")
				if type(map) == "string" and map ~= "" then
					mp.TextureID = map
					mp.Color = Color3.new(1, 1, 1)
					if d.AlphaMode == Enum.AlphaMode.Transparency then
						mp.Transparency = math.max(mp.Transparency, 0.02)
					end
				end
			end
			d:Destroy()
		end
	end
end

local function fadePet(pet: Model, a: number)
	for _, d in pet:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "RootPart" then
			d.LocalTransparencyModifier = a
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = a
		end
	end
end

local function behaviourOf(species: string): any
	local ok, B = pcall(function()
		return require(script.Parent:FindFirstChild("PetBehaviors") :: ModuleScript) :: any
	end)
	return if ok and B then B.get(species) else nil
end

local function castsOf(species: string, pet: Model): (string, { Cast })
	local c = ShopPetPreview.CASTS[species]
	if c then
		return c.move, { c[1], c[2] }
	end
	local prefix = string.gsub(tostring(pet:GetAttribute("Prefix") or species), "_$", "")
	return "MOVE", { { clip = "Ability", fx = prefix .. "Summon_L", label = "ABILITY" } }
end

local function close(instant: boolean?)
	local v = view
	if not v or v.closing then
		if v and instant then
			v.stage:Destroy()
			view = nil
		end
		return
	end
	v.closing = true
	for _, c in v.conns do
		c:Disconnect()
	end
	v.conns = {}
	for _, tw in v.tweens do
		tw:Cancel()
	end
	v.tweens = {}
	for _, l in v.labels do
		l.gui:Destroy()
	end
	v.labels = {}
	if v.chips then
		v.chips:Destroy()
	end
	swapCard(v, false)
	local art = v.card.inner:FindFirstChild("ArtBox") :: GuiObject?
	if instant or not art or not onScreen(v.stage) then
		v.stage:Destroy()
		view = nil
		return
	end
	tween(v, v.stage, { Position = art.Position, Size = art.Size, BackgroundTransparency = 1 })
	tween(v, v.vp, { ImageTransparency = 1 })
	local bd = v.stage:FindFirstChild("Backdrop")
	if bd then
		tween(v, bd, { ImageTransparency = 1 })
	end
	local stroke = v.stage:FindFirstChildOfClass("UIStroke")
	if stroke then
		tween(v, stroke, { Transparency = 1 })
	end
	local stage = v.stage
	task.delay(ShopPetPreview.TWEEN + 0.02, function()
		stage:Destroy()
		if view == v then
			view = nil
		end
	end)
end
ShopPetPreview.close = close

local function open(c: Card)
	if view and view.card == c and not view.closing then
		return
	end
	close(true)
	local inner = c.inner
	local art = inner:FindFirstChild("ArtBox") :: GuiObject?
	local it = HalloweenShop.item(c.id)
	local species = it and it.species
	if not art or type(species) ~= "string" then
		return
	end
	local still = reduceEffects()
	local theme = ShopPetPreview.THEME[c.id] or "violet"
	local accent = ShopPetPreview.ACCENT[theme]

	local stage = Instance.new("Frame")
	stage.Name = "PreviewStage"
	stage.Position = art.Position
	stage.Size = art.Size
	stage.BackgroundColor3 = Color3.new(0, 0, 0)
	stage.BackgroundTransparency = 1
	stage.BorderSizePixel = 0
	stage.ClipsDescendants = true
	stage.ZIndex = 12
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = stage
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(225, 225, 232)
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = stage
	local bd = Instance.new("ImageLabel")
	bd.Name = "Backdrop"
	bd.BackgroundTransparency = 1
	bd.Size = UDim2.fromScale(1, 1)
	bd.ScaleType = Enum.ScaleType.Crop
	bd.Image = ShopPetPreview.BACKDROP[theme] or ShopPetPreview.BACKDROP.violet
	bd.ImageTransparency = 1
	bd.ZIndex = 1
	bd.Parent = stage
	local back = Instance.new("Frame")
	back.Name = "FxBack"
	back.BackgroundTransparency = 1
	back.Size = UDim2.fromScale(1, 1)
	back.ZIndex = 2
	back.Parent = stage
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Viewport"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.ImageTransparency = 1
	vp.Ambient = Color3.fromRGB(150, 145, 175)
	vp.LightColor = Color3.fromRGB(255, 248, 235)
	vp.LightDirection = Vector3.new(-0.5, -1, -0.6)
	vp.ZIndex = 3
	vp.Parent = stage
	local front = Instance.new("Frame")
	front.Name = "FxFront"
	front.BackgroundTransparency = 1
	front.Size = UDim2.fromScale(1, 1)
	front.ZIndex = 4
	front.Parent = stage
	stage.Parent = inner

	local v: View = { card = c, stage = stage, vp = vp, back = back, front = front, chips = nil, conns = {}, tweens = {}, restore = {}, labels = {}, closing = false }
	view = v

	-- the pet, at the size its summon effect was authored for
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	local B = behaviourOf(species)
	local scale = (B and B.SUMMON_SCALE) or 1.3
	local pet = PetModel.build(species, scale, c.level)
	swapSurfaceAppearance(pet)
	pet.Parent = world
	local home = CFrame.lookAt(Vector3.zero, Vector3.new(0.55, 0, -1)) -- models face -Z: toward the camera, three-quarter to screen left
	pet:PivotTo(home)
	local rig: any = nil
	pcall(function()
		if PetModel.isRigged(species) then
			rig = PetRig.new(pet, species)
		end
	end)
	local function has(n: string): boolean
		if not rig then
			return false
		end
		local ok, yes = pcall(function()
			return rig:has(n)
		end)
		return ok and yes == true
	end
	local function play(n: string, speed: number?)
		if rig and has(n) then
			pcall(function()
				rig:play(n, 0.2, speed or 1)
			end)
		end
	end
	play("Idle")
	if rig then
		rig:step(0)
	end
	local bcf, bsize = pet:GetBoundingBox()
	local h = math.max(bsize.Y, 1)
	local w = math.max(bsize.X, bsize.Z, 1)
	local tanH = math.tan(math.rad(cam.FieldOfView / 2))
	local dist = math.max((h * 1.7) / (2 * tanH), (w * 1.12) / (2 * tanH))
	local visH = 2 * dist * tanH
	local target = bcf.Position - Vector3.new(0, visH * 0.1, 0) -- pet sits in the upper middle, clear of the title band
	cam.CFrame = CFrame.lookAt(target + Vector3.new(0, h * 0.15, -dist), target)

	-- tween in
	local inTo = UDim2.fromOffset(10, 10)
	local inSize = UDim2.fromOffset(inner.Size.X.Offset - 20, 478) -- 10 px padding left / top / right, 6 px above the buy button
	tween(v, stage, { Position = inTo, Size = inSize, BackgroundTransparency = 0 })
	tween(v, stroke, { Transparency = 0.25 })
	tween(v, bd, { ImageTransparency = 0 })
	tween(v, vp, { ImageTransparency = 0 })
	swapCard(v, true)

	-- the IDLE / MOVE / CAST chips in the tagline's slot
	local moveName, casts = castsOf(species, pet)
	local chips: { GuiObject } = {}
	if not still then
		local row = Instance.new("Frame")
		row.Name = "PreviewClips"
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(0, 451)
		row.Size = UDim2.fromOffset(inner.Size.X.Offset, 34)
		row.ZIndex = 25
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Padding = UDim.new(0, 10)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = row
		for i, name in { "IDLE", moveName, casts[1].label } do
			local t = cloneTag(inner, name)
			if t then
				t.Name = "Clip" .. i
				t.Position = UDim2.new()
				t.LayoutOrder = i
				t.Parent = row
				chips[i] = t
			end
		end
		row.Parent = inner
		v.chips = row
	end
	local baseColour = (inner:FindFirstChild("RarityTag") :: Frame?) and (inner :: any).RarityTag.BackgroundColor3 or Color3.fromRGB(28, 28, 30)
	local function lightChip(i: number)
		for k, t in chips do
			t.BackgroundColor3 = if k == i then accent else baseColour
			for _, d in t:GetDescendants() do
				if d:IsA("TextLabel") and not string.find(d.Name, "Shadow$") then
					d.TextTransparency = if k == i then 0 else 0.3
				end
			end
		end
	end

	if still then
		return -- Reduce effects: the idle pose stays still, no effect layer, no camera motion
	end

	-- ============================================================ effect layer
	local function project(p: Vector3): (number, number, number)
		local q = cam.CFrame:PointToObjectSpace(p)
		local depth = -q.Z
		if depth < 0.05 then
			return -1, -1, depth
		end
		local aspect = math.max(vp.AbsoluteSize.X, 1) / math.max(vp.AbsoluteSize.Y, 1)
		local ny = q.Y / (depth * tanH)
		local nx = q.X / (depth * tanH * aspect)
		return 0.5 + nx * 0.5, 0.5 - ny * 0.5, depth
	end
	local petDepth = (cam.CFrame:PointToObjectSpace(bcf.Position)).Z * -1
	local petPx = 0

	local function spawnParticles(e: ParticleEmitter, n: number, at: CFrame)
		local tex = e.Texture
		local grid = GRID[e.FlipbookLayout]
		local px = (e:GetAttribute("FlipbookPx") :: number?) or ShopPetPreview.FLIPBOOK_PX
		for _ = 1, n do
			if #v.labels >= ShopPetPreview.MAX_LABELS then
				return
			end
			local life = rnd(e.Lifetime) / math.max(e.TimeScale, 0.05)
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Image = tex
			img.ZIndex = 1
			if grid then
				img.ImageRectSize = Vector2.new(px / grid, px / grid)
			end
			local p = {
				gui = img,
				e = e,
				pos = at.Position,
				vel = dirOf(e, at) * rnd(e.Speed) * ShopPetPreview.FX_SCALE,
				age = 0,
				life = math.max(life, 0.03),
				rot = rnd(e.Rotation),
				spin = rnd(e.RotSpeed),
				grid = grid,
				cell = px / (grid or 1),
				startFrame = if e.FlipbookStartRandom and grid then math.random(0, grid * grid - 1) else 0,
				rate = rnd(e.FlipbookFramerate),
			}
			table.insert(v.labels, p)
		end
	end

	local function updateParticles(dt: number)
		petPx = h * vp.AbsoluteSize.Y / (2 * petDepth * tanH)
		local keep = {}
		for _, p in v.labels do
			p.age += dt
			local e: ParticleEmitter = p.e
			if p.age >= p.life then
				p.gui:Destroy()
				continue
			end
			local k = p.age / p.life
			p.vel += e.Acceleration * ShopPetPreview.FX_SCALE * dt
			if e.Drag > 0 then
				p.vel *= math.exp(-e.Drag * dt)
			end
			p.pos += p.vel * dt
			p.rot += p.spin * dt
			local x, y, depth = project(p.pos)
			if depth <= 0.05 then
				p.gui.Visible = false
			else
				local size = ns(e.Size, k) * ShopPetPreview.FX_SCALE * (vp.AbsoluteSize.Y / (2 * depth * tanH))
				local col = cs(e.Color, k)
				if e.LightEmission > 0 then
					col = col:Lerp(Color3.new(1, 1, 1), 0.15 * e.LightEmission)
				end
				p.gui.Visible = true
				-- big sprites (flash, smoke, swirl) bloom behind the pet so it stays readable; small ones (embers, cinders) fly in front
				p.gui.Parent = if depth > petDepth + 0.4 or size > petPx * 0.45 then back else front
				p.gui.Position = UDim2.fromScale(x, y)
				p.gui.Size = UDim2.fromScale(size / math.max(vp.AbsoluteSize.X, 1), size / math.max(vp.AbsoluteSize.Y, 1))
				p.gui.Rotation = p.rot
				p.gui.ImageColor3 = col
				p.gui.ImageTransparency = 1 - (1 - math.clamp(ns(e.Transparency, k), 0, 1)) * ShopPetPreview.FX_ALPHA
				if p.grid then
					local frames = p.grid * p.grid
					local f: number
					local mode = e.FlipbookMode
					if mode == Enum.ParticleFlipbookMode.OneShot then
						f = math.floor(k * frames)
					elseif mode == Enum.ParticleFlipbookMode.PingPong then
						local m = math.floor(p.age * p.rate) % (2 * frames - 2)
						f = if m < frames then m else 2 * frames - 2 - m
					else
						f = math.floor(p.age * p.rate) + p.startFrame
					end
					f = math.clamp(f % frames, 0, frames - 1)
					p.gui.ImageRectOffset = Vector2.new((f % p.grid) * p.cell, (f // p.grid) * p.cell)
				end
			end
			table.insert(keep, p)
		end
		v.labels = keep
	end

	-- effect events run on the preview's own clock (so timeScale slows them with the pet)
	local clock = 0
	local events: { { at: number, run: () -> () } } = {}
	local function after(sec: number, run: () -> ())
		table.insert(events, { at = clock + sec, run = run })
	end
	local function runEvents()
		local i = 1
		while i <= #events do
			if events[i].at <= clock then
				local e = table.remove(events, i) :: any
				e.run()
			else
				i += 1
			end
		end
	end

	-- plays the cast effect from its template: parts inside the viewport (VFX.Emit), emitters re-drawn as UI
	local function playEffect(name: string)
		local folder = ReplicatedStorage:FindFirstChild("VFX")
		local template = folder and folder:FindFirstChild(name)
		if not template or not template:IsA("Model") then
			return
		end
		local cf, size = pet:GetBoundingBox()
		local at = CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.1, 0)) -- the summon's own spot
		local pivot = template:GetPivot()
		local visibleParts = false
		for _, d in template:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				visibleParts = true
			elseif d:IsA("ParticleEmitter") then
				local delay = tonumber(d:GetAttribute("EmitDelay")) or 0
				local count = tonumber(d:GetAttribute("EmitCount"))
				local duration = tonumber(d:GetAttribute("EmitDuration"))
				local parent = d.Parent
				local wp = if parent and parent:IsA("Attachment") then parent.WorldCFrame elseif parent and parent:IsA("BasePart") then parent.CFrame else pivot
				local local_ = pivot:ToObjectSpace(wp)
				local function burst(n: number)
					if view == v and not v.closing then
						spawnParticles(d, math.min(n, ShopPetPreview.MAX_PER_EMITTER), at * local_)
					end
				end
				if count then
					after(delay, function()
						burst(math.floor(count :: number))
					end)
				end
				if duration and d.Rate > 0 then
					local total = math.min(math.floor(d.Rate * duration), ShopPetPreview.MAX_PER_EMITTER)
					for i = 1, total do
						after(delay + duration * (i - 1) / total, function()
							burst(1)
						end)
					end
				end
			end
		end
		if visibleParts then
			pcall(function()
				local Emit = require(folder:FindFirstChild("Emit") :: ModuleScript) :: any
				Emit.play(template, at, { parent = world })
			end)
		end
	end

	-- ============================================================ the loop: idle -> move -> cast (Runner, then Catcher next lap)
	local phase, phaseT, lap = 1, 0, 0
	local castLen, flashed, faded, settled = 0, false, false, false
	local cast: Cast = casts[1]
	local intro = (B and B.INTRO) or 0.9
	local flashAt = (B and B.FLASH_AT) or 0.45
	lightChip(1)
	local function enter(n: number)
		phase, phaseT = n, 0
		if n == 1 then
			play("Idle")
		elseif n == 2 then
			play(if has("Walk") then "Walk" elseif has("Fly") then "Fly" elseif has("Hop") then "Hop" else "Idle")
		else
			lap += 1
			cast = casts[(lap - 1) % #casts + 1]
			if chips[3] then
				setTagText(chips[3], cast.label)
			end
			flashed, faded, settled = false, false, false
			local len = if rig and has(cast.clip) then rig:length(cast.clip) else intro
			if rig and has(cast.clip) then
				pcall(function()
					rig:play(cast.clip, 0.1, len / (intro * 0.8), 0)
				end)
			end
			castLen = intro + ShopPetPreview.CAST_HOLD + 0.6
		end
		lightChip(n)
	end
	table.insert(v.conns, RunService.RenderStepped:Connect(function(rawDt)
		if not onScreen(inner) then
			close(true)
			return
		end
		local dt = rawDt * ShopPetPreview.timeScale
		clock += dt
		runEvents()
		phaseT += dt
		if phase == 1 and phaseT >= ShopPetPreview.IDLE_SECONDS then
			enter(2)
		elseif phase == 2 and phaseT >= ShopPetPreview.MOVE_SECONDS then
			enter(3)
		elseif phase == 3 then
			if not flashed and phaseT >= flashAt then
				flashed = true
				playEffect(cast.fx .. c.level)
			end
			if cast.fade then
				local a = if phaseT < flashAt + 0.05 then 0 elseif phaseT < intro + 0.4 then math.min(1, (phaseT - flashAt - 0.05) / 0.2) * 0.85
					else math.max(0, 0.85 - (phaseT - intro - 0.4) / 0.3 * 0.85)
				fadePet(pet, a)
				faded = a > 0
			end
			if not settled and phaseT >= intro * 0.8 then
				settled = true
				play("Idle")
			end
			if phaseT >= castLen then
				if faded then
					fadePet(pet, 0)
				end
				enter(1)
			end
		end
		-- a gentle drift while moving (the camera never moves)
		local drift = if phase == 2 then math.sin(phaseT * 1.6) * 0.18 * h else 0
		pet:PivotTo(home + Vector3.new(drift, 0, 0))
		if rig then
			rig:step(dt)
		end
		updateParticles(dt)
	end))
end

-- ============================================================ input
local function cardAt(x: number, y: number): Card?
	for _, c in cards do
		if onScreen(c.inner) then
			local p, s = c.inner.AbsolutePosition, c.inner.AbsoluteSize
			if x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y then
				-- covered by something above it (a confirm popup)? the topmost GUI object here must be part of the card
				local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
				local list = pg and pg:GetGuiObjectsAtPosition(x, y - GuiService:GetGuiInset().Y) or {}
				for _, g in list do
					if g:IsDescendantOf(c.root) or g == c.root then
						return c
					end
					local covering = (g:IsA("ImageLabel") or g:IsA("ImageButton")) and g.ImageTransparency < 0.95
						or g.BackgroundTransparency < 0.95
					if covering then
						return nil
					end
				end
				return c
			end
		end
	end
	return nil
end

local function isButtonAt(c: Card, x: number, y: number): boolean
	for _, n in { "BtnRobux", "BtnPrice", "BtnPoor", "BtnOwned" } do
		local b = c.inner:FindFirstChild(n) :: GuiObject?
		if b and b.Visible then
			local p, s = b.AbsolutePosition, b.AbsoluteSize
			if x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y then
				return true
			end
		end
	end
	return false
end

local function start()
	if started then
		return
	end
	started = true
	-- mouse: hover (after a short dwell) opens, leaving closes
	RunService.Heartbeat:Connect(function()
		if next(cards) == nil then
			return
		end
		if view and not view.closing and not onScreen(view.card.inner) then
			close(true)
		end
		local t = UserInputService:GetLastInputType()
		if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.MouseWheel then
			return
		end
		local m = UserInputService:GetMouseLocation()
		local c = cardAt(m.X, m.Y)
		if c ~= hoverCard then
			hoverCard = c
			hoverSince = os.clock()
		end
		if c and (not view or view.card ~= c or view.closing) and os.clock() - hoverSince >= ShopPetPreview.DWELL then
			open(c)
		elseif not c and view and not view.closing then
			close()
		end
	end)
	-- touch: a tap (or press-and-hold) on the card flips it; tapping it again or another card flips back. Buy buttons
	-- are left alone so buying is always one tap.
	UserInputService.InputBegan:Connect(function(io)
		if io.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local inset = GuiService:GetGuiInset()
		local x, y = io.Position.X, io.Position.Y + inset.Y
		local c = cardAt(x, y)
		if not c then
			if view and not view.closing then
				close()
			end
			return
		end
		if isButtonAt(c, x, y) then
			return
		end
		if view and view.card == c and not view.closing then
			close()
		else
			open(c)
		end
	end)
end

function ShopPetPreview.attach(root: GuiObject, id: string, level: number?)
	local art = root:FindFirstChild("ArtBox", true)
	local inner = art and art.Parent
	if not inner or not inner:IsA("GuiObject") then
		return
	end
	local c = cards[root]
	if c then
		c.id = id
		c.level = math.clamp(math.floor(level or c.level), 1, 3)
	else
		c = { root = root, inner = inner, id = id, level = math.clamp(math.floor(level or 1), 1, 3), hint = nil, orig = nil }
		cards[root] = c
		root.Destroying:Connect(function()
			if view and view.card == c then
				close(true)
			end
			cards[root] = nil
		end)
	end
	ensureHint(c :: Card)
	local theme = ShopPetPreview.THEME[id]
	local img = theme and ShopPetPreview.BACKDROP[theme]
	if img and not preloaded[img] then
		preloaded[img] = true
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync({ img })
			end)
		end)
	end
	start()
end

return ShopPetPreview
