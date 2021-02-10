#!/usr/bin/python2.7

import re
import sys
import string

if len(sys.argv) == 1:
	exit()

argv1 = sys.argv[1]

if re.match('^(0x|0X)', argv1) or re.search('([a-fA-F]+)', argv1):
        i = string.atoi(argv1, base=16)
elif re.match('^\d+$', argv1):
        i = string.atoi(argv1, base=10)
else:
        print "Error input!"
        exit()

r=''
n = 0x80000000

while n:
        r += '1' if n & i else '0'

        if len(re.sub(' ', '', r)) % 4 == 0:
                r += ' '

        n >>= 1

print '0x%x = %d = %.2fK =' % (i, i, i / 1024.0),
print '%.2fM = %.2fG' % (i / 1024.0 ** 2.0, i / 1024.0 ** 3.0)
print r
