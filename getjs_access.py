#!/usr/bin/env python

import re

uniques = []

read_file = open('/home/kali/ex5/access_log.txt', 'r')

for line in read_file:
    pattern = re.compile('([^/]+\.js)')
    if (match := re.search(pattern, line)) is not None:
        if (match[0] not in uniques):
            uniques += [match[0]]

uniques.sort()
for arquivo in uniques:
    print(arquivo)