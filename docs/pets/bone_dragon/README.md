# Bone Dragon (Tempest, Legendary, Halloween): HOS-HWN-001 pass 3

Hunter 17 Oct 15:40 ("maybe we make a bone dragon pet too that can cycle into the featured menu"), "Both" 15:46, "upload and
install" 15:59. Item `hwn_dragon`, 399 Robux (developer product 3719243734), on sale from Oct 24 2026 00:00 UTC to Nov 1.
- Model `tools/pet-kit/dragon/dragon_src.py` -> `dragon.py`: flying skeletal drake, horned skull + hinged jaw + fangs, green
  soul-fire slit sockets (decal shell), vertebra neck / tail with spikes and a bone blade, open ribcage with a soul-fire heart,
  bone wings with torn membrane, tucked legs. L2 "Grave Wyrm": longer horns, extra spikes, rune cracks, violet fire. L3 "Lich
  Drake": horn crown, soul flames, orbiting shards. 1,590 / 1,814 / 1,918 tris, 19 bones.
- In the place: template `Assets.Pets["Bone Dragon"]` (FBX 103913666192994, Prefix Dragon_, BaseScale 0.7), `PetRig.DragonAnims`,
  `Controllers.DragonPet` (Tengu hover follower; Ability / Breath, FLASH_AT 0.45). Effects `VFX.Abilities.Dragon{PulseCharge,
  PulseBlast,KnockHit,StormBall,StormBounce,StormHit}` (+_L2/_L3) and `VFX.DragonSummon_L1-3`: the Tempest set's sizes and timing
  with its own drawn textures (`vfx/halloween/dragon_textures.py`): bone-shard ground ring, dragon-skull flash, soul-fire flipbook,
  flying bone shards; green / violet / pale green per level. Family Tempest (FAMILIES.Tempest added by HalloweenShop.inject).
- Checked live: granted through the Robux receipt code, equipped in the lobby, follower shown, ability card "PULSE", summon L3
  played. Not pressed inside a real match (no round started before I stopped).
