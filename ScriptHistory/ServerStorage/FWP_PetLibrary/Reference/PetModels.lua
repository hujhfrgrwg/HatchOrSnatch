--!strict
-- HOOKED-PETS-CORE-001: pet and egg models for the client (follow, Pets window, hatch reveal).
-- A pet uses its Blender prefab ReplicatedStorage.Prefabs.Pets.<PetId> when one exists (PrimaryPart
-- "Root" at the feet, facing -Z); until then a small voxel placeholder is built from PetConfig Look.
--
-- HOOKED-PETS-IMPORT-001: a prefab with an AnimationController/Animator and an "Animations" folder
-- (Animation instances Idle, Walk, Fish, Cheer) is an animated pet: its clone carries the attribute
-- Animated = true and is driven with PetModels.SetState / PetModels.Cheer. Hover is modelled into
-- the Blender pets, so a prefab only floats when it sets the FloatHeight attribute itself.
-- Phone budget (plan §1.8, Revision 2): plain SmoothPlastic/Neon colours only (no SurfaceAppearance,
-- no textures, no sounds), at most 15 parts, one small emitter for Epic and above, and every part is
-- non-colliding, non-queryable, non-touchable, shadowless and massless, welded to an anchored root
-- so moving the root moves the whole pet with no physics.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PetVariantData = require(ReplicatedStorage.Shared.Config.PetVariantData)

local PetModels = {}

local INK = Color3.fromRGB(22, 24, 32)
local WHITE = Color3.fromRGB(255, 255, 255)
local SKIN = Color3.fromRGB(255, 212, 168)
local WOOD = Color3.fromRGB(120, 78, 44)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function prep(p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.EnableFluidForces = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

local function darker(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local Builder = {}
Builder.__index = Builder

local function newBuilder(name: string, colors: { [string]: Color3 })
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CFrame = CFrame.new()
	prep(root)
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root
	return setmetatable({ Model = model, Root = root, Colors = colors, Count = 0 }, Builder)
end

-- Box of `size` centred at `pos` (studs, root space; the pet faces -Z).
function Builder:Box(size: Vector3, pos: Vector3, color: any, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = CFrame.new(pos) * (if props and props.Rot then props.Rot else CFrame.identity)
	p.Color = if typeof(color) == "Color3" then color else (self.Colors[color] or WHITE)
	p.Material = if props and props.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	if props and props.Transparency then
		p.Transparency = props.Transparency
	end
	prep(p)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = self.Root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = self.Model
	self.Count += 1
	return p
end

-- Two eyes on the front face at height y, depth z (front surface), spread = half distance apart.
function Builder:Eyes(y: number, z: number, spread: number, size: number?)
	local s = size or 0.26
	for _, side in ipairs({ -1, 1 }) do
		self:Box(Vector3.new(s, s * 1.15, 0.06), Vector3.new(side * spread, y, z - 0.02), WHITE)
		self:Box(Vector3.new(s * 0.5, s * 0.62, 0.05), Vector3.new(side * spread, y - s * 0.12, z - 0.06), INK)
	end
end

local RECIPES = {}

function RECIPES.Fisherman(b)
	b:Box(Vector3.new(0.45, 0.45, 0.55), Vector3.new(-0.28, 0.22, 0), darker(b.Colors.Body, 0.55))
	b:Box(Vector3.new(0.45, 0.45, 0.55), Vector3.new(0.28, 0.22, 0), darker(b.Colors.Body, 0.55))
	b:Box(Vector3.new(1.25, 0.95, 0.85), Vector3.new(0, 0.9, 0), "Body")
	b:Box(Vector3.new(1.1, 1.0, 1.0), Vector3.new(0, 1.85, 0), SKIN)
	b:Box(Vector3.new(1.55, 0.12, 1.45), Vector3.new(0, 2.38, 0), "Accent")
	b:Box(Vector3.new(1.0, 0.42, 0.95), Vector3.new(0, 2.62, 0.05), "Accent")
	b:Box(Vector3.new(0.09, 2.3, 0.09), Vector3.new(0.82, 1.55, -0.25), WOOD, { Rot = CFrame.Angles(math.rad(-22), 0, math.rad(-8)) })
	b:Eyes(1.9, -0.5, 0.24)
end

function RECIPES.Crab(b)
	b:Box(Vector3.new(1.7, 0.7, 1.25), Vector3.new(0, 0.5, 0), "Body")
	b:Box(Vector3.new(1.3, 0.2, 0.9), Vector3.new(0, 0.95, 0.05), darker(b.Colors.Body, 0.85))
	for _, side in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.6, 0.5, 0.55), Vector3.new(side * 1.12, 0.62, -0.5), "Body")
		b:Box(Vector3.new(0.22, 0.28, 0.3), Vector3.new(side * 1.12, 0.95, -0.62), "Accent")
		b:Box(Vector3.new(0.14, 0.45, 0.14), Vector3.new(side * 0.32, 1.05, -0.38), "Body")
		b:Box(Vector3.new(0.9, 0.14, 0.14), Vector3.new(side * 0.95, 0.18, 0.2), darker(b.Colors.Body, 0.6))
	end
	b:Eyes(1.33, -0.46, 0.32, 0.24)
end

function RECIPES.Frog(b)
	b:Box(Vector3.new(1.45, 0.8, 1.35), Vector3.new(0, 0.5, 0), "Body")
	b:Box(Vector3.new(1.0, 0.45, 0.08), Vector3.new(0, 0.45, -0.7), "Accent")
	for _, side in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.5, 0.42, 0.5), Vector3.new(side * 0.42, 1.05, -0.3), "Body")
		b:Box(Vector3.new(0.55, 0.18, 0.65), Vector3.new(side * 0.68, 0.09, -0.35), darker(b.Colors.Body, 0.75))
	end
	b:Box(Vector3.new(0.7, 0.06, 0.05), Vector3.new(0, 0.62, -0.7), INK)
	b:Eyes(1.08, -0.56, 0.42, 0.26)
