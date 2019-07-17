#!/bin/bash

. /etc/os-release
if [ -z "$PRETTY_NAME" ]; then
    echo "Cannot get host information"
    exit 1
fi
echo $PRETTY_NAME

# config
REPO="file:///.autodirect/mtrsysgwork/roid/gerrit2/iproute2"
REPO="file:////images/chrism/iproute2"
[ -z "$BRANCH" ] && BRANCH=ct-one-table
TMPDIR=/tmp/tmp$$-iproute
DEBIAN=~chrism/bin/iproute2-ubuntu.debian.tar.gz

# run
set -e
echo "REPO: $REPO"
echo "BRANCH: $BRANCH"
echo "TMPDIR: $TMPDIR"
sleep 1
rm -fr $TMPDIR
mkdir -p $TMPDIR
cd $TMPDIR

# apt-get install -y fakeroot pkg-config libmnl0 libmnl-dev iptables iptables-dev \
#             libelf1 libelf-dev libdb-dev \
#             linuxdoc-tools psutils flex bison dvipsk-ja \
#             libselinux1-dev libatm1-dev \
#             texlive-latex-recommended  texlive-latex-extra

# clone and prep
CLONEDIR="iproute-$BRANCH"
git clone --depth=100 --branch=$BRANCH --single-branch $REPO $CLONEDIR
cd $CLONEDIR
git fetch -q --tags

# set version
git describe --always
VERSION=`git describe --always`
VERSION=${VERSION:1}
echo VERSION=$VERSION

tar -xzf $DEBIAN
dch -b -v ${VERSION}-1 ""

# create
DEB_BUILD_OPTIONS='parallel=16' fakeroot debian/rules binary

echo "Latest commits"
DEB=`ls -1 $TMPDIR/iproute2_$VERSION*.deb`
BASE=`basename -s .deb $DEB`
LOG=$TMPDIR/$BASE.log
git log --oneline -15 > $LOG
cat $LOG
echo "DIR $TMPDIR"
