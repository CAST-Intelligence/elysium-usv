#!/usr/bin/env python3
"""Simple script to test FTP connection"""

import socket
import time
import sys

def test_connection(host, port):
    """Test TCP connection to host:port"""
    print(f"Testing connection to {host}:{port}...")
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((host, port))
        if result == 0:
            print(f"Successfully connected to {host}:{port}")
            # Try to read the FTP welcome message
            try:
                data = sock.recv(1024).decode()
                print(f"Received: {data}")
            except Exception as e:
                print(f"Error receiving data: {e}")
        else:
            print(f"Could not connect to {host}:{port}, result code: {result}")
        sock.close()
    except Exception as e:
        print(f"Connection test failed: {e}")

if __name__ == "__main__":
    # Default values
    host = "localhost"
    port = 21
    
    # Check if arguments were provided
    if len(sys.argv) > 1:
        host = sys.argv[1]
    if len(sys.argv) > 2:
        port = int(sys.argv[2])
    
    # Test connection
    test_connection(host, port)