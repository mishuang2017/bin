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
import socket
import logging
from Queue import Queue
from threading import Thread
from optparse import OptionParser, SUPPRESS_HELP

START_DELAY = 10

def ConfigLogger():
    logging.getLogger().setLevel(logging.INFO)
    logging.basicConfig(format='%(levelname)s     : %(message)s')

def RunServer(ipAddress, port, clients, packets, size, max_delay, successRate, ipv6Mode):

    threads          = []
    connectedClients = []
    queue            = Queue()

    try:
        socketType = (socket.AF_INET, socket.AF_INET6)[ipv6Mode]
        tcpSocket  = socket.socket(socketType, socket.SOCK_STREAM, False)

        tcpSocket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, True)
        tcpSocket.settimeout(START_DELAY)
        tcpSocket.bind((ipAddress, port))
        tcpSocket.listen(len(clients))

        for _ in range(len(clients)):
            cSocket   = tcpSocket.accept()
            arguments = (cSocket, packets, size, max_delay, successRate, queue)
            thread    = Thread(target=ClientHandler, args=arguments)

            connectedClients.append(cSocket[1][0])

            thread.start()
            threads.append(thread)

    except Exception:
        rc = 1

    finally:
        [thread.join() for thread in threads]

        rc = [queue.get() for _ in range(queue.qsize())]
        rc = reduce(lambda rc1, rc2: rc1 + rc2, [0] + rc)

        tcpSocket.close()

    for client in filter(lambda client: client not in connectedClients, clients):
        logging.error('Failed to receive packets from %s' % client)
        rc = 1

    return rc

def ClientHandler (clientSocket, packets, size, max_delay, successRate, queue):
    rc         = 0
    tcpSocket  = clientSocket[0]
    peerName   = clientSocket[1][0]
    statistics = {'received':0, 'corrupted':0, 'outOfOrder':0}

    tcpSocket.settimeout(START_DELAY)

    try:
        for i in range(1, packets + 1):
            expectedData = '0' * (size - len(str(i))) + str(i)[-size:]
            actualData   = tcpSocket.recvfrom(size)[0]

            while len(actualData) != size and actualData:
                actualData += tcpSocket.recvfrom(size - len(actualData))[0]

            try:
                if int(actualData) != int(expectedData):
                    statistics['outOfOrder'] += 1

                elif actualData != expectedData:
                    statistics['corrupted'] += 1

            except Exception:
                statistics['corrupted'] += 1

            statistics['received'] += 1

            tcpSocket.settimeout(max_delay)

    except Exception:
        pass

    finally:
        tcpSocket.shutdown(socket.SHUT_RDWR)
        tcpSocket.close()

    rate = (float(statistics['received']) * 100 / float(packets))
    msg  = 'Client %s, %d packets expected, %d packets received, %d/%d packets corrupted, %d/%d packets out of order, %.2f%% packets loss'

    if rate < successRate or (statistics['corrupted'] or statistics['outOfOrder']):
        logging.error(msg % (peerName, packets, statistics['received'], statistics['corrupted'], statistics['received'], statistics['outOfOrder'], statistics['received'], (100 - rate)))
        rc = 1

    else:
        logging.info(msg % (peerName, packets, statistics['received'], statistics['corrupted'], statistics['received'], statistics['outOfOrder'], statistics['received'], (100 - rate)))

    queue.put(rc)

def CreateParser ():
    Usage =  '''Usage: %prog [-h] --ipAddress IPADDRESS -c CLIENTS [CLIENTS ...]
                    [-p PORT] [-s SIZE] [-n PACKETS] [-t MAX_DELAY] [-r SUCCESSRATE]'''

    optionParser = OptionParser(Usage)
    optionParser.add_option('-i', '--ipAddress'  , help='TCP address')
    optionParser.add_option('-p', '--port'       , help='TCP Port (default: %default)', type=int, default=19000)
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
            print '%s: error: argument -i/--ipAddress is required' % os.path.basename(__file__)
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

        parser = CreateParser()
        args   = ParseArgs(parser, sys.argv[1:])
        rc     = RunServer(args.ipAddress, args.port, args.clients, args.packets, args.size, args.max_delay, args.successRate, args.ipv6Mode)

    except Exception, e:
        logging.error(str(e))
        sys.exit(1)

    sys.exit(rc)
