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
| `robustness.py` | Re-checks the egg rules at loose and tight Catcher strength with the tuned table. |
| `hero.py`, `hero_headstart.py` | Hero or Chicken: a lone Runner against the one starting Catcher, with and without extra start protection. |

Run order: `experiments.py`, `longterm.py`, `tune.py`, `compare.py`, `robustness.py`, `cooldowns.py`, `hero.py`, `hero_headstart.py`. Seeds are fixed. `results/manifest.json` lists every job's seed and match count.

**Pressure** is the knob for how good chasing is relative to escaping. Real players and the Catcher's tools will set it, and no sim can. With one starting Catcher (Hunter, 16 Oct): `loose` = 2.0, `base` = 2.6, `tight` = 3.2, giving Runner survival over three crossings of about 65%, 47% and 31% in a 30-player match. The earlier 3-Catcher runs used 1.0 / 1.6 / 2.0; they are in git history.

**Independent vs repeated:** each match in a job is an independent simulation. Scoring several egg rules or evolution tables on the same matches is repeated evaluation of one set of outcomes. Careers in `longterm.py` / `tune.py` are resampled from simulated matches, not new matches.
