cmake_minimum_required(VERSION 3.15)
project(trinity-pipe LANGUAGES CXX)

# Force C++17 Standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Create executable
add_executable(trinity-pipe src/main.cpp)

# Cross-platform compiler flags for AVX2 execution vector
if(MSVC)
    target_compile_options(trinity-pipe PRIVATE /arch:AVX2 /W4)
else()
    target_compile_options(trinity-pipe PRIVATE -mavx2 -O3 -Wall -Wextra)
endif()

# Dynamic runtime test asset injection (Optional for clean repository)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/test.bin")
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/test.bin"
        "${CMAKE_CURRENT_BINARY_DIR}/test.bin"
        COPYONLY
    )
endif()

