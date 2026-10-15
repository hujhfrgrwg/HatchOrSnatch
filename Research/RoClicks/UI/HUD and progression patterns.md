---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ui/hud-and-progression-patterns
retrieved: 2026-10-15
---
# HUD and progression patterns

Patterns that made progression readable for kids without adding clutter. Feedback patterns (toasts, crates, celebrations, formatting) are in patterns-feedback.md.

Patterns that made progression readable for kids without adding clutter. Feedback patterns (toasts, crates, celebrations, formatting) are in [[Feedback patterns|patterns-feedback.md]].

## Contents

- [[#Next goal pill]]
- [[#Tier checklist]]
- [[#Upgrade preview]]
- [[#"Max for Tier N", not "Max level"]]
- [[#Tap-a-building bubble]]
- [[#Card bars]]
- [[#Badges]]
- [[#Progressive reveal]]
- [[#Screens that grow with the game]]

## Next goal pill

One pill under the top tabs that always says the single next thing to do, with progress, and does something when tapped. It replaced a rotating subtitle, a tip card and four counters.

- **Driven from config, not hand-written per state.** An ordered list of goal rules; the first rule whose condition is unmet wins. Each rule returns text, an optional `n / total` progress, and a tap action.
- **Walk the exact blocker.** For "reach the next tier" the pill steps through every requirement in order: "Clear Ring 2: conquer 2 more 5/7" -\> "Take X to clear Ring 2" -\> "Get 700 Iron for Tier 3 420/700" -\> "Save \$24,000 for Tier 3" -\> "Lab busy: finishes in 2:39" -\> green READY "Research Tier 3" -\> "Researching Tier 3 2:32" with a bar. A player asked "how do I get to tier 3?" before this existed.
- **Tapping goes to where the goal is solved**: the War screen for the weakest attackable target, the Research screen focused on the gate node, the Sell screen, or a toast naming the producer plus a pulse on that producer's build card.
- **Hide it while the tutorial runs** (the tutorial card is the goal then) and while a world bubble is open over it (glass panels let the pill show through).
- Compute it from the same server formulas and config the server uses, so the pill never disagrees with what the server allows.

See [snippets/NextGoal.luau](https://roclicks.gg/resources/code/ui/snippets/NextGoal.luau).

## Tier checklist

A small chip on the pill ("T3") opens a checklist under it:

- every requirement with a check or cross icon and its progress ("Iron 420 / 700"),
- the current blocker outlined in gold,
- an "Unlocks:" line naming what the tier gives (building level cap, new buildings, new units).

It stays live while open. On the research screen, tag the gate nodes ("TIER 2..5": green reached, gold next, grey later), halo the next gate, and order its Needs rows with the missing ones first, coloured by state. Pressing a gate while short toasts exactly what's missing ("Get 280 more Iron, save \$14,000 more").

## Upgrade preview

Every upgrade button shows the before and after of the stat it changes:

- "+0.9/s -\> +1.35/s Wood", "+16 -\> +21 army space", "+6% -\> +9% sell price", "Health 300 -\> 450".
- If the main stat doesn't change next level, show the first stat that does.
- **Compute it from the server's own formula module** (shared in ReplicatedStorage), never from card text. The bug that taught this: the preview called a formula function that didn't exist, fell back to the level-1 card text, and showed "+0.9/s" at every level, while the server was correctly paying 1.35. Players thought upgrades did nothing.
- Reopen or refresh the bubble when level, state or tier changes, so the numbers move after an upgrade.

## "Max for Tier N", not "Max level"

When an upgrade is capped by progression (tier N allows level 2, 4, 6...), the button must not say "Max level" at level 2. Kids read that as "this building is done" and stop.

- Button: **"Max for Tier N"**, sub-line "Reach Tier N+1 to upgrade".
- Tapping it says what's needed ("Research Regular Army and clear Ring 1").
- Only the real top level says "Max level".

Same principle everywhere: a locked thing says what unlocks it, never just "Locked".

## Tap-a-building bubble

Instead of a tool mode (equip a hammer, then click), tapping your own building opens a small bubble over it:

- one big context button: Upgrade / Repair / Rebuild / Finish, grey when unaffordable, with a cost line and a "starts in Xs" line if all builders are busy,
- small secondary buttons: Move / Rotate / Remove (Remove asks once, on the button itself, by turning into "Sure?") or Cancel / Skip / Clear depending on state,
- the upgrade preview line, and a one-line explanation of what the building does.

Rules: lines shrink to fit and never wrap; the bubble never rises over the top tab row; it hides the goal pill while open; panel actions clear the selection outline. One building tap = one bubble; tapping elsewhere closes it.

## Card bars

A bottom bar of build cards replaced a Buy tab plus a numbered hotbar:

- each card shows the item, its **live price** (from the same cost function the server uses), and turns to the grey plate when unaffordable; tapping a grey card says how much is missing and pops the cash,
- a "starts in Xs" chip when every builder is busy,
- worker slots on the bar's corner: a green dot per free worker, a countdown chip per busy one,
- tutorial pointers target the card, not a tab.

Cards are templates cloned once and updated in place (see [[Verifying UI|verifying-ui.md]]).

## Badges

- A badge means "you can act on this right now". Research badge only when a node can start and a slot is free. Shop badge only for an unclaimed free reward or a never-opened shop.
- One badge at a time, on the most useful button.
- A badge that never clears ("!" forever, "1" when nothing is available) trains players to ignore all badges. Delete static badges from the design data, not just at runtime, or a rebuild brings them back.

## Progressive reveal

The HUD starts nearly empty and grows as the player meets each system:

| Piece                    | Appears when                            | Then          |
|--------------------------|-----------------------------------------|---------------|
| Cash + Next goal         | always (goal hidden during tutorial)    | stays         |
| Premium currency         | first time the player owns any          | stays         |
| Research / tech button   | tutorial done                           | stays         |
| Conquest counters        | first conquest                          | stays         |
| Capacity counters        | only while full (red chip)              | hide again    |
| Event timer              | only while an event runs, with its name | hide again    |
| Paid toggles (auto-sell) | after purchase                          | stays         |
| Social reward buttons    | tutorial done                           | until claimed |

- Columns and stacks close up around hidden rows; never leave gaps.
- Keep reveal decisions in one function fed by state, so every screen agrees.
- Store "revealed" flags in the save, so a returning player isn't re-taught.

See [snippets/ProgressiveReveal.luau](https://roclicks.gg/resources/code/ui/snippets/ProgressiveReveal.luau).

## Screens that grow with the game

Mockups with a fixed number of rows silently drop data the game adds later. Seen three times:

- a sell screen with 6 rows when tier 5 had 8 resources: the newest two couldn't be sold one by one, and "Sell All \$X" summed only the visible rows, so it under-promised what the server paid;
- an army list sorted weakest-first and capped at the template's rows: the player's best units were invisible but still sent into battle.

Rules:

- Any list whose length depends on progress is a ScrollingFrame with pixel rows, or explicitly sized for the maximum.
- Totals are computed over the full data, never over the rows drawn.
- Sort the most valuable or newest first, so truncation (if any) hides the least important.

Previous: [[HTML-first UI pipeline]] · Next: [[Feedback patterns]]
