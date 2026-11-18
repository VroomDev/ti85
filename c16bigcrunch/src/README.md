
## Build for Commodore 16

Requires [cc65](https://cc65.github.io/) at `%USERPROFILE%\cc65`.

To build this, in the prior directory, there is:
```bat
build.bat
```


Produces `c16crunch.prg`.

## Run (NTSC, unexpanded)

```bat
%USERPROFILE%\GTK3VICE-3.10-win64\bin\xvic.exe -ntsc -autostart c16crunch.prg
```

If you are simply to play the game, then no need to monkey with cc65.
