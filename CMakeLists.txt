cmake_minimum_required(VERSION 3.18)
project(f90sockets VERSION 0.1.0 LANGUAGES C Fortran)

include(GNUInstallDirs)

# Only register tests when this is the top-level project, not when it is
# pulled into another build with add_subdirectory()
if(CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)
    include(CTest)
endif()

# Locate the fypp preprocessor executable; check that it actually runs, since
# a broken install (script present, Python module missing) is easy to end up with
find_program(FYPP_EXECUTABLE fypp)
if(FYPP_EXECUTABLE)
    execute_process(
        COMMAND "${FYPP_EXECUTABLE}" --version
        RESULT_VARIABLE FYPP_RESULT
        OUTPUT_QUIET ERROR_QUIET
    )
    if(NOT FYPP_RESULT EQUAL 0)
        message(WARNING "fypp found at ${FYPP_EXECUTABLE} but it does not run; ignoring it")
        set(FYPP_EXECUTABLE "")
    endif()
endif()

# ------------------------------------------------------------------------------
# Fypp Preprocessing: generate tcpsockets.f90 from src/tcpsockets.fypp, or fall
# back to the checked-in copy in preprocessed/ when fypp is unavailable
# ------------------------------------------------------------------------------
if(FYPP_EXECUTABLE)
    set(FYPP_INPUT "${CMAKE_CURRENT_SOURCE_DIR}/src/tcpsockets.fypp")
    set(TCPSOCKETS_SRC "${CMAKE_CURRENT_BINARY_DIR}/tcpsockets.f90")

    add_custom_command(
        OUTPUT "${TCPSOCKETS_SRC}"
        COMMAND ${FYPP_EXECUTABLE} "${FYPP_INPUT}" "${TCPSOCKETS_SRC}"
        DEPENDS "${FYPP_INPUT}"
        COMMENT "Preprocessing ${FYPP_INPUT} with Fypp"
        VERBATIM
    )
else()
    message(STATUS "fypp not available: using preprocessed/tcpsockets.f90")
    set(TCPSOCKETS_SRC "${CMAKE_CURRENT_SOURCE_DIR}/preprocessed/tcpsockets.f90")
endif()

# ------------------------------------------------------------------------------
# Targets
#   f90sockets_c  the C socket layer (libf90sockets): the only compiled part that
#                 is installed, since its C ABI works with any Fortran compiler
#   f90sockets    the Fortran module on top of it, for in-tree use (tests,
#                 add_subdirectory/FetchContent). Installed projects compile the
#                 module source themselves instead; see f90socketsConfig.cmake.in.
# Static by default; -DBUILD_SHARED_LIBS=ON builds shared libraries.
# ------------------------------------------------------------------------------
add_library(f90sockets_c src/sockets.c)
set_target_properties(f90sockets_c PROPERTIES
    OUTPUT_NAME f90sockets
    POSITION_INDEPENDENT_CODE ON
    C_STANDARD 11
    C_STANDARD_REQUIRED ON
    C_EXTENSIONS OFF
)

add_library(f90sockets "${TCPSOCKETS_SRC}")
add_library(f90sockets::f90sockets ALIAS f90sockets)
set_target_properties(f90sockets PROPERTIES
    OUTPUT_NAME f90sockets_fortran
    POSITION_INDEPENDENT_CODE ON
    Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules"
)
target_include_directories(f90sockets PUBLIC
    "${CMAKE_CURRENT_BINARY_DIR}/modules"
)
target_link_libraries(f90sockets PUBLIC f90sockets_c)

# ------------------------------------------------------------------------------
# Install: the C library, the generated Fortran source (compiled by each
# consuming project with its own compiler, so no compiler-specific .mod files
# are installed) and a CMake package config. Off by default when this project
# is pulled into another build with add_subdirectory()/FetchContent.
# ------------------------------------------------------------------------------
if(CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)
    set(F90SOCKETS_INSTALL_DEFAULT ON)
else()
    set(F90SOCKETS_INSTALL_DEFAULT OFF)
endif()
option(F90SOCKETS_INSTALL "Generate install rules for f90sockets" ${F90SOCKETS_INSTALL_DEFAULT})

