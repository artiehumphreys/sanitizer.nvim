cmake_minimum_required(VERSION 3.10)

project(ub-test VERSION 0.0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(ub-test main.cpp)

target_compile_options(ub-test PRIVATE -fsanitize=undefined -g -O1)
target_link_options(ub-test PRIVATE -fsanitize=undefined)

include(CTest)
enable_testing()
add_test(NAME ub COMMAND ub-test)

