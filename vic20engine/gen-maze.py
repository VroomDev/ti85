#!/usr/bin/env python3
"""Circular maze: recursive backtracker with a vertical-run limit."""
from __future__ import annotations

import argparse
import random
import re
import sys
import time

DY = (-2, 2, 0, 0)
DX = (0, 0, -2, 2)
MAP_CHARS = ".PMmcsfFBStbDkWX"
ADD_RE = re.compile(rf"^-a([{re.escape(MAP_CHARS)}])(b)?$")
MAP_LEGEND = """\
Each level item is one of the charecters in the string
".PMmcsfFBStbDkW".  The meanings are as follows:
   .  blank spot
   P  a person
   M  a monster
   m  another monster
   c  gem/coin treasure
   s  scroll, need one per level
   f  fire
   F  a bomb
   B  stationary bullet/strange door
   S  a blood stain
   t  a tree
   b  a brick
   D  a door
   k  a key
   W  a shootable brick for secret passages
   X  the place where the player starts
"""


def is_outside_circle(y: int, x: int, cy: float, cx: float, radius: float) -> bool:
    dy_val = y - cy
    dx_val = x - cx
    return (dx_val * dx_val + dy_val * dy_val) > (radius * radius)


def generate_maze(
    maze: list[list[str]],
    y: int,
    x: int,
    last_dir: int,
    run_len: int,
    width: int,
    height: int,
    cy: float,
    cx: float,
    radius: float,
    vertical_limit: int,
) -> None:
    maze[y][x] = " "
    dirs = [0, 1, 2, 3]
    for i in range(4):
        r = random.randrange(4)
        dirs[i], dirs[r] = dirs[r], dirs[i]

    for direction in dirs:
        ny = y + DY[direction]
        nx = x + DX[direction]
        if (
            ny <= 0
            or ny >= height - 1
            or nx <= 0
            or nx >= width - 1
            or is_outside_circle(ny, nx, cy, cx, radius)
        ):
            continue
        if maze[ny][nx] != "#":
            continue

        is_vertical = direction == 0 or direction == 1
        if is_vertical:
            if last_dir == direction:
                next_run_len = run_len + 2
            else:
                next_run_len = 2
            if next_run_len > vertical_limit:
                continue
        else:
            next_run_len = 0

        maze[y + DY[direction] // 2][x + DX[direction] // 2] = " "
        generate_maze(
            maze,
            ny,
            nx,
            direction,
            next_run_len,
            width,
            height,
            cy,
            cx,
            radius,
            vertical_limit,
        )


def peel_adds(argv: list[str]) -> tuple[list[tuple[str, bool, float]], list[str]]:
    adds: list[tuple[str, bool, float]] = []
    rest: list[str] = []
    i = 0
    while i < len(argv):
        m = ADD_RE.match(argv[i])
        if m:
            if i + 1 >= len(argv):
                raise SystemExit(f"{argv[i]} needs a percent 0-100")
            try:
                pct = float(argv[i + 1])
            except ValueError:
                raise SystemExit(f"{argv[i]} percent must be a number")
            if pct < 0 or pct > 100:
                raise SystemExit(f"{argv[i]} percent must be 0 to 100")
            adds.append((m.group(1), m.group(2) == "b", pct))
            i += 2
            continue
        if argv[i].startswith("-a") and argv[i] not in ("-a",):
            raise SystemExit(
                f"invalid -a spec {argv[i]!r}; use -aX PCT or -aXb PCT "
                f"with X one of {MAP_CHARS}"
            )
        rest.append(argv[i])
        i += 1
    return adds, rest


def apply_adds(grid: list[list[str]], adds: list[tuple[str, bool, float]]) -> None:
    if not adds:
        return
    height = len(grid)
    width = len(grid[0]) if height else 0
    for y in range(height):
        for x in range(width):
            ch = grid[y][x]
            for symbol, from_b, pct in adds:
                target = "b" if from_b else "."
                if ch == target and random.random() * 100.0 < pct:
                    ch = symbol
            grid[y][x] = ch


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        add_help=False,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description="Generate a circular ASCII maze (open=.  wall=b).",
        epilog="""\
  -aX PCT     PCT% chance to place X on each . cell
  -aXb PCT    PCT% chance to change each b into X
  -ac 3       3% coins on open cells
  -aFb 10     10% of bricks become bombs

"""
        + MAP_LEGEND,
    )
    parser.add_argument(
        "--help", action="help", help="show this help message and exit"
    )
    parser.add_argument("-w", dest="width", type=int, help="grid width")
    parser.add_argument("-h", dest="height", type=int, help="grid height")
    parser.add_argument(
        "-v",
        dest="vertical_limit",
        type=int,
        help="max consecutive vertical spaces (default: height)",
    )
    parser.add_argument(
        "-cx",
        dest="cx",
        type=float,
        help="circle center x (default: int((width-1)/2))",
    )
    parser.add_argument(
        "-cy",
        dest="cy",
        type=float,
        help="circle center y (default: int((height-1)/2))",
    )
    parser.add_argument(
        "-r",
        dest="radius",
        type=float,
        help="circle radius (default: (height-1)/2.0)",
    )
    parser.add_argument(
        "-i",
        dest="invert",
        action="store_true",
        help="invert glyphs (. becomes b, b becomes .)",
    )
    argv = sys.argv[1:]
    if len(argv) == 0:
        parser.print_help()
        raise SystemExit(0)
    adds, rest = peel_adds(argv)
    args = parser.parse_args(rest)
    if args.width is None or args.height is None:
        parser.print_help()
        raise SystemExit(2)
    args.adds = adds
    return args


