---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ui/overview
retrieved: 2026-10-15
---
# UI overview

How to design, build, ship and verify game UI on Roblox with an AI coding agent. Everything here came from real bugs in shipped and prototype games (a kids' strategy tycoon, several idle games, a...

How to design, build, ship and verify game UI on Roblox with an AI coding agent. Everything here came from real bugs in shipped and prototype games (a kids' strategy tycoon, several idle games, a parkour shooter, a pixel RPG). Each rule says which bug it prevents.

## Contents

| File                                                      | What it covers                                                                                                                                    |
|-----------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| [[HTML-first UI pipeline|html-pipeline.md]]           | Design every screen in HTML/CSS, export layout JSON, generate data, build the ScreenGui with one Builder. Keeping runtime copies in sync.         |
| [[Style rules|style-rules.md]]               | Icons, fonts, outlines, glass panels, phone readability, the "less on screen" rule for kids.                                                      |
| [[Measured GUI and input facts|gui-input-facts.md]]       | Measured engine facts: the 58 px inset, input space, UIStroke vs UIScale, ScrollingFrame collapse, BillboardGui clipping and clicks, touch sizes. |
| [[HUD and progression patterns|patterns.md]] | HUD and progression patterns: next-goal pill, tier checklist, upgrade preview, "Max for Tier N", tap-a-building bubble, card bars, badges.        |
| [[Feedback patterns|patterns-feedback.md]]   | Toasts, celebrations, odds popups, single-reel crate opening, loading screen, one number formatter.                                               |
| [[Verifying UI|verifying-ui.md]]             | Magenta captures, property sweeps, edit-mode mock harnesses, offline mock renders, device profiles, update-in-place.                              |
| [[Checklists|checklists.md]]                 | New-screen checklist and mobile-pass checklist.                                                                                                   |

### Snippets (`snippets/`, Luau, game-agnostic)

| File                        | Use                                                                                                                   |
|-----------------------------|-----------------------------------------------------------------------------------------------------------------------|
| `NumberFormat.luau`         | The one formatter: `1,234`, `250K`, `1.36M`, times, rates. Has the 250K/25K regression test.                          |
| `NextGoal.luau`             | Config-driven "Next goal" resolver: first unmet goal wins, returns text, progress and a tap action.                   |
| `Toasts.luau`               | Toast queue with dedupe (same text pulses instead of stacking), length-based duration, max stack.                     |
| `ProgressiveReveal.luau`    | Show HUD pieces only once they matter; columns close up around hidden rows.                                           |
| `WorldHitTest.luau`         | Pick BillboardGui plates and world objects by hit-testing instead of relying on billboard buttons.                    |
| `PixelRows.luau`            | ScrollingFrame rows in pixels, so AutomaticCanvasSize doesn't collapse or explode.                                    |
| `UpdateInPlace.luau`        | Reuse list rows when the row signature is unchanged; never destroy-and-reclone every tick.                            |
| `LoadingScreen.client.luau` | ReplicatedFirst loading screen driven by a load-stage attribute, with a safety timeout.                               |
| `CrateRoll.luau`            | Server roll with weights and pity, then a client reel plan whose near-miss is cosmetic.                               |
| `PropertySweep.luau`        | Edit-mode or runtime audit: text that doesn't fit, overlapping siblings, children escaping parents, tiny tap targets. |

### Tools (`tools/`)

| File              | Use                                                                                                |
|-------------------|----------------------------------------------------------------------------------------------------|
| `dump_layout.js`  | Minimal DOM-to-layout-JSON walker to inject into a headless page (the export step).                |
| `gen_layout.py`   | Minimal generator: layout JSON to a `Data_<Screen>.luau` module the Builder reads.                 |
| `check_copies.py` | Fails if the copies of a runtime module (Builder copy, StarterGui copy, source tree) have drifted. |

## The five lessons that cost the most

1.  **One source of truth for the UI runtime.** A Builder that clones its own stale copy of the UI module into every rebuild silently rolls back months of fixes. Hash-check the copies on every push.
2.  **One number formatter.** Two formatters disagree, and the buggy one ("strip trailing zeros" on whole numbers) showed 250,000 as "25K" on the screen kids look at most.
3.  **Update in place.** Re-cloning a panel every second drops any tap whose press and release straddle the refresh. Reuse rows; only rebuild when the row set changes.
4.  **Less on screen.** A kids' HUD with ~30 readouts became cash plus one "Next goal" pill, with everything else revealed when it starts to matter.
5.  **Verify with numbers, not eyes.** Studio captures can come back magenta or skip BillboardGuis. Sweep properties (TextFits, overlaps, AbsoluteSize) and render an offline mock from the same data.

Next: [[Style rules]]
