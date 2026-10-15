---
tags: [research, roclicks]
source: https://roclicks.gg/resources/tricks/ai-3d-props-that-fit
retrieved: 2026-10-15
---
# AI 3D models that fit a stud-style game

Build the world from parts; use AI models only for organic shapes, prompted as chunky toy plastic, with the texture projected from the concept so it stays crisp.

AI 3D generators (Meshy and friends) are great at creatures, characters and organic props, and bad at everything a stud-style world is made of. Splitting the work this way keeps the game looking like one game.

## Who makes what

- **Parts:** the world. Ground, buildings, paths, plots, machines. Free, exact, and already in the style.
- **Mesh editing (EditableMesh):** the two or three detailed pieces on a hero prop: a gear ring, a bezel, a wheel rim, chamfered trim.
- **AI 3D:** only what parts can't do well: characters, creatures, plants, weapons with curves.

## Prompt the concept like this

``` text
[the object], chunky stylised toy, smooth plastic with flat solid colours, simple readable shapes, slightly oversized proportions, no realistic detail, no noise or grain, side view, pure white background, no shadow
```

- **"Flat solid colours" and "toy plastic"** make it sit next to studded parts instead of looking like it came from another game.
- **"Side view, pure white background"** is for the texture fix below.

## Fix the smeared texture

AI-generated textures are a patchwork of hundreds of tiny pieces, with colour smeared across the seams, so stripes and edges come out blotchy. Recolouring each triangle doesn't fix it: edges come out jagged.

What works: clean the concept image (cut it down to a handful of flat colours), then project it straight onto the model from the side, trying all four flips and keeping the one whose outline overlaps best. That gave 82 to 94% outline overlap and crisp colour borders.

``` text
The texture on this model is smeared. Fix it by projection instead of repainting:
1. Clean the concept image: background is anything with min(r,g,b) >= 248; keep only connected areas at least 3% the size of the biggest; reduce to at most 7 flat colours (k-means), drop colours under 3% of the object; mode-filter, then bleed colours outward to fill.
2. In Blender, planar-project the cleaned concept onto the model along its thinnest axis. Try all 4 flips and keep the one whose silhouette overlaps the concept best, then nudge each edge of the projection box to maximise that overlap.
3. Report the overlap score and show me before and after renders.
```

For the curved detail pieces (bevels, rims, gear teeth) you can skip the AI and the upload entirely: model them in code with EditableMesh and preview them outside Studio with [[Build your game outside Studio with Lune|Lune]].

Previous: [[Get scripts and images into Studio fast]] · Next: [[Build your game outside Studio with Lune]]
