---
tags: [research, roclicks]
source: https://roclicks.gg/resources/building/building-ux
retrieved: 2026-10-15
---
# Building UX: placing, picking and selecting

Code for picking, hover and tap-vs-drag is in snippets/Picking.luau.

- [[#Placement ghost]]
- [[#Picking: the 58 px bug]]
- [[#Hover highlight]]
- [[#Forgiving tap-to-select]]
- [[#Tap vs drag on touch]]
- [[#Ruins counted as owned copies]]
- [[#Quick-build card bar vs nested shop menus]]
- [[#Checklist]]

Code for picking, hover and tap-vs-drag is in `snippets/Picking.luau`.

## Placement ghost

The ghost is a see-through copy of the building that follows the pointer, snapped to the grid, green when valid and red when not.

- **Start the ghost next to the player**, not under the pointer. The pointer is still over the shop card that opened placement, and a ray through it hits the horizon: the first thing the player saw was a red ghost over a neighbour's land.
- **Pull to the nearest valid cell** for *placement* problems only (occupied, off your land, on a road). Search outward up to ~10 cells (3 was too small: playtesters missed twice in a row) and cache the search per pointer cell. Cost, tier and limit errors stay red; moving the ghost wouldn't fix them.
- **Say why it's red, specifically.** "Something is already there" on a ruin left players stuck. "A ruin is in the way: clear it with the Hammer" told them what to do. Client and server must give the same reason (share the check in one module).
- **Ghost plate height** sits on its own layer above the thin ground plates inside building templates, or it z-fights them (see `snippets/Layers.luau`).
- **Repeat placement** (hold Shift, or stay in placement after a build) is great for walls and farms. Show the key hint on the placing bar, and keep the ghost's label clear of the new site's progress bar.
- **Only the touch that began on the world steers the ghost.** A finger that started on a GUI button and slid onto the world must not move it.
- **Rotation key works whenever a building is selected**, not only while placing. A Rotate button with an "R" hint that does nothing is a broken promise.

## Picking: the 58 px bug

Symptom from a playtester: "it was hard to select different builds ... like the mouse had an offset". Clicking a building's centre picked nothing, or picked the building above it.

Cause: there are two screen spaces.

| Source                                          | Space                                    | Ray function                      |
|-------------------------------------------------|------------------------------------------|-----------------------------------|
| `InputObject.Position` (mouse and touch events) | GUI space: top bar inset already removed | `Camera:ScreenPointToRay(x, y)`   |
| `UserInputService:GetMouseLocation()`           | Viewport space: includes the inset       | `Camera:ViewportPointToRay(x, y)` |

The bug fed `input.Position` to `ViewportPointToRay` (and `GetMouseLocation() - inset` to the same), aiming one inset (58 px in a Studio playtest) above the cursor. Measured error: 58.00 px at every point and zoom before, 0.000 after. At high zoom that was 3 grid cells off.

Rules:

- Pair the function with the source. Never add or subtract `GuiService:GetGuiInset()` by hand.
- One `pointerRay(input)` helper used by click, ghost, hover and touch. If two paths build rays differently, one of them is wrong.
- To decide "is the pointer over GUI", `PlayerGui:GetGuiObjectsAtPosition` takes GUI space.
- A full-screen `IgnoreGuiInset` ScreenGui root reports `AbsolutePosition = (0, -58)`; `input.Position` is in the same space as GUI `AbsolutePosition`.
- Test it with numbers: project a known world point to the screen, cast back, and measure the error in pixels across the grid and at three zoom levels.

## Hover highlight

A soft white highlight under the mouse makes a dense base readable and shows what a click will open.

- **One reused `Highlight` instance**, re-adorned to whatever is hovered. Roblox renders at most **31 Highlights at once**; creating one per building (or one per frame, as an old hover did) silently stops drawing past the limit and churns instances.
- Settings that read well: white, `FillTransparency` ~0.86, `OutlineTransparency` ~0.3, `DepthMode = Occluded`, fade in 0.1 s / out 0.14 s.
- **Same pick as the click.** What lights up must be exactly what a click opens.
- **Only highlight what a click can open.** Enemy buildings with `CanQuery = false` on 113 of 117 parts were unreachable by the click ray; a highlight there would promise a click that does nothing.
- **Off** while placing or moving, in map view, with a screen open, during cutscenes, over GUI, with the mouse locked, and on touch-only devices. Skip the selected building (it keeps its own selection outline).
- **Re-pick only when the mouse or camera moves**, at most ~15 Hz. Cache per-building boxes.
- Include props added by upgrades in the pick, or clicking the new silo selects nothing.

## Forgiving tap-to-select

Raycasting into thin, small or `CanQuery = false` parts makes selection miss, especially on phones. Build one pick function (`pickAt(pos, "touch" | "mouse")`, ~0.1 ms) with fallbacks:

1.  **Labels first.** Every name plate's tap box is at least 56 px square on touch (34 px on mouse) plus padding (12 / 4 px). A direct hit beats a padded hit. BillboardGui buttons never receive clicks under a HUD, so hit-test them yourself.
2.  **Cell → owner lookup.** Cast one ray against the ground layer only, convert the hit to a grid cell, and look up the owner of that cell (cached per cell). This works whatever the building's parts allow, and in walk view as well as map view. Don't rely on `CanQuery` being set right on every decorative part.
3.  **Near a boundary:** pick the nearest valid target within 34 px (touch) / 16 px (mouse).

Also:

- Wall hits count for the country the wall belongs to, not the cell just outside it.
- Own land never opens an enemy panel; build clicks own it.
- Feedback on press: outline the target and grow its label to 1.1x; a tap bounces it to ~1.28x with a click sound.
- BillboardGuis clip their content even with `ClipsDescendants` off. Size them in pixels with headroom (1.5x) for bounce and badges.
- Give label plates a pixel floor on phones (~170 x 46). A UI scale floor of 0.35 left labels 52 x 14 px, which no thumb can hit.
- Declutter overlapping map labels a few times per second: priority targets keep theirs and show a "+N" badge; their land still picks.

## Tap vs drag on touch

A camera that pans on drag and selects on tap must tell them apart, or every pan opens a panel.

- **A press is a tap only if** it moves less than 7 px (mouse) / 14 px or 2.5% of the short screen side (touch), ends within 0.5 s (mouse) / 0.65 s (touch), never had a second finger on the world, and wasn't claimed by another system (placement, camera pinch, a GUI).
- **`UserInputService:GetTouchesInProgress` does not exist.** A claim system that called it threw on every claim; the errors were swallowed by `pcall` and the feature silently never worked. Count touches yourself from `InputBegan` / `InputEnded`.
- **Claims expire** ~0.25 s after the press ends, not seconds later.
- Studio can't synthesise multi-finger touch. Verify the second-finger and pinch rejection by reading the code, and say so.

## Ruins counted as owned copies

Conquered or destroyed buildings stay as ruins (rebuildable). The client counted every building record, ruins included, while the server skipped ruins. After a few wars:

- The shop and ghost showed a farm at ~3.4x its real price (price scales with copies owned).
- The ghost went red with "Need more cash" when the player could afford it, and the client then offered a paid top-up the player didn't need.
- Limited buildings showed "Limit 3" from ruins alone.
- The hotbar showed "x26" farms after clearing one ring.

Fix: one shared `copies(role)` that counts only standing buildings (active, upgrading, damaged), used by client and server. Occupancy (what blocks placement) still includes ruins.

The general lesson: **any count the client shows must come from the same function the server uses.** Two implementations drift.

Related ruin bugs worth checking in your game: cancelling a rebuild played an explosion; ruin labels stacked into an unreadable pile visible from far away (limit to ~40 studs, hide during battles); and with many ruins there was nowhere left to place a large building (offer a "clear all ruins here" action).

## Quick-build card bar vs nested shop menus

The first design put buildings in a Buy tab inside a shop screen inside a hotbar. New players got lost; tutorial arrows pointed at cards hidden behind a closed panel.

What replaced it, and worked:

- **A card bar always on screen** with every building you can place: icon, live price, grey price plate when you can't afford it (a tap says how much is missing and pulses the cash).
- **Builder status on the bar:** a green dot per free builder, a countdown chip per busy one, and a "starts in Xs" chip on cards when every builder is busy.
- **Tap a building in the world → a bubble over it** with one big context button (Upgrade / Repair / Rebuild / Finish, with cost and wait) and small Move / Rotate / Remove buttons. Remove picks cancel-or-demolish, whichever refunds more, and asks once on the button.
- A one-line plain explanation of each building under its name in the bubble.

Why it works: zero navigation between wanting a building and placing it, and the tutorial can always point at a visible card.

## Checklist

- Ghost starts near the player, snaps to the nearest valid cell, explains red states.
- `ScreenPointToRay` for `input.Position`, `ViewportPointToRay` for `GetMouseLocation()`.
- One reused Highlight; hover uses the click's pick.
- Picking falls back to cell → owner, with big touch targets.
- Tap/drag thresholds per input type; touches counted by hand.
- Counts shown on the client come from the server's function.
- Placing a building takes one tap on an always-visible card.

Previous: [[Showing progress on buildings]] · Next: [[Verifying maps and models]]
