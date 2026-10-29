# fortran-sockets

[![CI](https://github.com/pjpbyrne/fortran-sockets/actions/workflows/ci.yml/badge.svg)](https://github.com/pjpbyrne/fortran-sockets/actions/workflows/ci.yml)

This is an attempt to write a reasonable wrapper for a sockets interface in fortran.

## Structure
The sockets interface is generated using fypp for the standard fortran numeric types (real32, real64, int32, int64) and for strings. The template is in src/tcpsockets.fypp. 

For your convenience, the generated code is given in the [preprocessed](preprocessed) folder, along with an example of how to use it. 

## Requirements
- A POSIX system: Linux, macOS or a BSD. Windows is not supported.
- A C11 compiler.
- A Fortran compiler supporting the Fortran 2018 features the module uses, `implicit none (type, external)` and assumed-type `type(*)` arguments. It is tested with gfortran.

## Building
CMake builds the library: the C socket layer (`libf90sockets`) and the Fortran module on top of it. It is static by default; pass `-DBUILD_SHARED_LIBS=ON` for a shared library. [fypp](https://github.com/aradi/fypp) is optional: if it is not installed (or does not run), the module is built from `preprocessed/tcpsockets.f90` instead of the template. To build only the library, without the tests or Python, pass `-DBUILD_TESTING=OFF`.

## Installing and using the library
```
cmake -S . -B build -DBUILD_TESTING=OFF
cmake --build build
cmake --install build --prefix /path/to/prefix
```
This installs the compiled C library and the Fortran module **as source**, not as a compiled `.mod` file:
```
lib/libf90sockets.a                 (or .so / .dylib)
include/f90sockets/tcpsockets.f90
lib/cmake/f90sockets/               CMake package files
lib/pkgconfig/f90sockets.pc
```
`.mod` files only work with the compiler (and version) that wrote them, so the module is compiled by each project that uses it, with that project's own Fortran compiler. One installation therefore works with any Fortran compiler, while the C library underneath has a stable C interface.

**CMake projects** find it with `find_package` (pointing `CMAKE_PREFIX_PATH` at the prefix if it is not a system location). The project must enable Fortran; the module is compiled once and shared by all of its targets:
```cmake
project(myapp LANGUAGES Fortran)
find_package(f90sockets 0.1 REQUIRED)
add_executable(myapp main.f90)
target_link_libraries(myapp PRIVATE f90sockets::f90sockets)
```

**Without installing**, a CMake project can include the source tree directly, with `add_subdirectory()` or FetchContent, and link the same `f90sockets::f90sockets` target. The tests and install rules are skipped in that case (set `F90SOCKETS_INSTALL=ON` to keep the install rules).
```cmake
include(FetchContent)
FetchContent_Declare(f90sockets GIT_REPOSITORY https://github.com/pjpbyrne/fortran-sockets.git GIT_TAG main)
FetchContent_MakeAvailable(f90sockets)
target_link_libraries(myapp PRIVATE f90sockets::f90sockets)
```

**Other build systems** can use pkg-config: compile the installed module source together with your program and link the library, e.g. in a Makefile:
```make
F90SOCKETS_SRC := $(shell pkg-config --variable=fortran_source f90sockets)
myapp: main.f90
	$(FC) $(F90SOCKETS_SRC) main.f90 $(shell pkg-config --libs f90sockets) -o $@
```

## Testing
For testing, this requires python and cmake. The `preprocessed_*_in_sync` tests check that the files in `preprocessed/` match `src/`; after changing the sources, regenerate them with `fypp src/tcpsockets.fypp preprocessed/tcpsockets.f90` and `cp src/sockets.c preprocessed/`. Without fypp, the per-type tests (`unit_int32` to `unit_real64`) and the Fortran sync check are skipped. To compile the test programs and run the full test suite:

```
cmake -B build
cd build
make
make test
```
You should see output similar to:
```
Running tests...
Test project fortran-sockets/build
      Start  1: install_and_consume
 1/21 Test  #1: install_and_consume ..............   Passed    1.43 sec
      Start  2: preprocessed_c_in_sync
 2/21 Test  #2: preprocessed_c_in_sync ...........   Passed    0.00 sec
      Start  3: preprocessed_f90_in_sync
 3/21 Test  #3: preprocessed_f90_in_sync .........   Passed    0.00 sec
      Start  4: unit_int32
 4/21 Test  #4: unit_int32 .......................   Passed    0.53 sec
      Start  5: unit_int64
 5/21 Test  #5: unit_int64 .......................   Passed    0.54 sec
      Start  6: unit_real32
 6/21 Test  #6: unit_real32 ......................   Passed    0.54 sec
      Start  7: unit_real64
 7/21 Test  #7: unit_real64 ......................   Passed    0.54 sec
      Start  8: unit_string
 8/21 Test  #8: unit_string ......................   Passed    0.54 sec
      Start  9: combination
 9/21 Test  #9: combination ......................   Passed    0.80 sec
      Start 10: sockopts
10/21 Test #10: sockopts .........................   Passed    0.05 sec
      Start 11: wire_format
11/21 Test #11: wire_format ......................   Passed    0.53 sec
      Start 12: error_refused
12/21 Test #12: error_refused ....................   Passed    0.10 sec
      Start 13: error_send_to_closed
13/21 Test #13: error_send_to_closed .............   Passed    0.54 sec
      Start 14: error_recv_from_closed
14/21 Test #14: error_recv_from_closed ...........   Passed    0.54 sec
      Start 15: error_negative_n
15/21 Test #15: error_negative_n .................   Passed    0.61 sec
      Start 16: error_buffer_too_small
16/21 Test #16: error_buffer_too_small ...........   Passed    0.60 sec
      Start 17: error_string_too_small
17/21 Test #17: error_string_too_small ...........   Passed    0.60 sec
      Start 18: error_already_open
18/21 Test #18: error_already_open ...............   Passed    0.60 sec
      Start 19: error_close_unopened
19/21 Test #19: error_close_unopened .............   Passed    0.54 sec
      Start 20: error_write_unopened
20/21 Test #20: error_write_unopened .............   Passed    0.55 sec
      Start 21: cloexec
21/21 Test #21: cloexec ..........................   Passed    0.54 sec

100% tests passed, 0 tests failed out of 21

Total Test time (real) =  10.75 sec
```
