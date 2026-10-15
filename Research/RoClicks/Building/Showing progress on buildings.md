---
tags: [research, roclicks]
source: https://roclicks.gg/resources/building/progress-visuals
retrieved: 2026-10-15
---
# Showing progress on buildings

In tycoon and base-building games the base is the progress bar. A playtester's first note on one game was "we need more upgrade visuals ... when someone upgrades a farm it shows".

- [[#Why it matters]]
- [[#One readable prop per level]]
- [[#Placing props on any model]]
- [[#Wall kits that measure their own segment]]
- [[#Lite and far versions]]
- [[#Part budgets]]
- [[#The upgrade moment]]
- [[#Checklist]]

## Why it matters

In tycoon and base-building games the base *is* the progress bar. A playtester's first note on one game was "we need more upgrade visuals ... when someone upgrades a farm it shows". The model only changed at tier steps (levels 1-2 = tier 1, 3-4 = tier 2 ...), so every other upgrade looked like nothing happened, and some models never changed between tiers at all.

## One readable prop per level

- **Every level adds exactly one thing.** Level L shows items 1..L-1, in a fixed order per building role. Level L+1 = level L plus one piece, so nothing jumps around between levels. ![A farm at four increasing levels, each adding props](https://roclicks.gg/playbook/building/examples/growth_levels.jpg)

*The same farm role at four rising levels. Each level adds props (hay, a lamp and pump, a water tower) that read from the default camera, and the yard plate grows with them.*

- **Each prop says what the building does.** A farm grows a crop field, hay bales, a silo, a tractor, a water tower. A barracks gets a tent, a flagpole, sandbags, a training dummy, a jeep. A house gets a garden, a car, an extension, a solar panel.
- **Readable from the default camera.** Props at 50% scale (about 0.2 studs in a 1/4 world) were invisible. Give each role a scale factor (`1.3` for a role whose models are big) and never shrink a prop below what reads at play distance.
- **Tint with the owner's colour** (a tractor body, a roof extension, a flag) through the same tint path the model uses, so a country's base reads as one.
- **Level pips are optional.** A strip of gold studs showing the level guarantees *something* changes, but the developer removed them in favour of props. Keep it behind a config flag.
- **Fallback pieces.** If a planned prop has no room on a model, place a slim stand-in (lamp, flagpole, barrels, crates) so every level still adds something. Check every role x tier x level layout in a script: one audit found 20+ levels that silently added nothing.

Data shape (see `snippets/Growth.luau`):

``` lua
Growth.ROLES = {
    Farm     = { "cropField", "hayBales", "silo", "tractor", "cropField", "waterTower", "silo", "windPump", "scarecrow" },
    Barracks = { "tent", "flagpole", "sandbags", "dummy", "tent", "crates", "floodlight", "jeep", "antenna" },
}
Growth.ITEMS = {
    silo = { size = Vector3.new(1.2, 3, 1.2), place = "ground", big = true }, -- big = kept on the lite version
    solarPanel = { size = Vector3.new(1.5, 0.2, 1), place = "roof" },
}
```

## Placing props on any model

Hand-placing 9 props on 100 role/tier models doesn't scale. Place them automatically:

1.  **Rasterise each template once** into a small height map (32 x 32) from its visible parts. Mark cells whose top is a wedge, a tilted part or a mesh blob as "rough" (no seats on gables).
2.  **Find a flat, unused rectangle** for each item in level order: ground items on low surfaces, roof items on flat roofs. Try front corners first, pull against the model's edge, and shrink through a short list of scales when nothing fits.
3.  **Cache the layout per template.** First layout ~17 ms (up to 60 ms, so yield inside chunk jobs); a cached build ~0.7 ms; lite ~0.06 ms. Only cache a layout once it's complete.
4.  **Yard plates.** When props land on bare footprint around a smaller model, lay a thin plate in the pad colour (top a hair under the pad top, never coplanar) so the pad visibly grows.
5.  **Sink props ~0.01 into their seat** so nothing hovers, and keep it off 0.01 multiples (see z-fighting in [[Stud style, materials and meshes|01]]).
6.  **Edit-mode previews:** a config module `require`d in an earlier `execute_luau` call is cached. Clone the config into the preview, or your edits won't show.

## Wall kits that measure their own segment

Walls, gates, corners and towers usually level up too, and a single wall model is often shared by every tier, so a wall looked identical from L1 to L10.

- **Measure the drawn segment, don't hard-code it.** Read length, body faces, coping height and gate pillars from the template actually drawn. Then one kit fits every tier's wall and any future wall model.
- **One piece per level, in local space with +Z = outside:** footing, a banner through the wall, a plating band, a flag on the walk, stakes, barbed wire, a floodlight, buttresses, gold trim.
- **Alternate by cell parity** (tall/short flags, lamp/beacon) so a long wall reads as a rhythm, not a copy-paste.
- **Pivot the kit at the segment's pivot**, so anything that hides or moves the wall (a battle arena clearing its area) takes the kit with it.
- **Budget it:** a 40-segment wall ring at L10 added ~600 parts on a 37-part segment. The lite kit is 5 parts a segment.

## Lite and far versions

Every template gets a `_Lite` sibling with roughly a third of the parts (measured on vehicles: 583 → 194, 528 → 175, 316 → 74).

- Lite props: only the first 2 "big" items, simplified recipes, no pips.
- Lite walls: banner, plating, flag, trim. Merge far runs into one band per run.
- Lite vehicles don't animate wheels; lite NPCs carry 1 gear part.
- Every lite template must still have ground. A lite chunk template with no ground part left holes in the far map (see [[Scale and maps|02]]).
- Low graphics quality uses the lite kit even up close.
- Choose by distance *and* crowd size: hero squads up close stay full, the crowd is lite.

## Part budgets

Count parts. It is the one performance number an agent can measure cheaply and reliably.

| Thing                              | Measured                                 |
|------------------------------------|------------------------------------------|
| A building model                   | 90-230 parts                             |
| Growth props at L10                | 30-70 parts (lite: 3-14)                 |
| All growth props in a live session | 1,353 parts = 2% of 66,401               |
| A full biome chunk template        | ~2,800 parts (before stripping scatter)  |
| Near-home world, 9 full chunks     | 106k → 41k after removing hidden scatter |
| A detailed hand tool               | ~44 parts                                |

Rules:

- Print part counts per template and per scene after every build.
- Decorative props are not free: a forest of 100 trees x 20 parts per chunk needs a lite tree.
- Growth props on enemy buildings: create on load, destroy on unload, don't pool unbounded `Instance.new` output.
- Before blaming parts for low fps, check the fps number isn't exactly 15 (an unfocused Studio window, see [[Verifying maps and models|05]]).

## The upgrade moment

The instant of upgrading should feel like a reward. Layer it:

1.  **The model pops**: scale from 0.85 (from 0.5 on a tier change, when the model swaps).
2.  **New pieces pop in one after another**: scale 5% → 100% about the ground pivot with a Back-ease bounce, rising out of the seat, each with a small sparkle burst.
3.  A bigger burst, a "Level N!" float, an upgrade sound, and a short camera shake that only jitters (never takes control of the camera).
4.  **Tier change:** every piece pops, bigger burst, confetti, a ring, and a "New look!" line.
5.  Use particles, not 3D ball puffs. Ball-cluster effects read as cheap.

Bug to avoid: if the server patches the record in place before firing "completed", the message's `level` is already the **new** level. The client adding 1 showed "Level 3!" for a level-2 upgrade. Decide once whether events carry old or new values, and test the text.

## Checklist

- Every role x tier x level adds a visible piece (audited by script).
- Props sized to read at play distance; owner-tinted.
- Walls, gates and towers have a kit that measures its segment.
- Every template has a lite version with ground; lite chosen by distance and quality.
- Part counts printed and within budget.
- The upgrade moment pops the model, then each new piece, with the right level number.

Previous: [[Scale and maps]] · Next: [[Building UX placing, picking and selecting]]
