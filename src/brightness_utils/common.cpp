// SPDX-License-Identifier: GPL-2.0

#include "common.h"

#include <unistd.h>

#include <sys/types.h>
#include <grp.h>
#include <pwd.h>

#include <stdexcept>
#include <string>

namespace BrightnessDaemon {

    using jsn = nlohmann::json;

    void drop_root_privileges(const char *username, const char *groupname) {
        auto uid = ::getuid();

        // We can only drop root privileges if we are root.
        if (uid != 0) {
            return;
        }

        ::group *grp{nullptr};

        if (groupname != nullptr) {
            grp = ::getgrnam(groupname);
            if (grp == nullptr) {
                throw std::runtime_error{"failed to find group"};
            }
        }

        ::passwd *pwd{nullptr};

        if (username != nullptr) {
            pwd = ::getpwnam(username);
            if (pwd == nullptr) {
                throw std::runtime_error{"failed to find user"};
            }

            if (pwd->pw_uid == 0) {
                throw std::runtime_error{"bogus user"};
            }

            if (grp == nullptr) {
                grp = ::getgrgid(pwd->pw_gid);
                if (grp == nullptr) {
                    throw std::runtime_error{"failed to find group of user"};
                }
            }
        }

        if (grp != nullptr) {
            if (grp->gr_gid == 0) {
                throw std::runtime_error{"bogus group"};
            }

            if (::setgid(grp->gr_gid) == -1) {
                throw std::runtime_error{"setgid()"};
            }

            if (::setgroups(0, nullptr) == -1) {
                throw std::runtime_error{"setgroups()"};
            }

            if (username != nullptr) {
                ::initgroups(username, grp->gr_gid);
            }
        }

        if (::chdir("/") == -1) {
            throw std::runtime_error{"chdir()"};
        }

        if (pwd != nullptr) {
            if (::setuid(pwd->pw_uid) == -1) {
                throw std::runtime_error{"setuid()"};
            }
        }
    }

    void BacklightIdentifier::parse(const jsn &data) {
        std::string tmp;

        data.at("prefix").get_to(prefix);

        data.at("vendor-id").get_to(tmp);
        vendor_id = std::stoi(tmp, nullptr, 16);

        data.at("device-id").get_to(tmp);
        device_id = std::stoi(tmp, nullptr, 16);
    }

} // namespace BrightnessDaemon
