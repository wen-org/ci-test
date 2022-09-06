#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})
source ../env.sh

save_workspace

gadmin start -v
sleep 20
gadmin stop vis -vy
sleep 5

cd $PRODUCT/bigtest/tests/gtest/
bash run_all.sh
cd -

cd $PRODUCT/bigtest/tests/gpr_test/
bash run_all.sh
cd -
