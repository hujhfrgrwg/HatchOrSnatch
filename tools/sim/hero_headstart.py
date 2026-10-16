"""Hero run with a head start: how long must the lone Catcher be held for a hero to cross about
half the time? (HOS-ECON-001 follow-up, one starting Catcher.) Writes results/hero_headstart.json."""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import chase  # noqa: E402

RES = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "economy-audit", "results")
M = 1500
out = {}
for pressure, pv in (("loose", 2.0), ("base", 2.6), ("tight", 3.2)):
    for hold in (0.75, 1.5, 2.5, 3.5, 4.5):
        chase.RELEASE = hold
        for skill in (-1.0, 0.0, 1.0):
            rng = np.random.default_rng(32000 + int(hold * 10) + int(pv * 100) + int(skill * 3))
            sk = np.zeros((M, 2))
            sk[:, 0] = skill
            r = chase.run_matches(M, 2, rng, n_crossings=1, skills=sk, n_initial=1, initial_select="not_focal", pressure=pv)
            p = round(float(r["survived"][:, 0].mean()), 3)
            out[f"{pressure}/hold{hold}/skill{skill:+.0f}"] = p
            print(pressure, hold, skill, p, flush=True)
json.dump(dict(matches_per_cell=M, hero_crosses=out), open(os.path.join(RES, "hero_headstart.json"), "w"), indent=1)
