"""Check Caves .LVL maps.

A map is a contiguous 32x32 block. Blocks are separated only by blank
lines, comment lines, or $ header lines. A short row stays in its block.
A row with an invalid character stays in its block and is reported.
Graphics (#...) end the map section.
"""

from __future__ import print_function

import glob
import os
import sys
from collections import Counter

TILES = set(".PMmcsfFBStbDkWX")
NEED = 32
RULER = "    |" + "".join(str(i % 10) for i in range(1, NEED + 1)) + "|"


def map_body(line):
    return line.split(";", 1)[0].rstrip("\n").rstrip()


def is_map_row(body):
    return bool(body) and all(c in TILES for c in body)


def mostly_tiles(body):
    good = sum(c in TILES for c in body)
    return good > 0 and good * 2 >= len(body)


def keep_map_row(body, in_map):
    """Keep a broken map row so its invalid characters get reported."""
    if not body:
        return False
    if is_map_row(body):
        return True
    if in_map:
        return True
    return len(body) >= 16 and mostly_tiles(body)


def invalid_chars(row):
    """Non-tile characters other than space (spaces have their own check)."""
    return [(i, c) for i, c in enumerate(row) if c not in TILES and c != " "]


def parse_maps(path):
    text = open(path, encoding="utf-8").read().splitlines()
    maps = []
    cur = []
    graphics = None
    declared_line = None
    declared = None

    def flush():
        if cur:
            maps.append(list(cur))
            cur[:] = []

    for i, line in enumerate(text, 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            graphics = i
            flush()
            break

        if declared is None and ";" in line:
            left, right = line.split(";", 1)
            if left.strip().isdigit() and "number of levels" in right.lower():
                declared = int(left.strip())
                declared_line = i
                flush()
                continue

        if (
            not stripped
            or stripped.startswith(";")
            or stripped.startswith("$")
        ):
            flush()
            continue

        body = map_body(line)
        if keep_map_row(body, bool(cur)):
            cur.append((i, body, line.rstrip("\n")))
        else:
            flush()

    flush()
    return {
        "declared": declared,
        "declared_line": declared_line,
        "maps": maps,
        "graphics": graphics,
        "title": text[0].strip() if text else "",
    }


def show_row(ln, row):
    n = len(row)
    if n < NEED:
        kind = "SHORT  missing %d" % (NEED - n)
    elif n > NEED:
        kind = "LONG   extra %d" % (n - NEED)
    else:
        kind = "32 cols"
    print("    line %d  %s" % (ln, kind))
    print("    |%s|" % row)
    print(RULER)
    if n < NEED:
        print("    |" + ("-" * n) + "^")
    elif n > NEED:
        print("    |" + ("-" * NEED) + "^")


def short_lines(maps):
    found = []
    for mi, m in enumerate(maps, 1):
        for row_i, (ln, row, _full) in enumerate(m, 1):
            n = len(row)
            if n != NEED:
                found.append((mi, row_i, ln, row, n))
    return found


def bad_letters(maps):
    found = []
    for mi, m in enumerate(maps, 1):
        for row_i, (ln, row, _full) in enumerate(m, 1):
            cols = invalid_chars(row)
            if cols:
                found.append((mi, row_i, ln, row, cols))
    return found


def caret_line(row, indexes):
    marks = [" "] * len(row)
    for i in indexes:
        if 0 <= i < len(marks):
            marks[i] = "^"
    return "    |" + "".join(marks)


def print_bad_letters(found):
    if not found:
        print("  invalid characters: none")
        print()
        return
    count = sum(len(cols) for _mi, _row_i, _ln, _row, cols in found)
    print("  INVALID CHARACTERS  %d" % count)
    for mi, row_i, ln, row, cols in found:
        where = ", ".join("col %d '%s'" % (i + 1, c) for i, c in cols)
        print(
            "    block %d row %d  file line %d  %s"
            % (mi, row_i, ln, where)
        )
        print("    |%s|" % row)
        print(caret_line(row, [i for i, _c in cols]))
    print()


def print_short_lines(found):
    if not found:
        print("  short lines: none (every map row is %d cols)" % NEED)
        print()
        return
    print("  SHORT LINES  %d (need %d cols each)" % (len(found), NEED))
    print(RULER)
    for mi, row_i, ln, row, n in found:
        delta = NEED - n
        if delta > 0:
            extra = "missing %d" % delta
        else:
            extra = "extra %d" % (-delta)
        print(
            "    block %d row %d  file line %d  %d cols  %s"
            % (mi, row_i, ln, n, extra)
        )
        print("    |%s|" % row)
        if n < NEED:
            print("    |" + ("-" * n) + "^")
        else:
            print("    |" + ("-" * NEED) + "^")
    print()


def check_block(mi, m):
    issues = []
    first_ln = m[0][0]
    last_ln = m[-1][0]
    widths = [len(row) for _ln, row, _full in m]
    wmin = min(widths)
    wmax = max(widths)
    size_ok = len(m) == NEED and wmin == NEED and wmax == NEED

    print("-" * 72)
    print(
        "map block %d   file lines %d-%d   %d rows   width %s"
        % (
            mi,
            first_ln,
            last_ln,
            len(m),
            str(wmin) if wmin == wmax else "%d-%d" % (wmin, wmax),
        )
    )
    print("  first |%s|" % m[0][1])
    print("  last  |%s|" % m[-1][1])

    if len(m) != NEED:
        msg = "%d rows (need %d)" % (len(m), NEED)
        print("  FAIL  %s" % msg)
        issues.append(msg)

    grid = []
    for ln, row, full in m:
        if " " in row:
            msg = "line %d has a space" % ln
            print("  FAIL  %s" % msg)
            show_row(ln, row)
            issues.append(msg)
        if len(row) != NEED:
            if len(row) < NEED:
                print(
                    "  SHORT line %d is %d cols (missing %d)"
                    % (ln, len(row), NEED - len(row))
                )
            else:
                print(
                    "  LONG  line %d is %d cols (extra %d)"
                    % (ln, len(row), len(row) - NEED)
                )
            show_row(ln, row)
        body = map_body(full)
        if len(body) > NEED and body[NEED:].strip():
            print("  NOTE  line %d chars after col %d: |%s|" % (ln, NEED, body[NEED:]))
        bad = invalid_chars(row)
        if bad:
            where = ", ".join("col %d '%s'" % (i + 1, c) for i, c in bad)
            kind = "character" if len(bad) == 1 else "characters"
            msg = "line %d invalid %s %s" % (ln, kind, where)
            print("  FAIL  %s" % msg)
            print("    |%s|" % row)
            print(caret_line(row, [i for i, _c in bad]))
            issues.append(msg)
        grid.append(row)

    items = Counter("".join(grid))
    bits = "  tiles "
    for k in "XsDkWbBcfmFMtP":
        if items[k]:
            bits += " %s=%d" % (k, items[k])
    print(bits if items else "  tiles  (empty)")

    if items["X"] != 1:
        msg = "X start count %d (need 1)" % items["X"]
        print("  FAIL  %s" % msg)
        issues.append(msg)
    if items["s"] != 1:
        msg = "scroll s count %d (need 1)" % items["s"]
        print("  FAIL  %s" % msg)
        issues.append(msg)
    if items["D"] != items["k"]:
        msg = "doors D=%d keys k=%d" % (items["D"], items["k"])
        print("  FAIL  %s" % msg)
        issues.append(msg)

    if size_ok and not issues:
        print("  OK    32x32")
    elif size_ok:
        print("  FAIL  32x32 layout ok, tile counts not")
    print()
    return ["block %d: %s" % (mi, msg) for msg in issues]


def expand_paths(args, here):
    if not args:
        return [os.path.join(here, "CASTLE.LVL")]
    paths = []
    seen = set()
    for arg in args:
        matches = glob.glob(arg)
        if not matches and os.path.isfile(arg):
            matches = [arg]
        if not matches:
            print("no files match:", arg)
            continue
        for path in sorted(matches):
            key = os.path.normcase(os.path.abspath(path))
            if key in seen:
                continue
            seen.add(key)
            paths.append(path)
    return paths


def check_file(path):
    info = parse_maps(path)
    maps = info["maps"]
    issues = []
    print("=" * 72)
    print(os.path.basename(path))
    print("  path     %s" % path)
    if info["title"]:
        print("  title    %s" % info["title"])
    if info["declared"] is None:
        print("  declared (no 'N ;number of levels' line)")
        issues.append("missing number-of-levels line")
    else:
        print(
            "  declared %d levels (file line %d)"
            % (info["declared"], info["declared_line"])
        )
        if info["declared"] not in (1, 2, 4, 8):
            msg = "declared %d (cmklvl wants 1, 2, 4, or 8)" % info["declared"]
            print("  FAIL     %s" % msg)
            issues.append(msg)
    print("  found    %d contiguous map blocks" % len(maps))
    if info["graphics"]:
        print("  graphics start at file line %d (maps stop here)" % info["graphics"])
    else:
        print("  graphics (none in this file)")
    if info["declared"] is not None and info["declared"] != len(maps):
        msg = "declared %d levels but found %d map blocks" % (
            info["declared"],
            len(maps),
        )
        print("  FAIL     %s" % msg)
        issues.append(msg)
    print()
    print("  Blocks are split only on blank, comment, or $ lines.")
    print("  A row shorter than 32 stays in the same block.")
    print("  A row with an invalid character stays in the same block.")
    print()
    letters = bad_letters(maps)
    print_bad_letters(letters)
    shorts = short_lines(maps)
    print_short_lines(shorts)
    for mi, row_i, ln, row, n in shorts:
        if n < NEED:
            issues.append(
                "SHORT line %d (block %d row %d): %d cols, missing %d"
                % (ln, mi, row_i, n, NEED - n)
            )
        else:
            issues.append(
                "LONG line %d (block %d row %d): %d cols, extra %d"
                % (ln, mi, row_i, n, n - NEED)
            )

    for mi, m in enumerate(maps, 1):
        issues.extend(check_block(mi, m))
    return issues


def main(argv):
    here = os.path.dirname(os.path.abspath(__file__))
    paths = expand_paths(argv[1:], here)
    if not paths:
        return 1
    failed = []
    for i, path in enumerate(paths):
        if i:
            print()
        issues = check_file(path)
        if issues:
            failed.append((path, issues))
    print("=" * 72)
    print("checked %d file(s)" % len(paths))
    if not failed:
        print("all ok")
        return 0
    print("issues:")
    for path, issues in failed:
        print("  %s" % os.path.basename(path))
        for msg in issues:
            print("    %s" % msg)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
