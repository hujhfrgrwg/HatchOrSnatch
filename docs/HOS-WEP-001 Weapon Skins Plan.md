# HOS-WEP-001 Weapon skins (dagger skins, weapon crate, lobby pedestals): plan

Status: plan for Hunter's OK, 17 Oct 2026. Nothing in the place has changed (a temporary preview folder, `Workspace._HOS_WEP_PREVIEW`, was built for the screenshots and deleted afterwards).

Preview sheet: `docs/HOS-WEP-001/weapon_skins_preview.png` (all blades at 3.0 studs, four in hand with the Minute Dagger's grip, three put away with the existing holster rules).

## What is in `ServerStorage["LargerWepModels(shouldsizedown?)"]`

20 usable blades once the Genshin pack and the dummies are opened up. Sizes are the longest side in studs. The current knife (`EOS_Assets["Minute Dagger"]`) is 2.56.

| # | Item | What it is | Size now | Mesh uploaded by | Verdict |
|---|------|-----------|---------|------------------|---------|
| 1 | KorbloxScytheDummy | Korblox Deathscythe on an R6 dummy | 8.94 | aventodev | IP risk (copy of a Roblox catalog item) |
| 2 | MidnightBlueScythe | Scythe, lots of star FX | 8.02 | Badukw | OK to use if the free-model licence is fine |
| 3 | Christmas eve | R6 dummy holding "idk axe by dull" | 11.32 | HowSoDull | OK (see licence note) |
| 4 | wat | Neon red blade (`spagethue`) + beams | 9.11 | Clazite_VFX | OK (see licence note) |
| 5 | holy sword by dull | Neon gold sword, 2 meshes | 4.60 | HowSoDull | OK (see licence note) |
| 6 | f0MUDD | R6 dummy holding a 5-part sword | 5.94 | Ako_Shiba | OK (see licence note) |
| 7 | Plane.003 | Blade with SurfaceAppearance + FX | 8.95 | (mesh 17640907532) | OK (see licence note) |
| 8 | DarkSwordGreatswordDummy | Dark greatsword on an R6 dummy | 8.53 | aventodev | OK (see licence note) |
| 9-17 | GenshinSwords | 9 Genshin Impact swords (Mistsplitter Reforged, Dull Blade, Lion's Roar, Cool Steel, Prototype Rancour, Freedom-Sworn, ...) | 4.7-6.1 | FalKirus | **Do not sell**: HoYoverse game assets |
| - | swordshitr2 | R6 rig with Yamato katana + sheath and one 3.95 s loop (`movething`) | 5.64 | - | Animation usable; **don't sell the Yamato model** (Capcom, Devil May Cry) |
| - | Body | A smoke-particle part, not a weapon | - | - | Skip |
| - | Part | A 209 x 239 baseplate | - | - | Skip |
| - | Sword Aura - Purple | An aura effect mesh, not a weapon | - | MozartStyle | Could be a crate "aura" add-on later, not a skin |

**No bow** is in the folder. If there is one somewhere else, point me at it.

## Licence / IP

- **Genshin Impact swords (9)**: ripped HoYoverse models. Selling them for Gems is selling someone else's IP; it is the kind of thing that gets a DMCA takedown or the game moderated. Recommend dropping them.
- **Yamato** (swordshitr2): Devil May Cry weapon. The animation is fine to reuse on our own blades; don't ship the model.
- **Korblox Deathscythe**: a copy of a Roblox catalog item. Lower risk than the others but it reads as a knock-off of a paid Roblox item. Recommend dropping it or restyling it so it isn't the Korblox design.
- **The rest** (6 blades) are original designs uploaded by individual Roblox users. Free models are fine to use in a game when they came from the Creator Store, but I can't see where these came from. If you got them from the Creator Store (or from the makers, e.g. "by dull"), they are fine.

That leaves **6 clean skins** (2, 3, 4, 5, 6, 7, 8 minus whichever you drop): Midnight Blue Scythe, Holiday Axe, Red Blade, Holy Sword, f0MUDD Sword, Plane.003 blade, Dark Greatsword. A crate needs roughly 8-12 to feel full, so the crate either waits for a few more blades or launches with 7 plus recolours (e.g. Holy Sword gold / void, Dark Greatsword red).

## Size-down rule

- Uniform scale (no squashing) so the longest side is **3.0 studs** (knife is 2.56). Scythes and the axe land around 2.3 wide x 3.0 tall, which still reads as a scythe.
- Grip: each skin gets a `Grip` attachment at the handle; the existing `Minute Sword` Motor6D is reused, with C1 set from that attachment, so every skin sits in the hand the same way the Minute Dagger does and every existing clip (swing, lunge, idle) works untouched.
- FX: particles and beams are scaled with the model and kept, but trimmed to a few per blade (some have 30+ emitters, which is too much for every player in a match). Rarer skins keep more.
- Cosmetic only: same hitbox, damage, range and timing as the Minute Dagger.

## Holster

All skins are under 4 studs after the shrink, so `WeaponHolster` would put them all on the hip. Your rule was "knife on the hip, scythe or sword on the back". Proposed: blades (swords, katana-likes) on the hip like the knife; **scythes, axe and greatsword on the back** (set `HolsterSlot = "Back"` on those templates). No holster code change needed.

## The katana animation (swordshitr2)

`movething` is a 3.95 s looping R6 clip that draws the katana from a sheath on the left side and puts it back (joints `Handle` on the right arm and `HandleSheathe` on the left). It is a showcase loop, not an attack, so it fits:

- the lobby pedestals (a mannequin on each pedestal plays it with that skin), and
- an "inspect" pose in the shop preview.

## Shop, crate, pedestals

- **Shop**: a "Daggers" tab; each skin bought for Gems (proposed 150 common / 300 rare / 500 epic / 900 legendary), equip one at a time.
- **Weapon Crate**: same flow and reel as the Emote Crate (250 Gems, dupes refund part of the price), with its own skin tiles.
- **Lobby pedestals**: 3-4 pedestals near the shop, each with a mannequin playing the katana loop holding a featured skin, a name + price board, and a prompt that opens the shop on that skin.
- All of the shop tab, crate screens and pedestal boards go through roblox-ui-maker (HTML first, your approval, then built in Studio). No hand-made UI.

## Build steps after your OK

1. Size, grip and holster-slot each kept skin into `ServerStorage.EOS_Assets.KnifeSkins` (backup to `docs/backups/HOS-WEP-001_<date>/` first).
2. Config + save data: `KnifeSkinConfig` (id, name, rarity, price, template), owned/equipped skins in the profile; `CharacterService.setKnife` picks the equipped template (falls back to Minute Dagger).
3. UI pages in HTML (shop tab, crate reel, pedestal board) for your approval.
4. Pedestals in the lobby with the katana loop.
5. One playtest (claimed) to check in hand, holstered, swing, crate and pedestals.
