# HOS-LEAD-001 Paid Lead Catcher: hooks (not applied yet)

None of these are applied yet. They wait for Hunter's shared-scripts OK. Each hook is one added line, and no existing line changes. Before adding each line, re-read the live script (the Hero or Chicken thread also edits MatchService), find the anchor by its code text, not by line number, and back up first. The line numbers below are from the 17 Oct snapshots, for orientation only. Backups of those snapshots are in `docs\backups\HOS-LEAD-001_20261017\`. Every added line ends with `-- HOS-LEAD-001`. To undo, delete that line.

The new module is `docs\HOS-LEAD-001\LeadCatcherService.lua`, which goes into the place as `ServerScriptService.EOS.Services.LeadCatcherService`. It does nothing until hook 4 starts it. Studio's auto-mode permission check stopped me from adding it to the place, so it is still only a file.

## 1. MatchService: the buyer replaces one normal starting Catcher pick
- Where: `runMatch`, right after the `if N.ENABLED and not solo ... else ... end` block that sets `catcherIds` (snapshot l.842-869).
- Anchor: the line `	local isCatcher = {}` (unique, snapshot l.870).
- Add this line **before** the anchor:
  ```lua
  	catcherIds = require(script.Parent.LeadCatcherService).assign(catcherIds, roster, solo, matchId) -- HOS-LEAD-001 paid Lead Catcher replaces one pick (same count)
  ```
- What it does:
  - The slot holder must be in `roster`, hold a credit, and this must not be a solo test. If so, they move to the front of `catcherIds`.
  - If they were not already picked, they replace an NPC Catcher (or else the last pick). The number of starting Catchers never changes. With 1 Catcher, the buyer is the only one.
  - One credit is spent, guarded by a `lead:<matchId>` use ledger. Buying closes.
  - If there is no holder, it returns `catcherIds` unchanged.

## 2. MatchService: the buyer starts as the sticky Hero or Chicken lead
- Anchor: the line `	current = c` (unique, snapshot l.903). It comes after the roster loop's `addParticipant` and before `ROLE_REVEAL`, so it runs well before `CrossingLineup.freeze` at the first crossing.
- Add this line **after** the anchor:
  ```lua
  	require(script.Parent.LeadCatcherService).matchStarted(c) -- HOS-LEAD-001 c.hcLead = the buyer
  ```
- What it does: sets `c.hcLead = buyer` only while the buyer is a live, non-disconnected CATCHER. HeroChickenService.leadCatcher (l.104-122) already keeps `c.hcLead` while that holds and falls back to its normal pick otherwise, so **HeroChickenService needs no edit**.

## 3. PurchaseService: the receipt grants +1 credit (one ProcessReceipt owner, unchanged)
- Where: `processReceipt`, after the "not loaded: NotProcessedYet" check.
- Anchor: the line `	local pack = packByProduct[info.ProductId]` (unique, snapshot l.104).
- Add this line **before** the anchor:
  ```lua
  	if require(script.Parent.LeadCatcherService).owns(info.ProductId) then return require(script.Parent.LeadCatcherService).processReceipt(info, plr) end -- HOS-LEAD-001
  ```
- What it does:
  - Adds +1 `leadCatcherCredits`, exact-once by PurchaseId in the shared `p.receipts` ledger. The commit label is `"receipt:"..PurchaseId`.
  - Roblox only hears PurchaseGranted after the save. It is never refused for slot reasons: a late receipt becomes a pass for a later match.
  - `owns()` is false while `PRODUCT_ID` is nil, so this line does nothing until the product exists.

## 4. Bootstrap: start the service
- Anchor: the line `PurchaseService.init() -- Robux Gem packs: ProcessReceipt grants once, after the save` (snapshot l.43).
- Add this line **after** the anchor:
  ```lua
  require(Services.LeadCatcherService).init() -- HOS-LEAD-001 one paid Lead Catcher per match
  ```
- Net.setup (which creates EOS_Remotes) and DataService.init have already run by this point. init creates `EOS_Remotes.RequestLeadCatcher` (RemoteFunction) and listens to `PromptProductPurchaseFinished`, PlayerRemoving, DataService.Loaded and `EOS_State.Phase`.

## 5. UI (after Hunter approves the look; HOS-LEAD-001 mockups)
The waiting-round button reads these:
- `ReplicatedStorage` attributes:
  - `LeadCatcherState`: `free` / `reserved` / `taken` / `closed` / `off`
  - `LeadCatcherOwner`, `LeadCatcherOwnerName`, `LeadCatcherPrice`, `LeadCatcherUntil`
- The player attribute `EOS_LeadCredits`.

It calls `EOS_Remotes.RequestLeadCatcher:InvokeServer()`. The **server** opens the Robux prompt. The client never calls PromptProductPurchase for this product.

Which state each player sees:

| Slot state | Who | What they see |
|---|---|---|
| free | everyone | (a) BE LEAD CATCHER, 29 Robux |
| reserved | the holder | (b) Waiting for purchase... |
| reserved / taken | everyone else | (c) LEAD CATCHER TAKEN, greyed, with the holder's name |
| taken | the holder | (d) You're Lead Catcher next match |
| closed / off | everyone | hidden |

## Still to do before going live (not in this ticket)
- Price: 29 Robux (Hunter, 17 Oct). Create the developer product on Hunter's PC with `python tools\upload\create_lead_product.py`. It prints the productId and never the key, and it's safe to re-run. Then set the id in `LeadCatcherService.PRODUCT_ID` and log it in `docs\VFX-LEDGER.md`.
- After wiring: a Studio test purchase with two players, plus a ScriptHistory snapshot.

## Design notes
- Buying is open only in WAITING / INTERMISSION / RESULTS. Hook 1 closes it at role assignment. As a safety net, the service also closes it on ROLE_REVEAL by itself.
- A reservation lasts 30 s. If the prompt reports "purchased", there is another 30 s grace while the receipt arrives. A cancelled prompt, a timeout or leaving the server releases it.
- A credit holder takes a free slot automatically. With several holders, the earliest credit wins (`leadCatcherCreditAt`). The others keep their passes. A player who leaves before roles are assigned keeps their credit.
- The profile fields (`leadCatcherCredits`, `leadCatcherCreditAt`, `leadCatcherUses`) are kept by ProfileLogic.migrate, which keeps unknown fields, so no ProfileLogic edit is needed.
- In the NPC fill path, a buyer who replaces an NPC Catcher leaves that NPC as one extra Runner. This is harmless.
