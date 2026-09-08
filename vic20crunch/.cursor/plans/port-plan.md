# Crunch v2.5 — VIC-20 port spec

Action game by Chris Busch (1995/96). This is the **unexpanded NTSC VIC-20** port. Living spec: [`SPEC.md`](../../SPEC.md). Gameplay truth for the original: [`reference/CRUNCH.ASM`](../../reference/CRUNCH.ASM).

---

## Target

| Item | Value |
|------|--------|
| Machine | Unexpanded VIC-20 |
| Video | NTSC, stock 22×23 |
| Language | 6502 ca65 only (no C) |
| Build | `build.bat` → `crunch.prg` |

---

## Screen

Stock text grid is **22 columns × 23 rows**. The map is **16×8**, placed near the center:

| | |
|--|--|
| Origin column | 3 |
| Origin row | 7 |
| Screen address | `$1E00 + 7*22 + 3` |

```
Col:  00        03                18        21
Row 00 +------------------------------------+
       |          Title area                |
Row 07 |    +--------------------------+    |
       |    |      16×8 playfield      |    |
Row 14 |    +--------------------------+    |
       |  Score and lives shown here        |
Row 22 +------------------------------------+
```

When the game starts, do not blank out the title area.


Do not change `$9002` column count or bit 7. Color RAM is `$9600`. Charset at `$1800` (glyphs `$00`–`$3F` only). Tiles `$60`–`$67` at `$1B00`.

---

## Tiles

| Entity | Z80 ID | VIC char |
|--------|--------|----------|
| Empty | `$00` | `$00` |
| Tree | `$1C` | `$60` |
| Brick | `$FF` | `$61` |
| Coin | `$38` | `$62` |
| Player | `$3C` | `$63` |
| Monster type 0 | `$42` | `$64` |
| Monster type 1 | `$42` | `$65` |
| Bullet | `$08` | `$66` |
| Blood | bloodpic | `$67` |

---

## Monster movement

There is **no monster array**. A monster is a `$64` or `$65` cell on `playfield[128]`.

Update monsters logic:

0. loop 0 to 16:
1.   look at `spotToScan`.
2.   If the cell is a monster, that monster tries **one** step.
3.   `spotToScan = (spotToScan + 11) & 127`.

If the destination is empty, move there. If blocked, **sit**. If the destination is the player, **hurt** and sit. Do not walk onto coins, trees, bricks, blood, bullets, or other monsters.

### Type 0 (`$64`) — wander

Facing = `(jiffy $A1 & 3) + 1` (1=up, 2=down, 3=left, 4=right). Same facing for every type-0 on that row that frame. If the path is blocked, try a random step.

### Type 1 (`$65`) — chase

If `coinsleft < level`: cardinal toward the player (longer axis; horizontal on a tie).
Else: random facing (`rand >> 2 & 3 + 1`).

### Hits

- Bullet on `$65` → becomes `$64` (second hit needed).
- Bullet on `$64` → blood. Killing monsters does **not** clear the level.

---

## Other gameplay

1. **Player** — move on empty tiles; coins score (and sometimes +health); fire in last facing direction.
2. **Bullet** — one shot at a time; step every 4 frames; max 4 tiles; then vanish (erase last cell). Clears trees and blood; bricks block.
3. **Level** — eight maps, `level & 7`. Count coins at load. Last coin → next level. Do not clear screen, instead place next level message on the center of the screen. Wait 39 jiffies and begin next level.
4. **Q** — quit to title. **SPACE** is fire, not a bomb.

### Controls

| Action | Key |
|--------|-----|
| Up | I |
| Left | J |
| Down | M |
| Right | L |
| Fire | K or SPACE |
| Quit | Q |
| Joystick | OR’d with keys while playing |

---

## Main loop

Engine work during display; only poke screen/color RAM in vertical blank.

```
InitGraphics
SilenceVic
hiscore = 0
randvar = 0

Intro:
  level = 2
  LoadLevel
  ClearScreen
  DrawTitle
  WaitVBlank
  BlitPlayfield
  PlayIntroSong
  WaitKey                 ; $C5, do not poke $9122

StartGame:
  SilenceVic
  score = $FF             ; first StartLevel incscore → 0
  health = 5

StartLevel:
  LoadLevel(level & 7)
  IncScore
  InitSprites             ; player + monsters on empty cells
  DrawHud                 ; do not clear — keep title
  UpdateHud
  WaitVBlank
  BlitPlayfield

GameLoop:
  UpdatePlayer            ; input I/J/K/L/M/SPACE + stick; move / fire
  UpdateMonsters          ; see above
  UpdateBullet            ; every 4 frames; max 4 tiles
  WaitVBlank              ; poll $9004
  BlitPlayfield           ; 16×8 → screen + color at col 3, row 7
  UpdateHud
  PlayAudioFrame
  if QUIT:       CheckHiscore; beep; wait key-up; goto Intro
  if GAMEOVER:   CheckHiscore; DrawGameOver; wait key; goto Intro
  if NEXTLEVEL:  DrawNewLevel (center, no clear); wait 39 VBlanks; goto StartLevel
  goto GameLoop
```

---

## Audio (VIC-I)

Since we are tight on memory, we will not use any sound from the original. 

Let's use short notes for these events:
1. getting a coin - a chirp
2. killing a monster - a sh sound
3. getting hurt - a bass sound

