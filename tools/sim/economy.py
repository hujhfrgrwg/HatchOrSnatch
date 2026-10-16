"""Hatch or Snatch: egg evolution, egg-award policies, currencies and incubation (HOS-ECON-001).

Rarity index: 0 Common, 1 Rare, 2 Epic, 3 Legendary. -1 = no egg.
"""
from __future__ import annotations

import numpy as np

RARITIES = ["Common", "Rare", "Epic", "Legendary"]

# ---------------------------------------------------------------- evolution systems
# Each system maps crossing -> {from_rarity: [(to_rarity, prob), ...]}; missing = stays.
EVOLUTION = {
    # The brief's illustrative numbers: after crossing 2 (entering the final crossing) R48/E45/L7.
    # The brief gives no final-crossing table; this one is our assumption.
    "brief": {
        1: {0: [(1, 1.0)]},
        2: {1: [(1, .48), (2, .45), (3, .07)]},
        3: {1: [(1, .40), (2, .50), (3, .10)], 2: [(2, .80), (3, .20)]},
    },
    # "More Epic" alternative from the brief (exact numbers ours).
    "epic_heavy": {
        1: {0: [(1, 1.0)]},
        2: {1: [(1, .30), (2, .62), (3, .08)]},
        3: {1: [(1, .40), (2, .50), (3, .10)], 2: [(2, .80), (3, .20)]},
    },
    # What the place does today (EconomyConfig.MATERIAL_FOR_TIER): Level 2 Rare, 3 Epic, 4 Epic.
    "code_levels": {
        1: {0: [(1, 1.0)]},
        2: {1: [(2, 1.0)]},
        3: {},
    },
    # Guaranteed +1 rarity per crossing (the brief rejects this: Legendary for every survivor).
    "deterministic": {
        1: {0: [(1, 1.0)]},
        2: {1: [(2, 1.0)]},
        3: {2: [(3, 1.0)]},
    },
    # FINAL recommendation (picked by tune.py against pacing targets; see results/recommended_economy.json):
    # crossing 1 always turns the egg Rare; crossing 2 is the first chance of Epic and the ONLY chance of
    # Legendary (so a Legendary is always visible during the final crossing); the final crossing can
    # lift Rare to Epic, and Epic to Legendary rarely.
    "tuned": {
        1: {0: [(1, 1.0)]},
        2: {1: [(1, .88), (2, .10), (3, .02)]},
        3: {1: [(1, .90), (2, .10)], 2: [(2, .99), (3, .01)]},
    },
    # Early draft from this audit (used in population.json / strategy.json before tuning; superseded
    # by "tuned"): crossing 1 always shows Rare; crossing 2 is where Legendary first
    # becomes visible (so Catchers can hunt it); the final crossing mostly lifts Rare to Epic and has
    # a small Legendary chance. Tuned so a typical player's first Legendary pet lands at ~15-30 h.
    "recommended": {
        1: {0: [(1, 1.0)]},
        2: {1: [(1, .62), (2, .35), (3, .03)]},
        3: {1: [(1, .45), (2, .52), (3, .03)], 2: [(2, .90), (3, .10)]},
    },
}


def make_evolution(name):
    table = EVOLUTION[name]

    def evolve(rarity, crossing, rng):
        out = rarity.copy()
        rules = table.get(crossing, {})
        u = rng.random(rarity.shape)
        for frm, outs in rules.items():
            sel = rarity == frm
            acc = 0.0
            res = np.full(rarity.shape, frm)
            for to, p in outs:
                res = np.where((u >= acc) & (u < acc + p), to, res)
                acc += p
            out = np.where(sel, res, out)
        return out

    return evolve


def survivor_distribution(name):
    """Exact rarity distribution of an egg that survives all three crossings."""
    d = np.zeros(4)
    d[0] = 1
    for c in (1, 2, 3):
        nd = np.zeros(4)
        for frm in range(4):
            outs = EVOLUTION[name].get(c, {}).get(frm)
            if not outs:
                nd[frm] += d[frm]
            else:
                for to, p in outs:
                    nd[to] += d[frm] * p
                nd[frm] += d[frm] * (1 - sum(p for _, p in outs))
        d = nd
    return d


