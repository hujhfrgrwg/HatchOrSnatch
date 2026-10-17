# Eclipse Tengu (Decoy, Legendary): HOS-PET-027

From the concept card (`eclipse_tengu_card.png`). Installed 17 Oct under Hunter's standing OK (09:02 / 09:18).

- **Model** (`tools/pet-kit/tengu/tengu.py`): a flying karasu-tengu crow spirit. Plum-black scalloped plumage with red
  flame-tooth flank feathers and glowing chest runes, a hooked red beak, tall swept gold horns, a spiky black crest,
  gold layered pauldrons and a gold chest medallion with a blue gem, big wings that run black to blazing red at the
  tips, a tail fan, tucked legs with gold talons (it hovers, never walks). Face decal shell: a dark tengu mask band,
  narrow slanted red slit eyes under a heavy brow, red war-paint marks. L2 "Crimson Mantle": front horns, a red flame
  crest, gold wing claws, long red tail plumes, orange glow. L3 "Black Sun Sovereign": a black-sun eclipse halo with a
  gold spiked corona, a second pair of wings, a gold brow crown, a red gem, gold-white eyes and glow.
  Tris 996 / 1,128 / 1,460. 11 bones. Anims (TenguAnims): Idle hover, Walk / Run flight, Hop, Ability (Fake Clone:
  wraps its wings, spins, flares), Snare (Catcher: rears, dives, stamps its talons).
- **In the place**: template `EOS.Assets.Pets["Eclipse Tengu"]` (FBX 99103848708260, Prefix Tengu_, BaseScale 0.85),
  `PetRig.TenguAnims`, `Controllers.TenguPet` (the Ghost's hover follower; summon clip Ability / Snare, FLASH_AT 0.45).
  Effects v2 (17 Oct, after Hunter rejected the Crow-burst recolour): its own set, `vfx/tengu/textures.py`.
  `VFX.Abilities.Tengu{DecoySplit,DecoyPoof,SnareTrigger}` (+_L2/_L3) and `VFX.TenguSummon_L1-3`: a black sun snaps
  open in a crimson corona (drawn TenguCorona + TenguSunDisc), a flare line, two fan gusts sweeping apart (drawn
  TenguGust 4x4), crow feathers (drawn TenguFeather) and plum cel smoke (AllVFX Smoke/24), a flat corona ring on the
  ground; the snare's ring snaps shut and feather talons shoot up. L2 adds ember wisps (AllVFX Wind/35), L3 turns the
  corona gold and raises a black sun with a gold corona plus gold glints. Textures in `vfx/tengu/assets.json`.
  Hooks via `_G.HOS_PetHooks` (Decoy, legendary). Not in the egg tables yet.
- **Checks**: playtest at L3: Runner Fake Clone ok (TenguSummon_L3 + TenguDecoySplit_L3, `ingame/playtest_fakeclone_L3.jpg`);
  Catcher Snare ok (summon + snare placed; the trigger needs a Runner, not testable solo).
- **VFX v2 check**: edit-mode holds at 0.06-0.85 s beside the Crow decoy (`vfx_v2/vfx_v2_compare.mp4`), playtest Runner
  at L3 ok (`vfx_v2/vfx_v2.jpg`).
