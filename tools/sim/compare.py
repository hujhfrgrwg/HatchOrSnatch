"""Compare complete design configurations on measured criteria, under several weightings (HOS-ECON-001).

Scores the SAME 2,000 simulated 30-player matches (results/raw_P30_base.npz, from tune.py) under
each configuration's egg rule, with the tuned evolution table. "Surrender payoff" uses players who
were caught in crossing 1 or 2 (whichever pays more) as the stand-in for someone who gives up then (strategy.json
checks this stand-in against simulations where one player really surrenders).

Egg use-value (hours of pacing each egg is worth) comes from the recommended recipes: an egg of
rarity r is worth target_hours[r] / recipe[r]; a Common egg is worth a third of a Rare (fusion).
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
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

r = tune.load_or_run()
rr = reroll(r, "_t", np.random.default_rng(1))
f = player_facts(rr)
sk = rr["skills"]
beg, skl = sk < -0.5, sk > 0.5
runner = ~rr["initial"]
c1 = rr["caught_cross"] == 1
c2 = rr["caught_cross"] == 2

CONFIGS = {
    "A Accessible (1 theft = egg at stolen rarity)": dict(policy="theft1", complexity=1, loss_sting=1),
    "B Competitive (Runners only; 2 thefts for Catchers)": dict(policy="theft2", complexity=2, loss_sting=2),
    "C High-stakes (bank the stolen egg; steals drop a rarity)": dict(policy="stolen_down", complexity=3, loss_sting=3),
    "D Snatch-back cap (steal up to the rarity of the egg you lost)": dict(policy="redeem", complexity=2, loss_sting=2),
    "D+1 Snatch-back +1 (steal up to 1 rarity above the egg you lost)": dict(policy="redeem_plus1", complexity=2, loss_sting=2),
    "Today's place (every active player gets a piece)": dict(policy="code_v04", complexity=1, loss_sting=0),
}
rows = {}
for name, c in CONFIGS.items():
    a = awards(rr, f, c["policy"])
    got = a >= 0
    v = np.where(got, val[np.clip(a, 0, 3)], 0.0)
    honest = v[runner].mean()
    surrender = max(v[c1].mean(), v[c2].mean())  # the better of giving up in crossing 1 or 2
    # new player frustration: chance of 5 matches in a row without an egg, beginners (independent matches)
    pb = got[beg].mean()
    rows[name] = dict(
        egg_rate_beginner=round(float(pb), 3),
        p_no_egg_5_beginner=round(float((1 - pb) ** 5), 4),
        honest_over_surrender_value=round(float(honest / max(surrender, 1e-9)), 2),
        starting_catcher_over_runner_value=round(float(v[rr["initial"]].mean() / honest), 3),
        skilled_over_beginner_value=round(float(v[skl].mean() / v[beg].mean()), 3),
        legendary_share_of_eggs=round(float((a == 3).sum() / max(got.sum(), 1)), 4),
        eggs_per_match=round(float(got.sum(1).mean()), 2),
        complexity=c["complexity"], loss_sting=c["loss_sting"],
    )

# criteria -> (higher is better?, how to normalise to 0..1 across configs)
CRIT = {
    "accessibility": ("egg_rate_beginner", True),
    "low_frustration": ("p_no_egg_5_beginner", False),
    "exploit_resistance": ("honest_over_surrender_value", True),
    "skill_reward": ("skilled_over_beginner_value", True),
    "catcher_reward": ("starting_catcher_over_runner_value", True),
    "scarcity": ("eggs_per_match", False),
    "simplicity": ("complexity", False),
    "meaningful_risk": ("loss_sting", True),
}


def norm(key, hi):
    xs = np.array([rows[n][key] for n in rows], float)
    if key == "honest_over_surrender_value":
        xs = np.minimum(xs, 3.0)  # beyond 3x honest play is clearly better; extra margin buys nothing
    lo, up = xs.min(), xs.max()
    s = (xs - lo) / (up - lo) if up > lo else np.ones_like(xs)
    return s if hi else 1 - s


WEIGHTS = {
    "balanced": dict(catcher_reward=1, accessibility=1, low_frustration=1, exploit_resistance=1, skill_reward=1, scarcity=1, simplicity=1, meaningful_risk=1),
    "growth (new players first)": dict(catcher_reward=1, accessibility=3, low_frustration=3, exploit_resistance=1, skill_reward=0.5, scarcity=0.5, simplicity=2, meaningful_risk=0.5),
    "integrity (no exploits, skill counts)": dict(catcher_reward=1, accessibility=1, low_frustration=1, exploit_resistance=3, skill_reward=2, scarcity=1, simplicity=1, meaningful_risk=1),
    "hardcore (scarce, risky)": dict(catcher_reward=1, accessibility=0.5, low_frustration=0.5, exploit_resistance=2, skill_reward=2, scarcity=3, simplicity=0.5, meaningful_risk=3),
}
# a hard gate before any weighting: a rule where giving up pays at least as well as playing fails
names = list(rows)
scores = {}
for wname, w in WEIGHTS.items():
    tot = np.zeros(len(names))
    for crit, (key, hi) in CRIT.items():
        tot += w[crit] * norm(key, hi)
    tot /= sum(w.values())
    scores[wname] = {n: round(float(t), 3) for n, t in zip(names, tot)}
gate = {n: rows[n]["honest_over_surrender_value"] > 1.2 for n in names}
out = dict(egg_use_value_hours=[round(float(x), 4) for x in val], configs=rows, scores=scores, passes_exploit_gate=gate,
           note="same 2,000 simulated matches scored under each rule (repeated evaluation)")
json.dump(out, open(os.path.join(RES, "design_comparison.json"), "w"), indent=1)
print(json.dumps(out, indent=1))
