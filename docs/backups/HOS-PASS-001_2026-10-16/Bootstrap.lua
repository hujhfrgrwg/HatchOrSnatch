--!strict
-- Bootstrap: starts Evolve or Steal's server services in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("Net"))
Net.setup()
Net.state()

local Services = script.Parent:WaitForChild("Services")
local CharacterService = require(Services.CharacterService)
local DataService = require(Services.DataService)
local MatchService = require(Services.MatchService)
local PlayerService = require(Services.PlayerService)
local PracticeService = require(Services.PracticeService)
local LobbyService = require(Services.LobbyService)
local NpcService = require(Services.NpcService)
local MapService = require(Services.MapService)
local NpcSkinService = require(Services.NpcSkinService)
local SandboxService = require(Services.SandboxService)
local EconomyService = require(Services.EconomyService)
local EmoteService = require(Services.EmoteService)
local AbilityService = require(Services.AbilityService)
local ServerListService = require(Services.ServerListService)
local PurchaseService = require(Services.PurchaseService)

CharacterService.init()
MapService.init() -- before anything reads arena numbers: points Layout at the live map
NpcService.init()
NpcSkinService.init()
DataService.init()
MatchService.init()
PlayerService.init()
EconomyService.init()
EmoteService.init()
AbilityService.init()
ServerListService.init() -- the Servers panel: this server in the shared list, join by teleport
PurchaseService.init() -- Robux Gem packs: ProcessReceipt grants once, after the save
LobbyService.init()
PracticeService.init()
SandboxService.init() -- Studio only: workspace attribute EOS_Sandbox = knife test baseplate
MatchService.start()

-- No unused server->client remote may build up a queue: every TO_CLIENT remote has a client
-- listener in ClientMain. Server-side, ignore stray client fires of server->client remotes.
for _, name in ipairs(Net.TO_CLIENT) do
	Net.event(name).OnServerEvent:Connect(function() end)
end

if RunService:IsStudio() then
	print(("[EOS] server up (v%s). NPCs fill matches to 20 Runners and the lobby to 5 people; matches start with 1 real player (under 4 real players = practice, never saved). VOLUNTEER TO HUNT = start as a Catcher; require(ServerScriptService.EOS.Services.MatchService).forceStart()"):format(
		require(ReplicatedStorage.EOS.Shared.GameConfig).VERSION
	))
end
