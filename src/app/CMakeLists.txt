add_executable(bonsai_app
        main.cpp
)

target_link_libraries(bonsai_app
        PRIVATE
        bonsai_platform
        bonsai_runtime
)

target_compile_features(bonsai_app
        PRIVATE
        cxx_std_20
)

bonsai_apply_warnings(bonsai_app)