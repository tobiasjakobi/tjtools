// SPDX-License-Identifier: GPL-2.0

#include "brightness_utils/config.h"
#include "brightness_utils/sysfs.h"

#include <boost/asio/local/datagram_protocol.hpp>
#include <boost/asio/buffer.hpp>
#include <boost/asio/io_context.hpp>
#include <boost/asio/signal_set.hpp>
#include <systemd/sd-journal.h>
#include <unistd.h>

#include <array>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string_view>
#include <vector>

namespace detail {

    using namespace std::string_view_literals;

    static constexpr unsigned kBufferSize{64};

    static constexpr unsigned kCommandFrameLenMax{32};
    static constexpr unsigned kCommandFrameSizeMin{2};

    static constexpr std::array kCommandTypeStrings{
        "SetState"sv,
        "ModifyState"sv,
        "SaveState"sv,
        "RestoreState"sv,
        "SetPowersave"sv,
    };

    static bool running{false};

} // namespace detail

namespace BrightnessDaemon {

    namespace as = boost::asio;

    using proto = as::local::datagram_protocol;

    enum class CommandType : std::uint8_t {
        SetState,
        ModifyState,
        SaveState,
        RestoreState,
        SetPowersave,

        Count,
    };

    struct CommandFrame {
        CommandType  type;
        std::uint8_t len;
        std::uint8_t value[];
    };

    struct SetStateFrame {
        CommandType   type;
        std::uint8_t  len;
        std::uint32_t value;
    } __attribute__((packed));

    struct ModifyStateFrame {
        CommandType   type;
        std::uint8_t  len;
        std::int32_t value;
    } __attribute__((packed));

    static auto to_string(const CommandType& ct) {
        switch (ct) {
            case CommandType::SetState:
            case CommandType::ModifyState:
            case CommandType::SaveState:
            case CommandType::RestoreState:
            case CommandType::SetPowersave:
                return ::detail::kCommandTypeStrings[static_cast<unsigned>(ct)];

            default:
                throw std::runtime_error{"invalid command type"};
        }
    }

    class BacklightContext {
    public:
        BacklightContext(const Config &cfg) : cfg_(cfg) {}
    
        void init() {
            using std::fstream;

            auto bl_node = lookup_backlight_node(cfg_.identifier);
            if (!bl_node.has_value()) {
                throw std::runtime_error{"failed to lookup backlight node"};
            }

            auto tmp = read_sysfs(bl_node.value() / "max_brightness"sv);
            if (!tmp.has_value()) {
                throw std::runtime_error{"failed to query maximum brightness"};
            }

            max_brightness_ = std::stoi(tmp.value());

            brightness_stream_.exceptions(fstream::failbit | fstream::badbit);
            brightness_stream_.open(bl_node.value() / "brightness"sv);

            sync();

            if (!fs::exists(cfg_.state_path)) {
                std::ofstream ofs(cfg_.state_path);
            }

            storage_stream_.open(cfg_.state_path, fstream::in | fstream::out | fstream::binary);
        }

        void setState(const unsigned value) {
            set(value);
        }

        void modifyState(const int value) {
            auto tmp = static_cast<int>(current_brightness_) + value;
            if (tmp < 0) {
                tmp = 0;
            }

            if (tmp > static_cast<int>(max_brightness_)) {
                tmp = max_brightness_;
            }

            set(static_cast<unsigned>(tmp));
        }

        void saveState() {
            storage_stream_.write(reinterpret_cast<const char *>(&current_brightness_), sizeof(unsigned));
            storage_stream_.flush();

            if (!storage_stream_.good()) {
                throw std::runtime_error{"failed to save brightness state"};
            }

            storage_stream_.seekp(0);
        }

        void restoreState() {
            unsigned tmp;

            storage_stream_.read(reinterpret_cast<char *>(&tmp), sizeof(tmp));

            const auto good_read = storage_stream_.good();

            storage_stream_.clear();
            storage_stream_.seekg(0);

            if (!good_read) {
                return;
            }

            try {
                set(tmp);
            } catch ([[maybe_unused]] const std::runtime_error &err) {
                // Just ignore this for now.
            }
        }

        void setPowersave() {
            set(cfg_.powersave_value);
        }

    private:
        void sync() {
            std::string tmp;

            brightness_stream_ >> tmp;
            current_brightness_ = std::stoi(tmp);

            brightness_stream_.clear();
            brightness_stream_.seekg(0);
        }

        void set(const unsigned value) {
            if (value > max_brightness_) {
                throw std::runtime_error{"value too large"};
            }

            brightness_stream_ << std::to_string(value);
            current_brightness_ = value;
            brightness_stream_.flush();
        }

        const Config &cfg_;

        unsigned current_brightness_;
        unsigned max_brightness_;

        std::fstream brightness_stream_;
        std::fstream storage_stream_;
    };

