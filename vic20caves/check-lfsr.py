"""Check Galois right-shift LFSR taps used by rand8 / rand16 in main.c.

Step matches C:

    rng = (rng >> 1) ^ ((rng & 1) ? poly : 0)

Maximal period is 2^n - 1 (every nonzero state, never 0).
"""

# Edit these to try other taps. Prints are computed from the values below.
POLY8 = 0xB4
POLY16 = 0xD008
SEED = 1

# Extra masks to measure the same way (not assumed good or bad).
EXTRA8 = (0x84,)
EXTRA16 = (0x8400, 0xB400, 0x8016, 0xA729)


def hex_width(bits):
    """Hex digits needed for an n-bit mask."""
    return (bits + 3) // 4


def fmt_poly(poly, bits):
    """Hex of a tap, width matching the register."""
    return "0x%0*X" % (hex_width(bits), poly)


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


def report(name, poly, bits):
    """Print measured period vs 2^n-1 for one tap mask."""
    want = (1 << bits) - 1
    n, hit_zero = period(poly, bits)
    ok = is_maximal(n, hit_zero, bits)
    print("")
    print("%s: tap %s, %d-bit register, seed %d" % (name, fmt_poly(poly, bits), bits, SEED))
    print("  Measured period (steps until that seed repeats): %d" % n)
    print("  Maximal period for %d bits: %d  (2^%d - 1)" % (bits, want, bits))
    print("  Entered state 0 on this run: %s" % ("yes" if hit_zero else "no"))
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
