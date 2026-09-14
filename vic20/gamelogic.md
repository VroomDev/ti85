# Caves — game logic (port spec)

Platform-neutral rules for the Caves engine. Use this to teach another machine (for example a VIC-20). Do not copy UI chrome, file formats unique to a browser, or sound.

Source of truth: what each map letter does, the 32×32 wrapping map, the jiffy-timed loop, and the playtest decisions that changed CENGINE.

---

## Goal

Find the **scroll** (artifact). Touching it scores, loads the next map, and raises difficulty. Maps loop after the last one in the pack; the level number and monster pressure keep climbing.

Beware monsters and lava. You have a pellet gun and a jump. One **key** at a time; a key opens one **door**.

---

## World

- Map is **32×32** cells = **1024** cells.
- Addressing is a **1-D ring**: index `xy` is `0…1023`, wrap with `xy & 1023`.
- Neighbors:
  - right `+1`, left `-1`
  - down `+32`, up `-32`
- Walking off the right end of a **obeys toridial geometry.**
- Sprites / tiles are **8×8** pixels, **1-bit** pictures (two banks for a two-frame changing on some graphics). Each graphic is one solid tint.

---

## Tiles, flags, map letters, colors

Behaviors (how you store them is up to the VIC-20 code):


| Behavior  | Meaning                                                         |
| --------- | --------------------------------------------------------------- |
| Solid     | Movers cannot enter this cell. Collision still “sees” the tile. |
| Shootable | Shot (and some stomps) destroy it and write a stain.            |
| Falling   | The falling pass drops it one cell if the cell below is blank.  |


**Player, patrol, and seeker** are the monster-family contacts (bump / stomp / shot scoring). **Empty, player, patrol, seeker, coin, scroll, lava, and bomb** use two picture banks. Cloud and later graphics are a single frame.

Unknown letters are not valid map cells. 

Colors are **VIC-20 names**. The VIC has **no greys**; mid-greys are forced to a nearby hue (see notes).

Hi-res **character color RAM is only 0–7**. Colors 8–15 are background, border (0–7 only), auxiliary, or extra via bitmap/multicolor. If a graphic must be a normal character color, use the 0–7 stand-in in the last column.


| Map       | Flags (placed)                | Role                                           | Color        | Char 0–7 if needed |
| --------- | ----------------------------- | ---------------------------------------------- | ------------ | ------------------ |
| `.`       | none                          | empty                                          | Black        | Black              |
| *(actor)* | Solid                         | player                                         | Light orange | Yellow             |
| `M`       | Solid, shootable, **falling** | placed patrol (tile)                           | Light purple | Purple             |
| `m`       | Solid, shootable              | placed seeker (still)                          | Red          | Red                |
| `c`       | Falling                       | coin                                           | Yellow       | Yellow             |
| `s`       | Solid                         | scroll / artifact                              | Light yellow | White              |
| `f`       | Solid                         | lava / fire                                    | Orange       | Red                |
| `F`       | Shootable, falling            | bomb                                           | Blue         | Blue               |
| `B`       | Solid                         | cloud / high-jump pad (same pic as the bullet) | White        | White              |
| `S`       | Falling                       | stain / splat / blood                          | Red          | Red                |
| `t`       | Solid, shootable, falling     | tree                                           | Light green  | Green              |
| `b`       | Solid                         | brick (not shootable)                          | Orange       | Red                |
| `W`       | Solid, shootable              | wall (shootable brick picture)                 | Light blue   | Blue               |
|           |                               |                                                |              |                    |
| `D`       | Solid, falling                | door                                           | Orange       | Red                |
| `k`       | Solid                         | key                                            | Light yellow | Yellow             |


Spawned roamers look and fight like `M` / `m` but **do not fall** as map tiles (patrols use their own gravity instead).

**Shared bitmap:** `b`, `W`, and falling wall all draw the brick picture (`#b`). Tint tells them apart: orange brick, light-blue wall, light-orange falling wall.

**Grey / brown stand-ins** (no VIC grey, no VIC brown):

- Bomb was mid-grey → **Blue** (cool “metal”).
- Wall was cool grey → **Light blue**.
- Falling wall was dusty brown-grey → **Light orange**.
- Door was dark brown → **Orange** (same as brick / lava).
- Brick was brown → **Orange** (closest; same index as lava).

