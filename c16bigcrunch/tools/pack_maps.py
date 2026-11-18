"""Pack reference/CRUNCH.ASM level maps into ca65 MAPS bytes."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASM = ROOT / "reference" / "CRUNCH.ASM"
OUT = ROOT / "build" / "maps.inc"

# Packed nibble codes (level.s xlat)
SYM = {"0": 0, "t": 1, "b": 2, "c": 3, "Y": 4, "M": 5}
MAP_NAMES = [
    "level1map",
    "level2map",
    "level3map",
    "level4map",
    "level5map",
    "level6map",
    "level7map",
    "level8map",
]
CELLS = 128


def cells_for(label: str, text: str) -> list[int]:
    m = re.search(rf"^{re.escape(label)}:\s*(.*)$", text, re.M)
    if not m:
        raise SystemExit(f"missing {label}: in {ASM}")
    lines = [m.group(1)]
    lines.extend(text[m.end() :].splitlines())
    cells: list[int] = []
    for line in lines:
        raw = line.split(";")[0].strip()
        if not raw:
            continue
        if re.match(r"^\w+:", raw):
            break
        db = re.search(r"\.db\s+(.*)$", raw, re.I)
        if not db:
            break
        for tok in db.group(1).split(","):
            tok = tok.strip()
            if not tok:
                continue
            if tok not in SYM:
                raise SystemExit(f"{label}: unknown tile {tok!r}")
            cells.append(SYM[tok])
            if len(cells) == CELLS:
                return cells
    raise SystemExit(f"{label}: got {len(cells)} cells, want {CELLS}")


def pack(cells: list[int]) -> list[int]:
    return [(cells[i] << 4) | cells[i + 1] for i in range(0, CELLS, 2)]


def main() -> None:
    text = ASM.read_text(encoding="utf-8", errors="replace")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        ";; generated from reference/CRUNCH.ASM -- do not edit",
        "maps:",
    ]
    for name in MAP_NAMES:
        blob = pack(cells_for(name, text))
        lines.append(f"        ;; {name}")
        for i in range(0, 64, 16):
            chunk = ",".join(f"${b:02x}" for b in blob[i : i + 16])
            lines.append(f"        .byte {chunk}")
    OUT.write_text("\n".join(lines) + "\n", encoding="ascii")
    print(f"Packed 8 maps -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    sys.exit(main())
