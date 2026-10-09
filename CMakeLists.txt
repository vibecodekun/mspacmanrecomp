cmake_minimum_required(VERSION 3.20)
project(MsPacManRecomp VERSION 0.2.0 LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# ---------------------------------------------------------------------------
# Ms. Pac-Man (Tengen, 1991) static recompilation.
#
# Shared engine: segagenesisrecomp/ (recompiler + clean-room runner).
# Game adapter and recompiler config: game/ (this repository).
# Generated C is a build product under this build tree, regenerated whenever
# the ROM, game/game.toml, or the recompiler changes.
# ---------------------------------------------------------------------------

set(RECOMP_ROOT "${CMAKE_SOURCE_DIR}/segagenesisrecomp")
set(RUNNER_ROOT "${RECOMP_ROOT}/runner")
set(MSPAC_GAME_DIR "${CMAKE_SOURCE_DIR}/game")

option(GEN_ENABLE_TRACE
    "Build the TCP cmd server + observability rings (frame_snapshots). OFF for release." ON)
if(GEN_ENABLE_TRACE)
    add_compile_definitions(GEN_ENABLE_TRACE=1)
endif()

# SDL2: the vendored Visual C++ package for MSVC builds; msys2's (or the
# release toolchain's, tools/windows/toolchain.cmake) everywhere else.
if(MSVC)
    list(APPEND CMAKE_PREFIX_PATH "${RUNNER_ROOT}/external/SDL2/SDL2-2.28.5/cmake")
endif()
find_package(SDL2 REQUIRED)

include("${RECOMP_ROOT}/cmake/GenesisRecompGenerated.cmake")
genesisrecomp_add_generated_sources(
    MSPAC_GENERATED_SOURCES mspac "${MSPAC_GAME_DIR}" mspacman.bin)
genesisrecomp_runner_sources(MSPAC_RUNNER_SOURCES TRACE ${GEN_ENABLE_TRACE})

add_executable(MsPacManRecomp
    ${MSPAC_RUNNER_SOURCES}
    ${MSPAC_GENERATED_SOURCES}
    "${MSPAC_GAME_DIR}/mspacman_spec.c"
    "${MSPAC_GAME_DIR}/mspacman_video.c")
add_dependencies(MsPacManRecomp ${MSPAC_GENERATED_SOURCES_TARGET})
genesisrecomp_runner_target(MsPacManRecomp)
target_compile_definitions(MsPacManRecomp PRIVATE
    INCLUDE_GENERATED_CODE=1
    ENABLE_RECOMPILED_CODE=1
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
    "${MSPAC_GAME_DIR}")
target_link_libraries(MsPacManRecomp PRIVATE SDL2::SDL2)
if(TARGET SDL2::SDL2main AND MSVC)
    target_link_libraries(MsPacManRecomp PRIVATE SDL2::SDL2main)
endif()
if(WIN32)
    target_link_libraries(MsPacManRecomp PRIVATE ws2_32 comdlg32 shell32)
endif()
if(MSVC)
    target_compile_options(MsPacManRecomp PRIVATE /W3 /WX- /utf-8 /wd4102 /wd4996)
    target_link_options(MsPacManRecomp PRIVATE /MAP)
else()
    # The generated 68000 translation is large and flat: build it for size,
    # the runner and the game adapter (which run every scanline) at -O2.
    set_source_files_properties(${MSPAC_GENERATED_SOURCES} PROPERTIES
        COMPILE_OPTIONS "-O1;-w")
    target_compile_options(MsPacManRecomp PRIVATE
        $<$<COMPILE_LANGUAGE:C,CXX>:-O2>)
    if(WIN32)
        # A GUI app: no console window behind the game.
        target_link_options(MsPacManRecomp PRIVATE -mwindows)
    endif()
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        target_link_options(MsPacManRecomp PRIVATE -s)   # no debug symbols in a release
    endif()
endif()

if(WIN32 AND MSVC)
    add_custom_command(TARGET MsPacManRecomp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${RUNNER_ROOT}/external/SDL2/SDL2-2.28.5/lib/x64/SDL2.dll"
            "$<TARGET_FILE_DIR:MsPacManRecomp>"
        COMMENT "Staging SDL2.dll next to MsPacManRecomp")
endif()

# Shared recomp-ui (Dear ImGui) pre-boot launcher + in-game menu. Mods are
# exposed so the full-maze view can be toggled from the launcher.
set(RECOMP_UI_ENABLE_MODS ON CACHE BOOL "Expose the full-maze view in the launcher Mods view")
include("${CMAKE_SOURCE_DIR}/recomp-ui/recomp_ui.cmake")
recomp_target_launcher_ui(MsPacManRecomp CONSOLE genesis
    BOXART "${CMAKE_SOURCE_DIR}/assets/boxart.tga")

# The GL frontend (segagenesisrecomp/runner/frontend): librashader shader
# presets, the ImGui Esc menu and settings window, rewind, preemptive frames
# and shortcuts. Off = the engine's SDL_Renderer presentation.
option(MSPAC_GL_FRONTEND "Present through the runner's GL frontend" ON)
if(MSPAC_GL_FRONTEND)
    genesisrecomp_runner_gl_frontend(MsPacManRecomp
        IMGUI_DIR "${CMAKE_SOURCE_DIR}/recomp-ui/src/third_party/imgui")

    # librashader and the slang-shaders presets from tools/build_librashader.sh
    # (x86 and arm64 build into windows-<arch>/, tools/build_linux.sh into
    # linux-<arch>/), staged beside the exe. The game opens the library at run
    # time, so without them it still builds and the Shader Presets menu says
    # why.
    set(_lrs "${CMAKE_SOURCE_DIR}/third_party/librashader")
    if(WIN32 AND MSPAC_WINDOWS_ARCH)
        set(_lrs_lib "${_lrs}/windows-${MSPAC_WINDOWS_ARCH}/librashader.dll")
    elseif(WIN32)
        set(_lrs_lib "${_lrs}/librashader.dll")
    else()
        set(_lrs_lib "${_lrs}/linux-${CMAKE_SYSTEM_PROCESSOR}/librashader.so")
    endif()
    set(_lrs_outputs)
    if(EXISTS "${_lrs_lib}")
        set(_lrs_stamp "${CMAKE_CURRENT_BINARY_DIR}/librashader_lib.stamp")
        add_custom_command(OUTPUT "${_lrs_stamp}"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_lrs_lib}"
                    "$<TARGET_FILE_DIR:MsPacManRecomp>"
            COMMAND ${CMAKE_COMMAND} -E touch "${_lrs_stamp}"
            DEPENDS "${_lrs_lib}"
            VERBATIM)
        list(APPEND _lrs_outputs "${_lrs_stamp}")
    endif()
    if(UNIX AND NOT APPLE)
        # dlopen("librashader.so") looks beside the executable, and only there.
        set_target_properties(MsPacManRecomp PROPERTIES
            BUILD_WITH_INSTALL_RPATH TRUE INSTALL_RPATH "$ORIGIN")
    endif()
    if(EXISTS "${_lrs}/shaders.stamp")
        # Copied once per build_librashader.sh run, not on every build (2500+ files).
        set(_shaders_stamp "${CMAKE_CURRENT_BINARY_DIR}/librashader_shaders.stamp")
        add_custom_command(OUTPUT "${_shaders_stamp}"
            COMMAND ${CMAKE_COMMAND} -E copy_directory "${_lrs}/shaders"
                    "$<TARGET_FILE_DIR:MsPacManRecomp>/shaders"
            COMMAND ${CMAKE_COMMAND} -E copy "${_lrs}/shaders.stamp" "${_shaders_stamp}"
            DEPENDS "${_lrs}/shaders.stamp"
            VERBATIM)
        list(APPEND _lrs_outputs "${_shaders_stamp}")
    endif()
    if(_lrs_outputs)
        add_custom_target(mspac_librashader ALL DEPENDS ${_lrs_outputs})
        add_dependencies(mspac_librashader MsPacManRecomp)
    endif()
endif()

# Engine framework tests (ROM-independent). Opt-in via -DBUILD_TESTS=ON; with
# recomp-ui present this also builds the launcher Mods test (video_mod).
option(BUILD_TESTS "Build the segagenesisrecomp framework tests" OFF)
if(BUILD_TESTS)
    enable_testing()
    add_subdirectory("${RECOMP_ROOT}/tests" tests)
endif()

# First-run defaults (only when missing): full-maze view on.
add_custom_command(TARGET MsPacManRecomp POST_BUILD
    COMMAND ${CMAKE_COMMAND}
        "-DDST=$<TARGET_FILE_DIR:MsPacManRecomp>/settings.ini"
        -P "${CMAKE_SOURCE_DIR}/cmake/default_settings.cmake"
    COMMENT "Seeding settings.ini if missing")