end

function RECIPES.Puffer(b)
	b:Box(Vector3.new(1.4, 1.3, 1.4), Vector3.new(0, 0.75, 0), "Body")
	b:Box(Vector3.new(1.0, 0.5, 0.08), Vector3.new(0, 0.45, -0.72), "Accent")
	local spikes = {
		Vector3.new(0, 1.5, 0), Vector3.new(-0.78, 0.9, 0), Vector3.new(0.78, 0.9, 0),
		Vector3.new(0, 1.2, 0.72), Vector3.new(-0.5, 1.35, 0.4),
	}
	for _, pos in ipairs(spikes) do
		b:Box(Vector3.new(0.2, 0.2, 0.2), pos, darker(b.Colors.Body, 0.7))
	end
	b:Box(Vector3.new(0.2, 0.6, 0.45), Vector3.new(0, 0.8, 0.9), darker(b.Colors.Body, 0.85))
	b:Eyes(1.0, -0.7, 0.34, 0.3)
end

function RECIPES.Bird(b)
	b:Box(Vector3.new(1.0, 0.9, 1.25), Vector3.new(0, 0.8, 0.05), "Body")
	b:Box(Vector3.new(0.9, 0.8, 0.8), Vector3.new(0, 1.55, -0.3), "Body")
	b:Box(Vector3.new(0.34, 0.22, 0.42), Vector3.new(0, 1.42, -0.86), "Accent")
	for _, side in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.14, 0.62, 0.95), Vector3.new(side * 0.57, 0.9, 0.08), if b.Look.Kind == "Bird" and b.Look.Fire then "Accent" else darker(b.Colors.Body, 0.82))
		b:Box(Vector3.new(0.14, 0.34, 0.14), Vector3.new(side * 0.24, 0.18, -0.02), "Accent")
	end
	b:Box(Vector3.new(0.62, 0.2, 0.5), Vector3.new(0, 0.85, 0.85), "Accent")
	if b.Look.Hat then
		b:Box(Vector3.new(1.05, 0.12, 0.7), Vector3.new(0, 2.0, -0.3), INK)
		b:Box(Vector3.new(0.7, 0.3, 0.5), Vector3.new(0, 2.2, -0.3), INK)
	end
	b:Eyes(1.62, -0.7, 0.24, 0.22)
