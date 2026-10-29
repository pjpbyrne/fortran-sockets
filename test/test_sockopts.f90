program test_sockopts
    use tcpsockets, only : open_socket, close_socket, socket_handle
    use arg_get_port, only: get_port
    use iso_c_binding, only: c_int

    implicit none

    interface
        function check_sockopts(fd, expect_nodelay) bind(c, name="f90sockets_test_check_sockopts") result(failed)
            import :: c_int
            implicit none
            integer(c_int), value, intent(in) :: fd
            integer(c_int), value, intent(in) :: expect_nodelay
            integer(c_int)                    :: failed
        end function check_sockopts
    end interface

    type(socket_handle) :: fd
    integer :: port
    character(len=100), parameter :: host = "localhost"

    port = get_port()

    write(*,*) 'DEFAULT OPTIONS'
    call open_socket(fd, port, host)
    call report(check_sockopts(fd%fd, 1_c_int))
    call close_socket(fd)

    write(*,*) 'NODELAY=.FALSE.'
    call open_socket(fd, port, host, nodelay=.false.)
    call report(check_sockopts(fd%fd, 0_c_int))
    call close_socket(fd)

    write(*,*) 'all socket options as expected'

contains

    subroutine report(failed)
        integer(c_int), intent(in) :: failed

        if (iand(failed, 1_c_int)  /= 0) write(*,*) 'TCP_NODELAY not as expected'
        if (iand(failed, 2_c_int)  /= 0) write(*,*) 'SO_KEEPALIVE not enabled'
        if (iand(failed, 4_c_int)  /= 0) write(*,*) 'keepalive idle time not 15 s'
        if (iand(failed, 8_c_int)  /= 0) write(*,*) 'keepalive interval not 15 s'
        if (iand(failed, 16_c_int) /= 0) write(*,*) 'keepalive probe count not 4'
        if (iand(failed, 32_c_int) /= 0) write(*,*) 'FD_CLOEXEC not set'
        if (failed /= 0) error stop 'Socket options not as expected!'
    end subroutine report

end program test_sockopts
