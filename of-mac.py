#!/usr/bin/python3

"""
of-mac.py - a script to generate openflow rule file

Copyright (C) 2017 Chris Mi <chrism@mellanox.com>
"""

import argparse

parser = argparse.ArgumentParser(description='TC batch file generator')
parser.add_argument("file", help="batch file name")
parser.add_argument("-n", "--number", type=int,
                    help="how many lines in batch file")
args = parser.parse_args()

file = open(args.file, 'w')

number = 1
if args.number:
    number = args.number

index = 0
for i in range(0x100):
    for j in range(0x100):
        for k in range(0x100):
            mac = ("%02x:%02x:%02x" % (i, j, k))
            mac = "24:00:00:" + mac
#             cmd = ("table=0,priority=10,ip,dl_src=02:25:d0:13:01:02,dl_dst=%s,in_port=enp4s0f0_1,action=output:enp4s0f0" % mac)
#             file.write("%s\n" % cmd)
            cmd = ("table=0,priority=10,ip,dl_dst=02:25:d0:13:01:02,dl_src=%s,in_port=enp4s0f0,action=output:enp4s0f0_1" % mac)
            file.write("%s\n" % cmd)
            index += 1
            if index >= number:
                file.close()
                exit(0)
