#!/usr/bin/env python3
import queue
import struct
import socket
import subprocess
import sys
import threading
import time

# Fail a test that hangs (e.g. waiting for bytes that never arrive) instead of
# blocking until CTest's 1500 s default timeout
TEST_TIMEOUT_SECONDS = 60

def echo_connection(conn):
    """Echo everything received on conn back to it until the client closes.

    A reader thread drains the client continuously into a queue while this
    thread writes it back with blocking sends. Because the server never stops
    reading, a client that writes a large message before reading the echo
    cannot deadlock against it, and no data is ever dropped.
    """
    chunks = queue.Queue()

    def reader():
        try:
            while True:
                data = conn.recv(1 << 20)
                if not data:
                    break
                chunks.put(data)
        except OSError:
            pass
        chunks.put(None)                  # end of stream

    reader_thread = threading.Thread(target=reader, daemon=True)
    reader_thread.start()
    try:
        while (data := chunks.get()) is not None:
            conn.sendall(data)
    except OSError:
        pass
    reader_thread.join()

# --wire mode: the exact bytes test_wire.f90 must send, and the bytes the
# server replies with. Native byte order ('='), standard sizes.
WIRE_EXPECTED = (struct.pack("=i", 42) + struct.pack("=q", 9876543210)
                 + struct.pack("=f", 1.5) + struct.pack("=d", -2.25)
                 + b"abc" + struct.pack("=3i", 1, 2, 3))
WIRE_REPLY = (struct.pack("=i", -7) + struct.pack("=q", 2**40)
              + struct.pack("=d", 0.125) + b"xyz")

# Set by a server mode to fail the test even if the Fortran program exits 0
server_failure = threading.Event()

def wire_connection(conn):
    """Check that the client sent exactly WIRE_EXPECTED, then send WIRE_REPLY."""
    received = b""
    while len(received) < len(WIRE_EXPECTED):
        data = conn.recv(len(WIRE_EXPECTED) - len(received))
        if not data:
            break
        received += data
    if received != WIRE_EXPECTED:
        print(f"[Python Runner] wire mismatch:\n  expected {WIRE_EXPECTED.hex()}\n  received {received.hex()}",
              file=sys.stderr)
        server_failure.set()
        return                            # closing makes the client's read fail
    conn.sendall(WIRE_REPLY)

def close_connection(conn):
    """--close: hang up straight away, so the client sees a closed peer."""

# --eof-check: the client must close its end within this many seconds
EOF_LIMIT_SECONDS = 2.0

def eof_check_connection(conn):
    """Fail unless the client's close is seen promptly (e.g. not held open
    by a child process that inherited the socket)."""
    start = time.monotonic()
    try:
        while conn.recv(65536):
            pass
    except OSError:
        pass
    elapsed = time.monotonic() - start
    print(f"[Python Runner] client close seen after {elapsed:.2f} s")
    if elapsed > EOF_LIMIT_SECONDS:
        print(f"[Python Runner] expected within {EOF_LIMIT_SECONDS} s", file=sys.stderr)
        server_failure.set()

MODES = {
    None: echo_connection,
    "--wire": wire_connection,
    "--close": close_connection,
    "--eof-check": eof_check_connection,
    "--no-listen": None,                  # nothing listens on the port: connect is refused
}
connection_done = threading.Event()

def run_echo_server(sock, stop_event, handler):
    sock.settimeout(0.5)                  # only so the accept loop can see stop_event
    while not stop_event.is_set():
        try:
            conn, _ = sock.accept()
        except socket.timeout:
            continue
        except OSError:
            break

        with conn:
            conn.settimeout(None)         # blocking: a timeout here could drop data
            # Echo each chunk immediately; with Nagle on, a second small echo
            # would wait for the client's delayed ACK (several ms per exchange)
            conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            handler(conn)
        connection_done.set()

def main():
    args = sys.argv[1:]
    mode = args.pop(0) if args and args[0].startswith("--") else None
    if mode not in MODES or not args:
        print(f"Usage: {sys.argv[0]} [{'|'.join(m for m in MODES if m)}] "
              "<path_to_fortran_test_exe> [extra args...]", file=sys.stderr)
        sys.exit(1)

    fortran_exe, extra_args = args[0], args[1:]

    # 1. Listen on an address that "localhost" (which the tests connect to)
    #    resolves to: IPv4 or IPv6. Port 0 lets the OS pick a free port.
    family, _, _, _, address = socket.getaddrinfo("localhost", 0, type=socket.SOCK_STREAM)[0]
    server_sock = socket.socket(family, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind(address)
    host, port = server_sock.getsockname()[:2]

    stop_event = threading.Event()
    server_thread = None
    if mode == "--no-listen":
        server_sock.close()               # keep the port number, but nothing listens on it
        print(f"[Python Runner] Nothing listening on {host}:{port}")
    else:
        server_sock.listen(1)
        print(f"[Python Runner] Server ({mode or 'echo'}) listening on {host}:{port}")
        server_thread = threading.Thread(target=run_echo_server, args=(server_sock, stop_event, MODES[mode]),
                                         daemon=True)
        server_thread.start()

    try:
        # 2. Run the Fortran test executable, passing the port (and any extra arguments)
        print(f"[Python Runner] Launching {fortran_exe} {port} {' '.join(extra_args)}")
        try:
            result = subprocess.run(
                [fortran_exe, str(port), *extra_args],
                check=False,
                text=True,
                timeout=TEST_TIMEOUT_SECONDS
            )
            test_returncode = result.returncode
        except subprocess.TimeoutExpired:
            print(f"[Python Runner] {fortran_exe} timed out after {TEST_TIMEOUT_SECONDS} s", file=sys.stderr)
            test_returncode = 1
        if mode == "--eof-check" and not connection_done.wait(timeout=10.0):
            print("[Python Runner] client close never seen", file=sys.stderr)
            server_failure.set()
    finally:
        # 3. Clean teardown - guaranteed to run even if subprocess crashes or aborts
        stop_event.set()
        if server_thread is not None:
            server_sock.close()
            server_thread.join(timeout=2.0)
        print("[Python Runner] Server stopped.")

    if server_failure.is_set() and test_returncode == 0:
        test_returncode = 1
    sys.exit(test_returncode)

if __name__ == "__main__":
    main()