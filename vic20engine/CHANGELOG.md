# Changelog

## 2026-11-11

- Optional direction-based tile drawing (`DIR_ANIMATION`) packs facing into the cell and uses it when drawing.
- Player cells are written with facing packed in (`PACKED_PLAYER`).
- Seekers occasionally veer randomly instead of always chasing.
- `rand8` / `rand16` XOR a running whitener for flatter short sequences.

## 2026-11-04

- Empty space is blue.
- A shootable brick copied from a solid brick shows one different pixel.

## 2026-11-02

- The random sequences the games actually use are more evenly balanced.

## 2026-11-01

- Picking up a key removes it from the map.
- Help appears only before a game starts, and the help picture animates.

## 2026-10-28

- The status line stays steady.
- The intro and help text are easier to follow.
- Levels can use a G tile.

## 2026-09-26

- After a long run, Scrolls switches to turbo speed.

## 2026-09-24

- The title screen says that W warps to another level, and W is the warp key.
- Rare levels show the right graphics.
