# Crunch v2.5 — VIC-20 Port Instructions

Action game by Chris Busch (1995/96). Unexpanded NTSC VIC-20 port.

**Living spec.** Update this file whenever behavior is locked or fixed.  
**Source of truth for gameplay:** `[reference/CRUNCH.ASM](reference/CRUNCH.ASM)` (+ `SPRITE.ASM`, `RAND.ASM`, `TUNESLIB.ASM`).  
**Direct conversion** — match Z80 logic; do not invent features (no bombs; CRUNCH only fires with 2nd).

---

## Target


| Item      | Value                                            |
| --------- | ------------------------------------------------ |
| Machine   | **Unexpanded** VIC-20 (no extra RAM)             |
| Video     | **NTSC**                                         |
| Language  | **6502 ca65 only** (no C)                        |
| Toolchain | `%USERPROFILE%\cc65`, config `vic20-crunch.cfg`  |
| Emulator  | `%USERPROFILE%\GTK3VICE-3.10-win64\bin\xvic.exe` |
| Build     | `build.bat` → `crunch.prg`                       |


After building report the number of bytes of free ram.

---



## Display (stock 22×23, unexpanded)

VIC-I only sees `$0000–$1FFF` (+ char ROM). User RAM is `$1000–$1FFF` (4K). There is **no** RAM at `$2000+`.


| Item       | Value                                                                                                                  |
| ---------- | ---------------------------------------------------------------------------------------------------------------------- |
| Screen     | `$1E00` (stock). **Leave** `$9002` **bit 7 set.** Do not clear it (that is a +8K/+32K trick).                          |
| Color RAM  | `$9600` (unexpanded; *not* `$9400`)                                                                                    |
| Charset    | `$1800` font `$00`–`$3F` only (2 pages). `$9005 = $FE` after fill. `$1A00` = extra code (do not copy ROM `$40`–`$5F`). |
| Tiles      | `$60`**–**`$66` live at `$1B00` (7 glyphs). Coin = PETSCII 113 at `$1B`. Never redefine A–Z (`$01`–`$1A`). Empty = `$00`. |
| BASIC stub | `$1001`, `SYS 4109` → `$100D`                                                                                          |
| Code       | `$100D`**–**`$17FF` plus `$1A00` (CODE2: rand / type-1 chase)                                                          |
| BSS        | playfield at tape buffer `$033C`; other vars `$1B40` (after tiles)                                                     |
| Maps       | nibble-packed at `$1C00` (8×64 = 512 bytes)                                                                            |


- Fill/copy glyphs **before** pointing `$9005`.
- Black border/background (`$900F = $08`: reverse on so bitmap 1 = color RAM). Cursor off (`$CC = 1`).
- **Do not** change row/column *counts* (`$9002` bits 0–6, `$9003`).



### Playfield placement (22×23 stock)


|               |                                            |
| ------------- | ------------------------------------------ |
| Map size      | 16×8 (same as TI `scrwidth` / `levelsize`) |
| Origin col    | **3**                                      |
| Origin row    | **6**                                      |
| Screen offset | `$1E00 + 6*22 + 3`                         |

Stock text grid is **22 columns × 23 rows**. Map 16×8, placed near the center:

```
Col:  00        03                18        21
Row 00 +------------------------------------+
       |          Title area                |
Row 06 |    +--------------------------+    |
       |    |      16×8 playfield      |    |
Row 13 |    +--------------------------+    |
Row 16 |  Score and lives (HUD)             |
Row 21 |  DONE (game over)                  |
Row 22 +------------------------------------+
```

When the game starts, do not blank out the title area.

Title in the top rows (left in place when a game starts): **CRUNCH** centered on row 0; **(C)1996 CHRIS BUSCH** centered on row 1. If hiscore ≠ 0, `HI:dddd` on **row 2** (indent 5). Score, lives, level on **row 16** (indent 3): `S:` + **4-digit** score, heart prefix for lives, `L:` prefix for level. Game over **DONE** centered on **row 21** (second-to-last); wipe with spaces on StartLevel. 

Have the game start on level 1.

---



## TI → VIC tile IDs

