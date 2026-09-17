# VIC-20 Caves

Living spec (`spec.md`). **Always update this file in the same change** when behavior is locked or altered.  
**Maps/pics:** a `.LVL` pack (default [`CASTLE.LVL`](CASTLE.LVL)). [`gen-charset.py`](gen-charset.py) and [`gen-level.py`](gen-level.py) take an optional LVL path and parse it via [`parse_lvl.py`](parse_lvl.py) → [`charset.h`](charset.h) / [`level.h`](level.h).  
**Code:** [`main.c`](main.c) is the source of truth. [`gamelogic.md`](gamelogic.md) must match that C. Sound is C (`playCoin` / `playKill` / `playHurt`), not `sound.s`.

---

## Style

Function names are **camelCase**, verb then noun (`drawView`, `initCharset`, `moveMonsters`, `moveSpr`, `tryMove`, `seekerDir`). Macros are **ALL_CAPS** (`GETKEY`, `GETJIFFY`, `SCREEN`, `UPDIR`, `RIGHTDIR`, `DOWNDIR`, `LEFTDIR`, `TF_SOLID`, `TF_SHOOTABLE`, `TF_FALLING`, `SPOT_STEPS`, `SPOT_STRIDE`).

---

## Target

| Item | Value |
|------|--------|
| Machine | VIC-20 **+32K** (`xvic -memory all`) |
| Language | C (cc65) |
| Toolchain | `%USERPROFILE%\cc65`, config `vic20-map.cfg` |
| Emulator | `%USERPROFILE%\GTK3VICE-3.10-win64\bin\xvic.exe` |
| Build | `build.bat [LVL]` → `prg/<basename>.prg` (`gen-charset.py` then `gen-level.py` then `cl65`). Default LVL is `CASTLE.LVL` → `prg/CASTLE.prg`. `build-all.bat` builds every `..\clvl\*.LVL` into `prg/`. |
| Run | `run.bat` |

---

## Display (stock 22×23)

- Do **not** change row/column counts.
- Clear `$9002` bit 7 so the video matrix is **`$1000`** (not `$1200` on expanded VIC).
- Screen RAM: **`$1000`**. Color RAM: **`$9400`** (+8K/+32K; not `$9600`).
- Cursor off (`$CC = 1`).
- **Black** background, **black** border. `textcolor` cyan for title `cputs`.

### Charset

After the title lines, `initCharset()` copies mixed-case ROM **`$8800`** (not `$8000`) to **5120 (`$1400`)**, overlays tiles, copies the **heart** from uppercase ROM `$8000` slot 83 into RAM screen code **95**, then `$9005 = (PEEK($9005) AND $F0) OR 13` (**205** if the screen nibble is `$C`). `cputs` of lowercase letters makes the Kernal switch to `$8800`; copying `$8000` or setting `$9005` *before* that print leaves the VIC on ROM, so the titles stay lowercase and the map never shows custom glyphs.

Source: `#M0` / `#M1` (and the other letters) in the LVL pack via [`gen-charset.py`](gen-charset.py) → [`charset.h`](charset.h). Missing glyphs fill from [`DEFCHARS.DEF`](DEFCHARS.DEF); the pack overrides. Missing bank `1` copies `0`. Slot order: `. P s f S k M m F B t b D c W X`. Pack has no `#W`; `W` copies `b`. Charset slot 15 (`X` pic) is unused blank. Map letter `X` is remapped to nibble **1** (the `#P` player glyph). Player is `TILE_PLAYER` on the playfield (**yellow**). `hurtPlayer` sets `hurtDur = 3`; while `hurtDur` is nonzero, `tileColor` draws the player **purple**. `playAudioFrame` decrements `hurtDur`.

`mapToTile` uses the cell’s **lower nibble** as the slot: `TILE_BASE + (charBank << 4) + (cell & 15)` (dir / spawn bits ignored). `tileColor` indexes a **16-byte** color table by that nibble. `charBank` flips when jiffy bit 6 changes (no 1/2 keys). Char colors are **0–7** only.

---

### Playfield and torus

| | |
|--|--|
| Map | 32×32 = **1024** cells |
| Packed ROM | `packedLevels[LEVEL_COUNT][512]` from CASTLE’s maps (two nibbles per byte: even cell bits 0–3, odd cell bits 4–7). Load `packedLevels[mapIndex % LEVEL_COUNT]`. |
| RAM | `playfield[1024]`; bits 0–3 tile id, bits 4–5 last dir (`UPDIR`/`RIGHTDIR`/`DOWNDIR`/`LEFTDIR`). `spawnMonster` also ORs `PF_SPAWNED` (`$40`). `moveMonsters` / `tryMove` rewrite `id \| (dir << 4)` and **drop** that high bit. |
| Origin | `viewxy` follows the player: `(playerxy - VIEW_CEN) & 1023` |
| Window | **12×8**, **centered**: screen col **5**, starts on **row 5** (0-based row 4) |
| Screen offset | `$1000 + (VIEW_ROW + row) * 22 + VIEW_COL + col` |
| Player | `TILE_PLAYER` at `playerxy` on the playfield (camera keeps that cell at viewport center) |

