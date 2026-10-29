# Installs the build into a temporary prefix and builds and runs a downstream
# project (test/consumer) against it in three ways: find_package, add_subdirectory
# of the source tree, and plain compilation using pkg-config.
#
# Run with cmake -P, passing -DBUILD_DIR -DSOURCE_DIR -DWORK_DIR -DCONFIG
# -DGENERATOR -DFortran_COMPILER -DC_COMPILER -DFYPP_EXECUTABLE -DLIBDIR
# -DINCLUDEDIR (the last two as CMAKE_INSTALL_LIBDIR/INCLUDEDIR), and the
# library build's -DFortran_FLAGS -DC_FLAGS -DEXE_LINKER_FLAGS, which the
# consumer must share (e.g. sanitizer builds).

function(run)
    execute_process(COMMAND ${ARGN} RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE out)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "Command failed (${result}): ${ARGN}\n${out}")
    endif()
    set(run_output "${out}" PARENT_SCOPE)
endfunction()

function(run_app exe)
    run("${exe}")
    if(NOT run_output MATCHES "f90sockets usable")
        message(FATAL_ERROR "${exe} did not report success:\n${run_output}")
    endif()
endfunction()

set(prefix "${WORK_DIR}/prefix")
file(REMOVE_RECURSE "${WORK_DIR}")

# --config only for multi-config generators / an explicit build type
set(config_args "")
if(CONFIG)
    set(config_args --config "${CONFIG}")
endif()

# 1. Install, and check the layout: C library + Fortran source, no .mod files
run("${CMAKE_COMMAND}" --install "${BUILD_DIR}" --prefix "${prefix}" ${config_args})
foreach(expected
        ${INCLUDEDIR}/f90sockets/tcpsockets.f90
        ${LIBDIR}/cmake/f90sockets/f90socketsConfig.cmake
        ${LIBDIR}/cmake/f90sockets/f90socketsConfigVersion.cmake
        ${LIBDIR}/cmake/f90sockets/f90socketsTargets.cmake
        ${LIBDIR}/pkgconfig/f90sockets.pc)
    if(NOT EXISTS "${prefix}/${expected}")
        message(FATAL_ERROR "Not installed: ${expected}")
    endif()
endforeach()
file(GLOB libraries "${prefix}/${LIBDIR}/*f90sockets*")
if(NOT libraries)
    message(FATAL_ERROR "No f90sockets library installed in ${prefix}/${LIBDIR}")
endif()
file(GLOB_RECURSE modules "${prefix}/*.mod")
if(modules)
    message(FATAL_ERROR "Compiler-specific .mod files were installed: ${modules}")
endif()
message(STATUS "Install layout OK")

set(compilers "-DCMAKE_Fortran_COMPILER=${Fortran_COMPILER}" "-DCMAKE_C_COMPILER=${C_COMPILER}"
    "-DCMAKE_Fortran_FLAGS=${Fortran_FLAGS}" "-DCMAKE_C_FLAGS=${C_FLAGS}"
    "-DCMAKE_EXE_LINKER_FLAGS=${EXE_LINKER_FLAGS}")

# 2. A downstream project using find_package
set(build "${WORK_DIR}/package")
run("${CMAKE_COMMAND}" -S "${SOURCE_DIR}/test/consumer" -B "${build}" -G "${GENERATOR}"
    ${compilers} "-DCMAKE_PREFIX_PATH=${prefix}" -DF90SOCKETS_CONSUMER_MODE=package)
run("${CMAKE_COMMAND}" --build "${build}" ${config_args})
foreach(app app app2)
    file(GLOB_RECURSE exe "${build}/${app}" "${build}/${app}.exe" "${build}/*/${app}")
    list(GET exe 0 exe)
    run_app("${exe}")
endforeach()
message(STATUS "find_package consumer OK")

# 3. A downstream project using add_subdirectory on the source tree
set(build "${WORK_DIR}/subdirectory")
run("${CMAKE_COMMAND}" -S "${SOURCE_DIR}/test/consumer" -B "${build}" -G "${GENERATOR}"
    ${compilers} "-DFYPP_EXECUTABLE=${FYPP_EXECUTABLE}"
    -DF90SOCKETS_CONSUMER_MODE=subdirectory "-DF90SOCKETS_SOURCE_DIR=${SOURCE_DIR}")
run("${CMAKE_COMMAND}" --build "${build}" ${config_args})
file(GLOB_RECURSE exe "${build}/app" "${build}/app.exe" "${build}/*/app")
list(GET exe 0 exe)
run_app("${exe}")
message(STATUS "add_subdirectory consumer OK")

# 4. A plain compile using pkg-config, as a Makefile would
find_program(PKG_CONFIG pkg-config)
if(PKG_CONFIG)
    set(ENV{PKG_CONFIG_PATH} "${prefix}/${LIBDIR}/pkgconfig")
    # A shared libf90sockets must be findable when the program runs
    set(ENV{LD_LIBRARY_PATH} "${prefix}/${LIBDIR}:$ENV{LD_LIBRARY_PATH}")
    set(ENV{DYLD_LIBRARY_PATH} "${prefix}/${LIBDIR}:$ENV{DYLD_LIBRARY_PATH}")
    run("${PKG_CONFIG}" --variable=fortran_source f90sockets)
    string(STRIP "${run_output}" source)
    run("${PKG_CONFIG}" --libs f90sockets)
    string(STRIP "${run_output}" libs)
    separate_arguments(libs UNIX_COMMAND "${libs}")
    separate_arguments(flags UNIX_COMMAND "${Fortran_FLAGS} ${EXE_LINKER_FLAGS}")
    set(build "${WORK_DIR}/pkgconfig")
    file(MAKE_DIRECTORY "${build}")
    execute_process(
        COMMAND "${Fortran_COMPILER}" ${flags} "${source}" "${SOURCE_DIR}/test/consumer/app.f90" ${libs} -o app
        WORKING_DIRECTORY "${build}" RESULT_VARIABLE result OUTPUT_VARIABLE out ERROR_VARIABLE out)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "pkg-config compile failed:\n${out}")
    endif()
    run_app("${build}/app")
    message(STATUS "pkg-config consumer OK")
else()
    message(STATUS "pkg-config not found: skipping the pkg-config consumer")
endif()
