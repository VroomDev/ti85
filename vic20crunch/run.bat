@echo off
setlocal
cd /d "%~dp0"

if not exist crunch.prg (
  echo crunch.prg not found. Run build.bat first.
  exit /b 1
)

set XVIC=%USERPROFILE%\GTK3VICE-3.10-win64\bin\xvic.exe
if not exist "%XVIC%" (
  echo xvic.exe not found: %XVIC%
  exit /b 1
)

"%XVIC%"  +maximized  -autostart crunch.prg
exit /b %ERRORLEVEL%
