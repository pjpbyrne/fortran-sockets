#!/usr/bin/env python3
import socket

# Define the host and port to listen on
# '0.0.0.0' listens on all available network interfaces
HOST = '0.0.0.0'  
PORT = 65432

# Create a TCP socket
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    # Allow immediate reuse of the port after stopping the server
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    # Bind the socket to the address and port
    s.bind((HOST, PORT))
    
    # Start listening for incoming connections
    s.listen()
    print(f"Python:- Server is listening on {HOST}:{PORT}...")
    
    # Accept a connection (blocks until a client connects)
    conn, addr = s.accept()
    with conn:
        print(f"Python:- Connected successfully by {addr}")
        
        # Loop to receive and echo back data
        while True:
            data = conn.recv(1024)
            if not data:
                break # Client disconnected
            
            print(f"Python:- Received: {data}")
            conn.sendall(data) # Echo the data back to the client
