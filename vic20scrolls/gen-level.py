"""Parse a .LVL pack's maps → nibble-packed level.h."""
from __future__ import annotations

import sys
from pathlib import Path

from parse_lvl import MAP_SIZE, ORDER, load_lvl, resolve_lvl_path

ROOT = Path(__file__).resolve().parent
DST = ROOT / "level.h"

PACKED_SIZE = (MAP_SIZE * MAP_SIZE) // 2
SCREEN_COLS = 22

TILE_DEFINES = """
#define TILE_BLANK   0  /* . */
#define TILE_PLAYER  1  /* map X start and P humans; #P glyph */
#define TILE_SCROLL  2  /* s */
#define TILE_FIRE    3  /* f */
#define TILE_BLOOD   4  /* S */
#define TILE_KEY     5  /* k */
#define TILE_PATROL  6  /* M monster1 */
#define TILE_SEEKER  7  /* m monster2 */
#define TILE_BOMB    8  /* F */
#define TILE_BULLET  9  /* B */
#define TILE_TREE    10 /* t falling wall */
#define TILE_BRICK   11 /* b */
#define TILE_DOOR    12 /* D */
#define TILE_COIN    13 /* c */
#define TILE_WALL    14 /* W */
#define TILE_UNUSED  15 /* charset slot 15 (#X pic); not a map cell */
""".strip()


def letter_to_nibble(ch: str) -> int:
    if ch == "X" or ch == "P":
        return 1
    try:
        return ORDER.index(ch)
    except ValueError:
        return 0


def compile_map(rows: list[str]) -> tuple[list[int], int]:
    cells: list[int] = []
    start = 0
    found_start = False
    for row in rows:
        for ch in row:
            if ch == "X" and not found_start:
                start = len(cells)
                found_start = True
            cells.append(letter_to_nibble(ch))
    return cells, start


def pack(cells: list[int]) -> bytes:
    out = bytearray()
    for i in range(0, len(cells), 2):
        out.append((cells[i] & 0x0F) | ((cells[i + 1] & 0x0F) << 4))
    return bytes(out)


def hex_block(packed: bytes, indent: str = "    ") -> str:
    hex_rows: list[str] = []
    for row in range(0, len(packed), 16):
        chunk = packed[row : row + 16]
        hex_rows.append(indent + ", ".join(f"0x{b:02X}" for b in chunk) + ",")
    return "\n".join(hex_rows)


def c_string(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def center_screen(s: str) -> str:
    s = s.strip()
    if len(s) > SCREEN_COLS:
        s = s[:SCREEN_COLS]
    return s.center(SCREEN_COLS)


def main(argv: list[str] | None = None) -> None:
    args = sys.argv[1:] if argv is None else argv
    if len(args) > 1:
        raise SystemExit("usage: gen-level.py [LVL]")
    src = resolve_lvl_path(args[0] if args else None)
    if not src.is_file():
        raise SystemExit(f"LVL not found: {src}")
    pack_data = load_lvl(src)
    maps = pack_data["maps"]
    if not maps:
        raise SystemExit(f"{src.name}: no 32x32 maps found")

    packed_maps: list[bytes] = []
    starts: list[int] = []
    for rows in maps:
        cells, start = compile_map(rows)
        packed = pack(cells)
        if len(packed) != PACKED_SIZE:
            raise SystemExit(f"expected {PACKED_SIZE} packed bytes, got {len(packed)}")
        packed_maps.append(packed)
        starts.append(start)

    n = len(packed_maps)
    meta = pack_data["meta"]
    story = center_screen(meta.get("story", ""))
    author = center_screen(meta.get("author", ""))

    level_blocks: list[str] = []
    for i, packed in enumerate(packed_maps):
        comma = "," if i < n - 1 else ""
        level_blocks.append("    {\n" + hex_block(packed, "        ") + "\n    }" + comma)

    start_list = ", ".join(str(s) for s in starts)

    lines = [
        f"/* Generated from {src.name} — do not edit. */",
        "#ifndef LEVEL_H",
        "#define LEVEL_H",
        "",
        TILE_DEFINES,
        "",
        f"#define LEVEL_COUNT {n}",
        f"#define PLAYER_START {starts[0]}",
        f"#define STORY_TITLE {c_string(story)}",
        f"#define STORY_AUTHOR {c_string(author)}",
        "",
        f"static const unsigned int playerStart[LEVEL_COUNT] = {{ {start_list} }};",
        "",
        f"static const unsigned char packedLevels[LEVEL_COUNT][{PACKED_SIZE}] = {{",
        "\n".join(level_blocks),
        "};",
        "",
        "#define packedLevel packedLevels[0]",
        "",
        "#endif",
        "",
    ]
    DST.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {DST.name} ({n} maps, {PACKED_SIZE} bytes each)")


if __name__ == "__main__":
    main()
