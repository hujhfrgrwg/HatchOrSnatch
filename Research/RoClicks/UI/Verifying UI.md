---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ui/verifying-ui
retrieved: 2026-10-15
---
# Verifying UI

An agent can't trust its eyes in Studio. Captures lie, clicks miss, hover never fires. Verify with numbers first, pictures second.

An agent can't trust its eyes in Studio. Captures lie, clicks miss, hover never fires. Verify with numbers first, pictures second.

## Contents

- [[#What Studio captures can and can't show]]
- [[#Property sweeps]]
- [[#Edit-mode mock harness]]
- [[#Offline mock render]]
- [[#Device simulator profiles]]
- [[#Real clicks]]
- [[#Update in place]]
- [[#Order of tool calls]]

## What Studio captures can and can't show

| Situation                                           | What came back                                                 |
|-----------------------------------------------------|----------------------------------------------------------------|
| Capture during a playtest (some builds, some tools) | solid **magenta** frame                                        |
| Capture in edit mode                                | 3D viewport only; ScreenGuis (and anything in CoreGui) missing |
| Capture during a playtest (later builds)            | ScreenGuis rendered correctly                                  |
| BillboardGuis, any mode                             | **never rendered**, even AlwaysOnTop in front of the camera    |
| Retina displays                                     | 2x images; pixel coordinates are not click coordinates         |

So: try a capture first, but a magenta frame is a broken screenshot, not a broken UI. Taking another screenshot teaches nothing. Switch to the methods below. Missing billboards in a capture are not a bug.

## Property sweeps

Run a script in the running client (or in edit mode on a cloned gui) that walks every visible GuiObject and reports objective failures. [snippets/PropertySweep.luau](https://roclicks.gg/resources/code/ui/snippets/PropertySweep.luau) checks:

- `TextFits == false` on any visible TextLabel/TextButton,
- `TextBounds.X` vs the design ink width (the fit pass; resize when more than 1.5% off),
- pairwise `AbsolutePosition`/`AbsoluteSize` overlap between sibling controls,
- children escaping their parent's rect (clipped or floating),
- tap targets smaller than the minimum on touch,
- images whose asset isn't loaded (judge per asset id; offscreen instances always report `IsLoaded` false),
- billboards: `Enabled`, `Adornee` and its parent, `Size`, `MaxDistance`.

Sweep several viewport sizes without resizing anything real: set `Root.Size = UDim2.fromOffset(w, h)` and the UIScale for each target (phone 844x390, tablet 1024x768, PC 1920x1080), sweep, restore.

Getting data out: a Studio plugin context can't enable `HttpService.HttpEnabled`, so it can't POST to a local sink. Return a compact line-format string from the script and parse it locally.

## Edit-mode mock harness

Most UI logic can be driven without a playtest (playtests are slow, and on shared machines one may be locked by another agent):

1.  Clone the built ScreenGui into a scratch parent.
2.  `require` the clone's UI module and the real controllers, passing a **MockState** table shaped like the server's replicated state (cash, tier, buildings, timers).
3.  Drive it: call `setGoal`, open screens, feed state changes, step timers manually.
4.  Sweep properties, and capture the 3D viewport if world-side pieces matter.
5.  Tear down: `UI.destroy()` disconnects InputBegan/RenderStepped, then destroy the clone.

Gotchas:

- `require` caches across separate script runs in the same Studio session. Clone a module (or rename it) to load a fresh copy after pushing a change, and clone config tables before mutating them in a preview.
- `PreSimulation`/`Heartbeat`-driven code doesn't tick in edit mode; step it by hand.
- Edit-mode harnesses verify layout and logic, not real input. Do at least one short real playtest per change that touches input.

## Offline mock render

The strongest check for generated UI: render the **same `Data_<Screen>` data the Builder reads** as HTML that follows Roblox semantics, then diff it against the original design screenshot.

- Emulate Roblox rules exactly: UIStroke inner/outer/contextual, UIGradient multiplying the base colour, ImageColor3 tint, ScaleType Fit/Stretch/Tile, AnchorPoint, UIScale, TextSize = line height.
- Inline images as data URIs (headless Chrome drops http images at random).
- Score with a blurred mean absolute difference, overall and per 3x3 region, and write a heatmap. A healthy pipeline scored 0.9-2.8 / 255 mean per screen.
- This caught overlapping header buttons that nobody saw in Studio.

## Device simulator profiles

- Test at least one phone profile (e.g. a 6.1" iPhone in landscape) and a PC window in Studio's device emulator every time a HUD or input change ships.
- On phones check: tap targets, world label floors, no keyboard hints, Roblox's own jump and thumbstick not covered, every PC action reachable.
- What emulation can't do: real multi-touch. Pinch and second-finger rejection get a code read and, before launch, a test on a real device.

## Real clicks

- Read the target's `AbsolutePosition + AbsoluteSize / 2` from the running client and click there (plus the inset on y when the gui doesn't ignore it; see [[Measured GUI and input facts|gui-input-facts.md]]).
- Confirm with an armed `InputBegan` recorder before calling a button dead.
- Verify the effect on state (cash went down, screen opened), not just that a handler ran.

## Update in place

**Never destroy and re-clone a panel's rows on a timer.** A sell screen refreshed every second by destroying all rows and cloning new ones. Any press whose down and up straddled a refresh was dropped, because `Activated` needs both on the same instance; hover and press animations also reset every second. Kids experienced it as "the button sometimes doesn't work". The same bug had already been fixed once for the army cards, then reappeared in two more panels.

- Build rows once. On refresh, compute a **signature** (row keys + lock states). If unchanged, only update labels, colours and bars in place.
- Rebuild only when the signature changes, and then reuse existing instances where keys match.
- Don't refresh hidden panels (a closed panel kept rebuilding itself at 1 Hz).
- Per-second refresh only for what actually changes per second (timers, live counts); everything else on the state-change event.
- Debounce repaint triggers (e.g. repaint at most every 2 s on frequent army changes).

See [snippets/UpdateInPlace.luau](https://roclicks.gg/resources/code/ui/snippets/UpdateInPlace.luau).

## Order of tool calls

Agent tool calls issued in one batch are **not ordered**. A camera move and a capture in the same batch raced and returned the old camera; a destroy and an import raced and the import was destroyed. Sequence dependent steps across turns, or do them inside one script run (stage the import in ServerStorage and move it in the same script that uses it).

Previous: [[Measured GUI and input facts]] · Next: [[Checklists]]
