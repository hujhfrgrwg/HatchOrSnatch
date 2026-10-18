-- Controller (LocalScript inside StarterGui.PointsUI; Builder copies it from the Client folder). HOS-PTS-001.
-- Boots the UI module + UIKit, then hands the gui to Controllers/PointsController (pops, JUKE!, the revive ring,
-- the podium and the results screen). The StarterGui copy stays Enabled = false; the controller enables it.
-- Everything is behind Shared.PointsConfig.Enabled: off = the gui stays disabled and nothing runs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gui = script.Parent
local PointsConfig = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("PointsConfig"))
if not PointsConfig.Enabled then
	return
end
local UI = require(gui:WaitForChild("UI"))
local UIKit = require(gui:WaitForChild("UIKit"))
UIKit.init(gui:GetAttribute("TemplatesFolder"), gui:FindFirstChild("AssetIds"))
UI.init(gui)
gui.Enabled = true

local controllers = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("EOS"):WaitForChild("Controllers")
local ok, err = pcall(function()
	require(controllers:WaitForChild("PointsController", 30)).init(gui, UI, UIKit)
end)
if not ok then
	warn("[PointsUI] PointsController: " .. tostring(err))
end
