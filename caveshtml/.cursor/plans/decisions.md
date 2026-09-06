# Decisions

Log locked choices. Newest first.

## Template

### YYYY-MM-DD — title

- **Choice:**
- **Why:**
- **Rejected:**

---

### 2026-09-06 — 200 ms before dismissing New Level

- **Choice:** After the scroll loads the next map, “New Level!” ignores keys for 200 ms (`performance.now()`).
- **Why:** Walking into the scroll still has a key down, which skipped the banner immediately.
- **Rejected:** `setTimeout` inside the sim tick; delaying the map load itself.

---

### 2026-09-06 — monster death uses coin song

- **Choice:** Shooting, stomping, or a monster walking into lava plays the Crunch `coinsong` (same as a coin/key/door pickup).
- **Why:** Feedback that a monster is gone.
- **Rejected:** Silent kills; a separate death jingle.

---

### 2026-09-06 — stomp kills the monster beneath you

- **Choice:** If you are not in the upward jump (`jumpptr === 0`) and the cell immediately below the player is a monster (`M`/`m` or a spawned ghost), that monster dies, scores like a shot, and is replaced with a splat (`S` / blood). You stay in the cell above the splat (monsters stay `NOERASE`, so you never occupy their cell). Walking or bumping into a monster from the side still does not kill it; a monster that walks into you still hurts you and stays alive.
- **Why:** Playtest: landing treated monsters as a floor, so you stood on them. Stomping matches the expected “land on it” outcome without reversing the contact-damage rule.
- **Rejected:** Standing on live monsters; killing on any contact; moving the player into the monster cell (that would overwrite the splat); stomping during `jumpptr !== 0`.

---

### 2026-09-02 — key, door, super-jump sounds

- **Choice:** Key pickup and opening a door play the Crunch `coinsong`. Standing on a cloud (`B`) and pressing down for the high jump plays a short rising TunesLib chirp (not in Crunch).
- **Why:** Extra feedback; coin song already means “got an item.”
- **Rejected:** Silent key/door; using `firesong` for the bounce.

---

### 2026-09-02 — `.LVL` map charset includes trees

- **Choice:** Map rows match every `CHAR_TILE` letter plus `X`/`P`. Incomplete 32-line maps are not kept.
- **Why:** The old regex `[.XcFBsSmWbMDfkPTz]` omitted `t` (trees). Castle maps 2–4 were discarded, so the pack had one level; taking the scroll indexed a missing map and threw, leaving you on map 1 with the scroll gone.
- **Rejected:** Hard-coded charset that can miss letters used in `.LVL` files.

---

### 2026-09-02 — scroll loads the next map

- **Choice:** Touching the scroll (`s`) increments the level index, loads that map, then shows “New Level!” until a key. The key only dismisses the banner.
- **Why:** Pickup must change the map; waiting to load until a second key felt like the scroll did nothing.
- **Rejected:** Setting `hasscrollbit` and leaving the same map until Enter.

---

### 2026-09-02 — contact does not kill roamers

- **Choice:** A monster that walks into the player hurts the player and stays alive. Only a shot (or lava) kills it.
- **Why:** Playtest: contact-kill made bumping the same as shooting. CENGINE writes blood and clears monster HP on `hitxyval==playerid`.
- **Rejected:** Splatting the roamer on touch.

---

### 2026-09-02 — JavaScript Math.random

- **Choice:** Game RNG is `Math.random()` (dirs, spawn type, bombs, seeker wander roll). Not CENGINE/`RAND.ASM` 8-bit LCG.
- **Why:** The Z80 generator’s low bits made 4-way directions unusable; the browser RNG is uniform enough for play.
- **Rejected:** Porting `randvar = randvar*17+13+frame` or `*21+1`.

---

### 2026-09-02 — spawned patrol vs seeker

