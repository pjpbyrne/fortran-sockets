# Pre-generated sockets

This is the preprocessed source ready to be used directly in a project.

## sockets.c
This file contains the underlying c code that directly deals with reading and writing bytes to the streams. It also handles correctly opening and closing connections. 

## tcpsockets.f90
These are the interfaces to call from Fortran: generic `writebuffer` and `readbuffer` routines for scalars and rank-1 arrays of `int32`, `int64`, `real32` and `real64`, and for strings (but not arrays of strings). For example:

```fortran
type(socket_handle) :: socket
character(len=100)  :: return_data

call open_socket(socket, 8080, 'localhost')
call writebuffer(socket, 'hello', 5)
call readbuffer(socket, return_data, 5)   ! reads exactly 5 bytes; rest blank-padded
call close_socket(socket)
```

A handle must be closed with `close_socket` before it is reused; calling `open_socket` on a handle that is still open stops the program. Use `socket_is_open(socket)` to check whether a handle is currently open.

### Small writes and `nodelay`
By default `open_socket` sets `TCP_NODELAY`, so every `writebuffer` call is sent immediately. This matters for request/response exchanges. Without it, TCP's Nagle algorithm holds back a second small write until the first is acknowledged. The peer, still waiting for the rest of the message, delays that acknowledgement, so a pattern such as *write length prefix, write payload, read reply* stalls for about 40 ms on every round trip.

The cost is that each `writebuffer` call becomes its own packet. Sending many separate scalars is therefore slower than sending them as one array, so batch small values into arrays where you can. If a program only streams many small writes with no replies, it can let TCP coalesce them instead:

```fortran
call open_socket(socket, 8080, 'localhost', nodelay=.false.)
```

The peer's side matters too. If it replies with several small writes, it should also disable Nagle, or send each reply in one write.

### Dead peers and keepalive
Every connection has TCP keepalive enabled. Once a connection has been idle for 15 s, TCP probes the peer every 15 s. After 4 unanswered probes it fails the connection, and a waiting `readbuffer` stops with an error instead of hanging forever. A peer that crashed, lost power or became unreachable is therefore usually detected about 75 s after the connection goes idle; the operating system defaults would take over two hours.

- **Busy peers are not affected.** The peer's operating system answers the probes, so a peer that is alive but computing for hours keeps the connection open.
- **A stuck peer is not detected.** If the peer process is alive but never replies (deadlocked, say), the probes are still answered and `readbuffer` still waits.
- **Long outages end the connection.** A network outage, or a suspended peer machine, lasting more than about 75 s while the connection is idle will end it.
- **Unacknowledged data takes longer.** Keepalive only applies while everything sent has been acknowledged. If the peer vanishes before acknowledging the last data written to it, TCP's retransmission timeout applies instead, which is about 15 minutes on Linux. (The `TCP_USER_TIMEOUT` option could shorten this, but it would also end connections to a peer that is simply busy and not reading, so it is not used.)
- **Platform differences.** The 15 s / 15 s / 4 timings are applied on Linux, macOS and FreeBSD. Platforms without per-connection keepalive settings, such as OpenBSD, use their system-wide defaults.

The file descriptors are wrapped in a simple type as they are of type c_int and there are no guarantees that fortran integers are big enough to hold them. 

## Wire format
Values are sent as their raw in-memory bytes, with no length prefix or other framing:

- **Byte order** is the host's native order. On all mainstream platforms (x86-64, ARM, RISC-V, POWER little-endian) this is little-endian. Both ends must use the same byte order.
- **Reals** are IEEE 754; **integers** are two's complement, with the exact width of their kind.
- **Strings** are raw bytes with no terminator. `readbuffer` pads any unused part of the receiving string with blanks, not NULs.

`readbuffer` blocks until exactly `n` values have arrived, so both ends must agree in advance on the order and size of every message. For arrays and strings, `n` may be a default `integer` or an `integer(int64)`; use the latter for transfers of 2³¹ or more elements.
