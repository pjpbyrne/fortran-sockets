#!/usr/bin/env python3
import queue
import struct
import socket
import subprocess
import sys
import threading

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
wire_mismatch = threading.Event()

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
        wire_mismatch.set()
        return                            # closing makes the client's read fail
    conn.sendall(WIRE_REPLY)

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

def main():
    args = sys.argv[1:]
    wire = bool(args) and args[0] == "--wire"
    if wire:
        args = args[1:]
    if len(args) < 1:
        print(f"Usage: {sys.argv[0]} [--wire] <path_to_fortran_test_exe>", file=sys.stderr)
        sys.exit(1)

    fortran_exe = args[0]
    handler = wire_connection if wire else echo_connection

    # 1. Bind to port 0 to let OS select an available ephemeral port
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind(("127.0.0.1", 0))
    server_sock.listen(1)

    host, port = server_sock.getsockname()
    print(f"[Python Runner] Echo server listening on {host}:{port}")

    stop_event = threading.Event()
    server_thread = threading.Thread(target=run_echo_server, args=(server_sock, stop_event, handler), daemon=True)
    server_thread.start()

    try:
        # 2. Run the Fortran test executable, passing port as argument
        print(f"[Python Runner] Launching {fortran_exe} {port}...")
        try:
            result = subprocess.run(
                [fortran_exe, str(port)],
                check=False,
                text=True,
                timeout=TEST_TIMEOUT_SECONDS
            )
            test_returncode = result.returncode
        except subprocess.TimeoutExpired:
            print(f"[Python Runner] {fortran_exe} timed out after {TEST_TIMEOUT_SECONDS} s", file=sys.stderr)
            test_returncode = 1
    finally:
        # 3. Clean teardown - guaranteed to run even if subprocess crashes or aborts
        stop_event.set()
        server_sock.close()
        server_thread.join(timeout=2.0)
        print("[Python Runner] Echo server stopped.")

    if wire_mismatch.is_set() and test_returncode == 0:
        test_returncode = 1
    sys.exit(test_returncode)

if __name__ == "__main__":
    main()