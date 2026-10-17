# Scroll Tanuki (Decoy, Epic): HOS-PET-022

From the concept card (`scroll_tanuki_card.png`). Installed 17 Oct under Hunter's standing OK (09:02).

- **Model** (`tools/pet-kit/tanuki/tanuki_src.py`, assembled into `tanuki.py` by `assemble_pet.py`): deep-umber
  tanuki with fur strokes, a near-black bandit mask, narrow amber slit eyes, a sly smirk with a fang, round dark
  ears, a leaf on its head, a tattered teal scarf, two teal scrolls with glowing orange kanji strapped across its back,
  a ringed bushy tail. L2 "Trickster": straw kasa hat, a third scroll, hanging ofuda tags. L3 "Shapeshift Master":
  a ring of floating leaves, spirit flames on the scroll ends, a gold bell, red-orange eyes and glow.
  Tris 1,192 / 1,338 / 1,472. 22 bones. Anims (TanukiAnims): Idle, Walk, Run, Hop, Ability (Fake Clone: leaf slap +
  spin), Snare (rears and slams a paw).
- **In the place**: template `Assets.Pets["Scroll Tanuki"]` (FBX 135828292760159, Prefix Tanuki_),
  `PetRig.TanukiAnims`, `Controllers.TanukiPet` (GroundPet). Effects `VFX.Abilities.TanukiDecoySplit /
  TanukiDecoyPoof / TanukiSnareTrigger` (+_L2/_L3) and `VFX.TanukiSummon_L1-3`: the default decoy smoke in warm
  brown with leaf swirls; L2 adds ofuda paper tags, L3 orange-red leaves and spirit fire. The Snare seal and Rooted
  ring stay default so opponents read them. Leaf / ofuda sprites uploaded (ledger).
- **Hooks**: `_G.HOS_PetHooks` entries; `Abilities.Decoy` now passes ctx.level to DecoySplit and SnareTrigger (the
  copy-leaving poof is played by Controllers.Pets without a level, so it uses the L1 look).
- **Checks**: playtest Runner (L3): ok, TanukiSummon_L3 + TanukiDecoySplit_L3 + the copy; Catcher: ok, Snare seal
  + summon with leaves (`ingame/playtest_snare.jpg`). Decoy is a launch family; its hatch table is unchanged (Epic
  is still the Kitsune).
- **Effects v2 (17 Oct, its own, `vfx/tanuki2/textures.py`)**: replaces the recoloured base Decoy effects. Same names
  (`VFX.Abilities.Tanuki{DecoySplit,DecoyPoof,SnareTrigger}` +_L2/_L3, `VFX.TanukiSummon_L1-3`), same timing. A
  transformation seal flashes (drawn TanukiSeal), a cream shape-shift cel puff with swirl lines and a leaf cut-out
  bursts over an umber twin (drawn TanukiShiftPuff), leaves and teal scroll strips fly (drawn TanukiScroll + the
  existing leaf / ofuda sprites); the split leaves a seal ring on the ground; the snare's seal snaps shut and scroll
  strips shoot up. L2 adds ofuda, L3 orange embers and red leaves. Old set backed up in
  `docs/backups/HOS-VFX-OWN_20261017/tanuki_old_effects.rbxm`. Side-by-side: `vfx_v2/vfx_v2_compare.mp4`.
  Playtest Runner L3 ok (TanukiSummon_L3 + TanukiDecoySplit_L3).
- **Reshape (17 Oct, HOS-PET-RESHAPE)**: Hunter: "a lot of these pets look the same" (it shared the Riot Hound's
  body). Now its own body plan: it stands upright on its hind legs like a tanuki statue, a squat pear body with a huge
  round belly, stubby legs, short arms resting on the belly, the ringed tail resting on the ground behind, scrolls
  strapped across its back on a slanting sash. New anims: Idle drums its belly, Walk / Run are an upright waddle,
  Fake Clone throws both paws up to slap the leaf, Snare winds up a paw and slams it. Same bone names (the arms are
  the Front* bones). Tris 1,164 / 1,310 / 1,444. New FBX 105121854295584 and maps (old ids kept as
  `#superseded-HOS-PET-RESHAPE`); old template + anims `docs/backups/HOS-PET-RESHAPE_20261017/scroll_tanuki_old_template.rbxm`.
  Playtest L3 Runner: Summon + DecoySplit ok, follower textured (`ingame/reshape_follower_L3.jpg`; the brand-new
  textures took a few seconds to load the first time).
- **Redo (17 Oct, HOS-PET-REDO)**: Hunter: lighter belly and face, brighter scrolls (muddy at distance). Coat a step lighter, a pale cream belly, a cream muzzle on the face decal under the bandit mask, scrolls now bright teal with gold bands, gold roller ends and glowing kanji. Same mesh. Tris 1,444. New FBX 136739202792019 and maps (ids in `Assets/asset_ids.json`, the old ones kept as `#superseded-HOS-PET-REDO`; ledger rows "redo HOS-PET-REDO"). Old templates and anims: `docs/backups/HOS-PET-REDO_20261017/eight_pets_templates_and_anims_before.rbxm`; old sources and renders in the same folder. Not saved: Hunter saves the place.
