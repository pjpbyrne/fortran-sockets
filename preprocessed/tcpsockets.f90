! -*- mode: F90 ; mode: font-lock ; column-number-mode: true ; vc-back-end: git -*-
module tcpsockets
   use, intrinsic :: iso_c_binding
   use, intrinsic :: iso_fortran_env, only: int32, int64, real32, real64

   implicit none(type, external)
   private

   public :: socket_handle
   public :: open_socket, close_socket
   public :: writebuffer, readbuffer

   ! -------------------------------------------------------------------------
   ! Generic Interfaces
   ! -------------------------------------------------------------------------
   interface writebuffer
      module procedure :: writebuffer_string
      module procedure :: writebuffer_int32_scalar
      module procedure :: writebuffer_int32_array
      module procedure :: writebuffer_int64_scalar
      module procedure :: writebuffer_int64_array
      module procedure :: writebuffer_real32_scalar
      module procedure :: writebuffer_real32_array
      module procedure :: writebuffer_real64_scalar
      module procedure :: writebuffer_real64_array
   end interface writebuffer

   interface readbuffer
      module procedure :: readbuffer_string
      module procedure :: readbuffer_int32_scalar
      module procedure :: readbuffer_int32_array
      module procedure :: readbuffer_int64_scalar
      module procedure :: readbuffer_int64_array
      module procedure :: readbuffer_real32_scalar
      module procedure :: readbuffer_real32_array
      module procedure :: readbuffer_real64_scalar
      module procedure :: readbuffer_real64_array
   end interface readbuffer

   ! -------------------------------------------------------------------------
   ! C Bindings
   ! -------------------------------------------------------------------------
   interface
      function tcp_connect(host, port, nodelay) bind(c, name="tcp_connect") result(sockfd)
         import :: c_char, c_int
         implicit none
         character(kind=c_char), dimension(*), intent(in) :: host
         integer(c_int), value, intent(in)                :: port
         integer(c_int), value, intent(in)                :: nodelay
         integer(c_int)                                   :: sockfd
      end function tcp_connect

      function tcp_close(sockfd) bind(c, name="tcp_close") result(status)
         import :: c_int
         implicit none
         integer(c_int), value, intent(in) :: sockfd
         integer(c_int)                    :: status
      end function tcp_close

      function tcp_send_array(sockfd, buf, len) bind(c, name="tcp_send") result(status)
         import :: c_int, c_size_t
         implicit none
         integer(c_int), value, intent(in)    :: sockfd
         type(*), dimension(*), intent(in)    :: buf
         integer(c_size_t), value, intent(in) :: len
         integer(c_int)                       :: status
      end function tcp_send_array

      function tcp_send_scalar(sockfd, buf, len) bind(c, name="tcp_send") result(status)
         import :: c_int, c_size_t
         implicit none
         integer(c_int), value, intent(in)    :: sockfd
         type(*), intent(in)                  :: buf
         integer(c_size_t), value, intent(in) :: len
         integer(c_int)                       :: status
      end function tcp_send_scalar

      function tcp_recv_array(sockfd, buf, len) bind(c, name="tcp_recv") result(status)
         import :: c_int, c_size_t
         implicit none
         integer(c_int), value, intent(in)    :: sockfd
         type(*), dimension(*)                :: buf
         integer(c_size_t), value, intent(in) :: len
         integer(c_int)                       :: status
      end function tcp_recv_array

      function tcp_recv_scalar(sockfd, buf, len) bind(c, name="tcp_recv") result(status)
         import :: c_int, c_size_t
         implicit none
         integer(c_int), value, intent(in)    :: sockfd
         type(*)                              :: buf
         integer(c_size_t), value, intent(in) :: len
         integer(c_int)                       :: status
      end function tcp_recv_scalar

      function tcp_send_chars(sockfd, buf, len) bind(c, name="tcp_send") result(status)
         import :: c_int, c_size_t, c_char
         implicit none
         integer(c_int), value, intent(in)                :: sockfd
         character(kind=c_char), dimension(*), intent(in) :: buf
         integer(c_size_t), value, intent(in)             :: len
         integer(c_int)                                   :: status
      end function tcp_send_chars

      function tcp_recv_chars(sockfd, buf, len) bind(c, name="tcp_recv") result(status)
         import :: c_int, c_size_t, c_char
         implicit none
         integer(c_int), value, intent(in)     :: sockfd
         character(kind=c_char), dimension(*)  :: buf
         integer(c_size_t), value, intent(in)  :: len
         integer(c_int)                        :: status
      end function tcp_recv_chars
   end interface

   type socket_handle
      integer(kind=c_int) :: fd   = -1_c_int
   end type socket_handle

