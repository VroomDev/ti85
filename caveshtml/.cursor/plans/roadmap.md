# Roadmap

Check items off as you go. Reorder freely.

## 0. Spec

- [x] Finish product / fidelity / controls / architecture notes
- [x] Legend: `.LVL` characters → tiles (Castle)
- [x] Confirm win/lose, scoring, extra health, hi-score rules from ASM

## 1. Skeleton

- [x] Index HTML + canvas scaled from 128-ish TI LCD
- [x] Game loop (requestAnimationFrame or fixed tick)
- [x] Keyboard map from `controls.md`

## 1b. Offline build

- [x] `build.py`: take a `.LVL`, inline CSS/JS, emit `{name}.html` with `var LVL_DATA="…"`
- [x] Runtime uses `LVL_DATA` (no `fetch` in play build); `castle.html` opens via `file://`
- [x] Document: edit split files → run build → play standalone HTML

## 2. World

- [x] Parse one `.LVL` (Castle, all 4 maps)
- [x] Draw tiles
- [x] Camera / scrolling

## 3. Player

- [ ] Move, jump (gravity, high-jumper device), shoot
- [ ] Collisions (no-erase vs eraseable vs falling)

## 4. Actors

- [ ] Monsters (seek vs patrol), spawn off-screen
- [ ] Bullet vs killable, bombs, fire, coins, keys/doors
- [ ] Blood / tree / secret shootable bricks

## 5. Meta

- [x] HUD: health, score, lives, key
- [x] Intro / story text from pack header
- [x] Pause, next level, pack complete
- [x] Hi-score (localStorage)
- [x] Crunch TunesLib sound (intro, fire, coin, hurt, new level, game over, quit)

## 6. Content

- [ ] All packs in `levels/` playable (one `build.py` run → one HTML each)
- [ ] Polish, CRT/scale options if wanted

## Notes for you to add

-
