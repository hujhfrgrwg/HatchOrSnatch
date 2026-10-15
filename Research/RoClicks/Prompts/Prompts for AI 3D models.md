---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ai-prompts/ai-3d-model-prompts
retrieved: 2026-10-15
---
# Prompts for AI 3D models

Concept-image and model prompts that produce props and characters which sit next to stud builds, plus a Blender prompt for a coding assistant.

Copy the prompt with the button on its box, then paste it into your AI.

AI 3D tools (Meshy and similar) work best as a two-step process: get the **concept image** right first (cheap), then turn it into a model (expensive). Regenerating a mesh to fix a problem that was in the concept wastes credits.

## Step 1: the concept image

The side view on a pure white background matters: it makes the image easy to clean up and to project back onto the model as a texture later.

``` text
[OBJECT], side view, centred, pure white background, no shadow on the ground.
Stylised for a Roblox game: chunky toy plastic, flat solid colours, simple bold shapes, crisp edges, small chamfers. Few colours, no fine texture, no photoreal materials, no text, no logos.
The whole object is visible with a small margin around it.
```

For characters and creatures, use a front or three-quarter view in a neutral pose instead, with arms slightly away from the body so it can be rigged:

``` text
[CREATURE / CHARACTER], full body, front view, neutral standing pose with arms held slightly away from the body, pure white background.
Stylised for a Roblox game: chunky toy plastic proportions, flat solid colours, simple readable shapes, big clear features. No fine texture, no photoreal skin or fur, no text.
```

## Step 2: image to 3D

Use the concept as the input image. If the tool takes a text prompt as well:

``` text
Low-poly stylised game asset, chunky toy plastic, flat colours, clean silhouette, matching the input image exactly. Suitable for a Roblox game.
```

Budget the triangles: about 2,000 to 5,000 for a prop, up to about 10,000 for a hero creature.

## Asking a coding assistant to model it in Blender

If you have an assistant connected to Blender, scripted modelling often beats AI generation for hard-surface props:

``` text
Model this in Blender for a Roblox game, using the attached image as the reference: [OBJECT].
- Build it from simple primitives with small bevels, in the reference's colours, using vertex colour instead of image textures.
- Every part that touches another must enter it; nothing floating, nothing resting flat against a curve.
- Anything that should move on its own (a lid, a wheel, a jaw, a limb) is a separate piece with its pivot at the joint. Decide this before joining anything.
- Stay under [N] triangles.
- Check it against the reference from the front, side and three-quarter views, list what doesn't match, fix it, and show me the final views before exporting.
- Export as GLB. Don't upload anything.
```

Previous: [[Writing prompts AI actually follows]] · Next: [[Prompts for building in Studio with an AI assistant]]
