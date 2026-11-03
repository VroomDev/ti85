"""Autocorrelation and lag-1 Markov checks for c16crunch RNG sequences.

Matches src/level.s / player.s:
  fast_rand: lsr; if C set eor #$FA  (period 255, never 0)
  rand16:    16-bit lsr/ror; if C set eor #$D008

Derived: rand_dir (>>1), make_dirs (>>1 / >>3 / >>5), rand512.

Prints at most 20 lines: one header + one summary row per sequence.

Usage:
  python tools/rng_stats.py
  python tools/rng_stats.py --steps 100000 --lags 32 --seed 0xAC
"""

from __future__ import annotations

import argparse
import math
from collections import Counter
from typing import Sequence


# --- LFSRs (Galois, shift right) ------------------------------------------------

TAP8 = 0xFA
TAP16 = 0xD008
BOOT = 0xAC


def step8(state: int) -> int:
    bit = state & 1
    state >>= 1
    if bit:
        state ^= TAP8
    return state & 0xFF


def step16(state: int) -> int:
    bit = state & 1
    state >>= 1
    if bit:
        state ^= TAP16
    return state & 0xFFFF


def gen8(seed: int, n: int) -> list[int]:
    s = seed & 0xFF
    if s == 0:
        raise ValueError("8-bit seed must be non-zero")
    out: list[int] = []
    for _ in range(n):
        s = step8(s)
        out.append(s)
    return out


def gen16(seed: int, n: int) -> list[int]:
    s = seed & 0xFFFF
    if s == 0:
        raise ValueError("16-bit seed must be non-zero")
    out: list[int] = []
    for _ in range(n):
        s = step16(s)
        out.append(s)
    return out


# --- Derived maps ---------------------------------------------------------------

def map_rand_dir(r: int) -> int:
    """player.s rand_dir: (fast_rand >> 1) & 3 + 1 → 1..4"""
    return ((r >> 1) & 3) + 1


def map_dirs_i3(r: int) -> int:
    """make_dirs first swap index: (rndb >> 1) & 3 → 0..3"""
    return (r >> 1) & 3


def map_dirs_i2(r: int) -> int:
    """make_dirs second index: (rndb >> 3) & 3, 3→2 → 0..2"""
    v = (r >> 3) & 3
    return 2 if v == 3 else v


def map_dirs_i1(r: int) -> int:
    """make_dirs third index: (rndb >> 5) & 1 → 0..1"""
    return (r >> 5) & 1


def map_rand512(r: int) -> int:
    return (r) & 511


# --- Stats ----------------------------------------------------------------------

def mean_var(xs: Sequence[float]) -> tuple[float, float]:
    n = len(xs)
    if n == 0:
        return 0.0, 0.0
    m = sum(xs) / n
    v = sum((x - m) ** 2 for x in xs) / n
    return m, v


def autocorrelation(xs: Sequence[int], max_lag: int) -> list[tuple[int, float]]:
    """Normalized ACF r(k) for k = 1..max_lag (population form)."""
    n = len(xs)
    m, v = mean_var([float(x) for x in xs])
    if v == 0.0:
        return [(k, float("nan")) for k in range(1, max_lag + 1)]
    out: list[tuple[int, float]] = []
    for k in range(1, max_lag + 1):
        if k >= n:
            out.append((k, float("nan")))
            continue
        cov = sum((xs[i] - m) * (xs[i + k] - m) for i in range(n - k)) / (n - k)
        out.append((k, cov / v))
    return out


def chi2_sf(chi2: float, dof: int) -> float:
    """Survival function P(X >= chi2) for chi-square via incomplete gamma (erfc path for dof=1..)."""
    if dof <= 0 or chi2 < 0 or math.isnan(chi2):
        return float("nan")
    # Regularized upper gamma Q(s,x) with s = dof/2, x = chi2/2
    return _gammaincc(dof / 2.0, chi2 / 2.0)


