---
tags: [research, roclicks]
source: https://roclicks.gg/resources/vfx/impact-recipe
retrieved: 2026-10-15
---
# Anatomy of an impact

A layer-by-layer timeline for hits and explosions, with the numbers, and why an explosion should keep growing after the flash.

A good hit is one emit where every layer has a different lifetime. The order in which layers disappear is what makes it feel like progression. R below is the effect's radius in studs.

## The timeline

| Time from hit | Layer         | What it is                                                                                      |
|---------------|---------------|-------------------------------------------------------------------------------------------------|
| -0.15 s       | Anticipation  | A glow that shrinks from 1.5R to 0 over 0.1 to 0.15 s, spinning fast                            |
| 0             | Flash         | A soft ball or four-point flare, 0 to 2.5R, lifetime 0.06 to 0.1, Brightness about 10, in front |
| +0.03 s       | Impact stars  | A spiky sheet, lifetime 0.075 to 0.15, 2 to 6 per emit, as colour + a black twin + a white copy |
| +0.03 s       | Black backing | A soft black blob behind everything, 2 to 4R                                                    |
| +0.05 s       | Streaks       | `VelocityParallel` with Squash, speed 60 to 200, drag 8 to 12                                   |
| +0.05 s       | Ring          | A flat ring growing to 2 to 3R over 0.2 to 0.4 s                                                |
| +0.05 s       | Smoke         | Constant-size puffs, speed 50 to 120, drag 8, lifetime 1 to 1.5, a warm and a grey layer        |
| +0.05 s       | Embers        | Dots at `LightEmission` 1, speed 10 to 120, drag 10, lifetime 0.75 to 2                         |
| 0             | Light         | A PointLight at Brightness 7 to 16, Range 7 to 15, fading over 0.5 s                            |

Treat it as a floor, not a target. Fill each role with your own textures and colours so it looks made for your game.

## Intensity only goes down

Plot intensity against time: it peaks at the emit and only falls. Three readable stages:

1.  the big flashy energy, with wind;
2.  the scatter: debris and fragments moving outward, flash gone;
3.  the residue: dust settling, a faint glow, the last smoke.

Nothing in the middle or at the end gets brighter again.

## But an explosion's mass keeps growing

Brightness falls; **size** shouldn't, not yet. In measured explosions, the screen area of live particles kept growing for 0.25 to 1.35 seconds after the hit: flames, smoke and crescents swell while the flash dies. A finisher that is biggest at its flash and then only shrinks reads as a pop, not an explosion. The mass comes from body layers (crescents, flame tongues, puffs) that outlive the flash. Sparks and shards are accents, not mass.

## Stagger cause and effect

Nothing fires at exactly the same time. The wall launches, then the creature appears, then the hit, then the cracks, then the debris. Simultaneous layers read as noise.

## The cheapest strong trick

A thin flat shockwave disc that grows from small to massive in 0.2 s while its transparency goes from 0 to 1.

> Parts of this guide are adapted from the VFX half of Roqer's `roblox-animation-vfx` skill (github.com/S4US/Roqer, MIT licence, TabooHarmony), measured and extended in Studio.

Previous: [[Sound and VFX checklist]] · Next: [[Colour, value and brightness in effects]]
