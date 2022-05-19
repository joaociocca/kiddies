#!/usr/bin/env python3

import subprocess, platform, sys

host = sys.argv[1]
bottom = int(sys.argv[2])
top = int(sys.argv[3])
top += 1

param = "-n" if platform.system().lower()=='windows' else '-c'

for ip in range(bottom,top):
        target = host+"."+str(ip)
#       print("Target: "+target)
        command = ['ping', param, '1', target]
#       print(command)
        # subprocess.call(command)
        if subprocess.call(command,stdout=subprocess.DEVNULL,stderr=subprocess.STDOUT) == 0:
                print(target)