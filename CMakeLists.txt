cmake_minimum_required(VERSION 3.16)
project(MsPacManRecomp VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# ---------------------------------------------------------------------------
# Ms. Pac-Man (Tengen, 1991) static recompilation.
#
# Shared engine: segagenesisrecomp/ (recompiler + clean-room runner).
# Per-game config and hooks: segagenesisrecomp/mspacman/.
# Generated C is a build product under this build tree, regenerated whenever
# the ROM, game.toml, or the recompiler changes.
# ---------------------------------------------------------------------------

set(RECOMP_ROOT "${CMAKE_SOURCE_DIR}/segagenesisrecomp")
set(RUNNER_ROOT "${RECOMP_ROOT}/runner")

option(GEN_ENABLE_TRACE
    "Build the TCP cmd server + observability rings (frame_snapshots). OFF for release." ON)
if(GEN_ENABLE_TRACE)
    set(GEN_TRACE_SOURCES
        "${RUNNER_ROOT}/cmd_server.c"
        "${RUNNER_ROOT}/frame_snapshots.c")
    add_compile_definitions(GEN_ENABLE_TRACE=1)
else()
    set(GEN_TRACE_SOURCES "${RUNNER_ROOT}/cmd_server_stub.c")
endif()

if(WIN32)
    list(APPEND CMAKE_PREFIX_PATH "${RUNNER_ROOT}/external/SDL2/SDL2-2.28.5/cmake")
endif()
find_package(SDL2 REQUIRED)

set(FM_SOURCES
    "${RUNNER_ROOT}/audio/ym2612_ymfm.cpp"
    "${RUNNER_ROOT}/external/ymfm/src/ymfm_opn.cpp"
    "${RUNNER_ROOT}/external/ymfm/src/ymfm_ssg.cpp"
    "${RUNNER_ROOT}/external/ymfm/src/ymfm_adpcm.cpp"
    "${RUNNER_ROOT}/external/ymfm/src/ymfm_pcm.cpp")

set(OWN_BACKEND_SOURCES
    "${RUNNER_ROOT}/video/genesis_vdp.c"
    "${RUNNER_ROOT}/video/genesis_bus.c"
    "${RUNNER_ROOT}/video/genesis_machine.c"
    "${RUNNER_ROOT}/external/superzazu/z80.c")

set(NATIVE_FLOOR_SOURCES
    "${RUNNER_ROOT}/m68k_interp.c"
    "${RECOMP_ROOT}/recompiler/src/m68k_decoder.c"
    "${RECOMP_ROOT}/recompiler/src/rom_parser.c")

include("${RECOMP_ROOT}/cmake/GenesisRecompGenerated.cmake")
genesisrecomp_add_generated_sources(
    MSPAC_GENERATED_SOURCES mspac mspacman mspacman.bin)

set(MSPAC_SOURCES
    "${RUNNER_ROOT}/main.c"
    "${RUNNER_ROOT}/audio.c"
    "${RUNNER_ROOT}/chip_trace.c"
    ${GEN_TRACE_SOURCES}
    "${RUNNER_ROOT}/glue.c"
    "${RUNNER_ROOT}/fiber_compat.c"
    "${RUNNER_ROOT}/crash_report.c"
    "${RUNNER_ROOT}/input_script.c"
    "${RUNNER_ROOT}/gamepad.c"
    "${RUNNER_ROOT}/input_map.c"
    "${RUNNER_ROOT}/app_config.c"
    "${RUNNER_ROOT}/audio/event_queue.c"
    ${FM_SOURCES}
    "${RUNNER_ROOT}/audio/sn76489.c"
    "${RUNNER_ROOT}/audio/mixer.c"
    "${RUNNER_ROOT}/audio/observability.c"
    "${RUNNER_ROOT}/cosim_state.c"
    "${RUNNER_ROOT}/audio/audio_shadow.c"
    "${RUNNER_ROOT}/audio/fm_shadow.cpp"
    "${RUNNER_ROOT}/video/color_lut.c"
    ${MSPAC_GENERATED_SOURCES}
    "${RECOMP_ROOT}/mspacman/mspacman_spec.c"
    "${RECOMP_ROOT}/mspacman/mspacman_video.c"
    ${NATIVE_FLOOR_SOURCES})

add_executable(MsPacManRecomp ${MSPAC_SOURCES} ${OWN_BACKEND_SOURCES})
add_dependencies(MsPacManRecomp ${MSPAC_GENERATED_SOURCES_TARGET})
target_compile_definitions(MsPacManRecomp PRIVATE
    INCLUDE_GENERATED_CODE=1
    ENABLE_RECOMPILED_CODE=1
    OWN_BACKEND=1
    DEFAULT_DEBUG_PORT=4382
    GENESIS_GAME_VERSION="${PROJECT_VERSION}")
target_include_directories(MsPacManRecomp PRIVATE
    "${RUNNER_ROOT}"
    "${RUNNER_ROOT}/include"
    "${RUNNER_ROOT}/external/ymfm/src"
    "${RUNNER_ROOT}/external/superzazu"
    "${RUNNER_ROOT}/external/clowncommon"
    "${RUNNER_ROOT}/video"
    "${RECOMP_ROOT}/recompiler/src"
    "${RECOMP_ROOT}/mspacman")
target_link_libraries(MsPacManRecomp PRIVATE SDL2::SDL2main SDL2::SDL2)
if(WIN32)
    target_link_libraries(MsPacManRecomp PRIVATE ws2_32 comdlg32)
endif()
if(MSVC)
    target_compile_options(MsPacManRecomp PRIVATE /W3 /WX- /utf-8 /wd4102 /wd4996)
    target_link_options(MsPacManRecomp PRIVATE /MAP)
endif()
if(WIN32)
    add_custom_command(TARGET MsPacManRecomp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${RUNNER_ROOT}/external/SDL2/SDL2-2.28.5/lib/x64/SDL2.dll"
            "$<TARGET_FILE_DIR:MsPacManRecomp>"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${RECOMP_ROOT}/mspacman/mspacman.bin"
            "$<TARGET_FILE_DIR:MsPacManRecomp>/mspacman.bin"
        COMMENT "Staging SDL2.dll and the ROM next to MsPacManRecomp")
endif()
# Shared recomp-ui (Dear ImGui) pre-boot launcher + in-game overlay. Mods are
# exposed so the full-maze view can be toggled from the launcher.
set(RECOMP_UI_ENABLE_MODS ON CACHE BOOL "Expose the full-maze view in the launcher Mods view")
include("${CMAKE_SOURCE_DIR}/recomp-ui/recomp_ui.cmake")
recomp_target_launcher_ui(MsPacManRecomp CONSOLE genesis
    BOXART "${CMAKE_SOURCE_DIR}/assets/boxart.tga")

# Engine framework tests (ROM-independent). Opt-in via -DBUILD_TESTS=ON; with
# recomp-ui present this also builds the launcher Mods test (video_mod).
option(BUILD_TESTS "Build the segagenesisrecomp framework tests" OFF)
if(BUILD_TESTS)
    enable_testing()
    add_subdirectory("${RECOMP_ROOT}/tests" tests)
endif()

# First-run defaults (only when missing): full-maze view on, and the launcher
# pointed at the staged ROM.
add_custom_command(TARGET MsPacManRecomp POST_BUILD
    COMMAND ${CMAKE_COMMAND}
        "-DDST=$<TARGET_FILE_DIR:MsPacManRecomp>/settings.ini"
        "-DROM_CFG=$<TARGET_FILE_DIR:MsPacManRecomp>/rom-MSPAC.cfg"
        "-DROM=$<TARGET_FILE_DIR:MsPacManRecomp>/mspacman.bin"
        -P "${CMAKE_SOURCE_DIR}/cmake/default_settings.cmake"
    COMMENT "Seeding settings.ini / rom-MSPAC.cfg if missing")