def _gammaincc(a: float, x: float) -> float:
    """Regularized upper incomplete gamma Q(a,x). Series / continued fraction."""
    if x < 0 or a <= 0:
        return float("nan")
    if x == 0:
        return 1.0
    if x < a + 1:
        # Q = 1 - P; P via series
        term = 1.0 / a
        s = term
        for n in range(1, 200):
            term *= x / (a + n)
            s += term
            if abs(term) < abs(s) * 1e-15:
                break
        return 1.0 - s * math.exp(-x + a * math.log(x) - math.lgamma(a))
    # Continued fraction for Q
    b = x + 1.0 - a
    c = 1e30
    d = 1.0 / b
    h = d
    for i in range(1, 200):
        an = -i * (i - a)
        b += 2.0
        d = an * d + b
        if abs(d) < 1e-30:
            d = 1e-30
        c = b + an / c
        if abs(c) < 1e-30:
            c = 1e-30
        d = 1.0 / d
        delta = d * c
        h *= delta
        if abs(delta - 1.0) < 1e-15:
            break
    return math.exp(-x + a * math.log(x) - math.lgamma(a)) * h


def markov_lag1(xs: Sequence[int], dense_limit: int = 64) -> dict:
    """Lag-1 transition counts, independence chi-square, and matrix (if small).

    For alphabets larger than dense_limit, chi² / max-dev use only observed
    (prev,next) cells plus a lumped 'unseen' contribution, so runtime stays
    O(n) instead of O(k²).
    """
    n_pairs = len(xs) - 1
    if n_pairs < 1:
        return {"error": "need at least 2 samples"}

    pairs = Counter((xs[i], xs[i + 1]) for i in range(n_pairs))
    marg_from = Counter(xs[i] for i in range(n_pairs))
    marg_to = Counter(xs[i + 1] for i in range(n_pairs))
    alphabet = sorted(set(xs))
    k = len(alphabet)

    max_dev = 0.0
    worst = None
    out_degrees = Counter()
    for (a, b), obs in pairs.items():
        out_degrees[a] += 1
        row_n = marg_from[a]
        p_ab = obs / row_n
        p_indep = marg_to[b] / n_pairs
        dev = abs(p_ab - p_indep)
        if dev > max_dev:
            max_dev = dev
            worst = (a, b, p_ab, p_indep)

    # Deterministic successor? (raw LFSR: each seen predecessor has one next)
    preds = [a for a in alphabet if marg_from[a]]
    det = bool(preds) and all(out_degrees[a] == 1 for a in preds)

    if k <= dense_limit:
        chi2 = 0.0
        for a in alphabet:
            for b in alphabet:
                exp = marg_from[a] * marg_to[b] / n_pairs
                if exp <= 0:
                    continue
                obs = pairs.get((a, b), 0)
                chi2 += (obs - exp) ** 2 / exp
        dof = (k - 1) * (k - 1)
        chi2_note = "dense"
    else:
        # Sparse: sum over observed cells only, then add one lumped term for
        # all zero cells whose expected mass is the remainder.
        chi2 = 0.0
        exp_obs_mass = 0.0
        for (a, b), obs in pairs.items():
            exp = marg_from[a] * marg_to[b] / n_pairs
            exp_obs_mass += exp
            if exp > 0:
                chi2 += (obs - exp) ** 2 / exp
        # Unseen cells: obs=0, total expected = n_pairs - exp_obs_mass
        exp_unseen = n_pairs - exp_obs_mass
        if exp_unseen > 1e-12:
            chi2 += exp_unseen  # (0 - E)^2 / E = E
        dof = max(len(pairs) - 1, 1)  # approximate; not exact contingency dof
        chi2_note = "sparse/approx dof"

    p = chi2_sf(chi2, dof) if dof > 0 else float("nan")

    self_obs = sum(pairs.get((a, a), 0) for a in alphabet) / n_pairs
    self_exp = sum(
        (marg_from[a] / n_pairs) * (marg_to[a] / n_pairs) for a in alphabet
    )

    return {
        "n_pairs": n_pairs,
        "alphabet_size": k,
        "unique_transitions": len(pairs),
        "deterministic_successor": det,
        "chi2": chi2,
        "dof": dof,
        "p_value": p,
        "chi2_note": chi2_note,
        "max_abs_dev": max_dev,
        "worst_cell": worst,
        "self_trans_obs": self_obs,
        "self_trans_exp_indep": self_exp,
        "pairs": pairs,
        "alphabet": alphabet,
        "marg_from": marg_from,
        "marg_to": marg_to,
    }


