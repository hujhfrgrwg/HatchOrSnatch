"""Run every HOS-ECON-001 experiment and write results to docs/economy-audit/results/.

    python3 tools/sim/experiments.py            # full run (~20-40 min on 4 cores)
    python3 tools/sim/experiments.py --quick    # small smoke run

Every job has its own seed (listed in results/manifest.json). Matches inside a job are independent
simulations. Where several egg rules or evolution tables are scored on the SAME simulated matches,
the results say so: those are repeated evaluations of one set of match outcomes, not new samples.
"""
from __future__ import annotations

import json
import os
import sys
import time
from multiprocessing import Pool

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from chase import SURRENDER, run_matches  # noqa: E402
from economy import (POLICIES, awards, currencies, make_evolution, player_facts,  # noqa: E402
                     reroll, survivor_distribution, EVOLUTION)

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "economy-audit", "results")
QUICK = "--quick" in sys.argv
SCALE = 0.1 if QUICK else 1.0
PRESSURES = {"loose": 1.0, "base": 1.6, "tight": 2.0}
EVOS = ["brief", "epic_heavy", "recommended", "code_levels", "deterministic"]


def n(x):
    return max(40, int(x * SCALE))


def ci(p, k):
    """95% Wilson interval half-width-ish summary for a proportion p from k samples."""
    if k == 0:
        return [None, None]
    z = 1.96
    den = 1 + z * z / k
    c = (p + z * z / (2 * k)) / den
    h = z * np.sqrt(p * (1 - p) / k + z * z / (4 * k * k)) / den
    return [round(float(c - h), 4), round(float(c + h), 4)]


def prop(mask_hit, mask_pop):
    k = int(mask_pop.sum())
    p = float(mask_hit[mask_pop].mean()) if k else float("nan")
    return dict(p=round(p, 4), n=k, ci95=ci(p, k))


def bins(skills):
    return dict(beginner=skills < -0.5, typical=np.abs(skills) <= 0.25, skilled=skills > 0.5,
                all=np.ones_like(skills, bool))


def paths(r):
    cc = r["caught_cross"]
    return dict(
        initial_catcher=r["initial"],
        caught_c1=cc == 1, caught_c2=cc == 2, caught_c3=cc == 3,
        timed_out=r["timeout_cross"] > 0, survivor=r["survived"],
    )


def dynamics(r):
    nr = np.array(r["n_runners"], float)
    nr[nr < 0] = np.nan
    ct = np.array(r["crossing_times"], float)
    caps = r["captures"]
    per_c = [float((caps[:, 1] == c).sum()) / r["M"] for c in range(1, len(r["n_runners"]) + 1)] if len(caps) else []
    surv = r["survived"].sum(1)
    runners0 = r["P"] - r["initial"].sum(1)
    cycle = 5 + np.nansum(ct + 4, 0) + 11 + 15
    return dict(
        runners_at_crossing_start=[round(float(np.nanmean(x)), 3) for x in nr],
        captures_per_crossing=[round(x, 3) for x in per_c],
        crossing_seconds=[round(float(np.nanmean(x)), 2) for x in ct],
        survivor_share=round(float((surv / runners0).mean()), 4),
        survivors_mean=round(float(surv.mean()), 3),
        zero_survivor_matches=round(float((surv == 0).mean()), 4),
        timeouts_per_match=round(float((r["timeout_cross"] > 0).sum(1).mean()), 3),
        est_cycle_seconds=round(float(cycle.mean()), 1),
    )


def score_policies(r, rng, evos=EVOS, policies=POLICIES, with_bins=True):
    out = {}
    for evo in evos:
        rr = reroll(r, evo, rng)
        f = player_facts(rr)
        for pol in policies:
            a = awards(rr, f, pol)
            got = a >= 0
            d = dict(
                eggs_per_match=round(float(got.sum(1).mean()), 3),
                supply_per_match={nm: round(float((a == i).sum(1).mean()), 4) for i, nm in enumerate(["Common", "Rare", "Epic", "Legendary"])},
            )
            if with_bins:
                sk = bins(rr["skills"])
                d["p_egg_by_skill"] = {k: prop(got, v) for k, v in sk.items()}
                d["p_egg_by_path"] = {k: prop(got, v) for k, v in paths(rr).items()}
                d["p_epic_plus_by_path"] = {k: prop(a >= 2, v) for k, v in paths(rr).items()}
                d["p_legendary_by_path"] = {k: prop(a == 3, v) for k, v in paths(rr).items()}
            out[f"{evo}/{pol}"] = d
    return out


