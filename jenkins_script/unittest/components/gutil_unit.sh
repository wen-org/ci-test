#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})
source ../env.sh

save_workspace
read_ut_opt "$@"

gadmin stop admin -vy
gadmin stop -vy

cd $PRODUCT
# compile
scons -j4 src/utility mode=$MODE $SAN_COMPILE_OPT

# run tests

build/$MODE/utility/gutil/unittests/gutil_unittests
