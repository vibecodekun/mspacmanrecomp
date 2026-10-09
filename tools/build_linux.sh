#!/usr/bin/env bash
# Build the Linux releases (x86_64 and aarch64). Runs on a Debian/Ubuntu
# machine or in WSL (from Windows: wsl bash tools/build_linux.sh), after
# tools/build_windows.sh x64 has recompiled the ROM: the generated C in
# build/x64/generated/mspac is the same for every platform, so the recompiler
# (and the ROM) are only needed there. $MSPAC_GENERATED names another
# directory holding it.
#
#   bash tools/build_linux.sh [x86_64|aarch64 ...] [--no-package] [--no-librashader]
#
# The first run fetches the toolchain into ~/.cache/mspacman-linux
# (tools/linux/bootstrap.sh; $MSPAC_LINUX_CACHE moves it). Binaries target
# glibc 2.28 with SDL2 and the C++ runtime linked in, so they run on any
# distribution from 2019 on (Debian 10, Ubuntu 20.04, RHEL 8, SteamOS, ...).
# The build tree lives in the cache on the Linux file system; results:
#   dist/linux/mspacman-recomp-<version>-linux-<arch>.tar.gz
#   dist/linux/MsPacMan_Recomp-<version>-<arch>.AppImage
# <version> is $MSPAC_VERSION, or the project version in CMakeLists.txt.
set -euo pipefail
ROOT="$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd)"
CACHE="${MSPAC_LINUX_CACHE:-$HOME/.cache/mspacman-linux}"
export MSPAC_LINUX_CACHE="$CACHE"
VERSION="${MSPAC_VERSION:-$(sed -n 's/^project(MsPacManRecomp VERSION \([0-9.]*\).*/\1/p' "$ROOT/CMakeLists.txt")}"
GENERATED="${MSPAC_GENERATED:-$ROOT/build/x64/generated/mspac}"
GLIBC_MAX=2.28
# This project's files in the (shareable) toolchain cache.
WORK="$CACHE/work-mspacman"

arches=()
package=1
librashader=1
for arg in "$@"; do
    case "$arg" in
        x86_64|aarch64) arches+=("$arg") ;;
        --no-package) package=0 ;;
        --no-librashader) librashader=0 ;;
        *) echo "usage: $0 [x86_64|aarch64 ...] [--no-package] [--no-librashader]"; exit 2 ;;
    esac
