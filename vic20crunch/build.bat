@echo off
setlocal
set CC65=%USERPROFILE%\cc65
set PATH=%CC65%\bin;%PATH%
set CFG=%~dp0vic20-crunch.cfg

if not exist build mkdir build

echo Packing maps from CRUNCH.ASM...
py -3 "%~dp0tools\pack_maps.py"
if errorlevel 1 exit /b 1

echo Assembling...
for %%f in (loadaddr exehdr startup main gfx map level input player sound) do (
  ca65 -t vic20 -I src -I build -o build\%%f.o src\%%f.s
  if errorlevel 1 exit /b 1
)

echo Linking...
ld65 -C "%CFG%" -o crunch.prg -m build\crunch.map build\loadaddr.o build\exehdr.o build\startup.o build\main.o build\gfx.o build\map.o build\level.o build\input.o build\player.o build\sound.o
if errorlevel 1 exit /b 1

echo Built crunch.prg
exit /b 0
