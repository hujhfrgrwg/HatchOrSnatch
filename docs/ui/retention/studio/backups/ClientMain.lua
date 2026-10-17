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
local FieldGems = require(Controllers.FieldGems)
local Outlines = require(Controllers.Outlines)
local FacePlayer = require(Controllers.FacePlayer)
local EmoteController = require(Controllers.EmoteController)
local ServersController = require(Controllers.ServersController)
local SpectateController = require(Controllers.SpectateController)
local ChatTags = require(Controllers.ChatTags)

Fit.init()
Movement.init()
CharacterAnim.init()
CameraFX.init()
Tag.init()
WorldFX.init()
UIController.init()
NpcSkins.init()
Pets.init()
EmoteController.init() -- Emotes panel (My Emotes, wheel, Emote Crate), the G wheel, lobby dances and their songs
ServersController.init() -- Servers panel: live server list, join by teleport
SpectateController.init() -- SPECTATE: watch the match from the lobby (follow / free cam)
ChatTags.init() -- [VIP] in chat for VIP pass holders
require(Controllers.LastStanding).init() -- HOS-CINE-002: the lone Runner's cut-scene + the solo-crossing pill
UIController.spectating = SpectateController.isActive
UIController.startSpectate = SpectateController.start
SlideFX.init() -- streaks on the floor and in the air for every slide (yours, other players', NPCs')
FieldGems.init() -- field Gems: spin, sparkle, pickup burst, "+1"
Outlines.init() -- Catchers / downed red, Runner teammates blue; per viewer, hidden behind walls
FacePlayer.init() -- lobby leaderboards swivel to face you
Ragdoll.bindLocal() -- caught = your body ragdolls (the server builds the joints, your client simulates)

-- every server->client remote has at least one listener (no "invocation queue exhausted")
for _, name in ipairs(Net.TO_CLIENT) do
	Net.event(name).OnClientEvent:Connect(function() end)
end
