---
tags: [delivery]
ticket: HOS-LOBBY-003
date: 2026-10-18
---
# HOS-LOBBY-003: Pro lobby gate

The pro altar (HOS-LOBBY-002) now has a tall glowing beam wall round it and a **PRO LOBBY / LOCKED** sign over each entrance. Both fade in as a player walks up and fade out as they walk away. There's no pro league backend yet, so this is visual only.

## What's in Studio

`Workspace.CentralAltar.ProAltar.ProGate`, built by `tools/build/HOS-LOBBY-002_pro_altar.lua` with the rest of the altar.

- **Beam wall** (revised 18 Oct after Matthew's feedback that the column curtain looked like a jail cell): one flat beam per side, a 32 × 32 square (half-width `GATE` = `HALF` + 5) just outside the stairs and jack-o'-lanterns.
  - **Wall:** 32.3 wide (the full side), 70 tall, not camera-facing. The incubator's purples (180,92,255 into 166,64,255), with a transparency gradient from 0.55 at the bottom to 0.92 by 40% of the height and fully clear at the top.
  - **Glow band:** a second full-length beam on each side, 9 tall, brighter at the foot (0.35 fading to 1).
  - **Ground line:** a thin neon line on the ground under each wall.
  - **Orientation:** a flat (not camera-facing) beam's width runs along its attachments' **Y** axis. Each wall's attachments have X = up (the beam's run), Y = along the side (the width) and Z = outward (the face). The first flat version had Y = outward: the four sheets stuck straight out from the side midpoints and crossed the whole lobby in a plus. Matthew caught it from a top-down view.
- **Signs:** text only (18 Oct, Matthew: no bricks). One over each entrance, facing out, just in front of the wall, centred 11.2 studs up so it sits above the bright glow band.
  - **Text:** "PRO LOBBY" over "LOCKED", the incubator sign's lavender (230,200,255) GothamSSm Heavy.
  - **Outline:** a 6 px near-black purple outline (24,6,44), so it reads against the glowing wall with no panel behind it. SurfaceGui brightness 1.2.
  - **Holder:** the text sits on an invisible holder part (`Sign`, transparency 1).
  - **Static:** it doesn't turn to face the player.
  - **Not always-on-top:** I tried `AlwaysOnTop` to stop the wall washing the text out. With it, Roblox didn't draw the text at all, first with a CanvasGroup and then without one, so it's off.
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
  - Text fades through `TextTransparency` and outlines through `UIStroke.Transparency`. CanvasGroups (`GroupTransparency`) are still supported, but the signs no longer use one.
  - Lights dim through `Brightness`.
  - It's smoothed over about a quarter of a second, and pieces that stream in later join the fade.
  - All of this is client-only, so each player sees only their own fade.
- **Reuse:** to make anything else fade by distance, tag its model `EOS_ProximityFade` and give it `FadeNear` / `FadeFar`.

## Checked in a playtest

- **Fade:** walking in and out along one axis gave these values, the same both ways, for all the beams and the signs (measured on the first, column version; the controller treats the new wall beams the same way).

  | Distance from centre | Fade (1 = hidden) |
  |---|---|
  | 50 | 1.00 |
  | 40 | 1.00 |
  | 32 | 0.67 |
  | 26 | 0.17 |
  | 20 | 0.00 |

- **Errors:** none in the output.
- **Look:** the first column version was a washed-out white wall from an angle, then read as jail bars once thinned. It's now one flat wall per side. After the axis fix, a top-down screenshot shows a closed square of light on the gate line with nothing outside it. A three-quarter view shows four walls meeting at the corners, and the incubator-style signs read clearly. (My earlier straight-on check missed the plus because the sheet facing the camera looked right from that angle; check from above.)
- **Fade with text-only signs:** the 8 wall beams, the 8 text labels and their outlines were all hidden at 50 studs, half at 30 and shown at 20.
- **Stairs:** walking in from outside with real key presses, the character climbed the steps, crossed the dais and stopped on the circle, standing on the disc and inside `SummonZone`.
- **Movement note:** the game moves characters with its own controller (`EOS_MoveDrive`) and keeps `Humanoid.WalkSpeed` at 0. Scripted `Humanoid:Move` does nothing, so movement tests need real key input.

## Backups

`docs/backups/HOS-LOBBY-003_2026-10-18/ClientMain.lua` (before the one added line).
