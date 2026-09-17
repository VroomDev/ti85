# Caves — game logic

Rules for this port as implemented in VIC-20 [`main.c`](main.c). If this file and the C disagree, **the C wins** — update this file.

Do not copy browser UI chrome. VIC display, addresses, and build live in [`spec.md`](spec.md).

---

## Goal

Find the **scroll** (artifact). Touching it scores, loads the next map, and raises difficulty. Maps loop after the last one in the pack; the level number and monster pressure keep climbing.

Beware monsters and lava. You have a pellet gun and a jump. One **key** at a time; a key opens one **door**.

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
| Solid     | `moveSpr` cannot enter. Monsters using `tryMove` also refuse any **non-blank** dest. |
| Shootable | Shot destroys it (monster splat, else stain). |
| Falling   | When the monster spot cursor lands on it (and it is not already handled as `M`/`m`), drop one cell if below is blank. Patrols also use falling for AI gravity. |

**Player, patrol, and seeker** are the monster-family contacts (bump / stomp / shot). **Empty, player, patrol, seeker, coin, scroll, lava, and bomb** use two picture banks. Cloud and later graphics are a single frame.

Unknown letters are not valid map cells. Character color RAM is **0–7** only.

| Map | Flags | Role | Char 0–7 (this port) |
| --- | ----- | ---- | -------------------- |
| `.` | none | empty | Black |
| *(actor)* | Solid | player | Yellow |
| `M` | Solid, shootable, **falling** | patrol (map and spawned; both walk) | Purple |
| `m` | Solid, shootable | seeker (map and spawned; both walk) | Red |
| `c` | Falling | coin | Yellow |
| `s` | Solid | scroll | White |
| `f` | Solid | lava | Red |
| `F` | Shootable, falling | bomb | Cyan |
| `B` | Solid | cloud / bullet picture | White |
| `S` | Falling | stain | Red |
| `t` | Solid, shootable, falling | falling wall | Green |
| `b` | Solid | brick (not shootable) | White |
| `W` | Solid, shootable | wall | White |
| `D` | Solid, falling | door | Red |
| `k` | Solid | key | Yellow |

**Shared bitmap:** `b`, `W`, and falling wall draw the brick picture (`#b`). Tint tells them apart in this port: white brick, white wall, green falling wall.

**Playfield background:** Black.  
**HUD:** `S:` score, heart, lives, `L:` level, then the key picture if carrying a key (else a space).

The player cannot be hurt if `sfxDur` is not zero. When a sound plays, `sfxDur` is set; each game loop decrements it; at 0 the VIC is silenced. On hurt, `hurtDur = 3` and the player glyph is purple until it counts down.

---

## Score, lives, levels

- **Lives** start at **5**. Cap **9**. Zero → game over banner, then a new run starts.
- **Score** is packed 4-digit BCD in 16 bits, four HUD digits, cap `$9999`.
- **Level** is `liveLevel`: 1-based, **never wraps**. Each scroll increments the map index and `liveLevel`. After the last map, load `mapIndex % mapCount`.
- Extra life when the last two BCD digits are 50 (50, 150, 250, …) and lives < 9 (max 9). HUD draws `lives` as one digit. Score is packed 4-digit BCD.
- A new run starts with **score 0**, lives 5, map index 0.

| Event | Δ score |
| ----- | ------- |
| `startLevel` (each map load **after** the first) | +1 |
| Touch coin | +1 |
| Kill a monster (shot or stomp) | +1 |
| Destroy a bomb (shot or stomp) | +1 |
| Touch scroll | +1, then `startLevel` (+1 more) |

Shooting a wall or falling wall (`t`) does **not** score. It still becomes a stain if shootable.

High score is kept **in RAM** (cleared on reset). It is recorded from `score` only when lives hit 0, then drawn as `HI:0000` on `HISCORE_ROW`.

---

## Controls

Keys and joystick may be used together.

