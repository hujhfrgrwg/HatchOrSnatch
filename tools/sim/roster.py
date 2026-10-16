"""Careers against the cofounder roster handoff (16 Oct): 5 archetypes x 4 rarities = 20 species, each
with three cosmetic mutation levels. How fast does a typical player collect species, and how many
duplicates pile up per species (the natural feed for mutation levels)? (HOS-ECON-001 follow-up.)

Egg stream: the recommended strict Snatch-back rule and tuned table on tune.py's 2,000 base matches,
typical players, resampled (300 careers x 50 h at 45 matches/h). Recipes from recommended_economy.json.
Common eggs: variant "fuse" (3 Commons -> 1 Rare egg) vs "common_hatch" (3 Commons hatch a Common
species the player is missing, then fuse once all five are owned). Writes results/roster_careers.json.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from economy import EVOLUTION, awards, player_facts, reroll  # noqa: E402
import tune  # noqa: E402

FAM, MPH, HOURS = 5, tune.MPH, 50
CHECK = (1, 5, 10, 25, 50)
rec = json.load(open(os.path.join(tune.RES, "recommended_economy.json")))
EVOLUTION["_t"] = tune.table(*rec["chosen_params"])
recipes = {int(k): v for k, v in rec["recipes"].items()}


def career(stream, variant, rng):
    inv = np.zeros(4, int)
    copies = np.zeros((FAM, 4), int)  # hatches per species (first copy + duplicates)
    target = int(rng.integers(FAM))
    first = None
    snaps = {}
    for k, e in enumerate(stream):
        if e >= 0:
            inv[e] += 1
            if first is None:  # first won egg: free Common pet of the chosen archetype, egg kept
                first = k
                copies[target, 0] += 1
            if variant == "common_hatch" and (copies[:, 0] == 0).any():
                while inv[0] >= 3 and (copies[:, 0] == 0).any():
                    inv[0] -= 3
                    copies[int(rng.choice(np.nonzero(copies[:, 0] == 0)[0])), 0] += 1
            if inv[0] >= 3 and (variant == "fuse" or not (copies[:, 0] == 0).any()):
                inv[1] += inv[0] // 3
                inv[0] %= 3
            for rar in (3, 2, 1):
                rnd, foc = recipes[rar]
                while True:
                    focus = copies[target, rar] == 0
                    cost = foc if focus else rnd
                    if inv[rar] < cost:
                        break
                    inv[rar] -= cost
                    copies[target if focus else int(rng.integers(FAM)), rar] += 1
        h = (k + 1) / MPH
        if h in CHECK:
            snaps[h] = copies.copy()
    return snaps


def main():
    r = tune.load_or_run()
    rr = reroll(r, "_t", np.random.default_rng(1))
    a = awards(rr, player_facts(rr), tune.RULE)
    pool = a[np.abs(rr["skills"]) <= 0.25]
    rng = np.random.default_rng(51000)
    streams = rng.choice(pool, size=(300, HOURS * MPH))
    out = dict(species=FAM * 4, careers=300, hours=HOURS, matches_per_hour=MPH, recipes=recipes, variants={})
    for variant in ("fuse", "common_hatch"):
        snaps = [career(list(s), variant, np.random.default_rng(i)) for i, s in enumerate(streams)]
        v = {}
        for h in CHECK:
            c = np.array([s[h] for s in snaps])  # careers x FAM x 4
            owned = (c > 0)
            dup = np.maximum(c - 1, 0)
            v[f"{h}h"] = dict(
                species_owned_median=float(np.median(owned.sum((1, 2)))),
                owned_by_rarity_median=[float(np.median(owned[:, :, i].sum(1))) for i in range(4)],
                all_20_share=round(float(owned.all((1, 2)).mean()), 3),
                dupes_total_median=float(np.median(dup.sum((1, 2)))),
                # duplicates of an owned species, by rarity: median and p90 over owned species
                dupes_per_owned_species=[dict(median=float(np.median(dup[:, :, i][owned[:, :, i]])) if owned[:, :, i].any() else None,
                                              p90=float(np.percentile(dup[:, :, i][owned[:, :, i]], 90)) if owned[:, :, i].any() else None)
                                         for i in range(4)])
        out["variants"][variant] = v
        print(variant, json.dumps(v["10h"]), json.dumps(v["50h"]), flush=True)
    json.dump(out, open(os.path.join(tune.RES, "roster_careers.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
