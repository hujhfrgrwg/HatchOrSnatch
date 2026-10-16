---
tags: [design, economy, audit]
updated: 2026-10-16
ticket: HOS-ECON-001
---
# Hatch or Snatch: economy and design audit

This answers the ChatGPT audit brief Hunter shared on 16 Oct, using the real repo: GDD v0.4, the decisions note, and the place's scripts as snapshotted in `ScriptHistory` on the PR #1 branch. The numbers come from a new multiplayer simulation in `tools/sim/`. Raw results are in `docs/economy-audit/results/`, and every run has a fixed seed listed in `results/manifest.json`.

**Match setup:** about 30 players and **one starting Catcher** (both corrections came from Hunter on 16 Oct).
- Everything below uses that setup unless it says otherwise. 12, 16 and 24 players are kept as comparisons.
- An earlier version of this report assumed 3 starting Catchers. Every simulation was re-run for one, and that version is in git history.
- The final calls are in [[Economy Decisions]] (`Design/Economy Decisions.md`). Hunter asked Claude to make them from this evidence.

## Latest revision: normal-strength Catcher (Hunter, late 16 Oct)
Hunter ruled that the starting Catcher must not be stronger than other players, and asked for no more sims. Sections 2–8 below model one *strong* Catcher, tuned to about 47% survival. They still show how the rules behave when catching is hard. The decisions now use the normal-strength results that were already in hand:

**Survival with one normal-strength Catcher:**

| Setup | Survive |
|---|---|
| 30 players, 3 crossings | about 81% (`population.json`, "old_base") |
| 12–30 players | 67–81% (first audit run, git history) |
| 2 Catchers from crossing 1 (a caught Hero) | about 64% |
| 4 crossings, 30 players | 64% |
| 4 crossings, 12–30 players | 48–64% |
| 5 crossings, 12–30 players | 29–37%, with up to 21% of small matches having no survivors |

The 4- and 5-crossing figures come from a quick check at the same strength.

**Hero runs against a normal-strength Catcher:** a lone Runner makes it 53% of the time as a beginner, 59% as a typical player and 89% as a skilled one (`hero.py` at pressure 1.6, first run). No extra protection is needed.

**Which egg rule:** the nearest measured point is one Catcher at 65% survival (`robustness_by_pressure.json`, "loose").
- The +1 Snatch-back cap passes there: honest play is worth 1.32× giving up, and the starting Catcher gets 0.68× a Runner's value.
- The strict cap leaves the lone Catcher at 0.44×.
- So +1 is back as the rule.

**What changed in [[Economy Decisions]]:**
- no Catcher-strength tuning, and bot fill stays at 20
- a 4th crossing is the lever if matches feel too safe
- a caught Hero joins the Catcher in crossing 1
- the +1 cap
- recipes scaled up by estimate: Rare about 31, Epic about 33, Legendary about 19

## 0. What I think of the prompt itself

**What it gets right:**
- It asks for an interacting multiplayer model rather than independent win chances.
- It tests deliberate surrender directly.
- It asks for percentiles, not just averages.
- It separates verified facts from guesses.
- It forces a decision at the end.

All five are what stops this kind of exercise turning into fluff.

**Where it falls short:**
- **It assumes the game isn't built.** Most of it is. The place already has the chase, eggs, materials, the incubator, three abilities, Gold, Gems, live Gem packs, passes, an emote crate and XP. The real question is what the place does today and what has to change.
- **It describes a design that is neither the GDD nor the code:** Legendary eggs, random evolution, eggs that are "won, not awarded", and 3/4/3 recipes. Its key numbers were also out of date: about 12 players and 2–3 minute matches. Real lobbies are about 30 players, and the place's cycle is about 65 seconds.
- **The "76.5%" figure comes from a simulation that isn't in the repo,** so it can't be checked. I rebuilt the question from scratch (section 3).
- **It asks for things no simulation can supply,** such as "psychological enjoyment" and "monetization compatibility". I scored those as stated hypotheses and kept them apart from measured results.
- **It never names the biggest unknown: how good catching is compared with escaping.** That one number decides survival rates, the surrender incentive and egg supply, and only playtests can set it. With one starting Catcher it matters even more. I ran everything at three Catcher strengths (loose, base, tight) instead of pretending to know it.

## 1. Executive verdict