# ---------------------------------------------------------------- per-player facts from a match
def player_facts(r):
    """Per-player steal lists etc. from run_matches output."""
    M, P = r["M"], r["P"]
    caps = r["captures"]
    n_steals = np.zeros((M, P), int)
    best_stolen = np.full((M, P), -1)
    first_stolen = np.full((M, P), -1)
    best_stolen_redeem = np.full((M, P), -1)
    best_level_stolen = np.zeros((M, P), int)
    steals = [[[] for _ in range(P)] for _ in range(M)]
    for m, c, i, j, t in caps:
        m, c, i, j = int(m), int(c), int(i), int(j)
        rar = int(r["rarity_at"][c - 1][m, j])
        steals[m][i].append((c, rar, j))
        n_steals[m, i] += 1
        best_stolen[m, i] = max(best_stolen[m, i], rar)
        if first_stolen[m, i] < 0:
            first_stolen[m, i] = rar
        best_level_stolen[m, i] = max(best_level_stolen[m, i], c)  # victim's level when caught = c
    banked_best = np.full((M, P), -1)
    for m, c, i, j in r["banked"]:
        m, c, i, j = int(m), int(c), int(i), int(j)
        banked_best[m, i] = max(banked_best[m, i], int(r["rarity_at"][c - 1][m, j]))
    return dict(n_steals=n_steals, best_stolen=best_stolen, first_stolen=first_stolen, steals=steals,
                best_level_stolen=best_level_stolen, banked_best=banked_best)


def awards(r, f, policy, initial_cap=1):
    """Egg rarity each player keeps from this match under `policy` (-1 = no egg)."""
    runner = np.where(r["survived"], r["rarity"], -1)
    M, P = r["M"], r["P"]
    if policy == "runner_only":
        return runner
    if policy == "theft1":
        return np.maximum(runner, f["best_stolen"])
    if policy == "theft1_first":  # keep the FIRST stolen egg, not the best
        return np.maximum(runner, f["first_stolen"])
    if policy == "theft2":
        return np.maximum(runner, np.where(f["n_steals"] >= 2, f["best_stolen"], -1))
    if policy == "banked":
        return np.maximum(runner, f["banked_best"])
    if policy == "stolen_down":  # a stolen egg counts one rarity lower; a stolen Common gives nothing
        return np.maximum(runner, np.where(f["best_stolen"] >= 1, f["best_stolen"] - 1, -1))
    if policy in ("redeem", "redeem_ic0", "redeem_plus1"):
        # a converted Catcher's steal is capped at the rarity of the egg THEY lost ("redeem_plus1":
        # one rarity above it); the starting Catcher (no egg to lose) is capped at `initial_cap`
        lost = r["lost_rarity"] + (1 if policy == "redeem_plus1" else 0)
        ic = 0 if policy == "redeem_ic0" else (2 if policy == "redeem_plus1" else initial_cap)
        cap = np.where(r["initial"], ic, lost)
        out = np.full((M, P), -1)
        for m in range(M):
            for i in range(P):
                for c, rar, j in f["steals"][m][i]:
                    out[m, i] = max(out[m, i], min(rar, cap[m, i]))
        return np.maximum(runner, out)
    if policy == "code_v04":
        # what the place does today: every active player gets one piece; Runner banks the level they
        # carried, a steal credits min(victim level, 3); Level 1 Common, 2 Rare, 3-4 Epic
        lvl_runner = r["level"]  # 1 + crossings completed (banked when caught)
        stolen_lvl = np.minimum(f["best_level_stolen"], 3)
        lvl = np.maximum(lvl_runner, stolen_lvl)
        return np.array([-1, 0, 1, 2, 2])[np.clip(lvl, 1, 4)]
    raise ValueError(policy)


POLICIES = ["runner_only", "theft1", "theft1_first", "theft2", "stolen_down", "redeem", "redeem_ic0", "redeem_plus1", "code_v04"]


# ---------------------------------------------------------------- currencies (EconomyConfig today)
def currencies(r, f):
    cr = r["crossings"]
    caps = f["n_steals"]
    anysurv = r["survived"].any(1, keepdims=True)
    win = np.where(anysurv, r["survived"], r["initial"])
    gold = np.minimum(90, 25 + 12 * cr + 10 * (caps > 0) + 15 * win)
    gems = np.minimum(5, 1 + (cr >= 1) + (cr >= 2) + win + (caps > 0))
    xp = 40 + 20 * cr + np.where(caps > 0, 25 + 10 * np.minimum(3, caps - 1), 0) + 40 * win
    return gold, gems, xp, win


