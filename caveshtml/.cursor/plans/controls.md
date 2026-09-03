# Controls

Original (README): simultaneous keys; CENGINE only polls some buttons.

| Action | TI-85 | Browser |
|--------|--------|---------|
| Move | arrows | Arrow keys |
| Jump | ALPHA (also up arrow in later ASM) | Space or ArrowUp |
| Shoot | 2nd | `X`, `Z`, or Control |
| Aim / drop faster | Down (faster fall if 2nd is **not** held) | ArrowDown (faster fall unless shooting) |
| Quit | EXIT twice | Escape twice (from play → title) |
| Pause | F1 (auto-off ~1 min) | `P` or F1 (no auto-off) |
| Instant off | F1 then MORE | Ignored |
| Cheat | F1 then cos | Not in this slice |
| Overview map | F1 then Graph | `M` while playing |
| Scrollable map | F1 then STAT | Not in this slice |

## Notes

- Shoot + a direction aims without using that direction as a walk, matching CENGINE’s “2nd held” checks on left/right/down.
- Jump length is still 3 tiles of upward force, then gravity.
