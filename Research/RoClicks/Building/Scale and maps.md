---
tags: [research, roclicks]
source: https://roclicks.gg/resources/building/scale-and-maps
retrieved: 2026-10-15
---
# Scale and maps

Strategy and tycoon games often want the player standing over a tiny country like a giant. The trick: keep the character life size and shrink the world (for example to 1/4).

- [[#A giant player in a miniature world]]
- [[#Map reorganisation breaks things silently]]
- [[#CollectionService and StreamingEnabled]]
- [[#Part.Size is not world extent]]
- [[#Chunked endless maps]]
- [[#Checklist]]

## A giant player in a miniature world

Strategy and tycoon games often want the player standing over a tiny country like a giant. The trick: **keep the character life size and shrink the world** (for example to 1/4).

- **Author everything at life size, then scale templates.** Builders, cell sizes and character-sized props stay in familiar numbers. A one-shot scaler runs `Model:ScaleTo(S)` on every template and marks each with a `WorldScale` attribute so a second run skips it (idempotent, safe to re-run after every asset rebuild).
- **One `Scale` module** owns `S`, studs per cell, chunk size, and helpers like `Scale.d(x)` = `x * S`. Game code writes distances as `lifeSize * S`. Viewer-space numbers (the character, camera minimum zoom, GUI pixels) are *not* scaled.
- **What `ScaleTo` handles** (measured): part sizes, joints, attachments, FileMesh scale, particle Size/Speed/Acceleration, beams, trails, fire/smoke, Texture StudsPerTile, billboard sizes/offsets/MaxDistance, SurfaceGui PixelsPerStud, sound rolloff, prompt distances, `Humanoid.HipHeight`.
- **What it misses, fix by hand:** light `Range`, `Beam.TextureLength`, `SelectionBox.LineThickness`, BillboardGui `ExtentsOffset`, any CFrame or stud-valued attributes your code stores, and `MaterialVariant.StudsPerTile` (variants live in MaterialService, not the model). Scale the variant too, or studs stay life-size on tiny parts.
- **TrussParts can't go below 2 studs per axis.** `ScaleTo(0.25)` left 59 ladders as 2x2x2 see-through cubes. Build ladders as plain Parts.
- **`ScaleTo` is absolute.** Calling `ScaleTo(1)` on a clone to "reset" it blows a 1/4 model up to life size. Use a relative helper: `m:ScaleTo(m:GetScale() * k)`.
- **Pooled shell models may report `GetScale() == 1`.** Read the `WorldScale` attribute as the fallback when animating Transform offsets.
- **Z-fight gaps stay in world studs.** Depth precision doesn't shrink with the world.
- **Sound from a far camera:** the giant's camera sits relatively farther away, so multiply rolloff by a small "ear" factor or the world goes silent.

## Map reorganisation breaks things silently

When a level designer moves map content into folders, two things die **with no error**:

1.  **Top-level discovery scans.** `for _, c in workspace:GetChildren()` looking for `Stage1..Stage20` found nothing once they moved into `Workspace.Stages`. Six services found zero checkpoints, hazards and teleports. "Found nothing" looks exactly like "there is nothing".
2.  **`workspace:WaitForChild("Container")` yields forever** once the container moves, taking every line after it with it. Studio prints only a soft "Infinite yield possible" line.

Fix (see `snippets/Discovery.luau`):

- One shared discovery module that walks down from Workspace through **Folders only** (cheap, ~100 visits, never wanders into 50k mesh parts).
- Match containers by what they *hold* (a tag, an attribute, a child class), not by a name that churns.
- Always `warn` when a lookup finds nothing.
- Never `WaitForChild` a map container without a timeout.
- When a search for something the developer says exists comes back empty, widen the filter and re-run before concluding it's absent. Authored props are often bare Parts (a `Ball` parented to another Part), not tidy Models. If a result is too big to read, narrow the query; skimming 600 lines is not looking.

## CollectionService and StreamingEnabled

**`CollectionService:GetInstanceAddedSignal(tag)` does not fire for an instance that streams in already tagged.** That is how everything outside the spawn area arrives. Measured: walking into a fresh stretch streamed in hundreds of tagged parts and the handler fired zero times.

Anything that builds a cache from `GetTagged` at startup and maintains it from the signal freezes at whatever was loaded on join. The bug is invisible: a part that doesn't react looks like a part nobody wired up.

Fix (see `snippets/TagCache.luau`):

- Rebuild tag caches on a timer (~1 s) guarded by a cheap change check (the count).
- Keep `GetInstanceRemovedSignal` for cleanup; streaming out does fire it.
- Pools: `RemoveTag` on release and `AddTag` on acquire, so per-part cached state (a rest CFrame, say) gets cleared and re-read.
- Testing a pooled object: verify by world position and re-find the occupant each sample; a pooled model is not a stable identity.
- Testing a "pressed when stepped on" part: record the rest pose of a target **far** from the player *before* stepping on it. Sampling the one under their feet records the pressed pose as the baseline and reports zero travel.

Related StreamingEnabled facts:

- `workspace.StreamingEnabled` is edit-time only. A running script setting it gets "lacking capability" and the whole bootstrap dies at that line. Set it in edit mode; at runtime only `warn` if it's off.
- `PersistentPerPlayer` models plus a large Y lift per player slot is a cheap way to keep one player's arena from streaming to others.

## Part.Size is not world extent

Geometry exported from Blender often arrives rotated. A bar authored `174 x 3 x 2.5` stood **174 studs tall** in the world. Reading `Size.X` as "width" sent a hazard along the wrong axis.

``` lua
-- world-axis extent of a rotated box part (snippets/WorldExtent.luau)
local cf, s = part.CFrame, part.Size
local ext = Vector3.new(
    math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
    math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z,
    math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z)
```

`Model:GetBoundingBox()` is world-aligned only for the model's pivot orientation. If the model box and the part sizes disagree, that disagreement is the tell.

The same trap in reverse: a model's bounding box is not its visible pad. A 2x2-cell building was ~7.4 x 5 studs of visible model on an 8 x 8 footprint (an invisible `Footprint` part sets the box). Measure what is drawn when placing props on it.

## Chunked endless maps

An endless or very large map is streamed in square chunks around the camera, at several levels of detail (full near, lite mid, flat far), under a per-frame time budget (~4 ms). A skeleton is in `snippets/ChunkStreamer.luau`. The rules below each come from a real bug.

### Publish the new chunk before releasing the old one

When a chunk changes LOD, build the new copy completely, record it as *the* loaded copy, and only then queue the release of the old one. If the release happens inside the build job, a cancel in between leaves the new copy recorded nowhere: it's orphaned in Workspace forever, its ground z-fights the real one, and the next update builds the chunk a third time.

### Never cancel a release

Releases yield (one piece per step to stay in budget). A scheduler that "cancels" a job just drops the coroutine at its last yield, leaving a half-destroyed chunk. It happens constantly while zooming, because LOD targets can flip every 0.25 s.

- Give release jobs their own tag; "clear all chunk jobs" cancels builds only.
- Mark `releasing = true` before the first yield. When a chunk comes back in range during its release, let the release finish, then rebuild.
- If a build is aborted, restore the old ground and destroy the half-built copy. Never pool it.
- Lay a cheap one-part "backstop" ground just under every chunk first, so any hole while an LOD swap is in flight shows plain ground, not the void or a water plane.

### Don't clone templates you then hide

One streamer cloned each ~2.8k-part chunk template, then hid almost all its scatter with a filter, keeping the hidden parts alive in memory. ~50 ms of clone per chunk went to parts no one saw. Run the filter on the **source** child (compute its position from the transform and `GetPivot()`) and never clone what it rejects. Removing scatter this way took the near-home world from 106k parts to 41k.

### Pools

- Reset everything a previous user changed on acquire: Transparency, colour, tags, scale. A reused lite chunk kept `Transparency = 1` on its ground from an old LOD swap and drew a pale-blue water plane through the map.
- Store original colours in an attribute (`GroundC0`) so a "mute" pass on a pooled copy never mutes twice.
- Cap pools per template: 1 for whole chunks, ~6 for small pieces, ~24 for NPC rigs. Uncapped, six biomes x 2 LODs x 6 copies kept ~200k detached parts alive.
- Clear pools on quality change, on campaign reset and when the map clears.
- Never pool a copy that may hold half-built content (a template cloned before a runtime mesh bake finished). Pools reuse it forever.

### Priorities and quality

- Re-layer and repair jobs run ahead of new streaming, so a long camera jump doesn't show bare baseplate under a battle for 12 s.
- Dropping a quality level during heavy scenes helps, but the drop and the restore both queue dozens of jobs. Stagger them, or the start and end of the scene hitch.
- Strip template scatter where gameplay needs clarity: "what you see is what blocks". Only cells that block movement get trees.

## Checklist

- One Scale module; the scaler is idempotent; variants and lights scaled too.
- No discovery by fixed parent; every empty lookup warns.
- Tag caches rebuilt on a timer under StreamingEnabled.
- World extents computed from CFrame axes, not `Size`.
- Chunk streamer: publish-then-release, uncancellable releases, filter before clone, reset-on-acquire, capped and cleared pools.

Previous: [[Stud style, materials and meshes]] · Next: [[Showing progress on buildings]]
