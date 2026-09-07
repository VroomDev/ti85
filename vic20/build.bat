@echo off
setlocal
set CC65=%USERPROFILE%\cc65
set PATH=%CC65%\bin;%PATH%

echo Generating charset.h...
python "%~dp0gen-charset.py"
if errorlevel 1 exit /b 1

echo Compiling for VIC-20 +32K...
cl65 -O -t vic20 -C "%~dp0vic20-map.cfg" -o mapview.prg header.s main.c
rem    cl65 -O -t vic20 -C vic20-32k.cfg -o mapview.prg header.s main.c

if errorlevel 1 exit /b 1

echo Built mapview.prg
exit /b 0
