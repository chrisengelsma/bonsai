#pragma once

#include <string>

namespace bonsai::runtime
{
    class RuntimeConfig
    {
    public:
        explicit RuntimeConfig(std::string application_name);

        [[nodiscard]] const std::string& application_name() const noexcept;

    private:
        std::string application_name_;
    };
} // namespace bonsai::runtime