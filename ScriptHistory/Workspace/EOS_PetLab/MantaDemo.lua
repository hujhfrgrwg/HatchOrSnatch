-- MantaDemo (client, Studio only): loops the Mirage Manta's Invisibility on the lab dummy (MantaDummy)
-- so the whole ability can be watched from outside: fly-in, loop, curtain fly-past, star VFX, fade.
-- Dummy attribute Level = 1..3 pins a level; anything else cycles 1 > 2 > 3.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local Players = game:GetService("Players")
local lab = script.Parent
local dummy = lab:WaitForChild("MantaDummy") :: Model
local ctrl = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("EOS"):WaitForChild("Controllers")
local MantaPet = require(ctrl:WaitForChild("MantaPet")) :: any

local saved: { [Instance]: number } = {}
local function fade(a: number)
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

task.wait(3)
local i = 0
while dummy.Parent do
	i = i % 3 + 1
	local pinned = dummy:GetAttribute("Level")
	local lv = if type(pinned) == "number" and pinned >= 1 and pinned <= 3 then pinned else i
	dummy:SetAttribute("Showing", lv)
	MantaPet.summon(dummy, lv)
	task.wait(MantaPet.INTRO)
	-- what other players see when someone goes invisible (Controllers.Invisibility OTHERS = 0.9)
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
end
