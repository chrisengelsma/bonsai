#pragma once

#include "bonsai/runtime/runtime_config.h"
#include "bonsai/runtime/runtime_host.h"

namespace bonsai::runtime
{
    class Runtime
    {
    public:
        enum class State
        {
            Created,
            Running,
            Stopped
        };

        Runtime(RuntimeConfig config, RuntimeHost& host);

        Runtime(const Runtime&) = delete;
        Runtime& operator=(const Runtime&) = delete;

        void start();
        void stop();

        [[nodiscard]] const RuntimeConfig& config() const noexcept;
        [[nodiscard]] State state() const noexcept;
        [[nodiscard]] bool is_running() const noexcept;

    private:
        RuntimeConfig config_;
        RuntimeHost& host_;
        State state_{State::Created};
    };
} // namespace bonsai::runtime