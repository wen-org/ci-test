#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})
source ../env.sh

save_workspace

read_ut_opt "$@"

# start zk
gadmin stop admin -vy
gadmin stop -vy
gadmin start zk -v

cd $PRODUCT
# compile
scons -j4 src/utility/zklib/ mode=$MODE $SAN_COMPILE_OPT

# run tests

build/$MODE/utility/zklib/unittests/zk_unittests
