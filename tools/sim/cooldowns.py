"""Cooldown thresholds: how often a rarity recharge bonus buys an extra ability use (HOS-ECON-001).

A Runner uses their ability ~3 s into each crossing where it is ready. Crossings last ~7 s in the
30-player simulation (sd 1.5 s) with 4 s transitions (GameConfig.Timing.WAVE_TRANSITION) and a
0.75 s Catcher hold. Cooldowns from EconomyConfig.FAMILIES. Output: expected uses per 3-crossing
match for each rarity bonus. Seeded, 200,000 simulated match timelines per cell.
"""
import json
import os

import numpy as np

COOLDOWNS = {"Brake": 10, "Scout": 18, "Decoy": 20}
BONUS = {"Common": 0, "Rare": .015, "Epic": .03, "Legendary": .045, "Cosmic": .06, "+10% (test)": .10}
rng = np.random.default_rng(31)
N = 200_000
dur = np.clip(rng.normal(7, 1.5, (N, 3)), 4, 30)
use_offset = np.clip(rng.normal(3, 1, (N, 3)), 0.5, None)
starts = np.zeros((N, 3))
for c in range(1, 3):
    starts[:, c] = starts[:, c - 1] + dur[:, c - 1] + 4 + 0.75
out = {}
for fam, cd0 in COOLDOWNS.items():
    out[fam] = {}
    for rname, b in BONUS.items():
        cd = cd0 * (1 - b)
        ready = np.zeros(N)
        uses = np.zeros(N)
        for c in range(3):
            # use as soon as it's ready during the crossing (and the Runner is still in it)
            t_want = starts[:, c] + use_offset[:, c]
            t_use = np.maximum(t_want, ready)
            ok = t_use <= starts[:, c] + dur[:, c]
            uses += ok
            ready = np.where(ok, t_use + cd, ready)
        out[fam][rname] = round(float(uses.mean()), 3)
path = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "economy-audit", "results", "cooldowns.json")
json.dump(dict(seed=31, timelines=N, uses_per_match=out), open(path, "w"), indent=1)
print(json.dumps(out, indent=1))
