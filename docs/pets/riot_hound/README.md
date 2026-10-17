# Riot Hound (Tempest, Rare): HOS-PET-020

From the concept-library card (`riot_hound_card.png`), read through `docs/pets/PET_LESSONS.md`.
Installed 17 Oct (Hunter 08:51: "Looks great. Fully implement").

## Model (tools/pet-kit/hound/hound.py)
- Navy-black storm wolf: spiky blue ruff, bushy blue tail with tufts, gold lightning-bolt fur along the spine, gold
  zig-zag flank cracks (glowing), tall dark ears, near-black socks and claws, narrow gold slit eyes in a dark mask,
  a snarl with a fang (face decal shell, eyes-flush 180 frames OK).
- L2 "Stormcaller": spiked riot collar, lightning shoulder bolts, fuller ruff, glowing claws.
  L3 "Thunder Alpha": lightning crown, tail bolt blades, gold leg bracers, electric cyan eyes / markings / bolts.
- Tris L1 1,157 / L2 1,349 / L3 1,685. 23 bones. Anims (HoundAnims): Idle 72, Walk 24, Run 14 (gallop), Hop 16,
  Ability 24 (Knockback: rears its head, slams the forepaws), Howl 22 (Catcher: crouches, howls the Storm Ball out).

## In the place
- Template `Assets.Pets["Riot Hound"]` (FBX 121537163189491, Prefix Hound_, BaseScale 0.75), full PBR + Looks.
- `Shared.PetRig.HoundAnims`, `Controllers.HoundPet` (GroundPet follower; summon plays Ability (Runner) or Howl
  (Catcher), HoundSummon_L* at 0.42 s, shrinks into you).
- Effects `VFX.Abilities.Hound{PulseCharge,PulseBlast,KnockHit,StormBall,StormBounce,StormHit}` + `_L2` / `_L3`, and
  `VFX.HoundSummon_L1-3`: the Toad's Tempest effects with navy shadows, a blue electric ball core and navy-blue shell
  (the card), gold sparks / floor scorch kept; L2 adds blue lightning, L3 cyan arcs (+30 % / +60 % counts). Same sizes.
- Hooks: PetModel.RIGGED, PetRig.MODULES, PetBehaviors.MODULES, AbilityCosmetics.SPECIES["Riot Hound"],
  EconomyConfig.EXTRA_SPECIES (Tempest) and SPECIES_RARITY (rare). `Abilities.Tempest` now passes ctx.level to its six
  effect calls so per-level looks play (pets without _L2 / _L3 templates, like the Toad, keep their one look).
  Undo notes in `docs/backups/HOS-PET-020_20261017/ORIGINAL_LINES.md`. Tempest isn't a launch family, so eggs don't
  hatch it yet.

## Checks
- Playtest: follower shows; Runner press -> ok, HoundSummon_L3 + HoundPulseCharge_L3 + HoundPulseBlast_L3; Catcher
  press -> ok, HoundStormBall fired (`ingame/playtest_stormball.jpg`). The follower was untextured for the first
  minutes while Roblox processed the new images.
- **Effects v2 (17 Oct, its own, `vfx/hound2/textures.py`)**: replaces the Thunder Toad recolour. Same names
  (`VFX.Abilities.Hound{PulseCharge,PulseBlast,KnockHit,StormBall,StormBounce,StormHit}` +_L2/_L3, `VFX.HoundSummon_L1-3`).
  The charge warning and the shock are a spiky gold ruff ring (drawn HoundRuff) at the archetype's size, rate and
  timing; fang jaws snap shut over an ink twin (drawn HoundJaws), jagged blue howl waves blast out (drawn HoundHowl), a
  crossed-fang bolt sigil marks the ground (drawn HoundPaw); the Storm Ball is the archetype orb in navy and gold with
  snapping jaws inside, double-line bolt beams and trail (drawn HoundBolt). L3 cyan sigil and jaws. Old set:
  `docs/backups/HOS-VFX-OWN_20261017/hound_old_effects.rbxm`. Side-by-side `vfx_v2/vfx_v2_compare.mp4`; playtest L3:
  Runner Knockback ok, Catcher Storm Ball ok.
