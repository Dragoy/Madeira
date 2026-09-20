// Back-deploy only the PMR base-class key function required by FEX.
// Apple's system libc++ provides this ABI from iOS 17 onward. The iOS 16
// executable must provide it itself; other libc++ facilities stay in libc++.
//
// Use the compiler's actual deployment-target macro. The earlier spelling
// __IPHONE_OS_VERSION_MIN_REQUIRED__ is not defined and made this TU empty.
#if defined(__APPLE__) && defined(__ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__) && \
    __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__ < 170000

#include <memory_resource>

// Use this SDK's real class declaration and ABI namespace, not a copied
// internal header or a second, potentially incompatible class definition.
_LIBCPP_BEGIN_NAMESPACE_STD
namespace pmr {
memory_resource::~memory_resource() = default;
}
_LIBCPP_END_NAMESPACE_STD

#endif
