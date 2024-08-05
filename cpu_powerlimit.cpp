/*
 * g++ -lboost_program_options -O2 -o cpu_powerlimit cpu_powerlimit.cpp
 */

#include <csignal>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <memory>
#include <optional>
#include <system_error>
#include <utility>
#include <vector>

#define BOOST_PROCESS_USE_STD_FS

#include <boost/interprocess/sync/file_lock.hpp>
#include <boost/process/child.hpp>
#include <boost/process/io.hpp>
#include <boost/program_options.hpp>
#include <nlohmann/json.hpp>

#include <unistd.h>

namespace CPUPowerlimit {

    namespace fs = std::filesystem;

    using jsn = nlohmann::json;

    static const fs::path kRyzenAdj{"/usr/bin/ryzenadj"};
    static const fs::path kConfigPath{"/etc/cpu-powerlimits.conf"};
    static const fs::path kLockPath{"/run/lock/cpu-powerlimits.lock"};

    static constexpr std::pair<float, float> kPowerlimitTDPBounds{8.0, 54.0};

    static std::string limit_scale(float value) {
        const auto rescaled = static_cast<unsigned>(std::lround(value * 1000.0f));

        return std::to_string(rescaled);
    }

    static bool bounds_check(float value) {
        return value >= kPowerlimitTDPBounds.first && value <= kPowerlimitTDPBounds.second;
    }

    class LimitProfile {
    public:
        void apply() const {
            namespace bp = boost::process;

            std::vector<std::string> args{
                std::string{"--stapm-limit="} + limit_scale(stapm_limit_),
                std::string{"--fast-limit="} + limit_scale(fast_limit_),
                std::string{"--slow-limit="} + limit_scale(slow_limit_),
            };

            if (tctl_temp_.has_value()) {
                args.push_back(std::string{"--tctl-temp="} + limit_scale(tctl_temp_.value()));
            }

            bp::child c(kRyzenAdj, args, bp::std_err > bp::null);

            c.wait();

            if (c.exit_code() != 0) {
                throw std::system_error(EFAULT, std::generic_category());
            }
        }

        void parse(const jsn& input) {
            stapm_limit_ = input.at("stapm_limit").get<float>();
            fast_limit_ = input.at("fast_limit").get<float>();
            slow_limit_ = input.at("slow_limit").get<float>();
            tctl_temp_ = input.at("tctl_temp").get<float>();
        }

        void fromTDP(float tdp, float fast_multiplier, float slow_multiplier) {
            const auto fast = tdp * fast_multiplier;
            const auto slow = tdp * slow_multiplier;

            if (!bounds_check(tdp) || !bounds_check(fast) || !bounds_check(slow)) {
                throw std::system_error(EINVAL, std::generic_category());
            }
        }

        float getTDP() const {
            return stapm_limit_;
        }

    private:
        float stapm_limit_{-1.0f};
        float fast_limit_{-1.0f};
        float slow_limit_{-1.0f};

        std::optional<float> tctl_temp_{};
    };

    struct LimitConfig {
        float fast_multiplier;
        float slow_multiplier;

        std::map<std::string, LimitProfile> profiles;

        void read() {
            if (!fs::is_regular_file(kConfigPath)) {
                throw std::system_error(ENOENT, std::generic_category());
            }

            std::ifstream config_file(kConfigPath);
            if (!config_file.good()) {
                throw std::system_error(EACCES, std::generic_category());
            }

            const auto config_data = jsn::parse(config_file);

            fast_multiplier = config_data.at("fast_multiplier").get<float>();
            slow_multiplier = config_data.at("slow_multiplier").get<float>();

            bool has_default = false;

            for (auto &profile : config_data.at("profiles").items()) {
                const auto profile_name = profile.key();

                if (profile_name == "default") {
                    has_default = true;
                }

                LimitProfile limit_profile;

                limit_profile.parse(profile.value());

                profiles.emplace(std::move(profile_name), std::move(limit_profile));
            }

            if (!has_default) {
                throw std::system_error(EINVAL, std::generic_category());
            }
        }
    };

} // namespace CPUPowerlimit

int main(int argc, char *argv[]) {
    using namespace CPUPowerlimit;

    namespace po = boost::program_options;

    po::options_description desc("Allowed options");
    desc.add_options()
        ("help,h", "display help message")
        ("profile,p", po::value<std::string>(), "Use a (named) profile to set the CPU powerlimit")
        ("tdp,t", po::value<float>(), "Use a numeric TDP value (in W) to set the CPU powerlimit")
        ("init,i", "Are we initializing the CPU powerlimit?");

    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, desc), vm);
    po::notify(vm);

    if (vm.count("help")) {
        std::cout << desc << std::endl;

        return 0;
    }

    LimitConfig limit_config;

    limit_config.read();

    const auto &def_profile = limit_config.profiles.at("default");

    LimitProfile limit_profile;
    bool         is_init{false};

    if (vm.count("init") != 0) {
        std::cout << "info: initializing CPU powerlimit with TDP: " << def_profile.getTDP() << std::endl;

        if (!fs::exists(kLockPath)) {
            std::cout << "info: creating lock file: " << kLockPath << std::endl;

            std::ofstream touch_lock;
            touch_lock.exceptions(std::ofstream::failbit | std::ofstream::badbit);
            touch_lock.open(kLockPath);
        }

        limit_profile = def_profile;
        is_init       = true;
    } else if (vm.count("profile") != 0) {
        const auto profile = vm["profile"].as<std::string>();

        std::cout << "info: using profile to set CPU powerlimit: " << profile << std::endl;

        limit_profile = limit_config.profiles.at(profile);
    } else if (vm.count("tdp") != 0) {
        const auto tdp = vm["tdp"].as<float>();

        std::cout << "info: using TDP to set CPU powerlimit: " << tdp << std::endl;

        limit_profile.fromTDP(tdp, limit_config.fast_multiplier, limit_config.slow_multiplier);
    } else {
        std::cerr << "error: missing profile/TDP argument" << std::endl;

        return 1;
    }

    boost::interprocess::file_lock powerlimit_lock{kLockPath.c_str()};

    if (!powerlimit_lock.try_lock()) {
        throw std::system_error(EBUSY, std::generic_category());
    }

    limit_profile.apply();

    if (!is_init) {
        const auto signal_handler = [](int signal) {
            std::cout << "info: signal received: " << signal << std::endl;
        };

        std::signal(SIGINT, signal_handler);
        std::signal(SIGTERM, signal_handler);

        ::pause();

        std::cout << "info: restoring CPU powerlimit to defaults..." << std::endl;

        def_profile.apply();
    }

    powerlimit_lock.unlock();

    return 0;
}
