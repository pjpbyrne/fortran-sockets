# Pre-generated sockets

This is the preprocessed source ready to be used directly in a project.

## sockets.c
This file contains the underlying c code that directly deals with reading and writing bytes to the streams. It also handles correctly opening and closing connections. 

## tcpsockets.f90
This is are the interfaces that you should call from fortran. It contains a lot of routines, one for every flavour of basic type and also for arrays of those types (except arrays of strings. An example of using these would be

```fortran
type(socket_handle) :: socket
character(len=100)  :: return_data

call open_socket(socket, 8080, 'localhost')
call writebuffer(socket, 'hello', 5)
call readbuffer(socket, return_data, 5)   ! reads exactly 5 bytes; rest blank-padded
call close_socket(socket)
```

A handle must be closed with `close_socket` before it is reused; calling `open_socket` on a handle that is still open stops the program.

### Small writes and `nodelay`
By default `open_socket` sets `TCP_NODELAY`, so every `writebuffer` call is sent immediately. This matters for request/response exchanges. Without it, TCP's Nagle algorithm holds back a second small write until the first is acknowledged. The peer, still waiting for the rest of the message, delays that acknowledgement, so a pattern such as *write length prefix, write payload, read reply* stalls for about 40 ms on every round trip.

The cost is that each `writebuffer` call becomes its own packet. Sending many separate scalars is therefore slower than sending them as one array, so batch small values into arrays where you can. If a program only streams many small writes with no replies, it can let TCP coalesce them instead:

```fortran
call open_socket(socket, 8080, 'localhost', nodelay=.false.)
```

The peer's side matters too. If it replies with several small writes, it should also disable Nagle, or send each reply in one write.

## Wire format
Values are sent as their raw in-memory bytes, with no length prefix or other framing:

- **Byte order** is the host's native order. On all mainstream platforms (x86-64, ARM, RISC-V, POWER little-endian) this is little-endian. Both ends must use the same byte order.
- **Reals** are IEEE 754; **integers** are two's complement, with the exact width of their kind.
- **Strings** are raw bytes with no terminator. `readbuffer` pads any unused part of the receiving string with blanks, not NULs.

`readbuffer` blocks until exactly `n` values have arrived, so both ends must agree in advance on the order and size of every message.

## Talking to Python
Decode with explicit little-endian formats. Use `<` (or `=` for native), never `!`, which means big-endian network order:

| Fortran  | `struct` | numpy   |
|----------|----------|---------|
| `int32`  | `'<i'`   | `'<i4'` |
| `int64`  | `'<q'`   | `'<i8'` |
| `real32` | `'<f'`   | `'<f4'` |
| `real64` | `'<d'`   | `'<f8'` |

Strings arrive as bytes: use `data.decode('ascii').rstrip()` to drop Fortran's blank padding.

TCP is a byte stream, so a Python receiver gets data in arbitrary chunks and must buffer until a whole message has arrived. With [Twisted](https://twisted.org/), a simple way is to send an `int32` byte count before each message and use `Int32StringReceiver`. Its default prefix is big-endian, so override `structFormat`:

```python
from twisted.protocols.basic import Int32StringReceiver
import numpy as np

class FortranProtocol(Int32StringReceiver):
    structFormat = "<i"          # Fortran int32, little-endian (default "!I" is big-endian)

    def stringReceived(self, data):
        values = np.frombuffer(data, dtype="<f8")
        reply = (values * 2).astype("<f8").tobytes()
        self.sendString(reply)   # sends <i length prefix + payload
```

```fortran
integer(int32) :: nbytes

call writebuffer(sock, int(8*n, int32))   ! length prefix in bytes
call writebuffer(sock, x, n)              ! x is real(real64)
call readbuffer(sock, nbytes)             ! int32 prefix from Twisted
call readbuffer(sock, y, nbytes/8)
```

The Fortran side can only connect, so the Python side must be the server. If the server closes the connection while Fortran is waiting for data, the Fortran program stops with an error.
