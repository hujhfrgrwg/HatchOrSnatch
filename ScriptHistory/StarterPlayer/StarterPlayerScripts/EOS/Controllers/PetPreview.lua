--!strict
-- PetPreview (client): the Pets menu's "VIEW 3D" button. Clicking it swaps the selected pet's icon
-- for a live 3D view of YOUR avatar with that pet beside you (at its level), slowly turning; drag to
-- spin it. Nothing is built until the button is clicked, and it's all torn down when you click
-- again, pick another pet, or close the menu.
--   PetPreview.set(slot, species, level)  -- UIController calls this whenever the selection shows
--   PetPreview.close()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel"))

local PetPreview = {}

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local PET_SCALE: { [string]: number } = { Crow = 1.0, Kitsune = 1.25, ["Prism Chameleon"] = 1.2 }

type State = {
	slot: GuiObject?,
	species: string?,
	level: number,
	button: TextButton?,
	view: ViewportFrame?,
	conns: { RBXScriptConnection },
	open: boolean,
}
local st: State = { slot = nil, species = nil, level = 1, button = nil, view = nil, conns = {}, open = false }

local function disconnect()
	for _, c in st.conns do
		c:Disconnect()
	end
	st.conns = {}
end

local function setIconsVisible(on: boolean)
	local slot = st.slot
	if not slot then
		return
	end
	for _, d in slot:GetChildren() do
		if d:IsA("ImageLabel") and (d.Name == "Icon" or d.Name == "IconShadow") then
			d.Visible = on
		end
	end
end

local function refreshButton()
	local b = st.button
	if b then
		local label = b:FindFirstChild("Label") :: TextLabel?
		if label then
			label.Text = if st.open then "CLOSE" else "VIEW 3D"
		end
		b.BackgroundColor3 = if st.open then Color3.fromRGB(220, 70, 90) else Color3.fromRGB(70, 140, 255)
	end
end

-- your avatar, frozen as a plain model (no scripts, no tools), with its idle animation id
local function avatarCopy(): (Model?, string?)
	local char = Players.LocalPlayer.Character
	if not char then
		return nil, nil
	end
	local idleId: string? = nil
	local animate = char:FindFirstChild("Animate")
	local idle = animate and animate:FindFirstChild("idle")
	local a1 = idle and idle:FindFirstChildWhichIsA("Animation")
	if a1 then
		idleId = (a1 :: Animation).AnimationId
	end
	local was = char.Archivable
	char.Archivable = true
	local copy = char:Clone()
	char.Archivable = was
	if not copy then
		return nil, nil
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("BillboardGui") or d:IsA("Constraint") or d:IsA("BodyMover") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.LocalTransparencyModifier = 0
		end
	end
	local hrp = copy:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.Anchored = true
		hrp.Transparency = 1
	end
	local h = copy:FindFirstChildOfClass("Humanoid")
	if h then
		h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	return copy, idleId
end

