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
INDEX_TAG = "HTML versions of CENGINE LVL packs — originally for the TI-85 by Chris Busch (c) 1996"

INDEX_CSS = """\
  :root {
    --ink: #0a0612;
    --cave: #14081c;
    --panel: #1c1028;
    --cyan: #6ef3ff;
    --cyan-dim: #3aa8b8;
    --yellow: #ffe566;
    --gold: #e4b000;
    --red: #ff5a6a;
    --green: #7dff9a;
    --purple: #d48cff;
    --white: #f4f0ff;
    --muted: #c4b8d8;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    color: var(--white);
    background:
      radial-gradient(ellipse at 50% -10%, #3a1848 0%, transparent 55%),
      repeating-linear-gradient(0deg, transparent 0 11px, rgba(110, 243, 255, 0.04) 11px 12px),
      var(--ink);
    font-family: "Segoe UI", Tahoma, sans-serif;
    line-height: 1.45;
  }
  .wrap {
    max-width: 46rem;
    margin: 0 auto;
    padding: 1.5rem 1rem 3rem;
  }
  header.hero {
    text-align: center;
    padding: 1.4rem 1rem 1.2rem;
    margin-bottom: 1.25rem;
    background: linear-gradient(180deg, #2a1038 0%, var(--panel) 100%);
    border: 3px solid var(--cyan);
    box-shadow: 0 0 0 4px #000, 0 0 28px rgba(110, 243, 255, 0.25);
  }
  h1 {
    margin: 0 0 0.4rem;
    color: var(--cyan);
    font-size: clamp(1.6rem, 5vw, 2.3rem);
    letter-spacing: 0.06em;
    text-shadow: 0 0 12px rgba(110, 243, 255, 0.45);
  }
  .tag {
    margin: 0;
    color: var(--yellow);
    font-weight: 600;
  }
  .lede, .card p, .card li, .keys td {
    color: var(--muted);
  }
  .lede { margin: 0 0 1.1rem; }
  .card {
    background: var(--panel);
    border: 2px solid var(--cyan-dim);
    padding: 1rem 1.1rem 1.05rem;
    margin: 0 0 1rem;
    box-shadow: 6px 6px 0 #000;
  }
  .card.story { border-color: var(--purple); }
  .card.tips { border-color: var(--green); }
  .card.play { border-color: var(--yellow); }
  h2 {
    margin: 0 0 0.65rem;
    font-size: 1.05rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }
  .story h2 { color: var(--purple); }
  .tips h2 { color: var(--green); }
  .play h2 { color: var(--yellow); }
  .hist h2 { color: var(--cyan); }
  .card p:last-child { margin-bottom: 0; }
  .tips ul, .hist ul {
    margin: 0;
    padding-left: 1.15rem;
  }
  .tips li, .hist li { margin: 0.28rem 0; }
  .tips li::marker { color: var(--green); }
  .hist li::marker { color: var(--cyan); }
  .keys {
    width: 100%;
    border-collapse: collapse;
    margin: 0.7rem 0;
    font-size: 0.92rem;
  }
  .keys th {
    text-align: left;
    color: var(--yellow);
    border-bottom: 1px solid var(--gold);
    padding: 0.35rem 0.5rem;
  }
  .keys td {
    padding: 0.38rem 0.5rem;
    border-bottom: 1px solid rgba(110, 243, 255, 0.15);
    font-family: ui-monospace, Consolas, "Courier New", monospace;
    font-size: 0.84rem;
  }
  .keys tr:nth-child(even) td { background: rgba(110, 243, 255, 0.06); }
  .keys td:first-child { color: var(--cyan); white-space: nowrap; }
  code {
    color: var(--yellow);
    background: #000;
    padding: 0.05em 0.35em;
    border-radius: 2px;
  }
  .packs { list-style: none; margin: 0; padding: 0; }
  .packs li {
    background: var(--cave);
    border: 2px solid var(--gold);
    margin: 0 0 0.85rem;
    padding: 0.85rem 0.9rem 0.7rem;
    box-shadow: 5px 5px 0 #000;
  }
  .packs li:nth-child(3n) { border-color: var(--cyan); }
  .packs li:nth-child(3n+1) { border-color: var(--red); }
  .packs li:nth-child(3n+2) { border-color: var(--purple); }
  .packs a {
    color: var(--yellow);
    font-weight: 700;
    font-family: ui-monospace, Consolas, "Courier New", monospace;
    text-decoration: none;
    margin-right: 0.45rem;
  }
  .packs a:hover { color: var(--cyan); text-decoration: underline; }
  .blurb { color: var(--muted); }
"""

