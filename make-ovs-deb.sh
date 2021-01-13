#!/bin/bash

# http://docs.openvswitch.org/en/latest/intro/install/debian/

. /etc/os-release
if [ -z "$PRETTY_NAME" ]; then
    echo "Cannot get host information"
    exit 1
fi
echo $PRETTY_NAME

# fix for python-sphinx binary location
# export PATH="/usr/libexec/python2-sphinx:$PATH"

# config
REPO=/images/cmi/openvswitch
BRANCH=ct-one-table-2.10

[ -z $TMPDIR ] && TMPDIR="/tmp/tmp$$-ovs"

# run
set -e
echo "REPO: $REPO"
echo "BRANCH: $BRANCH"
echo "TMPDIR: $TMPDIR"
sleep 1
rm -fr $TMPDIR
mkdir -p $TMPDIR
cd $TMPDIR

# install dependencies
sudo apt-get install -y dh-autoreconf build-essential fakeroot devscripts \
                     libcap-ng-dev python-sphinx python3-dev python3-twisted \
                     groff graphviz python3-zope.interface

# clone and prep
CLONEDIR="ovs-$BRANCH"
git clone --depth=100 --branch=$BRANCH --single-branch $REPO $CLONEDIR
cd $CLONEDIR
# dpkg-checkbuilddeps
git fetch -q --tags

VERSION=""
#git describe && VERSION=`git describe | tr - _` && VERSION=${VERSION:1}
if [ "$VERSION" == "" ]; then
    VERSION=`grep AC_INIT configure.ac | cut -d, -f2 | tr -d " "`
    #VERSION="`git symbolic-ref HEAD 2> /dev/null | cut -b 12-`-`git log --pretty=format:\"%h\" -1`"
    VERSION="${VERSION}-g`git log --pretty=format:\"%h\" -1`"
fi

# WA so Makefile won't be regenerated
#set +e ; timeout 5 make; set -e
#sed -i -e "s/^VERSION = .*/VERSION = $VERSION/" Makefile

sed -i "s/^\(AC_INIT(openvswitch,\) \([0-9.]\+\), /\1 $VERSION, /g" configure.ac

echo VERSION=$VERSION

# prep
./boot.sh
./configure
dch -b -v ${VERSION}-1 ""

CLONEDIR=$PWD

# create
DEB_BUILD_OPTIONS='parallel=16 nocheck' fakeroot debian/rules binary
TGZ_OLD="openvswitch.tar.gz"
TGZ="openvswitch-$VERSION.tar.gz"
mv $TGZ_OLD $TGZ
echo "TGZ $TGZ"
ls -l $TGZ

echo "Latest commits"
LOG="$TMPDIR/openvswitch-${VERSION}.log"
git log --oneline -30 > $LOG
cat $LOG
echo "DIR $TMPDIR"
