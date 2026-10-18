---
tags: [delivery]
ticket: HOS-LOBBY-003
date: 2026-10-18
---
# HOS-LOBBY-003: Pro lobby gate

The pro altar (HOS-LOBBY-002) now has a tall glowing beam wall round it and a **PRO LOBBY / LOCKED** sign over each entrance. Both fade in as a player walks up and fade out as they walk away. There's no pro league backend yet, so this is visual only.

## What's in Studio

`Workspace.CentralAltar.ProAltar.ProGate`, built by `tools/build/HOS-LOBBY-002_pro_altar.lua` with the rest of the altar.

- **Beam wall** (revised 18 Oct per Matthew): one flat beam per side, plus twinkling streaks. A 27.6 × 27.6 square (half-width `GATE` = `HALF` + 2.8), about a stud in front of the bottom step. The jack-o'-lanterns moved out to `HALF` + 5.2 and sit just outside its corners.
  - **Wall:** 27.9 wide (the full side), 70 tall, not camera-facing. The incubator's purples (180,92,255 into 166,64,255), with a transparency gradient from 0.74 at the bottom to 0.95 by 40% of the height and fully clear at the top.
  - **Glow band:** a second full-length beam on each side, 9 tall, purple (no white), 0.72 fading to 1.
  - **Streaks:** 14 thinner flat beams per side over the wall for texture. They have irregular positions across the whole side (behind the sign too), widths 0.25–1.85, heights 20–65 and a base transparency of 0.6–0.82, seeded per side so a rebuild gives the same pattern. Each is a hair further out than the last, so none share a plane. They carry a `Twinkle` attribute, and `ProximityFade` fades each one in and out on its own random rhythm like a sparkle, on top of the distance fade.
  - **Ground line:** a thin neon line on the ground under each wall.
  - **Orientation:** a flat (not camera-facing) beam's width runs along its attachments' **Y** axis. Each beam's attachments have X = up (the beam's run), Y = along the side (the width) and Z = outward (the face). The first flat version had Y = outward: the four sheets stuck straight out from the side midpoints and crossed the whole lobby in a plus. Matthew caught it from a top-down view.
- **Signs:** text only (18 Oct, Matthew: no bricks). One over each entrance, facing out, just in front of the wall, centred 9.6 studs up.
  - **Text:** "PRO LOBBY" over "LOCKED", the incubator sign's lavender (230,200,255) GothamSSm Heavy.
  - **Outline:** a 6 px near-black purple outline (24,6,44). SurfaceGui brightness 1.2.
  - **Backdrop:** a soft dark glow behind the text (GUI only, no part). It's a dark purple (16,6,30) pill `Frame` at 0.35 transparency whose `UIGradient` fades it out at both ends, so the text stands off the white of the beams.
  - **Holder:** the text sits on an invisible holder part (`Sign`, transparency 1).
  - **Static:** it doesn't turn to face the player.
  - **Not always-on-top:** I tried `AlwaysOnTop` to stop the wall washing the text out. With it, Roblox didn't draw the text at all, first with a CanvasGroup and then without one, so it's off.
- **Barrier:** `ProAltar.GateBarrier` holds four invisible walls on the gate line, 1 thick and 30 tall, so players can't get into the square while it's locked. They're `CanQuery` off (the camera passes through) and `CanTouch` off. They touch none of the altar's parts.

## The fade (client)

- **Controller:** new ModuleScript `StarterPlayer.StarterPlayerScripts.EOS.Controllers.ProximityFade`, started from `ClientMain` straight after `FacePlayer`.
- **What it fades:** any model tagged `EOS_ProximityFade`. The ProGate model carries the tag.
- **Distance:** measured flat from the model's pivot (the plaza centre), against the model's attributes:
  - `FadeFar` = 25: it starts fading in when the player comes within 25 studs of the altar's centre (hidden beyond).
  - `FadeNear` = 17: fully shown within 17 studs. The barrier stops players at about 14.8, so at the wall it's always fully shown.
  - Change those two attributes to tune it.
- **How each piece fades:**
  - Beams and parts use `LocalTransparencyModifier`.
  - Text fades through `TextTransparency`, outlines through `UIStroke.Transparency` and the backdrop `Frame` through `BackgroundTransparency`. CanvasGroups (`GroupTransparency`) are still supported, but the signs no longer use one.
  - Lights dim through `Brightness`.
  - It's smoothed over about a quarter of a second, and pieces that stream in later join the fade.
  - All of this is client-only, so each player sees only their own fade.
- **Twinkle:** beams with the attribute `Twinkle = true` also pulse on their own sine (0.9–2.4 rad/s, random phase, squared so they spend longer dim).
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
- **Stairs:** before the barrier, walking in from outside with real key presses, the character climbed the steps, crossed the dais and stopped on the circle, standing on the disc and inside `SummonZone`.
- **Barrier:** with real key presses the character stopped against the barrier straight on (14.8 studs from the centre, wall face at 14.3) and in a corner (outside on both axes).
- **Twinkle:** sampled over 2 seconds, the streaks swung independently between about 0 and 1 while the main wall stayed fully shown.
- **Movement note:** the game moves characters with its own controller (`EOS_MoveDrive`) and keeps `Humanoid.WalkSpeed` at 0. Scripted `Humanoid:Move` does nothing, so movement tests need real key input.

## Backups

`docs/backups/HOS-LOBBY-003_2026-10-18/ClientMain.lua` (before the one added line).

## Fade distances re-checked (18 Oct)

| Distance from centre | 30 | 26 | 25 | 23 | 21 | 19 | 17 | 15 |
|---|---|---|---|---|---|---|---|---|
| Wall fade (1 = hidden) | 1.00 | 1.00 | 1.00 | 0.75 | 0.50 | 0.25 | 0.00 | 0.00 |
