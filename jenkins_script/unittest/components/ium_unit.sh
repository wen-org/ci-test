#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})
branch='master'
if [[ $# -ge 1 ]]; then
  branch=$1
  shift
fi

source ../env.sh
#####################################################################
save_workspace
######################################################################
# test part 1: gtest
ium_test_folder=${PRODUCT}/src/gium
rm -rf $ium_test_folder
git clone -b $branch --quiet https://$GIT_USER:$GIT_TOKEN@github.com/TigerGraph/gium.git \
  $ium_test_folder --depth=1
cd $ium_test_folder/gtest
bash test_all.sh
cd -
######################################################################
# test part 2: original ium test
# copy current package for ium test
rm -rf /tmp/ium_test
mkdir -p  /tmp/ium_test/pkg
cp $PRODUCT/tigergraph.bin /tmp/ium_test/pkg/
PKG=`ls ${PROJECT_ROOT}/pkg_pool/*.tar.gz -atr | tail -n -1`
cp -f $PKG /tmp/ium_test/pkg/poc4.4_base.tar.gz
#####################################################################
cd $PRODUCT/bigtest/tests/ium_regression/
cp ~/.gsql/gsql.cfg.commited ./config_sample/MultiNode.cfg
./run_all.sh -b $branch -m MULTI
cd -
#####################################################################
# recover ium configuration
#yes | gadmin --config dummy || true
#echo -e '500\n500\n500\n500\n500\n500\nn\ny' | gadmin --configure timeout &> /dev/null
#gadmin config-apply
#####################################################################
# reinstall
$PRODUCT/tigergraph.bin -y
