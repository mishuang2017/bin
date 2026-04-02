#!/usr/bin/python3

import re
import sys

if len(sys.argv) == 1:
    exit()

argv1 = sys.argv[1]

# 修复：正则加 r 前缀（原始字符串），消除转义警告
if re.match(r'^0x[0-9a-fA-F]+$', argv1):  # 严格匹配十六进制
    i = int(argv1, base=16)
elif re.match(r'^\d+$', argv1):  # 严格匹配十进制
    i = int(argv1, base=10)
else:
    print("Error input!")
    exit()

r = ''
n = 0x80000000  # 固定32位二进制

while n:
    r += '1' if n & i else '0'

    # 每4位加空格
    if len(r.replace(' ', '')) % 4 == 0:
        r += ' '

    n >>= 1

# 输出结果
print('0x%x = %d = %.2fK =' % (i, i, i / 1024.0), end=' ')
print('%.2fM = %.2fG' % (i / 1024.0 ** 2.0, i / 1024.0 ** 3.0))
print(r)
