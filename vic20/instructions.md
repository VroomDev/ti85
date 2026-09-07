# VIC-20 map viewer

Living spec. **Always update this file in the same change** when behavior is locked or altered.  
**Source of truth for the map:** [`vic20.lvl`](vic20.lvl) (32×32).  
**Code:** [`main.c`](main.c) (cc65 C, +32K).

---

## Style

Function names are **camelCase**, verb then noun (`setCharBank`, `drawView`, `initCharset`). Macros are **ALL_CAPS** (`GETKEY`, `GETJIFFY`, `SCREEN`).


---

## Target

| Item | Value |
|------|--------|
| Machine | VIC-20 **+32K** (`xvic -memory all`) |
| Language | C (cc65) |
| Toolchain | `%USERPROFILE%\cc65`, config `vic20-map.cfg` |
| Emulator | `%USERPROFILE%\GTK3VICE-3.10-win64\bin\xvic.exe` |
| Build | `build.bat` → `mapview.prg` |
| Run | `run.bat` |


---

## Display (stock 22×23)

- Do **not** change row/column counts.
- Clear `$9002` bit 7 so the video matrix is **`$1000`** (not `$1200` on expanded VIC).
- Screen RAM: **`$1000`**. Color RAM: **`$9400`** (+8K/+32K; not `$9600`).
- Cursor off (`$CC = 1`).
- White background, cyan border.

### Charset

On **1** / **2**, `initCharset()` copies ROM glyphs `$00`–`$5F` into `$1C00` (A–Z / 0–9 stay there), then copies `tile_bank0` to **`$1F00`** (screen codes `$60`–`$6F`) and `tile_bank1` to **`$1F80`** (`$70`–`$7F`). The C arrays stay in program RAM at `$2000+` (VIC cannot see that); the VIC reads only `$1C00–$1FFF`. `setCharBank(0/1)` selects which 16 codes `drawView` pokes. Do not copy a full 1 KB of ROM — that would overwrite the tile slots.

Source: [`char.txt`](char.txt) via [`gen-charset.py`](gen-charset.py) → [`charset.h`](charset.h). `#M0` / `#M1` are bank 0 / bank 1; missing `1` copies `0`. Slot order: `. P s f S k M m F B t b D c W X`. `W` uses the `f` bitmap; `X` uses blank.

Map letters are remapped to those slots (not PETSCII screen codes) before poke.

```c
void setCharBank(unsigned char bank);  /* 0 = #X0 glyphs, 1 = #X1 */
```

---

### Viewport

| | |
|--|--|
| Map | 32×32, wrap with `& 31` |
| Origin | `view_x`, `view_y` (bytes, start at 0) |
| Window | columns 1–12, rows 1–8 (12×8 cells at the top-left of the 22-column screen) |
| Screen offset | `$1000 + row * 22 + col` |

Each frame, copy map cells into that window with `POKE` (character + color). Do **not** `clrscr` between moves — overwrite in place.

Cell at viewport `(col, row)`:

```text
map[(view_y + row) & 31][(view_x + col) & 31]
```

PETSCII map letters are remapped to custom screen codes `$60`–`$6F` before poke.

---

## Controls

Kernal **LSTX** `$C5` (PEEK 197): matrix code of the key currently **held**. **64** = no key (8×8 matrix is codes 0–63; 64 is the “none” sentinel).

```c
#define GETKEY()     (PEEK(LSTX))   /* $C5; 64 = none */
#define GETJIFFY()   (PEEK(TIME))   /* $A2; low byte of jiffy clock */
```

| Action | Key | Scan code |
|--------|-----|-----------|
| `y -= 1` | **I** | 12 |
| `x -= 1` | **J** | 20 |
| `x += 1` | **L** | 21 |
| `y += 1` | **M** | 36 |
| `setCharBank(0)` | **1** | 0 |
| `setCharBank(1)` | **2** | 56 |

Then `x &= 31`, `y &= 31`, redraw. Held keys keep scrolling (not one-shot `cgetc`).

---

## Build / run

```bat
build.bat
run.bat
```

```bat
cl65 -O -t vic20 -C vic20-map.cfg -o mapview.prg header.s main.c
%USERPROFILE%\GTK3VICE-3.10-win64\bin\xvic.exe -memory all -autostart mapview.prg
```
