# Scrolls — game logic

Rules for this port as implemented in VIC-20 [`main.c`](main.c). If this file and the C disagree, **the C wins** — update this file.

Do not copy browser UI chrome. VIC display, addresses, and build live in [`spec.md`](spec.md).

---

## Goal

Find the **scroll**. Touching it scores, loads the next map, and raises difficulty. Maps loop after the last one in the pack; the level number and monster pressure keep climbing.

Beware monsters and fire. You have a sling shot. One **key** at a time; a key opens one **door**. The player cannot drop bombs.

---

## World

- Map is **32×32** cells = **1024** cells.
- Addressing is a **1-D ring**: index `xy` is `0…1023`, wrap with `xy & 1023`.
- Neighbors: right `+1`, left `-1`, down `+32`, up `-32`.
- Walking off an edge wraps on that ring (torus).
- Sprites / tiles are **8×8** pixels, **1-bit** pictures (two banks on some graphics). Each graphic is one solid tint.

---

## Tiles, flags, map letters, colors

| Behavior  | Meaning |
| --------- | ------- |
| Solid     | Player cannot enter. Monsters using `tryMove` also refuse any **non-blank** dest. |
| Shootable | Shot may destroy or transform it. |
| Falling   | Flag is stored on the tile. Gravity drop in `moveMonsters` is commented out. Patrols do not use it for AI. |

**Player, patrol, and seeker** are the monster-family contacts (bump / shot). **Empty, player, patrol, seeker, coin, scroll, fire, and bomb** use two picture banks. Cloud and later graphics are a single frame.

Unknown letters are not valid map cells. Character color RAM is **0–7** only.

| Map | Flags | Role | Char 0–7 (this port) |
| --- | ----- | ---- | -------------------- |
| `.` | none | empty | Black |
| `X` | Solid | player start (`TILE_PLAYER`) | Yellow |
| `P` | Solid | fellow human (`TILE_PLAYER`) | Yellow |
| `M` | Solid, shootable, **falling** | patrol (map and spawned; both walk) | Purple |
| `m` | Solid, shootable | seeker (map and spawned; both walk) | Red |
| `c` | Falling | coin | Yellow |
| `s` | Solid | scroll | White |
| `f` | Solid | fire | Blue |
| `F` | Shootable, falling | bomb | Cyan |
| `B` | Solid | cloud / bullet picture | White |
| `S` | Falling | stain | Red |
| `t` | Solid, shootable, falling | tree | Green |
| `b` | Solid | brick (not shootable) | White |
| `W` | Solid, shootable | wall | White |
| `D` | Solid, falling | door | Red |
| `k` | Solid | key | Yellow |

**Shared bitmap:** `b`, `W`, and tree draw from pack pictures; wall `W` uses the brick bitmap (`#b`). Tint tells brick and wall apart: white brick, white wall, green tree.

**Playfield background:** Black.  
**HUD:** `S:` score, heart, lives, `L:` level (`liveLevel & 7`), then the key picture if carrying a key (else a space).

`hurtPlayer` in `engine.h` skips if `hurtDur` is set. On hurt, `hurtDur = 10` and the player glyph is purple until it counts down.

---

## Score, lives, levels

- **Lives** start at **5**. Cap **9**. Zero → game over banner, then a new run starts.
- **Score** is packed 4-digit BCD in 16 bits, four HUD digits, cap `$9999`.
- **Level** is `liveLevel`: 1-based, **never wraps**. Each scroll increments the map index and `liveLevel`. After the last map, load `mapIndex % mapCount`. HUD shows `liveLevel & 7`.
- Extra life when the last two BCD digits are 50 or 99 (50, 99, 150, 199, …) and lives < 9 (max 9).
- A new run starts with **score 0**, lives 5, map index 0.

| Event | Δ score |
| ----- | ------- |
| `startLevel` (each map load **after** the first) | +1 |
| Touch coin | +1 |
| Kill a seeker (shot) | +1 |
| Destroy a bomb (shot) | +1 |
| Touch scroll | +1, then `startLevel` (+1 more) |

