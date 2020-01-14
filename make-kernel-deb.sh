#!/bin/bash

make distclean
cp ~chrism/config.bytedance .config
make olddefconfig
make deb-pkg -j 32
