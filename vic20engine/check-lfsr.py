"""Check Galois right-shift LFSR taps used by rand8 / rand16 in main.c.

Step matches C:

    rng = (rng >> 1) ^ ((rng & 1) ? poly : 0)

Maximal period is 2^n - 1 (every nonzero state, never 0).
"""

# Edit these to try other taps. Prints are computed from the values below.
POLY8 = 0xFA
POLY16 = 0xD008
SEED = 1

# Extra taps to measure the same way (not assumed good or bad).
EXTRA8 = (0xB4, 0xB8,0x84,0xAF)
EXTRA16 = (0xB400, 0x8016)


def hex_width(bits):
    """Hex digits needed for an n-bit mask."""
    return (bits + 3) // 4


def fmt_poly(poly, bits):
    """Hex of a tap, width matching the register."""
    return "0x%0*X" % (hex_width(bits), poly)


def tap_ones(poly):
    """Count of 1-bits in the tap mask (e.g. 0b10010001 -> 3)."""
    return bin(poly).count("1")


def step(state, poly, mask):
    """One Galois right-shift LFSR step (same as main.c)."""
    return ((state >> 1) ^ (poly if (state & 1) else 0)) & mask


def period(poly, bits, seed=SEED):
    """Steps until seed repeats. Also notes whether 0 is visited."""
    mask = (1 << bits) - 1
    poly &= mask
    seed &= mask
    if seed == 0:
        return 1, True
    x = seed
    n = 0
    hit_zero = False
    max_n = mask + 1
    while n < max_n:
        x = step(x, poly, mask)
        n += 1
        if x == 0:
            hit_zero = True
        if x == seed:
            return n, hit_zero
    return n, hit_zero


def cycle_lengths(poly, bits):
    """Distinct cycle lengths from every seed (including 0)."""
    mask = (1 << bits) - 1
    poly &= mask
    seen = [False] * (mask + 1)
    lengths = set()
    for start in range(mask + 1):
        if seen[start]:
            continue
        x = start
        n = 0
        while not seen[x]:
            seen[x] = True
            x = step(x, poly, mask)
            n += 1
        lengths.add(n)
    return sorted(lengths)


def is_maximal(n, hit_zero, bits):
    """True if period is 2^n-1 and state 0 was never entered."""
    return n == (1 << bits) - 1 and not hit_zero


def sequence(poly, bits, count, seed=SEED):
    """Generate `count` successive LFSR states after `seed`."""
    mask = (1 << bits) - 1
    poly &= mask
    x = seed & mask
    out = []
    for _ in range(count):
        x = step(x, poly, mask)
        out.append(x)
    return out


def lag1_correlation(values):
    """Pearson lag-1 autocorrelation of a numeric sequence (near 0 is uncorrelated)."""
    n = len(values)
    if n < 2:
        return 0.0
    mean = sum(values) / float(n)
    num = 0.0
    den = 0.0
    for i in range(n):
        d = values[i] - mean
        den += d * d
        if i + 1 < n:
            num += d * (values[i + 1] - mean)
    if den == 0.0:
        return 0.0
    return num / den


def lo2_markov(values):
    """4x4 transition matrix for (rng >> 1) & 3 (bits [2:1])."""
    counts = [[0] * 4 for _ in range(4)]
    row_tot = [0] * 4
    for i in range(len(values) - 1):
        a = ((values[i])>>1) & 3
        b = ((values[i + 1])>>1) & 3
        counts[a][b] += 1
        row_tot[a] += 1
    probs = []
    for a in range(4):
        denom = float(row_tot[a]) if row_tot[a] else 0.0
        row = []
        for b in range(4):
            row.append((counts[a][b] / denom) if denom else 0.0)
        probs.append(row)
    return probs


def fmt_lo2_markov_flat(probs):
    """Sixteen P(from->to) values, row-major, two decimal places."""
    parts = []
    for a in range(4):
        for b in range(4):
            parts.append("%.2f" % probs[a][b])
    return " ".join(parts)


