#!/bin/bash

cwd=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
set -ex

PROJECT_VERSION=$1
iumBranch='master'
if [[ $# -ge 2 ]]; then
  iumBranch=$2
fi

base_dir=~

#add IUM
TOKEN='5D4F3079B50C3C25AD015EF68FBA7B20B46B714D'
GIT_TOKEN=$(echo $TOKEN |tr '97531' '13579' |tr 'FEDCBA' 'abcdef')
curl --fail -H "Authorization: token $GIT_TOKEN" -L \
    https://api.github.com/repos/${PROJECT_VERSION}/gium/tarball/$iumBranch -o $base_dir/gium.tar.gz
if [ $? != 0 ]; then
  echo "Download IUM failed"
  exit 1
fi
rm -rf $base_dir/GraphSQL-gium*
rm -rf $base_dir/tigergraph-gium*
tar xzf $base_dir/gium.tar.gz -C $base_dir
if [ $? != 0 ]; then
  echo "Uncompress IUM failed"
  exit 1
fi
if [ "$PROJECT_VERSION" != "TigerGraph" ]; then
  cd $base_dir/GraphSQL-gium*
else
  cd $base_dir/tigergraph-gium*
fi
bash install.sh
cd -
rm -rf $base_dir/GraphSQL-gium*
rm -rf $base_dir/tigergraph-gium*

