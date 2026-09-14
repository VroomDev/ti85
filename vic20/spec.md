# VIC-20 map viewer

Living spec (`spec.md`). **Always update this file in the same change** when behavior is locked or altered.  
**Source of truth:** [`CASTLE.LVL`](CASTLE.LVL) (CENGINE pack: header, 32×32 maps, `#X0`/`#X1` pics). [`gen-charset.py`](gen-charset.py) and [`gen-level.py`](gen-level.py) parse it via [`parse_lvl.py`](parse_lvl.py) → [`charset.h`](charset.h) / [`level.h`](level.h).  
**Code:** [`main.c`](main.c) (cc65 C, +32K).

---

## Style

Function names are **camelCase**, verb then noun (`drawView`, `initCharset`, `moveMonsters`). Macros are **ALL_CAPS** (`GETKEY`, `GETJIFFY`, `SCREEN`, `SPOT_STEPS`, `UPDIR`, `RIGHTDIR`, `DOWNDIR`, `LEFTDIR`).

---

## Target

| Item | Value |
|------|--------|
| Machine | VIC-20 **+32K** (`xvic -memory all`) |
| Language | C (cc65) |
| Toolchain | `%USERPROFILE%\cc65`, config `vic20-map.cfg` |
| Emulator | `%USERPROFILE%\GTK3VICE-3.10-win64\bin\xvic.exe` |
| Build | `build.bat` → `mapview.prg` (`gen-charset.py` then `gen-level.py` then `cl65`) |
| Run | `run.bat` |

---

## Display (stock 22×23)

- Do **not** change row/column counts.
- Clear `$9002` bit 7 so the video matrix is **`$1000`** (not `$1200` on expanded VIC).
- Screen RAM: **`$1000`**. Color RAM: **`$9400`** (+8K/+32K; not `$9600`).
- Cursor off (`$CC = 1`).
- **Black** background, **black** border.

### Charset

After the title lines, `initCharset()` copies mixed-case ROM **`$8800`** (not `$8000`) to **5120 (`$1400`)**, overlays tiles, copies the **heart** from uppercase ROM `$8000` slot 83 into RAM screen code **95**, then `$9005 = (PEEK($9005) AND $F0) OR 13` (**205** if the screen nibble is `$C`). `cputs` of lowercase letters makes the Kernal switch to `$8800`; copying `$8000` or setting `$9005` *before* that print leaves the VIC on ROM, so the titles stay lowercase and the map never shows custom glyphs.

Source: `#M0` / `#M1` (and the other letters) in [`CASTLE.LVL`](CASTLE.LVL) via [`gen-charset.py`](gen-charset.py) → [`charset.h`](charset.h). Missing bank `1` copies `0`. Slot order: `. P s f S k M m F B t b D c W X`. Pack has no `#W`; `W` copies `b`. `X` uses blank. Player is `TILE_PLAYER` on the playfield (white).

`mapToTile` uses the cell’s **lower nibble** as the slot: `TILE_BASE + (charBank << 4) + (cell & 15)`. `tileColor` indexes a **16-byte** color table by that nibble. `charBank` flips when jiffy bit 6 changes (no 1/2 keys).

---

### Playfield and torus

| | |
|--|--|
| Map | 32×32 = **1024** cells |
| Packed ROM | `packedLevels[LEVEL_COUNT][512]` from CASTLE’s maps (two nibbles per byte: even cell bits 0–3, odd cell bits 4–7). Game uses map 0 as `packedLevel`. |
| RAM | `playfield[1024]`; bits 0–3 tile id, bits 4–5 last move dir (`UPDIR`/`RIGHTDIR`/`DOWNDIR`/`LEFTDIR` = 0–3), bits 6–7 0 |
| Origin | `viewxy` follows the player: `(playerxy - VIEW_CEN) & 1023` |
| Window | **12×8**, **centered**: screen col **5**, starts on **row 3** (0-based row 2) |
| Screen offset | `$1000 + (VIEW_ROW + row) * 22 + VIEW_COL + col` |
| Player | `TILE_PLAYER` at `playerxy` on the playfield (camera keeps that cell at viewport center) |

At startup, unpack 512 → 1024. Wrap is **16-bit add then `& 1023`**. Deltas via `dirDelta[]`: `UPDIR` **−32**, `RIGHTDIR` **+1**, `DOWNDIR` **+32**, `LEFTDIR` **−1**. No per-axis `& 31`.

`drawView()` waits for the **start of vertical blank** (`$9004` goes 0: leave line 0, then wait until it is 0 again), then `POKE`s character + color. Do **not** `clrscr` between moves — overwrite in place.

Each view row starts at `(viewxy + (row << 5)) & 1023`, then walks right with `(i + 1) & 1023`. The player is a real playfield tile, so falling monsters cannot occupy that cell (and the center draw no longer hides them).

Screen rows 1–2 (0-based 0–1):

- Row 1: `Caves (c)1996 CHRIS B` (22 chars)
- Row 2: `Creepy Castle` (centered)

