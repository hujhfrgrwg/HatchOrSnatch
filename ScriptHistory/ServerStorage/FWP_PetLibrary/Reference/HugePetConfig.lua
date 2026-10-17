--!strict
-- HUGE_PETS_001 (Hunter 2026-10-05 01:08Z: "Make 1 and 2. Generate concept images first ... we need a stand to
-- advertise it with only 1000 being sold. sell it for 799"; "needs to be the best pets in the game"; 01:19Z "need a
-- stand in studio and tasteful placement around the map").
-- Two huge pets sold for Robux, 1,000 of each across all servers: the Cloud Whale and the Treasure Golem (Blender:
-- assets/pets/src/pet_cloud_whale.py, pet_treasure_golem.py). The products are the HugePet rows of
-- Config.PetProductConfig; the live count is Server.Controllers.LimitedRods (the limited rods' counter).
--   Enabled       THE SWITCH. false = the Huge Pet stands are hidden and the server refuses the purchase.
--                 Owned huge pets keep working either way. Stays false until the two products exist on Roblox.
--   ForceOnInStudio  Studio test servers show and sell the stands while Enabled is false (never on a live server).
--   OnePerPlayer  a player can buy each huge pet once.
--   StandTag      CollectionService tag on every stand model (Workspace.HugePetStands.<Island>); the client
--                 controller (Client.Controllers.HugePetStands) dresses each one.
--   Text          what the stand says (8 words or fewer, a kid reads it at a glance).
local HugePetConfig = {}

HugePetConfig.Enabled = true -- 2026-10-05 14:5xZ: both products exist (3716694144 / 3716694149); live from the next publish
HugePetConfig.ForceOnInStudio = true
HugePetConfig.OnePerPlayer = true
HugePetConfig.StandTag = "HugePetStand"
HugePetConfig.Order = { "CloudWhale", "TreasureGolem" }

HugePetConfig.Text = table.freeze({
	Title = "LIMITED", -- Hunter 01:42Z: "we arent naming them huge pets. they need to be LIMITED"
	Limited = "ONLY 1,000 EVER!",
	Left = "%s / %s left",
	SoldOut = "SOLD OUT",
	Owned = "OWNED",
	Prompt = "Buy",
	Thanks = "Your huge pet is here!",
})

-- On sale right now (the switch, or a Studio test).
function HugePetConfig.On(): boolean
	if HugePetConfig.Enabled == true then
		return true
	end
	return HugePetConfig.ForceOnInStudio == true and game:GetService("RunService"):IsStudio()
end

return HugePetConfig
