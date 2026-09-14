#!/usr/bin/env python3
"""Build every .LVL matching LVL_GLOB, then write built/index.html."""

import glob
import html
import os
import re
import shutil
import sys
from pathlib import Path

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build import build  # noqa: E402

# Edit these.
LVL_GLOB = os.path.join(HERE, "..", "clvl", "*.LVL")
TXT_GLOB = os.path.join(HERE, "..", "clvl", "*.TXT")
INDEX_TITLE = "Caves Levels as HTML Games."

ABOUT_TEXT = """\
                               Caves
                     HTML versions of CENGINE LVL packs


Caves was written for the TI-85 calculator. These pages are browser
versions of the same idea: CENGINE plays out a LVL pack. Each HTML
file is one LVL (story, maps, and pictures). The engine can play
many different LVL files; pick any pack in the list below.

o Story:

Because there can be many LVL packs, the story can change from one
file to the next. The best-known story is this:

You need to retrieve the artifact of wisdom from a deep secret world.
At your disposal is a pellet gun and strong jumping legs.

Beware: monsters will hurt you if they find you. If they do not get
you, the fire will burn you.

When you retrieve the artifact (the scroll), you travel to another
land and the quest continues.

o Tips:

  . You can only carry one key at a time. Use keys wisely.
  . You are rewarded with extra health as your score increases.
  . Some bricks are shootable and may reveal secret passages.
  . Find the high jumper pad. Stand on it and press Down to
    soar into the air.

o How to Play (laptop keyboard):

Keys can be used together. Focus the game page, then:

  Arrows     move
  Space      jump (Up arrow also jumps)
  Down       fall faster, or bounce high on a cloud
  X, Z, or Ctrl   shoot
  P          pause (the page does not power off)
  M          overview map
  Esc Esc    leave play and return to that pack's title
  Any key    start from the title screen

There is no TI-85 F1+cos cheat and no battery auto-off. High scores
and three initials are stored in this browser, separately for each
LVL pack.

o History:

     v4.0: Caves saved high scores and initials (LVLs compiled by
           cmklvl v4.0).
     HTML: The same CENGINE-style play runs in a browser from a
           standalone HTML file. No calculator, ZShell, or ROM is
           required.
"""

META_RE = re.compile(r'^(\$[TSA])\s*=\s*"([^"]*)"', re.MULTILINE)
MAP_LINE_RE = re.compile(r"^[.csfFBStbWDkMmXP]{32}")


def link_label_from_lvl(lvl_text):
    found = dict(META_RE.findall(lvl_text.replace("\r\n", "\n").replace("\r", "\n")))
    parts = [found.get("$T", ""), found.get("$S", ""), found.get("$A", "")]
    if not any(p.strip() for p in parts):
        return None
    return " &nbsp; ".join(html.escape(p) for p in parts)


def extract_maps(lvl_text):
    maps = []
    current = []
    for raw in lvl_text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        trimmed = raw.strip()
        body = raw.split(";")[0]
        m = MAP_LINE_RE.match(body)
        if m:
            current.append(m.group(0)[:32])
            if len(current) == 32:
                maps.append(current)
                current = []
        elif current and len(current) < 32 and not trimmed:
            continue
        elif current and len(current) < 32:
            current = []
    return maps


def warn_keys_doors(lvl_path, lvl_text):
    name = os.path.basename(lvl_path)
    for i, rows in enumerate(extract_maps(lvl_text), 1):
        grid = "".join(rows)
        keys = grid.count("k")
        doors = grid.count("D")
        if keys != doors:
            print(
                f"warning: {name} level {i}: {keys} keys, {doors} doors (mismatched)"
            )


def main():
    files = sorted(glob.glob(LVL_GLOB))
    if not files:
        print("no files matched", LVL_GLOB)
        return 1

    txt_by_stem = {}
    label_by_stem = {}
    for t in glob.glob(TXT_GLOB):
        txt_by_stem[os.path.splitext(os.path.basename(t))[0].lower()] = t

    for f in files:
        print("building", f)
        build(Path(f))
        stem = os.path.splitext(os.path.basename(f))[0].lower()
        lvl_text = Path(f).read_text(encoding="utf-8", errors="replace")
        warn_keys_doors(f, lvl_text)
        label = link_label_from_lvl(lvl_text)
        if label:
            label_by_stem[stem] = label
        for ext in (".TXT", ".txt"):
            cand = os.path.splitext(f)[0] + ext
            if os.path.isfile(cand):
                txt_by_stem[stem] = cand
                break

    built_dir = os.path.join(HERE, "built")
    os.makedirs(built_dir, exist_ok=True)

    links = []
    for name in sorted(os.listdir(built_dir)):
        if not name.lower().endswith(".html"):
            continue
        if name.lower() == "index.html":
            continue
        href = html.escape(name, quote=True)
        stem = os.path.splitext(name)[0].lower()
        meta = label_by_stem.get(stem, "")
        extra = ""
        src = txt_by_stem.get(stem)
        if src:
            dest_name = stem + ".txt"
            shutil.copy2(src, os.path.join(built_dir, dest_name))
            extra = (
                f' <a href="{html.escape(dest_name, quote=True)}">'
                f"{html.escape(os.path.basename(src))}</a>"
            )
        links.append(f'<li><a href="{href}">{href}</a> {meta} {extra}</li>')

    body = "\n".join(links) or "<li>No HTML pages yet.</li>"
    title = html.escape(INDEX_TITLE)
    about = html.escape(ABOUT_TEXT)
    page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
<style>
body {{ font-family: "Segoe UI", Tahoma, sans-serif; max-width: 44rem; margin: 1.5rem auto; padding: 0 1rem; }}
pre.about {{ white-space: pre-wrap; font-family: ui-monospace, Consolas, "Courier New", monospace; font-size: 0.85rem; }}
</style>
</head>
<body>
<h1>{title}</h1>
<pre class="about">{about}</pre>
<ul>
{body}
</ul>
</body>
</html>
"""
    index = os.path.join(built_dir, "index.html")
    with open(index, "w", encoding="utf-8", newline="\n") as out:
        out.write(page)
    print("wrote", index)
    return 0


if __name__ == "__main__":
    sys.exit(main())
