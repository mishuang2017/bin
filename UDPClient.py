#!/usr/bin/env python
# Author:  Moran Shukrun - morans@mellanox.com

# --
# Copyright (c) 2012-2013 Mellanox Technologies. All rights reserved.
#
# This software is available to you under a choice of one of two
# licenses.  You may choose to be licensed under the terms of the GNU
# General Public License (GPL) Version 2, available from the file
# COPYING in the main directory of this source tree, or the
# OpenIB.org BSD license below:
#
#     Redistribution and use in source and binary forms, with or
#     without modification, are permitted provided that the following
#     conditions are met:
#
#      - Redistributions of source code must retain the above
#        copyright notice, this list of conditions and the following
#        disclaimer.
#
#      - Redistributions in binary form must reproduce the above
#        copyright notice, this list of conditions and the following
#        disclaimer in the documentation and/or other materials
#        provided with the distribution.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import os
import re
import sys
import time
import socket
import logging
from optparse import OptionParser, SUPPRESS_HELP

#Number of reconnect attempts (Wait 0.2 sec between each reconnect failure, total of 10 sec).
MAX_RECONNECT = 50

def ConfigLogger():
    logging.getLogger().setLevel(logging.INFO)
    logging.basicConfig(format='%(levelname)s     : %(message)s')

def Send(serverAddr, port, packets, size, sleep, ipv6Mode):

    rc = 0

    try:
        socketType = (socket.AF_INET, socket.AF_INET6)[ipv6Mode]
        udpSocket  = socket.socket(socketType, socket.SOCK_DGRAM, socket.IPPROTO_UDP)

        udpSocket.settimeout(0.2)

        if GetServerStatus(udpSocket, serverAddr, port):

            for _ in range(packets):
                udpSocket.sendto('0' * size, (serverAddr, port))
                time.sleep (sleep)

        else:
            logging.error("Failed to connect to server %s." % serverAddr)
            rc = 1

    finally:
        udpSocket.close()

    return rc

def GetServerStatus(udpSocket, serverAddr, port):
    for _ in range(MAX_RECONNECT):
        try:
            udpSocket.sendto('Server Ready?', (serverAddr, port))

            (data, addr) = udpSocket.recvfrom(15)

            if addr[0] == serverAddr and data == 'Server Ready.':
                return True

        except Exception, e:
            # Exception with error number 10054 due to an existing connection was forcibly closed by the remote host, try to reconnect after 0.2 sec
            if e.errno == 10054:
                time.sleep(0.2)

            pass

    return False

def CreateParser():
    Usage =  '''Usage: %prog [-h] -i SERVERADDR [-s SIZE] [-p PORT]
                    [-S SLEEP] [-n PACKETS]'''

    optionParser = OptionParser(Usage)
    optionParser.add_option('-I', '--serverAddr', help='Server IP address')
    optionParser.add_option('-p', '--port'      , help='Multicast Port (default: %default)', type=int, default=19000)
    optionParser.add_option('-n', '--packets'   , help='Number of packets to transmit (default: %default)', type=int, default=50)
    optionParser.add_option('-s', '--size'      , help='Messages size (default: %default)', type=int, default=50)
    optionParser.add_option('-S', '--sleep'     , help='Sleep time before send (default: %default)', type=float, default=0.05)
    optionParser.add_option('-V', '--ipv6Mode'  , help=SUPPRESS_HELP)

    return optionParser

def ParseArgs(optionParser, args=[]):
    try:
        args = optionParser.parse_args(args)[0]

        if args.serverAddr == None:
            optionParser.print_usage()
            print '%s: error: argument -I/--serverAddr is required' % os.path.basename(__file__)
            sys.exit(1)

        if args.size < 1:
            optionParser.print_usage()
            print '%s: error: argument -s/--size must be positive' % os.path.basename(__file__)
            sys.exit(1)

        if re.match('\d+\.\d+\.\d+\.\d+', args.serverAddr):
            args.ipv6Mode = False

        elif re.match('[0-9a-fA-F:]+', args.serverAddr):
            args.ipv6Mode = True

        else:
            raise RuntimeError, 'Ilegal IP address\n'

    except Exception, e:
        raise RuntimeError , 'Failed to parse arguments\n%s' % str(e)

    return args

if __name__ == "__main__":
    try:
        ConfigLogger()

        parser = CreateParser()
        args   = ParseArgs(parser, sys.argv[1:])
        rc     = Send(args.serverAddr, args.port, args.packets, args.size, args.sleep, args.ipv6Mode)

    except Exception, e:
        logging.error(str(e))
        sys.exit(1)

    sys.exit(rc)