def bit1_markov(values):
    """2x2 transition matrix for (rng >> 1) & 1: P(next_bit | prev_bit)."""
    counts = [[0] * 2 for _ in range(2)]
    row_tot = [0] * 2
    for i in range(len(values) - 1):
        a = (values[i] >> 1) & 1
        b = (values[i + 1] >> 1) & 1
        counts[a][b] += 1
        row_tot[a] += 1
    probs = []
    for a in range(2):
        denom = float(row_tot[a]) if row_tot[a] else 0.0
        row = []
        for b in range(2):
            row.append((counts[a][b] / denom) if denom else 0.0)
        probs.append(row)
    return probs


def fmt_bit1_markov_flat(probs):
    """Four P(from->to) values for (rng>>1)&1, row-major, two decimals."""
    parts = []
    for a in range(2):
        for b in range(2):
            parts.append("%.2f" % probs[a][b])
    return " ".join(parts)


def print_lo2_markov(probs, indent="  "):
    """Print 4x4 (rng>>1)&3 transition probs rounded to two decimals."""
    print(
        "%sMarkov (rng>>1)&3 P(from->to) bits[2:1] "
        "(ideal independent ~0.25 each):" % indent
    )
    print("%s         to0   to1   to2   to3" % indent)
    for a in range(4):
        cells = "  ".join("%.2f" % probs[a][b] for b in range(4))
        print("%s  from%d  %s" % (indent, a, cells))
    print("%s  flat: %s" % (indent, fmt_lo2_markov_flat(probs)))


def print_bit1_markov(probs, indent="  "):
    """Print 2x2 (rng>>1)&1 transition probs, then flat 4 values."""
    print(
        "%sMarkov (rng>>1)&1 P(from->to) "
        "(ideal independent ~0.50 each):" % indent
    )
    print("%s         to0   to1" % indent)
    for a in range(2):
        cells = "  ".join("%.2f" % probs[a][b] for b in range(2))
        print("%s  from%d  %s" % (indent, a, cells))
    print("%s  flat: %s" % (indent, fmt_bit1_markov_flat(probs)))


def report(name, poly, bits):
    """Print measured period vs 2^n-1 for one tap mask."""
    want = (1 << bits) - 1
    n, hit_zero = period(poly, bits)
    ok = is_maximal(n, hit_zero, bits)
    vals = sequence(poly, bits, want)
    corr = lag1_correlation(vals)
    print("")
    print(
        "%s: tap %s (%d ones), %d-bit register, seed %d"
        % (name, fmt_poly(poly, bits), tap_ones(poly), bits, SEED)
    )
    print("  Measured period (steps until that seed repeats): %d" % n)
    print("  Maximal period for %d bits: %d  (2^%d - 1)" % (bits, want, bits))
    print("  Entered state 0 on this run: %s" % ("yes" if hit_zero else "no"))
    print("  Lag-1 autocorrelation (prior vs next, %d samples): %.6f" % (want, corr))
    print_lo2_markov(lo2_markov(vals))
    print_bit1_markov(bit1_markov(vals))
    if SEED == 0:
        print("  Result: FAIL: seed is 0, which stays 0 for this LFSR.")
        return False
    if ok:
        print("  Result: PASS: period is maximal and 0 was not entered.")
    elif hit_zero:
        print("  Result: FAIL: reached 0, which stays 0.")
    else:
        print("  Result: FAIL: period %d is shorter than %d." % (n, want))
    return ok


def explain_cycles(poly, bits):
    """Print cycle lengths using only what was measured."""
    want = (1 << bits) - 1
    lengths = cycle_lengths(poly, bits)
    print("")
    print(
        "All cycle lengths for %s from every %d-bit start, including 0: %s"
        % (fmt_poly(poly, bits), bits, lengths)
    )
    print("  Each value is the size of one loop of states.")
    if 1 in lengths:
        print("  A 1-cycle is a state that maps to itself (state 0 always does).")
    if want in lengths:
        print("  A %d-cycle is a full-period loop of the nonzero states." % want)
    else:
        print("  No %d-cycle, so this tap is not maximal for all nonzero seeds." % want)


