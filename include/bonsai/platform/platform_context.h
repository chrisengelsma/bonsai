#pragma once

#include <string>

namespace bonsai::platform
{
    class PlatformContext
    {
    public:
        explicit PlatformContext(std::string host_name);

        [[nodiscard]] const std::string& host_name() const noexcept;

    private:
        std::string host_name_;
    };
} // namespace bonsai::platform