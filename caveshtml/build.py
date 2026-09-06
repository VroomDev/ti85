#!/usr/bin/env python3
"""Build a standalone Caves HTML from split sources + a .LVL pack.

Usage:
  python build.py levels/CASTLE.LVL

Writes castle.html (basename of the .LVL, lowercased) next to this script.
No web server needed — open the HTML in a browser.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

# Dependency order for flattening ES modules into one classic script.
JS_FILES = [
    "js/tiles.js",
    "js/lvl.js",
    "js/input.js",
    "js/tunes.js",
    "js/engine.js",
    "js/render.js",
    "js/main.js",
]

IMPORT_RE = re.compile(
    r"^\s*import\s+(?:type\s+)?(?:[\s\S]*?)\s+from\s*['\"][^'\"]+['\"]\s*;?\s*\n?",
    re.MULTILINE,
)
EXPORT_BLOCK_RE = re.compile(r"^\s*export\s*\{[^}]*\}\s*;?\s*\n?", re.MULTILINE)
EXPORT_KW_RE = re.compile(
    r"^export\s+(?=async\s+function|function|const|let|var|class)",
    re.MULTILINE,
)


def strip_modules(src: str) -> str:
    src = IMPORT_RE.sub("", src)
    src = EXPORT_BLOCK_RE.sub("", src)
    src = EXPORT_KW_RE.sub("", src)
    src = re.sub(r"^export\s+default\s+", "", src, flags=re.MULTILINE)
    return src


def bundle_js() -> str:
    parts = []
    for rel in JS_FILES:
        path = ROOT / rel
        if not path.is_file():
            raise SystemExit(f"missing source: {path}")
        parts.append(f"/* ---- {rel} ---- */\n{strip_modules(path.read_text(encoding='utf-8'))}")
    return "\n\n".join(parts)


def js_string_literal(text: str) -> str:
    """Embed text as a JS string literal (JSON encoding is valid in JS)."""
    return json.dumps(text, ensure_ascii=False)


def build(lvl_path: Path, out_path: Path | None = None) -> Path:
    lvl_path = lvl_path.resolve()
    if not lvl_path.is_file():
        raise SystemExit(f"LVL not found: {lvl_path}")

    css = (ROOT / "caves.css").read_text(encoding="utf-8")
    lvl_text = lvl_path.read_text(encoding="utf-8")
    js = bundle_js()

    name = lvl_path.stem.lower()
    title = f"Caves — {lvl_path.stem.title()}"
    if out_path is None:
        out_path = ROOT / f"{name}.html"

    html = f"""<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    <style>
{css}
    </style>
  </head>
  <body>
    <div id="app">
      <header>
        <p id="story"></p>
      </header>
      <div id="stage">
        <canvas id="game" width="128" height="64" aria-label="Caves playfield"></canvas>
        <div id="overlay"></div>
      </div>
      <p id="help"></p>
    </div>
    <script>
var LVL_NAME = {js_string_literal(name)};
var LVL_DATA = {js_string_literal(lvl_text)};
    </script>
    <script>
{js}
    </script>
  </body>
</html>
"""
    out_path.write_text(html, encoding="utf-8", newline="\n")
    return out_path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build standalone Caves HTML from a .LVL pack.")
    parser.add_argument(
        "lvl",
        nargs="?",
        default=str(ROOT / "levels" / "CASTLE.LVL"),
        help="path to .LVL (default: levels/CASTLE.LVL)",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="output HTML path (default: <lvl-stem>.html in project root)",
    )
    args = parser.parse_args(argv)
    out = Path(args.output) if args.output else None
    written = build(Path(args.lvl), out)
    print(f"wrote {written}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
