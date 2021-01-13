#!/bin/bash

make distclean
cp ~cmi/bd-kernel.config.vm .config
make olddefconfig
make deb-pkg -j 32
