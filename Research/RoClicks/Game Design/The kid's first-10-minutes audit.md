---
tags: [research, roclicks]
source: https://roclicks.gg/resources/game-design/first-10-minutes-audit
retrieved: 2026-10-15
---
# The kid's first-10-minutes audit

A repeatable way to see the game the way a new 8-to-12-year-old sees it. You can do it by playing a fresh save or by reading the code path (an AI agent can do the code version without a playtest).

A repeatable way to see the game the way a new 8-to-12-year-old sees it. You can do it by playing a fresh save or by reading the code path (an AI agent can do the code version without a playtest).

## Contents

- [[#Method]]
- [[#The table]]
- [[#What to count]]
- [[#Red flags]]
- [[#Worked example]]

## Method

1.  Start from a **brand-new save**. In Studio, make sure saves go to memory, not the live DataStore.
2.  Walk the path from "Join" to minute 10, one row per moment: loading, intro, each tutorial step, the celebration, the first free-play decision, the first loss.
3.  For each row write down the code location, the wait, the clicks and decisions, and every number and menu on screen.
4.  Screenshot the **first frame of the HUD** and count its elements.
5.  List every **Robux surface** the player can see or hit.
6.  Total it up and rank the friction.
7.  Then look one step past the tutorial: what is the first decision the player makes alone, and does it lead to a likely loss?

## The table

| \#  | Moment                 | Code | Wait | Clicks / decisions | Numbers & menus on screen | Robux surfaces |
|-----|------------------------|------|------|--------------------|---------------------------|----------------|
| 1   | Join, before any UI    |      |      |                    |                           |                |
| 2   | Intro                  |      |      |                    |                           |                |
| 3   | Tutorial step 1        |      |      |                    |                           |                |
| …   |                        |      |      |                    |                           |                |
| n   | First free-play choice |      |      |                    |                           |                |
| n+1 | First loss             |      |      |                    |                           |                |

Totals:

- seconds of forced waiting (loading, intro, timers, battles, banners);
- clicks to the first win;
- full menus opened before minute 4;
- numbers on the first HUD frame;
- Robux surfaces visible before minute 10.

## What to count

| Count                      | Healthy target                      | Why                                                                     |
|----------------------------|-------------------------------------|-------------------------------------------------------------------------|
| Decisions                  | 1 per step                          | Each extra choice is a place to stall.                                  |
| Numbers on screen          | Under ~5 on the first HUD           | One game showed ~20 numbers and 26+ HUD elements on frame one.          |
| Full menus before minute 4 | 1 or 2                              | Sell, Army, War and a building panel in 4 minutes was too many.         |
| Forced waits               | Under ~15 s before the first action | 60 s of intro on top of 40 s of blank loading lost players.             |
| Robux prompts              | **0** that open by themselves       | See [[Monetization and compliance|monetization]]. |
| Robux buttons              | 0 during the tutorial               | One tutorial had 3 paid buttons inside it.                              |
| Modal time after a win     | Under ~5 s, tap to dismiss          | VICTORY + conquest popup + stamp was ~11 s.                             |

## Red flags

- Blank or default screen before your UI appears.
- An intro that can't be skipped with one tap.
- The whole HUD appears at once. Reveal elements as they become useful: progress counter at the first conquest, research at its tip, event timer with the first event, social rewards after 15 minutes.
- A dense screen in the tutorial (a sell screen with ~25 numbers: drifting prices, trend arrows, x10%/xAll, sliders).
- A "verdict" screen shown as a spreadsheet (power 64 vs 26, walls 36 sections, towers 2, win chance, a legend). A kid needs "Will I win? Go."
- Manual chores forever (walk to every building, open Sell, press Sell All) unless they pay.
- The first free-play target is much stronger than the tutorial target and nothing says so.
- The first loss opens a purchase dialog.
- A tutorial lock (retreat, auto-target) still active after the tutorial's own fight.
- Random events or attacks firing during the tutorial.

## Worked example

From a strategy tycoon's audit (before fixes):

- Up to 40 s of blank loading, then a 61.5 s intro with hold-to-skip.
- 6 tutorial steps, ~14 clicks, ~55 s of forced waiting.
- 4 full menus before minute 4; 26+ HUD elements and ~20 numbers on frame one.
- 7 Robux surfaces in the first 10 minutes, including automatic purchase prompts on any failed spend and a "New Campaign?"-titled dialog after the first loss that hid its Robux price.
- The tutorial's Retreat lock outlived the tutorial, so the first free-play war (a neighbour 1.5 to 5× stronger) ended in a wipeout, then the purchase dialog.

The cheapest high-impact fixes were: gate all monetization until ~10 minutes after the tutorial, scope tutorial locks to the tutorial's own fight, turn the first loss into a "Train N more" button, and keep the arrow on a beatable target.

Previous: [[Design checklist]] · Next: [[Onboarding]]
