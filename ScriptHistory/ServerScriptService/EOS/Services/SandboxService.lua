-- SandboxService (Studio only): a plain baseplate to try the Catcher kit outside a match.
-- Tick the workspace attribute EOS_Sandbox in Studio and press Play: you spawn on a big flat
-- baseplate far from the lobby as a Catcher (knife in hand, over-the-shoulder camera, mouse lock,
-- camera-facing movement, strafes, dashes) with a few target dummies to swing at. No matches start
-- while it's on. Untick it to play normally. Live servers ignore all of this.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local CharacterService = require(script.Parent.CharacterService)

local SandboxService = {}

local ATTRIBUTE = "EOS_Sandbox"
local CENTER = Vector3.new(0, 0, 900) -- well clear of the lobby (z ~0) and the arena (z ~-390)

function SandboxService.enabled(): boolean
	return RunService:IsStudio() and workspace:GetAttribute(ATTRIBUTE) == true
end

local function ensureWorld()
	if workspace:FindFirstChild("EOS_SandboxWorld") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "EOS_SandboxWorld"
	local base = Instance.new("Part")
	base.Name = "Baseplate"
	base.Anchored = true
	base.Size = Vector3.new(400, 2, 400)
	base.Position = CENTER - Vector3.new(0, 1, 0)
	base.Color = Color3.fromRGB(99, 95, 98)
	base.Material = Enum.Material.SmoothPlastic
	base.Parent = folder
	-- a few still dummies to swing at
	local template = StarterPlayer:FindFirstChild("StarterCharacter")
	if template then
		for i = 1, 4 do
			local d = template:Clone()
			d.Name = "Target " .. i
			for _, s in ipairs(d:GetDescendants()) do
				if s:IsA("BaseScript") then
					s:Destroy()
				end
			end
			local hrp = d:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				hrp.Anchored = true
			end
			local spot = CENTER + Vector3.new((i - 2.5) * 10, 3, -25)
			d:PivotTo(CFrame.lookAt(spot, spot + Vector3.new(0, 0, 1)))
			d.Parent = folder
		end
	end
	folder.Parent = workspace
end

local function place(plr: Player)
	if not SandboxService.enabled() or not plr.Parent then
		return
	end
	ensureWorld()
	plr:SetAttribute(ATTRIBUTE, true)
	plr:SetAttribute("EOS_InMatch", true) -- the match camera, head look and Catcher controls
	CharacterService.applyRole(plr, "CATCHER")
	CharacterService.teleport(plr, CENTER + Vector3.new(0, 0, 20), CENTER)
end

function SandboxService.init()
	if not RunService:IsStudio() then
		return
	end
	local function hook(plr: Player)
		plr.CharacterAdded:Connect(function()
			task.delay(0.6, place, plr)
		end)
		if plr.Character then
			task.delay(0.6, place, plr)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, plr in ipairs(Players:GetPlayers()) do
		hook(plr)
	end
end

return SandboxService
