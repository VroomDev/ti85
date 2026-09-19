"""Compare CENGINE doseek, vic20caves seekerDir, and caveshtml dirTowardPlayer.

Wander / rand branches are omitted so the chase path is deterministic.
"""

# TI-85 / CENGINE / caveshtml key dirs (doseek and JS)
K_DOWN = 1
K_LEFT = 2
K_RIGHT = 3
K_UP = 4

# vic20caves main.c
LEFTDIR = 0
RIGHTDIR = 1
UPDIR = 2
DOWNDIR = 3

MAP_CELLS = 1024
MAP_WRAP = 1023
LEVEL_W = 32


def keyDirName(d):
    """Name a TI-85 / CENGINE / caveshtml key dir (K_DOWN=1 … K_UP=4)."""
    return {K_DOWN: "down", K_LEFT: "left", K_RIGHT: "right", K_UP: "up"}.get(d, str(d))


def cDirName(d):
    """Name a vic20caves dir (LEFTDIR=0 … DOWNDIR=3)."""
    return {LEFTDIR: "left", RIGHTDIR: "right", UPDIR: "up", DOWNDIR: "down"}.get(d, str(d))


def doseek(monster, player):
    """CENGINE.ASM doseek chase (no 25% wander).

    monster, player: 0..1023 map indexes.
    Returns K_LEFT / K_RIGHT / K_UP / K_DOWN.
    hl = (monster - player) & 1023
    < 16 -> left; >= 1024-16 -> right; < 512 -> up; else down.
    """
    diff = (monster - player) & MAP_WRAP
    if diff < 16:
        return K_LEFT
    if diff >= MAP_CELLS - 16:
        return K_RIGHT
    if diff < 512:
        return K_UP
    return K_DOWN


def seekerDir(pos, playerxy):
    """vic20caves main.c seekerDir chase (no LCG wander).

    pos, playerxy: 0..1023 map indexes.
    Returns LEFTDIR / RIGHTDIR / UPDIR / DOWNDIR.
    Same 1-D ring test as doseek; only the dir constants differ.
    """
    diff = (pos - playerxy) & MAP_WRAP
    if diff < 16:
        return LEFTDIR
    if diff >= MAP_CELLS - 16:
        return RIGHTDIR
    if diff < 512:
        return UPDIR
    return DOWNDIR


def dirTowardPlayer(monster, player, pickHoriz=True):
    """caveshtml js/engine.js dirTowardPlayer.

    monster, player: 0..1023 map indexes.
    Returns one of K_LEFT / K_RIGHT / K_UP / K_DOWN, or None if overlapping
    (JS then calls randDir4).
    2-D torus on (x = xy & 31, y = xy >> 5), wrap each axis into -16..16.
    JS: if both axes need a step, Math.random() < 0.5 ? horiz : vert.
    pickHoriz stands in for that coin flip. Always one cardinal, never a pair.
    """
    dx = (player & 31) - (monster & 31)
    dy = (player >> 5) - (monster >> 5)
    if dx > 16:
        dx -= 32
    elif dx < -16:
        dx += 32
    if dy > 16:
        dy -= 32
    elif dy < -16:
        dy += 32
    horiz = K_RIGHT if dx > 0 else K_LEFT if dx < 0 else 0
    vert = K_DOWN if dy > 0 else K_UP if dy < 0 else 0
    if horiz and vert:
        return horiz if pickHoriz else vert
    if horiz:
        return horiz
    if vert:
        return vert
    return None


def jsDirName(monster, player):
    """Print both coin-flip outcomes of dirTowardPlayer, or one name if they match."""
    a = dirTowardPlayer(monster, player, True)
    b = dirTowardPlayer(monster, player, False)
    if a is None:
        return "rand"
    if a == b:
        return keyDirName(a)
    return "%s|%s" % (keyDirName(a), keyDirName(b))


def cellXY(n):
    """Format a 0..1023 index as (x,y) on the 32-wide map."""
    return "(%2d,%2d)" % (n & 31, n >> 5)


CASES = [
    (0, 1023),
    (1023, 0),
    (0, 16),
    (16, 0),
    (16, 48),
    (48, 16),
]


def main():
    """Print player/monster cases and the dir each chase function picks."""
    hdr = "%-8s %-8s %-12s %-10s %-10s %-16s" % (
        "player",
        "monster",
        "cells",
        "doseek",
        "seekerDir",
        "dirTowardPlayer",
    )
    print(hdr)
    print("-" * len(hdr))
    for player, monster in CASES:
        cells = "%s %s" % (cellXY(player), cellXY(monster))
        print(
            "%-8d %-8d %-12s %-10s %-10s %-16s"
            % (
                player,
                monster,
                cells,
                keyDirName(doseek(monster, player)),
                cDirName(seekerDir(monster, player)),
                jsDirName(monster, player),
            )
        )


if __name__ == "__main__":
    main()
