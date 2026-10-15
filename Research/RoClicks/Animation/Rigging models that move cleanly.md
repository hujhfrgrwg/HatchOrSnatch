---
tags: [research, roclicks]
source: https://roclicks.gg/resources/animation/rigging-pieces-vs-bones
retrieved: 2026-10-15
---
# Rigging models that move cleanly

Deciding between rigid pieces and skinned bones, joints that look attached, and triangle budgets for animated models.

## Decide what moves before you join anything

Anything that moves on its own (a jaw, a limb, a blade arm, a wheel) must be either:

- **a separate rigid piece** with its own pivot, connected by a Motor6D; or
- **a skinned bone** that deforms the mesh around it.

Make that call **before** joining geometry. Parts that never move apart get joined into one mesh; parts that do must stay separate. Separating them afterwards means rebuilding.

**Rigid pieces** suit mechanical and blocky things: robots, vehicles, stud-style creatures, anything Roblox-avatar-like. **Bones** suit organic bending: tails, tentacles, cloth, soft creatures.

## Every joint must look attached

Where two parts meet, one must **enter** the other with its cross-section unchanged. A flat end resting against a curved surface reads as unattached the moment it moves. Push it in so the seam is hidden at every angle the joint can reach.

## Curves bend at joints

Organic forms (trunks, tails, necks) are chains of segments: each segment starts buried about 0.3 studs into the end of the previous one and turns a consistent angle further. The arc then reads as continuous, and it can be posed segment by segment later.

## Triangle budgets

| Model                 | Triangles                     |
|-----------------------|-------------------------------|
| Hero creature         | up to about 10,000            |
| Prop                  | about 2,000 to 5,000          |
| Per EditableMesh part | 20,000 maximum (Roblox's cap) |

Report the count, and never decimate without comparing before and after.

## Vertex colour first

For stylised Roblox models, vertex colour is the default material: it survives export to GLB and into EditableMesh with no texture upload. Use image textures only when the reference needs detail vertex colour can't carry.

## Check the exported file, not the scene

The final check is on the exported GLB, not the Blender scene. Exports can flip normals, drop modifiers or change what you see.

> Partly adapted from blender-kiln (github.com/elithril/blender-kiln, MIT licence).

Previous: [[Procedural R6 animation with Motor6D.Transform]] · Next: [[Hits that feel heavy hitstop, impact frames and shake]]
