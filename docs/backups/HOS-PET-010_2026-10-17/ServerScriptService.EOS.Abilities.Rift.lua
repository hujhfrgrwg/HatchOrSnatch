--!strict
-- Abilities.Rift (HOS-PET-001): the Rift archetype slot. Numbers: AbilityConfig.ARCHETYPES.Rift.
-- Both handlers are stubs that only log until they're built (AbilityConfig ... built = false):
--  * Runner: portal hop (check it with Shared.validPosition; refuse = no cooldown)
--  * Catcher: telegraphed rift blink (not a dash; same checks)

local Shared = require(script.Parent.Shared)

local Rift = {}

Rift.Runner = Shared.stub("Rift", "Runner")
Rift.Catcher = Shared.stub("Rift", "Catcher")

return Rift