if(F90SOCKETS_INSTALL)
    include(CMakePackageConfigHelpers)
    set(F90SOCKETS_CMAKE_DIR "${CMAKE_INSTALL_LIBDIR}/cmake/f90sockets")
    set(F90SOCKETS_SOURCE_DIR "${CMAKE_INSTALL_INCLUDEDIR}/f90sockets")

    install(TARGETS f90sockets_c
        EXPORT f90socketsTargets
        ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
    )
    install(FILES "${TCPSOCKETS_SRC}" DESTINATION "${F90SOCKETS_SOURCE_DIR}")
    install(EXPORT f90socketsTargets
        NAMESPACE f90sockets::
        DESTINATION "${F90SOCKETS_CMAKE_DIR}"
    )
    # Exported as f90sockets::c rather than f90sockets::f90sockets_c
    set_target_properties(f90sockets_c PROPERTIES EXPORT_NAME c)

    configure_package_config_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/f90socketsConfig.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/f90socketsConfig.cmake"
        INSTALL_DESTINATION "${F90SOCKETS_CMAKE_DIR}"
        PATH_VARS F90SOCKETS_SOURCE_DIR
    )
    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/f90socketsConfigVersion.cmake"
        COMPATIBILITY SameMinorVersion
    )
    install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/f90socketsConfig.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/f90socketsConfigVersion.cmake"
        DESTINATION "${F90SOCKETS_CMAKE_DIR}"
    )
endif()

# ------------------------------------------------------------------------------
# CTest Integration (enables 'ctest' or 'cmake --build build --target test')
# Skipped with -DBUILD_TESTING=OFF or when built as a subproject.
# ------------------------------------------------------------------------------
if(NOT (BUILD_TESTING AND CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR))
    return()
endif()

find_package(Python3 COMPONENTS Interpreter REQUIRED)

# preprocessed/ is what non-CMake users copy; make sure it matches src/
add_test(NAME preprocessed_c_in_sync
    COMMAND ${CMAKE_COMMAND} -E compare_files
            "${CMAKE_CURRENT_SOURCE_DIR}/src/sockets.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/preprocessed/sockets.c"
)
if(FYPP_EXECUTABLE)
    add_test(NAME preprocessed_f90_in_sync
        COMMAND ${CMAKE_COMMAND} -E compare_files
                "${TCPSOCKETS_SRC}"   # fypp output generated by the build
                "${CMAKE_CURRENT_SOURCE_DIR}/preprocessed/tcpsockets.f90"
    )
endif()

# The per-type tests are generated from a fypp template, so need fypp
if(FYPP_EXECUTABLE)
    # Use '|' as delimiter to avoid conflicting with CMake's list separator
    set(TEST_TYPE_CONFIGS
        "int32|integer|int32|42_int32|10_int32|-5_int32"
        "int64|integer|int64|9876543210_int64|100_int64|-50_int64"
        "real32|real|real32|3.1415927_real32|1.234_real32|-9.99_real32"
        "real64|real|real64|2.718281828459045_real64|10.5_real64|-5.5_real64"
    )

    set(TEMPLATE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/test/cmake/test_type_template.fypp")

    foreach(entry IN LISTS TEST_TYPE_CONFIGS)
        # Split by '|' into a proper CMake list
        string(REPLACE "|" ";" config "${entry}")

        list(GET config 0 T_NAME)
        list(GET config 1 T_KW)
        list(GET config 2 T_KIND)
        list(GET config 3 T_SCALAR)
        list(GET config 4 T_COPIED)
        list(GET config 5 T_NOT_COPIED)

        set(GENERATED_SRC "${CMAKE_CURRENT_BINARY_DIR}/test_${T_NAME}.f90")
        set(TEST_TARGET "test_${T_NAME}")

        add_custom_command(
            OUTPUT "${GENERATED_SRC}"
            COMMAND ${FYPP_EXECUTABLE}
                -DNAME="${T_NAME}"
                -DTYPE_KW="${T_KW}"
                -DKIND_VAL="${T_KIND}"
                -DVAL_SCALAR="${T_SCALAR}"
                -DVAL_COPIED="${T_COPIED}"
                -DVAL_NOT_COPIED="${T_NOT_COPIED}"
                "${TEMPLATE_FILE}"
                "${GENERATED_SRC}"
            DEPENDS "${TEMPLATE_FILE}"
            COMMENT "Generating ${T_NAME} test from template"
            VERBATIM
        )

        add_executable(${TEST_TARGET}
            "${GENERATED_SRC}"
            "${CMAKE_CURRENT_SOURCE_DIR}/test/arg_get_port.f90"
        )
        target_link_libraries(${TEST_TARGET} PRIVATE f90sockets)

        add_test(
            NAME "unit_${T_NAME}"
            COMMAND "${Python3_EXECUTABLE}"
                    "${CMAKE_CURRENT_SOURCE_DIR}/test/run_test.py"
                    "$<TARGET_FILE:${TEST_TARGET}>"
        )
    endforeach()
else()
    message(STATUS "fypp not available: skipping the per-type unit tests")
endif()

add_executable(test_string
    "${CMAKE_CURRENT_SOURCE_DIR}/test/cmake/test_string.f90"
    "${CMAKE_CURRENT_SOURCE_DIR}/test/arg_get_port.f90"
)
target_link_libraries(test_string PRIVATE f90sockets)

add_test(
    NAME "unit_string"
    COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_CURRENT_SOURCE_DIR}/test/run_test.py"
            "$<TARGET_FILE:test_string>"
)

