---
tags: [design, gdd]
updated: 2026-10-15
source: "Design/GDD/Evolve or Steal GDD v0.4.pdf"
---
# Evolve or Steal: GDD v0.4 summary

The full document is the PDF next to this note (`GDD/Evolve or Steal GDD v0.4.pdf`, 15 pages, dated 15 Oct 2026). This note is a working digest: what the game is, what's locked and what's still open. Where the PDF and this note disagree, the PDF wins.

**Status words used in the GDD:** LOCKED = picked for the prototype. RECOMMENDED = the default, still needs testing. EXPERIMENT = an instrumented A/B alternative. DEFER = not needed at launch.

## The game in one paragraph
Evolve or Steal is an 8–16 player infection chase with no elimination. Runners each carry an egg across an arena. Every safe crossing levels the egg up one step (Level 1 → 4). Catchers hunt them, and a caught Runner becomes a Catcher, while the Catcher who caught them takes the egg (a real theft). After a match, each player earns one egg **material** at the highest tier they secured or stole. Players craft materials into **pets** at the incubator, and the equipped pet gives its owner one ability family in matches. Gold is the earn-only cosmetic currency and Gems are the premium one. Eggs are the only route to anything that affects play.

> **Final recommendation (GDD 18):** Gold = earned, frequent expression. Gems = buyable/earnable permanent premium expression. Eggs = the only primary pet/ability progression resource. Keep the path from skilful escape or theft to an earned pet; don't sell the loop.

## Status at a glance
| System | Decision | State |
|---|---|---|
| Three-round infection chase | Runner → Catcher conversion, no spectating | LOCKED |
| Arena egg theft | Real transfer of current egg; highest material reward | LOCKED |
| Starting pet | None; first Common earned through matches | LOCKED |
| Pets and abilities | One equipped pet = one ability family | LOCKED |
| Focused incubation | Extra same-tier piece picks the family; first Common focus free | LOCKED |
| Gold | Earn-only, frequent, low cost | RECOMMENDED |
| Gems | Earnable AND Robux-purchasable | LOCKED |
| Gem-powered focusing (Focus Seal) | Optional alternative to the extra piece | EXPERIMENT / POLICY GATE |
| Casual rarity stats | 0% vs +1.5/+3/+4.5% test | EXPERIMENT |
| Ranked | Normalise rarity stats; only if the queue supports it | DEFER |

## Match (GDD 02, Appendix A)
- 8–16 players by default. **Target cycle 135 s** including intermission, with a hard cap of 165 s. **Three crossings.**
- Start: every Runner gets a temporary Level-1 egg; one Catcher volunteers, with a fair fallback if nobody does.
- Crossings 1, 2 and 3 take the egg to Level 2, 3 and 4 for anyone who survives. Catchers convert their victims at the phase transition and grow the team. Crossing 3 is the last chance to steal.
- Infection is one-way. Nobody is eliminated into spectating. A captured player keeps their ability cooldown when they convert.
- A stolen egg goes into a per-match tally, so there are no floating egg stacks. Each player gets **at most one primary material** per match, from their best result. Crossings already completed bank a Common-equivalent minimum.
- Server state machine: `LOBBY → SELECT_HUNTER → CROSSING_1/2/3 → PHASE_SETTLEMENT → MATCH_SETTLEMENT → INTERMISSION`. The server timestamp decides capture vs safe arrival. A match ID plus player ID settles exactly once.

## Egg materials and incubation (GDD 03)
| Highest level | Material | Random-family recipe | Focused (same tier) |
|---|---|---|---|
| L1 / early capture | Common | 2 | 3 |
| L2 | Rare | 3 | 4 |
| L3 | Epic | 5 | 6 |
| L4 / secured final | Epic + victory bonus | 5 Epic | 6 Epic |

- The **first Common pet costs 2 pieces and includes a free family choice**. Players can reach it after 2 active matches.
- Rarity comes only from the material tier (no extra rarity roll). Each family has one species per tier.
- Materials can be downgraded 1:1 to a lower tier, never upgraded.
- **Crowned/Legendary is deferred.** At launch, L4 gives Epic. Never label a reward Legendary.

## Currencies (GDD 04–06, Appendix C)
- **Gold:** earn-only and cosmetic-only. Can't be bought with Robux or exchanged for Gems. No Gold crates. Sinks: one-match egg trails (35–60), lobby burst (75), emote (500), case skin (900), entrance (1,400), weekly colourway (2,400). The catalogue has to rotate or Gold loses its value.
- **Gems:** premium and earnable. Durable cosmetics: premium trail (100–180), ability VFX colour pack (250), hatch ceremony (350), showcase slot (450), themed override (700), prestige set (1,500). The Focus Seal (4/9/16/60 Gems) is EXPERIMENT ONLY and needs a policy review first.
- **Never sold:** egg materials, starting egg level, cooldowns, Legendary rolls.
- **Earn formulas (GDD 08):**
  - Gold = min(90, 25 active + 12 × crossings + 10 × first credited theft + 15 × victory)
  - Gems = min(5, 1 active + 1 first crossing + 1 second crossing + 1 victory + 1 first theft)
  - A Typical player earns about 1,099 Gold/h and 64 Gems/h.
