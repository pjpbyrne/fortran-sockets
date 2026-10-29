program main
  use tcpsockets, only : open_socket, close_socket, writebuffer, readbuffer, socket_handle
  use iso_fortran_env
  use arg_get_port, only: get_port

  implicit none
  type(socket_handle) :: fd
  integer :: port
  character(len=100), parameter :: host = "localhost"

  character(len=11) :: str_recv, str_send = "hello world"
  integer :: int_recv, int_send = 5
  real(REAL64) :: real_recv, real_send = 42

  integer, parameter :: real_len = 2
  real(REAL64), dimension(real_len) :: real_array_recv, real_array_send = 67

  real(REAL64), dimension(4) :: real_slice_recv, real_slice_send = 67

  real(REAL64), parameter :: real_slice_copied = 10, real_slice_not_copied = -5

  ! Large enough (64 MB each way) to overflow the socket buffers, so the
  ! write only completes if the peer reads while we are still writing
  integer, parameter :: big_n = 8 * 1024 * 1024
  real(REAL64), allocatable :: big_send(:), big_recv(:)
  integer :: i
  
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
  if (str_send /= str_recv) error stop 'Strings did not match!'
  write(*,*)
  
  write(*,*) 'REAL64'
  real_recv = -1
  call writebuffer(fd, real_send)
  write(*,*) 'sent: ', real_send
  call readbuffer(fd, real_recv)
  write(*,*) 'recv: ', real_recv
  if (real_send /= real_recv) error stop 'Reals did not match'
  write(*,*)
 
  write(*,*) 'Int'
  int_recv = -1
  call writebuffer(fd, int_send)
  write(*,*) 'sent: ', int_send
  call readbuffer(fd, int_recv)
  write(*,*) 'recv: ', int_recv
  if (int_send /= int_recv) error stop 'Ints did not match'
  write(*,*)
  
  write(*,*) 'real array'
  real_array_recv = -1
  call writebuffer(fd, real_array_send, real_len)
  write(*,*) 'sent: ', real_array_send
  call readbuffer(fd, real_array_recv, real_len)
  write(*,*) 'recv: ', real_array_recv
  if (any(real_array_send /= real_array_recv)) error stop 'Real arrays did not match'
  write(*,*)

  write(*,*) 'strided slice'
  real_slice_recv = real_slice_not_copied
  real_slice_send = real_slice_copied
  call writebuffer(fd, real_slice_send(1::2), 2)
  write(*,*) 'sent: ', real_slice_send(1::2)
  call readbuffer(fd, real_slice_recv(1::2), 2)
  write(*,*) 'expect (10): ', real_slice_recv(1::2)
  write(*,*) 'expect (-5): ', real_slice_recv(2::2)
  write(*,*) 'full:', real_slice_recv
  if (any(real_slice_copied /= real_slice_recv(1::2))) error stop 'Sent elements do not match'
  if (any(real_slice_not_copied /= real_slice_recv(2::2))) error stop 'Real slice - wrote to wrong elements'
  write(*,*) 
  
  
  write(*,*) 'large strided transfer'
  allocate(big_send(2 * big_n), big_recv(2 * big_n))
  ! A loop, not an array constructor: ifx builds a constructor this size as a
  ! temporary on the stack, which overflows it
  do i = 1, 2 * big_n
     big_send(i) = real(i, REAL64)
  end do
  big_recv = real_slice_not_copied
  call writebuffer(fd, big_send(1::2), big_n)
  call readbuffer(fd, big_recv(2::2), big_n)
  if (any(big_recv(2::2) /= big_send(1::2))) error stop 'Large strided transfer did not match'
  if (any(big_recv(1::2) /= real_slice_not_copied)) error stop 'Large strided read wrote to wrong elements'
  write(*,*) 'ok,', big_n, 'values each way'
  write(*,*)

  call close_socket(fd)
  write(*,*) 'closed socket'
  
  
end program main