done
[ ${#arches[@]} -gt 0 ] || arches=(x86_64 aarch64)

log() { printf '=== %s\n' "$*"; }

bash "$ROOT/tools/linux/bootstrap.sh" base
[ "$librashader" = 1 ] && bash "$ROOT/tools/linux/bootstrap.sh" rust
CMAKE="$CACHE/tools/cmake/bin/cmake"
NINJA="$CACHE/tools/ninja/ninja"

[ -f "$GENERATED/mspac_dispatch.c" ] || { echo "no generated C in $GENERATED; run tools/build_windows.sh x64 first"; exit 1; }

# ---- sources -> the Linux file system -------------------------------------------
# rsync keeps modification times, so an unchanged file is neither copied nor
# rebuilt. Only sources: no ROM, build tree or git metadata.
TREE="$WORK/tree"
log "syncing sources to $TREE"
mkdir -p "$TREE/third_party/librashader" "$TREE/game" "$TREE/generated"
rsync -a --delete --include='*.c' --include='*.h' --exclude='*' "$GENERATED/" "$TREE/generated/"
rsync -a --delete --include='*.c' --include='*.h' --include='*.toml' --exclude='*' \
    "$ROOT/game/" "$TREE/game/"
rsync -a --delete --exclude='.git' --exclude='/build*/' --exclude='*.bin' --exclude='*.md' \
    --exclude='/tests/' --exclude='/docs/' --exclude='/ghidra/' --exclude='/rka/' \
    --exclude='/runner/external/SDL2/' \
    "$ROOT/segagenesisrecomp/" "$TREE/segagenesisrecomp/"
rsync -a --delete --exclude='.git' --exclude='/build*/' --exclude='/tests/' --exclude='/test_data/' \
    "$ROOT/recomp-ui/" "$TREE/recomp-ui/"
rsync -a --delete "$ROOT/assets/" "$TREE/assets/"
rsync -a --delete "$ROOT/cmake/" "$TREE/cmake/"
rsync -a "$ROOT/CMakeLists.txt" "$TREE/"
if [ -f "$ROOT/third_party/librashader/shaders.stamp" ]; then
    rsync -a --delete "$ROOT/third_party/librashader/shaders/" "$TREE/third_party/librashader/shaders/"
    rsync -a "$ROOT/third_party/librashader/shaders.stamp" "$TREE/third_party/librashader/"
fi

# ---- librashader ------------------------------------------------------------------
# From the source tools/build_librashader.sh exported and patched.
LRS_SRC="$ROOT/third_party/librashader/src"
build_librashader() {
    local arch=$1
    local out="$ROOT/third_party/librashader/linux-$arch"
    local stamp
    stamp="$(cat "$LRS_SRC/.source-stamp") $(cat "$CACHE/rust/.stamp")"
    if [ "$(cat "$out/.stamp" 2> /dev/null)" != "$stamp" ]; then
        log "librashader for $arch"
        rsync -a --delete --exclude='/target/' "$LRS_SRC/" "$WORK/librashader-src/"
        PATH="$CACHE/tools/zig:$CACHE/rust/cargo/bin:$PATH" \
        RUSTUP_HOME="$CACHE/rust/rustup" CARGO_HOME="$CACHE/rust/cargo" \
        ZIG_GLOBAL_CACHE_DIR="$CACHE/zig-cache" ZIG_LOCAL_CACHE_DIR="$CACHE/zig-cache" \
            cargo zigbuild --release --manifest-path "$WORK/librashader-src/Cargo.toml" \
                -p librashader-capi --no-default-features --features runtime-opengl \
                --target "$arch-unknown-linux-gnu.$GLIBC_MAX" --target-dir "$WORK/librashader-target" \
                > "$WORK/librashader-$arch.log" 2>&1 \
            || { tail -30 "$WORK/librashader-$arch.log"; exit 1; }
        mkdir -p "$out"
        cp "$WORK/librashader-target/$arch-unknown-linux-gnu/release/liblibrashader_capi.so" "$out/librashader.so"
        echo "$stamp" > "$out/.stamp"
    fi
    mkdir -p "$TREE/third_party/librashader/linux-$arch"
    rsync -a "$out/librashader.so" "$TREE/third_party/librashader/linux-$arch/"
}

# ---- checks on a finished binary ----------------------------------------------------
# Newest glibc symbol version it needs, and what it links.
check_elf() {
    local file=$1
    local newest
    newest=$(readelf -W -V "$file" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1)
    echo "  ${file##*/}: needs ${newest:-no glibc}; links $(readelf -d "$file" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' | tr '\n' ' ')"
    if [ -n "$newest" ] && [ "$(printf '%s\n' "${newest#GLIBC_}" "$GLIBC_MAX" | sort -V | tail -1)" != "$GLIBC_MAX" ]; then
        echo "  $file needs $newest, newer than the $GLIBC_MAX this build targets"
        exit 1
    fi
}

# ---- build -------------------------------------------------------------------------
for arch in "${arches[@]}"; do
    if [ "$librashader" = 1 ]; then
        if [ -f "$LRS_SRC/.source-stamp" ]; then
            build_librashader "$arch"
        else
            echo "no librashader source at $LRS_SRC (tools/build_librashader.sh exports it); building without"
        fi
    fi
    build="$WORK/build-$arch"
    log "configuring $arch"
    "$CMAKE" -G Ninja -S "$TREE" -B "$build" \
        -DCMAKE_MAKE_PROGRAM="$NINJA" \
        -DCMAKE_TOOLCHAIN_FILE="$ROOT/tools/linux/toolchain.cmake" \
        -DMSPAC_LINUX_ARCH="$arch" -DMSPAC_LINUX_CACHE="$CACHE" \
        -DSDL2_DIR="$CACHE/sdl2-$arch/lib/cmake/SDL2" \
        -DGENESIS_PREGENERATED_DIR="$TREE/generated" \
        -DCMAKE_BUILD_TYPE=Release -DGEN_ENABLE_TRACE=OFF > "$WORK/cmake-$arch.log" 2>&1 \
        || { tail -30 "$WORK/cmake-$arch.log"; exit 1; }
    log "building $arch"
    "$NINJA" -C "$build" > "$WORK/build-$arch.log" 2>&1 \
        || { grep -E "error|FAILED" "$WORK/build-$arch.log" | head -30; exit 1; }
    check_elf "$build/MsPacManRecomp"
    [ -f "$build/librashader.so" ] && check_elf "$build/librashader.so"
done

[ "$package" = 1 ] || { log "done (not packaged)"; exit 0; }
for arch in "${arches[@]}"; do
    bash "$ROOT/tools/linux/package.sh" "$arch" "$WORK/build-$arch" "$VERSION"
done
