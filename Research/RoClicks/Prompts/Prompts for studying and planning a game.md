---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ai-prompts/ai-planning-prompts
retrieved: 2026-10-15
---
# Prompts for studying and planning a game

Break a reference game down from footage, simulate the economy before building, and run a QA pass.

Copy the prompt with the button on its box, then paste it into your AI.

## Study a reference game from footage

Record 10 to 15 minutes of play, pull frames, and give them to an assistant:

``` text
These are frames from 15 minutes of gameplay of [GAME]. Break it down as MEASURED facts, not impressions:
1. The pitch in one line, and the core loop as a numbered cycle.
2. A milestone timeline in minutes: first upgrade, first new zone, first rebirth or prestige.
3. An economy table: every currency, its sources and sinks, and cost and yield per tier. Mark numbers you fitted from the footage as fitted.
4. The screens in the order a new player meets them, and what the HUD always shows.
5. Monetisation: every pass and product, its price, and the moment it is first offered.
6. What to keep, what to cut and what to improve for my version.
Say "unknown" rather than guessing anything the footage doesn't show.
```

## Simulate the economy before building

``` text
Write a small simulation (Python or Luau) of this game's economy: [PASTE THE LOOP AND THE NUMBERS].
Simulate a new player who plays optimally and one who plays casually. Print the minute each milestone lands for each: [LIST MILESTONES].
Then tell me where the pacing drags (a wait over [N] minutes with nothing new) or rushes, and propose the smallest number changes that fix it. Change one curve at a time and re-run.
```

## A QA pass before launch

``` text
Run a QA pass on the game in edit mode. Don't start a playtest.
- Read the logs: list every error or warning from our code.
- UI: property-sweep every screen (TextFits on visible labels, overlapping siblings, elements escaping their parent, images not loaded, tap targets under 44 px) at phone, tablet and desktop sizes.
- Maps: 12+ player-height screenshots under the full lighting, plus 2 aerials. List defects.
- Code review: data saves and loads, rejoining doesn't duplicate anything, purchases are granted exactly once.
Write every defect with repro steps, fix what you can, and give me a step-by-step checklist for the things I need to playtest myself.
```

## Diagnose before fixing

The single most useful habit with any AI assistant:

``` text
Before you change anything, tell me what is wrong with [THIS IMAGE / THIS SCREEN / THIS BUILD] and why, as a numbered list. Don't fix it yet.
```

Previous: [[Prompts for building in Studio with an AI assistant]] · Next: [[Prompts for game music]]
