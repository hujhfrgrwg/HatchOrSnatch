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
task.spawn(require(Controllers.TopbarHover).init) -- HOS-TOPBAR-001: top-bar buttons rest as icon squares, grow to the pill on hover
SpectateController.init() -- SPECTATE: watch the match from the lobby (follow / free cam)
ChatTags.init() -- [VIP] in chat for VIP pass holders
require(Controllers.LastStanding).init() -- HOS-CINE-002: the lone Runner's cut-scene + the solo-crossing pill
UIController.spectating = SpectateController.isActive
UIController.startSpectate = SpectateController.start
task.spawn(require(Controllers.RetentionController).init, UIController) -- HOS-RET-001
task.spawn(require(Controllers.LeadCatcherController).init) -- HOS-LEAD-001: the paid Lead Catcher card in the lobby wait
task.spawn(require(Controllers.BackpackController).init) -- HOS-INV-001: the Pets screen becomes the Backpack (Pets, Weapons, Cosmetics tabs)
task.spawn(require(Controllers.HudDeclutter).init) -- HOS-INV-001 clutter pass: MENU square, one wallet plate, dash hints after 3 matches, streak row from the first clean crossing
task.spawn(require(Controllers.ShopItemPreview).init) -- HOS-INV-001: hover previews for the Shop's Cosmetics and Featured cosmetic cards
task.spawn(require(Controllers.CrateShowcase).init) -- HOS-INV-001: everyone sees crate openings (overhead burst, chat line for Epic+)
task.spawn(require(Controllers.CrateExtras).init) -- HOS-INV-001: open x10, the 10 PULLS screen, Emote Crate guarantee lines
task.spawn(require(Controllers.InspectController).init) -- HOS-INV-001: click a player in the lobby: their weapon, pet, emotes, GET IT
task.spawn(require(Controllers.LobbyBillboards).init) -- HOS-LOBBYBB-001: incubator chip/card (your egg), lobby crate signs, pedestal signs only when near; hidden in matches
SlideFX.init() -- streaks on the floor and in the air for every slide (yours, other players', NPCs')
FieldGems.init() -- field Gems: spin, sparkle, pickup burst, "+1"
Outlines.init() -- Catchers / downed red, Runner teammates blue; per viewer, hidden behind walls
FacePlayer.init() -- lobby leaderboards swivel to face you
require(Controllers.ProximityFade).init() -- HOS-LOBBY-003: the pro altar's beam wall and PRO LOBBY signs fade in as you walk up
require(Controllers.LobbyAmbience).init() -- HOS-LOBBY-004: lanterns swing when you're near, white wind trails; all lobby animation stops in a match
Ragdoll.bindLocal() -- caught = your body ragdolls (the server builds the joints, your client simulates)

-- every server->client remote has at least one listener (no "invocation queue exhausted")
for _, name in ipairs(Net.TO_CLIENT) do
	Net.event(name).OnClientEvent:Connect(function() end)
end
