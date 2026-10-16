"""Long-term progression for Hatch or Snatch (HOS-ECON-001).

Builds player careers by resampling per-player match outcomes from the 30-player match simulations
(results/player_matches_P30_<pressure>.npz). These careers are RESAMPLED from simulated matches:
they are not new match simulations, and they assume a player's matches are independent given their
skill band (no learning, no tilt, no friends). Run experiments.py first.

    python3 tools/sim/longterm.py
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from economy import RECIPES_BRIEF, RECIPES_REC, incubate, level_for  # noqa: E402

RES = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "economy-audit", "results")
HOURS = [0.25, 1, 5, 10, 25, 50]
MPH = 45  # matches per hour of play (measured ~65-70 s cycle + ~15% lobby/menu time); GDD assumed 26.7
COHORTS = {"beginner": lambda s: s < -0.5, "typical": lambda s: np.abs(s) <= 0.25, "skilled": lambda s: s > 0.5}
SEED = 424242
XP_T = np.concatenate([[0], np.cumsum([100 + 25 * (l - 1) for l in range(1, 2000)])])  # XP to reach level L+1

# today's shop (EconomyConfig.SHOP + EmoteConfig.CRATE_GEMS), for spending capacity
GOLD_ITEMS = {"Sparkle Trail (1 match)": 40, "Confetti Burst": 75, "Frost Egg Case": 900, "Bolt Entrance": 1400, "Sunset Egg Case": 2400}
GEM_ITEMS = {"Rainbow Trail": 150, "Gold Ability Colors": 250, "Emote Crate (1 random)": 250, "Royal Hatching": 350}


def pct(a, q):
    a = np.asarray([x for x in a if x is not None], float)
    return None if len(a) == 0 else round(float(np.percentile(a, q)), 2)


def careers(rows, idx, n_players, n_matches, rng):
    pick = rng.choice(idx, size=(n_players, n_matches))
    return {k: v[pick] for k, v in rows.items()}


def main():
    rng = np.random.default_rng(SEED)
    out = dict(seed=SEED, matches_per_hour=MPH, hours=HOURS, note="careers resampled from simulated 30-player matches", runs={})
    for pressure in ("loose", "base", "tight"):
        path = os.path.join(RES, f"player_matches_P30_{pressure}.npz")
        if not os.path.exists(path):
            continue
        z = dict(np.load(path))
        skill = z.pop("skill")
        for cname, sel in COHORTS.items():
            idx = np.nonzero(sel(skill))[0]
            n_players = 600
            n_matches = int(max(HOURS) * MPH)
            C = careers(z, idx, n_players, n_matches, rng)
            base = dict(rows_available=int(len(idx)))
            # currencies, with level-up pay (50 Gold per level, 10 Gems every 5th level)
            cum_gold = C["gold"].cumsum(1)
            cum_gems = C["gems"].cumsum(1)
            cum_xp = C["xp"].cumsum(1)
            lv_all = np.searchsorted(XP_T, cum_xp, side="right")  # account level after each match
            g_all = cum_gold + 50 * (lv_all - 1)
            gm_all = cum_gems + 10 * ((lv_all - 1) // 5)
            cur = {}
            for h in HOURS:
                k = int(h * MPH) - 1
                cur[str(h)] = dict(gold_median=int(np.median(g_all[:, k])), gems_median=int(np.median(gm_all[:, k])),
                                   level_median=int(np.median(lv_all[:, k])))
            base["currency"] = cur
            base["gold_per_hour"] = round(float(C["gold"].mean() * MPH), 1)
            base["gems_per_hour"] = round(float(C["gems"].mean() * MPH), 2)
            def first_hour(cum, price):
                k = (cum >= price).argmax(1).astype(float)
                k[~(cum >= price).any(1)] = np.nan
                return round(float(np.nanmedian(k + 1) / MPH), 2)

            base["median_hours_to_afford_from_zero"] = {
                **{f"gold:{k}": first_hour(g_all, v) for k, v in GOLD_ITEMS.items()},
                **{f"gems:{k}": first_hour(gm_all, v) for k, v in GEM_ITEMS.items()},
            }
            for key in [k for k in C if "__" in k]:
                evo, pol = key.split("__")
                eggs = C[key].astype(int)
                got = eggs >= 0
                d = dict(p_egg_per_match=round(float(got.mean()), 4))
                d["rarity_share_of_eggs"] = [round(float((eggs == i).sum() / max(1, got.sum())), 4) for i in range(4)]
                # dry spells: chance a NEW player's first k matches give no egg
                d["p_no_egg_in_first"] = {str(k): round(float((~got[:, :k]).all(1).mean()), 4) for k in (3, 5, 10)}
                # longest dry run in the first 2 hours
                runs = []
                for row in got[:, : 2 * MPH]:
                    best = cur_ = 0
                    for x in row:
                        cur_ = 0 if x else cur_ + 1
                        best = max(best, cur_)
                    runs.append(best)
                d["longest_dry_run_first_2h"] = dict(median=pct(runs, 50), p90=pct(runs, 90))
                inv = {}
                for h in HOURS:
                    k = int(h * MPH)
                    inv[str(h)] = [round(float((eggs[:, :k] == i).sum(1).mean()), 2) for i in range(4)]
                d["eggs_held_by_hour_before_hatching"] = inv
                # incubation variants
                inc = {}
                for rname, rec in (("brief", RECIPES_BRIEF), ("rec", RECIPES_REC)):
                    for fp in ("free_on_first", "consume_first", "two_eggs", "none_special"):
                        for fam in (3, 9):
                            if fp != "consume_first" and (fam == 9 or rname == "rec"):
                                continue  # first-pet variants only matter for first-pet timing
                            res = [incubate(list(row), families=fam, recipes=rec, first_pet=fp, rng=np.random.default_rng(i), common_fuse=3 if rname == "rec" else None)
                                   for i, row in enumerate(eggs[:200])]
                            mins = 60 / MPH

                            def stat(vals):
                                v = [x for x in vals]
                                never = sum(1 for x in v if x is None) / len(v)
                                got_ = [x + 1 for x in v if x is not None]
                                return dict(median_h=None if never >= 0.5 else round(float(np.percentile([x if x is not None else 1e9 for x in v], 50)) * mins / 60, 2),
                                            p90_h=None if never >= 0.1 else round(float(np.percentile([x if x is not None else 1e9 for x in v], 90)) * mins / 60, 2),
                                            share_never_in_50h=round(never, 3),
                                            median_matches=None if never >= 0.5 else int(np.percentile([x if x is not None else 1e9 for x in v], 50)) + 1)
                            inc[f"{rname}/{fp}/{fam}fam"] = dict(
                                first_pet=stat([r["first_pet_at"] for r in res]),
                                first_rare_pet=stat([r["pets_at"][1] for r in res]),
                                first_epic_pet=stat([r["pets_at"][2] for r in res]),
                                first_legendary_pet=stat([r["pets_at"][3] for r in res]),
                                target_family_epic=stat([r["target_at"][2] for r in res]),
                                target_family_legendary=stat([r["target_at"][3] for r in res]),
                                pets_owned_50h=pct([r["owned"] for r in res], 50),
                                duplicate_hatches_50h=pct([r["dupes"] for r in res], 50),
                                leftover_common_eggs_50h=pct([r["inv"][0] for r in res], 50),
                            )
                d["incubation"] = inc
                base[key] = d
            out["runs"][f"{pressure}/{cname}"] = base
            print(pressure, cname, flush=True)
    json.dump(out, open(os.path.join(RES, "longterm.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
