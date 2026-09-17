"""Does moveMonsters' spot cursor favor some walk directions?

main.c: each scan step does spotxy = (spotxy + STRIDE) & 1023, then if that
cell is a patrol it tryMoves along its dir. A walker that lands on a cell the
cursor will hit later in the same sweep gets extra turns.

This file:
  1. Average first-touch gap to +1 / -1 / +32 / -32 (smaller = that dir is faster).
  2. Simulates one locked-dir patrol on an empty map for N frames (no falling).

Prints are computed from STRIDE / STEPS / FRAMES; edit those at the top.
"""

MAP_CELLS = 1024
MAP_W = 32
MAP_WRAP = MAP_CELLS - 1
STRIDE = 241
STEPS = 128
FRAMES = 64
START = 0

TILE_BLANK = 0
TILE_PATROL = 6

LEFTDIR = 0
RIGHTDIR = 1
UPDIR = 2
DOWNDIR = 3

DELTA = {
    LEFTDIR: -1,
    RIGHTDIR: 1,
    UPDIR: -MAP_W,
    DOWNDIR: MAP_W,
}

DIR_NAME = {
    LEFTDIR: "left  (-1)",
    RIGHTDIR: "right (+1)",
    UPDIR: "up    (-32)",
    DOWNDIR: "down  (+32)",
}


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


def avg_gap(filled, period, delta):
    """Mean cursor steps from a cell to the neighbor at +delta."""
    total = 0
    n = 0
    for xy in range(MAP_CELLS):
        if filled[xy] < 0:
            continue
        dest = (xy + delta) & MAP_WRAP
        if filled[dest] < 0:
            continue
        total += (filled[dest] - filled[xy]) % period
        n += 1
    if n == 0:
        return None
    return float(total) / float(n)


def ratio_line(label, a_name, a_moves, b_name, b_moves):
    """One comparison line from the two measured move counts."""
    if a_moves == 0 and b_moves == 0:
        return "%s: no moves recorded." % label
    if b_moves == 0:
        return "%s: %s moved %d times, %s moved 0." % (label, a_name, a_moves, b_name)
    return "%s: %s/%s move ratio = %s (%s %d, %s %d)" % (
        label,
        a_name,
        b_name,
        float(a_moves) / float(b_moves),
        a_name,
        a_moves,
        b_name,
        b_moves,
    )


def packed_patrol(direction):
    return TILE_PATROL | (direction << 4)


def simulate(direction, frames=FRAMES, steps=STEPS, stride=STRIDE):
    """One patrol, empty map, dir locked. Returns (cursor_hits, successful_moves, pos)."""
    playfield = [TILE_BLANK] * MAP_CELLS
    start = 16 * MAP_W + 16
    playfield[start] = packed_patrol(direction)

    spotxy = START
    hits = 0
    moves = 0
    pos = start
    for _ in range(frames):
        for _ in range(steps):
            spotxy = (spotxy + stride) & MAP_WRAP
            cell = playfield[spotxy]
            if (cell & 15) != TILE_PATROL:
                continue
            hits += 1
            dest = (spotxy + DELTA[direction]) & MAP_WRAP
            if (playfield[dest] & 15) != TILE_BLANK:
                playfield[spotxy] = packed_patrol(direction)
                continue
            playfield[dest] = packed_patrol(direction)
            playfield[spotxy] = TILE_BLANK
            pos = dest
            moves += 1
    return hits, moves, pos


def main():
    print(
        "Cursor: spotxy = (spotxy + %d) & %d, %d steps/frame, %d frames."
        % (STRIDE, MAP_WRAP, STEPS, FRAMES)
    )
    print("If the next cell in a dir is scanned soon, walkers in that dir get extra turns.")
    print("")
    filled, period, _ = first_touch(STRIDE)
    print("Average scan gap to the next cell (smaller = faster re-visit):")
    gaps = {}
    for direction in (LEFTDIR, RIGHTDIR, UPDIR, DOWNDIR):
        g = avg_gap(filled, period, DELTA[direction])
        gaps[direction] = g
        print("  %s: %s" % (DIR_NAME[direction], g))
    lg, rg = gaps[LEFTDIR], gaps[RIGHTDIR]
    ug, dg = gaps[UPDIR], gaps[DOWNDIR]
    if lg is not None and rg is not None and rg != 0:
        print("  Left vs right: left_gap/right_gap = %s (left %s, right %s)" % (float(lg) / float(rg), lg, rg))
    if ug is not None and dg is not None and dg != 0:
        print("  Up vs down: up_gap/down_gap = %s (up %s, down %s)" % (float(ug) / float(dg), ug, dg))

    print("")
    print("Sim: one patrol, empty map, dir locked (falling skipped so all four dirs stay comparable).")
    results = []
    for direction in (LEFTDIR, RIGHTDIR, UPDIR, DOWNDIR):
        hits, moves, pos = simulate(direction)
        results.append((direction, hits, moves))
        print(
            "  %s: cursor hits %d, moves %d, end xy %d (x=%d y=%d)"
            % (
                DIR_NAME[direction],
                hits,
                moves,
                pos,
                pos & 31,
                pos >> 5,
            )
        )

    left_moves = results[0][2]
    right_moves = results[1][2]
    up_moves = results[2][2]
    down_moves = results[3][2]
    print("")
    print(ratio_line("Left vs right", "right", right_moves, "left", left_moves))
    print(ratio_line("Up vs down", "down", down_moves, "up", up_moves))


if __name__ == "__main__":
    main()
