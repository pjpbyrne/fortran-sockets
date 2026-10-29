# fortran-sockets

This is an attempt to write a reasonable wrapper for a sockets interface in fortran.

## Structure
The sockets interface is generated using fypp for the standard fortran numeric types (real32, real64, int32, int64) and for strings. The template is in src/tcpsockets.fypp. 

For your convenience, the generated code is given in the [preprocessed](preprocessed) folder, along with an example of how to use it. 

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
    Start 1: preprocessed_c_in_sync
1/8 Test #1: preprocessed_c_in_sync ...........   Passed    0.00 sec
    Start 2: preprocessed_f90_in_sync
2/8 Test #2: preprocessed_f90_in_sync .........   Passed    0.00 sec
    Start 3: unit_int32
3/8 Test #3: unit_int32 .......................   Passed    0.53 sec
    Start 4: unit_int64
4/8 Test #4: unit_int64 .......................   Passed    0.54 sec
    Start 5: unit_real32
5/8 Test #5: unit_real32 ......................   Passed    0.54 sec
    Start 6: unit_real64
6/8 Test #6: unit_real64 ......................   Passed    0.54 sec
    Start 7: unit_string
7/8 Test #7: unit_string ......................   Passed    0.54 sec
    Start 8: combination
8/8 Test #8: combination ......................   Passed    0.53 sec

100% tests passed, 0 tests failed out of 8

Total Test time (real) =   3.22 sec
```
