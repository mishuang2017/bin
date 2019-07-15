#!/bin/bash

SRC_RPM=$1
BUILD_DIR=$2

SRC_RPM=$(readlink -f ${SRC_RPM})

function exctract_srcs {
    rpm -ivh $SRC_RPM --define "_topdir $BUILD_DIR" &&
    rngd -r /dev/urandom
    rpmbuild -bp $BUILD_DIR/SPECS/kernel*.spec --define "_topdir $BUILD_DIR" --nodeps
    if [ $? -ne 0 ]; then
	    echo "Failed to extract the src.rpm!"
	    exit 1
    fi

    cd $BUILD_DIR/BUILD/kernel*/linux* 2>/dev/null || cd $BUILD_DIR/BUILD/kernel*/
#    read -p "Do you want to init git repo? [y|N] " -n 10 -r
#    echo
#    if [[ $REPLY =~ ^[Yy]$ ]]
#        the
    if (which git &>/dev/null); then
            echo "Creating a git repo ..."
            git init . &&
            git add . &&
            git commit --allow-empty -m "Repo Init"
    fi

#    read -p "Do you want to create CTAGS? [y|N] " -n 10 -r
#    echo
#    if [[ $REPLY =~ ^[Yy]$ ]]
#        then
#            find . -name "*.c" -o -name "*.cpp" -o -name "*.h" > cscope.files
#            sudo cscope -q -R -b -i cscope.files
    if (which ctags &>/dev/null); then
             echo "Creating CTAGS ..."
             ctags -R .
    fi

    echo
    echo "Ready at: $PWD"
}

if [ ! -e "$SRC_RPM" ]; then
        echo "ERROR: No SRCRPM was specified"
        exit 1
fi


if [ "X$BUILD_DIR" == "X" ]; then
        BUILD_DIR="/tmp/kernel_build"
else
	case "$BUILD_DIR" in
		\/*)
		;;
		*)
			BUILD_DIR="/tmp/$BUILD_DIR"
		;;
	esac
fi
echo "Will extract the src.rpm to '${BUILD_DIR}' ..."

if [ -d $BUILD_DIR ]; then
        read -p "Folder $BUILD_DIR already exist, will be overwriten. Are you Sure? [y|N]" -n 10 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]
            then
                exctract_srcs
        fi
    else
        mkdir -p $BUILD_DIR &&
        exctract_srcs
fi

