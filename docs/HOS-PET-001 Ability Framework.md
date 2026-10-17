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

## Prototypes (HOS-PET-006 to 010, 17 Oct)
All ten abilities now work as prototypes (placeholder looks: neon parts in the archetype colour). Every number is in `AbilityConfig`. Abilities fire on the press (Hunter, 17 Oct); `Abilities.Shared.INTRO` is visual-only timing.

| Archetype | Runner | Catcher |
|---|---|---|
| Decoy | DECOY: running copy, 3 s | SNARE: ring r4 for 8 s, first Runner in is rooted 1.2 s (speed 0, no dash) |
| Invisibility | INVISIBLE: 3 s shimmer | INVISIBLE: 2 s; Runners farther than 15 studs see nothing; ends on a stab or lunge |
| Guardian | SHIELD: blocks one tag for 3 s, then 0.5 s immunity | TETHER: nearest Runner within 25 studs / 60 degrees in front, 0.4 s beam, pulled 6 studs |
| Tempest | PULSE: 0.3 s ring, Catchers within 10 pushed 12; 3 s push immunity | STORM BALL: 40 studs/s for 50, walls stop it, first Runner hit at 50% for 1 s |
| Rift | PORTAL HOP: 12 studs, 0.35 s portals | RIFT BLINK: 10 studs ahead, 0.5 s warning ring |

Checked in local playtests (2 players + bots): shield blocks exactly one tag then the next lands after the 0.5 s immunity; push immunity holds for 3 s; Rift refuses safe zone, wall, box and zone-locked spots on the press with no cooldown, and fizzles with a refund if the spot goes bad during the windup; hops can't climb onto walls or boxes (fixed during testing). Catcher-side tests used a test helper to convert the player (a 2-player test match ends or converts people too early to stage naturally).

New hooks: `MatchService.onCatcherAttack` (stab / lunge), `ctx.refund` (AbilityService), `Shared.actorsInRole / slideTo / beam / ring / groundBelow`.

## VFX polish (HOS-VFX-001+)
Decoy, Guardian, Tempest and Rift done; previews in `docs/ability-vfx/<archetype>/`. Storm Ball now bounces once (`bounces = 1`, built in HOS-VFX-003); its v2 look (energy orb, lightning cage, floor arcs, scorch trail) is HOS-VFX-003b.

### Per-pet ability VFX (HOS-VFX-OVR, Hunter 17 Oct)
Every pet will get its own ability VFX one day. The archetype effects are the defaults for pets that have none of their own. Pets that already have their own effects (Crow, Kitsune, Grim Ghost, and Prism Chameleon's summon) keep them exactly as built, and no default plays on top of them.

**Effect keys.** Each effect has a key: the default template's name in `ReplicatedStorage.VFX.Abilities`.
- One-shots: DecoySplit, DecoyPoof, SnareTrigger, ShieldUp, ShieldBreak, TetherYank, PulseBlast, KnockHit, StormBounce, StormHit, RiftPortal, RiftArrive, RiftFizzle.
- Lasting effects: Snare, Rooted, ShieldBubble, TetherBeam, PulseCharge, StormBall, Slowed, RiftReticle.
- `Summon`: the pet's entrance over the user, for pets without a rigged entrance.

**Add an override for a species:**
1. Build the template next to the default in `ReplicatedStorage.VFX.Abilities` under a new name, e.g. `PulseBlast_Fox`. Keep the same structure: a Model with a `Root` part. For the custom-dressed effects (Snare, TetherBeam, StormBall), copy the default's children, because the client looks them up by name.
2. In `Shared.AbilityCosmetics.SPECIES`, add `Fox = { vfx = { PulseBlast = "PulseBlast_Fox" } }`. Override only the keys you want; everything else stays the default. One-shots and lasting effects work the same way.
3. To show nothing for one key (because the pet's own effect already covers it), use `AbilityCosmetics.NONE`. Crow and Kitsune do this for DecoySplit, since their swoop-in or run-in summon is the split.

**How it resolves.** The server sends the user's species with every effect: `Shared.vfx(name, pos, look, ctx.species)` and `Shared.tagVfx(part, name, keepVisible, ctx.species)`, which sets the `VFXSpecies` attribute. The client then picks the template in `AbilityVFX.template(key, species)`:
- the override, if the species has one and the template exists;
- otherwise the default.

A missing override template falls back to the default.

**Rules:**
- Pets with a rigged module (`PetBehaviors.MODULES`) always draw their own summon and poof; the poof falls back to the grey puff at level 1, as before HOS-VFX-001.
- Overrides are looks only: no numbers or timings.
- An override of something opponents must read (the snare, warning rings, the reticle, the Decoy copy) keeps its size, readability and archetype colour. Gold Ability Colors never applies to these.

## Queued for the polish pass
- **Storm Ball** (17 Oct): reference Mad Maggie's Wrecking Ball (Apex Legends), Hunter's pick. Mechanics decided: bounces off a wall **once**, same 50-stud total range; no speed pads (would make Catchers stronger); no detonation (keeps "slow the first Runner hit"). Build the bounce in the Storm Ball polish ticket, not before.
  - Video reference (Hunter, 17 Oct): https://www.youtube.com/watch?v=HI4Bg18iEqw ("Mad Maggie Season 12 Wrecking Ball Highlight", ~58 s, viewed in the browser at 360p, not downloaded). What reads: a small ball thrown low that skims and rolls along the floor with a bright core glint and a short spark trail; flat glowing disc pads with arrow marks left behind (we skip these); the hit is a big grey-white dust/smoke burst with sparks and flying debris, with blue electric arcs. For us: Tempest yellow core + electric arcs, dust kicked up as it rolls, a smaller smoke-and-sparks pop on the hit (it only slows), then the "slowed" ring under the Runner.
