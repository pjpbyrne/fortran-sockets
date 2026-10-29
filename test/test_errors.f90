! Failure paths: each scenario must end in the library's own `error stop`.
! CMake checks the message with PASS_REGULAR_EXPRESSION, so a scenario that
! does not fail, fails differently, or is killed (e.g. by SIGPIPE) fails the
! test. Usage: test_errors <port> <scenario>
program test_errors
    use tcpsockets, only : open_socket, close_socket, writebuffer, readbuffer, socket_handle
    use arg_get_port, only: get_port
    use iso_fortran_env, only: real64

    implicit none
    type(socket_handle) :: fd
    integer :: port, i
    character(len=32) :: scenario
    character(len=100), parameter :: host = "localhost"
    real(real64), allocatable :: block(:)
    real(real64) :: x(4)
    character(len=4) :: str

    port = get_port()
    call get_command_argument(2, scenario)
    write(*,*) 'scenario: ', trim(scenario)

    select case (trim(scenario))

    ! --- the peer and the network --------------------------------------------
    case ('refused')              ! run with --no-listen
        call open_socket(fd, port, host)

    case ('send_to_closed')       ! run with --close: must not die of SIGPIPE
        call open_socket(fd, port, host)
        allocate(block(131072))   ! 1 MiB per write
        block = 1
        do i = 1, 1000
            call writebuffer(fd, block, size(block))
        end do

    case ('recv_from_closed')     ! run with --close
        call open_socket(fd, port, host)
        call readbuffer(fd, x, 4)

    ! --- caller mistakes -----------------------------------------------------
    case ('negative_n')
        call open_socket(fd, port, host)
        call writebuffer(fd, x, -1)

    case ('buffer_too_small')
        call open_socket(fd, port, host)
        call readbuffer(fd, x, 5)

    case ('string_too_small')
        call open_socket(fd, port, host)
        call writebuffer(fd, str, 5)

    case ('already_open')
        call open_socket(fd, port, host)
        call open_socket(fd, port, host)

    case ('close_unopened')
        call close_socket(fd)

    case ('write_unopened')
        call writebuffer(fd, x, 4)

    case default
        error stop 'test_errors: unknown scenario'
    end select

    error stop 'test_errors: UNEXPECTED, the scenario did not fail'
end program test_errors
