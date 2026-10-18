---
tags: [delivery]
ticket: HOS-POD-001
date: 2026-10-18
---
# HOS-POD-001: Rig podiums

Four podiums for showing rigs (characters / NPCs), to replace the current display pads (`Workspace.DisplayPads`, 6.5 wide). They're built in the style of the incubator's pedestal (`Workspace.Incubator`, A09 steps / crown / core; see `HOS-POD-001 incubator reference.png`). Three are the regular style and one is Halloween.

## Where they are

- **Masters:** `ServerStorage.HOS_RigPodiums` holds `Podium_Crown`, `Podium_Obelisk`, `Podium_Rune` and `Podium_Harvest`.
- **Preview:** `Workspace._PodiumPreview` is a row of all four with a light grey R6 dummy standing on each, on a dark preview floor off the island at (0, 10, 1700). Nothing in the lobby was changed or moved. Delete the folder once you've picked.
- **Placing one:** each podium's pivot is its bottom centre. A rig's feet go on the `RigStand` attachment (on the `StandGlow` disc). The podium's `StandHeight` attribute holds that height above the pivot (1.87 for all four).

## The shared style (from the incubator pedestal)

- **Slab:** a dark slab (47,41,68) with three tiers stepping up.
- **Tiers:** each tier is a square plus the same square turned 45°, which gives the incubator's 8-point star outline. Colours go 59,52,82 → 68,60,94 → 74,63,99.
- **Size:** about 2/3 of the incubator's pedestal. The slab is 9 × 0.4, the tiers 6.6 / 5.2 / 3.8 across and 0.45 high, so the top is 1.75 up.
- **Glow disc:** on top, like the incubator's core (2.6 across, with a dark rim and a PointLight).
- **Lobby rules:** Plastic with Studs surfaces, and Neon only for glow accents.

## The four

| Podium | What makes it different | Parts |
|---|---|---|
| **Crown** | The incubator pedestal in miniature: a ring of 8 capped blocks round the top tier, each with a small purple gem, and a purple disc. | 33 |
| **Obelisk** | Four small obelisks on the slab's corners, each with a purple neon panel and glowing tip, and a purple neon rim round the top tier. | 37 |
| **Rune** | Square tiers (not star-shaped) with gear-tooth edges on the bottom tier and glowing rune marks between the teeth. It has a neon line round the second tier and a purple crystal cluster with glowing tips on each corner. | 54 |
| **Harvest** (Halloween) | The star tiers on a wider 11-stud slab so the props have room. It has voxel pumpkins in four sizes (one up on the first tier), three corn stalks with cobs and tassels, a wheat bundle, a hay bale and scattered red/orange/yellow leaves, with an orange glow disc. | 84 |

## Checks

- **Dummies:** on each podium, the dummy stands upright with its feet exactly on the stand height.
- **Flicker:** the coplanar sweep is clean on all four. The Obelisk's rim strips and the Rune's tier line alternate heights where they meet at the corners.
- **Placement:** props sit only where the floor under them is clear of the tier above, so nothing clips into the tiers.
- **Bug found and fixed:** the `RigStand` marker was first set before it was attached to the disc, so it inherited the disc's rotation and the dummies came out lying down. It's now attached first.

## Rebuilding

`tools/build/HOS-POD-001_rig_podiums.lua` rebuilds the masters and the preview row. Run it in the command bar or through `execute_luau`; it replaces both folders and records an undo step.
