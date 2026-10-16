"""Hatch or Snatch: 2D multiplayer chase simulation (HOS-ECON-001).

Every match in a batch runs at once (numpy arrays shaped [matches, players]). Players share one
arena, Catchers pick and chase Runners, captures convert Runners into Catchers, and the next
crossing starts with the bigger Catcher team. Movement numbers come from the place's GameConfig
(snapshot in ScriptHistory, 16 Oct 2026): run 31 studs/s for both roles, Runner side-dash 58 studs/s
for 0.16 s with a 2 s cooldown, stab reach 6.5 studs with a 1 s cooldown, Catcher lunge 46 studs/s
for 0.2 s (2.5 s cooldown, then 50% speed for 0.7 s), Catchers can't dash, 0.75 s release delay and
wave-start protection, field 176 x 140 studs, 30 s per crossing.

What is NOT real: the brains. Runners and Catchers follow simple steering rules with a skill-scaled
reaction delay, dash timing error and stab success. Skill is a made-up scale (-1 beginner, 0
typical, +1 skilled). The model shows how the RULES interact; it does not predict real players.
"""
from __future__ import annotations

import numpy as np

# ---- arena and movement (GameConfig / Layout) ----
FIELD_X = 176.0  # Layout.Arena.FIELD_HALF_X * 2
HALF_Z = 70.0
RUN = 31.0
DASH_SPEED = 58.0
DASH_TIME = 0.16
DASH_CD = 2.0
ACCEL = 160.0
TAG_REACH = 6.5
TAG_CD = 1.0
LUNGE_SPEED = 46.0
LUNGE_TIME = 0.2
LUNGE_CD = 2.5
LUNGE_SLOW = 0.5
LUNGE_SLOW_TIME = 0.7
LUNGE_MIN, LUNGE_MAX = 6.0, 10.0
RELEASE = 0.75
CROSS_TIME = 30.0
CONVERSION_GRACE = 1.5
EVADE_R = 30.0
CLAIM_PENALTY = 30.0
DT = 0.05
HIST = 16  # ticks of position history (0.8 s) for reaction delays

RUNNER, CATCHER, DOWN, SAFE, GONE = 0, 1, 2, 3, 4

# strategies
HONEST, SURRENDER = 0, 1


def skill_params(s, pressure=1.0):
    """Map skill (-1..+1, any real) to behaviour.

    `pressure` is the main sensitivity knob for how good chasing is relative to escaping, since the
    real number is unknown until playtests. Above 1 it lowers everyone's skill when they run and
    raises it when they catch (1 = the base brains).
    """
    s = np.asarray(s, float)
    sr = s - 0.8 * (pressure - 1.0)  # skill as a Runner
    sc = s + 0.8 * (pressure - 1.0)  # skill as a Catcher
    return dict(
        delay=np.clip(0.30 - 0.08 * sr, 0.12, 0.6),  # Runner reaction delay, s
        cdelay=np.clip(0.30 - 0.08 * sc, 0.08, 0.6),  # Catcher reaction delay, s
        juke_mu=np.full_like(s, 9.0),  # distance at which a Runner side-dashes
        juke_sd=np.clip(2.5 - 0.8 * sr, 0.6, 5.0),
        wrong_side=np.clip(0.30 - 0.12 * sr, 0.05, 0.6),
        dodge=np.clip(0.50 + 0.20 * sr, 0.05, 0.9),  # side-slides out of a lunge (dash ready)
        hit=np.clip(0.70 + 0.12 * sc, 0.2, 0.98),  # stab success when in reach
        lead=np.clip(0.25 * (1 + 0.3 * sc), 0.05, 0.6),  # Catcher prediction lead, s
        # good Runners read the field early and slide into gaps; beginners only react up close
        evade=np.clip(3.2 * (1 + 0.5 * sr), 0.5, 6.0),
        aware=np.clip(30.0 + 14.0 * sr, 10.0, 55.0),  # studs: how far ahead a Runner reads Catchers
        reach=np.full_like(s, TAG_REACH * (1 + 0.6 * (pressure - 1.0))),  # stab reach, studs
    )


