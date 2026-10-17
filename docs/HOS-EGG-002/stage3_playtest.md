# HOS-EGG-002 stage 3 playtest (17 Oct, ~09:58Z)
Hunter's typed "Playtest ok" (09:13). One claimed, self-closing solo playtest in the Hatch or Snatch place; NPCs filled the match
(20 Runners, 2 Catchers + the idle test player). Forced early end: the test match's `logic.maxWaves` set to 3 at runtime (playtest only)
to exercise section 10. Egg events collected through `Analytics.setSink` in the playtest server.

## Seen
- EggService booted (EggConfig.ENABLED, `ReplicatedStorage.EOS_Egg` remotes); no egg script errors in the run.
- Crossing 1: 17 / 17 safe Runners rolled Common -> Rare.
- Crossing 2: 16 rolls, no upgrade (base ~4% each; plausible).
- Crossing 3: one Rare -> Legendary.
- Catches: 6. Starting Catchers' snatches final as Common; a converted Catcher who held Common snatched a Rare (the +1 cap).
  No pending snatch left at the end.
- Early end after 3 crossings (endReason SAFETY_CAP from the forced cap, Runners win): every one of 13 survivors got
  BONUS x2 (EggRolled bonus=true); one went Rare -> Epic, the Legendary stayed Legendary.
- End shards (EggService.shardOf for all 22, checked against the rules: 0 mismatches): survivors 11 Rare / 1 Epic /
  1 Legendary; Catchers 2 Rare + 1 Common from their stash, 6 with no snatch -> none. The idle test player timed out with
  no snatch -> no shard (Q2), and its settlement carried no material / bonus pieces.
- Hero runs: 2, both CAUGHT (no Hero success to test the 1.0 charge live).

## Charge playtest (17 Oct, ~10:05Z, second claimed self-closing run, coordinator request)
Signals injected through the real paths: `PointsService.award(c, actor, "juke" / "revive")` and a real Hero run
(HeroChickenService picked the Hero; the Hero was teleported into the finish zone so MatchService's tick ran the real
finishCrossing -> EggService.onSafe). Test player 18537779 (Runner) and bot -1000007.
- Juke 1 -> 0.25, juke 2 -> 0.50, juke 3 -> 0.50 (third doesn't count; it still paid its 10 PTS). Player attribute
  EOS_EggCharge and the EggCharged events matched each step.
- Bot: revive -> 0.50, +2 jukes -> 1.00, another revive -> 1.00 (cap).
- Crossing 1 safety: rolls ran at charge 1.00 (bot) and 0.50 (player), both Common -> Rare (always), and both meters
  reset to 0 right after (attribute 0).
- Crossing 2 start: the bot's charge and juke count were 0 (per-crossing reset).
- Crossing 2 Hero run (the same bot was picked as Hero): EggCharged{source = hero, 1.0} -> EggRolled{crossing 2,
  rare -> rare, charge 1.0} -> HeroChickenResult CROSSED, in that order; charge reset to 0 after. The odds that roll used:
  Epic 7.60% / Legendary 0.76% at charge 1.0 (vs 3.60% / 0.36% at 0), from EggLogic.rollChances, the same function the
  roll calls with the stored charge. A single roll can't show the odds; the Lune specs check them.
- Average-charge bookkeeping for bonus rolls: the bot had 2 rolls with a charge sum of 2.0.
- No egg script errors. Playtest stopped; PLAYTEST claim removed.

## Not exercised live (covered only by the edit-mode dry run, stage3_dryrun.md)
- (first run) Charge: no natural juke / revive / Hero success happened; covered by the charge playtest above.
- A real player's saved shard (practice matches with under 4 real players never save).
