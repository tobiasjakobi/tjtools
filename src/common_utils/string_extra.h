// SPDX-License-Identifier: GPL-2.0

#if !defined(__COMMON_UTILS_STRING_EXTRA_H_)
#define __COMMON_UTILS_STRING_EXTRA_H_

#include <string>

namespace CommonUtils {

    static std::string rstrip(const std::string &input){
        auto end_it = input.rbegin();

        while (std::isspace(*end_it)) {
            ++end_it;
        }

        return std::string(std::begin(input), end_it.base());
    }

} // namespace CommonUtils

#endif // __COMMON_UTILS_STRING_EXTRA_H_
