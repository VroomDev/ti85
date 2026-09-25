# VIC-20 Scrolls

Living spec (`spec.md`). **Always update this file in the same change** when behavior is locked or altered.  
**Maps/pics:** a `.LVL` pack (default [`../slvl/POCMAN.LVL`](../slvl/POCMAN.LVL)). [`../vic20engine/gen-charset.py`](../vic20engine/gen-charset.py) and [`gen-level.py`](gen-level.py) take an optional LVL path and parse it via [`../vic20engine/parse_lvl.py`](../vic20engine/parse_lvl.py) → [`charset.h`](charset.h) / [`level.h`](level.h). `gen-level.py` writes `#define CRC` as CRC-8 (poly `$07`, init 0) of the LVL’s first-line name. If the number of packed 32×32 maps differs from the LVL `number of levels` line, it prints `WARNING: found levels does not match LVL N!=M` (found N, declared M) and still writes `level.h`.  
**Code:** Shared routines are [`../vic20engine/engine.h`](../vic20engine/engine.h), `#include`d from [`main.c`](main.c). Viewport, help text, tile flags, and Scrolls-only rules stay in `main.c`. [`gamelogic.md`](gamelogic.md) must match that C. Sound is C (`playCoin` / `playKill` / `playHurt` / `playBash` / `playEmptyClick`), not `sound.s`.

---

## Style

Function names are **camelCase**, verb then noun (`drawView`, `initCharset`, `moveMonsters`, `movePlayerFlat`, `tryMove`, `seekerDir`). Macros are **ALL_CAPS** (`GETKEY`, `GETJIFFY`, `SCREEN`, `UPDIR`, `RIGHTDIR`, `DOWNDIR`, `LEFTDIR`, `TF_SOLID`, `TF_SHOOTABLE`, `TF_FALLING`, `SPOT_STEPS`, `SPOT_STRIDE`).

---

## Target

| Item | Value |
|------|--------|
| Machine | VIC-20 **+32K** (`xvic -memory all`) |
| Language | C (cc65) |
| Toolchain | `%USERPROFILE%\cc65`, config [`../vic20engine/vic20-map.cfg`](../vic20engine/vic20-map.cfg) |
| Emulator | `%USERPROFILE%\GTK3VICE-3.10-win64\bin\xvic.exe` |
| Build | `build.bat [LVL]` in this folder calls [`../vic20engine/build.bat`](../vic20engine/build.bat). Charset fill is this folder's [`DEFCHARS.DEF`](DEFCHARS.DEF). Default LVL is `../slvl/POCMAN.LVL` → `prg/POCMAN.prg`. `build-all.bat` builds every `..\slvl\*.LVL`. |
| Run | `run.bat` (default `prg/POCMAN.prg`) |

---

## Display (stock 22×23)

- Do **not** change row/column counts.
- Clear `$9002` bit 7 so the video matrix is **`$1000`** (not `$1200` on expanded VIC).
- Screen RAM: **`$1000`**. Color RAM: **`$9400`** (+8K/+32K; not `$9600`).
- Cursor off (`$CC = 1`).
- **Black** background, **black** border. `textcolor` cyan for title `cputs`.

### Charset

After the title lines, `initCharset()` copies mixed-case ROM **`$8800`** (not `$8000`) to **5120 (`$1400`)**, overlays tiles, copies the **heart** from uppercase ROM `$8000` slot 83 into RAM screen code **95**, then `$9005 = (PEEK($9005) AND $F0) OR 13` (**205** if the screen nibble is `$C`). `cputs` of lowercase letters makes the Kernal switch to `$8800`; copying `$8000` or setting `$9005` *before* that print leaves the VIC on ROM, so the titles stay lowercase and the map never shows custom glyphs.

Source: `#M0` / `#M1` (and the other letters) in the LVL pack via [`../vic20engine/gen-charset.py`](../vic20engine/gen-charset.py) → [`charset.h`](charset.h). If the pack defines either frame of a letter, both frames come from the pack and the missing frame copies the one present. If the pack defines neither frame, both frames come from [`DEFCHARS.DEF`](DEFCHARS.DEF) the same way. `W` and `X` with no picture in the pack or DEFCHARS copy `b` and `.`. Slot order: `. P s f S k M m F B t b D c W X`. Charset slot 15 (`X` pic) is unused blank, not a map cell. Map letters `X` (start) and `P` (humans to protect) both pack as nibble **1** (`TILE_PLAYER`, `#P` pictures). The live player is `TILE_PLAYER` at `playerxy` (**yellow**). `hurtPlayer` sets `hurtDur = 10`; while `hurtDur` is nonzero, `drawView` tints every `TILE_PLAYER` cell **purple**. `playAudioFrame` decrements `hurtDur`.

