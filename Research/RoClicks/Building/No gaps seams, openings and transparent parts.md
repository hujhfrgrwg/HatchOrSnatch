---
tags: [research, roclicks]
source: https://roclicks.gg/resources/building/sealed-seams
retrieved: 2026-10-15
---
# No gaps: seams, openings and transparent parts

The door test, why clipping is a bug between things but a technique inside a model, and how transparent parts expose sloppy seams.

A build looks broken long before it looks ugly. Most "broken" comes from gaps.

## No gaps, ever

Windows, doors, frames, sills and trim must touch what they meet. A hairline gap between a jamb and its wall, or a sill floating 0.1 off the wall, reads as broken, not as detail.

## The door test

An opening is finished only when **no sight line escapes it**:

- the frame fills the opening on all four sides (head, both jambs, threshold or sill);
- every frame member overlaps about 0.1 into the wall around it;
- the leaf or pane sits inside the frame, not floating in the hole.

## A door is a framed panel, not a bare pane

Give each leaf side stiles (0.4 to 0.5), a top rail, a chunky bottom rail (1 to 1.5), a mid rail at handle height, and glass or panel insets embedded 0.2 into the rails. A flat slab with a handle reads as a placeholder.

## Clipping: a bug between things, a technique inside a model

- **Inside one model**, parts may interpenetrate to build its form: canopy tiers sinking into each other, rock slabs clipped together, path segments chained into one path.
- **Between things**, never. Windows and doors own their wall space: build the wall in strips around the opening or negate it out, then fit the frame in. Never stamp a window through an unbroken wall.

## Transparent parts: one layer, buried edges

Transparency double-punishes sloppy seams. Any gap behind a transparent part glows through it, and stacked transparent slabs sort against each other and shimmer. Use **one** transparent layer and bury its edges into the frame.

## Wedges flatten junctions

When two parts of different heights meet and the step isn't a deliberate feature, cap the junction with a WedgePart so it ramps instead of jumping.

## Hanging lines stay connected

Cables, ropes and chains are a chain of segments along a sagging curve, with each end embedded about 0.2 into the thing it hangs from. A wire that stops short of its pole is the most visible gap on any map.

Previous: [[Chunky, not blocky shape language for stud builds]] · Next: [[Measure colours, don't eyeball them]]
