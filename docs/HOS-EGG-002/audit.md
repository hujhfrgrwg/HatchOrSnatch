# HOS-EGG-002 Stage 0 audit (read-only)

17 Oct 2026, PC session. Place: **Hatch or Snatch** (`instance:75m-1no`, place 128015050187408). Faceoff was also connected and was not touched.
Backups of 22 scripts (live sources at audit time): `docs\backups\HOS-EGG-002_2026-10-17\`.
Line numbers are from the live place at the time of the audit. Re-read before each edit.

## How the live egg flow works today (differs from the spec's 02:00 snapshot)

- **The egg is a TierConfig level, not a tier 1-4.** HOS-PTS-001 added `ServerScriptService.EOS.Services.EggLadder` (not in the spec). It maps rarity to look levels: `PointsConfig.Ladder.LEVEL = { common = 1, rare = 3, epic = 5, legendary = 7 }`. Legendary already exists as level 7 with its own look (`TierConfig.Groups`), so **"add Legendary as tier 4" is not needed.** EggService will use the same levels.
- The current ladder rolls only on crossings 1, 3 and 5, with a boost on 2 and 4 (`PointsConfig.Ladder.STEPS/BOOST`). EggService replaces it when `EggConfig.ENABLED` is on.
- **Catcher cap**: `TierConfig.CATCHER_TIER_CAP = 3` is a flat level cap (level 3 = **Rare**) for every Catcher. There is **no +1 snatch-back rule in the live code**. The spec says it "stays" and that the starting Catcher's cap is Epic. This is new behaviour, built in EggService and plugged into `MatchLogic:capture`.
- **The caught Runner banks their egg today** (`MatchLogic:capture` l.396: `earnedRunnerTier = max(earned, stolen)`, so `securedTier` keeps it). Under the spec, the end shard for a caught Runner is only their best snatched egg. EggService computes the shard itself (see below) and does not use `securedTier`.
- **Hero bonus today** = extra crossings of Gold/XP (`heroBonusCrossings`) **plus** one bonus piece roll (`HeroChickenConfig.BONUS_ROLL`, granted via `s.bonusMaterials`). The spec removes the piece roll only. The HeroChicken client never shows the piece, so gating the settlement line is enough.
- **The false "Your egg grew" banner is already fixed live** (UIController l.3107-3113 compares rarities, HOS-PTS-001). The pending match-points edit may be something else, so I'll check with that thread before touching the HUD egg card.
- **Only two families can hatch**: `EconomyConfig.LAUNCH_FAMILIES = { "Decoy", "Invisibility" }`, and `FAMILIES` has species only for common/rare/epic. **No family has a Legendary species**, and Guardian/Tempest/Rift have no hatch table. (The Crystal Warden, Riot Hound, Thunder Toad, Bastion Beetle and Ring Imp exist only in `EXTRA_SPECIES`.)
- **One species per family and rarity** (`EconomyConfig.speciesFor`). "A species the player doesn't own" is therefore always that one species, and a duplicate raises the existing `pet.level` (1..3, ProfileLogic.hatch l.461-471). That is the live form of "mutation level".
- **There is no playtime stat.** `EOS_IsNew` = `stats.matchesCompleted == 0` (DataService l.398). The "first 10 h" newbie boost needs a new stat.
- **jest-lua is not installed in the place** (`Packages` is empty). Lune is installed on the PC. Logic tests: see Stage 1 below.
- `Net` (the remote list) is not on the shared-scripts OK list. EggService makes its own remotes folder `ReplicatedStorage.EOS_Egg` (the same pattern PointsService uses for `EOS_Points`), so Net needs no change.
- **EconomyConfig is claimed right now** by the Grin Ghost thread (edit-claims). The Legendary colour/name will go in `EggConfig.RARITY_INFO`, so **EggConfig needs no EconomyConfig edit**.

## Hook points (spec section 3)

| # | Script (live path) | Line(s) | What's there now | Change (behind `EggConfig.ENABLED`) |
|---|---|---|---|---|
| H1 | `ServerScriptService.EOS.Services.MatchService` | 700-707 (call at **703**) | `finishCrossing` ok, then `info = require(script.Parent.EggLadder).onCrossed(c, uid, info)`, then `applyRole` and `RunnerEvolved` | Line 703 becomes: `EggService.onSafe(c, uid, info)` when enabled, else EggLadder. It returns the same `info` shape (prevTier/newTier as levels, plus rarity/upgraded/charge), so applyRole, RunnerEvolved and the client keep working. **Round flow owned by the Hero or Chicken thread: I'll tell it about l.703.** |
| H2 | same | 1073-1077 | `hero = HeroChickenService.bonusFor` → `s.bonusMaterials = hero.pieces` | Skip `bonusMaterials` when enabled (the Hero bonus roll is removed; extra Gold/XP crossings stay). One line. |
| H3 | same | 1068 / 1078 | `s = logic:settlementFor(uid)` … `DataService.settle(plr, s)` | One line before settle: `s.shard = EggService.shardFor(c, uid)` (and `s.material = nil` when enabled). |
| H4 | same | 1094-1111 | `out.you = { … material = mine.material … }` | Add `shard = EggService.shardOf(c, uid)` to `you` (one line). |
| H5 | same | 1230-1234 | partial settlement for leavers | No change: leavers get no egg and no shard (as now). |
| H6 | `ServerScriptService.EOS.Core.MatchLogic` | 398 (capture) | `credited = min(clamp(stolen), CATCHER_TIER_CAP)` | `credited = if self.snatchCap then self.snatchCap(h, stolen) else <old>`. EggService sets `c.logic.snatchCap` at match start: cap = one rarity above the egg the Catcher held when caught (`earnedRunnerTier`); the initial Catcher's cap is Epic. |
| H7 | same | 345-356 (finishCrossing +1 level) | old +1; already rewritten by EggLadder/EggService after the call | No edit: H1 rewrites `currentCarriedTier` just as EggLadder does now. |
| H8 | same | 682 (`materialForTier`), 750-806 (settlementFor) | piece from securedTier | No edit: H3 sets the shard in MatchService; `material` is dropped there. |
| H9 | `TierConfig` | 17 | `CATCHER_TIER_CAP = 3` | **No edit needed**: Legendary is level 7 already; the cap is bypassed by H6. |
| H10 | `ServerScriptService.EOS.Services.PointsService` | 72-113 (`award`) | juke/revive/hero/safe points; no signals | One line at the top of the scoring path: `EggService.onAward(c, actor, kind)` (juke → +0.25, max 2 per crossing; revive → +0.5). Only runs when points are on: jukes are detected only by PointsService (`PointsConfig.Enabled`). |
| H11 | same | 297-306 (`ladderPieces`), 312 | rewrites `r.material` from rarity | Leave it: H3 nils `material` when enabled. |
| H12 | Hero success | `HeroChickenService.watchHero` l.430-440 (marks success a tick *after* safety) | | **No edit.** At the roll, `EggService.onSafe` checks `c.hc.heroId == uid and c.hc.phase == "HERO_RUN"` and sets charge to 1.0 before rolling, so the order is right. |
| H13 | `ReviveService` | 101-103 | a revived Runner gets the egg they carried back; the Catcher keeps the credit | No edit (charge +0.5 goes through H10). Question Q4. |
| H14 | `ServerScriptService.EOS.Core.ProfileLogic` | 28-75 default, 91-205 migrate, 263-360 applySettlement (pieces 302-318), 391-480 hatchPlan/hatch, 740-773 clientView | pieces → recipe hatch | Add `incubator` to default; `incubatorV1` migration block after l.169; in applySettlement, `s.shard` → `EggLogic.addShard` (pieces ignored when a shard is present); new `hatchIncubator` and `setFocus` after l.480; `incubator` in clientView. Old `hatch`/`hatchPlan` stay for rollback. |
| H15 | `ServerScriptService.EOS.Services.EconomyService` | 61-111 (onHatch), 394 (connect) | `RequestHatch(rarity, family, allowHigher)` | Remotes `HatchIncubator` / `SetFocus` live in **EggService** (own folder, own rate limits, lobby-only, through the same `tryUpdate` pattern). EconomyService: one line to `EggService.bindEconomy(...)`, or none if EggService uses DataService directly. `HatchResult` is reused for the ceremony. |
| H16 | `EconomyConfig` | 108-121 | MATERIALS / MATERIAL_INFO / RECIPES | **No edit** (Legendary info in EggConfig; RECIPES unused when enabled). |
| H17 | `StarterPlayer…Controllers.UIController` | 864 (MatchHUD `Egg` card: `EggSlot/EggTitle/EggLevel`), 2470-2488 (Results PieceSlot / BestEgg), 3101-3116 (RunnerEvolved banner), 1340-1450 (incubator / recipe panel) | | One line only: `require(script.Parent.EggUIController).init(...)`. No new top-level locals. EggUIController hides or overrides the recipe ladder and the Results piece slot. |
| H18 | `PointsController` | 712-745 (results egg line, `myEgg`), 1284-1292 (`onEvolved`), 1407-1412 | reads `t.prevTier/newTier` as rarities via `rarityForLevel` | No edit: H1 keeps the level shape, so it stays right. |
| H19 | `ServerStorage.EOSUIBuild.Data_Incubator` / `Data_MatchHUD` / `Data_Results` | generated | | Stage 4: new HTML pages, re-export after Hunter approves. |
| H20 | `Analytics` | 17-29 (`KNOWN`) | Unknown events are still logged, with `unknownEvent = true` | **No edit**: EggService adds `EggCharged`, `EggRolled`, `ShardGranted`, `IncubatorHatched` and `FocusChanged` to `Analytics.KNOWN` at init. |

## Shard at the end (how EggService computes it)
- A surviving Runner (still a Runner at the end): shard = rarity of `currentCarriedTier`.
- Everyone else: if `captureCount > 0`, shard = rarity of `bestStolenTier` (already the best snatch, capped by H6); otherwise none.
- Ineligible (AFK) or disconnected: none.

## Questions that change a rule (waiting for answers)
- **Q1. Legendary hatch with no Legendary species.** No family has a Legendary pet, and only Decoy and Invisibility can hatch at all. Options:
  (a) Legendary shows "coming soon" and its odds go to Epic until a Legendary pet exists (the odds shown stay honest);
  (b) keep Legendary odds, and a Legendary hatch gives the family's Epic pet plus a mutation level;
  (c) wait for pets.
  I recommend (a). The focus picker shows all 5 families, with locked chips for families that have no species yet.
- **Q2. Timed-out Runner** (didn't finish the crossing in time, so becomes a Catcher). Today they keep their egg. By the spec's wording they aren't "surviving", so they get no shard unless they snatch. I recommend following the spec: no shard, same as caught.
- **Q3. Newbie boost "first 10 h"**: there's no playtime stat. I recommend a new `stats.secondsPlayed`, added from each settlement's match length (match time only). The alternative is a proxy of `matchesCompleted < 240`.
- **Q4. Revive** gives the revived Runner their egg back while the Catcher keeps the snatch credit, so the egg exists twice. I recommend keeping it: revives are rare, once per crossing, and this matches today's rule.

## Stage 1 test plan
jest-lua is not in the place. I'll write `EggLogic.spec.lua` in jest-lua syntax and run it locally under **Lune** with a small describe/it/expect shim (EggLogic is pure, no Instances). The same spec also goes to `ServerStorage.EOSBuild.EggTests` so it can run in Studio like LogicTests/DataTests. If Hunter wants real Jest packages in the place, that's a Wally install plus an import (a download), so I'm asking first.
