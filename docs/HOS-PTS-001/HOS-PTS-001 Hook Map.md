---
tags: [ticket, match]
updated: 2026-10-17
---
# HOS-PTS-001 Hook Map (stage 1)

Match points, revive, 5 crossings and podium. Read from the live place on 17 Oct 2026 (MatchService 1314 lines, MatchLogic 806). No edits yet.

## What the place does today
- A match has no fixed length: it ends on 3 clean crossings in a row (`GameConfig.Match.CLEAN_STREAK_TO_WIN`), when the last Runner makes a solo crossing (`LAST_ONE_STANDING`), when no Runners are left, or at `MAX_CROSSINGS_SAFETY = 40`. `EOS_State.MaxWaves` is 0 ("no fixed number").
- Caught = `MatchLogic:capture` sets role `CAUGHT`, `MatchService.tryCapture` ragdolls the body (`RAGDOLL_STAY_DOWN = true`: down until the crossing ends). `MatchLogic:endWave` turns `CAUGHT` into `CATCHER` (`res.promoted`). Downed players are unragdolled and frozen into the Catcher line by `CrossingLineup.arrange` at the next crossing's start.
- Egg: +1 level per crossing (`MatchLogic:finishCrossing`), up to 99. Looks come from `TierConfig.Groups` (Common 1, Rare 3, Epic 5, Legendary 7, Cosmic 10). The piece paid comes from `EconomyConfig.MATERIAL_FOR_TIER` (1 common, 2 rare, 3-4 epic). These two maps disagree (level 2 = Common look but a Rare piece).
- Gold: `EconomyConfig.goldFor` per player (25 active + 12 per crossing + 10 first steal + 15 win, cap 90), computed in `MatchLogic:computeResults`. A Hero who crosses adds `heroBonusCrossings` (Gold line "HERO", XP via `settleXp`, plus a bonus piece roll).
- XP: `MatchService.settleXp` → `EconomyConfig.xpFor` (+ VIP / 2x pass boost).
- Emotes: `EmoteService` sets the character attribute `EOS_Emote`; `EmoteController` and `EmoteFX` (prop effects) play it on every client. Emotes are blocked in a match. The wheel is saved per player (`RequestEmoteWheel`); no favourite yet.
- Cut-scenes: `Controllers.Cinematic` (`play(spec)` with a shot list, letterbox, title, `keepGuis`). It always hands the camera back when Phase becomes CROSSING.
- NPC Catchers never call `MatchService.onCatcherAttack` (that hook only fires for real players' remotes).

## Where each piece hooks
| Piece | Hook | Shared edit? |
|---|---|---|
| Survive +100, Hero alone +200 | `MatchService.onCrossing(fn)`, event "end": Runners still `RUNNER` + `isSafeThisWave`. Hero from `p.heroBonusCrossings` going up | None |
| Catch +50, snatch +25/50/100 | PointsService diffs `c.logic` participants every tick (role → `CAUGHT`, `capturedBy`, the carried egg from the last snapshot) | None |
| Juke +10 (players) | `MatchService.onCatcherAttack(fn)`: note Runners within 6 studs, check after the strike time | None |
| Juke +10 (NPC Catchers) | One line in NpcService `lunge()` (and the NPC stab) calling the same attack hook | NpcService, 1 line each |
| Revive +25 | ReviveService (own module) | See revive below |
| Points → XP 1:1 | `MatchService.settleXp`: `PointsService.xpFor(plr) or EconomyConfig.xpFor(outcome)` | MatchService, 1 line |
| Gold pot split | `onCrossing` "match" event fires before `computeResults`; PointsService calls it first (it caches) and rewrites `perPlayer[uid].gold / goldParts` from the same total | None |
| Hero double points replace the Hero Gold/XP bonus | Behind the switch, `heroBonusCrossings` no longer pays Gold/XP (piece roll kept?) | HeroChicken thread: 1 line in `watchHero` |
| Popups | Own remote from PointsService, own client controller | ClientMain, 1 line |
| 5 crossings | `GameConfig.Match`: a `FIXED_CROSSINGS = 5` passed as `maxWaves`, clean streak off; `EOS_State.MaxWaves = 5` for the HUD | HeroChicken thread (MatchService ~line 818, 906) |
| Egg ladder | After `finishCrossing` succeeds in `MatchService.tick` (~line 701): `EggLadder.onCrossed(c, uid, info)` rewrites the new level | HeroChicken thread, 1 line |
| Podium | `MatchService.onResults(fn)` fires at RESULTS start (players are already in the lobby); RESULTS needs ~16 s instead of 11; UIController's own Results panel must wait for the podium | GameConfig 1 value, UIController 1 line |
| Favourite emote star | EmoteController emote menu + a new saved field (ProfileLogic default + validation) | EmoteController, ProfileLogic |

## Revive
- Downed window 6 s: inside it the downed Runner keeps role `CAUGHT`; a revive sets them back to `RUNNER` with the egg they carried, unragdolls them, re-applies the Runner look. After 6 s nothing changes from today (down until the crossing ends, a Catcher next crossing).
- ReviveService changes the participant table itself (as HeroChickenService does with `heroBonusCrossings`), so MatchLogic isn't edited. The capture still counts for the Catcher (+50 stays).
- Needed from the round-flow owner: a `RoleChanged` cause `"REVIVED"` (UIController shows nothing for unknown causes, so it is safe, but a banner is nicer) and confirmation that a revived Runner is fine for `CrossingLineup` and the clean-crossing count.

## Status (17 Oct, 06:45 UTC)
- Answers from Hunter (via the coordinator): 5 crossings; the match ends early only when no Runners are left (`GameConfig.Match.SOLO_WIN_ENDS_MATCH = false`); Gold split approved (PLAYED floor + the rest by points, total unchanged); the egg rarity sets look and piece, Legendary piece to be added; the Hero bonus egg roll stays, the Hero Gold/XP goes.
- In the place, new and unwired: `ReplicatedStorage.EOS.Shared.PointsConfig`, `ServerScriptService.EOS.Services.EggLadder`, `PointsService`, `ReviveService` (source: `roblox/game/points/`). Compile-checked. The ladder was simulated over 200k matches: after crossing 3, 2.5% Legendary and 12.5% Epic. The roll boost is +25% of each chance.
- Legendary piece: ProfileLogic refuses `crowned`, so Legendary pays `Ladder.LEGENDARY_FALLBACK` (epic) until the piece ships.
- Shared-script hook lines are blocked by this PC session's permission check; only `GameConfig.Timing.RESULTS = 16` went in. The lines waiting are listed in the coordinator message of 06:38 UTC. Backups: `docs/backups/HOS-PTS-001_2026-10-17/`.
- UI: `UI/build.py` section "HOS-PTS-001" (pages `points_*.html`), stills in `docs/HOS-PTS-001/mockups/`, review page https://claude.ai/artifact/VrXfipVeLXcANXkACGZzAW (round 2). Not imported; waiting for Hunter's yes.

## Open questions for Hunter (answered, kept for the record)
1. 5 crossings: does Last Runner Standing still end the match early when one Runner is left, or does it always run all 5?
2. Gold pot: proposed split = everyone eligible keeps the 25 PLAYED floor; the rest of today's total pot is shared by points. Total Gold per match unchanged.
3. Egg ladder: carried rarity becomes Common / Rare / Epic / Legendary (not levels). Pieces need a Legendary piece (today Epic is the top). Use rarity for both the look and the piece?
4. Does the Hero's bonus egg-piece roll stay, now that double points replace the Hero Gold/XP bonus?

## Runtime changes to the imported PointsUI (17 Oct, Hunter's polish notes)
- Between-crossings board (`PointsController.setCompact`): Leaderboard, Glow, Panel (+ their Art) and the List well are resized to the leaderboard column and the rows shown (7, or 8 with your row under them); SubText moves into the header strip, right-aligned; CloseButton hidden; Panel/Glow Art switch to 9-slice (margins 24 / 30 texture px) while compact. Every value is stored on the instance (`WideSize` / `WidePos`) and restored before the results screen opens.
- Revive ring fill: `Builder.cooldown` now builds each half as a round disc (UICorner 0.5) masked by a hard-step UIGradient whose Rotation sweeps the edge (was a rotating square plane). `PointsController.cooldown` drives the same layout.
- NEXT (results card): build.py `btn(224, 478, 186, 68, 'lime', ...)`, the old Results card's NEXT, on the card grid. New art uploaded: `art:adcef75dd54` (NEXT), `art:ad92fc49b48` (X, re-render).
- Build step after `Builder.build()` + `fit()` x2: `roblox/ui_points/PostFit.luau` (labels in "...Big" frames back to TextSize 100).

## Results screen v2 (17 Oct, Hunter: "looks phenomenal. build it with the fix.")
- **Design:** UI/build.py `rv_*`. The fix: the POINTS column is gone from YOUR REWARDS (the YOU strip has the points); the rewards are now XP / GOLD / GEMS plus the level bar.
- **Export:** `ui_points/pages.py` adds two groups to the Points screen:
  - **ResultsV2:** the end-of-match card.
  - **ResultsSkinRed:** the same panel in red, never shown; it only donates its art for a Catchers win.
  - The old Leaderboard group no longer carries the rewards/egg box (`rewards=False`); it is only the compact board between crossings now.
- **Server:** PointsService rows carry `safe` and `catches` (SURVIVED / CATCHES tabs).
- **Client (PointsController, RV2.\*):**
  - **Header:** a winner title per outcome and a pluralised subtitle. "Next match · Ns" counts from PhaseEndsAt.
  - **Tabs:** they auto-cycle every 4 s with a bar; a tap picks a tab and stops the cycle. A tab nobody scored in is hidden (the rest re-centre).
  - **Ranking:** competition ranking, with JOINT #n for ties.
  - **Pictures:** headshots via rbxthumb; bots through BotHeadshot.
  - **Role tags:** in role colours, centred, with a bigger word on phones.
  - **Rewards and egg:** the YOU strip, XP/GOLD count-ups, GEMS shown only when there are some (XP/GOLD re-spread otherwise), and the level bar from ProfileState.
  - **Egg block:** EggUIController still fills it (EggSlot, EggText, EggHow, PieceIcon, PieceText). Its frame is now `EggBlock`.
  - **Phones:** the panel is at 1.1 on PopScale (`PhoneScale` removed).
- **Motion:**
  - **Enter:** the dim fades in; the panel scales 0.92→1 (Back); the banner slides from the left (Quart); the tabs rise; the cards rise #2, #3, then #1 with a pop; the crown drops; YOU slides up; the rewards and egg boxes fade in and count; NEXT comes last.
  - **Tab switch:** the highlight slides across, and the cards cross-fade with a 24 px slide, staggered 0.04 s. Names and pictures swap while hidden, and stats count up.
  - **Exit:** about 0.42 s. Content fades and sinks, the panel goes to 0.95 and fades, then the dim. It starts 0.6 s before the results phase ends, so it is done before the lobby UI comes up.
  - **Reduce effects:** plain 0.15–0.2 s fades.
  - **Helpers:** one tween helper and one alpha helper, both cancelling what was running; checked with tap spam.
- **UI kit (PointsUI client UI.luau):**
  - `UI.hooks[screen] = { open, close }` lets a screen run its own motion instead of the pop.
  - A tap on the scrim no longer closes the screen when it lands inside a visible group's Panel. Before this, tapping a card closed the results.
- **Pops:** the last crossing's points pops are cleared when the results open.

## Emote podium on results v2 (17 Oct, Hunter "OK" on mock v2)
- **Layout (build.py):**
  - `RV_STAGE = 50`: the top-3 cards are 50 px taller, growing upward. The tabs move up 24 and the subtitle 12, and the crown sits on #1's top edge.
  - The fallback headshot is centred in the stage.
  - A hidden `EmoteChip` (EmoteText) sits in each card's top-right corner.
- **Client (PointsController `RV2.stage`):**
  - **Model:** one ViewportFrame + WorldModel per card (3 at most). Players are built with `CreateHumanoidModelFromDescriptionAsync`, using their applied description (R6). If that fails, a copy of their character is used. Bots wear NpcSkins `Skin<slot>`.
  - **Clean-up of the model:** scripts, tools, billboards and sounds are removed; the root is anchored and hats are welded.
  - **Emote:** the player's `EOS_FavEmote`, or else a free emote picked from `RV2.FREE` and kept for this player all screen. It loops on the Humanoid's Animator.
  - **Framing:** full body (7.2 studs tall in frame, FOV 30) at a 25° turn; #3 turns the other way.
  - **Reveal:** the view fades in over the headshot in 1.2 s once ready. Models are cached per player for the screen, so a tab switch swaps them while the card is hidden.
  - **Headshot fallback:** Reduce effects, SavedQualityLevel 1–3, a load or animation failure, or more than 2 s to load.
  - **Clean-up:** everything is destroyed on exit and on the next fill.
- **Favourites:** PodiumService now loads favourites and handles SetFav whenever Points is on (the podium cutscene stays off). PointsController shows the favourite star on My Emotes again.
