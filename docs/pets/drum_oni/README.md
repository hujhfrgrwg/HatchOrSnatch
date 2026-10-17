# Drum Oni (Tempest, Epic): HOS-PET-025

From the concept card (`drum_oni_card.png`). Installed 17 Oct under Hunter's standing OK (09:02).

- **Model** (`tools/pet-kit/oni/oni_src.py` -> `oni.py`): a hunched teal oni with dark stripes, a wild red mane,
  red horns with glowing tips, a gold chest plate, long arms with big clawed fists, short red legs, narrow red slit
  eyes and a fanged snarl, three gold-rimmed taiko drums (glowing tomoe) on a ring behind its back. L2 "War Drummer":
  a fourth drum, gold arm bands, a rope belt with tassels. L3 "Thunder Oni": a fan of lightning-bolt flags behind the
  drums, gold horn tips, flaming hair tips, gold eyes. Tris 1,460 / 1,876 / 1,972. 16 bones. Anims (OniAnims): Idle
  (drum tap), Walk, Run, Hop, Ability (Knockback: fists high, pounds the ground), Drum (Catcher: beats a drum,
  thrusts a palm).
- **In the place**: template `Assets.Pets["Drum Oni"]` (FBX 124936825921861, Prefix Oni_, BaseScale 0.72),
  `PetRig.OniAnims`, `Controllers.OniPet` (GroundPet). Effects `VFX.Abilities.Oni{PulseCharge,PulseBlast,KnockHit,
  StormBall,StormBounce,StormHit}` (+_L2/_L3) and `VFX.OniSummon_L1-3`: the Hound's Tempest effects recoloured ember red
  (gold kept, sizes unchanged). Hooks via `_G.HOS_PetHooks` (Tempest, epic).
- **Checks**: playtest Runner at L3: ok, OniSummon_L3 + OniPulseCharge_L3 + OniPulseBlast_L3
  (`ingame/playtest_knockback_L3.jpg`). The Storm Ball path is the Hound's (checked on the Hound).
- **Effects v2 (17 Oct, its own, `vfx/oni2/textures.py`)**: replaces the Riot Hound recolour. Same names
  (`VFX.Abilities.Oni{PulseCharge,PulseBlast,KnockHit,StormBall,StormBounce,StormHit}` +_L2/_L3, `VFX.OniSummon_L1-3`).
  The charge warning and the shock are a studded taiko-rim ring (drawn OniRim) at the archetype's size, rate and
  timing; a spinning mitsudomoe crest flashes (drawn OniTomoe), drumbeat sound arcs punch out (drawn OniBeat), ember
  tongues fly (drawn OniEmber); the Storm Ball is the archetype orb in red and gold with a tomoe core, braided cord
  beams and trail (drawn OniCord) and drumbeat arcs round it. L2 teal sparks, L3 a gold tomoe. Old set:
  `docs/backups/HOS-VFX-OWN_20261017/oni_old_effects.rbxm`. Side-by-side `vfx_v2/vfx_v2_compare.mp4`; playtest L3:
  Runner Knockback ok (Summon + PulseCharge + PulseBlast), Catcher Storm Ball ok.
- **Chest fix (17 Oct)**: Hunter, "remove the weird triangle on drum onis chest". The gold inverted triangle was the
  front "vest" plate (a mesh piece whose UVs fell on the gold trim), with a matching plate on the back; both plates are
  removed from `oni_src.py` / `oni.py`. Textures unchanged; new FBX 111540774959978 (old one kept in
  `Assets/asset_ids.json` as `#superseded-HOS-PET-RESHAPE`, old template in `docs/backups/HOS-PET-RESHAPE_20261017/`).
  Tris 1,444 / 1,860 / 1,956. Playtest: the follower shows without the plate.
- **Redo (17 Oct, HOS-PET-REDO)**: Hunter: "chest is plain teal now; add stripes or a rope sash (no triangle plate)". A thick twisted shimenawa rope sash (straw with red twist lines) from the left shoulder across the chest to the right hip, half-buried in the torso so it cannot z-fight, with a knot and two tassels; dark wavy tiger stripes across the chest and belly. Tris 2,056 at L3 (56 over the 2,000 cap, from the rope). New FBX 75526310777255 and maps (ids in `Assets/asset_ids.json`, the old ones kept as `#superseded-HOS-PET-REDO`; ledger rows "redo HOS-PET-REDO"). Old templates and anims: `docs/backups/HOS-PET-REDO_20261017/eight_pets_templates_and_anims_before.rbxm`; old sources and renders in the same folder. Not saved: Hunter saves the place.