def level_for(xp):
    level, rest = 1, xp
    while rest >= 100 + 25 * (level - 1):
        rest -= 100 + 25 * (level - 1)
        level += 1
    return level


# ---------------------------------------------------------------- incubation
RECIPES_BRIEF = {1: (3, 4), 2: (4, 5), 3: (3, 4)}  # rarity -> (random, focused)
RECIPES_REC = {1: (3, 4), 2: (4, 5), 3: (5, 6)}


def incubate(egg_stream, *, families=3, recipes=RECIPES_BRIEF, first_pet="consume_first",
             focus=True, target_family=0, common_fuse=None, rng=None):
    """Play one player's egg stream (list of rarity per match, -1 = none) through the incubator.

    Hatch rule: whenever a recipe is affordable, hatch the HIGHEST rarity available; focus on the
    target family while it's missing at that rarity, otherwise hatch random (cheaper).
    first_pet: 'free_on_first' (pet on first egg, egg kept), 'consume_first' (first egg becomes the
    Common pet), 'two_eggs' (first two eggs), 'none_special' (Common pet needs 3 Common eggs).
    common_fuse: k -> k Common eggs fuse into 1 Rare egg (None = Common eggs only feed the first pet).
    Returns dict of match index milestones and inventory.
    """
    rng = rng or np.random.default_rng()
    inv = np.zeros(4, int)
    owned = set()  # (family, rarity)
    first_pet_at = None
    pets_at = {1: None, 2: None, 3: None}
    target_at = {1: None, 2: None, 3: None}
    eggs_seen = 0
    dupes = 0
    hatches = 0
    for k, e in enumerate(egg_stream):
        if e < 0:
            continue
        eggs_seen += 1
        inv[e] += 1
        if first_pet_at is None:
            if first_pet == "free_on_first":
                first_pet_at = k
                owned.add((target_family, 0))
            elif first_pet == "consume_first":
                first_pet_at = k
                inv[e] -= 1
                owned.add((target_family, 0))
            elif first_pet == "two_eggs":
                if eggs_seen >= 2:
                    first_pet_at = k
                    # use the two lowest eggs
                    for _ in range(2):
                        lo = np.nonzero(inv)[0][0]
                        inv[lo] -= 1
                    owned.add((target_family, 0))
            elif first_pet == "none_special":
                if inv[0] >= 3:
                    first_pet_at = k
                    inv[0] -= 3
                    owned.add((target_family, 0))
        if common_fuse and inv[0] >= common_fuse:
            n = inv[0] // common_fuse
            inv[0] -= n * common_fuse
            inv[1] += n
        for rar in (3, 2, 1):
            rnd, foc = recipes[rar]
            while True:
                want_focus = focus and (target_family, rar) not in owned
                cost = foc if want_focus else rnd
                if inv[rar] < cost:
                    break
                inv[rar] -= cost
                fam = target_family if want_focus else int(rng.integers(families))
                if (fam, rar) in owned:
                    dupes += 1
                owned.add((fam, rar))
                hatches += 1
                if pets_at[rar] is None:
                    pets_at[rar] = k
                if fam == target_family and target_at[rar] is None:
                    target_at[rar] = k
    return dict(first_pet_at=first_pet_at, pets_at=pets_at, target_at=target_at, inv=inv,
                dupes=dupes, hatches=hatches, owned=len(owned))


def reroll(r, evo_name, rng):
    """Re-roll egg rarities of a finished match batch under another evolution system.

    Valid when Catchers ignore egg rarity (rarity_bias = 0), because then rarity never changed the
    chase: a Runner who finished k crossings finished crossings 1..k.
    """
    evolve = make_evolution(evo_name)
    M, P = r["M"], r["P"]
    rar = np.zeros((M, P), int)
    rarity_at = []
    n = len(r["rarity_at"])
    for c in range(1, n + 1):
        rarity_at.append(rar.copy())
        fin = r["crossings"] >= c
        rar = np.where(fin, evolve(rar, c, rng), rar)
    out = dict(r)
    out["rarity_at"] = rarity_at
    out["rarity"] = rar
    lost = np.full((M, P), -1)
    cc = np.maximum(r["caught_cross"], r["timeout_cross"])
    for c in range(1, n + 1):
        lost = np.where(cc == c, rarity_at[c - 1], lost)
    out["lost_rarity"] = lost
    return out
