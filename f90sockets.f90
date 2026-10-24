! -*- mode: F90 ; mode: font-lock ; column-number-mode: true ; vc-back-end: git -*-
!=============================================================================!
!                          F 9 0 S O C K E T S                                !
!=============================================================================!
! F90 iso_c_binding wrapper for socket communication.                         !
! (originally i-pi/drivers/f90/fsockets.f90)                                  !
!                                                                             !
! Copyright (C) 2013, Michele Ceriotti                                        !
!                                                                             !
! Permission is hereby granted, free of charge, to any person obtaining       !
! a copy of this software and associated documentation files (the             !
! "Software"), to deal in the Software without restriction, including         !
! without limitation the rights to use, copy, modify, merge, publish,         !
! distribute, sublicense, and/or sell copies of the Software, and to          !
! permit persons to whom the Software is furnished to do so, subject to       !
! the following conditions:                                                   !
!                                                                             !
! The above copyright notice and this permission notice shall be included     !
! in all copies or substantial portions of the Software.                      !
!                                                                             !
! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY kind,             !
! EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF          !
! MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.      !
! IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY        !
! CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,        !
! TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE           !
! SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                      !
!                                                                             !
!                                                                             !
! Contains both the functions that transmit data to the socket and read the   !
! data back out again once finished, and the function which opens the socket  !
! initially.                                                                  !
!                                                                             !
! Functions:                                                                  !
!    open_socket: Opens a socket with the required host server, socket type   !
!     and port number.                                                        !
!    write_buffer: Writes a string to the socket.                             !
!    read_buffer: Reads data from the socket.                                 !
!-----------------------------------------------------------------------------!
! Written from  "Module Specification for New Plane Wave Code",  M. Segall,   !
!    P. Lindan, M. Probert, C. Pickard, P. Hasnip, S. Clark and M. Payne      !
!                           Copyright 1999/2000                               !
!-----------------------------------------------------------------------------!
! Written by Michele Ceriotti, 2013 (extracted from i-Pi 2.4.0)               !
!=============================================================================!

MODULE F90SOCKETS
   USE iso_c_binding
   use iso_fortran_env, only: real64, int32

   implicit none(type, external)

   interface writebuffer
      PROCEDURE :: writebuffer_s
      PROCEDURE :: writebuffer_d
      PROCEDURE :: writebuffer_dv
      PROCEDURE :: writebuffer_i
   end interface

   interface readbuffer
      PROCEDURE :: readbuffer_s
      PROCEDURE :: readbuffer_dv
      PROCEDURE :: readbuffer_d
      PROCEDURE :: readbuffer_i
   end interface

   interface

      subroutine open_csocket(sockfd, inet, port, host) BIND(C, name="open_socket")
         USE iso_c_binding
         integer(kind=c_int)                  :: sockfd  ! Should be a reference
         integer(kind=c_int), value           :: inet, port
         character(kind=c_char), dimension(*) :: host
      end subroutine open_csocket

      subroutine close_csocket(sockfd) BIND(C, name="close_socket")
         USE iso_c_binding
         integer(kind=c_int), value           :: sockfd
      end subroutine close_csocket

      subroutine writebuffer_csocket_array(sockfd, data, plen) BIND(C, name="writebuffer")
         USE iso_c_binding
         integer(kind=c_int), value           :: sockfd
         type(*), dimension(*)                :: data ! New f2018 void* ptr which ensures contiguous
         integer(kind=c_int), value           :: plen
      end subroutine writebuffer_csocket_array

      subroutine readbuffer_csocket_array(sockfd, data, plen) BIND(C, name="readbuffer")
         USE iso_c_binding
         integer(kind=c_int), value           :: sockfd
         type(*), dimension(*)                :: data ! New f2018 void* ptr which ensures contiguous
         integer(kind=c_int), value           :: plen
      end subroutine readbuffer_csocket_array

      subroutine writebuffer_csocket_scalar(sockfd, data, plen) BIND(C, name="writebuffer")
         USE iso_c_binding
         integer(kind=c_int), value           :: sockfd
         type(*)                              :: data ! New f2018 void* ptr which ensures contiguous
         integer(kind=c_int), value           :: plen
      end subroutine writebuffer_csocket_scalar

      subroutine readbuffer_csocket_scalar(sockfd, data, plen) BIND(C, name="readbuffer")
         USE iso_c_binding
         integer(kind=c_int), value           :: sockfd
         type(*)                              :: data ! New f2018 void* ptr which ensures contiguous
         integer(kind=c_int), value           :: plen
      end subroutine readbuffer_csocket_scalar

   end interface

