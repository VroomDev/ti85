@echo off
setlocal EnableDelayedExpansion

if not defined GAME set "GAME=%~dp0"
if not defined LVLDIR set "LVLDIR=%GAME%..\slvl"
set "OK=0"
set "FAIL=0"

if not exist "%LVLDIR%\" (
  echo LVL directory not found: %LVLDIR%
  exit /b 1
)

if not exist "%LVLDIR%\*.LVL" (
  echo No .LVL files in %LVLDIR%
  exit /b 1
)

for %%F in ("%LVLDIR%\*.LVL") do (
  echo.
  echo === %%~nxF ===
  call "%~dp0build.bat" "%%F"
  if errorlevel 1 (
    echo FAILED %%~nxF
    set /a FAIL+=1
  ) else (
    set /a OK+=1
  )
)

echo.
echo Built !OK!  failed !FAIL!
if !FAIL! neq 0 exit /b 1
exit /b 0
