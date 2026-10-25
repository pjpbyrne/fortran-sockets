! -*- mode: F90 ; mode: font-lock ; column-number-mode: true ; vc-back-end: git -*-
!=============================================================================!
!                          F 9 0 S O C K E T S                                !
!=============================================================================!

! Section 15.5.2.4, paragraph 14 (Fortran 2018): "An actual argument that 
! represents an element sequence and corresponds to a dummy argument that
! is an assumed-size array shall be contiguous."

module tcpsockets
   use iso_c_binding
   use iso_fortran_env, only: real64, int32, real32

   implicit none(type, external)

   private
   public :: socket_handle
   public :: open_socket, close_socket
   public :: writebuffer, readbuffer


   interface writebuffer
      PROCEDURE :: writebuffer_string
      PROCEDURE :: writebuffer_real_scalar
      PROCEDURE :: writebuffer_double_scalar
      PROCEDURE :: writebuffer_double_array
      PROCEDURE :: writebuffer_integer_scalar
   end interface

   interface readbuffer
      PROCEDURE :: readbuffer_string
      PROCEDURE :: readbuffer_real_scalar
      PROCEDURE :: readbuffer_double_array
      PROCEDURE :: readbuffer_double_scalar
      PROCEDURE :: readbuffer_integer_scalar
   end interface

   interface

      ! int tcp_connect(const char *host, int port)
      function tcp_connect(host, port) bind(c, name="tcp_connect") result(sockfd)
         import :: c_char, c_int
         implicit none
         character(kind=c_char), dimension(*), intent(in) :: host
         integer(c_int), value, intent(in)                :: port
         integer(c_int)                                   :: sockfd
      end function tcp_connect

      ! int tcp_close(int sockfd)
      function tcp_close(sockfd) bind(c, name="tcp_close") result(status)
         import :: c_int
         implicit none
         integer(c_int), value, intent(in) :: sockfd
         integer(c_int)                    :: status
      end function tcp_close

      ! int tcp_send(int sockfd, const void *buf, size_t len)
      function tcp_send_array(sockfd, buf, len) bind(c, name="tcp_send") result(status)
         import :: c_int, c_size_t
         implicit none
         integer(c_int), value, intent(in)    :: sockfd
         type(*), dimension(*)                :: buf
         integer(c_size_t), value, intent(in) :: len
         integer(c_int)                       :: status
      end function tcp_send_array

      ! int tcp_send(int sockfd, const void *buf, size_t len)
      function tcp_send_scalar(sockfd, buf, len) bind(c, name="tcp_send") result(status)
         import :: c_int, c_size_t
         implicit none
         integer(c_int), value, intent(in)    :: sockfd
         type(*)                              :: buf
         integer(c_size_t), value, intent(in) :: len
         integer(c_int)                       :: status
      end function tcp_send_scalar

      ! int tcp_recv(int sockfd, void *buf, size_t len)
      function tcp_recv_array(sockfd, buf, len) bind(c, name="tcp_recv") result(status)
         import :: c_int, c_size_t
         implicit none
         integer(c_int), value, intent(in)    :: sockfd
         type(*), dimension(*)                :: buf
         integer(c_size_t), value, intent(in) :: len
         integer(c_int)                       :: status
      end function tcp_recv_array

      ! int tcp_recv(int sockfd, void *buf, size_t len)
      function tcp_recv_scalar(sockfd, buf, len) bind(c, name="tcp_recv") result(status)
         import :: c_int, c_size_t
         implicit none
         integer(c_int), value, intent(in)    :: sockfd
         type(*)                              :: buf
         integer(c_size_t), value, intent(in) :: len
         integer(c_int)                       :: status
      end function tcp_recv_scalar

   end interface

   type socket_handle
      integer(kind=c_int) :: fd   = -1_c_int
      logical             :: open = .false.
   end type socket_handle

