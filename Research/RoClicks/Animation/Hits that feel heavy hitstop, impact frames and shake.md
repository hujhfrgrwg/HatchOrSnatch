---
tags: [research, roclicks]
source: https://roclicks.gg/resources/animation/hit-feel
retrieved: 2026-10-15
---
# Hits that feel heavy: hitstop, impact frames and shake

The frame-level tricks that sell an impact: freezing time, flashing the screen, and camera shake that doesn't drift.

A hit that lands on the right frame with the right pause feels twice as strong as the same animation without them.

## Land the effect on the hit frame

Mark the keyframe where the hit connects with a KeyframeMarker (for example `Impact`) and trigger everything from `track:GetMarkerReachedSignal("Impact")`: the effect, the sound, the damage number, the shake. Timing them with `task.wait` drifts as soon as the animation speed changes.

## Anticipation

Effects start **before** the hit. A glow that shrinks into the contact point over 0.1 to 0.15 s, or particles gathering inward, tells the eye where to look a beat early.

## Hitstop

Freeze the effect, and ideally the attacker's animation, for a few frames at contact. Drive particles, meshes, lights and trails from one clock so a freeze or a slow-motion moment keeps them all in step. A slowed smoke layer that keeps playing at full speed breaks the illusion.

## Impact frames

One to three frames of a full-screen colour flash via `ColorCorrectionEffect`:

- **black frame:** Contrast 2 to 3, Saturation -1;
- **white frame:** Brightness 1, Saturation -1;
- the two can overlap about 0.15 s apart.

Use them on big moments only. On every hit they become noise.

## Camera shake that doesn't drift

- **Rotation only**, and gated by distance (fade it out between about 150 and 350 studs).
- **Take each frame's offset back off.** The player's camera computes its next frame from where it is now, so a shake written as `camera.CFrame *= offset` every frame accumulates and tips the view.
- **Always stop sustained shakes.** A shake left running is the most common "my camera is broken" report.

## How long each part lives

| Element               | Lifetime       |
|-----------------------|----------------|
| Flash, impact frames  | 0.03 to 0.15 s |
| Crescents and slashes | 0.15 to 0.4 s  |
| An explosion's body   | 0.35 to 1.2 s  |
| Rings and debris      | 0.4 to 1.4 s   |

> Partly adapted from Roqer's `roblox-animation-vfx` skill (github.com/S4US/Roqer, MIT licence, TabooHarmony).

Previous: [[Rigging models that move cleanly]]
