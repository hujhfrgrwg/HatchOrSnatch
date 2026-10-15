---
tags: [research, roclicks]
source: https://roclicks.gg/resources/workflow/build-order
retrieved: 2026-10-15
---
# The order to build a Roblox game in

Eleven phases from studying a game to live ops, what each one produces, and why the numbers come before the map.

Most wasted work comes from doing a phase before the one it depends on. This order holds up across idle games, simulators, combat games and remakes.

| \#  | Phase                  | What it produces                                                  |
|-----|------------------------|-------------------------------------------------------------------|
| 0   | **Study**              | A one-line pitch and a breakdown of the reference game            |
| 1   | **Design and economy** | The core loop, progression, monetisation, and a pacing simulation |
| 2   | **World**              | The map, blocked out first and agreed before detail               |
| 3   | **Models**             | Meshes only for what parts can't do                               |
| 4   | **Systems**            | Data, remotes, the loop, products                                 |
| 5   | **UI**                 | Every screen in HTML first, then real ScreenGuis                  |
| 6   | **VFX**                | Particle effects for every key moment                             |
| 7   | **Audio**              | Music cues and sound effects with SoundGroups                     |
| 8   | **QA**                 | A fixed defect list, screenshots, measured loop timings           |
| 9   | **Launch**             | Thumbnails, icon, products, published place, analytics            |
| 10  | **Live ops**           | The funnel read daily, the next update planned                    |

## Study a game from footage

Before remaking or competing with a game, pin down what it is **measured**, not remembered. Play it for 10 to 15 minutes and record it, then pull frames and write down:

- the core loop in one sentence, and its steps;
- the time to each milestone (first upgrade, first zone, first rebirth);
- prices and yields per tier, to fit a curve (say it's fitted, not recovered);
- the UI flow: which screens, in what order, what the HUD always shows;
- where monetisation appears: when the first offer shows and what it sells.

Then write what you'll keep, cut and improve. Never ship another studio's art; recreate it.

## Simulate the numbers before building the world

A pacing script (a few dozen lines in Python or Luau) tells you the minute each milestone lands for a new player. Fixing the economy in a script takes minutes; fixing it after the map, UI and products are built takes days.

## Decide one style for everything

Pick the style once per game and hold it for maps, props and every GUI. A stud-style world with a sleek UI reads as two different games.

## Ask before anything public or irreversible

Publishing, uploads, products and prices are public, and some can't be undone. Treat them as a separate decision from the work itself, every time.

Previous: [[The 12 lessons that mattered most]] · Next: [[Launch and the first week]]
