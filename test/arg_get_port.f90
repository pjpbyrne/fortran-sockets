module arg_get_port

contains

    integer function get_port() result(port)
        integer :: iostat_val
        character(len=32) :: arg_str
        character(len=128) :: err_msg

        ! 1. Check if the argument was provided
        if (command_argument_count() < 1) then
            write(*, '(A)') "Error: Missing port argument."
            write(*, '(A)') "Usage: ./test.exe <port>"
            error stop 1
        end if

        ! 2. Retrieve the first command-line argument
        call get_command_argument(1, arg_str)

        ! 3. Parse string into an integer safely
        read(arg_str, *, iostat=iostat_val, iomsg=err_msg) port
        if (iostat_val /= 0) then
            write(*, '(A, A)') "Error: Invalid port number: ", trim(arg_str)
            write(*, '(A, A)') "Details: ", trim(err_msg)
            error stop 1
        end if

        ! 4. Validate valid TCP port range (1 - 65535)
        if (port < 1 .or. port > 65535) then
            write(*, '(A, I0, A)') "Error: Port ", port, " is out of valid range (1 - 65535)."
            error stop 1
        end if

        write(*, '(A, I0)') "Successfully parsed port: ", port
    end function get_port

end module