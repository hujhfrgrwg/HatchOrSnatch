---
tags: [research, roclicks]
source: https://roclicks.gg/resources/vfx/beams-trails-projectiles
retrieved: 2026-10-15
---
# Projectiles, beams, trails and sustained effects

Building things that travel or last: heads, ribbons, beam bodies, slashes without meshes, and auras that cross-fade.

## A projectile has three parts

- **A head:** one sprite, such as a `VelocityParallel` diamond pointing along travel.
- **Ribbons:** two or three textured Trails spread across about 5 studs.
- **Shed particles:** droplets or specks at 15 to 60 per second, with gravity or drag, left behind as it flies.

For arcing shots, move along a Bezier curve with two or three random control points 10 to 25 studs up. For volleys, fire 10 to 15 sources one every 0.1 s, fanned behind the caster.

## Beams

- **The body:** two or three camera-facing Beams, width 5 to 12.
- **Fill:** `VelocityParallel` flame streaks at a high rate along the beam.
- **The muzzle:** a crown of short curved beams and a flat shockwave ring at the source.
- **Duration:** hold the beam 3.5 to 5 s, then collapse the widths to 0 rather than fading it out.

## A slash without a mesh

Sweep a Trail through an arc. The two attachments define the ribbon's width; rotating them through the swing draws the crescent. Add a short white copy for the leading edge.

## Particles need a direction

A flat sprite has to be told which way to face:

- `VelocityPerpendicular` lays a sprite flat against its travel, for rings and ground shockwaves.
- `VelocityParallel` with `Squash` stretches a sprite along its travel, for streaks.
- Two copies at rotation -90 and +90 make a symmetric pair.

## Sustained effects: auras, charges, sigils

- **The stack:** stationary billboards on one attachment with speed near zero, `LockedToPart` on, so they follow the character.
- **The cross-fade:** Rate x Lifetime of about 2 to 4, and transparency fading in and out over each particle's life, so overlapping particles hide the seams. That's what makes a held aura shimmer instead of blink.
- **Size ladder:** core 1, rings about 2, halo about 3.5, black backdrop about 4.5.
- **Ground sigils:** 5 to 7 studs wide, spinning slowly (0.5 to 5 degrees a second), in two counter-rotating layers.
- **Anticipation for a charge:** a sphere emitter with `ShapeInOut` set to inward gathers particles toward the centre.

> Parts of this guide are adapted from the VFX half of Roqer's `roblox-animation-vfx` skill (github.com/S4US/Roqer, MIT licence, TabooHarmony), measured and extended in Studio.

Previous: [[Colour, value and brightness in effects]]
