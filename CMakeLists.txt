cmake_minimum_required(VERSION 3.0)
project(ccronexpr)

# Strict compilation
if (MSVC)
    add_compile_options(/W4 /WX)
else()
    add_compile_options(-std=c99 -Wall -Wextra -Werror -Wshadow -Wpointer-arith -Wcast-qual -Wconversion -pedantic-errors)
endif()

# Library
add_library(ccronexpr STATIC ccronexpr.c)
target_compile_features(ccronexpr PRIVATE c_std_99)
target_include_directories(ccronexpr PUBLIC .)

if(CRON_USE_LOCAL_TIME)
    target_compile_definitions(ccronexpr PUBLIC CRON_USE_LOCAL_TIME=${CRON_USE_LOCAL_TIME})
endif()

if(MSVC)
    target_compile_definitions(ccronexpr PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

# Tests
enable_testing()
add_subdirectory(test)