At startup, unpack 512 → 1024. Wrap is **16-bit add then `& 1023`**. Deltas via `dirDelta[]`: `UPDIR` **−32**, `RIGHTDIR` **+1**, `DOWNDIR` **+32**, `LEFTDIR` **−1**. No per-axis `& 31`.

`drawView()` waits until `$9004` / `VIC.rasterline` is **`>= RASTER_OFF` (126)** (beam past the 12×8 view). One `while` — if already off the view, no spin. Then `POKE`s character + color. Do **not** `clrscr` between moves — overwrite in place. Play frames **draw first**, then `gameStep` while the beam paints. `moveMonsters` uses `SPOT_STEPS`, not a raster gate.

Each view row starts at `(viewxy + (row << 5)) & 1023`, then walks right with `(i + 1) & 1023`.

Screen rows 1–3 (0-based 0–2):

- Row 1: `Caves (c)1996 CHRIS B` (22 chars)
- Row 2: LVL `$S` (`STORY_TITLE`) at col 0; `gen-level.py` strips it and `.center(22)`
- Row 3: LVL `$A` (`STORY_AUTHOR`) at col 0, same trim/center to 22

`restoreStoryLine` redraws `$S` and `$A` (clears those rows first). First paint is in `initVideo` **before** `initCharset`.

One blank row under the viewport, then the HUD (0-based **13**), **centered** (`HUD_COL` = `(22-15)/2` = **3**): `S:0000 ♥:5 L:1` then the **key tile** if `hasKey` (that last cell is blank when not). Heart is RAM char 95 (red), not the letter H. Score digits white; `S:` / `L:` / `HI:` yellow. `drawHud` clears those rows then pokes. Call it when those change (`addScore`, `hurtPlayer`, key pickup, door unlock, `startLevel` / first-map HUD, and once from `initVideo`). Do **not** redraw the HUD every frame.

`HISCORE_ROW` is **15** (`HUD_ROW + 2`): centered `HI:0000` (`HISCORE_COL` = `(22-7)/2` = **7**), packed BCD like score. Stays up while New Level / Game Over occupy the row **between** HUD and high score (`HUD_ROW + 1`). `hiscore` is RAM, not cleared on a new run (only on reset / `main`).

`main` draws the titles, then `startRun()` (`waitFireOrKey` before play). Play is an inner `for (;;)`. Scroll sets `pendingLevel`; `pumpVideo` then `drawNewLevelMsg()` on the row **below the HUD** (`gotoxy(HUD_COL, HUD_ROW + 1)`, 0-based row 14). The play loop waits `WAIT_FRAMES` (12) then `startLevel()`, `cclear` that row, and restores the story line. Game over: `Game Over!` on the row **below the HUD** (`gotoxy(HUD_COL, HUD_ROW + 1)`, 0-based row 14), silence, wait `WAIT_FRAMES`, `cclear` that row, restore story, `break` — outer loop starts a new run at once. **Q** in `gameStep` sets `quitRun` and the inner loop breaks the same way. `waitFireOrKey()` spins until joystick fire (`$9111` bit 5 low) or any key (`GETKEY() != 64`), calling `rand8` and `rand16` each pass so hold time seeds both LFSRs.

---

### Level letters → nibble

Map letter `X` is the player start and packs as nibble **1** (`TILE_PLAYER`, `#P` pictures). Other letters use charset slot index (so a raw `X` pic slot 15 is not a map cell). Trailing `;` comments on map rows are ignored.

| Char | Id | Meaning | Flags | Color (0–7) |
|------|----|---------|--------|-------------|
| `.` | 0 | blank | — | black |
| `X` | 1 | player glyph starting point | solid | yellow |
| `s` | 2 | scroll | solid | white |
| `f` | 3 | lava / fire | solid | red |
| `S` | 4 | stain / splat | falling | red |
| `k` | 5 | key | solid | yellow |
| `M` | 6 | patrol | solid, shootable, falling | purple |
| `m` | 7 | seeker | solid, shootable | red |
| `F` | 8 | bomb | shootable, falling | cyan |
| `B` | 9 | cloud / bullet picture (`TILE_BULLET`) | solid | white |
| `t` | 10 | falling wall (`TILE_TREE`) | solid, shootable, falling | green |
| `b` | 11 | brick | solid | white |
| `D` | 12 | door | solid, falling | red |
| `c` | 13 | coin | falling | yellow |
| `W` | 14 | wall | solid, shootable | white |

