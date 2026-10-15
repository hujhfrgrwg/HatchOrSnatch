---
tags: [research, roclicks]
source: https://roclicks.gg/resources/scripting/data-and-saves
retrieved: 2026-10-15
---
# Data and saves

Save bugs are invisible in Studio, because Studio playtests usually run memory-only. These are the rules that came out of a save-layer review of a live game; every one prevents silent progress loss.

Save bugs are invisible in Studio, because Studio playtests usually run memory-only. These are the rules that came out of a save-layer review of a live game; every one prevents silent progress loss. A generic module implementing them is in [tools/SessionStore.luau](https://roclicks.gg/resources/code/engineering/tools/SessionStore.luau), with a plain-Luau test in [tools/test_sessionstore.luau](https://roclicks.gg/resources/code/engineering/tools/test_sessionstore.luau).

- [[#Shape of a save]]
- [[#Session lock with UpdateAsync and a lease]]
- [[#Errors: transient is not fatal]]
- [[#A failed load never starts a fresh game]]
- [[#Autosave and backoff]]
- [[#BindToClose waits for in-flight saves]]
- [[#Studio memory-only mode]]
- [[#Resets and prestige]]
- [[#Developer product receipts]]
- [[#Testing with a mock DataStore]]
- [[#Checklist]]

## Shape of a save

- One key per player (`p_<UserId>`), one table, a `version` number, and a `migrate(old)` that fills missing fields from defaults. Bump the version for renames; never delete a field in place.
- Keep runtime-only fields (`session`, `lock`, timers in flight) out of the game state, and strip them in `serialise`.
- **Sanitise on save:** walk the copy and replace NaN/inf with 0, warning with the path. One NaN in `cash` makes every comparison false and soft-locks shops; some non-finite values make the write fail.
- **Validate client-sent tables by exact shape** (array length, integer ranges, string lengths) before storing them. `HttpService:JSONEncode` succeeding is not proof DataStore can store it.

## Session lock with UpdateAsync and a lease

Without a lock: a player leaves server A mid-save, rejoins on server B within seconds, B loads the old save, A writes the new one, then B's autosave overwrites it. The last battle, purchase or conquest is silently rolled back.

The lock lives **inside the same key** as the data, so it is atomic with it:

``` lua
-- load: an UpdateAsync that takes the lock
store:UpdateAsync(key, function(old)
    if old and old.lock and old.lock.id ~= SESSION and os.time() - old.lock.t < LEASE then
        state = "locked"; return nil          -- another live server owns it: wait and retry
    end
    if old then old.lock = { id = SESSION, t = os.time() } end
    return old
end)
```

- `SESSION` = a GUID per server (`game.JobId` is empty in Studio).
- **Lease** (e.g. 180 s): every save refreshes `lock.t`. A lock older than the lease belongs to a dead server and may be taken over.
- **Wait** up to ~30 s for another server's lock (that is its leave save finishing), retrying every few seconds while the client shows "Loading your save...", then steal it with a warning.
- **Every save** checks the lock first. If another server now owns it, refuse the write, mark the session `noSave`, and `Kick` with "Your progress was updated on another server. Please rejoin."
- **The leave save clears the lock**, so a rejoin loads at once.
- Do not write a lock-only table for a brand-new player. A table with only `lock` in it loads next time as "an existing save with nothing in it" and skips first-time setup.

## Errors: transient is not fatal

The ordinary Roblox outage error is `502: API Services rejected request with error. HTTP 500`. One game treated any error containing `"API"` as "DataStore access is off" and flipped the **whole server** to memory-only, forever. One 502 during a join wiped everyone's session.

- Only Studio's "API access is off" error means memory-only: `RunService:IsStudio()` **and** the message contains `403` (or `StudioAccessToApisNotAllowed`).
- Everything else is retried with backoff (e.g. 5 load attempts: 1, 2, 4, 8 s; 3 write attempts).
- Never cache "the store is broken" server-wide on a live server.

## A failed load never starts a fresh game

If load fails after all retries, a "fresh game, don't save" fallback looks to the player like "my game got wiped", and then un-wiped on the next join, with that session's play lost.

- **Kick with a friendly message** ("We couldn't load your save. Your progress is safe, please rejoin in a minute!") or show a retry card with a Rejoin button. Never drop into the tutorial.
- If you do run a `noSave` session for any reason, tell the client, and make sure every code path that rebuilds the state (prestige, debug reset) **carries `noSave` over**. One game's prestige copied a list of fields but not `noSave`, so a throwaway session started saving and overwrote the real save.

## Autosave and backoff

- Autosave every 60 s plus on big moments (conquest, tier-up, purchase), debounced to ~10 s.
- **Set the next-save time before the attempt**, not only on success. Otherwise a failing save is retried every loop tick (one game: every 5 s, 3 `UpdateAsync` calls each, ~36 writes a minute for one stuck player, which starves every other player's saves).
- Back off failed saves: 15 s, doubling to a 5 min cap. Reset on success.
- Serialise saves per player (`saving[player] = true`) and take the snapshot **after** acquiring that flag, so a waiting save never writes an older snapshot.

## BindToClose waits for in-flight saves

When the last player leaves, `PlayerRemoving` fires and starts its save, then the server starts closing. `Players:GetPlayers()` is already empty, so a naive `BindToClose` returns at once and **Roblox kills the server with the save still in flight.** Most sessions end exactly this way.

``` lua
local leaving = 0
Players.PlayerRemoving:Connect(function(player)
    leaving += 1
    pcall(runLeaveHooks, player)   -- finish battles etc. first, capped in time
    pcall(saveFinal, player)       -- clears the session lock
    leaving -= 1
end)
game:BindToClose(function()
    for _, p in Players:GetPlayers() do task.spawn(pcall, saveFinal, p) end
    local t0 = os.clock()
    while (leaving > 0 or next(saving)) and os.clock() - t0 < 28 do task.wait(0.1) end
end)
```

- The close budget is 30 s total. Cap any leave-time work that runs before the save (resolving a running battle, refunding queues) at a few seconds; one game spent up to 20 s there.

## Studio memory-only mode

- In Studio, read a workspace attribute (e.g. `UseDataStore`) and default to memory-only so playtests never write real saves. Print one clear line when that happens.
- Memory-only must still **behave like the real thing** (same lock, same receipt bookkeeping), or the real paths are never exercised. Test those with the mock harness instead.
- Because every playtest is memory-only, session-lock, outage and shutdown bugs **never show in Studio**. Review the save layer by reading it, and test it with a mock.

## Resets and prestige

A reset builds a fresh state from defaults and copies over what survives. Bugs here are permanent.

- Keep an explicit **carry list**, in one function used by every reset path: purchases/receipts, entitlements, `noSave`, settings, lifetime stats, account-level unlocks.
- A reset that drops `purchases` either revokes paid items or makes a "receipts must not shrink" guard block every later save.
- Account-level timers (daily rewards, redeemed codes) belong in the carry list too; one game's prestige silently re-armed every daily reward and code.
- Optional: write the pre-reset save to a one-slot backup key so an accidental tap can be undone.

## Developer product receipts

- **Exactly one `MarketplaceService.ProcessReceipt` per server.** A second assignment silently replaces the first and its products retry forever. One `Products` service owns it; others call `Products.register(productId, handler)`. Registering id 0 is a no-op, so unconfigured products stay inert.
- **Idempotent by `PurchaseId`.** Store every granted `PurchaseId` in the save (keep them all; Roblox can retry much later). If the id is already there, return `PurchaseGranted` without granting again.
- **Return `PurchaseGranted` only after the save with that receipt has landed.** Grant, record the id, save durably (an `UpdateAsync` that merges receipts), then return. If the save fails, roll back and return `NotProcessedYet`.
- **Player away:** if `Players:GetPlayerByUserId(info.PlayerId)` is nil (they left, or are on another server), return `NotProcessedYet`. Roblox retries the receipt when they next join a server, where the same handler grants it. Never grant into a save you do not hold the lock for.
- Wait (up to ~15 s) for the player's data to finish loading before handling a receipt that arrives during join.
- `PromptProductPurchaseFinished` is a UI hint only; it fires before the receipt is processed. Show "Pending" on the button, never grant from it.
- **Studio test purchases** go through `ProcessReceipt` like real ones. If memory-only mode refuses receipts because it "can't save durably", test purchases grant nothing; let memory-only grant directly (still idempotent by `PurchaseId`).
- Paid random items (crates, loot boxes): check `PolicyService:GetPolicyInfoForPlayerAsync(p) .ArePaidRandomItemsRestricted` and refuse on the server, not only in the UI. If the lookup fails, treat the player as restricted and retry later.

## Testing with a mock DataStore

Plain `luau` can run the save module if you inject the Roblox globals. The pattern ([tools/mock_datastore.luau](https://roclicks.gg/resources/code/engineering/tools/mock_datastore.luau)):

- a store whose `UpdateAsync` deep-copies in and out (real DataStores never share tables) and can be told to throw a queue of errors (`"502: API Services rejected request"`);
- a fake clock: `task.wait(n)` advances `os.clock()`/`os.time()` instantly and runs an `onWait` hook, so a 30 s lock wait takes no real time and "the other server releases the lock after 3 waits" is one line;
- fake players with a `Kick` that records the message.

Cases worth a test each: new player; lock held then released; lock never released (steal after the wait); transient 502 retried; persistent failure kicks with no state; another server takes over (save refused, `noSave`, kick); Studio 403 goes memory-only; receipt granted once for a repeated `PurchaseId`.

## Checklist

- Session lock in the same key, refreshed on save, cleared on leave, with a lease and a wait.
- Only Studio 403 means memory-only; live errors retry with backoff.
- A failed load kicks with a message; no silent fresh game.
- Next-save time set before the attempt; exponential backoff to 5 min.
- BindToClose waits for leave saves and running saves, under 28 s.
- One carry list for every reset; it includes purchases and `noSave`.
- One ProcessReceipt owner; idempotent by PurchaseId; grant only after the durable save.
- Save sanitises NaN and validates client tables.
- A mock-DataStore test covers lock, 502, failure, takeover, receipts.

Previous: [[Fix brief template]] · Next: [[Solo in a shared server games]]
