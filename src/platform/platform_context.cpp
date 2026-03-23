#include "bonsai/platform/platform_context.h"

#include <utility>

namespace bonsai::platform
{
    PlatformContext::PlatformContext(std::string host_name)
        : host_name_(std::move(host_name))
    {
    }

    const std::string& PlatformContext::host_name() const noexcept
    {
        return host_name_;
    }
} // namespace bonsai::platform