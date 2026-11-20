"""Expand original 8x8 player/monster glyphs into ca65 tile bytes.

Player: 8x8 -> 2x2 (16x16) via nearest-neighbor (never smoothed).
Monsters: 8x8 -> 2x2 (16x16) via Scale2x (smooth) or nearest-neighbor.

Writes src/tiles_gen.inc. Run from build.bat or standalone:

  py -3 tools/expand_tiles.py
  py -3 tools/expand_tiles.py --nearest   # blocky pixel-double, no Scale2x
"""
from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "src" / "tiles_gen.inc"

# ---------------------------------------------------------------------------
# Original 8x8 source art (pre-expansion). Edit these, then regenerate.
# ---------------------------------------------------------------------------

TREE = [
    0b00011100,
    0b00101010,
    0b01010101,
    0b00101010,
    0b00011100,
    0b00011000,
    0b00111100,
    0b00000000,
]
TREE1 = [
    0b00111000,
    0b01010100,
    0b10101010,
    0b01010100,
    0b00111000,
    0b00011000,
    0b00111100,
    0b00000000,
]
BRICK = [
    0b11111111,
    0b00110000,
    0b00110000,
    0b11111111,
    0b11111111,
    0b10000001,
    0b10000001,
    0b11111111,
]
PLAYER = [
    0b00111100,
    0b01111110,
    0b00111100,
    0b00011001,
    0b11111111,
    0b10011000,
    0b00100100,
    0b01100110,
]
PLAYER1 = [
    0b00111100,
    0b01111110,
    0b00111100,
    0b10011000,
    0b11111111,
    0b00011001,
    0b00100100,
    0b11000110,
]
WANDER = [
    0b01000010,
    0b01111110,
    0b01011010,
    0b00111100,
    0b00011000,
    0b11111111,
    0b00011000,
    0b01100110,
]
WANDER1 = [
    0b00000000,
    0b01000010,
    0b01111110,
    0b01011010,
    0b00111100,
    0b11011011,
    0b00111100,
    0b01111110,
]
CHASE = [
    0b01000010,
    0b00111100,
    0b01011010,
    0b00100100,
    0b00011001,
    0b11111111,
    0b00011000,
    0b11100111,
]
CHASE1 = [
    0b01000010,
    0b00111100,
    0b01011010,
    0b00100100,
    0b11111111,
    0b00011000,
    0b01100110,
    0b00000000,
]
BULLET = [
    0b00000000,
    0b00000000,
    0b00011000,
    0b00101100,
    0b00111100,
    0b00011000,
    0b00000000,
    0b00000000,
]
BLOOD = [
    0b00000000,
    0b00010000,
    0b00001010,
    0b00100000,
    0b00000100,
    0b01000010,
    0b00010100,
    0b00000000,
]
BLOOD1 = [
    0b00000000,
    0b00000100,
    0b01010000,
    0b00000010,
    0b00100000,
    0b00000101,
    0b00101000,
    0b00000000,
]
COIN = [
    0b00000000,
    0b00111100,
    0b01111110,
    0b01111110,
    0b01111110,
    0b01111110,
    0b00111100,
    0b00000000,
]
COIN1 = [
    0b00000000,
    0b00111100,
    0b01111010,
    0b01111110,
    0b01111110,
    0b01111110,
    0b00111100,
    0b00000000,
]


def rows_to_grid(rows: list[int], w: int = 8, h: int = 8) -> list[list[bool]]:
    return [[bool(rows[y] & (0x80 >> x)) for x in range(w)] for y in range(h)]


def grid_to_rows(grid: list[list[bool]]) -> list[int]:
    rows = []
    for line in grid:
        b = 0
        for bit in line:
            b = (b << 1) | (1 if bit else 0)
        rows.append(b & 0xFF)
    return rows


def at(grid: list[list[bool]], x: int, y: int) -> bool:
    h = len(grid)
    w = len(grid[0])
    if x < 0 or y < 0 or x >= w or y >= h:
        return False
    return grid[y][x]


def nearest_2x(grid: list[list[bool]]) -> list[list[bool]]:
    """Blocky pixel-double: each source pixel -> 2x2."""
    h = len(grid)
    w = len(grid[0])
    out = [[False] * (w * 2) for _ in range(h * 2)]
    for y in range(h):
        for x in range(w):
            v = grid[y][x]
            out[y * 2][x * 2] = v
            out[y * 2][x * 2 + 1] = v
            out[y * 2 + 1][x * 2] = v
            out[y * 2 + 1][x * 2 + 1] = v
    return out


