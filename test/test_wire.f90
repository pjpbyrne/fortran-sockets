! Checks the exact bytes on the wire, not just a round trip: run with
! `run_test.py --wire`, whose server expects precisely the bytes written here
! (native byte order, exact widths, strings without terminator) and replies
! with known bytes that are checked below.
program test_wire
    use tcpsockets, only : open_socket, close_socket, writebuffer, readbuffer, socket_handle
    use arg_get_port, only: get_port
    use iso_fortran_env, only: int32, int64, real32, real64

    implicit none
    type(socket_handle) :: fd
    character(len=100), parameter :: host = "localhost"
    integer(int32) :: i32
    integer(int64) :: i64
    real(real64)   :: r64
    character(len=3) :: str

    call open_socket(fd, get_port(), host)

    call writebuffer(fd, 42_int32)
    call writebuffer(fd, 9876543210_int64)
    call writebuffer(fd, 1.5_real32)
    call writebuffer(fd, -2.25_real64)
    call writebuffer(fd, 'abc', 3)
    call writebuffer(fd, [1_int32, 2_int32, 3_int32], 3)

    call readbuffer(fd, i32)
    call readbuffer(fd, i64)
    call readbuffer(fd, r64)
    call readbuffer(fd, str, 3)
    write(*,*) 'received:', i32, i64, r64, ' "', str, '"'

    if (i32 /= -7_int32)          error stop 'int32 reply decoded wrongly'
    if (i64 /= 2_int64**40)       error stop 'int64 reply decoded wrongly'
    if (r64 /= 0.125_real64)      error stop 'real64 reply decoded wrongly'
    if (str /= 'xyz')             error stop 'string reply decoded wrongly'

    call close_socket(fd)
    write(*,*) 'wire format as expected'
end program test_wire
