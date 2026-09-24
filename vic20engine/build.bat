@echo off
setlocal
set CC65=%USERPROFILE%\cc65
set PATH=%CC65%\bin;%PATH%

if not defined GAME set "GAME=%~dp0"
if not defined LVLDIR set "LVLDIR=%GAME%..\slvl"
if not defined DEFAULTLVL set "DEFAULTLVL=POCMAN.LVL"
set "OUTDIR=%GAME%"
set "DEFCHARS=%GAME%DEFCHARS.DEF"

cd /d "%GAME%"

if "%~1"=="" (
  set "LVLFILE=%LVLDIR%\%DEFAULTLVL%"
  set "PRGNAME=%DEFAULTLVL:.LVL=.prg%"
) else (
  set "LVLFILE=%~1"
  set "PRGNAME=%~n1.prg"
)

set "PRGDIR=%GAME%prg"
if not exist "%PRGDIR%" mkdir "%PRGDIR%"

echo Generating charset.h from %LVLFILE% using %DEFCHARS%...
python "%~dp0gen-charset.py" "%LVLFILE%"
if errorlevel 1 exit /b 1

echo Generating level.h from %LVLFILE%...
python "%~dp0gen-level.py" "%LVLFILE%"
if errorlevel 1 exit /b 1

echo Compiling for VIC-20 +32K...

del "%~dp0header.s.*.o" 2>nul
del "%PRGDIR%\header.s.*.o" 2>nul

cl65 -O -t vic20 -C "%~dp0vic20-map.cfg" -o "%PRGDIR%\%PRGNAME%" "%~dp0header.s" main.c
if errorlevel 1 exit /b 1

echo Built %PRGDIR%\%PRGNAME%
exit /b 0
