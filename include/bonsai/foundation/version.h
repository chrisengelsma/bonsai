#pragma once

#include <string>

namespace bonsai::foundation {

    [[nodiscard]] int version_major() noexcept;
    [[nodiscard]] int version_minor() noexcept;
    [[nodiscard]] int version_patch() noexcept;
    [[nodiscard]] std::string version_string();

} // namespace bonsai::foundation