end

function RECIPES.Otter(b)
	b:Box(Vector3.new(1.0, 1.0, 1.35), Vector3.new(0, 0.6, 0.1), "Body")
	b:Box(Vector3.new(0.72, 0.62, 0.06), Vector3.new(0, 0.6, -0.58), "Accent")
	b:Box(Vector3.new(1.0, 0.9, 0.9), Vector3.new(0, 1.42, -0.32), "Body")
	b:Box(Vector3.new(0.6, 0.34, 0.2), Vector3.new(0, 1.25, -0.84), "Accent")
	b:Box(Vector3.new(0.2, 0.12, 0.06), Vector3.new(0, 1.38, -0.96), INK)
	for _, side in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.24, 0.24, 0.14), Vector3.new(side * 0.36, 1.92, -0.32), darker(b.Colors.Body, 0.8))
	end
	b:Box(Vector3.new(0.4, 0.3, 1.0), Vector3.new(0, 0.3, 1.2), darker(b.Colors.Body, 0.85))
	b:Eyes(1.6, -0.78, 0.26, 0.22)
end

function RECIPES.Koi(b)
	b:Box(Vector3.new(0.9, 0.9, 1.8), Vector3.new(0, 0.85, 0), "Body")
	b:Box(Vector3.new(0.94, 0.42, 0.55), Vector3.new(0, 1.12, -0.25), "Accent")
	b:Box(Vector3.new(0.94, 0.32, 0.4), Vector3.new(0, 0.72, 0.5), "Accent")
	b:Box(Vector3.new(0.16, 0.85, 0.6), Vector3.new(0, 0.95, 1.15), "Accent")
	for _, side in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.5, 0.1, 0.4), Vector3.new(side * 0.55, 0.55, -0.15), "Accent")
	end
	b:Eyes(1.0, -0.9, 0.28, 0.22)
end

function RECIPES.Hermit(b)
	b:Box(Vector3.new(1.25, 1.2, 1.2), Vector3.new(0, 1.0, 0.28), "Accent")
	b:Box(Vector3.new(1.3, 0.2, 1.25), Vector3.new(0, 1.62, 0.28), darker(b.Colors.Accent, 0.8))
	b:Box(Vector3.new(0.2, 0.5, 0.2), Vector3.new(0, 1.95, 0.28), Color3.fromRGB(230, 60, 60))
	b:Box(Vector3.new(0.95, 0.6, 0.8), Vector3.new(0, 0.35, -0.3), "Body")
	for _, side in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.42, 0.36, 0.42), Vector3.new(side * 0.62, 0.45, -0.72), "Body")
		b:Box(Vector3.new(0.12, 0.35, 0.12), Vector3.new(side * 0.24, 0.8, -0.55), "Body")
	end
	b:Eyes(1.05, -0.62, 0.24, 0.22)
end

function RECIPES.Narwhal(b)
	b:Box(Vector3.new(1.0, 0.9, 1.8), Vector3.new(0, 0.85, 0), "Body")
	b:Box(Vector3.new(0.9, 0.35, 1.5), Vector3.new(0, 0.5, -0.05), "Accent")
	b:Box(Vector3.new(0.14, 0.14, 1.1), Vector3.new(0, 1.05, -1.4), "Accent")
	b:Box(Vector3.new(1.05, 0.12, 0.42), Vector3.new(0, 0.9, 1.1), "Body")
	for _, side in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.5, 0.1, 0.32), Vector3.new(side * 0.62, 0.6, -0.2), darker(b.Colors.Body, 0.8))
	end
	b:Eyes(1.0, -0.9, 0.3, 0.2)
end

