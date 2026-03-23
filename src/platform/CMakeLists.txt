add_library(bonsai_platform
        platform_context.cpp
)

target_include_directories(bonsai_platform
        PUBLIC
        ${PROJECT_SOURCE_DIR}/include
)

target_link_libraries(bonsai_platform
        PUBLIC
        bonsai_foundation
)

target_compile_features(bonsai_platform
        PUBLIC
        cxx_std_20
)

bonsai_apply_warnings(bonsai_platform)