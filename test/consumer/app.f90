program app
    use tcpsockets, only: socket_handle, socket_is_open
    implicit none
    type(socket_handle) :: sock

    if (socket_is_open(sock)) error stop 'app: a new handle reports open'
    write(*,*) 'app: f90sockets usable'
end program app
