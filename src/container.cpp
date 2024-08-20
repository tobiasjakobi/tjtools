// SPDX-License-Identifier: GPL-2.0

#include "common_utils/scope_guard.h"

#include <boost/process/child.hpp>
#include <boost/process/io.hpp>
#include <boost/program_options.hpp>
#include <curl/curl.h>
#include <fmt/format.h>
#include <nlohmann/json.hpp>

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string_view>
#include <system_error>
#include <vector>

namespace detail {

    static const std::filesystem::path kConfigPath{"/etc/container.conf"};

    static constexpr auto     KCryptSetup{"/usr/bin/cryptsetup"};
    static constexpr unsigned kBufferSize{128};

} // namespace detail

namespace Container {

    namespace bp = boost::process;
    namespace fs = std::filesystem;

    using namespace std::string_view_literals;

    struct CallbackContext {
        std::vector<std::uint8_t> buffer;
    };

    struct ContainerConfig {
        std::string remote_user;
        std::string remote_host;
        std::string remote_base;

        void read() {
            using namespace ::detail;

            if (!fs::is_regular_file(kConfigPath)) {
                throw std::system_error(ENOENT, std::generic_category());
            }

            std::ifstream config_file(kConfigPath);
            if (!config_file.good()) {
                throw std::system_error(EACCES, std::generic_category());
            }

            const auto config_data = nlohmann::json::parse(config_file);

            config_data.at("remote-user").get_to(remote_user);
            config_data.at("remote-host").get_to(remote_host);
            config_data.at("remote-base").get_to(remote_base);
        }
    };

    static std::size_t curl_write_cb(void *buffer, std::size_t size, std::size_t nmemb, void *userdata) {
        auto ctx = reinterpret_cast<CallbackContext *>(userdata);

        auto incoming = reinterpret_cast<const std::uint8_t *>(buffer);

        auto &b = ctx->buffer;

        b.insert(std::end(b), incoming, incoming + size * nmemb);

        return size * nmemb;
    }

    /**
     * @brief Fetch a scp:// URL using libCURL.
     *
     * @param address The address part of the URL
     * @param buffer  Buffer into which the URL is fetched
     * @param verbose Should we be verbose when fetching?
     */
    static void scp_fetch(const std::string &address, std::vector<std::uint8_t> &buffer, const bool verbose) {
        CallbackContext ctx;
        ctx.buffer.reserve(::detail::kBufferSize);

        ::curl_global_init(CURL_GLOBAL_DEFAULT);

        auto sg_global = CommonUtils::scope_guard([] { ::curl_global_cleanup(); });

        auto curl = ::curl_easy_init();
        if (curl == nullptr) {
            throw std::runtime_error{"curl_easy_init()"};
        }

        auto sg_easy = CommonUtils::scope_guard([curl] { ::curl_easy_cleanup(curl);});

        // Setup download URL.
        {
            const auto url = std::string{"scp://"} + address;

            ::curl_easy_setopt(curl, CURLOPT_URL, url.data());
        }

        ::curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_write_cb);
        ::curl_easy_setopt(curl, CURLOPT_WRITEDATA, &ctx);

        // Setup SSH private/public key file.
        {
            const auto ssh_dir = fs::path{::getenv("HOME")} / ".ssh"sv;

            const auto private_key = ssh_dir / "id_ed25519"sv;
            const auto public_key = ssh_dir / "id_ed25519.pub"sv;

            ::curl_easy_setopt(curl, CURLOPT_SSH_PRIVATE_KEYFILE, private_key.c_str());
            ::curl_easy_setopt(curl, CURLOPT_SSH_PUBLIC_KEYFILE, public_key.c_str());
        }

        if (verbose) {
            ::curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
        }

        const auto res = ::curl_easy_perform(curl);
 
        if (res != CURLE_OK) {
            throw std::runtime_error{std::string{"curl_easy_perform(): "} + ::curl_easy_strerror(res)};
        }

