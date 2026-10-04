# Crunch — Commodore 16

Action game by Chris Busch (1995/96). 16KB Commodore 16 port. Levels are generated mazes.

**Living spec.** Update this file whenever behavior is locked or fixed.  
**Gameplay** matches `[reference/CRUNCH.ASM](reference/CRUNCH.ASM)` except the map source: there are no packed levels and no drip spawn.

---

## Target

| Item      | Value                                            |
| --------- | ------------------------------------------------ |
| Machine   | **16KB Commodore 16** (kernal and BASIC banked in) |
| Video     | TED, 40×25. PAL and NTSC (delays are in VBlanks) |
| Language  | **6502 ca65 only** (no C)                        |
| Toolchain | `%USERPROFILE%\cc65`, config `c16-crunch.cfg`    |
| Emulator  | `%USERPROFILE%\GTK3VICE-3.10-win64\bin\xplus4.exe -model c16` |
| Build     | `build.bat` → `c16crunch.prg`                       |

After building, report free RAM from the end of BSS to `$4000`.

---

## Display

| Item       | Value |
| ---------- | ----- |
| Screen     | `$0C00` |
| Color RAM  | `$0800` |
| Charset    | RAM `$2000`. Copy ROM `$D000` first, then point TED here. |
| Code       | `$100D`–below `$2000`. Stub `$1001`, `SYS 4109`. |
| Playfield  | `$2800`, 512 bytes |
| BSS        | `$2A00` up, including the maze stack |

- `$FF13` bits 7–2 = charset A15–A10 (`$20` for `$2000`). `$FF12` bit 2 clear so TED reads RAM.
- Background `$FF15` and border `$FF19` are black.
- TED color byte: luminance in bits 6–4, chroma in bits 3–0. Bit 7 is flash; leave it clear.
- Bitmap 1 = color RAM, 0 = background. Do not mask color with `and #7`.
- Tiles `$60`–`$66` only. Never redefine A–Z. Empty = `$00` (blank glyph). Coin = ROM glyph `$51` at screen code `$1B`. Heart = ROM `$53` at `$1C`.
- Hardware cursor parked past cell 1000 so it does not cover the playfield.
- Poke screen and color RAM only in VBlank. Poll raster `$FF1D` / `$FF1C` bit 0.

### Playfield (40×25)

| | |
| --- | --- |
| Map size | **32×16** |
| Origin col | **4** |
| Origin row | **4** |

```
Col:  00    04                          35    39
Row 00 +----------------------------------------+
       | CRUNCH / (C)1996 CHRIS BUSCH / HI      |
Row 04 |    +------------------------------+    |
       |    |         32×16 playfield      |    |
Row 19 |    +------------------------------+    |
Row 21 |  S:dddd  heart  L:dd                   |
Row 24 |  DONE                                  |
       +----------------------------------------+
```

Title stays when a game starts. **CRUNCH** centered on row 0. **(C)1996 CHRIS BUSCH** centered on row 1. If hiscore ≠ 0, `HI:dddd` on row 2 at column 5. Score, lives, and level on row 21 at column 3: `S:` + 4-digit score, heart, `L:` + 2-digit level. **DONE** centered on row 24; wipe those four cells on StartLevel. **next** is four characters at screen center (row 12). The game starts on level 1.

---

## Tiles

| Entity  | Char |
| ------- | ---- |
| Empty   | `$00` |
| Tree    | `$60` |
| Brick   | `$61` |
| Coin    | `$1B` |
| Player  | `$62` |
| Wander  | `$67`–`$6A` (blit draws `$63`) |
| Chase   | `$64` |
| Bullet  | `$65` |
| Blood   | `$66` |

Maze walls are bricks. Bullets clear trees and blood. Bricks block bullets.

---

## Gameplay

1. **Player** — move on empty tiles, one cell every other frame while a direction is held. A coin scores +1 (and +1 health when the low BCD byte is `$99`). Fire in the last facing direction. Fire while held aims and does not walk.
2. **Monsters** — placed by the generator before the level starts. There is **no drip spawn** and no shared spawn cell.
3. **Bullet** — one shot (`bulletdir == 0` to fire). Steps every frame. Max **4** tiles, then the last cell is erased. No score on a hit. Killing monsters does not clear the level.
4. **Levels** — generated, 1-based, cap **99**. Last coin: erase each remaining monster, `inc_score` twice (+2, chirp each) with blit and HUD, then show **next** (do not clear the screen). Wait **39** VBlanks, then StartLevel.
5. No quit. No bomb. **SPACE = fire** (same as **K**).

### Controls

| Action   | Key                |
| -------- | ------------------ |
| Up       | **I**              |
| Left     | **J**              |
| Down     | **M**              |
| Right    | **L**              |
| Fire     | **K** or **SPACE** |
| Joystick | Port 1, OR’d with the keys |

Keys are the TED matrix (`$FD30` select, `$FF` on `$FF08`, read `$FF08`). Joystick 1 is `$FF` on `$FD30`, `$FB` on `$FF08`. Active low. Title and game over wait for fire or any key, then for release.