Flags: `TF_SOLID=1`, `TF_SHOOTABLE=2`, `TF_FALLING=4`.

`moveSpr` (player only today): if dest is **solid**, do not move, return that tile. If the mover is **not** the player and dest is a **coin**, do not move. Else occupy dest, blank source, return the old dest tile. Coins, stains, and bombs are enterable (not solid). Camera: `viewxy = (playerxy - VIEW_CEN) & 1023`.

Monsters use `destBlank` / `tryMove` (dest must be nibble **blank**), not `moveSpr`.

---

## Loop

Outer `for (;;)`: `startRun()`, then inner play loop. Each play frame: if `pendingLevel`, `waitFrames(12)` (audio + video only), `startLevel`, clear flag, restore story line; if `lives == 0`, banner, silence, wait, restore, break; if `quitRun`, silence, restore, break. Else `pumpVideo`, `playAudioFrame`, `gameStep`. `drawView` waits while `$9004 < 126`, then POKEs; logic runs after that. `charBank` follows jiffy bit 6.

`gameStep`: if **Q**, set `quitRun` and return. If **S**, `cheatScroll` writes `TILE_SCROLL` at `(playerxy + 1) & 1023` (overwrites whatever is there; spawned `M`/`m` decrement `monsterCount` with no score). Else `spawnMonster`, `moveBullet`, `movePlayer`, `moveMonsters`. No `frame` counter. `putBomb()` is compiled but commented out. `blockspot` is initialized and never used. There is **no** `blockFall`.

Falling tiles drop when `moveMonsters`’s spot cursor lands on them (`TF_FALLING` and not already handled as `M`/`m`).

---

## Score, lives, maps

- New run: score 0, lives **5** (max **9**), `mapIndex` 0, `liveLevel` 1, `firstMap` (no +1 on that unpack). HUD draws `lives` as one digit (no `% 10`).
- `addScore`: packed 4-digit BCD in 16 bits (`$0000`–`$9999`). HUD digits are nibbles (no `/` `%`). Cap `$9999`. Extra life when the low BCD byte is `$50` (50, 150, 250, …) and lives < 9.
- `hiscore` is packed BCD; unsigned compare is valid. Commit `hiscore = score` only on **game over** (lives hit 0), then `drawHud`. Shown as `HI:0000`. Not cleared on a new run. **Q** does not record it.
- Coin **+1** (`playCoin`). Kill monster +1 (`playKill`). Bomb stomp/shot +1 (no kill SFX). Scroll +1 then `startLevel` (+1 if not the first map of the run).
- Scroll: `++mapIndex`, unpack `mapIndex % LEVEL_COUNT`, `liveLevel = mapIndex + 1` (never wraps).

---

## Player

`playerxy` is a 16-bit torus index **and** `playfield[playerxy] == TILE_PLAYER`. Every `gameStep` runs `movePlayer` (JS `tryPlayerMove`).

Stomp if `jumpptr == 0` (monster splat / bomb stain). If shooting and no bullet in flight, spawn the bullet. Then `hl` (unsigned wrap): if `jumpptr`, decrement and `hl = UPDELTA`; else if below blank or lava, `hl = DOWNDELTA`; else cloud + Down + not shooting sets `jumpptr = 20`, and jump held sets `jumpptr = JUMP_LEN - 1` and `hl = UPDELTA`. Down + not shooting overwrites `hl = DOWNDELTA`. Facing: Down, then Up, then Right, then Left (last wins).

Horizontal: if Right/Left and not shooting, look at **combined** `(playerxy + hl ± 1) & 1023`. Add `RIGHTDELTA` / `LEFTDELTA` to `hl` only if that cell is **not** `TILE_BRICK` / `TILE_WALL` / `TILE_TREE` (C stand-in for JS `BRICK_BASE`). Occupy dest if `hl != 0` and dest is **not** `TF_SOLID` (JS `NOERASE`). Then hits: monster hurt; coin score; lava stain + respawn; bomb hurt; key/door/scroll as before. Brick-family dest while `jumpptr`: extra `--jumpptr`.

---

## Bullet

