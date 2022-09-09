#!/usr/bin/env python3

import os

for ip in range(1,255):
    ip = str(ip)
    ip = "10.11.1." + ip
    response = os.system("ping -c 1 " + ip + " > /dev/null 2>&1")
    if response == 0:
        print(ip, "is up")
    else:
        print(ip, "is down")