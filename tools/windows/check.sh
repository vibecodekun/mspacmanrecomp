#!/usr/bin/env bash
# check.sh [x64|x86|arm64 ...]: check finished tools/build_windows.sh builds
# in their build dirs, with the DLLs staged there:
#   - tools/windows/check_imports.py: every module is the arch's, and every
#     function imported from a DLL beside the exe is exported by it (all arches)
#   - tools/check_startup.py: 600 frames of the game loop in a hidden window,
#     through the GL frontend (ANGLE), without an interpreter fallback or a
#     dispatch miss; and once more on SDL's dummy driver (the no-GL fallback)
#   - tools/check_states.py: preemptive frames against no preemptive frames,
#     and a save-state file loaded by another process, to the machine state
# The last two run the build: an x64 PC runs the x64 and x86 builds; the ARM64
# build needs an ARM64 PC (Windows 11 on ARM runs all three). Needs the ROM at
# game/mspacman.bin ($MSPAC_ROM to use another).
set -euo pipefail
HERE="$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)"
ROOT="$(cd -- "$HERE/../.." && pwd)"
ROM="${MSPAC_ROM:-$ROOT/game/mspacman.bin}"
PYTHON="${MSPAC_PYTHON:-$(command -v python || command -v python3)}"
LOGS="$ROOT/logs"

arches=()
for arg in "$@"; do
    case "$arg" in
        x64|x86|arm64) arches+=("$arg") ;;
        *) echo "usage: $0 [x64|x86|arm64 ...]"; exit 2 ;;
    esac
done
[ ${#arches[@]} -gt 0 ] || arches=(x64 x86 arm64)
[ -f "$ROM" ] || { echo "no ROM at $ROM (set MSPAC_ROM)"; exit 1; }
mkdir -p "$LOGS"
host="${PROCESSOR_ARCHITEW6432:-${PROCESSOR_ARCHITECTURE:-AMD64}}"
failed=0

runs_here() {
    case "$1" in
        x64|x86) [ "$host" = AMD64 ] || [ "$host" = ARM64 ] ;;
        arm64) [ "$host" = ARM64 ] ;;
    esac
}

for arch in "${arches[@]}"; do
    build="$ROOT/build/$arch"
    exe="$build/MsPacManRecomp.exe"
    [ -f "$exe" ] || { echo "no $arch build; run tools/build_windows.sh $arch"; failed=1; continue; }
    "$PYTHON" "$HERE/check_imports.py" "$arch" "$(cygpath -w "$build")" || failed=1
    if ! runs_here "$arch"; then
        echo "SKIP $arch runs (this is an $host PC)"
        continue
    fi
    "$PYTHON" "$ROOT/tools/check_startup.py" --exe "$exe" --rom "$ROM" \
        --log "$LOGS/startup-smoke-windows-$arch.log" || failed=1
    "$PYTHON" "$ROOT/tools/check_startup.py" --exe "$exe" --rom "$ROM" --no-gl \
        --log "$LOGS/startup-smoke-windows-$arch-nogl.log" || failed=1
    "$PYTHON" "$ROOT/tools/check_states.py" --exe "$exe" --rom "$ROM" --logs "$LOGS/states-$arch" || failed=1
done
exit $failed
