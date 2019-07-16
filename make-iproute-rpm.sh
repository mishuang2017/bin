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
#[ -z "$REPO" ] && REPO="file:///.autodirect/mtrsysgwork/roid/gerrit2/iproute2"
[ -z "$REPO" ] && REPO="git://git.kernel.org/pub/scm/network/iproute2/iproute2-next.git"
[ -z "$BRANCH" ] && BRANCH=${1:-master}
SPEC=~roid/scripts/ovs/iproute.spec
TMPDIR=/tmp/tmp$$-iproute

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
sudo $DNF install -y libmnl libmnl-devel iptables iptables-devel elfutils-devel libdb-devel linuxdoc-tools texlive-preprint psutils flex bison libcap-devel libcap

# Ubuntu
#sudo apt-get install libmnl-dev libmnl0 libdb-dev libselinux1-dev libatm1-dev libelf-dev flex bison

# clone and prep
CLONEDIR="iproute-$BRANCH"
git clone --depth=100 --branch=$BRANCH --single-branch $REPO $CLONEDIR
cd $CLONEDIR
git fetch -q --tags
cp $SPEC .

# set version
git describe
SPEC=`basename $SPEC`
VERSION=`git describe | tr - _`
VERSION=${VERSION:1}
sed -i -e "s/%version/$VERSION/" $SPEC

# prep rpm build env
RPMBUILDDIR=$TMPDIR/rpmbuild
mkdir -p $RPMBUILDDIR/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

cd ..
NEWCLONEDIR="iproute2-$VERSION"
mv $CLONEDIR $NEWCLONEDIR
CLONEDIR=$NEWCLONEDIR
tar -cJf $RPMBUILDDIR/SOURCES/$CLONEDIR.tar.xz $CLONEDIR
cp $CLONEDIR/$SPEC $RPMBUILDDIR/SPECS

# create rpms
export RPMOPTS="--define \"%_topdir $RPMBUILDDIR\" --define \"_tmppath %{_topdir}/tmp\""
cmd="rpmbuild $RPMOPTS -ba $RPMBUILDDIR/SPECS/$SPEC"
echo $cmd
eval $cmd

# locate rpms
RPMS=`find $RPMBUILDDIR/RPMS -iname "*.rpm"`
SRPMS=`find $RPMBUILDDIR/SRPMS -iname "*.rpm"`

# copy to output folder
REPODIR=$TMPDIR/repo
mkdir -p $REPODIR
cp $RPMS $REPODIR
cp $SRPMS $REPODIR

echo "Latest commits"
RPM=`ls -1 $REPODIR/iproute-$VERSION*.x86_64.rpm`
BASE=`basename -s .rpm $RPM`
LOG=$REPODIR/$BASE.log
cd $CLONEDIR
git log --oneline -15 > $LOG
cat $LOG
echo "REPO DIR $REPODIR"
