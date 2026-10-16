"""Tune the recommended evolution table and hatch recipes against pacing targets (HOS-ECON-001).

1. Simulates 2,000 independent 30-player matches (1 starting Catcher, base pressure) and keeps the
   raw outcomes (results/raw_P30_base.npz).
2. Re-scores those SAME matches under a grid of evolution tables (repeated evaluation, not new
   matches) with the recommended egg rule ("redeem") and reports egg rates per player-hour.
3. Plays resampled careers through the incubator for the chosen table and recipes.

Pacing targets (a design choice, stated in the report): typical player's first pet in session 1
(< 10 min), first Rare pet < 1 h, first Epic pet 3-6 h, first Legendary pet 15-30 h, median.
"""
from __future__ import annotations

import itertools
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from chase import run_matches  # noqa: E402
from economy import EVOLUTION, awards, incubate, player_facts, reroll  # noqa: E402

RES = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "economy-audit", "results")
MPH = 45
SEED = 12000


def load_or_run():
    path = os.path.join(RES, "raw_P30_base.npz")
    if os.path.exists(path):
        z = np.load(path, allow_pickle=True)
        return z["r"].item()
    rng = np.random.default_rng(SEED)
    from multiprocessing import Pool
    with Pool(4) as p:
        parts = p.map(_run, [(SEED + k, 500) for k in range(4)])
    r = merge(parts)
    np.savez_compressed(path, r=np.array(r, dtype=object))
    return r


def _run(a):
    seed, M = a
    return run_matches(M, 30, np.random.default_rng(seed), pressure=2.6, n_initial=1)  # base pressure, 1 starting Catcher


def merge(parts):
    out = dict(parts[0])
    M = sum(p["M"] for p in parts)
    for k in ["skills", "strategies", "initial", "survived", "rarity", "level", "crossings", "caught_cross", "timeout_cross", "lost_rarity", "end_cross"]:
        out[k] = np.concatenate([p[k] for p in parts])
    out["rarity_at"] = [np.concatenate([p["rarity_at"][c] for p in parts]) for c in range(3)]
    caps, off = [], 0
    for p in parts:
        c = p["captures"].copy()
        c[:, 0] += off
        caps.append(c)
        off += p["M"]
    out["captures"] = np.concatenate(caps)
    out["banked"] = np.zeros((0, 4))
    out["M"] = M
    return out


def table(p2_e, p2_l, p3_re, p3_rl, p3_el):
    return {1: {0: [(1, 1.0)]},
            2: {1: [(1, 1 - p2_e - p2_l), (2, p2_e), (3, p2_l)]},
            3: {1: [(1, 1 - p3_re - p3_rl), (2, p3_re), (3, p3_rl)], 2: [(2, 1 - p3_el), (3, p3_el)]}}


# Recommended egg rule. With one starting Catcher (16 Oct) the "+1" cap let players caught in
# crossing 2 out-earn honest play, so the strict cap ("redeem") is the recommendation.
RULE = "redeem"
TARGET_HOURS = {1: 1.0, 2: 5.0, 3: 25.0}  # median hours to the first pet of each rarity (typical player)


def value_table(a, mask):
    """Value of an egg of each rarity = hours a typical player needs to earn one (inverse rate)."""
    rate = np.array([(a[mask] == i).mean() * MPH for i in range(4)])
    return np.where(rate > 0, 1 / np.maximum(rate, 1e-9), 0.0), rate


