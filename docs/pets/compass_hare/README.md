# Compass Hare (Rift, Rare): HOS-PET-021

From the concept card (`compass_hare_card.png`). Installed 17 Oct under Hunter's standing OK (09:02).

- **Model** (`tools/pet-kit/hare/hare.py`): cold-white hare with slate jagged saddle and stripes, very long ears with
  deep-blue inner faces and glowing tips, a gold compass on its left flank (painted glass dial, glowing needle, rune
  ring) on a leather strap, a blue scarf with a gem, a gold circlet, narrow cyan slit eyes in a dark mask, a sly mouth.
  L2 "Wayfinder": compass-needle crest, glowing rune ring round the compass, a second scarf tail, glowing claws.
  L3 "Star Navigator": gold astrolabe rings behind its back, star gems on the ears, violet runes and eyes.
  Tris 1,505 / 1,673 / 1,917. 21 bones. Anims (HareAnims): Idle 72, Walk 16 (hops), Run 12 (bounds), Hop 16,
  Ability 24 (Portal: rears up, flips the compass open), Blink 18 (crouch, vanishing leap).
- **In the place**: template `Assets.Pets["Compass Hare"]` (FBX 129817478482350, Prefix Hare_), `PetRig.HareAnims`,
  `Controllers.HarePet` (GroundPet), effects `VFX.Abilities.HareRiftPortal/HareRiftArrive` (+_L2/_L3) and
  `VFX.HareSummon_L1-3` (the Imp's rune portals recoloured compass-blue with gold; L3 violet). Hooks added by
  `_G.HOS_PetHooks` (PetModel.RIGGED, PetRig / PetBehaviors MODULES, EconomyConfig EXTRA_SPECIES Rift + rarity,
  AbilityCosmetics). Rift isn't a launch family, so eggs don't hatch it yet.
- **Checks**: follower shows textured; the L3 summon plays with the L3 portal; AbilityVFX resolves
  HareRiftPortal_L3 / HareRiftArrive. Not checked live: the real portal / blink, because the Studio sandbox refuses
  Rift casts (OFF_MAP); they use the Imp's code path with the new template names.
- **Effects v2 (17 Oct, its own, `vfx/hare2/textures.py`)**: replaces the Static Imp recolour. Same names
  (`VFX.Abilities.HareRiftPortal` / `HareRiftArrive` +_L2/_L3, `VFX.HareSummon_L1-3`). The portal is a compass rose
  on the ground (drawn HareRose) with a spinning needle (drawn HareNeedle) under a turning globe grid (drawn
  HareGlobe); the arrival stamps the rose, the globe flashes and a dashed route (drawn HareRoute) trails in. Rift
  disc structure and timing kept. Old set: `docs/backups/HOS-VFX-OWN_20261017/hare_old_effects.rbxm`. Side-by-side
  `vfx_v2/vfx_v2_compare.mp4`; playtest L3 summon via the controller ok (HareSummon_L3 + HareRiftArrive_L3; the
  real cast is refused in the sandbox, OFF_MAP).
- **Reshape (17 Oct, HOS-PET-RESHAPE)**: Hunter: "a lot of these pets look the same" (it shared the Riot Hound's
  body). Now its own body plan: an upright hare sitting up on big haunches with long flat hind feet. The upper body
  is tilted back 50 degrees about the hips (`_tilt`), then the head and very long ears are brought level again and
  the small forelegs hang tucked in front of the chest (`_settle`, by skin weight); the bones get the same transforms,
  so names and anims are unchanged and it still moves in hops. Textures unchanged; new FBX 131159917868536 (old FBX
  kept as `#superseded-HOS-PET-RESHAPE`); old template + anims `docs/backups/HOS-PET-RESHAPE_20261017/compass_hare_old_template.rbxm`.
  Tris 1,537 / 1,705 / 1,949. Playtest L3: upright follower with the astrolabe rings, summon ok (`ingame/reshape_upright_L3.jpg`).
