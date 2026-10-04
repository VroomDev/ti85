"""Assemble the C16 build and print bytes free from the end of BSS to $4000.

Usage (from repo root):
  py -3 tools\\debug_overflow.py
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
CFG = ROOT / "c16-crunch.cfg"
CC65 = Path(os.environ.get("USERPROFILE", "")) / "cc65" / "bin"
OBJS = [
    "loadaddr", "exehdr", "startup", "main", "gfx", "map",
    "level", "input", "player", "sound",
]


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["PATH"] = str(CC65) + os.pathsep + env.get("PATH", "")
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, env=env)


def main() -> int:
    BUILD.mkdir(exist_ok=True)
    for name in OBJS:
        p = run([
            "ca65", "-t", "c16", "-I", "src", "-I", "build",
            "-o", str(BUILD / f"{name}.o"),
            str(ROOT / "src" / f"{name}.s"),
        ])
        if p.returncode:
            print(f"ca65 {name}.s failed:\n{p.stderr}")
            return p.returncode
    p = run([
        "ld65", "-C", str(CFG), "-o", str(ROOT / "c16crunch.prg"),
        "-m", str(BUILD / "crunch.map"),
        *[str(BUILD / f"{n}.o") for n in OBJS],
    ])
    if p.returncode:
        print("ld65 FAILED:")
        print(p.stderr.rstrip())
        return p.returncode
    text = (BUILD / "crunch.map").read_text(encoding="utf-8", errors="replace")
    m = re.search(r"^BSS\s+([0-9A-Fa-f]+)\s+([0-9A-Fa-f]+)", text, re.M)
    if not m:
        print("ld65 OK — c16crunch.prg")
        print("BSS not found in build/crunch.map")
        return 0
    end = int(m.group(1), 16) + int(m.group(2), 16)
    print("ld65 OK — c16crunch.prg")
    print(f"Free RAM: {0x4000 - end} bytes (${end:04X} to $4000)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