def scale2x(grid: list[list[bool]]) -> list[list[bool]]:
    """Scale2x / EPX — smooth 2x upsample for pixel art."""
    h = len(grid)
    w = len(grid[0])
    out = [[False] * (w * 2) for _ in range(h * 2)]
    for y in range(h):
        for x in range(w):
            e = grid[y][x]
            b = at(grid, x, y - 1)
            d = at(grid, x - 1, y)
            f = at(grid, x + 1, y)
            hh = at(grid, x, y + 1)  # H in Scale2x naming
            if b != hh and d != f:
                e0 = d if d == b else e
                e1 = f if b == f else e
                e2 = d if d == hh else e
                e3 = f if hh == f else e
            else:
                e0 = e1 = e2 = e3 = e
            out[y * 2][x * 2] = e0
            out[y * 2][x * 2 + 1] = e1
            out[y * 2 + 1][x * 2] = e2
            out[y * 2 + 1][x * 2 + 1] = e3
    return out


def expand_monster(rows: list[int], smooth: bool) -> tuple[list[int], list[int], list[int], list[int]]:
    """8x8 -> four 8x8 quadrants (TL, TR, BL, BR)."""
    src = rows_to_grid(rows)
    big = scale2x(src) if smooth else nearest_2x(src)
    tl = [grid_to_rows([big[y][0:8] for y in range(8)])]
    tr = [grid_to_rows([big[y][8:16] for y in range(8)])]
    bl = [grid_to_rows([big[y][0:8] for y in range(8, 16)])]
    br = [grid_to_rows([big[y][8:16] for y in range(8, 16)])]
    return tl[0], tr[0], bl[0], br[0]


def expand_player(rows: list[int]) -> tuple[list[int], list[int], list[int], list[int]]:
    """8x8 -> four 8x8 quadrants. Nearest-neighbor only — no Scale2x."""
    return expand_monster(rows, smooth=False)


def fmt_bytes(label: str, rows: list[int]) -> list[str]:
    lines = [f"        ; {label}"]
    for b in rows:
        lines.append(f"        .byte %{b:08b}")
    return lines


def emit_frame(
    tree: list[int],
    brick: list[int],
    player: list[int],
    wander: list[int],
    chase: list[int],
    bullet: list[int],
    blood: list[int],
    smooth: bool,
    frame_note: str,
) -> list[str]:
    ptl, ptr, pbl, pbr = expand_player(player)
    wtl, wtr, wbl, wbr = expand_monster(wander, smooth)
    ctl, ctr, cbl, cbr = expand_monster(chase, smooth)
    lines: list[str] = []
    lines += fmt_bytes(f"tree {frame_note}", tree)
    lines += fmt_bytes("brick", brick)
    lines += fmt_bytes("player tl", ptl)
    lines += fmt_bytes("player tr", ptr)
    lines += fmt_bytes("player bl", pbl)
    lines += fmt_bytes("player br", pbr)
    lines += fmt_bytes("wander tl", wtl)
    lines += fmt_bytes("wander tr", wtr)
    lines += fmt_bytes("wander bl", wbl)
    lines += fmt_bytes("wander br", wbr)
    lines += fmt_bytes("chase tl", ctl)
    lines += fmt_bytes("chase tr", ctr)
    lines += fmt_bytes("chase bl", cbl)
    lines += fmt_bytes("chase br", cbr)
    lines += fmt_bytes("bullet", bullet)
    lines += fmt_bytes("blood", blood)
    return lines


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--nearest",
        action="store_true",
        help="use blocky nearest-neighbor instead of Scale2x",
    )
    args = ap.parse_args()
    smooth = not args.nearest
    mode = "Scale2x smooth" if smooth else "nearest-neighbor"

    lines = [
        ";; AUTO-GENERATED by tools/expand_tiles.py -- do not edit by hand.",
        f";; Mode: {mode}. Source 8x8 art lives in that script.",
        ";; Player 2x2 (nearest), monsters 2x2 (Scale2x). py -3 tools/expand_tiles.py",
        "",
        ";; Bitmap 1 = foreground. TED paper is $FF15.",
        "tiles:",
    ]
    lines += emit_frame(TREE, BRICK, PLAYER, WANDER, CHASE, BULLET, BLOOD, smooth, "$60")
    lines.append("coin:")
    lines += fmt_bytes("PETSCII filled circle", COIN)
    lines.append("little:")
    lines += fmt_bytes("little wander $78", WANDER)
    lines += fmt_bytes("little chase $79", CHASE)
    lines += [
        "",
        ";; Second pose of each tile, same order as tiles.",
        "tiles1:",
    ]
    lines += emit_frame(TREE1, BRICK, PLAYER1, WANDER1, CHASE1, BULLET, BLOOD1, smooth, "")
    lines.append("coin1:")
    lines += fmt_bytes("PETSCII filled circle", COIN1)
    lines.append("little1:")
    lines += fmt_bytes("little wander", WANDER1)
    lines += fmt_bytes("little chase", CHASE1)
    lines.append("")

    OUT.write_text("\n".join(lines), encoding="ascii", newline="\n")
    print(f"Wrote {OUT.relative_to(ROOT)} ({mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
