# Crunch (VIC-20)

Port of Chris Busch’s TI-85 **Crunch** to an **unexpanded** VIC-20 (6502 / ca65 only).

**Spec:** [SPEC.md](SPEC.md). Update that file when behavior is locked or fixed.

## Build

Requires [cc65](https://cc65.github.io/) at `%USERPROFILE%\cc65`.

```bat
build.bat
```

Produces `crunch.prg`.

## Run (NTSC, unexpanded)

```bat
%USERPROFILE%\GTK3VICE-3.10-win64\bin\xvic.exe -ntsc -autostart crunch.prg
```
