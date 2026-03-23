cmake_minimum_required(VERSION 3.25)

project(bonsai
        VERSION 0.1.0
        DESCRIPTION "Modern C++ game engine project"
        LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

enable_testing()

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
include(Warnings)

add_subdirectory(src)
add_subdirectory(tests)