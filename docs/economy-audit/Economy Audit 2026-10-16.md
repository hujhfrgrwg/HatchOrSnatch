---
tags: [design, economy, audit]
updated: 2026-10-16
ticket: HOS-ECON-001
---
# Hatch or Snatch: economy and design audit

This answers the ChatGPT audit brief Hunter shared on 16 Oct, using the real repo: GDD v0.4, the decisions note, and the place's scripts as snapshotted in `ScriptHistory` on the PR #1 branch. The numbers come from a new multiplayer simulation in `tools/sim/`. Raw results are in `docs/economy-audit/results/`, and every run has a fixed seed listed in `results/manifest.json`.

**Lobby size:** Hunter corrected this mid-audit to about 30 players per match. Everything below uses 30 players with 3 starting Catchers unless it says otherwise. 12, 16 and 24 players are kept as comparisons.

## 0. What I think of the prompt itself

**What it gets right:**
- It asks for an interacting multiplayer model rather than independent win chances.
- It tests deliberate surrender directly.
- It asks for percentiles, not just averages.
- It separates verified facts from guesses.
- It forces a decision at the end.

All five are what stops this kind of exercise turning into fluff.

**Where it falls short:**
- **It assumes the game isn't built.** Most of it is. The place already has the chase, eggs, materials, the incubator, three abilities, Gold, Gems, live Gem packs, passes, an emote crate and XP. The real question is what the place does today and what has to change. Section 1 answers that.
- **It describes a design that is neither the GDD nor the code:** Legendary eggs, random evolution, eggs that are "won, not awarded", and 3/4/3 recipes. Its key numbers were also out of date: about 12 players and 2–3 minute matches. Hunter's lobbies are about 30, and the place's cycle is about 65 seconds.
- **The "76.5%" figure comes from a simulation that isn't in the repo,** so it can't be checked. I rebuilt the question from scratch instead (section 3).
- **It asks for things no simulation can supply,** such as "psychological enjoyment" and "monetization compatibility". I scored those as stated hypotheses and kept them apart from measured results.
- **It never names the biggest unknown: how good catching is compared with escaping.** That one number decides survival rates, the surrender incentive and egg supply, and only playtests can set it. I ran everything at three levels (loose, base, tight) instead of pretending to know it.

## 1. Executive verdict

**Yes, pursue it, but fix the economy before tuning anything else.** The format has proven demand. Huss Valley, the game this one is modelled on, had 95,644 people playing when checked on 16 Oct 2026 and 132.6 million visits, and it was only created on 31 Aug 2026. That comes from Roblox's public API (verified; links in section 8).

The economy as specified has three serious problems, and all of them can be fixed:

1. **Under "one theft = one egg", getting caught early pays as well as or better than playing to survive** (section 3). The fix is one rule, the Snatch-back cap.
2. **Rewards arrive far too fast.** The place runs a match cycle of about 65 s, not the 135 s the GDD assumed, and a 30-player lobby makes eggs plentiful. Under the brief's 3/4/3 recipes, a typical player hatches their first Legendary pet in about 45 minutes. They own all 28 pets in the nine-family roster well inside 50 hours, by which point they've made about 420 duplicate hatches. Gold income (about 2,500/h) also outruns the whole Gold shop within an hour.
3. **The place today gives every active player a piece every match, and about 88% of those pieces are Epic.** Eggs are awarded, not won, and Epic has become the common reward.

**The single biggest risk isn't the economy.** It's whether the chase feels as good as Huss Valley's, and no simulation can tell you that. P0 stays "fun with the shop closed".