def all_open_reachable(grid: list[list[str]]) -> bool:
    """True if every '.' is 4-connected to every other '.'."""
    height = len(grid)
    width = len(grid[0]) if height else 0
    opens: list[tuple[int, int]] = []
    for y in range(height):
        for x in range(width):
            if grid[y][x] == ".":
                opens.append((y, x))
    if not opens:
        return True
    sy, sx = opens[0]
    seen = {(sy, sx)}
    stack = [(sy, sx)]
    while stack:
        y, x = stack.pop()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if (
                0 <= ny < height
                and 0 <= nx < width
                and (ny, nx) not in seen
                and grid[ny][nx] == "."
            ):
                seen.add((ny, nx))
                stack.append((ny, nx))
    return len(seen) == len(opens)


def main() -> None:
    args = parse_args()
    width = args.width
    height = args.height
    vertical_limit = height if args.vertical_limit is None else args.vertical_limit
    cx = float(int((width - 1) / 2)) if args.cx is None else args.cx
    cy = float(int((height - 1) / 2)) if args.cy is None else args.cy
    radius = (height - 1) if args.radius is None else args.radius #was /2

    random.seed(int(time.time()))
    maze = [["#" for _ in range(width)] for _ in range(height)]

    start_y = int(cy)
    start_x = int(cx)
    if not (0 < start_y < height - 1 and 0 < start_x < width - 1):
        raise SystemExit("center is outside the inner grid")
    if not is_outside_circle(start_y, start_x, cy, cx, radius):
        generate_maze(
            maze,
            start_y,
            start_x,
            -1,
            0,
            width,
            height,
            cy,
            cx,
            radius,
            vertical_limit,
        )

    out_lines = []
    for y in range(height):
        row = []
        for x in range(width):
            ch = " " if is_outside_circle(y, x, cy, cx, radius) else maze[y][x]
            if ch == " ":
                glyph = "b" if args.invert else "."
            elif ch == "#":
                glyph = "." if args.invert else "b"
            else:
                glyph = ch
            row.append(glyph)
        out_lines.append("".join(row))
    grid = [list(line) for line in out_lines]
    apply_adds(grid, args.adds)
    if all_open_reachable(grid):
        sys.stderr.write("all open cells are reachable\n")
    else:
        sys.stderr.write("not all open cells are reachable\n")
    sys.stdout.write("\n".join("".join(row) for row in grid) + "\n")


if __name__ == "__main__":
    main()
