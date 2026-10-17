# Bastion Beetle: L1 (HOS-PET-012)

Guardian, Common. Handoff look note: *a rounded beetle with a big protective shell and a stout horn.*

**For review only: not imported into the place and not wired up** (waiting for Hunter's OK on the look).

| File | What |
|---|---|
| `bastion_beetle_L1_turnaround.jpg` | front, 3/4, side, back on one strip |
| `bastion_beetle_L1_front / three_quarter / side / back.jpg` | the four views at 1024 px |
| `bastion_beetle_L1_ingame.jpg` | in Studio beside an R15 avatar (centre) and the Mimic Crow (left), both at follower scale |
| `src/bastion_beetle_L1.blend` | the Blender file |
| `preview_mesh.json` | vertices, triangles and colours, used for the in-game preview |

Source script: `tools/pets/bastion_beetle.py` (shared kit `tools/pets/petkit.py`). Rebuild:

```
blender --background --factory-startup --python tools/pets/bastion_beetle.py -- <abs path to docs/pets/bastion_beetle>
```

## Build

**Shape:**
- **Shell:** two wing-case halves with a dark seam, over a darker rim lip. It overhangs the legs and comes forward over the head like a helmet.
- **Horn:** cream, in three thick segments that sweep up and forward (rhino-beetle read).
- **Head and legs:** a small charcoal head, and six stubby bent legs.
- **Eyes:** Crow-style toon eyes (dark rim, white, black pupil, highlight).

**Production numbers:**
- **Meshes:** 2 MeshParts, `Beetle_Body` (912 tris) and `Beetle_Face` (360 tris). **1,272 triangles total** (budget 1,500).
- **Size:** 2.1 × 1.71 × 2.96 studs at scale 1. Pivot at the ground centre; it faces the same way as the Crow in game.
- **In-game scale:** at follower scale (BaseScale ≈ 0.66 × FOLLOW_SCALE 1.25) it stands 1.40 studs, the same height as the Crow follower.

**Colours** (sRGB, what Roblox shows):

| Part | Colour |
|---|---|
| Shell | (58, 96, 160) |
| Seam | (26, 38, 70) |
| Rim | (34, 50, 88) |
| Body | (52, 54, 70) |
| Horn | (232, 214, 168) |

## How it compares to the Crow standard
- **Matches:** the stylised low-poly, smooth-shaded look; big readable shapes; the toon eye; a muted body colour; triangle count in the same range (Crow 1,080).
- **Not yet done (needed before import):**
  - **Rig and texture.** The Crow is a skinned mesh with a Root bone and SurfaceAppearance colour and normal maps. This L1 uses flat material colours and has no rig yet.
  - **The import step:** bake a colour map, rig (body, head, 6 legs), FBX in studs, `Assets.Pets.Bastion Beetle` with `Prefix` and a `Looks` folder like the Kitsune.
- **L2 / L3:** not modelled yet. The plan is the same pivot, face and rig, with added L2/L3 meshes (for example shell ridges, then a crest on the horn) like the Kitsune's L2/L3.

## In-game preview method
The in-game shot uses a temporary EditableMesh built in Studio edit mode from `preview_mesh.json`, inside a non-archivable stage folder. Nothing was uploaded, saved or wired up, and it was cleared afterwards.
