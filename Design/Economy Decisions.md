---
tags: [design, decisions, economy]
updated: 2026-10-16
ticket: HOS-ECON-001
---
# Economy decisions (16 Oct 2026)

On 16 Oct Hunter asked Claude to settle these himself, using the sim data, the psychology research and the market research in [[Economy Audit 2026-10-16]]. Later that day Hunter set **one starting Catcher**, so every sim was re-run and these decisions were revised around that. Section numbers point into the report, which has the evidence.

**These decisions replace the GDD v0.4 economy rules where the two differ.** They should be added to [[Evolve or Steal Decisions]] once the design branch merges.

Each decision has a playtest check. A failed check changes the number in that decision, not the decision itself. The checks are listed in section 14 of the report.

## The match
1. **The match is exactly 3 crossings, with about 30 players and one starting Catcher (Hunter).** This replaces the place's "3 clean crossings in a row" end rule.
   - *Data:* with one capable Catcher a clean crossing almost never happens. Matches run 4–5 crossings and Runners win 0–1.5% of them (section 2.4).
2. **Tune the Catcher's tools so 40–55% of Runners survive.** The levers are stab and lunge reach, lunge cooldown and protection time, not a second Catcher.
   - *Data:* survival is 81% at the Catcher strength the 3-Catcher runs assumed. Adding a second starting Catcher drops it to 9%, so the number of Catchers is too coarse to tune with. Below 40% survival, even the strict cap only just keeps honest play ahead of giving up (1.20×, section 8).
   - *Check:* playtest survival. Adjust reach or lunge if it lands outside 40–55%.
3. **Bots fill every match to 30 bodies.** Today the place fills to 20 Runners.
   - *Data:* with the Catcher tuned for 30 players, survival is 47% at 30, 35% at 24, 14% at 16 and 7% at 12. At 12, 72% of matches end with no survivors (section 4).
4. **Caught Runners convert next crossing, as now.** Converting immediately didn't add pressure in the sim (section 4).

## Hero or Chicken (from Huss Valley)
5. **Before crossing 1, the Runners line up and the starting Catcher picks one of them, with 5 s to do it (random if they don't).** The picked player then has 5 s to choose Hero or Chicken (Chicken if they don't).
   - This follows Hunter's first-hand account. Third-party guides say Huss Valley picks at random.
   - *Psychology:* it gives the lone Catcher agency and a social role, gives the picked player a real choice, and gives the lobby a shared spotlight moment.
6. **A Hero crosses alone, with about 2.75 s of start protection.**
   - *Data:* without protection, a lone Runner beats a Catcher this strong only 3–6% of the time. With 2.5 s it's 34–37%; with 3.5 s it's 100% (section 7).
   - *Check:* tune protection in 0.25 s steps until 35–60% of Heroes make it.
7. **If the Hero makes it:**
   - their crossing 1 is done and the egg turns Rare
   - the egg gets a bonus roll on the crossing-2 odds (Epic 10%, Legendary 2%)
   - a small Gold and XP bonus, and a "Hero" tag for the match
   - *Data (calculated by hand from sim rates):* a Hero is worth about 1.09× a Chicken on average, against 0.83× without the bonus roll. That makes Hero a fair gamble and not a trap.
8. **A caught Hero lies down and converts at crossing 2,** like any Runner caught in crossing 1. They can snatch up to Rare.
   - *Data:* if they joined the Catchers for crossing 1, as Huss Valley appears to do, survival would fall from 47% to 9% (section 4).
9. **A Chicken crosses with everyone at no cost.** A chicken emote or sound on their nameplate for that match is the only teasing.

## Eggs
10. **Eggs are won, not handed out.** A player wins one by surviving all three crossings, or by snatching one as a Catcher. No egg just for taking part.
    - *Data:* today the place gives out 30 pieces per match, and 98% are Epic (section 2.5).
11. **Strict Snatch-back cap: a snatched egg can't be higher than the egg you were carrying when caught.**
    - Caught in crossing 1: Common only. Caught in crossing 2: up to Rare. The starting Catcher and a caught Hero: up to Rare.
    - A player keeps one egg per match, the best one, and the HUD shows the cap.
    - *Data:* it's the only rule that passed every hard constraint with one Catcher (section 8).
      - Honest play is worth 1.66× giving up early.
      - The starting Catcher gets 0.62× a Runner's value.
      - A typical player wins an egg in 66% of matches.
    - *Data:* the "+1" version (cap one rarity above what you lost), the earlier pick, now loses to giving up in crossing 2 (0.91×).
    - *Psychology:* the reward follows how far you got, and a loss can still be won partly back in the same match.
12. **Evolution:**

    | Crossing | Odds |
    |---|---|
    | 1 | Common → Rare (always) |
    | 2 | Epic 10%, Legendary 2% |
    | 3 | Rare → Epic 10%, Epic → Legendary 1% |

    - Survivors end up 79% Rare, 18.7% Epic and 2.1% Legendary.
    - At least one Legendary is in play during the final crossing in 36% of matches.
13. **Every egg's rarity is visible.** In the sim, a Legendary carried into the final crossing is stolen 43–62% of the time, depending on how hard Catchers hunt it.
    - *Check:* a "felt fair" survey after a Legendary is stolen.
14. **Banking stolen eggs and needing two thefts are both rejected.**
    - Banking with nothing to stop it changes nothing.
    - With two thefts, honest play is worth only 0.72× giving up early.

