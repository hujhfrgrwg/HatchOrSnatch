---
tags: [research, roclicks]
source: https://roclicks.gg/resources/vfx/feedback-juice
retrieved: 2026-10-15
---
# Feedback juice

Every important action gets a sound, a particle burst and a float text, all at once, at the place where it happened.

## Contents

- [[#The rule]]
- [[#The moment table]]
- [[#One owner per moment]]
- [[#Finding missing feedback]]
- [[#Checklist]]

## The rule

Every important action gets **a sound, a particle burst and a float text**, all at once, at the place where it happened. A number silently changing in the HUD isn't feedback; kids watch the action, not the counter.

What happened without it: units finishing training just appeared in a count. Kids never noticed, opened the battle screen too early and lost. Training is the core loop, and it had no sound, no effect and no text, because the server fired `Trained` and **no client listened**.

## The moment table

Write this table for your game before wiring anything. The values below are a reasonable default.

| Moment               | Sound                                     | Burst                                        | Float text               | Extra                                                                   |
|----------------------|-------------------------------------------|----------------------------------------------|--------------------------|-------------------------------------------------------------------------|
| Collect              | `cash_collect`, rising pitch per coin     | `collect` (coins + sparkle)                  | `+$120` gold             | 3–6 coin icons fly from the building to the cash counter, counter bumps |
| Purchase             | `ui_purchase`                             | `sparkle`                                    | none                     | button squish                                                           |
| Build complete       | `build_complete`                          | `build` pop + dust                           | `Built!`                 | pop-in scale tween, tiny shake                                          |
| Upgrade              | `building_upgrade`                        | `levelup`                                    | `Level 3`                |                                                                         |
| Level-up / tier-up   | `ui_levelup` (supersedes `ui_reward`)     | `levelup` ×1.6 + `confetti` + shockwave ring | `Level N!` + `New look!` | stronger short shake, every piece pops                                  |
| Train complete       | `train_complete`                          | `levelup` ×0.8 at the trainer building       | `+5 Riflemen` green      | pulse the army button and count                                         |
| Victory              | `victory_fanfare` (UI group, ducks music) | fireworks + confetti                         | banner                   | one owner only                                                          |
| Reward / gems        | `ui_reward`                               | `sparkle`                                    | `+20`                    | skip if a reward fx played in the last 0.5 s                            |
| Error / can't afford | `ui_error`                                | none                                         | red `Need $50`           | button shake                                                            |

Put this in one helper, so call sites can't drift:

``` lua
Feedback.moment("trained", pos, "+5 Riflemen")
```

[snippets/Feedback.luau](https://roclicks.gg/resources/code/sound-vfx/snippets/Feedback.luau) picks exactly one sound, one burst and one float per kind.

Small touches that paid off:

- A run of the same sound **rises in pitch** (0.9 → 1.2): coins, land claims, combo hits.
- A rare, quiet chime when a building first fills up (cooldown ~20 s) pulls the player back to collect.
- Float text colour codes meaning: gold = money, green = units/healing, purple = gems, red = loss.

## One owner per moment

Most "juice" bugs were duplicates, not gaps:

- The victory fanfare played twice: once from the battle banner and once from the conquest handler a few seconds later, which also cut the first one off.
- A lost raid played the defeat sting from both the server toast and the battle view.
- A milestone toast played `ui_reward` while the caller played `ui_levelup` on the same frame.

Rules:

- Decide which system owns each moment's sound and write it next to the event ("UIBridge owns Trained; don't add a second listener").
- When a second system needs to react, give it a **different, smaller** cue (`conquest_flag` after the fanfare), or have it skip when the owner played within a few seconds.
- Let toasts carry the sound (`toast(text, {sound = "ui_levelup"})`) instead of the caller playing one beside it.
- Backstop with `supersedes` in the registry.

## Finding missing feedback

- **Unused registry names:** every sound, burst or template that is never referenced in code is a missing listener (`train_complete`) or dead weight.
- **Unlistened server events:** list every `FireClient` event name and grep the client for a listener.
- **Misspelt names:** `Sound.play("purchase")` with no `purchase` key. Make unknown names warn, and run a test that checks every literal name in the source against the registry and the template folder.
- Play the first 10 minutes with sound on and list every action that felt like nothing happened.

## Checklist

- Moment table written: sound + burst + float text for collect, purchase, build, upgrade, level-up, tier-up, train complete, victory, reward, error.
- All moments go through one `Feedback.moment` helper.
- Each moment has one owner; duplicates replaced by smaller cues.
- No registry sound or FX template is unused; no server event is unlistened.
- Every literal sound/FX name in source exists (tested).
- Repeats rise in pitch instead of stacking identical hits.

Previous: [[VFX particles, layering and colour]] · Next: [[FX controller, pooling and budgets]]
