"""Report unexpanded CHAR/MAIN holes vs assembled segment sizes.

Holes (vic20-crunch.cfg):
  MAIN     $1001–$17FF  (CODE + RODATA; EXEHDR at $1001)
  CODE2    $1A00–$1AFF  (256 bytes, then TILES)
  SFXCODE  $1BD0–$1BFF  (48 bytes, then MAPS)

Usage (from repo root):
  py -3 tools\\debug_overflow.py
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
CFG = ROOT / "vic20-crunch.cfg"
CC65 = Path(os.environ.get("USERPROFILE", "")) / "cc65" / "bin"
OBJS = [
    "loadaddr", "exehdr", "startup", "main", "gfx", "map",
    "level", "input", "player", "sound",
]

HOLES = {
    "CODE2": 256,     # $1A00–$1AFF
    "SFXCODE": 48,    # $1BD0–$1BFF
}

# #region agent log
DEBUG_LOG = ROOT / "debug-44408a.log"
DEBUG_SID = "44408a"


def _dlog(hid: str, loc: str, msg: str, data: dict) -> None:
    rec = {
        "sessionId": DEBUG_SID,
        "runId": "overflow-tool",
        "hypothesisId": hid,
        "location": loc,
        "message": msg,
        "data": data,
        "timestamp": int(time.time() * 1000),
    }
    with DEBUG_LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(rec) + "\n")
# #endregion


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["PATH"] = str(CC65) + os.pathsep + env.get("PATH", "")
    return subprocess.run(
        cmd, cwd=ROOT, capture_output=True, text=True, env=env
    )


def parse_od65(text: str) -> dict[str, int]:
    sizes: dict[str, int] = {}
    for m in re.finditer(r"^\s+(\S+):\s+(\d+)\s*$", text, re.M):
        sizes[m.group(1)] = int(m.group(2))
    return sizes


def assemble_all() -> int:
    BUILD.mkdir(exist_ok=True)
    p = run([sys.executable, str(ROOT / "tools" / "pack_maps.py")])
    if p.returncode:
        print(p.stderr or p.stdout)
        return p.returncode
    for name in OBJS:
        p = run([
            "ca65", "-t", "vic20", "-I", "src", "-I", "build",
            "-l", str(BUILD / f"{name}.lst"),
            "-o", str(BUILD / f"{name}.o"),
            str(ROOT / "src" / f"{name}.s"),
        ])
        if p.returncode:
            print(f"ca65 {name}.s failed:\n{p.stderr}")
            return p.returncode
    return 0


def main() -> int:
    if assemble_all():
        return 1

    per_obj: dict[str, dict[str, int]] = {}
    totals: dict[str, int] = {}
    for name in OBJS:
        p = run(["od65", "--dump-segsize", str(BUILD / f"{name}.o")])
        sizes = parse_od65(p.stdout)
        per_obj[name] = sizes
        for seg, n in sizes.items():
            totals[seg] = totals.get(seg, 0) + n
        # #region agent log
        _dlog("A", f"{name}.o", "od65-segsize", {"sizes": sizes})
        # #endregion

    print("Segment totals (bytes):")
    for seg in ("CODE", "RODATA", "CODE2", "CODE3", "CODE4", "SFXCODE", "TILES", "BSS"):
        if seg in totals:
            hole = HOLES.get(seg)
            extra = f"  hole={hole}  slack={hole - totals[seg]:+d}" if hole else ""
            print(f"  {seg:8} {totals[seg]:5d}{extra}")

    c2 = totals.get("CODE2", 0)
    sfx = totals.get("SFXCODE", 0)
    print()
    print("CODE2 by module:")
    for name in OBJS:
        n = per_obj[name].get("CODE2", 0)
        if n:
            print(f"  {name:8} {n:5d}")
    print(f"  {'TOTAL':8} {c2:5d} / {HOLES['CODE2']}  slack={HOLES['CODE2'] - c2:+d}")
    print()
    print("SFXCODE by module:")
    for name in OBJS:
        n = per_obj[name].get("SFXCODE", 0)
        if n:
            print(f"  {name:8} {n:5d}")
    print(f"  {'TOTAL':8} {sfx:5d} / {HOLES['SFXCODE']}  slack={HOLES['SFXCODE'] - sfx:+d}")

    p = run([
        "ld65", "-C", str(CFG), "-o", str(ROOT / "crunch.prg"),
        "-m", str(BUILD / "crunch.map"),
        *[str(BUILD / f"{n}.o") for n in OBJS],
    ])
    print()
    if p.returncode:
        print("ld65 FAILED:")
        print(p.stderr.rstrip())
    else:
        print("ld65 OK — crunch.prg")
    # #region agent log
    _dlog("B", "ld65", "link", {
        "rc": p.returncode,
        "stderr": p.stderr,
        "CODE2": c2,
        "SFXCODE": sfx,
        "CODE2_slack": HOLES["CODE2"] - c2,
        "SFXCODE_slack": HOLES["SFXCODE"] - sfx,
    })
    # #endregion
    return p.returncode


if __name__ == "__main__":
    sys.exit(main())
