/*
 * g++ -ludev -lboost_program_options -O2 -o battery_watch battery_watch.cpp
 */

#include <charconv>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <memory>
#include <string_view>
#include <system_error>
#include <thread>
#include <type_traits>
#include <utility>

#include <boost/program_options.hpp>
#include <libudev.h>

namespace BatteryWatch {

    namespace fs = std::filesystem;

    using namespace std::chrono_literals;

    static const fs::path kPowerState{"/sys/power/state"};
    static constexpr auto kCooldownTime = 5s;

    static auto make_device(struct ::udev_device *device) {
        auto deleter = [](struct ::udev_device *device) { ::udev_device_unref(device); };

        return std::unique_ptr<struct ::udev_device, decltype(deleter)>(device, deleter);
    }

    using UDevDevice = std::invoke_result<decltype(&make_device), struct ::udev_device *>::type;

    static std::string_view get_sysattr_value(struct ::udev_device *device, const char *sysattr) {
        auto value = ::udev_device_get_sysattr_value(device, sysattr);
        if (value == nullptr) {
            return std::string_view{};
        }

        return std::string_view{value};
    } 

    static unsigned to_unsigned(std::string_view input) {
        unsigned output{};

        auto result = std::from_chars(input.data(), input.data() + input.size(), output);
        if (result.ec != std::errc()) {
            throw std::system_error(static_cast<int>(result.ec), std::generic_category());
        }

        return output;
    }

    static void sys_suspend() {
        std::ofstream stream;

        stream.exceptions(std::ofstream::failbit | std::ofstream::badbit);
        stream.open(kPowerState);

        stream << "mem";
        stream.flush();
        stream.close();

        std::this_thread::sleep_for(kCooldownTime);
    }

    class BatteryContext {
    private:
        enum class State : unsigned {
            Unknown,
            Charging,
            Discharging,
        };

    public:
        BatteryContext(const std::string &device) : udev_ctx_(::udev_new()), device_name_(device) {
            if (udev_ctx_ == nullptr) {
                throw std::system_error(ENOMEM, std::generic_category());
            }

            if (device_name_.empty()) {
                throw std::system_error(EINVAL, std::generic_category());
            }
        }

        ~BatteryContext() {
            if (udev_ctx_ != nullptr) {
                ::udev_unref(udev_ctx_);
            }
        }

        void poll() {
            auto device = make_device(::udev_device_new_from_subsystem_sysname(udev_ctx_, "power_supply", device_name_.data()));
            if (!device) {
                throw std::system_error(ENODEV, std::generic_category());
            }

            std::string_view attrval;

            attrval = get_sysattr_value(device.get(), "status");

            if (attrval == std::string_view{"Charging"}) {
                state_ = State::Charging;
            } else if (attrval == std::string_view{"Discharging"}) {
                state_ = State::Discharging;
            } else {
                state_ = State::Unknown;
            }

            bool use_energy = false;
            unsigned charge_full{}, charge_now{};

            attrval = get_sysattr_value(device.get(), "charge_full");

            if (attrval.empty()) {
                use_energy = true;
            } else {
                charge_full = to_unsigned(attrval);

                attrval = get_sysattr_value(device.get(), "charge_now");
                charge_now = to_unsigned(attrval);
            }

            if (use_energy) {
                attrval = get_sysattr_value(device.get(), "energy_full");
                charge_full = to_unsigned(attrval);

                attrval = get_sysattr_value(device.get(), "energy_now");
                charge_now = to_unsigned(attrval);
            }

            if (charge_full == 0 || charge_now == 0) {
                throw std::system_error(EINVAL, std::generic_category());
            }

            charge_level_ = float(charge_now) / float(charge_full);
        }

        bool is_critical(float treshold) const {
            if (state_ != State::Discharging) {
                return false;
            }

            return charge_level_ * 100.0f < treshold;
        }

    private:
        struct ::udev *udev_ctx_;

        std::string device_name_{};

        State state_{State::Unknown};
        float charge_level_{-1.0f};
    };

} // namespace BatteryWatch

int main(int argc, char *argv[]) {
    namespace po = boost::program_options;

    po::options_description desc("Allowed options");
    desc.add_options()
        ("help,h", "display help message")
        ("interval,i", po::value<unsigned>(), "polling interval (in seconds)")
        ("treshold,t", po::value<float>(), "low battery treshold (in percentage)")
        ("device,d", po::value<std::string>(), "battery device name");

    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, desc), vm);
    po::notify(vm);

    if (vm.count("help")) {
        std::cout << desc << std::endl;

        return 0;
    }

    if (vm.count("interval") == 0) {
        std::cerr << "error: missing interval argument" << std::endl;
        std::cout << desc << std::endl;

        return 1;
    }

    if (vm.count("treshold") == 0) {
        std::cerr << "error: missing treshold argument" << std::endl;
        std::cout << desc << std::endl;

        return 2;
    }

    if (vm.count("device") == 0) {
        std::cerr << "error: missing device argument" << std::endl;
        std::cout << desc << std::endl;

        return 3;
    }

    const auto treshold = vm["treshold"].as<float>();
    if (treshold <= 5.0f || treshold >= 95.0f) {
        std::cerr << "error: invalid treshold argument: " << treshold << std::endl;
        std::cout << desc << std::endl;

        return 4;
    }

    BatteryWatch::BatteryContext battery_ctx(vm["device"].as<std::string>());

    const std::chrono::seconds polling_interval{vm["interval"].as<unsigned>()};

    while (true) {
        battery_ctx.poll();

        if (battery_ctx.is_critical(treshold)) {
            std::cout << "info: battery level critical, suspending system..." << std::endl;

            BatteryWatch::sys_suspend();
        }

        std::this_thread::sleep_for(polling_interval);
    }

    return 0;
}
