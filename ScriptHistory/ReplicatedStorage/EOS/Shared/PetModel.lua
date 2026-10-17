--!strict
-- PetModel: the launch pets as small voxel models built from Parts (stud style, no meshes).
-- Client-only uses: the owner's follower pet, the lobby pet display, ability summons and the
-- ViewportFrames in the incubator / pets screens. Never physical: anchored, no collision/query.
-- Model units: about 1 stud tall at scale 1 (the GDD keeps followers under 20% of avatar height).

local PetModel = {}

type Spec = { [number]: { any } } -- { name, size, pos, color, material?, rotDeg?, transparency? }

local BLACK = Color3.fromRGB(20, 20, 24)
local WHITE = Color3.fromRGB(245, 245, 245)

local function eyes(y: number, z: number, x: number?, size: number?): { { any } }
	local s = size or 0.08
	local ex = x or 0.12
	return {
		{ "EyeL", Vector3.new(s, s, 0.04), Vector3.new(-ex, y, z), BLACK },
		{ "EyeR", Vector3.new(s, s, 0.04), Vector3.new(ex, y, z), BLACK },
	}
end

local function join(...: { { any } }): { { any } }
	local out = {}
	for _, list in ipairs({ ... }) do
		for _, v in ipairs(list) do
			table.insert(out, v)
		end
	end
	return out
end

local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local FF = Enum.Material.ForceField

