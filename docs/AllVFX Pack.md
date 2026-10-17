# AllVFX pack (Hunter, 17 Oct): the primary VFX source

- **Source:** `C:\Users\hunte\Downloads\allvfx.zip`, left in place.
- **Unpacked to** `Assets/AllVFX/`, which is git-ignored (458 MB of textures).
- Nothing in it was run.

## What it is
- **Contents:** three texture packs, zipped inside the zip, totalling 1,936 files: 1,920 PNG, 15 JPG and 1 TXT.
  - No `.rbxm` / `.rbxmx` effect models.
  - No scripts or executables.
  - **No licence or readme file.** The one `.txt` is a joke note in `2_Flipbooks/Misc/Looks like something Ize would make/`, not a licence.
- **It is the same pack as `Assets/VFXPack`.** Every one of the 1,936 files matches a file in `Assets/VFXPack` by name and size. `VFXPack` adds my contact sheets (`_sheets`) and the original zips.
  - So everything the ability defaults use already comes from this pack.
  - The `av_*` textures in `vfx/abilities/tex/` were picked from these contact sheets.

| Pack | Folder | Files | Categories (file count) |
|---|---|---|---|
| 1, sprites | `vfx-texture-pack-1-sprites/1_Normal` | 942 | Shockwaves and Rings 165, Slashes/Crescents 163, Misc 111 (Aura, Bubbles, Genshin, Ground, Halftone, Impact Frames, Money, Muzzle, Shields, Snowflakes, Space, Splats, Text), Sigils 102, Specs/Wisps 75, Elements 70 (Fire, Lightning, Smoke, Water), Impact 69, Shards 52, Flares 38, Swirls 38, Stars 31, Cracks 24, Rock(s) 4 |
| 2, flipbooks | `vfx-texture-pack-2-flipbooks/2_Flipbooks` | 800 | Fire 148, Smoke 135, Shockwaves 95, Misc 79 (Butterflies, Distortion, Money, Rays, Shapes, Text), Lightning 73, Impact 60, Slashes 54, Water 46, Wind 28, Shards 26, Specs 20, Stars 12, Swirls 8, Sigils 5, Rocks 5, Ground 3, Cracks 2, Flares 1 |
| 3, beams and trails | `vfx-texture-pack-3-beams-trails/3_BeamsTrails` | 194 | Elemental 68 (Energy, Fire, Lightning, Smoke, Water, Wind), Misc 13 (Distorted, IDFK) + loose strips |

- **Image sizes:**
  - 1024² (662), 512² (343), 420² (265), 256² (140), 128² (46)
  - 2048² (56), 4096² (42)
- **Upload rule:** shrink anything over 1024 px to 1024 or less before uploading.
- **Flipbook grids:** 2×2 / 4×4 / 8×8, readable from the sheet; check each one before using it.

## How it's used from now on
- **Primary source** for all VFX: the per-pet ability effects (Beetle Shell Shield + Horn Tether, Toad, Imp, and the rest) and any future effects. The RoClicks material becomes the fallback.
- **Workflow:**
  1. Pick textures from the contact sheets in `Assets/VFXPack/_sheets` (same files).
  2. Shrink to 1024 px or less.
  3. Upload with `tools/upload/upload_assets.py`.
  4. Add the ids to `vfx/abilities/image_ids.json`.
- **Licence:** the pack carries no licence text. If it's a paid or community pack, Hunter should confirm its terms allow use in a published game; I can't verify that from the files.

## Should existing default effects be rebuilt from it?
No rebuild is needed for source reasons, because the defaults already come from this pack. Places where a better texture from the pack would clearly help, for a later pass:
- **Storm Ball / Pulse lightning:** `2_Flipbooks/Lightning` (73) has thicker, more cartoon bolts than the 2×2 sheet now used (`av_lightning_2x2`). They would read better on the bright sand.
- **Smoke** (Decoy poof, Storm hit, Rift fizzle): `2_Flipbooks/Smoke` (135) has animated cel-smoke flipbooks. The current `av_smoke_toon` is one of these; a denser 8×8 puff would hold up better on phones.
- **Shield bubble rim:** `1_Normal/Misc/Shields` has hex/shield textures that would give the Guardian bubble a crisper edge than the swirl ring.
- **Tether beam:** `3_BeamsTrails/Elemental/Energy` has rope-like energy strips, closer to a "tether" than the current electric strip.
