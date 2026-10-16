# Hatch or Snatch economy simulation (HOS-ECON-001)

Python 3 + numpy. No other dependencies. Results land in `docs/economy-audit/results/`; the report is `docs/economy-audit/Economy Audit 2026-10-16.md`.

| File | What it does |
|---|---|
| `chase.py` | 2D multiplayer chase. Every player shares one arena; Catchers pick and chase Runners, captures convert Runners, the next crossing starts with the bigger Catcher team. Movement numbers come from the place's `GameConfig` (16 Oct snapshot). The brains (steering, jukes, stab success) and the skill scale are invented. |
| `economy.py` | Egg evolution tables, egg-award rules, Gold/Gems/XP formulas as in `EconomyConfig`, and the incubator. |
| `experiments.py` | Every match experiment: lobby sizes, starting Catchers, pressure, conversion timing, deliberate surrender, pet power, the place's current end rule, banking, and visible-rarity targeting. About 1 hour on 4 cores; `--quick` is a 10% smoke run. |
| `longterm.py` | 15 min to 50 h careers, resampled from the 30-player match results: eggs, pets, duplicates, Gold, Gems, levels. |
| `tune.py` | Simulates 2,000 more 30-player matches, picks the evolution table that hits the rarity targets, sizes the hatch recipes to the pacing targets, and runs careers through the incubator. |
| `compare.py` | Scores the complete designs (A to D, plus today's place) on measured criteria under four weightings. |
| `cooldowns.py` | How often a rarity recharge bonus buys an extra ability use. |

Run order: `experiments.py`, `longterm.py`, `tune.py`, `compare.py`, `cooldowns.py`. Seeds are fixed. `results/manifest.json` lists every job's seed and match count.

**Pressure** is the knob for how good chasing is relative to escaping. Real players will set it, and no sim can. `loose` = 1.0, `base` = 1.6, `tight` = 2.0. With 30 players and 3 starting Catchers, Runner survival over three crossings is about 86%, 45% and 13%.

**Independent vs repeated:** each match in a job is an independent simulation. Scoring several egg rules or evolution tables on the same matches is repeated evaluation of one set of outcomes. Careers in `longterm.py` / `tune.py` are resampled from simulated matches, not new matches.
