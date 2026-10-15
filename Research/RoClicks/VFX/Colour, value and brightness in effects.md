---
tags: [research, roclicks]
source: https://roclicks.gg/resources/vfx/colour-value-brightness
retrieved: 2026-10-15
---
# Colour, value and brightness in effects

How many hues, where black belongs, when white is allowed, and reading the place's bloom before choosing brightness.

## Colour

- **One hue** is common for elemental skills (water blue, heal green, fire orange).
- **Two analogous hues** about 45 to 50 degrees apart (lime with gold) add richness without noise.
- **A complementary accent stays small:** about 10% of layers.
- **Saturated energy, desaturated matter.** Rings, flames and beams are saturated; smoke, dust and debris are not.
- **Smoke next to fire takes the fire's colour** where the fire lights it. Smoke away from fire comes in warm and grey pairs, lit by the scene.
- **Lights take the palette too.** One PointLight per hue tints the surroundings and sells the colour.

## Value: black is a colour

Black layers are 10 to 35% of emitters in good effects. A dark layer behind a bright one is what makes the bright one read as bright.

- **The three-value stack on impacts:** a colour layer, its black twin slightly behind, and a short white copy in front.
- **Stacked copies for an inner gradient:** three copies of one flame sheet at different sizes and colours give a hot core without drawing a new texture.
- **Glow that cools:** one copy at `LightEmission` 1 that dies first, and one unlit copy that lives longer.
- **Dark energy:** invert it. A black core with coloured edges.

## White is a thin shape, not a fill

Pure white is kept for thin, short-lived shapes: rings, flares, wind arcs, crescents. A white fill flattens everything around it.

## Brightness

- **Read the place's BloomEffect before choosing Brightness.** The same value blooms out in one place and looks dull in another.
- **Hard cel shapes:** `LightEmission` 0 (or negative) with Brightness 5 to 55.
- **Glows and halos:** `LightEmission` 1 at Brightness 1 to 6, often below 1.
- **The white-hot core:** one or two front layers at very high Brightness for a single frame or two.
- **A Decal's Color3 above 1 is overbright and blooms.** Tween it down for a crack that glows and cools.

## Lighting influence

`LightInfluence` 0 keeps a glowing layer at its own colour. Smoke reads better lit by the scene, at 0.35 to 1.

> Parts of this guide are adapted from the VFX half of Roqer's `roblox-animation-vfx` skill (github.com/S4US/Roqer, MIT licence, TabooHarmony), measured and extended in Studio.

Previous: [[Anatomy of an impact]] · Next: [[Projectiles, beams, trails and sustained effects]]
