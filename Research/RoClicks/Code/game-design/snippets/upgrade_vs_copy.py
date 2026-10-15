#!/usr/bin/env python3
"""Compare the cost of output from upgrading one building vs buying another copy.

Edit the four curve functions to match your game's config, then run:
    python3 upgrade_vs_copy.py

If "cost per +1 base output" from upgrading is much worse than from a new copy,
players will sprawl copies instead of upgrading (more clutter, fewer decisions).
"""

BASE_COST = 100.0
MAX_LEVEL = 10


def upgrade_cost(level):
    """Cost to go from `level` to `level + 1`, as a multiple of BASE_COST."""
    return 2.2 * level ** 1.45          # example curve that went wrong


def output(level):
    """Output at `level`, as a multiple of a level-1 building."""
    return 1 + 0.5 * (level - 1)        # linear +0.5 per level


def copy_cost(n_owned):
    """Cost of the next copy when you already own `n_owned`."""
    return 1.0 * 1.15 ** n_owned        # example copy curve


def main():
    total = 0.0
    print(f"{'step':>7} {'cost x base':>12} {'+output':>8} {'cost per +1':>12}")
    for lv in range(1, MAX_LEVEL):
        c = upgrade_cost(lv)
        gain = output(lv + 1) - output(lv)
        total += c
        print(f"{lv:>3}->{lv + 1:<3} {c:>12.1f} {gain:>8.2f} {c / gain:>12.1f}")
    print(f"\nTotal to L{MAX_LEVEL}: {total:.0f}x base for {output(MAX_LEVEL):.1f}x output")
    print(f"Upgrading: {total / (output(MAX_LEVEL) - 1):.1f}x base per +1 output (average)")
    for owned in (1, 5, 10, 15):
        print(f"New copy with {owned:>2} owned: {copy_cost(owned):.1f}x base per +1 output")
    worst = upgrade_cost(MAX_LEVEL - 1) / (output(MAX_LEVEL) - output(MAX_LEVEL - 1))
    if worst > copy_cost(10) * 2:
        print("\nWARNING: late upgrades cost far more per output than copies. "
              "Lower the cost exponent or raise the output step.")


if __name__ == "__main__":
    main()