If two orange solids are too close in play, keep lava as Orange and give brick **Red** — Red is the next-nearest for brick, but then brick, seeker, and stain share red.

**Playfield background:** Black.  
**HUD background:** Black.  
**HUD text:** White.  


The player cannot be hurt if the sfxdur is not zero.

When a sound is played sfxdur is set to a positive value.  Each game loop decrements it.  When it reaches 0, the sound is silenced.

## Score, lives, levels

- **Lives** (HUD `LV`) start at **5** (CENGINE started at 9). Cap **9**. Zero → game over.
- **Score** is **4-digit BCD** or a 16 bit number which ever is easier, shown in full on the HUD. 
- **Level** (`L` + number) is `liveLevel`: 1-based, **never wraps**. Each scroll increments the map index and `liveLevel`. After the last map, load `mapIndex % mapCount`; difficulty stays high.
- Extra life after a **+1** when the **low two BCD digits are** `99` (99, 199, 299, …, 9999) if stored as BCD or score & 63==63 if score is 16 bit integer, then `lives = min(9, lives+1)`. Coin and other multi-point awards are several +1s, so a +3 can still land on `xx99`. (HTML used `(score & 63) === 63`; CENGINE used `& 31`.)
- A new run starts with **score 0**, lives 5, map index 0.

Score events:


| Event                                            | Δ score                         |
| ------------------------------------------------ | ------------------------------- |
| `startLevel` (each map load **after** the first) | +1                              |
| Touch coin                                       | +3                              |
| Kill a monster (shot or stomp)                   | +1                              |
| Destroy a bomb (shot or stomp)                   | +1                              |
| Touch scroll                                     | +1, then `startLevel` (+1 more) |


Shooting a wall or tree does **not** score. It still becomes a stain if it is shootable.

High score is the same 4-digit BCD, kept **in RAM** (cleared when the machine is reset or powered off). If this run’s score beats it, replace it. No initials. Title shows the high score number.

---

## Controls

Keys and joystick may be used together.


| Action    | Input                               | Effect                                                                                                                                                                                         |
| --------- | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Left      | Joystick left or `J`                | Walk left **unless** shooting. Always set facing. Cannot merge a walk into a **brick, wall, or falling wall**.                                                                                 |
| Right     | Joystick right or `L`               | Same, to the right.                                                                                                                                                                            |
| Up / jump | Joystick up or `I`                  | Set facing up. If grounded, jump (`jumpptr = 2` and move up one cell this gravity phase).                                                                                                      |
| Down      | Joystick down or `M`                | Set facing down. If **not** shooting, force vertical delta to **down** (fast fall; cancels an upward jump this step). On a cloud, Down + not shooting starts a **high jump** (`jumpptr = 20`). |
| Shoot     | Joystick fire or `K`                | Face stays; no walk on left/right/down. Spawn one bullet if none is in flight.                                                                                                                 |
| Quit      | `Q`                                 | Return to title. Does not change the RAM high score except that a better in-run score may already have been stored.                                                                            |
| Start     | Start or joystick fire (from title) | Begin a new run.                                                                                                                                                                               |


After “New Level!” the next map is **already loaded**. Ignore input for **12 jiffies** so the key or fire that grabbed the scroll does not dismiss the banner. Then Start or fire continues.

After game over, Start or fire → title. If the run beat the RAM high score, that value is already updated.

---

## Movement and collision (`moveSpr`)

Attempt dest = `wrap(xy + delta)`.

- If dest is **solid**, **do not move**. Return the dest tile (the “hit”).
- If the mover is **not** the player and dest is a **coin**, do not move (coins block roamers and bullets).
- Else occupy dest, leave blank behind, return the old dest tile.

The player uses a combined delta (`hl`): vertical (jump / gravity / down) plus optional ±1 horizontal, then the same solid-tile test.

Player collision uses the dest cell even when the move is refused (solid).

---

## Player

- Occupies the map as the **player** (solid). Never share a cell with a solid tile.
- **Player step only when `frame` is even** (every **6 jiffies**).
- **Gravity / jump vertical** only when `(frame & 2) !== 0` during that player step.

### Jump and gravity

`jumpptr` is remaining upward force. `JUMP_LEN` is 3; a normal jump sets `jumpptr = 2`.

When the gravity phase runs:

