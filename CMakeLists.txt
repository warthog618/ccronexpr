cmake_minimum_required(VERSION 3.0)
project(ccronexpr)

# Strict compilation
if (MSVC)
    add_compile_options(/W4 /WX)
else()
    # TODO fix for -Wconversion
    add_compile_options(-std=c99 -Wall -Wextra -Werror -Wshadow -Wpointer-arith -Wcast-qual -pedantic-errors)
endif()

# Library
add_library(ccronexpr STATIC ccronexpr.c)
target_compile_features(ccronexpr PRIVATE c_std_99)
target_include_directories(ccronexpr PUBLIC .)

# Tests
enable_testing()
add_subdirectory(test)
