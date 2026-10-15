---
tags: [research, roclicks]
source: https://roclicks.gg/resources/building/stud-style-surfaces
retrieved: 2026-10-15
---
# Stud-style surfaces that look intentional

Materials, stud patterns and the two exceptions that separate a polished stud build from a noisy one.

Stud style lives or dies on surfaces. The shapes can be simple; the surfaces have to be consistent.

## Use MaterialVariants when the place has them

Check `MaterialService` before every build and only use the variants that actually exist there. Set the part to `Plastic` and apply the stud variant on top. If the place has no variants, fall back to SurfaceTypes on all six faces (`TopSurface`, `BottomSurface`, `FrontSurface`, `BackSurface`, `LeftSurface`, `RightSurface`).

Never assume a variant exists because it existed in another place. A missing variant name silently renders as plain plastic.

## Decide a pattern map by role, then apply it everywhere

Pick the pattern for each **role** before placing anything:

| Role                                         | Pattern                                      |
|----------------------------------------------|----------------------------------------------|
| Structure: posts, rails, frames, crates      | Weld                                         |
| Big fills: terrain, panels, floors           | Universal or studs without grid              |
| Rocks and raw ground props                   | Studs on the **top face only**, smooth sides |
| Anything under ~0.5 studs in every dimension | Plain smooth plastic                         |

Every copy of a repeated element gets the same pattern. Consistency beats variety: three fence posts with three different textures reads as a mistake, not as detail.

## The two exceptions

- **Rocks** get the stud inlet on the top face only. Studs on the sides of a rock look like a crate.
- **Tiny parts** (bolts, door handles, petal tips, lamp fittings) skip the pattern entirely. At that size studs are visual noise and clean plastic reads better.

## Neon is an accent, never a body

Neon belongs on thin glow strips, trim edging, lava, portals and the one glow cue that marks a zone's important thing. A whole neon wall, or neon strips on every prop, is the fastest way to make a build look AI-generated.

## Checkered ground is a texture, not coloured plates

The two-tone checkerboard on big studded ground is a tiling `Texture` instance laid over the studded part, not a grid of alternating coloured plates. Plates cost thousands of parts and z-fight at every seam; one texture costs nothing.

## Studs on tops earn their keep

Even when a build relies on modelled relief, studded top faces (roof courses, wall tops, ledges) are part of the charm. Don't strip tops to smooth without a reason.

Previous: [[Tools pushing, pulling and checking code]] · Next: [[Chunky, not blocky shape language for stud builds]]