`mapToTile` uses the cell’s **lower nibble** as the slot: `TILE_BASE + (charBank << 4) + (cell & 15)` (dir bits ignored). `tileColor` indexes a **16-byte** color table by that nibble. `charBank` flips when jiffy bit 6 changes (no 1/2 keys). Char colors are **0–7** only.

---

### Playfield and torus

| | |
|--|--|
| Map | 32×32 = **1024** cells |
| Packed ROM | `packedLevels[LEVEL_COUNT][512]` from the pack’s maps (two nibbles per byte: even cell bits 0–3, odd cell bits 4–7). Load `packedLevels[mapIndex % LEVEL_COUNT]`. |
| RAM | `playfield[1024]`; bits 0–3 tile id, bits 4–5 last dir (`LEFTDIR`/`RIGHTDIR`/`UPDIR`/`DOWNDIR`). `moveMonsters` / `tryMove` rewrite `id \| (dir << 4)`. |
| Origin | `viewxy` follows the player: `(playerxy - VIEW_CEN) & 1023` |
| Window | **12×8**, **centered**: screen col **5**, starts on **row 5** (0-based row 4) |
| Screen offset | `$1000 + (VIEW_ROW + row) * 22 + VIEW_COL + col` |
| Player | `TILE_PLAYER` at `playerxy` on the playfield (camera keeps that cell at viewport center) |

At startup, unpack 512 → 1024. Wrap is **16-bit add then `& 1023`**. Deltas via `dirDelta[]`: `LEFTDIR` **−1**, `RIGHTDIR` **+1**, `UPDIR` **−32**, `DOWNDIR` **+32** (enum `LEFTDIR=0`, `RIGHTDIR=1`, `UPDIR=2`, `DOWNDIR=3`). No per-axis `& 31`.

`drawView()` POKEs character + color. `waitVrefresh` is compiled in but empty. Do **not** `clrscr` between moves — overwrite in place. Play frames **draw first**, then `gameStep`. `moveMonsters` stops a pass when `$9004` / `VIC.rasterline` hits **`RASTER_OFF_EARLY` (123)** or **`RASTER_OFF` (126)**.

Each view row starts at `(viewxy + (row << 5)) & 1023`, then walks right with `(i + 1) & 1023`.

Screen rows 1–3 (0-based 0–2):

- Row 1: `Scrolls(c)1996 CBusch` (22 chars)
- Row 2: LVL `$S` (`STORY_TITLE`) at col 0; `gen-level.py` strips it and `.center(22)`
- Row 3: LVL `$A` (`STORY_AUTHOR`) at col 0, same trim/center to 22

`restoreStoryLine` redraws `$S` and `$A` (clears those rows first). First paint is in `initVideo` **before** `initCharset`.

One blank row under the viewport, then the HUD (0-based **13**), **centered** (`HUD_COL` = `(22-15)/2` = **3**): `S:0000 ♥:5 L:1` then the **key tile** if `hasKey` (that last cell is blank when not). Heart is RAM char 95 (red), not the letter H. Score digits white; `S:` / `L:` / `HI:` yellow. HUD level digit is `liveLevel & 7`. `drawHud` clears those rows then pokes. Call it when those change (`addScore`, `hurtPlayer`, key pickup, door unlock, `startLevel` / first-map HUD, and once from `initVideo`). Do **not** redraw the HUD every frame.

`HISCORE_ROW` is **15** (`HUD_ROW + 2`): centered `HI:0000` (`HISCORE_COL` = `(22-7)/2` = **7**), packed BCD like score. Stays up while New Level / Game Over occupy the row **between** HUD and high score (`HUD_ROW + 1`). `hiscore` is RAM, not cleared on a new run (only on reset / `main`).

Bottom row (0-based **22**): centered `Joy or Shift C= M,.` (`HELP_TEXT` via `drawHelpLine` from `initVideo`). That string is what the program prints; walk keys that work are **I/J/L/M**. Do **not** clear that row with the HUD.

