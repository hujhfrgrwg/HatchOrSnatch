---
tags: [research, roclicks]
source: https://roclicks.gg/resources/building/chunky-not-blocky
retrieved: 2026-10-15
---
# Chunky, not blocky: shape language for stud builds

Three tiers of detail, breaking the box, stepped roofs, and why maps need altitude.

"Blocky" is a box with a texture on it. "Chunky" is a box that has been designed. The difference is detail at the right scale.

## Build in three tiers

1.  **Massing, in whole studs:** the body of the house, the tower shaft, the ground slab.
2.  **Mid detail, 0.5 to 1 stud:** window and door frames that protrude 0.1 to 0.3 from the wall, corner posts, trim bands at floor lines, sills, fence posts.
3.  **Fine detail, 0.1 to 0.4 studs:** shingle lips, petals, handles, lamp fittings.

A build with only tier 1 looks unfinished. A build with only tier 3 looks cluttered. Most of the surface should be tier 1, framed by tier 2, with tier 3 where the eye lands.

## Break the box

Cube rooms and long flat walls are the signature of a beginner build.

- Footprints get notches, L-shapes and stepped-out wings instead of one rectangle.
- Long walls get piers, pilasters, insets or windows every **8 to 12 studs**, so no wall reads as a single slab.
- Towers get corner posts and a trim band every ~6 studs.

## Stepped roofs

Prefer stacked slabs that shrink as they rise: rows about 1.2 studs tall, each 2 studs narrower than the last, overhanging the walls by 1 to 2 on the first row. Four to seven rows reads well. Wedges are fine as accents (dormers, canopies) but a roof made entirely of wedges loses the style.

## Stay rectilinear

Balls are for very rare tiny accents: a lamp bulb, a doorknob. Never for foliage or massing. Use cylinders sparingly (poles, barrels); trunks and pillars read better as square posts.

## Unions are for shape, never for performance

Reach for `UnionAsync`/`SubtractAsync` when steps can't make the shape: arches, round-cornered slabs, wheel arches, clean door openings. Never union "to save parts". A plain Part is already the cheapest thing Roblox renders; a union is a unique shape the engine has to compute, with poorly optimised triangles.

## Maps have altitude

Never build an outdoor map on one plane. Add a raised plateau at one end (4 to 6 studs up), corner hills and a sunken area. Hills should look **grown from the ground, not placed on it**: two to four overlapping earth-toned blocks of different heights, clipped into each other, with an overhanging grass cap.

## Block out first

For whole maps, lay rough placeholder volumes for every zone (ground, hills, water, building footprints, spawns, lanes), screenshot it, and agree the layout **before** any detail. Moving a box is free; moving a finished building is an afternoon.

Previous: [[Stud-style surfaces that look intentional]] · Next: [[No gaps seams, openings and transparent parts]]
