---
tags: [delivery]
ticket: HOS-LOBBY-003
date: 2026-10-18
---
# HOS-LOBBY-003: Pro lobby gate

The pro altar (HOS-LOBBY-002) now has a tall glowing beam wall round it and a **PRO LOBBY / LOCKED** sign over each entrance. Both fade in as a player walks up and fade out as they walk away. There's no pro league backend yet, so this is visual only.

## What's in Studio

`Workspace.CentralAltar.ProAltar.ProGate`, built by `tools/build/HOS-LOBBY-002_pro_altar.lua` with the rest of the altar.

- **Beam wall:** a 32 × 32 square (half-width `GATE` = `HALF` + 5), just outside the stairs and jack-o'-lanterns. On each side:
  - A curtain of camera-facing columns every 2 studs: 1.6 wide, 70 tall, purple.
  - A transparency gradient from 0.72 at the bottom to 0.93 a third of the way up and fully clear at the top.
  - Brighter 0.6-wide pillars at the corner and either side of the entrance.
  - A thin neon line on the ground under the wall.
- **Signs:** a flat sign at each entrance, about 0.6 studs in front of the wall, 6–9.4 studs up, facing out.
  - 9 × 3.4 studs; the part is invisible and everything shows through its `SurfaceGui`.
  - A dark panel with a purple edge and a gold inner line.
  - "PRO LOBBY" in gold and "LOCKED" in red, in the lobby boards' font (GothamSSm Heavy).
  - It's static: it doesn't turn to face the player.
- **No collision:** nothing in the gate blocks movement, and players can still walk up to the summoning circle. Blocking entry would need either a wall or a server check once pro access exists.

## The fade (client)

- **Controller:** new ModuleScript `StarterPlayer.StarterPlayerScripts.EOS.Controllers.ProximityFade`, started from `ClientMain` straight after `FacePlayer`.
- **What it fades:** any model tagged `EOS_ProximityFade`. The ProGate model carries the tag.
- **Distance:** measured flat from the model's pivot (the plaza centre), against the model's attributes:
  - `FadeNear` = 24: fully shown within 24 studs of the centre, about 8 from the wall.
  - `FadeFar` = 36: fully hidden beyond 36.
  - Change those two attributes to tune it.
- **How each piece fades:**
  - Beams and parts use `LocalTransparencyModifier`.
  - The signs' `CanvasGroup` uses `GroupTransparency`.
  - Lights dim through `Brightness`.
  - It's smoothed over about a quarter of a second, and pieces that stream in later join the fade.
  - All of this is client-only, so each player sees only their own fade.
- **Reuse:** to make anything else fade by distance, tag its model `EOS_ProximityFade` and give it `FadeNear` / `FadeFar`.

## Checked in a playtest

- **Fade:** walking in and out along one axis gave these values, the same both ways, for all 76 beams and the signs.

  | Distance from centre | Fade (1 = hidden) |
  |---|---|
  | 50 | 1.00 |
  | 40 | 1.00 |
  | 32 | 0.67 |
  | 26 | 0.17 |
  | 20 | 0.00 |

- **Errors:** none in the output.
- **Look:** the first version was a washed-out white wall from an angle. Thinner columns, more transparency and a lower brightness fixed it. The altar now shows through, and the sign reads clearly in front of the wall.
- **Stairs:** walking in from outside with real key presses, the character climbed the steps, crossed the dais and stopped on the circle, standing on the disc and inside `SummonZone`.
- **Movement note:** the game moves characters with its own controller (`EOS_MoveDrive`) and keeps `Humanoid.WalkSpeed` at 0. Scripted `Humanoid:Move` does nothing, so movement tests need real key input.

## Backups

`docs/backups/HOS-LOBBY-003_2026-10-18/ClientMain.lua` (before the one added line).
