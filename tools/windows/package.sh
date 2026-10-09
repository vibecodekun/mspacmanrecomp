#!/usr/bin/env bash
# package.sh <arch> <build dir> <version>: the release zip for one arch from a
# finished tools/build_windows.sh build, into dist/windows/:
#   mspacman-recomp-<version>-windows-<arch>.zip   a folder to extract anywhere
set -euo pipefail
HERE="$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)"
ROOT="$(cd -- "$HERE/../.." && pwd)"
MSYS2="${MSPAC_MSYS2:-/c/msys64}"
arch=$1 build=$2 version=$3
dist="$ROOT/dist/windows"
name="mspacman-recomp-$version-windows-$arch"
stage_root="${MSPAC_WINDOWS_CACHE:-$ROOT/third_party/windows}/stage"
mkdir -p "$dist" "$stage_root"

# An allowlist: what the game needs beside it. Nothing a run creates (the ROM
# copy, settings, saves, rom.cfg, shader_cache/, logs, evidence files) goes in.
stage="$stage_root/$name"
rm -rf "$stage"
mkdir -p "$stage"
cp "$build/MsPacManRecomp.exe" "$stage/"
list=$(bash "$HERE/dlls.sh" "$build")
mapfile -t dlls <<< "$list"
cp "${dlls[@]}" "$stage/"
cp -r "$build/assets" "$stage/"
# recomp-ui stages its Genesis sample box art (Sonic 1's) too; not this game's.
rm -f "$stage/assets/img/boxart_sonic1.tga"
[ -d "$build/shaders" ] && cp -r "$build/shaders" "$stage/"
cp "$HERE/README-windows.txt" "$ROOT/LICENSE" "$ROOT/THIRD-PARTY-LICENSES.md" "$stage/"
# First-run defaults: the full-maze view on.
cp "$ROOT/release/settings.ini" "$stage/"
# Never a ROM, a dump or a state, whatever the build dir held. (Genesis ROMs
# can be .md too: anything with the cartridge's "SEGA" header counts.)
if find "$stage" -iname '*.bin' -o -iname '*.gen' -o -iname '*.smd' -o -iname '*.state*' \
        -o -iname 'rom*.cfg' | grep -q . ||
   find "$stage" -type f -size +64k -exec sh -c 'dd if="$1" bs=1 skip=256 count=4 2>/dev/null | grep -q SEGA' _ {} \; -print | grep -q .; then
    echo "refusing to package: a ROM, state or rom.cfg is in $stage"
    exit 1
fi
rm -f "$dist/$name.zip"
"$MSYS2/usr/bin/bsdtar" --format zip -cf "$dist/$name.zip.part" -C "$stage_root" "$name"
mv "$dist/$name.zip.part" "$dist/$name.zip"
rm -rf "$stage"
echo "=== $dist/$name.zip ($(du -h "$dist/$name.zip" | cut -f1))"