`main` draws the titles, then `startRun()` in `engine.h` (`Press key!`, `waitFireOrKey`, then `drawNewLevelMsg` before play). Play is an inner `for (;;)`. Scroll sets `pendingLevel`; `pumpVideo` then `drawNewLevelMsg()` on the row **below the HUD** (`gotoxy(HUD_COL, HUD_ROW + 1)`). That function, in `engine.h`, prints `New Level! SCODE:` and `levelCode(mapIndex)`: `rng` reset to `CRC`, then `rand8` once per `mapIndex` step, capped at `LEVEL_COUNT`. It only draws. `pumpVideo` calls it while `pendingLevel` is set, and `waitFrames` calls `pumpVideo`, so the message function must not wait. The play loop waits `WAIT_FRAMES` (30) then `startLevel()`, `cclear` that row, and restores the story line. Game over: `Game Over!` on the row **below the HUD**, silence, wait `WAIT_FRAMES`, `cclear` that row, restore story, `break` — outer loop starts a new run at once. **Q** in `gameStep` sets `quitRun` and the inner loop breaks the same way. `waitFireOrKey()` waits two raster lines then spins until joystick fire (`$9111` bit 5 low), Shift (`$028D` bit 0), or any key (`GETKEY() != 64`), calling `rand8` and `rand16` each pass so hold time seeds both LFSRs.

---

### Level letters → nibble

Map letter `X` is the player start (`playerStart` = first `X` in row-major order) and packs as nibble **1** (`TILE_PLAYER`, `#P` pictures). Map letter `P` is a fellow human and also packs as nibble **1**. Other letters use charset slot index (so a raw `X` pic slot 15 is not a map cell). Trailing `;` comments on map rows are ignored.

| Char | Id | Meaning | Flags | Color (0–7) |
|------|----|---------|--------|-------------|
| `.` | 0 | blank | — | black |
| `X` | 1 | player start (`TILE_PLAYER`) | solid | yellow |
| `P` | 1 | fellow human (`TILE_PLAYER`) | solid | yellow |
| `s` | 2 | scroll | solid | white |
| `f` | 3 | fire | solid | blue |
| `S` | 4 | stain / splat | falling | red |
| `k` | 5 | key | solid | yellow |
| `M` | 6 | patrol | solid, shootable, falling | purple |
| `m` | 7 | seeker | solid, shootable | red |
| `F` | 8 | bomb | shootable, falling | cyan |
| `B` | 9 | cloud / bullet picture (`TILE_BULLET`) | solid | white |
| `t` | 10 | tree (`TILE_TREE`) | solid, shootable, falling | green |
| `b` | 11 | brick | solid | white |
| `D` | 12 | door | solid, falling | red |
| `c` | 13 | coin | falling | yellow |
| `W` | 14 | wall | solid, shootable | white |

Flags: `TF_SOLID=1`, `TF_SHOOTABLE=2`, `TF_FALLING=4`. Falling is stored on the tile; the gravity drop loop in `moveMonsters` is commented out.

The player occupies dest if `hl != 0` and dest is **not** `TF_SOLID`. Camera: `viewxy = (playerxy - VIEW_CEN) & 1023`.

Monsters use `destBlank` / `tryMove` (dest must be nibble **blank**), not a shared `moveSpr`.

---

## Loop

Outer `for (;;)`: `startRun()`, then inner play loop. Each play frame: if `pendingLevel`, `waitFrames(12)` (audio + video only), `startLevel`, clear flag, restore story line; if `lives == 0`, banner, silence, wait, restore, break; if `quitRun`, silence, restore, break. Else `pumpVideo`, `playAudioFrame`, `gameStep`. `charBank` follows jiffy bit 6.

