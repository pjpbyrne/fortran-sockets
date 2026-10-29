! -*- mode: F90 ; mode: font-lock ; column-number-mode: true ; vc-back-end: git -*-
module tcpsockets
   use, intrinsic :: iso_c_binding
   use, intrinsic :: iso_fortran_env, only: int32, int64, real32, real64

   implicit none(type, external)
   private

   public :: socket_handle
   public :: open_socket, close_socket, socket_is_open
   public :: writebuffer, readbuffer

   ! -------------------------------------------------------------------------
   ! Generic Interfaces
   ! -------------------------------------------------------------------------
   interface writebuffer
      module procedure :: writebuffer_string
      module procedure :: writebuffer_string_n64
      module procedure :: writebuffer_int32_scalar
      module procedure :: writebuffer_int32_array
      module procedure :: writebuffer_int32_array_n64
      module procedure :: writebuffer_int64_scalar
      module procedure :: writebuffer_int64_array
      module procedure :: writebuffer_int64_array_n64
      module procedure :: writebuffer_real32_scalar
      module procedure :: writebuffer_real32_array
      module procedure :: writebuffer_real32_array_n64
      module procedure :: writebuffer_real64_scalar
      module procedure :: writebuffer_real64_array
      module procedure :: writebuffer_real64_array_n64
   end interface writebuffer

   interface readbuffer
      module procedure :: readbuffer_string
      module procedure :: readbuffer_string_n64
      module procedure :: readbuffer_int32_scalar
      module procedure :: readbuffer_int32_array
      module procedure :: readbuffer_int32_array_n64
      module procedure :: readbuffer_int64_scalar
      module procedure :: readbuffer_int64_array
      module procedure :: readbuffer_int64_array_n64
      module procedure :: readbuffer_real32_scalar
      module procedure :: readbuffer_real32_array
      module procedure :: readbuffer_real32_array_n64
      module procedure :: readbuffer_real64_scalar
      module procedure :: readbuffer_real64_array
      module procedure :: readbuffer_real64_array_n64
   end interface readbuffer

   ! -------------------------------------------------------------------------
   ! C Bindings
   ! -------------------------------------------------------------------------
   interface
      function tcp_connect(host, port, nodelay) bind(c, name="f90sockets_connect") result(sockfd)
         import :: c_char, c_int
         implicit none
         character(kind=c_char), dimension(*), intent(in) :: host
         integer(c_int), value, intent(in)                :: port
         integer(c_int), value, intent(in)                :: nodelay
         integer(c_int)                                   :: sockfd
      end function tcp_connect

      function tcp_close(sockfd) bind(c, name="f90sockets_close") result(status)
         import :: c_int
         implicit none
         integer(c_int), value, intent(in) :: sockfd
         integer(c_int)                    :: status
      end function tcp_close

      function tcp_send_array(sockfd, buf, len) bind(c, name="f90sockets_send") result(status)
         import :: c_int, c_size_t
         implicit none
         integer(c_int), value, intent(in)    :: sockfd
         type(*), dimension(*), intent(in)    :: buf
         integer(c_size_t), value, intent(in) :: len
         integer(c_int)                       :: status
      end function tcp_send_array

      function tcp_send_scalar(sockfd, buf, len) bind(c, name="f90sockets_send") result(status)
         import :: c_int, c_size_t
         implicit none
         integer(c_int), value, intent(in)    :: sockfd
         type(*), intent(in)                  :: buf
         integer(c_size_t), value, intent(in) :: len
         integer(c_int)                       :: status
      end function tcp_send_scalar

      function tcp_recv_array(sockfd, buf, len) bind(c, name="f90sockets_recv") result(status)
         import :: c_int, c_size_t
         implicit none
         integer(c_int), value, intent(in)    :: sockfd
         type(*), dimension(*)                :: buf
         integer(c_size_t), value, intent(in) :: len
         integer(c_int)                       :: status
      end function tcp_recv_array

      function tcp_recv_scalar(sockfd, buf, len) bind(c, name="f90sockets_recv") result(status)
         import :: c_int, c_size_t
         implicit none
         integer(c_int), value, intent(in)    :: sockfd
         type(*)                              :: buf
         integer(c_size_t), value, intent(in) :: len
         integer(c_int)                       :: status
      end function tcp_recv_scalar

      function tcp_send_chars(sockfd, buf, len) bind(c, name="f90sockets_send") result(status)
         import :: c_int, c_size_t, c_char
         implicit none
         integer(c_int), value, intent(in)                :: sockfd
         character(kind=c_char), dimension(*), intent(in) :: buf
         integer(c_size_t), value, intent(in)             :: len
         integer(c_int)                                   :: status
      end function tcp_send_chars

      function tcp_recv_chars(sockfd, buf, len) bind(c, name="f90sockets_recv") result(status)
         import :: c_int, c_size_t, c_char
         implicit none
         integer(c_int), value, intent(in)     :: sockfd
         character(kind=c_char), dimension(*)  :: buf
         integer(c_size_t), value, intent(in)  :: len
         integer(c_int)                        :: status
      end function tcp_recv_chars
   end interface

   ! Non-contiguous arrays (e.g. strided sections) are sent and received through
   ! a heap buffer of at most this many bytes. Passing them to C directly would
   ! make the compiler copy the whole array into a temporary, which some
   ! compilers (e.g. ifx) put on the stack, overflowing it for large arrays.
   integer(int64), parameter :: COPY_CHUNK_BYTES = 1048576_int64   ! 1 MiB

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
      character(kind=c_char, len=len_trim(adjustl(host)) + 1) :: c_host
      integer(c_int) :: c_nodelay

      if (sock%fd >= 0) error stop "open_socket: Socket already open!"
      c_nodelay = 1_c_int
      if (present(nodelay)) then
         if (.not. nodelay) c_nodelay = 0_c_int
      end if
      c_host = trim(adjustl(host)) // c_null_char
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

   ! True while the handle holds an open connection, i.e. between a successful
   ! open_socket and the matching close_socket
   logical function socket_is_open(sock)
      type(socket_handle), intent(in) :: sock

      socket_is_open = sock%fd >= 0
   end function socket_is_open

   ! -------------------------------------------------------------------------
   ! String Routines
   ! -------------------------------------------------------------------------
   ! Like the array routines, n may be int32 or int64; the int32 versions
   ! forward to the int64 ones.
   subroutine writebuffer_string(sock, fstring, n)
      type(socket_handle), intent(in) :: sock
      character(kind=c_char, len=*), intent(in)  :: fstring
      integer(int32), intent(in)      :: n

      call writebuffer_string_n64(sock, fstring, int(n, kind=int64))
   end subroutine writebuffer_string

   subroutine writebuffer_string_n64(sock, fstring, n)
      type(socket_handle), intent(in) :: sock
      character(kind=c_char, len=*), intent(in)  :: fstring
      integer(int64), intent(in)      :: n
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "writebuffer_string: Negative sized transfer"
      if (len(fstring, kind=int64) < n) error stop "writebuffer_string: Buffer too small"
      if (sock%fd < 0) error stop "writebuffer_string: Socket not open!"

      status = tcp_send_chars(sock%fd, fstring, int(n, kind=c_size_t))
      if (status /= 0) error stop "writebuffer_string: Failed sending"
   end subroutine writebuffer_string_n64

   subroutine readbuffer_string(sock, fstring, n)
      type(socket_handle), intent(in) :: sock
      character(kind=c_char, len=*), intent(out) :: fstring
      integer(int32), intent(in)      :: n

      call readbuffer_string_n64(sock, fstring, int(n, kind=int64))
   end subroutine readbuffer_string

   subroutine readbuffer_string_n64(sock, fstring, n)
      type(socket_handle), intent(in) :: sock
      character(kind=c_char, len=*), intent(out) :: fstring
      integer(int64), intent(in)      :: n
      integer :: status

      if (n == 0) then
         fstring = ' '   ! nothing read: the whole string is padding
         return
      end if
      if (n < 0) error stop "readbuffer_string: Negative sized transfer"
      if (n > len(fstring, kind=int64)) error stop "readbuffer_string: Buffer too small"
      if (sock%fd < 0) error stop "readbuffer_string: Socket not open!"

      status = tcp_recv_chars(sock%fd, fstring, int(n, kind=c_size_t))
      if (status /= 0) error stop "readbuffer_string: Failed receiving"
      if (n < len(fstring, kind=int64)) fstring(n + 1:) = ' '
   end subroutine readbuffer_string_n64

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

   ! Array transfers take n as int32 (the usual default integer) or int64 (for
   ! 2**31 or more elements); the int32 versions forward to the int64 ones.
   subroutine writebuffer_int32_array(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer(int32), intent(in)      :: n
      integer(kind=int32), intent(in) :: data(:)

      call writebuffer_int32_array_n64(sock, data, int(n, kind=int64))
   end subroutine writebuffer_int32_array

   subroutine writebuffer_int32_array_n64(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer(int64), intent(in)      :: n
      integer(kind=int32), intent(in) :: data(:)
      integer(kind=int32), allocatable :: buf(:)
      integer(int64) :: chunk, first, last
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "writebuffer_int32_array: Negative sized transfer"
      if (size(data, kind=int64) < n) error stop "writebuffer_int32_array: Buffer too small"
      if (sock%fd < 0) error stop "writebuffer_int32_array: Socket not open!"

      if (is_contiguous(data)) then
         ! Contiguous: pass straight through, no copy (C reads only n elements)
         status = tcp_send_array(sock%fd, data, c_sizeof(data(1)) * int(n, kind=c_size_t))
         if (status /= 0) error stop "writebuffer_int32_array: Failed sending"
      else
         ! Strided: copy through a heap buffer one chunk at a time
         chunk = max(1_int64, COPY_CHUNK_BYTES / c_sizeof(data(1)))
         allocate(buf(min(n, chunk)))
         do first = 1, n, chunk
            last = min(first + chunk - 1, n)
            buf(1:last - first + 1) = data(first:last)
            status = tcp_send_array(sock%fd, buf, c_sizeof(buf(1)) * int(last - first + 1, kind=c_size_t))
            if (status /= 0) error stop "writebuffer_int32_array: Failed sending"
         end do
      end if
   end subroutine writebuffer_int32_array_n64

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
      integer(int32), intent(in)      :: n
      integer(kind=int32), intent(inout) :: data(:)

      call readbuffer_int32_array_n64(sock, data, int(n, kind=int64))
   end subroutine readbuffer_int32_array

   subroutine readbuffer_int32_array_n64(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer(int64), intent(in)      :: n
      integer(kind=int32), intent(inout) :: data(:)
      integer(kind=int32), allocatable :: buf(:)
      integer(int64) :: chunk, first, last
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "readbuffer_int32_array: Negative sized transfer"
      if (size(data, kind=int64) < n) error stop "readbuffer_int32_array: Buffer too small"
      if (sock%fd < 0) error stop "readbuffer_int32_array: Socket not open!"

      if (is_contiguous(data)) then
         ! Contiguous: receive straight into data (only the first n elements)
         status = tcp_recv_array(sock%fd, data, c_sizeof(data(1)) * int(n, kind=c_size_t))
         if (status /= 0) error stop "readbuffer_int32_array: Failed receiving"
      else
         ! Strided: receive through a heap buffer one chunk at a time
         chunk = max(1_int64, COPY_CHUNK_BYTES / c_sizeof(data(1)))
         allocate(buf(min(n, chunk)))
         do first = 1, n, chunk
            last = min(first + chunk - 1, n)
            status = tcp_recv_array(sock%fd, buf, c_sizeof(buf(1)) * int(last - first + 1, kind=c_size_t))
            if (status /= 0) error stop "readbuffer_int32_array: Failed receiving"
            data(first:last) = buf(1:last - first + 1)
         end do
      end if
   end subroutine readbuffer_int32_array_n64

   subroutine writebuffer_int64_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      integer(kind=int64), intent(in) :: data
      integer :: status

      if (sock%fd < 0) error stop "writebuffer_int64_scalar: Socket not open!"
      status = tcp_send_scalar(sock%fd, data, c_sizeof(data))
      if (status /= 0) error stop "writebuffer_int64_scalar: Failed sending"
   end subroutine writebuffer_int64_scalar

   ! Array transfers take n as int32 (the usual default integer) or int64 (for
   ! 2**31 or more elements); the int32 versions forward to the int64 ones.
   subroutine writebuffer_int64_array(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer(int32), intent(in)      :: n
      integer(kind=int64), intent(in) :: data(:)

      call writebuffer_int64_array_n64(sock, data, int(n, kind=int64))
   end subroutine writebuffer_int64_array

   subroutine writebuffer_int64_array_n64(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer(int64), intent(in)      :: n
      integer(kind=int64), intent(in) :: data(:)
      integer(kind=int64), allocatable :: buf(:)
      integer(int64) :: chunk, first, last
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "writebuffer_int64_array: Negative sized transfer"
      if (size(data, kind=int64) < n) error stop "writebuffer_int64_array: Buffer too small"
      if (sock%fd < 0) error stop "writebuffer_int64_array: Socket not open!"

      if (is_contiguous(data)) then
         ! Contiguous: pass straight through, no copy (C reads only n elements)
         status = tcp_send_array(sock%fd, data, c_sizeof(data(1)) * int(n, kind=c_size_t))
         if (status /= 0) error stop "writebuffer_int64_array: Failed sending"
      else
         ! Strided: copy through a heap buffer one chunk at a time
         chunk = max(1_int64, COPY_CHUNK_BYTES / c_sizeof(data(1)))
         allocate(buf(min(n, chunk)))
         do first = 1, n, chunk
            last = min(first + chunk - 1, n)
            buf(1:last - first + 1) = data(first:last)
            status = tcp_send_array(sock%fd, buf, c_sizeof(buf(1)) * int(last - first + 1, kind=c_size_t))
            if (status /= 0) error stop "writebuffer_int64_array: Failed sending"
         end do
      end if
   end subroutine writebuffer_int64_array_n64

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
      integer(int32), intent(in)      :: n
      integer(kind=int64), intent(inout) :: data(:)

      call readbuffer_int64_array_n64(sock, data, int(n, kind=int64))
   end subroutine readbuffer_int64_array

   subroutine readbuffer_int64_array_n64(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer(int64), intent(in)      :: n
      integer(kind=int64), intent(inout) :: data(:)
      integer(kind=int64), allocatable :: buf(:)
      integer(int64) :: chunk, first, last
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "readbuffer_int64_array: Negative sized transfer"
      if (size(data, kind=int64) < n) error stop "readbuffer_int64_array: Buffer too small"
      if (sock%fd < 0) error stop "readbuffer_int64_array: Socket not open!"

      if (is_contiguous(data)) then
         ! Contiguous: receive straight into data (only the first n elements)
         status = tcp_recv_array(sock%fd, data, c_sizeof(data(1)) * int(n, kind=c_size_t))
         if (status /= 0) error stop "readbuffer_int64_array: Failed receiving"
      else
         ! Strided: receive through a heap buffer one chunk at a time
         chunk = max(1_int64, COPY_CHUNK_BYTES / c_sizeof(data(1)))
         allocate(buf(min(n, chunk)))
         do first = 1, n, chunk
            last = min(first + chunk - 1, n)
            status = tcp_recv_array(sock%fd, buf, c_sizeof(buf(1)) * int(last - first + 1, kind=c_size_t))
            if (status /= 0) error stop "readbuffer_int64_array: Failed receiving"
            data(first:last) = buf(1:last - first + 1)
         end do
      end if
   end subroutine readbuffer_int64_array_n64

   subroutine writebuffer_real32_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      real(kind=real32), intent(in) :: data
      integer :: status

      if (sock%fd < 0) error stop "writebuffer_real32_scalar: Socket not open!"
      status = tcp_send_scalar(sock%fd, data, c_sizeof(data))
      if (status /= 0) error stop "writebuffer_real32_scalar: Failed sending"
   end subroutine writebuffer_real32_scalar

   ! Array transfers take n as int32 (the usual default integer) or int64 (for
   ! 2**31 or more elements); the int32 versions forward to the int64 ones.
   subroutine writebuffer_real32_array(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer(int32), intent(in)      :: n
      real(kind=real32), intent(in) :: data(:)

      call writebuffer_real32_array_n64(sock, data, int(n, kind=int64))
   end subroutine writebuffer_real32_array

   subroutine writebuffer_real32_array_n64(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer(int64), intent(in)      :: n
      real(kind=real32), intent(in) :: data(:)
      real(kind=real32), allocatable :: buf(:)
      integer(int64) :: chunk, first, last
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "writebuffer_real32_array: Negative sized transfer"
      if (size(data, kind=int64) < n) error stop "writebuffer_real32_array: Buffer too small"
      if (sock%fd < 0) error stop "writebuffer_real32_array: Socket not open!"

      if (is_contiguous(data)) then
         ! Contiguous: pass straight through, no copy (C reads only n elements)
         status = tcp_send_array(sock%fd, data, c_sizeof(data(1)) * int(n, kind=c_size_t))
         if (status /= 0) error stop "writebuffer_real32_array: Failed sending"
      else
         ! Strided: copy through a heap buffer one chunk at a time
         chunk = max(1_int64, COPY_CHUNK_BYTES / c_sizeof(data(1)))
         allocate(buf(min(n, chunk)))
         do first = 1, n, chunk
            last = min(first + chunk - 1, n)
            buf(1:last - first + 1) = data(first:last)
            status = tcp_send_array(sock%fd, buf, c_sizeof(buf(1)) * int(last - first + 1, kind=c_size_t))
            if (status /= 0) error stop "writebuffer_real32_array: Failed sending"
         end do
      end if
   end subroutine writebuffer_real32_array_n64

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
      integer(int32), intent(in)      :: n
      real(kind=real32), intent(inout) :: data(:)

      call readbuffer_real32_array_n64(sock, data, int(n, kind=int64))
   end subroutine readbuffer_real32_array

   subroutine readbuffer_real32_array_n64(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer(int64), intent(in)      :: n
      real(kind=real32), intent(inout) :: data(:)
      real(kind=real32), allocatable :: buf(:)
      integer(int64) :: chunk, first, last
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "readbuffer_real32_array: Negative sized transfer"
      if (size(data, kind=int64) < n) error stop "readbuffer_real32_array: Buffer too small"
      if (sock%fd < 0) error stop "readbuffer_real32_array: Socket not open!"

      if (is_contiguous(data)) then
         ! Contiguous: receive straight into data (only the first n elements)
         status = tcp_recv_array(sock%fd, data, c_sizeof(data(1)) * int(n, kind=c_size_t))
         if (status /= 0) error stop "readbuffer_real32_array: Failed receiving"
      else
         ! Strided: receive through a heap buffer one chunk at a time
         chunk = max(1_int64, COPY_CHUNK_BYTES / c_sizeof(data(1)))
         allocate(buf(min(n, chunk)))
         do first = 1, n, chunk
            last = min(first + chunk - 1, n)
            status = tcp_recv_array(sock%fd, buf, c_sizeof(buf(1)) * int(last - first + 1, kind=c_size_t))
            if (status /= 0) error stop "readbuffer_real32_array: Failed receiving"
            data(first:last) = buf(1:last - first + 1)
         end do
      end if
   end subroutine readbuffer_real32_array_n64

   subroutine writebuffer_real64_scalar(sock, data)
      type(socket_handle), intent(in) :: sock
      real(kind=real64), intent(in) :: data
      integer :: status

      if (sock%fd < 0) error stop "writebuffer_real64_scalar: Socket not open!"
      status = tcp_send_scalar(sock%fd, data, c_sizeof(data))
      if (status /= 0) error stop "writebuffer_real64_scalar: Failed sending"
   end subroutine writebuffer_real64_scalar

   ! Array transfers take n as int32 (the usual default integer) or int64 (for
   ! 2**31 or more elements); the int32 versions forward to the int64 ones.
   subroutine writebuffer_real64_array(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer(int32), intent(in)      :: n
      real(kind=real64), intent(in) :: data(:)

      call writebuffer_real64_array_n64(sock, data, int(n, kind=int64))
   end subroutine writebuffer_real64_array

   subroutine writebuffer_real64_array_n64(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer(int64), intent(in)      :: n
      real(kind=real64), intent(in) :: data(:)
      real(kind=real64), allocatable :: buf(:)
      integer(int64) :: chunk, first, last
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "writebuffer_real64_array: Negative sized transfer"
      if (size(data, kind=int64) < n) error stop "writebuffer_real64_array: Buffer too small"
      if (sock%fd < 0) error stop "writebuffer_real64_array: Socket not open!"

      if (is_contiguous(data)) then
         ! Contiguous: pass straight through, no copy (C reads only n elements)
         status = tcp_send_array(sock%fd, data, c_sizeof(data(1)) * int(n, kind=c_size_t))
         if (status /= 0) error stop "writebuffer_real64_array: Failed sending"
      else
         ! Strided: copy through a heap buffer one chunk at a time
         chunk = max(1_int64, COPY_CHUNK_BYTES / c_sizeof(data(1)))
         allocate(buf(min(n, chunk)))
         do first = 1, n, chunk
            last = min(first + chunk - 1, n)
            buf(1:last - first + 1) = data(first:last)
            status = tcp_send_array(sock%fd, buf, c_sizeof(buf(1)) * int(last - first + 1, kind=c_size_t))
            if (status /= 0) error stop "writebuffer_real64_array: Failed sending"
         end do
      end if
   end subroutine writebuffer_real64_array_n64

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
      integer(int32), intent(in)      :: n
      real(kind=real64), intent(inout) :: data(:)

      call readbuffer_real64_array_n64(sock, data, int(n, kind=int64))
   end subroutine readbuffer_real64_array

   subroutine readbuffer_real64_array_n64(sock, data, n)
      type(socket_handle), intent(in) :: sock
      integer(int64), intent(in)      :: n
      real(kind=real64), intent(inout) :: data(:)
      real(kind=real64), allocatable :: buf(:)
      integer(int64) :: chunk, first, last
      integer :: status

      if (n == 0) return
      if (n < 0) error stop "readbuffer_real64_array: Negative sized transfer"
      if (size(data, kind=int64) < n) error stop "readbuffer_real64_array: Buffer too small"
      if (sock%fd < 0) error stop "readbuffer_real64_array: Socket not open!"

      if (is_contiguous(data)) then
         ! Contiguous: receive straight into data (only the first n elements)
         status = tcp_recv_array(sock%fd, data, c_sizeof(data(1)) * int(n, kind=c_size_t))
         if (status /= 0) error stop "readbuffer_real64_array: Failed receiving"
      else
         ! Strided: receive through a heap buffer one chunk at a time
         chunk = max(1_int64, COPY_CHUNK_BYTES / c_sizeof(data(1)))
         allocate(buf(min(n, chunk)))
         do first = 1, n, chunk
            last = min(first + chunk - 1, n)
            status = tcp_recv_array(sock%fd, buf, c_sizeof(buf(1)) * int(last - first + 1, kind=c_size_t))
            if (status /= 0) error stop "readbuffer_real64_array: Failed receiving"
            data(first:last) = buf(1:last - first + 1)
         end do
      end if
   end subroutine readbuffer_real64_array_n64

end module tcpsockets