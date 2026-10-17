# Bastion Beetle (Guardian, Common): HOS-PET-013c

Rebuilt to Hunter's model sheet, `docs/pets/concepts/bastion_beetle_model_sheet.png`. That sheet replaces the earlier concept-library card and the v2 gold beetle. The beetle is **imported and wired into the place**.

## Review files
| File | What |
|---|---|
| `bastion_beetle_preview.mp4` | in-game clip, 16 s: idle, walking beside the player, Runner **Shell Shield** (summon, crystal burst, hex dome, shatters on a tag), Catcher **Horn Tether** (summon, crystal spear from the horn, yank) |
| `bastion_beetle_ingame_idle / walk / shield / break / tether.jpg` | stills from the clip |
| `bastion_beetle_turnaround.jpg` | turnaround laid out like the sheet: hero 3/4, front, side, back (+ the single views `_L1_*.jpg`) |
| `bastion_beetle_head_closeup.jpg`, `_head_front.jpg` | head close-ups: narrow glowing cyan eyes under the V brow |
| `bastion_beetle_vs_sheet.jpg` | the model beside Hunter's sheet |
| `bastion_beetle_levels.jpg` (+ `_L2_`, `_L3_` views) | L1 / L2 / L3 |
| `bastion_beetle_ability_pose_three_quarter.jpg` | the Ability pose: rears up, plates flare, horn thrusts |

## Model (tools/pets/bastion_beetle.py)
- **Shell:** a stout armoured scarab. The domed shell is made of large ivory plates (#EDE3CF) with thick bevelled bronze rims (#B07A3A). The bronze dome shows between the plates as straps. A raised bronze rune sits on each big side plate.
- **Underside:** a dark body (#3A3A40).
- **Head:** a helmet with a V brow and a lower face mask.
- **Horn:** a forward-swept sickle horn with a cyan crystal edge, and a cyan crystal set in the forehead.
- **Eyes:** small narrow glowing cyan eyes. They glow through a baked emissive mask on the SurfaceAppearance.
- **Claws and legs:** big armour-plated front claws with cyan insets, and short dark legs with small shin plates.
- **Levels:**
  - L1 has the bronze-framed crystal at the back.
  - L2 adds a bigger crystal cluster on the back and brighter eyes.
  - L3 adds full crystal growth on the back, sides and shoulders, plus a faint cyan aura: a PointLight and sparkles on the L3 mesh.
- **Triangles:** L1 1,692 / L2 1,785 / L3 1,905 (budget 2,000). The rig, pivot and face are the same at every level.
- **Rig:** 18 bones: Root, Body, ShellL/R (they flare), Head, Horn, ArmU/L ×2, and mid/back legs U/L ×2.
- **Animations:** `BeetleAnims` (Idle, Walk with a tripod gait, Run, Hop, Ability).
- **Texture:** base colour × contact AO, with a baked sheen on the ivory, bronze and crystal. Body 1024 px, the rest 512/256 px. Each mesh also gets an emissive mask (`tex/*_emit.png`).
- **rigkit additions:** `bake_textures(sheen=, ao_distance=, sizes=, emissive=)`. Higher-level meshes (L2/L3) are hidden while lower meshes bake, so hidden crystals don't leave shadows.

## In the place
- **Template:** `ReplicatedStorage.EOS.Assets.Pets["Bastion Beetle"]`, from Model **105439147577643**.
  - Colour decals: Body 130920859999276 / Face 103541314880955 / L2 101800600287820 / L3 123555067617039.
  - Emissive decals: Body 125124402509775 / Face 87526503961006 / L2 137293283533197 / L3 121854295964230.
- **Effects:** the same per-pet templates and names as before, rebuilt to the sheet:

| Role | Ability | Templates | Look |
|---|---|---|---|
| Runner | Shell Shield | `BeetleShieldUp`, `BeetleShieldBubble`, `BeetleShieldBreak` | cyan crystal spikes burst up from the base; a glowing hex-cell dome sits on the ground around the player (AllVFX hexagon pattern turned into cell lines, emissive SurfaceAppearance), with a crystal ring around its base, a floor glow and drifting cyan sparkles; it shatters into crystal fragments when it blocks a tag |
| Catcher | Horn Tether | `BeetleTetherBeam`, `BeetleTetherYank` | a jagged cyan crystal spear from the horn to the Runner (AllVFX shard strip, lightning crackle core, deep-blue underlay), crystal fragments bursting on the Runner; cyan fragments and streaks on the yank |
| both | summon | `VFX.BeetleSummon_L1-3` | now cyan, with crystal spikes |

- **Shield meshes:** `tools/vfx/beetle_shield_meshes.py` builds Model 124416136733506 (`BeetleHexDome`, `BeetleCrystalRing`).
- **Textures:** in `docs/ability-vfx/beetle_v3/`.
- **Code (`AbilityVFX` follow):** templates can now set `Offset` (Vector3) and `HideServerPart`. The Beetle's dome sits on the ground and replaces the server's blue ball on each client. Other pets are unchanged. Checked in edit mode: the dome landed at ground level, the server ball was hidden locally, and both restored when the tag was removed.
- **Tether start:** `FromOffset` is now (2.1, -0.9, -2.8) to match the new horn.
- **Not changed:** gameplay numbers, the server, and the archetype defaults.
- `BastionBeetle_InPlace.rbxm` exports the template and all Beetle effect templates.


## Full PBR retrofit (17 Oct, Hunter: "premium")
- **What it is:** every Beetle MeshPart's SurfaceAppearance now carries the full PBR set: colour, normal, roughness, metalness and emissive maps.
- **Normal map:** tangent space, baked from a smoothed subdivided copy, so the plates and limbs shade rounded with no extra triangles.
- **Metalness:** the bronze rims are metallic. Roughness: the ivory is satin and the crystals are glossy.
- **Glow:** emissive masks on the horn crystal, forehead crystal, claw insets, back crystals and eyes.
  - EmissiveStrength: body 2.2, eyes 3.0, L2 3.2, L3 2.6. Tint is cyan.
  - The base value is stored as the `BaseEmissive` attribute, for a later idle pulse.
- **Ivory tint:** SurfaceAppearance.Color is set to (242, 226, 196), the warm ivory of the sheet.
- **Assets:**
  - FBX Model 128824837218745 (triangulated, exported with tangents).
  - All map ids are in `docs/VFX-LEDGER.md`.
- **Pipeline:** `rigkit.bake_textures(pbr=True)` bakes these maps, and the Studio helper `_G.HOS_ApplyPBR` applies them. Every pet from the Toad on uses both.
- **Daylight previews:**
  - `bastion_beetle_ingame_daylight.jpg` (hero view)
  - `bastion_beetle_ingame_daylight_L3_L1.jpg` (L3 next to L1)
  - `bastion_beetle_studio_hero / front / side / back.jpg`
  - `bastion_beetle_vs_sheet.jpg`, now with Studio views beside the sheet.

## Not done / next
- **No live playtest:** Studio refused to start one this pass (solo and multiplayer both returned an unknown error). The clip is staged in edit mode, as before.
- **Against the sheet:** the sheet's shell plates are rounder, with finer bronze trim and a larger back crystal. This is a low-poly read of them.
