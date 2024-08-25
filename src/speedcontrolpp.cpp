// SPDX-License-Identifier: GPL-2.0

#include "common_utils/scope_guard.h"

#include <boost/program_options.hpp>
#include <linux/cdrom.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>

#include <cerrno>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>

// Code is based on the speedcontrol tool written in C
// by Thomas Fritzsche <tf@noto.de>.

namespace detail {

    // Size in bytes of the performance descriptor for SET_STREAMING.
    static constexpr unsigned kPerfDescSize{28};

    static constexpr std::uint32_t kReadSizeMultiplier{177UL};

    static constexpr std::uint32_t kMaxSpeed = std::numeric_limits<std::uint32_t>::max() / (kReadSizeMultiplier + 1);

} // namespace detail

namespace SpeedControl {

    namespace fs = std::filesystem;

    struct PerformanceDescriptor {
        std::uint8_t  random_access:1;
        std::uint8_t  exact:1;
        std::uint8_t  restore_logical_unit_defaults:1;
        std::uint8_t  write_rotation_control:2;
        std::uint8_t  reserved0:3;
        std::uint8_t  reserved1[3];
        std::uint32_t start_lba;
        std::uint32_t end_lba;
        std::uint32_t read_size;  // in kilobytes
        std::uint32_t read_time;  // in milliseconds
        std::uint32_t write_size; // in kilobytes
        std::uint32_t write_time; // in milliseconds
    };

    static_assert(sizeof(PerformanceDescriptor) == ::detail::kPerfDescSize);

    class CommandContext {
    public:
        CommandContext() {
            std::memset(&generic_command_, 0x00, sizeof(::cdrom_generic_command));

            generic_command_.sense  = &sense_;
            generic_command_.buffer = reinterpret_cast<unsigned char*>(&perf_desc_);
            generic_command_.buflen = sizeof(PerformanceDescriptor);
        }

        void setStreaming(const unsigned speed) {
            if (speed >= ::detail::kMaxSpeed) {
                throw std::runtime_error{"invalid speed"};
            }

            generic_command_.cmd[0]  = GPCMD_SET_STREAMING;

            // TODO: this should write to both 9 and 10
            generic_command_.cmd[10] = sizeof(PerformanceDescriptor);

            generic_command_.data_direction = CGC_DATA_WRITE;
            generic_command_.quiet          = 1;

            std::memset(&sense_, 0x00, sizeof(::request_sense));
            std::memset(&perf_desc_, 0x00, sizeof(PerformanceDescriptor));

            // Set the "Restore Logical Unit Defaults" bit.
            if (speed == 0) {
                perf_desc_.restore_logical_unit_defaults = 1;
            }

            perf_desc_.end_lba = __builtin_bswap32(std::numeric_limits<std::uint32_t>::max());

            // Convert to kbyte/s.
            const std::uint32_t rw_size = static_cast<std::uint32_t>(speed) * ::detail::kReadSizeMultiplier;

            // Use timebase of 1s = 1000ms.
            perf_desc_.read_size = __builtin_bswap32(rw_size);
            perf_desc_.read_time = __builtin_bswap32(1000);

            perf_desc_.write_size = __builtin_bswap32(rw_size);
            perf_desc_.write_time = __builtin_bswap32(1000);

            speed_ = speed;
        }

        void issue(const fs::path &path) {
            auto fd = ::open(path.c_str(), O_RDONLY | O_NONBLOCK);
            if (fd < 0) {
                throw std::runtime_error{std::string{"open(): "} + std::strerror(errno)};
            }

            auto fd_sg = CommonUtils::scope_guard([fd]() { ::close(fd); });

            auto ret = ::ioctl(fd, CDROM_SEND_PACKET, &generic_command_);
            if (ret == 0) {
                std::cout << "info: SET_STREAMING successful" << std::endl;

                return;
            }

            std::cout << "info: trying again with legacy speed select" << std::endl;

            ret = ::ioctl(fd, CDROM_SELECT_SPEED, speed_);
            if (ret == 0) {
                std::cout << "info: SET_CD_SPEED successful" << std::endl;

                return;
            }

            std::cerr << "error: command failed" << std::endl;

            dump();
        }

    private:
        void dump() {
            const auto cmd = generic_command_.cmd;

            const auto flags = std::cerr.flags();

            std::cerr << "cmd="  << std::hex;

            for (unsigned i = 0; i < CDROM_PACKET_SIZE; ++i) {
                std::cerr << static_cast<unsigned>(cmd[i]) << ' ';
            }

            if (generic_command_.sense != nullptr) {
                const auto &sense = *generic_command_.sense;

                std::cerr << "; sense=" << sense.sense_key << '.' << sense.asc << '.' << sense.ascq;
            } else {
                std::cerr << "; no sense";
            }

            std::cerr << std::endl;

            std::cerr.flags(flags);
        }

    private:
        ::cdrom_generic_command generic_command_{};
        ::request_sense sense_;

        PerformanceDescriptor perf_desc_;

        unsigned speed_{0};
    };

};

int main(int argc, char *argv[]) {
    namespace po = boost::program_options;

    po::options_description desc("Allowed options");
    desc.add_options()
        ("help,h", "display help message")
        ("device,d", po::value<std::string>()->required(), "Device for which we want to apply speed control")
        ("speed,s", po::value<unsigned>()->required(), "CD/DVD speed value");

    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, desc), vm);

    if (vm.count("help")) {
        std::cout << desc << std::endl;

        return 0;
    }

    try {
        po::notify(vm);
    } catch (const std::exception &exc) {
        std::cerr << "error: invalid arguments: " << exc.what() << std::endl;

        return 1;
    }

    SpeedControl::CommandContext cmd_ctx;

    const std::filesystem::path device_path{vm["device"].as<std::string>()};

    if (!std::filesystem::is_block_file(device_path)) {
        std::cerr << "error: invalid device argument: " << device_path << std::endl;

        return 2;
    }

    try {
        cmd_ctx.setStreaming(vm["speed"].as<unsigned>());
        cmd_ctx.issue(device_path);
    } catch (const std::runtime_error &err) {
        std::cerr << "error: speed control failed: " << err.what() << std::endl;

        return 3;
    }

    return 0;
}
