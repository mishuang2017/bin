#!/usr/bin/env python
# Author:  Alon Liber - alonli@mellanox.com
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

import re
import os
import sys
import time
import socket
import logging
from optparse import OptionParser, SUPPRESS_HELP

RECONNECT_ATTEMPTS = 10

def ConfigLogger():
    logging.getLogger().setLevel(logging.INFO)
    logging.basicConfig(format='%(levelname)s     : %(message)s')

def Send(ipAddress, port, packets, size, sleep, ipv6Mode):

    rc = 0

    try:
        socketType = (socket.AF_INET, socket.AF_INET6)[ipv6Mode]

        for i in range(RECONNECT_ATTEMPTS):
            tcpSocket = socket.socket(socketType, socket.SOCK_STREAM, False)
            tcpSocket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, True)
            tcpSocket.settimeout(1)

            try:
                tcpSocket.connect((ipAddress, port))
                break

            except Exception:
                if i == (RECONNECT_ATTEMPTS - 1):
                    raise

                else:
                    tcpSocket.close()

                time.sleep(1)

        tcpSocket.settimeout(None)

        for i in range(1, packets + 1):
            data = '0' * (size - len(str(i))) + str(i)[-size:]
            tcpSocket.sendto(data, (ipAddress, port))
            time.sleep(sleep)

    except Exception:
        rc = 1

    finally:
        tcpSocket.close()

    return rc

def CreateParser():
    Usage =  '''Usage: %prog [-h] --ipAddress IPADDRESS [-p PORT] [-n PACKETS]
                    [-s SIZE] [-S SLEEP]'''

    optionParser = OptionParser(Usage)
    optionParser.add_option('-i', '--ipAddress' , help='Server IP address')
    optionParser.add_option('-p', '--port'      , help='Multicast Port (default: %default)', type=int, default=19000)
    optionParser.add_option('-n', '--packets'   , help='Number of packets to transmit (default: %default)', type=int, default=50)
    optionParser.add_option('-s', '--size'      , help='Messages size (default: %default)', type=int, default=50)
    optionParser.add_option('-S', '--sleep'     , help='Sleep time before send (default: %default)', type=float, default=0.05)
    optionParser.add_option('-V', '--ipv6Mode'  , help=SUPPRESS_HELP)

    return optionParser

def ParseArgs(optionParser, args=[]):
    try:
        args = optionParser.parse_args(args)[0]

        if args.ipAddress == None:
            optionParser.print_usage()
            print '%s: error: argument -i/--ipAddress is required' % os.path.basename(__file__)
            sys.exit(1)

        if args.size < 1:
            optionParser.print_usage()
            print '%s: error: argument -s/--size must be positive' % os.path.basename(__file__)
            sys.exit(1)

        if re.match('\d+\.\d+\.\d+\.\d+', args.ipAddress):
            args.ipv6Mode = False

        elif re.match('[0-9a-fA-F:]+', args.ipAddress):
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
        rc     = Send(args.ipAddress, args.port, args.packets, args.size, args.sleep, args.ipv6Mode)

    except Exception, e:
        logging.error(str(e))
        sys.exit(1)

    sys.exit(rc)
