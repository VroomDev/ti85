# Crunch (VIC-20)

Port of Chris Busch’s TI-85 **Crunch** to an **unexpanded** VIC-20 (6502 / ca65 only).

Download crunch.prg. Tested in vice vic 20 with 5k. Keyboard and joystick 🕹️ support. 

I used Cursor to help me port my TI-85 Crunch game over to Commodore vic-20. It was difficult to make it fit into the 5k and still have the 8 levels. I had to improve the game mechanics where it uses less memory to do more! The TI-85 has a lot of RAM and a 6mhz CPU so more powered than the Vic 20.

**Spec:** [SPEC.md](SPEC.md).

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

If you are simply to play the game, then no need to monkey with cc65.
