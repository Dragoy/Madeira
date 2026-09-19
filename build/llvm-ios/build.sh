#!/bin/bash
# LLVM dependencies used by DXMT's airconv, built for an iOS device, not macOS.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LLVM_TAG=llvmorg-15.0.7
LLVM_ROOT="$ROOT/toolchains/llvm-project"
LLVM_HOST="$ROOT/toolchains/llvm-host-build"
LLVM_IOS="$ROOT/toolchains/llvm-ios-build"
JOBS="${BUILD_JOBS:-3}"
mkdir -p "$ROOT/toolchains" "$ROOT/ci-logs"
exec > >(tee "$ROOT/ci-logs/llvm-ios.log") 2>&1

if [ ! -f "$LLVM_ROOT/llvm/CMakeLists.txt" ]; then
    ARCHIVE="${RUNNER_TEMP:-/tmp}/madeira-llvm15.tar.gz"
    curl -fL --retry 3 \
      "https://github.com/llvm/llvm-project/archive/refs/tags/$LLVM_TAG.tar.gz" \
      -o "$ARCHIVE"
    # GitHub's archive root includes the tag name. Do not guess that root.
    mkdir -p "$LLVM_ROOT"
    tar -xzf "$ARCHIVE" --strip-components=1 -C "$LLVM_ROOT"
fi
test -f "$LLVM_ROOT/llvm/CMakeLists.txt"

python3 - "$LLVM_ROOT" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / 'llvm/cmake/modules/AddLLVM.cmake'
s = p.read_text()
s = s.replace('MATCHES "Darwin"', 'MATCHES "Darwin|iOS"')
p.write_text(s)
PY

COMMON=(
    -G Ninja
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_C_COMPILER="$(xcrun --sdk macosx -f clang)"
    -DCMAKE_CXX_COMPILER="$(xcrun --sdk macosx -f clang++)"
    -DLLVM_TARGETS_TO_BUILD=
    -DLLVM_ENABLE_PROJECTS=
    -DLLVM_INCLUDE_TESTS=OFF
    -DLLVM_INCLUDE_EXAMPLES=OFF
    -DLLVM_INCLUDE_BENCHMARKS=OFF
    -DLLVM_INCLUDE_DOCS=OFF
    -DLLVM_ENABLE_TERMINFO=OFF
    -DLLVM_ENABLE_ZLIB=OFF
    -DLLVM_ENABLE_ZSTD=OFF
    -DBUILD_SHARED_LIBS=OFF
    -DLLVM_BUILD_LLVM_DYLIB=OFF
    -DLLVM_LINK_LLVM_DYLIB=OFF
)

cmake -S "$LLVM_ROOT/llvm" -B "$LLVM_HOST" "${COMMON[@]}" \
    -DCMAKE_OSX_SYSROOT="$(xcrun --sdk macosx --show-sdk-path)"
cmake --build "$LLVM_HOST" --target llvm-tblgen --parallel "$JOBS"
test -x "$LLVM_HOST/bin/llvm-tblgen"

cmake -S "$LLVM_ROOT/llvm" -B "$LLVM_IOS" "${COMMON[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_SYSTEM_PROCESSOR=arm64 \
    -DCMAKE_OSX_SYSROOT="$(xcrun --sdk iphoneos --show-sdk-path)" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=16.5 \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DLLVM_TABLEGEN="$LLVM_HOST/bin/llvm-tblgen" \
    -DLLVM_BUILD_UTILS=OFF \
    -DLLVM_BUILD_TOOLS=OFF \
    -DLLVM_INCLUDE_TOOLS=OFF
# DXMT meson declares llvm-config --libs bitwriter passes. Build exactly
# those targets and their dependency closure, not unused code generators.
cmake --build "$LLVM_IOS" --target LLVMPasses LLVMBitWriter --parallel "$JOBS"
for lib in LLVMPasses LLVMBitWriter LLVMCore LLVMSupport LLVMDemangle; do
    test -s "$LLVM_IOS/lib/lib${lib}.a"
done
xcrun --sdk iphoneos lipo -info "$LLVM_IOS/lib/libLLVMCore.a"
find "$LLVM_IOS/lib" -maxdepth 1 -name '*.a' -print | sort