Z80 uses the **first bitmap row** as the collision ID. VIC uses **character codes** in an offscreen `playfield[128]`:


| Entity  | Z80 ID     | VIC char                                      |
| ------- | ---------- | --------------------------------------------- |
| Empty   | `$00`      | `$00`                                         |
| Tree    | `$1C`      | `$60`                                         |
| Brick   | `$FF`      | `$61`                                         |
| Coin    | `$38`      | `$1B` (PETSCII 113 ●, ROM `$51`)              |
| Player  | `$3C`      | `$62`                                         |
| Monster | `$42`      | wander `$67`–`$6A` (facing); chase `$64`      |
| Bullet  | `$08`      | `$65`                                         |
| Blood   | (bloodpic) | `$66`                                         |


Packed ROM maps in `level.s` use nibbles `0–5`; translate via table at load (as in Z80 `putobj` matching).

Glyph bitmaps: copy from `playerpic`, `monsterpic`, `monsterpic1`, `bulletpic`, `bloodpic`, `treepic`, `brickpic` in `CRUNCH.ASM`. Coin is ROM PETSCII 113, not a custom tile.

---



## Gameplay (from CRUNCH.ASM — do not invent)

1. **Player** — move on empty tiles; pick up coins → `incscore` (+1 health when low BCD byte is `$99`, i.e. 99 / 199 / 299 / …); fire in last facing dir (`firebullet`).
2. **Monsters** — see [Monster movement](#monster-movement) below.
3. **Bullet** — one shot at a time (`bulletdir == 0` to fire). Steps every **4** frames (same as player `MOVE_DELAY`); max **4** tiles then vanish (erase last cell). Clears trees and blood; bricks block. Hits monster → damage/blood. Killing monsters does **not** clear the level.
4. **Levels** — eight maps (`level1map`…`llevel4map`). `level` is **1-based** (HUD, spawn cap = **level+2**, chase). Map is `(level-1) & 7`. Load counts coins into `coinsleft`. Last coin → `inc_score` + coin chirp for each remaining monster, then overlay “next” at screen center (do **not** clear). Wait **39 VBlanks**, then StartLevel.
5. **No quit / COS cheat.** No bomb. **SPACE = fire** (same as **K**).



### VIC controls (this port)


| Action   | Key                | Notes                            |
| -------- | ------------------ | -------------------------------- |
| Up       | **I**              |                                  |
| Left     | **J**              |                                  |
| Down     | **M**              |                                  |
| Right    | **L**              |                                  |
| Fire     | **K** or **SPACE** | Last facing; while held, dirs aim only |
| Joystick | Stick + button     | OR’d with keyboard while playing |




### Monster movement

No sprite array. A monster is a wander (`$67`–`$6A`) or chase (`$64`) cell on `playfield[128]`.

Each game loop, 16 cells:

1. Look at `spot` (0–127 linear index).
2. If that cell is a monster, it tries **one** step.
3. `spot = (spot + 11) & 127`.

Empty dest → move. Blocked → sit. Dest is the player → hurt and sit. Do not walk onto coins, trees, bricks, blood, bullets, or other monsters.

| Type | Char | Facing |
|------|------|--------|
| 0 wander  |red `$67` up `$68` down `$69` left `$6A` right | cell encodes facing; walk that cardinal until blocked, then pick a new facing and sit |
| 1 chase |purple `$64` | if coinsleft>level or (jiffy $A2 & 16)!=0 then random step else chase: cardinal toward player (longer axis; horizontal on a tie) |

Blit draws wander as `$63` (same pic). Bullet: wander → `$64`; `$64` → blood.

Note: jiffy $A0 is most significant and $A2 is least

---




## Main loop (mandatory)

Engine work during display time; **only** poke Screen/Color RAM in vertical blank. World state lives in `playfield[128]`, not screen RAM.

```
InitGraphics
SilenceVic
hiscore = 0
randvar = 0

Intro:
  level = 1
  LoadLevel
  ClearScreen
  DrawTitle
  DrawHiscore             ; row 2, indent 5; blank if hiscore==0
  WaitVBlank
  BlitPlayfield
  WaitJoystickFireOrKey                 ; $C5, do not poke $9122

StartGame:
  SilenceVic
  score = 9999 BCD        ; first StartLevel incscore → 0000
  health = 5
  level = 1

StartLevel:
  LoadLevel((level-1) & 7)
  IncScore
  InitSprites             ; place player
  ClearOver               ; spaces over row-21 “done”
  DrawHiscore
  DrawHud                 ; indent 3; do not clear — keep title
  UpdateHud
  WaitVBlank
  BlitPlayfield

GameLoop:
  UpdatePlayer            ; input I/J/K/L/M/SPACE + stick; fire aims without walking
  check spawn spot and if empty and created less than level+2 monsters then create monster in that spot
  UpdateMonsters          ; 16 cells: spot = (spot+11)&127

  UpdateBullet            ; every 4 frames; max 4 tiles
  WaitVBlank              ; poll $9004
  BlitPlayfield           ; 16×8 → screen + color at col 3, row 6
  UpdateHud
  PlayAudioFrame
  if GAMEOVER:   CheckHiscore; DrawGameOver (row 21 center, purple); wait 60 jiffies; WaitJoystickFireOrKey; goto Intro
  if NEXTLEVEL:  DrawNewLevel (center, no clear); wait 39 VBlanks; goto StartLevel
  goto GameLoop
```

---



## Audio (VIC-I)

No original TunesLib. Three short VIC-I cues only: coin = soprano chirp `$900C=$E8`; kill = `$900D` noise; hurt = `$900A` bass.

No intro song. No next level sound.

---



## Repo layout

```text
reference/     Z80 originals (read-only spec)
src/           ca65 6502 port
SPEC.md        THIS FILE — update as we go
build.bat      → crunch.prg
```

---



## Progress log


| Date       | Status                                                                                                                                                                                                                    |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-09-04 | Restart: clean `instructions.md`; `src/` wiped; rebuild from CRUNCH.ASM + this loop/layout.                                                                                                                               |
| 2026-09-04 | **Fix static:** charset `$1C00` + `$9005=$47` (VIC cannot see `$2000`).                                                                                                                                                   |
| 2026-09-04 | **Fix RUN→BASIC:** stub at `$1201` + JMP `$2000` startup; code above charset hole.                                                                                                                                        |
| 2026-09-07 | **Retarget unexpanded:** stock screen `$1E00`, color `$9600`, charset `$1800` / `$9005=$FE`, stub `$1001`, nibble maps at `$1C00`. Do not clear `$9002` bit 7. Run VICE **without** `-memory all`.                        |
| 2026-09-07 | **Fix no-move:** play used raw `$9120` without `$9122` DDR, so I/J/M/L never scanned. In-game input now uses kernal SCNKEY / `$C5` (same as title).                                                                       |
| 2026-09-07 | **Fix diagonal / off-map:** `probe` stored `map_get`’s index in `tx` (X is clobbered). Now uses `hit_x`/`hit_y`. Ignore floating joystick (UP+DOWN both active).                                                          |
| 2026-09-07 | **Fix inverted colors:** `$900F=0` (black paper, reverse off). RAM charset 1=ink / 0=paper. EOR ROM copy; invert tile bitmaps. Color RAM bits 0–2 only.                                                                   |
| 2026-09-07 | **Playtest retune:** monster/bullet gate `$0700` → **12** NTSC frames (Z80 loop was not VBlank). Coin pickup plays a VIC soprano blip (`coinsong`).                                                                       |
| 2026-09-07 | **Fix shooting:** K/SPACE scanned on VIA (not only `$C5`, so fire works while moving). Fire while `bulletdir==0`. Bullet steps every frame; monsters stay on the 12-frame gate.                                           |
| 2026-09-07 | **Fix no-start:** `$9122=$FF` fire scan hung VIA#2 (IEC). Reverted to kernal `$C5` for keys. Title waits on `$C5` only. Fire with **K** (works with move) or **SPACE** (alone).                                           |
| 2026-09-07 | Bullets **clear trees and blood** (bricks still block). Coin SFX is a 2-frame tick. Monster death uses a short **noise** burst (`$900D`), not the coin beep.                                                              |
| 2026-09-07 | **Q** during play: hi-score check, quit beep, wait for key-up, **intro title**. (Unexpanded ROM is full; quit cue reuses the intro beep.)                                                                                 |
| 2026-09-07 | **Type 1 chase:** 2-hit monsters (`$65`) steer each step: `rand()&3==0` → random facing; else cardinal toward player (longer axis). Type 0 still wall-bounces. Rand/chase live at `$1A00`; font copy is `$00`–`$3F` only. |
| 2026-09-07 | **Board-only monsters:** dropped 5×21 sprite arrays. Scan one row per frame; `rowtoscan=(rowtoscan+3)&7`. Type 0 dir from jiffy `$A1`; type 1 random/chase from `$A2` bit 0. First hit on `$65` → `$64`.                  |
| 2026-09-07 | **Next level = last coin.** `load_level` counts `$62` into `coinsleft`. Pickup decrements; zero → next level. Monster kills no longer clear the map.                                                                      |
| 2026-09-07 | **Bullet:** max **4** tiles; moves every **4** NTSC frames (was every VBlank).                                                                                                                                            |
| 2026-09-07 | **Fix leftover bullet:** range expiry now erases the last cell (`stop_bullet`).                                                                                                                                           |
| 2026-09-07 | **Type 0 blocked:** wander (`$A1&3`) then one random step if that cell is blocked.                                                                                                                                        |
| 2026-09-07 | **Fix type-1 chase:** `$A2&1` was stuck (row period 8). Use `$A2&8`. `chase_player` now `sec` before abs. New level waits 30 jiffies after the message.                                                                   |
| 2026-09-07 | **Monster scan:** 16 cells/frame, `spot=(spot+11)&127`. Type 0 blocked → chase logic. HUD on row 16. Level++ only on next-level, not StartLevel. |
| 2026-09-07 | **Fix next-level hang:** `sei` so `$A2` never ticks. Overlay “next” at center; wait 39 VBlanks; no key, no clear. |
| 2026-09-07 | **`cli` after charset init** so kernal IRQ runs and jiffy `$A0–$A2` counts. |
| 2026-09-07 | **Keep title:** StartLevel does not `ClearScreen`. Hurt plays a short bass `$900A`. |
| 2026-09-07 | **Type 1:** chase when `coinsleft < level`, else random. Type 0 blocked → random step. |
| 2026-09-07 | **Drip spawn:** InitSprites places player only. Each frame, if `M` is empty and `made < level`, create one monster there. |
| 2026-09-08 | HUD `S:` / ♥ / `L:` on row 16. StartGame `level=1`. Hit `$64`→`$65`, `$65`→blood. |
| 2026-09-08 | No next-level sound: `silence_vic` before the “next” overlay. |
| 2026-09-08 | 4-digit BCD score. Title: centered CRUNCH / (C)1996 CHRIS BUSCH. |
| 2026-09-08 | Coin chirp lowered: `$900C` `$FC` → `$E8`. |
| 2026-09-08 | Level is 1-based: intro + StartGame `level=1` loads `level1map` (`(level-1)&7`). |
| 2026-09-08 | Game over: “over” on 3rd line, purple; wait 120 jiffies, then key → StartGame. |
| 2026-09-08 | OVER centered row 21 (wipe on restart). HI:dddd row 2 indent 5 if hiscore≠0. S: indent 3. |
| 2026-09-08 | Renamed living spec `instructions.md` → `SPEC.md`; plan brief → `.cursor/plans/port-plan.md`. |
| 2026-09-08 | Type 1: random if `coinsleft > level` or `$A2&16`; else chase. |
| 2026-09-08 | Tiles match CRUNCH.ASM (1=ink); one scanline per source line. |
| 2026-09-08 | Stop EOR of ROM charset/heart; 1=ink matches tiles. |
| 2026-09-08 | `$900F=$08` reverse: bitmap 1 = color RAM, 0 = black. No intro song. |
| 2026-09-08 | Coin = PETSCII 113 (ROM ● at `$1B`); custom coin tile dropped. |
| 2026-09-08 | Wander facing in cell `$67`–`$6A`; straight until bump, then turn. |
| 2026-09-08 | Spawn cap `level+1` (level 1 starts with 2 monsters). |
| 2026-09-08 | Spawn cap `level+2`. Fire updates `pdir` but does not walk. |
| 2026-09-08 | Game over text **DONE** (was OVER). |
| 2026-09-08 | `rand` adds VIC `$9004` raster and `$900D` noise into `randvar`. |
| 2026-09-08 | Restore `$9122` after stick read so SPACE cannot ghost as Q (quit). |
| 2026-09-08 | `sei` around stick VIA + SCNKEY so jiffy cannot smash `$9122`/`$9120`. |
| 2026-09-10 | Folded leftover brief bits into this file (screen diagram, one-shot bullet / trees+blood, chase longer-axis). Cleared `.cursor/plans/port-plan.md`. |
| 2026-09-10 | Dropped Q/quit. Intro and game over: `WaitJoystickFireOrKey`. Game over delay **60** jiffies. |
| 2026-09-10 | Stick fire sampled before up+down float skip so title/game-over wait sees the button. |
| 2026-09-10 | Playfield origin row **6** (rows 6–13). |
| 2026-09-10 | Spawn: `made < level+2` (`beq`/`bcc`); level 1 has 3 monsters. |
| 2026-09-10 | `inc_score` no longer `inc randvar` (entropy is raster/noise in `rand`). |
| 2026-09-10 | Dropped `score_tick`. +1 health when score low byte is BCD `$99`. |
| 2026-09-10 | Last coin: `inc_score` + `play_coin` per remaining monster, then next level. |
| 2026-09-10 | Bonus chirps wait 3 VBlanks each so they are audible. |




### Current milestone

- [x] Scaffold `src/` + build producing `crunch.prg`
- [x] Init graphics (charset after fill; centered empty field)
- [x] Load level maps into `playfield[]` + VBlank blit
- [x] Player move (I/J/L/M) + coin pickup
- [x] Fire (K/SPACE) + bullet
- [x] Monsters (board scan, one row/frame)
- [x] Game over / next level / hi-score (basic)
- [x] Unexpanded playtest (VICE, no extra memory)



### Notes locked this session

- Modules: `main gfx map level input player sound` (no separate chars/screen).
- Frame gate retuned after playtest: **12** NTSC frames (was Z80 `$0700` without VBlank).
- SPACE = fire (not bomb).
- Unexpanded only — no `$2000+` code, no `$9400` color, no `$9002` bit7 clear.
- `cli` after `init_graphics` so jiffy `$A0–$A2` counts. Joystick: `sei`, clear `$9122` bit 7, read stick, restore DDRB, SCNKEY, then `cli` (IRQ between poke `$9122` and peek `$9120` smashes the read / ghosts SPACE as Q).
- Drip spawn: `made < level+2` (level 1 starts with 3). Type 0: `$67`–`$6A` encode facing; straight until bump, then new facing. Type 1: random if `coinsleft > level` or `$A2&16`; else chase.
- No monster arrays. Each frame: 16 cells, `spot = (spot+11) & 127`.
- HUD indent 3: `S:dddd ♥n L:dd` on row 16. HI:dddd on row 2 indent 5 if hiscore≠0. DONE centered on row 21.
- Playfield origin col 3, row 6 (blit 16×8).
- No Q/quit. Intro and game over: `wait_fire_or_key` (stick fire on `$9111` even if up+down float skip, or any `$C5` key; wait until released). Game over: 60 jiffies, then that wait → Intro.
- `level` is 1-based. Map index is `(level-1) & 7`. Intro and first game are level 1.
- Level clear is **all coins gone**, not all monsters dead.
- Bullet range **4** tiles; step delay **4** frames.
- +1 health when BCD score lands on `$99` (99, 199, 299, …). No `score_tick`.
- Last coin: bonus `inc_score` + a coin chirp (3 VBlanks each) for each live monster, then next level.

---



## Build / run

```bat
build.bat
run.bat
```

`run.bat` starts NTSC unexpanded VICE (`xvic -ntsc -autostart crunch.prg`).