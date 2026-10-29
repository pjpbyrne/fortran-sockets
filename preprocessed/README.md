# Pre-generated sockets

This is the preprocessed source ready to be used directly in a project.

## sockets.c
This file contains the underlying c code that directly deals with reading and writing bytes to the streams. It also handles correctly opening and closing connections. 

## tcpsockets.f90
This is are the interfaces that you should call from fortran. It contains a lot of routines, one for every flavour of basic type and also for arrays of those types (except arrays of strings. An example of using these would be

```fortran
type(socket_handle) :: socket
character(len=100)  :: return_data

call open_socket(socket, 8080, 'localhost')
call writebuffer(socket, 'hello', 5)
call readbuffer(socket, return_data, 5)   ! reads exactly 5 bytes; rest blank-padded
call close_socket(socket)
```

The file descriptors are wrapped in a simple type as they are of type c_int and there are no guarantees that fortran integers are big enough to hold them. 
