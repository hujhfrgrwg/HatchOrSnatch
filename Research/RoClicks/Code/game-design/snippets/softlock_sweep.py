#!/usr/bin/env python3
"""Soft-lock sweep: generate many worlds, play them with a cheapest-legal-move
bot, and report every seed where the next required target is unreachable.

The world and rules below are a toy ring map, written to reproduce a real bug:
`can_attack` used `ring == current_ring`, so leftovers from older rings became
unattackable and could wall off the next ring's capital. Swap in your own
generator and your game's real rule functions (port them, or call your Luau
through a shim), keep the sweep loop.

    python3 softlock_sweep.py            # buggy rule
    python3 softlock_sweep.py --fixed    # ring <= current_ring
"""
import random
import sys
from collections import deque

SEEDS = 300
RINGS = 5
FIXED = "--fixed" in sys.argv


def gen_world(seed):
    """Rings of countries around a home node. Each ring has one capital.
    Edges link neighbours in a ring and some pairs across adjacent rings."""
    rng = random.Random(seed)
    nodes = {"home": {"ring": 0, "capital": False}}
    edges = {"home": set()}
    prev = ["home"]
    for r in range(1, RINGS + 1):
        n = 6 + 2 * r
        ring = [f"r{r}_{i}" for i in range(n)]
        cap = rng.choice(ring)
        for c in ring:
            nodes[c] = {"ring": r, "capital": c == cap}
            edges[c] = set()
        for i, c in enumerate(ring):  # ring neighbours
            d = ring[(i + 1) % n]
            edges[c].add(d)
            edges[d].add(c)
        for c in ring:                # 1-2 links inward
            for p in rng.sample(prev, k=min(len(prev), rng.choice((1, 2)))):
                edges[c].add(p)
                edges[p].add(c)
        prev = ring
    return nodes, edges


def can_attack(nodes, owned, current_ring, c):
    ring = nodes[c]["ring"]
    if FIXED:
        return ring <= current_ring and c not in owned
    return ring == current_ring and c not in owned   # the bug


def frontier(nodes, edges, owned, current_ring):
    out = set()
    for o in owned:
        for c in edges[o]:
            if can_attack(nodes, owned, current_ring, c):
                out.add(c)
    return out


def capital_reachable(nodes, edges, owned, current_ring):
    """BFS over legal attacks only: can the current ring's capital be reached?"""
    seen, q = set(owned), deque(owned)
    while q:
        o = q.popleft()
        for c in edges[o]:
            if c in seen or not can_attack(nodes, seen, current_ring, c):
                continue
            if nodes[c]["capital"] and nodes[c]["ring"] == current_ring:
                return True
            seen.add(c)
            q.append(c)
    return False


def play(seed):
    """Returns None if the bot finished, else the ring it got stuck on."""
    rng = random.Random(seed * 7919)
    nodes, edges = gen_world(seed)
    owned, current_ring = {"home"}, 1
    while current_ring <= RINGS:
        if not capital_reachable(nodes, edges, owned, current_ring):
            return current_ring
        # take a few ordinary countries, then the capital when it borders us
        f = frontier(nodes, edges, owned, current_ring)
        caps = [c for c in f if nodes[c]["capital"] and nodes[c]["ring"] == current_ring]
        normal = [c for c in f if not nodes[c]["capital"]]
        if caps and (not normal or rng.random() < 0.5):
            owned.add(caps[0])
            current_ring += 1         # leftovers of the old ring stay unowned
        elif normal:
            owned.add(rng.choice(normal))
        else:
            return current_ring
    return None


def main():
    stuck = {}
    for seed in range(1, SEEDS + 1):
        r = play(seed)
        if r is not None:
            stuck.setdefault(r, []).append(seed)
    print(f"{'fixed' if FIXED else 'buggy'} rule, {SEEDS} seeds")
    if not stuck:
        print("no soft-locks")
    for r in sorted(stuck):
        print(f"ring {r}: {len(stuck[r])} seeds stuck, e.g. {stuck[r][:5]}")


if __name__ == "__main__":
    main()
