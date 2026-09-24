"""Parse a .LVL pack's pic blocks → charset.h (16 tiles × bank0/bank1 × 8 bytes)."""
from __future__ import annotations

import os
import sys
from datetime import date
from pathlib import Path

from parse_lvl import ORDER, load_lvl, resolve_lvl_path

OUT = Path(os.environ["OUTDIR"]) if os.environ.get("OUTDIR") else Path.cwd()
DST = OUT / "charset.h"
DEFCHARS = Path(os.environ["DEFCHARS"]) if os.environ.get("DEFCHARS") else OUT / "DEFCHARS.DEF"


def hex_row(data: bytes) -> str:
    return ", ".join(f"0x{b:02X}" for b in data)


def merge_bank(base: dict[str, bytes], overlay: dict[str, bytes]) -> dict[str, bytes]:
    out = dict(base)
    out.update(overlay)
    return out


def alias_wx(
    bank0: dict[str, bytes],
    bank1: dict[str, bytes],
    pack0: dict[str, bytes],
    pack1: dict[str, bytes],
) -> None:
    blank = b"\x00" * 8
    if "W" not in pack0 and "b" in bank0:
        bank0["W"] = bank0["b"]
    if "W" not in pack1:
        bank1["W"] = bank1.get("b") or bank0.get("W", blank)
    if "X" not in pack0 and "." in bank0:
        bank0["X"] = bank0["."]
    if "X" not in pack1:
        bank1["X"] = bank0.get("X", blank)


def patch_notes(
    pack0: dict[str, bytes],
    pack1: dict[str, bytes],
    defs0: dict[str, bytes],
    defs1: dict[str, bytes],
) -> list[str]:
    notes: list[str] = []
    for ch in ORDER:
        for frame, pack, defs in ((0, pack0, defs0), (1, pack1, defs1)):
            if ch in pack:
                continue
            tag = f"#{ch}{frame}"
            if ch == "W":
                notes.append(f"{tag} patched from b")
            elif ch == "X":
                src = "." if frame == 0 else "bank0 X"
                notes.append(f"{tag} patched from {src}")
            elif ch in defs:
                notes.append(f"{tag} patched from {DEFCHARS.name}")
            elif frame == 1 and (ch in pack0 or ch in defs0):
                notes.append(f"{tag} copied from bank0")
            else:
                notes.append(f"{tag} patched as blank")
    return notes


def emit_bank(name: str, bank: dict[str, bytes], bank0: dict[str, bytes], frame: int) -> list[str]:
    lines = [f"static const unsigned char {name}[TILE_COUNT][8] = {{"]
    blank = bank0.get(".", b"\x00" * 8)
    for i, ch in enumerate(ORDER):
        data = bank.get(ch) or bank0.get(ch) or blank
        comma = "," if i < len(ORDER) - 1 else ""
        lines.append(f"    {{ {hex_row(data)} }}{comma}  /* {ch}{frame} */")
    lines.append("};")
    return lines


def main(argv: list[str] | None = None) -> None:
    args = sys.argv[1:] if argv is None else argv
    if len(args) > 1:
        raise SystemExit("usage: gen-charset.py [LVL]")
    src = resolve_lvl_path(args[0] if args else None)
    if not src.is_file():
        raise SystemExit(f"LVL not found: {src}")
    if not DEFCHARS.is_file():
        raise SystemExit(f"defaults not found: {DEFCHARS}")
    defs = load_lvl(DEFCHARS, apply_aliases=False)
    pack = load_lvl(src, apply_aliases=False)
    bank0 = merge_bank(defs["bank0"], pack["bank0"])
    bank1 = merge_bank(defs["bank1"], pack["bank1"])
    alias_wx(bank0, bank1, pack["bank0"], pack["bank1"])
    for note in patch_notes(pack["bank0"], pack["bank1"], defs["bank0"], defs["bank1"]):
        print(note)
    ver = date.today().strftime("%Y%m%d")
    lines = [
        f"/* Generated from {src.name} + {DEFCHARS.name} — do not edit. */",
        "#ifndef CHARSET_H",
        "#define CHARSET_H",
        "",
        f'static const char* VERSION="v{ver}";',
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
