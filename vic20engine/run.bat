@echo off
setlocal
set VICE=%USERPROFILE%\GTK3VICE-3.10-win64\bin

if not defined GAME set "GAME=%~dp0"
if not defined DEFAULTLVL set "DEFAULTLVL=POCMAN.LVL"

if "%~1"=="" (
  set "PRGNAME=%DEFAULTLVL:.LVL=.prg%"
) else (
  set "PRGNAME=%~n1.prg"
)
set "PRGFILE=%GAME%prg\%PRGNAME%"
if not exist "%PRGFILE%" (
  call "%~dp0build.bat" %*
  if errorlevel 1 exit /b 1
)
"%VICE%\xvic.exe" -memory all -autostart "%PRGFILE%"
