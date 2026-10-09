# Third-Party Components and Licenses

Ms. Pac-Man Recomp is built from the segagenesisrecomp recompiler and runtime
and the recomp-ui launcher. The components below are compiled into
`MsPacManRecomp.exe` / `MsPacManRecomp`, or ship beside it as DLLs,
`librashader.so`, `assets/` and `shaders/`. Each keeps its own license,
separate from the project's PolyForm Noncommercial license (`LICENSE`).

## Engine and launcher

| Component | Role | License | Source |
|---|---|---|---|
| **segagenesisrecomp**, Copyright (c) 2026 Matthew Stan | Recompiler and the runtime compiled into the game (clean-room VDP, bus and scheduler, interpreter floor, GL frontend) | PolyForm Noncommercial 1.0.0 | <https://github.com/mstan/segagenesisrecomp>, this build: <https://github.com/vibecodekun/segagenesisrecomp/tree/mspacman> |
| **m68k-recomp-core**, Copyright (c) 2026 Matthew Stan | 68000 decoder used by the interpreter floor | PolyForm Noncommercial 1.0.0 | <https://github.com/mstan/m68k-recomp-core> |
| **rbengine**, Copyright (c) 2026 retcomm-rbengine contributors | Rollback snapshots behind rewind, preemptive frames and save states | MIT | <https://github.com/RetroPortingToolKit/rbengine> |
| **minicoro**, with Windows x86 and ARM64 context switches added for this build | The game fiber's context switch | Unlicense OR MIT-0; its x86-64 Windows switch derives from LuaCoco (MIT, Mike Pall) | <https://github.com/edubart/minicoro> |
| **ymfm** | YM2612 FM synthesis | BSD-3-Clause | <https://github.com/aaronsgiles/ymfm> |
| **superzazu/z80** | Z80 sound CPU | MIT | <https://github.com/superzazu/z80> |
| **clowncommon** | Integer types and small C helpers | ISC | <https://github.com/Clownacy/clowncommon> |
| **ShadowVerifier and color-science core** | Opt-in verified audio/video enhancements | MIT OR Apache-2.0 | <https://github.com/JRickey/gba-recomp> |
| **recomp-ui**, Copyright (c) 2026 Matthew Stanley | Pre-boot launcher and in-game menu | MIT | <https://github.com/RetroPortingToolKit/recomp-ui>, this build: <https://github.com/vibecodekun/recomp-ui/tree/shantae> |
| **Dear ImGui**, Copyright (c) 2014-2025 Omar Cornut | Launcher, menu and settings UI | MIT | <https://github.com/ocornut/imgui> |
| **stb_image / stb_image_write / stb_truetype** | Image and font loading, screenshots | Public domain or MIT | <https://github.com/nothings/stb> |
| **tinyfiledialogs** | Native ROM file picker | zlib | <https://sourceforge.net/projects/tinyfiledialogs/> |

## Libraries

| Component | Where | License | Source |
|---|---|---|---|
| **SDL2** 2.32 | `SDL2.dll` (Windows); linked in (Linux) | zlib | <https://libsdl.org> |
| **ANGLE** | `libEGL.dll`, `libGLESv2.dll` (Windows) | BSD-3-Clause | <https://chromium.googlesource.com/angle/angle> |
| **librashader** 0.12.0, with the patches in `third_party/librashader/patches/` | `librashader.dll` / `librashader.so` | MPL-2.0 (C headers: MIT) | <https://github.com/SnowflakePowered/librashader> |
| **slang-shaders** | `shaders/` | Per shader, stated in each file (mostly GPL-2.0-or-later, MIT or public domain) | <https://github.com/libretro/slang-shaders> |
| **zlib** 1.3 | `zlib1.dll` (Windows) | zlib | <https://zlib.net> |
| **GCC runtime** (`libgcc_s_*.dll`, `libstdc++-6.dll`) | Windows x64 and x86 | GPL-3.0 with the GCC Runtime Library Exception | <https://gcc.gnu.org> |
| **mingw-w64 winpthreads** (`libwinpthread-1.dll`) | Windows x64 and x86 | MIT and others (see its COPYING) | <https://www.mingw-w64.org> |
| **LLVM libc++, libunwind, compiler-rt** | `libc++.dll` (Windows ARM64); linked in (Linux) | Apache-2.0 WITH LLVM-exception | <https://llvm.org> |
| **AppImage runtime** | The `.AppImage` files | MIT | <https://github.com/AppImage/type2-runtime> |

## Fonts and images

| Component | License | Source |
|---|---|---|
| **Lato** (`assets/fonts/LatoLatin-*.ttf`) | SIL Open Font License 1.1 | <https://www.latofonts.com> |
| **Noto Sans Symbols 2** (`assets/fonts/NotoSansSymbols2-Regular.ttf`), Copyright (c) The Noto Project Authors | SIL Open Font License 1.1 | <https://github.com/notofonts/symbols> |
| **OpenMoji** (`assets/fonts/OpenMoji-black-glyf.ttf`), Copyright (c) OpenMoji Project | CC BY-SA 4.0 | <https://openmoji.org> |
| **Country flags** (`assets/img/flags.png`), rendered from Noto Color Emoji, Copyright (c) The Noto Project Authors | SIL Open Font License 1.1 | <https://github.com/googlefonts/noto-emoji> |

Full license texts:

- PolyForm Noncommercial 1.0.0: <https://polyformproject.org/licenses/noncommercial/1.0.0>
- MIT: <https://opensource.org/license/mit>
- MIT-0: <https://opensource.org/license/mit-0>
- Unlicense: <https://unlicense.org>
- BSD-3-Clause: <https://opensource.org/license/bsd-3-clause>
- ISC: <https://opensource.org/license/isc-license-txt>
- zlib: <https://zlib.net/zlib_license.html>
- MPL-2.0: <https://www.mozilla.org/MPL/2.0/>
- Apache-2.0: <https://www.apache.org/licenses/LICENSE-2.0>
- GPL-3.0 and the GCC Runtime Library Exception: <https://www.gnu.org/licenses/gcc-exception-3.1.html>
- Apache-2.0 WITH LLVM-exception: <https://llvm.org/LICENSE.txt>
- SIL Open Font License 1.1: <https://openfontlicense.org>
- CC BY-SA 4.0: <https://creativecommons.org/licenses/by-sa/4.0/>

## The game

Ms. Pac-Man is a trademark of Bandai Namco Entertainment. The Genesis version
was published by Tengen in 1991. This release contains no ROM: you supply your
own copy. The executable holds a machine translation of the game's 68000 code,
and the licenses above cannot grant any rights to that code. The box art the
launcher shows is a capture of the game running. This project is not
affiliated with or endorsed by Bandai Namco, Tengen, or Sega.