### Decisions at a glance
| # | Decision | Verdict |
|---|---|---|
| 1 | Three fixed crossings, 30 players, 3 starting Catchers (1 per 10) | LOCK the structure; PROTOTYPE the Catcher count |
| 2 | Replace the place's "3 clean crossings in a row" end rule with exactly 3 crossings | REVISE (code) |
| 3 | Eggs are won: survive all 3 crossings, or snatch one | LOCK |
| 4 | **Snatch-back cap:** a Catcher who snatches keeps an egg at most one rarity above the egg they lost. Starting Catchers can keep up to Epic. | LOCK (replaces "one theft = an egg at the stolen rarity") |
| 5 | Physically banking stolen eggs | REJECT (no effect without counterplay) |
| 6 | Two thefts required | REJECT (still rewards early capture; adds frustration) |
| 7 | Evolution: crossing 1 → Rare always. Crossing 2 → Epic 10%, Legendary 2%. Final crossing → Rare to Epic 10%, Epic to Legendary 1%. | PROTOTYPE |
| 8 | First pet: the first won egg also grants a Common pet of a chosen family, and the egg is kept | LOCK |
| 9 | Recipes sized to hours, not to 3/4/3: Rare 26 (focus 33), Epic 23 (29), Legendary 10 (13) at 45 matches/h, shown as an incubator bar | REVISE |
| 10 | 3 Common eggs fuse into 1 Rare | LOCK |
| 11 | Rarity stat bonus (+1.5/3/4.5%) on distance or duration only, never recharge | PROTOTYPE (measured as invisible; see section 6) |
| 12 | Gold earn kept; Gold prices ×3 | REVISE |
| 13 | Earned Gems cut to about 31/h (Gems = win + first snatch, max 2 per match) | REVISE |
| 14 | Gem-paid focusing, sold eggs, sold abilities | REJECT for launch |
| 15 | Egg Index | DEFER |
| 16 | Ranked | DEFER |
| 17 | Cosmic tier | DEFER |

## 2. Critical flaws (most dangerous first)

