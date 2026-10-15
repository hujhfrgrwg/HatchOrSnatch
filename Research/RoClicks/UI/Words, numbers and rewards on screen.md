---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ui/copy-numbers-rewards
retrieved: 2026-10-15
---
# Words, numbers and rewards on screen

Error copy that helps, one number formatter, and the reward rules players notice.

## Copy

- **Error text names the exact blocker and the fix:** "Need 3 wheat", not "Not enough resources".
- **Never show raw ids, "?", "nil" or empty interpolations** ("Season begins!"). Guard every string that interpolates data.
- **Pluralise and pick a/an in one helper.** "Fishermans", "a Egg" and "Sword (Gold)s" all shipped from inline string building.
- **Toasts are about 40 characters with one verb.** Longer ones get more time on screen. Tutorial lines stay at six words or fewer.

## Numbers

- **One formatter for HUD and panels.** Two formatters will disagree on screen.
- **Watch the suffix bug:** stripping trailing zeros from whole numbers turns 250K into "25K" and 100K into "1K". Strip only after the decimal point.
- **Currency prefix first:** "\$1.36K", not "1.36K\$".
- **Count-up tweens:** one per key, cancel the previous one, and always land on the exact target.

## Data truth

- **One denominator everywhere.** "Conquer 7 more" in one place and "0/8" in another breaks trust.
- **Compute tags per item, never type them in.** Every crate saying "SAVE 10%" while real savings were 10, 16 and 13% is a lie the player can check.
- **Show net values.** Income net of upkeep, not gross.
- **Overwrite every mock value on a screen's first draw.** Search the mockup for its sample strings; leftover demo numbers ship surprisingly often.

## Rewards

- **Hide zero rewards** entirely: no "+0 gems".
- **Never auto-claim.** A silent join reward is never seen and quietly breaks the starting balance. Claims go through a visible button.
- **Unaffordable:** a grey plate. Tapping it says how much is missing and pulses the currency counter.
- **Dedupe identical toasts:** restart the timer and pulse instead of stacking copies. Cap the stack at about four.
- **Don't spoil a reveal** with a generic "purchase granted" toast before the reveal plays.

Previous: [[Checklists]]
