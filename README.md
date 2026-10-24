# fortran-sockets

This is an attempt to write a reasonable wrapper for a sockets interface in fortran.

## Structure
The sockets interface itself is in f90sockets.f90 and csockets.c. These only support a limited number of types at the moment. 

## Compiling
This can be compiled with
    make
and this should build a main.exe for testing.

## Testing
Included is a python tcp echo server. Run this with
    ./python-server.py

This will listen on port 65432 for tcp connections and echo any messages back to the sender. This is used by main.exe to test that it can successfully send and recieve.

Running main.exe you should see some output.

The whole test run can be automated with the included bash script, test-run.sh:

```
$ ./test-run.sh
make: 'main.exe' is up to date.
Python:- Server is listening on 0.0.0.0:65432...
 connected

 STRING
 sent: hello world
Python:- Connected successfully by ('127.0.0.1', 36526)
Python:- Received: b'hello world'
 recv: hello world

 REAL64
 sent:    42.000000000000000
Python:- Received: b'\x00\x00\x00\x00\x00\x00E@'
 recv:    42.000000000000000

 Int
 sent:            5
Python:- Received: b'\x05\x00\x00\x00'
 recv:            5

 real array
 sent:    67.000000000000000        67.000000000000000
Python:- Received: b'\x00\x00\x00\x00\x00\xc0P@\x00\x00\x00\x00\x00\xc0P@'
 recv:    67.000000000000000        67.000000000000000

 strided slice
 sent:    10.000000000000000        10.000000000000000
Python:- Received: b'\x00\x00\x00\x00\x00\x00$@\x00\x00\x00\x00\x00\x00$@'
 expect (10):    10.000000000000000        10.000000000000000
 expect (-5):   -5.0000000000000000       -5.0000000000000000
 full:   10.000000000000000       -5.0000000000000000        10.000000000000000       -5.0000000000000000

 closed socket
Passed!
```
