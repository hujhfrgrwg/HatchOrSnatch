# Witch's Cat (Decoy, Epic, Halloween): HOS-HWN-001

Limited Halloween pet, 250 Gems on the Featured page until Nov 1 2026. Store: `../halloween_store/README.md`.

- **Model** (`tools/pet-kit/witchcat/witchcat.py`): a lean black cat riding a floating broom (it never walks), tall swept
  ears, sharp cheek tufts, a long hooked tail, a crooked witch hat with a bent tip and frayed brim. Face: narrow slanted
  green slit eyes, a dark mask, a thin one-sided smirk with one fang. L2 "Hex Familiar": hat band + gold buckle with a
  green rune, crescent charm off the hat tip, glowing potion vial off the broom, whisker marks. L3 "Coven Queen": violet
  cape, two extra forked tails, green hex flame in the bristles, moon emblem. Tris 1,047 / 1,277 / 1,501. 16 bones.
  Anims (WitchCatAnims): Idle, Walk / Run flight, Hop, Ability (Fake Clone: barrel-roll + hat tip), Snare (Catcher).
- **In the place**: template `Assets.Pets["Witch's Cat"]` (FBX 97547829917932, Prefix WitchCat_, BaseScale 0.85),
  `PetRig.WitchCatAnims`, `Controllers.WitchCatPet`. Effects `VFX.Abilities.Cat{DecoySplit,DecoyPoof,SnareTrigger}`
  (+_L2/_L3, the Tanuki decoy set in cauldron green, leaves -> cauldron smoke) and `VFX.CatSummon_L1-3` (the Tengu
  summon in green, feathers -> cauldron smoke, sun disc removed).
- **Effects v2 (17 Oct, its own, `vfx/halloween/textures.py`)**: same names, sizes and timing. Summon: a spinning
  hex sigil (drawn CatHexSigil), cauldron puffs (drawn CatSmokePuff 4x4) with a dark twin, rising cauldron bubbles
  (drawn CatBubble), violet smoke; L3 adds a second counter-spinning gold sigil. Decoy split / poof / snare: puffs,
  bubbles and green broom sparks; the ground rings and the snare's chain ring became hex sigils (same size and timing).
- **Checks**: bought with Gems through the real client remote (RequestBuy -> ShopResult ok, reward "UNLOCKED!",
  `../previews_page/store/ingame_cat_bought.jpg`); a second buy refused OWNED. Summon L3 played on the client
  (`../previews_page/witch_cat/ingame_summon.jpg`). The decoy split / snare in a real match were not pressed live.
- Pass 1 look: Hunter has not commented on the Cat yet.