add_executable(test_full
    "${CMAKE_CURRENT_SOURCE_DIR}/test/test_full.f90"
    "${CMAKE_CURRENT_SOURCE_DIR}/test/arg_get_port.f90"
)
target_link_libraries(test_full PRIVATE f90sockets)

add_test(
    NAME "combination"
    COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_CURRENT_SOURCE_DIR}/test/run_test.py"
            "$<TARGET_FILE:test_full>"
)

# Checks that connections really get TCP_NODELAY, keepalive and close-on-exec
add_executable(test_sockopts
    "${CMAKE_CURRENT_SOURCE_DIR}/test/test_sockopts.f90"
    "${CMAKE_CURRENT_SOURCE_DIR}/test/sockopt_check.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/test/arg_get_port.f90"
)
target_link_libraries(test_sockopts PRIVATE f90sockets)

add_test(
    NAME "sockopts"
    COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_CURRENT_SOURCE_DIR}/test/run_test.py"
            "$<TARGET_FILE:test_sockopts>"
)

# Checks the exact bytes on the wire against what the --wire server expects
add_executable(test_wire
    "${CMAKE_CURRENT_SOURCE_DIR}/test/test_wire.f90"
    "${CMAKE_CURRENT_SOURCE_DIR}/test/arg_get_port.f90"
)
target_link_libraries(test_wire PRIVATE f90sockets)

add_test(
    NAME "wire_format"
    COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_CURRENT_SOURCE_DIR}/test/run_test.py"
            --wire
            "$<TARGET_FILE:test_wire>"
)

# Failure paths: each scenario must stop with the given library error message
add_executable(test_errors
    "${CMAKE_CURRENT_SOURCE_DIR}/test/test_errors.f90"
    "${CMAKE_CURRENT_SOURCE_DIR}/test/arg_get_port.f90"
)
target_link_libraries(test_errors PRIVATE f90sockets)

# scenario | run_test.py server mode ("-" = echo) | expected message
set(ERROR_SCENARIOS
    "refused|--no-listen|open_socket: Failed to open tcp connection"
    "send_to_closed|--close|writebuffer_real64_array: Failed sending"
    "recv_from_closed|--close|readbuffer_real64_array: Failed receiving"
    "negative_n|-|writebuffer_real64_array: Negative sized transfer"
    "buffer_too_small|-|readbuffer_real64_array: Buffer too small"
    "string_too_small|-|writebuffer_string: Buffer too small"
    "already_open|-|open_socket: Socket already open"
    "close_unopened|-|close_socket: Tried to close tcp socket that was not open"
    "write_unopened|-|writebuffer_real64_array: Socket not open"
)
foreach(entry IN LISTS ERROR_SCENARIOS)
    string(REPLACE "|" ";" fields "${entry}")
    list(GET fields 0 scenario)
    list(GET fields 1 mode)
    list(GET fields 2 message)
    if(mode STREQUAL "-")
        set(mode "")
    endif()
    add_test(
        NAME "error_${scenario}"
        COMMAND "${Python3_EXECUTABLE}"
                "${CMAKE_CURRENT_SOURCE_DIR}/test/run_test.py"
                ${mode}
                "$<TARGET_FILE:test_errors>"
                "${scenario}"
    )
    set_tests_properties("error_${scenario}" PROPERTIES PASS_REGULAR_EXPRESSION "${message}")
endforeach()

# Close-on-exec: a child process must not keep the connection open
add_executable(test_cloexec
    "${CMAKE_CURRENT_SOURCE_DIR}/test/test_cloexec.f90"
    "${CMAKE_CURRENT_SOURCE_DIR}/test/arg_get_port.f90"
)
target_link_libraries(test_cloexec PRIVATE f90sockets)

add_test(
    NAME "cloexec"
    COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_CURRENT_SOURCE_DIR}/test/run_test.py"
            --eof-check
            "$<TARGET_FILE:test_cloexec>"
)
