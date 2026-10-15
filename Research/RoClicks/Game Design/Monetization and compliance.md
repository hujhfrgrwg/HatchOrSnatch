---
tags: [research, roclicks]
source: https://roclicks.gg/resources/game-design/monetization-and-compliance
retrieved: 2026-10-15
---
# Monetization and compliance

Make money in a way that a parent would be fine watching. Most rules here exist because a specific bug charged a kid, surprised a kid, or broke a Roblox policy.

Make money in a way that a parent would be fine watching. Most rules here exist because a specific bug charged a kid, surprised a kid, or broke a Roblox policy.

Check Roblox's current Terms, Community Standards and monetization policies before you ship; they change. This page records what we learned, not legal advice.

## Contents

- [[#Never auto-open Robux prompts]]
- [[#Hide Robux surfaces early on]]
- [[#Prevent double purchases]]
- [[#Paid random items]]
- [[#Rewarding likes and other engagement]]
- [[#Grandfathering decisions]]
- [[#Starting currency]]
- [[#Receipts, briefly]]
- [[#Product list hygiene]]

## Never auto-open Robux prompts

A purchase prompt opens only when the player taps a button that clearly shows a Robux price. Never from code reacting to something else.

**Bug 1:** any failed spend (build, train, research) called the shortfall handler, which called `MarketplaceService:PromptProductPurchase` on the client. A kid clicking around got a Roblox purchase window every 15 s.

**Bug 2, partial affordability:** a "+5" train button first tried to spend the cost of the whole batch. That failed and fired the Robux prompt, *then* the code fell back to "train as many as you can afford". The kid got the units **and** a purchase window.

Rules:

- Check affordability before spending. Spend once, silently.
- Only show a shortfall offer when not even one unit is affordable, and then only as a toast or a chip ("Need more? R\$ 49") the player has to tap.
- No automatic offers on a loss. See [[Combat feel|combat-feel.md]].
- Every paid button shows its price. A dialog whose yes button said "Skip Battle" (no price) led straight into a Robux prompt.

## Hide Robux surfaces early on

One strategy game had 7 Robux surfaces in the first 10 minutes, 3 of them inside the tutorial (skip training, a paid nuke, a paid 5× speed). For an 8-year-old the screen looked like a store.

Make one helper and gate every surface on it:

``` lua
-- Shared: true while the player should see no Robux UI at all
local QUIET_SECONDS = 600
local function shopQuiet(state, now)
    return not state.tutorial.done
        or (now - (state.tutorial.doneAt or now)) < QUIET_SECONDS
end
```

While quiet, hide: paid battle buttons (nuke, win now, 5× speed), skip-timer buttons, the shop's "!" badge, HUD buttons for paid automation (or show them as grey "Shop" links), and any shortfall chips. The Shop itself stays reachable if the player opens it on purpose.

Also avoid permanent nag lines like "Tip: Auto Collect is available in the Shop" cycling every 10 s.

## Prevent double purchases

**Bug:** the client re-enabled the Buy button on `PromptProductPurchaseFinished`, which fires *before* `ProcessReceipt` has run. The receipt handler could take seconds (session lock, durable save). During that window the item wasn't owned yet, so a second tap opened a second prompt, and the kid paid twice (99 to 299 R\$) for a permanent upgrade.

Fix all three layers:

- **Client:** when `isPurchased` is true, set the card to "Delivering…" with a spinner and lock every Buy button until the server's "granted" event arrives (cap ~20 s to 2 min).
- **Server:** refuse to prompt a permanent product again while an intent for it is younger than ~60 s.
- **Server:** if a receipt arrives for an entitlement already owned, compensate (e.g. premium currency equal to the price) and tell the player. Never silently do nothing.
- Rate-limit the "buy" remote (1 per second per player) and don't do a durable DataStore write on every tap.
- Credits (a saved "free skip") are decremented *before* use and refunded on error, so two fast calls can't spend one credit twice.

Code: [snippets/purchase_guard.luau](https://roclicks.gg/resources/code/game-design/snippets/purchase_guard.luau).

## Paid random items

Anything random that can be bought with Robux, *or with a currency sold for Robux* (gem crates count), is a paid random item.

- **Check `PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted` on the server**, cached per player.
- **Refuse on the server** in every path that can start one: the crate open remote *and* the generic "use product" remote. One game hid the Crates tab on the client but `Shop.Use("CrateLegendary1")` still worked.
- **A failed lookup counts as restricted, and is retried** (every 60 s). Return `{restricted = true, failed = true}` so the client keeps asking too. A client that accepted the first "restricted" answer hid crates for the whole session.
- Hide the tab and any crate UI until the server says "not restricted". Fall back to another shop page.
- A Robux receipt that still arrives is honoured. Never take money and give nothing.
- **Show the odds** before purchase, generated from the same config the server rolls with. Odds baked into a pre-rendered image go stale the moment someone edits a weight.
- **Add pity:** "guaranteed Rare in N". Roll on the server; when `pity >= N`, force the pick. The client's countdown must match the server's counter.
- Never lose a reveal. Queue unseen results in the save and play them on join.
- Ask before a reward replaces something the player customised ("Use it now" / "Keep mine").

Code: [snippets/paid_random_policy.luau](https://roclicks.gg/resources/code/game-design/snippets/paid_random_policy.luau).

## Rewarding likes and other engagement

A "Like the game for 5 gems" button is common, but:

- Rewarding ratings, favourites or follows **may break Roblox's rules** on incentivising engagement. Check the current policy before shipping one, and get the developer's sign-off.
- There is no API to verify a like, so any version is honour-based (claim once, after a timer). If you keep it, auto-claim when the timer ends instead of making the kid find the button again.
- Group rewards can be verified (`Player:IsInGroup(groupId)`) and are a safer social reward. Keep the group id in config.

## Grandfathering decisions

When a free feature becomes paid (e.g. auto-collect moving from research to a game pass), existing players who had it need a decision, and it is **the developer's decision, not the agent's**:

- **Grandfather:** grant the entitlement to saves with the old unlock flag, and mark it so it isn't granted twice.
- **No grandfathering:** clear the old flag on load so the feature is actually off, and decide whether to refund what they spent.

Either way, make it complete and explicit. One project implemented grandfathering, then the developer decided against it; the grant and its marker were removed, the old flags cleared on load, and every script checked so only the paid entitlement enables the feature. Log the decision in the change log.

## Starting currency

The fresh-save balance should match the config. Test it with a real first join, not `defaults()`.

**Bug:** the config said 5 starting gems, but new players had 30. A join handler **auto-claimed the group reward** (+25 gems, +\$500) for group members, which in testing was everyone on the team. Also, a stale disk copy of the config said 25.

- Rewards are claimed by a tap, not on join.
- Measure the first-join balance in a playtest and compare with config.
- Count every free source of premium currency (start, tutorial, codes, group, milestones) in one table, and compare it with what speed-ups cost.

## Receipts, briefly

The full save/receipt pattern belongs in the data/server docs. The design-level rules:

- `ProcessReceipt` is idempotent per `PurchaseId`, stored in the same save key as the grant.
- Return `NotProcessedYet` when the player isn't in the server or the save failed; Roblox retries.
- A DataStore error must never switch the server into "memory only, no purchases". One "502: API Services…" blip did that to a whole server for good.
- Studio test purchases should grant (idempotently) so the flow can be tested.

## Product list hygiene

- Keep every product and pass id in **one config file**, with 0 or a placeholder for "not on sale yet". Write a list of exactly what the developer must create on the Creator Dashboard (name, type, price).
- Only show what can be used now. Battle-only products outside a battle should be grey ("Use in battle") or replaced.
- Sort owned items to the end.
- Fewer prices: 3 currency packs, not 4 packs + 2 skips + x1/x3 variants.
- A free alternative should exist for every paid convenience, even if slower. Paywalling collection itself made the free core loop a chore.

Previous: [[Combat feel]] · Next: [[Analytics]]
