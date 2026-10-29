program app2
    use tcpsockets, only: socket_handle, socket_is_open
    implicit none
    type(socket_handle) :: sock

    if (socket_is_open(sock)) error stop 'app2: a new handle reports open'
    write(*,*) 'app2: f90sockets usable'
end program app2
