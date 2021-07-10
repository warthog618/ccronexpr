cmake_minimum_required(VERSION 3.0)
project(ccronexpr)


# Library
add_library(ccronexpr STATIC ccronexpr.c)
target_include_directories(ccronexpr PUBLIC .)

if (CRON_USE_LOCAL_TIME)
    target_compile_definitions(ccronexpr PUBLIC CRON_USE_LOCAL_TIME=${CRON_USE_LOCAL_TIME})
endif ()

if (MSVC)
    # Strict compilation
    target_compile_options(ccronexpr PRIVATE /W4 /WX)
    # But ignore _s functions
    target_compile_definitions(ccronexpr PRIVATE _CRT_SECURE_NO_WARNINGS)
else()
    # Strict compilation
    target_compile_options(ccronexpr PRIVATE -std=c99 -Wall -Wextra -Werror -Wshadow -Wpointer-arith -Wcast-qual -Wconversion -pedantic-errors)
endif ()

# Tests
enable_testing()
add_subdirectory(test)
