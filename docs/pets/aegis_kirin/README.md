# Aegis Kirin (Guardian, Legendary): HOS-PET-029

From the concept card (`aegis_kirin_card.png`). Installed 17 Oct under Hunter's standing OK.

- **Model** (`tools/pet-kit/kirin/kirin_src.py` -> `kirin.py`): a lean white qilin with a deer-dragon head, branching
  gold antlers, big gold flame blades for mane, shoulder tufts, fetlocks and tail, jagged blue scale plates on the back,
  dark-blue hooves, narrow slanted teal slit eyes under a heavy gold brow, blue forehead flame marking, flat mouth with
  one small fang (face decal shell). L2 "Aegis Warden": a gold chest aegis with a blue gem, gold shoulder guards,
  glowing scale plates. L3 "Celestial Aegis": a floating gold halo ring of six blue crystal shards, crystal antler tips,
  crystal anklets, white-cyan glow and eyes. Tris 1,293 / 1,341 / 1,565. 23 bones. Anims (KirinAnims): Idle (head
  toss, hoof paw, halo turning), Walk, Run, Hop, Ability (Shield: rears high, stamps both hooves), Reach (Catcher:
  levels the antlers like a lance and thrusts).
- **In the place**: template `EOS.Assets.Pets["Aegis Kirin"]` (FBX 89596188104214, Prefix Kirin_, BaseScale 0.7),
  `PetRig.KirinAnims`, `Controllers.KirinPet` (GroundPet; FLASH_AT 0.48, Reach clip for the Catcher).
- **Effects (its own, `vfx/kirin/textures.py`)**: `VFX.Abilities.Kirin{ShieldUp,ShieldBubble,ShieldBreak,TetherBeam,
  TetherYank}` (+_L2/_L3) and `VFX.KirinSummon_L1-3`. A hoof stamp: a hexagon aegis seal flashes on the ground (drawn
  KirinSeal), kirin fire tongues lick up (drawn KirinFlame), blue scale shards scatter (drawn KirinScale), auspicious
  cloud curls drift (drawn KirinCloud), a fire eruption (AllVFX Impact DetailedImpact.3). The bubble keeps the
  Guardian dome (the archetype's readable shape and size) with a turning seal floor, rim flames and drifting scales;
  the borrowed crystal ring mesh is gone. The Long Reach beam is its own twisting gold strip (drawn KirinBeam) with a
  seal and fire at the hook. Caster-side layers capped at 5.5 studs. L2 adds glints (and cloud wisps in the bubble);
  L3 turns the seal and shards cyan and adds crystal streaks. Tether FromOffset kept (2.1, -1.6, -3.0).
  Hooks via `_G.HOS_PetHooks` (Guardian, legendary). Guardian isn't a launch family, so eggs don't hatch it yet.
- **Checks**: playtest Runner at L3: ok, KirinSummon_L3 + KirinShieldUp_L3 + KirinShieldBubble_L3
  (`ingame/playtest_shield_L3.jpg`). Catcher Long Reach: refused NO_TARGET solo (needs a Runner), as for the Lion.
- **Reshape (17 Oct, HOS-PET-RESHAPE)**: Hunter: "a lot of these pets look the same" (it shared the Riot Hound's
  body). Now its own body plan: a tall slender deer high on long legs (straight forelegs, hind legs with a backward
  hock), a long neck carried almost upright (the Chest bone runs up it, so bone names are unchanged), a small head held
  high under taller antlers; about 2.9 studs tall in the source units against 2.1 before. Same anims, re-timed: the
  idle sways the neck, Long Reach lowers the whole neck like a lance. Tris 1,396 / 1,444 / 1,668. New FBX
  117350042048570 and maps (old ids kept in `Assets/asset_ids.json` as `#superseded-HOS-PET-RESHAPE`; the old template
  was not exported before the swap, so recover it from those ids plus `docs/backups/HOS-PET-RESHAPE_20261017/kirin_src.py`).
  Playtest L3 Runner: follower textured, Summon + ShieldUp + ShieldBubble ok (`ingame/reshape_shield_L3.jpg`).