Shooting a wall or tree does **not** score. It still becomes a stain if shootable (`playBash`).

High score is kept **in RAM** (cleared on reset). It is recorded from `score` only when lives hit 0, then drawn as `HI:0000` on `HISCORE_ROW`.

---

## Controls

Keys and joystick may be used together. **I/J/L/M** walk and **Shift** is fire (the VIC reports one letter key at a time). Bottom row still prints `Joy or Shift C= M,.`.

| Action | Input | Effect |
| ------ | ----- | ------ |
| Left | Joystick left or `J` | Walk left **unless** fire is freshly held. Set facing. |
| Right | Joystick right or `L` | Same, to the right. |
| Up | Joystick up or `I` | Walk up unless fire is freshly held. Set facing. |
| Down | Joystick down or `M` | Walk down unless fire is freshly held. Set facing. |
| Shoot | Joystick fire or Shift | Face stays; no walk until `fireHolds > 3`. Spawn one bullet if none in flight. |
| Quit | `Q` | End the run; outer loop starts another run. |
| Pause | `P` | Silence; `Paused` below the HUD until **P** is pressed again. |
| Level jump | `S` | `jumpLevels`: prompt on the HUD row, then two keypresses. |

There is **no** bomb-drop control.

After “New Level!” the next map loads after **12** video frames (no extra key to dismiss). After game over, **12** frames then a new run. Title wait is `Press key!` then fire or any key.

---

## Movement and collision

**Player** uses `movePlayerFlat`: dest = `wrap(xy + delta)`.

- If dest is **solid**, do not move.
- Else occupy dest, leave blank behind.

Hits use the dest cell even when the move is refused (solid).

**Monsters** use `destBlank` / `tryMove` to walk: dest must be **blank** (nibble 0). They do not occupy a solid `TILE_PLAYER` cell. If dest is `TILE_PLAYER` (the hero or a map `P` human), `hurtPlayer`. They do not use a shared `moveSpr`.

---

## Player

- Occupies the map as the **player** (solid).
- **Every other game step** (`frame` bit 0).

### Walk

No `jumpptr` path in play. Four directions only. Holding fire for the first three ticks blocks walking; after that, walk and fire together.

### Bumping a monster

If the dest is a monster, **lose a life**. The monster stays.

### Fire

Move refused, hit = fire: lose a life, stain on the **current** cell, `playerxy` = spawn if still alive. You do not enter the fire cell.

### Bomb (walk-in)

Bombs are **not** solid. Walking onto one: lose a life. The player cannot drop bombs.

### Coin

Not solid. Walking on it: +1 score (`playCoin`).

### Key / door

Both solid.

- Key, no key held: set has-key, erase the key.
- Key, already carrying: ignore.
- Door, have key: clear has-key, erase the door.
- Door, no key: blocked.

**One key at a time.**

### Scroll

Solid. Hit: erase, +1 score, increment map index, set pending level, show “New Level!”. After 12 frames, `startLevel`.

### Brick / wall / tree

Solid. Walls and trees are shootable (shot → stain). Bricks (`b`) are not.

---

## Bullet

- At most one. Range **6** minus `fireHolds`. Picture and color same as `B`.
- Spawn if none in flight. Direction = facing. Start on the player cell; first step leaves the player.
- Moves **every** game step.
- Non-blank dest: `shootCell` (unless dest is the player), then despawn.
- Always rewrite the player onto the player cell after the bullet step.

Patrol → seeker (gets mad). Seeker → splat (`playKill`, +1). Stain `S` → blank. Other shootable → stain. Extra +1 if bomb. Tree/wall also `playBash`.

---

## Bombs

The player **cannot drop bombs**. Map `F` tiles (and any engine-spawned `F`) wander with `randDir` + `tryMove`. Contact hurts. Shooting a bomb stains it, scores, and may call `putTileRandomly(TILE_BOMB)` — that is not a player action.

