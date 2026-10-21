# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Property test of the sizing rules, on random symbols and setups (no terminal needed).

    python3 tests/check_sizing.py [cases]       default 200000, fixed seed

For every random case it checks: the money lost at the stop never exceeds the risk asked; it is within one lot step
of it (when a lot can be given); the lot is a whole number of lot steps, never below the minimum and never above the
maximum; a risk too small for the minimum lot gives 0 plus a note instead of a rounded-up lot."""
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from reference import Symbol, size, loss_per_lot, tick_price  # noqa: E402

# (name, tick size, tick value per lot, price level, typical stop in ticks)
KINDS = [("fx5", 0.00001, 1.0, 1.1, 150), ("jpy3", 0.001, 0.65, 150.0, 150), ("gold2", 0.01, 1.0, 3000.0, 800),
         ("index1", 0.1, 0.1, 20000.0, 400), ("crypto2", 0.01, 0.01, 90000.0, 200000), ("fx3", 0.001, 1.0, 1.5, 100)]
STEPS = [(0.01, 0.01), (0.01, 0.1), (0.001, 0.001), (1.0, 1.0), (0.1, 0.1)]   # (vol_step, vol_min)


def main(n):
    rng = random.Random(20261021)
    bad = []
    stats = dict(sized=0, below_min=0, capped=0)
    worst_gap = 0.0
    for i in range(n):
        name, ts, tv, lvl, stop_ticks = rng.choice(KINDS)
        step, vmin = rng.choice(STEPS)
        vmax = rng.choice([50.0, 100.0, 500.0])
        sym = Symbol(ts, tv * rng.uniform(0.5, 1.5), step, vmin, vmax)
        entry = lvl * rng.uniform(0.9, 1.1)
        d = ts * max(2, rng.uniform(0.3, 3.0) * stop_ticks)
        sl = entry - d if rng.random() < 0.5 else entry + d
        risk = rng.choice([10, 25, 50, 100, 250, 1000, 5000]) * rng.uniform(0.2, 2.0)
        lots, real, note = size(sym, entry, sl, risk)
        lpl = loss_per_lot(sym, tick_price(sym, entry), tick_price(sym, sl))
        if lots > 0:
            stats["sized"] += 1
            if lots * lpl > risk * (1 + 1e-9) and lots < vmax:
                bad.append((i, "risk exceeded", name, lots, lots * lpl, risk))
            if lots >= vmax - 1e-9:
                stats["capped"] += 1
            elif risk - lots * lpl >= step * lpl * (1 + 1e-9):
                bad.append((i, "more than one lot step under the risk", name, lots, lots * lpl, risk))
            else:
                worst_gap = max(worst_gap, (risk - lots * lpl) / (step * lpl))
            k = lots / step
            if abs(k - round(k)) > 1e-6:
                bad.append((i, "not a whole number of steps", name, lots, step))
            if lots < vmin - 1e-12 or lots > vmax + 1e-12:
                bad.append((i, "outside min/max", name, lots, vmin, vmax))
        else:
            stats["below_min"] += 1
            if note != "min lot" or risk / lpl >= vmin + 1e-9:
                bad.append((i, "zero lot without a good reason", name, lots, note, risk, lpl))
    print(f"cases: {n}")
    print(f"sized: {stats['sized']}  (capped at the maximum lot: {stats['capped']})")
    print(f"below the minimum lot (answered 0 + note): {stats['below_min']}")
    print(f"largest shortfall under the risk, in lot steps: {worst_gap:.6f} (must stay under 1)")
    print(f"violations: {len(bad)}")
    for b in bad[:10]:
        print("  ", b)
    print("RESULT:", "PASS" if not bad else "FAIL")
    return 0 if not bad else 1


if __name__ == "__main__":
    sys.exit(main(int(sys.argv[1]) if len(sys.argv) > 1 else 200000))