PetModel.SPECS = {
	-- Decoy family
	Mouse = join({
		{ "Body", Vector3.new(0.62, 0.46, 0.8), Vector3.new(0, 0.25, 0.05), Color3.fromRGB(168, 168, 180) },
		{ "Head", Vector3.new(0.46, 0.42, 0.42), Vector3.new(0, 0.5, -0.4), Color3.fromRGB(180, 180, 192) },
		{ "EarL", Vector3.new(0.26, 0.26, 0.06), Vector3.new(-0.2, 0.8, -0.38), Color3.fromRGB(255, 170, 196) },
		{ "EarR", Vector3.new(0.26, 0.26, 0.06), Vector3.new(0.2, 0.8, -0.38), Color3.fromRGB(255, 170, 196) },
		{ "Nose", Vector3.new(0.08, 0.08, 0.06), Vector3.new(0, 0.46, -0.64), Color3.fromRGB(255, 130, 170) },
		{ "Tail", Vector3.new(0.06, 0.06, 0.6), Vector3.new(0, 0.22, 0.72), Color3.fromRGB(255, 170, 196) },
	}, eyes(0.56, -0.62)),
	Parrot = join({
		{ "Body", Vector3.new(0.5, 0.56, 0.52), Vector3.new(0, 0.34, 0.04), Color3.fromRGB(64, 200, 96) },
		{ "Head", Vector3.new(0.42, 0.4, 0.4), Vector3.new(0, 0.78, -0.1), Color3.fromRGB(232, 64, 64) },
		{ "Beak", Vector3.new(0.16, 0.18, 0.18), Vector3.new(0, 0.72, -0.37), Color3.fromRGB(255, 204, 64) },
		{ "WingL", Vector3.new(0.08, 0.42, 0.46), Vector3.new(-0.29, 0.38, 0.06), Color3.fromRGB(60, 132, 240) },
		{ "WingR", Vector3.new(0.08, 0.42, 0.46), Vector3.new(0.29, 0.38, 0.06), Color3.fromRGB(60, 132, 240) },
		{ "Tail", Vector3.new(0.2, 0.06, 0.46), Vector3.new(0, 0.16, 0.42), Color3.fromRGB(60, 132, 240), nil, Vector3.new(-25, 0, 0) },
		{ "FeetL", Vector3.new(0.08, 0.1, 0.12), Vector3.new(-0.12, 0.03, -0.02), Color3.fromRGB(110, 110, 110) },
		{ "FeetR", Vector3.new(0.08, 0.1, 0.12), Vector3.new(0.12, 0.03, -0.02), Color3.fromRGB(110, 110, 110) },
	}, eyes(0.84, -0.31, 0.12)),
	["Mirror Dragon"] = join({
		{ "Body", Vector3.new(0.56, 0.5, 0.82), Vector3.new(0, 0.32, 0.05), Color3.fromRGB(146, 96, 226) },
		{ "Belly", Vector3.new(0.4, 0.06, 0.6), Vector3.new(0, 0.07, 0.05), Color3.fromRGB(214, 190, 255) },
		{ "Head", Vector3.new(0.42, 0.38, 0.48), Vector3.new(0, 0.66, -0.5), Color3.fromRGB(160, 112, 238) },
		{ "Snout", Vector3.new(0.28, 0.2, 0.2), Vector3.new(0, 0.6, -0.8), Color3.fromRGB(176, 130, 245) },
		{ "HornL", Vector3.new(0.07, 0.24, 0.07), Vector3.new(-0.12, 0.94, -0.42), Color3.fromRGB(230, 236, 255), NEON, Vector3.new(-20, 0, 0) },
		{ "HornR", Vector3.new(0.07, 0.24, 0.07), Vector3.new(0.12, 0.94, -0.42), Color3.fromRGB(230, 236, 255), NEON, Vector3.new(-20, 0, 0) },
		{ "WingL", Vector3.new(0.05, 0.5, 0.6), Vector3.new(-0.44, 0.62, 0.08), Color3.fromRGB(200, 220, 255), GLASS, Vector3.new(0, 0, 28), 0.2 },
		{ "WingR", Vector3.new(0.05, 0.5, 0.6), Vector3.new(0.44, 0.62, 0.08), Color3.fromRGB(200, 220, 255), GLASS, Vector3.new(0, 0, -28), 0.2 },
		{ "Tail", Vector3.new(0.18, 0.18, 0.56), Vector3.new(0, 0.24, 0.66), Color3.fromRGB(146, 96, 226) },
		{ "TailTip", Vector3.new(0.14, 0.14, 0.14), Vector3.new(0, 0.24, 0.98), Color3.fromRGB(230, 236, 255), NEON },
		{ "EyeL", Vector3.new(0.09, 0.07, 0.04), Vector3.new(-0.12, 0.72, -0.75), Color3.fromRGB(120, 240, 255), NEON },
		{ "EyeR", Vector3.new(0.09, 0.07, 0.04), Vector3.new(0.12, 0.72, -0.75), Color3.fromRGB(120, 240, 255), NEON },
	}),
	-- Scout family
	Sparrow = join({
		{ "Body", Vector3.new(0.46, 0.42, 0.52), Vector3.new(0, 0.27, 0.04), Color3.fromRGB(150, 108, 74) },
		{ "Belly", Vector3.new(0.34, 0.3, 0.06), Vector3.new(0, 0.25, -0.24), Color3.fromRGB(236, 214, 178) },
		{ "Head", Vector3.new(0.36, 0.34, 0.34), Vector3.new(0, 0.6, -0.08), Color3.fromRGB(124, 86, 58) },
		{ "Beak", Vector3.new(0.12, 0.1, 0.14), Vector3.new(0, 0.56, -0.31), Color3.fromRGB(70, 56, 40) },
		{ "WingL", Vector3.new(0.07, 0.3, 0.4), Vector3.new(-0.26, 0.3, 0.06), Color3.fromRGB(110, 76, 50) },
		{ "WingR", Vector3.new(0.07, 0.3, 0.4), Vector3.new(0.26, 0.3, 0.06), Color3.fromRGB(110, 76, 50) },
		{ "Tail", Vector3.new(0.18, 0.06, 0.32), Vector3.new(0, 0.18, 0.38), Color3.fromRGB(110, 76, 50), nil, Vector3.new(-20, 0, 0) },
	}, eyes(0.64, -0.26, 0.1)),
	Seagull = join({
		{ "Body", Vector3.new(0.48, 0.44, 0.66), Vector3.new(0, 0.3, 0.04), WHITE },
		{ "Head", Vector3.new(0.38, 0.36, 0.38), Vector3.new(0, 0.66, -0.16), WHITE },
		{ "Beak", Vector3.new(0.1, 0.12, 0.24), Vector3.new(0, 0.6, -0.44), Color3.fromRGB(255, 200, 60) },
		{ "WingL", Vector3.new(0.5, 0.06, 0.4), Vector3.new(-0.44, 0.44, 0.08), Color3.fromRGB(150, 160, 170), nil, Vector3.new(0, 0, 18) },
		{ "WingR", Vector3.new(0.5, 0.06, 0.4), Vector3.new(0.44, 0.44, 0.08), Color3.fromRGB(150, 160, 170), nil, Vector3.new(0, 0, -18) },
		{ "TipL", Vector3.new(0.14, 0.07, 0.4), Vector3.new(-0.72, 0.53, 0.08), BLACK, nil, Vector3.new(0, 0, 18) },
		{ "TipR", Vector3.new(0.14, 0.07, 0.4), Vector3.new(0.72, 0.53, 0.08), BLACK, nil, Vector3.new(0, 0, -18) },
		{ "Tail", Vector3.new(0.2, 0.06, 0.28), Vector3.new(0, 0.22, 0.46), Color3.fromRGB(220, 224, 228) },
	}, eyes(0.72, -0.35, 0.11)),
	["Celestial Owl"] = join({
		{ "Body", Vector3.new(0.58, 0.62, 0.5), Vector3.new(0, 0.36, 0.02), Color3.fromRGB(44, 56, 128) },
		{ "Face", Vector3.new(0.5, 0.36, 0.06), Vector3.new(0, 0.5, -0.25), Color3.fromRGB(70, 86, 170) },
		{ "EyeRingL", Vector3.new(0.2, 0.2, 0.04), Vector3.new(-0.12, 0.52, -0.29), WHITE },
		{ "EyeRingR", Vector3.new(0.2, 0.2, 0.04), Vector3.new(0.12, 0.52, -0.29), WHITE },
		{ "EyeL", Vector3.new(0.09, 0.09, 0.04), Vector3.new(-0.12, 0.52, -0.32), Color3.fromRGB(255, 214, 72), NEON },
		{ "EyeR", Vector3.new(0.09, 0.09, 0.04), Vector3.new(0.12, 0.52, -0.32), Color3.fromRGB(255, 214, 72), NEON },
		{ "Beak", Vector3.new(0.08, 0.1, 0.08), Vector3.new(0, 0.4, -0.31), Color3.fromRGB(255, 200, 80) },
		{ "TuftL", Vector3.new(0.1, 0.2, 0.08), Vector3.new(-0.2, 0.74, -0.06), Color3.fromRGB(44, 56, 128), nil, Vector3.new(0, 0, 18) },
		{ "TuftR", Vector3.new(0.1, 0.2, 0.08), Vector3.new(0.2, 0.74, -0.06), Color3.fromRGB(44, 56, 128), nil, Vector3.new(0, 0, -18) },
		{ "StarA", Vector3.new(0.07, 0.07, 0.07), Vector3.new(-0.2, 0.24, -0.27), Color3.fromRGB(255, 240, 160), NEON, Vector3.new(0, 0, 45) },
		{ "StarB", Vector3.new(0.06, 0.06, 0.06), Vector3.new(0.18, 0.16, -0.27), Color3.fromRGB(255, 240, 160), NEON, Vector3.new(0, 0, 45) },
		{ "WingL", Vector3.new(0.07, 0.46, 0.38), Vector3.new(-0.32, 0.34, 0.04), Color3.fromRGB(34, 44, 104) },
		{ "WingR", Vector3.new(0.07, 0.46, 0.38), Vector3.new(0.32, 0.34, 0.04), Color3.fromRGB(34, 44, 104) },
	}),
	-- Brake family
	Turtle = join({
		{ "Shell", Vector3.new(0.72, 0.3, 0.8), Vector3.new(0, 0.3, 0.04), Color3.fromRGB(70, 156, 82) },
		{ "ShellTop", Vector3.new(0.5, 0.14, 0.58), Vector3.new(0, 0.5, 0.04), Color3.fromRGB(92, 184, 100) },
		{ "Plate", Vector3.new(0.24, 0.04, 0.24), Vector3.new(0, 0.58, 0.04), Color3.fromRGB(150, 210, 120) },
		{ "Head", Vector3.new(0.3, 0.28, 0.3), Vector3.new(0, 0.3, -0.54), Color3.fromRGB(154, 206, 112) },
		{ "LegFL", Vector3.new(0.16, 0.16, 0.16), Vector3.new(-0.3, 0.1, -0.26), Color3.fromRGB(154, 206, 112) },
		{ "LegFR", Vector3.new(0.16, 0.16, 0.16), Vector3.new(0.3, 0.1, -0.26), Color3.fromRGB(154, 206, 112) },
		{ "LegBL", Vector3.new(0.16, 0.16, 0.16), Vector3.new(-0.3, 0.1, 0.32), Color3.fromRGB(154, 206, 112) },
		{ "LegBR", Vector3.new(0.16, 0.16, 0.16), Vector3.new(0.3, 0.1, 0.32), Color3.fromRGB(154, 206, 112) },
	}, eyes(0.34, -0.7, 0.08, 0.06)),
	["Hermit Crab"] = join({
		{ "Body", Vector3.new(0.56, 0.24, 0.44), Vector3.new(0, 0.16, -0.12), Color3.fromRGB(226, 84, 64) },
		{ "Shell1", Vector3.new(0.56, 0.36, 0.52), Vector3.new(0, 0.4, 0.14), Color3.fromRGB(238, 186, 150) },
		{ "Shell2", Vector3.new(0.42, 0.28, 0.4), Vector3.new(0, 0.66, 0.2), Color3.fromRGB(246, 206, 176) },
		{ "Shell3", Vector3.new(0.26, 0.2, 0.26), Vector3.new(0, 0.86, 0.24), Color3.fromRGB(252, 226, 200) },
		{ "ClawL", Vector3.new(0.2, 0.18, 0.22), Vector3.new(-0.3, 0.16, -0.42), Color3.fromRGB(236, 96, 72) },
		{ "ClawR", Vector3.new(0.24, 0.22, 0.26), Vector3.new(0.3, 0.18, -0.42), Color3.fromRGB(236, 96, 72) },
		{ "StalkL", Vector3.new(0.05, 0.2, 0.05), Vector3.new(-0.1, 0.36, -0.3), Color3.fromRGB(226, 84, 64) },
		{ "StalkR", Vector3.new(0.05, 0.2, 0.05), Vector3.new(0.1, 0.36, -0.3), Color3.fromRGB(226, 84, 64) },
		{ "EyeL", Vector3.new(0.08, 0.08, 0.08), Vector3.new(-0.1, 0.48, -0.3), BLACK },
		{ "EyeR", Vector3.new(0.08, 0.08, 0.08), Vector3.new(0.1, 0.48, -0.3), BLACK },
	}),
	["Time Spirit"] = join({
		{ "Aura", Vector3.new(0.78, 0.78, 0.78), Vector3.new(0, 0.55, 0), Color3.fromRGB(120, 240, 200), FF, Vector3.new(0, 45, 0), 0.1 },
		{ "Core", Vector3.new(0.34, 0.34, 0.34), Vector3.new(0, 0.55, 0), Color3.fromRGB(150, 255, 220), NEON, Vector3.new(45, 0, 45) },
		{ "Face", Vector3.new(0.46, 0.46, 0.06), Vector3.new(0, 0.55, -0.32), Color3.fromRGB(250, 250, 236) },
		{ "HandLong", Vector3.new(0.04, 0.2, 0.03), Vector3.new(0, 0.63, -0.36), BLACK },
		{ "HandShort", Vector3.new(0.13, 0.04, 0.03), Vector3.new(0.06, 0.55, -0.36), BLACK },
		{ "Tick12", Vector3.new(0.05, 0.05, 0.03), Vector3.new(0, 0.74, -0.36), Color3.fromRGB(60, 200, 160), NEON },
		{ "Tick3", Vector3.new(0.05, 0.05, 0.03), Vector3.new(0.19, 0.55, -0.36), Color3.fromRGB(60, 200, 160), NEON },
		{ "Tick6", Vector3.new(0.05, 0.05, 0.03), Vector3.new(0, 0.36, -0.36), Color3.fromRGB(60, 200, 160), NEON },
		{ "Tick9", Vector3.new(0.05, 0.05, 0.03), Vector3.new(-0.19, 0.55, -0.36), Color3.fromRGB(60, 200, 160), NEON },
		{ "Wisp", Vector3.new(0.14, 0.3, 0.14), Vector3.new(0, 0.16, 0.06), Color3.fromRGB(120, 240, 200), NEON, Vector3.new(0, 45, 0), 0.3 },
	}),
} :: { [string]: Spec }

