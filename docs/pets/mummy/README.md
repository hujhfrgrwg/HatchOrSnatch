# Mummy (Guardian, Epic, Halloween): HOS-HWN-001

Limited Halloween pet, 250 Gems on the Featured page until Nov 1 2026. Store: `../halloween_store/README.md`.

- **Model** (`tools/pet-kit/mummy/mummy.py`): a hunched floating mummy; the lower body unravels into a trailing bandage
  tail (floating-pet rule), long reaching clawed arms, loose ribbon strips off the wrists, head and back. Grimy dark
  linen wraps (helical bands, crossing straps, stains, faint curse glow in the gaps). Face: wraps over the face, one
  torn gap with a single glowing cyan slit eye, a glow seeping through the covered eye, a jagged mouth gap. L2 "Tomb
  Warden": gold cuffs, scarab amulet, glowing glyph dashes. L3 "Cursed Pharaoh": striped nemes with a gold cobra, a
  jewelled broad collar, an orbiting ankh, crimson eye. Tris 944 / 1,400 / 1,842. 15 bones. Anims (MummyAnims): Idle,
  Walk / Run flight, Hop, Ability (Shield: arms cross, then thrown wide), Lash (Catcher tether).
- **In the place**: template `Assets.Pets["Mummy"]` (FBX 77092492393405, Prefix Mummy_, BaseScale 0.8),
  `PetRig.MummyAnims`, `Controllers.MummyPet`. Effects `VFX.Abilities.Mummy{ShieldUp,ShieldBubble,ShieldBreak,TetherBeam,
  TetherYank}` (+_L2/_L3, the Shrine Lion's Guardian set in linen / cursed cyan, already capped to player size) and
  `VFX.MummySummon_L1-3` (the Lion summon, crystals -> tomb / wrap dust). Guardian has no hatch table, so the store
  adds `EconomyConfig.FAMILIES.Guardian` (no species, not a launch family) for the pets menu ability card.
- **Effects v2 (17 Oct, its own, `vfx/halloween/textures.py`)**: same names and timing. Shield up: a bandage wrap
  swirl (drawn MummyWrapSwirl 4x4), bandage strips spinning out and up (drawn MummyStrip), sand dust. Shield bubble:
  the Lion's hex dome and crystals removed; a linen force-field shell at player size (6 x 5.4 studs) with a wrap swirl
  orbiting, strips circling and sand drifting for the shield's 1 s. Break: a wrap burst, strips falling, sand. Tether: the
  beam is a scrolling bandage (drawn MummyBandage) with a cursed glow core; hit / yank throw strips and sand.
- **Checks**: bought with Gems on the server (ProfileLogic.buy) -> Mummy / Guardian / epic in p.pets; summon L3 played on
  the client (`../previews_page/mummy/ingame_summon.jpg`). The shield / tether in a real match were not pressed live.
- Pass 1 look: Hunter has not commented on the Mummy yet.
