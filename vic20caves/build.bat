@echo off
setlocal
set CC65=%USERPROFILE%\cc65
set PATH=%CC65%\bin;%PATH%

if "%~1"=="" (
  set "LVLFILE=%~dp0CASTLE.LVL"
  set "PRGNAME=CASTLE.prg"
) else (
  set "LVLFILE=%~1"
  set "PRGNAME=%~n1.prg"
)

set "PRGDIR=%~dp0prg"
if not exist "%PRGDIR%" mkdir "%PRGDIR%"

echo Generating charset.h from %LVLFILE%...
python "%~dp0gen-charset.py" "%LVLFILE%"
if errorlevel 1 exit /b 1

echo Generating level.h from %LVLFILE%...
python "%~dp0gen-level.py" "%LVLFILE%"
if errorlevel 1 exit /b 1

echo Compiling for VIC-20 +32K...

del header.s.*.o 2>nul

cl65 -O -t vic20 -C "%~dp0vic20-map.cfg" -o "%PRGDIR%\%PRGNAME%" header.s main.c
rem    cl65 -O -t vic20 -C vic20-32k.cfg -o mapview.prg header.s main.c

if errorlevel 1 exit /b 1

echo Built prg\%PRGNAME%
exit /b 0
