"""Parse CASTLE.LVL pic blocks → charset.h (16 tiles × bank0/bank1 × 8 bytes)."""
from __future__ import annotations

from pathlib import Path

from parse_lvl import ORDER, load_lvl

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "CASTLE.LVL"
DST = ROOT / "charset.h"


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
    pack = load_lvl(SRC)
    bank0, bank1 = pack["bank0"], pack["bank1"]
    lines = [
        f"/* Generated from {SRC.name} — do not edit. */",
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