contains

   subroutine open_socket(sock, port, host)
      implicit none
      type(socket_handle), intent(out) :: sock
      integer, intent(in)              :: port
      character(LEN=*),    intent(in)  :: host

      character(kind=c_char, len=len_trim(host) + 1) :: c_host

      c_host = trim(host) // c_null_char
      sock%fd = tcp_connect(c_host, int(port, kind=c_int))

      if (sock%fd <0) ERROR STOP "open_socket: Failed to open tcp connection."
      sock%open = .true.

   end subroutine open_socket

   subroutine close_socket(sock)
      implicit none
      type(socket_handle), intent(inout) :: sock
      integer :: status
      if (.not. sock%open) ERROR STOP 'close_socket: Tried to close tcp socket that was not open!'
      status = tcp_close(sock%fd)
      if (status/=0) ERROR STOP "Failed to close tcp connection."
      sock%open = .false.
      sock%fd   = -1_c_int
   end subroutine close_socket

   subroutine writebuffer_double_scalar(sock, data)
      ! Send a single double
      type(socket_handle), intent(in) :: sock
      REAL(kind=real64),   intent(in) :: data
      integer :: status

      if (.not. sock%open) ERROR STOP 'writebuffer_double_scalar: Tried to write to tcp socket that was not open!'
      status = tcp_send_scalar(sock%fd, data, c_sizeof(data))
      if (status/=0) ERROR STOP 'writebuffer_double_scalar: Failed sending'

   end subroutine writebuffer_double_scalar

   subroutine writebuffer_real_scalar(sock, data)
      ! Send a single double
      type(socket_handle), intent(in) :: sock
      REAL(kind=real32),   intent(in) :: data
      integer :: status

      if (.not. sock%open) ERROR STOP 'writebuffer_real_scalar: Tried to write to tcp socket that was not open!'
      status = tcp_send_scalar(sock%fd, data, c_sizeof(data))
      if (status/=0) ERROR STOP 'writebuffer_real_scalar: Failed sending'

   end subroutine writebuffer_real_scalar
   
   subroutine writebuffer_integer_scalar(sock, data)
      ! Send a single integer
      type(socket_handle), intent(in) :: sock
      integer(kind=int32), intent(in) :: data
      integer :: status

      if (.not. sock%open) ERROR STOP 'writebuffer_integer_scalar: Tried to write to tcp socket that was not open!'  
      status = tcp_send_scalar(sock%fd, data, c_sizeof(data))
      if (status/=0) ERROR STOP 'writebuffer_integer_scalar: Failed sending'

   end subroutine writebuffer_integer_scalar

   subroutine writebuffer_string(sock, fstring, plen)
      ! Send an string
      type(socket_handle), intent(in) :: sock
      character(LEN=*), intent(in)             :: fstring
      integer, intent(in)                      :: plen
      integer :: status

      if (plen == 0) return
      if (plen < 0) ERROR STOP 'writebuffer_string: Negative sized transfer'
      if (len(fstring) < plen) ERROR STOP 'writebuffer_string: Buffer too small'
      if (.not. sock%open) ERROR STOP 'writebuffer_string: Tried to write to tcp socket that was not open!'

      status = tcp_send_array(sock%fd, fstring(1:1), int(plen, kind=c_size_t))
      if (status/=0) ERROR STOP 'writebuffer_string: Failed sending'

   end subroutine writebuffer_string

   subroutine writebuffer_double_array(sock, data, plen)
      ! Send an array of doubles
      type(socket_handle), intent(in) :: sock
      integer, intent(in)           :: plen
      REAL(kind=real64), intent(in) :: data(:)
      integer :: status

      if (plen == 0) return
      if (plen < 0) ERROR STOP 'writebuffer_double_array: Negative sized transfer'
      if (size(data) < plen) ERROR STOP 'writebuffer_double_array: Buffer too small'
      if (.not. sock%open) ERROR STOP 'writebuffer_double_array: Tried to write to tcp socket that was not open!'

      status = tcp_send_array(sock%fd, data, c_sizeof(data(1))*int(plen,kind=c_size_t))
      if (status/=0) ERROR STOP 'writebuffer_double_array: Failed sending'

   end subroutine writebuffer_double_array

   subroutine readbuffer_double_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      REAL(kind=real64), intent(out)           :: data
      integer :: status

      if (.not. sock%open) ERROR STOP 'readbuffer_double_scalar: Tried to read from tcp socket that was not open!'
      status = tcp_recv_scalar(sock%fd, data, c_sizeof(data))
      if (status/=0) ERROR STOP 'readbuffer_double_scalar: Failed receiving'

   end subroutine readbuffer_double_scalar

   subroutine readbuffer_real_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      REAL(kind=real32), intent(out)           :: data
      integer :: status

      if (.not. sock%open) ERROR STOP 'readbuffer_real_scalar: Tried to read from tcp socket that was not open!'
      status = tcp_recv_scalar(sock%fd, data, c_sizeof(data))
      if (status/=0) ERROR STOP 'readbuffer_real_scalar: Failed receiving'

   end subroutine readbuffer_real_scalar


   subroutine readbuffer_integer_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      integer(kind=int32), intent(out)         :: data
      integer :: status

      if (.not. sock%open) ERROR STOP 'readbuffer_int_scalar: Tried to read from tcp socket that was not open!'
      status = tcp_recv_scalar(sock%fd, data, c_sizeof(data))
      if (status/=0) ERROR STOP 'readbuffer_int_scalar: Failed receiving'
   end subroutine

   subroutine readbuffer_string(sock, fstring, plen)
      type(socket_handle), intent(in) :: sock
      character(LEN=*), intent(out)            :: fstring
      integer, intent(in)                      :: plen
      integer :: status

      if (plen == 0) return
      if (plen < 0) ERROR STOP 'readbuffer_string: Negative sized transfer'
      if (plen > len(fstring)) ERROR STOP 'readbuffer_string: Buffer too small'

      if (.not. sock%open) ERROR STOP 'readbuffer_string: Tried to read from tcp socket that was not open!'
      status = tcp_recv_array(sock%fd, fstring(1:1), int(plen, kind=c_size_t))
      if (status/=0) ERROR STOP 'readbuffer_string: Failed receiving'

   end subroutine readbuffer_string

   subroutine readbuffer_double_array(sock, data, plen)
      type(socket_handle), intent(in) :: sock
      integer, intent(in)                      :: plen
      REAL(kind=real64), intent(out)           :: data(:)
      integer :: status

      if (plen == 0) return
      if (plen < 0) ERROR STOP 'readbuffer_double_array: Negative sized transfer'
      if (size(data) < plen) ERROR STOP 'readbuffer_double_array: Buffer too small'

      if (.not. sock%open) ERROR STOP 'readbuffer_double_array: Tried to read from tcp socket that was not open!'
      status = tcp_recv_array(sock%fd, data,c_sizeof(data(1))*int(plen,kind=c_size_t))
      if (status/=0) ERROR STOP 'readbuffer_double_array: Failed receiving'

   end subroutine readbuffer_double_array
end module tcpsockets
