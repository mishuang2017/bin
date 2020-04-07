#!/bin/bash

make distclean
# cp ~chrism/config.bytedance .config
cp ~chrism/sm/config/config-5.4.19-100.fc30.x86_64 .config
make olddefconfig
make deb-pkg -j 32
