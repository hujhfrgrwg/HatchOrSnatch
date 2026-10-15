---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ui/feedback-patterns
retrieved: 2026-10-15
---
# Feedback patterns

Toasts, celebrations, odds, crate openings, loading and number formatting.

Toasts, celebrations, odds, crate openings, loading and number formatting.

## Contents

- [[#Toasts]]
- [[#Celebration moments]]
- [[#Odds popups]]
- [[#Single-reel crate opening]]
- [[#Loading screen in ReplicatedFirst]]
- [[#One number formatter]]
- [[#Confirm dialogs]]

## Toasts

Two lifetimes:

| Kind  | Duration                                      | Use                                                                           |
|-------|-----------------------------------------------|-------------------------------------------------------------------------------|
| Short | 3-4 s (+1 s per extra line for young players) | "Not enough wood", "+\$120", "Training 5 units"                               |
| Long  | 6 s or until dismissed                        | text over ~50 characters, raid warnings, outcomes ("Raid repelled: +\$22.8K") |

Rules, each from a bug:

- **Dedupe.** Four identical "Must be on your land" toasts stacked on screen. Now an identical toast already showing restarts its timer and pulses instead of stacking. Re-tween its countdown strip too, or it shows empty while the toast stays up.
- **Merge bursts.** Big events (reinforcement waves) fire many messages; merge into one toast per window (e.g. at most one every 20 s, with the running total).
- **Cap the stack** (about 4); the oldest drops.
- **Short text, one verb**, about 40 characters. Long technical toasts get squeezed and unreadable.
- **Say what happened.** "Kills 0" became "The defenders gave up". A defeat sound on a repelled raid that damaged one house taught players they lost.
- **Place them away from action and close buttons**: under the tutorial card, never in the middle of a battle view, and nudged below an open panel's X.
- **Don't spoil reveals.** Skip the generic "granted" toast when a crate reel is about to show the prize.
- Word wrap: when no space exists in the first N characters, cut at N without dropping a character.
- Every icon name used by a toast exists in the icon map; a missing one falls back silently.
- Sounds chosen by the server must reach the client (a toast's sound field was dropped in transit).

See [snippets/Toasts.luau](https://roclicks.gg/resources/code/ui/snippets/Toasts.luau).

## Celebration moments

Big moments get a full-screen card, not a toast: tier up, prestige, first win, legendary drop.

- Card: big outlined title ("TIER 3 UNLOCKED!"), at most two lines of what's new (capped, so it never becomes a wall), confetti and particles, a fanfare, tap or ~9 s to close.
- **Queue celebrations; never overlap them.** Two at once (tutorial step reward + tier up) covered each other.
- Pair it with the world: particles on the thing that changed, number pops at the source.
- Don't celebrate what didn't happen: a tier-up toast that said "units upgrade" when they only upgrade after buildings level up was a broken promise.

## Odds popups

Any paid random item shows its odds before purchase, in the game's own style, per crate:

- one row per rarity with its percentage and icon, a split bar showing the proportions,
- the pity rule in words ("Epic or better guaranteed within 15 opens") and the player's current counter,
- generated from the **same config table the server rolls from**, never typed into the UI. Verify each popup row against the config after every change.
- Check `PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted` and hide or replace paid random items for players where they are restricted.

## Single-reel crate opening

The pattern that felt best: **one** horizontal reel, not three spinning columns.

1.  **Server rolls first.** The client asks to open; the server checks price, rolls with the real weights, applies pity, grants through the normal grant paths, and replies with the prize. The reel is a replay of a decided result.
2.  **Client builds a reel plan** around the known prize: a strip of tiles drawn from the odds table for flavour, the prize at a fixed landing index, and a **cosmetic near-miss**: the tile just past the prize is one rarity better (a Legendary next to an Epic prize; an Epic next to a Legendary). The reel eases past slightly, creeps toward the near-miss, then settles back onto the prize.
3.  Timing: crate shakes ~1.25 s, bursts (flash, ring, sprites), first spin ~5 s, later spins of a x3 open ~3.6 s. Markers above and below the landing slot; nothing drawn over the prize.
4.  Tap skips to the landing (never skips the grant; the grant already happened).
5.  Reward card: rarity header, rays, glow; the top rarity adds flash, shake and a "NEW" tag.

Why server-first: a client roll can be spoofed, and a reel that decides the prize at the end can disagree with what was granted. The near-miss changes nothing about odds; it only lives in the strip.

Other lessons: preload reel templates at init (tiles rendered blank when a CanvasGroup drew before art loaded); blur the world with a BlurEffect on the camera, not Lighting (Lighting effects are global and other systems fight over them); unconfigured product ids (0) show "coming soon", never a broken prompt.

See [snippets/CrateRoll.luau](https://roclicks.gg/resources/code/ui/snippets/CrateRoll.luau).

## Loading screen in ReplicatedFirst

A LocalScript in `ReplicatedFirst` runs before anything else replicates:

- call `ReplicatedFirst:RemoveDefaultLoadingScreen()` and show your own screen built from the approved title card art,
- drive the progress bar from a stage attribute the main client script sets as it boots (`LoadStage = 0..1`), not from a fake timer,
- fade out when the client sets `ClientReady`,
- if an intro cutscene will play (first join only), fade onto the intro's own first frame so there's no flash between the two,
- add a **safety timeout** (about 60-75 s) so a client error can never trap a player behind the screen.

See [snippets/LoadingScreen.client.luau](https://roclicks.gg/resources/code/ui/snippets/LoadingScreen.client.luau).

## One number formatter

The bug: the HUD had its own formatter and the panels used another. The HUD one formatted values \>= 100 with `%.0f` and then stripped trailing zeros with `gsub("0+$", "")`, a step meant only for decimals:

- 250,000 -\> "250" -\> "25" -\> **"25K"**,
- 100,000 -\> "1K", 300,000 -\> "3K",
- 999,600 rounded to "1000" -\> "1K".

Short style was the default, so every player with 100K-999K saw cash 10-100x too small, on the number kids look at most, while the shop showed the right value.

Rules:

- **Exactly one formatter module**, used by HUD, panels, toasts, billboards and float text.
- Strip zeros **only when the string contains a decimal point**.
- When rounding reaches 1000, bump to the next suffix ("1.00M", not "1000K").
- Truncate, don't round up, for currency the player is about to spend (\$9.99K, not \$10K, when they have 9,995), or "you can afford it" lies.
- Currency prefix ("\$1.36K"), no "1.00K".
- A unit test with the regression values: 0, 999, 1000, 1234, 99999, 100000, 250000, 999600, 1000000, -2500.

See [snippets/NumberFormat.luau](https://roclicks.gg/resources/code/ui/snippets/NumberFormat.luau).

## Confirm dialogs

- One shared dialog: dim scrim, card, message (up to 3 lines), red action + blue Cancel.
- The text states the real consequence with real numbers, computed with the same rule the server uses ("Remove it? You get \$273 back").
- Escape / gamepad B must run the same close path as the Cancel button (one popup's Escape skipped its server "collect" call).
- A failed open must never leave an invisible full-screen blocker behind.

Previous: [[HUD and progression patterns]] · Next: [[Measured GUI and input facts]]
