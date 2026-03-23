#include "bonsai/platform/platform_context.h"
#include "bonsai/runtime/runtime.h"
#include "bonsai/runtime/runtime_config.h"
#include "bonsai/runtime/runtime_host.h"

#include <iostream>

namespace
{
    class AppHost final : public bonsai::runtime::RuntimeHost
    {
    public:
        explicit AppHost(bonsai::platform::PlatformContext& platform_context)
            : platform_context_(platform_context)
        {
        }

        void on_runtime_started() override
        {
            std::cout << "bonsai runtime started on host: "
                      << platform_context_.host_name()
                      << '\n';
        }

        void on_runtime_stopped() override
        {
            std::cout << "bonsai runtime stopped\n";
        }

    private:
        bonsai::platform::PlatformContext& platform_context_;
    };
} // namespace

int main()
{
    bonsai::platform::PlatformContext platform_context{"desktop"};
    AppHost host{platform_context};

    bonsai::runtime::Runtime runtime{
        bonsai::runtime::RuntimeConfig{"bonsai"},
        host
    };

    runtime.start();
    runtime.stop();

    return 0;
}