// SPDX-License-Identifier: GPL-2.0

#if !defined(__BRIGHTNESS_UTILS_SYSFS_H_)
#define __BRIGHTNESS_UTILS_SYSFS_H_

#include "common.h"

#include <cctype>
#include <filesystem>
#include <fstream>
#include <optional>
#include <string_view>
#include <string>

namespace detail {

    static const std::filesystem::path kSysfsBasePath{"/sys/class/backlight"};

} // namespace detail

namespace BrightnessDaemon {

    namespace fs = std::filesystem;

    using namespace std::string_view_literals;

    static std::string rstrip(const std::string &input){
        auto end_it = input.rbegin();

        while (std::isspace(*end_it)) {
            ++end_it;
        }

        return std::string(std::begin(input), end_it.base());
    }

    /**
     * Check if a device path belongs to a parent device.
     *
     * @param path The device path to check
     */
    static bool is_parent_device(const fs::path &path) {
        for (const auto &arg : {"class"sv, "vendor"sv, "device"sv}) {
            if (!fs::is_regular_file(path / arg)) {
                return false;
            }
        }

        return true;
    }

    /**
     * Get the parent device path for a device.
     *
     * @param path The device path to use
     */
    static auto get_parent_device(const fs::path &path) {
        auto current_path = path;

        std::optional<decltype(current_path)> parent_device;

        while (true) {
            if (is_parent_device(current_path)) {
                parent_device = current_path;
                break;
            }

            const auto next_path = current_path / "device"sv;
            if (!fs::is_symlink(next_path)) {
                break;
            }

            current_path = next_path;
        }

        return parent_device;
    }

    /**
     * Read from a sysfs path.
     *
     * Returns the read result as a string, or None if the read failed.
     *
     * @param path The path from which to read
     */
    static std::optional<std::string> read_sysfs(const fs::path &path) {
        std::ifstream stream;

        stream.open(path);
        if (stream.good()) {
            std::string data;
            stream >> data;

            return rstrip(data);
        }

        return std::nullopt;
    }

    /**
     * Identify the backlight device.
     *
     * @param path  sysfs path to the backlight node
     * @param ident backlight identfier
     *
     * Returns true if the information from the sysfs path matches
     * the identifier, and false if not.
     */
    static bool identify_backlight(const fs::path &path, const BacklightIdentifier &ident) {
        std::uint16_t vendor_id;
        std::uint16_t device_id;

        try {
            vendor_id = std::stoi(read_sysfs(path / "vendor"sv).value(), nullptr, 16);
            device_id = std::stoi(read_sysfs(path / "device"sv).value(), nullptr, 16);
        } catch ([[maybe_unusued]] const std::exception &exc) {
            return false;
        }

        return vendor_id == ident.vendor_id && device_id == ident.device_id;
    }

    /**
     * Lookup the sysfs path to the backlight node.
     *
     * @param ident Backlight identfier
     *
     * Returns the sysfs path to the node, or nullopt if nothing was found.
     */
    static std::optional<fs::path> lookup_backlight_node(const BacklightIdentifier &ident) {
        using namespace ::detail;

        if (!fs::is_directory(kSysfsBasePath)) {
            return std::nullopt;
        }

        for (const auto &dir_entry : fs::directory_iterator{kSysfsBasePath}) {
            if (!dir_entry.is_symlink()) {
                continue;
            }

            const auto &p = dir_entry.path();

            if (p.filename().string().rfind(ident.prefix, 0) != 0) {
                continue;
            }

            auto parent = get_parent_device(p);
            if (!parent.has_value()) {
                continue;
            }

            if (identify_backlight(parent.value(), ident)) {
                return p;
            }
        }

        return std::nullopt;
    }

} // namespace BrightnessDaemon

#endif // __BRIGHTNESS_UTILS_SYSFS_H_