        buffer.swap(ctx.buffer);
    }

    /**
     * @brief Open a encrypted container.
     *
     * @param cfg      The container configuraiton
     * @param hostname The hostname of the local machine
     * @param spec     The container specification
     */
    static void open(const ContainerConfig &cfg, std::string_view hostname, std::string_view spec) {
        const auto pos = spec.find('.');
        if (pos == std::string_view::npos) {
            throw std::runtime_error{"malformed spec"};
        }

        const auto name = spec.substr(0, pos);
        const auto uuid = spec.substr(pos + 1);

        if (name.empty()) {
            throw std::runtime_error{"empty name"};
        }

        if (uuid.empty()) {
            throw std::runtime_error{"empty UUID"};
        }

        const auto device = fs::path{"/dev/disk/by-uuid"} / uuid;
        if (!fs::exists(device)) {
            throw std::runtime_error{"no device present with such UUID"};
        }

        const auto path    = fs::path{cfg.remote_base} / hostname / fmt::format("key.{}", spec);
        const auto address = fmt::format("{0}@{1}/{2}", cfg.remote_user, cfg.remote_host, path.string());

        std::vector<std::uint8_t> key_content;
        scp_fetch(address, key_content, false);

        const std::vector<std::string> args{
            "open",
            "--allow-discards",
            "--key-file", "-",
            device.string(),
            fmt::format("container-{}", name),
        };

        bp::opstream in_stream;
        bp::child c(::detail::KCryptSetup, args, bp::std_err > bp::null, bp::std_in < in_stream);

        in_stream.write(reinterpret_cast<const char *>(key_content.data()), key_content.size());

        in_stream.flush();
        in_stream.pipe().close();

        c.wait();

        if (c.exit_code() != 0) {
            throw std::system_error(EFAULT, std::generic_category());
        }
    }

    /**
     * @brief Close a encrypted container.
     *
     * @param cfg  The container configuraiton
     * @param spec The container specification
     */
    static void close([[maybe_unused]] const ContainerConfig &cfg, std::string_view spec) {
        const auto pos = spec.find('.');
        if (pos == std::string_view::npos) {
            throw std::runtime_error{"malformed spec"};
        }

        const auto name = spec.substr(0, pos);
        const auto uuid = spec.substr(pos + 1);

        if (name.empty()) {
            throw std::runtime_error{"empty name"};
        }

        if (uuid.empty()) {
            throw std::runtime_error{"empty UUID"};
        }

        const std::vector<std::string> args{
            "close",
            fmt::format("container-{}", name),
        };

        bp::child c(::detail::KCryptSetup, args, bp::std_err > bp::null);

        c.wait();

        if (c.exit_code() != 0) {
            throw std::system_error(EFAULT, std::generic_category());
        }
    }

} // namespace Container

int main(int argc, char *argv[]) {
    using namespace Container;

    namespace po = boost::program_options;

    po::options_description desc("Allowed options");
    desc.add_options()
        ("help,h", "display help message")
        ("mode,m", po::value<std::string>()->required(), "Operation mode (allowed values = open, close)")
        ("hostname,o", po::value<std::string>()->required(), "Hostname of the local machine")
        ("specification,s", po::value<std::string>()->required(), "Container specification, i.e. <container name>.<device UUID>");

    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, desc), vm);
    po::notify(vm);

    if (vm.count("help") != 0) {
        std::cout << desc << std::endl;

        return 0;
    }

    ContainerConfig config;

    config.read();

    const auto &mode     = vm["mode"].as<std::string>();
    const auto &hostname = vm["hostname"].as<std::string>();
    const auto &spec     = vm["specification"].as<std::string>();

    try {
        if (mode == "open"sv) {
            open(config, hostname, spec);
        } else if (mode == "close"sv) {
            close(config, spec);
        } else {
            std::cerr << "error: invalid operation mode: " << mode << std::endl;

            return 1;
        }
    } catch (const std::runtime_error &err) {
        std::cerr << "error: error executing operation: " << err.what() << std::endl;

        return 1;
    }

    return 0;
}

