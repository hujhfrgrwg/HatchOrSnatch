---
tags: [research, roclicks]
source: https://roclicks.gg/resources/vfx/vfx-particles
retrieved: 2026-10-15
---
# VFX: particles, layering and colour

Build effects from ParticleEmitter, Beam and Trail with real textures. Don't build them from Parts, spheres or ball clusters.

## Contents

- [[#Particles over 3D objects]]
- [[#Textures]]
- [[#Layering an explosion]]
- [[#Colour: the sky tints your smoke]]
- [[#Beams, trails and rings]]
- [[#Verifying effects]]
- [[#Checklist]]

## Particles over 3D objects

Build effects from `ParticleEmitter`, `Beam` and `Trail` with real textures. Don't build them from Parts, spheres or ball clusters.

What happened: explosions looked "flat, terrible coloring", so they were rebuilt as shaded 3D ball-cluster puffs. The developer's reply: he wanted actual VFX, not 3D objects. The puff layer was thrown away.

- Fix flatness with particle technique (layers, ramps, opaque smoke), never with geometry.
- No Neon cylinder "rings" either. A flat shockwave **particle** (oriented `VelocityPerpendicular` or a flat ring texture) plus a glow reads better and is cheaper.
- No physics-Part debris. Use a debris flipbook emitter with gravity (`Acceleration`) and drag.
- Delete dead part-based effect code once it's replaced, or the next agent revives it.

## Textures

- Use **one** licensed texture pack per project; don't mix packs (styles clash). Read the licence: some packs forbid AI training or redistribution. Never ship ripped textures from other games.
- Catalogue the pack once: file, category, flipbook grid (2x2, 4x4, 8x8), background (alpha or black) and the uploaded id. A catalogue lets an agent pick "soft opaque smoke" instead of guessing from file names.
- **Black-background textures** only work additively: `LightEmission = 1`. They can't do dark smoke.
- **Flipbooks:** set `FlipbookLayout` to the grid and `FlipbookMode` (`OneShot` for blasts, `Loop` for fire, `Random` for variety). Some flipbooks break up in their last cells; cut them with the transparency curve (fully transparent from ~80% of life).
- Upload many small textures as a batch. For UI-style sprites, a sprite sheet with `ImageRectOffset` is one upload instead of forty.

## Layering an explosion

A good blast stacks about 8–12 emitters, each with its own job and timing:

| Order | Layer                        | Settings that matter                                                                   |
|-------|------------------------------|----------------------------------------------------------------------------------------|
| 1     | **Flash**                    | 1 particle, 0.1 s, `LightEmission 1`, brightness 1.6, warm white                       |
| 2     | **Glow**                     | 1 particle, 0.18 s, larger, orange, fades from 0.55 transparency                       |
| 3     | **Fire core**                | 2–4 particles, 0.25 s, random flipbook, fast drag                                      |
| 4     | **Fireball**                 | flipbook fire, 1–1.4 s, slight upward `Acceleration`, size ease-out then slow growth   |
| 5     | **Fire licks**               | narrower spread (~75°), faster, slightly delayed (0.03 s)                              |
| 6     | **Smoke body**               | soft **opaque** smoke, `LightInfluence 1`, `LightEmission 0`, 1.5–3 s, rises and grows |
| 7     | **Sparks / embers**          | small, `LightEmission 1`, gravity, drag                                                |
| 8     | **Debris**                   | flipbook chunks with gravity                                                           |
| 9     | **Dust skirt + ground ring** | flat, warm, wide, short                                                                |

Techniques that removed the "flat" look:

- **Offset spawn shapes** (a sphere shell for smoke, a disc for dust) so layers don't all come from one point.
- **Random rotation** (`Rotation` -180..180, `RotSpeed` -60..60).
- **Staggered delays**: 0, 0.01, 0.02, 0.03 s between layers.
- **Size sequences** that punch out fast (12% of life) then grow slowly.
- **Colour sequences** from hot white-yellow to orange to red-brown to grey, instead of one colour.

## Colour: the sky tints your smoke

Smoke with `LightInfluence 1` is shaded by the scene, which is what makes it look volumetric. But it also picks up the sky's ambient colour. Under a bright cyan sky ambient, grey smoke measured about 0.75 R / 1.05 G / 1.2 B of its set colour: it rendered **blue-cyan**, not grey.

- Pick **warm** smoke colours, especially for the late (light) keys: tan and warm brown like `(204,152,120)`, which renders as neutral grey under a cyan sky.
- Keep smoke **opaque** for most of its life (transparency ~0.05–0.15). A see-through puff lets even more sky colour through.
- A "white" flash may need `(236,204,176)` to render as warm white.
- **Judge rendered pixels, not properties.** Sample the colour from a screenshot under the game's real lighting.

## Beams, trails and rings

- A `Beam` runs the image's **vertical** axis along its length. If the texture is a horizontal streak, upload a rotated copy.
- Tracers: a short `Beam` between two attachments moved per frame, or a `Trail`. Cap them (30/60/90 by quality).
- Projectiles: a small part or attachment with a smoke `Trail` plus a thruster emitter; cap them too (10/24/32).

## Verifying effects

- **Particles freeze in edit mode.** A static edit-mode screenshot shows an emitter mid-air or nothing. Verify in a playtest.
- Burst effects need a trigger to be seen. For a showcase, one small demo script per group calls `:Emit()` every 2–3 s.
- Capture each effect at its peak, from the **player's camera height and angle**, under the game's real lighting.
- The effect should read at the game's scale. At 1/4 world scale a soldier is ~1.25 studs, so a 20-stud explosion is a nuke.

## Checklist

- No Parts, spheres, Neon rings or physics debris in any effect.
- One texture pack; licence read; catalogue with grid, background and id.
- Black-background textures use `LightEmission 1`; smoke uses soft opaque textures with `LightInfluence 1`.
- Explosions are layered (flash, fire, smoke, sparks, debris, dust) with offsets, rotation and staggered delays.
- Smoke colours are warm, checked against rendered pixels under the real sky.
- Effects verified in a playtest at the player's camera, not in edit mode.

Previous: [[Sound and VFX overview]] · Next: [[Feedback juice]]
