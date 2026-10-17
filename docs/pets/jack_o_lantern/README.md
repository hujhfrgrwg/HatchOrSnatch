# Jack-o'-Lantern (Invisibility, Legendary, Halloween): HOS-HWN-001 pass 3

Replaces the Pumpkin Wraith look (Hunter 17 Oct 15:40: "the jacko wraith would look better as just a pumpkin"). Same pet:
item `hwn_wraith`, species id "Pumpkin Wraith" (shown as Jack-o'-Lantern via DISPLAY_NAMES, no save migration), product
3719178740 (renamed), 399 Robux, prefix Wraith_, controller WraithPet, effects WraithVanish / WraithStalk (its own embers + grin).
- Model `tools/pet-kit/pumpkin/pumpkin_src.py` (+ `_parts.py` helpers from wraith.py) -> `pumpkin.py`: floating carved scorched
  pumpkin, same carved face (decal shell), curled stem + leaves, vine arms with thorn hooks, root tendrils. L2 "Harvest Reaper":
  thorn vines on the back and sides, leaf-blade wings, ember wisps. L3 "Hollow King": black candle crown, soul flame from the lid.
  970 / 1,254 / 1,670 tris, 12 bones. Build: `docs/pets/pumpkin_wraith/build_v3/wraith`.
- In the place: template `Assets.Pets["Pumpkin Wraith"]` (FBX 95744581149909, BaseScale 0.75), `PetRig.WraithAnims` (new data).
  The cloak version is in `ServerStorage.HWN_Backup`.
- Checked live (17 Oct playtest): follower shown; Runner ability in a real NPC match -> invisible + ember summon.
