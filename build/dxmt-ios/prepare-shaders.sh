#!/bin/bash
# Reproduce DXMT's metalir + xxd generators for the target iOS version.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/research/dxmt/src/airconv/shaders"
OUTPUT="$ROOT/build/dxmt-ios/shader-headers"
mkdir -p "$OUTPUT" "$ROOT/ci-logs"

if ! xcrun --sdk iphoneos metal --version > "$ROOT/ci-logs/metal-version.txt" 2>&1; then
    xcodebuild -downloadComponent MetalToolchain
    xcrun --sdk iphoneos metal --version > "$ROOT/ci-logs/metal-version.txt" 2>&1
fi
cat "$ROOT/ci-logs/metal-version.txt"

for name in air_msad air_samplepos air_tessellation; do
    test -s "$SOURCE/$name.metal"
    echo "=== Compiling $name for iOS 16.5 / Metal 3.0 ==="
    xcrun --sdk iphoneos metal \
      -std=metal3.0 --target=air64-apple-ios16.5 \
      -c "$SOURCE/$name.metal" -o "$OUTPUT/$name.air" \
      2> "$ROOT/ci-logs/$name-metal.log" || {
        cat "$ROOT/ci-logs/$name-metal.log"
        exit 1
      }
    test -s "$OUTPUT/$name.air"
    xxd -n "$name" -i "$OUTPUT/$name.air" "$OUTPUT/$name.h"
    grep -F "unsigned char $name[]" "$OUTPUT/$name.h" >/dev/null
    shasum -a 256 "$OUTPUT/$name.air"
done
