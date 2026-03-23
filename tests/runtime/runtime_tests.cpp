#include "bonsai/runtime/runtime.h"
#include "bonsai/runtime/runtime_config.h"
#include "bonsai/runtime/runtime_host.h"

#include <catch2/catch_test_macros.hpp>

namespace
{
    class TestHost final : public bonsai::runtime::RuntimeHost
    {
    public:
        void on_runtime_started() override
        {
            started = true;
        }

        void on_runtime_stopped() override
        {
            stopped = true;
        }

        bool started{false};
        bool stopped{false};
    };
} // namespace

TEST_CASE("runtime transitions through created running and stopped states")
{
    TestHost host{};

    bonsai::runtime::Runtime runtime{
        bonsai::runtime::RuntimeConfig{"bonsai-test"},
        host
    };

    REQUIRE(runtime.state() == bonsai::runtime::Runtime::State::Created);
    REQUIRE_FALSE(runtime.is_running());

    runtime.start();

    REQUIRE(runtime.state() == bonsai::runtime::Runtime::State::Running);
    REQUIRE(runtime.is_running());
    REQUIRE(host.started);
    REQUIRE_FALSE(host.stopped);

    runtime.stop();

    REQUIRE(runtime.state() == bonsai::runtime::Runtime::State::Stopped);
    REQUIRE_FALSE(runtime.is_running());
    REQUIRE(host.stopped);
}