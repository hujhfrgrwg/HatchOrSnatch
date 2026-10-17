---
tags: [delivery]
ticket: HOS-LOBBY-001
date: 2026-10-17
---
# HOS-LOBBY-001: Lobby edge walls

Invisible walls run all the way around the Halloween lobby island, so players can walk right up to the edge without falling off.

## What's in Studio

`Workspace.LobbyEdgeWalls`: 212 parts (`EdgeWall_001` to `EdgeWall_212`).

- **Shape:** 140 walls follow the island's stepped outline one edge at a time. Each wall's inner face sits exactly on the edge of the ground. 72 small posts fill the outside corners of the steps, so there's no gap where two walls meet.
- **Size:** 2 studs thick, from y 9 (the underside of the ground) to y 59.
- **Settings:** `Transparency 1`, `CanCollide` on, `Anchored`. `CanQuery` and `CanTouch` are off, so the camera and raycasts pass through them and nothing triggers on touch. `CastShadow` is off.
- **Source:** the outline was traced from the 150 blocks in `Workspace.Ground` (`Ground_Outer`, `Ground_Ring`, `Ground_Plaza`). They're all axis-aligned and the outline has no holes.

If the ground's shape changes, rebuild the walls from the new outline. The rebuild deletes and replaces the `LobbyEdgeWalls` folder.

## Checks

- **Ground:** no wall overlaps any ground block.
- **Gaps:** I cast 3,600 rays outward from the plaza centre (0, 1500). Every one hit a wall before it left the ground.
- **Nothing outside:** probes 1 stud outside the edge found no ground, path or prop, so the walls don't block anything walkable. The practice field is switched off (`Layout.Practice.enabled = false`), so nothing expects players to leave on foot.
- **Playtest:** I drove the character outward in 22 directions from 3 studs inside the edge. It always stopped at the edge (centre about 0.5 studs in, or touching the steps on both sides on diagonals) and never fell; y stayed at about 13.

Note: during the playtest the lobby sometimes set the test character's `WalkSpeed` to 0 (with `EOS_AFK` false). That's unrelated to the walls; the test forced it back to 16.
