# Moonveil Moth (Invisibility, Epic): HOS-PET-023

From the concept card (`moonveil_moth_card.png`). Installed 17 Oct under Hunter's standing OK (09:02).

- **Model** (`tools/pet-kit/moth/moth.py`): a floating pale-lavender moth spirit (fur strokes, dark abdomen bands),
  dark violet mask with narrow cyan slit eyes, a fluffy mane, feathered antennae, a gold crescent on its head, four
  deep-violet wings with radiating veins, moon-eye spots and jagged dark edges. L2 "Eclipse": a second crescent,
  fuller mane, glowing wing veins. L3 "Moon Sovereign": a moon halo ring, hind-wing streamers, magenta eyes.
  Tris 779 / 957 / 1,109. 13 bones. Anims (MothAnims): Idle hover, Walk / Run flight, Hop, Ability (Vanish: wing
  cocoon then flare), Stalk (Catcher: wings swept back, darts low).
- **In the place**: template `Assets.Pets["Moonveil Moth"]` (FBX 82803533268817, Prefix Moth_, BaseScale 0.85),
  `PetRig.MothAnims`, `Controllers.MothPet` (the Ghost's hover follower). Effects `VFX.MothVanish_L1-3` /
  `VFX.MothStalk_L1-3`: the Ghost's vanish / stalk recoloured lilac / silver-blue / magenta with a crescent-moon
  afterimage and moon dust. Hooks via `_G.HOS_PetHooks` (Invisibility, epic, InvisShimmer None) and a lilac glint
  tint in `Controllers.Invisibility`. The Invisibility hatch table is unchanged (Epic is still the Mirage Manta).
- **Checks**: playtest Runner at L3: ok, invisible, MothVanish_L3 + summon (`ingame/playtest_vanish_L3.jpg`).
  The Catcher path is the Ghost's (checked on the Ghost).
- **Effects v2 (17 Oct, its own, `vfx/moth2/textures.py`)**: replaces the Grin Ghost recolour. Same names
  (`VFX.MothVanish_L1-3`, `VFX.MothStalk_L1-3`). Vanish: a four-wing moth silhouette flares open and dissolves into
  glittering moon dust (drawn MothWingFlash + MothDust) over an ink twin, dust motes, the crescent afterimage (its
  existing sprite); L2 floating moon eyespots (drawn MothEyespot), L3 a moon halo. Stalk: a dark moth shape sweeps
  back, one moon-eye stares, dust streaks dart forward. Old set: `docs/backups/HOS-VFX-OWN_20261017/moth_old_effects.rbxm`.
  Side-by-side `vfx_v2/vfx_v2_compare.mp4`; playtest Runner L3 ok (invisible, MothVanish_L3).
- **Redo (17 Oct, HOS-PET-REDO)**: Hunter: "flat round disc wings read like paddles". Long sickle forewings with a hooked pointed apex and a scalloped outer margin, layered over separate pointed, scalloped hindwings with luna-moth tail streamers swept out and back (L3 adds longer streamers). Paint unchanged apart from the streamers. Tris 828 body + 15 face / +178 L2 / +160 L3 (1,181 at L3). Effects unchanged. New FBX 138167711908925 and maps (ids in `Assets/asset_ids.json`, the old ones kept as `#superseded-HOS-PET-REDO`; ledger rows "redo HOS-PET-REDO"). Old templates and anims: `docs/backups/HOS-PET-REDO_20261017/eight_pets_templates_and_anims_before.rbxm`; old sources and renders in the same folder. Not saved: Hunter saves the place.
