--!strict
-- PetShowcase (client), HOS-HWN-002 (Matthew, 18 Oct): "make one of the other pedestals be a pet cycling animation
-- of all our sellable halloween pets. Show what it does with the ability and different animations." On the Crown podium
-- (HOS-POD-001, placed by Matthew at the south end of the island).
--  * Any podium tagged HOS_PetShowcase cycles the Halloween shop's pets (HalloweenShop.PETS, minus any whose sale window
--    has closed) on its StandGlow.RigStand, facing the way the podium's Dummy faces. The Dummy stays in the place to mark
--    the spot in Studio; this client takes it out.
--  * Each pet runs: idle, its move clip on a slow turn, hop, run on a faster turn, then its two casts with their real
--    match effects (ShopPetPreview.CASTS: the Runner cast, then the Catcher cast; the Jack-o'-Lantern turns see-through
--    on Vanish), then fades out for the next pet. Effects are the pets' own summon templates (ReplicatedStorage.VFX
--    <name>L1) played through VFX.Emit, scaled up with the pet (by the square root of its size); real particles.
--  * A sign above shows the pet's name in its rarity colour, what it's doing now ("AS RUNNER: VANISH" on a cast) and
--    "ON SALE <date>" for a pet whose sale hasn't started yet. (Matthew: no rarity / description line.)
--  * Looks only, nothing goes to the server. Rests while LobbyGate says the lobby isn't in use or you're far away;
--    Reduce effects (Settings) keeps the animations and drops the effects.
--   PetShowcase.start()   WeaponFXBoot, once

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))
local PetRig = require(Shared:WaitForChild("PetRig"))
local HalloweenShop = require(Shared:WaitForChild("HalloweenShop"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local LobbyGate = require(script.Parent:WaitForChild("LobbyGate")) -- HOS-LOBBY-004
local ShopPetPreview = require(script.Parent:WaitForChild("ShopPetPreview")) :: any -- its CASTS table (no side effects)

local PetShowcase = {}

local TAG = "HOS_PetShowcase"
local SCAN_EVERY = 1 -- seconds between looks for podiums and dummies (streaming can bring either back)
local PET_SCALE = 2.8 -- PetModel scale on the podium (about 3.5 studs tall)
local MAX_WIDTH = 5.6 -- studs: a wider pet (the Bone Dragon's wings) is built smaller to fit over the podium
local SUMMON_SCALE = 1.4 -- the pet scale the summon effects were authored at (PetBehaviors.SUMMON_SCALE)
local HOVER = 0.7 -- studs a flying / floating pet hovers above the stand
local SIGN_UP = 5.2 -- studs from the stand to the sign's middle
local FADE = 0.35 -- seconds to fade a pet in or out
local CAST_HOLD = 0.7 -- after a cast's clip and effect (as ShopPetPreview.CAST_HOLD)

-- the loop for each pet: kind, seconds (a cast's own length is worked out when it plays), turns made during it
local STEPS = {
	{ kind = "idle", secs = 2.0 },
	{ kind = "move", secs = 2.6, turns = 1 },
	{ kind = "hop", secs = 0 }, -- two hops, from the clip's length
	{ kind = "run", secs = 1.8, turns = 1 },
	{ kind = "idle", secs = 0.6 },
	{ kind = "cast", cast = 1 },
	{ kind = "idle", secs = 0.8 },
	{ kind = "cast", cast = 2 },
	{ kind = "idle", secs = 1.2 },
	{ kind = "out", secs = FADE },
}

type Show = {
	podium: Model,
	stand: CFrame?, -- the pet's home: feet on the stand, facing the lobby
	dummy: Model?,
	idx: number, -- which pet of the list
	pet: Model?,
	rig: any,
	item: any,
	species: string,
	fx: { [string]: Model }, -- the pet's effect templates, scaled to it
	fxScale: number,
	hover: number,
	step: number,
	t: number, -- seconds into the step
	len: number, -- the step's length
	yaw: number,
	flashed: boolean,
	settled: boolean,
	fadeIn: number, -- seconds into the fade-in (FADE = done)
	sign: BillboardGui?,
	anchor: BasePart?,
}

local shows: { [Model]: Show } = {}
local folder: Folder? = nil
local started = false

local function holder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "HOS_PetShowcase" -- this client's pets, signs and effects (never replicated)
	f.Parent = workspace
	folder = f
	return f
end

local function reduceEffects(): boolean
	local ok, CameraFX = pcall(function()
		return require(script.Parent:FindFirstChild("CameraFX") :: ModuleScript) :: any
	end)
	return ok and CameraFX and CameraFX.reduceEffects == true
end

-- the pets on show: the shop's list, without any whose sale window has already closed
local function petList(): { any }
	local now = HalloweenShop.now()
	local list = {}
	for _, it in HalloweenShop.PETS do
		if it.to == nil or now < it.to then
			table.insert(list, it)
		end
	end
	return list
end

local function castsOf(species: string): (string, { any })
	local c = ShopPetPreview.CASTS and ShopPetPreview.CASTS[species]
	if c then
		return c.move, { c[1], c[2] }
	end
	return "WALK", { { clip = "Ability", fx = "", label = "ABILITY" } }
end

local function fadePet(pet: Model, a: number)
	for _, d in pet:GetDescendants() do
		if (d:IsA("BasePart") and d.Name ~= "RootPart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = a
		end
	end
end

-- ===== the sign

local function label(parent: Instance, name: string, y: number, h: number, size: number): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0, y)
	t.Size = UDim2.fromScale(1, h)
	t.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold) -- the game's UI face
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.TextStrokeColor3 = Color3.fromRGB(20, 12, 30)
	t.Text = ""
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = size
	c.Parent = t
	t.Parent = parent
	return t
end

local function ensureSign(s: Show)
	if s.sign and s.sign.Parent then
		return
	end
	local stand = s.stand :: CFrame
	local a = Instance.new("Part")
	a.Name = "SignAnchor"
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.new(0.2, 0.2, 0.2)
	a.CFrame = stand + Vector3.new(0, SIGN_UP, 0)
	a.Parent = holder()
	local g = Instance.new("BillboardGui")
	g.Name = "PetShowcaseSign"
	g.Size = UDim2.fromScale(7, 2.1) -- studs: it shrinks with distance like the world
	g.LightInfluence = 0
	g.MaxDistance = 90
	g.ResetOnSpawn = false
	label(g, "PetName", 0, 0.44, 40)
	label(g, "Doing", 0.44, 0.33, 30)
	label(g, "Soon", 0.77, 0.23, 20)
	g.Adornee = a
	g.Parent = a
	s.anchor, s.sign = a, g
end

local function setSign(s: Show, doing: string?)
	local g = s.sign
	local it = s.item
	if not g or not it then
		return
	end
	local r = EconomyConfig.KNIFE_RARITY and EconomyConfig.KNIFE_RARITY[it.rarity]
	local name = g:FindFirstChild("PetName") :: TextLabel
	local now = g:FindFirstChild("Doing") :: TextLabel
	local soon = g:FindFirstChild("Soon") :: TextLabel
	name.Text = it.name
	name.TextColor3 = (r and r.color) or it.color or Color3.new(1, 1, 1)
	if doing then
		now.Text = doing
		now.TextColor3 = if string.find(doing, ":") then it.color or Color3.new(1, 1, 1) else Color3.fromRGB(235, 228, 245)
	end
	local t = HalloweenShop.now()
	soon.Text = if it.from and t < it.from then "ON SALE " .. string.upper(os.date("!%b %d", it.from)) else ""
end

-- ===== the pet

local function clearPet(s: Show)
	if s.pet then
		s.pet:Destroy()
	end
	for _, m in s.fx do
		m:Destroy()
	end
	s.pet, s.rig = nil, nil
	table.clear(s.fx)
end

local function has(s: Show, n: string): boolean
	local rig = s.rig
	if not rig then
		return false
	end
	local ok, yes = pcall(function()
		return rig:has(n)
	end)
	return ok and yes == true
end

local function play(s: Show, n: string, speed: number?)
	if has(s, n) then
		pcall(function()
			s.rig:play(n, 0.2, speed or 1)
		end)
	end
end

local function place(s: Show)
	local pet, stand = s.pet, s.stand
	if pet and stand then
		pet:PivotTo(stand * CFrame.Angles(0, s.yaw, 0) + Vector3.new(0, s.hover, 0))
	end
end

local function buildPet(s: Show)
	clearPet(s)
	local list = petList()
	if #list == 0 or not s.stand then
		return
	end
	s.idx = (s.idx - 1) % #list + 1
	local it = list[s.idx]
	s.item, s.species = it, it.species
	local scale = PET_SCALE
	local pet = PetModel.build(it.species, scale, 1)
	local _, size = pet:GetBoundingBox()
	if math.max(size.X, size.Z) > MAX_WIDTH then
		pet:Destroy()
		scale = PET_SCALE * MAX_WIDTH / math.max(size.X, size.Z)
		pet = PetModel.build(it.species, scale, 1)
	end
	pet.Name = "ShowcasePet"
	pet.Parent = holder()
	s.pet = pet
	pcall(function()
		if PetModel.isRigged(it.species) then
			s.rig = PetRig.new(pet, it.species)
		end
	end)
	local move = castsOf(it.species)
	s.hover = if move == "FLY" or move == "FLOAT" then HOVER else 0
	s.fxScale = math.sqrt(scale / SUMMON_SCALE) -- (in full proportion the effects swamp the podium and the sign)
	s.yaw = 0
	fadePet(pet, 1)
	s.fadeIn = 0
	place(s)
	ensureSign(s)
	s.step, s.t, s.len = 1, 0, STEPS[1].secs or 1
	play(s, "Idle")
	setSign(s, "IDLE")
	if s.rig then
		s.rig:step(0)
	end
end

-- one of the pet's cast effects, its summon template scaled to the pet, at the summon's own spot
local function playEffect(s: Show, name: string)
	if name == "" or reduceEffects() then
		return
	end
	local vfx = ReplicatedStorage:FindFirstChild("VFX")
	local tpl = s.fx[name]
	if not tpl then
		local src = vfx and vfx:FindFirstChild(name)
		if not src or not src:IsA("Model") then
			return
		end
		local copy = src:Clone()
		if math.abs(s.fxScale - 1) > 0.01 then
			copy:ScaleTo(copy:GetScale() * s.fxScale)
		end
		s.fx[name] = copy
		tpl = copy
	end
	local pet = s.pet
	if not pet or not vfx then
		return
	end
	local cf, size = pet:GetBoundingBox()
	local at = CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.1, 0))
	pcall(function()
		local Emit = require(vfx:FindFirstChild("Emit") :: ModuleScript) :: any
		Emit.play(tpl, at, { parent = holder() })
	end)
end

local function behaviour(species: string): any
	local ok, B = pcall(function()
		return require(script.Parent:FindFirstChild("PetBehaviors") :: ModuleScript) :: any
	end)
	return if ok and B then B.get(species) else nil
end

local function enter(s: Show, n: number)
	s.step, s.t = n, 0
	local step = STEPS[n]
	local move, casts = castsOf(s.species)
	if step.kind == "idle" then
		s.len = step.secs
		play(s, "Idle")
		setSign(s, "IDLE")
	elseif step.kind == "move" then
		s.len = step.secs
		play(s, if has(s, "Walk") then "Walk" elseif has(s, "Fly") then "Fly" else "Idle")
		setSign(s, move)
	elseif step.kind == "hop" then
		local l = if has(s, "Hop") then s.rig:length("Hop") else 0.6
		s.len = math.max(l, 0.4) * 2
		play(s, "Hop")
		setSign(s, "HOP")
	elseif step.kind == "run" then
		s.len = step.secs
		play(s, if has(s, "Run") then "Run" else "Walk", 1)
		setSign(s, "RUN")
	elseif step.kind == "cast" then
		local cast = casts[step.cast] or casts[1]
		local B = behaviour(s.species)
		local intro = (B and B.INTRO) or 0.9
		s.flashed, s.settled = false, false
		if has(s, cast.clip) then
			local l = s.rig:length(cast.clip)
			pcall(function()
				s.rig:play(cast.clip, 0.1, l / (intro * 0.8), 0)
			end)
		end
		s.len = intro + CAST_HOLD + 0.6
		setSign(s, (if step.cast == 1 then "AS RUNNER: " else "AS CATCHER: ") .. cast.label)
	elseif step.kind == "out" then
		s.len = step.secs
	end
end

local function update(s: Show, dt: number)
	local pet = s.pet
	if not pet then
		return
	end
	s.t += dt
	local step = STEPS[s.step]
	local _, casts = castsOf(s.species)
	-- fade in a new pet, out an old one
	if s.fadeIn < FADE then
		s.fadeIn = math.min(FADE, s.fadeIn + dt)
		fadePet(pet, 1 - s.fadeIn / FADE)
	end
	if step.kind == "out" then
		fadePet(pet, math.min(1, s.t / FADE))
	end
	-- turning while it moves (a full turn, ending facing the lobby again)
	if step.turns and s.len > 0 then
		s.yaw = 2 * math.pi * step.turns * math.min(1, s.t / s.len)
	else
		s.yaw = 0
	end
	if step.kind == "cast" then
		local cast = casts[step.cast] or casts[1]
		local B = behaviour(s.species)
		local intro = (B and B.INTRO) or 0.9
		local flashAt = (B and B.FLASH_AT) or 0.45
		if not s.flashed and s.t >= flashAt then
			s.flashed = true
			playEffect(s, cast.fx .. "1")
		end
		if cast.fade then
			local a = if s.t < flashAt + 0.05 then 0
				elseif s.t < intro + 0.4 then math.min(1, (s.t - flashAt - 0.05) / 0.2) * 0.85
				else math.max(0, 0.85 - (s.t - intro - 0.4) / 0.3 * 0.85)
			fadePet(pet, a)
		end
		if not s.settled and s.t >= intro * 0.8 then
			s.settled = true
			play(s, "Idle")
		end
	end
	-- a flying / floating pet bobs
	local bob = if s.hover > 0 then math.sin(os.clock() * 2.2) * 0.12 else 0
	local stand = s.stand :: CFrame
	pet:PivotTo(stand * CFrame.Angles(0, s.yaw, 0) + Vector3.new(0, s.hover + bob, 0))
	if s.rig then
		s.rig:step(dt)
	end
	if s.t >= s.len then
		if s.step == #STEPS then
			s.idx += 1
			buildPet(s)
		else
			if step.kind == "cast" and (casts[step.cast] or casts[1]).fade then
				fadePet(pet, 0)
			end
			enter(s, s.step + 1)
		end
	end
end

-- ===== podiums

-- the podium's stand and facing (the Dummy's, else toward the middle of the lobby), and the Dummy out of the world,
-- as they stream in
local function refresh(s: Show)
	local p = s.podium
	local dummy = p:FindFirstChild("Dummy")
	local dr = dummy and dummy:FindFirstChild("HumanoidRootPart")
	if not s.stand then
		local glow = p:FindFirstChild("StandGlow")
		local att = glow and glow:FindFirstChild("RigStand")
		local at = if att and att:IsA("Attachment") then att.WorldPosition
			elseif dr and dr:IsA("BasePart") then dr.Position - Vector3.new(0, 3, 0)
			else nil
		if at then
			local look = if dr and dr:IsA("BasePart") then dr.CFrame.LookVector else LobbyGate.centre() - at
			look = Vector3.new(look.X, 0, look.Z)
			s.stand = CFrame.lookAt(at, at + (if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)))
		end
	end
	if s.stand and dummy and dummy:IsA("Model") then
		s.dummy = dummy
		dummy.Parent = nil -- (this client only; the place keeps it)
	end
	if s.stand and not s.pet then
		buildPet(s)
	end
