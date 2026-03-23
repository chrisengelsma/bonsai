#include "bonsai/foundation/version.h"

#include <string>

namespace bonsai::foundation {

    namespace {
        constexpr int kVersionMajor = 0;
        constexpr int kVersionMinor = 1;
        constexpr int kVersionPatch = 0;
    } // namespace

    int version_major() noexcept {
        return kVersionMajor;
    }

    int version_minor() noexcept {
        return kVersionMinor;
    }

    int version_patch() noexcept {
        return kVersionPatch;
    }

    std::string version_string() {
        return std::to_string(kVersionMajor) + "." +
               std::to_string(kVersionMinor) + "." +
               std::to_string(kVersionPatch);
    }

} // namespace bonsai::foundation