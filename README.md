# fortran-sockets

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
      Start 10: wire_format
10/10 Test #10: wire_format ......................   Passed    0.53 sec

100% tests passed, 0 tests failed out of 10

Total Test time (real) =   4.11 sec
```