# ------------------------------------------------------------------ jobs
def job_population(args):
    P, pname, n_initial, immediate, seed, M, keep = args
    rng = np.random.default_rng(seed)
    t0 = time.time()
    r = run_matches(M, P, rng, pressure=PRESSURES[pname], n_initial=n_initial,
                    immediate_conversion=immediate, evolution=make_evolution("brief"))
    res = dict(P=P, pressure=pname, n_initial=n_initial, immediate=immediate, seed=seed, matches=M,
               dynamics=dynamics(r), policies=score_policies(r, np.random.default_rng(seed + 1)))
    f = player_facts(r)
    gold, gems, xp, win = currencies(r, f)
    res["currency_per_match"] = dict(gold=round(float(gold.mean()), 2), gems=round(float(gems.mean()), 3), xp=round(float(xp.mean()), 1))
    res["initial_catcher"] = dict(
        steals_mean=round(float(f["n_steals"][r["initial"]].mean()), 3),
        p_any_steal=prop(f["n_steals"] > 0, r["initial"]),
    )
    res["converted_catcher_p_steal"] = prop(f["n_steals"] > 0, (r["caught_cross"] > 0))
    res["seconds"] = round(time.time() - t0, 1)
    if keep:
        # per player-match rows for the long-term economy (resampled later)
        rows = {}
        for evo in ["brief", "recommended", "code_levels"]:
            rr = reroll(r, evo, np.random.default_rng(seed + 2))
            ff = player_facts(rr)
            for pol in ["runner_only", "theft1", "theft2", "redeem", "code_v04"]:
                rows[f"{evo}/{pol}"] = awards(rr, ff, pol).ravel().astype(np.int8)
        np.savez_compressed(os.path.join(OUT, f"player_matches_P{P}_{pname}.npz"),
                            skill=r["skills"].ravel().astype(np.float32), gold=gold.ravel(), gems=gems.ravel(),
                            xp=xp.ravel(), initial=r["initial"].ravel(), **{k.replace("/", "__"): v for k, v in rows.items()})
    return res


def job_focal(args):
    """Player 0 has a fixed skill and a strategy; never the starting Catcher."""
    skill, strat, scross, pname, seed, M = args
    rng = np.random.default_rng(seed)
    P, NI = 30, 3
    skills = rng.normal(0, 0.6, (M, P))
    skills[:, 0] = skill
    strategies = np.zeros((M, P), int)
    sc = np.ones((M, P), int)
    if strat != "honest":
        strategies[:, 0] = SURRENDER
        sc[:, 0] = scross
    r = run_matches(M, P, rng, skills=skills, strategies=strategies, surrender_crossing=sc,
                    initial_select="not_focal", pressure=PRESSURES[pname], evolution=make_evolution("brief"),
                    n_initial=NI)
    out = dict(skill=skill, strategy=strat, surrender_crossing=scross if strat != "honest" else None,
               pressure=pname, seed=seed, matches=M, results={})
    focal = np.zeros((M, P), bool)
    focal[:, 0] = True
    f0 = player_facts(r)
    gold, gems, xp, win = currencies(r, f0)
    out["gold"] = round(float(gold[:, 0].mean()), 2)
    out["gems"] = round(float(gems[:, 0].mean()), 3)
    out["focal_caught_c"] = {c: round(float((r["caught_cross"][:, 0] == c).mean()), 4) for c in (1, 2, 3)}
    out["focal_survived"] = round(float(r["survived"][:, 0].mean()), 4)
    out["focal_steals_mean"] = round(float(f0["n_steals"][:, 0].mean()), 3)
    for evo in ["brief", "recommended", "code_levels"]:
        rr = reroll(r, evo, np.random.default_rng(seed + 1))
        f = player_facts(rr)
        for pol in POLICIES:
            a = awards(rr, f, pol)[:, 0]
            k = len(a)
            out["results"][f"{evo}/{pol}"] = dict(
                p_egg=round(float((a >= 0).mean()), 4), ci95=ci(float((a >= 0).mean()), k),
                dist=[round(float((a == i).mean()), 4) for i in range(4)],
                p_epic_plus=round(float((a >= 2).mean()), 4),
                value=round(float(np.where(a >= 0, np.array([0.25, 1, 2, 4])[np.clip(a, 0, 3)], 0).mean()), 4),
            )
    return out


