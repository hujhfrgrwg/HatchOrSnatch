---
tags: [research, roclicks]
source: https://roclicks.gg/resources/tricks/check-a-build-with-screenshots
retrieved: 2026-10-15
---
# Check a build with 12 screenshots before showing anyone

Four aerial shots hide what players see. Full lighting, a dozen player-height shots, fix, re-shoot, then present.

A map that looks fine from above can be empty, blocky and clipping at eye level. This is the check that catches it, and it's quick to hand to an AI agent.

## Paste this into your agent

``` text
Before you show me this build, check it properly:
1. Apply the full map lighting first (Atmosphere, Bloom, ColorCorrection, SunRays, whatever the game uses at runtime). Judging under default lighting doesn't count.
2. Take at least 12 screenshots at player height (about 5 studs up) covering every zone, plus 2 aerials. For each shot set the camera position AND its focus point, then confirm it is looking where you meant.
3. For every shot, list what's wrong: empty areas, gaps between parts, z-fighting (flickering overlapping faces), parts clipping through each other, flat lighting, props that look like stacked boxes, anything floating.
4. Fix everything on the list.
5. Re-shoot the same 12 angles and compare. Only then show me, with the before and after list.
Do not start a playtest. Do all of this in edit mode.
```

## Why each step matters

- **Full lighting.** Colours and contrast change a lot once the real lighting is on. A build judged without it gets judged twice.
- **Player height.** Aerials hide empty lanes, blocky props and clipping. Players never see the map from above.
- **Set the focus.** In Studio's edit mode, setting only the camera's position lets its rotation snap back. Set where it's looking too, or half the shots point at the sky.
- **Re-shoot the same angles.** Otherwise "fixed" is a guess.

More on this: [[Verifying maps and models|verifying maps]].

Previous: [[Remake a map 11 from a gameplay video]] · Next: [[Get scripts and images into Studio fast]]
