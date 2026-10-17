--!strict
-- Abilities.Tempest (HOS-PET-001): the Tempest archetype slot. Numbers: AbilityConfig.ARCHETYPES.Tempest.
-- Both handlers are stubs that only log until they're built (AbilityConfig ... built = false):
--  * Runner: pulse that pushes Catchers away
--  * Catcher: rolling storm ball that slows a Runner

local Shared = require(script.Parent.Shared)

local Tempest = {}

Tempest.Runner = Shared.stub("Tempest", "Runner")
Tempest.Catcher = Shared.stub("Tempest", "Catcher")

return Tempest
