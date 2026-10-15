---
tags: [research, roclicks]
source: https://roclicks.gg/resources/game-design/tutorial-template
retrieved: 2026-10-15
---
# Tutorial template

Copy this page into your game's docs, fill in the table, and build it with snippets/tutorialsteps.luau. The reasons behind each rule are in onboarding.md.

Copy this page into your game's docs, fill in the table, and build it with [snippets/tutorial_steps.luau](https://roclicks.gg/resources/code/game-design/snippets/tutorial_steps.luau). The reasons behind each rule are in [[Onboarding|onboarding.md]].

## 1. The step table

Aim for 5 to 7 steps, all of them the core loop. Cut any step that teaches a system the player doesn't need in the first 5 minutes; make it a one-time tip instead.

| \#  | id      | Card text (≤ 8 words)                | Done when (server)            | Pointer (exact target)                                                                  | Fallback target                                | Reward         | Can go back to       |
|-----|---------|--------------------------------------|-------------------------------|-----------------------------------------------------------------------------------------|------------------------------------------------|----------------|----------------------|
| 1   | collect | Walk over your farm to collect       | any collect                   | 3D arrow + beam on the farm                                                             | any producer                                   | \$50           | none                 |
| 2   | sell    | Sell your wheat for cash             | any sell                      | Sell tab, then Sell All                                                                 | none                                           | \$100          | none                 |
| 3   | train   | Train 3 soldiers *(counter "6 / 8")* | army ≥ 8 (absolute)           | Army button, then the unit's +1 (found by name); the queue timer once enough are queued | none                                           | \$150          | none                 |
| 4   | attack  | Attack your neighbour!               | the tutorial fight starts     | gate ring + 3D arrow; Army → Go to War → Send                                           | Army button if the target is behind the camera | none           | train (army \< goal) |
| 5   | win     | Watch your army win!                 | the tutorial target is beaten | Watch button + arrow at the fight                                                       | none                                           | \$200 + 2 gems | attack / train       |
| 6   | upgrade | Upgrade your farm                    | any upgrade starts            | 3D arrow on the farm, then the Upgrade button in its panel                              | any building                                   | \$100 + 3 gems | none                 |
| end |         | "You are ready!" / Let's go!         | tap                           |                                                                                         |                                                |                |                      |

## 2. Per-step checklist

For every row:

- Text is one line, ≤ 8 words, no names the player hasn't seen.
- Done condition is checked on the server and counts actions done earlier.
- Goal is absolute (≥ N), not "N more than when the step started".
- Pointer is on the exact button, including inside panels.
- Pointer finds its target by name or attribute, not by list order.
- Pointer never covers the price or the label it points at.
- Wrong panel open → pointer on that panel's X.
- Target off screen → edge arrow. Target gone → fallback.
- If the step waits, the text says so and the pointer moves to the timer.
- No Robux button visible during this step.
- Reward pays once (`paid[id]`).
- Completion shows a check stamp, a "+\$N" line, particles and a sound.

## 3. Whole-tutorial checklist

- A loading screen from ReplicatedFirst before anything else.
- Intro only on the first-ever join, ~15 s, action only, one tap skips.
- The tutorial fight (if any) is unlosable, decided on the server, and tested on many seeds and army sizes.
- Tutorial locks (no retreat, fixed target) apply only to the tutorial's own fight.
- World events, raids, diplomacy and random popups are off until the tutorial ends, and the next one is pushed a few minutes out.
- The card hides under big banners and popups and returns after a 1 s gap; no stacking.
- Low-cash tip in the counter slot when cash is below the next cost.
- Rejoin resumes the step, and the next tick re-checks it (a stale "win" goes back to "attack").
- Old saves with a different step list are mapped to the nearest new step.
- Skip on the card, with a confirm; skipping shows the done card.
- A done card the player taps, then one-time tips (max one per 40 s, never over a panel).
- After the tutorial, the pointer keeps showing the next good target.
- Robux surfaces stay hidden until ~10 minutes after the tutorial ends.
- Every other file that checks a tutorial step number is listed (raids off while step \< X, etc.) and still correct after any change.
- Onboarding funnel steps for every sub-action ([[Analytics|analytics.md]]).

## 4. Test plan

Run each of these on a fresh save and write down the result:

| Test                                 | Expected                                                                        |
|--------------------------------------|---------------------------------------------------------------------------------|
| Real clicks, start to finish         | Each step advances by itself; total rewards match the table                     |
| Do step 2's action before step 1     | Step 2 completes about 1 s after it appears                                     |
| Reach the train goal before step 3   | Step 3 completes by itself                                                      |
| Lose or leave the tutorial fight     | Goes back to attack (or train, with the counter); the second reward is not paid |
| Rejoin mid-step, including mid-fight | Resumes on the right step                                                       |
| Open the wrong panel                 | Pointer moves to its X                                                          |
| Turn the camera away from the target | Edge arrow or panel button                                                      |
| Demolish the target building         | Fallback target                                                                 |
| Skip                                 | Confirm → done card → first tip                                                 |
| Cash at 0 on the train step          | Low-cash tip shows; no purchase prompt                                          |
| Battle-end sequence                  | Banner → popup → 1 s gap → check stamp → next card; nothing overlaps            |

Previous: [[Onboarding]] · Next: [[Progression and pacing]]
