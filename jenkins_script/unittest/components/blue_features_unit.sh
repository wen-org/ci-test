#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})
source ../env.sh

save_workspace

gadmin start -v
sleep 20

cd $PRODUCT/src/blue/features/gtest
bash test_all.sh
cd -
