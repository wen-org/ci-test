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
scons -j4 src/utility/admin_server/ mode=$MODE $SAN_COMPILE_OPT

# clean up zk
$PROJECT_ROOT/zk/bin/zkCli.sh -server 127.0.0.1:19999 <<EOF
rmr /tigergraph/dict/objects/__services/RESTPP/_static_nodes
quit
EOF

# run tests
build/$MODE/utility/admin_server/unittests/admin_server_unittest #UT
build/$MODE/utility/admin_server/unittests/admin_server_smoketest #ST

# recover restpp config
gadmin __sync-config-to-dict
