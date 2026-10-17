--!nocheck
-- BuildAll: (re)builds the whole world in EDIT mode. Run from the command bar / execute_luau:
--   require(game.ServerStorage.EOSBuild.BuildAll)()
-- Idempotent: destroys workspace.EOS_World and rebuilds it. The template's Baseplate and
-- SpawnLocation are parked (not deleted) in ServerStorage._TemplateOriginals.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local Kit = require(script.Parent.WorldKit)
local BuildLobby = require(script.Parent.BuildLobby)
local BuildArena = require(script.Parent.BuildArena)
local PAL = Kit.PAL

local function lighting()
	Lighting.ClockTime = 13.6
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(118, 120, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(168, 170, 190)
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.GlobalShadows = true
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
	atmo.Density = 0.26
	atmo.Offset = 0.12
	atmo.Color = Color3.fromRGB(200, 232, 255)
	atmo.Decay = Color3.fromRGB(110, 156, 206)
	atmo.Glare = 0
	atmo.Haze = 0.8
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Intensity = 0.5
		bloom.Size = 24
		bloom.Threshold = 1.4
	end
	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if dof then
		dof.Enabled = false -- keep far Runners/Catchers sharp: reading opponents is the game
	end
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		rays.Intensity = 0.04
	end
	local cc = Lighting:FindFirstChild("EOS_ColorCorrection") or Instance.new("ColorCorrectionEffect")
	cc.Name = "EOS_ColorCorrection"
	cc.Saturation = 0.12
	cc.Contrast = 0.06
	cc.Brightness = 0.01
	cc.Parent = Lighting
end

return function()
	pcall(ChangeHistoryService.SetWaypoint, ChangeHistoryService, "EOS: before world build")
	local t0 = os.clock()
	-- collision groups are saved with the place; register them before tagging parts with them
	require(game:GetService("ServerScriptService").EOS.Services.CharacterService).setupCollisionGroups()
	-- park the template's baseplate + default spawn (reversible)
	local parking = ServerStorage:FindFirstChild("_TemplateOriginals")
	if not parking then
		parking = Instance.new("Folder")
		parking.Name = "_TemplateOriginals"
		parking.Parent = ServerStorage
	end
	for _, name in ipairs({ "Baseplate", "SpawnLocation" }) do
		local inst = workspace:FindFirstChild(name)
		if inst then
			inst.Parent = parking
		end
	end
	local old = workspace:FindFirstChild("EOS_World")
	if old then
		old:Destroy()
	end
	local world = Instance.new("Model")
	world.Name = "EOS_World"

	-- the sea: one flat cyan plane (big water register)
	local sea = Kit.brick(world, "Sea", Vector3.new(2048, 2, 2048), CFrame.new(0, -13, -200), PAL.water, { Pattern = "Smooth", CanCollide = false, CanQuery = false, CastShadow = false })
	sea.Transparency = 0.05

	local lobby = BuildLobby(world)
	local arena = BuildArena(world)
	world.Parent = workspace
	lighting()
	workspace:SetAttribute("EOS_WorldBuiltAt", os.time())

	local parts = 0
	for _, d in ipairs(world:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	pcall(ChangeHistoryService.SetWaypoint, ChangeHistoryService, "EOS: world built")
	return ("world built: %d parts (lobby %d, arena %d) in %.1fs"):format(parts, #lobby:GetDescendants(), #arena:GetDescendants(), os.clock() - t0)
end
