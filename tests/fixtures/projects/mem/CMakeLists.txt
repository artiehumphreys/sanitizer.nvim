cmake_minimum_required(VERSION 3.10)

project(mem-test VERSION 0.0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(mem-test main.cpp)

include(CTest)
enable_testing()
add_test(NAME mem COMMAND mem-test)
