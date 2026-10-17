---
tags: [delivery, pets, abilities]
updated: 2026-10-16
---
# HOS-PET-001: pet ability framework

Hunter's scope (16 Oct): build only the framework for the five ability archetypes, remove Scout and Brake, keep Decoy working, make no pets. Edited in the Hatch or Snatch place (not saved or published; Hunter saves after his playtest).

## What was already in the place
- **Families:** `EconomyConfig.FAMILIES` had Decoy (Mouse / Parrot / Mirror Dragon), Scout, Brake, and Invisibility (Grim Ghost / Prism Chameleon, built but not a launch family). Eggs hatched Decoy / Scout / Brake. `EXTRA_SPECIES` maps Crow and Kitsune to Decoy.
- **Abilities:** all in `AbilityService`: Decoy copy, Invisibility (server attribute + client `Controllers.Invisibility` shimmer), Scout pings, Brake (client `Movement.brake`). One cooldown per pet; no Runner/Catcher split; species had a gameplay delay (`INTRO`: Crow 0.5 s, Kitsune 1.25 s, Chameleon 0.7 s, Grim Ghost 0.55 s).
- **Rigged pets (looks):** Crow (`CrowPet`), Kitsune (`KitsunePet`), Prism Chameleon (`ChameleonPet`), `GroundPet`, picked by `PetBehaviors`.
- **Nothing existed for Guardian, Tempest or Rift**, and nothing stopped the starting Catcher using a pet ability.

## What changed
- `ReplicatedStorage.EOS.Shared.AbilityConfig` (new): the five archetypes and every number, per role (`Runner` / `Catcher`): cooldown, duration, windup, `built`, card name, one line of text.
- `ReplicatedStorage.EOS.Shared.AbilityCosmetics` (new): the species hook. A species can set only `color` and `sound`; anything else is dropped. Gold Ability Colors recolours the summon ring only.
- `ServerScriptService.EOS.Abilities` (new folder): `Shared` + one module per archetype, each `{ Runner, Catcher, cleanup? }`.
  - `Decoy.Runner`: the existing copy, moved unchanged; now fires on the press (no species delay).
  - `Invisibility.Runner`: the existing invisibility, moved unchanged; also fires on the press.
  - Every other handler is a stub: logs, refuses, costs no cooldown.
  - `Shared.validPosition(actor, to)`: no crossing skip / safe zone (path sampled), not while zone-locked, inside the arena, a sphere sweep plus a room box using the body's own collision group, ground under the target.
  - `Shared.grantTagBlock / consumeTagBlock`: "blocks one tag" charges.
- `AbilityService`: dispatcher. Role at press picks the handler; the starting Catcher (`initialHunter`) is refused and gets `EOS_PetAbilityOff`; the cooldown starts only when a handler succeeds; it registers the capture guard.
- `MatchService`: `addCaptureGuard`; `tryCapture` asks the guards only when a tag would really land (a blocked lunge counts as used).
- Removed: Scout and Brake families, SCOUT/BRAKE code, `ScoutPing` remote and client handler, `Movement.brake`, the Outlines Scout hook, UI text. `LAUNCH_FAMILIES` is now `{ "Decoy" }`. Incubator tiles for Scout/Brake are hidden at runtime (GUI kept).
- `Pets` / `UIController`: card and touch button hidden when there's no usable ability (starting Catcher, removed family); the match card shows the role's ability name; incubator role lines from AbilityConfig; sound from AbilityCosmetics.
- `Analytics`: `AbilityRefused`, `AbilityStub`, `AbilityTagBlocked`.
- `LogicTests` G04 now uses Decoy (and checks a removed family can't be picked).

Backups: `docs/backups/HOS-PET-001_2026-10-16/`.

## Checks (local 2-player playtest + NPCs)
- Decoy Runner: works; copy spawns 1 ms after the request (was 0.5 s for the Crow).
- Invisibility Runner: on at the press, off after 3 s.
- Starting Catcher: no card, `Pets.family()` nil, a forced request is refused `STARTER`.
- Converted Catcher with a Decoy pet: Catcher stub runs, refused `NOT_BUILT`, no cooldown. Rift Runner stub: same.
- Tag block: one charge blocks exactly one tag; the next tag lands; everyone gets the `blocked` effect.
- validPosition: open field OK; safe zone, off map, through a wall, into a box, into the ground, zone-locked all refused.
- No script errors on the server or either client. LogicTests 55/56: E03 (MatchLogic clean streak) fails, not touched by this ticket.

## Open for Hunter
- Kitsune and Chameleon now fire on the press too (species can't change timing). Their fly-in plays over the effect.
- Old saved Scout/Brake pets have no ability now (no migration, per brief).
- The incubator's 3x3 grid has two hidden tiles (gaps) until a UI pass.
- When Guardian is built: contact tags retry every tick, so a blocked tag is followed by another ~0.1 s later unless the shield adds a short immunity.
- Placeholder colours for Guardian / Tempest / Rift in AbilityConfig.