1. **Surrender pays (brief's design).** See section 3. At base pressure a typical player who gives up in crossing 1 wins an egg 90% of the time, against 69% for honest play. A skilled player's expected egg value is higher by giving up (1.45 vs 1.34). At tight pressure giving up wins outright (1.47 vs 0.88).
2. **Pacing is broken by about 30× at the top end.**
   - The brief's evolution table makes 20.8% of surviving eggs Legendary, which is about 2.5 Legendary eggs per 30-player match.
   - With 3-egg Legendary recipes, the first Legendary pet arrives at a median of 0.76 h (`longterm.json`, base/typical, brief evolution + one-theft rule).
   - **The brief's Legendary recipe (3) is also cheaper than its Epic recipe (4).**
3. **The place's end rule contradicts both the GDD and the brief.**
   - `MatchLogic` runs crossings until 3 clean ones in a row, the last Runner's solo crossing, or no Runners.
   - In the simulation that averages 5–8 crossings. At base pressure Runners win only 10–22% of 12–16-player matches.
   - Egg levels reach 6–9. `TierConfig` names levels 7–9 "Legendary" and 10+ "Cosmic", while `EconomyConfig.MATERIAL_FOR_TIER` pays Epic. That is exactly the "never label a reward Legendary while granting unrelated material" rule the GDD forbids. (`code_end_rule.json`)
4. **Pieces are participation rewards in the place today.**
   - Every active player gets a piece: Runners bank their level when caught, and steals credit up to level 3. That's 30 pieces per 30-player match, about 88% of them Epic.
   - A theft takes nothing economically: the victim keeps their banked level and the thief gets a new piece.
5. **Common eggs have no use after the first pet** in the brief's recipes, so they pile up as dead inventory (about 30–200 by 50 h, depending on the rule).
6. **Currencies inflate.**
   - Gold is about 2,540/h for a typical player. The most expensive Gold item (2,400) takes 0.7 h from zero.
   - Gems are about 142/h earned. Every premium item (150–350) and an emote crate (250) costs 1–2.2 h of play.
   - So a 199 R$ pack of 500 Gems is worth about 3.5 h of free play. That's weak value for buyers and makes Gems feel abundant.
7. **Bots set the economy at low player counts.** NPCs top up to 20 Runners. While the game is small, most eggs will be stolen from or by bots, so bot difficulty is an economy setting.
8. **Rarity bonuses as proposed are invisible.**
   - A recharge bonus of 1.5–6% changes ability uses per match by under 0.02 (`cooldowns.json`).
   - A dash-distance bonus of up to +20% didn't change survival measurably in the chase model (`pet_power.json`).
   - Players may not notice it, so its value is mainly the label.

## 3. The surrender problem (Part 2)

**Setup:** in `job_focal`, one player out of 30 has a fixed skill and a strategy, and is never the starting Catcher. "Surrender at crossing c" means walking straight into the nearest Catcher during crossing c. Each cell is 1,200 independent matches (95% CI on egg chance about ±2.7 pts).

Value weights: Common 0.25, Rare 1, Epic 2, Legendary 4. The conclusion doesn't depend on these weights; section 7 repeats it with weights derived from hatch recipes.

Typical skill:

| Pressure | Strategy | P(egg) "1 theft" | Value "1 theft" | P(egg) Snatch-back | Value Snatch-back | Gold/match |
|---|---|---|---|---|---|---|
| loose | play honestly | 0.90 | **2.00** | 0.90 | **1.97** | 72 |
| loose | give up in crossing 1 | 0.62 | 0.87 | 0.62 | 0.16 | 31 |
| base | play honestly | 0.69 | 1.39 | 0.69 | **1.18** | 59 |
| base | give up in crossing 1 | **0.90** | 1.31 | 0.90 | 0.23 | 34 |
| base | give up in crossing 2 | 0.77 | 1.34 | 0.77 | 0.70 | 43 |
| tight | play honestly | 0.49 | 0.88 | 0.49 | **0.53** | 50 |
| tight | give up in crossing 1 | **0.98** | **1.47** | 0.98 | 0.25 | 35 |

"Snatch-back" here is the strict version: a snatch is capped at the rarity you lost, and starting Catchers are capped at Rare. The recommended "+1" version is checked in section 7.

**Who comes out ahead (base pressure, "1 theft" rule):**

- **The starting Catcher** wins an egg 96% of the time.
- **A Runner caught in crossing 1** wins one 89% of the time.
- **A Runner caught in crossing 2** wins one 75% of the time.
- **A Runner caught in crossing 3** never wins one, because conversion happens after the crossing and there's no crossing left.
- **A survivor** always wins one.
- **A Runner who plays honestly** wins one 69% of the time (`population.json`).
- **A player who gives up on purpose** does as well as someone caught early by accident: the surrender sims match the "caught in crossing 1" group within 1–2 points.
- **Skilled thieves** get more out of giving up. A skilled player averages 2.0 snatches after giving up in crossing 1, against 1.6 for a typical player.

**Conclusion:** the problem is real, and it gets worse as Catchers get stronger. It isn't caused by low effort; it's caused by the number of steal chances. A converted Catcher gets two crossings of steal chances against a crowd still carrying eggs. A survivor gets one egg.

**Why the Snatch-back cap works:**

- **It ties a Catcher's best possible egg to how long they survived,** so surviving is always worth more than giving up, at every pressure.
- **It doesn't make Catchers miserable.**
  - A Catcher who snatches still wins an egg, at nearly the same rate as before.
  - With "+1", someone caught holding a Rare can snatch an Epic.
  - Starting Catchers can snatch up to Epic, which puts their egg value at 0.71× a Runner's.
  - The strict version and "stolen eggs drop a rarity" fall to 0.25× for starting Catchers (`design_comparison.json`).
- **Gold also favours honest play.** Giving up costs about 40% of the match's Gold and Gems in every cell.

## 4. Simulation results (Part 4)

### Model
- **Arena:** a 2D field of 176 × 140 studs with 30 s crossings. Run speed is 31 for both roles.
- **Movement and tags:**
  - Runner side-dash: 58 studs/s for 0.16 s, 2 s cooldown.
  - Stab: 6.5-stud reach, 1 s cooldown.
  - Lunge: 46 studs/s for 0.2 s, then 50% speed for 0.7 s.
  - Catchers can't dash.
  - There's a 0.75 s Catcher hold and start protection at the beginning of each crossing.
- **Each player has:**
  - a reaction delay
  - dash timing error and a chance of dashing the wrong way
  - a chance of dodging a lunge
  - stab accuracy
  - how far ahead they read the field
- **Skill** is a made-up scale (−1 beginner, 0 typical, +1 skilled). Everyone in a lobby is drawn from N(0, 0.6).
- **Catchers coordinate** by claiming targets, with at most a soft 2 per Runner.
- **Conversion is delayed by default:** a caught Runner lies down and becomes a Catcher next crossing, as in the place.

### Match dynamics (`population.json`)
| Lobby | Starting Catchers | Pressure | Runners at C1 / C2 / C3 | Captures per crossing | Survive | Zero-survivor matches |
|---|---|---|---|---|---|---|
| 30 | 3 | loose | 27 / 26.2 / 25.1 | 0.8 / 1.1 / 2.0 | 86% | 0% |
| 30 | 3 | base | 27 / 24.5 / 20.0 | 2.5 / 4.6 / 7.8 | 45% | 0.2% |
| 30 | 3 | tight | 27 / 23.2 / 15.6 | 3.8 / 7.7 / 11.9 | 13% | 26% |
| 30 | 1 / 2 / 4 | base | | | 81% / 64% / 29% | |
| 30 | 3, immediate conversion | base | | | 52% | |
| 12 | 1 | base | | | 67% | |
| 16 | 2 | base | | | 46% | 0.9% |
| 24 | 2 | base | | | 56% | |

**What this shows:**

- **The number of starting Catchers is the strongest tuning knob.** At base pressure, going from 1 to 4 starting Catchers takes survival from 81% to 29%.
- **Immediate conversion doesn't raise pressure.** Fresh Catchers get up behind the Runner wave and can't catch up at equal speed, and it adds visual noise.
- **Crossings last 7–10 s,** so a full match cycle is about 65–70 s using the place's own timers.

### Egg rules: eggs per 30-player match at base pressure, brief's evolution table
| Rule | Eggs/match | Common / Rare / Epic / Legendary | P(egg) caught in crossing 1 | Starting Catcher |
|---|---|---|---|---|
| Runners only | 12.2 | 0 / 2.3 / 7.3 / 2.5 | 0 | 0 |
| 1 theft = egg | 20.7 | 0.4 / 6.8 / 10.5 / 3.0 | 0.89 | 0.96 |
| 2 thefts | 16.7 | 0.05 / 4.6 / 9.2 / 2.8 | 0.54 | 0.73 |
| Stolen egg drops a rarity | 20.3 | 4.4 / 5.4 / 7.9 / 2.5 | 0.89 | 0.83 |
| Snatch-back, strict | 20.7 | 2.6 / 8.2 / 7.3 / 2.5 | 0.89 | 0.96 |
| Banked theft | same as 1 theft | | | |
| The place today | 30.0 | 0.8 / 2.9 / 26.3 / 0 | 1.0 | 1.0 |

**Banked theft** (`banking.json`): every steal was banked, because nothing can stop a carrier. Banking without counterplay is a delay, not a decision.

**Keeping the first stolen egg instead of the best:** it changes the rarity mix, not how many players win an egg. At base pressure it turns about 1.8 Rare-or-better eggs per match into Commons.

**Visible Legendaries** (`visible_rarity_targeting.json`):
- If Catchers ignore rarity, a Legendary carried into crossing 3 is stolen 39% of the time.
- If they hunt it hard, 49%. A Rare is stolen 25% of the time.
- So visible rarity does create a "protect the gold egg" moment without making Legendaries impossible to keep.

### What the sim can't show
- **Skill barely matters in my model.** Beginners win an egg 66% of the time and skilled players 69%. Real skill gaps are certainly larger, so treat every beginner-vs-skilled number here as a floor on the gap, not an estimate of it.
- **The model has no friends, no voice chat, no latency and no map geometry.**

## 5. Recommended rules (Parts 4B–4E)

### Egg acquisition: Snatch-back (+1)
1. **Survive all three crossings:** you keep your egg at its evolved rarity.
2. **Snatch an egg as a converted Catcher:** you win an egg at the snatched rarity, capped at one rarity above the egg you were carrying when caught. Caught with a Common (crossing 1): up to Rare. Caught with a Rare: up to Epic. Caught with an Epic: up to Legendary.
3. **Snatch as a starting Catcher:** capped at Epic.
4. **One egg per player per match;** keep the best one.
5. **No snatch and no survival:** Gold and XP only.
6. **The UI says it plainly,** e.g. "You snatched a LEGENDARY! Your cap: EPIC (you lost a Rare)." The cap is visible on the Catcher's HUD.

**Results with the tuned evolution table** (`recommended_economy.json`):
- A typical player wins an egg in 66% of matches.
- A beginner's chance of five eggless matches in a row is 0.45%.
- Honest play is worth 1.9× giving up in crossing 1.
- A starting Catcher's eggs are worth 0.71× a Runner's.

### Evolution
| Crossing | Rare | Epic | Legendary |
|---|---|---|---|
| 1 | Common becomes Rare (100%) | | |
| 2 | Rare stays 88% | Rare → Epic 10% | Rare → Legendary 2% |
| 3 (final) | Rare stays 90% | Rare → Epic 10%; Epic stays 99% | Epic → Legendary 1% |

**How it plays out:**

- **Every crossing visibly changes the egg.** The level always rises, and the place already tints each level. Rarity doesn't always rise.
- **Legendaries are mostly born in crossing 2,** so one is in play during the final crossing in about 39% of matches (0.39 per match).
- **A surviving egg ends** Rare 79%, Epic 18.7% or Legendary 2.1% (exact, from the table).
- **Across all eggs** (typical player, Snatch-back +1): Common 2%, Rare 83%, Epic 14% and Legendary 1.2%.

**Alternatives rejected:**
- The brief's table: 21% of survivors' eggs are Legendary.
- "Epic-heavy": 23%.
- Deterministic: Legendary for every survivor.
- The place's levels: Epic for every survivor, with no Legendary.

### First pet
**Rule:** the first won egg also grants a Common pet of a family the player picks, and the egg is kept.

| Option | Median time to first pet | 90th percentile |
|---|---|---|
| Pet on first egg (any option that keys off it) | 1 match | about 2–3 matches |
| Two eggs | 2–3 matches | about 4 matches |
| A separate "3 Common eggs" recipe | 4–5 hours | over 8 hours |

The last option is unacceptable.

Giving the pet while keeping the egg costs almost nothing, and it doubles the moment: you win an egg and you get your first ability. That fits endowed progress (Nunes & Drèze, 2006). The GDD's "first pet after two matches" target is met.

### Incubation
**Recipe size:** recipes are set so a typical player's first pet of each rarity lands at about 1 h (Rare), 5 h (Epic) and 25 h (Legendary). That's a design target, and you can choose different ones. At 45 matches/h (65–70 s cycles plus lobby time) that gives:

| Rarity | Random | Focused (+25%) |
|---|---|---|
| Rare | 26 | 33 |
| Epic | 23 | 29 |
| Legendary | 10 | 13 |

**Common eggs:** 3 Common eggs fuse into 1 Rare.

**The numbers are big, so show progress as a filling incubator bar ("Rare nest 18/26"), not a count.** If the match cycle moves back toward the GDD's 135 s, everything halves: Rare 13, Epic 12, Legendary 5.

**Careers through the incubator** (300 careers each, resampled):

| | First Rare pet | First Epic pet | First Legendary pet | Pets owned at 50 h | Duplicate hatches at 50 h |
|---|---|---|---|---|---|
| Typical | 1.3 h (90th pct 1.5) | 6.2 h (7.6) | 33 h (45.5) | 17 of 27 | 44 |
| Beginner | 1.4 h | 7.0 h | 35 h; 9% none by 50 h | | |
| Skilled | 1.4 h | 5.8 h | 36 h | | |

Pets owned and duplicates are for the full nine families. In my model skill hardly changes egg income; see the limits in section 4.

**Focusing:**
- Keep it as a surcharge in eggs (+25%), never in Gems at launch.
- The first Legendary is focused by default, which is why it lands later than the random-recipe target.

**Duplicates:**
- About 44 by 50 h. They need a home, such as cosmetic mastery stars.
- Don't let them multiply stats (that's in the GDD already).