Row immediately below the viewport (0-based 10), starting **2 columns left of the view** (screen col 3): HUD `S: 0000 ♥:4 L:1` — heart is RAM char 95 (red), not the letter H. `score` starts 0, `hearts` 4, `levelNum` 1. `PLAYER_START` / `playerStart[0]` in `level.h` is the first `P`/`X` on map 0.

---

### Level letters → nibble

`P` and `X` in the pack maps are **player start only** and pack as blank (`0`). Other letters use charset slot index. Trailing `;` comments on map rows are ignored.

| Char | Id | Meaning | Flags |
|------|----|---------|--------|
| `.` | 0 | blank | — |
| `P` | (start → 0) | player glyph slot 1, not placed | no-erase |
| `s` | 2 | scroll (win) | no-erase |
| `f` | 3 | lava / fire | no-erase |
| `S` | 4 | stain / splat | falling |
| `k` | 5 | key | — |
| `M` | 6 | patrol monster | no-erase, killable, falling |
| `m` | 7 | seeker monster | no-erase, killable |
| `F` | 8 | bomb | killable, falling |
| `B` | 9 | bullet / cloud | — |
| `t` | 10 | tree | no-erase, killable, falling |
| `b` | 11 | brick | — |
| `D` | 12 | door | falling |
| `c` | 13 | coin | falling |
| `W` | 14 | wall | — |
| `X` | (start → 0) | X glyph slot 15, not placed | — |

Flags (`tileFlags[16]`): `TF_NOERASE=1`, `TF_KILLABLE=2`, `TF_FALLING=4`. A mover may enter a cell only if the dest nibble is **blank**. Killable is unused until shooting. A successful step writes dest and clears the source to 0.

---

## `moveMonsters()`

`SPOT_STEPS` 10, `SPOT_STRIDE` 13, `spotxy` starts at 0. Each frame: `movePlayer()`, `moveMonsters()`, maybe flip `charBank` (jiffy bit 6), then `drawView()` which waits for vblank. No jiffy-change gate — `waitVrefresh` already paces the loop.

Each step: `spotxy = (spotxy + 13) & 1023`.

- **`M` patrol:** if falling and `(spotxy + dirDelta[DOWNDIR]) & 1023` is blank, move down. Else continue last dir (bits 4–5); if blocked, random dir (`rng = rng*17+1`, `& 3`).
- **`m` seeker:** CENGINE `doseek`. 25% of the time (`(rng>>2)&3 == 0` after an LCG step) pick a random dir. Else `diff = (spotxy - playerxy) & 1023`: **left** if `diff < 16`, **right** if `diff >= 1024-16`, **up** if `diff < 512`, else **down**. If blocked, random dir.
- **Other `TF_FALLING` ids:** try `+32` only.

On fail, still store the attempted dir on a monster.

---

## Player

`playerxy` is a 16-bit torus index **and** `playfield[playerxy] == TILE_PLAYER`. Unpack leaves the start cell blank, then `initPlayfield` writes the player tile. `tryPlayerStep` uses the same `tryMove` as monsters (dest must be blank; source cleared). `movePlayer()` runs **once per frame** with `moveMonsters()`.

`jumpptr` / `JUMP_LEN` (5):

- If **I** or joystick up is held and the cell **beneath** the player is not blank, `jumpptr = JUMP_LEN`.
- If `jumpptr > 0`: try move **up** (`dirDelta[UPDIR]`) unless blocked (antigravity).
- If `jumpptr == 0`: gravity, try move **down** (`dirDelta[DOWNDIR]`) unless blocked.
- **J** / **L** and joystick left/right apply regardless of `jumpptr`.
- After the move attempts, if `jumpptr > 0` then `jumpptr--`.

Blocked = dest nibble not blank (same as monsters). Camera: `viewxy = (playerxy - VIEW_CEN) & 1023`.

## Controls

Kernal **LSTX** `$C5` (PEEK 197): matrix code of the key currently **held**. **64** = no key.

Joystick (VIA, active low): up/down/left `$9111` bits 2/3/4, right `$9120` bit 7.

```c
#define GETKEY()     (PEEK(LSTX))   /* $C5; 64 = none */
#define GETJIFFY()   (PEEK(TIME))   /* $A2; low byte of jiffy clock */
```

| Action | Key | Scan code | Joystick |
|--------|-----|-----------|----------|
| Jump if grounded | **I** | 12 | up |
| Left | **J** | 20 | left |
| Right | **L** | 21 | right |

Charset bank flips when jiffy bit 6 changes. **M** is not “move down”; gravity handles falling.

---

## Build / run

```bat
build.bat
run.bat
```

```bat
python gen-charset.py
python gen-level.py
cl65 -O -t vic20 -C vic20-map.cfg -o mapview.prg header.s main.c
%USERPROFILE%\GTK3VICE-3.10-win64\bin\xvic.exe -memory all -autostart mapview.prg
```
