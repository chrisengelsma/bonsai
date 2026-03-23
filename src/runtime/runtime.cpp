#include "bonsai/runtime/runtime.h"

#include <stdexcept>
#include <utility>

namespace bonsai::runtime
{
    RuntimeConfig::RuntimeConfig(std::string application_name)
        : application_name_(std::move(application_name))
    {
    }

    const std::string& RuntimeConfig::application_name() const noexcept
    {
        return application_name_;
    }

    Runtime::Runtime(RuntimeConfig config, RuntimeHost& host)
        : config_(std::move(config))
        , host_(host)
    {
    }

    void Runtime::start()
    {
        if (state_ != State::Created)
        {
            throw std::logic_error("Runtime can only be started from the Created state.");
        }

        state_ = State::Running;
        host_.on_runtime_started();
    }

    void Runtime::stop()
    {
        if (state_ != State::Running)
        {
            throw std::logic_error("Runtime can only be stopped from the Running state.");
        }

        state_ = State::Stopped;
        host_.on_runtime_stopped();
    }

    const RuntimeConfig& Runtime::config() const noexcept
    {
        return config_;
    }

    Runtime::State Runtime::state() const noexcept
    {
        return state_;
    }

    bool Runtime::is_running() const noexcept
    {
        return state_ == State::Running;
    }
} // namespace bonsai::runtime