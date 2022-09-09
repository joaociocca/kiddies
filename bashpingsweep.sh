#!/usr/bin/env bash

base=$1

for ip in {1..254}; do
    if ping -c 1 "$base"."$ip" &> /dev/null; then
        echo "$base.$ip is up"
    fi
done