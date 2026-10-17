# HOS-EGG-002 Egg plan: delivery report (17 Oct 2026)

Spec: `docs/HOS-EGG-002/Egg Plan Build Spec.md` (approved by Hunter 08:49; section 10, early-end bonus rolls, added 09:17).
Built by the PC session in thread "Economy and name review", stages 0 to 7. Hunter saved the place at ~16:00Z; the
guaranteed-upgrade change below (~17:25-18:10Z) is **not saved yet**: Hunter saves.

## Fixes + full import (17 Oct ~18:25-19:30Z, Hunter "make the fixes and then implement fully"; PC session, not saved)
- **Mockups** (`ui/build.py`, review page "Fixes", artifact v8/v9): fill only, never percent ("27 / 36 FILL", ring marks
  HATCH at 18 and MAX at 36, "Odds at 27 fill"); a bigger Lucky strip (22 px, phone checked); the hatch boost ladder
  beside HATCH (x2 ODDS / UPGRADE TO x3 / UPGRADE TO x4 with the Robux price, x4 MAXED greyed) and an "xN BOOST" tag
  beside LUCKY; results "+N FILL" pill with the shard name small, mini egg "x / 18 FILL", then "x / 36 FILL" in gold.
  Stills: `ui/shots/egg_fix_*.png` (desktop 1920 + phone 844x390), review `img/fx_*.jpg`.
- **Imported** (roblox-ui-maker flow): EggIncubator rebuilt with every state, templates `FillLine_<rarity>` added. HUD and
  first-pet screens kept as they were. Fit x2, then `roblox/ui_egg/PostFit.luau` (EggUI copy of ui_hc's PostFit).
  6 new images uploaded to group 228184582 (gold Lucky strip, purple and grey boost plates, 3 odds-bar fills); robux and star icons reused.
- **New ModuleScripts** (one-line hooks in EggUIController; UIController untouched): `Controllers.EggIncubatorView`
  (fill, marks, odds note, Lucky tag/strip/prompt, boost ladder and prompt, hatch label) and `Controllers.EggResultsRow`
  ("+N FILL" in Results v2's EggBlock, the mini egg, the Results v2 fade contract, `whenSettled`).
- **Bug from Hunter's screenshot fixed:** the results mini egg's "0 / 18 FILL" sat on the card's bottom border (the ShardRow
  template put it under the ring). Now it sits above the ring, and the ring and label are clamped inside the card with
  10 px padding, measured on screen. The pill and the mini fade in with the egg box: they take Results v2's own
  `RVb<prop>` attributes and the box's current alpha. The crack-and-fly waits until results have settled.
- **Test harness bug fixed:** EggTests' ProfileIncubatorSpec reset `IncubatorLogic.setEcon(nil)` on the live module, which
  emptied the incubator view on any server where EggTests had run. It now restores EconomyConfig.
- **Boost / Lucky logic** (installed earlier): unchanged. EggService gained a test hook, `EggService._setLucky`.
- **Tests:** Lune 66/66 (after the no-roll specs replaced the roll specs, below). Studio EggTests on a fresh server: 79
  passed, 5 failed. The 5 are the old spread specs whose helpers were already removed from Studio's EggLogic (the
  no-roll change, paused below). Every boost tier, Lucky, cap and receipt test passed. LogicTests G04 and E03 fail as before (not ours).
- **Playtest (claimed and released, 19:10-19:25Z), read from the live client:** 12 / 36 FILL, "6 more fill to hatch",
  80 / 16 / 4. At 27 with x2: UPGRADE TO x3, x2 BOOST, 44 / 44 / 12, HATCH (BIGGER ODDS). At 36 with the Lucky pass forced and
  x3: MAX FILL, LUCKY +50%, x3 BOOST, UPGRADE TO x4, 0 / 80 / 20, matching `EggLogic.hatchOdds` on the server. x4: x4 MAXED.
  Ids at 0: the boost button and the Lucky strip are hidden. In a real bot match the results card read NO EGG THIS MATCH
  (a Catcher with no snatch). A Results with an Epic shard read EPIC EGG / +2 FILL / 17 / 18 FILL; the pill and the mini faded
  with the box (both 54% at 0.68 s), and the ring's bottom sat 8 px inside the card. No incubator label spilled its box.
  The hatch itself wasn't run: the sandbox-off server started a match, and hatches are lobby-only. Live stills are not
  available: Studio's capture and device simulator returned errors on the client, and screen access was declined.
