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
import socket
import logging
from optparse import OptionParser, SUPPRESS_HELP

START_DELAY = 10

def ConfigLogger():
    logging.getLogger().setLevel(logging.INFO)
    logging.basicConfig(format='%(levelname)s     : %(message)s')

def Receive(ipAddress, port, packets, size, clients, max_delay, ipv6Mode):

    packetsRecived = 0
    statistics     = {}

    try:
        socketType = (socket.AF_INET, socket.AF_INET6)[ipv6Mode]
        udpSocket  = socket.socket(socketType, socket.SOCK_DGRAM, socket.IPPROTO_UDP)

        udpSocket.settimeout(START_DELAY)
        udpSocket.bind(('', port))

        while packetsRecived < (packets * len(clients)):
            (data, addr) = udpSocket.recvfrom((size, 15)[size < 15])

            if data == 'Server Ready?':
                udpSocket.sendto('Server Ready.', addr)

            elif addr[0] in clients:
                statistics[addr[0]] = statistics.get(addr[0], {'received':0, 'corrupted':0})
                statistics[addr[0]]['received']  += (0, 1)[data == ('0' * size)]
                statistics[addr[0]]['corrupted'] += (0, 1)[data != ('0' * size)]

                packetsRecived = packetsRecived  + 1;

                udpSocket.settimeout(max_delay)

    except Exception:
        pass

    finally:
        udpSocket.close()

    return statistics

def AnalyzeStats(packets, clients, successRate, statistics):

    rc = 0

    for addr, statistic in statistics.iteritems():
        rate = (float(statistic['received'] * 100) / float(packets))
        msg  = 'Client %s, %d expected datagrams, %d datagrams received, %d corrupted datagrams, %.2f%% datagrams loss'

        if rate < successRate:
            logging.error(msg % (addr, packets, statistic['received'], statistic['corrupted'], (100 - rate)))
            rc = 1

        else:
            logging.info(msg % (addr, packets, statistic['received'], statistic['corrupted'], (100 - rate)))

    for clientAddr in filter(lambda clientAddr: not statistics.has_key(clientAddr), clients):
        logging.error('Failed to receive datagrams from %s' % clientAddr)
        rc = 1

    return rc

def CreateParser():
    Usage = '''Usage: %prog [-h] -a IPADDRESS [-p PORT] [-n PACKETS] [-s SIZE] -c
                    CLIENTS [CLIENTS ...] [-t MAX_DELAY] [-r SUCCESSRATE]'''

    optionParser = OptionParser(Usage)
    optionParser.add_option('-a', '--ipAddress'  , help='Multicast address')
    optionParser.add_option('-p', '--port'       , help='Multicast Port (default: %default)', type=int, default=19000)
    optionParser.add_option('-n', '--packets'    , help='Number of packets to transmit (default: %default)', type=int, default=50)
    optionParser.add_option('-s', '--size'       , help='Messages size (default: %default)', type=int, default=50)
    optionParser.add_option('-c', '--clients'    , help='Expected clients IPs [CLIENTS ...]', type="string", action="callback", callback=nargsParser)
    optionParser.add_option('-t', '--max_delay'  , help='Max number of seconds to wait between receives (default: Infinite)', type=float, default=None)
    optionParser.add_option('-r', '--successRate', help='Success rate (default: %default)', type=float, default=100)
    optionParser.add_option('-V', '--ipv6Mode'   , help=SUPPRESS_HELP)

    return optionParser

def nargsParser(option, opt_str, value, parser):
    parser.values.clients = map(lambda val: val.strip(), value.split())

def ParseArgs(optionParser, args=[]):
    try:
        args = optionParser.parse_args(args)[0]

        if args.ipAddress == None:
            optionParser.print_usage()
            print '%s: error: argument -a/--ipAddress is required' % os.path.basename(__file__)
            sys.exit(1)

        if args.clients in [None, []]:
            optionParser.print_usage()
            print '%s: error: argument -c/--clients is required' % os.path.basename(__file__)
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

        args       = ParseArgs(CreateParser(), sys.argv[1:])
        statistics = Receive(args.ipAddress, args.port, args.packets, args.size, args.clients, args.max_delay, args.ipv6Mode)
        resulte    = AnalyzeStats(args.packets, args.clients, args.successRate, statistics)

    except Exception, e:
        logging.error(str(e))
        sys.exit(1)

    sys.exit(resulte)
