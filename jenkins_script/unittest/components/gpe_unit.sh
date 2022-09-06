#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})
source ../env.sh

save_workspace
read_ut_opt "$@"


cd $PRODUCT

# compile tests
scons unit mode=$MODE $SAN_COMPILE_OPT 

# run tests

build/$MODE/olgp/unittests/gunit --gtest_filter=GP* -GPE4UDFTEST.Partition_UD
build/$MODE/olgp/unittests/gunit --gtest_filter=UTILTEST.*
build/$MODE/olgp/unittests/gunit --gtest_filter=GNETTEST.*