### Monster movement

Each frame, `update_monsters` keeps going while `steps < SPOT_STEPS` (**200**) and the TED raster (`$FF1D`) is neither **123** nor **126**. Then `spot = (spot + 183) & 511`. A monster on one of those cells tries **one** tile step. The level no longer adds extra steps.

Empty dest → move. Blocked → sit. Dest is the player → hurt only if `sfx_dur == 0`. Do not walk onto coins, trees, bricks, blood, bullets, or other monsters.

| Type | Behavior |
| ---- | -------- |
| Wander `$67`–`$6A` | Walk the facing direction until blocked, then pick a new facing and sit |
| Chase `$64` | If `coinsleft > level` or (`$A5 & 16`) ≠ 0, random step. Else cardinal toward the player (longer axis; horizontal on a tie) |

Blit alternates monster glyphs `$63` and `$64` every frame. Wander stays red and chase stays purple. A bullet turns a wander into `$64`, and `$64` into blood.

---

## Maze

`load_level` builds a 32×16 maze. Wall marker from the reference generator is brick (`$61`). Open marker is empty (`$00`).

1. Seed the 8-bit LFSR with the level, or **255** if the level is 0.
2. Fill the field with bricks.
3. Depth-first carve from `(1, 1)`, step 2, same shuffle as below. The 6502 stack is not used; frames live in BSS (row, column, direction index, four shuffled dirs).
4. Seed `rng16` the same way (level, or 255; high byte 0).
5. Player: `rand512` until the cell is empty. Leave it empty.
6. Every in-bounds **empty** cell of the eight around the player becomes a coin.
7. For `i = 0; i < level; i++`: one wander, one chase, 3 coins, 3 trees, each on its own empty cell via `rand512`.

`coinsleft` is the number of coins placed (ring plus the scattered coins). A placement that finds no empty cell is skipped. Wander facing is bits 9–10 of the `rand16` value that chose the cell.

Directions `{0,1,2,3}`, offsets `DR = {-2,2,0,0}`, `DC = {0,0,-2,2}`. One `fast_rand` byte shuffles them:

- `j3 = r & 3`, swap 3 with `j3`
- `j2 = (r >> 2) & 3`; if `j2 == 3` then `j2 = 2`; swap 2 with `j2`
- `j1 = (r >> 4) & 1`, swap 1 with `j1`

A neighbor is carved only when its row is 1..14 and its column is 1..30 and it is still brick. The cell halfway between is opened first.

---

## RNG

Never store 0.

**8-bit** `fast_rand`. Boot value `$AC`. `load_level` sets it from the level before the carve. Shift right; if the old low bit was set, XOR `$B8`.

**16-bit** `rand16`. Seeded at the start of placement the same way as the 8-bit generator. Shift right; if the old low bit was set, XOR `$D008`. `rand512` is `rand16() & 511`.

The next level reseeds both, so calls during play do not change the next maze. In-game random facing uses `fast_rand`. Cell picks use `rand512`.

---

## Main loop

```
InitGraphics
Silence
hiscore = 0
lfsr = $AC

Intro:
  level = 1
  LoadLevel
  ClearScreen
  DrawTitle
  DrawHiscore
  WaitVBlank
  BlitPlayfield
  WaitJoystickFireOrKey

StartGame:
  Silence
  score = 9999 BCD
  health = 5
  level = 1

StartLevel:
  LoadLevel
  IncScore
  InitSprites          ; player only
  ClearOver
  DrawHiscore
  DrawHud
  UpdateHud
  WaitVBlank
  BlitPlayfield

GameLoop:
  UpdatePlayer
  UpdateMonsters
  UpdateBullet
  WaitVBlank
  BlitPlayfield
  UpdateHud
  PlayAudioFrame
  if GAMEOVER:  CheckHiscore; DrawGameOver; wait 60 jiffies; WaitJoystickFireOrKey; goto Intro
  if NEXTLEVEL: DrawNewLevel; wait 39 VBlanks; level++ (cap 99); goto StartLevel
  goto GameLoop
```

---

## Audio

Three TED cues. Coin = voice 1 tone (`$FF0E` / `$FF11`). Kill = voice 2 noise. Hurt = voice 1 low tone. Silence clears `$FF11` and the frequency registers. Do not zero `$FF12` (charset select lives there). No intro song. No next-level sound.

---

## Repo

```text
reference/     Z80 originals (read-only gameplay)
src/           ca65 port
SPEC.md        this file
build.bat      → c16crunch.prg
```

---

## Build / run

```bat
build.bat
run.bat
```

`run.bat` starts `xplus4 -model c16 -autostart c16crunch.prg`.

Free RAM is the bytes from the first address after BSS through `$3FFF`. Charset `$2000`–`$27FF` and the playfield `$2800`–`$29FF` are reserved and are not part of that count. This build: **4833 bytes** (`$2D1F`–`$3FFF`).
