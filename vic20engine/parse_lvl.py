"""Parse a CENGINE .LVL pack: 32×32 maps and #X0/#X1 8×8 pics."""
from __future__ import annotations

import re
from pathlib import Path

ORDER = [".", "P", "s", "f", "S", "k", "M", "m", "F", "B", "t", "b", "D", "c", "W", "X"]
MAP_SIZE = 32
MAP_CHARS = frozenset(ORDER)
HEADER_RE = re.compile(r"^#(.)([01])")
BITS_RE = re.compile(r"^([01]{8})")
KV_RE = re.compile(r'^(\$[TASP])\s*=\s*"([^"]*)"')
NLEV_RE = re.compile(r"^(\d+)\s*;\s*number of levels", re.I)


def _is_map_row(body: str) -> str | None:
    if len(body) < MAP_SIZE:
        return None
    row = body[:MAP_SIZE]
    if all(ch in MAP_CHARS for ch in row):
        return row
    return None


def parse_lvl(text: str, apply_aliases: bool = True) -> dict:
    maps: list[list[str]] = []
    current: list[str] = []
    bank0: dict[str, bytes] = {}
    bank1: dict[str, bytes] = {}
    meta = {
        "title": "",
        "story": "",
        "author": "",
        "zshell": "",
        "hiscorePrompt": "",
        "levelCount": 0,
    }
    kv_map = {"$T": "zshell", "$S": "story", "$A": "author", "$P": "hiscorePrompt"}
    glyph_id: str | None = None
    frame = 0
    rows: list[int] = []
    seen_map = False
    title_locked = False

    def flush_glyph() -> None:
        nonlocal glyph_id, rows
        if glyph_id is None or not rows:
            return
        data = bytes(rows[:8]).ljust(8, b"\x00")
        if frame == 0:
            bank0[glyph_id] = data
        else:
            bank1[glyph_id] = data
        rows = []
        glyph_id = None

    def flush_map() -> None:
        nonlocal current
        if len(current) == MAP_SIZE:
            maps.append(current)
        current = []

    for raw in text.splitlines():
        trimmed = raw.strip()
        body = raw.split(";", 1)[0].rstrip("\n")

        if glyph_id is not None:
            bits = BITS_RE.match(trimmed.split(";", 1)[0].strip())
            if bits:
                rows.append(int(bits.group(1), 2))
                if len(rows) >= 8:
                    flush_glyph()
                continue
            if trimmed.startswith("#"):
                flush_glyph()
            elif not trimmed or trimmed.startswith(";"):
                continue
            else:
                flush_glyph()

        header = HEADER_RE.match(trimmed)
        if header:
            flush_map()
            seen_map = True
            glyph_id = header.group(1)
            frame = int(header.group(2))
            rows = []
            continue

        kv = KV_RE.match(trimmed)
        if kv:
            meta[kv_map[kv[1]]] = kv.group(2)
            continue

        if not seen_map and not title_locked:
            if trimmed and not trimmed.startswith(";") and not trimmed.startswith("$") and not NLEV_RE.match(trimmed):
                meta["title"] = trimmed
                title_locked = True

        nlev = NLEV_RE.match(trimmed)
        if nlev:
            meta["levelCount"] = int(nlev.group(1))
            continue

        row = _is_map_row(body.lstrip())
        if row is not None:
            seen_map = True
            current.append(row)
            if len(current) == MAP_SIZE:
                flush_map()
        elif current and not trimmed:
            continue
        elif current:
            flush_map()

    flush_glyph()
    flush_map()

    if apply_aliases:
        if "W" not in bank0 and "b" in bank0:
            bank0["W"] = bank0["b"]
        if "W" not in bank1:
            bank1["W"] = bank1.get("b", bank0.get("W", b"\x00" * 8))
        if "X" not in bank0 and "." in bank0:
            bank0["X"] = bank0["."]
        if "X" not in bank1:
            bank1["X"] = bank0.get("X", b"\x00" * 8)

    if not meta["levelCount"]:
        meta["levelCount"] = len(maps)

    return {"meta": meta, "maps": maps, "bank0": bank0, "bank1": bank1}


DEFAULT_LVL_NAME = "CASTLE.LVL"


def resolve_lvl_path(arg: str | None = None) -> Path:
    p = Path(arg) if arg else Path(DEFAULT_LVL_NAME)
    if not p.is_absolute():
        p = Path.cwd() / p
    return p


def load_lvl(path: Path, apply_aliases: bool = True) -> dict:
    return parse_lvl(path.read_text(encoding="utf-8"), apply_aliases=apply_aliases)
