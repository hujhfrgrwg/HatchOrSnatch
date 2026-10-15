---
tags: [research, roclicks]
source: https://roclicks.gg/resources/game-design/progression-and-pacing
retrieved: 2026-10-15
---
# Progression and pacing

How to keep a player moving toward the next tier, and how to prove with a simulation that they can't get stuck.

How to keep a player moving toward the next tier, and how to prove with a simulation that they can't get stuck.

## Contents

- [[#Make the next goal explicit]]
- [[#Gate goods vs auto-sell]]
- [[#Time milestones with a sim]]
- [[#Sims are optimistic]]
- [[#Upgrades must beat a new copy]]
- [[#Serial gates and lulls]]
- [[#Prestige worth doing]]
- [[#Daily and tier-up rewards]]
- [[#Soft-lock detection by simulation]]

## Make the next goal explicit

Players asked "how do I get to Tier 3?" because the requirements lived on three screens (rings, research, goods). Fix it with two pieces:

- **A next-goal pill** on the HUD that names the *current blocker* only, and walks through them in order:

  1.  "Clear Ring 2: conquer 2 more (5/7)"
  2.  "Take the capital to clear Ring 2"
  3.  "Get 700 Iron for Tier 3 (420/700)"
  4.  "Save \$24,000 for Tier 3"
  5.  "Lab busy: Drill finishes first (2:39)"
  6.  green READY: "Research Tier 3 in the Lab"
  7.  "Researching Tier 3 (2:32)" with a bar

  Tapping it opens the right screen, focused on the right item.

- **A checklist** under the pill (tap a tier chip): every requirement with a tick or cross, progress, the current blocker outlined, and "Unlocks: …" so the player knows why they want it.

Build both from the same config the server checks (tier list + research costs). Never hand-write the text, or it drifts. Hide the pill while a building panel or the tutorial card is up, so it doesn't show through.

## Gate goods vs auto-sell

**Bug:** an Auto Sell feature kept a flat 150 iron and sold the rest every 10 s. The Tier 3 gate needed 700 iron. With Auto Sell on, iron never got past ~150, so the tier could never be paid, and the message just said "Need 550 iron". It hit paying players first, because Auto Sell was a paid pass.

Rules:

- One keep function decides how much of each resource is safe to sell. Every sell path uses it: auto sell, "Sell All" and per-row sell buttons. (A per-row button that skipped it let tutorial players sell the wheat they needed for the next step.)
- Priority: the player's own keep setting \> the next tier gate's goods (once its other requirements are met) \> the next build's cost \> the tutorial reserve.
- When a sell keeps everything, say why in a toast.
- The "Need N iron" message adds "(Auto Sell is on)" when it is.
- Better still: remove goods from gates. One redesign went cash-only for this reason.

Same family: **storage caps must never be the only thing blocking a purchase.** If a cost exceeds the warehouse cap, the player can never afford it. Raise the cap floor to the largest cost the player can face *next* (next research level, not level 1).

## Time milestones with a sim

Write a plain-Luau (or Python) balance sim that plays the game with a greedy bot using the real config and formulas. Use it to time milestones across many seeds:

| Milestone                 | Example target |
|---------------------------|----------------|
| First win                 | ~4 min         |
| First ring / zone cleared | 10 to 15 min   |
| Tier 2                    | 20 to 35 min   |
| Tier 3                    | 50 to 70 min   |

Also measure **lulls**: the share of each 5-minute block with no purchase or win for 20 s or more. One sim showed 9 to 28% waiting at minutes 15 to 25 because the next zone's weakest enemy was 3× the last boss. Adding two weaker "gateway" enemies on the road out fixed it. Later lulls had 35 to 64% waiting; four gateways, one tier weaker, fixed those.

Re-run the sim after every balance change, on 4 to 9 seeds, and report min / median / max.

## Sims are optimistic

A sim bot is not a kid. Known ways sims flattered one game:

- It **bought missing goods with cash**, which the real game can't do, so 700 iron cost it a trivial \$9.5K.
- It reacted instantly (attacked the moment it was ready); a real player paced 3 to 5× slower on the first conquest.
- It picked units it couldn't actually train, and attacked at ratios real fights didn't support.
- It didn't model the single research slot being busy with side research, which blocked the tier gate for an hour.

So:

- Mirror real constraints in the sim (no buying goods, slot limits, caps).
- Feed the sim measured numbers. One game ran 102 real battles to measure win rates by power ratio, then used those in the sim.
- Treat sim times as a lower bound. Check the important ones with one real paced playthrough.
- When the sim stalls, first ask: bot bug or game bug? Replay the bot's exact state in the real game.

## Upgrades must beat a new copy

**Counter-example:** upgrade cost was `2.2 × level^1.45` per step, so reaching level 10 cost **223× base** in total for **5.5× output** (linear +0.5 per level). A new copy cost 1 to 7.6× base. Copies always won, the sim built 138 copies vs 32 upgrades, and the map filled with clutter to walk over.

Rule: the marginal cost of output from upgrading should be close to, or better than, building another copy. Check it with [snippets/upgrade_vs_copy.py](https://roclicks.gg/resources/code/game-design/snippets/upgrade_vs_copy.py). Fixes: lower the cost exponent (≈1.1), or raise the output step (≈+1.0 per level). Also:

- show the upgrade's effect before buying ("+0.9/s → +1.35/s Wood"), computed from the server's own formula;
- make every level change something visible on the building;
- say "Max for Tier N" with what unlocks more, not just "Max level".

## Serial gates and lulls

If every tier requires "clear the zone, *then* pay, *then* wait 10 / 40 / 90 minutes", the player sits idle against enemies a tier above them.

- Let the tier research start before the zone is cleared; the tier unlocks the moment both are done.
- Keep gate timers short (5 / 15 / 30 min).
- Give the gate research its own slot, or let it pre-empt side research.
- When the research slot is idle, suggest a one-tap node (gate first, then production).

## Prestige worth doing

A reset that pays 2 stars (≈+10% income) for 2 to 3 hours of buildings, land and research is a trap, and repeating "New Campaign unlocked!" on every zone clear nudges kids into it.

- Show "you'll lose X, you'll gain Y" before confirming.
- Pay enough that the second run is visibly faster (e.g. 3 stars per zone + 1 per 5 wins, instead of `floor(sqrt(wins/5))`).
- Announce it once, when first available.
- Make the dialog text true. One said "you keep research" and then reset every node to level 1 and dropped running jobs.
- **List what survives a reset explicitly.** An idle game rebuilt state from `newState()` and silently re-armed the daily reward, the wheel, quests, redeemed codes and the tutorial on every prestige. Keep an `Account` list of fields to carry; anything new and permanent must be added there.
- Leaderboards rank a monotonic total, never "earned this run".

## Daily and tier-up rewards

- **Daily login streak:** a 7-day calendar, cash scaled to current income, premium currency on days 3 and 7, a free item on day 7. Store `{day, lastClaim}` in the save and use server time.
- **Tier-up reward:** a "TIER n UNLOCKED!" card with fanfare and particles, a gift (e.g. 10 / 20 / 30 / 40 gems), and the new buildings and units it unlocked. A tier-up that only flips a number feels like nothing happened.
- **Offline:** a welcome-back screen that says "Collect" and gives \$0 feels broken. Give some offline income (e.g. 25% for up to 2 h) or label it honestly.
- Count free premium currency on the main path against what rushing costs. ~28 free gems vs 1 gem per minute of rush meant kids never got to feel a rush.

## Soft-lock detection by simulation

**Bug:** on an endless map of rings, countries left over in an old ring became unattackable once the player's current ring moved on (`ring == currentRing` instead of `ring <= currentRing`). If the path to the next capital ran through a leftover, the game was permanently stuck. Nobody found it by playing. A **300-seed sim** found it: 32 seeds locked at ring 3, 50 at ring 4, 60 at ring 5.

How to look for this class of bug:

1.  Generate the world for many seeds (hundreds, they're cheap).
2.  Play it with the real "can I attack / is it visible / neighbours" functions, using a bot that always takes the cheapest legal move.
3.  Assert reachability at every step: the next required target must be reachable through legal moves.
4.  Report the seeds and the step where it got stuck.

A template is in [snippets/softlock_sweep.py](https://roclicks.gg/resources/code/game-design/snippets/softlock_sweep.py). Fix leftovers by keeping them as easy "mop-up" targets, and add a "clear all" button for leftover ruins.

Previous: [[Tutorial template]] · Next: [[Combat feel]]
