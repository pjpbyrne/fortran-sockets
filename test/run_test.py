#!/usr/bin/env python3
import socket
import subprocess
import sys
import threading

# Fail a test that hangs (e.g. waiting for bytes that never arrive) instead of
# blocking until CTest's 1500 s default timeout
TEST_TIMEOUT_SECONDS = 60

def run_echo_server(sock, stop_event):
    sock.settimeout(0.5)
    while not stop_event.is_set():
        try:
            conn, _ = sock.accept()
        except socket.timeout:
            continue
        except OSError:
            break

        with conn:
            conn.settimeout(0.5)
            while not stop_event.is_set():
                try:
                    data = conn.recv(4096)
                    if not data:
                        break
                    conn.sendall(data)
                except socket.timeout:
                    continue
                except OSError:
                    break

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <path_to_fortran_test_exe>", file=sys.stderr)
        sys.exit(1)

    fortran_exe = sys.argv[1]

    # 1. Bind to port 0 to let OS select an available ephemeral port
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind(("127.0.0.1", 0))
    server_sock.listen(1)

    host, port = server_sock.getsockname()
    print(f"[Python Runner] Echo server listening on {host}:{port}")

    stop_event = threading.Event()
    server_thread = threading.Thread(target=run_echo_server, args=(server_sock, stop_event))
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

    sys.exit(test_returncode)

if __name__ == "__main__":
    main()