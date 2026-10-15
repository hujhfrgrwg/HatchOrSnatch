---
tags: [research, roclicks]
source: https://roclicks.gg/resources/game-design/onboarding
retrieved: 2026-10-15
---
# Onboarding

How to get a new player (often 8 to 12 years old) from "joined" to "I get it, this is fun" with no confusion, no dead ends and no store in their face.

How to get a new player (often 8 to 12 years old) from "joined" to "I get it, this is fun" with no confusion, no dead ends and no store in their face.

## Contents

- [[#Tutorial shape]]
- [[#Pointers]]
- [[#Advancing and rewards]]
- [[#Never soft-lock]]
- [[#The first fight is unlosable]]
- [[#Waiting steps]]
- [[#Low-cash tip]]
- [[#Keep the world quiet during the tutorial]]
- [[#Intro cutscene and loading screen]]
- [[#After the tutorial]]

Use [[Tutorial template|tutorial-template.md]] to build one and [[The kid's first-10-minutes audit|first-10-minutes-audit.md]] to check it.

## Tutorial shape

- **About 6 steps, all of them the core loop.** One strategy tycoon started with 10 steps. Five of them taught systems a new player didn't need yet: placing buildings twice, a "civilians" stat, a construction timer, ruins and research. The rewrite kept collect → sell → train → attack → win → upgrade. Teach the rest later with one-time tips.
- **Learn by doing.** Every step is an action the player performs, never a paragraph to read. "Walk over your farm to collect", not "Farms produce wheat over time, which you can collect by…".
- **At most 8 words per card, one line, no hint text.** Long cards (9 to 14 words, two lines) got skipped. Set the text large; in one game it went from TextSize 41 to 50. The only small line allowed is a live counter ("Riflemen 6 / 8").
- **Don't use names the player hasn't seen.** "Supply Farm" means nothing on step 1. "your farm" does.
- **Don't let the card shrink over time.** A "compact after 60 s" rule made the card text smaller than the HUD subtitle from step 3 onward.
- **Calm the world.** In an RPG, testers said "monsters keep attacking and I can't focus". Pacify regular mobs while the tutorial runs.

## Pointers

One pointer, on the exact thing to press. Text, hint and pointer must all agree.

- A bouncing arrow plus a thick pulsing ring on the exact button. A 2 px ring was missed by everyone.
- Pointers **inside open panels** too (Sell All, +1, Send Army, Upgrade). The first version had no arrow inside panels, so players stalled exactly there.
- Find target buttons by name or attribute, not by list position. A unit list re-sorted itself and the arrow pointed at the wrong unit card.
- Don't cover the thing you point at. A ring over a button hid its price ("\$45 + 3 wheat"). Put the ring on the button's own edge.
- In the 3D world: an arrow over the building or gate, plus a beam from the character.
- Target off screen: put the arrow on the screen edge, pointing the way.
- The wrong panel is open: point at that panel's **X** so the player can get back.
- The target was destroyed (the player demolished the farm): fall back to any building of the same kind instead of pointing at nothing.

## Advancing and rewards

- **Auto-advance the moment the action happens.** No "Next" button, no "OK".
- **Make "done" loud.** A sparkle in the 3D world at the camera focus is usually off screen. Use a big check stamp on the card, a "+\$100" reward line, 2D particles and a reward sound.
- **Reward every step.** Small cash and premium-currency gifts. One game paid \$50 / \$100 / \$150 / \$200 + 2 gems / \$100 + 3 gems: \$600 and 5 gems total, about what the old tutorial gave, so the economy pacing barely moved.
- **Pay each reward once.** Store a `paid[stepId]` flag. If a step can be redone (lose the war, retrain), the second completion must not pay again.
- **Don't stack modals.** The VICTORY banner drew over the next card, then a conquest popup drew over both. Hide the card while big banners or popups are up, then show the next step after a 1 s gap.

## Never soft-lock

Write these as server rules, not client hopes.

- **Count actions done early.** Record every relevant action (`did.collect`, `did.sell`, …) whatever the current step. A step whose action already happened completes itself about 1 s after it appears.
- **Use absolute goals, not deltas.** "Train 3 more" measured from `max(5, current army)` meant anyone who trained early had to train 3 *more* again. Use "army ≥ 8" with a counter.
- **Steps can go backwards.** Lost the war, or left mid-battle? "Win" goes back to "Attack". Army below the goal? Back to "Train", with the counter showing what's missing.
- **Guarantee affordability.** If the upgrade step starts and cash is short, grant the difference.
- **Resume on rejoin.** Save the step. On load, re-send it and run the same checks, so a stale "win" step becomes "attack" again.
- **Migrate old step numbers** when you change the step list. Map each old step to its nearest new one ("ruins" → "upgrade", "lumber" → "train").
- **Offer a skip.** Keep it on the card, behind a confirm. Skipping still shows the done card and starts the post-tutorial tips.
- **Scope tutorial locks to the tutorial's own target.** One game locked Retreat for *every* battle until the tutorial's last step. A kid who skipped the last card attacked a much stronger neighbour, couldn't retreat and lost the whole army. Lock only when `battle.enemyId == tutorial.targetId`.

## The first fight is unlosable

If the tutorial includes a fight, losing it is the worst possible first impression. A collaborator asked: "you can lose the first battle? make it 100% win rate".

- **Decide it on the server, before the armies are picked.** Flag the battle as the tutorial war and send the whole army (one War screen let the player go out with 2 of 8 units).
- **Protect the player's side**: take reduced damage and never drop below a health floor, so there are no deaths, downs or routs. One game used 40% damage and a 20% health floor.
- **Weaken the defenders**: damage ×0.5, health ×0.6, walls ×0.5, and the defence gives up on the clock (90 s).
- **Keep the target easy over time.** The starter enemy must not grow, must not be annexed by bot wars, and must not get units on its walls. A regression made the tutorial war read "Hard Fight ~2%" because a new "minimum 3 defenders" rule put one man in an unreachable tower.
- **Test it as a matrix, not once.** Several army sizes × every starter garrison × many seeds. Target: 20/20 wins, 0 losses, 17 to 35 s.
- Hide the paid "skip/nuke/win now" buttons in this fight (see [[Monetization and compliance|monetization]]).

## Waiting steps

Avoid steps that wait on a timer. When one is unavoidable (units training, a battle running):

- Change the card text: "Wait for your Riflemen to train".
- **Move the pointer to the timer** (the queue bar), so the player can see it moving. Pointing at "+1" while three units train invites a fourth tap.
- Count queued items toward the goal, so "Train 3" doesn't keep saying "Train 3" while 3 are in the queue.
- Keep paid "skip" buttons hidden next to that timer.
- Never point at the wrong thing. A "wait for construction" step pointed at a building that had already finished.

## Low-cash tip

New players run out of cash mid-tutorial (they spent it or sold nothing). When cash drops below the next step's cost and the card has no other line, show the fix in the counter slot: "Low on cash? Walk over your farm, then Sell!". Log it once per session as an analytics event, so you can see how often it happens.

Never answer low cash with a Robux prompt.

## Keep the world quiet during the tutorial

Turn off anything random until the tutorial is done, then wait a few more minutes:

- world events (one had a 9% chance of starting a defensive battle mid-tutorial);
- raids and enemy attacks;
- diplomacy offers and other popups;
- "tip of the day" subtitles that sit above the card.

When the tutorial ends, push the next random event out (`next = max(next, now + 180)`).

## Intro cutscene and loading screen

- **Show something from frame one.** A ReplicatedFirst LocalScript calls `ReplicatedFirst:RemoveDefaultLoadingScreen()` and shows your own title card with a progress bar. Without it, one game showed a raw half-built world and a \$0 HUD for 10 to 40 s while the server baked meshes. Kids leave during that.
- **Intro only on the first-ever join.** Store `introSeen` in the server save and set it when the intro *starts*, not only when it ends (a player who leaves mid-intro shouldn't see it again). Any load of an existing save sets it. The client may set it to true, never back to false.
- **About 15 s, action only.** A 61.5 s intro with a 27 s base-building act was cut to 15 s: march, barrage, close-up kill, air strike, a slow-motion explosion, flag swap, end card. Cut every establishing shot and builder montage.
- **One tap skips.** A 0.9 s hold-to-skip confused kids. Accept E, Esc, gamepad, click and touch. Log `skippedBy` so you can find accidental skips (one test skipped at 2.3 s from a window-focus click).
- **Hand off cleanly.** The loading screen fades into the intro's title card on a first join; the tutorial card starts only after the film returns.
- Load heavy stage props behind the title card, not mid-film.

## After the tutorial

- **One-time tips** instead of more steps: shown once each, at most one per 40 s, never over a panel or battle, saved per player. Each points at its target and goes away on the action or after 8 s.
- **Keep a pointer on the next good target.** After the done card, the arrow vanished and kids picked their next fight blind. Keep pointing at the weakest target the player beats comfortably; if none, point at "train more".
- **A done card** ("You are ready to rule!" / "Let's go!") that the player taps, not a 5 s toast.

Previous: [[The kid's first-10-minutes audit]] · Next: [[Tutorial template]]