- If `jumpptr !== 0`: decrement it, vertical = up.
- Else look at the cell **below**:
  - blank **or lava** → vertical = down (lava is not a floor).
  - cloud (`B`) and Down held and not shooting → `jumpptr = 20` (high jump).
  - jump action → `jumpptr = 2`, vertical = up.

Hitting **brick, wall, or falling wall** **while** `jumpptr !== 0` decrements `jumpptr` again (jump clips sooner).

### Stomp (before walking this player step)

If `jumpptr === 0` and the cell **immediately below** is:

- a monster tile (`M`/`m` or a spawned ghost) → kill it (score +1, stain, clear that roamer’s HP if any). Call **play_kill**. Player stays in the cell above. Because monsters are solid, you never occupy their cell.
- a bomb → score +1, stain. Walking **into** a bomb still hurts.

Stomp does **not** run during the upward jump (`jumpptr !== 0`).

### Bumping a monster

If the attempted dest is a monster, **lose a life**. The monster stays. Side, below, or jumping **into** it hurts. Stomp is checked first, so landing from above with `jumpptr === 0` kills instead of hurting.

### Lava

Touching lava (move refused, hit = fire): lose a life, write a **stain on the player’s current cell**, set `player.xy` to spawn. You do not enter the lava cell.

### Bomb (walk-in)

Bombs are **not** solid. Walking onto one: lose a life (player overwrites the bomb cell). Stomp/shoot as above.

### Coin

Not solid. Walking on it: +1 score (player overwrites the coin). Coins **fall** if the cell below is blank. Call **play_coin**.

### Key / door

Both solid — you do not step onto them.

- Key, and you have no key: set “has key”, erase the key cell.
- Key, already carrying: ignore (key stays).
- Door, have key: clear “has key”, erase the door.
- Door, no key: blocked (solid).

**One key at a time.**

### Scroll

Solid. Hit: erase that cell, +1 score, increment map index, `startLevel` (new map, spawn, roamers, +1 score, `liveLevel = mapIndex + 1`), show “New Level!” until a key (after the short ignore window).

### Brick / wall / tree

Solid. Walls and trees are shootable (shot → stain). Bricks (`b`) are not.

---

## Bullet

- At most one. Range **4** steps. Picture and color same as cloud `B`.
- Spawn only if none in flight. Direction = current facing, snapped to 1…4. Start `xy` = player cell; first step **moves** off the player.
- Moves on even `frame` (after `frame` increments).
- On any non-blank hit: destroy it if shootable (see below), then despawn. Extra +1 if the hit was a bomb.
- Range counter decrements every bullet step; at 0, despawn and blank the bullet cell.
- Always rewrite the **player** onto the player cell after the bullet step (so the shot leaving the player cell does not erase you).

Destroying a shootable tile: if it is **not** shootable, skip. If it is a **monster**, +1 score and **play_kill**. If a live roamer sits on that cell, decrement its HP; at 0 write stain. Always write stain on the hit cell.

---

## Falling (`blockFall`)

Each game step, scan **32** cells backward from a rotating `blockspot` (decrement and wrap). If the cell **falls** and the cell below is **blank**, move the tile down one and blank the old cell.

This is how coins, stains, bombs, trees, doors, **map `M`**, and any falling wall drop. Spawned roamers do **not** fall this way.

---

## Monsters

### Two populations

1. **Map tiles** `M` / `m` baked into the level.
  - `m`: stays put (no sprite AI). Bump hurts. Stomp / shot kills (stain).
  - `M`: same combat, plus **falling** so the falling pass drops it if air is below. Not a live roamer unless a spawned sprite shares the cell.
2. **Roamers** — live spawned ghosts. How many should be alive is `(liveLevel << 2)` (level×4). There is no 5 / 10 / 20 cap.

### Spawn

Each game step, if the number of **alive roamers** is less than `(liveLevel << 2)`, add **one** more.

Kind from the count **before** the spawn:

- count **even** → seeker `m`
- count **odd** → patrol `M`

Location (then wrap onto the 1024-cell map):

`xy = (player.xy + 256 + ((random() << 2) + random())) & 1023`

Each `random()` is an integer **0 through 512** (two independent rolls). If that cell is not blank, skip this spawn.

Do not use the old “≥ 112 cells away, pick a random blank” spawn. Do not 50/50 the type on respawn.

Spawned kinds:


