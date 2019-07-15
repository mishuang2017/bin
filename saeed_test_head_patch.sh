#!/bin/bash -e
#
# description     : Test the head patch of current branch
# author          : Saeed Mahameed <saeedm@emllanox.com>
# version         : 0.1
#

CURRDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "======================[ Testing PATCH ] ========================="
echo $(git log --abbrev=12 --format='%h ("%s")' -1)

function checkpatch {
	#checkpatch:
	CHKPATCH_IGNORE='--ignore GERRIT_CHANGE_ID,LONG_LINE,COMMIT_LOG_LONG_LINE,FILE_PATH_CHANGES,MACRO_ARG_REUSE'
	./scripts/checkpatch.pl --max-line-length=95 --strict --show-types ${CHKPATCH_IGNORE} -g HEAD
}

function check_fixes_tag {
	$CURRDIR/git_patch_fixes_check.sh HEAD
}

function compile {
	#make:
	make olddefconfig
	#KCFLAGS=-Werror make W=1 -j$(nproc) -s
	make -j$(nproc) -s
}

function werror {
	# should run after compile step
	# look for warning in mlx5_core only
	touch drivers/net/ethernet/mellanox/mlx5/core/mlx5_core.h
	KCFLAGS="-Wall -Werror" make W=1 drivers/net/ethernet/mellanox/mlx5/core/ -j
}

function mlx5_ifc {
	[ -z "$(git show HEAD --stat  | grep 'include/linux/mlx5/mlx5_ifc')" ] && return 0
	echo $(git log --oneline -1)
	echo "Touches mlx5_ifc.h: Checking .."
	$CURRDIR/mlx5_ifc/ifc_diff.sh HEAD~1..HEAD
}

tests="checkpatch
check_fixes_tag
mlx5_ifc
compile
werror"

for test in $tests
do
	echo ""
	echo "---------------[ $test ]----------------"
	set -x
	$test
	rc=$?
	{ set +x; } 2>/dev/null
	if [ "$rc" == "0" ] ; then echo [V] $test PASSED; else echo [X] $test FAILED; fi
done
