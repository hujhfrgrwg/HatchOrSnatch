---
tags: [research, roclicks]
source: https://roclicks.gg/resources/building/overview
retrieved: 2026-10-15
---
# Building overview

How to build Roblox worlds, maps and models when an AI coding agent drives Studio (through an MCP plugin, executeluau, and model files pushed from disk).

How to build Roblox worlds, maps and models when an AI coding agent drives Studio (through an MCP plugin, `execute_luau`, and model files pushed from disk). Every rule here came from a real bug in a shipped or near-shipped game, and each one says which bug it prevents.

## Contents

| File                                                                           | What it covers                                                                                                                             |
|--------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| [[Stud style, materials and meshes|01-stud-style-and-materials.md]] | Stud-style parts, MaterialVariant studs, parts vs meshes, AI-generated meshes, toolbox permission traps, EditableMesh re-bakes, z-fighting |
| [[Scale and maps|02-scale-and-maps.md]]                     | Miniature worlds with a giant player, map reorganisation breakage, streaming and tags, `Part.Size` vs world extent, chunked endless maps   |
| [[Showing progress on buildings|03-progress-visuals.md]]                 | Making every upgrade visible: per-level props, wall kits, lite/far versions, part budgets, the upgrade "pop"                               |
| [[Building UX placing, picking and selecting|04-building-ux.md]]                           | Placement ghost, picking (the 58 px bug), hover highlight, forgiving tap-to-select, tap vs drag, ruins bug, quick-build bar                |
| [[Verifying maps and models|05-verifying-maps.md]]                     | Screenshot surveys, edit-camera control, Studio capture quirks, the 15 fps trap                                                            |
| [[Tools pushing, pulling and checking code|06-tools.md]]                       | The push/pull/check tool chain and how to use it safely with a collaborator editing live                                                   |

### Snippets (`snippets/`)

| File                 | Use                                                                            |
|----------------------|--------------------------------------------------------------------------------|
| `Discovery.luau`     | Find map containers by walking Folders, never by fixed parent; warn on empty   |
| `WorldExtent.luau`   | True world-axis extent of a rotated part                                       |
| `TagCache.luau`      | Tag cache that survives StreamingEnabled (timer rebuild, not the added signal) |
| `AssetProbe.luau`    | Detect meshes and images you have no permission to load                        |
| `MeshSpots.luau`     | EditableMesh "spot" pattern: background bake, repair loop, stand-ins           |
| `Layers.luau`        | One height table for everything stacked on the ground                          |
| `ZFightSweep.luau`   | Find exactly-coplanar overlapping faces in a model                             |
| `ChunkStreamer.luau` | Chunk loader skeleton: publish-then-release, uncancellable releases, pools     |
| `Growth.luau`        | One readable prop per upgrade level, with a pop-in                             |
| `Picking.luau`       | Correct pointer rays, one reused hover Highlight, tap-vs-drag                  |

### Tools (`tools/`)

| File               | Use                                                                            |
|--------------------|--------------------------------------------------------------------------------|
| `stage_rbxmx.py`   | Pack edited Luau files into one `.rbxmx` with the "base" each edit was made on |
| `stage_apply.luau` | Run in Studio: apply the stage only if live source still equals the base       |
| `rbxm_src.py`      | Pull every script's exact source out of a binary `.rbxm` export                |
| `luau_check.py`    | Compile-check every `.luau` file without running it                            |

### Examples (`examples/`)

- `growth_levels.jpg`: one building role at rising upgrade levels (our own build), used in 03.

## The ten rules that saved the most time

- Build the world from **parts**; use generated meshes only for organic shapes parts can't make.
- Probe every third-party mesh and image id before building around it. No permission = renders as **nothing**, with no error.
- EditableMesh output is **not saved**. Store recipes, bake at runtime in the background, and run a repair loop with stand-ins.
- Never leave two faces exactly coplanar. A 0.001-stud gap is enough; keep one shared layer table.
- Never discover map content by scanning one fixed parent, and never `WaitForChild` a map container.
- Under StreamingEnabled, `GetInstanceAddedSignal` does not fire for parts that stream in already tagged. Rebuild tag caches on a timer.
- In a chunk streamer, publish the new chunk before releasing the old one, and never cancel a release.
- `input.Position` is GUI space: use `ScreenPointToRay`. `GetMouseLocation()` is viewport space: use `ViewportPointToRay`.
- Every upgrade level must add one thing a player can see from the default camera.
- Before showing a map, take 12+ player-eye screenshots under the real lighting, fix, and re-shoot.

## How to work with an agent on 3D builds

1.  **Build scripts, not hand edits.** The agent writes Luau builder modules on disk, pushes them as model files, and runs them. A build you can re-run is a build you can fix.
2.  **Preview in edit mode.** `require` the builder from `execute_luau`, build into a preview folder, screenshot, then delete the preview before any playtest (it would overlap the real thing).
3.  **Measure, don't eyeball.** Part counts, coplanar-face counts, extents and ray hits are numbers the agent can check. Screenshots are for judgement, numbers are for proof.
4.  **Studio may be the source of truth.** If a collaborator edits live in Studio, pull before editing and push with a base-compare (see [[Tools pushing, pulling and checking code|06-tools.md]]).

Next: [[Stud style, materials and meshes]]
