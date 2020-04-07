#!/bin/bash

. /etc/os-release
if [ -z "$PRETTY_NAME" ]; then
    echo "Cannot get host information"
    exit 1
fi
echo $PRETTY_NAME

if [ ! -e /usr/bin/rpmbuild ]; then
    echo "Cannot find rpmbuild"
    exit 1
fi

# config
# [ -z "$REPO" ] && REPO="/images/chrism/linux"
# [ -z "$BRANCH" ] && BRANCH='4.19'

[ -z "$REPO" ] && REPO="/images/chrism/5.4-ct-rpm"
[ -z "$BRANCH" ] && BRANCH='5.4-ct'

if [ "$DEBUG" == "1" ]; then
    CONFIG=/labhome/roid/scripts/ovs/.config_debug
else
    CONFIG=/labhome/roid/scripts/ovs/.config
fi
# CONFIG=/labhome/chrism/roi.config
# CONFIG=/labhome/chrism/roi.config.debug
# CONFIG=/images/chrism/linux/.config
CONFIG=/labhome/chrism/sm/config/config-5.4.19-100.fc30.x86_64
[ -z $TMPDIR ] && TMPDIR="/tmp/tmp$$-kernel"

# check for free space
free=`df  /tmp | tail -1 | awk {'print $4'}`
((need=15*1024*1024))
if (( free < need )); then
    echo "Please check for free space in /tmp"
    exit 1
fi

#if [ "$1" = "linus" ]; then
#    REPO="git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
#    BRANCH="master"
#fi

if [ ! -e $CONFIG ]; then
    echo "Cannot read $CONFIG"
    exit 1
fi

err=0
# warning
for i in \
    CONFIG_BOOTPARAM_HARDLOCKUP_PANIC=y \
    CONFIG_BOOTPARAM_SOFTLOCKUP_PANIC=y \
; do
    if grep $i $CONFIG ; then
        echo "WARNING: $i"
    fi
done

# error
for i in \
    CONFIG_KASAN=y \
; do
    if [ "$DEBUG" == "1" ]; then
        if ! grep $i $CONFIG ; then
            echo "ERROR: Cannot find $i"
            err=1
        fi
    else
        if grep $i $CONFIG ; then
            echo "ERROR: $i"
            err=1
        fi

    fi
done

test $err != 0 && exit $err
echo

# run
set -e
echo "REPO: $REPO"
echo "BRANCH: $BRANCH"
echo "CONFIG: $CONFIG"
echo "TMPDIR: $TMPDIR"
sleep 1
rm -fr $TMPDIR
mkdir -p $TMPDIR
cd $TMPDIR

# clone and prep
CLONEDIR="linux-$BRANCH"
git clone --depth=100 --branch=$BRANCH --single-branch $REPO $CLONEDIR
cd $CLONEDIR
cp $CONFIG ./.config
make olddefconfig

# prep rpm build env
RPMBUILDDIR=$TMPDIR/rpmbuild
mkdir -p $RPMBUILDDIR/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# create rpms
export RPMOPTS="--define \"%_topdir $RPMBUILDDIR\" --define \"_tmppath %{_topdir}/tmp\""
export INSTALL_MOD_STRIP=1
export CONFIG_LOCALVERSION_AUTO=y
if [ "$DEBUG" == "1" ]; then
    export LOCALVERSION=-ver
fi
export RPM_BUILD_NCPUS=32
make -s -j32 rpm-pkg RPM_BUILD_NCPUS=32

# locate rpms
RPMS=`find $RPMBUILDDIR/RPMS -iname "*.rpm"`
SRPM=`find $RPMBUILDDIR/SRPMS -iname "*.rpm"`

# copy to output folder
REPODIR=$TMPDIR/repo
mkdir -p $REPODIR
cp $RPMS $REPODIR
cp $SRPM $REPODIR

echo "Latest commits"
RPM=`ls -1tr $REPODIR/kernel-[0-9]*x86_64.rpm`
BASE=`basename -s .rpm $RPM`
LOG=$REPODIR/$BASE.log
git log --oneline -60 > $LOG
cat $LOG
echo "REPO DIR $REPODIR"
