# fortran-sockets

This is an attempt to write a reasonable wrapper for a sockets interface in fortran.

## Structure
The sockets interface is generated using fypp for the standard fortran numeric types (real32, real64, int32, int64) and for strings. The template is in src/tcpsockets.fypp. 

For your convenience, the generated code is given in the [preprocessed](preprocessed) folder. 

## Testing
For testing, this requires python and cmake. To compile the test programs and run the full test suite:

```
cmake -B build
cd build
make
make test
```
You should see output similar to:
```
Running tests...
Test project /home/byo/test-sockets/build
    Start 1: unit_int32
1/6 Test #1: unit_int32 .......................   Passed    0.52 sec
    Start 2: unit_int64
2/6 Test #2: unit_int64 .......................   Passed    0.52 sec
    Start 3: unit_real32
3/6 Test #3: unit_real32 ......................   Passed    0.52 sec
    Start 4: unit_real64
4/6 Test #4: unit_real64 ......................   Passed    0.52 sec
    Start 5: unit_string
5/6 Test #5: unit_string ......................   Passed    0.52 sec
    Start 6: combination
6/6 Test #6: combination ......................   Passed    0.52 sec

100% tests passed, 0 tests failed out of 6

Total Test time (real) =   3.12 sec
```
