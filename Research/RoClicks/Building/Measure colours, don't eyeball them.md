---
tags: [research, roclicks]
source: https://roclicks.gg/resources/building/colours-and-remakes
retrieved: 2026-10-15
---
# Measure colours, don't eyeball them

Sampling a reference's palette, building 1:1 remakes from a video, and checking a map the way players will see it.

Eyeballed colours drift the moment Studio lighting is applied. If you are matching a reference, measure it.

## Sample the palette

1.  Pull stills from the reference video (`ffmpeg -ss 00:00:12 -i ref.mp4 -frames:v 1 still.png`).
2.  Take the **median** RGB of each surface region, not one pixel. Medians ignore highlights and noise.
3.  Render the same area in Studio under the real lighting (Atmosphere, Bloom, ColorCorrection, SunRays all on) and compare against the still.
4.  Adjust until they match, including the global lighting grade, not just part colours.

Keep the results in one palette file per game, so every later prop uses the same numbers.

## 1:1 remakes: the video is the spec

When the job is "remake this map", match it **exactly**. Invented trims, recolours and renamed signs read as wrong the instant someone compares side by side.

- Measure sizes from things of known size: an avatar is about **5 studs** tall, and the stud grid gives you the rest.
- Make side-by-side images (video still next to a Studio shot from the same angle) for every landmark.
- Add nothing the video doesn't show. Areas the video never shows get flagged, not invented.

## Check it the way players see it

A few aerial shots hide what players actually see: empty lanes, clipping props, flat lighting. Before calling a map done:

1.  Apply the full map lighting.
2.  Take **12 or more player-height shots** covering every zone, plus 2 aerials.
3.  Write down every defect, fix them, and re-shoot **the same angles**.

Previous: [[No gaps seams, openings and transparent parts]] · Next: [[Detail props without the AI look]]
