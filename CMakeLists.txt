cmake_minimum_required(VERSION 3.28)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

project(bonsai
        VERSION 0.1.0
        LANGUAGES CXX
)

include(cmake/Warnings.cmake)

add_subdirectory(src/foundation)
add_subdirectory(src/platform)
add_subdirectory(src/runtime)
add_subdirectory(src/app)
add_subdirectory(tests)