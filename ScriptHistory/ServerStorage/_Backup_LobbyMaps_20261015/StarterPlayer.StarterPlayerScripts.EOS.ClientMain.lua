-- ClientMain: boots Evolve or Steal's client controllers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared"):WaitForChild("Net"))
local Ragdoll = require(ReplicatedStorage.EOS.Shared:WaitForChild("Ragdoll"))
local Controllers = script.Parent:WaitForChild("Controllers")

local Fit = require(Controllers.Fit)
local Movement = require(Controllers.Movement)
local CharacterAnim = require(Controllers.CharacterAnim)
local CameraFX = require(Controllers.CameraFX)
local Tag = require(Controllers.Tag)
local WorldFX = require(Controllers.WorldFX)
local UIController = require(Controllers.UIController)
local NpcSkins = require(Controllers.NpcSkins)
local Pets = require(Controllers.Pets)
local SlideFX = require(Controllers.SlideFX)
local Outlines = require(Controllers.Outlines)

Fit.init()
Movement.init()
CharacterAnim.init()
CameraFX.init()
Tag.init()
WorldFX.init()
UIController.init()
NpcSkins.init()
Pets.init()
SlideFX.init() -- streaks on the floor and in the air for every slide (yours, other players', NPCs')
Outlines.init() -- Catchers / downed red, Runner teammates blue; per viewer, hidden behind walls
Ragdoll.bindLocal() -- caught = your body ragdolls (the server builds the joints, your client simulates)

-- every server->client remote has at least one listener (no "invocation queue exhausted")
for _, name in ipairs(Net.TO_CLIENT) do
	Net.event(name).OnClientEvent:Connect(function() end)
end
