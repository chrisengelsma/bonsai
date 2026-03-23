include(FetchContent)

FetchContent_Declare(
        Catch2
        GIT_REPOSITORY https://github.com/catchorg/Catch2.git
        GIT_TAG v3.5.4
)

FetchContent_MakeAvailable(Catch2)

list(APPEND CMAKE_MODULE_PATH ${catch2_SOURCE_DIR}/extras)

add_executable(bonsai_foundation_tests
        foundation/version_tests.cpp
)

target_link_libraries(bonsai_foundation_tests
        PRIVATE
        bonsai_foundation
        Catch2::Catch2WithMain
)

bonsai_apply_warnings(bonsai_foundation_tests)

add_executable(bonsai_foundation_smoke
        smoke/foundation_smoke.cpp
)

target_link_libraries(bonsai_foundation_smoke
        PRIVATE
        bonsai_foundation
)

bonsai_apply_warnings(bonsai_foundation_smoke)

include(CTest)
include(Catch)

catch_discover_tests(bonsai_foundation_tests)

add_test(
        NAME bonsai_foundation_smoke
        COMMAND bonsai_foundation_smoke
)