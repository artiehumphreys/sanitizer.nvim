cmake_minimum_required(VERSION 3.10)

project(hang)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# env-gated variables bc M.build does not forward -D cache vars

if(DEFINED ENV{SLOW_CONFIGURE})
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E sleep 5
        RESULT_VARIABLE config_result
    )

    if(NOT config_result EQUAL 0)
        message(FATAL_ERROR "slow configuration failed.")
    endif()
endif()

add_executable(hang-test main.cpp)

if(DEFINED ENV{SLOW_BUILD})
    add_custom_command(
        TARGET hang-test
        PRE_BUILD
        COMMAND ${CMAKE_COMMAND} -E sleep 5
        COMMENT "executing slow build"
    )
endif()

include(CTest)
enable_testing()
add_test(NAME hang COMMAND hang-test)
