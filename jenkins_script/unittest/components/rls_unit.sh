#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})
source ../env.sh
set +e

save_workspace
read_ut_opt "$@"

cd $PRODUCT
# start zk
gadmin stop admin -vy
gadmin stop -vy
gadmin start zk -v

# compile
scons src/utility/replicated_log mode=$MODE $SAN_COMPILE_OPT

# run tests

build/$MODE/utility/replicated_log/unittests/replicatedlog_unittests --gtest_filter=-NamesTest.PartitionNameTest
