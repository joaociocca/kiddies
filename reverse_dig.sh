#!/usr/bin/env bash

for ip in {1..254}; do 
    if respostas=$(dig @192.168.135.254 -x 192.168.135."${ip}" | sed -n -r 's#.*ANSWER: ([0-9]+).*#\1#p'); then
        echo "192.168.135.${ip} - ${respostas}"
    fi
done