// SPDX-License-Identifier: GPL-2.0

#if !defined(__COMMON_UTILS_SCOPE_GUARD_H_)
#define __COMMON_UTILS_SCOPE_GUARD_H_

#include <functional>

namespace CommonUtils {

    class scope_guard {
    public: 
        template<class Callable>
        explicit scope_guard(Callable &&callback) : callback_(std::forward<Callable>(callback)) {}

        ~scope_guard() {        
            try {
                if (callback_ != nullptr) {
                    callback_();
                }
            } catch (...) {
                // Make sure that our destructor doesn't throw.
            }
        }

        scope_guard([[maybe_unused]] const scope_guard &rhs) = delete;
        void operator=([[maybe_unused]] const scope_guard &rhs) = delete;

        scope_guard(scope_guard &&other) : callback_(std::move(other.callback_)) {
            other.callback_ = nullptr;
        }

        void disable() noexcept {
            callback_ = nullptr;
        }

    private:
        std::function<void()> callback_{nullptr};
    };

} // namespace CommonUtils

#endif // __COMMON_UTILS_SCOPE_GUARD_H_
