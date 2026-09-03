# Architecture

## Source layout (edit these)

- `index.html` — shell for multi-file work (optional during edit)
- `caves.css` — styles
- `js/main.js` — boot / game loop
- `js/tunes.js` — TunesLib player + Crunch song bytes (square-wave speaker)
- `js/engine.js` — CENGINE tick: player, bullet, monsters, falling
- `js/render.js` — 128×64 framebuffer, integer-scaled canvas
- `js/input.js` — keyboard
- `js/lvl.js` — parse `.LVL` text → maps, meta, pics (`parseLvl(text)`)
- `js/tiles.js` — char → tile id, tints, pic letters
- `levels/*.LVL` — pack sources (truth for maps + sprite bitmaps)
- `build.py` — Python 3: pack → standalone HTML

## Build / play (no web server)

```
levels/CASTLE.LVL  +  css/js/html sources
        │
        ▼
   python build.py levels/CASTLE.LVL
        │
        ▼
   castle.html   ← open in browser (file:// OK)
```

- Output name = `.LVL` basename, lowercased (`CASTLE.LVL` → `castle.html`).
- Builder inlines CSS and JS into that file.
- Builder embeds pack text as:

```js
var LVL_DATA = "…escaped contents of the .LVL…";
```

- Runtime: `parseLvl(LVL_DATA)`. Never `fetch` the pack in the playable build.
- Escape carefully in Python (`\`, quotes, newlines) so the string is valid JS.

### Builder responsibilities

1. Read the given `.LVL` path.
2. Read `caves.css` + the JS modules (order that preserves dependencies; flatten ES `import`/`export` into one script suitable for a single HTML — no bare module imports in the artifact).
3. Write `{basename}.html` with inlined `<style>`, `LVL_DATA`, and `<script>`.

### Dev vs play

- **Play / share:** built `castle.html` only.
- **Edit:** change split CSS/JS, then re-run `build.py`. A local HTTP server is optional for debugging multi-file sources, not part of the product.

## Original system (seed)

```
LVL pack  -->  (missing compiler)  -->  85s / CENGINE data
CENGINE   -->  GRAPH_MEM 32x32 map, sprites, VIDEO_MEM blit
```

HTML target:

```
.LVL text (LVL_DATA)  -->  parseLvl  -->  tile map + metadata
engine tick           -->  game state
renderer              -->  canvas
```

## Tile / entity IDs (from CMACROS — verify while porting)

| ID idea | Notes |
|---------|--------|
| blank, player, monster1/2 | player/monsters no-erase; monsters killable |
| coin | falling |
| scroll | no-erase (win item) |
| fire | no-erase |
| bomb | killable + falling |
| bullet, blood | |
| tree | no-erase, killable, falling |
| brick / wall / falling wall | same base id, different flags |
| door, key | |

Level chars in `.LVL` (Castle; nibble mapper in CENGINE is the compiled path — ASCII source uses these letters):

| Char | Meaning | Engine id / flags |
|------|---------|-------------------|
| `.` | blank | 0 |
| `X` / `P` | player start (tile left blank) | actor only |
| `W` | wall (shootable brick pic) | wallid |
| `M` | patrol monster (placed tile) | monster1id |
| `m` | seeker monster (placed tile) | monster2id |
| `c` | coin | coinid, falling |
| `s` | scroll (win the level) | scrollid |
| `f` | lava / fire | fireid |
| `F` | bomb | bombid, killable, falling |
| `B` | bullet / cloud (high-jump pad) | bulletid |
| `S` | stain / splat | bloodid, falling |
| `t` | tree (shootable, falling) | treeid |
| `b` | brick (solid, not shootable) | brickid |
| `D` | door | doorid, falling |
| `k` | key | keyid |
| `z` | treated as brick (one graveyard cell) | brickid |

## Display (seed)

- Sprite 8×8, `scrwidth` 16 bytes, `dispwidth` 13, `scrhite` 8
- Camera follows player; full-way scrolling

## Colors (one per graphic)

See `js/tiles.js`. Shared bitmaps (`b` / `W` / falling wall) share the brick picture; wall is tinted cooler gray so shootable stone reads differently in Castle.

## Notes

- Map is 32×32 wrapping (offset `& 1023`).
- Visible playfield 13×8 tiles; right stripe is HUD.
- Current `js/` uses ES modules; the builder must emit a non-module (or fully inlined) script so `file://` works without a server.
