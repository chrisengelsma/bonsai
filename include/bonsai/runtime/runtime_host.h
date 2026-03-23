#pragma once

namespace bonsai::runtime
{
    class RuntimeHost
    {
    public:
        virtual ~RuntimeHost() = default;

        virtual void on_runtime_started() = 0;
        virtual void on_runtime_stopped() = 0;
    };
} // namespace bonsai::runtime