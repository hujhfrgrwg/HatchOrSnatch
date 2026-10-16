"""Does the recommended egg rule hold at every Catcher strength? (HOS-ECON-001, one starting Catcher.)

Simulates 1,200 new 30-player matches at loose and tight pressure (base reuses tune.py's 2,000),
scores them with the tuned evolution table and recipe-based egg values (as compare.py), and reports
honest play vs the better of being caught in crossing 1 or 2. Writes results/robustness_by_pressure.json.
"""
import json
import os
import sys
from multiprocessing import Pool

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from chase import run_matches  # noqa: E402
from economy import EVOLUTION, awards, player_facts, reroll  # noqa: E402
import tune  # noqa: E402

RES = tune.RES
rec = json.load(open(os.path.join(RES, "recommended_economy.json")))
EVOLUTION["_t"] = tune.table(*rec["chosen_params"])
recipes = {int(k): v for k, v in rec["recipes"].items()}
val = np.zeros(4)
for r_, h in tune.TARGET_HOURS.items():
    val[r_] = h / recipes[r_][0]
val[0] = val[1] / 3


def _run(a):
    seed, M, pv = a
    return run_matches(M, 30, np.random.default_rng(seed), pressure=pv, n_initial=1)


def score(r):
    rr = reroll(r, "_t", np.random.default_rng(1))
    f = player_facts(rr)
    runner, cc = ~rr["initial"], rr["caught_cross"]
    out = dict(survive=round(float(rr["survived"][runner].mean()), 3))
    for pol in ("theft1", "redeem", "redeem_plus1", "stolen_down"):
        a = awards(rr, f, pol)
        v = np.where(a >= 0, val[np.clip(a, 0, 3)], 0.0)
        honest = v[runner].mean()
        out[pol] = dict(p_egg_runner=round(float((a[runner] >= 0).mean()), 3),
                        honest_over_caught_c1=round(float(honest / v[cc == 1].mean()), 2),
                        honest_over_caught_c2=round(float(honest / v[cc == 2].mean()), 2),
                        starting_catcher_over_runner=round(float(v[rr["initial"]].mean() / honest), 2))
    return out


if __name__ == "__main__":
    res = {"base": score(tune.load_or_run())}
    with Pool(4) as p:
        for name, pv, seed in (("loose", 2.0, 41000), ("tight", 3.2, 42000)):
            parts = p.map(_run, [(seed + k, 300, pv) for k in range(4)])
            res[name] = score(tune.merge(parts))
            print(name, res[name], flush=True)
    json.dump(dict(egg_value_hours=[round(float(x), 4) for x in val], by_pressure=res), open(os.path.join(RES, "robustness_by_pressure.json"), "w"), indent=1)
    print(json.dumps(res, indent=1))
