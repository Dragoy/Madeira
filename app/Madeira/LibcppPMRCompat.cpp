// Compatibility ABI shim for std::__1::pmr::memory_resource on iOS 16.
//
// Apple first shipped libc++16 PMR runtime symbols in iOS 17. Xcode 26 can
// nevertheless emit references to the out-of-line memory_resource destructor
// when targeting iOS 16, which causes dyld to abort before main().
//
// Do not include <memory_resource> here: its _LIBCPP_EXPORTED_FROM_ABI
// annotations preserve two-level ownership by /usr/lib/libc++.1.dylib. Instead
// declare the exact Itanium ABI class shape in libc++'s ABI namespace and
// provide its key function locally. This causes clang to emit strong local
// destructor/vtable/RTTI definitions that satisfy FEX's PMR references.
#include <stddef.h>

#if defined(__APPLE__) && defined(__IPHONE_OS_VERSION_MIN_REQUIRED__) && __IPHONE_OS_VERSION_MIN_REQUIRED__ < 170000

namespace std {
inline namespace __1 {
namespace pmr {

class __attribute__((visibility("default"))) memory_resource {
public:
  virtual ~memory_resource();

private:
  virtual void* do_allocate(::size_t, ::size_t) = 0;
  virtual void do_deallocate(void*, ::size_t, ::size_t) = 0;
  virtual bool do_is_equal(memory_resource const&) const noexcept = 0;
};

__attribute__((visibility("default"), used, noinline))
memory_resource::~memory_resource() {}

} // namespace pmr
} // inline namespace __1
} // namespace std

#endif
