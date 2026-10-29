! Close-on-exec: start a child process, then close the socket. Run with
! `run_test.py --eof-check`, whose server fails the test unless it sees the
! close promptly. If the child inherited the socket, the connection would
! stay open until the child (`sleep 5`) exits.
program test_cloexec
    use tcpsockets, only : open_socket, close_socket, socket_handle
    use arg_get_port, only: get_port

    implicit none
    type(socket_handle) :: fd
    character(len=100), parameter :: host = "localhost"

    call open_socket(fd, get_port(), host)
    ! (output redirected so ctest does not wait for the child to finish)
    call execute_command_line("sleep 5 > /dev/null 2>&1 &")
    call close_socket(fd)
    write(*,*) 'closed socket with a child process still running'
end program test_cloexec
