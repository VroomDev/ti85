"""First-touch order of moveMonsters spotxy on the 32x32 torus.

Matches main.c:

    spotxy = (spotxy + SPOT_STRIDE) & 1023

Cell index is y * 32 + x (x = 0 at the left of each printed row).
Each cell is filled with the step when it was first reached (0 = start).
Untouched cells print as ----.
"""

# Same as main.c; edit these to try other taps.
MAP_CELLS = 1024
MAP_W = 32
MAP_WRAP = MAP_CELLS - 1
STRIDE = 1
START = 0


def gcd(a, b):
    while b:
        a, b = b, a % b
    return a


def first_touch(stride, start=START):
    """Walk start, then start+stride, ... until a cell repeats."""
    filled = [-1] * MAP_CELLS
    spotxy = start & MAP_WRAP
    step = 0
    while filled[spotxy] < 0:
        filled[spotxy] = step
        step += 1
        spotxy = (spotxy + stride) & MAP_WRAP
    return filled, step, spotxy


def neighbor_gaps(filled, period):
    """Avg first-touch gap from each visited cell to its torus neighbor.

    Gap is (touch[neighbor] - touch[here]) mod period: cursor steps after
    visiting this cell until the neighbor is visited. Smaller = that dir
    is scanned again sooner.
    """
    offsets = (
        ("right (+1)", 1),
        ("left  (-1)", -1),
        ("down  (+32)", MAP_W),
        ("up    (-32)", -MAP_W),
    )
    out = []
    for name, delta in offsets:
        total = 0
        n = 0
        lo = period
        hi = 0
        for xy in range(MAP_CELLS):
            if filled[xy] < 0:
                continue
            dest = (xy + delta) & MAP_WRAP
            if filled[dest] < 0:
                continue
            gap = (filled[dest] - filled[xy]) % period
            total += gap
            n += 1
            if gap < lo:
                lo = gap
            if gap > hi:
                hi = gap
        avg = (float(total) / float(n)) if n else None
        out.append((name, avg, n, lo if n else None, hi if n else None))
    return out


def print_gaps(filled, period):
    """Print left/right and up/down average scan gaps."""
    rows = neighbor_gaps(filled, period)
    print("Average scan gap to the next cell in each dir (smaller = faster re-visit):")
    by_name = {}
    for name, avg, n, lo, hi in rows:
        by_name[name] = avg
        if avg is None:
            print("  %s: no visited pairs" % name)
            continue
        extra = ""
        if lo == hi:
            extra = " (same at every cell)"
        else:
            extra = " (min %d max %d)" % (lo, hi)
        print("  %s: avg %s over %d cells%s" % (name, avg, n, extra))
    print("")
    r, l = by_name["right (+1)"], by_name["left  (-1)"]
    d, u = by_name["down  (+32)"], by_name["up    (-32)"]
    if r is not None and l is not None and r != 0:
        print("  Left vs right: left_gap/right_gap = %s (left %s, right %s)" % (float(l) / float(r), l, r))
    if d is not None and u is not None and d != 0:
        print("  Up vs down: up_gap/down_gap = %s (up %s, down %s)" % (float(u) / float(d), u, d))


def print_grid(filled):
    """32 rows, x = 0 on the left, y = 0 at the top."""
    width = len(str(MAP_CELLS - 1))
    for y in range(MAP_W):
        cells = []
        for x in range(MAP_W):
            n = filled[y * MAP_W + x]
            if n < 0:
                cells.append("-" * width)
            else:
                cells.append("%*d" % (width, n))
        print(" ".join(cells))


def main():
    g = gcd(STRIDE, MAP_CELLS)
    cycle = MAP_CELLS // g
    filled, visited, back = first_touch(STRIDE)
    untouched = sum(1 for n in filled if n < 0)

    print("spotxy starts at %d, then spotxy = (spotxy + %d) & %d" % (START, STRIDE, MAP_WRAP))
    print("Map is %d x %d; printed x = 0 on the left, y = 0 at the top." % (MAP_W, MAP_W))
    print("Each number is the first-touch step (cell at start is 0).")
    print(
        "gcd(stride, %d) = %d, so this walk hits %d cells before it loops (back at index %d)."
        % (MAP_CELLS, g, cycle, back)
    )
    print("Visited %d unique cells; %d never touched." % (visited, untouched))
    print("")
    print_gaps(filled, visited)
    print("")
    print_grid(filled)


if __name__ == "__main__":
    main()
