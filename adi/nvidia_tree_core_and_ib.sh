#!/bin/bash

#========================================================================================
# Imports
# -------
#========================================================================================
source /.autodirect/vmgwork/adin/SW/scripts/sysConfig/General_functions/colors.sh
source /.autodirect/vmgwork/adin/SW/scripts/sysConfig/General_functions/general_funcs.sh

LINUX_DIR="/net/gen-l-vrt-103/adin/code/upstream/linux/"
MOFED_DIR="/net/gen-l-vrt-103/adin/code/mofed/mlnx-ofa_kernel-4.0/"
SCRIPTS_DIR="/net/gen-l-vrt-103/adin/code/upstream/scripts/"

#========================================================================================
# Functions
# ---------
#========================================================================================
fAddToMakefile(){
    local _Makefile=$1
    echo "=====================>${_Makefile}"
    #cat ${_Makefile}
    #cat ${_Makefile} | head -1 > temp
    cat /.autodirect/vmgwork/adin/SW/scripts/myScripts/nvidia/Addition_to_makefile.txt >>  temp
    #cat ${_Makefile} | tail - >> temp
    cat ${_Makefile} >> temp
    cat temp > ${_Makefile}
    rm -rf temp
    #echo "-------------------after change "
    #cat ${_Makefile}
} >>  build.txt

fCopy_h_c_Makefiles(){
    local _fromDir=$1
    local _toDir=$2
    echo "copy from $_fromDir to $_toDir *.h & *.c files"
    cd ${LINUX_DIR}
    if [ -d "${_toDir}" ]; then
        fDoCommand "echo Dir $_toDir exist"
    else
        fDoCommand "mkdir ${_toDir}"
    fi
    (cd ${_fromDir} && find . -name '*.h' -print | tar --create --files-from -) | (cd ${_toDir} && tar xvfp -)
    (cd ${_fromDir} && find . -name '*.c' -print | tar --create --files-from -) | (cd ${_toDir} && tar xvfp -)
    (cd ${_fromDir} && find . -name 'Makefile' -print | tar --create --files-from -) | (cd ${_toDir} && tar xvfp -)

    cd ${_toDir}
    for makefile in $(find -name "Makefile"); do
        local _isHW=`echo ${makefile} | grep \/hw | wc -l`
        if [ "$_isHW" == "0"  ]; then
            fAddToMakefile ${makefile}
        else
            local _isMellanox=`echo ${makefile} | grep \/mlx | wc -l`
            if [ "$_isMellanox" == "0"  ]; then
                echo "$_isHW-------------${makefile}----------------------Dont change Makefile"
            else
                fAddToMakefile ${makefile}
            fi
        fi
    done
    cd -
} >> build.txt

