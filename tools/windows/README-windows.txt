Ms. Pac-Man (Tengen, Genesis), recompiled - Windows build
==========================================================

There is one zip per kind of processor:

  windows-x64     64-bit Intel and AMD PCs: almost every Windows PC
  windows-x86     32-bit Windows (x86)
  windows-arm64   ARM PCs: Snapdragon X laptops, Surface Pro X and 9 5G,
                  Windows Dev Kit 2023. (They run the x64 build too, through
                  emulation; this one runs natively.)

Windows 10 or 11, and a graphics driver with Direct3D 11. The game draws
through ANGLE (OpenGL ES on Direct3D), which comes with it, as do SDL2 and
librashader for the shader presets; nothing else needs installing.

You need your own Ms. Pac-Man (USA, Europe) Genesis ROM: the No-Intro dump
"Ms. Pac-Man (USA, Europe).md", SHA-256
87f3c75fea5c4e105163a3b6d4467527fdc3fcc4b8e385155067719b98b2be7c
(CRC32 AF041BE6). The launcher reads "ROM verified" for it and starts no
other file.


Running
-------
Extract the zip to a folder you can write to (your Documents or Desktop, not
Program Files) and run MsPacManRecomp.exe in it. Settings, save states and
rom-MSPAC.cfg are kept in that folder; to update, copy a newer version's
files over the old ones there.

Windows may say it protected your PC from an unrecognized app: click
"More info", then "Run anyway".

Esc, or a controller's Guide/Home button, opens the in-game menu (settings,
the full-maze view, shader presets). F10 opens the full settings window.


Keyboard
--------
  Arrows          move           Z / X / C     A / B / C
  Enter           Start          Esc           menu
  Tab (hold)      fast forward   `             fast forward on/off
  R (hold)        rewind         P / O         pause / advance one frame
  F5 / F8         save / load    F6 / F7       previous / next state slot
  F1              overlay        F9            mute
  F11             fullscreen

Save states can be made during play (not on the title or demo screens).
Controllers work out of the box; the triggers fast forward (right) and
rewind (left). Everything can be rebound: game buttons in the launcher's
Controllers page or the settings window, shortcuts in the settings window
(Advanced > Controls).


Troubleshooting
---------------
- MSPAC.log in the game's folder has what the game reports.
- A preset under Shader Presets compiles in the background the first time it
  is picked (up to a minute for the biggest Mega Bezel ones) and loads in a
  moment after that.
- A graphics driver without OpenGL ES through Direct3D 11 (some remote
  desktops and virtual machines) gets the plain picture without the menus'
  newer look or shader presets.
