@echo off
set "GAME=%~dp0"
set "LVLDIR=%~dp0..\slvl"
set "DEFAULTLVL=POCMAN.LVL"
call "%~dp0..\vic20engine\build-all.bat" %*