-- Rigged mesh pets: skinned meshes in ReplicatedStorage.EOS.Assets.Pets.<species>, posed from
-- code by Shared/CrowRig (no Animation assets). Their PrimaryPart "RootPart" sits at the feet.
-- Template attributes: BaseScale (studs per unit of `scale`), EyeBase / EyeL3 (eye textures).
-- Newer pets (Shared/PetRig): RigScale (the template's own Model scale), Prefix (mesh name prefix);
-- meshes <Prefix>Body / Face / L2 / L3 and a Looks folder with SurfaceAppearances Body1..3 / Face1..3.
-- Level 1 shows Body + Face; level 2 adds L2; level 3 adds L3 (each level has its own colour + face maps).
PetModel.RIGGED = { Crow = true, Kitsune = true, ["Prism Chameleon"] = true, ["Bastion Beetle"] = true, ["Thunder Toad"] = true, ["Mirage Manta"] = true, ["Ring Imp"] = true, ["Grim Ghost"] = true, ["Crystal Warden"] = true, ["Riot Hound"] = true, ["Compass Hare"] = true, ["Scroll Tanuki"] = true, ["Moonveil Moth"] = true, ["Shrine Lion"] = true, ["Drum Oni"] = true, ["Astral Djinn"] = true, ["Eclipse Tengu"] = true, ["Veil Nekomata"] = true, ["Aegis Kirin"] = true, ["Raiju"] = true, ["Void Seraph"] = true, ["Pumpkin Wraith"] = true, ["Witch's Cat"] = true, ["Mummy"] = true, ["Bone Dragon"] = true } :: { [string]: boolean }

function PetModel.isRigged(species: string): boolean
	return PetModel.RIGGED[species] == true
end

-- the rig module that poses a species' bones (CrowRig for the crow, PetRig for the rest)
function PetModel.rigModule(species: string): any
	if species == "Crow" then
		return require(script.Parent:WaitForChild("CrowRig"))
	end
	return require(script.Parent:WaitForChild("PetRig"))
end

local function applyLevelLook(model: Model, prefix: string, level: number)
	local looks = model:FindFirstChild("Looks")
	if level < 2 then
		local p = model:FindFirstChild(prefix .. "L2")
		if p then
			p:Destroy()
		end
	end
	if level < 3 then
		local p = model:FindFirstChild(prefix .. "L3")
		if p then
			p:Destroy()
		end
	end
	if looks then
		for _, nm in ipairs({ "Body", "L2", "L3", "Face", "Veil" }) do
			local p = model:FindFirstChild(prefix .. nm)
			-- the L2 / L3 add-on meshes can have their own look ("Extra<level>", e.g. glowing crystals);
			-- a "Veil" mesh (the manta's translucent fins) always uses Extra<level>
			-- (a pet whose L2 / L3 meshes have separate atlases gives each its own: "Extra<level>_<mesh>", e.g. Extra3_L2)
			local look = (nm == "L2" or nm == "L3" or nm == "Veil") and (looks:FindFirstChild("Extra" .. level .. "_" .. nm) or looks:FindFirstChild("Extra" .. level))
				or looks:FindFirstChild((if nm == "Face" then "Face" else "Body") .. level)
			if p and look then
				local old = p:FindFirstChildOfClass("SurfaceAppearance")
				if old then
					old:Destroy()
				end
				local sa = look:Clone()
				sa.Name = "SurfaceAppearance"
				sa.Parent = p
			end
		end
		looks:Destroy()
	end
end

local function buildRigged(species: string, s: number, level: number): Model?
	local assets = script.Parent.Parent:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Pets")
	local tpl = folder and folder:FindFirstChild(species)
	if not tpl or not tpl:IsA("Model") then
		return nil
	end
	local Rig = PetModel.rigModule(species)
	Rig.prime(tpl, species)
	local model = tpl:Clone()
	model.Name = "EOS_Pet"
	model:SetAttribute("Species", species)
	model:SetAttribute("Level", level)
	-- level effects baked into the template (particles, lights...) carry a MinLevel attribute:
	-- they only stay on pets at that level or higher
	for _, d in model:GetDescendants() do
		local min = d:GetAttribute("MinLevel")
		if type(min) == "number" and level < min then
			d:Destroy()
		end
	end
	local eyes = model:FindFirstChild("Crow_Eyes")
	local l3 = tpl:GetAttribute("EyeL3")
	if level >= 3 and eyes and eyes:IsA("MeshPart") and type(l3) == "string" then
		eyes.TextureID = l3 -- level 3: the red eyes
	end
	local prefix = tpl:GetAttribute("Prefix")
	if type(prefix) == "string" then
		applyLevelLook(model, prefix, level)
	end
	local base = tpl:GetAttribute("BaseScale")
	local rs = tpl:GetAttribute("RigScale")
	model:ScaleTo(s * (if type(base) == "number" then base else 1) * (if type(rs) == "number" then rs else 1))
	Rig.new(model, species):pose("Idle", 0)
	return model
end

-- Build a pet. scale: 1 = about 1 stud tall. The model's PrimaryPart "Root" sits at its feet.
-- level (1..3) only changes the look of pets that have mutation looks (the crow's eyes).
function PetModel.build(species: string, scale: number?, level: number?): Model
	local s = scale or 1
	if PetModel.RIGGED[species] then
		local rigged = buildRigged(species, s, level or 1)
		if rigged then
			return rigged
		end
	end
	local spec = PetModel.SPECS[species] or PetModel.SPECS.Mouse
	local model = Instance.new("Model")
	model.Name = "EOS_Pet"
	model:SetAttribute("Species", species)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2) * s
	root.Transparency = 1
	root.CFrame = CFrame.new()
	local parts = { root }
	for _, row in ipairs(spec) do
		local p = Instance.new("Part")
		p.Name = row[1]
		p.Size = row[2] * s
		local rot = row[6] :: Vector3?
		p.CFrame = CFrame.new((row[3] :: Vector3) * s) * (if rot then CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)) else CFrame.identity)
		p.Color = row[4]
		p.Material = row[5] or Enum.Material.SmoothPlastic
		p.Transparency = row[7] or 0
		table.insert(parts, p)
	end
	for _, p in ipairs(parts) do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
	end
	model.PrimaryPart = root
	return model
end

-- Put a pet in a ViewportFrame, framed and turned a little toward the viewer.
function PetModel.viewport(vp: ViewportFrame, species: string, yaw: number?)
	for _, c in ipairs(vp:GetChildren()) do
		if c:IsA("Model") or c:IsA("Camera") then
			c:Destroy()
		end
	end
	local model = PetModel.build(species, 1)
	model:PivotTo(CFrame.Angles(0, math.rad(yaw or 25), 0))
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local _, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * 1.05
	local center = Vector3.new(0, size.Y / 2 + 0.04, 0)
	cam.CFrame = CFrame.lookAt(center + Vector3.new(0, dist * 0.32, -dist), center)
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Ambient = Color3.fromRGB(190, 190, 200)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-0.4, -1, 0.6)
end

return PetModel
