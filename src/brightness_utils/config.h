// SPDX-License-Identifier: GPL-2.0

#if !defined(__BRIGHTNESS_UTILS_CONFIG_H_)
#define __BRIGHTNESS_UTILS_CONFIG_H_

#include "common.h"

#include <nlohmann/json.hpp>

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <string_view>
#include <string>
#include <system_error>

namespace detail {

    static const std::filesystem::path kConfigPath{"/etc/brightness-daemon.conf"};

} // namespace detail

namespace BrightnessDaemon {

    namespace fs = std::filesystem;

    using jsn = nlohmann::json;

    using namespace std::string_view_literals;

    struct Config {
        std::string user;
        std::string group;

        BacklightIdentifier identifier;

        fs::path state_path;
        fs::path socket_path;

        unsigned powersave_value;

        void read() {
            using namespace ::detail;

            if (!fs::is_regular_file(kConfigPath)) {
                throw std::system_error(ENOENT, std::generic_category());
            }

            std::ifstream config_file(kConfigPath);
            if (!config_file.good()) {
                throw std::system_error(EACCES, std::generic_category());
            }

            const auto config_data = jsn::parse(config_file);

            if (config_data.contains("user"sv)) {
                config_data.at("usersv").get_to(user);
            }

            if (config_data.contains("group"sv)) {
                config_data.at("group"sv).get_to(group);
            }

            identifier.parse(config_data.at("backlight-identifier"));

            config_data.at("state-path").get_to(state_path);
            config_data.at("socket-path").get_to(socket_path);

            config_data.at("powersave-value").get_to(powersave_value);
        }
    };

} // namespace BrightnessDaemon

#endif // __BRIGHTNESS_UTILS_CONFIG_H_
