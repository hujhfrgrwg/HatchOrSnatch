---
tags: [research, roclicks]
source: https://roclicks.gg/resources/building/detail-props
retrieved: 2026-10-15
---
# Detail props without the AI look

Where to spend mesh detail, how round is too round, and the props vocabulary that reads as made by a person.

Stacked boxes read as amateur on a hero prop. Spheres and neon read as AI. The sweet spot is in between.

## Mesh detail on two or three focal pieces

Most of a prop stays plain studded Parts. Put modelled detail (EditableMesh or a mesh part) on only **2 to 3 focal pieces per object**: a gear ring, a bezel, a wheel rim. Not every piece needs modelling, and the simpler pieces make the detailed ones stand out.

## Not too round

"More modelled" means crisp chunky silhouettes with **small** detail: 0.2 to 0.4 stud chamfers, mouldings, recessed panels, gear teeth, rivets, vents. When everything gets rounded off, props turn pill-shaped and stop matching the stud world. Only small bits are round: bulbs, buttons, antenna tips.

## The vocabulary of a real machine

Make props read as mechanical, not decorative:

- bolts, pipes with flanges, gears, cranks, gauges, hatches, vents;
- at most one or two small plastic indicator lamps;
- spheres only where they have a job (a knob, a bulb).

Neon glow strips and random decorative orbs are the two strongest "AI-generated" tells. Leave them out.

## Variants keep the style

When asked for alternative designs, keep the reference's materials, palette and detail vocabulary, and change **shape language and structure** instead: an arcade cabinet, a gantry tower, a dome. "Make it different" almost never means "make it candy-themed".

## EditableMesh detail is rebuilt at runtime

A mesh built with EditableMesh is **not saved with the place**. Keep a marker part ("mesh spot") where each detail mesh goes, and bake the mesh onto it when the game starts. Designing for that from the start avoids discovering an empty map after the first reload.

Previous: [[Measure colours, don't eyeball them]]