- **Not done / blocked:** the PurchaseService one-line receipt route (PurchaseService looked released at ~19:05Z; it is a
  shared script, so it needs Hunter's OK); the line to add is in the boost section below.

## 17 Oct ~20:20-20:35Z: back shard + start-of-match intro built (Hunter "approved" 20:18; in Studio, not saved)
- `ReplicatedStorage.EggShardKit`: Shard (MeshPart, 1.45 studs tall) + SA_common/rare/epic/legendary.
- `Services.EggShardBack` (new), hooked with one line in EggService.init: `CharacterService.onEggBuilt(EggShardBack.dress)`.
  On every carried egg (players and bots) it welds the shard (CFrame(-0.06, -0.02, back) * 180 Y * -12 Z) in the egg's
  rarity with a PointLight (1.2, range 6, rarity colour), sets egg.PrimaryPart = shard (EggFX attaches there), and hides
  the egg's own parts after the other hooks (task.defer). It rebuilds on every setEgg (step = recolour) and leaves with the egg.
  No CharacterService or MatchService edit.
- `Controllers.EggShardIntro` (new), started with one line in EggUIController.init: on Phase ROLE_REVEAL (5 s), float 0-0.8 s,
  crack 0.8-1.4 s (VFX.EggBurst, "crack" sound), shard copies arc 1.4-2.4 s, each back shard revealed as its copy lands, ends at 3 s;
  one Cinematic shot (comfort clamps, letterbox, no dim, HUD kept), skipped if another cut-scene plays. Reduce effects: nothing
  plays. Switch: `EggConfig.SHARD_INTRO_ENABLED` (in EggConfig, not GameConfig: Hunter's OK covers EggConfig).
- HUD: EggShardMeter reskins the Runner looks ("YOUR SHARD", piece icons); EggUIController EGG_ICON = piece icons
  (Catcher stash, results slot), results "RARE SHARD".
- Playtest (claimed and released ~20:23-20:30Z): 20 back shards at ROLE_REVEAL, egg parts hidden; intro timeline as above
  (camera back at 3.5 s); setEgg rare/epic/legendary -> matching rarity and light; nil -> none; 3 Catchers without; HUD
  Runner looks YOUR SHARD with piece icons; phone compact 122 x 48 under the inset. No captures (client capture fails).
- UIController wording (Hunter's "ok" 20:31; backup UIController.pre-shardwording.rbxm): SAFE banner "Your shard grew to Rare!",
  feed "is safe with a Rare shard", "stole X's Rare shard" (3 string literals, no new locals; compiles).

## 17 Oct ~20:05-20:20Z: phone fixes; back shard centred (in Studio, not saved)
- HUD card on phones (Hunter: "this pill looks unnecessarily large on mobile"): `EggShardMeter.compact` makes the Glass plate
  hug the slot, word and meter (134 design px instead of 178, DropShadow follows) whenever EggUIController's applyCompact is on;
  `EggShardMeter.clearTopbar` keeps the plate below the Roblox top-bar inset. Two one-line hooks in EggUIController (refreshCard,
  hideOldCard). Live at 844 x 390 (iPhone 14 simulator): compact on, plate under the 58 px inset. An extra 0.82 shrink was tried
  and dropped (word 12 px, meter 5 px).
- Results line on phones (from Results v2): `EggResultsRow.unwrap` (no wrap/truncate, AutomaticSize X) on the fill line and the
  mini egg; on an EggBlock narrower than 320 px the "RARE / SHARD" pair becomes one bigger rarity word. Live: "+1 FILL", "RARE",
  "1 / 18 FILL" each on one line, the label inside the card (it used to wrap "FILL" onto a hidden line).
- Back shard preview re-shot (final after a direct-behind check, ~20:15Z: CFrame(-0.06, -0.02, ...); the -0.2 first try overshot): CFrame(-0.2, 0.05, Z/2 + depth/2 - 0.05) * 180 deg Y * -12 deg Z tilt, 1.45 studs tall; inside
  the torso outline (0.53 / 0.97 half-width, 0.84 / 0.85 half-height). Preview rigs removed from Workspace again.
- Phone stills on the review page (v13) are renders of the implemented layout: Studio's capture fails while the device simulator is on.

## 17 Oct ~19:50-20:05Z: PurchaseService receipt route; 3D back shard (model only)
- PurchaseService (Hunter's typed OK, 19:34): one line at the top of `processOther` routes hatch-boost products to
  `EggService.processReceipt`. Receipt test through `PurchaseService.processReceipt` with test ids: x2/x3/x4 granted as tiers 1/2/3,
  a retried PurchaseId changed nothing, a late x2 never lowered the tier, an unknown product falls through (NotProcessedYet);
  HatchBoostBought once per new purchase. Backup: `docs/backups/HOS-EGG-002_2026-10-17/PurchaseService.pre-eggroute.rbxm`.
- Back shard (Hunter: a physical 3D shard welded to the back): `tools/shard/shard.py` (numpy: curved faceted eggshell crescent,
  jagged broken edge, 512 tris, 4 painted 1024 atlases) + `tools/shard/shard_blender.py` (turntable render, FBX pre-turned 180 deg).
  Uploaded to group 228184582: mesh model 74627171410790 (MeshId rbxassetid://113762394289915; Size = MeshSize/100), image ids
  common 140569661410974, rare 116099154813254, epic 111135847758895, legendary 109098928858678. In Studio: `ServerStorage.HOS_ShardImport`
  (not wired). Preview: welded to UpperTorso at CFrame(0, 0.2, Z/2 + 0.38) * 180 deg Y, x1.26 of the mesh size, SurfaceAppearance,
  PointLight (rarity colour, 1.2, range 6), no Neon. Stills on the review page (v12). The back egg and the intro wait for Hunter's approval.

## Installed 17 Oct ~19:45Z: the in-match roll removed (Hunter's typed "Shared-scripts ok ... no-roll meter", 19:02; not saved)
- Studio now matches `docs/HOS-EGG-002/src` (checksums) for EggConfig, EggLogic, EggService and IncubatorLogic (comment), plus the
  client: EggUIController (meter via the new `Controllers.EggShardMeter`, tip, no flicker, banner "SHARD UPGRADED: EPIC" that waits
  for results to settle, results line "Upgraded by your meter") and EggFX (glow toward the first mark). The HUD card was rebuilt with the
  two-mark meter (Seg1 to EPIC, Seg2 to LEGENDARY, labels Mark1/Mark2), its tag reads "NEXT SAFE: EPIC/LEGENDARY", and the templates' banners use the new
  title. 3 new images uploaded (2 segment fills, 1 glow). Incubator and first-pet screens untouched.
- Tests: Lune 66/66. Studio EggTests 72/72 on a fresh server (LogicTests G04 and E03 fail as before, not ours).
- Playtest (claimed and released ~19:40Z): in a bot match a new player's 4 revives gave 3.0 (x1.5). The card filled Seg1 58/58 and
  Seg2 30/91 with marks EPIC and LEGENDARY. Safeties (driven through EggService.onSafe): Common -> Rare unmarked (the mark kept),
  Rare -> Epic marked (marks 1), at 5.0 Epic -> Legendary marked (marks 2), then nothing. ShardStep logged each with from/to/meter/marked;
  no EggRolled. Banners read "SHARD UPGRADED: EPIC" / "SHARD UPGRADED: LEGENDARY" inside their box. NEXT SAFE now names the step the
  next safe gives (none while the egg is Common).

### Earlier note (paused ~18:55Z)
- On disk (`docs/HOS-EGG-002/src`): EggConfig `CHARGE = { JUKE 0.25 (2 a crossing), REVIVE 0.5, HERO_SUCCESS 2.0, MARKS = {2.0,
  5.0}, CAP 5.0, NEWBIE_MULT 1.5, NEWBIE_HOURS 10 }`, `MARK_RARITY = {epic, legendary}`; EggLogic `safetyStep` (Common to Rare;
  a passed, unspent mark steps once per safety; the meter never empties), `marksPassed / nextMark / markReady`, the roll,
  bonus-roll and spread code removed; EggService steps with no RNG, no bonus rolls, attribute `EOS_EggMarks`, telemetry
  `ShardStep{from,to,meter,marked}` (replaces EggRolled), newbie fill x1.5. Specs rewritten (Lune 66/66).
- In Studio only the unused spread helpers left EggLogic (lines 472-512) before the permission check stopped the shared-script
  edit; the game still runs the old roll. Pending client wording: `docs/HOS-EGG-002/pending/` (banner "SHARD UPGRADED: EPIC",
  waits for results to settle). HUD two-mark meter mockup: not started.

## Change 17 Oct 17:19: a full meter guarantees an upgrade (Hunter "do it"; odds table still to confirm)
- The charge meter lasts the whole match (the juke count resets each crossing): juke +0.25 (2 count per crossing), revive
  +0.5, a Hero success fills it. `CHARGE.FULL = 2.0` (= `CAP`).
- At a safety on crossings 2 to 5 (or an early-end bonus roll) a **full** meter on a Rare or Epic egg gives exactly one
  step (Rare to Epic, Epic to Legendary) and empties. One guarantee a match (`GUARANTEE_PER_MATCH = 1`); after it the meter
  stays empty and hidden. On crossing 1 (Common to Rare anyway) a full meter is kept for crossing 2.
- Without a full meter: base chances only (Rare to Epic 3.6%, Rare to Legendary 0.36%, Epic to Legendary 2.4%; new players
  x1.5). Every `perCharge` is 0.
- Early-end bonus rolls: base chances; an unspent full meter is used once by the first of them.
- Incubator: weights 0.5 / 1 / 2 / 8; +1% Epic per Epic shard, +3% Legendary per Legendary shard. Fill 30, base odds and
  caps unchanged.
- UI (text only, no uploads): the meter shows the fill toward FULL, then "FULL: GUARANTEED UPGRADE"; the tip reads
  "Brave plays fill your meter. A full meter guarantees an upgrade at safety."; a guaranteed step's banner and the results
  card read "GUARANTEED UPGRADE"; the incubator's weights line reads "Rare 1 · Epic 2 · Legendary 8".
- Telemetry: `EggRolled` carries `guaranteed = true / false`.
- Seen live (playtest, 17 Oct ~17:50Z): the meter filled to 2.0 in crossing 1 (the third juke and the fourth revive added
  nothing), stayed full through crossing 1's Common to Rare, then crossing 2 stepped Rare to Epic with the banner
  "EPIC EGG! / GUARANTEED UPGRADE"; the meter emptied and hid (`EOS_EggMeterSpent`). EggRolled: c1 common->rare
  guaranteed=false, c2 rare->epic guaranteed=true. Stills on the review page.
- Fixed on the way: the results card's source line read the role, which is already LOBBY when results land, so it always
  said "Your best snatch". It now reads the stash (a Catcher's shard is their stash; a survivor never has one). Second
  pass (same claim): results read "EPIC EGG / GUARANTEED UPGRADE / +1 EPIC SHARD", and the incubator's weights line reads
  "Rare 1 · Epic 2 · Legendary 8".
- Installed (checksums): EggConfig 4364:1938764194, EggLogic 13927:1542123822, EggService 17997:1380062108, EggFX
  7572:1621353343, EggUIController 33584:1479167738, EggTests 7987:935888598. Only egg modules changed: no shared scripts,
  no hatch tables (EconomyConfig untouched). ScriptHistory updated for these.

## Change 17 Oct ~18:15-18:45: the hatch boost ladder (logic installed in Studio, not saved; receipt hook and UI pending)
- Hunter's choice (via the coordinator): Robux dev products on the incubator, for the current egg's hatch only: x2, then
  UPGRADE TO x3, then UPGRADE TO x4 (Epic and Legendary odds; Rare the rest). Legendary capped at 20% after every
  multiplier (overfill and the Lucky Egg pass included). `EggConfig.HATCH_BOOST = { products = { x2 = 0, x3 = 0, x4 = 0 },
  mults = { 2, 3, 4 }, legendaryCap = 0.20 }`: off while the ids are 0 (Hunter creates the 3 products; prices his).
- Logic: `EggLogic.hatchOdds` = overfill odds -> Lucky Egg pass -> boost tier -> cap (the hatch and the screen both use
  it); `incubator.boost` (tier) and `incubator.boostReceipts` (purchase-id ledger, 50) are saved, sanitized for old
  saves, and the boost resets after the hatch. `IncubatorLogic.grantBoost` (idempotent by PurchaseId, never lowers the
  tier). `EggService.processReceipt(info, plr)`: grants only inside `DataService.commit` (PurchaseGranted after the
  save, NotProcessedYet otherwise), returns nil for products that aren't ours. Telemetry: `HatchBoostBought{tier, mult,
  robux, purchaseId}`, `IncubatorHatched.boostTier`.
- **Pending: the receipt hook.** Roblox allows one ProcessReceipt; PurchaseService owns it and is claimed by the Lead
  Catcher thread. When the coordinator releases it, one line at the top of PurchaseService's `processOther(info, plr)`:
  `local egg = require(script.Parent.EggService).processReceipt(info, plr) if egg then return egg end`
  Until then (and while the ids are 0) no boost can be bought.
- Note for Hunter: with these numbers Rare reaches 0% (every hatch Epic or better, Legendary at the 20% cap) at 200%
  fill from x3 (x2 with the Lucky Egg pass), and at 100% fill with x4 + the pass. Full table in EggLogic.spec.
- Tests: Lune 78/78 (every tier at 100% and 200%, with and without the pass, the cap, the receipt ledger, the reset,
  boostTier in the hatch info). Studio EggTests not re-run after this install (the session's reporting tool went away;
  run `require(game.ServerStorage.EOSBuild.EggTests)()` on a fresh playtest server).
- Installed: EggConfig 5780:1566694233, EggLogic 19025:814815306, EggService 20884:556138465, EggUIController
  34335:2138280928 (the incubator shows `EggLogic.hatchOdds` with the pass and the boost), EggTests 8518:1439674800
  (specs 20051:340474934 / 12477:1115674957), IncubatorLogic 12545:1923895473 (small line edits). ScriptHistory updated.
- **Pending: the UI mockup** (ladder button "x2 ODDS" / "UPGRADE TO x3" / "UPGRADE TO x4" / maxed, and an "x2 BOOST" tag
  on the odds) in `egg_incubator_over` in ui/build.py, then the review page. Not started.

## Change 17 Oct ~18:04-18:30: overfill, the Lucky Egg pass, "+N FILL" on results (logic in Studio, not saved; UI mockups awaiting approval)
- **Overfill (coordinator's decision for Hunter):** the egg hatches at 18 fill (100%) and keeps filling to 36 (200%, a
  hard cap); fill past the cap waits in `carry` for the next egg. A hatch spends the whole egg and reads its odds from
  the fill at that moment, linear between 100% 80 / 16 / 4, 150% 72 / 22 / 6 and 200% 64 / 28 / 8 (Rare / Epic /
  Legendary). Shard rarity now only sets fill (0.5 / 1 / 2 / 8); the per-shard odds bonuses and their caps are gone.
  Focus is spent at hatch: 25% of an egg (4.5 fill), odds read from fill - 4.5, so a focused egg needs 22.5; a refunded
  focus puts the 4.5 into the next egg. The Legendary fold and the family step-down rules are unchanged.
  Config: `EggConfig.INCUBATOR = { FILL 18, MAX_MULT 2, FOCUS_COST 0.25, ODDS = 3 points }`.
- **Lucky Egg pass (Hunter approved "+50% odds"):** `EggConfig.LUCKY_PASS = { gamePassId = 0, epicMult = 1.5,
  legendaryMult = 1.5 }`. An owner's Epic and Legendary odds x1.5 after the overfill odds are read (Rare is the rest:
  70 / 24 / 6 at 100%, 58 / 33 / 9 at 150%, 46 / 42 / 12 at 200%). Off while the id is 0: Hunter creates the pass in
  Creator Hub and sends the id (no API). Ownership: EggService checks once on join and on
  PromptGamePassPurchaseFinished, cached, every call in a pcall; attribute `EOS_LuckyEgg` lets the incubator show the
  same odds the hatch rolls (`EggLogic.applyLuck` on both sides). Lives only in the egg modules (not PurchaseService).
- **Economy rule changed:** odds can be boosted by one Lucky Egg pass; rarity stays cosmetic; odds are always shown.
- Telemetry: `IncubatorHatched` adds `fillAtHatch` and `lucky`.
- Scripts: EggConfig 5202:1685380383, EggLogic 16658:1058158820, EggService 19458:1777067954, EggUIController
  34173:1340010696 (the shown odds apply the pass), EggTests 8518:1439674800, IncubatorLogic 12040:328214932. IncubatorLogic
  had the pets thread's HOS-PET-REDO changes (species lists): merged, and my changes applied there as small line edits.
- Tests: Lune 75/75; Studio EggTests 81/81 on a fresh server. Live (claimed playtest): a hatch at 27 fill logged
  `IncubatorHatched{fillAtHatch 27, fillUsed 27, lucky false}` and the egg went back to 0.
- **UI (mockups only, review page v7):**
  - Results: the shard line becomes a "+N FILL" pill in the shard's colour, with the shard icon and a small rarity word.
    It is data-driven from EggConfig and drawn inside Results v2's egg block without touching their layout. All four
    states, at 1920 and at phone size.
  - Incubator: a 0-200% ring with marks at 100 / 150 / 200%, odds that follow the fill, HATCH NOW / HATCH (BIGGER ODDS),
    and "-4.5 FILL" on the focus. States: filling, 100%, 150%, 200%, focused at 125%, and Lucky owned.
  - Lucky: a "LUCKY +50%" tag when owned, and a small "Get Lucky Egg" button otherwise.
  - Until Hunter approves, the live incubator keeps its current screen. It already shows the true odds (from the
    server's view, with the pass applied).
- Pages: `ui/build.py` HOS-EGG-002 section (`egg_fill_*`, `egg_over_*`, helpers `egg_rv_swap` / `egg_incubator_over`).

## Change 17 Oct ~17:45: faster pets (Hunter, via the coordinator)
- Incubator `FILL` 30 to 12, then **18** at ~17:50 (22.5 when focused, `FOCUS_MULT` 1.25 unchanged; the coordinator's
  middle option while Hunter picks 12 / 18 / 24). Base hatch odds 90 / 8.5 / 1.5 to **85 / 12 / 3**. Weights 0.5 / 1 / 2 / 8, +1% Epic / +3% Legendary per shard, the caps and the meter rules unchanged.
- The incubator screen reads the fill and odds from the server's view (`need`, `odds`), so its text follows the config;
  the weights line follows `SHARD_WEIGHT`. The hint "Locked families get pets soon" now hides when every focus family is
  open (it showed with nothing locked).
- Tests updated: Lune 71/71; Studio EggTests 77/77 on a fresh server (its live-data checks now follow the pet data:
  which focus chips are open and which family Any picks change as pets land). Seen live: the incubator reads
  "0 / 18 FILL", odds 85% / 12% / 3%, the hint hidden (every family is open now).
- Back egg seen live (same claimed playtest): Rare built as Shiny, and after the guaranteed step the Epic egg on the
  Runner's back is the purple Cosmic egg, matching the card.
- Not ours, seen while testing: LogicTests G04 (plan off) now expects the Mouse, which the pets thread removed from the
  hatch tables; and one playtest started a match although `EOS_Sandbox` was on in the edit place and on the server.

## Fix 17 Oct ~17:55: the carried egg's look (coordinator, from gu_banner_guaranteed.jpg)
- The Runner's back egg showed the gold mesh at Epic. Not lag and not the glow: `Shared.EggModel.kindFor` still mapped
  the old ladder's levels (1 Basic, 2 Shiny, 3 Cosmic, 4+ Golden), and the egg plan uses levels 1 / 3 / 5 / 7, so Rare
  wore Cosmic and Epic wore Golden. Three small line edits in EggModel (a shared script; Hunter's "Shared-scripts ok"):
  an `EggConfig` require, a new `EggModel.carriedKind` (Common Basic, Rare Shiny, Epic Cosmic, Legendary Golden, the
  egg card's icons, while `EggConfig.ENABLED`), and the wearable build uses it. Showcase and map eggs keep `kindFor`.
  EggModel 3760:1164982267 -> 4447:1990682262; backup `docs/backups/HOS-EGG-002_2026-10-17/ReplicatedStorage.EOS.Shared.EggModel.pre-backegg.lua`.

## What a player gets
- **In a match:** each Runner carries a visible egg and a charge meter that brave plays fill (see the change above). At
  safety the egg rolls once (crossing 1 always turns Common into Rare). An upgrade shows a banner, a burst and a sound; no
  upgrade shows the old SAFE!. A Catcher stashes the eggs they snatch (at most one rarity
  above the egg they had, the starting Catcher up to Epic) and keeps the best. A match that ends early gives bonus rolls for
  the crossings it didn't play, so short matches pay the same on average.
- **After the match:** one shard per player: the egg a survivor holds, or a Catcher's best snatch.
- **In the lobby:** one incubator egg fills from shards (weights 0.5 / 1 / 2 / 8). It can hatch at 18 (22.5 with a family
  focus) or keep filling to 36 for bigger odds (80 / 16 / 4 at 100% up to 64 / 28 / 8 at 200%); its odds are always shown. HATCH plays the existing
  ceremony. Focus never costs anything. A family's focus chip needs both a Rare and an Epic pet in that family. Legendary
  folds into Epic until a Legendary pet exists, and the odds row reads "PETS COMING SOON". The first egg won still gives a
  free first pet of the player's chosen family.
- **Removed while the plan is on:** the 1/3/5 ladder, per-rarity piece stacks and recipes, the Hero bonus roll, and the
  lobby goal pill (it counted pieces). The old pieces convert once into incubator fill (`incubatorV1`).

## Switch
`ReplicatedStorage.EOS.Shared.EggConfig.ENABLED`. With it off the game runs exactly as before: the old ladder and pieces,
LogicTests passing, and nothing is migrated. **It is ON in the edit place right now** (it was on for every playtest). If the
place is saved and published as it is, the egg plan goes live. Hunter decides before publishing.
The knife-test sandbox flag (`workspace.EOS_Sandbox`) is unchanged in the edit place. It was turned off only inside
playtest servers.

## Scripts
New:
- `ReplicatedStorage.EOS.Shared.EggConfig`, `EggLogic`: the numbers and the pure rules.
- `ServerScriptService.EOS.Core.IncubatorLogic`: the profile's incubator (migrate, settle, focus, hatch, client view).
- `ServerScriptService.EOS.Services.EggService`: charge, rolls, snatches, bonus rolls, shards, lobby remotes
  (`ReplicatedStorage.EOS_Egg`) and telemetry names.
- `StarterPlayer...Controllers.EggUIController` (33584:1479167738) and `EggFX`; `StarterGui.EggUI`,
  `ReplicatedStorage.EggUITemplates`, `ServerStorage.EggUIBuild`, `ReplicatedStorage.VFX.EggGlow / EggPulse / EggBurst`.
- `ServerStorage.EOSBuild.EggTests` (plus 2 specs).

One-line hooks in shared scripts (with Hunter's "Shared-scripts ok"):
- ProfileLogic: require, migrate, settlement, clientView.
- MatchService: line 703 onSafe; the settle call; results material/shard.
- PointsService: the award hook.
- EconomyService: init.
- UIController: one require at the end of `UIC.init`.

Pre-edit backups: `docs/backups/HOS-EGG-002_2026-10-17/`. Local sources: `docs/HOS-EGG-002/src/`. Every runtime change
to other screens is listed in `docs/HOS-EGG-002/ui_runtime_changes.md`.

## Art and sound
- 63 UI images uploaded to group 228184582, with Hunter's typed OK at 09:49. Ledger: `ui_egg/rbx/out/uploaded.json`; decal
  list: `Assets/asset_ids.json`.
- VFX use the AllVFX textures already uploaded.
- Sounds are the game's existing licensed Pro Sound Effects recordings (no new audio, nothing synthesised).

## Tests
- Lune (`docs/HOS-EGG-002/src/run_specs.luau`): 71/71 after the guaranteed-upgrade change (meter, guarantee, base
  odds, bonus rolls using the meter once, new weights and odds).
- Studio `EggTests`: 77/77 (run on a fresh playtest server), including the real ProfileLogic on V1, V2 and V3 profile
  shapes and the live EconomyConfig.
- LogicTests with the plan off: 55/56. The only failure is E03 (crossing count, from the round-cap work, not this ticket).
  Run it on a fresh server or fresh module clones: an edit session's require cache can hold a stale ProfileLogic.
- Playtests:
  - Stage 3: `docs/HOS-EGG-002/stage3_playtest.md` (plus the charge run).
  - Stage 5: live check on a phone screen.
  - Stage 6: `docs/HOS-EGG-002/stage6_playtest.md` (a full 5-crossing match to a focused hatch, telemetry checked, a
    focus-chip bug found and fixed).
- Review page with mockups, Studio QA and live clips: https://claude.ai/artifact/XBsS3EVF9S6qv3GTaDHufM

## Telemetry
EggCharged, EggRolled (with guaranteed, bonus, rolls, matchCrossings, endReason), EggSnatched, ShardGranted, FocusChanged and
IncubatorHatched (rarity, family, focused, fillUsed, duplicate) are registered in `Analytics.KNOWN`.

## For the Economy Decisions doc (not on this PC: coordinator to apply)
1. The egg plan replaces the 1/3/5 ladder, piece stacks, recipes, Common fusion and the Hero bonus roll (spec section 1).
2. Charge meter (changed 17 Oct 17:19): lasts the match; juke +0.25 (2 per crossing), revive +0.5, Hero success fills it;
   FULL 2.0. A full meter at a safety on crossings 2-5 guarantees one step (Rare to Epic, Epic to Legendary), once a match.
3. Roll at safety: crossing 1 Common to Rare; crossings 2-5 base chances only (3.6% / 0.36% / 2.4%); new players (under
   10 h of playtime) get them × 1.5.
4. Early end: bonus rolls = 4 − (crossings − 1), at the base chances; an unspent full meter is used once (section 10).
5. Snatch cap +1, the starting Catcher up to Epic, keep the best. A timed-out Runner gets no shard (Q2). A revive cancels a
   snatch (Q4).
6. Incubator (changed 17 Oct, last ~18:04): shard weights 0.5 / 1 / 2 / 8 (rarity only sets fill); hatch at 18, overfill
   to 36; odds from the fill at hatch: 100% 80 / 16 / 4, 150% 72 / 22 / 6, 200% 64 / 28 / 8; focus spends 4.5 at hatch.
6b. Lucky Egg pass (~18:10): Epic and Legendary odds x1.5 for owners. Rule: odds can be boosted by one Lucky Egg pass;
   rarity stays cosmetic; odds always shown.
7. Legendary folds into Epic until a Legendary pet exists, read from the pet data (Q1).
8. Focus rules: a family's focus chip needs both a Rare and an Epic pet.
   - A focused hatch uses the nearest lower rarity in the same family.
   - A family with no pets falls back to Any and refunds the +25% fill into the next egg.
   - Any steps down a rarity when no family has the rolled one.
9. Never sold: eggs, shards, fill, focus, hatches. (Odds: only through the one Lucky Egg pass, 6b.)

## Follow-ups
- A lobby goal pill showing the egg's fill (needs a mockup and Hunter's OK).
- Not ours, for the match-points thread: on phones the results role tag "ESCAPED" is cut to "ESCAP", and the header says "1 crossings".
- Checked 17 Oct ~18:05Z: with Legendary pets in the data, the Legendary odds row opened by itself (1.5%) and every focus
  family is open. The incubator's hint "Locked families get pets soon" still shows with nothing locked: hide it when
  every family is open (a small EggUIController change; not done, waiting for the hatch-table work to settle).
- Tuning from telemetry: charge sources and the roll terms are in EggConfig.

## Housekeeping left for Hunter
- **Save the place.**
- Done 17 Oct ~16:00Z (Hunter ran the delete; Claude's deletions are blocked on this PC): the 7 stale duplicate files
  under `ScriptHistory/ServerStorage/_Backup_LobbyMaps_20261015/`'s nested folders and the temporary `ui/_sh_local.txt`
  are gone. The 7 dotted-name copies are intact and match the place's checksums.
- The ScriptHistory snapshot (50 scripts changed or new, including other threads' pet and points work) is on disk, not
  committed (PC sessions don't use git).