local function build()
	local slot = st.slot
	local species = st.species
	if not slot or not species then
		return
	end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "PetPreview3D"
	vp.Size = UDim2.new(1, -16, 1, -16)
	vp.Position = UDim2.fromOffset(8, 8)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(170, 170, 185)
	vp.LightColor = Color3.fromRGB(255, 250, 240)
	vp.LightDirection = Vector3.new(-0.5, -1, -0.6)
	vp.ZIndex = (st.button and st.button.ZIndex or 10) - 1
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Parent = slot
	st.view = vp

	-- a turntable: everything sits on `pivot`, which spins
	local pivot = Instance.new("Model")
	pivot.Name = "Turntable"
	pivot.Parent = world
	local avatar, idleId = avatarCopy()
	local height = 5
	if avatar then
		avatar.Parent = pivot
		avatar:PivotTo(CFrame.new(-1.3, 0, 0))
		local cf, size = avatar:GetBoundingBox()
		height = size.Y
		avatar:PivotTo(avatar:GetPivot() + Vector3.new(0, size.Y / 2 - cf.Position.Y, 0))
		local h = avatar:FindFirstChildOfClass("Humanoid")
		if h and idleId then
			pcall(function()
				local animator = h:FindFirstChildOfClass("Animator") or Instance.new("Animator", h)
				local anim = Instance.new("Animation")
				anim.AnimationId = idleId :: string
				local track = (animator :: Animator):LoadAnimation(anim)
				track.Looped = true
				track:Play(0)
			end)
		end
	end
	local pet = PetModel.build(species, PET_SCALE[species] or 1.1, st.level)
	-- ViewportFrames don't draw SurfaceAppearance: move each look's colour map onto the mesh itself
	-- (templates carry it as a ColorMap attribute on each SurfaceAppearance; set in Studio)
	-- (a hair of Transparency lets the face decal's alpha cut out)
	for _, d in pet:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			local mp = d.Parent
			if mp and mp:IsA("MeshPart") then
				-- the colour map is copied to an attribute in Studio (scripts can't read ColorMap)
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
	pet.Parent = pivot
	pet:PivotTo(CFrame.new(1.6, 0, 0.2))
	local rig: any = nil
	local walkClip, idleClip = nil, "Idle"
	pcall(function()
		local mod = PetModel.rigModule(species)
		if mod then
			if not PetModel.isRigged(species) then
				return
			end
			rig = mod.new(pet, species)
			local function has(n: string): boolean
				if rig.has == nil then
					return n == "Walk" or n == "Idle" -- CrowRig: Idle, Walk, Fly, Swoop
				end
				local ok, yes = pcall(function()
					return rig:has(n)
				end)
				return ok and yes == true
			end
			for _, n in { "Walk", "Hop", "Run", "Fly" } do
				if has(n) then
					walkClip = n
					break
				end
			end
			if not has("Idle") then
				idleClip = walkClip or "Idle"
			end
		end
	end)
	local function play(name: string?, speed: number?)
		if rig and name then
			pcall(function()
				rig:play(name, 0.15, speed or 1)
			end)
		end
	end
	-- spin around the pair's own centre, and frame the whole pair (any yaw) with a little room
	local gcf, gsize = pivot:GetBoundingBox()
	local mid = Vector3.new(gcf.Position.X, 0, gcf.Position.Z)
	local homes: { [Model]: CFrame } = {}
	for _, m in pivot:GetChildren() do
		if m:IsA("Model") then
			homes[m] = m:GetPivot() - mid
		end
	end
	-- the pet's spot: beside you, facing the camera and turned a little toward you
	local petHome = CFrame.lookAt(homes[pet].Position, homes[pet].Position + Vector3.new(-0.35, 0, -1))
	homes[pet] = petHome
	local reach = math.max(gsize.X, gsize.Z) -- widest it gets while turning
	local h = math.max(gsize.Y, height)
	local fitH = (h / 2) / math.tan(math.rad(cam.FieldOfView / 2))
	local fitW = (reach / 2) / math.tan(math.rad(cam.FieldOfView / 2))
	local dist = math.max(fitH, fitW) * 0.98 + reach * 0.3
	local center = Vector3.new(0, h * 0.5, 0)
	cam.CFrame = CFrame.lookAt(center + Vector3.new(0, h * 0.1, -dist), center)

	-- walk-up: the pet comes in from behind your right side, walks to its spot, turns and settles
	local WALK = 1.3
	local from = petHome.Position + Vector3.new(3.4, 0, 2.6)
	local heading = (petHome.Position - from).Unit
	local t = 0
	play(walkClip or idleClip, 1.1)
	local arrived = false

	local yaw = 0
	local spinDelay = 0.6
	local dragging = false
	local lastX = 0
	table.insert(st.conns, vp.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			lastX = io.Position.X
		end
	end))
	table.insert(st.conns, UserInputService.InputChanged:Connect(function(io)
		if dragging and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
			yaw -= (io.Position.X - lastX) * 0.012
			lastX = io.Position.X
		end
	end))
	table.insert(st.conns, UserInputService.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
	table.insert(st.conns, RunService.RenderStepped:Connect(function(dt)
		t += dt
		local rot = CFrame.Angles(0, yaw, 0)
		for m, home in homes do
			if m ~= pet then
				m:PivotTo(rot * home)
			end
		end
		local petCF: CFrame
		if t < WALK then
			local u = t / WALK
			local e = u * u * (3 - 2 * u) -- ease in and out
			local p = from:Lerp(petHome.Position, e)
			petCF = CFrame.lookAt(p, p + heading)
		else
			if not arrived then
				arrived = true
				play(idleClip, 1)
			end
			-- turn from the walking heading to its spot's facing over a short beat
			local k = math.clamp((t - WALK) / 0.25, 0, 1)
			local face = CFrame.lookAt(petHome.Position, petHome.Position + heading)
			petCF = face:Lerp(petHome, k)
			if t > WALK + spinDelay and not dragging then
				yaw += dt * 0.5
			end
		end
		pet:PivotTo(rot * petCF)
		if rig then
			rig:step(dt)
		end
	end))
	-- the menu closed (or this slot went away): tear it down
	table.insert(st.conns, slot.AncestryChanged:Connect(function()
		if not slot:IsDescendantOf(Players.LocalPlayer.PlayerGui) then
			PetPreview.close()
		end
	end))
	local screen = slot:FindFirstAncestorWhichIsA("GuiObject")
	while screen and screen.Parent and screen.Parent:IsA("GuiObject") and screen.Name ~= "Pets" do
		screen = screen.Parent :: GuiObject
	end
	if screen then
		table.insert(st.conns, screen:GetPropertyChangedSignal("Visible"):Connect(function()
			if not screen.Visible then
				PetPreview.close()
			end
		end))
	end
	setIconsVisible(false)
end

function PetPreview.close()
	disconnect()
	if st.view then
		st.view:Destroy()
		st.view = nil
	end
	st.open = false
	setIconsVisible(true)
	refreshButton()
end

local function toggle()
	if st.open then
		PetPreview.close()
	else
		st.open = true
		refreshButton()
		build()
	end
end
PetPreview.toggle = toggle

local function ensureButton(slot: GuiObject)
	if st.button and st.button.Parent == slot then
		return
	end
	if st.button then
		st.button:Destroy()
	end
	local b = Instance.new("TextButton")
	b.Name = "BtnView3D"
	b.AutoButtonColor = true
	b.Text = ""
	b.Size = UDim2.fromOffset(112, 40)
	b.AnchorPoint = Vector2.new(1, 0)
	b.Position = UDim2.new(1, -12, 0, 12)
	b.BackgroundColor3 = Color3.fromRGB(70, 140, 255)
	b.ZIndex = 20
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(20, 22, 40)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = FONT
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "VIEW 3D"
	label.ZIndex = 21
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 7)
	pad.PaddingBottom = UDim.new(0, 7)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = label
	local ts = Instance.new("UIStroke")
	ts.Thickness = 2
	ts.Color = Color3.fromRGB(20, 22, 40)
	ts.Parent = label
	label.Parent = b
	b.Parent = slot
	b.Activated:Connect(toggle)
	st.button = b
end

-- the Pets menu shows `species` at `level` in `slot` (the square icon frame): add the button, and
-- drop any open 3D view if the selection changed
function PetPreview.set(slot: GuiObject?, species: string?, level: number?)
	if not slot then
		return
	end
	local lv = math.clamp(math.floor(level or 1), 1, 3)
	local changed = st.slot ~= slot or st.species ~= species or st.level ~= lv
	st.slot = slot
	ensureButton(slot)
	if changed then
		if st.open then
			PetPreview.close()
		end
		st.species = species
		st.level = lv
	end
	if st.button then
		st.button.Visible = species ~= nil and species ~= "" and species ~= "Pet"
	end
end

return PetPreview
