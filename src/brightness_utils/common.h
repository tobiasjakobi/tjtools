// SPDX-License-Identifier: GPL-2.0

#if !defined(__BRIGHTNESS_UTILS_COMMON_H_)
#define __BRIGHTNESS_UTILS_COMMON_H_

#include <nlohmann/json.hpp>
#include <sys/types.h>

#include <cstdint>
#include <string>
#include <utility>

namespace BrightnessDaemon {

    using UGID = std::pair<__uid_t, __gid_t>;

    /**
     * Get UID/GID pair for username/groupname.
     *
     * @param username  Username to query
     * @param groupname Groupname to query
     */
    UGID get_uid_gid(const char *username, const char *groupname);

    /**
     * Drop root privileges.
     * 
     * @param username  Username to become
     * @param groupname Groupname to become
     *
     * If the current user is root, then drop these privileges and
     * become the given user/group.
     *
     * Groupname is optional and can be a nullptr.
     */
    void drop_root_privileges(const char *username, const char *groupname);

    struct BacklightIdentifier {
        std::string   prefix;
        std::uint16_t vendor_id;
        std::uint16_t device_id;

        void parse(const nlohmann::json &data);
    };

} // namespace BrightnessDaemon

#endif // __BRIGHTNESS_UTILS_COMMON_H_
