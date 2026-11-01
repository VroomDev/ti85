# Decisions

Log locked choices. Newest first.

## Template

### YYYY-MM-DD — title

- **Choice:**
- **Why:**
- **Rejected:**

---

### 2026-11-01 — continuous D-pad tracking (not per-button capture)

- **Choice:** `.pad-dpad` is one hit surface (`pointer-events: none` on the glyphs). `pointerdown`/`pointermove` map to an **8-way angle** from the pad center (with dead-zone + hysteresis). Direction codes update as the thumb slides. Fire/Pause/Map/Quit stay separate buttons. Up-diagonals always include `ArrowUp` (so grounded jump matches keyboard Up+Left/Right).
- **Why:** Per-button capture locked one direction until lift. A later 3×3 grid made “diagonal” presses often land in pure Left/Right (no Up), so jump flickered. Angle wedges keep each diagonal a full 45° slice.
- **Rejected:** Sticking with eight independent capture buttons; 3×3 cell hit-testing; analog stick with float axes (engine wants digital holds).

---

### 2026-11-01 — pad diagonals as dual-direction holds

- **Choice:** Portrait D-pad is a full 3×3 with corner buttons (↖↗↙↘). Each diagonal `press`es both matching arrow codes until release (with shared-code ref safety across pointers).
- **Why:** Holding two direction buttons at once is awkward with thumbs; CENGINE already treats simultaneous left+up etc. as combined move/aim.
- **Rejected:** Requiring two-finger chords for diagonals; analog stick.

---

### 2026-11-01 — build stamp `vYYMMDD.HHMM` on screen

- **Choice:** `build.py` injects a local-time stamp `vYYMMDD.HHMM` into each HTML as `#build` (bottom of `#app`) and `var BUILD_ID`. `build-all.py` computes one stamp for the run and passes it into every `build()` plus `built/index.html`.
- **Why:** github.io caching makes it hard to tell which JS you are debugging; the footer shows the build minute.
- **Rejected:** git hash only; invisible meta tag; per-file clocks that drift across a `build-all` run.

---

### 2026-11-01 — portrait initials via joypad

- **Choice:** On the “Enter initials:” screen with the joypad, Up/Down scroll the alphabet on the current slot; Left/Right move among the three characters; Fire confirms (enter). Desktop still types three A–Z keys.
- **Why:** No on-screen keyboard; the pad is already there after game over.
- **Rejected:** Separate A–Z touch keyboard; requiring physical letters on phone.

---

### 2026-11-01 — portrait phone joypad under the screen

- **Choice:** Keep desktop keyboard play as primary. On a coarse pointer in **portrait**, show a virtual joypad **beneath** the playfield (not overlaid on the 128×64 canvas): D-pad (Left/Right/Up/Down) plus a held **Fire** button. Buttons set the same held flags as `js/input.js` (including simultaneous hold for aim-while-shoot). Small Pause / Map / Quit buttons beside the pad. Hide the pad on fine pointer / desktop / landscape (`pointer: coarse` + `orientation: portrait`). Overlay tap counts as “any key” for title/banners. Initials entry uses the same pad (see sibling decision).
- **Why:** The scaled TI LCD is a short 2:1 strip; portrait leaves room under the screen for thumbs. CENGINE already polls simultaneous held buttons; a held Fire matches 2nd. Overlaying controls on a 64-pixel-tall field would hide the action.
- **Rejected:** Landscape-first touch; on-canvas overlays; tap-to-fire (breaks aim); omitting Down (faster fall / aim / bullet ride); replacing keyboard on desktop.

---

### 2026-09-13 — Castle graveyard `z` was a typo

- **Choice:** The one `z` in `CASTLE.LVL` map 2 is `b`. `CHAR_TILE` has no `z`.
- **Why:** It sat in a brick floor (`…bbbzb`). Mapping `z` to brick hid a typo and made the README look like a real tile.
- **Rejected:** Keeping a silent `z`→brick alias.

---

### 2026-09-13 — bumping map monsters hurts

