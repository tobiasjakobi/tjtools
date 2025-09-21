// SPDX-License-Identifier: GPL-2.0

#include "aecram.h"

#include "common_utils/scope_guard.h"

#include <boost/program_options.hpp>
#include <fmt/format.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>

#include <cerrno>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <stdexcept>

namespace detail {

    // AECRAM kernel device.
    static const char kDevice[] = "/dev/aecram";

    // Offset into the 16-bit AEC address space.
    //
    // Details currently unknown.
    static const std::uint16_t kUnknownOffset = 0xd100;

} // namespace detail

namespace AECRAM {

    static void dump(std::size_t offset, std::size_t length) {
        if (offset > std::numeric_limits<std::uint16_t>::max()) {
            throw std::runtime_error{"invalid offset"};
        }

        if (length > AECRAM_BUFFER_SIZE) {
            throw std::runtime_error{"invalid lenght"};
        }

        const auto fd = ::open(::detail::kDevice, O_RDWR);
        if (fd < 0) {
            const auto err = std::strerror(errno);

            throw std::runtime_error{fmt::format("failed to open AECRAM device: {}", err)};
        }

        auto fd_sg = CommonUtils::scope_guard([fd]() { ::close(fd); });

        // Configure the AECRAM driver for Ayaneo devices.
        {
            const int aecram_type = AECRAM_TYPE_AYANEO;

            if (const auto ret = ::ioctl(fd, IOCTL_AECRAM_SET_TYPE, &aecram_type); ret < 0) {
                const auto err = std::strerror(errno);

                throw std::runtime_error{fmt::format("failed to set AECRAM type: {}", err)};
            }
        }

        // Read bytes and print.
        {
            struct ::aecram_request req = {
                .offset   = ::detail::kUnknownOffset + offset,
                .length   = length,
                .reserved = 0,
                .buffer   = { 0 },
            };

            if (const auto ret = ::ioctl(fd, IOCTL_AECRAM_READ, &req); ret < 0) {
                const auto err = std::strerror(errno);

                throw std::runtime_error{fmt::format("failed to read AECRAM: {}", err)};
            }

            for (unsigned i = 0; i < length; ++i) {
                std::cout << std::hex << static_cast<unsigned>(req.buffer[i]) << std::endl;
            }
        }
    }
} // namespace AECRAM

int main(int argc, char *argv[]) {
    namespace po = boost::program_options;

    po::options_description desc("Allowed options");
    desc.add_options()
        ("help,h", "display help message")
        ("offset,o", po::value<std::size_t>(), "Read at offset")
        ("length,l", po::value<std::size_t>(), "Read length bytes");

    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, desc), vm);
    po::notify(vm);

    if (vm.count("help")) {
        std::cout << desc << std::endl;

        return 0;
    }

    if (vm.count("offset") == 0) {
        std::cerr << "error: missing offset argument" << std::endl;

        return -1;
    }

    if (vm.count("length") == 0) {
        std::cerr << "error: missing length argument" << std::endl;

        return -2;
    }

    try {
        const auto offset = vm["offset"].as<std::size_t>();
        const auto length = vm["length"].as<std::size_t>();

        AECRAM::dump(offset, length);
    } catch (const std::runtime_error &err) {
        std::cerr << "error: dump failed: " << err.what() << std::endl;

        return -3;
    }

    return 0;
}
