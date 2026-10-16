--!strict
-- PlayerService: validated client requests that touch the profile (AFK, volunteer, settings,
-- quest claims, profile refresh). There is NO remote that can grant Gold, Gems, egg pieces or tiers (B10).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProfileLogic = require(ServerScriptService.EOS.Core.ProfileLogic)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)

local PlayerService = {}

local DEVICES = { pc = true, touch = true, gamepad = true, console = true, vr = true }
local UI_COLOURS = { [""] = true, purple = true, pink = true, sky = true, lime = true, gold = true, coral = true, steel = true }

local function reject(plr: Player, remote: string)
	Analytics.warn("RemoteValidationRejected", remote .. plr.UserId, ("bad %s payload from %d"):format(remote, plr.UserId), { userId = plr.UserId, remote = remote })
end

local function toast(plr: Player, text: string, kind: string?)
	Net.event("Toast"):FireClient(plr, { text = text, kind = kind or "info" })
end

function PlayerService.init()
	local limiter = MatchService.limiter

	Net.event("RequestAFK").OnServerEvent:Connect(function(plr, on)
		if not limiter:allow(plr.UserId, "RequestAFK", os.clock()) then
			return
		end
		if type(on) ~= "boolean" then
			return reject(plr, "RequestAFK")
		end
		plr:SetAttribute("EOS_AFK", on)
		DataService.update(plr, "afk", function(p)
			ProfileLogic.setFlag(p, "afkPreference", on)
		end)
		Analytics.log("AFKToggled", { userId = plr.UserId, on = on, inMatch = plr:GetAttribute("EOS_InMatch") == true })
		if on and plr:GetAttribute("EOS_InMatch") then
			toast(plr, "AFK will start after this match", "info")
		end
	end)

	Net.event("RequestVolunteer").OnServerEvent:Connect(function(plr, on)
		if not limiter:allow(plr.UserId, "RequestVolunteer", os.clock()) then
			return
		end
		if type(on) ~= "boolean" then
			return reject(plr, "RequestVolunteer")
		end
		plr:SetAttribute("EOS_Volunteer", on)
		DataService.update(plr, "volunteer", function(p)
			ProfileLogic.setFlag(p, "volunteerPreference", on)
		end)
	end)

	Net.event("RequestSettings").OnServerEvent:Connect(function(plr, settings)
		if not limiter:allow(plr.UserId, "RequestSettings", os.clock()) then
			return
		end
		if type(settings) ~= "table" then
			return reject(plr, "RequestSettings")
		end
		local clean = {}
		for _, k in ipairs({ "sfx", "reduceEffects", "showHints" }) do
			if type(settings[k]) == "boolean" then
				clean[k] = settings[k]
			end
		end
		-- UI Colour (HOS-UI-IMPORT-001): looks only; one of the menu accents, "" = one colour per screen
		local uiColour = settings.uiColour
		if type(uiColour) ~= "string" or not UI_COLOURS[uiColour] then
			uiColour = nil
		end
		DataService.update(plr, "settings", function(p)
			ProfileLogic.setSettings(p, clean)
			if uiColour ~= nil and type(p.settings) == "table" then
				p.settings.uiColour = uiColour
			end
		end)
	end)

	-- head look (cosmetic): the client's camera yaw relative to its body, relayed as a character
	-- attribute so every client can turn that head. Nothing in gameplay reads it.
	local maxYaw = GameConfig.HeadLook.MAX_YAW
	local maxPitchUp, maxPitchDown = GameConfig.HeadLook.MAX_PITCH_UP, GameConfig.HeadLook.MAX_PITCH_DOWN
	Net.event("RequestLook").OnServerEvent:Connect(function(plr, yaw, pitch)
		if not limiter:allow(plr.UserId, "RequestLook", os.clock()) then
			return
		end
		if type(yaw) ~= "number" or yaw ~= yaw or math.abs(yaw) > 4 then
			return
		end
		if type(pitch) ~= "number" or pitch ~= pitch or math.abs(pitch) > 4 then
			pitch = 0
		end
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:SetAttribute("EOS_HeadYaw", math.clamp(math.floor(yaw * 50 + 0.5) / 50, -maxYaw, maxYaw))
			hum:SetAttribute("EOS_HeadPitch", math.clamp(math.floor(pitch * 50 + 0.5) / 50, -maxPitchDown, maxPitchUp))
		end
	end)

	Net.event("RequestQuestClaim").OnServerEvent:Connect(function(plr, questId)
		if not limiter:allow(plr.UserId, "RequestQuestClaim", os.clock()) then
			return
		end
		if type(questId) ~= "string" or #questId > 32 then
			return reject(plr, "RequestQuestClaim")
		end
		local result: any = nil
		local ok = DataService.update(plr, "claim:" .. questId, function(p)
			local a, reason, reward = ProfileLogic.claimQuest(p, questId, DataService.utcCtx())
			if result == nil then
				result = { ok = a, reason = reason, reward = reward }
			end
		end)
		if not ok or not result then
			return
		end
		if result.ok then
			Analytics.log("QuestClaimed", { userId = plr.UserId, questId = questId, reward = result.reward })
			toast(plr, "+" .. result.reward .. " Gold claimed!", "reward")
		elseif result.reason == "ALREADY_CLAIMED" then
			toast(plr, "Already claimed today", "info")
		elseif result.reason == "NOT_COMPLETE" then
			toast(plr, "Finish the quest first", "info")
		end
	end)

	Net.event("RequestProfile").OnServerEvent:Connect(function(plr, device)
		if not limiter:allow(plr.UserId, "RequestProfile", os.clock()) then
			return
		end
		if type(device) == "string" and DEVICES[device] then
			plr:SetAttribute("EOS_Device", device)
		end
		if DataService.isLoaded(plr) then
			DataService.pushProfile(plr)
		end
	end)

	-- daily rollover while playing: refresh quests at UTC midnight (B12)
	task.spawn(function()
		while true do
			task.wait(ProfileLogic.secondsToUtcMidnight(os.time()) + 2)
			for _, plr in ipairs(Players:GetPlayers()) do
				DataService.update(plr, "daily", function(p)
					ProfileLogic.ensureDaily(p, ProfileLogic.utcDate(os.time()), QuestConfig)
				end)
			end
		end
	end)
end

return PlayerService
