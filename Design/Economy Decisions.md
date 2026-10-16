---
tags: [design, decisions, economy]
updated: 2026-10-16
ticket: HOS-ECON-001
---
# Economy decisions (16 Oct 2026)

On 16 Oct Hunter asked Claude to settle these himself, using the sim data, the psychology research and the market research in [[Economy Audit 2026-10-16]]. Section numbers point into that report, which has the evidence.

**These decisions replace the GDD v0.4 economy rules where the two differ.** They should be added to [[Evolve or Steal Decisions]] once the design branch merges.

Each decision has a playtest check. A failed check changes the number in that decision, not the decision itself. The checks are listed in section 13 of the report.

## The match
1. **The match is exactly 3 crossings, with up to 30 players.** This replaces the place's "3 clean crossings in a row" end rule.
   - *Data:* that rule averages 5–8 crossings, Runners win only 10–22% of the time, and it labels eggs Legendary while paying Epic (section 2.3).
   - *Psychology:* a fixed end point gives a clear goal-gradient finish.
2. **One starting Catcher per 10 players, rounded, minimum 1:**

   | Players | Starting Catchers |
   |---|---|
   | 12 | 1 |
   | 16 | 2 |
   | 24 | 2 |
   | 30 | 3 |

   - *Data:* in a 30-player match, survival is 81% with 1 starting Catcher, 64% with 2, 45% with 3 and 29% with 4. Only 3 falls in the 35–55% window, where surviving feels earned and losing still feels fair (section 4).
   - *Check:* if real survival lands outside 35–55%, move to 2 or 4.
3. **Caught Runners convert next crossing, as now.** Converting them immediately didn't add pressure in the sim, and it adds visual noise (section 4).

## Eggs
4. **Eggs are won, not handed out.** There are two ways to win one:
   - survive all three crossings, or
   - snatch one as a Catcher.

   No player gets an egg just for taking part.
   - *Data:* today the place gives 30 pieces per match and 88% of them are Epic, so Epic means nothing (section 2.4).
   - *Psychology:* competence needs rewards that track how well you played.
5. **Snatch-back cap:** a Catcher who snatches keeps an egg at most one rarity above the egg they were carrying when caught. Starting Catchers can keep up to Epic.
   - Each player wins at most one egg per match, and keeps the best one they get.
   - The cap shows on the Catcher HUD ("SNATCH ONE BACK, up to EPIC").
   - *Data:* this was the only rule that passed all three hard constraints (sections 3 and 7):
     - playing honestly is worth 1.9× giving up early
     - a starting Catcher's eggs are worth 0.71× a Runner's
     - a typical player still wins an egg 66% of the time
   - *Psychology:*
     - losing an egg hurts, and loss aversion makes that worse, but you can win one back in the same match
     - the near miss is skill-driven, not chance-driven
6. **Evolution table:**

   | Crossing | Outcome |
   |---|---|
   | 1 | Every egg becomes Rare |
   | 2 | Rare → Epic 10%, Rare → Legendary 2% |
   | 3 | Rare → Epic 10%, Epic → Legendary 1% |

   Survivors end 79% Rare, 18.7% Epic and 2.1% Legendary.
   - *Data:* a Legendary is in play during the final crossing in about 39% of matches. Without the cap, about 1.2% of all eggs won end up Legendary (section 5).
   - *Psychology:* a visible "golden egg" gives the lobby something to chase.
7. **Every player can see each egg's rarity.** In the sim, Catchers who hunted Legendaries raised the chance of one being stolen from 39% to 49%. That's tension, but keeping a Legendary is still possible (section 4).
8. **Banking stolen eggs is rejected,** and so is needing two thefts for an egg.
   - Banking with nothing that can stop it changed nothing in the sim.
   - Two thefts still pay players who are caught early (honest play is only worth 1.12× giving up), and it adds frustration.

## Pets and incubation
9. **The first egg a player wins also gives them a Common pet from a family they choose, and they keep the egg.** The median wait is 1 match.
   - *Research:* the endowed-progress effect (Nunes & Drèze 2006) says a head start keeps players going.
   - *Psychology:* picking the family gives the player a sense of choice from minute one.
10. **Hatching recipes are sized in hours, not as a fixed small number of eggs:**

    | Rarity | Eggs to hatch | With focus (+25%) |
    |---|---|---|
    | Rare | 26 | 33 |
    | Epic | 23 | 29 |
    | Legendary | 10 | 13 |

    - Each recipe shows as an incubator bar that fills up.
    - The targets for a typical player are a first Rare pet at about 1 h, a first Epic at about 6 h and a first Legendary at about 33 h.
    - *Data:* with the brief's 3/4/3 recipes, the first Legendary arrives in 45 min and every pet is owned within 50 h (section 2.2).
    - *Research:* the goal-gradient effect (Kivetz et al. 2006) is why it's a bar and not a counter.
    - *Check:* the counts assume 45 matches an hour. Recompute them from real matches per hour after the first test using recipe = target hours × eggs per hour.
11. **Three Common eggs fuse into one Rare.** Without this, Common eggs pile up with no use after the first pet.
12. **Focusing costs eggs (+25%), never Gems.** Selling focus for Gems would turn hatching into a paid random item under Roblox's rules.
13. **Duplicate pets give cosmetic mastery stars only, never stats.**
14. **Rarity stat bonus:** Rare +1.5%, Epic +3%, Legendary +4.5%, on ability duration or distance only, never recharge.
    - *Data:* the bonus made no measurable difference to survival or ability uses, so it carries no balance risk (section 6).
    - *Psychology:* it gives the rarity chase an honest, stated reason.
    - Rarity is mainly shown through louder visuals and sound on higher-rarity pets.
    - If Ranked ever ships, the bonus is normalised there.

## Currencies
15. **Gold:** earn rates stay the same and prices go up 3×:

    | Item | Gold |
    |---|---|
    | Consumables | 120–180 |
    | Emote | 1,500 |
    | Case | 2,700 |
    | Entrance | 4,200 |
    | Weekly colourway | 7,200 |

    - *Data:* at about 2,540 Gold an hour, a player could buy the whole shop in under an hour (section 10).
16. **Gems:** a player earns 1 for winning plus 1 for their first snatch, at most 2 per match. Level-up Gems stay.
    - That's about 31 an hour, down from about 142.
    - *Data:* at the current rate, a 500-Gem pack is worth about 3.5 h of play, so it's poor value. At the new rate it's worth about 16 h.
17. **Robux only ever buys looks, never power:** Gem packs, passes, cosmetics, and the emote crate with its odds shown.
    - Eggs, focus, abilities and rarity are never sold.
    - *Research:* players judge pay-to-win as unfair (Freeman et al. 2022). Huss Valley sells abilities, and not selling them is how this game stands apart.
18. **No shop prompts until after the first pet.**
    - *Research:* Roblox ranks games mainly on how many players keep playing and for how long, more than on spend.

## Deferred
19. **Not at launch:** Egg Index, Ranked, the Cosmic tier, Gem-paid focusing, and ability families from waves 2–3 (already planned).
