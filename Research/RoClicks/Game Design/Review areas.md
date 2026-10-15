---
tags: [research, roclicks]
source: https://roclicks.gg/resources/game-design/review-areas
retrieved: 2026-10-15
---
# Review areas

The 15 areas for a parallel read-only review (see process.md). Give each reviewer one row, the shared brief, and the "look for" list.

The 15 areas for a parallel read-only review (see [[Process|process.md]]). Give each reviewer one row, the shared brief, and the "look for" list. Rename or merge rows for your genre; a pure idle game might fold Combat and Army into one.

| \#  | Area                               | Look for                                                                                                                                                                                                                                         |
|-----|------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 01  | **Economy**                        | Every sell/spend path uses the same keep rule; income formulas match what the UI shows; offline income; caps that block purchases; refund loops (demolish must refund a share of what was actually *paid*, never more); free vs paid automation. |
| 02  | **Building / placement**           | Valid-spot feedback, cancel paths (Esc, a big Cancel button on touch), counting owned copies (ruins counted as owned inflated prices), queued/upgrading buildings hit by raids, refunds.                                                         |
| 03  | **Combat**                         | Endings that drag, stuck units, cooldowns at 2×/5× speed, research bonuses actually applied, skip/resolve paths, the difficulty estimate vs real results, paid "win now" killing your own units.                                                 |
| 04  | **Army / units**                   | Train, queue and partial batches (no Robux prompt on partial affordability), caps, roster display across tiers, unit icons.                                                                                                                      |
| 05  | **Map / world**                    | Reachability on many seeds (soft-locks), visibility rules, label colours, leftover targets, map controls on phones.                                                                                                                              |
| 06  | **Tutorial**                       | Step list, pointers, early actions counted, regressions after a loss, rejoin, skip, step-number couplings in other files.                                                                                                                        |
| 07  | **Shop / products / random items** | No auto-prompts, double purchase window, PolicyService on every server path, odds from config, pity, receipt idempotency, rate limits, product ids in one config.                                                                                |
| 08  | **UI / HUD**                       | Number formatting (one formatter showed \$250,000 as "25K\$"), missing rows, phone layouts, overlapping panels, stale builder copies, element count on frame one.                                                                                |
| 09  | **Data / saves**                   | `BindToClose` waits for in-flight saves, session locking, transient errors not treated as "no DataStore", failed loads kick instead of starting a never-saving fresh game, backoff, migrations.                                                  |
| 10  | **Server / remotes / security**    | Validation and rate limits on every remote, trusting client values, half-done features left live, multiplayer leftovers in a solo game.                                                                                                          |
| 11  | **Sound and FX**                   | Unapproved or missing sound ids, loops that never stop, double plays, mute settings scoped right, feedback on every action.                                                                                                                      |
| 12  | **Controls**                       | Touch and gamepad parity, pinch/drag bugs, one click firing several handlers, camera recenter, input while a panel is open.                                                                                                                      |
| 13  | **Performance**                    | Part counts, clones made then hidden, UI rebuilding every second (eats taps), leaks on player leave, battles with 100+ units on phones.                                                                                                          |
| 14  | **A kid's first 10 minutes**       | The [[The kid's first-10-minutes audit|audit method]]: waits, decisions, numbers, menus, Robux surfaces, the first loss.                                                                                                             |
| 15  | **Progression and pacing**         | Sim times per milestone, serial gates, goods vs auto-sell, upgrade vs copy, prestige value, daily and tier-up rewards, free premium currency vs rush costs.                                                                                      |

## Brief checklist for the coordinator

- One shared brief file, plus a one-line area assignment per agent.
- Point at an exact code snapshot exported from Studio, not the disk copy.
- Read-only. No Studio tools, no playtests (they overload the developer's machine).
- One output file per reviewer: `reviews/NN_<area>.md`.
- Report format: bugs (file:lines, trigger, severity, confidence, fix), 5–10 kid-friendly improvements (impact, effort), summary.
- Flag half-done work (e.g. a cancelled multiplayer feature still live).
- Merge into `00_SUMMARY.md`: P0, P1, half-done work, shared ideas (numbered), needs-the-developer.

Previous: [[Process]]