- **Choice:** Roamer type is 50/50 (`#M` patrol / `#m` seeker). Level fill alternates slots. Seekers: each monster step, if `random(100) > 20 * level` pick a random of 4 dirs, else pick a dir that closes on the player (if both axes need a step, pick horizontal or vertical at random — not only the longer axis); no gravity. Patrols: gravity (fall if the cell below is blank); on a blocked/occupied step, pick any of 4 dirs (they may hop up, then gravity pulls them down). Map-placed `m`/`M` stay still.
- **Why:** Playtest seeker formula; CENGINE patrol redir is 4-way, with down forced when nothing is underneath.
- **Rejected:** One movement formula for both types; seekers always chasing; chase using only the longer axis (that hid up/down); patrols locked to left/right only.

---

### 2026-09-02 — 23 Hz CENGINE loop

- **Choice:** Physics at 23 ticks/s (20 Hz halt/blit estimate + 15% from playtest). Draw every animation frame.
- **Why:** 60 Hz was several times too fast; 20 Hz felt close but a bit slow.
- **Rejected:** 60 Hz simulation; cycle-accurate Z80 timing.

---

### 2026-09-02 — Crunch TunesLib sound

- **Choice:** Port `TUNESLIB.ASM` as a Web Audio square-wave player. Use the song tables in `CRUNCH.ASM` (intro, fire, coin, hurt, new level, game over, quit). Unlock on first key (browser autoplay).
- **Why:** Caves/CENGINE has no beeper songs; Crunch is the recovered sound source. Same duration/freq byte format.
- **Rejected:** Inventing new music; requiring exact Z80 cycle timing before shipping sound.

---

### 2026-09-02 — built HTML at repo root

- **Choice:** `build.py` writes `{name}.html` next to the project root (e.g. `castle.html`), not under `dist/`.
- **Why:** Easiest to find and double-click; one pack → one file beside the sources.
- **Rejected:** A separate `dist/` folder for now.

### 2026-09-02 — offline standalone HTML via Python build

- **Choice:** Keep editable split sources (`index.html`, `caves.css`, `js/*.js`). A Python 3 script builds one self-contained HTML per pack: read `levels/FOO.LVL`, emit `foo.html` (basename lowercased), with CSS/JS inlined and the pack text as `var LVL_DATA = "…"` (one escaped string). The game reads `LVL_DATA` only — no `fetch`, no web server to play. Open the built file in a browser (`file://` or double-click).
- **Why:** Playable offline; each pack is a single shareable file named after the level; sources stay easy to edit.
- **Rejected:** Fetching `.LVL` at runtime; requiring `python -m http.server` (or any server) to play; shipping only multi-file ES modules as the play artifact.

### 2026-09-02 — keyboard only

- **Choice:** Keyboard controls only for this port. No touch or gamepad.
- **Why:** Matches CENGINE’s key model and keeps the first playable build small.
- **Rejected:** Touch / gamepad in the first slices.

### 2026-09-02 — CASTLE first, one color per graphic

- **Choice:** Ship a playable Castle pack (`levels/CASTLE.LVL` only). Each sprite is 1-bit like the TI-85, tinted a single color. Player spawn uses the first `X` in the map (respawn there after fire); CENGINE hard-coded offset 0.
- **Why:** User asked to match old behavior with some enhancements, pick one color per graphic, and not get distracted by other packs.
- **Rejected:** Multi-color sprites; waiting for every `.LVL` before a first playable build; spawning only at map index 0.

### 2026-09-02 — PC controls

- **Choice:** Arrows move; Up or Space jump; `X` / `Z` / Ctrl shoot; Down aims down and drops faster unless you are shooting; `P` or F1 pause; Esc twice quits to title; `M` overview map.
- **Why:** Maps original simultaneous 2nd/Alpha/arrows onto a keyboard without calculator labels.
- **Rejected:** Requiring a TI-85 keymap overlay to play.

### 2026-09-02 — start as vanilla web, ASM as spec

- **Choice:** No framework until we need one. `asm/` + `levels/` define behavior.
- **Why:** Folder is `caveshtml`; recovered source is the spec; missing compiler should not block a text `.LVL` loader.
- **Rejected:** Emulating Z80 in the browser as the first approach.
