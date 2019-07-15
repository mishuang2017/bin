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
SPECDIR=~chrism/jd
SPEC=$SPECDIR/jd-kernel.spec
# [ -z "$REPO" ] && REPO="git@github.com:mishuang2017/linux.git"
[ -z "$REPO" ] && REPO="/home1/chrism/linux"
[ -z "$BRANCH" ] && BRANCH=${1:-jd-1-mlx5}
tmpbase="/home1/chrism/tmp"
mkdir -p $tmpbase
[ -z $TMPDIR ] && TMPDIR="$tmpbase/tmp$$-kernel"

# check for free space
free=`df  $tmpbase | tail -1 | awk {'print $4'}`
((need=15*1024*1024))
if (( free < need )); then
    echo "Please check for free space in $tmpbase"
    exit 1
fi

err=0
test $err != 0 && exit $err
echo

# run
set -e
echo "REPO: $REPO"
echo "BRANCH: $BRANCH"
echo "TMPDIR: $TMPDIR"
sleep 1
rm -fr $TMPDIR
mkdir -p $TMPDIR
cd $TMPDIR

# clone and prep
CLONEDIR="linux-$BRANCH"
git clone --depth=100 --branch=$BRANCH --single-branch $REPO $CLONEDIR
cd $CLONEDIR

# prep rpm build env
RPMBUILDDIR=$TMPDIR/rpmbuild
mkdir -p $RPMBUILDDIR/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# create rpms
export RPMOPTS="--define \"%_topdir $RPMBUILDDIR\" --define \"_tmppath %{_topdir}/tmp\""
export INSTALL_MOD_STRIP=1
export CONFIG_LOCALVERSION_AUTO=y
rm -f .scmversion
make kernelrelease
rel=`scripts/setlocalversion .`

# set scm version
#scripts/setlocalversion --save-scmversion .
#git add -f .scmversion
#git commit -m "add scmversion $rel"
kver=linux-`make kernelrelease`
echo kver $kver

#echo "set ver inside the module"
#target="drivers/net/ethernet/mellanox/mlx5/core/main.c"
#echo $rel $target
#sed -i "s/jd_version = \"\(.*\)\";/jd_version = \"\\1$rel\";/" $target
#git add drivers/net/ethernet/mellanox/mlx5/core/main.c
#git commit -m "set jd version $rel"
#kver=linux-3.10.0-693.21.1.el7
#echo kver $kver

git archive --format=tar --prefix=$kver/ -o ${kver}.tar HEAD
cp $SPEC $RPMBUILDDIR/SPECS
cp $SPECDIR/* $RPMBUILDDIR/SOURCES
cp ${kver}.tar $RPMBUILDDIR/SOURCES

SPEC=$RPMBUILDDIR/SPECS/`basename $SPEC`
rel=`echo $rel | cut -d- -f2`
sed -i "s/pkgrelease 693.21.1.el7/pkgrelease $rel/" $SPEC
echo pkgrelease $rel
cmd="rpmbuild $RPMOPTS -ba $SPEC"
echo $cmd
eval $cmd


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
