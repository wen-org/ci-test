#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})
source ../env.sh

save_workspace
read_ut_opt "$@"


cd $PRODUCT

gadmin stop admin -vy
gadmin stop -vy
gadmin start zk -v

# compile
scons src/utility/gdict mode=$MODE $SAN_COMPILE_OPT

# run tests
build/$MODE/utility/gdict/unittests/gdict_unittests
