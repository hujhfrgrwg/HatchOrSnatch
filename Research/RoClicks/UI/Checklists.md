---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ui/checklists
retrieved: 2026-10-15
---
# Checklists

Design - \[ \] Purpose in one sentence; what the player does here and how they leave. - \[ \] Designed in HTML at the design canvas, in the game's one kit (shared plate, fonts, outlines).

## Contents

- [[#New screen]]
- [[#Mobile pass]]
- [[#Before every UI push]]

## New screen

Design

- Purpose in one sentence; what the player does here and how they leave.
- Designed in HTML at the design canvas, in the game's one kit (shared plate, fonts, outlines).
- Every state drawn on a sheet page: empty, full, locked, unaffordable, loading, error, longest text.
- Shown in context over a real game capture at real size, phone and PC.
- Approved by the developer on the HTML before import.
- Icons only from the project's one pack; no emojis; close button is a text "X".
- All words are live text; no text baked into art.
- One primary action, biggest and brightest.
- Locked and unaffordable items say what unlocks them or how much is missing.

Data and logic

- Lists that grow with progress scroll (pixel rows), or are sized for the maximum.
- Totals computed over all data, not over drawn rows.
- Numbers go through the one formatter; previews and costs come from the shared formula module.
- No raw ids, "?", "nil" or placeholder numbers can reach a label (open the screen with fresh state and check the mock values are all replaced).
- Opening the screen refreshes it with real data (one prestige screen opened showing mock numbers).
- Rows update in place; nothing re-clones on a timer; hidden screens don't refresh.
- Escape / gamepad B / close button / forced close (battle start, another screen opening) all run the same close path and clear any selection state (a hotbar button needed two taps after Esc).
- Number keys and shortcuts are ignored while the screen's mode doesn't allow them.

Build and verify

- Group wrappers and node names added; renders still pixel-identical.
- No child named after a GuiObject property.
- Exported, generated, uploaded via the ledger, built by the Builder (not by hand).
- Fit pass run twice; TextFits sweep clean at phone, tablet and PC sizes.
- Offline mock diff scored; heatmap checked.
- Real click on every button in a playtest, effect on state confirmed.
- Runtime module copies hash-identical (disk, Builder folder, live gui).
- Inventory of runtime UI updated if game code creates any of this screen's pieces.

## Mobile pass

Run on a phone device profile in landscape, plus portrait if the game allows it.

Reach

- Every PC action is reachable on touch (no desktop-only buttons, no keyboard-only actions).
- Nothing important sits under Roblox's top bar, thumbstick area or jump button.
- Primary actions under the right thumb.

Size

- Every tap target is at least 48 screen px; primary ones 56-60 px (about 130 / 160 design px on a 1920x1080 canvas at phone scale).
- Body text at least about 9-10 screen px; `MinTextSize` floors not below 14 design px.
- World labels and plates have a pixel floor on touch, and their BillboardGui canvas is sized in pixels with headroom (no clipped names or badges).

Input

- World picks use `ScreenPointToRay(input.Position)` and raycast from the tap, not from a reticle.
- Tap vs drag thresholds tuned for touch (14 px or 2.5% of the short side, 0.65 s).
- Billboard "buttons" are hit-tested with padded tap boxes, not relying on billboard clicks.
- A cancel exists for every targeting mode (no "right click to cancel" on phones).
- Keyboard hints and key-number chips are hidden.
- Camera drag and pinch claim the touch so they don't also click.

Density

- HUD shows only cash, the next goal and what's needed right now.
- Toasts are short enough to read at phone scale without shrinking.
- Panels fit the screen height at phone scale (scale to height, not width).

Verify

- Property sweep at phone size: no TextFits failures, no overlaps, no escaped children.
- One short real playtest on the phone profile per input change.
- Multi-touch behaviour noted as "read only" until tested on a real device.

## Before every UI push

- Pull Studio's current copies first if anyone else (a collaborator or another agent) edits the place.
- Diff disk vs Studio for every file you're about to push; merge, don't overwrite.
- Static check every client file (`luau-analyze`).
- Push as model files (.rbxmx), not by pasting source.
- Hash-check the runtime copies after the push.
- Note in the change log what was verified live vs in edit mode vs by reading only.

Previous: [[Verifying UI]] · Next: [[Words, numbers and rewards on screen]]
