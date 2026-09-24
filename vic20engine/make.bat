@echo off
call "%~dp0build.bat" %*
if errorlevel 1 exit /b 1
pause
call "%~dp0run.bat" %*