| Kind   | Looks like         | Gravity                                 |
| ------ | ------------------ | --------------------------------------- |
| Patrol | `M` (light purple) | Yes: if cell below is blank, dir = down |
| Seeker | `m` (red)          | No                                      |


HP = 1. Initial dir = down.

### Roamer step (every **24 jiffies**, i.e. every 8 game steps)

For each live roamer:

1. **Seeker:** `dir = pickSeekerDir`.
  - If `random(100) > 20 * liveLevel` → random of 4 dirs.
  - Else chase: 2-D torus on `(x = xy & 31, y = xy >> 5)`, wrap deltas into `-16…16`, pick a dir that reduces dx and/or dy. If both axes need a step, **50/50** horizontal vs vertical (not “longer axis only”). If already overlapping in 2-D, random dir.
  - From `liveLevel >= 5`, `20 * level >= 100`, so seekers **always chase**.
2. **Patrol:** if beneath is blank, `dir = down`.
3. `moveSpr` in `dir`.
4. **Patrol only:** 1-in-64 chance to `putBomb` (see below). If the step **hit** something (not blank), pick a new random 4-dir (they may hop **up**, then gravity pulls them down next time).
5. If hit **player**: lose a life; monster **stays alive** (does not splat). Contact is not a kill.
6. If hit **lava**: stain on the monster cell, HP = 0, **play_kill** (a later game step may spawn a replacement if the alive count is below `(liveLevel << 2)`).

### Patrol bombs

`putBomb` does **not** use ±32. It only writes a bomb at `xy ± 1` (the four logical dirs collapse to left/right in 1-D). Only if that cell is blank. Spawned bombs are normal `F` tiles (killable, falling, hurt on walk-in).

### Combat summary


| Situation                                  | Result                                 |
| ------------------------------------------ | -------------------------------------- |
| Roamer walks into you                      | You hurt; **play_hurt**; monster lives |
| You walk/jump into monster (not a stomp)   | You hurt; **play_hurt**; monster lives |
| You stomp (`jumpptr === 0`, monster below) | Monster dies, +1, stain, **play_kill** |
| Shot hits monster                          | Monster dies, +1, stain, **play_kill** |
| Monster enters lava                        | Monster dies, stain, **play_kill**     |
| You stomp bomb                             | Bomb gone, +1, stain                   |
| You walk onto bomb                         | You hurt; **play_hurt**                |
| Shot hits bomb                             | Bomb gone, +1, stain                   |


---

## HUD (play)

Right strip, not the 13×8 world:

- `SC` and 4-digit BCD score
- `LV` and lives (0–9)
- `L` + `liveLevel`
- Key picture if carrying a key

---

## Title / overlays (logic only)

**Title:** pack story (`$S`), author (`$A`), high score (number only). Hint: find the scroll; one key at a time. Start or joystick fire begins a run.

**New Level!** after a scroll (map already advanced).

**Game Over!** when lives hit 0. Start or fire returns to title. No initials.

---

## Sounds

Three calls. Do not invent others.


| Call        | When                                                                                                                   |
| ----------- | ---------------------------------------------------------------------------------------------------------------------- |
| `play_coin` | Player picks up a **coin**.                                                                                            |
| `play_hurt` | Player **loses a life** (bump a monster, monster walks into you, lava, walk onto a bomb). Same time as the hurt flash. |
| `play_kill` | A **monster** dies (stomp, shot, or it walks into lava). Not for bombs, walls, or trees.                               |


Shooting, jumping, opening a door, taking a key, grabbing the scroll, extra life, and game over are silent unless they also match a row above.

---

## Pictures

Each pack defines 8×8 bitmaps `#X0` and `#X1` for letters `. P M m c s f F B S t b D k`. Bank 0 is the default; bank 1 is the alternate frame. Missing pictures may be filled from the shared default set (`DEFCHARS.DEF`) at pack build time — gameplay does not care where the bits came from.

Wall `W` uses the brick bitmap.

---

## Summary

- Lives at start: 5
- Extra life: BCD low two digits `99`
- Map `M`: falls like other falling tiles
- Stomp: kills; bump still hurts
- Roamer touch: hurts you; monster lives
- Scroll: loads next map immediately, then banner
- Spawn: first `X`/`P`
- Seeker chase: `20 * level` wander vs chase; both axes
- RNG: uniform random
- Timing: jiffy clock (1/60 s); one game step every 3 jiffies
- Colors: one tint per graphic (table above)

