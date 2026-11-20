@echo off
setlocal
cd /d "%~dp0"

if not exist c16bigcrunch.prg (
  echo c16bigcrunch.prg not found. Run build.bat first.
  exit /b 1
)

set XPLUS4=%USERPROFILE%\GTK3VICE-3.10-win64\bin\xplus4.exe
if not exist "%XPLUS4%" (
  echo xplus4.exe not found: %XPLUS4%
  exit /b 1
)

"%XPLUS4%" -model c16 +maximized -autostart c16bigcrunch.prg
exit /b %ERRORLEVEL%