## Pets and incubation
15. **The first egg a player wins also gives them a Common pet from a family they choose, and they keep the egg.** The median wait is 1 match.
    - With the cofounder roster, the choice is between the five Common species: Mimic Crow, Veil Chameleon, Bastion Beetle, Thunder Toad and Ring Imp.
    - The Crow is the production quality benchmark, so many players' first pet will be the best-made model.
    - *Research:* endowed progress (Nunes & Drèze 2006).
16. **Recipes are sized in hours:**

    | Rarity | Eggs | Focused (+25%) |
    |---|---|---|
    | Rare | 24 | 30 |
    | Epic | 19 | 24 |
    | Legendary | 11 | 14 |

    - Each shows as an incubator bar.
    - A typical player gets a first Rare pet at about 1.3 h, a first Epic at about 6.3 h and a first Legendary at about 32 h.
    - *Research:* goal gradient (Kivetz et al. 2006).
    - *Check:* the sizes assume 45 matches per hour. Recompute them from real matches per hour using target hours × eggs per hour.
17. **Common eggs:** three Common eggs hatch a Common species the player doesn't have yet. Once all five Commons are owned, three Common eggs fuse into one Rare egg instead.
    - Commons are 9% of eggs under the cap, so they need a use.
    - *Data (`roster_careers.json`):* this takes a typical player from 4 to 8 species owned by 5 h, and costs almost nothing in Rare-pet pace.
18. **Focusing costs eggs, never Gems.** Paying Gems to focus would make hatching a paid random item.
19. **Duplicate pets raise the pet's mutation level (L1 → L2 → L3, from the cofounder roster handoff). Mutations are cosmetic only.** The thresholds are set by rarity so each tier has a reachable goal:

    | Rarity | L2 | L3 |
    |---|---|---|
    | Rare | 2 duplicates | 6 duplicates |
    | Epic | 1 duplicate | 3 duplicates |
    | Legendary | 1 duplicate | 2 duplicates |
    | Common | 1 copy from Common eggs | 3 copies from Common eggs |

    - *Data:* a typical player has a median of 1 duplicate per Rare species at 10 h, 4 at 25 h and 9 at 50 h, and 1 per Epic species at 50 h. On those numbers, Rare L2 arrives around 15 h, Rare L3 around 35 h, and Epic L3 is a long-term goal.
    - Common copies come from Common eggs, chosen by the player, once all five Commons are owned.
20. **No rarity stat bonus at launch: rarity changes how an ability looks, never how much it does.** (Revised 16 Oct after the cofounder roster handoff; this used to be +1.5/3/4.5%.)
    - *Data:* a +3% to +20% bonus made no measurable difference to survival (45–48% at every level). That's exactly the competitive test the handoff asks for, and it found nothing.
    - *Design:* the handoff's rule is that "the pet decides how an effect looks, not how much it accomplishes". A bonus that does nothing would break that rule for no gain, and it would add balancing work across ten role abilities.
    - *Psychology:* players perceive the visuals and sound anyway. Revisit the bonus only if playtests show players want rarity to feel stronger.

## Pet roster (cofounder handoff, 16 Oct)
26. **The economy fits the proposed roster: 5 archetypes × 4 rarities = 20 species, plus 3 cosmetic mutation levels.** Archetype = the family you focus, and rarity = which species hatches.
    - *Data (`roster_careers.json`, typical player):*

      | Hours played | Species owned | Note |
      |---|---|---|
      | 5 h | 8 of 20 | |
      | 10 h | 11 | |
      | 25 h | 13 | |
      | 50 h | 15 | Usually all Commons and Rares, 4 Epics, 1 Legendary |

    - Nobody has all 20 by 50 h, which gives a long tail.
27. **Build art in the order players will see it:**
    1. L1 of all Commons and Rares (every player meets these in the first hours)
    2. Epics (first one at about 6 h)
    3. Legendaries (about 30 h)
    4. L2 and L3, Rares first, since Rare duplicates pile up first
28. **Catcher abilities and the Hero run count towards Catcher strength.** Extended reach, tether pull, the projectile and the rift dash all make Catchers stronger, and the shield, knockback and portal make Runners harder to catch.
    - Tune the 40–55% survival target and the Hero protection time with abilities switched on, and with the starting Catcher holding each archetype in turn.
    - The strict Snatch-back cap still holds whatever the abilities do, because it caps rarity, not how often you snatch.
29. **Still open (not an economy call):** the handoff's five archetypes (Decoy, Invisibility, Guardian, Tempest, Rift) don't match the nine-family, three-wave plan in [[Evolve or Steal Decisions]]. That plan has Double Dash, Decoy and Scout at launch, and Brake, Wall and others later. The economy works with either. Hunter and the cofounder need to pick one.

## Currencies
30. **Gold earn rates stay the same, and prices go up 3×:**

    | Item | Price |
    |---|---|
    | Consumables | 120–180 |
    | Emote | 1,500 |
    | Case | 2,700 |
    | Entrance | 4,200 |
    | Weekly colourway | 7,200 |

    - *Data:* players earn about 2,700 Gold per hour, so at current prices the whole shop is affordable in under an hour.
31. **Gems: 1 for a win plus 1 for the first snatch, at most 2 per match.** Level-up Gems stay. That's about 30 per hour, down from 151.
32. **Robux only buys looks:** Gem packs, passes, cosmetics including Hero-run effects, and the emote crate with its odds shown.
    - Eggs, focus, abilities, rarity and any boost to being picked as Hero are never sold.
    - *Research:* players see pay-to-win as unfair (Freeman et al. 2022). Huss Valley sells power, and not doing so is our difference.
33. **No shop prompts until after the first pet.**

## Deferred
34. **Not at launch:** Egg Index, Ranked, the Cosmic tier, Gem-paid focusing, and ability families from waves 2–3.
