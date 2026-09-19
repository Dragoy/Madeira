#!/bin/bash
# Check the PMR back-deployment ABI with the selected Apple toolchain.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${RUNNER_TEMP:-/tmp}/madeira-pmr-preflight"
mkdir -p "$OUT"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CXX="$(xcrun --sdk iphoneos -f clang++)"
COMMON=(-std=c++20 -isysroot "$SDK")
SOURCE="$ROOT/app/Madeira/LibcppPMRCompat.cpp"

"$CXX" "${COMMON[@]}" -target arm64-apple-ios16.5 -dM -E -x c++ /dev/null > "$OUT/macros.txt"
grep '^#define __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__ 160500$' "$OUT/macros.txt"

# Regression control: the old misspelling excluded the whole implementation.
cat > "$OUT/old-guard.cpp" <<EOF
#if defined(__APPLE__) && defined(__IPHONE_OS_VERSION_MIN_REQUIRED__) && __IPHONE_OS_VERSION_MIN_REQUIRED__ < 170000
#include "$SOURCE"
#endif
EOF
"$CXX" "${COMMON[@]}" -target arm64-apple-ios16.5 -c "$OUT/old-guard.cpp" -o "$OUT/old.o"
xcrun nm -gU "$OUT/old.o" > "$OUT/old-defined.txt"
if grep -q 'pmr15memory_resource' "$OUT/old-defined.txt"; then
    echo 'Regression control changed: investigate the SDK deployment macros.' >&2
    exit 1
fi

"$CXX" "${COMMON[@]}" -target arm64-apple-ios16.5 -c "$SOURCE" -o "$OUT/compat.o"
xcrun nm -gU "$OUT/compat.o" | tee "$OUT/defined.txt"
for symbol in __ZNSt3__13pmr15memory_resourceD0Ev __ZNSt3__13pmr15memory_resourceD1Ev __ZNSt3__13pmr15memory_resourceD2Ev __ZTINSt3__13pmr15memory_resourceE __ZTVNSt3__13pmr15memory_resourceE; do
    grep -Eq "[[:space:]]${symbol}$" "$OUT/defined.txt" || {
        echo "Missing local PMR definition: $symbol" >&2
        exit 1
    }
done

cat > "$OUT/consumer.cpp" <<'CPP'
#include <memory_resource>
#include <new>
#include <typeinfo>
class Resource final : public std::pmr::memory_resource {
    void* do_allocate(std::size_t n, std::size_t a) override {
        return ::operator new(n, std::align_val_t(a));
    }
    void do_deallocate(void* p, std::size_t, std::size_t a) override {
        ::operator delete(p, std::align_val_t(a));
    }
    bool do_is_equal(const std::pmr::memory_resource& r) const noexcept override {
        return this == &r;
    }
};
int main() {
    Resource r;
    std::pmr::polymorphic_allocator<int> allocator(&r);
    int* p = allocator.allocate(1);
    *p = 42;
    int result = *p;
    allocator.deallocate(p, 1);
    const std::type_info* volatile base_type = &typeid(std::pmr::memory_resource);
    return result != 42 || base_type == nullptr;
}
CPP
"$CXX" "${COMMON[@]}" -target arm64-apple-ios16.5 "$OUT/consumer.cpp" "$OUT/compat.o" -o "$OUT/consumer"
xcrun nm -u "$OUT/consumer" > "$OUT/imports.txt"
if grep -E '__Z.*NSt3__13pmr' "$OUT/imports.txt"; then
    echo 'The test still imports PMR from the system dylib.' >&2
    exit 1
fi
xcrun vtool -show-build "$OUT/consumer"

# Newer deployments must use their system-provided PMR implementation.
"$CXX" "${COMMON[@]}" -target arm64-apple-ios17.0 -c "$SOURCE" -o "$OUT/native17.o"
xcrun nm -gU "$OUT/native17.o" > "$OUT/native17-defined.txt"
if grep -q 'pmr15memory_resource' "$OUT/native17-defined.txt"; then
    echo 'Compatibility implementation must be disabled for iOS 17+.' >&2
    exit 1
fi
echo 'PASS: iOS16 PMR is locally resolved; iOS17 uses the system implementation.'
