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
| Build     | `build.bat` → `c16crunch.prg`. Writes `src/version.s` (`VERSION`, screen codes `v` + `YYYYMMDD`) before assembling. |

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
- Tiles `$60`–`$66` only. Never redefine A–Z. Empty = `$00` (blank glyph). Coin is screen code `$1B`, two editable bitmaps that start as the PETSCII filled circle. Heart = ROM `$53` at `$1C`.
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
       | C16 CRUNCH / (C)1996 CHRIS BUSCH       |
Row 04 |    +------------------------------+    |
       |    |         32×16 playfield      |    |
Row 19 |    +------------------------------+    |
Row 21 |    S:dddd  heart  L:dd    HI:dddd      |
Row 24 |  DONE                                  |
       +----------------------------------------+
```

Title stays when a game starts. **C16 CRUNCH** centered on row 0. **(C)1996 CHRIS BUSCH** centered on row 1. On the first intro only, row 21 centers `vYYYYMMDD` (column 15), the build date from `src/version.s`. StartLevel clears those nine cells and draws the score line. Later intros leave that row blank except the high score. Score, lives, level, and high score are centered on row 21: `S:` at column 5, then the 4-digit score, heart, `L:` + 2-digit level, and `HI:dddd` at column 28, including when the high score is 0. **DONE** centered on row 24; wipe those four cells on StartLevel. **next** is four characters at screen center (row 12). The game starts on level 1.

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

1. **Player** — the cell is a 9-bit index. Up and down add `-PF_COLS` and `PF_COLS`. Left and right add −1 and +1. The sum is masked with 511. Move onto an empty cell or blood, one step every other frame while a direction is held. Stepping on blood removes the splat. A coin scores +1. Health increases by 1 when the last two score digits are 49 or 99, unless health is already 9. Fire in the last facing direction. Fire while held aims and does not walk.
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
| Joystick | Either port, OR’d with the keys |
| Code    | **C** shows **?** at column 0 of row 24 and stays armed for the rest of the game. **B** then sets the score to 0 and takes the normal next-level path, once per press |

Keys are the TED matrix (`$FD30` select, `$FF` on `$FF08`, read `$FF08`). Joysticks are `$FF` on `$FD30`, then `$FB` (port 1, fire bit 6) or `$FD` (port 2, fire bit 7) on `$FF08`. Active low. Title and game over wait for fire or any key, then for release.

### Monster movement

Each frame, `update_monsters` keeps going while `steps < SPOT_STEPS` (**200**) and the TED raster (`$FF1D`) is neither **123** nor **126**. Then `spot = (spot + 183) & 511`. A monster on one of those cells tries **one** tile step, the same index add as the player. The bullet uses that add too. The level no longer adds extra steps.

Empty dest → move. Blocked → sit, except a chase monster then tries one random direction. Dest is the player → hurt only if `hurt_dur == 0`. A hurt sets `hurt_dur` to `HURT_PERIOD` (10). Each game cycle decrements it while it is nonzero. While it is nonzero the player is drawn purple. Do not walk onto coins, trees, bricks, blood, bullets, or other monsters. The mask wraps at 512. The maze frame is brick, so a step off the board is blocked.

| Type | Behavior |
| ---- | -------- |
| Wander `$67`–`$6A` | Walk the facing direction until blocked, then pick a new facing and sit |
| Chase `$64` | `diff = (spot − player) & 1023`. `diff < 16` → left. `diff ≥ 1008` → right. `diff < 512` → up. Otherwise down. If that step is blocked by anything other than the player, try one random direction |

Each tile `$60`–`$66` has two bitmaps. The two brick bitmaps are identical. The coin at `$1B` has two bitmaps, `coin` and `coin1`, both the PETSCII filled circle. `blit_playfield` increments `frame` and installs `tiles1` and `coin1` when `frame & 64` is set, otherwise `tiles` and `coin`. Wander is drawn as `$63` in red and chase stays `$64` in purple. A bullet turns a wander into `$64`, and `$64` into blood.

---

## Maze

`load_level` builds a 32×16 maze. Wall marker from the reference generator is brick (`$61`). Open marker is empty (`$00`).

1. Seed the 8-bit LFSR with the level, or **255** if the level is 0. When the level is greater than 98, leave the LFSR as it is.
2. Fill the field with bricks.
3. Depth-first carve from `(1, 1)`, step 2, same shuffle as below. The 6502 stack is not used; frames live in BSS (row, column, direction index, four shuffled dirs).
4. Seed `rng16` the same way (level, or 255; high byte 0). Advance `rand16` **16** times before the player search draws its cell.
5. Player starts at column 16, row 7 (index 240). That cell stays empty.
6. Every in-bounds **empty** cell of the eight around the player becomes a coin.
7. For `i = 0; i < level; i++`: two wanders, two chases, and 3 coins. Each of those uses one `rand512`, then up to 8 cells to the right. A placement that finds no empty cell is skipped. Each pass also draws `r = rand16 & 511` and, when that cell is brick, stores a tree there.
8. `place_space` punches **level << 2** hallways. When `level` is greater than 60, it punches 60. Each one draws one `rand512` and steps right with `(index + 1) & 511` until a brick with an empty cell above or to the left. One full lap (512 cells) with no such brick skips that hallway. Empty above: punch down (`+ PF_COLS`, then `& 511`) through bricks until the next empty cell. Empty to the left: punch right (`+ 1`, then `& 511`) the same way. If both, punch down. The empty cell on the far side stays empty.

`coinsleft` is the number of coins placed (ring plus the scattered coins). Wander facing is bits 9–10 of the `rand16` value that chose the cell.

Directions `{0,1,2,3}`, offsets `DR = {-2,2,0,0}`, `DC = {0,0,-2,2}`. One `fast_rand` byte shuffles them:

- `j3 = r & 3`, swap 3 with `j3`
- `j2 = (r >> 2) & 3`; if `j2 == 3` then `j2 = 2`; swap 2 with `j2`
- `j1 = (r >> 4) & 1`, swap 1 with `j1`

A neighbor is carved only when its row is 1..14 and its column is 1..30 and it is still brick. The cell halfway between is opened first.

---

## RNG

Never store 0.

**8-bit** `fast_rand`. Boot value `$AC`. `load_level` sets it from the level before the carve. Shift right; if the old low bit was set, XOR `$B8`.

**16-bit** `rand16`. Seeded at the start of placement the same way as the 8-bit generator. Shift right; if the old low bit was set, XOR `$D008`. `rand512` is `rand16() & 511`. `load_level` advances it once after the seed. The player is not placed from it.

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
  if first load: DrawVersion    ; vYYYYMMDD centered, then latch off
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
  ClearVersion
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

Free RAM is the bytes from the first address after BSS through `$3FFF`. Charset `$2000`–`$27FF` and the playfield `$2800`–`$29FF` are reserved and are not part of that count. This build: **4837 bytes** (`$2D1B`–`$3FFF`).
