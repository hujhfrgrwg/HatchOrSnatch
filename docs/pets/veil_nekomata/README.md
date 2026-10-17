# Veil Nekomata (Invisibility, Legendary): HOS-PET-028

From the concept card (`veil_nekomata_card.png`). Installed 17 Oct under Hunter's standing OK. Built to Legendary
quality; Hunter is still deciding whether the Grin Ghost becomes the Legendary Invisibility pet (the Ghost is untouched).

- **Model** (`tools/pet-kit/neko/neko_src.py` -> `neko.py`): a lean two-tailed cat yokai. Near-black plum fur with fur
  strokes, a white bib, muzzle, blaze and socks, tall sharp ears with violet insides, a white chest ruff, a blue rope
  collar with a gold bell, narrow slanted glowing cyan slit eyes under a heavy brow, a flat mouth with one small fang
  (face decal shell), two fluffy tails that turn white and burn into blue onibi plumes, small onibi on the ears.
  L2 "Spirit Veil": bigger ear flames, two floating onibi, ghost-fire tufts on the ruff, glowing cyan flank stripes.
  L3 "Thousand-Year Nekomata": a ring of five onibi over its back, a ghost-flame crown, a second flame on each tail,
  blue-violet glow and violet eyes. Tris 1,257 / 1,337 / 1,417. 25 bones. Anims (NekoAnims): Idle (tails weave out of
  phase, ear flicks), Walk, Run, Hop, Ability (Vanish: crouches, whips both tails over its back, springs out), Stalk
  (Catcher: hunting crouch, lunges a forepaw).
- **In the place**: template `EOS.Assets.Pets["Veil Nekomata"]` (FBX 135140424357503, Prefix Neko_, BaseScale 0.75),
  `PetRig.NekoAnims`, `Controllers.NekoPet` (GroundPet; FLASH_AT 0.5, Stalk clip for the Catcher).
- **Effects (its own, `vfx/neko/textures.py`)**: `VFX.NekoVanish_L1-3` (Runner): a ghost-fire veil sweeps over and tears
  into strips (drawn NekoVeil), forked onibi burst out (drawn NekoOnibi), two big tail flames rise, spirit mist hangs
  (AllVFX Smoke/12). `VFX.NekoStalk_L1-3` (Catcher, the card's Tether): a slit cat eye opens (drawn NekoEye) and a
  three-claw scratch rakes out (drawn NekoClaw) with onibi and dark mist. L2 adds glints; L3 goes blue-violet with an
  onibi ring (Vanish) / an eye halo (Stalk). Hooks via `_G.HOS_PetHooks` (Invisibility, legendary, InvisShimmer None)
  and a cyan onibi glint tint in `Controllers.Invisibility`. The Invisibility hatch table is unchanged.
- **Checks**: playtest at L3: Runner Vanish ok, invisible, NekoVanish_L3 (`ingame/playtest_vanish_L3.jpg`); Catcher ok,
  invisible, NekoStalk_L3.
- **Reshape (17 Oct, HOS-PET-RESHAPE)**: Hunter: "a lot of these pets look the same" (it shared the Riot Hound's
  body). Now its own body plan: a sleek, slinky cat high on long thin legs (everything below the body stretched
  1.55x), the body lifted and lengthened with an arched back, and the twin onibi tails stretched 1.2x so they sweep
  higher (`_slink`, applied after the build; bones get the same transform, so names and anims are unchanged).
  Textures unchanged; new FBX 125628708340354 (old FBX kept as `#superseded-HOS-PET-RESHAPE`); old template + anims
  `docs/backups/HOS-PET-RESHAPE_20261017/veil_nekomata_old_template.rbxm`. Tris 1,257 / 1,337 / 1,417.
  Playtest: follower textured (`ingame/reshape_follower.jpg`, L1), summon ok.
- **Redo (17 Oct, HOS-PET-REDO)**: Hunter: longer slimmer body, a real arched back, whip tails with wispy flames (not chunky blue blocks), its own colour apart from the Witch Cat. `_slink` now lengthens the body 1.45x (was 1.25x) with a higher, tighter arch and less stilted legs (1.3x, was 1.55x); body radii cut ~20 %. Thin S-curled whip tails end in a plume of seven long curled cyan wisps (L3 adds two mid-tail wisps). Ghost-silver coat with indigo ink tabby stripes, ink socks and kumadori cheek streaks, a crimson rope collar with the gold bell, cyan onibi. Tris 1,273 / 1,353 / 1,481. BaseScale 0.75 -> 0.8. Effects unchanged (cyan onibi already match). New FBX 135269893646090 and maps (ids in `Assets/asset_ids.json`, the old ones kept as `#superseded-HOS-PET-REDO`; ledger rows "redo HOS-PET-REDO"). Old templates and anims: `docs/backups/HOS-PET-REDO_20261017/eight_pets_templates_and_anims_before.rbxm`; old sources and renders in the same folder. Not saved: Hunter saves the place.
