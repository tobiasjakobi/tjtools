// SPDX-License-Identifier: GPL-2.0

#if !defined(__BRIGHTNESS_UTILS_COMMON_H_)
#define __BRIGHTNESS_UTILS_COMMON_H_

#include <nlohmann/json.hpp>

#include <cstdint>
#include <string>

namespace BrightnessDaemon {

    void drop_root_privileges(const char *username, const char *groupname);

    struct BacklightIdentifier {
        std::string   prefix;
        std::uint16_t vendor_id;
        std::uint16_t device_id;

        void parse(const nlohmann::json &data);
    };

} // namespace BrightnessDaemon

#endif // __BRIGHTNESS_UTILS_COMMON_H_
