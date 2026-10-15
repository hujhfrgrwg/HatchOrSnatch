---
tags: [research, roclicks]
source: https://roclicks.gg/resources/game-design/design-checklist
retrieved: 2026-10-15
---
# Design checklist

Run this before every release that touches the first hour, the shop or the balance. Each line links to the page that explains the bug behind it.

Run this before every release that touches the first hour, the shop or the balance. Each line links to the page that explains the bug behind it.

## Onboarding ([[Onboarding|onboarding.md)]]

- Custom loading screen from ReplicatedFirst; no blank world or \$0 HUD on join.
- Intro plays only on the first-ever join (flag in the server save, set on start), ~15 s, action only, one-tap skip.
- Tutorial is ~6 learn-by-doing steps, ≤ 8 words per card, all core loop.
- One strong pointer on the exact button, inside panels too; text, hint and pointer agree.
- Steps auto-advance and celebrate (stamp, "+\$N", particles, sound); each reward pays once.
- Actions done early count; goals are absolute; steps can go back after a loss.
- Rejoin resumes the step; old step lists are migrated; skip exists.
- The tutorial fight is unlosable, decided on the server, tested as a matrix of army sizes × seeds.
- Tutorial locks apply only to the tutorial's own target.
- Waiting steps say "wait" and point at the timer.
- Low-cash tip instead of a dead end.
- Events, raids, popups and diplomacy are off during the tutorial.
- After the tutorial, a pointer keeps showing the next beatable target.

## First 10 minutes ([[The kid's first-10-minutes audit|first-10-minutes-audit.md)]]

- Audit table filled in for a fresh save: waits, decisions, numbers, menus, Robux surfaces.
- Under ~5 numbers on the first HUD frame; the rest reveals itself when useful.
- No dense screen (sliders, price trends, legends) before it's needed.
- The first free-play choice doesn't lead straight into a likely loss.

## Progression ([[Progression and pacing|progression-and-pacing.md)]]

- A next-goal pill names the current blocker; a checklist shows every requirement and what it unlocks.
- One keep rule for every sell path; auto-sell never sells goods the next gate needs.
- Storage caps never block the next purchase.
- Milestones timed by a sim on 4+ seeds, with a lull metric; treated as a lower bound.
- Sim mirrors real constraints (no buying goods, slot limits) and uses measured fight results.
- Upgrading costs about the same per output as a new copy (`upgrade_vs_copy.py`).
- Gate research can start early and doesn't queue behind side research.
- Prestige shows lose/gain, pays enough, carries an explicit account-field list, announces once.
- Daily streak and a tier-up reward card exist; offline screen never says "Collect" for \$0.
- Multi-seed soft-lock sweep passes (`softlock_sweep.py` pattern, 300 seeds).

## Combat ([[Combat feel|combat-feel.md)]]

- Mop-up, surrender and a pace scale end fights without a long tail.
- Vehicles get their own slots and targets; no pile-ups.
- No idle squads; sieges keep moving.
- Easy / Close / Hard verdicts, calibrated from real fights, one colour source.
- Losing explains why and offers one free next step; no purchase dialog on a loss.

## Monetization ([[Monetization and compliance|monetization-and-compliance.md)]]

- No Robux prompt ever opens by itself, including on partial affordability.
- Every paid button shows its price.
- All Robux surfaces hidden until the tutorial is done plus ~10 minutes.
- "Delivering…" state; server refuses a repeat prompt for a permanent item; duplicate receipts compensate.
- Paid random items: `ArePaidRandomItemsRestricted` checked on the server in every path; failed lookup = restricted + retry; odds from config; pity.
- Like rewards reviewed against current Roblox rules, with the developer's sign-off.
- Grandfathering decided by the developer and fully implemented either way.
- First-join balance measured in a playtest and matches config (no auto-claimed rewards).
- Product ids in one config; a list of what the developer must create.

## Analytics ([[Analytics|analytics.md)]]

- Onboarding funnel: fine-grained, monotonic, gaps filled by the server, fresh saves only.
- Per-join session funnel with New player / Rejoin.
- Custom events for step time, skips, intro skip time, low-cash tips.
- Client steps: allow-list, next-step only, tutorial active, rate-limited.
- Renumbered funnel: old mid-tutorial saves frozen as legacy.
- Studio dry run verified.

## Process ([[Process|process.md)]]

- Collaborator feedback written down, numbered, and answered item by item.
- Studio pulled and base-compared before every push.
- Held changes staged with a base-checked apply step and marked "NOT applied".
- Decisions that belong to the developer were asked, not made.

Previous: [[Game design overview]] · Next: [[The kid's first-10-minutes audit]]
