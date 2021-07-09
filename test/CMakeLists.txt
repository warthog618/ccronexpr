cmake_minimum_required(VERSION 3.0)

project(ccronexpr_test)

# Test executable
add_executable(ccronexpr_test ../ccronexpr_test.c)
target_compile_features(ccronexpr_test PRIVATE c_std_99)
target_include_directories(ccronexpr_test PRIVATE .)
target_link_libraries(ccronexpr_test ccronexpr)

# Add tests
add_test(NAME ccronexpr_test COMMAND ccronexpr_test)
