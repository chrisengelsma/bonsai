add_library(bonsai_foundation STATIC
        version.cpp
)

target_include_directories(bonsai_foundation
        PUBLIC
        ${PROJECT_SOURCE_DIR}/include
)

target_compile_features(bonsai_foundation
        PUBLIC
        cxx_std_20
)

bonsai_apply_warnings(bonsai_foundation)