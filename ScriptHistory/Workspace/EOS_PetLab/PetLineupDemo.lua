-- PetLineupDemo (client, Studio only): brings EOS_PetLab.PetLineup to life in Play mode.
--  * every pet (model attribute Species) plays its Idle clip (CrowRig for the crow, PetRig for the rest)
--  * one demo rig per pet (attributes DemoSpecies / DemoLevel / DemoFamily) loops that pet's ability on
--    itself: the species' real client summon (Controllers.PetBehaviors -> <Species>Pet.summon), and for the
--    Invisibility pets the fade other players see (0.9) while it's on. DemoLevel 0 cycles L1 > L2 > L3
--    (1..3 pins one); the rig's LevelLabel shows the level playing. Rigs start staggered.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local PetModel = require(Shared:WaitForChild("PetModel")) :: any
local ctrl = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("EOS"):WaitForChild("Controllers")
local PetBehaviors = require(ctrl:WaitForChild("PetBehaviors")) :: any

local lineup = script.Parent:WaitForChild("PetLineup")
task.wait(2)

-- ===== idle pets =====
local rigs = {}
for _, m in ipairs(lineup:GetChildren()) do
	local sp = m:GetAttribute("Species")
	if m:IsA("Model") and type(sp) == "string" and m:FindFirstChild("RootPart") then
		local ok, rig = pcall(function()
			local Rig = PetModel.rigModule(sp)
			local r = Rig.new(m, sp)
			r:play("Idle", 0, 1, math.random() * 30)
			return r
		end)
		if ok and rig then
			table.insert(rigs, rig)
		end
	end
end
RunService.RenderStepped:Connect(function(dt)
	for _, r in ipairs(rigs) do
		r:step(dt)
	end
end)

-- ===== ability loops on the demo rigs =====
local function fader(dummy: Model)
	local saved: { [Instance]: number } = {}
	return function(a: number)
		for _, p in ipairs(dummy:GetDescendants()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				p.LocalTransparencyModifier = a
			elseif p:IsA("Decal") then
				if saved[p] == nil then
					saved[p] = p.Transparency
				end
				p.Transparency = saved[p] + (1 - saved[p]) * a
			end
		end
	end
end

local function loop(dummy: Model, delay: number)
	local sp = dummy:GetAttribute("DemoSpecies")
	local lv = dummy:GetAttribute("DemoLevel")
	local fam = dummy:GetAttribute("DemoFamily")
	local beh = PetBehaviors.get(sp)
	if not beh then
		return
	end
	local fade = fader(dummy)
	local hrp = dummy:FindFirstChild("HumanoidRootPart")
	local bb = hrp and hrp:FindFirstChild("LevelLabel")
	local text = bb and bb:FindFirstChildOfClass("TextLabel")
	local cycle = 0
	task.wait(delay)
	while dummy.Parent do
		cycle = cycle % 3 + 1
		local pinned = dummy:GetAttribute("DemoLevel")
		lv = if type(pinned) == "number" and pinned >= 1 and pinned <= 3 then pinned else cycle
		if text then
			text.Text = "Ability · L" .. lv
		end
		pcall(beh.summon, dummy, lv)
		task.wait(beh.INTRO or 0.8)
		if fam == "Invisibility" then
			for t = 0, 1, 0.1 do
				fade(0.9 * t)
				task.wait(0.022)
			end
			task.wait(2.5)
			for t = 1, 0, -0.1 do
				fade(0.9 * t)
				task.wait(0.022)
			end
			fade(0)
			task.wait(1.5)
		else
			task.wait(3.5)
		end
	end
end

local i = 0
for _, m in ipairs(lineup:GetChildren()) do
	if m:IsA("Model") and m:GetAttribute("DemoSpecies") then
		i += 1
		task.spawn(loop, m, (i % 5) * 0.7 + math.random() * 0.4)
	end
end