def job_pet(args):
    bonus, skill, pname, seed, M = args
    rng = np.random.default_rng(seed)  # same seed for every bonus: common random numbers
    P, NI, K = 30, 3, 6  # K focal Runners per match carry the bonus (never starting Catchers)
    skills = rng.normal(0, 0.6, (M, P))
    skills[:, :K] = skill
    dm = np.ones((M, P))
    dm[:, :K] = 1 + bonus
    r = run_matches(M, P, rng, skills=skills, initial_select="not_focal", pressure=PRESSURES[pname],
                    dash_mult=dm, n_initial=NI)
    s = r["survived"][:, :K].ravel()
    return dict(bonus=bonus, skill=skill, pressure=pname, seed=seed, matches=M, samples=len(s),
                survive=round(float(s.mean()), 4), ci95=ci(float(s.mean()), len(s)),
                caught_c1=round(float((r["caught_cross"][:, :K] == 1).mean()), 4))


def job_code_rule(args):
    pname, P, seed, M = args
    rng = np.random.default_rng(seed)
    r = run_matches(M, P, rng, pressure=PRESSURES[pname], clean_streak=3, max_crossings=40,
                    n_initial=max(1, round(P / 10)))
    ec = r["end_cross"]
    surv = r["survived"].sum(1)
    return dict(pressure=pname, P=P, seed=seed, matches=M,
                crossings_mean=round(float(ec.mean()), 2),
                crossings_pct=[int(np.percentile(ec, q)) for q in (10, 50, 90)],
                share_hit_cap=round(float((ec >= 40).mean()), 4),
                runner_win=round(float((surv > 0).mean()), 4),
                survivors_mean=round(float(surv.mean()), 2),
                play_seconds_mean=round(float(np.nansum(np.array(r["crossing_times"], float), 0).mean()), 1),
                est_cycle_seconds=round(float((5 + np.nansum(np.array(r["crossing_times"], float) + 4, 0) + 26).mean()), 1),
                max_level_mean=round(float(r["level"].max(1).mean()), 2))


def job_bank(args):
    pname, seed, M = args
    rng = np.random.default_rng(seed)
    r = run_matches(M, 30, rng, pressure=PRESSURES[pname], bank_mode=True, evolution=make_evolution("brief"), n_initial=3)
    f = player_facts(r)
    res = dict(pressure=pname, seed=seed, matches=M, dynamics=dynamics(r))
    for pol in ["runner_only", "theft1", "banked"]:
        a = awards(r, f, pol)
        res[pol] = dict(eggs_per_match=round(float((a >= 0).sum(1).mean()), 3),
                        p_egg_caught_c1=prop(a >= 0, r["caught_cross"] == 1),
                        p_egg_initial=prop(a >= 0, r["initial"]))
    res["steals_per_match"] = round(len(r["captures"]) / M, 3)
    res["banked_per_match"] = round(len(r["banked"]) / M, 3)
    return res


