# A minimal downstream project, built by test/install_consumer.cmake against
# an installed f90sockets (find_package) or the source tree (add_subdirectory).
cmake_minimum_required(VERSION 3.18)
project(f90sockets_consumer LANGUAGES Fortran)

set(F90SOCKETS_CONSUMER_MODE "package" CACHE STRING "package or subdirectory")
if(F90SOCKETS_CONSUMER_MODE STREQUAL "package")
    find_package(f90sockets 0.1 REQUIRED)
else()
    add_subdirectory("${F90SOCKETS_SOURCE_DIR}" f90sockets)
endif()

# Two executables share the one compiled copy of the module
add_executable(app app.f90)
target_link_libraries(app PRIVATE f90sockets::f90sockets)
add_executable(app2 app2.f90)
target_link_libraries(app2 PRIVATE f90sockets::f90sockets)
