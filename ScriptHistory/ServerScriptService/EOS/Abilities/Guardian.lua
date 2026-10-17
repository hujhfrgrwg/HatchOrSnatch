--!strict
-- Abilities.Guardian (HOS-PET-001): the Guardian archetype slot. Numbers: AbilityConfig.ARCHETYPES.Guardian.
-- Both handlers are stubs that only log until they're built (AbilityConfig ... built = false):
--  * Runner: shield that blocks one tag (Shared.grantTagBlock)
--  * Catcher: longer stab / lunge reach

local Shared = require(script.Parent.Shared)

local Guardian = {}

Guardian.Runner = Shared.stub("Guardian", "Runner")
Guardian.Catcher = Shared.stub("Guardian", "Catcher")

return Guardian