## 6. Pet balance (Part 4F)

**Recharge bonus:** with Brake (10 s), Scout (18 s) and Decoy (20 s), ability uses per three-crossing match are 2.97, 1.99 and 1.98 at Common. They are 2.97, 1.99 and 1.98 at Legendary (+4.5%) as well. Even +10% adds at most 0.04 uses (`cooldowns.json`). The thresholds don't line up with the match's timing.

**Distance bonus:**
- A dash 3–20% longer didn't change survival in the chase model. Survival stayed at 40–41% (95% CI ±1 pt, about 9,000 Runner samples per level, `pet_power.json`).
- In this model escapes are decided by timing and Catcher positioning, not the last couple of studs.
- Real players might exploit precision the brains don't, so read this as "small", not "zero".

**Feedback loop:** stronger pets → more eggs → stronger pets. With the effect this small, the loop is negligible.

**Recommendation:**
- If you keep rarity bonuses (you prefer them), put them on duration or distance only, and keep them small (≤5% at Legendary). Show them as flavour ("Legendary Decoy lasts 3.15 s").
- Expect them to feel like status, not power.
- Make the visual and audio upgrade with rarity loud, because that's what players will actually perceive.
- If Ranked ever happens, normalise them there.

## 7. Comparing complete designs (Part 7)

