# AGENTS

Commodore 16 port of Chris Busch’s TI-85 **Crunch**.

## Spec

1. **[`SPEC.md`](SPEC.md)** — living port spec (update as we go)
2. **[`reference/CRUNCH.ASM`](reference/CRUNCH.ASM)** — gameplay truth, except levels

## Rules

- Pure ca65 6502; no C
- **16KB Commodore 16**; stock 40×25; playfield 32×16 at column 4, row 4
- Tiles `$60+` only; never redefine A–Z
- Loop: input → logic (map) → VBlank → blit
- Levels are generated. Monsters are placed when the level is built. There is no drip spawn.
- When behavior is locked or fixed, **update `SPEC.md` in the same turn**

## Build

`build.bat` → `c16crunch.prg`. `run.bat` starts VICE `xplus4 -model c16`.
