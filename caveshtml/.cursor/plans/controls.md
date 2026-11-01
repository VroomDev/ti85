# Controls

Original (README): simultaneous keys; CENGINE only polls some buttons.

| Action | TI-85 | Browser (desktop) | Phone portrait (joypad) |
|--------|--------|-------------------|-------------------------|
| Move | arrows | Arrow keys | D-pad Left / Right |
| Jump | ALPHA (also up arrow in later ASM) | Space or ArrowUp | D-pad Up (and/or Jump if split later) |
| Shoot | 2nd | `X`, `Z`, or Control | **Fire** (held, not tap) |
| Aim / drop faster | Down (faster fall if 2nd is **not** held) | ArrowDown (faster fall unless shooting) | D-pad Down |
| Quit | EXIT twice | Escape twice (from play → title) | Quit button twice (same Escape edge) |
| Pause | F1 (auto-off ~1 min) | `P` or F1 (no auto-off) | small Pause button |
| Instant off | F1 then MORE | Ignored | — |
| Cheat | F1 then cos | Not in this slice | — |
| Overview map | F1 then Graph | `M` while playing | small Map button |
| Scrollable map | F1 then STAT | Not in this slice | — |

## Phone portrait joypad

- Layout: playfield on top; virtual pad **beneath** the canvas (not overlaid). Centered 3×3 D-pad (cardinals + diagonals) + Fire so either thumb can one-hand; Pause/Map/Quit in a thin row above the cross.
- Show only for coarse pointer in portrait; hide on desktop / fine pointer / landscape.
- Diagonals press both axis flags at once (touch chords are awkward). Multi-touch still allows Fire + a direction together — same flags as keyboard `input.js`.
- Title / banners: tap the overlay or any pad button (`input.any()`).
- Quit: pad **Quit** twice (feeds Escape). Pause / Map are small pad buttons.
- **Initials (game over):** Up/Down cycle A–Z on the current slot; Left/Right move among the three characters; Fire confirms (blanks become A). Desktop can still type three A–Z keys (auto-submit after the third).

## Notes

- Shoot + a direction aims without using that direction as a walk, matching CENGINE’s “2nd held” checks on left/right/down.
- Jump length is still 3 tiles of upward force, then gravity.
