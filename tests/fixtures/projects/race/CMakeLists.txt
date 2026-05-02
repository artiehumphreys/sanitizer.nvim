cmake_minimum_required(VERSION 3.10)

project(race-test VERSION 0.0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(race-test main.cpp src/worker.cpp)

target_compile_options(race-test PRIVATE -fsanitize=thread -g -O1)
target_link_options(race-test PRIVATE -fsanitize=thread)

include(CTest)
enable_testing()
add_test(NAME race COMMAND race-test)