---

## Monsters

Map `M` / `m` and spawned `M` / `m` use the **same** walker.

### Spawn

Each game step, if `monsterCount < (liveLevel << 2)`, try **one** spawn.

Kind from the count **before** the spawn: `count & 3` → patrol `M`, else seeker `m`. Scrolls also drops a tree on a blank cell.

`xy = (playerxy + 256 + rand512()) & 1023` where `rand512` is `rand16() & 511` (0…511). If not blank, skip.

Packed: id, dir down. `monsterCount++`.

### Step (every game step)

Probe up to **100** cells with stride **239** (`spotxy` persists), stopping if the raster hits 123 or 126.

1. **Patrol:** last dir. If dest not blank and not the player, `randDir()`.
2. **Seeker:** `seekerDir` — `diff = (pos - playerxy) & 1023`: left if `diff < 16`, right if `diff >= 1024-16`, up if `diff < 512`, else down. No wander branch.
3. Dest is the player → `hurtPlayer`, stay on source, store `id | (dir << 4)`. Else `tryMove` onto blank with that packed byte. If blocked, write that packed byte on the source cell.

### Combat summary

| Situation | Result |
| --------- | ------ |
| Monster dest is the player | Monster does not enter; `hurtPlayer` |
| You walk into monster | You hurt; `playHurt`; monster lives |
| Shot hits patrol | Patrol becomes a seeker |
| Shot hits seeker | Seeker dies, +1, stain, `playKill` |
| You walk onto bomb | You hurt; `playHurt` |
| Shot hits bomb | Bomb gone, +1, stain, `playKill` |

---

## HUD (play)

One blank row below the viewport, then centered `S:0000` heart lives `L:` (`liveLevel & 7`), then a key tile if `hasKey`. Two rows below the HUD (`HISCORE_ROW`): centered `HI:0000`. New Level / Game Over sit on the row between them.

---

## Title / overlays

**Title lines** stay up for the run: row 0 `Scrolls(c)1996 CBusch`, row 1 LVL `$S`, row 2 LVL `$A`. `startRun` prints `Press key!` and waits for fire or a key.

**New Level!** on the row below the HUD after a scroll; map advances after 12 frames, then that line is cleared.

**Game Over!** on the row below the HUD when lives hit 0; 12 frames, that line is cleared, then a new run.

---

## Sounds

| Call | When |
| ---- | ---- |
| `playCoin` | Pick up a coin, key, door, or scroll (`sfxDur` 1) |
| `playHurt` | Lose a life (`sfxDur` 2) |
| `playKill` | Seeker dies by shot, or a bomb is shot (`sfxDur` 2) |
| `playBash` | Shot hits a tree or wall (`sfxDur` 2) |
| `playEmptyClick` | Fire held at max without a new bullet (`sfxDur` 1) |

Shooting, door, key, scroll, extra life, and game over are silent unless they also match a row above.

---

## Pictures

Each pack defines 8×8 bitmaps `#X0` and `#X1` for letters `. P M m c s f F B S t b D k`. Bank 0 is the default; bank 1 is the alternate frame. Wall `W` uses the brick bitmap.

---

## Summary

- Lives at start: 5
- Extra life: last two BCD digits are 50 or 99 (50, 99, 150, 199, …)
- Overhead 4-way walk (`movePlayerFlat` every other step)
- Map `M` and `m` walk via the rotary scan (stride 239)
- Shot patrol gets mad (becomes seeker); shot seeker dies
- Player cannot drop bombs
- Scroll: pending flag, 12 frames, then next map
- Spawn: first map `X` / `playerStart` (`P` is `TILE_PLAYER` but not spawn)
- Seeker: `seekerDir` (16-cell left/right window)
- Timing: draw, then `gameStep` (monster scan stops at raster 123/126)
- Colors: table above

---
