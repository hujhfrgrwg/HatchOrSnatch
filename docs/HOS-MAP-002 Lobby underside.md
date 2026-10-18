---
tags: [delivery, lobby]
ticket: HOS-MAP-002
date: 2026-10-17
requested_by: Matthew
---
# HOS-MAP-002: floating-island underside for the Halloween lobby

Matthew liked the Haunted Graveyard's cliff columns (HOS-MAP-001) and asked for the same style under the lobby: hanging down until all the sides meet in the middle like an upside-down pyramid, with some random roughness.

## What was built
- **Model:** `Workspace.Ground.Ground_Underside`, 336 parts. It sits directly under the lobby disc (`Ground_Outer`, underside at y 9) and nothing else in the lobby was touched.
- **Shape:**
  - Hanging stone columns, 4 to 10 studs wide, in 6-stud bands with staggered joints. They follow the disc's stepped outline exactly, and every one of its 2,928 cells has a column under it.
  - Each column hangs down 1 stud per stud it sits in from the rim (45°), plus or minus 2.5 studs at random for roughness.
  - The sides meet under the centre around y −48, and a two-step point hangs under the deepest column to y −55.5.
  - A depth sample through the middle runs from about 0.7 at the rim down to −48.
- **Style:** the graveyard's cliff columns: Plastic with studs, alternating purple tones (92,72,128)/(74,56,110), with darker (74,56,110)/(58,44,92) toward the middle and the point.

## How to change it
`ServerStorage.EOSBuild.BuildLobbyUnderside` (new, seeded, idempotent). Run `require(game.ServerStorage.EOSBuild.BuildLobbyUnderside)()` to rebuild it. The knobs at the top are:
- `SLOPE`: depth per stud in from the rim. Higher means a deeper, sharper point.
- `ROUGH`: random depth per column.
- `BAND` and the 2-5 cell chunk widths: column size.

It reads the outline from `Ground_Outer`, so if the lobby disc changes shape, re-running it follows the new outline.

## Checks
- Nothing else in the place clips into the underside. The display pads and incubator only look like they dip below the floor because their discs lie on their sides.
- 0 visible shared faces between columns (flicker sweep).
- No column overlaps the lobby floor: their tops meet its underside at y 9.
- Visual review: a playtest was running when the build finished, so the screenshot pass waits until it's stopped.
