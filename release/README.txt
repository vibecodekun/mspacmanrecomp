Ms. Pac-Man (Tengen, Genesis) - Static Recompilation
=====================================================

A native Windows build of Tengen's 1991 Genesis Ms. Pac-Man, recompiled from
the original 68000 code. The headline feature is a full-maze view: every maze
(Arcade, Mini, Big, Strange) is shown whole, HUD included, with no forced
vertical scrolling.

Source code: https://github.com/vibecodekun/mspacmanrecomp


YOU NEED YOUR OWN ROM
---------------------
No game data is included. You need the USA/Europe Genesis cartridge ROM of
Ms. Pac-Man (Tengen), CRC32 AF041BE6. The launcher checks it for you.


HOW TO PLAY
-----------
1. Unzip this folder anywhere.
2. Run MsPacManRecomp.exe.
3. In the launcher, pick your ROM (it is remembered), then press PLAY.

Default keyboard controls (rebindable in the launcher):
  Player 1   Arrows move, Z / X / C = A / B / C, Enter = Start
  Player 2   I / J / K / L move
  Tab        hold for fast-forward

Xbox and other SDL-compatible controllers work out of the box.

In the options screen, Down moves the cursor and A changes the value.


FULL-MAZE VIEW
--------------
On by default. Change it in the launcher under Mods -> Full maze view, or in
game from the settings overlay:
  All mazes  one 360-line canvas for every maze (default)
  Per maze   window height follows each maze
Turning it off restores the original scrolling view. Title, menus and
intermissions always show at native size.

Command-line use skips the launcher:
  MsPacManRecomp.exe path\to\rom.bin --widescreen off|fit|stage


LICENSE
-------
Released under the PolyForm Noncommercial License 1.0.0 (see LICENSE).
Third-party components and their licenses are listed in
THIRD-PARTY-LICENSES.md.

Ms. Pac-Man is a trademark of Bandai Namco Entertainment. This project is not
affiliated with or endorsed by Bandai Namco, Tengen, or Sega.
