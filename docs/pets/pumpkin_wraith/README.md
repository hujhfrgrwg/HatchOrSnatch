# Pumpkin Wraith (Invisibility, Legendary, Halloween): HOS-HWN-001

Limited Halloween pet, sold for 399 Robux on the Featured page until Nov 1 2026 (developer product 3719178740). Buying
it puts it in your pets with its family's ability (Hunter's exception for the Halloween pets). Store: `../halloween_store/README.md`.

- **Model** (`tools/pet-kit/wraith/wraith.py`): a floating hooded wraith (no legs) with a scorched, ribbed jack-o'-lantern
  head deep in a cowl that covers the top of the head (pass 2, Hunter 10:11: "it should cover the top of the head like a
  wraith"). Face decal shell: narrow slanted carved slit eyes with an ember core and a dark slit, a small inverted nose
  cut, a wide flat jagged fanged mouth with the corners pulled down. Tattered black cloak with burning jagged hems, bell
  sleeves, black ember-tipped claws, mantle blades and streaming cape blades. L2 "Harvest Reaper": thorned vines round
  the sleeves, leaf-blade pauldrons, two ember wisps, glowing hood stitch. L3 "Hollow King": black thorn crown on the
  hood, soul flame out of the peak, gold-trimmed plum cloak, a scythe floating behind. Tris 1,046 / 1,462 / 1,730.
  14 bones. Anims (WraithAnims): Idle hover, Walk / Run flight, Hop, Ability (Vanish), Stalk (Catcher).
- **In the place**: template `EOS.Assets.Pets["Pumpkin Wraith"]` (FBX 94966021066790, Prefix Wraith_, BaseScale 0.8),
  `PetRig.WraithAnims`, `Controllers.WraithPet` (Tengu hover follower; summon Ability / Stalk, FLASH_AT 0.5).
  Effects `VFX.WraithVanish_L1-3` / `VFX.WraithStalk_L1-3`: the Moth vanish / stalk rebuilt in ember orange (L2 gold,
  L3 white-gold), moon dust turned into rising embers, the Grin Ghost's grin / eyes afterimage in place of the moon,
  chains removed. AbilityCosmetics InvisShimmer None; ember glint tint in `Controllers.Invisibility`.
- **Effects v2 (17 Oct, its own, `vfx/halloween/textures.py`)**: same names and timing. Vanish / Stalk: an ember
  spiral winds up and breaks into sparks (drawn WraithEmberSwirl 4x4), a carved jack-o'-lantern grin flashes (drawn
  WraithGrin), glowing cinders rise (drawn WraithCinder), charcoal smoke backing; L2 gold, L3 white-gold with two
  swirls and more cinders. The Moth's crescent is gone (Grin / Eyes layers now use WraithGrin).
- **Checks** (solo playtest 17 Oct): granted through the Robux receipt path (ProfileLogic.grantItemPurchase) -> in
  p.pets as Pumpkin Wraith / Invisibility / legendary, auto-equipped, follower shown (`../previews_page/pumpkin_wraith/ingame_follower.jpg`).
  Ability press as Catcher: ok, invisible + WraithStalk summon. The Catcher effect still showed the Moth's crescent; fixed
  after the playtest and checked on the stage (`stage_stalk_L3.jpg`), not re-checked in a live match. The Runner side
  was not pressed live (the sandbox made me a Catcher).
