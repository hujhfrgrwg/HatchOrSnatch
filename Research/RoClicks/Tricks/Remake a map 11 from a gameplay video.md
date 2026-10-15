---
tags: [research, roclicks]
source: https://roclicks.gg/resources/tricks/remake-a-map-from-a-video
retrieved: 2026-10-15
---
# Remake a map 1:1 from a gameplay video

The video is the spec. Pull frames, measure from the avatar, sample real colours, and compare side by side until nothing is invented.

When you're remaking a map from another game or a reference video, "close enough" reads as wrong the moment anyone puts the two side by side. These steps get it right first time.

## The rules

- **The video is the spec.** Add nothing it doesn't show. Areas the video never shows get flagged to you, not made up.
- **Measure, don't eyeball.** An avatar is about 5 studs tall: use it and the stud grid as rulers for every size and gap.
- **Sample colours from stills.** Eyeballed colours drift once Studio lighting is on. Take the median colour of each surface from a still, then compare a Studio shot against the same frame and adjust, including the overall lighting.
- **Compare every landmark.** A still from the video next to a Studio shot from the same angle, for each one.
- **Detail where it counts.** Most of a prop stays plain parts. Put real modelling (mesh bevels, rims, gear teeth) on two or three focal pieces per object; stacked boxes read as amateur, but everything rounded reads as a toy.

## Paste this into your agent

``` text
Remake the map in [video file] 1:1 in Roblox Studio. The video is the spec: no artistic liberty, nothing it doesn't show.

1. Extract stills with ffmpeg (one every 2 seconds plus any frame that shows a new area). List every landmark and zone you can see, with timestamps.
2. Measure sizes and positions using the avatar (about 5 studs tall) and the stud grid as rulers. Write the measurements down before building.
3. Sample colours: for each surface, take the median RGB from the stills (not one pixel). Keep them in a PALETTE.md and use only those.
4. Build zone by zone. After each zone, take a Studio screenshot from the same angle as the matching still and put them side by side. Fix differences before moving on.
5. Anything the video never shows: list it and ask me. Do not invent it.
6. When done, give me the side-by-side images for every landmark.
```

## Why it works

Every rule here came from a remake that got sent back: invented trim, colours "a bit off" after lighting, and props that were either too blocky or too rounded. Measuring and comparing up front costs less than one round of fixes.

Previous: [[Make game UI from a screenshot]] · Next: [[Check a build with 12 screenshots before showing anyone]]
