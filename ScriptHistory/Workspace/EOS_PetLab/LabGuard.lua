-- LabGuard: EOS_PetLab is a Studio-only workbench for building pets and checking their ability
-- VFX (a bay of posed models per pet, a stand-in dummy). Live servers delete it at once.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	script.Parent:Destroy()
end
