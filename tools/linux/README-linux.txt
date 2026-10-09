Ms. Pac-Man (Tengen, Genesis), recompiled - Linux build
========================================================

Runs on 64-bit x86 (x86_64) and 64-bit ARM (aarch64) Linux with glibc 2.28
or newer: Debian 10+, Ubuntu 20.04+, Fedora, Arch, RHEL/Alma/Rocky 8+,
openSUSE Leap 15.3+, SteamOS 3 (Steam Deck), Raspberry Pi OS (64-bit) and
the like. It needs an OpenGL ES 2.0 capable graphics driver (Mesa or
NVIDIA's; 3.0 for the shader presets) and X11 or Wayland. SDL2 and the C++
runtime are built in.

You need your own Ms. Pac-Man (USA, Europe) Genesis ROM: the No-Intro dump
"Ms. Pac-Man (USA, Europe).md", SHA-256
87f3c75fea5c4e105163a3b6d4467527fdc3fcc4b8e385155067719b98b2be7c
(CRC32 AF041BE6). The launcher asks for it on the first start, reads
"ROM verified" for it and starts no other file.


Running
-------
Tarball: extract it anywhere you can write to and run ./MsPacManRecomp in
the extracted folder (or double-click it). Settings, save states and
rom-MSPAC.cfg are kept in that folder.

AppImage: make it executable (chmod +x MsPacMan_Recomp-*.AppImage, or the
file's Properties > Permissions) and run it. Settings and save states are
kept in the folder the .AppImage is in. If it says it cannot mount (no
FUSE), run it with --appimage-extract-and-run.

Esc, or a controller's Guide/Home button, opens the in-game menu (settings,
the full-maze view, shader presets). F10 opens the full settings window.

Steam Deck: in Desktop Mode, put the AppImage (or the extracted folder) in
your home folder, e.g. ~/Games/MsPacMan, make it executable, then right-click
it > "Add to Steam". It then starts from Game Mode like any other game,
with the Deck's controls through Steam Input. The Steam button belongs to
Steam there, so to reach the in-game menu bind one of the back buttons
(L4/R4/L5/R5) to the keyboard's Escape key in the game's controller
settings.


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
- Run it from a terminal to see what it reports.
- The ROM file picker uses zenity or kdialog when either is installed, and
  its own picker otherwise.
- SDL uses X11 (XWayland on a Wayland desktop) by default; set
  SDL_VIDEODRIVER=wayland to run on Wayland directly.
- No sound: it plays through PipeWire, PulseAudio or ALSA, whichever the
  system has; with none of them it runs silently.
- A preset under Shader Presets compiles in the background the first time it
  is picked (up to a minute for the biggest Mega Bezel ones) and loads in a
  moment after that. Shader presets need librashader.so beside the game
  (included).
