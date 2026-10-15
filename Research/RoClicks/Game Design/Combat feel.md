---
tags: [research, roclicks]
source: https://roclicks.gg/resources/game-design/combat-feel
retrieved: 2026-10-15
---
# Combat feel

For any game with simulated fights (armies, mobs, tower defence, vehicles). Most of this came from measuring real battles in a harness, not from guessing.

For any game with simulated fights (armies, mobs, tower defence, vehicles). Most of this came from measuring real battles in a harness, not from guessing.

## Contents

- [[#Endings must not drag]]
- [[#Vehicles get their own slot]]
- [[#Natural infantry]]
- [[#Easy / Close / Hard, not power numbers]]
- [[#Losing feels OK]]
- [[#Measure with a harness]]

## Endings must not drag

Collaborator feedback: "battles need to be like 1.5x faster … slow down way too much at end". The cause was a tail, not the fight: one or two stragglers nobody could reach. A burning enemy vehicle "retreated behind its lines" to the far edge of the base, and the whole army hunted it for 2 to 3 minutes while towers wore them down.

Fixes, all in the sim:

- **Mop-up mode.** When the enemy is down to `max(3, 20%)`, every squad stops holding position and hunts the enemy nearest to *itself*, at a run. Don't let all squads chase one shared target.
- **Don't let units flee out of reach.** A damaged defender pulls back only to just inside its wall.
- **Surrender once the outcome is certain.** At ≤10% of the defence's peak (at least 2 units) and outnumbered 4:1 for 15 s, the holdouts give up. At time-out, ≤5% left also counts as surrender, not a loss.
- **A clock that speeds up as one side collapses.** Pace ×1 normally, then ×1.3 / ×1.6 / ×2 at 35 / 60 / 85% of either side down, ×1.25 during the march. Multiply it on top of the player's own 1×/2×/5× speed. Code: [snippets/battle_pace.luau](https://roclicks.gg/resources/code/game-design/snippets/battle_pace.luau).
- **Overtime, once.** If the clock is nearly out, reinforcements are still coming and the defence is down to half, add one 90 s overtime and update the timer.
- **Huge armies come in waves**, formed up behind the front, instead of columns hundreds of studs long that time out before arriving.

Measured result (real seconds, 6 seeds each): rifle fights 44 → 27 s, mixed armies 178 → 41 s (wins 1/6 → 6/6), mass-APC army 208 → 81 s. Typical fights got 1.3 to 1.6× faster and stuck ones 2.5 to 4×.

## Vehicles get their own slot

Feedback: "sometimes the vehicles cram up in one place" (23 APCs in one blob). Cause: the march used at most 5 lanes, every vehicle in a lane got the same goal point, and hunting vehicles all drove to the same cell next to the shared target.

- Give each vehicle its **own slot**: spread across ~80% of the front's width with a golden-ratio sequence, in 3 depth rows.
- Each vehicle hunts its **own nearest target**, never past a closed wall, and parks on its own spot on a ring around it.
- Stronger separation: 9 studs at 0.3 push (was 8 / 0.12).
- Wrecks block infantry only; tanks shove past them.

Result: overlapping vehicle pairs (\< 5 studs) went from 7.7 to 14.8 on average to 0.0 to 0.1.

``` lua
-- Slot i of n across a front of width W (golden-ratio spread, 3 rows)
local PHI = 0.6180339887
local function vehicleSlot(i, n, frontCenter, right, back, W)
    local x = ((i * PHI) % 1 - 0.5) * W * 0.8
    local row = (i - 1) % 3
    return frontCenter + right * x + back * (row * 12)
end
```

## Natural infantry

Players read soldiers as smart or dumb from a few cues. Aim for:

- **Squads** with a leader and spacing; column on roads, line or wedge in the open.
- **Behaviour states:** advance, take cover (walls, buildings, craters, rocks), suppress, flank, retreat or rout when morale breaks.
- **Role behaviour:** anti-tank troops prefer armour, snipers prefer officers and MGs, medics heal, engineers repair and breach.
- **Line of sight by raycast**, hit chance by range and cover, visible tracers.
- **No idle squads.** "Nothing in my sector" must fall back to hunting the nearest enemy. A bug where the fallback never fired let 10+ infantry lose to 2 defenders.
- **Sieges keep moving.** After breaching wall 1, squads stopped 38 studs short of wall 2 and a 240-unit "Easy 2.5×" army lost on the clock. Once a wall is open and the lead is through, start on the next wall.
- **Cover where fights happen.** Scatter rocks and craters on battlefields (one game used ~7% density, at least 3 per zone) rather than everywhere.
- Performance: run lightweight agent state on the server at 10 to 20 Hz with a spatial hash; render and interpolate rigs on the client, swap to lite rigs at distance. Don't run hundreds of physics Humanoids.

## Easy / Close / Hard, not power numbers

A kid can't use "64 vs 26, walls 36 sections, towers 2, ~98%". Show a coloured verdict: green **Easy**, yellow **Close**, red **Hard**, and the loot. Put the same verdict on map labels, the attack screen and any one-tap Attack button.

- **Calibrate bands from real fights.** One game used Easy ≥ 1.3×, Close 0.9 to 1.3×, Hard \< 0.9× (attacker power / expected defence). Measured over 102 real battles, Close fights were won 8 of 10.
- **Expected defence ≠ listed power.** Include what actually fights: garrison caps, manned walls and towers, boss modifiers (capitals got ×1.5 after two "Close 66%" armies lost). An unmanned wall counted as 0.25 of a manned one.
- **Re-check after any combat change.** A rule change made the easy tutorial fight read "Hard ~2%", and it really was unwinnable.
- **Check per army type.** All-vehicle armies underperformed their rating against hidden anti-tank nests; mass infantry timed out. Label accuracy by army type is part of the test.
- One colour source for all surfaces. A map label that read an unset field was always yellow.
- When the fight is Hard, say what to do: "You need about 390 power for an easy win: train more units first", or at a cap, "build or upgrade Barracks to grow it".

## Losing feels OK

- **Explain and give one next step:** "Your army was too small! Train **4 more** Riflemen", with a "Train 4" button that queues them. Compute N from the expected defence.
- **"So close!"** when the enemy was nearly beaten.
- **Never open a purchase dialog on a loss**, at least for the first few losses. Offer a paid skip only from the second loss against the same target, with the price on the button.
- **Never mislabel it.** A loss dialog reused a "New Campaign?" template. A kid reads that as "my game is being reset".
- Warn before a Hard fight: "You'll probably lose. Pick an easier one?" with a button that retargets to the weakest beatable enemy.
- Let the player retreat (hold to retreat), except in the unlosable tutorial fight.
- Losing a fight never loses permanent purchases or progress beyond the units sent.

## Measure with a harness

- Run the real deploy + sim code headless (plain Luau with a small Roblox shim) on many seeds.
- Include line of sight and the real obstacles. An older harness without LOS never showed the slow tail.
- Report per scenario: win rate, real seconds, losses, worst pile-up. Keep the numbers in the change log as before → after.

Previous: [[Progression and pacing]] · Next: [[Monetization and compliance]]