| Action | Input | Effect |
| ------ | ----- | ------ |
| Left | Joystick left or `J` | Walk left **unless** shooting. Set facing. |
| Right | Joystick right or `L` | Same, to the right. |
| Up / jump | Joystick up or `I` | Set facing up. If grounded (`jumpptr` path), jump. |
| Down | Joystick down or `M` | Set facing down. If **not** shooting, force vertical down (fast fall). On a cloud, Down + not shooting starts a **high jump** (`jumpptr = 20`). |
| Shoot | Joystick fire or `K` | Face stays; no walk. Spawn one bullet if none in flight. |
| Quit | `Q` | End the run; outer loop starts another run. |
| Cheat scroll | `S` | Place a scroll in the cell to the right of the player, overwriting that cell. |

After “New Level!” the next map loads after **12** video frames (no extra key to dismiss). After game over, **12** frames then a new run (no title wait).

---

## Movement and collision

**Player** uses `moveSpr`: dest = `wrap(xy + delta)`.

- If dest is **solid**, do not move. Return the dest tile (the “hit”).
- Else occupy dest, leave blank behind, return the old dest tile.

The player builds `hl` (vertical then optional ±1). Horizontal is added only if the **combined** cell is not brick / wall / falling wall. Occupy dest if `hl != 0` and dest is not solid.

Player collision uses the dest cell even when the move is refused (solid).

**Monsters** use `destBlank` / `tryMove` to walk: dest must be **blank** (nibble 0). They do not occupy a solid player cell. If dest is the player, `hurtPlayer` (same i-frame as bump: skip while `sfxDur` is set). They do not use `moveSpr`.

---

## Player

- Occupies the map as the **player** (solid).
- **Every game step** (one step per vblank), not every other frame.

### Jump and gravity

`jumpptr` is remaining upward force. A grounded jump sets `jumpptr = JUMP_LEN - 1`.

- If `jumpptr !== 0`: decrement it, vertical = up.
- Else look at the cell **below**:
  - blank **or lava** → vertical = down (lava is not a floor).
  - cloud (`B`) and Down held and not shooting → `jumpptr = 20` (high jump).
  - jump action → `jumpptr = JUMP_LEN - 1`, vertical = up.
- Down + not shooting overwrites `hl` to down.

Left/right (not shooting): if `(playerxy + hl ± 1)` is not `TILE_BRICK` / `TILE_WALL` / `TILE_TREE`, add that delta to `hl`.

Hitting **brick, wall, or falling wall** **while** `jumpptr !== 0` decrements `jumpptr` again.

### Stomp (before walking this player step)

If `jumpptr === 0` and the cell **immediately below** is:

- a monster (`M`/`m`) → kill it (score +1, stain, `playKill`). Player stays above.
- a bomb → score +1, stain. Walking **into** a bomb still hurts.

Stomp does **not** run during the upward jump (`jumpptr !== 0`).

### Bumping a monster

If the attempted dest is a monster and the move is refused, **lose a life**. The monster stays. Stomp is checked first.

### Lava

Move refused, hit = fire: lose a life, stain on the **current** cell, `playerxy` = spawn if still alive. You do not enter the lava cell.

### Bomb (walk-in)

Bombs are **not** solid. Walking onto one: lose a life (player overwrites the bomb). Stomp/shoot as above.

### Coin

Not solid. Walking on it: +1 score (`playCoin`). Coins fall when the spot cursor hits them and below is blank.

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

- At most one. Range **4**. Picture and color same as cloud `B`.
- Spawn if none in flight. Direction = facing. Start on the player cell; first step leaves the player.
- Moves **every** game step.
- Non-blank dest: `shootCell` if shootable (or dest is stain `S`), then despawn. Extra +1 if bomb. Stain is erased to blank, not replaced with another stain.
- Always rewrite the player onto the player cell after the bullet step.

Shootable non-monster → stain. Stain `S` → blank. Monster → splat (`playKill`, +1, decrement `monsterCount` only if `PF_SPAWNED` still set).

---

## Falling

There is **no** separate `blockFall` pass. Coins, stains, falling walls, doors (and any other `TF_FALLING` tile that is not processed as `M`/`m`/`F`) drop when `moveMonsters` probes that cell and the cell below is blank. **Bombs** drop if below is blank; if not, they chirp and try a random left/right step.

