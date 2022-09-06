#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})
source ../env.sh

save_workspace

read_ut_opt "$@"

# start zk and gdict
#gadmin restart zk -vy
#sleep 30
gadmin restart dict -vy
sleep 5
gadmin start -v
sleep 20
gadmin stop gse -vy

# clean up zk
$PROJECT_ROOT/zk/bin/zkCli.sh -server 127.0.0.1:19999 <<EOF
rmr /tigergraph/dict/objects/__services/RLS-GSE/_static_nodes
rmr /tigergraph/dict/objects/__services/RLS-GSE/_expelled_nodes
quit
EOF

cd $PRODUCT

# compile tests
scons unit mode=$MODE $SAN_COMPILE_OPT

# run tests
# build/release/olgp/unittests/gunit --gtest_filter=GSETEST.*


build/release/olgp/unittests/gunit --gtest_filter=GSETEST.*:-GSETEST.High*
build/release/olgp/unittests/gunit --gtest_filter=GSETEST.High*
