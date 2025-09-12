#!/usr/bin/env python

from sys import argv

mapping = {}
with open(argv[1]) as f:
    f.readline()
    for line in f:
        ss = line.split()
        if len(ss)<4: continue
        left = ss[2]
        right = ss[3]
        mapping[left] = right

removed = set()
with open(argv[1]) as f:
    print(f.readline().strip('\n'))
    for line in f:
        ss = line.split()
        if len(ss)<4:
            print(line.strip('\n'))
            continue
        map_out = ss[3]
        if ss[2] in removed: continue
        while True:
            if map_out not in mapping: break
            removed.add(map_out)
            map_out = mapping[map_out]
        print(f"{ss[0]}    {ss[1]} {ss[2]}     {map_out}")