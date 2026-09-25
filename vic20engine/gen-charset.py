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


BLANK = b"\x00" * 8


def hex_row(data: bytes) -> str:
    return ", ".join(f"0x{b:02X}" for b in data)


def frames_of(
    src0: dict[str, bytes], src1: dict[str, bytes], ch: str
) -> tuple[bytes, bytes, str] | None:
    """Both frames from one source. A missing frame copies the one that exists."""
    has0 = ch in src0
    has1 = ch in src1
    if has0 and has1:
        return src0[ch], src1[ch], "both"
    if has0:
        return src0[ch], src0[ch], "from0"
    if has1:
        return src1[ch], src1[ch], "from1"
    return None


def build_banks(
    pack0: dict[str, bytes],
    pack1: dict[str, bytes],
    defs0: dict[str, bytes],
    defs1: dict[str, bytes],
) -> tuple[dict[str, bytes], dict[str, bytes], list[str]]:
    """A letter defined in the pack comes only from the pack.

    DEFCHARS supplies a letter only when the pack defines neither frame.
    W and X with no picture in either file copy b and `.`.
    """
    bank0: dict[str, bytes] = {}
    bank1: dict[str, bytes] = {}
    notes: list[str] = []
    for ch in ORDER:
        got = frames_of(pack0, pack1, ch)
        if got is not None:
            f0, f1, kind = got
            bank0[ch], bank1[ch] = f0, f1
            if kind == "from0":
                notes.append(f"#{ch}1 copied from #{ch}0")
            elif kind == "from1":
                notes.append(f"#{ch}0 copied from #{ch}1")
            continue
        got = frames_of(defs0, defs1, ch)
        if got is not None:
            f0, f1, kind = got
            bank0[ch], bank1[ch] = f0, f1
            if kind == "both":
                notes.append(f"#{ch}0 patched from {DEFCHARS.name}")
                notes.append(f"#{ch}1 patched from {DEFCHARS.name}")
            elif kind == "from0":
                notes.append(f"#{ch}0 patched from {DEFCHARS.name}")
                notes.append(f"#{ch}1 copied from #{ch}0")
            else:
                notes.append(f"#{ch}0 copied from #{ch}1")
                notes.append(f"#{ch}1 patched from {DEFCHARS.name}")
            continue
        if ch == "W" and "b" in bank0:
            bank0[ch] = bank0["b"]
            bank1[ch] = bank1["b"]
            notes.append("#W0 patched from b")
            notes.append("#W1 patched from b")
        elif ch == "X" and "." in bank0:
            bank0[ch] = bank0["."]
            bank1[ch] = bank1["."]
            notes.append("#X0 patched from .")
            notes.append("#X1 patched from .")
        else:
            bank0[ch] = BLANK
            bank1[ch] = BLANK
            notes.append(f"#{ch}0 patched as blank")
            notes.append(f"#{ch}1 patched as blank")
    return bank0, bank1, notes


def emit_bank(name: str, bank: dict[str, bytes], frame: int) -> list[str]:
    lines = [f"static const unsigned char {name}[TILE_COUNT][8] = {{"]
    for i, ch in enumerate(ORDER):
        data = bank[ch]
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
    bank0, bank1, notes = build_banks(
        pack["bank0"], pack["bank1"], defs["bank0"], defs["bank1"]
    )
    for note in notes:
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
    lines.extend(emit_bank("tile_bank0", bank0, 0))
    lines.append("")
    lines.extend(emit_bank("tile_bank1", bank1, 1))
    lines.extend(["", "#endif", ""])
    DST.write_text("\n".join(lines), encoding="utf-8")
    print("Wrote charset.h")


if __name__ == "__main__":
    main()
