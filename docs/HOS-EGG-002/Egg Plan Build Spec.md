# Egg Plan Build Spec (HOS-EGG-002)

Status: approved by Hunter 2026-10-17 08:49 ("Build the plan for this and let's start implementing IN HIGH QUALITY"). Source discussion: thread "Economy and name review" and the Claude Doc "Economy and Name Review" (https://claude.ai/code/artifact/87477f80-7038-4fd5-9ff2-57cb7b5f26a9). Every number below is a starting value. Tune it from playtests and telemetry, not by feel. No sims (Hunter).

## 1. The rules, final

**In the match**
1. Every Runner starts with a whole **Common** egg on their back (as now). Its rarity colour is visible to everyone.
2. **Charge.** During a crossing, brave plays charge the egg (0 to 1, shown as a glow on the egg and a meter on the HUD egg card):
   - juke (PointsService juke event): +0.25, at most 2 jukes count per crossing
   - revive a teammate: +0.5 (revives are already once per Runner per crossing)
   - Hero success: charge = 1.0 for that crossing
   - cap 1.0. Charge resets to 0 after the roll at safety.
3. **Roll at safety.** The moment a Runner enters the finish zone (today's "RunnerEvolved" point in MatchService), the egg rolls once, in about 1 s, on the egg itself. Play never pauses.
   - Crossing 1: Common to Rare, always.
   - Crossings 2 to 5 (c = charge):
     - Rare to Epic: 3.6% + 4% × c
     - Rare to Legendary: 0.36% + 0.4% × c
     - Epic to Legendary: 2.4% + 2.25% × c
   - New players (first 10 h played) get the base terms × 1.5 (the charge terms are unchanged).
   - The big banner shows only on an upgrade. A non-upgrade shows a small "SAFE!" only (existing).
4. **Caught.** The Catcher takes the egg into their stash (it never goes on the Catcher's back). The +1 snatch-back cap stays: a snatched egg can be at most one rarity above the egg the snatcher held when caught. The starting Catcher's cap is Epic. A Catcher keeps only their best snatched egg.
5. **End of match.** Each player gets **one shard**: a surviving Runner gets a shard of the egg they hold, and a Catcher gets a shard of their best snatched egg (none if they snatched nothing). Points, XP and Gold are unchanged (points split the Gold pot as now).
6. **Hero bonus roll is removed.** A Hero success sets charge to 1.0 instead, and keeps +200 PTS and the HERO banner. Tell the Hero or Chicken thread.

**Between matches: one incubator egg**
7. Every shard goes into a single incubator egg. Weights: Common 0.5, Rare 1, Epic 3, Legendary 10. The egg needs **30** to fill (37.5 when focused).
8. Hatch odds, shown on the egg at all times:
   - base: Rare 90%, Epic 8.5%, Legendary 1.5%
   - +2.5% Epic per Epic shard in this egg, +4% Legendary per Legendary shard
   - caps: Legendary 25%, Epic 50%. Rare is the remainder.
9. Full egg: the player presses **Hatch** at the incubator, using the existing ceremony and the Royal Hatching cosmetic. Rarity is rolled from the shown odds. The family is the focus, or random if the focus is Any. The species is one the player doesn't own in that family and rarity first; otherwise it's a duplicate, which raises the mutation level (Economy Decisions #19). Overflow fill carries into the next egg as plain fill, while shard counts for odds reset.
10. **Focus**: pick one of the five families (Decoy, Invisibility, Guardian, Tempest, Rift) or Any. Focus raises the fill needed by 25%. It can be changed any time while the egg fills (the requirement updates). It never costs Gems or Robux.
11. **First pet**: the first egg a player wins still gives a Common pet of a family they choose (Economy Decisions #15), outside the incubator.
12. **Removed**: the 1/3/5 crossing ladder and its odds, per-rarity piece stacks and recipes (RECIPES), Common fusion, the Hero bonus roll.
13. **Never sold**: eggs, shards, fill, odds, focus and hatches (Robux buys looks only).

**Expected results (hand arithmetic, at about 24 matches an hour, 80% survival):**

| Player | Egg at end (Rare / Epic / Legendary) | First Epic pet | First Legendary pet |
|---|---|---|---|
| Quiet (charge 0) | 85.1% / 13.1% / 1.9% | about 6 h | about 36 h |
| Average (charge 0.4) | 79.0% / 18.1% / 2.9% | about 5 h | about 27 h |
| Bold (charge 1) | 70.5% / 24.9% / 4.6% | about 4 h | about 19 h |

The first Rare pet comes at about 1 h for everyone. Getting caught on purpose earns about 0.3× a survivor's shards. These figures leave out the new-player boost.

## 2. Config: one table (new ModuleScript `ReplicatedStorage.EOS.Shared.EggConfig`)

```lua
EggConfig.ENABLED = true            -- false = old ladder path (rollback switch)
EggConfig.CHARGE = { JUKE = 0.25, JUKE_MAX_PER_CROSSING = 2, REVIVE = 0.5, HERO_SUCCESS = 1.0, CAP = 1.0 }
EggConfig.ROLL = {  -- per crossing 2..5; crossing 1 = Common->Rare always
  RARE_TO_EPIC = { base = 0.036, perCharge = 0.04 },
  RARE_TO_LEGENDARY = { base = 0.0036, perCharge = 0.004 },
  EPIC_TO_LEGENDARY = { base = 0.024, perCharge = 0.0225 },
  NEWBIE_BASE_MULT = 1.5, NEWBIE_HOURS = 10,
}
EggConfig.SHARD_WEIGHT = { common = 0.5, rare = 1, epic = 3, legendary = 10 }
EggConfig.INCUBATOR = { FILL = 30, FOCUS_MULT = 1.25,
  BASE_ODDS = { rare = 0.90, epic = 0.085, legendary = 0.015 },
  EPIC_PER_SHARD = 0.025, LEGENDARY_PER_SHARD = 0.04, CAP = { epic = 0.50, legendary = 0.25 } }
EggConfig.FAMILIES = { "Decoy", "Invisibility", "Guardian", "Tempest", "Rift" }
```
All logic reads this table. The UI reads it too, so the screen shows the same odds the server uses.

## 3. Scripts (names from the 02:00 ScriptHistory snapshot: verify in the live place in stage 0)

| Script | Change | Kind |
|---|---|---|
| `Shared.EggConfig` (new) | the table above | new module |
| `Shared.EggLogic` (new) | pure functions: addCharge, rollAtSafety, shardFor, incubatorOdds, addShard, hatchRoll, pickSpecies | new module, unit tested |
| `ServerScriptService.EOS.Services.EggService` (new) | per-match charge state; listens to PointsService juke/revive/Hero events; runs the roll; fires `EggCharged` / `EggRolled` to clients; reports the shard at settlement | new module |
| `MatchService` | one-line hook at finish-zone entry (where `RunnerEvolved` fires) to `EggService.onSafe(plr, crossing)`; settlement passes `shard` instead of `material` when `EggConfig.ENABLED` | small line edits; the Hero or Chicken thread owns round flow, so ask it first |
| `MatchLogic` / `TierConfig` | bypass the old evolution odds when enabled; keep securedTier/currentCarriedTier as the egg rarity source; add Legendary as tier 4 | small line edits |
| `EconomyConfig` | add `legendary` to MATERIALS/MATERIAL_INFO (colour to match the kit); leave RECIPES in place but unused when enabled | small line edits |
| `ProfileLogic` | new `incubator` field, migration (section 4), `applySettlement` adds the shard via EggLogic, new `hatchIncubator` and `setFocus` | small line edits plus new functions |
| `EconomyService` | remotes for Hatch and SetFocus (server-validated, rate-limited) | small line edits |
| PointsService (HOS-PTS-001) | expose or fire juke, revive and Hero-success signals if not already present | one-line hooks |
| `UIController` | **no new top-level locals** (200-local limit): only a one-line require of a new `EggUIController` | one line |
| `StarterPlayerScripts.EOS.Controllers.EggUIController` (new) | HUD egg card meter, roll toast, incubator screen, results shard row, tutorial | new module |

Claim every shared script in `C:\HatchOrSnatch\docs\workflow\edit-claims.md` (cloud copy `/mnt/project-files/workflow/edit-claims.md`) as `script | Economy and name review | time`. Re-read each script right before every edit. Small line edits only, never whole-source writes.

## 4. Migration (ProfileLogic.migrate, idempotent, flag `incubatorV1`)
- New field: `incubator = { fill = 0, shards = { common = 0, rare = 0, epic = 0, legendary = 0 }, focus = "Any", hatched = 0 }`.
- Existing pieces convert at the shard weights: `fill += common×0.5 + rare×1 + epic×3 (+ crowned/legendary×10)`. Epic and Legendary piece counts also go into `shards` so they raise odds. Then set the pieces to 0 (keep the old fields for one release for rollback).
- If the migrated fill is 30 or more, the egg is ready to hatch, and overflow carries over as plain fill.
- Owned pets, mutation levels and `firstCommonFree` are untouched.
- Pre-launch, so few profiles are affected. Still unit-test old V1/V2/V3 shapes.

## 5. UI (roblox-ui-maker only)
Make an HTML mockup with every state in `C:\HatchOrSnatch\ui` (build.py, EOSUI kit, Montserrat ExtraBold, dark outline). Hunter approves the look, then export, import and wire. Check each screen beside the round header, the best-egg card, the Gems wallet and the Results card, at phone size, 1920×1080 and 1366×768. Keep everything small and don't repeat information. Units rule: never a bare number. Shards read "+1 RARE SHARD", points use pts_pill(), Gold uses coin + GOLD.
1. **HUD egg card** (edit the existing best-egg card): rarity name and colour, plus a 3-segment charge meter that ticks on each charge. States: Common, Rare, Epic, Legendary × charge 0 / partial / full. This also fixes the pending false "Your egg grew" SAFE banner (coordinate with the match-points thread, which has that UIController change pending).
2. **Charge pop**: small "+CHARGE" next to the existing "+10 PTS Juke" pop, with no extra text card.
3. **Roll at safety**: the existing SAFE! line. On an upgrade only, an "EPIC EGG!" or "LEGENDARY EGG!" banner (reuse the egg-grew banner style).
4. **Incubator egg screen** (replaces the recipe panel; Data_Incubator): big egg with a fill ring "18 / 30", three shard counters (Rare, Epic, Legendary icons with counts), odds bars, a focus picker (Any + 5 family chips, "+25% to fill" note), a Hatch button (states: filling / ready / hatching), and a one-line explainer.
5. **Results screen**: a "+1 EPIC SHARD" row under POINTS/XP/GOLD. The egg icon cracks, and its glowing core flies to a small incubator egg icon whose ring fills.
6. **Lobby**: "READY TO HATCH" badge on the incubator button.
7. **Tutorial pop** (once, on the first charge): "Brave plays charge your egg. Charged eggs roll better at safety."

## 6. VFX and audio
- roblox-vfx skill, textures from allvfx only.
- Back-egg glow: 3 strengths by charge, in the rarity colour.
- Charge pulse: a short ring on the egg.
- Roll flicker at safety: about 1 s, cycling rarity colours.
- Upgrade burst: gentle, with no flash burst and no camera motion (cinematic comfort rule). Reduce effects = glow only.
- Results crack and core-fly happen in UI space.
- Sounds: real recordings only (CC0 or the Roblox licensed library), never synthesised or AI. Needed: a charge tick, a roll whirr, an upgrade chime, an egg crack, a hatch.
- Uploads need Hunter's typed OK line.

## 7. Build stages (one at a time; each ends with its test)

| Stage | Work | Test before moving on |
|---|---|---|
| 0. Audit | Read-only map of the live egg flow: EconomyConfig, TierConfig, MatchLogic evolution, MatchService finish-zone hook, PointsService events, ProfileLogic pieces and incubator, EconomyService remotes, UIController and Data_Incubator. Back up those scripts to `docs\backups\HOS-EGG-002_2026-10-17\`. Write `docs\HOS-EGG-002\audit.md` listing every place that needs changing | Audit lists each hook point with its line, with no unknowns left. Send it to the thread |
| 1. Logic | EggConfig + EggLogic, pure, with no Studio side effects | jest-lua unit tests: roll odds per crossing, the newbie boost, the +1 cap, shard weights, the odds formula and caps, overflow, species picking. A deterministic table check reproduces section 1's spread (avg 79.0 / 18.1 / 2.9) |
| 2. Data | ProfileLogic incubator field, migration, settlement shard, hatch and focus | Unit tests on old profile shapes. A Studio command-bar check on a test profile: migrate, add shards, hatch |
| 3. Match | EggService, MatchService and MatchLogic hooks behind `EggConfig.ENABLED` | Claimed self-closing playtest with bots: charge rises on juke and revive, Hero sets 1.0, one roll per Runner per crossing, crossing 1 always Rare, a caught egg goes to the Catcher's stash, the end shard matches. Output log attached |
| 4. UI | HTML mockups for every state, then Hunter approves | Hunter's typed approval, then import. QA screenshots at 3 sizes next to existing panels, sent as attached_outputs |
| 5. VFX/audio | Glow, pulse, roll, burst, crack and core-fly, sounds | Frame captures plus a short clip, with Reduce effects checked. Previews in the thread |
| 6. Full playtest | Whole match through to the incubator hatch | One full 5-crossing match. Hatch a seeded full egg. Check telemetry events fire. Clip plus stills to Hunter |
| 7. Wrap | ScriptHistory snapshot, `docs\HOS-EGG-002_report.md`, update the Home note and Economy Decisions | Hunter reviews and saves the place |

**Telemetry** (existing analytics path): `EggCharged{source}`, `EggRolled{crossing, from, to, charge}`, `ShardGranted{rarity, role}`, `IncubatorHatched{rarity, family, focused, fillUsed}`, `FocusChanged`. Tune targets: average charge per crossing 0.3 to 0.5. Survivors' end spread near 79 / 18 / 3. First Rare pet about 1 h, measured from real matches per hour.

## 8. Project rules for the PC sessions
- No git, branches or PRs. Work straight in the Studio place through the PC session in `C:\HatchOrSnatch`. Never save or publish the place: Hunter does.
- Call `get_connected_instances` first and pick the Hatch or Snatch place. Never touch the Faceoff or HOOKED places.
- Hunter must type these himself in the thread, per thread: the Studio MCP token line ("Claude on my PC: you may read ~/.robloxstudio-mcp/auth-token to use the local Studio MCP on 127.0.0.1."), "shared-scripts OK" before editing MatchService, MatchLogic, ProfileLogic, EconomyConfig or UIController, a playtest OK, and a typed upload OK for any asset.
- Claims file before edits. Claim `PLAYTEST` before any playtest, one at a time, self-closing, and remove the line after.
- New features go in their own modules with one-line hooks. UIController gets no new top-level locals.
- UI only through roblox-ui-maker, with Hunter's approval of the HTML before import. VFX through roblox-vfx with allvfx textures. Sounds are real recordings.
- Previews: Hunter reviews on his phone. PC sessions publish stills and clips to a review artifact, and the thread pulls them into `/mnt/project-files/economy-review/previews/` and attaches them.

## 9. Open (defaults chosen, change if Hunter says)
- Common pets beyond the first choice: default level rewards at levels 5, 10, 15 and 20 (one unowned Common each). Not built in this ticket unless Hunter confirms.
- 24 matches an hour is an estimate. Re-set FILL from real matches per hour once telemetry exists.
- Game name (thread recommends "Egg Heist"): undecided, so not in scope.

## 10. Early end: bonus rolls (added 17 Oct, 09:17, via the thread)
Hunter is bringing back the early end: 3 clean crossings in a row ends the match as a Runners win (the match-points thread restores it, with CLEAN STREAK diamonds). A match is now 3 to 5 crossings.
- When a match ends early, each surviving Runner's egg rolls once for every skipped crossing, right after the final SAFE. Skipped = 5 minus crossings played, counting only crossings 2 to 5 as roll slots (TOTAL_ROLLS = 4).
- Bonus rolls use the player's average charge over the match's crossings. Catchers' stashes don't roll.
- Result: an average player's end spread stays 79.0 / 18.1 / 2.9 whatever the match length (without it: 88.9 / 9.9 / 1.2 after 3 crossings).
- Config: `EggConfig.ROLL.BONUS_ROLLS_ON_EARLY_END = true`, `EggConfig.ROLL.TOTAL_ROLLS = 4`. FILL stays 30 (re-set later from real shards per hour).
- Telemetry: `matchCrossings` on ShardGranted; `EggRolled{bonus = true}`.
- Hook: match end through MatchService.onCrossing ("match"), which EggService already uses. No edit to the match-points thread's code.
- UI: one small "RUNNERS WIN: BONUS ROLLS xN" flicker on the egg; the banner only on an upgrade.
- Tests: Lune specs for 3, 4 and 5 crossing matches giving equal spreads; a forced 3-clean early end in the playtest if possible.
