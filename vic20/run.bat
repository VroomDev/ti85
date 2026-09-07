@echo off
setlocal
set VICE=%USERPROFILE%\GTK3VICE-3.10-win64\bin
if not exist mapview.prg (
  call "%~dp0build.bat"
  if errorlevel 1 exit /b 1
)
"%VICE%\xvic.exe"  -memory all -autostart "%~dp0mapview.prg"
