add_library(bonsai_runtime
        runtime.cpp
)

target_include_directories(bonsai_runtime
        PUBLIC
        ${PROJECT_SOURCE_DIR}/include
)

target_link_libraries(bonsai_runtime
        PUBLIC
        bonsai_foundation
)

target_compile_features(bonsai_runtime
        PUBLIC
        cxx_std_20
)

bonsai_apply_warnings(bonsai_runtime)