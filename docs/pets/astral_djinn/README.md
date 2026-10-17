# Astral Djinn (Rift, Epic): HOS-PET-026

From the concept card (`astral_djinn_card.png`). Installed 17 Oct under Hunter's standing OK (09:02).

- **Model** (`tools/pet-kit/djinn/djinn_src.py` -> `djinn.py`): a floating royal-blue genie with a smoke tail (no
  legs), star-speckled dark markings, gold horns, a gold collar and bracers, a red sash, a forehead gem, narrow red
  slit eyes and a fanged scowl, and a gold-rimmed galaxy portal disc on its back. L2 "Star Keeper": gold shoulder
  guards with gems, an inner star ring in the disc, gold tail bands. L3 "Cosmic Sultan": a crown of gold spikes with a
  star gem, four orbiting star gems, violet galaxy and eyes. Tris 1,240 / 1,504 / 1,584. 15 bones. Anims
  (DjinnAnims): Idle hover (disc turning), Walk / Run flight, Hop, Ability (Portal: flings the disc open, dives
  through), Blink (Catcher: crosses arms, snaps them wide).
- **In the place**: template `Assets.Pets["Astral Djinn"]` (FBX 97902333210496, Prefix Djinn_, BaseScale 0.8),
  `PetRig.DjinnAnims`, `Controllers.DjinnPet` (the Ghost's hover follower). Effects `VFX.Abilities.DjinnRiftPortal /
  DjinnRiftArrive` (+_L2/_L3) and `VFX.DjinnSummon_L1-3`: the Imp's rune portals in royal blue (L3 violet) with gold.
  Hooks via `_G.HOS_PetHooks` (Rift, epic).
- **Checks**: the L3 summon plays and AbilityVFX resolves DjinnRiftPortal_L3 (`ingame/playtest_summon_L3.jpg`).
  Live Rift casts are refused in the Studio sandbox (OFF_MAP), as for the Hare; they use the Imp's code path.
- **Effects v2 (17 Oct, its own, `vfx/djinn2/textures.py`)**: replaces the Static Imp recolour. Same names
  (`VFX.Abilities.DjinnRiftPortal` / `DjinnRiftArrive` +_L2/_L3, `VFX.DjinnSummon_L1-3`). The portal is a gold
  eight-point khatam seal (drawn DjinnSeal) turning over a dark pool with a counter-turning blue inner seal, genie
  smoke coils (drawn DjinnSmoke, with a navy ink twin) curling up off it and four-point twinkles (drawn DjinnTwinkle)
  rising from the rim; the arrival stamps the seal, bursts smoke coils outward and flashes a constellation (drawn
  DjinnConst) overhead. L2 red-gold glints, L3 a violet outer seal. Rift disc structure, sizes (~7 portal, ~9
  arrival) and timing kept. Old set: `docs/backups/HOS-VFX-OWN_20261017/djinn_old_effects.rbxm`. Side-by-side
  `vfx_v2/vfx_v2_compare.mp4`; playtest L3 summon via the controller ok (DjinnSummon_L3 + DjinnRiftArrive_L3; the
  real cast is refused in the sandbox, OFF_MAP).
- **Z-fighting fix (17 Oct)**: Hunter, "weird zfighting going on with that yellow gold band on his neck and the blue
  piece". The jaw's underside sat inside the top of the gold collar ring and the collar's inner edge lay on the neck.
  Now the collar is a level ring 0.32 wide (inner edge 0.03 clear of the neck) and the jaw sits 0.08 higher, clear of
  it. Other near-coplanar parts were separated too: the forearm bracers (radius 0.15, clear of the arm), the sash
  (moved off the chest), the L2 tail bands (wider) and the L2 star ring (in front of the back disc). Textures
  unchanged; new FBX 128975787570154 (old FBX kept as `#superseded-HOS-PET-RESHAPE`, old template in
  `docs/backups/HOS-PET-RESHAPE_20261017/astral_djinn_old_template.rbxm`). Tris unchanged (1,240 / 1,504 / 1,584).
- **Redo (17 Oct, HOS-PET-REDO)**: Hunter: more detail and contrast, less plain navy. A pale cyan-lilac chest panel against a deep indigo back with a violet nebula, bigger stars, glowing gold rune bands round the arms and a gold constellation over the chest. Mesh unchanged, so the collar / jaw gap (z-fight fix) is kept. New FBX 102635132814406 and maps (ids in `Assets/asset_ids.json`, the old ones kept as `#superseded-HOS-PET-REDO`; ledger rows "redo HOS-PET-REDO"). Old templates and anims: `docs/backups/HOS-PET-REDO_20261017/eight_pets_templates_and_anims_before.rbxm`; old sources and renders in the same folder. Not saved: Hunter saves the place.