**Yes, pursue it, but fix the economy before tuning anything else.** The format has proven demand. Huss Valley, the game this one is modelled on, had 95,644 people playing on 16 Oct 2026 and 132.6 million visits, and it was only created on 31 Aug 2026 (Roblox's public API; verified, see section 9).

The economy as specified has four serious problems, and all of them can be fixed:

1. **With one starting Catcher, getting caught early pays better than playing to survive** under "one theft = one egg". It also pays under the softer "snatch up to one rarity above what you lost" rule (section 3). Only the strict Snatch-back cap fixes this: a Catcher can keep an egg up to the rarity they lost, not above it.
2. **One Catcher only works if catching is strong.**
   - At the Catcher strength the 3-Catcher runs assumed, one Catcher lets 81% of Runners survive. A Catcher that strong only produces the target 40–55% survival when there are about 30 players. Smaller lobbies collapse: 16 players survive 14% of the time, 12 players 7%.
   - So bots must fill every match to about 30, and the Catcher's tools are the main tuning knob (section 4).
3. **Rewards arrive far too fast.** The place runs a match cycle of about 65 s, not the 135 s the GDD assumed. Under the brief's 3/4/3 recipes, a typical player hatches their first Legendary pet in about 40 minutes, and Gold income (about 2,700/h) outruns the whole Gold shop within an hour.
4. **The place today gives every active player a piece every match, and about 98% of those pieces are Epic.** Eggs are awarded, not won.

**Hero or Chicken fits Hatch or Snatch,** with two changes so it doesn't wreck the match (section 7).

**The single biggest risk isn't the economy.** It's whether the chase feels as good as Huss Valley's, and no simulation can tell you that. P0 stays "fun with the shop closed".

### Decisions at a glance
Reasons for each are in [[Economy Decisions]].

| # | Decision | Verdict |
|---|---|---|
| 1 | Exactly 3 crossings, about 30 players, one starting Catcher | LOCK |
| 2 | The starting Catcher has normal strength (Hunter). Expect about 80% survival; a 4th crossing is the lever if matches feel too safe | LOCK |
| 3 | Bot fill stays at 20 Runners | KEEP |
| 4 | Replace the place's "3 clean crossings in a row" end rule with exactly 3 crossings | REVISE (code) |
| 5 | Eggs are won: survive all 3 crossings, or snatch one | LOCK |
| 6 | **Snatch-back cap (+1):** a snatched egg can be at most one rarity above the egg you lost. The starting Catcher is capped at Epic. | LOCK (replaces "one theft = an egg at the stolen rarity") |
| 7 | Hero or Chicken at match start: the Catcher picks a player, that player chooses. No extra protection; a caught Hero joins the Catcher in crossing 1 | LOCK |
| 8 | Physically banking stolen eggs; needing two thefts | REJECT |
| 9 | Evolution: crossing 1 → Rare always. Crossing 2 → Epic 10%, Legendary 2%. Crossing 3 → Rare to Epic 10%, Epic to Legendary 1%. | LOCK |
| 10 | First pet: the first won egg also grants a Common pet of a chosen family, and the egg is kept | LOCK |
| 11 | Recipes sized to hours, shown as an incubator bar: estimated Rare 31, Epic 33, Legendary 19 at normal strength (24 / 19 / 11 measured for a strong Catcher) | REVISE |
| 12 | 3 Common eggs hatch a missing Common species, then fuse into 1 Rare once all five are owned | LOCK |
| 13 | No rarity stat bonus at launch; rarity changes looks only (revised after the cofounder roster handoff) | LOCK (measured as invisible; see section 6) |
| 14 | Gold earn kept; Gold prices ×3 | REVISE |
| 15 | Earned Gems cut to about 30/h (Gems = win + first snatch, max 2 per match) | REVISE |
| 16 | Gem-paid focusing, sold eggs, sold abilities | REJECT for launch |
| 17 | Egg Index, Ranked, Cosmic tier | DEFER |

## 2. Critical flaws (most dangerous first)

1. **Surrender pays.** See section 3. With one starting Catcher, a typical player who gives up in crossing 1 wins an egg 99.8% of the time, against 66% for honest play. Under "one theft = one egg", giving up in crossing 2 is worth 1.28× honest play at base strength, and more at tight.
2. **One Catcher plus a fixed Catcher strength breaks small lobbies.** The share caught depends on how many Runners a single Catcher wave can reach. Tune it for 30 and a 12-player match ends with no survivors 72% of the time. Tune it for 12 and a 30-player match is a walk (section 4).
3. **Pacing is broken.**
   - The brief's evolution table makes 21% of surviving eggs Legendary, about 2.8 per 30-player match.
   - With 3-egg Legendary recipes, the first Legendary pet arrives at a median of 0.7 h (`longterm.json`, base/typical, brief evolution + one-theft rule).
   - **The brief's Legendary recipe (3) is cheaper than its Epic recipe (4).**
4. **The place's end rule contradicts both the GDD and the brief.**
   - `MatchLogic` runs crossings until 3 clean ones in a row, the last Runner's solo crossing, or no Runners.
   - With one Catcher strong enough to matter, a crossing is almost never clean. So matches run 4–5 crossings and end with everyone caught: Runners win 0–1.5% of matches (`code_end_rule.json`).
   - `TierConfig` also names egg levels 7–9 "Legendary" and 10+ "Cosmic" while `EconomyConfig.MATERIAL_FOR_TIER` pays Epic. The GDD forbids that kind of label.
5. **Pieces are participation rewards in the place today.** Every active player gets a piece: Runners bank their level when caught, and steals credit up to level 3. That's 30 pieces per 30-player match, about 98% of them Epic, and a theft takes nothing from the victim.
6. **Common eggs have no use after the first pet** in the brief's recipes. Under the cap they're 9% of all eggs, about 130 by 50 h.
7. **Currencies inflate.**
   - Gold runs about 2,700/h for a typical player. The most expensive Gold item takes 0.7 h from zero.
   - Gems run about 151/h earned. Every premium item and the emote crate costs 0.8–2 h of play.
   - So a 199 R$ pack of 500 Gems is worth about 3.3 h of free play: weak value for buyers.
8. **Rarity bonuses as proposed are invisible.**
   - A recharge bonus of 1.5–6% changes ability uses per match by under 0.02 (`cooldowns.json`).
   - A dash-distance bonus up to +20% didn't change survival measurably (`pet_power.json`).

## 3. The surrender problem (Part 2)

**Setup:**
- In `job_focal`, one player out of 30 has a fixed skill and a strategy, and is never the starting Catcher.
- "Surrender at crossing c" means walking straight into the Catcher during crossing c.
- Each cell is 1,200 independent matches (95% CI on egg chance about ±2.7 pts).
- Value weights here are Common 0.25, Rare 1, Epic 2 and Legendary 4, with the brief's evolution table. Section 8 repeats the test with recipe-based weights and the tuned table.

Typical skill:

| Strength | Strategy | P(egg) "1 theft" | Value "1 theft" | Value Snatch-back +1 | Value Snatch-back (strict) | Gold/match |
|---|---|---|---|---|---|---|
| loose | play honestly | 0.81 | **1.75** | **1.72** | **1.63** | 67 |
| loose | give up in crossing 1 | 0.98 | 1.56 | 0.98 | 0.25 | 35 |
| loose | give up in crossing 2 | 0.93 | 1.72 | 1.50 | 0.90 | 46 |
| base | play honestly | 0.66 | 1.41 | 1.32 | **1.19** | 61 |
| base | give up in crossing 1 | **1.00** | 1.68 | 1.00 | 0.25 | 35 |
| base | give up in crossing 2 | 0.97 | **1.80** | **1.58** | 0.93 | 46 |
| tight | play honestly | 0.53 | 1.13 | 1.04 | 0.88 | 56 |
| tight | give up in crossing 1 | **1.00** | 1.84 | 1.00 | 0.25 | 35 |
| tight | give up in crossing 2 | 0.97 | **1.92** | **1.64** | 0.92 | 46 |

**Who comes out ahead (base strength, "1 theft" rule, `population.json`):**
- **The starting Catcher** wins an egg 99.97% of the time and averages 4.1 snatches per match.
- **A Runner caught in crossing 1** wins an egg 99% of the time.
- **A Runner caught in crossing 2** wins one 96% of the time.
- **A Runner caught in crossing 3** never wins one, because there's no crossing left to snatch in.
- **A survivor** always wins one, and **an honest Runner** wins one 67% of the time.
- **Skilled players** get more out of giving up early: 3.7 snatches against 2.8 for a typical player.

**Why it's worse with one Catcher:** a lone Catcher has to be strong, so anyone who becomes a Catcher early snatches almost every time. A converted Catcher gets one or two crossings of steal chances against a crowd still carrying eggs. A survivor gets one egg.

**Why the strict Snatch-back cap is the fix:**
- **It ties a Catcher's best possible egg to how far they got.** Caught in crossing 1 while holding a Common, you can only snatch a Common. Caught in crossing 2 holding a Rare, you can snatch up to Rare.
- **The softer "+1" version fails now.** With 3 Catchers it was the recommendation. With one, a player caught in crossing 2 can snatch an Epic, and that beats honest play.
- **It still pays Catchers.** They win an egg at the same rate, and Commons fuse into Rares (3 → 1).
- **Gold also favours honest play.** Giving up costs 25–45% of the match's Gold in every cell.
- **The strict cap passes at every Catcher strength,** but only just when Catchers are strong. See section 8 for the margins.

## 4. Simulation results (Part 4)

### Model
- **Arena:** a 2D field of 176 × 140 studs with 30 s crossings. Run speed is 31 for both roles.
- **Movement and tags:**
  - Runner side-dash: 58 studs/s for 0.16 s, 2 s cooldown.
  - Stab: 6.5-stud base reach, 1 s cooldown.
  - Lunge: 46 studs/s for 0.2 s, then 50% speed for 0.7 s.
  - Catchers can't dash.
  - Each crossing opens with 0.75 s of protection.
- **Each player has:** a reaction delay, dash timing error and a chance of dashing the wrong way, a chance of dodging a lunge, stab accuracy, and a look-ahead distance.
- **Skill** is a made-up scale (−1 beginner, 0 typical, +1 skilled), with lobbies drawn from N(0, 0.6).
- **Catcher strength ("pressure")** raises Catcher accuracy and reach and lowers Runner reactions.
  - One starting Catcher needs far more of it than three did. Base is 2.6 on the model's scale, against 1.6 for the 3-Catcher runs.
  - In the model that's about 45% more tag reach plus faster Catcher reactions.
- **Catchers coordinate** by claiming targets.
- **Conversion is delayed by default:** a caught Runner lies down and becomes a Catcher next crossing, as in the place.

### Match dynamics (`population.json`, 30 players, one starting Catcher)
| Catcher strength | Runners at C1 / C2 / C3 | Captures per crossing | Survive | Zero-survivor matches |
|---|---|---|---|---|
| loose | 29 / 27.7 / 24.9 | 1.3 / 2.8 / 5.9 | 65% | 0% |
| base | 29 / 27.3 / 23.3 | 1.7 / 4.0 / 9.8 | 47% | 0.1% |
| tight | 29 / 27.2 / 22.3 | 1.8 / 4.9 / 13.4 | 31% | 1% |
| the 3-Catcher runs' strength | | 0.8 / 1.7 / 3.0 | 81% | 0% |
| base, immediate conversion | | | 50% | |
| base, 2 starting Catchers | | | 9% | 42% |
| base, 3 starting Catchers | | | 0.7% | 91% |

**Lobby size at base strength** (one Catcher):

| Players | 12 | 16 | 24 | 30 |
|---|---|---|---|---|
| Survive | 7% | 14% | 35% | 47% |
| Zero-survivor matches | 72% | 40% | 1% | 0.1% |

**What this shows:**
- **With one Catcher, the second Catcher is the cliff.** Anything that adds a Catcher before crossing 1 takes survival from 47% to 9%. That's why a caught Hero must not join crossing 1 (section 7).
- **Lobby size matters as much as Catcher strength.** Fill with bots to 30 so every match plays like the tuned one.
- **Immediate conversion doesn't raise pressure.** Fresh Catchers get up behind the Runner wave.
- **Crossings last about 6.5 s,** so a full match cycle is about 62–65 s using the place's own timers.

### Egg rules: eggs per 30-player match at base strength, brief's evolution table
| Rule | Eggs/match | Common / Rare / Epic / Legendary | P(egg) caught in crossing 1 | Starting Catcher |
|---|---|---|---|---|
| Runners only | 13.6 | 0 / 2.6 / 8.1 / 2.8 | 0 | 0 |
| 1 theft = egg | 20.0 | 0 / 5.1 / 11.5 / 3.5 | 0.99 | 1.0 |
| 2 thefts | 18.6 | 0 / 4.3 / 10.9 / 3.4 | 0.93 | 0.99 |
| Stolen egg drops a rarity | 20.0 | 2.5 / 6.0 / 8.8 / 2.8 | 0.99 | 0.98 |
| Snatch-back, strict | 20.0 | 1.7 / 7.4 / 8.1 / 2.8 | 0.99 (all Common) | 1.0 |
| Snatch-back +1 | 20.0 | 0 / 5.9 / 11.3 / 2.8 | 0.99 | 1.0 |
| The place today | 30.0 | 0 / 0.6 / 29.4 / 0 | 1.0 | 1.0 |

- **Banked theft** (`banking.json`): every steal was banked, because nothing can stop a carrier. Banking without counterplay is a delay, not a decision.
- **Keeping the first stolen egg instead of the best** turns about one Rare-or-better egg per match into a Common.
- **Visible Legendaries** (`visible_rarity_targeting.json`):
  - If Catchers ignore rarity, a Legendary carried into crossing 3 is stolen 43% of the time.
  - If they lean towards it, 54%; if they hunt it hard, 62%.
  - A Rare is stolen 27–31% of the time.
  - Holding a Legendary makes you a target, and roughly half of Legendary carriers keep it.

### What the sim can't show
- **Skill barely matters in the model.** Beginners and skilled players both win an egg about 65–66% of the time. Real skill gaps are certainly larger, so treat beginner-vs-skilled numbers as a floor.
- **No friends, voice chat, latency or map geometry.**

## 5. Recommended rules (Parts 4B–4E)

### Egg acquisition: strict Snatch-back
1. **Survive all three crossings:** you keep your egg at its evolved rarity.
2. **Snatch an egg as a converted Catcher:** you win an egg at the snatched rarity, capped at the rarity of the egg you were carrying when caught.
   - Caught in crossing 1 with a Common: a Common.
   - Caught in crossing 2 with a Rare: up to Rare.
   - Caught in crossing 3: no crossing left, so no egg.
3. **Snatch as the starting Catcher:** capped at Rare. A caught Hero is also capped at Rare (section 7).
4. **One egg per player per match;** keep the best one.
5. **No snatch and no survival:** Gold and XP only.
6. **The UI says it plainly,** e.g. "You snatched a LEGENDARY! You keep a RARE (you lost a Rare)." The cap is on the Catcher's HUD.

**Results with the tuned evolution table** (`recommended_economy.json`, `design_comparison.json`, `robustness_by_pressure.json`):
- A typical Runner wins an egg in 65–66% of matches.
- A beginner's chance of five eggless matches in a row is 0.5%.
- Honest play is worth 1.66× the better of giving up in crossing 1 or 2 at base strength.
- The starting Catcher's eggs are worth 0.62× a Runner's.
- Eggs per match: 20.0. Common 1.7, Rare 15.5, Epic 2.5, Legendary 0.28.

### Evolution
| Crossing | Rare | Epic | Legendary |
|---|---|---|---|
| 1 | Common becomes Rare (100%) | | |
| 2 | Rare stays 88% | Rare → Epic 10% | Rare → Legendary 2% |
| 3 (final) | Rare stays 90% | Rare → Epic 10%; Epic stays 99% | Epic → Legendary 1% |

**How it plays out:**
- **Every crossing visibly changes the egg.** The level always rises, and rarity sometimes does.
- **Legendaries are mostly born in crossing 2,** so 0.45 are carried into the final crossing per match. At least one is in play in 36% of matches.
- **A surviving egg ends** Rare 79%, Epic 18.7% or Legendary 2.1%.
- **Across all eggs won:** Common 8.6%, Rare 77.6%, Epic 12.4% and Legendary 1.4%.
- **Rejected tables:**
  - the brief's (21% of survivors Legendary)
  - "Epic-heavy" (23%)
  - deterministic (every survivor Legendary)
  - the place's levels (every survivor Epic, no Legendary)

### First pet
**Rule:** the first won egg also grants a Common pet of a family the player picks, and the egg is kept.

| Option | Median time to first pet | 90th percentile |
|---|---|---|
| Pet on first egg | 1 match | 2–3 matches |
| Two eggs | 3 matches | about 4 matches |
| A separate "3 Common eggs" recipe | 89% have none within 50 h | |

Giving the pet while keeping the egg costs almost nothing, and it doubles the moment: you win an egg and you get your first ability. That fits endowed progress (Nunes & Drèze, 2006), and it meets the GDD's "first pet after two matches" target.

### Incubation
**Recipes are sized so a typical player's first pet of each rarity lands at about 1 h (Rare), 5 h (Epic) and 25 h (Legendary).** That's a design target you can change. At 45 matches/h:

| Rarity | Random | Focused (+25%) |
|---|---|---|
| Rare | 24 | 30 |
| Epic | 19 | 24 |
| Legendary | 11 | 14 |

- **Common eggs:** 3 fuse into 1 Rare.
- **Show progress as a filling bar** ("Rare nest 18/24"), not a count.
- **If the cycle moves back toward the GDD's 135 s,** halve them: Rare 12, Epic 10, Legendary 6.

**Careers through the incubator** (300 careers each, resampled, nine families):

| | First Rare pet | First Epic pet | First Legendary pet | Pets owned at 50 h | Duplicates at 50 h |
|---|---|---|---|---|---|
| Typical | 1.3 h (90th pct 1.5) | 6.3 h (8.2) | 32 h (44); 2% none by 50 h | 17 | 44 |
| Beginner | 1.3 h | 6.7 h | 29 h | | |
| Skilled | 1.3 h | 6.1 h | 34 h; 6% none by 50 h | | |

- **Focusing** stays a surcharge in eggs (+25%), never Gems. The first Legendary is focused by default, which is why it lands later than the 25 h target.
- **Duplicates** (about 44 by 50 h) raise a pet's cosmetic mutation level (L1–L3), never stats. Thresholds are set by rarity; see [[Economy Decisions]].

### Against the cofounder pet roster (16 Oct)
The handoff proposes 5 archetypes × 4 rarities = 20 species, each with three cosmetic mutation levels. `roster.py` replays typical careers against that roster (`roster_careers.json`):
- **Species owned:** 8 by 5 h (when Common eggs hatch missing Commons), 11 by 10 h, 13 by 25 h and 15 by 50 h. Nobody has all 20 by 50 h.
- **Duplicates per Rare species:** 1 by 10 h, 4 by 25 h and 9 by 50 h. Epic species get about 1 by 50 h.
- **That's why the mutation thresholds are set by rarity.**
- **The ability sets conflict.** The handoff's five archetypes don't match the nine-family wave plan. That's a design call for Hunter and the cofounder; the economy works with either.

## 6. Pet balance (Part 4F)

**Recharge bonus:** with Brake (10 s), Scout (18 s) and Decoy (20 s), ability uses per match are 2.97, 1.99 and 1.98 at both Common and Legendary (+4.5%). Even +10% adds at most 0.04 uses (`cooldowns.json`).

**Distance bonus:**
- A dash 3–20% longer didn't change survival. It stayed at 45–48% (95% CI ±1 pt, 9,000 Runner samples per level, `pet_power.json`).
- Escapes in the model come down to timing and positioning.
- Real players might use precision the model's Runners don't, so read this as "small", not "zero".

**Feedback loop:** stronger pets → more eggs → stronger pets. With an effect this small, the loop is negligible.

**Decision (revised after the cofounder roster handoff):** no stat bonus at launch. Rarity changes how an ability looks, never how much it does. That matches the handoff's "same gameplay, different presentation" rule, and the sim shows the bonus bought nothing measurable. Make the visual and audio upgrade loud, because that's what players will perceive.

## 7. Hero or Chicken (Hunter's addition, 16 Oct)

### How Huss Valley does it
- **Per Hunter, who has played it:**
  - The players line up, and the original Catcher picks one of them.
  - That player chooses Hero (cross alone) or Chicken (stay back and cross with everyone).
- **[S] Third-party guides agree on what the two choices mean:** a Hero crosses alone for a bonus, and a Chicken gives up the bonus. Sources: games.gg and technerdiness beginner guides, hussvalley.top "Hero or Chicken" guide.
- **[S] Where the guides differ from Hunter:**
  - They say the game picks the player at random. None mentions a lineup or the Catcher choosing.
  - None shows footage. I'm going with Hunter's first-hand account.
- **Not found:**
  - the size of the Hero bonus
  - what happens to a caught Hero (guides imply they join the Chasers)
  - pick timers
  - any monetisation (none of its 9 passes relates to it) [V]
- **Note:** the game's own description is just "RUN!!" [V].

### What the sim says (`hero_solo.json`, `hero_headstart.json`)
**A lone Runner against one Catcher,** at the Catcher strength the 30-player match needs:

| Protection at the start of the Hero run | Loose | Base | Tight |
|---|---|---|---|
| 0.75 s (the normal crossing) | 15–18% | 3–6% | ~1% |
| 1.5 s | 22–27% | 6–9% | ~1% |
| 2.5 s | 52–55% | 34–37% | 19–21% |
| 3.5 s | 100% | 100% | 100% |

- **Without help, Hero is suicide.** A Catcher strong enough to catch half of a 30-player crowd catches a lone Runner almost every time.
- **The curve is steep around 2.5–3 s,** so protection is a fine dial for playtests.
- **Skill barely moves these numbers in the model.** Real 1-v-1 juking should matter more, so treat them as rough.

**If a caught Hero joined the Catchers for crossing 1** (Huss Valley's apparent rule), crossing 1 would start with 2 Catchers. Survival would fall from 47% to 9%, and 42% of matches would end with nobody surviving (`population.json`). With failure that common, the match would collapse in most rounds. **A caught Hero must convert at crossing 2,** like any other Runner caught in crossing 1.

### How it fits Hatch or Snatch
1. **Before crossing 1,** Runners line up. The starting Catcher has 5 s to pick one; if they don't, it's random.
2. **The picked player has 5 s to choose Hero or Chicken.** If they don't, it's Chicken.
3. **Hero:**
   - crosses alone with about 2.75 s of protection, tuned in playtests so about half of Heroes make it
   - everyone watches, with a short camera cut and an announcer line
   - **made it:** the crossing counts as their crossing 1, so the egg turns Rare. The Hero's egg also gets a bonus roll on the crossing-2 odds (Epic 10%, Legendary 2%). Small Gold and XP bonus, plus a "Hero" tag for the match.
   - **caught:** they lie down, convert at crossing 2, and can snatch up to Rare (the Hero cap). The Catcher's catch counts as a snatch of a Common.
4. **Chicken:** crosses with everyone, no penalty. A chicken emote or sound on the nameplate for that match is the only teasing.

**Is Hero worth taking?** This is my calculation from simulated rates, in hours of progress:

| Choice | Expected value | |
|---|---|---|
| Chicken (plays honestly) | about 0.066 h | |
| Hero, no bonus roll, about 50% success | about 0.055 h | 0.83× Chicken |
| Hero with the bonus roll | about 0.072 h | 1.09× Chicken |

So the bonus makes Hero a real, slightly favourable gamble. Hero has more variance, and the spotlight is the real reward.

**Psychology:**
- The Catcher's pick gives the one starting Catcher agency and a social role from the first second.
- The choice gives the picked player autonomy.
- The spotlight run is a shared moment the whole lobby watches.
- [H] The "Chicken" label adds playful social pressure without costing anything.
- Keeping the egg odds close to even stops it being a trap or a must-pick.

## 8. Comparing complete designs (Part 7)

All designs are scored on the same 2,000 simulated matches (base strength, tuned evolution). Each egg's value is the hours of progress it's worth under the recommended recipes: Rare 0.042 h, Epic 0.26 h, Legendary 2.27 h, Common a third of a Rare. "Give-up value" is the better of being caught in crossing 1 or 2. Source: `design_comparison.json`.

| Design | Beginner egg rate | Honest ÷ give-up | Starting Catcher ÷ Runner | Eggs/match | Legendary share |
|---|---|---|---|---|---|
| A Accessible (1 theft = egg) | 0.67 | **0.63 ✗** | 1.64 | 20.0 | 2.3% |
| B Competitive (Runners + 2 thefts) | 0.59 | **0.72 ✗** | 1.74 | 18.5 | 2.4% |
| C High-stakes (banking + steals drop a rarity) | 0.67 | 2.62 | **0.39 ✗** | 19.9 | 1.4% |
| **D Snatch-back (strict)** | 0.67 | 1.66 | 0.62 | 20.0 | 1.4% |
| D+1 Snatch-back +1 | 0.67 | **0.91 ✗** | 1.05 | 20.0 | 1.4% |
| The place today | 1.00 | **1.02 ✗** | 0.91 | **30 ✗** (participation) | 0% |

**Hard constraints first,** taken from your brief:
- Honest play must clearly beat giving up (more than 1.2×).
- The starting Catcher must get at least half a Runner's value.
- Eggs must be won, not given for showing up.

**Only strict Snatch-back (D) passes all three.**

**Does it hold at other Catcher strengths?** (`robustness_by_pressure.json`, 1,200 new matches each)

| Strength (survival) | D: honest ÷ give-up | D: starting Catcher ÷ Runner | D+1: honest ÷ give-up |
|---|---|---|---|
| loose (66%) | 2.44 | 0.44 | 1.32 |
| base (46%) | 1.66 | 0.62 | 0.91 ✗ |
| tight (31%) | 1.20 (borderline) | 0.85 | 0.67 ✗ |

That's why the survival target is 40–55%, not 35–55%. Below 40%, even the strict cap only just keeps honest play ahead.

**Weightings, for completeness.** Without the constraints, every weighting picks a design that fails one:

| Weighting | Rank 1 | D's rank |
|---|---|---|
| Balanced | A | 6th |
| Growth | The place today | 4th |
| Integrity | C | 5th |
| Hardcore | B | 4th |

The scores reward high egg rates and Catcher payouts, which are exactly what the exploit comes from. So the constraints decide, not the weights.

**Established by maths vs needing real players:**
- **Established:** the exploit ordering of the rules, at all three strengths.
- **Needs real players:**
  - whether the cap feels fair once explained
  - whether a 66% egg rate feels "won"
  - whether losing a Legendary is tension or robbery
  - whether Hero gets picked

## 9. Research (Part 3)

Labels:
- **[V]** I or a helper read the source.
- **[S]** secondary.
- **[H]** a hypothesis.

### Huss Valley
- **[V] Size:** universe 10764627709, group "Huss Valley Official", created 31 Aug 2026. On 16 Oct: 95,644 playing, 132,591,554 visits, about 88% upvotes, 30-player servers (`games.roblox.com/v1/games?universeIds=10764627709`).
- **[S] Peak:** RoWatcher reports a 174K concurrent-player peak in Oct 2026.
- **[V] Passes:** VIP 799 R$ (+25% XP), X2 EXP 199 R$, Premium Pass 799, and knife cosmetics (99–1,799). The place's VIP (499, +25% XP) mirrors it more cheaply.
- **[V] Developer products:**
  - **It sells permanent abilities for Robux** (479–1,299 R$), e.g. Cloak and Big Dagger. **Huss Valley sells power. Hatch or Snatch's "never sold" rule is a deliberate difference, and it gives up Huss Valley's main Robux lever.**
  - Coins and Gem packs, paid crates (399 R$, odds shown), spins and quest skips.
- **[S] Gameplay:**
  - One Chaser starts. The caught become Chasers, and a crossing teammate can revive with E.
  - Gems unlock abilities.
  - Hero or Chicken: see section 7. Sources: Beebom, games.gg, technerdiness and bloxgamer beginner guides, hussvalley.top.
- **Not verified:** round length, crate odds, the XP curve, the Hero bonus.

### Roblox platform
- **[V] Discovery signals:**
  - The most important are play-through rate, first-play bounce, play days per user and playtime per user.
  - Spend matters, but it ranks below retention.
  - Source: create.roblox.com/docs/discovery.
- **[V] Paid random items:**
  - Odds must be shown.
  - Items bought with purchasable currency (Gems) count.
  - Users with `ArePaidRandomItemsRestricted` need an alternative.
  - Source: create.roblox.com/docs/production/monetization/paid-random-items.
  - The emote crate is in scope, and the place already handles it. **Hatching earned eggs is not paid random as long as eggs and focus are never bought.**

### Psychology
- **[V/S] Self-determination theory:** autonomy, competence and relatedness in games predict enjoyment and wanting to keep playing (Ryan, Rigby & Przybylski, 2006, *Motivation and Emotion* 30). Focusing and the Hero choice give autonomy. The cap protects competence. The Catcher's pick and the spotlight run add relatedness.
- **[S] Loss aversion** (Kahneman & Tversky, 1979): losing a carried Legendary will sting. **[H]** That's acceptable because it was never banked and the loser can snatch back.
- **[V] Endowed progress** (Nunes & Drèze, 2006, JCR 32): supports the first pet on the first win.
- **[S] Goal gradient** (Kivetz, Urminsky & Zheng, 2006, JMR 43): supports the incubator bar.
- **[V] Loot boxes** (Zendle & Cairns, 2018, PLOS ONE): spending is linked to problem-gambling severity. The link is correlational, but **[H]** it's a reason to keep paid randomness cosmetic, with odds shown.
- **[V] Pay to win** (Freeman et al., 2022, CHI PLAY): players judge some purchases "pay to cheat".
- **[S] Near misses** (Clark et al., 2009, *Neuron*): raise the urge to play again when the player feels in control. **[H]** A Hero caught a stud from safety is that kind of moment.

## 10. Psychological audit (Part 5): short answers
1. **Is winning worth the risk of losing?** Yes, if the loss can be partly won back in the same match. That's the snatch.
2. **Losing a rare egg: tension or frustration?** Tension, if about half of Legendary carriers keep theirs (43–62% are stolen in the model) and the thief is shown. Playtest check 4 decides.
3. **How often should rewards land?** An egg in about two of three matches. A hatch about hourly early on, a first Epic at about 6 h, a first Legendary at about 30 h.
4. **First pet right after the first egg?** Yes.
5. **What motivates most?** **[H]** Visible rarity and social moments (the Legendary egg, the Hero run) beat efficiency. The stat effects are invisible, so lean on looks.
6. **Multi-egg incubation: anticipation or grind?** Anticipation as a bar with a reveal, grind as a 24-item counter.
7. **Does focusing add investment?** Yes. It's the autonomy lever, so keep it cheap (+25%).
8. **Egg Index?** Not yet.
9. **Can Catchers enjoy it without undermining survivors?** Yes. The starting Catcher averages 4 snatches, picks the Hero, and gets Gold and XP for every snatch.
10. **Will players queue again after a loss?** Likely, with a 62-second cycle and a fresh Hero pick every match.

## 11. Gold and Gems (Part 6)

### Gold (earn only)
- Keep the formula: about 59 Gold per match, about 2,700/h including level-ups.
- **Multiply prices by 3:**
  - consumables 120–180
  - emote 1,500
  - case 2,700
  - entrance 4,200
  - weekly colourway 7,200 (about 2.7 h)
- Keep rotating stock as the real sink.

### Gems (earned + Robux)
- **Earned Gems become "1 for a win + 1 for the first snatch", max 2 per match.** That's 0.67 per match, about 30/h, down from 151/h. Level-up Gems (10 every 5 levels) stay.
- **At about 30/h:**
  - premium trail (150): 5 h
  - crate (250): 8 h
  - a 500-Gem pack (199 R$) is worth about 17 h of play
- **Sell (cosmetic only):** trails, ability colours, hatch ceremonies, pet showcase, egg-case skins, the emote crate (odds shown), and Hero-run effects such as a custom Hero entrance or trail.
- **Never sell:** eggs, focus, abilities, rarity, or a better chance of being picked as Hero.
- **No shop prompts before the first pet.**
- **[H]** For discovery, a first hour that feels earned beats more Robux per user.

## 12. The first 15 minutes (Part 5/14)
1. **0:00** Spawn in the lobby. The next match starts in 15 s. No shop, no pet.
2. **0:20** First match. Bots fill to 30. The lineup forms, and the Catcher picks a Hero. Maybe it's you: Hero or Chicken?
3. **0:40** Crossing 1. The egg pops to Rare.
4. **Crossing 2:** caught holding a Rare? The HUD says "SNATCH ONE BACK (up to RARE)".
5. **1:30** Results: "You snatched a RARE egg!" Then **First pet! Pick your ability:** Double Dash, Decoy or Scout.
6. **2–6 min** Matches 2–5 with the ability. The incubator bar fills ("Rare nest 4/24"). XP levels 2 → 4.
7. **About 8 min** First Gold purchase affordable. It's shown in the lobby, never mid-match.
8. **About 12 min** A Legendary egg is visible in someone's hands during a final crossing, and everyone chases it.
9. **15 min** Next goal on screen: "Rare pet in about 45 min" plus today's weekly item.

## 13. Development priorities (Part 11)
1. **Now (code):**
   - exactly 3 crossings (drop the clean-streak rule)
   - one starting Catcher
   - bot fill to 30
   - `MAX_PLAYERS` 30
   - the strict Snatch-back cap in `MatchLogic.capture` / `computeResults`
   - remove the participation piece
   - Legendary tier with the tuned table
   - fix `TierConfig` naming
2. **Next:**
   - Catcher strength tuning (stab and lunge reach, lunge cooldown) against the survival target
   - Hero or Chicken
   - first pet on first egg
   - recipe bar and sizes
   - Common fusion
   - Gold ×3 and the new Gems formula
3. **Later:** Egg Index, Cosmic, Ranked, more families (waves 2–3).

## 14. Validation plan (Part 12)

| # | Test | Measure | Pass |
|---|---|---|---|
| 1 | Strength check: 10+ real 30-body matches (bots fill), telemetry on | Runner survival over 3 crossings | 40–55%. If not, adjust Catcher reach and lunge, not the Catcher count |
| 2 | Surrender check: same matches | Egg value: players caught in crossings 1–2 vs survivors | Caught-early players earn less than 0.8× an honest Runner's value |
| 3 | Hero check: same matches | Hero success rate; share who choose Hero | 35–60% success; 30–70% choose Hero. Tune protection in 0.25 s steps |
| 4 | First session: 20+ new players | Pet within 3 matches; still playing at 10 min | 90%; 70% |
| 5 | Loss feel: survey after a stolen Legendary | "Felt fair" (1–5), victim and thief | Victim median ≥ 3; thief ≥ 4 |

A 20–40 person test finds broken things; it can't measure retention lifts. Soft launch does that.

## 15. What the GDD v0.4 says vs what supersedes it
| GDD v0.4 | Now |
|---|---|
| 8–16 players | About 30, one starting Catcher, bots fill to 30 |
| Every active match ≥ Common piece | Eggs are won only |
| Rarity from level, L4 = Epic, Crowned deferred | Random evolution with Legendary at launch, tuned table |
| Recipes 2/3/5 | Sized to hours (section 5) |
| 135 s cycle | About 62–65 s in the place |
| Gems 64/h | 151/h measured; cut to about 30/h |
| Rarity stats 0% test | Small distance or duration bonus; measured as invisible |
| (none) | Hero or Chicken at match start |

## 16. If I were investing my own money

> If I were investing my own money and development time, this is the version of Hatch or Snatch I would build:
>
> - **The match:** a 30-body, exactly-three-crossing chase against one strong starting Catcher, tuned so about half the Runners survive.
> - **The opener:** a Hero-or-Chicken pick that puts one player in the spotlight before every match.
> - **The eggs:** each one visibly evolves every crossing. Legendaries are born in crossing 2, so most final crossings have a gold egg worth chasing.
> - **The rule:** survive to keep your egg, or snatch one back, but never above the rarity you lost.
> - **The first pet:** the first egg you win also gives you a chosen ability.
> - **The incubator:** progress fills a bar, paced in hours.
> - **The shop:** Gold and Gems buy only looks, and Robux never buys an egg or power.
>
> **The reasons:**
> - The format has proven demand right now.
> - The strict Snatch-back cap is the only rule tested that keeps surviving worth more than giving up while still paying the Catcher.
> - Filling to 30 and tuning the Catcher's tools keeps every match in the range where both of those hold.
> - The pacing fixes turn an afternoon's progression into weeks.
> - Not selling power is what lets the egg chase mean something.

## Limits
- The model's player behaviour and skill scale are invented, so skill hardly matters in it. "Catcher strength" is a stand-in for real catching skill and the Catcher's tools.
- Careers are resampled from simulated matches and treat matches as independent: no learning, no tilt, no parties.
- Bots aren't modelled separately from players.
- 45 matches/h is an assumption.
- The Hero value maths combines simulated rates by hand. It isn't a full simulation of matches with a Hero run.
- Nothing here measures fun.
