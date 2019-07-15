#!/bin/bash

#========================================================================================
# Imports
# -------
#========================================================================================
source ~mi/adi/colors.sh
source ~mi/adi/general_funcs.sh

LINUX_DIR=/home1/mi/rpmbuild/BUILD/kernel-3.10.0-693.21.1.el7/linux-3.10.0-693.21.1.el7.x86_64
MOFED_DIR=/home1/chrism/mlnx-ofa_kernel-4.5

#========================================================================================
# Functions
# ---------
#========================================================================================
fCopy_h_c_files(){
    local _fromDir=$1
    local _toDir=$2
    echo "copy from $_fromDir to $_toDir *.h & *.c files"
    cd ${LINUX_DIR}
    if [ -d "${_toDir}" ]; then
        echo "Dir $_toDir exist"
    else
        fDoCommand "mkdir ${_toDir}"
    fi
    (cd ${_fromDir} && find . -name '*.h' -print | tar --create --files-from -) | (cd ${_toDir} && tar xvfp -)
    (cd ${_fromDir} && find . -name '*.c' -print | tar --create --files-from -) | (cd ${_toDir} && tar xvfp -)
}

fRemoveDir(){
    local _dir=$1
    if [ -d "$_dir" ]; then
        fDoCommand "rm -rf $_dir"
    fi
}
#========================================================================================
# Main
# -------
#========================================================================================

#configure
#cd ${LINUX_DIR}
#git c 4.4.52-mlnx-asap-v3
#./rebuild_nvidia_with_driver.sh
#git c ${branch_with_ofed}
#cd ${MOFED_DIR}
#export KBUILD_OUTPUT="/adin/code/upstream/build/"; ./configure -j32 --with-mlx5-core-and-en-mod --kernel-version=4.4.52+ --modules-dir=$KBUILD_OUTPUT --kernel-sources=$KBUILD_OUTPUT/source --with-linux=$KBUILD_OUTPUT/source --with-linux-obj=$KBUILD_OUTPUT
#make -j23

mkdir -p ${LINUX_DIR}/mofed
if [ -d "${LINUX_DIR}/mofed" ]; then
    fDoCommand "rm -rf ${LINUX_DIR}/mofed"
    fDoCommand "mkdir ${LINUX_DIR}/mofed"
fi

fRemoveDir "${LINUX_DIR}/drivers/net/ethernet/mellanox/mlxfw/"
fRemoveDir "${LINUX_DIR}/drivers/net/ethernet/mellanox/mlx5/core/"

fDoCommand "git reset --hard HEAD"
fDoCommand "git status"

fCopy_h_c_files "${MOFED_DIR}/compat/" "${LINUX_DIR}/mofed/compat"
fCopy_h_c_files "${MOFED_DIR}/include/" "${LINUX_DIR}/mofed/include"
fCopy_h_c_files "${MOFED_DIR}/block/" "${LINUX_DIR}/mofed/block"

fCopy_h_c_files "${MOFED_DIR}/drivers/net/ethernet/mellanox/mlx5/core/" "${LINUX_DIR}/drivers/net/ethernet/mellanox/mlx5/core"
fCopy_h_c_files "${MOFED_DIR}/drivers/net/ethernet/mellanox/mlxfw/" "${LINUX_DIR}/drivers/net/ethernet/mellanox/mlxfw"

fDoCommand "cp ${MOFED_DIR}/compat_base ${LINUX_DIR}/mofed/compat_base"
fDoCommand "cp ${MOFED_DIR}/compat_base_tree ${LINUX_DIR}/mofed/compat_base_tree"
fDoCommand "cp ${MOFED_DIR}/compat_base_tree_version ${LINUX_DIR}/mofed/compat_base_tree_version"
fDoCommand "cp ${MOFED_DIR}/compat_version ${LINUX_DIR}/mofed/compat_version"
#to check - this file is created only if the OFED is after configure & make
fDoCommand "cp ${MOFED_DIR}/Module.symvers ${LINUX_DIR}/mofed/"

cd ${LINUX_DIR}
fDoCommand "git add drivers/net/ethernet/mellanox/mlx5/"
fDoCommand "git add drivers/net/ethernet/mellanox/mlxfw/"
fDoCommand "git add mofed"
fDoCommand "git status"
echo "==============================>rebuild"

#./rebuild_nvidia_with_driver.sh

