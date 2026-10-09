# CMake toolchain for the 32-bit x86 and ARM64 Windows builds
# (tools/build_windows.sh; the x64 build uses msys2 mingw64 directly):
#   x86    msys2 mingw32's GCC, the same compiler family and runtime as x64
#   arm64  msys2 mingw64's clang and lld cross-compiling for aarch64-w64-mingw32
#          (msys2's own ARM64 compilers only run on ARM64 Windows)
# SDL2, ANGLE and the ARM64 runtime come from the pinned packages that
# tools/windows/bootstrap.sh unpacks into the cache.
#
#   -DMSPAC_WINDOWS_ARCH=x86|arm64 -DMSPAC_WINDOWS_CACHE=<bootstrap cache>
#   -DMSPAC_MSYS2=<msys2 root, C:/msys64>
# The cache path goes into compiler flags, so it must not contain spaces.
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES MSPAC_WINDOWS_ARCH MSPAC_WINDOWS_CACHE MSPAC_MSYS2)
if(NOT MSPAC_WINDOWS_ARCH OR NOT MSPAC_WINDOWS_CACHE OR NOT MSPAC_MSYS2)
    message(FATAL_ERROR "toolchain.cmake needs -DMSPAC_WINDOWS_ARCH, -DMSPAC_WINDOWS_CACHE and -DMSPAC_MSYS2")
endif()

set(CMAKE_SYSTEM_NAME Windows)
set(_mspac_root "${MSPAC_WINDOWS_CACHE}/sysroot-${MSPAC_WINDOWS_ARCH}")
if(MSPAC_WINDOWS_ARCH STREQUAL "x86")
    set(CMAKE_SYSTEM_PROCESSOR X86)
    set(_mspac_prefix "${_mspac_root}/mingw32")
    set(CMAKE_C_COMPILER "${MSPAC_MSYS2}/mingw32/bin/gcc.exe")
    set(CMAKE_CXX_COMPILER "${MSPAC_MSYS2}/mingw32/bin/g++.exe")
    # SSE2 floating point, as on x64 (x87 rounds differently); Windows 8 and
    # later need SSE2 anyway. The sysroot adds SDL2, ANGLE and the GL headers
    # to the compiler's own.
    set(_mspac_flags "-msse2 -mfpmath=sse -isystem ${_mspac_prefix}/include")
    set(CMAKE_C_FLAGS_INIT "${_mspac_flags}")
    set(CMAKE_CXX_FLAGS_INIT "${_mspac_flags}")
    # Up to 4 GB of address space on 64-bit Windows instead of 2 GB, for the
    # largest expanded views.
    set(CMAKE_EXE_LINKER_FLAGS_INIT "-L${_mspac_prefix}/lib -Wl,--large-address-aware")
elseif(MSPAC_WINDOWS_ARCH STREQUAL "arm64")
    set(CMAKE_SYSTEM_PROCESSOR ARM64)
    set(_mspac_prefix "${_mspac_root}/clangarm64")
    set(_mspac_bin "${MSPAC_MSYS2}/mingw64/bin")
    set(CMAKE_C_COMPILER "${_mspac_bin}/clang.exe")
    set(CMAKE_CXX_COMPILER "${_mspac_bin}/clang++.exe")
    set(CMAKE_C_COMPILER_TARGET aarch64-w64-mingw32)
    set(CMAKE_CXX_COMPILER_TARGET aarch64-w64-mingw32)
    set(CMAKE_SYSROOT "${_mspac_prefix}")
    # mingw64's clang defaults to GCC's runtime and linker; the ARM64 sysroot
    # is LLVM's (as in msys2's clangarm64). Plain char is signed, as on x86.
    set(_mspac_flags "-resource-dir=${MSPAC_WINDOWS_CACHE}/clang-resource-arm64 -fsigned-char")
    set(CMAKE_C_FLAGS_INIT "${_mspac_flags}")
    set(CMAKE_CXX_FLAGS_INIT "${_mspac_flags} -stdlib=libc++")
    set(CMAKE_EXE_LINKER_FLAGS_INIT "-fuse-ld=lld -rtlib=compiler-rt -unwindlib=libunwind -stdlib=libc++")
    set(CMAKE_AR "${_mspac_bin}/llvm-ar.exe" CACHE FILEPATH "")
    set(CMAKE_RANLIB "${_mspac_bin}/llvm-ranlib.exe" CACHE FILEPATH "")
    # The generated project strips with this after linking (debug info only).
    set(CMAKE_STRIP "${_mspac_bin}/llvm-strip.exe" CACHE FILEPATH "")
    set(CMAKE_RC_COMPILER "${_mspac_bin}/llvm-windres.exe" CACHE FILEPATH "")
else()
    message(FATAL_ERROR "MSPAC_WINDOWS_ARCH must be x86 or arm64, not ${MSPAC_WINDOWS_ARCH}")
endif()

set(CMAKE_FIND_ROOT_PATH "${_mspac_prefix}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