function RECIPES.Jelly(b)
	b:Box(Vector3.new(1.4, 0.9, 1.4), Vector3.new(0, 1.25, 0), "Body", { Transparency = 0.15 })
	b:Box(Vector3.new(1.0, 0.25, 1.0), Vector3.new(0, 1.8, 0), "Body", { Transparency = 0.15 })
	local legs = { Vector3.new(-0.42, 0.5, -0.42), Vector3.new(0.42, 0.5, -0.42), Vector3.new(-0.42, 0.5, 0.42), Vector3.new(0.42, 0.5, 0.42), Vector3.new(0, 0.42, 0) }
	for _, pos in ipairs(legs) do
		b:Box(Vector3.new(0.15, 0.85, 0.15), pos, "Accent", { Neon = true })
	end
	b:Eyes(1.28, -0.72, 0.3, 0.24)
end

function RECIPES.Kraken(b)
	b:Box(Vector3.new(1.4, 1.3, 1.3), Vector3.new(0, 1.25, 0), "Body")
	b:Box(Vector3.new(1.0, 0.3, 0.9), Vector3.new(0, 2.02, 0.05), darker(b.Colors.Body, 0.85))
	local legs = { Vector3.new(-0.5, 0.35, -0.4), Vector3.new(0.5, 0.35, -0.4), Vector3.new(-0.5, 0.35, 0.4), Vector3.new(0.5, 0.35, 0.4) }
	for _, pos in ipairs(legs) do
		b:Box(Vector3.new(0.32, 0.75, 0.32), pos, "Body")
		b:Box(Vector3.new(0.34, 0.2, 0.34), pos + Vector3.new(pos.X * 0.35, -0.32, pos.Z * 0.35), "Accent")
	end
	b:Eyes(1.35, -0.66, 0.34, 0.32)
end

function RECIPES.Leviathan(b)
	b:Box(Vector3.new(0.9, 0.8, 1.0), Vector3.new(0, 1.35, -0.6), "Body")
	b:Box(Vector3.new(0.8, 0.7, 0.7), Vector3.new(0, 1.0, 0.2), "Body")
	b:Box(Vector3.new(0.66, 0.58, 0.6), Vector3.new(0, 0.78, 0.8), "Body")
	b:Box(Vector3.new(0.5, 0.46, 0.5), Vector3.new(0, 0.9, 1.3), "Body")
	for _, z in ipairs({ -0.6, 0.2, 0.8 }) do
		b:Box(Vector3.new(0.1, 0.45, 0.45), Vector3.new(0, if z < 0 then 1.95 else 1.55 - z * 0.3, z), "Accent", { Neon = true })
	end
	for _, side in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.12, 0.35, 0.12), Vector3.new(side * 0.3, 1.9, -0.45), "Accent", { Neon = true })
	end
	b:Eyes(1.45, -1.1, 0.24, 0.22)
end

local function addEffects(model: Model, root: BasePart, rarity: string, look: any)
	local order = PetConfig.Rarities[rarity] and PetConfig.Rarities[rarity].Order or 1
	if order < PetConfig.Rarities.Epic.Order and not look.Fire then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PetSparkle"
	if look.Fire then
		emitter.Texture = FIRE
		emitter.Color = ColorSequence.new(look.Accent, look.Body)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		emitter.Lifetime = NumberRange.new(0.4, 0.7)
		emitter.Speed = NumberRange.new(1, 2)
		emitter.Rate = 8
	else
		emitter.Texture = SPARKLE
		emitter.Color = ColorSequence.new(PetConfig.Rarities[rarity].Light)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		emitter.Lifetime = NumberRange.new(0.6, 1)
		emitter.Speed = NumberRange.new(0.4, 1)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = if order >= PetConfig.Rarities.Legendary.Order then 8 else 5
	end
	emitter.LightEmission = 0.8
	emitter.LockedToPart = false
	-- the emitter sits on an invisible part at the pet's middle so particles surround the body
	local anchor = Instance.new("Attachment")
	anchor.Name = "FXAttachment"
	anchor.Position = Vector3.new(0, 1, 0)
	anchor.Parent = root
	emitter.Parent = anchor
end

