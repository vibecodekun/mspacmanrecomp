#!/usr/bin/env bash
# package.sh <arch> <build dir> <version>: the release files for one arch from
# a finished tools/build_linux.sh build, into dist/linux/:
#   mspacman-recomp-<version>-linux-<arch>.tar.gz   a folder to extract anywhere
#   MsPacMan_Recomp-<version>-<arch>.AppImage       one file; state beside it
set -euo pipefail
HERE="$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)"
ROOT="$(cd -- "$HERE/../.." && pwd)"
CACHE="${MSPAC_LINUX_CACHE:-$HOME/.cache/mspacman-linux}"
WORK="$CACHE/work-mspacman"
arch=$1 build=$2 version=$3
dist="$ROOT/dist/linux"
name="mspacman-recomp-$version-linux-$arch"
mkdir -p "$dist" "$WORK/stage"

# An allowlist: what the game needs beside it. Nothing a run creates (the ROM
# copy, settings, saves, rom.cfg, shader_cache/, logs, evidence files) goes in.
stage="$WORK/stage/$name"
rm -rf "$stage"
mkdir -p "$stage"
cp "$build/MsPacManRecomp" "$stage/"
[ -f "$build/librashader.so" ] && cp "$build/librashader.so" "$stage/"
cp -r "$build/assets" "$stage/"
# recomp-ui stages its Genesis sample box art (Sonic 1's) too; not this game's.
rm -f "$stage/assets/img/boxart_sonic1.tga"
[ -d "$build/shaders" ] && cp -r "$build/shaders" "$stage/"
cp "$HERE/README-linux.txt" "$ROOT/LICENSE" "$ROOT/THIRD-PARTY-LICENSES.md" "$stage/"
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
tar -C "$WORK/stage" -czf "$dist/$name.tar.gz.part" "$name"
mv "$dist/$name.tar.gz.part" "$dist/$name.tar.gz"
echo "=== $dist/$name.tar.gz ($(du -h "$dist/$name.tar.gz" | cut -f1))"

bash "$HERE/bootstrap.sh" appimage > /dev/null
appdir="$WORK/stage/AppDir-$arch"
rm -rf "$appdir"
mkdir -p "$appdir/usr/bin"
cp -r "$stage"/. "$appdir/usr/bin/"
rm "$appdir/usr/bin/README-linux.txt"
cp "$HERE/AppRun" "$HERE/mspacman.desktop" "$HERE/mspacman.png" "$appdir/"
chmod +x "$appdir/AppRun"
ln -s mspacman.png "$appdir/.DirIcon"
image="$dist/MsPacMan_Recomp-$version-$arch.AppImage"
ARCH="$arch" "$CACHE/appimage/appimagetool/AppRun" --no-appstream \
    --runtime-file "$CACHE/appimage/runtime-$arch" "$appdir" "$image.part" > "$WORK/appimage-$arch.log" 2>&1 \
    || { tail -20 "$WORK/appimage-$arch.log"; exit 1; }
mv "$image.part" "$image"
chmod +x "$image"
rm -rf "$stage" "$appdir"
echo "=== $image ($(du -h "$image" | cut -f1))"
