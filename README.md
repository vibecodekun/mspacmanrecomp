# Ms. Pac-Man (Tengen, Genesis) — static recompilation with a full-maze view

<p align="center">
  <img src="docs/screenshot.png" alt="Arcade maze shown whole in the full-maze view" width="256" />
</p>

A native PC build of Tengen's 1991 Genesis Ms. Pac-Man, produced by
[segagenesisrecomp](https://github.com/mstan/segagenesisrecomp) from the
original ROM. The headline feature is a **vertical full-maze view**: every maze
type (Arcade, Mini, Big, Strange) is shown in full, HUD included, with no
forced scrolling.

## Download

Grab the latest Windows build from
[Releases](https://github.com/vibecodekun/mspacmanrecomp/releases/latest), unzip
it, run `MsPacManRecomp.exe`, and point the launcher at your ROM.

**No ROM is included.** You need your own USA/Europe Genesis ROM of Ms.
Pac-Man (Tengen), CRC32 `AF041BE6`; the launcher verifies it.

## Layout

| Path | What |
|---|---|
| `CMakeLists.txt` | Game build (recompiler → generated C → `MsPacManRecomp.exe`) |
| `segagenesisrecomp/` | Recompiler + clean-room runtime (submodule: [fork](https://github.com/vibecodekun/segagenesisrecomp/tree/mspacman) of [mstan/segagenesisrecomp](https://github.com/mstan/segagenesisrecomp), branch `mspacman`) |
| `segagenesisrecomp/mspacman/game.toml` | Recompiler config for this ROM |
| `segagenesisrecomp/mspacman/mspacman_spec.c` | Game hooks: interrupt model (see below) |
| `segagenesisrecomp/mspacman/mspacman_video.c` | Full-maze view renderer |
| `segagenesisrecomp/mspacman/mspacman.bin` | The ROM (you supply it; gitignored) |
| `recomp-ui/` | Shared launcher + in-game settings overlay (submodule: [RetroPortingToolKit/recomp-ui](https://github.com/RetroPortingToolKit/recomp-ui)) |
| `assets/boxart.tga` | Launcher box art (placeholder cut from the title screen) |
| `cmake/default_settings.cmake` | First-run `settings.ini` / `rom-MSPAC.cfg` seeding |
| `release/` | Files that ship in the release zip (README, notices, default settings) |
| `play.bat` | Launch the built game |

## Build

Requires Visual Studio 2022 (C/C++ workload), CMake 3.16+ and Git. Put your
ROM at `segagenesisrecomp/mspacman/mspacman.bin` (USA/Europe, CRC32
`AF041BE6`) after cloning.

```bat
git clone --recursive https://github.com/vibecodekun/mspacmanrecomp.git
cd mspacmanrecomp
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release --target MsPacManRecomp
```

Already cloned without `--recursive`? Run
`git submodule update --init --recursive`.

Generated C lives only in `build/generated/mspac/` and is regenerated whenever
the ROM, `game.toml`, or the recompiler changes.

## Run

```bat
play.bat
```

This opens the recomp-ui launcher: controller setup (3/6-button, keyboard or
pad, rebinding), Settings, and **Mods → Full maze view** (on/off, and
Canvas: *All mazes* = one 360-line canvas, *Per maze* = height follows each
maze). The first build points the launcher at the staged ROM, so it opens
already verified; press **PLAY**. Tick "Skip launcher on boot" to go straight
into the game next time. In game, the runtime overlay offers the same view
toggle plus window scale, fullscreen, filtering and volume.

Passing a ROM path skips the launcher (`play.bat mspacman.bin ...`) and allows
overrides: `--widescreen off` (original scrolling view), `--widescreen fit`,
`--widescreen stage`.

Full-view heights: Mini 264, Strange 304–312, Arcade 312, Big 360 lines
(native is 224). Title, menus and intermissions are shown at native size.

## How the full view works

The game draws each whole maze into a 256×512 plane when the maze loads, and
all scrolling is one camera word (`$FF000E`) copied to VSRAM each V-blank.
Sprites are kept in screen space and re-based by the game when the camera
moves. So the renderer locks the camera at the top of the playfield, draws
the planes from VRAM, and shifts each sprite by `game camera − locked camera`.
Game logic is untouched. The view verifies itself every frame: the 224 rows
the hardware raster produced must reappear unchanged in the tall frame (TCP
command `mspac_view`, see below).

## Interrupt model

All gameplay runs inside the V-blank interrupt. The main program only unmasks
interrupts in two `BRA *` idle loops (`$0008F6`, `$00F76E`), and the handler
can run for many frames or discard its own exception frame and continue as
main-program code. `mspacman_spec.c` therefore takes IRQ6 on the game fiber
from those idle loops (see the comment at the top of that file).

## Sound

The Z80 sound driver times its music off the YM2612's **Timer A** (it polls
the status flag at Z80 `$014D`). The runner's synchronous YM status model
originally implemented only Timer B, so the driver never ticked and the game
was silent; Timer A now lives beside it in `runner/video/genesis_bus.c`.
Save states from before that change are refused (format tag `GROWNS3`).

## Tests

```bat
cmake -S . -B build -DBUILD_TESTS=ON
cmake --build build --config Release
ctest --test-dir build -C Release
```

Runs the engine's ROM-independent suite, including the launcher Mods test.

## Debugging

Dev builds include the TCP debug server (`GEN_ENABLE_TRACE`, on by default;
release builds turn it off). Put a `debug.ini` containing `port=4382` next to
the exe to enable it, then e.g.:

```bat
python segagenesisrecomp\tools\tcp_cmd.py 4382 "{\"id\":1,\"cmd\":\"mspac_view\"}"
```

After every run, `build/Release/dispatch_misses.toml` should list no
functions (it has been empty for every run so far).

## Packaging a release

Follow `segagenesisrecomp/RELEASING.md`: build with the debug server off, then
package with the allowlist tool, which refuses to include a ROM or build junk.
Never zip the build folder by hand, because the build copies the ROM next to
the exe.

```bat
cmake -S . -B build-release -G "Visual Studio 17 2022" -A x64 -DGEN_ENABLE_TRACE=OFF
cmake --build build-release --config Release --target MsPacManRecomp
python segagenesisrecomp\tools\package_release.py ^
    --exe build-release\Release\MsPacManRecomp.exe ^
    --extra build-release\Release\SDL2.dll release\settings.ini ^
    --asset-dir build-release\Release\assets ^
    --license LICENSE --notices release\THIRD-PARTY-LICENSES.md ^
    --readme release\README.txt ^
    --out dist\MsPacManRecomp-vX.Y.Z-win64.zip
```

`release/settings.ini` ships in the zip so the full-maze view is on at first
launch. Without it the runtime defaults to the original scrolling view.

## License

PolyForm Noncommercial 1.0.0 (`LICENSE`), the same as the segagenesisrecomp
engine (Copyright (c) 2026 Matthew Stan). recomp-ui is MIT (Copyright (c) 2026
Matthew Stanley). Other components are listed in
`release/THIRD-PARTY-LICENSES.md`.

Ms. Pac-Man is a trademark of Bandai Namco Entertainment. This project
contains no ROM; the box art and screenshot are captures of the game running.
It is not affiliated with or endorsed by Bandai Namco, Tengen, or Sega.
