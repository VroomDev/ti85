@echo off
set "GAME=%~dp0"
set "LVLDIR=%~dp0..\clvl"
set "DEFAULTLVL=CASTLE.LVL"
call "%~dp0..\vic20engine\make.bat" %*
