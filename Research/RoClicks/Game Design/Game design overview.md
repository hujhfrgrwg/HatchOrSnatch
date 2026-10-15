---
tags: [research, roclicks]
source: https://roclicks.gg/resources/game-design/overview
retrieved: 2026-10-15
---
# Game design overview

How to design Roblox games for kids that are fun, low friction and monetized ethically.

How to design Roblox games for kids that are fun, low friction and monetized ethically. Distilled from shipping several Roblox games with an AI coding agent, mainly a kids' strategy tycoon, plus idle, RNG and RPG projects. The specific games appear only as short worked examples.

## Contents

| Page                                                                                 | What it covers                                                                                                                                         |
|--------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| [[Design checklist|design-checklist.md]]                       | **Start here.** The release checklist, one line per rule, linked to the reasons.                                                                       |
| [[Onboarding|onboarding.md]]                                   | Tutorial shape, pointers, auto-advance, no soft-locks, the unlosable first fight, waiting steps, low-cash tip, intro and loading screen.               |
| [[Tutorial template|tutorial-template.md]]                     | A fill-in step table, per-step and whole-tutorial checklists, and a test plan.                                                                         |
| [[The kid's first-10-minutes audit|first-10-minutes-audit.md]]           | How to audit a kid's first 10 minutes: decisions, numbers, menus, waits, Robux prompts.                                                                |
| [[Progression and pacing|progression-and-pacing.md]]           | Next-goal pill, gate goods vs auto-sell, sims (and why they're optimistic), upgrades vs copies, prestige, daily and tier-up rewards, soft-lock sweeps. |
| [[Combat feel|combat-feel.md]]                                 | Endings that don't drag, vehicle slots, natural infantry, Easy / Close / Hard, losing that feels OK.                                                   |
| [[Monetization and compliance|monetization-and-compliance.md]] | No auto-prompts, quiet period, double-purchase guard, paid random items and PolicyService, like rewards, grandfathering, starting currency.            |
| [[Analytics|analytics.md]]                                     | Onboarding funnel, session funnel, custom events, client validation, renumbering safely.                                                               |
| [[Process|process.md]]                                         | Playtester feedback loops, 15 parallel reviewers merged into a ranked list, fix agents, prepare-then-apply.                                            |
| [[Review areas|review-areas.md]]                               | The 15 review areas and what each reviewer looks for.                                                                                                  |

### Snippets

| File                                                                                             | What it is                                                                                                        |
|--------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| [snippets/tutorial_steps.luau](https://roclicks.gg/resources/code/game-design/snippets/tutorial_steps.luau)         | Server tutorial step machine: early actions count, absolute goals, go-back rules, pay-once rewards, resume, skip. |
| [snippets/onboarding_funnel.luau](https://roclicks.gg/resources/code/game-design/snippets/onboarding_funnel.luau)   | Monotonic onboarding funnel with fill-in, legacy freeze, validated client steps, session funnel, Studio dry run.  |
| [snippets/purchase_guard.luau](https://roclicks.gg/resources/code/game-design/snippets/purchase_guard.luau)         | Client "Delivering…" state plus server intent window, duplicate compensation and safe credits.                    |
| [snippets/paid_random_policy.luau](https://roclicks.gg/resources/code/game-design/snippets/paid_random_policy.luau) | `ArePaidRandomItemsRestricted` gate with retry, weighted roll with pity, odds from the same table.                |
| [snippets/battle_pace.luau](https://roclicks.gg/resources/code/game-design/snippets/battle_pace.luau)               | Pace scale, mop-up trigger, surrender, overtime.                                                                  |
| [snippets/upgrade_vs_copy.py](https://roclicks.gg/resources/code/game-design/snippets/upgrade_vs_copy.py)           | Prints cost per output for upgrades vs copies and warns when copies win.                                          |
| [snippets/softlock_sweep.py](https://roclicks.gg/resources/code/game-design/snippets/softlock_sweep.py)             | Many-seed reachability sweep; the toy map reproduces a real "leftover ring" soft-lock and its fix.                |

The `.luau` snippets pass `luau-analyze` apart from Roblox globals. The Python scripts run with plain `python3`.

## The ten lessons that mattered most

1.  **The tutorial is the core loop, nothing else.** 10 steps became 6; each ≤ 8 words, one pointer on the exact button, auto-advance with a reward.
2.  **Write tutorial rules on the server so they can't soft-lock**: count early actions, absolute goals, go back after a loss, resume on rejoin.
3.  **The first fight can't be lost**, and that has to be re-tested after every combat change; a balance tweak once made it "Hard ~2%".
4.  **No Robux prompt ever opens by itself.** A partial "+5" purchase once trained the units *and* opened a prompt.
5.  **Lock Buy until the grant lands.** `PromptProductPurchaseFinished` fires before `ProcessReceipt`, and a kid paid twice.
6.  **Check `ArePaidRandomItemsRestricted` on the server in every path**, treat a failed lookup as restricted, and retry.
7.  **Sims time your milestones but flatter you.** Mirror real constraints and feed them measured fight results.
8.  **Run a soft-lock sweep on hundreds of seeds.** A 300-seed sim found a progression wall nobody hit in playtests.
9.  **Upgrades must pay like copies.** 223× the cost for 5.5× the output turned the map into clutter.
10. **Fights end fast**: mop-up, surrender, a clock that speeds up, and Easy / Close / Hard instead of numbers.

Next: [[Design checklist]]
