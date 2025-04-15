// SPDX-License-Identifier: GPL-2.0

#include <openssl/evp.h>

#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include <cstdint>
#include <cstring>
#include <iomanip>
#include <ios>
#include <iostream>
#include <stdexcept>
#include <vector>

namespace detail {

    namespace UCode {

        // TODO: desc
        static constexpr std::uint32_t kMagic{0x414d44};

        // TOOD: desc
        static constexpr std::uint32_t kEquivCPUTableType{0x0};

        // TODO: desc
        static constexpr std::uint32_t kUCodeType{0x1};

    } // namespace UCode

} // namespace detail

namespace AMDMicrocode {

    using PayloadType = std::vector<std::uint8_t>;

    struct OuterHeader {
        std::uint32_t magic;
        std::uint32_t table_type;
        std::uint32_t table_len;
    } __attribute__((packed));

    struct EquivCPUEntry {
        std::uint32_t installed_cpu;
        std::uint32_t fixed_errata_mask;
        std::uint32_t fixed_errata_compare;
        std::uint16_t equiv_cpu;
        std::uint16_t res;
    } __attribute__((packed));

    struct MicrocodeHeader {
        std::uint32_t data_code;
        std::uint32_t patch_id;
        std::uint16_t mc_patch_data_id;
        std::uint8_t  mc_patch_data_len;
        std::uint8_t  init_flag;
        std::uint32_t mc_patch_data_checksum;
        std::uint32_t nb_dev_id;
        std::uint32_t sb_dev_id;
        std::uint16_t processor_rev_id;
        std::uint8_t  nb_rev_id;
        std::uint8_t  sb_rev_id;
        std::uint8_t  bios_api_rev;
        std::uint8_t  reserved1[3];
        std::uint32_t match_reg[8];
    } __attribute__((packed));

    struct InnerHeader {
        std::uint32_t patch_type;
        std::uint32_t patch_size;
    } __attribute__((packed));

    struct Microcode {
        InnerHeader hdr;
        PayloadType payload;

        const MicrocodeHeader *mchdr;
    };

    static void print_sha256(const std::uint8_t *data, const std::size_t len) {
        using namespace ::detail;

        auto ctx = ::EVP_MD_CTX_new();
        if (ctx == nullptr) {
            throw std::runtime_error{"EVP_MD_CTX_new()"};
        }

        auto ret = ::EVP_DigestInit_ex(ctx, ::EVP_sha256(), nullptr);
        if (ret != 1) {
            throw std::runtime_error{"EVP_DigestInit_ex()"};
        }


        ret = ::EVP_DigestUpdate(ctx, data, len);
        if (ret != 1) {
            throw std::runtime_error{"EVP_DigestUpdate()"};
        }

        std::uint8_t sha256_digest[EVP_MAX_MD_SIZE];
        unsigned digest_length = 0;

        ret = ::EVP_DigestFinal_ex(ctx, sha256_digest, &digest_length);
        if (ret != 1) {
            throw std::runtime_error{"EVP_DigestFinal_ex()"};
        }

        ret = ::EVP_MD_CTX_reset(ctx);
        if (ret != 1) {
            throw std::runtime_error{"EVP_MD_CTX_reset()"};
        }

        ::EVP_MD_CTX_free(ctx);

        const auto cout_flags = std::cout.flags();
        std::cout << "digest={" << std::hex;
        for (unsigned i = 0; i < digest_length; ++i) {
            if (i != 0) {
                std::cout << ',';
            }

            if ((i % 8) == 0) {
                std::cout << '\n';
            }

            std::cout << "0x" << std::setw(2) << std::setfill('0') << static_cast<std::uint32_t>(sha256_digest[i]);
        }
        std::cout << '}' << std::endl;
        std::cout.flags(cout_flags);
    }

} // namespace AMDMicrocode

int main([[maybe_unused]] int argc, [[maybe_unused]] char *argv[]) {
    using namespace AMDMicrocode;

    if (argc < 2) {
        throw std::runtime_error{"missing argument"};
    }

    const auto fd = open(argv[1], O_RDONLY);
    if (fd < 0) {
        throw std::runtime_error{"failed to open file"};
    }

    struct ::stat statbuf;

    const auto ret = ::fstat(fd, &statbuf);
    if (ret < 0) {
        const auto errcode = errno;

        throw std::runtime_error{std::string{"fstat(): "} + std::strerror(errcode)};
    }

    const auto len = statbuf.st_size;
    if (len <= 0) {
        throw std::runtime_error{"empty file"};
    }

    auto available_bytes = static_cast<std::size_t>(len);

    if (available_bytes < sizeof(OuterHeader)) {
        throw std::runtime_error{"no outer header"};
    }

    auto fd_map = ::mmap(nullptr, statbuf.st_size, PROT_READ, MAP_PRIVATE, fd, 0);

    auto buffer = reinterpret_cast<const std::uint8_t *>(fd_map);

    OuterHeader ohdr;
    std::memcpy(&ohdr, buffer, sizeof(OuterHeader));

    buffer += sizeof(OuterHeader);
    available_bytes -= sizeof(OuterHeader);

    if (ohdr.magic != ::detail::UCode::kMagic) {
        throw std::runtime_error{"wrong magic"};
    }

    if (ohdr.table_type != ::detail::UCode::kEquivCPUTableType) {
        throw std::runtime_error{"no equiv CPU table"};
    }

    if ((ohdr.table_len % sizeof(EquivCPUEntry)) != 0) {
        throw std::runtime_error{"wrong table length"};
    }

    const auto num_entries = ohdr.table_len / sizeof(EquivCPUEntry);

    std::vector<EquivCPUEntry> entries;

    for (unsigned i = 0; i < num_entries; ++i) {
        if (available_bytes < sizeof(EquivCPUEntry)) {
            throw std::runtime_error{"short entry"};
        }

        EquivCPUEntry entry;
        std::memcpy(&entry, buffer, sizeof(EquivCPUEntry));

        buffer += sizeof(EquivCPUEntry);
        available_bytes -= sizeof(EquivCPUEntry);

        if (entry.installed_cpu == 0) {
            break;
        }

        entries.push_back(entry);
    }

    for (const auto &it : entries) {
        Microcode mc;

        if (available_bytes < sizeof(InnerHeader)) {
            throw std::runtime_error{"short inner header"};
        }

        std::memcpy(&mc.hdr, buffer, sizeof(InnerHeader));

        buffer += sizeof(InnerHeader);
        available_bytes -= sizeof(InnerHeader);

        if (mc.hdr.patch_type != ::detail::UCode::kUCodeType) {
            throw std::runtime_error{"wrong patch type"};
        }

        if (available_bytes < sizeof(MicrocodeHeader)) {
            throw std::runtime_error{"short mc header"};
        }

        const auto p_size = mc.hdr.patch_size;

        if (available_bytes < p_size) {
            throw std::runtime_error{"short payload"};
        }

        mc.payload.resize(p_size);

        std::memcpy(mc.payload.data(), buffer, p_size);

        buffer += p_size;
        available_bytes -= p_size;

        mc.mchdr = reinterpret_cast<const MicrocodeHeader *>(mc.payload.data());

        const auto cout_flags = std::cout.flags();
        std::cout << "patch_id=0x" << std::hex << mc.mchdr->patch_id << std::endl;
        std::cout.flags(cout_flags);

        print_sha256(mc.payload.data(), mc.hdr.patch_size);
    }

    ::munmap(fd_map, len);
    ::close(fd);

    return 0;
}

