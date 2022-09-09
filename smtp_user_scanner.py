#!/usr/bin/env python

import re
import socket
import sys

if len(sys.argv) != 2:
        print("Usage: vrfy.py <username>")
        sys.exit(0)

read_file = open(sys.argv[1], 'r')

servers = [
    "10.11.1.72",
    "10.11.1.115",
    "10.11.1.217",
    "10.11.1.227",
    "10.11.1.229",
    "10.11.1.231"
]

for server in servers:
    read_file.seek(0)
    # Create a Socket
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    print("Scanning server {}".format(server))
    # Connect to the Server
    connect = s.connect((server,25))

    # Receive the banner
    banner = s.recv(1024)

    print(banner.decode().strip('\r\n'))

    #VRFY loop!
    for line in read_file:
#        print("Username: {}".format(line))
        # VRFY a user
        query = str.encode('VRFY '+ line)
        s.send(query)
        try:
            result = s.recv(1024)
            pattern = re.compile('^252.+')
            if (match := re.search(pattern, result.decode())) is not None:
                print("User ",line.strip('\n')," is valid")
            else:
#                print("User invalid")
                pass
        except socket.timeout:
#            print("Attempt timedout!")
            pass

    # Close the socket
    s.close()

┌──(kali㉿kali)-[~/lab]