# AGENTS

VIC-20 port of Chris Busch’s TI-85 **Crunch**.

## Spec

1. **[`SPEC.md`](SPEC.md)** — living port spec (update as we go)
2. **[`reference/CRUNCH.ASM`](reference/CRUNCH.ASM)** — gameplay truth (direct conversion)

## Rules

- Pure ca65 6502; no C
- **Unexpanded** VIC-20; stock 22×23; playfield at col 3, row 6
- Tiles `$60+` only; never redefine A–Z
- Loop: input → logic (map) → VBlank → blit
- When behavior is locked or fixed, **update `SPEC.md` in the same turn**

## Build

`build.bat` → `crunch.prg`
