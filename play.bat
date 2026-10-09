@echo off
rem Launch the Ms. Pac-Man recomp built by tools/build_windows.sh x64 through
rem the recomp-ui launcher (pick the ROM once; it is remembered in
rem rom-MSPAC.cfg). Passing a ROM path skips the launcher, e.g.:
rem   play.bat mspacman.bin --widescreen off     (original scrolling view)
rem   play.bat mspacman.bin --widescreen stage   (canvas height follows each maze)
cd /d "%~dp0build\x64"
start "" MsPacManRecomp.exe %*
