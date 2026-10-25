program main
    use tcpsockets, only : open_socket, close_socket, writebuffer, readbuffer, socket_handle
    use arg_get_port, only: get_port
    use iso_fortran_env

    implicit none
    type(socket_handle) :: fd
    integer :: port
    character(len=100), parameter :: host = "localhost"
    character(len=11) :: str_recv, str_send = "hello world"

    port = get_port()
    
    call open_socket(fd, port, host)
    write(*,*) 'connected'
    write(*,*)
    
    write(*,*) 'STRING'
    str_recv = "wrong wrong"
    call writebuffer(fd, str_send, 11)
    write(*,*) 'sent: ', str_send
    call readbuffer(fd, str_recv, 11)
    write(*,*) 'recv: ', str_recv
    if (str_send /= str_recv) ERROR STOP 'Strings did not match!'
    write(*,*)
    
    call close_socket(fd)
    write(*,*) 'closed socket'
    

end program main

