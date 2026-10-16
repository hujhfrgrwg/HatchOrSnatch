"""Hero solo crossing (Huss Valley's "Hero or Chicken"): how often does one Runner cross alone
against the starting Catchers? (HOS-ECON-001 follow-up.) Writes results/hero_solo.json."""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from chase import run_matches  # noqa: E402

RES = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "economy-audit", "results")
out = {}
M = 2000
for pressure, pv in (("loose", 2.0), ("base", 2.6), ("tight", 3.2)):
    for nc in (1,):
        for skill in (-1.0, 0.0, 1.0):
            rng = np.random.default_rng(31000 + nc * 10 + int(pv * 10) + int(skill * 3))
            sk = np.full((M, nc + 1), 0.0)
            sk[:, 0] = skill
            r = run_matches(M, nc + 1, rng, n_crossings=1, skills=sk, n_initial=nc, initial_select="not_focal", pressure=pv)
            p = float(r["survived"][:, 0].mean())
            out[f"{pressure}/catchers{nc}/skill{skill:+.0f}"] = round(p, 3)
            print(pressure, nc, skill, round(p, 3), flush=True)
json.dump(dict(matches_per_cell=M, hero_crosses=out), open(os.path.join(RES, "hero_solo.json"), "w"), indent=1)
