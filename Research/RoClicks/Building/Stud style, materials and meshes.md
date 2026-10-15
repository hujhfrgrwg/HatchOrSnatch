---
tags: [research, roclicks]
source: https://roclicks.gg/resources/building/stud-style-and-materials
retrieved: 2026-10-15
---
# Stud style, materials and meshes

The "stud revival" look (bright plastic bricks, every face wearing a stud pattern, lots of small detail) is the cheapest style an agent can build well, because it is all parts.

- [[#Stud-style worlds]]
- [[#MaterialVariant studs]]
- [[#Parts or meshes?]]
- [[#AI-generated meshes and the texture fix]]
- [[#Toolbox and asset permission traps]]
- [[#EditableMesh: render data is not saved]]
- [[#Z-fighting]]
- [[#Checklist]]

## Stud-style worlds

The "stud revival" look (bright plastic bricks, every face wearing a stud pattern, lots of small detail) is the cheapest style an agent can build well, because it is all parts.

- **Plastic on every part.** Colour does the work; the stud texture rides on Plastic. Avoid SmoothPlastic and PBR materials (Brick, Concrete, WoodPlanks) in a stud world: they read as a different game pasted in.
- **Neon is an accent, never a body.** Thin glow strips, pads under a hero prop, lava. A big Neon panel blooms under the place's Bloom and turns a building into a lamp. In one game, 233 large Neon faces made T3-T5 buildings "super bright"; the fix was converting any Neon face over ~0.4 stud² to plastic and capping accent brightness (HSV value ≤ 0.85).
- **Cap whites.** Near-white facades blow out the same way. Cap opaque whites at value ~0.88.
- **Break the box.** Big plain boxes fail the style. Notch footprints, add trim every 8-12 studs, add small Y changes (a step, a raised platform). Detail = many small parts.
- **Size everything against the character** (about 5-6 studs tall). Grass at 6.6 studs read as a cane field the player was buried in; waist height (~40% of the player) reads as a lawn. Size props by the *height* they should be, not their width (sizing a fence by width gave 13-stud-tall fences).
- **Parts under ~0.5 studs skip the stud texture.** Studs at that size are noise.
- **One art source per project.** Same rule as icon packs: don't mix toolbox models from different creators with your own builds. Mismatched part counts, heights and styles break the set, and the licence picture gets muddy.

## MaterialVariant studs

The old `SurfaceType = Studs` faces render faint and only on some faces. A **MaterialVariant** with a stud colour map + normal map textures every face, walls included, and reads clearly.

``` lua
local MaterialService = game:GetService("MaterialService")
local mv = Instance.new("MaterialVariant")
mv.Name = "Stud"
mv.BaseMaterial = Enum.Material.Plastic
mv.ColorMap = "rbxassetid://<your stud colour map>"   -- upload your own texture
mv.NormalMap = "rbxassetid://<your stud normal map>"
mv.StudsPerTile = 4 -- 4 at life size; scale it with the world (see 02)
mv.Parent = MaterialService

part.Material = Enum.Material.Plastic -- must equal mv.BaseMaterial or the variant is ignored
part.MaterialVariant = "Stud"
```

Gotchas:

- **A variant only applies when `part.Material == variant.BaseMaterial`.** Set both, every time.
- **The colour map multiplies the part colour.** Use a light, neutral texture and tint with `Color`. A dark texture can't be tinted light.
- **Survey `MaterialService` before building.** Use the variants that exist in this place; don't assume a roster from another place.
- **Toolbox material packs stream in slowly.** A flat swatch seconds after install is not "blocked". Wait, then judge. (`PreloadAsync` and EditableImage probes report failure even for textures that render, so they can't settle it either.)
- **Stud texture origin is per part.** Two overlapping stud parts never line up, which makes any coplanar overlap flicker even when the colours match (see z-fighting below).
- **Ground reads checkered** through one tiling `Texture` (2x2 checker, `Face = Top`, `Transparency` ~0.8) per big slab, not hundreds of coloured plates.

## Parts or meshes?

| Use parts                                              | Use a mesh                                        |
|--------------------------------------------------------|---------------------------------------------------|
| Buildings, walls, roads, ground, props with flat faces | Characters, creatures, plants with organic curves |
| Anything that must match the stud style exactly        | Weapons and gear with smooth silhouettes          |
| Anything that needs to change per level or per player  | One-off hero props that parts can't shape         |

Why parts first: free, instantly editable from a script, guaranteed to match the style, no upload step, no permission risk, and they save with the place. The weak point of meshes is getting them *into* Roblox (upload auth, moderation, or runtime EditableMesh).

## AI-generated meshes and the texture fix

Image-to-3D services are good at organic shapes and bad at textures.

- **Prompt for the style.** "Chunky toy plastic, flat colours, side view, pure white background." The white background is what makes the fix below possible.
- **Quote the credit cost before every generation call.** It is real money.
- **The texture problem:** generated textures are atlases of hundreds of tiny UV charts, with smears painted across chart borders. That shows up as streaky, blotchy surfaces.
- **What doesn't work:** one palette colour per triangle. Colour borders follow triangles, so stripes come out jagged.
- **What works: project the concept image.**
  1.  Clean the concept: background = pixels with `min(r,g,b) >= 248`; keep connected regions ≥ 3% of the largest; reduce to a k-means palette of ≤ 7 colours (drop colours under 3%); mode-filter, then bleed colours outward until every pixel is filled.
  2.  Planar-project the cleaned image onto the mesh along its thinnest axis. Try all 4 flips and keep the best silhouette overlap (IoU), then nudge each bounding-box edge to maximise IoU (this removes soft drop shadows a colour mask can't).
  3.  Expect 82-94% silhouette overlap and crisp colour borders.
- Headless Blender's bundled Python usually lacks PIL; do the image work in system Python.

## Toolbox and asset permission traps

**A mesh or image your experience has no permission to use renders as literally nothing.** No error at the call site, no placeholder. A tier-7 item shipped invisible this way, in the world and in its viewport preview, while every sibling worked.

How to detect it (see `snippets/AssetProbe.luau`):

- Output log lines like "doesn't have access permission to use asset id" or "MeshContentProvider failed to process ... could not fetch". Easy to miss.
- Programmatically: `pcall(AssetService.CreateMeshPartAsync, AssetService, content)` per mesh id, and `CreateEditableImageAsync` per image id. Run it over every asset folder.

Rules:

- Probe every third-party mesh/image id before building around it, including ids a collaborator hands you.
- You can't self-approve someone else's asset. Get it shared, or rebuild.
- When rebuilding a missing tier, clone a working sibling and recolour it, so structure, part names and scale attributes match the set.
- Toolbox particle textures fail permission very often. Prefer `rbxasset://` built-ins or textures you uploaded.
- Strip `Sparkles`, `Fire` and `Smoke` from catalog accessories used on NPC templates; some carry them.
- `insert_asset`-style tools may refuse third-party assets that `game:GetObjects(...)` loads fine inside `execute_luau` (useful for skies).

## EditableMesh: render data is not saved

`AssetService:CreateEditableMesh` → `CreateDataModelContentAsync` → `CreateMeshPartAsync` gives smooth custom meshes that replicate to clients. But **the render mesh is not saved** with the place: after a save/reopen or an rbxm round trip, only collision survives and the part is invisible. Publishing as a real asset may not be available from tools.

The pattern that works (see `snippets/MeshSpots.luau`):

1.  **Store recipes, not meshes.** Each mesh lives in the model as an invisible "spot" part carrying a recipe key and JSON params as attributes.
2.  **Bake at runtime, in the background.** Bake each unique key once, cache it, clone per spot. Do it in `task.spawn` *after* services start. A real game baked ~4,400 spots in 11 s at the top of server `Main`; every service waited, the client's 10 s remote wait timed out, and state never loaded. Moving the bake to the background put services up instantly and the bake finished 3.8 s later.
3.  **Repair loop.** Templates cloned *before* the bake finished have empty spots, and pools keep reusing those copies forever. A watcher fills any spot with no mesh: every 1 s until three clean passes after the bake, then every ~6 s as a safety net.
4.  **Stand-ins.** A spot whose bake fails gets a plain block with its bounds, colour and material (tag it so a later pass can swap in the real mesh). A grey block beats a hole.
5.  **Probe the full path.** An empty `CreateEditableMesh()` succeeds even when the API is off; the error only comes when the mesh becomes content. Probe with one real triangle all the way to a MeshPart, and fall back to part-built geometry if it fails.
6.  **Game setting.** Published games need "Allow Mesh & Image APIs" enabled (Game Settings \> Security). On a group-owned place, only the group owner may be able to change it. Ask early.
7.  **Edit-mode preview:** bake with the results marked `Archivable = false` so they never get saved by accident.

## Z-fighting

Measured in Studio: two coplanar plates of different colour seen at a 5° grazing angle.

| Gap between planes | Result                                             |
|--------------------|----------------------------------------------------|
| 0 or ±0.0001 studs | Flickering triangles                               |
| 0.001 studs        | Clean even 1,500 studs away                        |
| 0.025 studs        | Clean, but the step is *visible* on walls as a lip |

So depth precision is better than textbook estimates, and the real culprit is **exactly coplanar faces**, often created by tiny "hair" offsets (0.0001) that a 1/4 world scale shrinks 4x further.

Rules:

- Detect pairs with planes \< 0.005 apart; fix to 0.01 apart. Not 0.02+, which shows lips.
- Only overlapping faces that face the same way matter; edge contact is fine.
- A pair only flickers visibly if the two faces differ (colour, material, variant, or any stud texture, since texture origin is per part) *and* the spot isn't buried in a third part.
- Any offset you add can re-align with template steps. Pick offsets ~0.005 away from multiples of 0.01.
- Use many distinct hair values if you jitter (`% 37`, not `% 7`: 418 coplanar hits fell to 18).
- Keep world-space layer heights in **one module** (`snippets/Layers.luau`): ground, road, land overlay, borders, decals, ghost plates. Keep these in world studs, not scaled: depth precision does not shrink when the world does.
- Run the sweep after every template rebuild, and a world sweep on a built scene to catch cross-piece pairs. Run long sweeps in edit mode, not on a playtest client (a long loop there killed the playtest).

## Checklist

- Every part is Plastic + stud variant (except Neon accents, rocks, and tiny parts).
- No Neon face bigger than trim; whites capped.
- Props sized by height against a 5-6 stud character.
- Every third-party asset id probed.
- EditableMesh content baked in the background, with repair and stand-ins.
- Coplanar sweep is clean.

Previous: [[Building overview]] · Next: [[Scale and maps]]
