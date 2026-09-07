"""Parse char.txt → charset.h (16 tiles × bank0/bank1 × 8 bytes)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "char.txt"
DST = ROOT / "charset.h"

ORDER = [".", "P", "s", "f", "S", "k", "M", "m", "F", "B", "t", "b", "D", "c", "W", "X"]

HEADER_RE = re.compile(r"^#(.)([01])")
BITS_RE = re.compile(r"^([01]{8})")


def parse(text: str) -> tuple[dict[str, bytes], dict[str, bytes]]:
    bank0: dict[str, bytes] = {}
    bank1: dict[str, bytes] = {}
    glyph_id: str | None = None
    frame = 0
    rows: list[int] = []

    def flush() -> None:
        nonlocal glyph_id, rows
        if glyph_id is None or not rows:
            return
        data = bytes(rows[:8]).ljust(8, b"\x00")
        if frame == 0:
            bank0[glyph_id] = data
        else:
            bank1[glyph_id] = data
        rows = []

    for line in text.splitlines():
        header = HEADER_RE.match(line)
        if header:
            flush()
            glyph_id = header.group(1)
            frame = int(header.group(2))
            rows = []
            continue
        bits = BITS_RE.match(line)
        if bits:
            rows.append(int(bits.group(1), 2))
    flush()

    if "W" not in bank0 and "f" in bank0:
        bank0["W"] = bank0["f"]
    if "W" not in bank1:
        bank1["W"] = bank1.get("f", bank0.get("W", b"\x00" * 8))
    if "X" not in bank0 and "." in bank0:
        bank0["X"] = bank0["."]
    if "X" not in bank1:
        bank1["X"] = bank0.get("X", b"\x00" * 8)

    return bank0, bank1


def hex_row(data: bytes) -> str:
    return ", ".join(f"0x{b:02X}" for b in data)


def emit_bank(name: str, bank: dict[str, bytes], bank0: dict[str, bytes], frame: int) -> list[str]:
    lines = [f"static const unsigned char {name}[TILE_COUNT][8] = {{"]
    blank = bank0.get(".", b"\x00" * 8)
    for i, ch in enumerate(ORDER):
        data = bank.get(ch) or bank0.get(ch) or blank
        comma = "," if i < len(ORDER) - 1 else ""
        lines.append(f"    {{ {hex_row(data)} }}{comma}  /* {ch}{frame} */")
    lines.append("};")
    return lines


def main() -> None:
    bank0, bank1 = parse(SRC.read_text(encoding="utf-8"))
    lines = [
        "/* Generated from char.txt — do not edit. */",
        "#ifndef CHARSET_H",
        "#define CHARSET_H",
        "",
        "#define TILE_COUNT 16",
        "#define TILE_BASE  0x60",
        "",
        "/* Slot order: . P s f S k M m F B t b D c W X */",
    ]
    lines.extend(emit_bank("tile_bank0", bank0, bank0, 0))
    lines.append("")
    lines.extend(emit_bank("tile_bank1", bank1, bank0, 1))
    lines.extend(["", "#endif", ""])
    DST.write_text("\n".join(lines), encoding="utf-8")
    print("Wrote charset.h")


if __name__ == "__main__":
    main()
