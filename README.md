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
CMake builds the `f90sockets` static library. [fypp](https://github.com/aradi/fypp) is optional: if it is not installed (or does not run), the library is built from `preprocessed/tcpsockets.f90` instead of the template. To build only the library, without the tests or Python, pass `-DBUILD_TESTING=OFF`.

The project can also be pulled into another CMake build with `add_subdirectory()` and linked against `f90sockets`; its tests are not registered in that case.

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
      Start  1: preprocessed_c_in_sync
 1/20 Test  #1: preprocessed_c_in_sync ...........   Passed    0.01 sec
      Start  2: preprocessed_f90_in_sync
 2/20 Test  #2: preprocessed_f90_in_sync .........   Passed    0.01 sec
      Start  3: unit_int32
 3/20 Test  #3: unit_int32 .......................   Passed    0.54 sec
      Start  4: unit_int64
 4/20 Test  #4: unit_int64 .......................   Passed    0.54 sec
      Start  5: unit_real32
 5/20 Test  #5: unit_real32 ......................   Passed    0.54 sec
      Start  6: unit_real64
 6/20 Test  #6: unit_real64 ......................   Passed    0.54 sec
      Start  7: unit_string
 7/20 Test  #7: unit_string ......................   Passed    0.54 sec
      Start  8: combination
 8/20 Test  #8: combination ......................   Passed    0.68 sec
      Start  9: sockopts
 9/20 Test  #9: sockopts .........................   Passed    0.03 sec
      Start 10: wire_format
10/20 Test #10: wire_format ......................   Passed    0.54 sec
      Start 11: error_refused
11/20 Test #11: error_refused ....................   Passed    0.09 sec
      Start 12: error_send_to_closed
12/20 Test #12: error_send_to_closed .............   Passed    0.53 sec
      Start 13: error_recv_from_closed
13/20 Test #13: error_recv_from_closed ...........   Passed    0.55 sec
      Start 14: error_negative_n
14/20 Test #14: error_negative_n .................   Passed    0.60 sec
      Start 15: error_buffer_too_small
15/20 Test #15: error_buffer_too_small ...........   Passed    0.60 sec
      Start 16: error_string_too_small
16/20 Test #16: error_string_too_small ...........   Passed    0.61 sec
      Start 17: error_already_open
17/20 Test #17: error_already_open ...............   Passed    0.60 sec
      Start 18: error_close_unopened
18/20 Test #18: error_close_unopened .............   Passed    0.54 sec
      Start 19: error_write_unopened
19/20 Test #19: error_write_unopened .............   Passed    0.54 sec
      Start 20: cloexec
20/20 Test #20: cloexec ..........................   Passed    0.54 sec

100% tests passed, 0 tests failed out of 20

Total Test time (real) =   9.16 sec
```
