# Third-Party Components and Licenses

MsPacManRecomp is built from the segagenesisrecomp engine and the recomp-ui
launcher. The components below are compiled into `MsPacManRecomp.exe` or ship
beside it in `SDL2.dll` and `assets/`. Each keeps its own license, separate
from the project's PolyForm Noncommercial license (`LICENSE`).

## Engine and launcher

| Component | Role | License | Source |
|---|---|---|---|
| **segagenesisrecomp**, Copyright (c) 2026 Matthew Stan | Recompiler output runtime, clean-room VDP/bus/scheduler, interpreter floor | PolyForm Noncommercial 1.0.0 | <https://github.com/mstan/segagenesisrecomp> |
| **m68k-recomp-core** | 68000 decoder used by the interpreter floor | Project-owned; see its repository | <https://github.com/mstan/m68k-recomp-core> |
| **recomp-ui**, Copyright (c) 2026 Matthew Stanley | Pre-boot launcher and in-game overlay | MIT | <https://github.com/RetroPortingToolKit/recomp-ui> |

## Runtime dependencies

| Component | Role | License | Source |
|---|---|---|---|
| **ymfm** | YM2612 FM synthesis | BSD-3-Clause | <https://github.com/aaronsgiles/ymfm> |
| **superzazu/z80** | Z80 sound CPU | MIT | <https://github.com/superzazu/z80> |
| **clowncommon** | Integer types and small C helpers | ISC | <https://github.com/Clownacy/clowncommon> |
| **SDL2** 2.28.5 (`SDL2.dll`) | Window, input, rendering, audio output | zlib | <https://libsdl.org> |
| **ShadowVerifier and color-science core** | Opt-in verified audio/video enhancements | MIT OR Apache-2.0 | <https://github.com/JRickey/gba-recomp> |

## Launcher dependencies

| Component | Role | License | Source |
|---|---|---|---|
| **Dear ImGui**, Copyright (c) 2014-2025 Omar Cornut | Launcher and overlay UI | MIT | <https://github.com/ocornut/imgui> |
| **stb_image / stb_truetype / stb_image_write** | Image and font loading | Public domain or MIT | <https://github.com/nothings/stb> |
| **tinyfiledialogs** | Native ROM file picker | zlib | <https://sourceforge.net/projects/tinyfiledialogs/> |
| **Lato** (`assets/fonts/LatoLatin-*.ttf`) | Launcher typeface | SIL Open Font License 1.1 | <https://www.latofonts.com> |
| **Noto Sans Symbols 2** (`assets/fonts/NotoSansSymbols2-Regular.ttf`), Copyright (c) The Noto Project Authors | Symbol fallback font | SIL Open Font License 1.1 | <https://github.com/notofonts/symbols> |
| **OpenMoji** (`assets/fonts/OpenMoji-black-glyf.ttf`), Copyright (c) OpenMoji Project | Emoji fallback font | CC BY-SA 4.0 | <https://openmoji.org> |
| **Country flags** (`assets/img/flags.png`), rendered from Noto Color Emoji, Copyright (c) The Noto Project Authors | Flag sprite sheet | SIL Open Font License 1.1 | <https://github.com/googlefonts/noto-emoji> |

Full license texts:

- PolyForm Noncommercial 1.0.0: <https://polyformproject.org/licenses/noncommercial/1.0.0>
- MIT: <https://opensource.org/license/mit>
- BSD-3-Clause: <https://opensource.org/license/bsd-3-clause>
- ISC: <https://opensource.org/license/isc-license-txt>
- zlib: <https://zlib.net/zlib_license.html>
- Apache-2.0: <https://www.apache.org/licenses/LICENSE-2.0>
- SIL Open Font License 1.1: <https://openfontlicense.org>
- CC BY-SA 4.0: <https://creativecommons.org/licenses/by-sa/4.0/>

## The game

Ms. Pac-Man is a trademark of Bandai Namco Entertainment. The Genesis version
was published by Tengen in 1991. This release contains no ROM: you supply your
own copy. The executable holds a machine translation of the game's 68000 code,
and the licenses above cannot grant any rights to that code. This project is
not affiliated with or endorsed by Bandai Namco, Tengen, or Sega.