At most one. Range **4**. Same picture/color as cloud `B`. Spawn on fire/`K` if none in flight; dir = facing; start on player cell, first step leaves the player. Every `gameStep`. Non-blank dest: `shootCell` if dest is stain (`S` → blank) or shootable (monster splat, else stain; bomb +1), then despawn. Always rewrite the player cell after the bullet step.

---

## Monsters

**Every** playfield `M` and `m` (packed map tiles and spawned) is eligible. `SPOT_STEPS` **100**, `SPOT_STRIDE` **13**: each call `spotxy = (spotxy + 13) & 1023` that many times.

- **Patrol `M`:** if `TF_FALLING` and the cell below is blank, dir = down. Else last dir (bits 4–5). If that dir is up/down (map tiles start at dir 0 = up) or dest is not blank, pick left or right only — not 4-way, so they do not hop in place. Blank beside them is a valid step (walk off ledges).
- **Seeker `m`:** `seekerDir` (CENGINE `doseek`): `diff = (spotxy - playerxy) & 1023`: **left** if `diff < 16`, **right** if `diff >= 1024-16`, **up** if `diff < 512`, else **down**. No wander branch.
- Dest `TILE_PLAYER`: `hurtPlayer` (i-frame while `sfxDur`); monster stays, source packed as `id | (dir << 4)`. Else `tryMove` onto blank only; packed write is `id | (dir << 4)` (no `PF_*`). If blocked, rewrite the source cell with that packed byte (dir update).
- **Bomb `F`:** dest = below. If that cell is blank, drop. Else `playChirp` and dest = random left/right. `tryMove` (no-op if dest not blank).
- Other `TF_FALLING` tiles (stain, `t`, door, coin): try drop down one if dest blank.

`spawnMonster` each `gameStep` if `monsterCount < (liveLevel << 2)`: even count → seeker, odd → patrol; `xy = (playerxy + 256 + rand512()) & 1023` with `rand512` = `rand16() & 511`. `rand8` / `rand16` are Galois right-shift LFSRs (`rng = (rng >> 1) ^ ((rng & 1) ? poly : 0)`), polys **`$B4`** (period 255) and **`$D008`** (period 65535). Both seeded `1` in `main`; `waitFireOrKey` steps both. Never seed 0. [`check-lfsr.py`](check-lfsr.py) checks period. Skip if not blank. Packed with down dir and `PF_SPAWNED`. `monsterCount++`. `splatMonster` decrements count only if `PF_SPAWNED` is still set on that cell.

---

## Sound (C)

VIC `$900A–$900E`. `sfxDur` is the i-frame / duration counter.

| Call | VIC | `sfxDur` |
|------|-----|----------|
| `playCoin` | volume 15, soprano+alto 240 | 4 |
| `playKill` | volume 10, bass+noise 220 | 10 |
| `playHurt` | volume 15, bass+alto+noise 140 | **5** |
| `silenceVic` | all oscillators and volume 0 | 0 |

`playAudioFrame` each game tick: if `sfxDur`, decrement; at 0 call `silenceVic`. If `hurtDur`, decrement. Only coin / hurt / kill make sound.

---

## Controls

Kernal **LSTX** `$C5` (PEEK 197): matrix code of the key currently **held**. **64** = no key.

Joystick (VIA, active low): up/down/left/fire `$9111` bits 2/3/4/5, right `$9120` bit 7 (`$9122` bit 7 cleared so right is readable).

```c
#define GETKEY()     (PEEK(LSTX))   /* $C5; 64 = none */
#define GETJIFFY()   (PEEK(TIME))   /* $A2; low byte of jiffy clock */
```

| Action | Key | Scan code | Joystick |
|--------|-----|-----------|----------|
| Jump if grounded | **I** | 12 | up |
| Left | **J** | 20 | left |
| Right | **L** | 21 | right |
| Down / fast fall / cloud high-jump | **M** | 36 | down |
| Shoot | **K** | 44 | fire |
| Quit (end run; outer loop starts another) | **Q** | 48 | — |
| Cheat: scroll one cell to the right of the player | **S** | 41 | — |
| RETURN | **RETURN** | 15 | fire (`waitFireOrKey` treats any key or fire as done) |

Shoot: facing stays; no walk. Keys and joystick may be used together. Charset bank flips when jiffy bit 6 changes.

---

## Build / run

```bat
build.bat
build.bat CASTLE.LVL
build-all.bat
run.bat
```

```bat
python gen-charset.py CASTLE.LVL
python gen-level.py CASTLE.LVL
cl65 -O -t vic20 -C vic20-map.cfg -o prg/CASTLE.prg header.s main.c
%USERPROFILE%\GTK3VICE-3.10-win64\bin\xvic.exe -memory all -autostart prg/CASTLE.prg
```

---