`gameStep` in `engine.h`: if **Q**, set `quitRun` and return. If **P**, `pauseRun`: silence, `Paused` on the row below the HUD, wait for P up then P down then P up, clear that row (restore `New Level!` if `pendingLevel`). If **S**, `warpLevels`: set `$9122` bit 7 to output so column 7 scans, then on the HUD row `cputs` of `Secret Code:` and two `cgetc` keypresses at column 13. `x` then `y` calls `cheatScroll`. Each read waits for `$C5 == 64`, then `POKE $C6, 0`. Letters are passed to `cputc` as ASCII `a`–`z` so they draw as `A`–`Z` on the `$8800` RAM charset. `$9122` is restored afterward. The two PETSCII digits (`0`–`9`, `A`–`F`, or shifted `a`–`f` at `$C1`–`$C6`) are packed into one byte, high nibble first. Anything else is nibble 0. A nonzero byte walks `levelCode` (`rng = CRC`, then `rand8`) and warps when that step count is `< LEVEL_COUNT`. `0` is ignored. Else `spawnMonster`, `movePlayer` on odd `frame` bits only, `moveBullet`, `moveMonsters`. No player jump. The player cannot drop bombs.

---

## Score, lives, maps

- New run: score 0, lives **5** (max **9**), `mapIndex` 0, `liveLevel` 1, `firstMap` (no +1 on that unpack). HUD draws `liveLevel & 7` as one digit.
- `addScore`: packed 4-digit BCD in 16 bits (`$0000`–`$9999`). HUD digits are nibbles (no `/` `%`). Cap `$9999`. Extra life when the low BCD byte is `$50` or `$99` (50, 99, 150, 199, …) and lives < 9. `addScore` lives in `engine.h`.
- `hiscore` is packed BCD; unsigned compare is valid. Commit `hiscore = score` only on **game over** (lives hit 0), then `drawHud`. Shown as `HI:0000`. Not cleared on a new run. **Q** does not record it.
- Coin **+1** (`playCoin`). Kill seeker +1 (`playKill`). Shot bomb +1 (`playKill`). Scroll +1 then `startLevel` (+1 if not the first map of the run).
- Scroll: `++mapIndex`, unpack `mapIndex % LEVEL_COUNT`, `liveLevel = mapIndex + 1` (never wraps).

---

## Player

`playerxy` is a 16-bit torus index **and** `playfield[playerxy] == TILE_PLAYER`. `movePlayerFlat` runs every other `gameStep` (`if ((++frame) & 1)`). Overhead 4-way walk; no gravity.

Facing: Down, else Up, then Right else Left (last pair wins). If shooting and `fireHolds <= FIRES_BEFORE_MOVE` (3), do not add a walk delta. Else dest = `(playerxy + hl) & 1023`. Occupy dest if `hl != 0` and dest is not `TF_SOLID`.

Hits use that dest cell even when the move is refused: monster hurt; coin score; fire stain + respawn; bomb hurt; key/door/scroll as below. Brick-family dest simply blocks.

The player **cannot drop bombs**.

---

## Bullet

At most one. Range **`BULLET_RANGE` (6)** minus how long fire has been held (`fireHolds`). Same picture/color as `B`. Spawn on fire/Shift if none in flight; dir = facing; start on player cell, first step leaves the player. `moveBullet` every `gameStep`. Non-blank dest: `shootCell` then despawn (ignore dest if it is the player). Always rewrite the player cell after the bullet step. Held fire at `fireHolds == BULLET_RANGE` plays `playEmptyClick` and does not spawn.

`shootCell`: stain `S` → blank. Patrol → becomes seeker (gets mad). Seeker → splat (`playKill`, +1). Other shootable → stain; bomb also +1 / `playKill`; tree/wall `playBash`.

---

## Monsters

**Every** playfield `M` and `m` (packed map tiles and spawned) is eligible. `SPOT_STEPS` **100**, `SPOT_STRIDE` **239**: each call `spotxy = (spotxy + 239) & 1023` until steps run out or the raster hits 123 or 126.

- **Patrol `M`:** last dir (bits 4–5). If dest is not blank and not the player, `randDir()`. Blank dest is a valid step.
- **Seeker `m`:** `seekerDir`: `diff = (spotxy - playerxy) & 1023`: **left** if `diff < 16`, **right** if `diff >= 1024-16`, **up** if `diff < 512`, else **down**. No wander branch.
- Dest `TILE_PLAYER` (the hero at `playerxy` or a map `P` human): `hurtPlayer` (skip while `hurtDur`); monster stays, source packed as `id | (dir << 4)`. Else `tryMove` onto blank only. If blocked, rewrite the source cell with that packed byte (dir update).
- **Bomb `F`:** `randDir()` then `tryMove`. Not a player-placed trap. `startLevel` in `engine.h` calls `putTileRandomly(TILE_BOMB)` (and `TILE_TREE` when `SCROLLS` is defined) up to 32 times while the index is `<= liveLevel`. That writes on a blank cell at `playerxy + 256 + rand512()`. Also called from spawn / shot-bomb. Engine placement, not a control.

