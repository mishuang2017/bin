#!/usr/bin/python3

"""
tdc_batch.py - a script to generate TC batch file

Copyright (C) 2017 Chris Mi <chrism@mellanox.com>
"""

import argparse

parser = argparse.ArgumentParser(description='TC batch file generator')
parser.add_argument("file", help="batch file name")
parser.add_argument("-n", "--number", type=int,
                    help="how many lines in batch file")
parser.add_argument("-d", "--delete",
                    help="delete, by default add",
                    action="store_true")
args = parser.parse_args()

file = open(args.file, 'w')

number = 1
if args.number:
    number = args.number

op = "add"
if args.delete:
    op = "delete"

index = 0
for i in range(1, 0x1000000):
    cmd = ("action %s action ok index %d" % (op, i))
    file.write("%s\n" % cmd)
    index += 1
    if index >= number:
        file.close()
        exit(0)
