#!/usr/bin/env bash
# check.sh [x86_64|aarch64 ...]: run finished tools/build_linux.sh builds
# through
#   - tools/check_startup.py: 600 frames of the game loop in a hidden window
#     through the GL frontend, without an interpreter fallback or a dispatch
#     miss (on this machine, for its own arch)
#   - tools/check_states.py: preemptive frames against no preemptive frames,
#     and a save-state file loaded by another process (same)
#   - the startup check again on Debian 10's glibc 2.28, the oldest userland
#     the builds target, on SDL's dummy video driver (aarch64 through
#     qemu-user, with Debian 10 arm64 as its root)
# Needs the ROM at game/mspacman.bin ($MSPAC_ROM to use another).
set -euo pipefail
HERE="$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)"
ROOT="$(cd -- "$HERE/../.." && pwd)"
CACHE="${MSPAC_LINUX_CACHE:-$HOME/.cache/mspacman-linux}"
WORK="$CACHE/work-mspacman"
ROM="${MSPAC_ROM:-$ROOT/game/mspacman.bin}"
LOGS="$ROOT/logs"

arches=()
for arg in "$@"; do
    case "$arg" in
        x86_64|aarch64) arches+=("$arg") ;;
        *) echo "usage: $0 [x86_64|aarch64 ...]"; exit 2 ;;
    esac
done
[ ${#arches[@]} -gt 0 ] || arches=(x86_64 aarch64)
[ -f "$ROM" ] || { echo "no ROM at $ROM (set MSPAC_ROM)"; exit 1; }
bash "$HERE/bootstrap.sh" buster
mkdir -p "$LOGS"
failed=0

# The command prefix that runs an <arch> binary on Debian 10's libraries.
buster_runner() {
    local arch=$1 root="$CACHE/buster-$1"
    case "$arch" in
        x86_64)
            [ "$(uname -m)" = x86_64 ] || return 1
            echo "$root/lib64/ld-linux-x86-64.so.2 --library-path $root/lib/x86_64-linux-gnu:$root/usr/lib/x86_64-linux-gnu" ;;
        aarch64)
            if [ "$(uname -m)" = aarch64 ]; then
                echo "$root/lib/ld-linux-aarch64.so.1 --library-path $root/lib/aarch64-linux-gnu:$root/usr/lib/aarch64-linux-gnu"
            else
                command -v qemu-aarch64-static > /dev/null || return 1
                echo "qemu-aarch64-static -L $root"
            fi ;;
    esac
}

for arch in "${arches[@]}"; do
    exe="$WORK/build-$arch/MsPacManRecomp"
    [ -x "$exe" ] || { echo "no $arch build; run tools/build_linux.sh $arch"; failed=1; continue; }
    if [ "$(uname -m)" = "$arch" ]; then
        python3 "$ROOT/tools/check_startup.py" --exe "$exe" --rom "$ROM" \
            --log "$LOGS/startup-smoke-linux-$arch.log" || failed=1
        python3 "$ROOT/tools/check_states.py" --exe "$exe" --rom "$ROM" \
            --logs "$LOGS/states-linux-$arch" || failed=1
    fi
    if runner=$(buster_runner "$arch"); then
        printf 'Debian 10: '
        python3 "$ROOT/tools/check_startup.py" --exe "$exe" --rom "$ROM" --no-gl --timeout 1200 \
            --wrapper "$runner" --log "$LOGS/startup-smoke-linux-$arch-debian10.log" || failed=1
    else
        echo "SKIP $arch on Debian 10 (no way to run $arch here)"
    fi
done
exit $failed
