cmake_minimum_required(VERSION 3.5)
project(ccronexpr LANGUAGES C)

option(CRON_DISABLE_TESTING "Disable building tests" OFF)
option(CRON_BUILD_SUPERTINYCRON "Build supertinycron executable (POSIX only)" OFF)
option(CRON_SUPERTINYCRON_STATIC "Link supertinycron statically (-static)" OFF)

# Library
add_library(ccronexpr STATIC ccronexpr.c)
target_include_directories(ccronexpr PUBLIC .)

if (ESP_PLATFORM)
    target_compile_definitions(ccronexpr PRIVATE ESP_PLATFORM=1)
    set(CRON_DISABLE_TESTING ON) # disable tests automatically
endif ()

if (CRON_USE_LOCAL_TIME)
    target_compile_definitions(ccronexpr PUBLIC CRON_USE_LOCAL_TIME=1)
endif ()

if (CRON_COMPILE_AS_CXX)
    target_compile_definitions(ccronexpr PUBLIC CRON_COMPILE_AS_CXX=1)
endif ()

if (MSVC)
    # Strict compilation
    target_compile_options(ccronexpr PRIVATE /W4 /WX)
    # But ignore _s functions
    target_compile_definitions(ccronexpr PRIVATE _CRT_SECURE_NO_WARNINGS)
else ()
    # Strict compilation
    target_compile_options(ccronexpr PRIVATE -ansi -Wall -Wextra -Werror -Wshadow -Wpointer-arith -Wcast-qual -Wconversion -Wno-unused-parameter -pedantic-errors)
endif ()

# Supertinycron binary (optional, POSIX-only)
if (CRON_BUILD_SUPERTINYCRON)
    if (WIN32)
        message(WARNING "CRON_BUILD_SUPERTINYCRON is ON, but supertinycron uses POSIX APIs and is skipped on WIN32.")
        if (CRON_SUPERTINYCRON_STATIC)
            message(WARNING "CRON_SUPERTINYCRON_STATIC is ignored on WIN32.")
        endif ()
    else ()
        add_executable(supertinycron supertinycron.c)
        target_include_directories(supertinycron PRIVATE .)
        target_link_libraries(supertinycron PRIVATE ccronexpr)
        if (CRON_SUPERTINYCRON_STATIC)
            set_property(TARGET supertinycron APPEND_STRING PROPERTY LINK_FLAGS " -static")
        endif ()
        if (MSVC)
            target_compile_definitions(supertinycron PRIVATE _CRT_SECURE_NO_WARNINGS)
        else ()
            target_compile_options(supertinycron PRIVATE -ansi -Wall -Wextra -Wshadow -Wpointer-arith -Wcast-qual -Wconversion -Wno-unused-parameter -pedantic-errors)
        endif ()
    endif ()
endif ()

# Tests
if (NOT CRON_DISABLE_TESTING)
    enable_testing()
    add_subdirectory(test)
endif ()
