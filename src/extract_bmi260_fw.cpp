// SPDX-License-Identifier: GPL-2.0

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string_view>
#include <vector>

namespace detail {

    using namespace std::string_view_literals;

    using BufferType = std::vector<std::uint8_t>;

    struct Sequence {
        std::uint16_t offset; // At which offset do we expect the sequence?

        const std::uint16_t *data; // Sequence data
        std::size_t          len;  // Sequence length (in number of words)
    };

    // Output filename.
    //
    // Matches the filename the Linux kernel driver expects.
    static constexpr auto kOutputName{"bmi260-init-data.fw"sv};

    // Size of the firmware blob (in bytes).
    static constexpr std::size_t kBlobSize{8 * 1024};

    // Some magic values that occur frequently in the header.
    static constexpr std::uint16_t kMagic0{0x2ec8};
    static constexpr std::uint16_t kMagic1{0x2e80};
    static constexpr std::uint16_t kMagic2{0x2e00};
    static constexpr std::uint16_t kMagic3{0xc100};

    // First identifier that preludes the header of the blob.
    static constexpr std::array<std::uint16_t, 3> kIdent0{
        kMagic0, kMagic2, kMagic1,
    };

    // Second identifier.
    //
    // This is the longest identifier that appears in both the
    // fw blobs that we have access to.
    static constexpr std::array<std::uint16_t, 5> kIdent1{
        0x3050, 0x2e21, 0xf559, 0x3010, 0x2e21,
    };

    // Third identifier that seems to be some sort of padding.
    static constexpr std::array<std::uint16_t, 2> kPadding{
        kMagic1, kMagic3,
    };

    // Size of the fw blob header (in bytes).
    static constexpr std::size_t kHeaderSize{96};

    // Sequence array used to identify the header.
    static constexpr std::array<Sequence, 14> kHeader{{
        {0x00, kIdent0.data(), kIdent0.size()},
        {0x08, &kMagic0, 1},
        {0x0a, &kMagic2, 1},

        {0x10, &kMagic1, 1},
        {0x18, &kMagic0, 1},
        {0x1c, &kMagic1, 1},

        {0x20, kIdent1.data(), kIdent1.size()},

        {0x44, kPadding.data(), kPadding.size()},
        {0x48, kPadding.data(), kPadding.size()},
        {0x4c, kPadding.data(), kPadding.size()},
        {0x50, kPadding.data(), kPadding.size()},
        {0x54, kPadding.data(), kPadding.size()},
        {0x58, kPadding.data(), kPadding.size()},
        {0x5c, kPadding.data(), kPadding.size()},
    }};

    template <std::size_t Size>
    static auto check(const BufferType &buf, const std::array<Sequence, Size> &hdr) {
        for (const auto &seq : hdr) {
            const auto raw_mem = reinterpret_cast<const std::uint8_t *>(buf.data());
            const auto len     = seq.len * sizeof(std::uint16_t);

            if (::memcmp(raw_mem + seq.offset, seq.data, len) != 0) {
                return false;
            }
        }

        return true;
    }

    template <std::size_t Size>
    static auto locate(BufferType::const_iterator first, BufferType::const_iterator last, const std::array<std::uint16_t, Size> &pattern) {
        const auto buf_len     = (last - first) * sizeof(BufferType::value_type);
        const auto pattern_len = pattern.size() * sizeof(std::uint16_t);

        const BufferType::value_type *storage = &(*first);

        // We use memmem() here to search for the pattern, since we want the
        // search to be done on byte-level. If we use e.g. std::search we search
        // on the level of the buffer's value type.
        const auto *ptr = ::memmem(storage, buf_len, pattern.data(), pattern_len);
        if (ptr == nullptr) {
            return last;
        }

        const auto offset = reinterpret_cast<const BufferType::value_type *>(ptr) - storage;

        return first + offset;
    }

} // namespace detail

static void ExtractBMI260FW(const std::filesystem::path &path) {
    using namespace ::detail;

    using Stream = std::ifstream;

    Stream stream;

    stream.exceptions(Stream::failbit | Stream::badbit);
    stream.open(path);

    stream.seekg(0, Stream::end);
    const auto len = stream.tellg();
    stream.seekg(0, Stream::beg);

    BufferType buffer;
    buffer.resize(len);

    stream.read(reinterpret_cast<char *>(buffer.data()), len);

    BufferType header;
    header.resize(kHeaderSize);

    auto it = buffer.cbegin();

    while (true) {
        it = locate(it, buffer.cend(), kIdent0);
        if (it == buffer.cend()) {
            throw std::runtime_error{"blob not found"};
        }

        if (buffer.cend() - it < kBlobSize) {
            throw std::runtime_error{"no space left"};
        }

        std::copy(it, it + kHeaderSize, header.begin());

        if (check(header, kHeader)) {
            std::ofstream blob;

            blob.exceptions(Stream::failbit | Stream::badbit);
            blob.open(std::filesystem::path{kOutputName});

            blob.write(reinterpret_cast<const char *>(&(*it)), kBlobSize);

            return;
        }

        ++it;
    }

    throw std::runtime_error{"no matching blob found"};
}

int main(int argc, char *argv[]) {
    namespace fs = std::filesystem;

    if (argc < 2) {
        std::cerr << "error: missing input file argument\n";

        return -1;
    }

    const auto path = fs::canonical(fs::path{argv[1]});

    if (!fs::is_regular_file(path)) {
        std::cerr << "error: input is not a regular file\n";

        return -2;
    }

    try {
        ExtractBMI260FW(path);
    } catch (const std::runtime_error &err) {
        std::cerr << "error: fw extraction failed with runtime error: " << err.what() << std::endl;

        return -3;
    } catch (const std::exception &exc) {
        std::cerr << "error: fw extraction failed with exception: " << exc.what() << std::endl;

        return -4;
    }

    return 0;
}