- **Choice:** If the player’s attempted move lands on a monster tile (`M`/`m` or a spawned ghost) they lose a life (`decHealth`). The monster stays (`NOERASE`). Stomp still runs first: if `jumpptr === 0` and a monster is in the cell below, it dies and that dest is no longer a live monster, so landing on top does not hurt.
- **Why:** Map ghosts used to act like walls. Side, below, and jump-into contact should match a roamer walking into you.
- **Rejected:** Leaving bump harmless; killing the monster on bump; requiring a spawned sprite.

---

### 2026-09-13 — map `M` falls

- **Choice:** `.LVL` letter `M` is `monster1id | FALLING`, so `blockFall` drops it when the cell below is blank. Spawned patrols still write plain `monster1id` (their own `beneath` gravity). Map `m` stays non-falling.
- **Why:** A placed patrol hanging in air does not read as a grounded enemy. CENGINE left map `M` still; that felt wrong in play.
- **Rejected:** Giving all `monster1id` the falling bit (would also `blockFall` roamers); making map `m` fall; turning map `M` into a live sprite.

---

### 2026-09-13 — extra life every 64 points

- **Choice:** Bonus life when `(score & 63) === 63` (63, 127, …), not CENGINE’s `& 31`. Cap stays 9.
- **Why:** Stomp-kills (kept because other platformers have them) farm score too fast; 32-point lives made the run too easy.
- **Rejected:** Removing stomp; keeping `& 31`; raising the interval further.

---

### 2026-09-13 — start with 3 lives

- **Choice:** New run sets HUD lives (`health`) to 3, not 9. Score still can raise it up to 9.
- **Why:** Shorter, harder runs than CENGINE’s `'9'` start.
- **Rejected:** Lowering the max of 9; changing ASM.

---

### 2026-09-13 — build.py fills missing `#` pics from DEFCHARS.DEF

- **Choice:** After reading a `.LVL`, `build.py` appends any `#X0`/`#X1` picture blocks that exist in `DEFCHARS.DEF` but not in that pack. Only the embedded `LVL_DATA` is patched; the source file and the JS parser are not changed. A header already in the pack wins (no overwrite).
- **Why:** Some packs (e.g. BLANK) omit monster and other pictures. Shared defaults live in `DEFCHARS.DEF`. Keep the risk in the builder so gameplay code stays as-is.
- **Rejected:** Patching in `js/lvl.js`; rewriting `.LVL` files on disk; replacing pictures the pack already defines.

---

### 2026-09-06 — Digit1 drops a test scroll

- **Choice:** Press `1` (or numpad 1) once to write a scroll on `player.xy + 1` (mod 1024). For testing level wrap and seeker difficulty.
- **Why:** Walking to every scroll is slow when checking L5+.
- **Rejected:** Auto-advance level; putting the scroll in the player cell.

---

### 2026-09-06 — level number climbs; maps wrap

- **Choice:** `liveLevel` increases by 1 every scroll (HUD and seeker `20 * level`, monster cap 5 / 10 / 20). The map loaded is `levelIdx % pack.levels.length`. Assets loop; difficulty does not reset.
- **Why:** Wrapping `levelIdx` before `liveLevel = levelIdx + 1` sent the HUD back to 1 after the last map.
- **Rejected:** Resetting difficulty when the pack loops.

---

### 2026-09-06 — map mode is 2×2 tiles, player-centered

- **Choice:** Overview (M) draws a 64×64 pixel panel (2×2 per tile, no gaps). Cells use `colorForTile`. The 32×32 window is centered on `player.xy` using the same **mod 1024** addressing as play: left/right ±1, up/down ±32 (`wrapMap`).
- **Why:** Wrapping X and Y as a 2D torus put the tile to your right at the start of the same row; play uses a 1D 1024-cell wrap, so that tile is the next index.
- **Rejected:** 1-pixel CENGINE `showmap`; independent `(x&31, y>>5)` wrap; hiding killable tiles as dark pixels.

---

### 2026-09-06 — hiscore key follows the .LVL stem