class Batch:
    def __init__(self, M, P, rng, skills, strategies, initial_catchers, *, pressure=1.0,
                 dash_mult=None, immediate_conversion=False, bank_mode=False, rarity_bias=0.0,
                 surrender_crossing=None):
        self.M, self.P, self.rng = M, P, rng
        self.skill = skills  # [M,P]
        self.strat = strategies  # [M,P]
        self.sp = skill_params(skills, pressure)
        self.dash_mult = np.ones((M, P)) if dash_mult is None else dash_mult
        self.immediate = immediate_conversion
        self.bank_mode = bank_mode
        self.rarity_bias = rarity_bias
        self.surrender_crossing = surrender_crossing if surrender_crossing is not None else np.ones((M, P), int)
        self.role = np.where(initial_catchers, CATCHER, RUNNER)
        self.initial = initial_catchers.copy()
        self.pos = np.zeros((M, P, 2))
        self.vel = np.zeros((M, P, 2))
        # catchers start mid-field
        self.pos[..., 0] = np.where(initial_catchers, FIELD_X / 2, 0)
        self.pos[..., 1] = np.where(initial_catchers, rng.uniform(-20, 20, (M, P)), 0)
        self.rarity_vis = np.zeros((M, P))  # visible egg rarity index (for target bias)
        self.captures = []  # (m, crossing, captor, victim, t)
        self.banked = []  # (m, crossing, captor, victim) when bank_mode and the carrier reached the bank
        self.carrying = np.full((M, P), -1)  # bank mode: victim id of the egg being carried

    # ------------------------------------------------------------------
    def run_crossing(self, c):
        """Run crossing c (1-based). Returns per-player result arrays."""
        M, P, rng = self.M, self.P, self.rng
        sp = self.sp
        runner0 = self.role == RUNNER
        # Runners line up at x = 0 across the width; Catchers keep (mirrored) positions
        lanes = rng.uniform(-HALF_Z + 6, HALF_Z - 6, (M, P))
        self.pos[..., 0] = np.where(runner0, 0.0, FIELD_X - self.pos[..., 0])
        self.pos[..., 1] = np.where(runner0, lanes, self.pos[..., 1])
        self.pos[..., 0] = np.clip(self.pos[..., 0], 10, FIELD_X - 10) * (~runner0) + self.pos[..., 0] * runner0
        self.vel[:] = 0
        lane = lanes
        hist = np.repeat(self.pos[None], HIST, axis=0)
        histv = np.zeros_like(hist)
        dash_until = np.zeros((M, P))
        dash_ready = np.zeros((M, P))
        dash_dir = np.zeros((M, P, 2))
        juke_at = rng.normal(sp["juke_mu"], sp["juke_sd"])
        tag_ready = np.zeros((M, P))
        lunge_ready = np.zeros((M, P))
        lunge_until = np.full((M, P), -1.0)
        lunge_dir = np.zeros((M, P, 2))
        slow_until = np.zeros((M, P))
        grace = np.zeros((M, P))
        dodge_at = np.full((M, P), np.inf)
        dodge_dir = np.zeros((M, P, 2))
        finished = np.zeros((M, P), bool)
        caught_now = np.zeros((M, P), bool)
        rdelay = np.maximum(1, np.round(sp["delay"] / DT).astype(int))
        cdelay = np.maximum(1, np.round(sp["cdelay"] / DT).astype(int))
        mi = np.arange(M)[:, None]
        surrendering = (self.strat == SURRENDER) & (self.surrender_crossing == c) & runner0
        t = 0.0
        tick = 0
        active = np.ones(M, bool)
        while t < CROSS_TIME and active.any():
            # ---- observations (delayed per observer) ----
            idx = (tick - np.where(self.role == RUNNER, rdelay, cdelay)) % HIST  # [M,P]
            obs = hist[idx[:, :, None], mi[:, :, None], np.arange(P)[None, None, :]]  # [M,obs,tgt,2]
            obsv = histv[idx[:, :, None], mi[:, :, None], np.arange(P)[None, None, :]]
            is_r = self.role == RUNNER
            is_c = (self.role == CATCHER) & (t >= RELEASE) & (t >= grace)
            carrying = self.carrying >= 0
            # ---- Runner steering ----
            diff = self.pos[:, :, None, :] - obs  # runner - catcher(obs)
            dist = np.linalg.norm(diff, axis=-1) + 1e-6
            ahead = obs[..., 0] > self.pos[:, :, None, 0] - 3  # catcher not yet passed
            aware = sp["aware"][:, :, None]
            threat = is_c[:, None, :] & ahead & (dist < aware) & ~carrying[:, None, :]
            w = np.where(threat, (aware - dist) / aware, 0.0)
            rep = (diff / dist[..., None] * w[..., None]).sum(2) * sp["evade"][..., None]
            rep[..., 0] = np.maximum(rep[..., 0], -0.5)  # side-step, don't turn back
            goal = np.zeros((M, P, 2))
            goal[..., 0] = 1.0
            goal[..., 1] = np.clip((lane - self.pos[..., 1]) / 40, -0.3, 0.3)
            want = goal + rep
            # surrender: walk to the nearest Catcher and stand there
            dsel = np.where(is_c[:, None, :], dist, np.inf)
            near = dsel.argmin(2)
            near_d = np.take_along_axis(dsel, near[..., None], 2)[..., 0]
            near_pos = np.take_along_axis(obs, near[..., None, None].repeat(2, -1), 2)[:, :, 0]
            to_c = near_pos - self.pos
            want = np.where(surrendering[..., None] & np.isfinite(near_d)[..., None], to_c, want)
            # ---- Runner jukes (side-dash) ----
            near_ahead_d = np.where(threat | (is_c[:, None, :] & ahead & (dist < 15)), dist, np.inf).min(2)
            can_dash = is_r & (t >= dash_ready) & ~surrendering
            do_dash = can_dash & (near_ahead_d < juke_at)
            if do_dash.any():
                cpos = near_pos
                away = self.pos - cpos
                perp = np.stack([-away[..., 1], away[..., 0]], -1)
                perp /= np.linalg.norm(perp, axis=-1, keepdims=True) + 1e-6
                # the right side is the one away from the Catcher's sideways motion
                cv = np.take_along_axis(obsv, near[..., None, None].repeat(2, -1), 2)[:, :, 0]
                side = np.sign((perp * -cv).sum(-1) + 1e-3)
                wrong = rng.random((M, P)) < sp["wrong_side"]
                side = np.where(wrong, -side, side)
                d = perp * side[..., None]
                d[..., 0] = np.maximum(d[..., 0], 0.25)  # no backwards dive
                d /= np.linalg.norm(d, axis=-1, keepdims=True)
                dash_dir = np.where(do_dash[..., None], d, dash_dir)
                dash_until = np.where(do_dash, t + DASH_TIME, dash_until)
                dash_ready = np.where(do_dash, t + DASH_CD, dash_ready)
                juke_at = np.where(do_dash, rng.normal(sp["juke_mu"], sp["juke_sd"]), juke_at)
            # lunge dodges
            dodge_now = is_r & (t >= dodge_at) & (t >= dash_ready)
            if dodge_now.any():
                dash_dir = np.where(dodge_now[..., None], dodge_dir, dash_dir)
                dash_until = np.where(dodge_now, t + DASH_TIME, dash_until)
                dash_ready = np.where(dodge_now, t + DASH_CD, dash_ready)
            dodge_at = np.where(dodge_now | ~is_r, np.inf, dodge_at)
            # ---- Catcher targeting (sequential claims, vectorised over matches) ----
            tgt = np.full((M, P), -1)
            claims = np.zeros((M, P))
            rpos_obs = obs  # catcher i sees runner j at obs[m,i,j]
            cd = np.linalg.norm(rpos_obs - self.pos[:, :, None, :], axis=-1)
            past = rpos_obs[..., 0] > self.pos[:, :, None, 0] + 3
            base_score = cd + np.where(past, 60.0, 0.0) - self.rarity_bias * 10 * self.rarity_vis[:, None, :]
            valid_r = is_r & ~finished
            for i in range(P):
                ci = is_c[:, i] & ~carrying[:, i]
                if not ci.any():
                    continue
                sc = np.where(valid_r, base_score[:, i, :] + CLAIM_PENALTY * claims, np.inf)
                j = sc.argmin(1)
                ok = ci & np.isfinite(sc[np.arange(M), j])
                tgt[:, i] = np.where(ok, j, -1)
                claims[np.arange(M), j] += ok
            has_t = tgt >= 0
            tj = np.maximum(tgt, 0)
            tpos = np.take_along_axis(rpos_obs, tj[..., None, None].repeat(2, -1), 2)[:, :, 0]
            tvel = np.take_along_axis(obsv, tj[..., None, None].repeat(2, -1), 2)[:, :, 0]
            pred = tpos + tvel * sp["lead"][..., None]
            dtt = np.linalg.norm(tpos - self.pos, axis=-1)
            guard = np.clip(dtt * 0.3, 0, 10)
            aim = pred + np.stack([guard * (dtt > 9), np.zeros_like(guard)], -1)
            cwant = aim - self.pos
            # bank carriers run back to x <= 0
            bank_dir = np.zeros((M, P, 2))
            bank_dir[..., 0] = -1
            cwant = np.where(carrying[..., None], bank_dir, cwant)
            cwant = np.where(has_t[..., None] | carrying[..., None], cwant, 0.0)
            # ---- desired velocities ----
            desired = np.where(is_r[..., None], want, np.where(is_c[..., None] | carrying[..., None], cwant, 0.0))
            n = np.linalg.norm(desired, axis=-1, keepdims=True)
            speed = np.where(t < slow_until, RUN * LUNGE_SLOW, RUN)
            dv = np.where(n > 1e-6, desired / np.maximum(n, 1e-6), 0.0) * speed[..., None]
            stand = surrendering & (near_d < 3)
            dv = np.where(stand[..., None], 0.0, dv)
            # acceleration limit
            delta = dv - self.vel
            dn = np.linalg.norm(delta, axis=-1, keepdims=True)
            lim = ACCEL * DT
            self.vel = self.vel + np.where(dn > lim, delta / np.maximum(dn, 1e-9) * lim, delta)
            # dash / lunge overrides
            dashing = t < dash_until
            self.vel = np.where(dashing[..., None], dash_dir * (DASH_SPEED * self.dash_mult)[..., None], self.vel)
            lunging = (t < lunge_until) & (lunge_until > 0)
            self.vel = np.where(lunging[..., None], lunge_dir * LUNGE_SPEED, self.vel)
            frozen = (self.role == DOWN) | (self.role == SAFE) | ((self.role == CATCHER) & (t < RELEASE)) | (self.role == GONE)
            self.vel = np.where(frozen[..., None], 0.0, self.vel)
            self.pos = self.pos + self.vel * DT
            self.pos[..., 1] = np.clip(self.pos[..., 1], -HALF_Z, HALF_Z)
            self.pos[..., 0] = np.clip(self.pos[..., 0], -24, FIELD_X + 24)
            t += DT
            tick += 1
            hist[tick % HIST] = self.pos
            histv[tick % HIST] = self.vel
            # ---- finish ----
            fin = (self.role == RUNNER) & (self.pos[..., 0] >= FIELD_X)
            if fin.any():
                finished |= fin
                self.role = np.where(fin, SAFE, self.role)
            # ---- bank ----
            if self.bank_mode:
                banked = carrying & (self.pos[..., 0] <= 0)
                for m, i in zip(*np.nonzero(banked)):
                    self.banked.append((m, c, i, self.carrying[m, i]))
                self.carrying = np.where(banked, -1, self.carrying)
            # ---- Catcher attacks ----
            is_c = (self.role == CATCHER) & (t >= RELEASE) & (t >= grace) & (self.carrying < 0)
            rr = (self.role == RUNNER)
            if t >= RELEASE and rr.any() and is_c.any():
                d_all = np.linalg.norm(self.pos[:, None, :, :] - self.pos[:, :, None, :], axis=-1)  # [M,c,r]
                d_r = np.where(rr[:, None, :], d_all, np.inf)
                jn = d_r.argmin(2)
                dn_ = np.take_along_axis(d_r, jn[..., None], 2)[..., 0]
                # lunge strike resolves
                strike = (lunge_until > 0) & (np.abs(t - lunge_until) < DT / 2 + 1e-9)
                # stab
                stab = is_c & (dn_ <= sp["reach"]) & (t >= tag_ready) & ~lunging
                attempt = stab | (strike & (dn_ <= sp["reach"]))
                slow_until = np.where(strike, t + LUNGE_SLOW_TIME, slow_until)
                lunge_until = np.where(strike, -1.0, lunge_until)
                hit = attempt & (rng.random((M, P)) < sp["hit"])
                tag_ready = np.where(stab, t + TAG_CD, tag_ready)
                # start lunges
                tdist = np.take_along_axis(d_all, tj[..., None], 2)[..., 0]
                start_l = is_c & has_t & (t >= lunge_ready) & (tdist >= LUNGE_MIN) & (tdist <= LUNGE_MAX) & ~lunging & ~stab
                if start_l.any():
                    ld = tpos - self.pos
                    ld /= np.linalg.norm(ld, axis=-1, keepdims=True) + 1e-6
                    lunge_dir = np.where(start_l[..., None], ld, lunge_dir)
                    lunge_until = np.where(start_l, t + LUNGE_TIME, lunge_until)
                    lunge_ready = np.where(start_l, t + LUNGE_CD, lunge_ready)
                    # the targeted Runner may side-slide out of it after their reaction delay
                    for m, i in zip(*np.nonzero(start_l)):
                        j = tgt[m, i]
                        if rng.random() < sp["dodge"][m, j]:
                            dodge_at[m, j] = min(dodge_at[m, j], t + sp["delay"][m, j])
                            perp = np.array([-ld[m, i, 1], ld[m, i, 0]])
                            if rng.random() < 0.5:
                                perp = -perp
                            perp[0] = max(perp[0], 0.25)
                            dodge_dir[m, j] = perp / np.linalg.norm(perp)
                # resolve hits: each victim once (lowest catcher index wins ties)
                for m, i in zip(*np.nonzero(hit)):
                    j = jn[m, i]
                    if self.role[m, j] != RUNNER:
                        continue
                    if t < RELEASE:  # wave-start protection
                        continue
                    self.role[m, j] = DOWN
                    caught_now[m, j] = True
                    self.captures.append((m, c, i, j, t))
                    if self.bank_mode:
                        self.carrying[m, i] = j
                    if self.immediate:
                        grace[m, j] = t + CONVERSION_GRACE
            if self.immediate:
                conv = (self.role == DOWN) & (t >= grace)
                self.role = np.where(conv, CATCHER, self.role)
            # matches with no live Runners end the crossing
            live = ((self.role == RUNNER)).any(1)
            if self.bank_mode:
                live |= (self.carrying >= 0).any(1)
            active = live
        # timeout: unfinished Runners convert, no credit
        timed_out = self.role == RUNNER
        if self.bank_mode:
            self.carrying[:] = -1  # an egg not banked by the end of the crossing is lost
        self.role = np.where((self.role == DOWN) | timed_out, CATCHER, self.role)
        self.role = np.where(self.role == SAFE, RUNNER, self.role)
        return dict(finished=finished & runner0, caught=caught_now, timed_out=timed_out & runner0, time=t)