---

## Monsters

Map `M` / `m` and spawned `M` / `m` use the **same** walker.

### Spawn

Each game step, if `monsterCount < (liveLevel << 2)`, try **one** spawn.

Kind from the count **before** the spawn: even → seeker `m`, odd → patrol `M`.

`xy = (playerxy + 256 + rand512()) & 1023` where `rand512` is `rand16() & 511` (0…511). `rand16` is `rng16 = rng16*17+1` (16-bit, period 65536). If not blank, skip.

Packed: id, dir down, `PF_SPAWNED`. `monsterCount++`.

### Step (every game step)

Probe **100** cells with stride **13** (`spotxy` persists).

1. **Patrol:** if falling and below blank, dir = down. Else last dir. If last dir is up/down or dest not blank, pick left or right only. Blank beside them (a ledge) is a legal step.
2. **Seeker:** `seekerDir` — about 25% random (`(rng >> 2) & 3 == 0` after `rng = rng*17+1`). Else `diff = (pos - playerxy) & 1023`: left if `diff < 16`, right if `diff >= 1024-16`, up if `diff < 512`, else down.
3. Dest is the player → `hurtPlayer`, stay on source, store `id | (dir << 4)`. Else `tryMove` onto blank with that packed byte. If blocked, write that packed byte on the source cell.

`putBomb` exists (bomb at `playerxy + 256 + rand512()` if blank) but is **not** called.

### Combat summary

| Situation | Result |
| --------- | ------ |
| Monster dest is the player | Monster does not enter; `hurtPlayer` |
| You walk/jump into monster (not a stomp) | You hurt; `playHurt`; monster lives |
| You stomp (`jumpptr === 0`, monster below) | Monster dies, +1, stain, `playKill` |
| Shot hits monster | Monster dies, +1, stain, `playKill` |
| You stomp bomb | Bomb gone, +1, stain |
| You walk onto bomb | You hurt; `playHurt` |
| Shot hits bomb | Bomb gone, +1, stain |

---

## HUD (play)

One blank row below the viewport, then centered `S:0000` heart lives `L:` `liveLevel`, then a key tile if `hasKey`. Two rows below the HUD (`HISCORE_ROW`): centered `HI:0000`. New Level / Game Over sit on the row between them.

---

## Title / overlays

**Title lines** stay up for the run: row 0 `Caves (c)1996 CHRIS B`, row 1 LVL `$S`, row 2 LVL `$A`. A run starts as soon as `main` finishes `initVideo`.

**New Level!** on the row below the HUD after a scroll; map advances after 12 frames, then that line is cleared.

**Game Over!** on the row below the HUD when lives hit 0; 12 frames, that line is cleared, then a new run.

---

## Sounds

| Call | When |
| ---- | ---- |
| `playCoin` | Pick up a coin (`sfxDur` 4) |
| `playHurt` | Lose a life (`sfxDur` **5**) |
| `playKill` | Monster dies by stomp or shot (`sfxDur` 10) |

Shooting, jumping, door, key, scroll, extra life, and game over are silent unless they also match a row above. Monster-into-lava kill SFX is not implemented (they cannot enter lava via `tryMove`).

---

## Pictures

Each pack defines 8×8 bitmaps `#X0` and `#X1` for letters `. P M m c s f F B S t b D k`. Bank 0 is the default; bank 1 is the alternate frame. Wall `W` uses the brick bitmap.

---

## Summary

- Lives at start: 5
- Extra life: last two BCD digits are 50 (50, 150, 250, …)
- Map `M` and `m` walk via the rotary scan
- Stomp kills; bump still hurts
- Monsters only step onto blank cells
- Scroll: pending flag, 12 frames, then next map
- Spawn: first `X` / `PLAYER_START`
- Seeker: `doseek` (25% wander, 16-cell left/right window)
- Timing: wait `$9004 >= 126`, draw, then `gameStep` (logic during the next scan)
- Colors: table above

---