`spawnMonster` in `engine.h` each `gameStep` if `monsterCount < (liveLevel << 2)`: `monsterCount & 3` → patrol, else seeker; `xy = (playerxy + 256 + rand512()) & 1023` with `rand512` = `rand16() & 511`. When `SCROLLS` is defined, also `putTileRandomly(TILE_TREE)`. `rand8` / `rand16` are Galois right-shift LFSRs (`rng = (rng >> 1) ^ ((rng & 1) ? poly : 0)`), polys **`$B4`** (period 255) and **`$D008`** (period 65535). Both seeded `1` in `main`; `waitFireOrKey` steps both. Never seed 0. [`../vic20engine/check-lfsr.py`](../vic20engine/check-lfsr.py) checks period. Skip if not blank. Packed with down dir. `monsterCount++`. `splatMonster` decrements count if the cell was nonzero.

---

## Sound (C)

VIC `$900A–$900E`. `sfxDur` is a duration counter (also part of hurt i-frame with `hurtDur`).

| Call | VIC | `sfxDur` |
|------|-----|----------|
| `playCoin` | volume 15, soprano+alto 240 | 1 |
| `playKill` | volume 10, bass 130, alto 148, noise 220 | 2 |
| `playHurt` | volume 15, bass 140, alto 155, noise 200 | 2 |
| `playBash` | volume 5, noise 150 | 2 |
| `playEmptyClick` | volume 15, noise 240 | 1 |
| `silenceVic` | all oscillators and volume 0 | 0 |

`playAudioFrame` each game tick: if `sfxDur`, decrement; at 0 call `silenceVic`. If `hurtDur`, decrement.

---

## Controls

Kernal **LSTX** `$C5` (PEEK 197): matrix code of the key currently **held**. **64** = no key. Only one matrix key; Shift is **not** in `$C5`. **NDX** `$C6` is the Kernal keyboard-buffer count; `cgetc` reads that buffer (PETSCII), not `$C5`. **SHFLAG** `$028D`: bit 0 left/right Shift, bit 1 CBM, bit 2 Ctrl (updated by SCNKEY).

Joystick (VIA, active low): up/down/left/fire `$9111` bits 2/3/4/5, right `$9120` bit 7 (`$9122` bit 7 cleared so right is readable). That bit is also keyboard column 7 (**2**, **4**, **6**, **8**, **0**, `-`, HOME, F7). While it is an input those keys do not scan. `jumpLevels` sets `$9122` bit 7 back to output for the prompt, then restores it.

```c
#define GETKEY()     (PEEK(LSTX))   /* $C5; 64 = none */
#define GETJIFFY()   (PEEK(TIME))   /* $A2; low byte of jiffy clock */
```

| Action | Key | Scan code | Joystick |
|--------|-----|-----------|----------|
| Up | **I** | 12 | up |
| Left | **J** | 20 | left |
| Right | **L** | 21 | right |
| Down | **M** | 36 | down |
| Shoot | **Shift** | `$028D` bit 0 | fire |
| Quit (end run; outer loop starts another) | **Q** | 48 | — |
| Pause | **P** | 13 | — |
| Level jump | **S** | 41 | — |
| RETURN | **RETURN** | 15 | fire (`waitFireOrKey` treats any key or fire as done) |

Shoot: facing stays; no walk until `fireHolds > 3`. Keyboard fire is **Shift**. Joystick still works. There is **no** bomb-drop key. Charset bank flips when jiffy bit 6 changes.

---

## Build / run

```bat
build.bat
build.bat POCMAN.LVL
build-all.bat
run.bat
```

```bat
python ..\vic20engine\gen-charset.py ..\slvl\POCMAN.LVL
python ..\vic20engine\gen-level.py ..\slvl\POCMAN.LVL
cl65 -O -t vic20 -C ..\vic20engine\vic20-map.cfg -o prg/POCMAN.prg ..\vic20engine\header.s main.c
%USERPROFILE%\GTK3VICE-3.10-win64\bin\xvic.exe -memory all -autostart prg/POCMAN.prg
```

---
