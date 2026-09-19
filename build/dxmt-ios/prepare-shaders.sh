#!/bin/bash
# Reproduce DXMT's metalir + xxd generators for the target iOS version.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/research/dxmt/src/airconv/shaders"
OUTPUT="$ROOT/build/dxmt-ios/shader-headers"
mkdir -p "$OUTPUT" "$ROOT/ci-logs"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / 'research/dxmt/src/winemetal/unix/winemetal_unix.c'
s = p.read_text()
marker = 'MADEIRA_IOS16_DEVICE_ENUMERATION'
old = '  params->ret = (obj_handle_t)MTLCopyAllDevices();'
new = '''  /* MADEIRA_IOS16_DEVICE_ENUMERATION: iOS has one local GPU. Preserve
   * the Copy API's +1 array ownership; the array retains its device. */
#if TARGET_OS_IOS
  id<MTLDevice> device = MTLCreateSystemDefaultDevice();
  NSArray *devices = device ? [[NSArray alloc] initWithObjects:device, nil]
                            : [[NSArray alloc] init];
  [device release];
  params->ret = (obj_handle_t)devices;
#else
  params->ret = (obj_handle_t)MTLCopyAllDevices();
#endif'''
if marker not in s:
    if s.count(old) != 1:
        raise SystemExit('Expected exactly one DXMT device enumeration call')
    p.write_text(s.replace(old, new, 1))
PY

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
