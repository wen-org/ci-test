#!/bin/bash
#############################################
##This is a script to setup gsql testing env.
#############################################
set +ex
source $(dirname ${BASH_SOURCE[0]})/../../util.sh
set -ex

ulimit -n
source $HOME/.gium/GSQL/scripts/gsql_admin_complete
#############################################
## link to lib/gle
cd $PRODUCT/gtest
ln -s -f ../lib/gle/regress/base_line
ln -s -f ../lib/gle/regress/drivers
ln -s -f ../lib/gle/regress/lib
ln -s -f ../lib/gle/regress/resources
ln -s -f ../lib/gle/regress/test_case
cd -
############################################
# turn off zk disk writes
gadmin start -v
sleep 20
gsql 'set json_api = "v2" '
#############################################
