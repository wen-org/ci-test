#!/bin/bash
# This script is to install tigergraph.bin
# But it clears old files first:
#   * tigergraph/bin/*
#   * tigergraph/pkg_pool/*
#   * tigergraph/logs/*
#   * tigergraph/zk/zookeeper.out*
#   * tigergraph/kafka/kafka.out*
#   * tigergraph/kafka/*.log*
#   * product/gtest/output/*
#   * product/gtest/diff/*
##############################################
cwd=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
set -ex
source $cwd/../util.sh


if [ ! -f ${PRODUCT}/tigergraph.bin ]; then
  echo "${PRODUCT}/tigergraph.bin doesn't exist"
  exit 1
fi

# set license
LICENSE=`curl -s ftp://ftp.graphsql.com/lic/license.txt`
~/.gium/gadmin set-license-key $LICENSE
touch ~/.gsql/full_ium_4.3

# stop service first
~/.gium/gadmin stop -vy
~/.gium/gadmin stop admin -vy

find /tmp -type f -user ${USER} -mtime +15 -print -delete || true
# tigergraph binaries
rm -rf ${PROJECT_ROOT}/dev/*
rm -rf ${PROJECT_ROOT}/dev_*
rm -rf ${PROJECT_ROOT}/bin/libudf.so.dir/*
rm -rf ${PROJECT_ROOT}/bin/libudf.so.upd.dir/*
rm -rf ${PROJECT_ROOT}/pkg_pool/*

# tigergraph logs
rm -rf ${PROJECT_ROOT}/logs/* || true
rm -rf ${PROJECT_ROOT}/zk/zookeeper.out*
rm -rf ${PROJECT_ROOT}/kafka/kafka.out*
rm -rf ${PROJECT_ROOT}/kafka/*.log*

# gtest related
rm -rf ${PRODUCT}/gtest/output/*
rm -rf ${PRODUCT}/gtest/diff/*
rm -rf ${PRODUCT}/gtest/.working_dir/*

sudo apt-get remove libssl-dev -y || true
sudo apt-get remove libssl-doc -y || true
rm -rf ${PRODUCT}/build

cd ${PRODUCT} && bash ./tigergraph.bin -y -v

~/.gium/gadmin config-apply -v

crontab -l > mycron
sed -i "/.*all_log_cleanup.*/d" mycron
crontab mycron
rm -rf mycron