- **Choice:** High score and initials use `caveshtml.${packId}.hiscore` / `.initials`. `packId` is the `.LVL` basename (from `LVL_NAME` in the built HTML). No pack name is hardcoded in JS.
- **Why:** Each pack is its own file; scores must not all live under `castle`.
- **Rejected:** `caveshtml.castle.hiscore` in source.

---

### 2026-09-06 — intro plays once

- **Choice:** Intro is a single play, not a loop. Starting a game uses `{ cut: true }` so a looping or leftover intro cannot keep going. After quit/game over, intro may wait behind `quitsong` then play once.
- **Why:** `{ loop: true }` on the title plus `play("intro")` queuing while that loop ran made the song repeat forever, including in play.
- **Rejected:** Crunch’s looping title intro.

---

### 2026-09-06 — initials on game-over high score

- **Choice:** When lives hit 0 and this run beat the stored high score, show CENGINE’s “Enter initials:” and take three A–Z keys. The field starts as `___`. The title `$P` line shows those three characters then the score. Quit (Esc twice) does not ask.
- **Why:** Playtest: ask at game over, not on quit. Keyboard letters instead of the TI-85 `letterconverter` table.
- **Rejected:** Prompt on Esc quit; numeric keypad initials.

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

### 2026-09-06 — stomp a bomb like a monster

- **Choice:** If `jumpptr === 0` and the cell below you is a bomb (`F`), replace it with a splat, `incScore`, and play `coinsong`. Walking into a bomb still hurts.
- **Why:** Same “land on it” rule as ghosts.
- **Rejected:** Hurting the player when standing on a bomb; stomping bombs during `jumpptr !== 0`.

---

### 2026-09-06 — stomp kills the monster beneath you

- **Choice:** If you are not in the upward jump (`jumpptr === 0`) and the cell immediately below the player is a monster (`M`/`m` or a spawned ghost), that monster dies, scores like a shot, and is replaced with a splat (`S` / blood). You stay in the cell above the splat (monsters stay `NOERASE`, so you never occupy their cell). Walking or bumping into a monster from the side, below, or while jumping into it hurts and does not kill it; a monster that walks into you still hurts you and stays alive.
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

- **Choice:** Roamer type is 50/50 (`#M` patrol / `#m` seeker). Level fill alternates slots. Seekers: each monster step, if `random(100) > 20 * level` pick a random of 4 dirs, else pick a dir that closes on the player (if both axes need a step, pick horizontal or vertical at random — not only the longer axis); no gravity. Patrols: gravity (fall if the cell below is blank); on a blocked/occupied step, pick any of 4 dirs (they may hop up, then gravity pulls them down). Map-placed `m` stays still; map `M` falls via `blockFall` (see 2026-09-13).
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

### 2026-09-06 — built HTML under `built/`

- **Choice:** `build.py` writes `built/{name}.html` (e.g. `built/castle.html`). `-o` still overrides. Creates `built/` if missing.
- **Why:** Keep generated files out of the source tree root.
- **Rejected:** Writing next to `build.py` (that was the 2026-09-02 default).

### 2026-09-02 — built HTML at repo root

- **Superseded** by 2026-09-06 (`built/`). Original choice was `{name}.html` at the project root, not `dist/`.

### 2026-09-02 — offline standalone HTML via Python build

- **Choice:** Keep editable split sources (`index.html`, `caves.css`, `js/*.js`). A Python 3 script builds one self-contained HTML per pack: read `levels/FOO.LVL`, emit `built/foo.html` (basename lowercased), with CSS/JS inlined and the pack text as `var LVL_DATA = "…"` (one escaped string). The game reads `LVL_DATA` only — no `fetch`, no web server to play. Open the built file in a browser (`file://` or double-click).
- **Why:** Playable offline; each pack is a single shareable file named after the level; sources stay easy to edit.
- **Rejected:** Fetching `.LVL` at runtime; requiring `python -m http.server` (or any server) to play; shipping only multi-file ES modules as the play artifact.

### 2026-09-02 — keyboard only

- **Superseded** by 2026-11-01 (portrait joypad under the screen). Original choice was keyboard only, no touch or gamepad, for the first playable slices.

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
