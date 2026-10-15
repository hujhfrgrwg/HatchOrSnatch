---
tags: [research, roclicks]
source: https://roclicks.gg/resources/vfx/fx-pooling-and-budgets
retrieved: 2026-10-15
---
# FX controller, pooling and budgets

Why one controller: budgets, culling, pooling and quality scaling only work if every play goes through one place. A system that clones a template directly bypasses all of them.

## Contents

- [[#Templates in ReplicatedStorage, one FX controller]]
- [[#Pooling]]
- [[#The generation counter]]
- [[#Per-quality budgets]]
- [[#The Low path for phones]]
- [[#Edit-mode leftovers]]
- [[#Checklist]]

## Templates in ReplicatedStorage, one FX controller

- Store each finished effect as a template: `ReplicatedStorage.<Game>VFX.<EffectName>`, an Attachment or small anchored Part holding the emitters, beams and trails.
- Give it attributes: `Kind` = `burst` / `loop` / `beam`, and `EmitCount` on each burst emitter (how many particles `:Emit()` fires).
- Play everything through **one** client module (`FX`): `FX.burst(name, pos, opts)`, `FX.loop(name, parentOrPos, opts) -> handle`, `FX.clear(group)`.
- Keep a showcase in the place (one labelled pedestal per effect) built **from the same templates**, so what you review is what ships.

Why one controller: budgets, culling, pooling and quality scaling only work if every play goes through one place. A system that clones a template directly bypasses all of them.

If a template is missing, count it (`FX.stats.missing`) and warn once. Check at startup that every name the code asks for exists.

## Pooling

Cloning a 12-emitter template per explosion costs a lot. Pool them:

- Key the pool by `name | scale | colour | quality`, because emitter sizes and rates are baked at prepare time.
- On release: park the root far away (`CFrame` at y = −2000), anchor it, disable continuous emitters, beams, trails and lights, and reset `TimeScale`. Keep at most ~8 parked per key; destroy the rest.
- Burst release delay = the longest particle lifetime plus a margin.

## The generation counter

The bug: `FX.clear("battle")` (or `handle:stop(true)`) released effects immediately, while their old `task.delay(life, release, rec)` was still pending. If the same pooled record was acquired for a new effect before that delay fired, **the old timer released the new effect**: a fire or smoke loop in the next battle vanished mid-play. Stale handles did the same (`smokeScreen`'s delayed `h:stop()` after the battle was cleared).

The fix:

``` lua
-- acquire
rec.gen += 1
-- every delayed callback captures the generation it was scheduled for
local g = rec.gen
task.delay(t, function() if rec.gen == g then release(rec) end end)
-- handles remember it too
handle.gen = rec.gen
function Handle:stop() if self.rec.gen ~= self.gen then return end ... end
```

Apply it to **every** timer: delayed release, light-off, burst-emit stop, loop stop, and handle methods. Test it: stop a handle, reacquire the same rec, fire the stale handle and the old timer, and check the new effect is still alive.

The full snippet is [snippets/FXPool.luau](https://roclicks.gg/resources/code/sound-vfx/snippets/FXPool.luau).

## Per-quality budgets

Give each effect a class and limit plays per second with a token bucket per class. Numbers that held up in 150-unit battles:

| Class  | Examples                                   | Plays/s (medium) | Live cap        | Cull distance |
|--------|--------------------------------------------|------------------|-----------------|---------------|
| small  | muzzle flashes, impacts, casings, sparkles | 70               | 24 per template | 220 studs     |
| medium | most things                                | 22               | 10              | 420 studs     |
| big    | large explosions, shockwaves, fireworks    | 9                | 8               | never culled  |

Quality multipliers (Low / Medium / High): particle **count** 0.5 / 1 / 1.25, **rate** 0.5 / 1 / 1.15. Tracers 30 / 60 / 90, projectiles 10 / 24 / 32.

- Cull small and medium effects that are off-screen or far from the camera.
- UI moments (level-up over the base, conquest) pass `cull = false`.
- Drop, don't queue. A late muzzle flash is worse than none.
- During very large fights, drop world detail by one quality level and restore it after.

## The Low path for phones

- Pick the default automatically: **Low** for touch devices, small viewports, or a low Roblox graphics level (`UserSettings().GameSettings.SavedQualityLevel`). Store it as unset in new saves so the client chooses on first run; let the settings page override.
- On Low: halve emitter counts and rates, cap weather (storm rain ≤ 400 particles), turn off splash and heat-shimmer layers, halve full-screen grades and flashes.
- **No camera shake from thunder at any quality.** Keep shake for things the player did (a building completing, a tier-up), short and small.
- Re-apply the quality when the player changes it; pooled templates are keyed by quality, so old pools just age out.

## Edit-mode leftovers

Agents often run client modules in edit mode to preview. Anything they create can be **saved into the place**:

- Two stale VFX holders with 14 emitters ended up in Workspace; a sound pool ended up in SoundService and played in every server.
- Fix: when `not RunService:IsRunning()`, set `Archivable = false` on every runtime folder. At runtime, replace any root folder this session didn't create.
- Audit the place before publish: search for your runtime folder names in Workspace, Terrain (stray Attachments) and SoundService.

## Checklist

- All effects are templates in ReplicatedStorage with `Kind` and `EmitCount` attributes.
- Every play goes through the one FX controller; missing templates are counted and warned.
- Pools are keyed by name, scale, colour and quality; release parks and disables everything.
- Every delayed callback and handle checks the generation counter; tested with a stale handle.
- Token-bucket budgets and live caps per class; small effects culled by distance and screen.
- Low quality is the default on phones; it halves counts and caps weather.
- No camera shake from ambient events.
- Runtime folders are non-Archivable in edit mode; place audited for leftovers before publish.

Previous: [[Feedback juice]] · Next: [[Sound and VFX checklist]]
