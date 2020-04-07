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

# fix for python-sphinx binary location
export PATH="/usr/libexec/python2-sphinx:$PATH"

# config
# [ -z "$REPO" ] && REPO="file:///.autodirect/mtrsysgwork/roid/gerrit2/openvswitch"
# [ -z "$REPO" ] && REPO="file:///images/chrism/ovs-roi"
# [ -z "$BRANCH" ] && BRANCH=${1:-master}

[ -z "$REPO" ] && REPO="file:///images/chrism/ovs_2.13"
[ -z "$BRANCH" ] && BRANCH=${1:-2.13.0-ct}

SPEC="./rhel/openvswitch-fedora.spec"
[ -z $TMPDIR ] && TMPDIR="/tmp/tmp$$-ovs"

# run
set -e
echo "REPO: $REPO"
echo "BRANCH: $BRANCH"
echo "SPEC: $SPEC"
echo "TMPDIR: $TMPDIR"
sleep 1
rm -fr $TMPDIR
mkdir -p $TMPDIR
cd $TMPDIR

# install dependencies
if [ -e /usr/bin/dnf ]; then
    DNF=dnf
else
    DNF=yum
fi
sudo $DNF install -y PyQt4 libcap-ng-devel selinux-policy-devel \
                     python-sphinx python3-devel policycoreutils-python-utils \
                     groff graphviz python-zope-interface python3-sphinx \
                     unbound unbound-devel

# clone and prep
CLONEDIR="ovs-$BRANCH"
git clone --depth=100 --branch=$BRANCH --single-branch $REPO $CLONEDIR
cd $CLONEDIR
git fetch -q --tags

VERSION=""
#git describe && VERSION=`git describe | tr - _` && VERSION=${VERSION:1}
if [ "$VERSION" == "" ]; then
    VERSION=`grep AC_INIT configure.ac | cut -d, -f2 | tr -d " "`
    #VERSION="`git symbolic-ref HEAD 2> /dev/null | cut -b 12-`-`git log --pretty=format:\"%h\" -1`"
    VERSION="${VERSION}_g`git log --pretty=format:\"%h\" -1`"
fi

# WA so Makefile won't be regenerated
#set +e ; timeout 5 make; set -e
#sed -i -e "s/^VERSION = .*/VERSION = $VERSION/" Makefile

sed -i "s/^\(AC_INIT(openvswitch,\) \([0-9.]\+\), /\1 $VERSION, /g" configure.ac

echo VERSION=$VERSION

# prep
./boot.sh
./configure

CLONEDIR=$PWD
RPMBUILDDIR=$PWD/rpm/rpmbuild

# create rpms
make dist
TGZ="openvswitch-$VERSION.tar.gz"
echo "TGZ $TGZ"
ls -l $TGZ

# Enable this to compile the old dpif-hw-offload
#sed -i -e 's/%configure/%configure --enable-dpif-tc/g' $SPEC
make rpm-fedora RPMBUILD_OPT="--without check"

# locate rpms
RPMS=`find $RPMBUILDDIR/RPMS -iname "*.rpm"`
SRPM=`find $RPMBUILDDIR/SRPMS -iname "*.rpm"`

# copy to output folder
REPODIR=$TMPDIR/repo
mkdir -p $REPODIR
cp $RPMS $REPODIR
cp $SRPM $REPODIR

echo "Latest commits"
RPM=`ls -1 $REPODIR/openvswitch-$VERSION*.x86_64.rpm`
BASE=`basename -s .rpm $RPM`
LOG=$REPODIR/$BASE.log
cd $CLONEDIR
git log --oneline -30 > $LOG
cat $LOG
echo "REPO DIR $REPODIR"
