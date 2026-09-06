#!/usr/bin/env python3
"""Build every .LVL matching LVL_GLOB, then write built/index.html."""

import glob
import html
import os
import sys
from pathlib import Path

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build import build  # noqa: E402

# Edit these.
LVL_GLOB = os.path.join(HERE, "..", "clvl", "*.LVL")
INDEX_TITLE = "Caves Levels as HTML Games."


def main():
    files = sorted(glob.glob(LVL_GLOB))
    if not files:
        print("no files matched", LVL_GLOB)
        return 1

    for f in files:
        print("building", f)
        build(Path(f))

    built_dir = os.path.join(HERE, "built")
    os.makedirs(built_dir, exist_ok=True)

    links = []
    for name in sorted(os.listdir(built_dir)):
        if not name.lower().endswith(".html"):
            continue
        if name.lower() == "index.html":
            continue
        href = html.escape(name, quote=True)
        label = html.escape(os.path.splitext(name)[0])
        links.append(f'<li><a href="{href}">{label}</a></li>')

    body = "\n".join(links) or "<li>No HTML pages yet.</li>"
    title = html.escape(INDEX_TITLE)
    page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
</head>
<body>
<h1>{title}</h1>
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
