---
tags: [research, roclicks]
source: https://roclicks.gg/resources/scripting/performance
retrieved: 2026-10-15
---
# Performance

Kids play on phones, tablets and Chromebooks. Most "the game feels bad" reports turn out to be hitches, lost taps or slow pop-in. Rules with the numbers that justified them.

Kids play on phones, tablets and Chromebooks. Most "the game feels bad" reports turn out to be hitches, lost taps or slow pop-in. Rules with the numbers that justified them.

- [[#Measure first]]
- [[#Time-budgeted schedulers]]
- [[#LOD and rig caps]]
- [[#Pools]]
- [[#No per-frame allocations]]
- [[#Graphics level: pick Low automatically]]
- [[#GUIs: update in place, never rebuild on a timer]]
- [[#EditableMesh: keep the bake off the startup path]]
- [[#Streaming gotchas]]
- [[#Checklist]]

## Measure first

- **Focus the Studio window.** An unfocused Studio playtest is capped at exactly 15 fps, so any A/B taken in a background window is meaningless.
- **Find out whether you are script-bound or render-bound** by removal experiments, one at a time: hide all units, hide the arena, hide world chunks, turn global shadows off, pause the server sim. In one big battle the script profiler showed the animator at 21-29%, yet cutting script work barely moved fps; removing the soldier models took it from 28 to 51 fps. It was render-bound (220 Humanoid soldiers with clothing, ~7,000 arena parts, ~80,000 world parts).
- Sample fps in alternating 2 s windows (A, B, A, B, A, B); single samples taken during a transition lie.
- Track `worstSliceMs` (longest uninterrupted job) and the longest gap between yields, with a traceback, so the loop that forgot to yield names itself.

## Time-budgeted schedulers

Anything that creates or destroys lots of instances runs as a coroutine job under a per-frame budget: [tools/Scheduler.luau](https://roclicks.gg/resources/code/engineering/tools/Scheduler.luau).

- Measured: cloning a 2,800-part chunk template costs ~50 ms, and parenting it in one go another ~117 ms. Spread over frames at a 4 ms budget, nobody notices.
- **Move big models piece by piece**: parent an empty shell first, then move leaves (parts, small models) one at a time with `S.step()` between them. The cost lands inside the budget instead of one spike.
- **Filter before cloning.** One map cloned every chunk's full template and then hid most of it; every hidden part was still cloned, transformed and kept in memory. Test the source child and never clone what you will hide. Better: bake a ground-only template offline.
- **Never cancel a release.** Cancelling a job drops its coroutine where it last yielded. A release (destroy / back to pool) cancelled halfway orphans a half-destroyed model for the rest of the session: duplicate ground that z-fights, enemy bases that never go away, unbounded leaks. Publish the new thing first, then release the old one in a separate job under a tag nothing cancels.
- Under heavy load (a 100+ unit battle) lower the streaming budget (e.g. 4 to 1.5 ms) rather than changing LOD radii. Changing radii at battle start re-streams ~30 chunks in the same frames as the units spawn, and again at the end banner.

## LOD and rig caps

- **Every heavy model gets a `_Lite` twin** (15-35% of the parts, same silhouette and colours). Vehicles: 583 to 194 parts, 528 to 175, 316 to 74.
- **Cap the number of full-detail rigs** by distance: in one war, `FULL_VEH` 16 to 6 and full distance 190 to 60 studs took 61 on-screen vehicles from 22.8 to 30.5 fps (+34%).
- **Animation LOD**: pose rigs past 18 studs at 20 Hz, past 35 at 10 Hz, and at 5 Hz behind the camera. Advance their clocks in full so events and speed do not change.
- No shadows on tiny parts (arena pieces under 3 studs, gear under 1.5 studs).
- **Humanoids are expensive.** Beyond the nearest 30-40, use Humanoid-free models (body plus gear, clothing baked into colours). In the battle above, soldiers cost about 14 fps.
- Skip dead entries: a render list that still iterates 900 removed corpses wastes the frame.

## Pools

- Pool clones of templates you spawn often (units, effects, props): `acquire` = take from pool or clone, `release` = reset and park with `Parent = nil`.
- **Cap and trim pools.** A pool of 6 per template sounds small, until every template is a 2,800-part chunk: 6 biomes x 2 LODs x 6 copies is ~200,000 detached parts, which crashes phones in a long session. Use a per-template cap (1 for huge templates, 6 for small ones, ~24 for rigs) and clear pools on quality change, map reset and 30 s after a battle view closes.
- **Reset state on release**: transparency set by an old LOD, hidden caps, running emitters. A pooled chunk that kept its hidden water plane showed a "blue checker" through the ground.
- Give each pooled record a **generation counter**. Delayed callbacks (`task.delay` stop timers, light fades, release timers) check it, so a stale timer cannot stop or park the effect after it was reused.
- Tagged pooled instances: `RemoveTag` on release and `AddTag` on acquire, or tag-keyed caches keep stale per-instance data.

## No per-frame allocations

Each one is small; together they are GC spikes on phones.

- No `{}` per rig per frame: compact arrays in place.
- Do not count descendants with `#inst:GetDescendants()` in a loop; cache counts per template.
- Cache `FindFirstChild("Fill", true)` results when the object is created, not every frame.
- Do not build strings (`tostring(cam.CFrame)`) as cache keys per frame.
- Throttle work that does not need 60 Hz: hover picking at 10-15 Hz, pickup/contact checks at 10 Hz, and cache bounding boxes of static models.
- Reuse scratch tables (and say so in the API: "the returned table is reused by the next call").
- Bound every buffer: a "snapshots that arrived early" queue that is never drained grows for a whole battle at 15 Hz. Cap by count and age.

## Graphics level: pick Low automatically

Kids never open Settings. Choose the first default for them:

``` lua
local function autoGraphics()
    local cam = workspace.CurrentCamera
    local small = cam and math.min(cam.ViewportSize.X, cam.ViewportSize.Y * 16 / 9) < 1000
    local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local ok, low = pcall(function()
        local q = UserSettings().GameSettings.SavedQualityLevel
        return q ~= Enum.SavedQualitySetting.Automatic and q.Value <= 3
    end)
    return (touch or small or (ok and low)) and "Low" or nil
end
```

- Use it **only when the save has no graphics setting yet**. If `defaults()` writes "Medium", the auto choice never runs; leave the default nil.
- Low means fewer chunk rings, capped weather particles (e.g. rain at 400), no screen-space extras, no camera shake from thunder.

## GUIs: update in place, never rebuild on a timer

- A panel that destroys and re-clones its cards whenever state ticks (once a second) **loses taps**: a press that starts on the old card and ends on its replacement never fires `Activated`. It also resets hover tweens and churns GC.
- Build rows once per open or structural change (category, count, locked/unlocked); write numbers into existing labels.
- Rule of thumb from an idle game that flickered: the rebuild "signature" carries **structure only**; every mere number goes in an update closure. Probes that call the update function by hand can show zero rebuilds while the live game flickers, so measure with real state packets.
- Clearing a container's children also deletes its `UIScale` / `UIListLayout`; skip layout objects.
- Debounce expensive reactions to rapid UI input (a flag colour picker that saves on every click would recolour the whole map each time): `task.delay(0.6)` with a generation counter, and recolour in place rather than rebuilding.

## EditableMesh: keep the bake off the startup path

- **Never bake meshes before services start.** One server baked unit gear inline before `PlayerAdded` and the remotes were connected; clients gave up waiting for state after 20 s. Bake in a `task.spawn`, set an attribute (`UnitBaked = true`) when done, and make rendering tolerate missing meshes meanwhile.
- **Cap concurrency** (e.g. 24 at a time). An unbounded burst hits the EditableMesh memory budget and those meshes fail permanently.
- **EditableMesh content is not saved with the place.** Meshes built in edit mode vanish on reopen; bake at runtime (or publish them as assets).
- **Probe the full path before relying on it.** An empty `CreateEditableMesh()` succeeds even when the experience's "Allow Mesh / Image APIs" setting is off; the error only appears when the mesh becomes content. Build one triangle, turn it into a MeshPart in a `pcall`, and fall back to part-built geometry if that fails. On a group-owned place only the group owner can enable that setting.
- Watchers that poll for unbaked meshes must count stand-ins as final and back off (6 s, then 30 s), or they walk the whole DataModel every second forever when a bake fails.

## Streaming gotchas

- `CollectionService:GetInstanceAddedSignal(tag)` **does not fire for instances that stream in already tagged.** A cache built from `GetTagged` at startup freezes at whatever was loaded on join. Rebuild tag-derived caches on a 1 s timer guarded by a cheap count check; keep the removed signal for cleanup.
- `workspace.StreamingEnabled` is edit-time only; set it in Studio, and only `warn` from scripts.
- Models the player must always have (their own arena, a showcase): `ModelStreamingMode = Persistent` or `PersistentPerPlayer`.

## Checklist

- fps measured with the Studio window focused, A/B alternated.
- Heavy create/destroy runs in budgeted jobs; releases are never cancelled.
- `_Lite` twins, distance caps on full rigs, animation LOD, no shadows on tiny parts.
- Pools capped per template and cleared on reset; generation counters on pooled records.
- No allocations or full scans per frame; hover/contact checks throttled.
- Low graphics chosen automatically on first join for touch and small screens.
- GUI rows built once, numbers updated in place.
- Mesh bakes off the startup path, concurrency-capped, with a part fallback.

Previous: [[Solo in a shared server games]] · Next: [[Input]]