contains

   subroutine open_socket(psockfd, inet, port, host)
      implicit none
      integer, intent(in) :: inet, port
      integer, intent(out) :: psockfd
      character(LEN=*), intent(in) :: host
      character(LEN=1, kind=c_char) :: chost(1024)

      call fstr2cstr(host, chost)
      call open_csocket(psockfd, inet, port, chost)

   end subroutine open_socket

   subroutine close_socket(psockfd)
      implicit none
      integer, intent(in) :: psockfd
      call close_csocket(int(psockfd, kind=c_int))
   end subroutine close_socket

   subroutine fstr2cstr(fstr, cstr)
      implicit none
      character(LEN=*), intent(in) :: fstr
      character(kind=c_char, LEN=1), intent(out) :: cstr(:)

      integer i, n

      ! Check hostname isn't too large to fit in the buffer
      if (len_trim(fstr) >= size(cstr)) STOP 'open_socket: hostname too long!'

      n = LEN_TRIM(fstr)
      do i = 1, n
         cstr(i) = fstr(i:i)
      end do
      cstr(n + 1) = C_NULL_CHAR

   end subroutine

   subroutine writebuffer_d(sockfd, fdata)
      ! Send a single double
      integer, intent(in)                      :: sockfd
      REAL(kind=real64), intent(in)            :: fdata
      REAL(kind=c_double), TARGET              :: cdata

      cdata = fdata
      call writebuffer_csocket_scalar(int(sockfd, kind=c_int), cdata, int(c_sizeof(cdata), kind=c_int))

   end subroutine writebuffer_d

   subroutine writebuffer_i(sockfd, fdata)
      ! Send an integer
      integer, intent(in)                      :: sockfd
      integer(kind=int32), intent(in)          :: fdata
      integer(kind=c_int), TARGET              :: cdata

      cdata = fdata
      call writebuffer_csocket_scalar(int(sockfd, kind=c_int), cdata, int(c_sizeof(cdata), kind=c_int))

   end subroutine writebuffer_i

   subroutine writebuffer_s(sockfd, fstring, plen)
      ! Send an string
      integer, intent(in)                      :: sockfd
      character(LEN=*), intent(in) :: fstring
      integer, intent(in)                      :: plen

      integer                                  :: i
      character(LEN=1, kind=c_char), TARGET    :: cstring(plen)

      if (plen == 0) return
      if (plen < 0) STOP 'writebuffer_s: Negative sized transfer'
      if (len(fstring) < plen) STOP 'writebuffer_s: Buffer too small'

      do i = 1, plen
         cstring(i) = ACHAR(ICHAR(fstring(i:i)), kind=c_char) ! Convert to ascii before packing into c string
      end do

      call writebuffer_csocket_array(int(sockfd, kind=c_int), cstring, int(plen, kind=c_int))

   end subroutine writebuffer_s

   subroutine writebuffer_dv(sockfd, fdata, plen)
      ! Send an array of doubles
      integer, intent(in)           :: sockfd, plen
      REAL(kind=real64), intent(in) :: fdata(:)

      if (plen == 0) return
      if (plen < 0) STOP 'writebuffer_dv: Negative sized transfer'
      if (size(fdata) < plen) STOP 'writebuffer_dv: Buffer too small'

      call writebuffer_csocket_array(int(sockfd, kind=c_int), fdata, int(c_sizeof(fdata(1))*plen, kind=c_int))

   end subroutine writebuffer_dv

   subroutine readbuffer_d(sockfd, fdata)
      integer, intent(in)                      :: sockfd
      REAL(kind=real64), intent(out)           :: fdata
      REAL(kind=c_double), TARGET              :: cdata

      call readbuffer_csocket_scalar(int(sockfd, kind=c_int), cdata, int(c_sizeof(cdata), kind=c_int))
      fdata = cdata

   end subroutine

   subroutine readbuffer_i(sockfd, fdata)
      integer, intent(in)                      :: sockfd
      integer(kind=int32), intent(out)         :: fdata
      integer(kind=c_int), target              :: cdata

      call readbuffer_csocket_scalar(int(sockfd, kind=c_int), cdata, int(c_sizeof(cdata), kind=c_int))
      fdata = int(cdata)

   end subroutine

   subroutine readbuffer_s(sockfd, fstring, plen)
      integer, intent(in)                      :: sockfd
      character(LEN=*), intent(out)            :: fstring
      integer, intent(in)                      :: plen

      character(LEN=1, kind=c_char), target    :: cstring(plen)

      if (plen == 0) return
      if (plen < 0) STOP 'readbuffer_s: Negative sized transfer'
      if (plen > len(fstring)) STOP 'readbuffer_s: Buffer too small'

      call readbuffer_csocket_array(int(sockfd, kind=c_int), cstring, int(plen, kind=c_int))
      fstring(1:plen) = transfer(achar(iachar(cstring(1:plen))), mold=fstring(1:plen))

   end subroutine

   subroutine readbuffer_dv(sockfd, fdata, plen)
      integer, intent(in)                      :: sockfd, plen
      REAL(kind=real64), intent(out)           :: fdata(:)

      if (plen == 0) return
      if (plen < 0) STOP 'readbuffer_dv: Negative sized transfer'
      if (size(fdata) < plen) STOP 'readbuffer_dv: Buffer too small'

      call readbuffer_csocket_array(int(sockfd, kind=c_int), fdata, int(c_sizeof(fdata(1))*plen, kind=c_int))

   end subroutine
end MODULE
