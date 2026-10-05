@echo off
setlocal
set CC65=%USERPROFILE%\cc65
set PATH=%CC65%\bin;%PATH%
set CFG=%~dp0c16-crunch.cfg

if not exist build mkdir build

py -3 "%~dp0tools\gen_version.py"
if errorlevel 1 exit /b 1

echo Assembling...
for %%f in (loadaddr exehdr startup main gfx map level input player sound version) do (
  ca65 -t c16 -I src -I build -o build\%%f.o src\%%f.s
  if errorlevel 1 exit /b 1
)

echo Linking...
ld65 -C "%CFG%" -o c16crunch.prg -m build\crunch.map build\loadaddr.o build\exehdr.o build\startup.o build\main.o build\gfx.o build\map.o build\level.o build\input.o build\player.o build\sound.o build\version.o
if errorlevel 1 exit /b 1

py -3 "%~dp0tools\free_ram.py"

echo Built c16crunch.prg
exit /b 0