local function placeholder(petId: string): Model?
	local pet = PetConfig.Pets[petId]
	if not pet then
		return nil
	end
	local look = pet.Look
	local b = newBuilder(petId, { Body = look.Body, Accent = look.Accent })
	b.Look = look
	local recipe = RECIPES[look.Kind] or RECIPES.Frog
	recipe(b)
	addEffects(b.Model, b.Root, pet.Rarity, look)
	b.Model:SetAttribute("Placeholder", true)
	return b.Model
end

local function prefabFolder(): Instance?
	local prefabs = ReplicatedStorage:FindFirstChild("Prefabs")
	return prefabs and prefabs:FindFirstChild("Pets")
end

-- HOOKED-PETS-VARIANTS-001: puts a pet model in a colour variant (1 = the pet as drawn). Works on a
-- model that is re-used (pools): tier 1 restores the pet's own colours. Three stars adds one small
-- sparkle emitter, named VariantSparkle, on the root (the follow code switches it off with the other
-- emitters on slow devices; viewports never draw particles). Placeholder pets have no variants.
function PetModels.SetVariant(model: Model, tier: any): number
	local petId = model:GetAttribute("PetId")
	local applied = 1
	-- HUGE_PETS_001: a pet with no variant data (the limited pets: one colour, their own texture sheet) keeps its
	-- texture; Apply would put the shared pet sheet on it
	if type(petId) == "string" and model:GetAttribute("Placeholder") ~= true and (PetVariantData.Pets :: any)[petId] ~= nil then
		applied = PetVariantData.Apply(model, petId, tonumber(tier))
	end
	local root = model.PrimaryPart
	local sparkle = root and root:FindFirstChild("VariantSparkle")
	if applied >= PetVariantData.MaxTier and root then
		if not sparkle then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "VariantSparkle"
			emitter.Texture = SPARKLE
			emitter.Rate = 5
			emitter.Lifetime = NumberRange.new(0.7, 1.1)
			emitter.Speed = NumberRange.new(0.6, 1.4)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 0) })
			emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
			emitter.Color = ColorSequence.new(PetConfig.Variants.Colors[3])
			emitter.LightEmission = 0.6
			emitter.Rotation = NumberRange.new(0, 360)
			emitter.RotSpeed = NumberRange.new(-90, 90)
			emitter.Acceleration = Vector3.new(0, 1.2, 0)
			emitter.EmissionDirection = Enum.NormalId.Top
			local height = tonumber(model:GetAttribute("Height")) or 2
			local at = Instance.new("Attachment")
			at.Name = "VariantSparkle"
			at.Position = Vector3.new(0, height * 0.55, 0)
			emitter.Parent = at
			at.Parent = root
		end
	elseif sparkle then
		sparkle:Destroy()
	end
	model:SetAttribute("VariantTier", applied)
	return applied
end

-- New model for a pet (caller owns it). Attributes: PetId, Float (hover studs), Height (studs).
-- `variant` (optional) = colour variant tier, applied with SetVariant.
function PetModels.Pet(petId: string, variant: any?): Model?
	local pet = PetConfig.Pets[petId]
	if not pet then
		return nil
	end
	local model: Model?
	local folder = prefabFolder()
	local prefab = folder and folder:FindFirstChild(petId)
	if prefab and prefab:IsA("Model") and prefab.PrimaryPart then
		model = prefab:Clone()
		for _, d in ipairs((model :: Model):GetDescendants()) do
			if d:IsA("BasePart") then
				local anchored = d == (model :: Model).PrimaryPart
				prep(d)
				d.Anchored = anchored
			end
		end
	else
		model = placeholder(petId)
	end
	if not model then
		return nil
	end
	local extents = model:GetExtentsSize()
	local fromPrefab = model:GetAttribute("Placeholder") ~= true
	model:SetAttribute("PetId", petId)
	model:SetAttribute("Float", if fromPrefab then tonumber(model:GetAttribute("FloatHeight")) or 0 else pet.Look.Float or 0)
	model:SetAttribute("Height", extents.Y)
	if fromPrefab then
		local controller = model:FindFirstChildOfClass("AnimationController")
		local animations = model:FindFirstChild("Animations")
		local animated = controller ~= nil and controller:FindFirstChildOfClass("Animator") ~= nil
			and animations ~= nil and animations:FindFirstChild("Idle") ~= nil
		model:SetAttribute("Animated", animated)
	end
	if variant ~= nil and (tonumber(variant) or 1) >= 2 then
		PetModels.SetVariant(model, variant)
	end
	return model
