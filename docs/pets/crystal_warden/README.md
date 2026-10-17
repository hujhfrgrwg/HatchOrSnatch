# Crystal Warden (Guardian, Rare): HOS-PET-019

From the concept-library card (`crystal_warden_card.png`), read through `docs/pets/PET_LESSONS.md`.
Installed 17 Oct (Hunter 08:35: "Yes. Fullt install").

## Model (tools/pet-kit/warden/warden.py)
- Stocky dark-indigo quadruped with jagged armour plates and glowing crystal-vein cracks, chunky cyan crystals on
  spine, flanks, horns and tail club, gold crest and nose guard, crystal-tipped claws, narrow slanted gold slit eyes
  in a dark mask, a snarl with fangs (face decal shell, eyes-flush 182 frames OK).
- L2 "Bulwark": crystal pauldrons, chest gem, brow crystals, more tail crystals. L3 "Prism Sovereign": crystal crown,
  wing-fins, a great spine crystal, violet-white crystals, violet eyes.
- Tris L1 1,136 / L2 1,208 / L3 1,288. 20 bones. Anims (WardenAnims): Idle 72, Walk 24, Run 16, Hop 16,
  Ability 24 (Shield: rears up, slams forepaws), Reach 22 (Catcher: crouch, lunge with jaw open, yank).

## In the place
- Template `Assets.Pets["Crystal Warden"]` (FBX 97483318702255, Prefix Warden_, BaseScale 0.75), full PBR + Looks.
- `Shared.PetRig.WardenAnims`, `Controllers.WardenPet` (GroundPet follower; summon at front-right plays Ability
  (Runner) or Reach (Catcher), WardenSummon_L* at 0.4 s, shrinks into you).
- Effects: `VFX.Abilities.Warden{ShieldUp,ShieldBubble,ShieldBreak,TetherBeam,TetherYank}` + `_L2` / `_L3`, and
  `VFX.WardenSummon_L1-3`: the Beetle's Guardian effects recoloured sapphire / violet, plus prism facet shards
  (sapphire L1, gold L2, rainbow L3). The dome keeps its size and blue. Tether FromOffset (2.1, -1.9, -2.9) = the
  Warden's mouth at the summon spot.
- Hooks (originals in `docs/backups/HOS-PET-019_20261017/ORIGINAL_LINES.md`): PetModel.RIGGED, PetRig.MODULES,
  PetBehaviors.MODULES, AbilityCosmetics.SPECIES["Crystal Warden"], EconomyConfig.EXTRA_SPECIES (Guardian) and
  SPECIES_RARITY (rare). Guardian is not a launch family yet, so eggs don't hatch it (same as the Beetle).

## Checks
- Playtest: follower shows; Runner press -> ok, WardenSummon + WardenShieldUp + WardenShieldBubble on the dome
  (`ingame/playtest_shield.jpg`); the Reach summon at L3 runs (`ingame/playtest_summon_L3.jpg`).
- Not checked live: the Catcher tether beam, because the sandbox has no Runner to tether (refused NO_TARGET). It
  uses the same code path as the Beetle's tether with the new template names.
- **Effects v2 (17 Oct, its own, `vfx/warden2/textures.py`)**: replaces the Bastion Beetle recolour. Same names
  (`VFX.Abilities.Warden{ShieldUp,ShieldBubble,ShieldBreak,TetherBeam,TetherYank}` +_L2/_L3, `VFX.WardenSummon_L1-3`).
  A cluster of sapphire crystal spires erupts from the ground over an indigo twin (drawn WardenSpires), the Warden's
  gold crest sigil flashes on the ground and over its head (drawn WardenCrest), faceted shards shoot out (drawn
  WardenShard); the bubble keeps the Guardian dome with a turning crest floor and drifting shards (the borrowed
  crystal ring mesh is gone); the Long Reach is a faceted prism beam (drawn WardenPrism) with spires at the hook.
  L2 gold glints, L3 violet-white prism crystals and rainbow shards. Caster layers within 5.5 studs. Old set:
  `docs/backups/HOS-VFX-OWN_20261017/warden_old_effects.rbxm`. Side-by-side `vfx_v2/vfx_v2_compare.mp4`; playtest
  Runner L3 ok (WardenSummon_L3 + ShieldUp_L3 + ShieldBubble_L3).
- **Reshape (17 Oct, HOS-PET-RESHAPE)**: Hunter: "a lot of these pets look the same" (it shared the Riot Hound's
  body). Now its own body plan: a low armoured crawler like a pangolin, a very wide flat domed shell close to the
  ground under five rows of angled crystal plates, short legs splayed out to the sides, a small low wedge head with
  the gold crest and muzzle plate, and a long flat armoured tail with a crystal tip cluster. Its Shield (Ability)
  now hunkers under the shell with the head pulled in, then heaves the shell up and slams it down. Same bone names.
  Textures unchanged; new FBX 111057892559303 (old FBX kept as `#superseded-HOS-PET-RESHAPE`); old template + anims
  `docs/backups/HOS-PET-RESHAPE_20261017/crystal_warden_old_template.rbxm`. Tris 1,256 / 1,328 / 1,408.
  Playtest Runner: follower textured, Summon + ShieldUp + ShieldBubble ok (`ingame/reshape_follower.jpg`).
- **Redo (17 Oct, HOS-PET-REDO)**: Hunter: bigger in game, brighter crystals. Crystals repainted with lighter roots, a more saturated body and a stronger emissive (0.75-1.0, was 0.45-1.0); BaseScale 0.75 -> 1.0. Same mesh. New FBX 78041546026328 and maps (ids in `Assets/asset_ids.json`, the old ones kept as `#superseded-HOS-PET-REDO`; ledger rows "redo HOS-PET-REDO"). Old templates and anims: `docs/backups/HOS-PET-REDO_20261017/eight_pets_templates_and_anims_before.rbxm`; old sources and renders in the same folder. Not saved: Hunter saves the place.