def main():
    r = load_or_run()
    typical = np.abs(r["skills"]) <= 0.25
    rows = []
    grid = itertools.product([.10, .20, .30], [.005, .01, .02], [.10, .20, .30], [0, .002, .005], [.01, .03, .06])
    for g in grid:
        EVOLUTION["_t"] = table(*g)
        rr = reroll(r, "_t", np.random.default_rng(1))
        f = player_facts(rr)
        row = dict(params=g, legendary_into_final_per_match=round(float((rr["rarity_at"][2] == 3).sum(1).mean()), 3))
        for pol in ("redeem", "redeem_plus1"):
            a = awards(rr, f, pol)[typical]
            got = a >= 0
            row[pol] = dict(share=[round(float((a == i).sum() / got.sum()), 4) for i in range(4)],
                            eggs_per_hour=[round(float((a == i).mean() * MPH), 3) for i in range(4)])
        rows.append(row)
    json.dump(rows, open(os.path.join(RES, "tuning_grid.json"), "w"), indent=0)
    # pick: Legendary 0.8-1.6% of eggs, Epic 8-16%, a visible Legendary in >= 1 of 4 matches; then
    # the table closest to Legendary 1.2% / Epic 12%
    ok = [x for x in rows if 0.008 <= x[RULE]["share"][3] <= 0.016 and 0.08 <= x[RULE]["share"][2] <= 0.16
          and x["legendary_into_final_per_match"] >= 0.25]
    pool = ok or rows
    best = min(pool, key=lambda x: abs(x[RULE]["share"][3] - 0.012) * 10 + abs(x[RULE]["share"][2] - 0.12))
    print("chosen", best)
    EVOLUTION["_t"] = table(*best["params"])
    rr = reroll(r, "_t", np.random.default_rng(1))
    f = player_facts(rr)
    out = dict(chosen_params=best["params"], chosen_table={str(k): {str(a): b for a, b in v.items()} for k, v in table(*best["params"]).items()},
               candidates_meeting_targets=len(ok), matches=r["M"], seed=SEED, paths={})
    # incentive check by path: does any way of getting caught beat running honestly?
    cc = rr["caught_cross"]
    paths = dict(initial=rr["initial"], caught_c1=cc == 1, caught_c2=cc == 2, caught_c3=cc == 3,
                 survivor=rr["survived"], runner_any=~rr["initial"])
    for pol in ("runner_only", "theft1", "theft2", "stolen_down", "redeem", "redeem_plus1", "code_v04"):
        a = awards(rr, f, pol)
        val, rate = value_table(a, typical)
        v = np.where(a >= 0, val[np.clip(a, 0, 3)], 0.0)
        out["paths"][pol] = {k: dict(p_egg=round(float((a[m] >= 0).mean()), 4), value_hours=round(float(v[m].mean()), 4),
                                      dist=[round(float((a[m] == i).mean()), 4) for i in range(4)]) for k, m in paths.items()}
        out["paths"][pol]["_egg_value_hours"] = [round(float(x), 4) for x in val]
    # recipes sized to the pacing targets from the chosen table's typical rates (recommended rule)
    a = awards(rr, f, RULE)
    rate = np.array([(a[typical] == i).mean() * MPH for i in range(4)])
    common_as_rare = rate[0] / 3  # 3 Common fuse into 1 Rare
    rec = {}
    for rar, h in TARGET_HOURS.items():
        per_h = rate[rar] + (common_as_rare if rar == 1 else 0)
        base = max(3, int(round(per_h * h)))
        rec[rar] = (base, int(np.ceil(base * 1.25)))
    out["eggs_per_hour_typical"] = [round(float(x), 3) for x in rate]
    out["recipes"] = {str(k): v for k, v in rec.items()}
    # careers through the incubator with those recipes (resampled from these matches)
    rng = np.random.default_rng(SEED + 7)
    res_all = {}
    for cname, sel in {"beginner": r["skills"] < -0.5, "typical": typical, "skilled": r["skills"] > 0.5}.items():
        pool_ = a[sel]
        for fam in (3, 9):
            streams = rng.choice(pool_, size=(300, 50 * MPH))
            res = [incubate(list(s), families=fam, recipes=rec, first_pet="consume_first", common_fuse=3,
                            rng=np.random.default_rng(i)) for i, s in enumerate(streams)]

            def st(vals):
                arr = np.array([x if x is not None else np.inf for x in vals], float) + 1
                return dict(median_h=round(float(np.percentile(arr, 50) / MPH), 2) if np.isfinite(np.percentile(arr, 50)) else None,
                            p90_h=round(float(np.percentile(arr, 90) / MPH), 2) if np.isfinite(np.percentile(arr, 90)) else None,
                            never_in_50h=round(float(np.isinf(arr).mean()), 3))
            res_all[f"{cname}/{fam}fam"] = dict(
                first_pet=st([x["first_pet_at"] for x in res]), first_rare=st([x["pets_at"][1] for x in res]),
                first_epic=st([x["pets_at"][2] for x in res]), first_legendary=st([x["pets_at"][3] for x in res]),
                chosen_family_epic=st([x["target_at"][2] for x in res]), chosen_family_legendary=st([x["target_at"][3] for x in res]),
                pets_owned_50h=float(np.median([x["owned"] for x in res])), dupes_50h=float(np.median([x["dupes"] for x in res])))
    out["careers"] = res_all
    json.dump(out, open(os.path.join(RES, "recommended_economy.json"), "w"), indent=1)
    print(json.dumps({k: out[k] for k in ("recipes", "eggs_per_hour_typical")}, indent=1))


if __name__ == "__main__":
    main()
