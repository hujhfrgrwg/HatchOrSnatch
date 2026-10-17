# Void Seraph (Rift, Legendary): HOS-PET-031

From the concept card (`void_seraph_card.png`). Installed 17 Oct under Hunter's standing OK.

- **Model** (`tools/pet-kit/seraph/seraph.py`, assembled from `seraph_head.py` + the Tengu's flier helpers +
  `seraph_body.py`): a small pale winged void beast that hovers. Ivory-lavender fur with glowing magenta void cracks
  and a void-violet underside, big feathered wings that darken from white to void-violet with a glowing magenta rim,
  tall sharp ears, a gold circlet with a violet gem and two gold points, a gold collar with a pendant, tucked paws, a
  long tail ending in a void wisp; narrow slanted gold slit eyes with violet liner, a flat mouth (face decal shell).
  L2 "Twin Halo": a second, lower pair of wings and a gold halo. L3 "Six-Winged Void": a third pair of temple wings, a
  black void eye with a magenta rim behind the head, violet crystal crown points, magenta-gold eyes and glow.
  Tris 1,039 / 1,247 / 1,367. 16 bones. Anims (SeraphAnims): Idle hover (slow strokes, halo turning), Walk / Run
  flight, Hop, Ability (Portal: folds every wing into a cocoon, spins, bursts them open), Blink (Catcher: wings
  snapped tight, flickers forward, flares to brake).
- **In the place**: template `EOS.Assets.Pets["Void Seraph"]` (FBX 103348228208630, Prefix Seraph_, BaseScale 0.85),
  `PetRig.SeraphAnims`, `Controllers.SeraphPet` (the Djinn's hover follower; FLASH_AT 0.5, Blink clip for the Catcher).
- **Effects (its own, `vfx/seraph/textures.py`)**: `VFX.Abilities.Seraph{RiftPortal,RiftArrive}` (+_L2/_L3) and
  `VFX.SeraphSummon_L1-3`. Portal: a void core whirls open (AllVFX Swirls black-hole sheet) inside a magenta accretion
  swirl with an ink twin (drawn SeraphAccretion), a turning gold halo rim (drawn SeraphHalo), a flare line, feathers
  flung off the rim and feather streaks from the ring of spark points (drawn SeraphFeather). Arrive: a halo and
  accretion swirl land on the ground over a void floor, a wing pair spreads and sheds (drawn SeraphWings), white and
  magenta feathers drift down. L2 adds glints; L3 adds an outer magenta halo (portal) and a void eye (arrive). Same
  sizes and timing as the Rift archetype. Hooks via `_G.HOS_PetHooks` (Rift, legendary). The Rift egg table is unchanged.
- **Checks**: playtest at L3: follower flies; the Rift cast is refused in the Studio sandbox (OFF_MAP), as for the
  Djinn and Hare, so the summon was played through the controller: SeraphSummon_L3 plays
  (`ingame/playtest_summon_L3.jpg`); SeraphRiftArrive_L3 checked in edit mode (`ingame/riftarrive_L3_edit.jpg`).
  Live Portal / Blink casts need a match map.
- **Redo (17 Oct, HOS-PET-REDO)**: Hunter: "a small pale cat with wings, plainer than the Epics". A void-black indigo coat with a magenta nebula and glowing stars, a pearl chest ruff, muzzle and paws, a bigger head, and big layered angel wings built from pointed feather blades (9 primaries, 8 secondaries, 6 pearl-gold coverts per wing on a gold wing arm; pearl -> lilac -> violet with glowing magenta tips). The L2 lower pair and the L3 temple wings are feathered the same way. Tris 1,343 / 1,687 / 1,895. BaseScale 0.85 -> 1.0. Effects unchanged (already void / magenta / gold). New FBX 98531776354909 and maps (ids in `Assets/asset_ids.json`, the old ones kept as `#superseded-HOS-PET-REDO`; ledger rows "redo HOS-PET-REDO"). Old templates and anims: `docs/backups/HOS-PET-REDO_20261017/eight_pets_templates_and_anims_before.rbxm`; old sources and renders in the same folder. Not saved: Hunter saves the place.
