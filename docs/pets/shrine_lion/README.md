# Shrine Lion (Guardian, Epic): HOS-PET-024

From the concept card (`shrine_lion_card.png`). Installed 17 Oct under Hunter's standing OK (09:02).

- **Model** (`tools/pet-kit/lion/lion_src.py` -> `lion.py`): a white komainu with fur strokes and red swirl markings,
  a red curly mane in two rings of tufts, red swept horns with glowing tips, a green rope collar with three gold bells,
  narrow gold slit eyes under a heavy red brow, a snarl with fangs, a curled tail with a red tuft.
  L2 "Temple Guard": gold chest plate, two more bells, red tassels. L3 "Divine Guardian": a flame-mane crown, a jade
  forehead gem, a flame tail, jade eyes. Tris 1,557 / 1,709 / 1,797. 23 bones. Anims (LionAnims): Idle (growl,
  bells swing), Walk, Run, Hop, Ability (Shield: rears and stamps), Roar (Catcher: lowers its head, roars the beam).
- **In the place**: template `Assets.Pets["Shrine Lion"]` (FBX 90668553513882, Prefix Lion_, BaseScale 0.72),
  `PetRig.LionAnims`, `Controllers.LionPet` (GroundPet). Effects `VFX.Abilities.Lion{ShieldUp,ShieldBubble,ShieldBreak,
  TetherBeam,TetherYank}` (+_L2/_L3) and `VFX.LionSummon_L1-3`: the Warden's Guardian effects recoloured gold / red
  (already capped to player size); the dome keeps its size. Tether FromOffset (2.1, -1.6, -3.0). Hooks via
  `_G.HOS_PetHooks` (Guardian, epic). Guardian isn't a launch family, so eggs don't hatch it yet.
- **Checks**: playtest Runner at L3: ok, LionSummon_L3 + LionShieldUp_L3 + LionShieldBubble_L3
  (`ingame/playtest_shield_L3.jpg`). Catcher tether: same path as the Warden / Beetle (sandbox has no Runner to pull).
- **Effects v2 (17 Oct, its own, `vfx/lion2/textures.py`)**: replaces the Crystal Warden recolour. Same names
  (`VFX.Abilities.Lion{ShieldUp,ShieldBubble,ShieldBreak,TetherBeam,TetherYank}` +_L2/_L3, `VFX.LionSummon_L1-3`).
  A stamp of shrine motifs: gold suzu bells fly and one rings over its head (drawn LionBell), red komainu mane curls
  roll out (drawn LionCurls), white shide paper zigzags scatter (drawn LionShide), a shimenawa rope ring lands on the
  ground (drawn LionRopeRing); the bubble keeps the Guardian dome with a turning rope floor, drifting shide and curls;
  the Long Reach is a twisted straw-rope beam (drawn LionRope) with a bell at the hook. L2 glints (+ bells in the
  bubble), L3 jade curls and a jade floor glow. Caster layers stay within 5.5 studs. Old set:
  `docs/backups/HOS-VFX-OWN_20261017/lion_old_effects.rbxm`. Side-by-side `vfx_v2/vfx_v2_compare.mp4`; playtest Runner
  L3 ok (LionSummon_L3 + ShieldUp_L3 + ShieldBubble_L3).
- **Reshape (17 Oct, HOS-PET-RESHAPE)**: Hunter: "a lot of these pets look the same" (it shared the Riot Hound's
  body). Now its own body plan: a heavy komainu with a huge square head inside an enormous three-ring red mane, a
  broad barrel chest, short thick legs with big paws and a tail curled over its back. Its idle sits upright on guard
  like a shrine statue (`_sit` pose: haunches down, chest up, forelegs straight), scanning and growling; walk / run
  re-timed for the short legs. Same bone and anim names. Tris 1,689 / 1,841 / 1,929. New FBX 84617415892057 and maps
  (old ids kept as `#superseded-HOS-PET-RESHAPE`); old template + anims `docs/backups/HOS-PET-RESHAPE_20261017/shrine_lion_old_template.rbxm`.
  Playtest L3 Runner: seated follower, Summon + ShieldUp + ShieldBubble ok (`ingame/reshape_seated_L3.jpg`).