def run_matches(M, P, rng, *, n_crossings=3, skills=None, strategies=None, n_initial=1,
                initial_select="random", evolution=None, clean_streak=None, max_crossings=40,
                surrender_crossing=None, **kw):
    """Run M independent matches of P players. Returns a dict of per-player outcomes.

    evolution: callable(rarity[M,P], crossing, rng) -> new rarity, applied to Runners who finish.
    clean_streak: if set, use the place's current end rule (crossings continue until this many clean
    crossings in a row, the last Runner's solo crossing, or no Runners left) instead of n_crossings.
    """
    if skills is None:
        skills = rng.normal(0, 0.6, (M, P))
    if strategies is None:
        strategies = np.zeros((M, P), int)
    init = np.zeros((M, P), bool)
    if initial_select == "random":
        order = rng.random((M, P)).argsort(1)
    elif initial_select == "highest_skill":
        order = (-skills).argsort(1)
    elif initial_select == "not_focal":  # player 0 never starts as the Catcher
        r = rng.random((M, P))
        r[:, 0] = 2
        order = r.argsort(1)
    elif initial_select == "focal":
        r = rng.random((M, P))
        r[:, 0] = -1
        order = r.argsort(1)
    else:
        raise ValueError(initial_select)
    for k in range(n_initial):
        init[np.arange(M), order[:, k]] = True
    b = Batch(M, P, rng, skills, strategies, init, surrender_crossing=surrender_crossing, **kw)
    rarity = np.zeros((M, P), int)  # egg rarity index carried by each Runner (Common = 0)
    level = np.ones((M, P), int)
    crossings_done = np.zeros((M, P), int)
    caught_cross = np.zeros((M, P), int)  # crossing in which caught (0 = never)
    lost_rarity = np.full((M, P), -1)  # rarity of the egg a player had when caught / timed out
    timeout_cross = np.zeros((M, P), int)
    rarity_at = []  # rarity snapshot per crossing (for steals)
    n_runners = []
    crossing_times = []
    streak = np.zeros(M, int)
    ended = np.zeros(M, bool)
    end_cross = np.zeros(M, int)
    lone = np.full(M, -1)
    total = n_crossings if clean_streak is None else max_crossings
    for c in range(1, total + 1):
        if ended.all():
            break
        # ended matches: freeze by making everybody GONE for this crossing
        saved_roles = b.role.copy()
        b.role = np.where(ended[:, None], GONE, b.role)
        if clean_streak is not None:
            nr = (b.role == RUNNER).sum(1)
            lone = np.where(nr == 1, (b.role == RUNNER).argmax(1), -1)
        b.rarity_vis = np.where(b.role == RUNNER, rarity, 0)
        rarity_at.append(rarity.copy())
        n_runners.append(np.where(ended, -1, (b.role == RUNNER).sum(1)))
        res = b.run_crossing(c)
        b.role = np.where(ended[:, None], saved_roles, b.role)
        crossing_times.append(np.where(ended, np.nan, res["time"]))
        fin = res["finished"] & ~ended[:, None]
        crossings_done += fin
        level += fin
        if evolution is not None:
            new = evolution(rarity, c, rng)
            rarity = np.where(fin, new, rarity)
        lost = (res["caught"] | res["timed_out"]) & ~ended[:, None]
        caught_cross = np.where(res["caught"] & ~ended[:, None], c, caught_cross)
        timeout_cross = np.where(res["timed_out"] & ~ended[:, None], c, timeout_cross)
        lost_rarity = np.where(lost, rarity, lost_rarity)
        if clean_streak is not None:
            clean = (~lost).all(1)
            streak = np.where(clean, streak + 1, 0)
            runners_left = (b.role == RUNNER).sum(1)
            lone_won = (lone >= 0) & fin[np.arange(M), np.maximum(lone, 0)]
            newly = ~ended & ((runners_left == 0) | (streak >= clean_streak) | lone_won)
            end_cross = np.where(newly, c, end_cross)
            ended |= newly
        else:
            runners_left = (b.role == RUNNER).sum(1)
            newly = ~ended & ((runners_left == 0) | (c == n_crossings))
            end_cross = np.where(newly, c, end_cross)
            ended |= newly
    end_cross = np.where(end_cross == 0, total, end_cross)
    survived = (b.role == RUNNER) & ~init
    if clean_streak is not None:
        # last-one-standing: only the lone Runner counts as the winner
        pass
    caps = np.array(b.captures, dtype=float).reshape(-1, 5)
    return dict(
        M=M, P=P, skills=skills, strategies=strategies, initial=init, survived=survived,
        rarity=rarity, level=level, crossings=crossings_done, caught_cross=caught_cross,
        timeout_cross=timeout_cross, lost_rarity=lost_rarity, rarity_at=rarity_at, captures=caps,
        banked=np.array(b.banked, dtype=float).reshape(-1, 4), n_runners=n_runners,
        crossing_times=crossing_times, end_cross=end_cross,
    )