fCopy(){
    local _fromDir=$1
    local _toDir=$2

    if [ -d "${_toDir}" ]; then
        echo "Dir $_toDir exist"
    else
        fDoCommand "mkdir ${_toDir}"
    fi

    cp -rf $_fromDir $_toDir/../
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
#export KBUILD_OUTPUT="/adin/code/upstream/build/"; ./configure -j32 --with-mlx5-core-and-en-mod --kernel-version=4.4.52+ --modules-dir=$KBUILD_OUTPUT --kernel-sources=$KBUILD_OUTPUT/source --with-linux=$KBUILD_OUTPUT/source --with-linux-obj=$KBUILD_OUTPUT

if [ -d "${LINUX_DIR}/mofed" ]; then
    fDoCommand "rm -rf ${LINUX_DIR}/mofed"
    fDoCommand "mkdir ${LINUX_DIR}/mofed"
fi

fRemoveDir "${LINUX_DIR}/drivers/net/ethernet/mellanox/"
fRemoveDir "${LINUX_DIR}/drivers/infiniband/"

fDoCommand "git reset --hard HEAD"
fDoCommand "git status"

#create mofed directory in linux tree
fCopy_h_c_Makefiles "${MOFED_DIR}/compat/" "${LINUX_DIR}/mofed/compat"
fCopy_h_c_Makefiles "${MOFED_DIR}/compat/" "${LINUX_DIR}/mofed/compat"
fCopy_h_c_Makefiles "${MOFED_DIR}/include/" "${LINUX_DIR}/mofed/include"
fCopy_h_c_Makefiles "${MOFED_DIR}/block/" "${LINUX_DIR}/mofed/block"
fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/" "${LINUX_DIR}/mofed/drivers"
fDoCommand "cp ${MOFED_DIR}/compat_base ${LINUX_DIR}/mofed/compat_base"
fDoCommand "cp ${MOFED_DIR}/compat_base_tree ${LINUX_DIR}/mofed/compat_base_tree"
fDoCommand "cp ${MOFED_DIR}/compat_base_tree_version ${LINUX_DIR}/mofed/compat_base_tree_version"
fDoCommand "cp ${MOFED_DIR}/compat_version ${LINUX_DIR}/mofed/compat_version"
fDoCommand "cp ${MOFED_DIR}/Module.symvers ${LINUX_DIR}/mofed/"

#replace driver
fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/net/ethernet/mellanox/mlx5/core/" "${LINUX_DIR}/drivers/net/ethernet/mellanox/mlx5/core"
fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/net/ethernet/mellanox/mlxfw/" "${LINUX_DIR}/drivers/net/ethernet/mellanox/mlxfw"
#fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/infiniband/" "${LINUX_DIR}/drivers/infiniband/"
fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/infiniband/hw/mlx5/" "${LINUX_DIR}/drivers/infiniband/hw/mlx5/"
fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/infiniband/hw/nes/" "${LINUX_DIR}/drivers/infiniband/hw/nes/"
fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/infiniband/ulp/ipoib/" "${LINUX_DIR}/drivers/infiniband/ulp/ipoib/"
fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/infiniband/ulp/iser/" "${LINUX_DIR}/drivers/infiniband/ulp/iser/"
fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/infiniband/ulp/isert/" "${LINUX_DIR}/drivers/infiniband/ulp/isert/"
#problematic
fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/infiniband/ulp/srp/" "${LINUX_DIR}/drivers/infiniband/ulp/srp/"
fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/infiniband/ulp/srpt/" "${LINUX_DIR}/drivers/infiniband/ulp/srpt/"
fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/infiniband/core/" "${LINUX_DIR}/drivers/infiniband/core/"
#problematic
#fCopy_h_c_Makefiles "${MOFED_DIR}/net/sunrpc/xprtrdma/" "${LINUX_DIR}/net/sunrpc/xprtrdma/"
#cp ${MOFED_DIR}/drivers/Kconfig ${LINUX_DIR}/drivers/
(cd ${MOFED_DIR}/drivers/ && find . -name 'Kconfig' -print | tar --create --files-from -) | (cd ${LINUX_DIR}/drivers/ && tar xvfp -)

fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/infiniband/core/" "${LINUX_DIR}/drivers/infiniband/core/"
fCopy_h_c_Makefiles "${MOFED_DIR}/drivers/infiniband/hw/mlx5/" "${LINUX_DIR}/drivers/infiniband/hw/mlx5/"

#cp -rf  ${MOFED_DIR}/drivers/infiniband/hw/nes/* ${LINUX_DIR}/drivers/infiniband/hw/nes/
#cp -rf  ${MOFED_DIR}/drivers/infiniband/ulp/ipoib/* ${LINUX_DIR}/drivers/infiniband/ulp/ipoib/
#git c drivers/infiniband/ulp/ipoib/Makefile


cd ${LINUX_DIR}
echo "==============================>rebuild"
git c drivers/net/ethernet/mellanox/mlx4/Kconfig
git c drivers/infiniband/Kconfig
git c drivers/net/ethernet/mellanox/mlx5/core/Kconfig
rm -rf  drivers/infiniband/hw/ehca/
rm -rf  drivers/infiniband/hw/hfi1/
rm -rf  drivers/infiniband/hw/hns/
rm -rf  drivers/infiniband/hw/i40iw/
rm -rf  drivers/infiniband/hw/ipath/
git c drivers/infiniband/hw/mlx4
git c drivers/net/ethernet/mellanox/mlx5/core/Makefile
git c mofed/compat/Makefile

./rebuild_nvidia_with_driver.sh

exit
#fRemoveDir "${LINUX_DIR}/include/linux/mlx5/"
#fCopy_h_c_files "${MOFED_DIR}/include/linux/mlx5/" "${LINUX_DIR}/include/linux/mlx5"
