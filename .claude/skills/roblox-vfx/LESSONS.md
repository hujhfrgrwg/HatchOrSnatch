# VFX lessons

Rules the developer has taught about effects, each with the moment behind it. Newest
at the bottom. These win over the references when they disagree. Add one entry
per piece of feedback: the rule, then **Why** (what happened) and **How to
apply**.

## 1. Actual VFX, never 3D objects

Build effects from ParticleEmitters, Beams and Trails with textures. Never
from 3D objects such as sphere or ball-cluster "puffs".

**Why:** after a "flat, terrible coloring" complaint on a strategy game's
explosions, they were remade as shaded 3D ball clusters, and those were rejected
too: they read as 3D objects, not effects.

**How to apply:** fix flatness with particle technique instead:
- layered flipbook emitters with offset spawn shapes, random rotation and
  staggered `EmitDelay`;
- colour and size sequences; a dark layer or black twin for value
  (`vfx-design.md` §3);
- soft opaque smoke textures at `LightInfluence` 1 so the scene shades them;
- warm colour ramps, and smoke beside fire carrying the fire's colour.

## 2. Bright ground: saturated colour, low glow, dark twins

On a bright map (Hatch or Snatch's cream sand arena under a clear sky), additive layers (LightEmission 1,
white-to-colour) vanish into the floor and sky. Read the effect from colour, not glow.

**Why:** the first Decoy and Guardian passes (17 Oct) were white smudges on the sand: rings, smoke and the
shield all washed out until the colour was carried by the texture tint instead of the light.

**How to apply:** LightEmission 0-0.3 on most layers; saturated archetype colour (a deep orange or blue, not a
pastel); a dark twin (same texture, near-black tint of the hue, a little larger, ZOffset just behind) under
every ring and beam; cel smoke tinted a saturated colour rather than cream; keep big PointLights dim (they
bloom the floor white). Particles sitting inside a body are hidden by it: put icon-style sprites (a shield
crest) above the head.

## 3. Beam textures run along the strip's V axis

A Beam wraps its texture so the image's vertical axis runs along the beam. Horizontal strip textures (most
"beam/trail" pack strips are drawn lying down) show as stripes across the beam: rotate them 90 degrees before
upload.