contains

   ! nodelay (default .true.) disables Nagle's algorithm so small writes go out
   ! immediately. Without it, a write-write-read exchange (e.g. a length prefix,
   ! then a payload, then waiting for the reply) can stall ~40 ms per round trip
   ! on delayed ACKs. Pass nodelay=.false. only when streaming many small writes
   ! with no replies, where letting TCP coalesce them is faster.
   ! TCP keepalive is always enabled, so a peer that vanishes without closing
   ! the connection is detected ~75 s after it goes idle (see sockets.c).
   subroutine open_socket(sock, port, host, nodelay)
      type(socket_handle), intent(inout) :: sock
      integer, intent(in)              :: port
      character(len=*), intent(in)     :: host
      logical, intent(in), optional    :: nodelay
      character(kind=c_char, len=len_trim(host) + 1) :: c_host
      integer(c_int) :: c_nodelay

      if (sock%fd >= 0) error stop "open_socket: Socket already open!"
      c_nodelay = 1_c_int
      if (present(nodelay)) then
         if (.not. nodelay) c_nodelay = 0_c_int
      end if
      c_host = trim(host) // c_null_char
      sock%fd = tcp_connect(c_host, int(port, kind=c_int), c_nodelay)
      if (sock%fd < 0) error stop "open_socket: Failed to open tcp connection."
   end subroutine open_socket

   subroutine close_socket(sock)
      type(socket_handle), intent(inout) :: sock
      integer :: status

      if (sock%fd < 0) error stop "close_socket: Tried to close tcp socket that was not open!"
      status = tcp_close(sock%fd)
      if (status /= 0) error stop "close_socket: Failed to close tcp connection."
      sock%fd   = -1_c_int
   end subroutine close_socket

   ! -------------------------------------------------------------------------
   ! String Routines
   ! -------------------------------------------------------------------------
   subroutine writebuffer_string(sock, fstring, n)
      type(socket_handle), intent(in) :: sock
      character(kind=c_char, len=*), intent(in)  :: fstring
      integer, intent(in)             :: n
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "writebuffer_string: Negative sized transfer"
      if (len(fstring) < n) error stop "writebuffer_string: Buffer too small"
      if (sock%fd < 0) error stop "writebuffer_string: Socket not open!"

      status = tcp_send_chars(sock%fd, fstring, int(n, kind=c_size_t))
      if (status /= 0) error stop "writebuffer_string: Failed sending"
   end subroutine writebuffer_string

   subroutine readbuffer_string(sock, fstring, n)
      type(socket_handle), intent(in) :: sock
      character(kind=c_char, len=*), intent(out) :: fstring
      integer, intent(in)             :: n
      integer :: status

      if (n == 0) then
         fstring = ' '   ! nothing read: the whole string is padding
         return
      end if
      if (n < 0) error stop "readbuffer_string: Negative sized transfer"
      if (n > len(fstring)) error stop "readbuffer_string: Buffer too small"
      if (sock%fd < 0) error stop "readbuffer_string: Socket not open!"

      status = tcp_recv_chars(sock%fd, fstring, int(n, kind=c_size_t))
      if (status /= 0) error stop "readbuffer_string: Failed receiving"
      if (n < len(fstring)) fstring(n + 1:) = ' '
   end subroutine readbuffer_string

   ! -------------------------------------------------------------------------
   ! Fypp-Generated Typed Routines
   ! -------------------------------------------------------------------------
   subroutine writebuffer_int32_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      integer(kind=int32), intent(in) :: data
      integer :: status

      if (sock%fd < 0) error stop "writebuffer_int32_scalar: Socket not open!"
      status = tcp_send_scalar(sock%fd, data, c_sizeof(data))
      if (status /= 0) error stop "writebuffer_int32_scalar: Failed sending"
   end subroutine writebuffer_int32_scalar

   subroutine writebuffer_int32_array(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer, intent(in)             :: n
      integer(kind=int32), intent(in) :: data(:)
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "writebuffer_int32_array: Negative sized transfer"
      if (size(data) < n) error stop "writebuffer_int32_array: Buffer too small"
      if (sock%fd < 0) error stop "writebuffer_int32_array: Socket not open!"

      status = tcp_send_array(sock%fd, data(1:n), c_sizeof(data(1)) * int(n, kind=c_size_t))
      if (status /= 0) error stop "writebuffer_int32_array: Failed sending"
   end subroutine writebuffer_int32_array

   subroutine readbuffer_int32_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      integer(kind=int32), intent(out) :: data
      integer :: status

      if (sock%fd < 0) error stop "readbuffer_int32_scalar: Socket not open!"
      status = tcp_recv_scalar(sock%fd, data, c_sizeof(data))
      if (status /= 0) error stop "readbuffer_int32_scalar: Failed receiving"
   end subroutine readbuffer_int32_scalar

   subroutine readbuffer_int32_array(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer, intent(in)             :: n
      integer(kind=int32), intent(inout) :: data(:)
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "readbuffer_int32_array: Negative sized transfer"
      if (size(data) < n) error stop "readbuffer_int32_array: Buffer too small"
      if (sock%fd < 0) error stop "readbuffer_int32_array: Socket not open!"

      status = tcp_recv_array(sock%fd, data(1:n), c_sizeof(data(1)) * int(n, kind=c_size_t))
      if (status /= 0) error stop "readbuffer_int32_array: Failed receiving"
   end subroutine readbuffer_int32_array

   subroutine writebuffer_int64_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      integer(kind=int64), intent(in) :: data
      integer :: status

      if (sock%fd < 0) error stop "writebuffer_int64_scalar: Socket not open!"
      status = tcp_send_scalar(sock%fd, data, c_sizeof(data))
      if (status /= 0) error stop "writebuffer_int64_scalar: Failed sending"
   end subroutine writebuffer_int64_scalar

   subroutine writebuffer_int64_array(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer, intent(in)             :: n
      integer(kind=int64), intent(in) :: data(:)
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "writebuffer_int64_array: Negative sized transfer"
      if (size(data) < n) error stop "writebuffer_int64_array: Buffer too small"
      if (sock%fd < 0) error stop "writebuffer_int64_array: Socket not open!"

      status = tcp_send_array(sock%fd, data(1:n), c_sizeof(data(1)) * int(n, kind=c_size_t))
      if (status /= 0) error stop "writebuffer_int64_array: Failed sending"
   end subroutine writebuffer_int64_array

   subroutine readbuffer_int64_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      integer(kind=int64), intent(out) :: data
      integer :: status

      if (sock%fd < 0) error stop "readbuffer_int64_scalar: Socket not open!"
      status = tcp_recv_scalar(sock%fd, data, c_sizeof(data))
      if (status /= 0) error stop "readbuffer_int64_scalar: Failed receiving"
   end subroutine readbuffer_int64_scalar

   subroutine readbuffer_int64_array(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer, intent(in)             :: n
      integer(kind=int64), intent(inout) :: data(:)
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "readbuffer_int64_array: Negative sized transfer"
      if (size(data) < n) error stop "readbuffer_int64_array: Buffer too small"
      if (sock%fd < 0) error stop "readbuffer_int64_array: Socket not open!"

      status = tcp_recv_array(sock%fd, data(1:n), c_sizeof(data(1)) * int(n, kind=c_size_t))
      if (status /= 0) error stop "readbuffer_int64_array: Failed receiving"
   end subroutine readbuffer_int64_array

   subroutine writebuffer_real32_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      real(kind=real32), intent(in) :: data
      integer :: status

      if (sock%fd < 0) error stop "writebuffer_real32_scalar: Socket not open!"
      status = tcp_send_scalar(sock%fd, data, c_sizeof(data))
      if (status /= 0) error stop "writebuffer_real32_scalar: Failed sending"
   end subroutine writebuffer_real32_scalar

   subroutine writebuffer_real32_array(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer, intent(in)             :: n
      real(kind=real32), intent(in) :: data(:)
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "writebuffer_real32_array: Negative sized transfer"
      if (size(data) < n) error stop "writebuffer_real32_array: Buffer too small"
      if (sock%fd < 0) error stop "writebuffer_real32_array: Socket not open!"

      status = tcp_send_array(sock%fd, data(1:n), c_sizeof(data(1)) * int(n, kind=c_size_t))
      if (status /= 0) error stop "writebuffer_real32_array: Failed sending"
   end subroutine writebuffer_real32_array

   subroutine readbuffer_real32_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      real(kind=real32), intent(out) :: data
      integer :: status

      if (sock%fd < 0) error stop "readbuffer_real32_scalar: Socket not open!"
      status = tcp_recv_scalar(sock%fd, data, c_sizeof(data))
      if (status /= 0) error stop "readbuffer_real32_scalar: Failed receiving"
   end subroutine readbuffer_real32_scalar

   subroutine readbuffer_real32_array(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer, intent(in)             :: n
      real(kind=real32), intent(inout) :: data(:)
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "readbuffer_real32_array: Negative sized transfer"
      if (size(data) < n) error stop "readbuffer_real32_array: Buffer too small"
      if (sock%fd < 0) error stop "readbuffer_real32_array: Socket not open!"

      status = tcp_recv_array(sock%fd, data(1:n), c_sizeof(data(1)) * int(n, kind=c_size_t))
      if (status /= 0) error stop "readbuffer_real32_array: Failed receiving"
   end subroutine readbuffer_real32_array

   subroutine writebuffer_real64_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      real(kind=real64), intent(in) :: data
      integer :: status

      if (sock%fd < 0) error stop "writebuffer_real64_scalar: Socket not open!"
      status = tcp_send_scalar(sock%fd, data, c_sizeof(data))
      if (status /= 0) error stop "writebuffer_real64_scalar: Failed sending"
   end subroutine writebuffer_real64_scalar

   subroutine writebuffer_real64_array(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer, intent(in)             :: n
      real(kind=real64), intent(in) :: data(:)
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "writebuffer_real64_array: Negative sized transfer"
      if (size(data) < n) error stop "writebuffer_real64_array: Buffer too small"
      if (sock%fd < 0) error stop "writebuffer_real64_array: Socket not open!"

      status = tcp_send_array(sock%fd, data(1:n), c_sizeof(data(1)) * int(n, kind=c_size_t))
      if (status /= 0) error stop "writebuffer_real64_array: Failed sending"
   end subroutine writebuffer_real64_array

   subroutine readbuffer_real64_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      real(kind=real64), intent(out) :: data
      integer :: status

      if (sock%fd < 0) error stop "readbuffer_real64_scalar: Socket not open!"
      status = tcp_recv_scalar(sock%fd, data, c_sizeof(data))
      if (status /= 0) error stop "readbuffer_real64_scalar: Failed receiving"
   end subroutine readbuffer_real64_scalar

   subroutine readbuffer_real64_array(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer, intent(in)             :: n
      real(kind=real64), intent(inout) :: data(:)
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "readbuffer_real64_array: Negative sized transfer"
      if (size(data) < n) error stop "readbuffer_real64_array: Buffer too small"
      if (sock%fd < 0) error stop "readbuffer_real64_array: Socket not open!"

      status = tcp_recv_array(sock%fd, data(1:n), c_sizeof(data(1)) * int(n, kind=c_size_t))
      if (status /= 0) error stop "readbuffer_real64_array: Failed receiving"
   end subroutine readbuffer_real64_array

end module tcpsockets