def scan_maximal(bits):
    """List every tap mask of this width with maximal period from SEED."""
    want = (1 << bits) - 1
    good = []
    for poly in range(1, 1 << bits):
        n, hit_zero = period(poly, bits)
        if is_maximal(n, hit_zero, bits):
            good.append(poly)
    print("")
    print(
        "Scan: %d of %d nonzero %d-bit taps have period %d from seed %d:"
        % (len(good), want, bits, want, SEED)
    )
    print("  " + " ".join(fmt_poly(p, bits) for p in good))
    return good


def rank_maximal_by_autocorr(bits=8, polys=None):
    """Maximal taps listed best first (lowest lag-1).

    If polys is None, scan every nonzero tap of this width; otherwise only those.
    """
    want = (1 << bits) - 1
    primary = POLY8 if bits == 8 else (POLY16 if bits == 16 else None)
    primary_name = "POLY8" if bits == 8 else ("POLY16" if bits == 16 else "POLY")
    tap_w = 2 + hex_width(bits)
    if polys is None:
        candidates = range(1, 1 << bits)
        scan_desc = "1..%d" % want
    else:
        candidates = polys
        scan_desc = ", ".join(fmt_poly(p, bits) for p in polys)
    ranked = []
    print("")
    print("Scanning %d-bit taps [%s] for maximal period + lag-1..." % (bits, scan_desc))
    for poly in candidates:
        n, hit_zero = period(poly, bits)
        if not is_maximal(n, hit_zero, bits):
            continue
        vals = sequence(poly, bits, want)
        corr = lag1_correlation(vals)
        ranked.append((corr, poly, lo2_markov(vals), bit1_markov(vals)))
    ranked.sort(key=lambda item: item[0])
    print(
        "Valid %d-bit taps (maximal), best first (lowest lag-1 autocorrelation):"
        % bits
    )
    print(
        "  %-*s ones  lag-1     markov (rng>>1)&3 (0->0..3..)  "
        "markov (rng>>1)&1 (0->0,0->1,1->0,1->1)"
        % (tap_w, "tap")
    )
    for corr, poly, markov, bit1 in ranked:
        mark = (" <-- " + primary_name) if poly == primary else ""
        print(
            "  %-*s  %2d  %+.4f   %s  %s%s"
            % (
                tap_w,
                fmt_poly(poly, bits),
                tap_ones(poly),
                corr,
                fmt_lo2_markov_flat(markov),
                fmt_bit1_markov_flat(bit1),
                mark,
            )
        )
    return ranked


def main():
    print("Galois right-shift LFSR check (same step as rand8 / rand16 in main.c).")
    print("Period = steps until the configured seed repeats. Maximal = 2^n - 1.")
    print("State 0 always stays 0; a maximal tap must never reach it from a nonzero seed.")

    ok = True
    ok &= report("POLY8 / rand8", POLY8, 8)
    ok &= report("POLY16 / rand16", POLY16, 16)
    explain_cycles(POLY8, 8)

    print("")
    print("Extra taps (same measurements; verdict follows the numbers):")
    for poly in EXTRA8:
        report("EXTRA8", poly, 8)
    for poly in EXTRA16:
        report("EXTRA16", poly, 16)

    good8 = scan_maximal(8)
    print("")
    if POLY8 in good8:
        print("POLY8 %s is in the maximal 8-bit list above." % fmt_poly(POLY8, 8))
    else:
        print("POLY8 %s is not in the maximal 8-bit list above." % fmt_poly(POLY8, 8))

    rank_maximal_by_autocorr(8)
    rank_maximal_by_autocorr(16, polys=(POLY16,) + tuple(EXTRA16))

    print("")
    if ok:
        print(
            "Overall: PASS (%s and %s both measured maximal from seed %d)."
            % (fmt_poly(POLY8, 8), fmt_poly(POLY16, 16), SEED)
        )
    else:
        print(
            "Overall: FAIL (%s or %s is not maximal from seed %d)."
            % (fmt_poly(POLY8, 8), fmt_poly(POLY16, 16), SEED)
        )
        raise SystemExit(1)


if __name__ == "__main__":
    main()
