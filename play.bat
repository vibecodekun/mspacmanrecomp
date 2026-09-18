@echo off
rem Launch the Ms. Pac-Man recomp through the recomp-ui launcher (pick the ROM
rem once; it is remembered in rom-MSPAC.cfg). Passing a ROM path skips the
rem launcher, e.g.:
rem   play.bat mspacman.bin --widescreen off     (original scrolling view)
rem   play.bat mspacman.bin --widescreen stage   (canvas height follows each maze)
cd /d "%~dp0build\Release"
start "" MsPacManRecomp.exe %*