end

-- Loads one variant's texture ahead of showing it (the hatch reveal calls this while the egg cracks).
function PetModels.PreloadVariant(petId: string, tier: any)
	local variant = PetVariantData.Get(petId, tonumber(tier))
	if variant then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync({ variant.Texture })
			end)
		end)
	end
end

-- ---------------------------------------------------------------------------------------------
-- Animated prefab pets (Idle / Walk / Fish loop, Cheer plays once on top)
-- ---------------------------------------------------------------------------------------------

local FADE = 0.2
local animState = setmetatable({}, { __mode = "k" }) :: { [Model]: any }

local function animEntry(model: Model)
	if model:GetAttribute("Animated") ~= true then
		return nil
	end
	local entry = animState[model]
	if not entry then
		local controller = model:FindFirstChildOfClass("AnimationController")
		local animator = controller and controller:FindFirstChildOfClass("Animator")
		local folder = model:FindFirstChild("Animations")
		if not (animator and folder) then
			return nil
		end
		entry = { Animator = animator, Folder = folder, Tracks = {}, State = nil }
		animState[model] = entry
	end
	return entry
end

local function animTrack(entry, name: string): AnimationTrack?
	local track = entry.Tracks[name]
	if track then
		return track
	end
	local animation = entry.Folder:FindFirstChild(name)
	if not (animation and animation:IsA("Animation")) or animation.AnimationId == "" then
		return nil
	end
	-- LoadAnimation needs the model inside Workspace or a WorldModel; a failed load is retried on the next call
	local ok, loaded = pcall(function()
		return (entry.Animator :: Animator):LoadAnimation(animation)
	end)
	if not ok or not loaded then
		return nil
	end
	loaded.Looped = name ~= "Cheer" and name ~= "Hatch" -- one-shots: the pets' Cheer, an egg's Hatch
	entry.Tracks[name] = loaded
	return loaded
end

-- Switches the looping animation ("Idle" | "Walk" | "Fish"). `restart` replays it even when the state
-- did not change (a model that was hidden and shown again). Returns true when a track is playing.
function PetModels.SetState(model: Model, state: string, restart: boolean?): boolean
	local entry = animEntry(model)
	if not entry then
		return false
	end
	if entry.State == state and not restart then
		return true
	end
	local track = animTrack(entry, state) or animTrack(entry, "Idle")
	if not track then
		return false
	end
	for name, other in pairs(entry.Tracks) do
		if other ~= track and name ~= "Cheer" and other.IsPlaying then
			other:Stop(FADE)
		end
	end
	if restart or not track.IsPlaying then
		track:Play(FADE)
	end
	entry.State = state
	return true
end

-- Plays the one-shot Cheer over whatever is looping (hatch reveal, equip).
function PetModels.Cheer(model: Model): boolean
	local entry = animEntry(model)
	local track = entry and animTrack(entry, "Cheer")
	if not track then
		return false
	end
	track:Play(0.1)
	return true
end

-- The looping state last set on this model (nil for placeholders).
function PetModels.GetState(model: Model): string?
	local entry = animState[model]
	return entry and entry.State
end

local function eggPrefab(tier: string): Model?
	local prefabs = ReplicatedStorage:FindFirstChild("Prefabs")
	local folder = prefabs and prefabs:FindFirstChild("PetEggs")
	local prefab = folder and folder:FindFirstChild(tier)
	if prefab and prefab:IsA("Model") and prefab.PrimaryPart then
		local model = prefab:Clone()
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				local anchored = d == model.PrimaryPart
				prep(d)
				d.Anchored = anchored
			end
		end
		-- HATCH_CINEMATIC_001: a Blender egg with an AnimationController/Animator and an "Animations"
		-- folder (Idle, Wobble, Hatch) is an animated egg, driven like the pets (SetState) and by
		-- Controllers.Pets.HatchCinematic (the Hatch clip).
		local controller = model:FindFirstChildOfClass("AnimationController")
		local animations = model:FindFirstChild("Animations")
		model:SetAttribute("Animated", controller ~= nil and controller:FindFirstChildOfClass("Animator") ~= nil
			and animations ~= nil and animations:FindFirstChildOfClass("Animation") ~= nil)
		-- The light inside the shell (a Neon part named "Glow") stays hidden while the egg is closed
		-- (shelf, incubator, menu, HUD), so it never leaks through a seam; the hatch cinematic shows it.
		local glow = model:FindFirstChild("Glow", true)
		if glow and glow:IsA("BasePart") then
			glow.Transparency = 1
		end
		return model
	end
	return nil