META_RE = re.compile(r'^(\$[TSA])\s*=\s*"([^"]*)"', re.MULTILINE)
MAP_LINE_RE = re.compile(r"^[.csfFBStbWDkMmXP]{32}")


def link_label_from_lvl(lvl_text):
    found = dict(META_RE.findall(lvl_text.replace("\r\n", "\n").replace("\r", "\n")))
    parts = [p for p in (found.get("$T", ""), found.get("$S", ""), found.get("$A", "")) if p.strip()]
    if not parts:
        return None
    return " — ".join(html.escape(p) for p in parts)


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
        blurb = f' <span class="blurb">{meta}</span>' if meta else ""
        extra = ""
        src = txt_by_stem.get(stem)
        if src:
            dest_name = stem + ".txt"
            shutil.copy2(src, os.path.join(built_dir, dest_name))
            extra = (
                f' <a href="{html.escape(dest_name, quote=True)}">'
                f"{html.escape(os.path.basename(src))}</a>"
            )
        links.append(f"<li><a href=\"{href}\">{href}</a>{blurb}{extra}</li>")

    body = "\n      ".join(links) or "<li>No HTML pages yet.</li>"
    title = html.escape(INDEX_TITLE)
    tag = html.escape(INDEX_TAG)
    page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
{INDEX_CSS}
</style>
</head>
<body>
<div class="wrap">
  <header class="hero">
    <h1>{title}</h1>
    <p class="tag">{tag}</p>
  </header>

  <p class="lede">
    Caves was written for the TI-85 calculator. These pages are browser
    versions of the same idea: CENGINE plays out a LVL pack. Each HTML
    file is one LVL (story, maps, and pictures). The engine can play
    many different LVL files; pick any pack in the list below.
  </p>

  <section class="card story">
    <h2>Story</h2>
    <p>Because there can be many LVL packs, the story can change from one file to the next. The best-known story is this:</p>
    <p>You need to retrieve the artifact of wisdom from a deep secret world. At your disposal is a pellet gun and strong jumping legs.</p>
    <p>Beware: monsters will hurt you if they find you. If they do not get you, the fire will burn you.</p>
    <p>When you retrieve the artifact (the scroll), you travel to another land and the quest continues.</p>
  </section>

  <section class="card">
    <h2>Level packs</h2>
    <ul class="packs">
      {body}
    </ul>
  </section>

  <section class="card tips">
    <h2>Tips</h2>
    <ul>
      <li>You can only carry one key at a time. Use keys wisely.</li>
      <li>You are rewarded with extra health as your score increases.</li>
      <li>Some bricks are shootable and may reveal secret passages.</li>
      <li>Find the high jumper pad. Stand on it and press Down to soar into the air.</li>
    </ul>
  </section>

  <section class="card play">
    <h2>How to Play (laptop keyboard)</h2>
    <p>Keys can be used together. Focus the game page, then:</p>
    <table class="keys">
      <tr><th>Key</th><th>Action</th></tr>
      <tr><td>Arrows</td><td>move</td></tr>
      <tr><td>Space</td><td>jump (Up arrow also jumps)</td></tr>
      <tr><td>Down</td><td>fall faster, or bounce high on a cloud</td></tr>
      <tr><td>X, Z, or Ctrl</td><td>shoot</td></tr>
      <tr><td>P</td><td>pause (the page does not power off)</td></tr>
      <tr><td>M</td><td>overview map</td></tr>
      <tr><td>Esc Esc</td><td>leave play and return to that pack's title</td></tr>
      <tr><td>Any key</td><td>start from the title screen</td></tr>
    </table>
    <p>There is no TI-85 F1+cos cheat and no battery auto-off. High scores and three initials are stored in this browser, separately for each LVL pack.</p>
  </section>

  <section class="card hist">
    <h2>History</h2>
    <ul>
      <li><strong>v4.0:</strong> Caves saved high scores and initials (LVLs compiled by cmklvl v4.0).</li>
      <li><strong>HTML:</strong> The same CENGINE-style play runs in a browser from a standalone HTML file. No calculator, ZShell, or ROM is required.</li>
    </ul>
  </section>
</div>
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
