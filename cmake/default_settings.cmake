# First-run defaults next to the executable. Runs as a post-build step and
# never overwrites files that already exist (the launcher owns them after).
#   cmake -DDST=<exe dir>/settings.ini [-DROM_CFG=<exe dir>/rom-MSPAC.cfg
#         -DROM=<exe dir>/mspacman.bin] -P default_settings.cmake
if(NOT DST)
    message(FATAL_ERROR "default_settings.cmake: DST is required")
endif()

# settings.ini: full-maze view enabled.
if(NOT EXISTS "${DST}")
    file(WRITE "${DST}"
"# Ms. Pac-Man recomp settings (hand-editable; the launcher rewrites it).\n"
"[video]\n"
"window_scale = 2\n"
"\n"
"# Full-maze view. enabled = 0 restores the original scrolling view.\n"
"# aspect: fit = one 360-line canvas for every maze; stage = height follows each maze.\n"
"[mods.widescreen]\n"
"enabled = 1\n"
"aspect = fit\n")
endif()

# rom-MSPAC.cfg: point the launcher at the ROM staged beside the exe.
if(ROM_CFG AND ROM AND EXISTS "${ROM}" AND NOT EXISTS "${ROM_CFG}")
    file(TO_NATIVE_PATH "${ROM}" _rom_native)
    file(WRITE "${ROM_CFG}" "${_rom_native}\n")
endif()