MAX_ROWS = 20  # hard cap on printed lines (including header)

# seq  r1  peak_lag  peak_r  p  markov  det  maxDev
# markov: PASS if p >= 0.05 (fail to reject independence), else FAIL
ROW_FMT = "%-14s %8s %8s %8s %10s %6s %4s %8s"
ALPHA = 0.05


def peak_acf(acf: list[tuple[int, float]]) -> tuple[int, float]:
    best_lag, best_r = 1, 0.0
    for lag, r in acf:
        if math.isnan(r):
            continue
        if abs(r) > abs(best_r):
            best_lag, best_r = lag, r
    return best_lag, best_r


# Raw / wide sequences: Markov independence is meaningless (LFSR successor or huge alphabet).
SKIP_MARKOV = frozenset({"fast_rand", "rand16", "rand512"})


def summarize(name: str, seq: Sequence[int], max_lag: int) -> tuple[str, ...]:
    acf = autocorrelation(seq, max_lag)
    r1 = acf[0][1] if acf else float("nan")
    plag, pr = peak_acf(acf)
    m = markov_lag1(seq)
    if "error" in m:
        return (name, "ERR", "-", "-", "-", "-", "-", "-")
    if name in SKIP_MARKOV:
        p_s, markov = "", ""
    else:
        p = m["p_value"]
        p_s = "0" if p == 0 else f"{p:.3g}"
        markov = "PASS" if (not math.isnan(p) and p >= ALPHA) else "FAIL"
    det = "Y" if m["deterministic_successor"] else "N"
    return (
        name,
        f"{r1:+.3f}",
        str(plag),
        f"{pr:+.3f}",
        p_s,
        markov,
        det,
        f"{m['max_abs_dev']:.3f}",
    )



def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--steps", type=int, default=255 * 40,
                    help="samples per generator (default: 40 full 8-bit periods)")
    ap.add_argument("--lags", type=int, default=32, help="max ACF lag")
    ap.add_argument("--seed", type=lambda s: int(s, 0), default=BOOT,
                    help="boot seed for both LFSRs (default 0xAC)")
    args = ap.parse_args()

    raw8 = gen8(args.seed & 0xFF or BOOT, args.steps)
    raw16 = gen16(args.seed & 0xFFFF or BOOT, args.steps)

    sequences: list[tuple[str, list[int]]] = [
        ("fast_rand", raw8),
        ("rand_dir", [map_rand_dir(r) for r in raw8]),
        ("make_dirs_i3", [map_dirs_i3(r) for r in raw8]),
        ("make_dirs_i2", [map_dirs_i2(r) for r in raw8]),
        ("make_dirs_i1", [map_dirs_i1(r) for r in raw8]),
        ("rand16", raw16),
        ("rand512", [map_rand512(r) for r in raw16]),
    ]

    lines = [
        f"seed=${args.seed:04X} TAP8=${TAP8:02X} TAP16=${TAP16:04X} n={args.steps} lags={args.lags}",
        ROW_FMT % ("seq", "r1", "peakLag", "peakR", "p", "markov", "det", "maxDev"),
    ]
    for name, seq in sequences:
        lines.append(ROW_FMT % summarize(name, seq, args.lags))

    for line in lines[:MAX_ROWS]:
        print(line)


if __name__ == "__main__":
    main()