end

local function add(p: Instance)
	if not p:IsA("Model") or shows[p] then
		return
	end
	local s: Show = {
		podium = p, stand = nil, dummy = nil, idx = 1, pet = nil, rig = nil, item = nil, species = "", fx = {},
		fxScale = 1, hover = 0, step = 1, t = 0, len = 1, yaw = 0, flashed = false, settled = false, fadeIn = FADE,
		sign = nil, anchor = nil,
	}
	shows[p] = s
	refresh(s)
end

local function remove(p: Instance)
	local s = shows[p :: Model]
	if not s then
		return
	end
	shows[p :: Model] = nil
	clearPet(s)
	if s.anchor then
		s.anchor:Destroy()
	end
end

function PetShowcase.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	for _, p in CollectionService:GetTagged(TAG) do
		add(p)
	end
	local lastScan = os.clock()
	RunService.Heartbeat:Connect(function(dt)
		if not LobbyGate.active() then
			return -- HOS-LOBBY-004: rests in a match and while the camera is away from the lobby
		end
		local now = os.clock()
		if now - lastScan >= SCAN_EVERY then
			lastScan = now
			for _, p in CollectionService:GetTagged(TAG) do
				add(p)
			end
			for _, s in shows do
				refresh(s)
			end
		end
		for _, s in shows do
			local stand = s.stand
			if stand and LobbyGate.near(stand.Position, LobbyGate.ANIM_RANGE) then
				update(s, math.min(dt, 0.1))
			end
		end
	end)
end

return PetShowcase