    class SocketContext {
    public:
        SocketContext(as::io_context &ioc, const Config &cfg) : ioc_(ioc), cfg_(cfg), sock_(ioc), ep_(cfg.socket_path) {}

        void init() {
            fs::remove(cfg_.socket_path);

            sock_.open();
            sock_.bind(ep_);

            if (!cfg_.user.empty()) {
                const auto info = get_uid_gid(cfg_.user.data(), cfg_.group.data());

                const auto ret = ::fchown(sock_.lowest_layer().native_handle(), info.first, info.second);
                if (ret != 0) {
                    throw std::runtime_error{std::string{"fchown() failed: "} + std::strerror(errno)};
                }
            }
        }

        void start(BacklightContext &bl_ctx, bool verbose) {
            drop_root_privileges(cfg_.user.data(), cfg_.group.data());

            bl_ctx_  = &bl_ctx;
            verbose_ = verbose;

            process();
        }

    private:
        void handleFrame(const CommandFrame &frame) {
            if (frame.type >= CommandType::Count) {
                ::sd_journal_print(LOG_WARNING, "invalid command frame type: %u", static_cast<unsigned>(frame.type));
                return;
            }

            const std::string cmd_type{to_string(frame.type)};

            if (verbose_) {
                ::sd_journal_print(LOG_NOTICE, "handling command type: %s", cmd_type.data());
            }

            switch (frame.type) {
                case CommandType::SetState: {
                    if (frame.len != sizeof(std::uint32_t)) {
                        throw std::runtime_error{"malformed set state"};
                    }

                    auto set_state = reinterpret_cast<const SetStateFrame *>(&frame);
                    bl_ctx_->setState(set_state->value);
                } break;

                case CommandType::ModifyState: {
                    if (frame.len != sizeof(std::int32_t)) {
                        throw std::runtime_error{"malformed modify state"};
                    }

                    auto modify_state = reinterpret_cast<const ModifyStateFrame *>(&frame);
                    bl_ctx_->modifyState(modify_state->value);
                } break;

                case CommandType::SaveState: {
                    if (frame.len != 0) {
                        throw std::runtime_error{"malformed save state"};
                    }

                    bl_ctx_->saveState();
                } break;

                case CommandType::RestoreState: {
                    if (frame.len != 0) {
                        throw std::runtime_error{"malformed restore state"};
                    }

                    bl_ctx_->restoreState();
                } break;

                case CommandType::SetPowersave: {
                    if (frame.len != 0) {
                        throw std::runtime_error{"malformed set powerstate"};
                    }

                    bl_ctx_->setPowersave();
                } break;

                default:
                    throw std::runtime_error{"unhandled command type"};
            }
        }

        void process() {
            using namespace ::detail;

            buffer_.clear();
            buffer_.resize(::detail::kBufferSize);

            sock_.async_receive(boost::asio::buffer(buffer_), [this](const auto &ec, auto bytes_transferred) {
                if (!ec) {
                    if (bytes_transferred < kCommandFrameSizeMin) {
                        ::sd_journal_print(LOG_WARNING, "short command frame");
                    } else {
                        auto frame = reinterpret_cast<const CommandFrame *>(buffer_.data());

                        if (frame->len > kCommandFrameLenMax || frame->len + kCommandFrameSizeMin != bytes_transferred) {
                            ::sd_journal_print(LOG_WARNING, "malformed command frame");
                        } else {
                            try {
                                handleFrame(*frame);
                            } catch (const std::runtime_error &err) {
                                ::sd_journal_print(LOG_ERR, "error handling frame: %s", err.what());
                            }
                        }
                    }

                    process();
                }
            });
        }

    private:
        as::io_context &ioc_;
        const Config   &cfg_;

        BacklightContext *bl_ctx_{nullptr};

        bool verbose_{false};

        proto::socket   sock_;
        proto::endpoint ep_;

        std::vector<std::uint8_t> buffer_;
    };

} // namespace BrightnessDaemon

int main([[maybe_unused]] int argc, [[maybe_unused]] char *argv[]) {
    BrightnessDaemon::Config config;

    config.read();

    boost::asio::io_context ioc;

    BrightnessDaemon::BacklightContext bl_ctx(config);
    BrightnessDaemon::SocketContext    sock_ctx(ioc, config);

    bl_ctx.init();
    sock_ctx.init();

    sock_ctx.start(bl_ctx, false);

    bl_ctx.restoreState();

    boost::asio::signal_set signals(ioc, SIGTERM, SIGINT);

    signals.async_wait([](const auto& ec, int signal_number) {
        if (!ec) {
            ::sd_journal_print(LOG_NOTICE, "received signal: %d", signal_number);

            ::detail::running = false;
        }
    });

    ::detail::running = true;

    while (::detail::running) {
        ioc.run_one();
    }

    bl_ctx.saveState();

    return 0;
}
