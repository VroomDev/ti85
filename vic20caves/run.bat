@echo off
setlocal
set VICE=%USERPROFILE%\GTK3VICE-3.10-win64\bin
if "%~1"=="" (
  set "PRGNAME=CASTLE.prg"
) else (
  set "PRGNAME=%~n1.prg"
)
set "PRGFILE=%~dp0prg\%PRGNAME%"
if not exist "%PRGFILE%" (
  call "%~dp0build.bat" %*
  if errorlevel 1 exit /b 1
)
"%VICE%\xvic.exe"  -memory all -autostart "%PRGFILE%"