All five designs are scored on the same 2,000 simulated matches (base pressure, tuned evolution). Each egg's value is the hours of progress it's worth under the recommended recipes (Rare 0.038 h, Epic 0.22 h, Legendary 2.5 h, Common a third of a Rare). Source: `design_comparison.json`.

| Design | Beginner egg rate | Honest ÷ give-up value | Starting Catcher ÷ Runner | Eggs/match | Legendary share |
|---|---|---|---|---|---|
| A Accessible (1 theft = egg) | 0.66 | **0.98 ✗** | 1.01 | 20.7 | 2.0% |
| B Competitive (Runners + 2 thefts) | 0.51 | **1.12 ✗** | 1.04 | 16.7 | 2.1% |
| C High-stakes (banking + steals drop a rarity) | 0.65 | 3.72 | **0.25 ✗** | 20.3 | 1.2% |
| **D Snatch-back (+1)** | 0.66 | 1.91 | 0.71 | 20.7 | 1.2% |
| The place today | 1.00 | 1.54 | 0.66 | **30 ✗** (participation) | 0% |

**Hard constraints come first.** These are taken from your brief:
- Playing honestly must clearly beat giving up (more than 1.2×).
- Catchers must not be miserable (a starting Catcher gets at least half a Runner's value).
- Eggs must be won, not given for showing up.

Only D passes all three.

**Then the weightings, for completeness:**

| Weighting | Rank 1 | D's rank |
|---|---|---|
| Balanced | A | 3rd |
| Growth | The place today | 2nd |
| Integrity | C | 3rd |
| Hardcore | B | 3rd |

D is never first and never last. Weightings alone pick whichever design matches their bias, which is why the constraints decide here.

**Established by maths vs needing real tests:**
- **Established:** the exploit ordering of the egg rules holds at all three pressures. The Snatch-back rule removes the give-up advantage at all three.
- **Needs real players:**
  - whether the cap feels fair once explained
  - whether a 66% egg rate feels "won"
  - whether losing a Legendary feels like good tension or like being robbed

## 8. Research (Part 3)

Labels:
- **[V]** I or a helper read the source.
- **[S]** secondary.
- **[H]** a hypothesis, not a finding.

### Huss Valley
- **[V] Size:** universe 10764627709, owned by the group "Huss Valley Official", created 31 Aug 2026. On 16 Oct: 95,644 playing, 132,591,554 visits, about 88% upvotes, 30-player servers. Source: `games.roblox.com/v1/games?universeIds=10764627709`.
- **[S] Peak:** RoWatcher reports a 174K concurrent-player peak in Oct 2026.
- **[V] Passes:** VIP 799 R$ (+25% XP, tag, dagger) and 2x EXP 199 R$. Source: Roblox game-passes API.
  - So the place's VIP at 499 with +25% XP mirrors this at a lower price.
- **[V] Developer products:**
  - **It sells permanent abilities for Robux,** 479–1,299 R$, e.g. Cloak (invisible 3 s) and Big Dagger (double reach). **Huss Valley sells power. Hatch or Snatch's "eggs only, never sold" is a deliberate difference, and it gives up Huss Valley's main Robux lever.**
  - Coins and Gems packs.
  - Paid crates at 399 R$ for 1, with odds shown in game.
  - Spins and quest skips.
- **[S] Gameplay:** one Chaser, Runners cross, the caught become Chasers, and the last survivor wins. Gems unlock abilities; Coins buy consumables. Source: Beebom's beginner guide.
- **Not verified:** round length, crate odds and the XP curve.

### Roblox platform
- **[V] Discovery signals:** the most important are play-through rate, first-play bounce, play days per user and playtime per user (capped at 60 min/day). Important but secondary: co-play days, qualified sessions, spend days and Robux spent per user. Only users who arrived organically from Home count. Spend matters, but it ranks below retention. Source: create.roblox.com/docs/discovery.
- **[V] Paid random items:**
  - Odds must be shown and total 100%.
  - Items bought with purchasable currency, such as Gems, count.
  - Anything that changes odds counts too.
  - Users with `ArePaidRandomItemsRestricted` need an alternative.
  - Source: create.roblox.com/docs/production/monetization/paid-random-items.
  - The emote crate (Gems) is in scope. The place already checks PolicyService and shows odds (`EmoteService`).
  - **Hatching with earned eggs is not paid random** as long as eggs and focus are never bought. Keep it that way.

### Psychology
- **[V/S] Self-determination theory:** autonomy, competence and relatedness in games predict enjoyment and wanting to keep playing (Ryan, Rigby & Przybylski, 2006, *Motivation and Emotion* 30).
  - Focusing gives autonomy. The cap rule protects competence ("I survived, so I earned more").
- **[S] Loss aversion:** losses weigh more than equal gains (Kahneman & Tversky, 1979).
  - Losing a carried Legendary will sting.
  - **[H]** The sting is fine because the egg was never banked, and the cap lets the loser win back up to Legendary from an Epic.
- **[V] Endowed progress:** artificial early progress speeds goal completion (Nunes & Drèze, 2006, JCR 32). This supports the first pet arriving on the first win.
- **[S] Goal gradient:** people speed up near a reward (Kivetz, Urminsky & Zheng, 2006, JMR 43). This supports the incubator bar.
- **[V] Loot boxes:** spending on them is linked to problem-gambling severity (Zendle & Cairns, 2018, PLOS ONE). This is correlational. **[H]** It's a reason to keep paid randomness to cosmetics (the emote crate) with odds shown, and never on eggs.
- **[V] Pay to win:** players judge some purchases "pay to cheat", and payers and non-payers disagree about fairness (Freeman et al., 2022, CHI PLAY).
- **[S] Near misses:** these raise the desire to play, but only when the player feels in control (Clark et al., 2009, *Neuron*).
  - "You lost a Legendary 2 studs from safety" is that kind of moment.
  - **[H]** It's healthy here because the outcome is skill-driven, not a slot machine.

## 9. Psychological audit (Part 5): short answers
1. **Is winning worth the risk of losing?** Yes, if the loss can be partly won back the same match. That's the Snatch-back cap.
2. **Losing a rare egg: tension or frustration?** Tension, as long as it happens to around 40% of Legendary carriers or fewer, and the Catcher who took it is shown. Stronger Catcher pressure makes it frustration.
3. **How often should meaningful rewards land?** An egg in most matches (66%). A hatch about every 30–60 min early, slowing later. A rarity jump (first Epic or Legendary pet) at 6 h and 33 h.
4. **Should the first pet come right after the first egg?** Yes, on the first won egg.
5. **What motivates most?** **[H]** Visible rarity (the Legendary egg everyone chases) and social prestige beat efficiency. The measured stat effects are invisible, so lean on looks.
6. **Is multi-egg incubation anticipation or grind?** Anticipation if it's a bar with a reveal, grind if it's a 26-item counter.
7. **Does focusing add investment?** Yes, it's the autonomy lever. Keep it cheap (+25%).
8. **Is the Egg Index worth it?** Not yet. The rarity chase plus nine families is enough content for launch.
9. **Can Catchers enjoy the match without undermining survivors?** Yes. Snatching still pays, and every snatch also pays Gold and XP.
10. **Will players queue again after a loss?** Likely. A 65-second cycle plus a near-miss line plus "your cap next match" gives a reason to run it back.

## 10. Gold and Gems (Part 6)

### Gold (earn only)
- Keep the formula. A typical player earns about 56 Gold per match and 2,540/h, including level-up pay.
- **Multiply Gold prices by 3:**
  - consumables 120–180
  - emote 1,500
  - case 2,700
  - entrance 4,200
  - weekly colourway 7,200
- That puts the weekly item at about 3 h, roughly two sessions.
- Keep rotating stock, because that's the real sink.

### Gems (earned + Robux)
- **Cut earned Gems to "1 for a win + 1 for the first snatch", max 2 per match.** That's about 31/h, down from 142/h.
- Level-up Gems (10 every 5 levels) stay.
- **What it costs at 31/h:**
  - premium trail (150): about 5 h of play
  - crate (250): about 8 h
  - Gem pack 500 for 199 R$: about 16 h of play, which is now real value
- **Sell (cosmetic only):** premium trails, ability colour packs, hatch ceremonies, pet showcase, egg-case skins, and the emote crate (odds shown).
- **Don't sell:** eggs, focus, abilities, rarity.

### Purchases
- **Recurring:** Gem packs, emote crate.
- **Permanent:** passes, premium cosmetics.

### Visibility and first session
- **Cosmetics others see:** egg trails, cases, entrances and ability colours are all seen by other players. That's good.
- **First session:** no shop prompts before the first pet.

### Discovery
- Spend counts, but play-through, bounce, play days and playtime come first.
- **[H]** A tighter economy that makes the first hour feel earned is better for ranking than more Robux per user.

## 11. The first 15 minutes (Part 5/14)
1. **0:00** Spawn in the lobby. The next match starts in 15 s. No shop, no pet.
2. **0:20** First match as a Runner. Bots fill the lobby if needed. The egg turns Rare after crossing 1, with a big pop. Caught in crossing 2 holding a Rare? The HUD says "SNATCH ONE BACK (up to EPIC)".
3. **1:30** Results: "You snatched a RARE egg!" Then **First pet! Pick your ability:** Double Dash, Decoy or Scout. The pet appears beside you.
4. **2–6 min** Matches 2–5 with the ability. The incubator bar fills ("Rare nest 4/26"). XP levels 2 → 4, each paying a little Gold.
5. **about 8 min** First Gold purchase becomes affordable (a 120–180 Gold trail). Shown in the lobby, never mid-match.
6. **about 12 min** The first Legendary egg is visible in someone's hands during a final crossing. Everyone chases it. That's the moment to sell the dream.
7. **15 min** Next goal on screen: "Rare pet in about 45 min" plus today's weekly item.

## 12. Development priorities (Part 11)
1. **Now (code):**
   - exactly 3 crossings (drop the clean-streak end rule)
   - the 1-per-10 starting Catcher table
   - `MAX_PLAYERS` 30
   - the Snatch-back cap in `MatchLogic.capture` / `computeResults`
   - remove the participation piece (no egg without survival or a snatch)
   - Legendary tier with the tuned evolution table
   - fix `TierConfig` naming so levels never claim a rarity they don't pay
2. **Next:**
   - first-pet-on-first-egg
   - recipe bar UI and the new recipe sizes
   - Common fusion
   - Gold price ×3, Gems formula
3. **Later:** Egg Index, Cosmic, Ranked, Gem focusing (if ever), more families (waves 2–3).

## 13. Validation plan (Part 12)

Four tests, each with a pass line:

| # | Test | Measure | Pass |
|---|---|---|---|
| 1 | Pressure check: 10+ real 20–30-player matches, telemetry on | Runner survival over 3 crossings | 35–55% (if not, change starting Catchers 2–4) |
| 2 | Surrender check: same matches | Egg value per match, players caught in crossing 1 vs survivors | Caught-in-crossing-1 group earns less than half the survivors' value |
| 3 | First session: 20+ new players | First pet in the first 3 matches; still playing at 10 min | 90% get a pet within 3 matches; 70% still playing at 10 min |
| 4 | Loss feel: 5-question survey after matches where a Legendary was stolen | "Felt fair" (1–5) from victim and thief | Victim median ≥ 3; thief ≥ 4 |

A 20–40 person test finds broken things; it can't measure retention lifts. Soft launch handles that, as the GDD says.

## 14. What the GDD v0.4 says vs what supersedes it
| GDD v0.4 | Now |
|---|---|
| 8–16 players | About 30 (Hunter, 16 Oct) |
| Every active match ≥ Common piece | Eggs are won only (the brief, and this audit) |
| Rarity from level, L4 = Epic, Crowned deferred | Random evolution with Legendary at launch (the brief), using the tuned table |
| Recipes 2/3/5 | Sized to hours (section 5) |
| 135 s cycle | About 65 s measured in the place; rates doubled |
| Gems 64/h | 142/h measured; cut to about 31/h |
| Rarity stats 0% test | Small distance or duration bonus allowed; measured as invisible |

## 15. If I were investing my own money

> If I were investing my own money and development time, I'd build this version of Hatch or Snatch:
>
> - **The match:** a 30-player, exactly-three-crossing chase. Three starting Catchers, tuned so about 45% of Runners survive.
> - **The eggs:** every crossing visibly evolves your egg. Legendaries are born only in crossing 2, so every final crossing has a gold egg worth chasing.
> - **The rule:** survive to keep your egg, or snatch one back, up to one rarity above what you lost.
> - **The first pet:** the first egg you win also gives you a chosen ability.
> - **The incubator:** progress fills a bar, paced to hours rather than to a fixed egg count.
> - **The shop:** Gold and Gems buy only looks, and Robux never buys an egg.
>
> **The reasons:**
> - The format has proven demand right now (Huss Valley).
> - The Snatch-back cap is the only rule tested here that keeps surviving worth more than giving up while still paying Catchers.
> - The pacing fixes turn a progression that would be finished in an afternoon into one that lasts weeks.
> - Not selling power is what lets the egg chase mean something.

## Limits
- The brains and the skill scale are invented, so skill hardly matters in the model. "Pressure" is a stand-in for real catching skill.
- Careers are resampled from simulated matches and treat matches as independent: no learning, no tilt, no parties.
- Bots aren't modelled separately.
- 45 matches/h is an assumption: the measured 65–70 s cycle plus about 15% lobby time.
- Nothing here measures fun.