def job_bias(args):
    bias, pname, seed, M = args
    rng = np.random.default_rng(seed)
    r = run_matches(M, 30, rng, pressure=PRESSURES[pname], rarity_bias=bias, evolution=make_evolution("brief"), n_initial=3)
    f = player_facts(r)
    caps = r["captures"]
    stolen = np.array([r["rarity_at"][int(c) - 1][int(m), int(j)] for m, c, i, j, t in caps]) if len(caps) else np.array([])
    # chance that a Legendary egg carried into the final crossing gets stolen there
    leg_c3 = r["rarity_at"][2] == 3
    caught3 = r["caught_cross"] == 3
    return dict(bias=bias, pressure=pname, seed=seed, matches=M,
                legendary_into_c3_per_match=round(float(leg_c3.sum(1).mean()), 4),
                p_legendary_stolen_in_c3=prop(caught3, leg_c3),
                p_rare_stolen_in_c3=prop(caught3, r["rarity_at"][2] == 1),
                stolen_rarity_share=[round(float((stolen == i).mean()), 4) for i in range(4)] if len(stolen) else None,
                survivors_mean=round(float(r["survived"].sum(1).mean()), 3))


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = dict(started=time.strftime("%Y-%m-%d %H:%M:%S"), quick=QUICK, jobs={})
    with Pool(4) as pool:
        # 1. population runs: lobby size x initial Catchers x pressure x conversion timing
        pop_args = []
        seed = 1000
        # main lobby: 30 players, 3 starting Catchers (Hunter, 16 Oct: ~30 players per match)
        for pname in PRESSURES:
            pop_args.append((30, pname, 3, False, seed, n(3000), True)); seed += 10
        for ni in (1, 2, 4):  # starting-Catcher count
            pop_args.append((30, "base", ni, False, seed, n(1000), False)); seed += 10
        pop_args.append((30, "base", 3, True, seed, n(1000), False)); seed += 10  # immediate conversion
        for P in (12, 16, 24):  # smaller lobbies, ~1 starting Catcher per 10 players
            for pname in PRESSURES:
                pop_args.append((P, pname, max(1, round(P / 10)), False, seed, n(1500), False)); seed += 10
        t = time.time()
        pop = pool.map(job_population, pop_args, chunksize=1)
        print("population", round(time.time() - t), "s", flush=True)
        json.dump(pop, open(os.path.join(OUT, "population.json"), "w"), indent=1)
        manifest["jobs"]["population"] = [(a[0], a[1], a[2], a[3], a[4], a[5]) for a in pop_args]

        # 2. strategy: honest vs deliberate surrender, by skill and pressure
        foc_args = []
        seed = 5000
        for pname in PRESSURES:
            for skill in (-1.0, 0.0, 1.0):
                for strat, sc in (("honest", 1), ("surrender", 1), ("surrender", 2), ("surrender", 3)):
                    foc_args.append((skill, strat, sc, pname, seed, n(1200)))
                    seed += 10
        t = time.time()
        foc = pool.map(job_focal, foc_args, chunksize=1)
        print("focal", round(time.time() - t), "s", flush=True)
        json.dump(foc, open(os.path.join(OUT, "strategy.json"), "w"), indent=1)
        manifest["jobs"]["strategy"] = foc_args

        # 3. pet power: dash distance bonus for one Runner (common random numbers per skill)
        pet_args = []
        for skill, seed in ((-1.0, 7000), (0.0, 7100)):
            for bonus in (0, .03, .045, .06, .10, .20):
                pet_args.append((bonus, skill, "base", seed, n(1500)))
        t = time.time()
        pet = pool.map(job_pet, pet_args, chunksize=1)
        print("pet", round(time.time() - t), "s", flush=True)
        json.dump(pet, open(os.path.join(OUT, "pet_power.json"), "w"), indent=1)
        manifest["jobs"]["pet_power"] = pet_args

        # 4. the place's current end rule (3 clean crossings in a row)
        cr_args = [(p, P, 8000 + 10 * i, n(600)) for i, (p, P) in enumerate((p, P) for p in PRESSURES for P in (8, 12, 16))]
        bank_args = [(p, 9000 + 10 * i, n(1000)) for i, p in enumerate(PRESSURES)]
        bias_args = [(b, "base", 9500 + 10 * i, n(1000)) for i, b in enumerate((0.0, 1.0, 3.0))]
        t = time.time()
        cr = pool.map(job_code_rule, cr_args, chunksize=1)
        bank = pool.map(job_bank, bank_args, chunksize=1)
        bias = pool.map(job_bias, bias_args, chunksize=1)
        print("rules", round(time.time() - t), "s", flush=True)
        json.dump(cr, open(os.path.join(OUT, "code_end_rule.json"), "w"), indent=1)
        json.dump(bank, open(os.path.join(OUT, "banking.json"), "w"), indent=1)
        json.dump(bias, open(os.path.join(OUT, "visible_rarity_targeting.json"), "w"), indent=1)
        manifest["jobs"].update(code_end_rule=cr_args, banking=bank_args, visible_rarity_targeting=bias_args)
    manifest["survivor_distributions"] = {k: [round(float(x), 4) for x in survivor_distribution(k)] for k in EVOLUTION}
    manifest["finished"] = time.strftime("%Y-%m-%d %H:%M:%S")
    json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w"), indent=1, default=str)


if __name__ == "__main__":
    main()