- **Robux catalogue (candidate prices):** Gem packs 100/225/500/1,100/2,400/5,000 for 49/99/199/399/799/1,499 R$. Passes: lobby celebration 79, 2x Gold 199, Pet FX Bundle 249, VIP 499. Premium collection track (799) and prestige pet skin (1,299) are DEFERRED.
- Purchases go through server `ProcessReceipt` and are idempotent per transaction ID. Purchased Gems are logged separately. No fake countdowns or discounts, and no purchase modal during a chase.

## Pets and abilities (GDD 13, Appendix B)
- No starter pet. One equipped pet gives one ability. Pets are not just cosmetic.
- Nine families: Dash, Decoy, Scout, Brake, Spring, Mist, Rebound, Drift, Tracker. **Launch with 3 polished abilities**, go to 6 after tests, and 9 only once both roles show fair use.
  - **Superseded 15 Oct 2026 (Hunter):** the nine are now Double Dash, Decoy, Scout (wave 1, launch); Brake, Invisibility, Wall (wave 2); Shield, Spring, Pet Tackle (wave 3). Mist became Invisibility, Rebound became Shield, Drift and Tracker were dropped (they overlapped Brake and Scout), and Wall and Pet Tackle came from the pet showroom. See [[Evolve or Steal Decisions]].
- Species ladders in the GDD (replaced by the showroom pets in `FWPPetData.Pools`): Dash Sand Crab/Otter/Phoenix · Decoy Mouse/Parrot/Mirror Dragon · Scout Sparrow/Seagull/Celestial Owl · Brake Turtle/Hermit/Time Spirit · Spring Frog/Hare/Cloud Serpent · Mist Puffer/Jelly/Kraken · Rebound Gecko/Ram/Thunder Beast · Drift Minnow/Koi/Leviathan · Tracker Firefly/Bat/Ghost Wolf.
- Rarity stat boosts are a TEST only (0% by default). Ranked would normalise them.
- Visibility: the owner sees a small local follower (under 20% of avatar height). Opponents only see a short summon and telegraph when the ability fires. The server owns effects and cooldowns.

## FTUE and UX (GDD 14)
1. Spawn straight into a legible match. Teach egg evolution and catching, not shopping.
2. After 1 match: show an earned material and "1 of 2" towards the first pet.
3. After 2 matches: craft the first Common with a free family choice.
4. Introduce Gold and Gems only after the player has earned eggs.
5. Gem packs appear in the shop and incubator lobby, never during chases.
6. Ranked needs enough queue population.

During a crossing, hide the economy counters except the egg level and ability cooldown. At the end of a match, show one breakdown: Gold, Gems, best material, recipe progress and collection milestone.

## Roadmap (GDD 17)
| Milestone | Deliverable | Release condition |
|---|---|---|
| Week 1 / P0 | Three-crossing chase, eggs, capture, 3 pet abilities, server wallet schema | Fun even when nobody opens the shop |
| Week 2 / P1 | Common/Rare/Epic materials, first Common hatch, focus recipe, Gold shop | Atomic crafting; first pet within 2 active matches |
| Week 3 / P2 | Purchasable Gems, premium guaranteed visuals, transaction analytics, low-end mobile QA | Receipt idempotency, transparent prices, fair results |
| Soft launch | Tune capture rate, player tiers, Gold/Gem economy, pet visibility | Retention, role engagement, non-payer participation |
| Expansion | 6–9 abilities, families, events, premium catalogue, maybe Ranked | Queue, player base and content cadence |

Experiment order: P0 gameplay with no offers → P1 currencies and Gold shop → P2 purchasable Gems → P3 Focus Seal (only if policy and fairness pass) → P4 casual rarity stats → P5 Ranked.

## Open sign-offs (GDD 18): Hunter must approve each one
| Decision | GDD default |
|---|---|
| Launch Gem shop | Yes: Gem packs + guaranteed premium cosmetics |
| Gem payment for Focus Seal | Disabled pending policy + fairness check |
| Direct egg piece purchase | No |
| Gold direct Robux purchase | No |
| Gold temporary cosmetic shop | Yes |
| Casual pet rarity boosts | 0% until A/B shows a safe alternative |
| Crowned tier at launch | No |
| Permanent trading | Disabled |
| Ranked at launch | No; implement optional normalisation rules |

## Telemetry contract (Appendix E)
`match_start`, `role_selected`, `crossing_complete`, `capture_confirmed`, `piece_awarded`, `gold_source/gold_sink`, `gems_source/gems_sink`, `focus_used`, `pet_crafted`, `purchase_receipt`, `return_next_round`. Field lists are in the PDF.

**Critical QA:** no initial pet; first Common after two eligible matches; focus never picks another family; focus debit only once; Crowned disabled (L4 grants Epic); one material per Catcher; crash-safe transactions; readable mobile telegraphs; Gems granted exactly once.

**Security QA:** injected capture packets, out-of-range tags, forged eggs, replayed rewards and receipts, concurrent cross-server transactions, clock manipulation, AFK farming, alt-account teaming.