end

-- Egg for a tier: the Blender prefab ReplicatedStorage.Prefabs.PetEggs.<Tier> when it exists (owner
-- 2026-09-30: the UI will use the Blender eggs; PrimaryPart "Root" at the bottom centre), otherwise a
-- voxel placeholder in the tier's colours.
function PetModels.Egg(tier: string): Model?
	local info = EggConfig.Tiers[tier]
	if not info then
		return nil
	end
	local prefab = eggPrefab(tier)
	if prefab then
		prefab:SetAttribute("EggTier", tier)
		prefab:SetAttribute("Height", prefab:GetExtentsSize().Y)
		return prefab
	end
	local b = newBuilder(tier .. "Egg", { Body = info.Color, Accent = info.Spots })
	local layers = {
		{ 1.3, 0.35, 0.18 }, { 1.75, 0.5, 0.6 }, { 1.9, 0.6, 1.15 },
		{ 1.7, 0.5, 1.7 }, { 1.3, 0.4, 2.15 }, { 0.8, 0.25, 2.45 },
	}
	for _, layer in ipairs(layers) do
		b:Box(Vector3.new(layer[1], layer[2], layer[1]), Vector3.new(0, layer[3], 0), "Body")
	end
	local glow = tier == "Golden" or tier == "Cosmic" or tier == "Royal" or tier == "Alien"
	local spots = {
		Vector3.new(0.5, 1.2, -0.96), Vector3.new(-0.45, 0.65, -0.88), Vector3.new(-0.2, 1.75, -0.86),
		Vector3.new(0.96, 0.9, 0.2), Vector3.new(-0.96, 1.35, -0.1), Vector3.new(0.3, 1.5, 0.9),
	}
	for _, pos in ipairs(spots) do
		local size = if math.abs(pos.X) > 0.9 then Vector3.new(0.06, 0.3, 0.3) else Vector3.new(0.3, 0.3, 0.06)
		b:Box(size, pos, "Accent", { Neon = glow })
	end
	b.Model:SetAttribute("EggTier", tier)
	b.Model:SetAttribute("Height", 2.6)
	return b.Model
end

-- Preload the pet and egg prefab meshes (and their texture) once, so a hatch reveal never shows an
-- empty stage on a phone (plan Revision 2: MeshLoad reports). The client asks for this when pets
-- unlock for the player, not at join: a new player in the tutorial downloads nothing. Animations are
-- left to load when first played.
local preloaded = false
function PetModels.Preload()
	if preloaded then
		return
	end
	preloaded = true
	local prefabs = ReplicatedStorage:FindFirstChild("Prefabs")
	local list = {}
	local seenClip = {}
	for _, name in ipairs({ "Pets", "PetEggs" }) do
		local folder = prefabs and prefabs:FindFirstChild(name)
		if folder then
			for _, d in ipairs(folder:GetDescendants()) do
				if d:IsA("MeshPart") then
					table.insert(list, d)
				elseif name == "PetEggs" and d:IsA("Animation") and d.AnimationId ~= "" and not seenClip[d.AnimationId] then
					-- PLAYTEST_FIXES_003: the eggs' Idle / Wobble / Hatch clips (three assets shared by
					-- every egg), so a first hatch never waits for its crack
					seenClip[d.AnimationId] = true
					table.insert(list, d)
				end
			end
		end
	end
	if #list == 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

return PetModels
