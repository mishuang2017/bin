#!/usr/bin/python

from __future__ import print_function

import os
import sys
import argparse
import time
import random
from scapy.all import *

def run():
    sample_pkt1=Ether()/IP(src='1.2.3.4', dst='8.8.8.8')/TCP(sport=1234, dport=80)
    sendp(sample_pkt1, iface="p0", count=1)

    sample_pkt2=Ether()/IP(src='1.2.3.4', dst='8.8.8.8')/TCP(sport=1234, dport=81)
    sendp(sample_pkt2, iface="p0", count=1)

if __name__ == '__main__':
    run()
