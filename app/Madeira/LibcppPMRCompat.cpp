// Compatibility shim for libc++ PMR ABI introduced on Apple platforms in iOS 17.
//
// Xcode 26 headers allow std::pmr::memory_resource to be used when availability
// markup is disabled, but iOS 16's /usr/lib/libc++.1.dylib does not export the
// out-of-line destructor / key-function RTTI added with libc++ 16.
//
// Defining the key function in the executable makes the destructor, vtable and
// RTTI local to Madeira, preserving the pre-iOS-17 deployment target without
// replacing the system libc++.
#include <Availability.h>
#include <memory_resource>

#if defined(__APPLE__) && defined(__IPHONE_OS_VERSION_MIN_REQUIRED__) && __IPHONE_OS_VERSION_MIN_REQUIRED__ < 170000
namespace std::pmr {
memory_resource::~memory_resource() = default;
}
#endif
