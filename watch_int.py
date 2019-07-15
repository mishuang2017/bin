#!/bin/env python

#
# Copyright (C) 2012 Roi Dayan <roid@mellanox.com>
#

# Argument can be one of [irq num | txt | ALL]

import sys
import os
import time


__version__ = "0.3"


if len(sys.argv) > 1:
    req = sys.argv[1]
else:
    req = 'ALL'


def read_int(req):
    last_inf = {}
    while True:
        f = open('/proc/interrupts')
        d = f.read().splitlines()
        f.close()
        os.system('clear')

        cpus = d[0].split()
        for i in cpus:
            i = i.strip('CPU')
            print "%3s" % i,
        print
        print '-'*70

        for line in d[1:]:
            inf = line.split()
            irq = inf[0].strip(':')
            inf = inf[1:]
            txt = ' '.join(inf[len(cpus):])
            inf = inf[0:len(cpus)]
            if req == 'ALL' or irq == req or (len(req) > 2 and txt.find(req) >= 0):
                if irq not in last_inf:
                    last_inf[irq] = inf
                    continue
                cur_inf = []
                p = False
                for i in range(len(inf)):
                    c = int(inf[i]) - int(last_inf[irq][i])
                    if c != 0:
                        p = True
                    cur_inf += [c]
                if p:
                    for i in cur_inf:
                        print "%3d" % i,
                    print irq, txt
                last_inf[irq] = inf
        if not last_inf:
            print 'no data'
            break
        print '-'*70
        time.sleep(1)

try:
    read_int(req)
except KeyboardInterrupt:
    print
    pass
